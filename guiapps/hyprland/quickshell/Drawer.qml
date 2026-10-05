import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Wayland

// Gaveta de widgets (SUPER+W): entra pela direita, abaixo da barra, por cima
// das janelas. Os cartões seguem o layout do Store numa grade de duas colunas
// com três tamanhos: "small" (1×1), "wide" (2×1) e "large" (2×2). O modo
// "editar" adiciona, remove, arrasta para reordenar e troca o tamanho.
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

    // `sizes` são os tamanhos que o cartão sabe desenhar; `size` é o padrão.
    readonly property var catalog: ({
        media: { label: "mídia", icon: "music-notes", color: Theme.purple, sizes: ["small", "wide", "large"], size: "wide" },
        weather: { label: "clima", icon: "cloud-sun", color: Theme.yellow, sizes: ["small", "wide"], size: "small" },
        energy: { label: "energia", icon: "lightning", color: Theme.green, sizes: ["small", "wide"], size: "small" },
        calendar: { label: "calendário & agenda", icon: "calendar-blank", color: Theme.cyan, sizes: ["small", "wide", "large"], size: "large" },
        system: { label: "sistema", icon: "cpu", color: Theme.cyan, sizes: ["small", "wide"], size: "small" },
        timers: { label: "alarmes & timers", icon: "alarm", color: Theme.orange, sizes: ["small", "wide", "large"], size: "small" },
        notes: { label: "tarefas & rascunho", icon: "note-pencil", color: Theme.yellow, sizes: ["small", "wide", "large"], size: "wide" },
        clock: { label: "relógio mundial", icon: "globe-hemisphere-west", color: Theme.cyan, sizes: ["small", "wide"], size: "small" },
        ai: { label: "limites de IA", icon: "gauge", color: Theme.orange, sizes: ["small", "wide"], size: "small" },
        network: { label: "rede", icon: "wifi-high", color: Theme.green, sizes: ["small", "wide"], size: "small" }
    })
    readonly property var catalogKeys: Object.keys(catalog)
    readonly property var defaultKeys: ["media", "weather", "energy", "calendar", "system", "timers", "notes"]
    readonly property var sizeNames: ({ small: "1×1", wide: "2×1", large: "2×2" })

    // Grade: duas colunas e uma altura de linha fixa.
    readonly property int gridGap: 14
    readonly property real cellWidth: (drawerWidth - 50 - gridGap) / 2
    readonly property int rowUnit: 180

    // Tamanho válido para o cartão; converte o esquema antigo ("half"/"full").
    function fitSize(key: string, size: string): string {
        const info = catalog[key]
        if (info.sizes.includes(size)) return size
        if (size === "half") return info.sizes.includes("small") ? "small" : info.size
        if (size === "full") return info.size !== "small" ? info.size : "wide"
        return info.size
    }

    // Sem layout salvo, o padrão menos o que estava escondido no esquema antigo.
    readonly property var layout: {
        const saved = Store.data.drawerLayout
        // O JsonAdapter devolve uma lista que não passa no Array.isArray.
        if (saved && typeof saved.length === "number")
            return Array.from(saved).filter(item => catalog[item.key] !== undefined).map(item => ({ key: item.key, size: fitSize(item.key, item.size) }))
        const hidden = Store.data.hiddenWidgets ?? []
        return defaultKeys.filter(key => !hidden.includes(key)).map(key => ({ key: key, size: catalog[key].size }))
    }
    readonly property var available: catalogKeys.filter(key => !layout.some(item => item.key === key))

    // Enquanto arrasta, a grade mostra a ordem provisória; grava ao soltar.
    property var dragOrder: null
    property string dragKey: ""
    property string dragTarget: ""
    readonly property var order: dragOrder ?? layout

    // Encaixe "first-fit": cada cartão vai para o primeiro espaço livre, de
    // cima para baixo e da esquerda para a direita.
    readonly property var placement: {
        const used = []
        const map = {}
        let rows = 0
        const free = (row, col, w, h) => {
            for (let r = row; r < row + h; r++)
                for (let c = col; c < col + w; c++)
                    if (used[r]?.[c]) return false
            return true
        }
        for (const item of order) {
            const w = item.size === "small" ? 1 : 2
            const h = item.size === "large" ? 2 : 1
            let row = 0, col = -1
            for (; col < 0; row++)
                for (let c = 0; c + w <= 2; c++)
                    if (free(row, c, w, h)) { col = c; break }
            row--
            for (let r = row; r < row + h; r++) {
                used[r] = used[r] ?? [false, false]
                for (let c = col; c < col + w; c++) used[r][c] = true
            }
            map[item.key] = {
                size: item.size,
                x: col * (cellWidth + gridGap),
                y: row * (rowUnit + gridGap),
                width: w * cellWidth + (w - 1) * gridGap,
                height: h * rowUnit + (h - 1) * gridGap
            }
            rows = Math.max(rows, row + h)
        }
        return { map: map, height: rows > 0 ? rows * rowUnit + (rows - 1) * gridGap : 0 }
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

    // Próximo tamanho da lista do cartão (o botão do modo de edição).
    function cycleSize(key: string): void {
        setLayout(layout.map(item => {
            if (item.key !== key) return item
            const sizes = catalog[key].sizes
            return { key: key, size: sizes[(sizes.indexOf(item.size) + 1) % sizes.length] }
        }))
    }

    function remove(key: string): void {
        setLayout(layout.filter(item => item.key !== key))
    }

    function add(key: string): void {
        if (!catalog[key] || layout.some(item => item.key === key)) return
        setLayout([...layout, { key: key, size: catalog[key].size }])
        picking = false
    }

    function startDrag(key: string): void {
        dragOrder = [...layout]
        dragKey = key
        dragTarget = ""
    }

    // Centro do cartão arrastado sobre outro: ele toma o lugar desse na
    // ordem. Ignora o mesmo alvo de novo para não ficar trocando ida e volta
    // quando os tamanhos diferem.
    function dragOver(cx: real, cy: real): void {
        const map = placement.map
        const target = Object.keys(map).find(key => key !== dragKey
            && cx >= map[key].x && cx <= map[key].x + map[key].width
            && cy >= map[key].y && cy <= map[key].y + map[key].height)
        if (!target || target === dragTarget) return
        dragTarget = target
        const list = [...dragOrder]
        const from = list.findIndex(item => item.key === dragKey)
        const to = list.findIndex(item => item.key === target)
        const [item] = list.splice(from, 1)
        list.splice(to, 0, item)
        dragOrder = list
    }

    function endDrag(): void {
        const list = dragOrder
        dragOrder = null
        dragKey = ""
        if (list && list.some((item, index) => item.key !== layout[index]?.key)) setLayout(list)
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
        function resize(key: string): void { root.cycleSize(key) }
        function move(index: int, delta: int): void { root.move(index, delta) }
        function add(key: string): void { root.add(key) }
        function remove(key: string): void { root.remove(key) }
        function layout(): string { return JSON.stringify(root.layout) }
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
            active: root.shown && !ShellState.capturing
            windows: [win, ...ShellState.barWindows]
            onCleared: if (root.shown && !ShellState.capturing) ShellState.close()
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
                // Editando, arrastar move cartões; a roda continua rolando.
                interactive: !root.editing

                WheelHandler {
                    enabled: root.editing
                    onWheel: event => {
                        const limit = Math.max(0, flick.contentHeight - flick.height)
                        flick.contentY = Math.max(0, Math.min(limit, flick.contentY - event.angleDelta.y))
                    }
                }

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

                    Item {
                        id: grid

                        Layout.fillWidth: true
                        implicitHeight: root.placement.height

                        // Um Loader por cartão do catálogo, sempre o mesmo: reordenar
                        // ou redimensionar só move, sem recriar o cartão.
                        Repeater {
                            model: root.catalogKeys

                            Loader {
                                id: slotItem

                                required property string modelData
                                readonly property var place: root.placement.map[modelData] ?? null
                                // Lidos pelo Card (parent).
                                readonly property string key: modelData
                                readonly property string size: place?.size ?? "small"
                                readonly property bool dragging: dragger.active
                                property var lastPlace: null
                                property real grabX
                                property real grabY

                                active: place !== null
                                visible: active
                                z: dragging ? 10 : 0
                                scale: dragging ? 1.04 : 1
                                sourceComponent: root.cardFor(modelData)

                                Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }

                                // Entra no lugar sem animar; depois desliza até a casa nova.
                                function settle(): void {
                                    const animate = lastPlace !== null && place !== null
                                    lastPlace = place
                                    if (!place || dragging) return
                                    moveAnim.stop()
                                    if (!animate) {
                                        x = place.x
                                        y = place.y
                                        width = place.width
                                        height = place.height
                                        return
                                    }
                                    xAnim.to = place.x
                                    yAnim.to = place.y
                                    widthAnim.to = place.width
                                    heightAnim.to = place.height
                                    moveAnim.start()
                                }
                                onPlaceChanged: settle()
                                Component.onCompleted: settle()

                                ParallelAnimation {
                                    id: moveAnim
                                    NumberAnimation { id: xAnim; target: slotItem; property: "x"; duration: Theme.slow; easing.type: Theme.easing }
                                    NumberAnimation { id: yAnim; target: slotItem; property: "y"; duration: Theme.slow; easing.type: Theme.easing }
                                    NumberAnimation { id: widthAnim; target: slotItem; property: "width"; duration: Theme.slow; easing.type: Theme.easing }
                                    NumberAnimation { id: heightAnim; target: slotItem; property: "height"; duration: Theme.slow; easing.type: Theme.easing }
                                }

                                HoverHandler {
                                    enabled: root.editing
                                    cursorShape: slotItem.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                }

                                // Só no modo de edição; o corpo do cartão fica desativado.
                                DragHandler {
                                    id: dragger
                                    enabled: root.editing
                                    target: null
                                    grabPermissions: PointerHandler.CanTakeOverFromAnything

                                    onActiveChanged: {
                                        if (active) {
                                            moveAnim.stop()
                                            slotItem.grabX = slotItem.x
                                            slotItem.grabY = slotItem.y
                                            root.startDrag(slotItem.key)
                                        } else {
                                            root.endDrag()
                                            // Solto: volta animado para a casa da ordem nova.
                                            slotItem.lastPlace = slotItem.place
                                            xAnim.to = slotItem.place.x
                                            yAnim.to = slotItem.place.y
                                            widthAnim.to = slotItem.place.width
                                            heightAnim.to = slotItem.place.height
                                            moveAnim.restart()
                                        }
                                    }
                                    onActiveTranslationChanged: {
                                        if (!active) return
                                        slotItem.x = slotItem.grabX + activeTranslation.x
                                        slotItem.y = slotItem.grabY + activeTranslation.y
                                        root.dragOver(slotItem.x + slotItem.width / 2, slotItem.y + slotItem.height / 2)
                                    }
                                }
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

    // Cartão com título e ação à direita, do tamanho da casa na grade. No modo
    // de edição o corpo desliga (arrastar move o cartão) e aparecem os botões
    // de tamanho e remoção. O Loader pai informa key e size.
    component Card: Rectangle {
        id: cardItem

        property string key
        property string title
        property string action
        property color actionColor: Theme.yellow
        property string actionIcon
        property int gap: 10
        default property alias body: column.data
        readonly property string size: parent?.size ?? "wide"
        readonly property bool compact: size === "small"
        readonly property bool large: size === "large"
        // Altura que sobra abaixo do título, para decidir quantos itens cabem.
        readonly property real bodyHeight: column.height - (titleRow.visible ? titleRow.height + gap : 0)
        signal actionClicked

        radius: 22
        color: Theme.raised
        border.color: !root.editing ? "transparent" : (parent?.dragging ?? false) ? Theme.yellow : Theme.dim
        // Último recurso: cada cartão já se ajusta ao tamanho.
        clip: true

        ColumnLayout {
            id: column
            x: 16
            y: 16
            width: parent.width - 32
            height: parent.height - 32
            spacing: cardItem.gap
            enabled: !root.editing

            RowLayout {
                id: titleRow
                Layout.fillWidth: true
                visible: cardItem.title !== "" || root.editing
                spacing: 6

                Caption {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.editing ? (root.catalog[cardItem.key]?.label ?? "") : cardItem.title
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
                // Espaço dos botões de edição, que ficam por cima.
                Item {
                    visible: root.editing
                    implicitWidth: editControls.width
                    implicitHeight: 1
                }
            }
        }

        Row {
            id: editControls
            visible: root.editing
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 11
            anchors.rightMargin: 12
            spacing: 6

            EditButton {
                visible: (root.catalog[cardItem.key]?.sizes.length ?? 0) > 1
                label: root.sizeNames[cardItem.size] ?? ""
                onClicked: root.cycleSize(cardItem.key)
            }
            EditButton {
                icon: "x"
                onClicked: root.remove(cardItem.key)
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
                                Caption { text: option.info.sizes.map(size => root.sizeNames[size]).join(" · ") }
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
                    if (root.editing) return "arraste para reordenar · 1×1, 2×1 e 2×2 trocam o tamanho"
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

        readonly property var players: Media.players
        readonly property MprisPlayer player: Media.player
        readonly property bool playing: media.player?.isPlaying ?? false
        readonly property real progress: player && player.length > 0 ? Math.min(1, player.position / player.length) : 0
        readonly property int coverSize: media.large ? 168 : media.compact ? 56 : 74

        function time(seconds: real): string {
            const total = Math.max(0, Math.floor(seconds))
            return Math.floor(total / 60) + ":" + String(total % 60).padStart(2, "0")
        }

        // O MPRIS não avisa da posição; atualiza enquanto toca.
        Timer {
            interval: 1000
            running: root.shown && media.playing
            repeat: true
            onTriggered: media.player.positionChanged()
        }

        // O cava só roda com a gaveta aberta e algo tocando.
        Binding {
            target: Spectrum
            property: "active"
            value: root.shown && media.playing
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            // Capa e textos levam até o app que está tocando.
            HoverHandler { cursorShape: media.player ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler {
                onTapped: {
                    if (!media.player) return
                    Media.focusApp(media.player)
                    ShellState.close()
                }
            }

            Rectangle {
                implicitWidth: media.coverSize
                implicitHeight: media.coverSize
                radius: media.large ? 26 : 20
                color: Theme.track
                clip: true

                Icon {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    name: "music-notes"
                    size: media.large ? 48 : 26
                    color: Theme.textMuted
                }

                Image {
                    id: cover
                    anchors.fill: parent
                    visible: status === Image.Ready
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(336, 336)
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
                    wrapMode: media.large ? Text.Wrap : Text.NoWrap
                    maximumLineCount: media.large ? 3 : 1
                    color: Theme.textBright
                    font.family: Theme.font
                    font.pixelSize: media.large ? 19 : 15
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: [media.player?.trackArtist, media.player?.trackAlbum].filter(Boolean).join(" · ")
                    elide: Text.ElideRight
                    color: Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: media.large ? 13 : 12
                }
                Caption {
                    Layout.fillWidth: true
                    visible: !media.compact
                    elide: Text.ElideRight
                    text: media.player
                        ? Media.nameOf(media.player).toLowerCase() + (media.player.length > 0 ? " · " + media.time(media.player.position) + " / " + media.time(media.player.length) : "")
                        : "abra algo no mpv, helium ou spotify"
                }
            }

            Rectangle {
                Layout.alignment: media.large ? Qt.AlignBottom : Qt.AlignVCenter
                implicitWidth: 46
                implicitHeight: 46
                radius: 23
                color: media.player ? Theme.purple : Theme.track

                Icon {
                    anchors.centerIn: parent
                    name: media.playing ? "pause" : "play"
                    size: 19
                    color: media.player ? Theme.onAccent : Theme.textFaint
                }

                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: if (media.player?.canTogglePlaying) media.player.togglePlaying() }
            }
        }

        // Mais de um player: um chip por player; o escolhido fica fixo até
        // outro começar a tocar.
        Flow {
            Layout.fillWidth: true
            visible: media.players.length > 1 && !media.compact
            spacing: 6

            Repeater {
                model: media.players

                Rectangle {
                    id: playerChip
                    required property MprisPlayer modelData
                    readonly property bool current: modelData === media.player

                    implicitWidth: chipRow.implicitWidth + 16
                    implicitHeight: 24
                    radius: 12
                    color: current ? Theme.purple : chipHover.hovered ? Theme.raised : Theme.track

                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 5

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: playerChip.modelData.isPlaying ? "play" : "pause"
                            size: 10
                            color: playerChip.current ? Theme.onAccent : Theme.textMuted
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Media.nameOf(playerChip.modelData).toLowerCase()
                            color: playerChip.current ? Theme.onAccent : Theme.text
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
                    }

                    HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: Media.choose(playerChip.modelData) }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Pequeno: o tempo fica acima da linha, já que o texto ao lado é curto.
        Caption {
            Layout.fillWidth: true
            visible: media.compact && media.player !== null && media.player.length > 0
            text: media.time(media.player?.position ?? 0) + " / " + media.time(media.player?.length ?? 0)
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

            // Progresso como no Android: o que falta é uma linha reta apagada; o
            // que já tocou ondula, com a amplitude seguindo o volume do cava (sem
            // cava, uma onda fixa) e achatando quando pausa.
            Canvas {
                id: wave

                Layout.fillWidth: true
                implicitHeight: 26
                property real progress: media.progress
                property real phase: 0
                property real amplitude: 0
                property real energy: 0
                readonly property real targetAmplitude: !media.playing ? 0
                    : Spectrum.live ? 1.5 + energy * 7 : 3.5
                onProgressChanged: requestPaint()
                onWidthChanged: requestPaint()

                FrameAnimation {
                    running: root.shown && wave.visible && (media.playing || wave.amplitude > 0.05)
                    onTriggered: {
                        const dt = Math.min(0.05, frameTime)
                        // Suaviza o nível: sobe rápido, desce devagar.
                        const level = Spectrum.level
                        wave.energy += (level - wave.energy) * Math.min(1, dt * (level > wave.energy ? 18 : 6))
                        wave.amplitude += (wave.targetAmplitude - wave.amplitude) * Math.min(1, dt * 8)
                        if (media.playing) wave.phase = (wave.phase + dt * 7) % (Math.PI * 2)
                        wave.requestPaint()
                    }
                }

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const mid = height / 2
                    const cut = Math.max(0, Math.min(width, width * progress))
                    const wavelength = 26

                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"

                    // O resto da música, reto, depois de um respiro após o cursor.
                    if (cut + 8 < width) {
                        ctx.strokeStyle = "#3D4657"
                        ctx.lineWidth = 3
                        ctx.beginPath()
                        ctx.moveTo(cut + 8, mid)
                        ctx.lineTo(width, mid)
                        ctx.stroke()
                    }

                    // O que já tocou: senoide com a fase andando para a direita.
                    if (cut > 2) {
                        ctx.strokeStyle = "" + Theme.purple
                        ctx.lineWidth = 3
                        ctx.beginPath()
                        for (let x = 0; x <= cut; x += 2) {
                            // Encosta na linha perto do começo e do cursor.
                            const ease = Math.min(1, x / 12, (cut - x) / 12 + 0.25)
                            const y = mid + Math.sin(x * Math.PI * 2 / wavelength - phase) * amplitude * ease
                            if (x === 0) ctx.moveTo(x, y)
                            else ctx.lineTo(x, y)
                        }
                        ctx.stroke()
                    }

                    // Cursor em pílula vertical.
                    ctx.fillStyle = "" + Theme.purple
                    ctx.beginPath()
                    ctx.roundedRect(Math.max(0, cut - 2.5), mid - 9, 5, 18, 2.5, 2.5)
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
        id: weather

        key: "weather"
        title: Weather.place || "clima"
        action: "weathr ↗"
        onActionClicked: {
            root.terminal(["weathr"], "weathr")
            ShellState.close()
        }

        // Pequeno: agora em cima e as próximas horas embaixo; largo: lado a lado.
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: weather.compact ? 1 : 2
            columnSpacing: 24
            rowSpacing: 10

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 12
                Icon { name: Weather.icon; size: weather.compact ? 36 : 46; color: Weather.color }
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: Weather.ready ? Weather.temperature + "°" : "--°"
                        color: Theme.textBright
                        font.family: Theme.font
                        font.pixelSize: weather.compact ? 26 : 32
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
                Layout.alignment: Qt.AlignVCenter
                spacing: weather.compact ? 6 : 10

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
    }

    // ── energia ──────────────────────────────────────────────────────────

    component EnergyCard: Card {
        id: energy

        key: "energy"
        title: "energia"
        action: Net.hasBattery ? Math.round(Net.batteryPercent) + "%" + (Net.batteryTime && !energy.compact ? " · " + Net.batteryTime : "") : ""
        actionColor: Net.batteryColor
        gap: 11

        readonly property var profiles: [
            { label: "economia", icon: "leaf", profile: PowerProfile.PowerSaver },
            { label: "equilíbrio", icon: "scales", profile: PowerProfile.Balanced },
            { label: "desempenho", icon: "rocket-launch", profile: PowerProfile.Performance }
        ]

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: energy.compact ? 1 : 2
            columnSpacing: 24
            rowSpacing: 11

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignVCenter
                spacing: 11

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
            }

            // Perfis: só ícones no pequeno, com nome no largo.
            GridLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignVCenter
                columns: energy.compact ? 3 : 1
                columnSpacing: 7
                rowSpacing: 7

                Repeater {
                    model: energy.profiles

                    Rectangle {
                        required property var modelData
                        readonly property bool active: PowerProfiles.profile === modelData.profile

                        Layout.fillWidth: true
                        implicitHeight: 30
                        radius: 14
                        color: active ? Theme.yellow : profileHover.hovered ? Theme.dimmer : Theme.track

                        Row {
                            anchors.centerIn: parent
                            spacing: 7
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: parent.parent.modelData.icon
                                size: 13
                                color: parent.parent.active ? Theme.onAccent : Theme.textMuted
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !energy.compact
                                text: parent.parent.modelData.label
                                color: parent.parent.active ? Theme.onAccent : Theme.textMuted
                                font.family: Theme.font
                                font.pixelSize: 11
                            }
                        }

                        HoverHandler { id: profileHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: PowerProfiles.profile = parent.modelData.profile }
                    }
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

        // Semana do dia escolhido, para os tamanhos de uma linha.
        readonly property var week: {
            const start = new Date(selected.getFullYear(), selected.getMonth(), selected.getDate() - selected.getDay())
            const list = []
            for (let i = 0; i < 7; i++) list.push(new Date(start.getFullYear(), start.getMonth(), start.getDate() + i))
            return list
        }
        // Eventos que cabem embaixo da semana (cabeçalho 16 + faixa 40).
        readonly property int weekCapacity: Math.max(0, Math.floor((bodyHeight - 16 - 40 - 2 * 10 + 6) / (18 + 6)))
        // Sobrando eventos, a última linha vira o "+n".
        readonly property int weekShown: selectedEvents.length > weekCapacity ? weekCapacity - 1 : selectedEvents.length

        function shiftWeek(delta: int): void {
            selected = new Date(selected.getFullYear(), selected.getMonth(), selected.getDate() + delta * 7)
            month = new Date(selected.getFullYear(), selected.getMonth(), 1)
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: !calendar.large
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 16
                spacing: 8
                Caption {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: calendar.selectedToday ? Theme.date(calendar.selected, "MMMM") + " · hoje" : Theme.date(calendar.selected, "dd MMM")
                }
                Icon {
                    name: "caret-left"; size: 11; color: Theme.textFaint
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { margin: 6; onTapped: calendar.shiftWeek(-1) }
                }
                Icon {
                    name: "caret-right"; size: 11; color: Theme.textFaint
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { margin: 6; onTapped: calendar.shiftWeek(1) }
                }
                Link {
                    visible: !calendar.compact
                    text: "calcure ↗"
                    onClicked: {
                        root.terminal(["calcure"], "calcure")
                        ShellState.close()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: calendar.week

                    Rectangle {
                        id: weekDay
                        required property date modelData
                        readonly property bool today: Agenda.sameDay(modelData, Agenda.today)
                        readonly property bool picked: Agenda.sameDay(modelData, calendar.selected)

                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: 13
                        color: today ? Theme.yellow : picked ? Theme.track : weekHover.hovered ? Theme.raisedAlt : "transparent"

                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: ["d", "s", "t", "q", "q", "s", "s"][weekDay.modelData.getDay()]
                                color: weekDay.today ? Theme.onAccent : Theme.textGhost
                                font.family: Theme.font
                                font.pixelSize: 9
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: weekDay.modelData.getDate()
                                color: weekDay.today ? Theme.onAccent : Agenda.hasEvents(weekDay.modelData) ? Theme.cyan : Theme.textMuted
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                        }

                        HoverHandler { id: weekHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: calendar.selected = weekDay.modelData }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: calendar.selectedEvents.slice(0, calendar.weekShown)

                    RowLayout {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: 18
                        spacing: 8

                        Rectangle {
                            implicitWidth: 3
                            implicitHeight: 14
                            radius: 2
                            color: [Theme.purple, Theme.cyan, Theme.green, Theme.orange][index % 4]
                        }
                        Caption { text: modelData.time || "dia" }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.title
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }
                }

                Caption {
                    visible: calendar.selectedEvents.length !== calendar.weekShown || calendar.selectedEvents.length === 0
                    text: calendar.selectedEvents.length === 0 ? "nada marcado"
                        : "+" + (calendar.selectedEvents.length - calendar.weekShown) + " no calcure"
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            visible: calendar.large
            columns: 3
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

            Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.track }

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
        id: system

        key: "system"
        title: "sistema"
        action: "btop ↗"
        gap: 8
        onActionClicked: {
            root.terminal(["btop"], "btop")
            ShellState.close()
        }

        // Valores lidos por função: o modelo do Repeater é fixo, então as
        // barras continuam de onde estavam em vez de recriar e vir do zero.
        function meter(name: string): var {
            switch (name) {
            case "cpu": return { label: "cpu", value: SysInfo.cpu / 100, text: Math.round(SysInfo.cpu) + "%", color: Theme.cyan }
            case "memory": return { label: "memória", value: SysInfo.memory / 100, text: SysInfo.memoryUsedGiB.toFixed(1) + "/" + Math.round(SysInfo.memoryTotalGiB) + "G", color: Theme.green }
            case "disk": return { label: "disco /", value: SysInfo.disk / 100, text: Math.round(SysInfo.diskUsedGiB) + "/" + Math.round(SysInfo.diskTotalGiB) + "G", color: Theme.purple }
            }
            return { label: "temp", value: SysInfo.temperature / 100, text: SysInfo.temperature + "°c", color: Theme.orange }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: system.compact ? 1 : 2
            columnSpacing: 24
            rowSpacing: system.compact ? 8 : 18

            Repeater {
                model: ["cpu", "memory", "disk", "temp"]

                ColumnLayout {
                    required property string modelData
                    readonly property var info: system.meter(modelData)

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: info.label; color: Theme.textMuted; font.family: Theme.font; font.pixelSize: 11 }
                        Item { Layout.fillWidth: true }
                        Text { text: info.text; color: info.color; font.family: Theme.font; font.pixelSize: 11 }
                    }
                    Level { value: info.value; accent: info.color }
                }
            }
        }
    }

    // ── alarmes & timers ─────────────────────────────────────────────────

    component TimersCard: Card {
        id: timersCard

        key: "timers"
        title: "alarmes & timers" + (hidden > 0 ? " · +" + hidden : "")
        property bool adding: false
        property string error: ""
        actionIcon: adding ? "x" : "plus"
        onActionClicked: adding = !adding
        onAddingChanged: {
            error = ""
            if (adding) alarmInput.forceActiveFocus()
        }

        // Quantas linhas (de 40) cabem; no largo, em duas colunas.
        readonly property int columns: size === "wide" ? 2 : 1
        readonly property real listHeight: bodyHeight - (adding ? addForm.implicitHeight + gap : 0)
        readonly property int capacity: Math.max(0, Math.floor((listHeight + 6) / (40 + 6))) * columns
        readonly property var shownTimers: Timers.timers.slice(0, capacity)
        readonly property var shownAlarms: Timers.alarms.slice(0, Math.max(0, capacity - shownTimers.length))
        readonly property int hidden: Timers.items.length - shownTimers.length - shownAlarms.length

        // Novo timer/alarme.
        ColumnLayout {
            id: addForm
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
                border.color: timersCard.error !== "" ? Theme.red : "transparent"

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
                    clip: true
                    onTextChanged: timersCard.error = ""
                    // Inválido: mantém o texto e mostra o motivo, em vez de sumir.
                    onAccepted: {
                        const error = Timers.create(text)
                        if (error !== "") {
                            timersCard.error = error
                            return
                        }
                        text = ""
                        timersCard.adding = false
                    }
                    Keys.onEscapePressed: timersCard.adding = false

                    Text {
                        visible: parent.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: timersCard.compact ? "7h30 acordar · 10m ↵" : "alarme 06:40 acordar · timer 10m chá ↵"
                        color: Theme.textGhost
                        font: parent.font
                    }
                }
            }

            Caption {
                visible: timersCard.error !== ""
                text: timersCard.error
                color: Theme.red
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: timersCard.columns
            columnSpacing: 8
            rowSpacing: 6

            Repeater {
                model: timersCard.shownTimers

                Rectangle {
                    id: timerRow
                    required property var modelData
                    readonly property real remainingMs: Timers.remaining(modelData)

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 40
                    radius: 15
                    color: Theme.track

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 11
                        anchors.rightMargin: 7
                        spacing: 9

                        Icon { name: "timer"; size: 16; color: Theme.green }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                text: Timers.clock(timerRow.remainingMs)
                                color: Theme.textBright
                                font.family: Theme.font
                                font.pixelSize: 13
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
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: 13
                            color: Theme.green
                            Icon {
                                anchors.centerIn: parent
                                name: timerRow.modelData.paused ? "play" : "pause"
                                size: 11
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
                model: timersCard.shownAlarms

                Item {
                    id: alarmRow
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 40

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
        }

        Text {
            visible: Timers.items.length === 0 && !timersCard.adding
            text: "nenhum timer · + para criar"
            color: Theme.textGhost
            font.family: Theme.font
            font.pixelSize: 12
        }

        Item { Layout.fillHeight: true }
    }

    // ── tarefas + rascunho ───────────────────────────────────────────────

    component NotesCard: Card {
        id: notes

        key: "notes"

        readonly property var tasks: Store.data.tasks ?? []
        readonly property int doneCount: tasks.filter(task => task.done).length
        // Abertas primeiro; as feitas mais recentes logo abaixo.
        // Linhas de 17 + 8 que cabem entre o cabeçalho e o campo de nova tarefa.
        readonly property int capacity: Math.max(0, Math.floor((bodyHeight - 2 * (17 + 8) + 8) / (17 + 8)))
        readonly property var ordered: [...tasks.map((task, index) => ({ task, index }))]
            .sort((a, b) => Number(a.task.done) - Number(b.task.done))
            .slice(0, capacity)

        function setTasks(list: var): void {
            Store.data.tasks = list
            Store.save()
        }

        // Pequeno: só as tarefas; nos maiores, o rascunho ao lado.
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: notes.compact ? 1 : 3
            columnSpacing: 20
            rowSpacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 17
                    Caption { text: "tarefas" }
                    Item { Layout.fillWidth: true }
                    Caption {
                        text: (notes.tasks.length > notes.ordered.length ? "+" + (notes.tasks.length - notes.ordered.length) + " · " : "")
                            + notes.doneCount + " / " + notes.tasks.length
                    }
                }

                Repeater {
                    model: notes.ordered

                    RowLayout {
                        id: taskRow
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 17
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
                    Layout.preferredHeight: 17
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

                Item { Layout.fillHeight: true }
            }

            Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.track; visible: !notes.compact }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                visible: !notes.compact
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
                    Layout.fillHeight: true
                    clip: true
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
            font.pixelSize: world.compact ? 26 : 30
            font.letterSpacing: -0.5
        }

        Item { Layout.fillHeight: true }

        GridLayout {
            Layout.fillWidth: true
            columns: world.compact ? 1 : 2
            columnSpacing: 24
            rowSpacing: world.compact ? 4 : 8

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

        // Modelo fixo, como no sistema: as barras não recomeçam do zero.
        function limit(name: string): var {
            return name === "claude"
                ? { label: "claude · 5h", limit: AiUsage.claudeSession, available: AiUsage.claudeAvailable, color: Theme.orange }
                : { label: "codex · 5h", limit: AiUsage.codexPrimary, available: AiUsage.codexAvailable, color: Theme.green }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: ai.compact ? 1 : 2
            columnSpacing: 24
            rowSpacing: 12

            Repeater {
                model: ["claude", "codex"]

                ColumnLayout {
                    id: limitItem
                    required property string modelData
                    readonly property var info: ai.limit(modelData)
                    readonly property real value: info.available ? AiUsage.percent(info.limit) : -1

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: limitItem.info.label; color: Theme.textMuted; font.family: Theme.font; font.pixelSize: 11 }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: limitItem.info.available ? AiUsage.percentText(limitItem.info.limit) : "sem dados"
                            color: limitItem.value >= 90 ? Theme.red : limitItem.info.color
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
                    }
                    Level { value: Math.max(0, limitItem.value) / 100; accent: limitItem.value >= 90 ? Theme.red : limitItem.info.color }
                    Caption {
                        visible: limitItem.info.available && limitItem.info.limit !== null
                        text: AiUsage.resetText(limitItem.info.limit)
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

        Item { Layout.fillHeight: true }
    }
}
