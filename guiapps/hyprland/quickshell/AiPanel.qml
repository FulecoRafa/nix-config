import QtQuick
import QtQuick.Layouts
import Quickshell

// Limites de uso (SUPER+U): pendura do chip cc/cx da barra com a sessão e a
// semana do Claude Code e do Codex, mais o pico diário dos últimos 7 dias.
HangingPanel {
    id: panel

    name: "ai"
    side: "right"
    panelWidth: 520
    marginRight: 356
    padding: 22
    topPadding: 28

    onOpened: AiUsage.refresh()

    // Atualiza o "há N min" enquanto aberto.
    property int tick: 0
    Timer {
        interval: 30000
        running: panel.shown
        repeat: true
        onTriggered: panel.tick++
    }

    function color(value: real, fallback: color): color {
        if (value >= 90) return Theme.red
        return fallback
    }

    ColumnLayout {
        width: parent.width
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Icon { name: "gauge"; size: 18; color: Theme.orange }
            Text {
                text: "limites de uso"
                color: Theme.textBright
                font.family: Theme.font
                font.pixelSize: 15
            }
            Item { Layout.fillWidth: true }
            Text {
                text: panel.tick >= 0 ? AiUsage.updatedText() : ""
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: 11
            }
            Icon {
                name: "arrows-clockwise"
                size: 14
                color: refreshHover.hovered ? Theme.text : Theme.textFaint
                HoverHandler { id: refreshHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { margin: 6; onTapped: AiUsage.refresh() }
            }
        }

        Provider {
            icon: "asterisk"
            accent: Theme.orange
            tint: Theme.orangeTint
            label: "claude code"
            badge: ""
            detail: (AiUsage.data.claude?.model ?? "").toLowerCase()
            available: AiUsage.claudeAvailable
            hint: "abra o claude code: a status line grava os limites"
            limits: [
                { label: "sessão (5h)", limit: AiUsage.claudeSession, color: Theme.orange },
                { label: "semana · todos os modelos", limit: AiUsage.claudeWeek, color: Theme.yellow },
                { label: "semana · opus", limit: AiUsage.claudeOpus, color: Theme.purple },
                { label: "semana · sonnet", limit: AiUsage.claudeSonnet, color: Theme.cyan }
            ].filter(item => item.limit !== null)
        }

        Provider {
            icon: "hexagon"
            accent: Theme.green
            tint: Theme.greenTint
            label: "codex"
            badge: (AiUsage.data.codex?.planType ?? "").toLowerCase()
            detail: AiUsage.data.codex?.stale ? "em cache" : ""
            available: AiUsage.codexAvailable
            hint: "faça login com `codex login` para ver os limites"
            limits: [
                { label: "sessão (5h)", limit: AiUsage.codexPrimary, color: Theme.green },
                { label: "semana", limit: AiUsage.codexSecondary, color: Theme.cyan }
            ].filter(item => item.limit !== null)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            History { name: "claude"; accent: Theme.orange }
            History { name: "codex"; accent: Theme.green }
        }
    }

    component Provider: Rectangle {
        id: provider

        property string icon
        property color accent
        property color tint
        property string label
        property string badge
        property string detail
        property bool available
        property string hint
        property var limits: []

        Layout.fillWidth: true
        implicitHeight: providerColumn.implicitHeight + 32
        radius: 20
        color: Theme.raised

        ColumnLayout {
            id: providerColumn
            x: 16
            y: 16
            width: parent.width - 32
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 10
                    color: provider.tint
                    Icon { anchors.centerIn: parent; name: provider.icon; size: 15; color: provider.accent }
                }
                Text {
                    text: provider.label
                    color: Theme.textBright
                    font.family: Theme.font
                    font.pixelSize: 13
                }
                Rectangle {
                    visible: provider.badge !== ""
                    implicitWidth: badgeText.implicitWidth + 18
                    implicitHeight: badgeText.implicitHeight + 6
                    radius: 10
                    color: Theme.track
                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: provider.badge
                        color: Theme.textMuted
                        font.family: Theme.font
                        font.pixelSize: 10
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: provider.available ? provider.detail : "sem dados"
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !provider.available || provider.limits.length === 0
                text: provider.hint
                wrapMode: Text.Wrap
                color: Theme.textGhost
                font.family: Theme.font
                font.pixelSize: 11
            }

            Repeater {
                model: provider.available ? provider.limits : []

                ColumnLayout {
                    required property var modelData
                    readonly property real value: AiUsage.percent(modelData.limit)

                    Layout.fillWidth: true
                    spacing: 7

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: modelData.label; color: Theme.textMuted; font.family: Theme.font; font.pixelSize: 12 }
                        Item { Layout.fillWidth: true }
                        Text { text: AiUsage.percentText(modelData.limit); color: Theme.text; font.family: Theme.font; font.pixelSize: 12 }
                    }
                    Meter {
                        Layout.fillWidth: true
                        interactive: false
                        thickness: 8
                        track: Theme.track
                        value: Math.max(0, parent.value) / 100
                        accent: panel.color(parent.value, modelData.color)
                    }
                    Text {
                        text: AiUsage.resetText(modelData.limit)
                        color: Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    // Barrinhas dos 7 dias; hoje em destaque.
    component History: ColumnLayout {
        id: history

        property string name
        property color accent
        readonly property var values: AiUsage.week(name)
        readonly property real peak: Math.max(1, ...values)

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: 6

        Text {
            text: "7 dias · " + history.name
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: 11
        }

        Row {
            spacing: 12
            Repeater {
                model: history.values
                Item {
                    required property real modelData
                    required property int index
                    width: 18
                    height: 34
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(4, 34 * parent.modelData / history.peak)
                        radius: 3
                        color: parent.index === 6 ? history.accent : "#3D4657"
                    }
                }
            }
        }
    }
}
