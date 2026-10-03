// Ponte MIDI bidirecional entre um instrumento USB (piano) e dispositivos
// Bluetooth MIDI conectados ao Mac (ex.: iPhone/iPad rodando Smart Pianist).
import CoreMIDI
import Foundation
import os

struct MIDIEndpointInfo: Identifiable, Hashable {
    let id: Int32          // kMIDIPropertyUniqueID
    let name: String
    let isBluetooth: Bool
}

/// Estado compartilhado com a thread de MIDI (CoreMIDI chama o bloco de entrada fora da main thread).
private final class SharedState: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock()
    private var _pianoID: Int32?
    private var _filterClock = true
    private var _filterActiveSensing = true
    private var _toDevice = 0
    private var _toPiano = 0
    private var _filtered = 0

    var pianoID: Int32? {
        get { lock.withLock { _pianoID } }
        set { lock.withLock { _pianoID = newValue } }
    }
    var filterClock: Bool {
        get { lock.withLock { _filterClock } }
        set { lock.withLock { _filterClock = newValue } }
    }
    var filterActiveSensing: Bool {
        get { lock.withLock { _filterActiveSensing } }
        set { lock.withLock { _filterActiveSensing = newValue } }
    }
    func count(toDevice: Int = 0, toPiano: Int = 0, filtered: Int = 0) {
        lock.withLock { _toDevice += toDevice; _toPiano += toPiano; _filtered += filtered }
    }
    func counters() -> (Int, Int, Int) { lock.withLock { (_toDevice, _toPiano, _filtered) } }
}

@MainActor
final class MIDIBridge: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var endpoints: [MIDIEndpointInfo] = []
    @Published private(set) var toDevice = 0
    @Published private(set) var toPiano = 0
    @Published private(set) var filtered = 0
    /// Bytes por segundo em cada sentido (alimenta os VU meters).
    @Published private(set) var rateToDevice: Double = 0
    @Published private(set) var rateToPiano: Double = 0
    @Published private(set) var lastError: String?

    @Published var pianoID: Int32? {
        didSet { state.pianoID = pianoID; UserDefaults.standard.set(pianoName, forKey: "pianoName"); reconnect() }
    }
    @Published var filterClock: Bool {
        didSet { state.filterClock = filterClock; UserDefaults.standard.set(filterClock, forKey: "filterClock") }
    }
    @Published var filterActiveSensing: Bool {
        didSet { state.filterActiveSensing = filterActiveSensing; UserDefaults.standard.set(filterActiveSensing, forKey: "filterActiveSensing") }
    }

    private let state = SharedState()
    private var client = MIDIClientRef()
    private var inPort = MIDIPortRef()
    private var outPort = MIDIPortRef()
    private var timer: Timer?

    var pianoName: String? { endpoints.first { $0.id == pianoID }?.name }
    var devices: [MIDIEndpointInfo] { endpoints.filter { $0.id != pianoID && $0.isBluetooth } }

    init() {
        let d = UserDefaults.standard
        filterClock = d.object(forKey: "filterClock") as? Bool ?? true
        filterActiveSensing = d.object(forKey: "filterActiveSensing") as? Bool ?? true
        state.filterClock = filterClock
        state.filterActiveSensing = filterActiveSensing

        let status = MIDIClientCreateWithBlock("Piano MIDI Bridge" as CFString, &client) { [weak self] notif in
            guard notif.pointee.messageID == .msgSetupChanged else { return }
            Task { @MainActor in self?.refreshEndpoints() }
        }
        if status != noErr { lastError = "Falha ao iniciar CoreMIDI (\(status))"; return }
        MIDIOutputPortCreate(client, "out" as CFString, &outPort)

        let state = self.state
        let outPort = self.outPort
        MIDIInputPortCreateWithBlock(client, "in" as CFString, &inPort) { list, refCon in
            MIDIBridge.forward(list, fromPiano: Int(bitPattern: refCon) == 1, state: state, outPort: outPort)
        }

        refreshEndpoints()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let (dev, pno, flt) = self.state.counters()
                self.rateToDevice = Double(dev - self.toDevice) / 0.2
                self.rateToPiano = Double(pno - self.toPiano) / 0.2
                (self.toDevice, self.toPiano, self.filtered) = (dev, pno, flt)
            }
        }
        if d.object(forKey: "autoStart") as? Bool ?? true { start() }
    }

    func start() { isRunning = true; UserDefaults.standard.set(true, forKey: "autoStart"); reconnect() }
    func stop() { isRunning = false; UserDefaults.standard.set(false, forKey: "autoStart"); disconnectAll() }

    // MARK: - Endpoints

    private func refreshEndpoints() {
        var list: [MIDIEndpointInfo] = []
        var seen = Set<Int32>()
        for i in 0..<MIDIGetNumberOfSources() {
            let src = MIDIGetSource(i)
            let info = MIDIBridge.info(src)
            if seen.insert(info.id).inserted { list.append(info) }
        }
        endpoints = list

        // Mantém o piano escolhido; senão tenta o nome salvo; senão o primeiro instrumento não-Bluetooth.
        if pianoID == nil || !list.contains(where: { $0.id == pianoID }) {
            let saved = UserDefaults.standard.string(forKey: "pianoName")
            let candidates = list.filter { !$0.isBluetooth }
            let pick = candidates.first { $0.name == saved }
                ?? candidates.first { $0.name.localizedCaseInsensitiveContains("piano") }
                ?? candidates.first
            if pick?.id != pianoID { pianoID = pick?.id; return } // didSet já reconecta
        }
        reconnect()
    }

    private func disconnectAll() {
        for i in 0..<MIDIGetNumberOfSources() { MIDIPortDisconnectSource(inPort, MIDIGetSource(i)) }
    }

    private func reconnect() {
        disconnectAll()
        guard isRunning, let pianoID else { return }
        for i in 0..<MIDIGetNumberOfSources() {
            let src = MIDIGetSource(i)
            let info = MIDIBridge.info(src)
            let isPiano = info.id == pianoID
            guard isPiano || info.isBluetooth else { continue }
            // refCon: 1 = mensagem vinda do piano, 2 = vinda de um dispositivo Bluetooth
            MIDIPortConnectSource(inPort, src, UnsafeMutableRawPointer(bitPattern: isPiano ? 1 : 2))
        }
    }

    nonisolated private static func info(_ obj: MIDIObjectRef) -> MIDIEndpointInfo {
        var uid: Int32 = 0
        MIDIObjectGetIntegerProperty(obj, kMIDIPropertyUniqueID, &uid)
        var name: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(obj, kMIDIPropertyDisplayName, &name)
        // Endpoints Bluetooth pertencem ao driver BLE da Apple.
        var entity = MIDIEntityRef(), device = MIDIDeviceRef()
        var driver: Unmanaged<CFString>?
        if MIDIEndpointGetEntity(obj, &entity) == noErr, MIDIEntityGetDevice(entity, &device) == noErr {
            MIDIObjectGetStringProperty(device, kMIDIPropertyDriverOwner, &driver)
        }
        let driverName = (driver?.takeRetainedValue() as String?) ?? ""
        return MIDIEndpointInfo(id: uid,
                                name: (name?.takeRetainedValue() as String?) ?? "?",
                                isBluetooth: driverName.localizedCaseInsensitiveContains("bluetooth"))
    }

    // MARK: - Encaminhamento (thread do CoreMIDI)

    nonisolated private static func destinations(piano: Bool, pianoID: Int32) -> [MIDIEndpointRef] {
        (0..<MIDIGetNumberOfDestinations()).map { MIDIGetDestination($0) }.filter {
            let i = info($0)
            return piano ? i.id == pianoID || (i.name == nameOfSource(pianoID) && !i.isBluetooth)
                         : i.isBluetooth
        }
    }

    /// Origem e destino do mesmo dispositivo podem ter UniqueIDs diferentes; casa pelo nome.
    nonisolated private static func nameOfSource(_ id: Int32) -> String? {
        for i in 0..<MIDIGetNumberOfSources() {
            let s = MIDIGetSource(i)
            var uid: Int32 = 0
            MIDIObjectGetIntegerProperty(s, kMIDIPropertyUniqueID, &uid)
            if uid == id { return info(s).name }
        }
        return nil
    }

    nonisolated private static func forward(_ list: UnsafePointer<MIDIPacketList>, fromPiano: Bool,
                                            state: SharedState, outPort: MIDIPortRef) {
        guard let pianoID = state.pianoID else { return }

        // Bytes de tempo real (F8 clock, FE active sensing) têm 1 byte e podem
        // aparecer em qualquer posição, até no meio de um SysEx: basta removê-los.
        var drop = Set<UInt8>()
        if fromPiano {
            if state.filterClock { drop.insert(0xF8) }
            if state.filterActiveSensing { drop.insert(0xFE) }
        }

        var total = 0, removed = 0
        let bufferSize = 65536
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: 4)
        defer { buffer.deallocate() }
        let out = buffer.assumingMemoryBound(to: MIDIPacketList.self)
        var cur = MIDIPacketListInit(out)
        let dataOffset = MemoryLayout<MIDIPacket>.offset(of: \MIDIPacket.data)!

        for packet in list.unsafeSequence() {
            // MIDIPacket tem tamanho variável (SysEx pode passar de 256 bytes): lê pelo ponteiro.
            let raw = UnsafeRawBufferPointer(start: UnsafeRawPointer(packet) + dataOffset,
                                             count: Int(packet.pointee.length))
            let kept = drop.isEmpty ? Array(raw) : raw.filter { !drop.contains($0) }
            removed += raw.count - kept.count
            guard !kept.isEmpty else { continue }
            cur = MIDIPacketListAdd(out, bufferSize, cur, packet.pointee.timeStamp, kept.count, kept)
            total += kept.count
        }

        if removed > 0 { state.count(filtered: removed) }
        guard total > 0 else { return }
        let targets = destinations(piano: !fromPiano, pianoID: pianoID)
        for d in targets { MIDISend(outPort, d, out) }
        if fromPiano { state.count(toDevice: total) } else { state.count(toPiano: total) }
    }
}
