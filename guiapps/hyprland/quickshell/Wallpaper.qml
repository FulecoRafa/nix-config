import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    readonly property string source: Quickshell.env("HOME") + "/.local/share/backgrounds/fuleco.png"

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "fuleco-wallpaper"
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "#0a0e24"

            Image {
                anchors.fill: parent
                source: "file://" + root.source
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }

            // Mini widgets do desktop: clima e cpu/ram/°c. Clique abre a gaveta.
            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 22
                spacing: 10

                MiniCard {
                    RowLayout {
                        spacing: 12
                        Icon { name: Weather.icon; size: 24; color: Weather.color }
                        ColumnLayout {
                            spacing: 2
                            Text { text: Weather.ready ? Weather.temperature + "°" : "--°"; color: Theme.textBright; font.family: Theme.font; font.pixelSize: 14 }
                            Text { text: Weather.description || "clima"; color: Theme.textFaint; font.family: Theme.font; font.pixelSize: 11 }
                        }
                    }
                }

                MiniCard {
                    RowLayout {
                        spacing: 14
                        Repeater {
                            model: [
                                { label: "cpu", value: Math.round(SysInfo.cpu) + "%", color: Theme.cyan },
                                { label: "ram", value: Math.round(SysInfo.memory) + "%", color: Theme.green },
                                { label: "°c", value: SysInfo.temperature, color: Theme.orange }
                            ]
                            ColumnLayout {
                                required property var modelData
                                spacing: 3
                                Text { text: modelData.label; color: Theme.textFaint; font.family: Theme.font; font.pixelSize: 10 }
                                Text { text: modelData.value; color: modelData.color; font.family: Theme.font; font.pixelSize: 12 }
                            }
                        }
                    }
                }
            }
        }
    }

    component MiniCard: Rectangle {
        default property alias content: holder.data
        implicitWidth: holder.childrenRect.width + 32
        implicitHeight: Math.max(52, holder.childrenRect.height + 24)
        radius: 20
        color: Theme.surface
        border.color: Theme.surfaceBorder

        Item {
            id: holder
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: ShellState.open("drawer") }
    }
}
