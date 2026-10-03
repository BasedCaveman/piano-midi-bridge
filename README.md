# 🎹 Piano MIDI Bridge

Use o **Smart Pianist** (ou outro app MIDI do iPhone/iPad) com um piano digital ligado **por USB ao Mac**, sem comprar o adaptador Bluetooth MIDI (ex.: Yamaha UD-BT01).

O Mac vira um "adaptador Bluetooth MIDI": o iPhone se conecta ao Mac por Bluetooth e o app repassa as mensagens MIDI entre o iPhone e o piano USB, nos dois sentidos (notas, pedais, comandos e SysEx).

```
iPhone (Smart Pianist) ──Bluetooth MIDI──▶ Mac (Piano MIDI Bridge) ──USB──▶ Piano
```

Testado com **Yamaha P-145BT** + Smart Pianist no iPhone. Deve funcionar com qualquer instrumento USB-MIDI class-compliant.

> Projeto independente, sem vínculo com a Yamaha. "Yamaha", "Smart Pianist" e "UD-BT01" são marcas de seus respectivos donos.

## Requisitos

- macOS 14 (Sonoma) ou mais novo, Apple Silicon ou Intel
- Mac com Bluetooth
- Piano ligado ao Mac por cabo USB (porta **USB TO HOST** do piano)

## Instalação

1. Baixe o `PianoMIDIBridge-x.y.z.dmg` em **[Releases](../../releases)**.
2. Abra o DMG e arraste **Piano MIDI Bridge** para **Aplicativos**.
3. **Primeira abertura:** o app não é assinado com certificado da Apple, então o macOS vai bloquear:
   - Abra o app uma vez (vai aparecer o aviso) e feche o aviso.
   - Vá em **Ajustes do Sistema → Privacidade e Segurança**, role até o fim e clique em **Abrir Mesmo Assim**.
   - Ou, pelo Terminal:
     ```bash
     xattr -dr com.apple.quarantine "/Applications/Piano MIDI Bridge.app"
     ```
4. O app aparece como um ícone de teclado 🎹 na **barra de menus** (não aparece no Dock).

## Como usar

1. Ligue o piano no Mac pelo cabo USB.
2. Clique no ícone 🎹 na barra de menus e confira se o piano aparece em **Instrumento (USB)**.
3. Clique em **Configurar Bluetooth MIDI (Anunciar)…**, dê um nome (ex.: `P-145`) e clique em **Anunciar**.
   - Se o app do iPhone não encontrar o Mac, use o nome `UD-BT01`.
4. No iPhone, abra o **Smart Pianist → Instrumento → Bluetooth** e conecte no nome escolhido.
   - ⚠️ Não pareie pelos Ajustes → Bluetooth do iPhone; conecte **por dentro do app**.
5. O ícone fica preenchido e o iPhone aparece em **Dispositivo (Bluetooth)**. Pronto!

### Opções

| Opção | O que faz |
|---|---|
| Interruptor no topo | Liga/desliga a ponte |
| **Filtrar clock MIDI (F8)** | Não envia o clock do piano ao iPhone. Recomendado: o clock gera dezenas de mensagens por segundo e pode derrubar a conexão Bluetooth |
| **Filtrar active sensing (FE)** | Não envia o "estou vivo" do piano. Recomendado pelo mesmo motivo |
| Abrir ao iniciar o Mac | Inicia o app automaticamente no login |

Os contadores mostram quantos bytes foram enviados em cada sentido e quantos foram filtrados.

## Problemas comuns

- **O piano não aparece:** confira o cabo (tem que ser de dados) e a porta USB TO HOST. Ele deve aparecer em *Configuração de Áudio e MIDI*.
- **O iPhone não encontra o Mac:** abra de novo a janela de Bluetooth MIDI e confirme que está **Anunciando**. Feche e reabra o Smart Pianist. Teste o nome `UD-BT01`.
- **A conexão cai:** deixe os dois filtros ligados e mantenha o iPhone perto do Mac.
- **O app conecta, mas não reconhece o piano:** desligue e ligue a ponte pelo interruptor e reconecte pelo app.

## Compilar a partir do código

Precisa só das Command Line Tools (`xcode-select --install`), não do Xcode completo.

```bash
./build.sh                 # gera build/Piano MIDI Bridge.app e build/PianoMIDIBridge-1.0.0.dmg
VERSION=1.1.0 ./build.sh   # outra versão
```

Com um certificado Developer ID, defina `DEVELOPER_ID="Developer ID Application: Seu Nome (TEAMID)"` para assinar de verdade.

### Estrutura

```
Sources/MIDIBridge.swift   motor CoreMIDI: detecta portas, repassa e filtra mensagens
Sources/App.swift          interface SwiftUI na barra de menus
Resources/Info.plist       metadados do app
scripts/make-icon.swift    gera o ícone
build.sh                   compila, monta o .app, assina e cria o .dmg
```

Como funciona: o app escuta o instrumento USB escolhido e todas as portas do driver Bluetooth MIDI da Apple. Tudo que chega de um lado é reenviado ao outro. Os bytes de tempo real `F8`/`FE` são removidos só no sentido piano → iPhone, quando os filtros estão ligados.

---

## English (short)

Menu-bar app that turns your Mac into a Bluetooth MIDI adapter. Your iPhone/iPad (e.g. Yamaha **Smart Pianist**) connects to the Mac over Bluetooth MIDI, and the app forwards all MIDI (including SysEx) to and from a piano connected to the Mac by USB. No UD-BT01 needed. It can optionally filter MIDI clock (F8) and active sensing (FE) to keep the BLE link stable.

Install the DMG from Releases, allow it under *System Settings → Privacy & Security → Open Anyway*, click the 🎹 menu-bar icon, then **Configure Bluetooth MIDI → Advertise**, and connect from the app on the iPhone. Build with `./build.sh` (Command Line Tools only). Requires macOS 14+.

## Licença

MIT. Veja [LICENSE](LICENSE).
