import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// Bandeja (StatusNotifier): ícones que os apps publicam, como o do Discord.
// Clique ativa, botão do meio faz a ação secundária e o direito abre o menu
// do app, desenhado aqui no estilo do shell.
Row {
    id: tray

    required property var window

    spacing: 10
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        Item {
            id: slot

            required property SystemTrayItem modelData

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 18
            implicitHeight: 22

            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                source: slot.modelData.icon
                opacity: hover.hovered ? 0.75 : 1
            }

            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }

            TapHandler {
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onTapped: (point, button) => {
                    const item = slot.modelData
                    if (button === Qt.MiddleButton) item.secondaryActivate()
                    else if (button === Qt.RightButton || item.onlyMenu) menu.toggle(item, slot)
                    else item.activate()
                }
            }

            WheelHandler {
                onWheel: event => slot.modelData.scroll(event.angleDelta.y, false)
            }
        }
    }

    // Menu do app: lista do QsMenuOpener; submenus empilham com "voltar".
    PopupWindow {
        id: menu

        property var item: null
        property var stack: []
        readonly property var current: stack.length > 0 ? stack[stack.length - 1] : (item?.menu ?? null)

        function toggle(target: var, anchorItem: Item): void {
            if (visible && item === target) {
                close()
                return
            }
            item = target
            stack = []
            const point = anchorItem.mapToItem(tray.window.contentItem, anchorItem.width / 2, 0)
            anchor.rect.x = Math.round(point.x - implicitWidth / 2)
            anchor.rect.y = Theme.barBottom + 6
            visible = true
        }

        function close(): void {
            visible = false
            stack = []
        }

        anchor.window: tray.window
        anchor.rect.width: 1
        anchor.rect.height: 1
        implicitWidth: 240
        implicitHeight: menuColumn.implicitHeight + 16
        color: "transparent"
        visible: false

        HyprlandFocusGrab {
            active: menu.visible
            windows: [menu]
            onCleared: menu.close()
        }

        QsMenuOpener {
            id: opener
            menu: menu.current
        }

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: Theme.surface
            border.color: Theme.surfaceBorder

            ColumnLayout {
                id: menuColumn

                x: 8
                y: 8
                width: parent.width - 16
                spacing: 2

                // Título e "voltar" dentro de submenus.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    Layout.topMargin: 2
                    Layout.bottomMargin: 4
                    spacing: 6

                    Icon {
                        visible: menu.stack.length > 0
                        name: "caret-left"
                        size: 12
                        color: Theme.textMuted
                        TapHandler { margin: 6; onTapped: menu.stack = menu.stack.slice(0, -1) }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: (menu.item?.tooltipTitle || menu.item?.title || menu.item?.id || "").toLowerCase()
                        elide: Text.ElideRight
                        color: Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                }

                Repeater {
                    model: opener.children

                    Item {
                        id: entry

                        required property QsMenuEntry modelData

                        Layout.fillWidth: true
                        implicitHeight: modelData.isSeparator ? 9 : 30

                        Rectangle {
                            visible: entry.modelData.isSeparator
                            anchors.verticalCenter: parent.verticalCenter
                            x: 8
                            width: parent.width - 16
                            height: 1
                            color: Theme.divider
                        }

                        Rectangle {
                            visible: !entry.modelData.isSeparator
                            anchors.fill: parent
                            radius: 10
                            color: entryHover.hovered && entry.modelData.enabled ? Theme.raised : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Icon {
                                    visible: entry.modelData.buttonType !== QsMenuButtonType.None
                                    name: entry.modelData.buttonType === QsMenuButtonType.RadioButton
                                        ? (entry.modelData.checkState === Qt.Checked ? "radio-button" : "circle")
                                        : (entry.modelData.checkState === Qt.Checked ? "check-square" : "square")
                                    size: 13
                                    color: entry.modelData.checkState === Qt.Checked ? Theme.yellow : Theme.textGhost
                                }
                                IconImage {
                                    visible: entry.modelData.icon !== ""
                                    implicitSize: 14
                                    source: entry.modelData.icon
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: entry.modelData.text.replace(/_(?!_)/g, "")
                                    elide: Text.ElideRight
                                    color: entry.modelData.enabled ? Theme.text : Theme.textGhost
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                }
                                Icon {
                                    visible: entry.modelData.hasChildren
                                    name: "caret-right"
                                    size: 11
                                    color: Theme.textFaint
                                }
                            }

                            HoverHandler { id: entryHover; cursorShape: entry.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
                            TapHandler {
                                enabled: entry.modelData.enabled
                                onTapped: {
                                    if (entry.modelData.hasChildren) {
                                        menu.stack = [...menu.stack, entry.modelData]
                                        return
                                    }
                                    entry.modelData.triggered()
                                    menu.close()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
