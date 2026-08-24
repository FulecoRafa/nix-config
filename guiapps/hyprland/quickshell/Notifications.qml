import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Scope {
    id: root

    property var currentNotification: null

    NotificationServer {
        bodySupported: true
        keepOnReload: true

        onNotification: notification => {
            notification.tracked = true
            root.currentNotification = notification
            expiry.restart()
        }
    }

    Timer {
        id: expiry
        interval: 5000
        onTriggered: {
            if (root.currentNotification) root.currentNotification.expire()
            root.currentNotification = null
        }
    }

    PanelWindow {
        visible: root.currentNotification !== null
        implicitWidth: 360
        implicitHeight: 100
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            right: true
        }

        margins {
            top: 42
            right: 10
        }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "#202124"

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                Text {
                    width: parent.width
                    text: root.currentNotification?.summary || ""
                    color: "#e8eaed"
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.currentNotification?.body || ""
                    color: "#bdc1c6"
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.currentNotification?.dismiss()
                    root.currentNotification = null
                }
            }
        }
    }
}
