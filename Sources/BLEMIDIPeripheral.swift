// Periférico Bluetooth LE MIDI próprio: o app anuncia o serviço BLE MIDI padrão
// (o mesmo que adaptadores como o UD-BT01 usam) e converte entre o formato BLE MIDI
// e bytes MIDI comuns. Dispensa a janela "Bluetooth Configuration" do macOS.
import CoreBluetooth
import Foundation

final class BLEMIDIPeripheral: NSObject, CBPeripheralManagerDelegate, @unchecked Sendable {
    static let serviceUUID = CBUUID(string: "03B80E5A-EDE8-4B33-A751-6CE34EC4C700")
    static let characteristicUUID = CBUUID(string: "7772E5DB-3868-4112-A1A9-F2669D106BF3")

    enum Status: Equatable { case starting, off, unauthorized, unsupported, idle, advertising, connected(Int) }

    /// Chamado (na fila do Bluetooth) com bytes MIDI vindos do iPhone/iPad.
    var onMIDI: (([UInt8]) -> Void)?
    /// Chamado na main thread quando o estado muda.
    var onStatus: ((Status) -> Void)?

    private let queue = DispatchQueue(label: "piano-midi-bridge.ble")
    private var manager: CBPeripheralManager?
    private var characteristic: CBMutableCharacteristic?
    private var subscribers: [CBCentral] = []
    private var pending: [Data] = []
    private var wantAdvertising = false
    private var name = "Piano Bridge"
    private var decoder = BLEMIDIDecoder()
    private var encoder = BLEMIDIEncoder()
    private var lastReported: Status?

    override init() {
        super.init()
        // Sem NSBluetoothAlwaysUsageDescription o macOS encerra o processo ao usar Bluetooth.
        if Bundle.main.object(forInfoDictionaryKey: "NSBluetoothAlwaysUsageDescription") != nil {
            manager = CBPeripheralManager(delegate: self, queue: queue)
        } else {
            DiagLog.write("BLE: desativado (Info.plist sem NSBluetoothAlwaysUsageDescription)")
        }
    }

    // MARK: API

    func start(name: String) {
        queue.async {
            self.name = name
            self.wantAdvertising = true
            self.setupIfReady()
        }
    }

    func stop() {
        queue.async {
            self.wantAdvertising = false
            self.manager?.stopAdvertising()
            self.manager?.removeAllServices()
            self.characteristic = nil
            self.subscribers = []
            self.pending = []
            self.report()
        }
    }

    func rename(_ newName: String) {
        queue.async {
            guard newName != self.name else { return }
            self.name = newName
            if self.wantAdvertising, self.manager?.isAdvertising == true {
                self.manager?.stopAdvertising()
                self.advertise()
            }
        }
    }

    /// Envia bytes MIDI (mensagens completas ou trechos de SysEx) ao iPhone conectado.
    func send(_ bytes: [UInt8]) {
        queue.async {
            guard let ch = self.characteristic, !self.subscribers.isEmpty else { return }
            let mtu = max(20, min(self.subscribers.map { $0.maximumUpdateValueLength }.min() ?? 20, 512))
            self.pending.append(contentsOf: self.encoder.packets(for: bytes, maxLength: mtu))
            self.flush(ch)
        }
    }

    var hasSubscribers: Bool { queue.sync { !subscribers.isEmpty } }

    // MARK: Internals

    private func setupIfReady() {
        guard let manager, wantAdvertising, manager.state == .poweredOn else { report(); return }
        if characteristic == nil {
            let ch = CBMutableCharacteristic(type: Self.characteristicUUID,
                                             properties: [.read, .writeWithoutResponse, .notify],
                                             value: nil, permissions: [.readable, .writeable])
            let service = CBMutableService(type: Self.serviceUUID, primary: true)
            service.characteristics = [ch]
            characteristic = ch
            manager.add(service) // continua em didAdd
        } else if !manager.isAdvertising {
            advertise()
        }
    }

    private func advertise() {
        manager?.startAdvertising([CBAdvertisementDataLocalNameKey: name,
                                  CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID]])
    }

    private func flush(_ ch: CBMutableCharacteristic) {
        while let first = pending.first {
            if manager?.updateValue(first, for: ch, onSubscribedCentrals: nil) == true {
                pending.removeFirst()
            } else {
                return // continua em peripheralManagerIsReady(toUpdateSubscribers:)
            }
        }
    }

    private func report() {
        let s: Status
        switch manager?.state ?? .unsupported {
        case .poweredOff: s = .off
        case .unauthorized: s = .unauthorized
        case .unsupported: s = .unsupported
        case .unknown, .resetting: s = .starting
        default:
            if !wantAdvertising { s = .idle }
            else if !subscribers.isEmpty { s = .connected(subscribers.count) }
            else { s = .advertising }
        }
        if s != lastReported { DiagLog.write("BLE: \(s) (estado do Bluetooth: \(manager?.state.rawValue ?? -1))"); lastReported = s }
        DispatchQueue.main.async { self.onStatus?(s) }
    }

    // MARK: CBPeripheralManagerDelegate

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state != .poweredOn { characteristic = nil; subscribers = [] }
        setupIfReady()
        report()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error { DiagLog.write("BLE: erro ao registrar serviço: \(error.localizedDescription)") }
        if error == nil, wantAdvertising { advertise() }
        report()
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        DiagLog.write(error.map { "BLE: erro ao anunciar: \($0.localizedDescription)" } ?? "BLE: anunciando como “\(name)”")
        report()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        if !subscribers.contains(where: { $0.identifier == central.identifier }) { subscribers.append(central) }
        DiagLog.write("BLE: dispositivo conectado (MTU \(central.maximumUpdateValueLength))")
        decoder = BLEMIDIDecoder()
        encoder = BLEMIDIEncoder()
        report()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscribers.removeAll { $0.identifier == central.identifier }
        DiagLog.write("BLE: dispositivo desconectado")
        if subscribers.isEmpty { pending = [] }
        report()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        // A especificação BLE MIDI pede leitura vazia.
        request.value = Data()
        peripheral.respond(to: request, withResult: .success)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for r in requests {
            if let v = r.value {
                let bytes = decoder.decode(Array(v))
                if bytes.first == 0xF0 { DiagLog.write("iPhone → piano SysEx: " + bytes.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " ")) }
                if !bytes.isEmpty { onMIDI?(bytes) }
            }
        }
        if let first = requests.first { peripheral.respond(to: first, withResult: .success) }
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        if let ch = characteristic { flush(ch) }
    }
}

// MARK: - Formato BLE MIDI

/// Timestamp BLE MIDI de 13 bits em milissegundos.
private func bleTimestamp() -> (header: UInt8, ts: UInt8) {
    let ms = UInt32(truncatingIfNeeded: UInt64(Date().timeIntervalSince1970 * 1000)) & 0x1FFF
    return (0x80 | UInt8((ms >> 7) & 0x3F), 0x80 | UInt8(ms & 0x7F))
}

struct BLEMIDIEncoder {
    /// Guardado entre chamadas: um SysEx do piano pode chegar em vários pedaços.
    private var inSysex = false

    /// Converte bytes MIDI em pacotes BLE MIDI: cabeçalho + (timestamp antes de cada status).
    /// SysEx longo é dividido em pacotes de continuação, como manda a especificação.
    mutating func packets(for bytes: [UInt8], maxLength: Int) -> [Data] {
        let (header, ts) = bleTimestamp()
        var out: [Data] = []
        var cur: [UInt8] = [header]
        var i = 0

        func newPacket() { out.append(Data(cur)); cur = [header] }

        while i < bytes.count {
            let b = bytes[i]
            if b >= 0x80 {
                if b >= 0xF8 {
                    // tempo real: timestamp + byte, pode aparecer até no meio de um SysEx
                    if cur.count + 2 > maxLength { newPacket() }
                    cur += [ts, b]; i += 1; continue
                }
                if b == 0xF7 {
                    if cur.count + 2 > maxLength { newPacket() }
                    cur += [ts, b]; inSysex = false; i += 1; continue
                }
                if b == 0xF0 {
                    if cur.count + 3 > maxLength { newPacket() }
                    cur += [ts, b]; inSysex = true; i += 1; continue
                }
                // mensagem de canal/sistema comum: mantém a mensagem inteira no mesmo pacote
                var len = 1
                while i + len < bytes.count, bytes[i + len] < 0x80 { len += 1 }
                if cur.count + 1 + len > maxLength { newPacket() }
                cur.append(ts)
                cur += bytes[i..<(i + len)]
                i += len
                inSysex = false
            } else {
                // byte de dados: dentro de SysEx pode quebrar em qualquer ponto
                if cur.count + 1 > maxLength { newPacket() }
                if !inSysex && cur.count == 1 { cur.append(ts) } // segurança para dados soltos
                cur.append(b); i += 1
            }
        }
        if cur.count > 1 { out.append(Data(cur)) }
        return out
    }
}

struct BLEMIDIDecoder {
    private var inSysex = false
    private var runningStatus: UInt8 = 0
    private var expectStatusAfterTimestamp = false

    /// Converte um pacote BLE MIDI em bytes MIDI comuns (reinsere running status).
    mutating func decode(_ packet: [UInt8]) -> [UInt8] {
        guard packet.count > 1, packet[0] & 0x80 != 0 else { return [] }
        var out: [UInt8] = []
        var i = 1
        expectStatusAfterTimestamp = false
        while i < packet.count {
            let b = packet[i]
            if b & 0x80 != 0 {
                if !expectStatusAfterTimestamp {
                    expectStatusAfterTimestamp = true // é um timestamp
                } else {
                    out.append(b) // é um status
                    expectStatusAfterTimestamp = false
                    if b == 0xF0 { inSysex = true }
                    else if b == 0xF7 { inSysex = false }
                    else if b < 0xF0 { runningStatus = b }
                    else if b < 0xF8 { runningStatus = 0 }
                }
            } else {
                if expectStatusAfterTimestamp && !inSysex && runningStatus != 0 {
                    out.append(runningStatus) // running status depois de timestamp
                }
                expectStatusAfterTimestamp = false
                out.append(b)
            }
            i += 1
        }
        return out
    }
}
