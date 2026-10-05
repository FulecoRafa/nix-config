import QtQuick

// Interruptor 30×17 do design.
Rectangle {
    id: toggle

    property bool checked: false
    property color accent: Theme.cyan
    signal toggled(bool checked)

    implicitWidth: 30
    implicitHeight: 17
    radius: 9
    color: checked ? accent : Theme.dimmer

    Behavior on color { ColorAnimation { duration: Theme.fast } }

    Rectangle {
        x: toggle.checked ? toggle.width - width - 2 : 2
        y: 2
        width: 13
        height: 13
        radius: 7
        color: toggle.checked ? Theme.onAccent : Theme.textMuted

        Behavior on x { NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }
    }

    TapHandler {
        margin: 6
        onTapped: toggle.toggled(!toggle.checked)
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
