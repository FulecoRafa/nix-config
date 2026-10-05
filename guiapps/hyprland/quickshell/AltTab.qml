import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Alt+Tab entre as janelas do workspace atual, com miniaturas ao vivo.
// O Hyprland manda os toques (GlobalShortcut alttab-next/-prev) e o
// `alttab commit` quando o Alt é solto; a janela escolhida recebe o foco.
Scope {
    id: root

    property bool shown: false
    property int index: 0
    // Lista congelada ao abrir: a ordem não muda enquanto o Alt está preso.
    property var items: []
    property ShellScreen screen: ShellState.focusedScreen()

    function step(delta: int): void {
        if (!shown) {
            Hyprland.refreshToplevels()
            screen = ShellState.focusedScreen()
            items = Windows.current()
            if (items.length === 0) return
            // Primeiro Tab: a janela anterior (a atual é a primeira).
            index = items.length > 1 ? (delta > 0 ? 1 : items.length - 1) : 0
            shown = true
            return
        }
        if (items.length > 0) index = (index + delta + items.length) % items.length
    }

    function commit(): void {
        if (!shown) return
        const toplevel = items[index]
        shown = false
        items = []
        Windows.focus(toplevel)
    }

    function cancel(): void {
        shown = false
        items = []
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "alttab-next"
        description: "Alt+Tab: próxima janela"
        onPressed: root.step(1)
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "alttab-prev"
        description: "Alt+Tab: janela anterior"
        onPressed: root.step(-1)
    }

    IpcHandler {
        target: "alttab"

        function next(): void { root.step(1) }
        function prev(): void { root.step(-1) }
        function commit(): void { root.commit() }
        function cancel(): void { root.cancel() }
    }

    PanelWindow {
        id: win

        screen: root.screen
        visible: root.shown
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "fuleco-alttab"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        implicitWidth: Math.min(strip.implicitWidth + 40, (screen?.width ?? 1920) - 80)
        implicitHeight: strip.implicitHeight + 40

        Rectangle {
            anchors.fill: parent
            radius: 26
            color: Theme.surface
            border.color: Theme.surfaceBorder

            Flickable {
                anchors.fill: parent
                anchors.margins: 20
                contentWidth: strip.implicitWidth
                contentHeight: strip.implicitHeight
                // Mantém a escolhida à vista quando a fileira não cabe.
                contentX: {
                    const item = row.children[root.index]
                    if (!item || strip.implicitWidth <= width) return 0
                    return Math.max(0, Math.min(strip.implicitWidth - width, item.x + item.width / 2 - width / 2))
                }
                interactive: false
                clip: true

                Item {
                    id: strip
                    implicitWidth: row.implicitWidth
                    implicitHeight: row.implicitHeight

                    Row {
                        id: row
                        spacing: 18

                        Repeater {
                            model: root.items

                            WindowThumb {
                                required property var modelData
                                required property int index
                                toplevel: modelData
                                maxWidth: 300
                                maxHeight: 180
                                selected: index === root.index
                                onHovered: root.index = index
                                onClicked: {
                                    root.index = index
                                    root.commit()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
