import QtQuick
import QtQuick.Layouts
import Quickshell

// Cartão de notificação: ícone redondo tingido, app · resumo, idade,
// corpo e botões de ação.
Rectangle {
    id: card

    required property var notification
    property bool popup: false
    signal closed

    readonly property string accent: NotifService.accent(notification)
    readonly property color accentColor: Theme[accent]
    readonly property color accentTint: Theme[accent + "Tint"]
    readonly property var actions: (notification?.actions ?? []).filter(action => action.identifier !== "default")

    implicitWidth: 352
    implicitHeight: layout.implicitHeight + 28
    radius: 22
    color: Theme.surface
    border.color: hover.hovered ? Theme.dim : Theme.surfaceBorder

    Behavior on border.color { ColorAnimation { duration: Theme.fast } }

    function activate(): void {
        const fallback = (notification?.actions ?? []).find(action => action.identifier === "default")
        if (fallback) fallback.invoke()
        notification?.dismiss()
        closed()
    }

    HoverHandler { id: hover }
    TapHandler { onTapped: card.activate() }

    ColumnLayout {
        id: layout

        x: 14
        y: 14
        width: parent.width - 28
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                implicitWidth: 30
                implicitHeight: 30
                radius: 15
                color: card.accentTint
                clip: true

                Icon {
                    anchors.centerIn: parent
                    visible: appImage.status !== Image.Ready
                    name: NotifService.icon(card.notification)
                    size: 16
                    color: card.accentColor
                }

                Image {
                    id: appImage
                    anchors.fill: parent
                    anchors.margins: 5
                    visible: status === Image.Ready
                    sourceSize: Qt.size(40, 40)
                    source: {
                        const icon = card.notification?.appIcon ?? ""
                        if (icon === "") return ""
                        return icon.startsWith("/") || icon.includes("://") ? icon : Quickshell.iconPath(icon, true)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: {
                    const app = (card.notification?.appName || "").toLowerCase()
                    const summary = card.notification?.summary || ""
                    return app && summary && app !== summary.toLowerCase() ? app + " · " + summary : summary || app
                }
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Text {
                text: NotifService.age(card.notification)
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: 11

                // Atualiza "agora" → "1 min" sem depender de outro evento.
                Timer {
                    interval: 30000
                    running: true
                    repeat: true
                    onTriggered: parent.text = NotifService.age(card.notification)
                }
            }

            Icon {
                visible: hover.hovered
                name: "x"
                size: 13
                color: Theme.textFaint

                TapHandler {
                    margin: 6
                    onTapped: {
                        card.notification?.dismiss()
                        card.closed()
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: NotifService.markup(card.notification?.body ?? "")
            color: Theme.textMuted
            linkColor: Theme.cyan
            font.family: Theme.font
            font.pixelSize: 12
            lineHeight: 1.3
            wrapMode: Text.Wrap
            maximumLineCount: card.popup ? 3 : 5
            elide: Text.ElideRight
            textFormat: Text.StyledText
            onLinkActivated: link => Qt.openUrlExternally(link)
        }

        Image {
            Layout.fillWidth: true
            Layout.preferredHeight: status === Image.Ready ? Math.min(160, width * implicitHeight / Math.max(1, implicitWidth)) : 0
            visible: status === Image.Ready
            fillMode: Image.PreserveAspectCrop
            source: card.notification?.image ?? ""
        }

        Row {
            visible: card.actions.length > 0
            spacing: 8

            Repeater {
                model: card.actions

                Rectangle {
                    required property var modelData
                    required property int index

                    implicitWidth: actionText.implicitWidth + 28
                    implicitHeight: 30
                    radius: 14
                    color: index === 0 ? Theme.raised : actionHover.hovered ? Theme.raisedAlt : "transparent"

                    Text {
                        id: actionText
                        anchors.centerIn: parent
                        text: parent.modelData.text.toLowerCase()
                        color: parent.index === 0 ? Theme.text : Theme.textMuted
                        font.family: Theme.font
                        font.pixelSize: 11
                    }

                    HoverHandler { id: actionHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        // invoke() pode destruir este delegate; guarda as referências antes.
                        onTapped: {
                            const action = parent.modelData
                            const owner = card
                            action.invoke()
                            owner.closed()
                        }
                    }
                }
            }
        }
    }
}
