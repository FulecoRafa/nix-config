import QtQuick

// Pílula de abas/escopo: amarela quando ativa.
Rectangle {
    id: chip

    property string label
    property bool active: false
    property int fontSize: 12
    signal clicked

    implicitWidth: text.implicitWidth + 28
    implicitHeight: text.implicitHeight + 14
    radius: height / 2
    color: active ? Theme.yellow : hover.hovered ? Theme.track : Theme.raised

    Behavior on color { ColorAnimation { duration: Theme.fast } }

    Text {
        id: text
        anchors.centerIn: parent
        text: chip.label
        color: chip.active ? Theme.onAccent : Theme.textMuted
        font.family: Theme.font
        font.pixelSize: chip.fontSize
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: chip.clicked() }
}
