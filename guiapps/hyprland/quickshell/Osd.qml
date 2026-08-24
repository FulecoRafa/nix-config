import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string message: ""

    IpcHandler {
        target: "osd"

        function show(message: string): void {
            root.message = message
            osd.visible = true
            expiry.restart()
        }
    }

    Timer {
        id: expiry
        interval: 1200
        onTriggered: osd.visible = false
    }

    PanelWindow {
        id: osd

        visible: false
        implicitWidth: 220
        implicitHeight: 54
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            bottom: true
        }

        margins.bottom: 48

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "#202124"

            Text {
                anchors.centerIn: parent
                text: root.message
                color: "#e8eaed"
            }
        }
    }
}
