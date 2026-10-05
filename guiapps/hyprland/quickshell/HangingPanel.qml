import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Painel que "pendura" da barra: sem borda em cima, cantos inferiores
// arredondados, desce e aparece em ~160 ms. Clique fora ou Esc fecha.
PanelWindow {
    id: win

    required property string name
    property int panelWidth: 420
    property int padding: 20
    property int topPadding: 30
    // "left" usa marginLeft; "right" usa marginRight; "center" centraliza.
    property string side: "left"
    property int marginLeft: 120
    property int marginRight: 22
    property bool hanging: true
    property int topOffset: hanging ? Theme.hangTop : Theme.barBottom + 14
    property bool wantsKeyboard: false
    default property alias content: body.data

    readonly property bool shown: ShellState.panel === name

    signal opened

    screen: ShellState.screen
    visible: shown || card.opacity > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "fuleco-" + name
    WlrLayershell.keyboardFocus: shown && wantsKeyboard ? WlrKeyboardFocus.Exclusive : shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        left: side !== "right"
        right: side === "right"
    }

    margins {
        top: topOffset
        left: side === "center" ? Math.max(0, ((screen?.width ?? 1920) - panelWidth) / 2) : side === "left" ? marginLeft : 0
        right: side === "right" ? marginRight : 0
    }

    implicitWidth: panelWidth
    implicitHeight: body.implicitHeight + (hanging ? topPadding : padding) + padding + 2

    onShownChanged: if (shown) opened()

    HyprlandFocusGrab {
        active: win.shown
        windows: [win, ...ShellState.barWindows]
        onCleared: if (win.shown) ShellState.close()
    }

    Rectangle {
        id: card

        width: win.panelWidth
        height: win.implicitHeight
        y: win.shown ? 0 : -14
        opacity: win.shown ? 1 : 0
        color: Theme.surface
        border.color: Theme.surfaceBorder
        radius: 26
        topLeftRadius: win.hanging ? 0 : 26
        topRightRadius: win.hanging ? 0 : 26

        Behavior on y { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }

        // Esconde a borda de cima para fundir com a barra.
        Rectangle {
            visible: win.hanging
            x: 1
            width: parent.width - 2
            height: 2
            color: Theme.surface
        }

        Item {
            id: body

            focus: true
            x: win.padding
            y: win.hanging ? win.topPadding : win.padding
            width: win.panelWidth - 2 * win.padding
            implicitHeight: childrenRect.height
            Keys.onEscapePressed: ShellState.close()
        }
    }
}
