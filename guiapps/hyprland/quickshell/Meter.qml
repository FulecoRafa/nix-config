import QtQuick

// Barra de nível (horizontal ou vertical). Clique/arraste ajusta o valor e a
// roda do mouse sobe/desce 5%.
Item {
    id: meter

    property real value: 0
    property color accent: Theme.yellow
    property color track: Theme.raised
    property bool vertical: false
    property bool interactive: true
    property int thickness: 8
    signal moved(real value)

    implicitWidth: vertical ? thickness : 120
    implicitHeight: vertical ? 120 : thickness

    Rectangle {
        anchors.fill: parent
        radius: Math.min(width, height) / 2 + 1
        color: meter.track
        clip: true

        Rectangle {
            readonly property real amount: Math.max(0, Math.min(1, meter.value))
            x: 0
            y: meter.vertical ? parent.height - height : 0
            width: meter.vertical ? parent.width : parent.width * amount
            height: meter.vertical ? parent.height * amount : parent.height
            radius: parent.radius
            color: meter.accent

            Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: Theme.fast } }
            Behavior on height { enabled: !drag.pressed; NumberAnimation { duration: Theme.fast } }
        }
    }

    function valueAt(x: real, y: real): real {
        const raw = vertical ? 1 - y / height : x / width
        return Math.max(0, Math.min(1, raw))
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        anchors.margins: -6
        enabled: meter.interactive
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => meter.moved(meter.valueAt(mouse.x - 6, mouse.y - 6))
        onPositionChanged: mouse => { if (pressed) meter.moved(meter.valueAt(mouse.x - 6, mouse.y - 6)) }
        onWheel: wheel => meter.moved(Math.max(0, Math.min(1, meter.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
