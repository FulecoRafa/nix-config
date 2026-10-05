import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Wayland

// Gaveta de widgets (SUPER+W): entra pela direita, abaixo da barra, por cima
// das janelas. Os cartões seguem o layout do Store (duas colunas: "half"
// ocupa uma, "full" as duas); o modo "editar" adiciona, remove, reordena e
// redimensiona.
Scope {
    id: root

    readonly property bool shown: ShellState.panel === "drawer"
    readonly property int drawerWidth: 600
    property bool editing: false
    property bool picking: false

    onShownChanged: if (!shown) editing = false
    onEditingChanged: if (!editing) picking = false

    function terminal(command: var, klass: string): void {
        Quickshell.execDetached(["ghostty", "--class=fuleco." + klass, "-e", ...command])
    }

    // ── layout ───────────────────────────────────────────────────────────

    readonly property var catalog: ({
        media: { label: "mídia", icon: "music-notes", color: Theme.purple, size: "full" },
        weather: { label: "clima", icon: "cloud-sun", color: Theme.yellow, size: "half" },
        energy: { label: "energia", icon: "lightning", color: Theme.green, size: "half" },
        calendar: { label: "calendário & agenda", icon: "calendar-blank", color: Theme.cyan, size: "full" },
        system: { label: "sistema", icon: "cpu", color: Theme.cyan, size: "half" },
        timers: { label: "alarmes & timers", icon: "alarm", color: Theme.orange, size: "half" },
        notes: { label: "tarefas & rascunho", icon: "note-pencil", color: Theme.yellow, size: "full" },
        clock: { label: "relógio mundial", icon: "globe-hemisphere-west", color: Theme.cyan, size: "half" },
        ai: { label: "limites de IA", icon: "gauge", color: Theme.orange, size: "half" },
        network: { label: "rede", icon: "wifi-high", color: Theme.green, size: "half" }
    })
    readonly property var defaultKeys: ["media", "weather", "energy", "calendar", "system", "timers", "notes"]

    // Sem layout salvo, o padrão menos o que estava escondido no esquema antigo.
    readonly property var layout: {
        const saved = Store.data.drawerLayout
        // O JsonAdapter devolve uma lista que não passa no Array.isArray.
        if (saved && typeof saved.length === "number") return Array.from(saved).filter(item => catalog[item.key] !== undefined)
        const hidden = Store.data.hiddenWidgets ?? []
        return defaultKeys.filter(key => !hidden.includes(key)).map(key => ({ key: key, size: catalog[key].size }))
    }
    readonly property var available: Object.keys(catalog).filter(key => !layout.some(item => item.key === key))

    // Linhas da grade: "full" sozinho; "half" em pares, na ordem.
    readonly property var rows: {
        const list = []
        let pending = null
        layout.forEach((item, index) => {
            const entry = { key: item.key, size: item.size, index: index }
            if (item.size === "full") {
                if (pending) list.push([pending])
                pending = null
                list.push([entry])
            } else if (pending) {
                list.push([pending, entry])
                pending = null
            } else {
                pending = entry
            }
        })
        if (pending) list.push([pending])
        return list
    }

    function setLayout(list: var): void {
        Store.data.drawerLayout = list
        Store.data.hiddenWidgets = []
        Store.save()
    }

    function move(index: int, delta: int): void {
        const target = index + delta
        if (target < 0 || target >= layout.length) return
        const list = [...layout]
        const [item] = list.splice(index, 1)
        list.splice(target, 0, item)
        setLayout(list)
    }

    function resize(index: int): void {
        setLayout(layout.map((item, i) => i === index ? { key: item.key, size: item.size === "full" ? "half" : "full" } : item))
    }

    function removeAt(index: int): void {
        setLayout(layout.filter((item, i) => i !== index))
    }

    function add(key: string): void {
        if (!catalog[key] || layout.some(item => item.key === key)) return
        setLayout([...layout, { key: key, size: catalog[key].size }])
        picking = false
    }

    // Para testes e atalhos: `quickshell -c fuleco ipc call drawer edit`.
    IpcHandler {
        target: "drawer"

        function edit(): void {
            if (!root.shown) ShellState.open("drawer")
            root.editing = !root.editing
        }
        function pick(): void {
            if (!root.shown) ShellState.open("drawer")
            root.editing = true
            root.picking = !root.picking
        }
        function resize(index: int): void { root.resize(index) }
        function add(key: string): void { root.add(key) }
        function remove(index: int): void { root.removeAt(index) }
        function reset(): void {
            Store.data.drawerLayout = null
            Store.save()
        }
    }

    PanelWindow {
        id: win

        screen: ShellState.screen
        visible: root.shown || card.x < win.width
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "fuleco-drawer"
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        anchors { top: true; right: true; bottom: true }
        margins.top: Theme.barBottom + Theme.gap
        implicitWidth: root.drawerWidth

        // Clique fora (menos na barra, que alterna os painéis) fecha.
        HyprlandFocusGrab {
            active: root.shown
            windows: [win, ...ShellState.barWindows]
            onCleared: if (root.shown) ShellState.close()
        }

        Rectangle {
            id: card

            x: root.shown ? 0 : win.width + 2
            width: win.width + 30
            height: win.height
            color: Theme.surface
            border.color: Theme.surfaceBorder
            radius: 26

            Behavior on x { NumberAnimation { duration: Theme.slow; easing.type: Theme.easing } }

            Flickable {
                id: flick

                anchors.fill: parent
                anchors.rightMargin: 30
                contentHeight: content.implicitHeight + 48
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: content

                    focus: true
                    x: 26
                    y: 24
                    width: root.drawerWidth - 50
                    spacing: 12
                    Keys.onEscapePressed: {
                        if (root.picking) root.picking = false
                        else ShellState.close()
                    }

                    Header {}

                    Repeater {
                        model: root.rows

                        RowLayout {
                            id: row

                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 14

                            Repeater {
                                model: row.modelData

                                Loader {
                                    required property var modelData
                                    // Lidos pelo Card (parent) para os controles de edição.
                                    readonly property int slot: modelData.index
                                    readonly property string size: modelData.size

                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    Layout.alignment: Qt.AlignTop
                                    sourceComponent: root.cardFor(modelData.key)
                                }
                            }

                            // "half" sozinho na linha continua com meia largura.
                            Item {
                                visible: row.modelData.length === 1 && row.modelData[0].size === "half"
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                            }
                        }
                    }

                    AddCard { visible: root.editing }
                }
            }

            // Barra de rolagem fina, só quando sobra conteúdo.
            Rectangle {
                visible: flick.contentHeight > flick.height
                x: root.drawerWidth - 9
                y: 26 + (flick.height - 52 - height) * flick.visibleArea.yPosition / Math.max(0.001, 1 - flick.visibleArea.heightRatio)
                width: 4
                height: Math.max(30, (flick.height - 52) * flick.visibleArea.heightRatio)
                radius: 2
                color: Theme.dimmer
            }
        }
    }

    function cardFor(key: string): Component {
        switch (key) {
        case "media": return mediaCard
        case "weather": return weatherCard
        case "energy": return energyCard
        case "calendar": return calendarCard
        case "system": return systemCard
        case "timers": return timersCard
        case "notes": return notesCard
        case "clock": return clockCard
        case "ai": return aiCard
        case "network": return networkCard
        }
        return null
    }

    Component { id: mediaCard; MediaCard {} }
    Component { id: weatherCard; WeatherCard {} }
    Component { id: energyCard; EnergyCard {} }
    Component { id: calendarCard; CalendarCard {} }
    Component { id: systemCard; SystemCard {} }
    Component { id: timersCard; TimersCard {} }
    Component { id: notesCard; NotesCard {} }
    Component { id: clockCard; ClockCard {} }
    Component { id: aiCard; AiCard {} }
    Component { id: networkCard; NetworkCard {} }

    // ── peças ────────────────────────────────────────────────────────────

    component Caption: Text {
        color: Theme.textFaint
        font.family: Theme.font
        font.pixelSize: 11
    }

    component Link: Text {
        signal clicked
        color: Theme.yellow
        font.family: Theme.font
        font.pixelSize: 11
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: parent.clicked() }
    }

    // Botão redondo dos controles de edição.
    component EditButton: Rectangle {
        property string icon
        property string label
        property bool enabled: true
        signal clicked

        implicitWidth: label !== "" ? editText.implicitWidth + 18 : 24
        implicitHeight: 24
        radius: 12
        color: editHover.hovered && enabled ? Theme.track : Theme.raisedAlt
        opacity: enabled ? 1 : 0.35

        Icon {
            visible: parent.icon !== ""
            anchors.centerIn: parent
            name: parent.icon
            size: 12
            color: Theme.text
        }
        Text {
            id: editText
            visible: parent.label !== ""
            anchors.centerIn: parent
            text: parent.label
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 11
        }

        HoverHandler { id: editHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: if (parent.enabled) parent.clicked() }
    }

    // Cartão com título, ação à direita e, no modo de edição, os controles
    // de tamanho, ordem e remoção. O Loader pai informa slot e size.
    component Card: Rectangle {
        id: cardItem

        property string key
        property string title
        property string action
        property color actionColor: Theme.yellow
        property string actionIcon
        property int gap: 10
        default property alias body: column.data
        readonly property int slot: parent?.slot ?? -1
        readonly property bool full: (parent?.size ?? "full") === "full"
        // Meia largura: os cartões de duas colunas empilham.
        readonly property bool compact: width > 0 && width < 400
        signal actionClicked

        implicitHeight: column.implicitHeight + 32
        radius: 22
        color: Theme.raised
        border.color: root.editing ? Theme.dim : "transparent"

        ColumnLayout {
            id: column
            x: 16
            y: 16
            width: parent.width - 32
            spacing: cardItem.gap

            RowLayout {
                Layout.fillWidth: true
                visible: cardItem.title !== "" || root.editing
                spacing: 6

                Caption {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: cardItem.title !== "" ? cardItem.title : root.editing ? (root.catalog[cardItem.key]?.label ?? "") : ""
                }
                Link {
                    visible: cardItem.action !== "" && !root.editing
                    text: cardItem.action
                    color: cardItem.actionColor
                    onClicked: cardItem.actionClicked()
                }
                Icon {
                    visible: cardItem.actionIcon !== "" && !root.editing
                    name: cardItem.actionIcon
                    size: 13
                    color: Theme.textFaint
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { margin: 6; onTapped: cardItem.actionClicked() }
                }

                EditButton {
                    visible: root.editing
                    // Encolhe para ½ ou estica para a largura inteira.
                    icon: cardItem.full ? "arrows-in-line-horizontal" : "arrows-out-line-horizontal"
                    onClicked: root.resize(cardItem.slot)
                }
                EditButton {
                    visible: root.editing
                    icon: "caret-up"
                    enabled: cardItem.slot > 0
                    onClicked: root.move(cardItem.slot, -1)
                }
                EditButton {
                    visible: root.editing
                    icon: "caret-down"
                    enabled: cardItem.slot < root.layout.length - 1
                    onClicked: root.move(cardItem.slot, 1)
                }
                EditButton {
                    visible: root.editing
                    icon: "x"
                    onClicked: root.removeAt(cardItem.slot)
                }
            }
        }
    }

    // Fim da gaveta no modo de edição: abre a lista do que ainda não está nela.
    component AddCard: Rectangle {
        Layout.fillWidth: true
        implicitHeight: addColumn.implicitHeight + 28
        radius: 22
        color: addHover.hovered && !root.picking ? Theme.raised : "transparent"
        border.color: Theme.dim

        HoverHandler { id: addHover }

        ColumnLayout {
            id: addColumn
            x: 16
            y: 14
            width: parent.width - 32
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Icon { name: root.picking ? "x" : "plus"; size: 13; color: Theme.yellow }
                Text {
                    text: root.picking ? "escolha um widget" : "adicionar widget"
                    color: Theme.yellow
                    font.family: Theme.font
                    font.pixelSize: 12
                }
                Item { Layout.fillWidth: true }
                Caption {
                    text: root.available.length === 0 ? "todos já estão na gaveta" : root.available.length + " disponíveis"
                }

                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: if (root.available.length > 0) root.picking = !root.picking }
            }

            GridLayout {
                Layout.fillWidth: true
                visible: root.picking
                columns: 2
                rowSpacing: 8
                columnSpacing: 8

                Repeater {
                    model: root.picking ? root.available : []

                    Rectangle {
                        id: option

                        required property string modelData
                        readonly property var info: root.catalog[modelData]

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 52
                        radius: 16
                        color: optionHover.hovered ? Theme.track : Theme.raised

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Rectangle {
                                implicitWidth: 30
                                implicitHeight: 30
                                radius: 10
                                color: Theme.raisedAlt
                                Icon { anchors.centerIn: parent; name: option.info.icon; size: 15; color: option.info.color }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: option.info.label
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                }
                                Caption { text: option.info.size === "full" ? "inteiro" : "½ largura" }
                            }
                            Icon { name: "plus"; size: 12; color: Theme.textFaint }
                        }

                        HoverHandler { id: optionHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.add(option.modelData) }
                    }
                }
            }
        }
    }

    component Level: Rectangle {
        property real value
        property color accent: Theme.cyan
        Layout.fillWidth: true
        implicitHeight: 6
        radius: height / 2
        color: Theme.track

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, parent.value))
            height: parent.height
            radius: parent.radius
            color: parent.accent
            Behavior on width { NumberAnimation { duration: Theme.normal } }
        }
    }

    // ── cabeçalho ────────────────────────────────────────────────────────

    component Header: RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 2
        spacing: 12

        SystemClock { id: clock; precision: SystemClock.Minutes }

        ColumnLayout {
            spacing: 3
            Text {
                text: Theme.date(clock.date, "dddd, d 'de' MMMM").replace("-feira", "")
                color: Theme.textBright
                font.family: Theme.font
                font.pixelSize: 24
                font.letterSpacing: -0.2
            }
            Caption {
                font.pixelSize: 12
                text: {
                    const events = Agenda.todayCount
                    const alarms = Timers.activeAlarms
                    const open = (Store.data.tasks ?? []).filter(task => !task.done).length
                    return events + (events === 1 ? " evento" : " eventos") + " · "
                        + alarms + (alarms === 1 ? " alarme" : " alarmes") + " · "
                        + open + (open === 1 ? " tarefa aberta" : " tarefas abertas")
                }
            }
        }

        Item { Layout.fillWidth: true }

        Chip {
            Layout.alignment: Qt.AlignBottom
            label: root.editing ? "pronto" : "editar"
            active: root.editing
            fontSize: 11
            onClicked: root.editing = !root.editing
        }
    }

    // ── mídia ────────────────────────────────────────────────────────────

    component MediaCard: Card {
        id: media

        key: "media"
        gap: 12

        readonly property var players: Mpris.players.values
        readonly property MprisPlayer player: players.find(p => p.isPlaying) ?? players[0] ?? null
        readonly property real progress: player && player.length > 0 ? Math.min(1, player.position / player.length) : 0

        function time(seconds: real): string {
            const total = Math.max(0, Math.floor(seconds))
            return Math.floor(total / 60) + ":" + String(total % 60).padStart(2, "0")
        }

        // O MPRIS não avisa da posição; atualiza enquanto toca.
        Timer {
            interval: 1000
            running: root.shown && (media.player?.isPlaying ?? false)
            repeat: true
            onTriggered: media.player.positionChanged()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                implicitWidth: media.compact ? 56 : 74
                implicitHeight: media.compact ? 56 : 74
                radius: 20
                color: Theme.track
                clip: true

                Icon {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    name: "music-notes"
                    size: 26
                    color: Theme.textMuted
                }

                Image {
                    id: cover
                    anchors.fill: parent
                    visible: status === Image.Ready
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(148, 148)
                    source: media.player?.trackArtUrl ?? ""
                    layer.enabled: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                // Encolhe com o cartão; os textos cortam com reticências.
                Layout.preferredWidth: 0
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: media.player?.trackTitle || "nada tocando"
                    elide: Text.ElideRight
                    color: Theme.textBright
                    font.family: Theme.font
                    font.pixelSize: 15
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: [media.player?.trackArtist, media.player?.trackAlbum].filter(Boolean).join(" · ")
                    elide: Text.ElideRight
                    color: Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: 12
                }
                Caption {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: media.player
                        ? (media.player.identity || "player").toLowerCase() + (media.player.length > 0 ? " · " + media.time(media.player.position) + " / " + media.time(media.player.length) : "")
                        : "abra algo no mpv, helium ou spotify"
                }
            }

            Rectangle {
                implicitWidth: 46
                implicitHeight: 46
                radius: 23
                color: media.player ? Theme.purple : Theme.track

                Icon {
                    anchors.centerIn: parent
                    name: media.player?.isPlaying ? "pause" : "play"
                    size: 19
                    color: media.player ? Theme.onAccent : Theme.textFaint
                }

                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: if (media.player?.canTogglePlaying) media.player.togglePlaying() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: media.player !== null
            spacing: 14

            Icon {
                name: "skip-back"
                size: 17
                color: media.player?.canGoPrevious ? Theme.text : Theme.textGhost
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { margin: 6; onTapped: media.player?.previous() }
            }

            // Linha ondulada: tocado em lilás, o resto apagado.
            Canvas {
                id: wave

                Layout.fillWidth: true
                implicitHeight: 26
                property real progress: media.progress
                onProgressChanged: requestPaint()
                onWidthChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const step = 20
                    const points = []
                    for (let x = 0, i = 0; x <= width + step; x += step, i++) {
                        // Alturas pseudoaleatórias fixas, como no design.
                        const y = 13 + Math.sin(i * 2.4) * 5 + Math.cos(i * 1.3) * 3
                        points.push({ x: Math.min(x, width), y: y })
                    }
                    const cut = width * progress
                    const yAt = x => {
                        const index = Math.min(points.length - 2, Math.floor(x / step))
                        const a = points[index], b = points[index + 1]
                        return a.y + (b.y - a.y) * Math.max(0, Math.min(1, (x - a.x) / Math.max(1, b.x - a.x)))
                    }
                    ctx.lineWidth = 2.5
                    ctx.lineJoin = "round"
                    ctx.lineCap = "round"

                    ctx.strokeStyle = "#3D4657"
                    ctx.beginPath()
                    ctx.moveTo(cut, yAt(cut))
                    for (const p of points) if (p.x > cut) ctx.lineTo(p.x, p.y)
                    ctx.stroke()

                    ctx.strokeStyle = "" + Theme.purple
                    ctx.beginPath()
                    ctx.moveTo(points[0].x, points[0].y)
                    for (const p of points) if (p.x < cut) ctx.lineTo(p.x, p.y)
                    ctx.lineTo(cut, yAt(cut))
                    ctx.stroke()

                    ctx.fillStyle = "" + Theme.purple
                    ctx.beginPath()
                    ctx.arc(Math.max(4, cut), yAt(cut), 4, 0, Math.PI * 2)
                    ctx.fill()
                }

                TapHandler {
                    onTapped: point => {
                        const player = media.player
                        if (player?.canSeek && player.length > 0) player.position = player.length * point.position.x / wave.width
                    }
                }
            }

            Icon {
                name: "skip-forward"
                size: 17
                color: media.player?.canGoNext ? Theme.text : Theme.textGhost
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { margin: 6; onTapped: media.player?.next() }
            }
        }
    }

    // ── clima ────────────────────────────────────────────────────────────

    component WeatherCard: Card {
        key: "weather"
        title: Weather.place || "clima"
        action: "weathr ↗"
        onActionClicked: {
            root.terminal(["weathr"], "weathr")
            ShellState.close()
        }

        RowLayout {
            spacing: 12
            Icon { name: Weather.icon; size: 40; color: Weather.color }
            ColumnLayout {
                spacing: 2
                Text {
                    text: Weather.ready ? Weather.temperature + "°" : "--°"
                    color: Theme.textBright
                    font.family: Theme.font
                    font.pixelSize: 30
                }
                Text {
                    text: Weather.ready ? "sensação " + Weather.feelsLike + "°" : "buscando…"
                    color: Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: Weather.hours

                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8

                    Caption { Layout.preferredWidth: 30; text: modelData.hour }
                    Icon { name: modelData.icon; size: 14; color: modelData.color }
                    Text {
                        Layout.preferredWidth: 26
                        text: modelData.temperature + "°"
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                    // Chance de chuva.
                    Level { implicitHeight: 4; value: modelData.rain; accent: Theme.cyan }
                }
            }
        }
    }

    // ── energia ──────────────────────────────────────────────────────────

    component EnergyCard: Card {
        key: "energy"
        title: "energia"
        action: Net.hasBattery ? Math.round(Net.batteryPercent) + "%" + (Net.batteryTime ? " · " + Net.batteryTime : "") : ""
        actionColor: Net.batteryColor
        gap: 11

        RowLayout {
            spacing: 12
            Icon { name: Net.hasBattery ? Net.batteryIcon : "plug"; size: 34; color: Net.batteryColor }
            ColumnLayout {
                spacing: 2
                Text {
                    text: Net.watts > 0 ? Net.watts.toFixed(1) + " W" : Net.hasBattery ? Math.round(Net.batteryPercent) + "%" : "tomada"
                    color: Theme.textBright
                    font.family: Theme.font
                    font.pixelSize: 19
                }
                Text {
                    text: !Net.hasBattery ? "sem bateria"
                        : Net.battery?.state === UPowerDeviceState.FullyCharged ? "carregada"
                        : Net.charging ? "carregando" : "descarregando"
                    color: Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }
        }

        Level {
            visible: Net.hasBattery
            implicitHeight: 7
            value: Net.batteryPercent / 100
            accent: Net.batteryColor
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 7

            Repeater {
                model: [
                    { label: "economia", profile: PowerProfile.PowerSaver },
                    { label: "equilíbrio", profile: PowerProfile.Balanced },
                    { label: "desempenho", profile: PowerProfile.Performance }
                ]

                Rectangle {
                    required property var modelData
                    readonly property bool active: PowerProfiles.profile === modelData.profile

                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 14
                    color: active ? Theme.yellow : profileHover.hovered ? Theme.dimmer : Theme.track

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        color: parent.active ? Theme.onAccent : Theme.textMuted
                        font.family: Theme.font
                        font.pixelSize: 11
                    }

                    HoverHandler { id: profileHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: PowerProfiles.profile = parent.modelData.profile }
                }
            }
        }
    }

    // ── calendário + agenda ──────────────────────────────────────────────

    component CalendarCard: Card {
        id: calendar

        key: "calendar"

        property date month: new Date(Agenda.today.getFullYear(), Agenda.today.getMonth(), 1)
        property date selected: Agenda.today
        readonly property var selectedEvents: Agenda.eventsOn(selected)
        readonly property bool selectedToday: Agenda.sameDay(selected, Agenda.today)

        // Dias exibidos: começa no domingo antes do dia 1, semanas inteiras.
        readonly property var days: {
            const first = new Date(month.getFullYear(), month.getMonth(), 1)
            const start = new Date(first)
            start.setDate(1 - first.getDay())
            const last = new Date(month.getFullYear(), month.getMonth() + 1, 0)
            const count = Math.ceil((first.getDay() + last.getDate()) / 7) * 7
            const list = []
            for (let i = 0; i < count; i++) list.push(new Date(start.getFullYear(), start.getMonth(), start.getDate() + i))
            return list
        }

        function shift(delta: int): void {
            month = new Date(month.getFullYear(), month.getMonth() + delta, 1)
        }

        Connections {
            target: root
            function onShownChanged() {
                if (!root.shown) return
                calendar.month = new Date(Agenda.today.getFullYear(), Agenda.today.getMonth(), 1)
                calendar.selected = Agenda.today
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: calendar.compact ? 1 : 3
            columnSpacing: 18
            rowSpacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Caption { text: Theme.date(calendar.month, "MMMM yyyy") }
                    Item { Layout.fillWidth: true }
                    Icon {
                        name: "caret-left"; size: 11; color: Theme.textFaint
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { margin: 6; onTapped: calendar.shift(-1) }
                    }
                    Icon {
                        name: "caret-right"; size: 11; color: Theme.textFaint
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { margin: 6; onTapped: calendar.shift(1) }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 5
                    rowSpacing: 5

                    Repeater {
                        model: ["d", "s", "t", "q", "q", "s", "s"]
                        Text {
                            required property string modelData
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: Theme.textGhost
                            font.family: Theme.font
                            font.pixelSize: 10
                        }
                    }

                    Repeater {
                        model: calendar.days

                        Rectangle {
                            id: dayCell
                            required property date modelData
                            readonly property bool inMonth: modelData.getMonth() === calendar.month.getMonth()
                            readonly property bool today: Agenda.sameDay(modelData, Agenda.today)
                            readonly property bool picked: Agenda.sameDay(modelData, calendar.selected)
                            readonly property bool busy: Agenda.hasEvents(modelData)

                            Layout.fillWidth: true
                            implicitHeight: 22
                            radius: 11
                            color: today ? Theme.yellow : picked ? Theme.track : dayHover.hovered ? Theme.raisedAlt : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: dayCell.modelData.getDate()
                                color: dayCell.today ? Theme.onAccent
                                    : !dayCell.inMonth ? "#4E5666"
                                    : dayCell.busy ? Theme.cyan : Theme.textMuted
                                font.family: Theme.font
                                font.pixelSize: 11
                            }

                            HoverHandler { id: dayHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: calendar.selected = dayCell.modelData }
                        }
                    }
                }
            }

            Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.track; visible: !calendar.compact }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: 9

                RowLayout {
                    Layout.fillWidth: true
                    Caption { text: calendar.selectedToday ? "agenda" : "agenda · " + Theme.date(calendar.selected, "dd MMM") }
                    Item { Layout.fillWidth: true }
                    Link {
                        text: "calcure ↗"
                        onClicked: {
                            root.terminal(["calcure"], "calcure")
                            ShellState.close()
                        }
                    }
                }

                Repeater {
                    model: calendar.selectedEvents.slice(0, 5)

                    RowLayout {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 10

                        Caption {
                            Layout.preferredWidth: 36
                            Layout.alignment: Qt.AlignTop
                            text: modelData.time || "dia"
                        }
                        Rectangle {
                            Layout.fillHeight: true
                            implicitWidth: 3
                            radius: 2
                            color: [Theme.purple, Theme.cyan, Theme.green, Theme.orange][index % 4]
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: modelData.title
                                elide: Text.ElideRight
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                            Text {
                                text: modelData.time ? "calcure" : "dia todo"
                                color: Theme.textGhost
                                font.family: Theme.font
                                font.pixelSize: 11
                            }
                        }
                    }
                }

                Text {
                    visible: calendar.selectedEvents.length === 0
                    text: "nada marcado"
                    color: Theme.textGhost
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }
        }
    }

    // ── sistema ──────────────────────────────────────────────────────────

    component SystemCard: Card {
        key: "system"
        title: "sistema"
        action: "btop ↗"
        onActionClicked: {
            root.terminal(["btop"], "btop")
            ShellState.close()
        }

        Repeater {
            model: [
                { label: "cpu", value: SysInfo.cpu / 100, text: Math.round(SysInfo.cpu) + "%", color: Theme.cyan },
                { label: "memória", value: SysInfo.memory / 100, text: SysInfo.memoryUsedGiB.toFixed(1) + "/" + Math.round(SysInfo.memoryTotalGiB) + "G", color: Theme.green },
                { label: "disco /", value: SysInfo.disk / 100, text: Math.round(SysInfo.diskUsedGiB) + "/" + Math.round(SysInfo.diskTotalGiB) + "G", color: Theme.purple },
                { label: "temp", value: SysInfo.temperature / 100, text: SysInfo.temperature + "°c", color: Theme.orange }
            ]

            ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: modelData.label; color: Theme.textMuted; font.family: Theme.font; font.pixelSize: 11 }
                    Item { Layout.fillWidth: true }
                    Text { text: modelData.text; color: modelData.color; font.family: Theme.font; font.pixelSize: 11 }
                }
                Level { value: modelData.value; accent: modelData.color }
            }
        }
    }

    // ── alarmes & timers ─────────────────────────────────────────────────

    component TimersCard: Card {
        id: timersCard

        key: "timers"
        title: "alarmes & timers"
        property bool adding: false
        actionIcon: adding ? "x" : "plus"
        onActionClicked: adding = !adding

        // Novo timer/alarme.
        ColumnLayout {
            Layout.fillWidth: true
            visible: timersCard.adding
            spacing: 7

            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: [
                        { label: "5 min", minutes: 5, name: "timer" },
                        { label: "15 min", minutes: 15, name: "timer" },
                        { label: "pomodoro", minutes: 25, name: "pomodoro · foco" }
                    ]
                    Chip {
                        required property var modelData
                        label: modelData.label
                        fontSize: 11
                        color: Theme.track
                        onClicked: {
                            Timers.startTimer(modelData.minutes, modelData.name)
                            timersCard.adding = false
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 14
                color: Theme.track

                TextInput {
                    id: alarmInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 11
                    selectByMouse: true
                    onAccepted: {
                        const parts = text.trim().split(/\s+/)
                        Timers.addAlarm(parts[0], parts.slice(1).join(" "))
                        text = ""
                        timersCard.adding = false
                    }

                    Text {
                        visible: parent.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "alarme: 06:40 acordar ↵"
                        color: Theme.textGhost
                        font: parent.font
                    }
                }
            }
        }

        Repeater {
            model: Timers.timers

            Rectangle {
                id: timerRow
                required property var modelData
                readonly property real remainingMs: Timers.remaining(modelData)

                Layout.fillWidth: true
                implicitHeight: 46
                radius: 15
                color: Theme.track

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 11
                    anchors.rightMargin: 9
                    spacing: 10

                    Icon { name: "timer"; size: 17; color: Theme.green }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: Timers.clock(timerRow.remainingMs)
                            color: Theme.textBright
                            font.family: Theme.font
                            font.pixelSize: 14
                        }
                        Text {
                            Layout.fillWidth: true
                            text: (timerRow.modelData.label || "timer") + (timerRow.modelData.paused ? " · pausado" : "")
                            elide: Text.ElideRight
                            color: Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: 10
                        }
                    }
                    Icon {
                        visible: timerHover.hovered
                        name: "x"
                        size: 12
                        color: Theme.textFaint
                        TapHandler { margin: 6; onTapped: Timers.remove(timerRow.modelData.id) }
                    }
                    Rectangle {
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 14
                        color: Theme.green
                        Icon {
                            anchors.centerIn: parent
                            name: timerRow.modelData.paused ? "play" : "pause"
                            size: 12
                            color: Theme.onAccent
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Timers.togglePause(timerRow.modelData) }
                    }
                }

                HoverHandler { id: timerHover }
            }
        }

        Repeater {
            model: Timers.alarms

            Item {
                id: alarmRow
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: 38

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 11
                    anchors.rightMargin: 4
                    spacing: 10

                    Icon { name: "alarm"; size: 16; color: alarmRow.modelData.enabled ? Theme.yellow : Theme.textGhost }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: alarmRow.modelData.time
                            color: alarmRow.modelData.enabled ? Theme.text : Theme.textMuted
                            font.family: Theme.font
                            font.pixelSize: 13
                        }
                        Text {
                            Layout.fillWidth: true
                            text: Timers.daysText(alarmRow.modelData)
                            elide: Text.ElideRight
                            color: alarmRow.modelData.enabled ? Theme.textFaint : Theme.textGhost
                            font.family: Theme.font
                            font.pixelSize: 10
                        }
                    }
                    Icon {
                        visible: alarmHover.hovered
                        name: "x"
                        size: 12
                        color: Theme.textFaint
                        TapHandler { margin: 6; onTapped: Timers.remove(alarmRow.modelData.id) }
                    }
                    Toggle {
                        checked: alarmRow.modelData.enabled
                        accent: Theme.yellow
                        onToggled: checked => Timers.update(alarmRow.modelData.id, { enabled: checked })
                    }
                }

                HoverHandler { id: alarmHover }
            }
        }

        Text {
            visible: Timers.items.length === 0 && !timersCard.adding
            text: "nenhum timer · + para criar"
            color: Theme.textGhost
            font.family: Theme.font
            font.pixelSize: 12
        }
    }

    // ── tarefas + rascunho ───────────────────────────────────────────────

    component NotesCard: Card {
        id: notes

        key: "notes"

        readonly property var tasks: Store.data.tasks ?? []
        readonly property int doneCount: tasks.filter(task => task.done).length
        // Abertas primeiro; as feitas mais recentes logo abaixo.
        readonly property var ordered: [...tasks.map((task, index) => ({ task, index }))]
            .sort((a, b) => Number(a.task.done) - Number(b.task.done))
            .slice(0, 6)

        function setTasks(list: var): void {
            Store.data.tasks = list
            Store.save()
        }

        GridLayout {
            Layout.fillWidth: true
            columns: notes.compact ? 1 : 3
            columnSpacing: 20
            rowSpacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Caption { text: "tarefas" }
                    Item { Layout.fillWidth: true }
                    Caption { text: notes.doneCount + " / " + notes.tasks.length }
                }

                Repeater {
                    model: notes.ordered

                    RowLayout {
                        id: taskRow
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 9

                        Icon {
                            name: taskRow.modelData.task.done ? "check-square" : "square"
                            size: 15
                            color: taskRow.modelData.task.done ? Theme.green : Theme.textGhost
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                margin: 4
                                onTapped: notes.setTasks(notes.tasks.map((task, index) => index === taskRow.modelData.index ? { text: task.text, done: !task.done } : task))
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: taskRow.modelData.task.text
                            elide: Text.ElideRight
                            font.strikeout: taskRow.modelData.task.done
                            color: taskRow.modelData.task.done ? Theme.textGhost : Theme.text
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                        Icon {
                            visible: taskHover.hovered
                            name: "x"
                            size: 11
                            color: Theme.textFaint
                            TapHandler { margin: 4; onTapped: notes.setTasks(notes.tasks.filter((task, index) => index !== taskRow.modelData.index)) }
                        }
                        HoverHandler { id: taskHover }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 9
                    Icon { name: "plus"; size: 15; color: Theme.textGhost }
                    TextInput {
                        id: taskInput
                        Layout.fillWidth: true
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 12
                        selectByMouse: true
                        clip: true
                        onAccepted: {
                            if (text.trim() === "") return
                            notes.setTasks([...notes.tasks, { text: text.trim(), done: false }])
                            text = ""
                        }
                        Text {
                            visible: parent.text === "" && !parent.activeFocus
                            text: "nova tarefa"
                            color: Theme.textGhost
                            font: parent.font
                        }
                    }
                }
            }

            Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.track; visible: !notes.compact }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Caption { text: "rascunho" }
                    Item { Layout.fillWidth: true }
                    Caption { text: draftSave.running ? "salvando…" : "salvo" }
                }

                TextEdit {
                    id: draft
                    Layout.fillWidth: true
                    Layout.minimumHeight: 60
                    text: Store.data.draft
                    wrapMode: TextEdit.Wrap
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 12
                    selectByMouse: true
                    onTextChanged: if (activeFocus) draftSave.restart()

                    Text {
                        visible: draft.text === "" && !draft.activeFocus
                        text: "ideias, links, coisas soltas…"
                        color: Theme.textGhost
                        font: draft.font
                    }

                    Timer {
                        id: draftSave
                        interval: 600
                        onTriggered: {
                            Store.data.draft = draft.text
                            Store.save()
                        }
                    }
                }
            }
        }
    }

    // ── relógio mundial ──────────────────────────────────────────────────

    component ClockCard: Card {
        id: world

        key: "clock"
        title: "relógio mundial"

        SystemClock { id: worldClock; precision: SystemClock.Minutes }

        // Sem Intl no motor do QML: offsets fixos mais as regras de horário
        // de verão da UE e dos EUA.
        function lastSunday(year: int, month: int): int {
            const last = new Date(Date.UTC(year, month + 1, 0))
            return last.getUTCDate() - last.getUTCDay()
        }
        function offset(zone: string, now: date): real {
            const year = now.getUTCFullYear()
            const t = now.getTime()
            if (zone === "eu") {
                const start = Date.UTC(year, 2, world.lastSunday(year, 2), 1)
                const end = Date.UTC(year, 9, world.lastSunday(year, 9), 1)
                return t >= start && t < end ? 1 : 0
            }
            if (zone === "us") {
                const march = new Date(Date.UTC(year, 2, 1)).getUTCDay()
                const november = new Date(Date.UTC(year, 10, 1)).getUTCDay()
                const start = Date.UTC(year, 2, 1 + (7 - march) % 7 + 7, 7)
                const end = Date.UTC(year, 10, 1 + (7 - november) % 7, 6)
                return t >= start && t < end ? -4 : -5
            }
            return Number(zone)
        }

        readonly property var zones: [
            { city: "utc", zone: "0" },
            { city: "lisboa", zone: "eu" },
            { city: "nova york", zone: "us" },
            { city: "tóquio", zone: "9" }
        ]
        readonly property real localOffset: -worldClock.date.getTimezoneOffset() / 60

        Text {
            text: Qt.formatTime(worldClock.date, "HH:mm")
            color: Theme.textBright
            font.family: Theme.font
            font.pixelSize: 30
            font.letterSpacing: -0.5
        }

        GridLayout {
            Layout.fillWidth: true
            columns: world.compact ? 1 : 2
            columnSpacing: 18
            rowSpacing: 6

            Repeater {
                model: world.zones

                RowLayout {
                    required property var modelData
                    readonly property real hours: world.offset(modelData.zone, worldClock.date)
                    readonly property real diff: hours - world.localOffset

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: 8

                    Text { text: modelData.city; color: Theme.textMuted; font.family: Theme.font; font.pixelSize: 12 }
                    Item { Layout.fillWidth: true }
                    Caption { text: (diff >= 0 ? "+" : "") + diff + "h" }
                    Text {
                        text: Qt.formatTime(new Date(worldClock.date.getTime() + diff * 3600000), "HH:mm")
                        color: Theme.cyan
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }
            }
        }
    }

    // ── limites de IA ────────────────────────────────────────────────────

    component AiCard: Card {
        id: ai

        key: "ai"
        title: "limites de uso"
        action: "detalhes ↗"
        onActionClicked: ShellState.open("ai")

        GridLayout {
            Layout.fillWidth: true
            columns: ai.compact ? 1 : 2
            columnSpacing: 18
            rowSpacing: 10

            Repeater {
                model: [
                    { label: "claude · 5h", limit: AiUsage.claudeSession, available: AiUsage.claudeAvailable, color: Theme.orange },
                    { label: "codex · 5h", limit: AiUsage.codexPrimary, available: AiUsage.codexAvailable, color: Theme.green }
                ]

                ColumnLayout {
                    required property var modelData
                    readonly property real value: modelData.available ? AiUsage.percent(modelData.limit) : -1

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: modelData.label; color: Theme.textMuted; font.family: Theme.font; font.pixelSize: 11 }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: modelData.available ? AiUsage.percentText(modelData.limit) : "sem dados"
                            color: value >= 90 ? Theme.red : modelData.color
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
                    }
                    Level { value: Math.max(0, parent.value) / 100; accent: parent.value >= 90 ? Theme.red : modelData.color }
                    Caption {
                        visible: modelData.available && modelData.limit !== null
                        text: AiUsage.resetText(modelData.limit)
                    }
                }
            }
        }
    }

    // ── rede ─────────────────────────────────────────────────────────────

    component NetworkCard: Card {
        id: network

        key: "network"
        title: "rede"
        action: "ajustes ↗"
        onActionClicked: ShellState.openControl("rede")

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: 14
                color: Net.online ? Theme.greenTint : Theme.track
                Icon { anchors.centerIn: parent; name: Net.icon; size: 19; color: Net.online ? Theme.green : Theme.textFaint }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: Net.wiredDevice ? "cabo" : Net.activeNetwork ? Net.activeNetwork.name : Net.wifiEnabled ? "desconectado" : "wi-fi desligado"
                    color: Theme.textBright
                    font.family: Theme.font
                    font.pixelSize: 14
                }
                Caption {
                    text: Net.activeNetwork && !Net.wiredDevice ? "sinal " + Math.round(Net.strength(Net.activeNetwork) * 100) + "%" : Net.online ? "conectado" : "offline"
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Icon { name: "bluetooth"; size: 13; color: Net.bluetoothConnected.length > 0 ? Theme.cyan : Theme.textFaint }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: !Net.bluetoothEnabled ? "bluetooth desligado"
                    : Net.bluetoothConnected.length > 0 ? Net.bluetoothConnected.map(device => device.name).join(", ")
                    : "nenhum dispositivo"
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: 11
            }
        }
    }
}
