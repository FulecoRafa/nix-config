import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Popups no canto superior direito e o painel de notificações (sino).
Scope {
    id: root

    readonly property bool centerOpen: ShellState.panel === "notifications"

    // Popups: somem em 6 s (críticas ficam até serem tocadas).
    PanelWindow {
        id: popups

        screen: ShellState.focusedScreen()
        visible: NotifService.popups.length > 0 && !root.centerOpen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "fuleco-notification-popups"
        implicitWidth: 352
        implicitHeight: popupColumn.implicitHeight

        anchors {
            top: true
            right: true
        }

        margins {
            top: Theme.barBottom + 14
            right: 22
        }

        Column {
            id: popupColumn

            width: parent.width
            spacing: 10

            Repeater {
                model: NotifService.popups

                NotificationCard {
                    id: popupCard

                    required property var modelData

                    notification: modelData
                    popup: true
                    width: popupColumn.width
                    onClosed: NotifService.dropPopup(modelData)

                    opacity: 0
                    x: 40
                    Component.onCompleted: {
                        opacity = 1
                        x = 0
                    }
                    Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                    Behavior on x { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }

                    Timer {
                        running: popupCard.modelData?.urgency !== 2
                        interval: 6000
                        onTriggered: NotifService.dropPopup(popupCard.modelData)
                    }

                    Connections {
                        target: popupCard.modelData
                        function onClosed() { NotifService.dropPopup(popupCard.modelData) }
                    }
                }
            }
        }
    }

    // Painel com o histórico.
    PanelWindow {
        id: center

        screen: ShellState.screen
        visible: root.centerOpen || list.opacity > 0
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "fuleco-notifications"
        WlrLayershell.keyboardFocus: root.centerOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        implicitWidth: 352
        implicitHeight: Math.min(list.implicitHeight, (screen?.height ?? 1080) - Theme.barBottom - 40)

        anchors {
            top: true
            right: true
        }

        margins {
            top: Theme.barBottom + 14
            right: 22
        }

        HyprlandFocusGrab {
            active: root.centerOpen
            windows: [center, ...ShellState.barWindows]
            onCleared: if (root.centerOpen) ShellState.close()
        }

        Flickable {
            id: list

            anchors.fill: parent
            contentHeight: column.implicitHeight
            implicitHeight: column.implicitHeight
            clip: true
            opacity: root.centerOpen ? 1 : 0
            focus: root.centerOpen
            Keys.onEscapePressed: ShellState.close()

            Behavior on opacity { NumberAnimation { duration: Theme.fast } }

            transform: Translate {
                x: root.centerOpen ? 0 : 30
                Behavior on x { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }
            }

            Column {
                id: column

                width: list.width
                spacing: 10

                // Cabeçalho: notificações · não perturbe · limpar tudo
                Rectangle {
                    width: parent.width
                    height: 38
                    radius: 19
                    color: Theme.surface
                    border.color: Theme.surfaceBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        Text {
                            text: "notificações"
                            color: Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: 11
                        }

                        Item { Layout.fillWidth: true }

                        Row {
                            spacing: 6

                            Icon {
                                name: NotifService.dnd ? "bell-slash" : "bell-simple"
                                size: 13
                                color: NotifService.dnd ? Theme.yellow : Theme.textFaint
                            }

                            Text {
                                text: "não perturbe"
                                color: NotifService.dnd ? Theme.yellow : Theme.textFaint
                                font.family: Theme.font
                                font.pixelSize: 11
                            }

                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: NotifService.dnd = !NotifService.dnd }
                        }

                        Text {
                            text: "limpar tudo"
                            color: clearHover.hovered ? Theme.text : Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: 11

                            HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: NotifService.clearAll() }
                        }
                    }
                }

                Repeater {
                    model: NotifService.list

                    NotificationCard {
                        required property var modelData
                        notification: modelData
                        width: column.width
                    }
                }

                Rectangle {
                    visible: NotifService.count === 0
                    width: parent.width
                    height: 92
                    radius: 22
                    color: Theme.surface
                    border.color: Theme.surfaceBorder

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: "bell-simple-z"
                            size: 22
                            color: Theme.dim
                        }

                        Text {
                            text: "nada por aqui"
                            color: Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }
}
