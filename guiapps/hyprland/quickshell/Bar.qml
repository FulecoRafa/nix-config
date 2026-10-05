import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Barra flutuante do topo: logo, workspaces, apps, uso de IA, CPU,
// status, calendário e relógio. Os painéis "pendurados" nascem dela.
Scope {
    id: root

    readonly property int workspaceCount: Number(Quickshell.env("HYPRLAND_WORKSPACE_COUNT") || "6")

    // Apps fixos. `match` casa com o app-id das janelas abertas.
    readonly property var pinned: [
        { icon: "compass", color: Theme.cyan, match: /helium|chrom|firefox|zen/i, command: ["helium"] },
        { icon: "terminal-window", color: Theme.green, match: /ghostty|kitty|foot|alacritty/i, command: ["ghostty"] },
        { icon: "folder", color: Theme.yellow, match: /yazi|nautilus|thunar|dolphin/i, command: ["ghostty", "--class=fuleco.yazi", "-e", "yazi"] },
        { icon: "magnifying-glass", color: Theme.yellow, panel: "launcher" },
        { icon: "squares-four", color: Theme.purple, panel: "drawer" }
    ]

    // Fixados pelo lançador (ctrl+p): "tui:nome" ou o id do .desktop.
    readonly property var tuiIcons: ({ wifitui: "wifi-high", btop: "gauge", yazi: "folder", calcure: "calendar-dots", wiremix: "faders", bluetui: "bluetooth" })
    readonly property var userPins: {
        const result = []
        for (const id of Store.data.pinned ?? []) {
            if (id.startsWith("tui:")) {
                const name = id.slice(4)
                result.push({ icon: tuiIcons[name] ?? "terminal-window", color: Theme.green, match: new RegExp("^fuleco\\." + name + "$"), command: ["ghostty", "--class=fuleco." + name, "-e", name] })
                continue
            }
            const entry = DesktopEntries.byId(id)
            if (!entry) continue
            const base = id.replace(/\.desktop$/, "").replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
            result.push({ iconSource: Quickshell.iconPath(entry.icon, "application-x-executable"), color: Theme.cyan, match: new RegExp("^" + base + "$", "i"), entry: entry })
        }
        return result
    }
    readonly property var allPinned: [...pinned.slice(0, 3), ...userPins, ...pinned.slice(3)]

    readonly property var toplevels: ToplevelManager.toplevels.values

    function windowsFor(app: var): var {
        if (!app.match) return []
        return toplevels.filter(toplevel => app.match.test(toplevel.appId))
    }

    function activatePinned(app: var): void {
        if (app.panel) {
            ShellState.toggle(app.panel)
            return
        }
        const windows = windowsFor(app)
        if (windows.length === 0) {
            if (app.entry) app.entry.execute()
            else Quickshell.execDetached(app.command)
            return
        }
        // Clique repetido alterna entre as janelas do mesmo app.
        const current = windows.findIndex(toplevel => toplevel.activated)
        windows[(current + 1) % windows.length].activate()
    }

    // Janelas abertas que não pertencem a nenhum app fixo.
    readonly property var extraApps: {
        const seen = {}
        const result = []
        for (const toplevel of toplevels) {
            const id = toplevel.appId
            if (!id || seen[id]) continue
            if (allPinned.some(app => app.match && app.match.test(id))) continue
            seen[id] = true
            result.push(id)
        }
        return result
    }

    component Divider: Rectangle {
        implicitWidth: 1
        implicitHeight: 22
        color: Theme.divider
    }

    component AppTile: Item {
        id: tile

        property string icon
        property string iconSource
        property color accent: Theme.cyan
        property bool active: false
        property bool running: false
        signal clicked

        implicitWidth: 34
        implicitHeight: 34

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: tile.active ? Theme.surfaceBorder : hover.hovered ? "#2A303C" : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.fast } }
        }

        Icon {
            anchors.centerIn: parent
            visible: tile.iconSource === ""
            name: tile.icon
            size: 18
            color: tile.active ? tile.accent : Theme.textMuted
            Behavior on color { ColorAnimation { duration: Theme.fast } }
        }

        Image {
            anchors.centerIn: parent
            visible: tile.iconSource !== ""
            width: 18
            height: 18
            sourceSize: Qt.size(36, 36)
            source: tile.iconSource
            opacity: tile.active ? 1 : 0.75
        }

        Rectangle {
            visible: tile.running
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            width: 4
            height: 4
            radius: 3
            color: tile.active ? tile.accent : Theme.dim
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: tile.clicked() }
    }

    component StatusIcon: Item {
        id: status

        property string icon
        property color tint: Theme.textMuted
        signal clicked

        implicitWidth: 17
        implicitHeight: 22

        Icon {
            anchors.centerIn: parent
            name: status.icon
            size: 17
            color: status.tint
            opacity: hover.hovered ? 0.8 : 1
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: status.clicked() }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar

            required property var modelData

            IdleInhibitor {
                window: bar
                enabled: ShellState.caffeine
            }
            readonly property bool isPanelScreen: ShellState.screen === modelData

            screen: modelData
            color: "transparent"
            implicitHeight: Theme.barBottom
            WlrLayershell.namespace: "fuleco-bar"

            Component.onCompleted: ShellState.barWindows = [...ShellState.barWindows, bar]
            Component.onDestruction: ShellState.barWindows = ShellState.barWindows.filter(w => w !== bar)

            anchors {
                top: true
                left: true
                right: true
            }

            Rectangle {
                id: shape

                x: Theme.gap
                y: Theme.barMargin
                width: parent.width - 2 * Theme.gap
                height: Theme.barHeight
                radius: Theme.barRadius
                color: Theme.surface
                border.color: Theme.surfaceBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 14
                    spacing: 14

                    // Logo (floco do NixOS): abre a central de controle.
                    Item {
                        implicitWidth: 28
                        implicitHeight: 28
                        scale: logoHover.hovered ? 1.08 : 1
                        rotation: logoHover.hovered ? 30 : 0
                        Behavior on scale { NumberAnimation { duration: Theme.fast } }
                        Behavior on rotation { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }

                        Image {
                            anchors.fill: parent
                            source: "nix-snowflake.svg"
                            sourceSize: Qt.size(56, 56)
                            smooth: true
                        }

                        HoverHandler { id: logoHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: ShellState.toggle("control") }
                    }

                    // Workspaces: pílula longa amarela na ativa, cianas nas
                    // ocupadas, pontos nas vazias.
                    Row {
                        spacing: 7

                        Repeater {
                            model: root.workspaceCount

                            Rectangle {
                                id: pill

                                required property int index
                                readonly property int workspaceId: index + 1
                                readonly property var workspace: Hyprland.workspaces.values.find(w => w.id === workspaceId) ?? null
                                readonly property bool focused: bar.modelData.name === Hyprland.focusedMonitor?.name
                                    ? Hyprland.focusedWorkspace?.id === workspaceId
                                    : workspace?.monitor?.name === bar.modelData.name && workspace?.active === true
                                readonly property bool occupied: (workspace?.toplevels?.values?.length ?? 0) > 0

                                anchors.verticalCenter: parent.verticalCenter
                                width: focused ? 24 : occupied ? 12 : 6
                                height: 6
                                radius: 4
                                color: focused ? Theme.yellow : occupied ? Theme.cyan : Theme.dimmer

                                Behavior on width { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }
                                Behavior on color { ColorAnimation { duration: Theme.normal } }

                                TapHandler {
                                    margin: 6
                                    onTapped: Hyprland.dispatch("workspace " + pill.workspaceId)
                                }
                                HoverHandler { margin: 6; cursorShape: Qt.PointingHandCursor }
                            }
                        }

                        WheelHandler {
                            onWheel: event => Hyprland.dispatch(event.angleDelta.y > 0 ? "workspace r-1" : "workspace r+1")
                        }
                    }

                    Divider {}

                    Row {
                        spacing: 6

                        Repeater {
                            model: root.allPinned

                            AppTile {
                                required property var modelData
                                readonly property var windows: root.windowsFor(modelData)

                                icon: modelData.icon ?? ""
                                iconSource: modelData.iconSource ?? ""
                                accent: modelData.color
                                running: windows.length > 0
                                active: modelData.panel
                                    ? ShellState.panel === modelData.panel
                                    : windows.some(toplevel => toplevel.activated)
                                onClicked: root.activatePinned(modelData)
                            }
                        }

                        Repeater {
                            model: root.extraApps

                            AppTile {
                                required property string modelData
                                readonly property var windows: root.toplevels.filter(t => t.appId === modelData)
                                readonly property var entry: DesktopEntries.heuristicLookup(modelData)

                                iconSource: Quickshell.iconPath(entry?.icon ?? modelData, "application-x-executable")
                                running: true
                                active: windows.some(toplevel => toplevel.activated)
                                onClicked: {
                                    const current = windows.findIndex(toplevel => toplevel.activated)
                                    windows[(current + 1) % windows.length].activate()
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Chip de IA: cc = sessão do Claude, cx = Codex.
                    Rectangle {
                        id: aiChip

                        readonly property real claude: AiUsage.percent(AiUsage.claudeSession)
                        readonly property real codex: AiUsage.percent(AiUsage.codexPrimary)
                        readonly property bool hot: Math.max(claude, codex) >= 90

                        implicitWidth: aiRow.implicitWidth + 20
                        implicitHeight: 26
                        radius: 13
                        color: ShellState.panel === "ai" ? Theme.surfaceBorder : Theme.raisedAlt
                        border.color: hot ? Theme.red : Theme.raisedAlt

                        SequentialAnimation on opacity {
                            running: aiChip.hot
                            loops: Animation.Infinite
                            alwaysRunToEnd: true
                            NumberAnimation { to: 0.55; duration: 700; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                        }

                        Row {
                            id: aiRow

                            anchors.centerIn: parent
                            spacing: 10

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "gauge"
                                size: 14
                                color: Theme.orange
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                textFormat: Text.StyledText
                                text: "cc <font color='" + (aiChip.claude < 0 ? Theme.textFaint : Theme.usageColor(aiChip.claude)) + "'>"
                                    + AiUsage.percentText(AiUsage.claudeSession) + "</font>"
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 12
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1
                                height: 13
                                color: Theme.dimmer
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                textFormat: Text.StyledText
                                text: "cx <font color='" + (aiChip.codex < 0 ? Theme.textFaint : Theme.usageColor(aiChip.codex)) + "'>"
                                    + AiUsage.percentText(AiUsage.codexPrimary) + "</font>"
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 12
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: text !== ""
                                text: AiUsage.remainingText(AiUsage.claudeSession) || AiUsage.remainingText(AiUsage.codexPrimary)
                                color: Theme.textFaint
                                font.family: Theme.font
                                font.pixelSize: 11
                            }
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                AiUsage.refresh()
                                ShellState.toggle("ai")
                            }
                        }
                    }

                    // Medidor circular de CPU.
                    Item {
                        implicitWidth: 32
                        implicitHeight: 32

                        Canvas {
                            id: gauge

                            property real value: SysInfo.cpu
                            anchors.fill: parent
                            onValueChanged: requestPaint()

                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.reset()
                                ctx.lineWidth = 3.5
                                ctx.lineCap = "round"
                                ctx.strokeStyle = Theme.surfaceBorder
                                ctx.beginPath()
                                ctx.arc(16, 16, 13, 0, 2 * Math.PI)
                                ctx.stroke()
                                if (value > 0) {
                                    ctx.strokeStyle = value >= 85 ? Theme.red : value >= 60 ? Theme.orange : Theme.cyan
                                    ctx.beginPath()
                                    ctx.arc(16, 16, 13, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.min(value, 100) / 100)
                                    ctx.stroke()
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Math.round(SysInfo.cpu)
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 10
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Quickshell.execDetached(["ghostty", "-e", "btop"]) }
                    }

                    // Bandeja dos apps (Discord etc.); some quando vazia.
                    Tray { id: tray; window: bar }
                    Divider { visible: tray.visible }

                    Row {
                        spacing: 14

                        StatusIcon {
                            icon: Net.icon
                            tint: Net.online ? Theme.cyan : Theme.textMuted
                            onClicked: ShellState.openControl("rede")
                        }

                        StatusIcon {
                            visible: Net.adapter !== null
                            icon: Net.bluetoothConnected.length > 0 ? "bluetooth-connected" : Net.bluetoothEnabled ? "bluetooth" : "bluetooth-slash"
                            tint: Net.bluetoothConnected.length > 0 ? Theme.cyan : Theme.textMuted
                            onClicked: ShellState.openControl("rede")
                        }

                        StatusIcon {
                            icon: Audio.muted ? "speaker-x" : Audio.volume > 0.66 ? "speaker-high" : Audio.volume > 0 ? "speaker-low" : "speaker-none"
                            onClicked: ShellState.openControl("som")

                            WheelHandler {
                                onWheel: event => Audio.setVolume(Audio.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05))
                            }
                        }

                        StatusIcon {
                            icon: NotifService.dnd ? "bell-slash" : "bell"
                            tint: ShellState.panel === "notifications" ? Theme.yellow : Theme.textMuted
                            onClicked: ShellState.toggle("notifications")

                            Rectangle {
                                visible: NotifService.count > 0
                                x: parent.width - 9
                                y: -1
                                width: Math.max(14, badgeText.implicitWidth + 6)
                                height: 14
                                radius: 8
                                color: Theme.red

                                Text {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: NotifService.count > 9 ? "9+" : NotifService.count
                                    color: Theme.onAccent
                                    font.family: Theme.font
                                    font.pixelSize: 9
                                }
                            }
                        }

                        StatusIcon {
                            visible: Net.hasBattery
                            icon: Net.batteryIcon
                            tint: Net.batteryColor
                            onClicked: ShellState.toggle("drawer")
                        }
                    }

                    Divider {}

                    Row {
                        spacing: 12

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Agenda.todayCount > 0
                            implicitWidth: calendarRow.implicitWidth + 18
                            implicitHeight: 20
                            radius: 10
                            color: Theme.purpleTint

                            Row {
                                id: calendarRow
                                anchors.centerIn: parent
                                spacing: 4

                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "calendar-dots"
                                    size: 12
                                    color: Theme.purple
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Agenda.todayCount
                                    color: Theme.purple
                                    font.family: Theme.font
                                    font.pixelSize: 11
                                }
                            }

                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: ShellState.toggle("drawer") }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: Qt.formatDateTime(clock.date, "HH:mm")
                                color: Theme.textBright
                                font.family: Theme.font
                                font.pixelSize: 13
                            }

                            Text {
                                text: Theme.date(clock.date, "ddd dd MMM")
                                color: Theme.textFaint
                                font.family: Theme.font
                                font.pixelSize: 9
                            }

                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: ShellState.toggle("power") }
                        }
                    }
                }
            }

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }
        }
    }
}
