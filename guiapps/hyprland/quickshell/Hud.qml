import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// HUD de atalho: os binds reconhecidos chamam `hud flash <id>` além da ação,
// e o atalho aparece embaixo, no centro, por 1,2 s. Segurar o super mostra a
// continuação (o que dá para apertar a partir dali); SUPER+/ abre a lista
// completa. Caps Lock e Num Lock também aparecem aqui ao mudar.
Scope {
    id: root

    // Os ids batem com os binds `hud flash` do default.nix/screenshots.nix.
    readonly property var binds: [
        { id: "w", keys: ["super", "w"], label: "gaveta de widgets", command: "quickshell · drawer", icon: "squares-four", color: Theme.purple },
        { id: "u", keys: ["super", "u"], label: "limites de uso", command: "quickshell · ai", icon: "gauge", color: Theme.orange },
        { id: "a", keys: ["super", "a"], label: "central de controle", command: "quickshell · control", icon: "sliders-horizontal", color: Theme.cyan },
        { id: "n", keys: ["super", "n"], label: "notificações", command: "quickshell · notifications", icon: "bell", color: Theme.red },
        { id: "space", keys: ["super", "space"], label: "buscar", command: "quickshell · launcher", icon: "magnifying-glass", color: Theme.yellow },
        { id: "shift-s", keys: ["super", "shift", "s"], label: "captura de região", command: "hyprshot -m region", icon: "crop", color: Theme.green },
        { id: "shift-o", keys: ["super", "shift", "o"], label: "capturar e OCR", command: "screenshot-ocr region", icon: "text-aa", color: Theme.green },
        { id: "ctrl-v", keys: ["super", "ctrl", "v"], label: "área de transferência", command: "quickshell · cliphist", icon: "clipboard-text", color: Theme.yellow },
        { id: "return", keys: ["super", "enter"], label: "terminal", command: "ghostty", icon: "terminal-window", color: Theme.text },
        { id: "shift-return", keys: ["super", "shift", "enter"], label: "navegador", command: "helium", icon: "compass", color: Theme.cyan },
        { id: "alt-t", keys: ["super", "alt", "t"], label: "terminal flutuante", command: "ghostty · flutuante", icon: "terminal-window", color: Theme.purple },
        { id: "tab", keys: ["super", "tab"], label: "exposé", command: "quickshell · expo", icon: "cards", color: Theme.yellow },
        { id: "grave", keys: ["super", "`"], label: "janelas do app", command: "quickshell · expo app", icon: "copy", color: Theme.yellow },
        { id: "alt-tab", keys: ["alt", "tab"], label: "alternar janelas", command: "quickshell · alttab", icon: "arrows-left-right", color: Theme.textMuted },
        { id: "esc", keys: ["super", "esc"], label: "energia", command: "quickshell · power", icon: "power", color: Theme.red },
        { id: "ctrl-m", keys: ["super", "ctrl", "m"], label: "monitores", command: "quickshell · monitors", icon: "monitor", color: Theme.textMuted },
        { id: "ctrl-l", keys: ["super", "ctrl", "l"], label: "bloquear", command: "hyprlock", icon: "lock", color: Theme.textMuted },
        { id: "q", keys: ["super", "q"], label: "fechar janela", command: "killactive", icon: "x-circle", color: Theme.textMuted },
        { id: "f", keys: ["super", "f"], label: "tela cheia", command: "fullscreen", icon: "arrows-out", color: Theme.textMuted },
        { id: "t", keys: ["super", "t"], label: "flutuar janela", command: "togglefloating", icon: "app-window", color: Theme.textMuted },
        { id: "h", keys: ["super", "h"], label: "esconder flutuantes", command: "quickshell · floats", icon: "eye-slash", color: Theme.textMuted },
        { id: "alt-space", keys: ["super", "alt", "space"], label: "trocar layout do teclado", command: "us ⇄ us internacional", icon: "keyboard", color: Theme.cyan },
        { id: "1-9", keys: ["super", "1…9"], label: "ir para o workspace", command: "workspace", icon: "squares-four", color: Theme.textMuted },
        { id: "slash", keys: ["super", "/"], label: "lista de atalhos", command: "quickshell · hud", icon: "keyboard", color: Theme.textMuted }
    ]
    // Os do design primeiro: a continuação do "segurar super" mostra só esses.
    readonly property var quick: binds.slice(0, 7)

    property var current: binds[0]
    property bool flashing: false
    property bool holding: false
    readonly property bool listing: ShellState.panel === "hud"

    function flash(id: string): void {
        const bind = binds.find(item => item.id === id)
        if (bind) show(bind)
    }

    function show(bind: var): void {
        holdDelay.stop()
        holding = false
        current = bind
        flashing = false
        flashing = true
        expiry.restart()
    }

    Connections {
        target: Keyboard
        function onSwitched() {
            root.show({
                keys: ["super", "alt", "space"],
                label: Keyboard.intl ? "US internacional" : "US",
                command: Keyboard.intl ? "acentos com teclas mortas" : "layout para código",
                icon: "keyboard",
                color: Keyboard.intl ? Theme.cyan : Theme.textMuted
            })
        }
    }

    // Estado dos LEDs (-1 = ainda não lido).
    property int capsLock: -1
    property int numLock: -1

    function lockFlash(key: string, on: bool): void {
        show({
            keys: [key],
            label: on ? "ligado" : "desligado",
            command: key === "caps lock" ? (on ? "maiúsculas" : "minúsculas") : (on ? "teclado numérico" : "setas no teclado numérico"),
            icon: on ? "lock-simple" : "lock-simple-open",
            color: on ? Theme.yellow : Theme.textMuted
        })
    }

    Process {
        id: lockReader
        // O maior valor entre teclados (USB inclusive) para cada LED.
        command: ["sh", "-c", "for k in capslock numlock; do cat /sys/class/leds/input*::$k/brightness 2>/dev/null | sort -n | tail -1; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [caps, num] = text.trim().split("\n").map(value => Number(value) > 0 ? 1 : 0)
                if (root.capsLock >= 0 && caps !== root.capsLock) root.lockFlash("caps lock", caps === 1)
                else if (root.numLock >= 0 && num !== root.numLock) root.lockFlash("num lock", num === 1)
                root.capsLock = caps
                root.numLock = num
            }
        }
    }

    // O LED só muda depois que a tecla é processada.
    Timer { id: lockDelay; interval: 120; onTriggered: lockReader.running = true }
    Component.onCompleted: lockReader.running = true

    IpcHandler {
        target: "hud"

        function flash(id: string): void { root.flash(id) }
        // Caps Lock / Num Lock (binds não consumidores no default.nix).
        function locks(): void { lockDelay.restart() }
        // SUPER sozinho: pressionar arma, soltar cancela.
        function hold(): void { holdDelay.restart() }
        function release(): void {
            holdDelay.stop()
            root.holding = false
        }
    }

    // Super + algo sem HUD (workspace, mover foco…): a continuação some.
    Connections {
        target: Hyprland
        enabled: root.holding || holdDelay.running
        function onRawEvent(event: HyprlandEvent): void {
            if (["workspace", "activewindow", "openwindow", "closewindow", "fullscreen", "changefloatingmode", "movewindow"].includes(event.name)) {
                holdDelay.stop()
                root.holding = false
            }
        }
    }

    Timer { id: expiry; interval: 1200; onTriggered: root.flashing = false }
    Timer { id: holdDelay; interval: 450; onTriggered: { root.holding = true; holdLimit.restart() } }
    // O release nem sempre chega (super+tecla sem bind); some sozinho.
    Timer { id: holdLimit; interval: 4000; onTriggered: root.holding = false }

    component Key: Rectangle {
        property string label
        property int size: 46
        property int fontSize: 16

        implicitWidth: Math.max(size, keyText.implicitWidth + size * 0.6)
        implicitHeight: size
        radius: size * 0.3
        color: Theme.raised
        border.color: Theme.dimmer

        // Borda inferior mais grossa, como uma tecla.
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - parent.radius * 2
            height: 1
            color: Theme.dimmer
        }

        Text {
            id: keyText
            anchors.centerIn: parent
            text: parent.label
            color: Theme.textBright
            font.family: Theme.font
            font.pixelSize: parent.fontSize
        }
    }

    // Atalho reconhecido: teclas, nome e comando, com a barrinha do tempo.
    PanelWindow {
        id: flashWindow

        screen: ShellState.focusedScreen()
        visible: root.flashing || flashCard.opacity > 0
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "fuleco-hud"
        mask: Region {}

        anchors.bottom: true
        margins.bottom: 96
        implicitWidth: flashColumn.implicitWidth + 40
        implicitHeight: flashColumn.implicitHeight + 24

        ColumnLayout {
            id: flashColumn

            anchors.horizontalCenter: parent.horizontalCenter
            y: root.flashing ? 0 : 16
            opacity: root.flashing ? 1 : 0
            spacing: 14

            Behavior on y { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }

            Rectangle {
                id: flashCard

                opacity: parent.opacity
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: flashRow.implicitWidth + 44
                implicitHeight: flashRow.implicitHeight + 32
                radius: 24
                color: Theme.surface
                border.color: Theme.surfaceBorder

                RowLayout {
                    id: flashRow

                    anchors.centerIn: parent
                    spacing: 14

                    Row {
                        spacing: 8
                        Repeater {
                            model: root.current.keys
                            Row {
                                required property string modelData
                                required property int index
                                spacing: 8
                                Text {
                                    visible: parent.index > 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "+"
                                    color: Theme.textGhost
                                    font.family: Theme.font
                                    font.pixelSize: 15
                                }
                                Key { label: parent.modelData }
                            }
                        }
                    }

                    Rectangle { implicitWidth: 1; implicitHeight: 34; color: Theme.divider }

                    ColumnLayout {
                        spacing: 3
                        Text {
                            text: root.current.label
                            color: Theme.textBright
                            font.family: Theme.font
                            font.pixelSize: 15
                        }
                        Text {
                            text: root.current.command
                            color: Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
                    }

                    Icon { name: root.current.icon; size: 20; color: root.current.color }
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 220
                implicitHeight: 3
                radius: 2
                color: Theme.raised
                clip: true

                Rectangle {
                    id: progress
                    height: parent.height
                    radius: 2
                    color: Theme.yellow
                    width: parent.width
                }

                // Esvazia junto com o tempo de exibição.
                NumberAnimation {
                    target: progress
                    property: "width"
                    running: root.flashing
                    from: 220
                    to: 0
                    duration: 1200
                }
            }
        }
    }

    // Continuação ("super seguido de…") e lista completa (SUPER+/).
    PanelWindow {
        id: listWindow

        readonly property bool shown: root.holding || root.listing

        screen: ShellState.focusedScreen()
        visible: shown || listCard.opacity > 0
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "fuleco-hud-list"
        WlrLayershell.keyboardFocus: root.listing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        mask: Region { item: root.listing ? listCard : null }

        anchors.bottom: true
        anchors.right: true
        margins.bottom: 96
        margins.right: 48
        implicitWidth: listCard.width
        implicitHeight: listCard.implicitHeight + 16

        HyprlandFocusGrab {
            active: root.listing && !ShellState.capturing
            windows: [listWindow]
            onCleared: if (root.listing && !ShellState.capturing) ShellState.close()
        }

        Rectangle {
            id: listCard

            y: listWindow.shown ? 0 : 16
            opacity: listWindow.shown ? 1 : 0
            width: root.listing ? 760 : 420
            implicitHeight: listColumn.implicitHeight + 36
            height: implicitHeight
            radius: 24
            color: Theme.surface
            border.color: Theme.surfaceBorder

            Behavior on y { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }

            ColumnLayout {
                id: listColumn

                focus: root.listing
                x: 18
                y: 18
                width: parent.width - 36
                spacing: 12
                Keys.onEscapePressed: ShellState.close()

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Key { label: "super"; size: 30; fontSize: 12 }
                    Text {
                        text: root.listing ? "todos os atalhos" : "seguido de…"
                        color: Theme.textGhost
                        font.family: Theme.font
                        font.pixelSize: 13
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.listing ? "esc fecha" : "solte para cancelar"
                        color: Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: root.listing ? 2 : 1
                    rowSpacing: 6
                    columnSpacing: 6

                    Repeater {
                        model: root.listing ? root.binds : root.quick

                        Rectangle {
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: 14
                            color: Theme.raisedAlt

                            Text {
                                x: 10
                                width: 96
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.modelData.keys.slice(1).join(" + ")
                                color: parent.modelData.color
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                            Text {
                                x: 10 + 96 + 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.modelData.label
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                        }
                    }
                }

                RowLayout {
                    visible: !root.listing
                    spacing: 8
                    Icon { name: "keyboard"; size: 14; color: Theme.textFaint }
                    Text {
                        text: "super + / abre a lista completa"
                        color: Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
