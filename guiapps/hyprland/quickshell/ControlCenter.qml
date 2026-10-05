import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland

// Central de controle: pendura da barra à esquerda, abas rede/som/sistema,
// volume e microfone sempre à mão.
HangingPanel {
    id: panel

    name: "control"
    panelWidth: 420
    marginLeft: 120

    // Linha aberta da lista de redes/bluetooth ("wifi:nome", "bt:endereço").
    property string expanded: ""
    // Campo de senha visível: o painel pega o teclado de vez.
    property bool typing: false
    property string ipAddress: ""
    // O Repeater recria as linhas a cada varredura; o rascunho da senha e o
    // erro ficam aqui para não sumirem no meio da digitação.
    property string draft: ""
    property bool reveal: false
    property string wifiError: ""

    onExpandedChanged: {
        draft = ""
        reveal = false
        wifiError = ""
    }

    wantsKeyboard: typing

    onOpened: {
        expanded = ""
        Net.scan()
        ipReader.running = true
    }
    onShownChanged: if (!shown && Net.adapter?.discovering) Net.adapter.discovering = false

    Connections {
        target: Net
        function onActiveNetworkChanged() { ipReader.running = true }
    }

    Process {
        id: ipReader
        command: ["sh", "-c", "ip -4 -o addr show dev \"$1\" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1", "sh", Net.wifiDevice?.name ?? "wlan0"]
        stdout: StdioCollector { onStreamFinished: panel.ipAddress = text.trim() }
    }

    function failText(reason: int): string {
        switch (reason) {
        case ConnectionFailReason.NoSecrets: return "senha incorreta"
        case ConnectionFailReason.WifiClientDisconnected: return "o roteador recusou a conexão"
        case ConnectionFailReason.WifiAuthTimeout: return "tempo esgotado na autenticação"
        case ConnectionFailReason.WifiNetworkLost: return "rede fora de alcance"
        default: return "não foi possível conectar"
        }
    }

    function securityText(security: int): string {
        switch (security) {
        case WifiSecurityType.Open: return "aberta"
        case WifiSecurityType.Owe: return "aberta · owe"
        case WifiSecurityType.Sae: return "wpa3"
        case WifiSecurityType.Wpa3SuiteB192: return "wpa3 enterprise"
        case WifiSecurityType.Wpa2Psk: return "wpa2"
        case WifiSecurityType.WpaPsk: return "wpa"
        case WifiSecurityType.Wpa2Eap:
        case WifiSecurityType.WpaEap: return "enterprise"
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep: return "wep"
        default: return "protegida"
        }
    }

    function run(command: var): void {
        Quickshell.execDetached(command)
    }

    function terminal(app: string, klass: string): void {
        run(["ghostty", "--class=fuleco." + klass, "-e", app])
        ShellState.close()
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    ColumnLayout {
        width: parent.width
        spacing: 16

        // Cabeçalho
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "central de controle"
                color: Theme.textBright
                font.family: Theme.font
                font.pixelSize: 15
            }

            Item { Layout.fillWidth: true }

            Text {
                text: Qt.formatTime(clock.date, "HH:mm") + " · " + Theme.date(clock.date, "ddd dd MMM")
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: 11
            }

            Icon {
                name: "gear-six"
                size: 16
                color: gearHover.hovered ? Theme.text : Theme.textMuted
                HoverHandler { id: gearHover; cursorShape: Qt.PointingHandCursor }
                // Configurações = o próprio repositório nix-config, no Zed.
                TapHandler {
                    onTapped: {
                        ShellState.close()
                        Quickshell.execDetached(["zeditor", Quickshell.env("HOME") + "/Documents/Dev/nix-config"])
                    }
                }
            }
        }

        // Abas
        Row {
            spacing: 6
            Repeater {
                model: ["rede", "som", "sistema"]
                Chip {
                    required property string modelData
                    label: modelData
                    active: ShellState.controlTab === modelData
                    onClicked: ShellState.controlTab = modelData
                }
            }
        }

        // ── rede ─────────────────────────────────────────────────────────
        ColumnLayout {
            visible: ShellState.controlTab === "rede"
            Layout.fillWidth: true
            spacing: 16

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10

                ToggleCard {
                    icon: Net.wifiEnabled ? Net.icon : "wifi-slash"
                    label: "wi-fi"
                    detail: !Net.wifiEnabled ? "desligado"
                        : Net.activeNetwork ? Net.activeNetwork.name + " · " + Math.round(Net.strength(Net.activeNetwork) * 100) + "%"
                        : Net.wiredDevice ? "cabo conectado" : "sem rede"
                    checked: Net.wifiEnabled
                    onToggled: checked => Net.setWifi(checked)
                }

                ToggleCard {
                    icon: Net.bluetoothConnected.length > 0 ? "bluetooth-connected" : Net.bluetoothEnabled ? "bluetooth" : "bluetooth-slash"
                    label: "bluetooth"
                    detail: !Net.bluetoothEnabled ? "desligado"
                        : Net.bluetoothConnected.length === 1 ? "1 conectado"
                        : Net.bluetoothConnected.length + " conectados"
                    checked: Net.bluetoothEnabled
                    onToggled: checked => Net.setBluetooth(checked)
                }
            }

            ColumnLayout {
                visible: Net.wifiEnabled
                Layout.fillWidth: true
                spacing: 8

                SectionTitle {
                    label: "redes wi-fi · " + Net.wifiNetworks.length
                    action: "mais configurações ↗"
                    onActivated: panel.terminal("wifitui", "wifitui")
                }

                ScrollList {
                    maxHeight: 260

                    Repeater {
                        model: Net.wifiNetworks
                        WifiRow {}
                    }
                }

                Text {
                    visible: Net.wifiNetworks.length === 0
                    text: "procurando redes…"
                    color: Theme.textGhost
                    font.family: Theme.font
                    font.pixelSize: 11
                    Layout.leftMargin: 12
                }
            }

            ColumnLayout {
                visible: Net.bluetoothEnabled
                Layout.fillWidth: true
                spacing: 8

                SectionTitle {
                    label: "bluetooth"
                    action: Net.adapter?.discovering ? "parar busca" : "procurar"
                    onActivated: if (Net.adapter) Net.adapter.discovering = !Net.adapter.discovering
                }

                ScrollList {
                    maxHeight: 180

                    Repeater {
                        model: Net.adapter?.discovering ? [...Net.bluetoothDevices, ...Net.bluetoothNearby] : Net.bluetoothDevices
                        BluetoothRow {}
                    }
                }

                Text {
                    visible: Net.bluetoothDevices.length === 0 && !(Net.adapter?.discovering && Net.bluetoothNearby.length > 0)
                    text: Net.adapter?.discovering ? "procurando dispositivos…" : "nenhum dispositivo pareado · procurar para parear"
                    color: Theme.textGhost
                    font.family: Theme.font
                    font.pixelSize: 11
                    Layout.leftMargin: 12
                }
            }

            Text {
                visible: !Net.wifiEnabled && !Net.bluetoothEnabled
                text: "rádios desligados"
                color: Theme.textGhost
                font.family: Theme.font
                font.pixelSize: 11
                Layout.leftMargin: 12
            }
        }

        // ── som ──────────────────────────────────────────────────────────
        ColumnLayout {
            visible: ShellState.controlTab === "som"
            Layout.fillWidth: true
            spacing: 8

            onVisibleChanged: if (visible) Audio.refreshRoutes()

            SectionTitle {
                label: "saída"
                action: "wiremix ↗"
                onActivated: panel.terminal("wiremix", "wiremix")
            }

            Repeater {
                model: Audio.sinks

                ListRow {
                    required property var modelData
                    icon: (modelData.properties?.["device.form-factor"] ?? "").includes("head") ? "headphones" : "speaker-high"
                    label: Audio.deviceName(modelData)
                    connected: Pipewire.defaultAudioSink === modelData
                    trailing: connected ? "padrão" : ""
                    onActivated: Pipewire.preferredDefaultAudioSink = modelData
                }
            }

            SectionTitle { label: "entrada"; Layout.topMargin: 6 }

            Repeater {
                model: Audio.sources

                ListRow {
                    required property var modelData
                    icon: "microphone"
                    label: Audio.deviceName(modelData)
                    connected: Pipewire.defaultAudioSource === modelData
                    trailing: connected ? "padrão" : ""
                    onActivated: Pipewire.preferredDefaultAudioSource = modelData
                }
            }
        }

        // ── sistema ──────────────────────────────────────────────────────
        ColumnLayout {
            visible: ShellState.controlTab === "sistema"
            Layout.fillWidth: true
            spacing: 12

            SectionTitle { label: "perfil de energia" }

            Row {
                spacing: 6
                Repeater {
                    model: [
                        { label: "economia", profile: PowerProfile.PowerSaver },
                        { label: "equilíbrio", profile: PowerProfile.Balanced },
                        { label: "desempenho", profile: PowerProfile.Performance }
                    ]
                    Chip {
                        required property var modelData
                        label: modelData.label
                        fontSize: 11
                        active: PowerProfiles.profile === modelData.profile
                        onClicked: PowerProfiles.profile = modelData.profile
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 10

                ToggleCard {
                    icon: "coffee"
                    label: "cafeína"
                    detail: !ShellState.caffeine ? "suspensão normal"
                        : ShellState.caffeineUntil > 0 ? "acesa até " + Qt.formatTime(new Date(ShellState.caffeineUntil), "HH:mm")
                        : "sempre acesa"
                    checked: ShellState.caffeine
                    accent: Theme.orange
                    onToggled: checked => checked ? ShellState.setCaffeine(0) : ShellState.caffeine = false
                }

                ToggleCard {
                    icon: NotifService.dnd ? "bell-slash" : "bell-simple"
                    label: "não perturbe"
                    detail: NotifService.dnd ? "popups silenciados" : "popups ativos"
                    checked: NotifService.dnd
                    accent: Theme.purple
                    onToggled: checked => NotifService.dnd = checked
                }
            }

            // Prazo da cafeína: liga já com o tempo escolhido.
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Icon { name: "timer"; size: 15; color: ShellState.caffeine ? Theme.orange : Theme.textFaint }
                Text {
                    text: "cafeína por"
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: 11
                }
                Item { Layout.fillWidth: true }
                Repeater {
                    model: [
                        { label: "30 min", minutes: 30 },
                        { label: "1 h", minutes: 60 },
                        { label: "2 h", minutes: 120 },
                        { label: "∞", minutes: 0 }
                    ]
                    Chip {
                        required property var modelData
                        label: modelData.label
                        fontSize: 11
                        active: ShellState.caffeine && ShellState.caffeineMinutes === modelData.minutes
                        onClicked: active ? ShellState.caffeine = false : ShellState.setCaffeine(modelData.minutes)
                    }
                }
            }

            RowLayout {
                visible: Brightness.available
                Layout.fillWidth: true
                spacing: 10

                Icon { name: "sun-dim"; size: 18; color: Theme.text }
                Meter {
                    Layout.fillWidth: true
                    value: Brightness.value
                    accent: Theme.cyan
                    onMoved: value => Brightness.set(value)
                }
                Percent { value: Brightness.value }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        { icon: "monitor", label: "monitores", action: () => { ShellState.close(); Quickshell.execDetached(["quickshell", "-c", "fuleco", "ipc", "call", "monitors", "toggle"]) } },
                        { icon: "chart-line", label: "btop", action: () => panel.terminal("btop", "btop") },
                        { icon: "calendar-dots", label: "calcure", action: () => panel.terminal("calcure", "calcure") }
                    ]

                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: 14
                        color: shortcutHover.hovered ? Theme.track : Theme.raised

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Icon { name: parent.parent.modelData.icon; size: 15; color: Theme.textMuted }
                            Text {
                                text: parent.parent.modelData.label
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 11
                            }
                        }

                        HoverHandler { id: shortcutHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: parent.modelData.action() }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.raised }

        // Volume e microfone
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Icon {
                    name: Audio.muted ? "speaker-slash" : Audio.volume > 0.5 ? "speaker-high" : Audio.volume > 0 ? "speaker-low" : "speaker-none"
                    size: 18
                    color: Audio.muted ? Theme.textGhost : Theme.text
                    TapHandler { onTapped: Audio.toggleMute() }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
                Meter {
                    Layout.fillWidth: true
                    value: Audio.volume
                    accent: Audio.muted ? Theme.dim : Theme.yellow
                    onMoved: value => Audio.setVolume(value)
                }
                Percent { value: Audio.volume }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Icon {
                    name: Audio.micMuted ? "microphone-slash" : "microphone"
                    size: 18
                    color: Audio.micMuted ? Theme.textGhost : Theme.textMuted
                    TapHandler { onTapped: Audio.toggleMicMute() }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
                Meter {
                    Layout.fillWidth: true
                    value: Audio.micVolume
                    accent: Audio.micMuted ? Theme.dim : Theme.cyan
                    onMoved: value => Audio.setMicVolume(value)
                }
                Percent { value: Audio.micVolume }
            }

            // Volume por aplicativo
            Rectangle {
                visible: Audio.streams.length > 0
                Layout.fillWidth: true
                implicitHeight: perApp.implicitHeight + 24
                radius: 16
                color: Theme.raisedAlt

                ColumnLayout {
                    id: perApp
                    x: 12
                    y: 12
                    width: parent.width - 24
                    spacing: 10

                    Text {
                        text: "por aplicativo"
                        color: Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: 11
                    }

                    Repeater {
                        model: Audio.streams

                        RowLayout {
                            id: streamRow
                            required property var modelData
                            required property int index
                            readonly property color accent: [Theme.cyan, Theme.purple, Theme.green, Theme.orange][index % 4]
                            readonly property string appName: Audio.streamName(modelData).toLowerCase()

                            Layout.fillWidth: true
                            spacing: 10

                            Icon {
                                name: streamRow.appName.includes("mpv") || streamRow.appName.includes("spotify") ? "music-notes"
                                    : streamRow.appName.includes("helium") || streamRow.appName.includes("chrom") || streamRow.appName.includes("firefox") ? "compass"
                                    : streamRow.appName.includes("discord") ? "chat-circle"
                                    : "waveform"
                                size: 15
                                color: streamRow.accent
                            }
                            Text {
                                Layout.preferredWidth: 52
                                text: streamRow.appName
                                elide: Text.ElideRight
                                color: Theme.textMuted
                                font.family: Theme.font
                                font.pixelSize: 11
                            }
                            Meter {
                                Layout.fillWidth: true
                                thickness: 6
                                track: Theme.track
                                accent: streamRow.accent
                                value: streamRow.modelData.audio?.volume ?? 0
                                onMoved: value => { if (streamRow.modelData.audio) streamRow.modelData.audio.volume = value }
                            }
                        }
                    }
                }
            }
        }

        Row {
            spacing: 8
            Icon { name: "lightning"; size: 13; color: Theme.green }
            Text {
                text: Net.hasBattery ? "energia e bateria agora vivem na gaveta de widgets" : "mais controles na gaveta de widgets"
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: 11
                TapHandler { onTapped: ShellState.open("drawer") }
            }
        }
    }

    // Peças locais

    // Lista com rolagem que cresce até maxHeight.
    component ScrollList: Flickable {
        id: list
        property int maxHeight: 260
        default property alias rows: listColumn.data

        Layout.fillWidth: true
        implicitHeight: Math.min(listColumn.implicitHeight, maxHeight)
        contentHeight: listColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        ColumnLayout {
            id: listColumn
            width: list.width - (list.interactive ? 8 : 0)
            spacing: 4
        }

        // Barrinha de rolagem fina.
        Rectangle {
            visible: list.interactive
            x: list.width - 4
            y: list.visibleArea.yPosition * list.height
            width: 3
            height: list.visibleArea.heightRatio * list.height
            radius: 2
            color: Theme.dim
        }
    }

    component ActionButton: Rectangle {
        id: action
        property string label
        property color accent: Theme.text
        property bool primary: false
        signal clicked

        implicitWidth: actionText.implicitWidth + 24
        implicitHeight: 28
        radius: 12
        color: primary ? (actionHover.hovered ? Qt.lighter(accent, 1.1) : accent) : actionHover.hovered ? Theme.track : Theme.raisedAlt

        Text {
            id: actionText
            anchors.centerIn: parent
            text: action.label
            color: action.primary ? Theme.onAccent : action.accent
            font.family: Theme.font
            font.pixelSize: 11
        }

        HoverHandler { id: actionHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: action.clicked() }
    }

    // Cabeçalho clicável de uma linha expansível.
    component RowHeader: Item {
        id: header
        property string icon
        property color iconColor: Theme.textMuted
        property string label
        property bool secure: false
        property bool strong: false
        property string trailing
        property color trailingColor: Theme.textFaint
        property bool open: false
        signal activated

        Layout.fillWidth: true
        implicitHeight: 36

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Icon { name: header.icon; size: 16; color: header.iconColor }
            Text {
                text: header.label
                elide: Text.ElideRight
                Layout.maximumWidth: 200
                color: header.strong ? Theme.text : Theme.textMuted
                font.family: Theme.font
                font.pixelSize: 12
            }
            Icon {
                visible: header.secure
                name: "lock-simple"
                size: 12
                color: Theme.textGhost
            }
            Item { Layout.fillWidth: true }
            Text {
                text: header.trailing
                color: header.trailingColor
                font.family: Theme.font
                font.pixelSize: 11
            }
            Icon {
                name: header.open ? "caret-up" : "caret-down"
                size: 12
                color: Theme.textGhost
            }
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: header.activated() }
    }

    component WifiRow: Rectangle {
        id: wrow
        required property var modelData
        readonly property var network: modelData
        readonly property string key: "wifi:" + network.name
        readonly property bool open: panel.expanded === key
        readonly property bool secure: network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe
        readonly property bool needsPassword: secure && !network.known && !network.connected

        Layout.fillWidth: true
        implicitHeight: wcol.implicitHeight
        radius: 14
        color: open || network.connected ? Theme.raised : wHover.hovered ? Theme.raisedAlt : "transparent"

        HoverHandler { id: wHover }

        Binding {
            target: panel
            property: "typing"
            value: true
            when: wrow.open && wrow.needsPassword
        }

        Connections {
            target: wrow.network
            function onConnectionFailed(reason) {
                if (wrow.open) panel.wifiError = panel.failText(reason)
            }
            function onConnectedChanged() {
                if (wrow.network.connected && wrow.open) panel.expanded = ""
            }
        }

        function connect(): void {
            panel.wifiError = ""
            if (needsPassword) {
                if (panel.draft.length < 8) {
                    panel.wifiError = "a senha precisa de ao menos 8 caracteres"
                    return
                }
                network.connectWithPsk(panel.draft)
            } else {
                network.connect()
            }
        }

        ColumnLayout {
            id: wcol
            width: parent.width
            spacing: 0

            RowHeader {
                icon: Net.wifiIcon(wrow.network)
                iconColor: wrow.network.connected ? Theme.green : Theme.textMuted
                label: wrow.network.name
                secure: wrow.secure
                strong: wrow.open || wrow.network.connected
                open: wrow.open
                trailing: wrow.network.stateChanging ? (wrow.network.state === ConnectionState.Disconnecting ? "desconectando…" : "conectando…")
                    : wrow.network.connected ? "conectado" : wrow.network.known ? "salva" : ""
                trailingColor: wrow.network.connected ? Theme.green : wrow.network.stateChanging ? Theme.yellow : Theme.textFaint
                onActivated: {
                    panel.expanded = wrow.open ? "" : wrow.key
                    if (wrow.open && wrow.needsPassword) password.forceActiveFocus()
                }
            }

            ColumnLayout {
                visible: wrow.open
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Layout.bottomMargin: 12
                spacing: 10

                Text {
                    text: [
                        "sinal " + Math.round(Net.strength(wrow.network) * 100) + "%",
                        panel.securityText(wrow.network.security),
                        wrow.network.connected && panel.ipAddress !== "" ? panel.ipAddress : ""
                    ].filter(part => part !== "").join(" · ")
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                Rectangle {
                    visible: wrow.needsPassword
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: 12
                    color: Theme.sunken
                    border.color: password.activeFocus ? Theme.yellow : Theme.surfaceBorder

                    TextInput {
                        id: password
                        anchors.left: parent.left
                        anchors.right: eye.left
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.draft
                        echoMode: panel.reveal ? TextInput.Normal : TextInput.Password
                        color: Theme.textBright
                        selectionColor: Theme.yellow
                        selectedTextColor: Theme.onAccent
                        font.family: Theme.font
                        font.pixelSize: 12
                        clip: true
                        onTextChanged: panel.draft = text
                        onAccepted: wrow.connect()
                        Component.onCompleted: if (wrow.open && wrow.needsPassword) forceActiveFocus()

                        Text {
                            visible: password.text === ""
                            text: "senha da rede"
                            color: Theme.textGhost
                            font: password.font
                        }
                    }

                    Icon {
                        id: eye
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        name: panel.reveal ? "eye-slash" : "eye"
                        size: 15
                        color: Theme.textFaint
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: panel.reveal = !panel.reveal }
                    }
                }

                Text {
                    visible: wrow.open && panel.wifiError !== ""
                    Layout.fillWidth: true
                    text: panel.wifiError
                    wrapMode: Text.Wrap
                    color: Theme.red
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                Row {
                    spacing: 6

                    ActionButton {
                        visible: !wrow.network.connected
                        label: wrow.network.stateChanging ? "conectando…" : "conectar"
                        primary: true
                        accent: Theme.yellow
                        onClicked: if (!wrow.network.stateChanging) wrow.connect()
                    }
                    ActionButton {
                        visible: wrow.network.connected
                        label: "desconectar"
                        onClicked: wrow.network.disconnect()
                    }
                    ActionButton {
                        visible: wrow.network.known
                        label: "esquecer"
                        accent: Theme.red
                        onClicked: {
                            wrow.network.forget()
                            panel.expanded = ""
                        }
                    }
                }
            }
        }
    }

    component BluetoothRow: Rectangle {
        id: brow
        required property var modelData
        readonly property var device: modelData
        readonly property string key: "bt:" + device.address
        readonly property bool open: panel.expanded === key

        Layout.fillWidth: true
        implicitHeight: bcol.implicitHeight
        radius: 14
        color: open || device.connected ? Theme.raised : bHover.hovered ? Theme.raisedAlt : "transparent"

        HoverHandler { id: bHover }

        ColumnLayout {
            id: bcol
            width: parent.width
            spacing: 0

            RowHeader {
                icon: brow.device.connected ? "bluetooth-connected" : "bluetooth"
                iconColor: brow.device.connected ? Theme.cyan : Theme.textMuted
                label: brow.device.name || brow.device.deviceName || brow.device.address
                strong: brow.open || brow.device.connected
                open: brow.open
                trailing: brow.device.pairing ? "pareando…"
                    : brow.device.batteryAvailable ? Math.round(brow.device.battery * 100) + "%"
                    : brow.device.connected ? "conectado" : brow.device.paired ? "pareado" : "novo"
                trailingColor: brow.device.connected ? Theme.cyan : brow.device.pairing ? Theme.yellow : Theme.textFaint
                onActivated: panel.expanded = brow.open ? "" : brow.key
            }

            ColumnLayout {
                visible: brow.open
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Layout.bottomMargin: 12
                spacing: 10

                Text {
                    text: [brow.device.address, brow.device.trusted ? "confiável" : "", brow.device.batteryAvailable ? "bateria " + Math.round(brow.device.battery * 100) + "%" : ""]
                        .filter(part => part !== "").join(" · ")
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                Row {
                    spacing: 6

                    ActionButton {
                        visible: !brow.device.paired
                        label: brow.device.pairing ? "cancelar" : "parear"
                        primary: !brow.device.pairing
                        accent: Theme.cyan
                        onClicked: brow.device.pairing ? brow.device.cancelPair() : brow.device.pair()
                    }
                    ActionButton {
                        visible: brow.device.paired && !brow.device.connected
                        label: "conectar"
                        primary: true
                        accent: Theme.cyan
                        onClicked: brow.device.connect()
                    }
                    ActionButton {
                        visible: brow.device.connected
                        label: "desconectar"
                        onClicked: brow.device.disconnect()
                    }
                    ActionButton {
                        visible: brow.device.paired
                        label: "esquecer"
                        accent: Theme.red
                        onClicked: {
                            brow.device.forget()
                            panel.expanded = ""
                        }
                    }
                }
            }
        }
    }

    component Percent: Text {
        property real value
        Layout.preferredWidth: 30
        horizontalAlignment: Text.AlignRight
        text: Math.round(value * 100) + "%"
        color: Theme.textMuted
        font.family: Theme.font
        font.pixelSize: 11
    }

    component SectionTitle: RowLayout {
        id: section
        property string label
        property string action: ""
        signal activated
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: section.label
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: 11
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.raised }
        Text {
            visible: section.action !== ""
            text: section.action
            color: Theme.yellow
            font.family: Theme.font
            font.pixelSize: 11
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: section.activated() }
        }
    }

    component ToggleCard: Rectangle {
        id: tcard
        property string icon
        property string label
        property string detail
        property bool checked
        property color accent: Theme.cyan
        signal toggled(bool checked)

        Layout.fillWidth: true
        implicitHeight: tcol.implicitHeight + 28
        radius: 18
        color: Theme.raised

        ColumnLayout {
            id: tcol
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Icon { name: tcard.icon; size: 18; color: tcard.checked ? tcard.accent : Theme.textFaint }
                Text {
                    Layout.fillWidth: true
                    text: tcard.label
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 12
                }
                Toggle {
                    checked: tcard.checked
                    accent: tcard.accent
                    onToggled: checked => tcard.toggled(checked)
                }
            }

            Text {
                Layout.fillWidth: true
                text: tcard.detail
                elide: Text.ElideRight
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: 12
            }
        }
    }

    component ListRow: Rectangle {
        id: row
        property string icon
        property string label
        property bool secure: false
        property bool connected: false
        property bool highlighted: connected
        property string trailing: ""
        signal activated

        Layout.fillWidth: true
        implicitHeight: 36
        radius: 14
        color: highlighted ? Theme.raised : rowHover.hovered ? Theme.raisedAlt : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Icon { name: row.icon; size: 16; color: row.connected ? Theme.green : Theme.textMuted }
            Text {
                text: row.label
                elide: Text.ElideRight
                Layout.maximumWidth: 220
                color: row.highlighted ? Theme.text : Theme.textMuted
                font.family: Theme.font
                font.pixelSize: 12
            }
            Icon {
                visible: row.secure
                name: "lock-simple"
                size: 13
                color: row.highlighted ? Theme.textFaint : Theme.textGhost
            }
            Item { Layout.fillWidth: true }
            Text {
                text: row.trailing
                color: row.connected ? Theme.green : Theme.textFaint
                font.family: Theme.font
                font.pixelSize: 11
            }
        }

        HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: row.activated() }
    }
}
