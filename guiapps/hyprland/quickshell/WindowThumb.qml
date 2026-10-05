import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Miniatura ao vivo de uma janela do Hyprland (Alt+Tab e exposé): captura
// da janela, ícone do app e título. A largura sai da proporção da janela.
Item {
    id: thumb

    required property HyprlandToplevel toplevel
    property bool selected: false
    property real maxWidth: 360
    property real maxHeight: 220
    property bool showTitle: true
    // Texto extra depois do título (o workspace, no App Exposé).
    property string note: ""
    signal clicked
    signal hovered

    readonly property var ipc: toplevel?.lastIpcObject ?? ({})
    readonly property string appClass: ipc.class ?? ""
    readonly property var entry: appClass !== "" ? DesktopEntries.heuristicLookup(appClass) : null
    readonly property real aspect: {
        const size = ipc.size
        return size && size[1] > 0 ? size[0] / size[1] : 16 / 10
    }
    readonly property real frameWidth: Math.min(maxWidth, maxHeight * aspect)
    readonly property real frameHeight: frameWidth / aspect

    implicitWidth: frameWidth
    implicitHeight: frameHeight + (showTitle ? 30 : 0)

    Rectangle {
        id: frame

        width: thumb.frameWidth
        height: thumb.frameHeight
        radius: 14
        color: Theme.sunken
        border.width: thumb.selected ? 3 : 1
        border.color: thumb.selected ? Theme.yellow : mouse.containsMouse ? Theme.dim : Theme.surfaceBorder
        scale: thumb.selected ? 1.03 : mouse.containsMouse ? 1.015 : 1

        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }

        ScreencopyView {
            id: capture

            anchors.fill: parent
            anchors.margins: 4
            captureSource: thumb.toplevel?.wayland ?? null
            live: true
            constraintSize: Qt.size(width, height)
            layer.enabled: true
        }

        // Sem captura (ainda), o ícone grande no lugar.
        Image {
            anchors.centerIn: parent
            visible: !capture.hasContent
            width: Math.min(64, parent.height * 0.4)
            height: width
            sourceSize: Qt.size(128, 128)
            source: Quickshell.iconPath(thumb.entry?.icon ?? thumb.appClass, "application-x-executable")
        }

        // Ícone do app no canto, por cima da captura.
        Rectangle {
            visible: capture.hasContent
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 8
            width: 34
            height: 34
            radius: 11
            color: Theme.surface
            border.color: Theme.surfaceBorder

            Image {
                anchors.centerIn: parent
                width: 22
                height: 22
                sourceSize: Qt.size(64, 64)
                source: Quickshell.iconPath(thumb.entry?.icon ?? thumb.appClass, "application-x-executable")
            }
        }
    }

    Text {
        visible: thumb.showTitle
        anchors.top: frame.bottom
        anchors.topMargin: 9
        anchors.horizontalCenter: frame.horizontalCenter
        width: Math.min(implicitWidth, frame.width)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: (thumb.toplevel?.title || thumb.entry?.name || thumb.appClass) + (thumb.note !== "" ? "  ·  " + thumb.note : "")
        color: thumb.selected ? Theme.textBright : Theme.textMuted
        font.family: Theme.font
        font.pixelSize: 12
    }

    MouseArea {
        id: mouse
        anchors.fill: frame
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: thumb.clicked()
        onContainsMouseChanged: if (containsMouse) thumb.hovered()
    }
}
