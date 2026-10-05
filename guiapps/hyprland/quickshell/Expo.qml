import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Exposé: todas as janelas do workspace em grade, com miniaturas ao vivo.
// Abre com Super+Tab ou três dedos para cima; setas/Enter escolhem, Esc
// ou três dedos para baixo fecham. As pílulas no topo trocam de workspace.
// App Exposé (três dedos para baixo, Super+` ou clique direito num app da
// barra): as janelas de um app só, de todos os workspaces.
Scope {
    id: root

    property bool shown: false
    property int index: 0
    property var items: []
    property ShellScreen screen: ShellState.focusedScreen()
    readonly property int workspaceId: Hyprland.focusedWorkspace?.id ?? -1
    // Regex do app no App Exposé; vazio = exposé do workspace.
    property string appPattern: ""
    readonly property bool appMode: appPattern !== ""
    readonly property var appEntry: appMode && items.length > 0
        ? root.entryFor(items[0].wayland?.appId ?? items[0].lastIpcObject?.class ?? "")
        : null

    // PWAs têm o .desktop com o mesmo nome da classe; o resto, por heurística.
    function entryFor(id: string): var {
        return id === "" ? null : DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id)
    }

    // A seleção segue a janela, não a posição: o refreshToplevels logo depois
    // de abrir recarrega a lista e a escolhida não pode voltar para a primeira.
    property string selected: ""
    property bool reloading: false
    onIndexChanged: if (!reloading && items[index]) selected = items[index].address

    function reload(): void {
        reloading = true
        items = appMode ? Windows.ofApp(appPattern) : Windows.current()
        const found = items.findIndex(toplevel => toplevel.address === selected)
        index = found >= 0 ? found : Math.min(index, Math.max(0, items.length - 1))
        reloading = false
    }

    function open(): void {
        if (shown && !appMode) return
        start("")
    }

    function start(pattern: string): void {
        ShellState.close()
        Hyprland.refreshToplevels()
        screen = ShellState.focusedScreen()
        appPattern = pattern
        selected = ""
        index = 0
        reload()
        // A atual é a primeira; com mais de uma, já aponta para a anterior.
        const first = appMode && items.length > 1 ? 1 : 0
        selected = items[first]?.address ?? ""
        index = first
        shown = true
    }

    function openApp(pattern: string): void {
        if (shown && appPattern === pattern) {
            close()
            return
        }
        start(pattern)
    }

    // App da janela em foco; sem janela, o exposé do workspace.
    function openActiveApp(): void {
        const active = Hyprland.activeToplevel
        const id = active?.wayland?.appId ?? active?.lastIpcObject?.class ?? ""
        if (id === "") open()
        else openApp("^" + id.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "$")
    }

    Connections {
        target: ShellState
        function onAppExposeRequested(pattern) { root.openApp(pattern) }
    }

    function close(): void {
        shown = false
    }

    function choose(toplevel: HyprlandToplevel): void {
        shown = false
        Windows.focus(toplevel)
    }

    function move(dx: int, dy: int): void {
        if (items.length === 0) return
        const next = index + dx + dy * grid.columns
        if (next >= 0 && next < items.length) index = next
    }

    // A lista acompanha janelas que abrem/fecham e a troca de workspace.
    onWorkspaceIdChanged: if (shown && !appMode) reload()
    Connections {
        target: Hyprland.toplevels
        enabled: root.shown
        function onValuesChanged() { root.reload() }
    }

    IpcHandler {
        target: "expo"

        function open(): void { root.open() }
        function close(): void { root.close() }
        function toggle(): void {
            if (root.shown) root.close()
            else root.open()
        }
        // App Exposé do app em foco (abre/fecha).
        function app(): void {
            if (root.shown && root.appMode) root.close()
            else root.openActiveApp()
        }
        // Três dedos para baixo: fecha o exposé aberto ou abre o App Exposé.
        function down(): void {
            if (root.shown) root.close()
            else root.openActiveApp()
        }
    }

    PanelWindow {
        id: win

        screen: root.screen
        visible: root.shown || backdrop.opacity > 0
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "fuleco-expo"
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            id: backdrop

            anchors.fill: parent
            color: Qt.rgba(0.07, 0.08, 0.11, 0.92)
            opacity: root.shown ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }

        Item {
            id: content

            anchors.fill: parent
            anchors.margins: 48
            anchors.topMargin: Theme.barBottom + 18
            opacity: backdrop.opacity
            scale: 0.96 + 0.04 * backdrop.opacity
            focus: root.shown

            Keys.onEscapePressed: root.close()
            Keys.onLeftPressed: root.move(-1, 0)
            Keys.onRightPressed: root.move(1, 0)
            Keys.onUpPressed: root.move(0, -1)
            Keys.onDownPressed: root.move(0, 1)
            Keys.onTabPressed: if (root.items.length > 0) root.index = (root.index + 1) % root.items.length
            Keys.onBacktabPressed: if (root.items.length > 0) root.index = (root.index - 1 + root.items.length) % root.items.length
            Keys.onReturnPressed: if (root.items.length > 0) root.choose(root.items[root.index])
            Keys.onEnterPressed: if (root.items.length > 0) root.choose(root.items[root.index])
            Keys.onPressed: event => {
                // Super+Tab de novo, ou 1–9 para ir direto a um workspace.
                if (event.key === Qt.Key_Tab && (event.modifiers & Qt.MetaModifier)) {
                    root.close()
                    event.accepted = true
                } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                    Hyprland.dispatch("workspace " + (event.key - Qt.Key_0))
                    event.accepted = true
                }
            }

            // App Exposé: ícone, nome e quantas janelas no lugar das pílulas.
            Row {
                visible: root.appMode
                anchors.verticalCenter: pills.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    sourceSize: Qt.size(64, 64)
                    source: Quickshell.iconPath(root.appEntry?.icon ?? (root.items[0]?.wayland?.appId ?? ""), "application-x-executable")
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.appEntry?.name ?? root.items[0]?.wayland?.appId ?? "app")
                        + "  ·  " + root.items.length + (root.items.length === 1 ? " janela" : " janelas")
                    color: Theme.textBright
                    font.family: Theme.font
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
            }

            // Pílulas dos workspaces.
            Row {
                id: pills

                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                opacity: root.appMode ? 0 : 1
                enabled: !root.appMode

                Repeater {
                    model: Hyprland.workspaces.values.filter(ws => ws.id > 0 && ws.monitor?.name === root.screen?.name)

                    Rectangle {
                        required property HyprlandWorkspace modelData
                        readonly property bool current: modelData.id === root.workspaceId
                        readonly property int count: Hyprland.toplevels.values.filter(t => t.workspace?.id === modelData.id).length

                        width: label.implicitWidth + 28
                        height: 34
                        radius: 17
                        color: current ? Theme.yellow : pillMouse.containsMouse ? Theme.raised : Theme.surface
                        border.color: current ? Theme.yellow : Theme.surfaceBorder

                        Behavior on color { ColorAnimation { duration: Theme.fast } }

                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: parent.modelData.id + (parent.count > 0 ? "  ·  " + parent.count : "")
                            color: parent.current ? Theme.onAccent : Theme.text
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: pillMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Hyprland.dispatch("workspace " + parent.modelData.id)
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: area
                visible: root.items.length === 0
                text: root.appMode ? "Nenhuma janela deste app" : "Nenhuma janela neste workspace"
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: 16
            }

            // Área da grade: as células dividem o espaço e cada miniatura
            // ocupa o que a proporção da janela permite dentro da sua.
            Item {
                id: area

                anchors.top: pills.bottom
                anchors.topMargin: 32
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                Grid {
                    id: grid

                    readonly property int count: root.items.length
                    readonly property real gap: 28
                    // Colunas que deixam as células mais perto de 16:10.
                    columns: {
                        let best = 1, bestScore = -1
                        for (let c = 1; c <= Math.max(1, count); c++) {
                            const r = Math.ceil(count / c)
                            const w = (area.width - gap * (c - 1)) / c
                            const h = (area.height - gap * (r - 1)) / r - 30
                            const score = Math.min(w, h * 1.6)
                            if (score > bestScore) { bestScore = score; best = c }
                        }
                        return best
                    }
                    readonly property int rowCount: Math.max(1, Math.ceil(count / columns))
                    readonly property real cellWidth: Math.min(640, (area.width - gap * (columns - 1)) / columns)
                    readonly property real cellHeight: Math.min(420, (area.height - gap * (rowCount - 1)) / rowCount - 30)

                    anchors.centerIn: parent
                    spacing: gap
                    horizontalItemAlignment: Grid.AlignHCenter
                    verticalItemAlignment: Grid.AlignVCenter

                    Repeater {
                        model: root.items

                        WindowThumb {
                            required property var modelData
                            required property int index
                            toplevel: modelData
                            maxWidth: grid.cellWidth
                            maxHeight: grid.cellHeight
                            selected: index === root.index
                            note: root.appMode ? "ws " + (modelData.workspace?.name?.startsWith("special:floats-")
                                ? modelData.workspace.name.slice(15) + " (escondida)"
                                : modelData.workspace?.name ?? "?") : ""
                            onHovered: root.index = index
                            onClicked: root.choose(modelData)
                        }
                    }
                }
            }
        }
    }
}
