import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    readonly property int workspaceCount: Number(Quickshell.env("HYPRLAND_WORKSPACE_COUNT") || "6")
    readonly property string iconFont: "CaskaydiaCove Nerd Font"
    property var aiUsage: ({})

    function limitText(limit: var): string {
        if (!limit || typeof limit.usedPercent !== "number") return "—"
        return Math.round(limit.usedPercent) + "%"
    }

    function codexText(): string {
        const codex = aiUsage.codex
        if (!codex?.available) return "login"
        return limitText(codex.primary)
    }

    function claudeText(): string {
        const claude = aiUsage.claude
        if (!claude?.available) return "use uma vez"
        const limits = claude.limits || {}
        const parts = []
        if (limits.five_hour) parts.push("5h " + limitText(limits.five_hour))
        if (limits.seven_day) parts.push("7d " + limitText(limits.seven_day))
        return parts.length > 0 ? parts.join(" · ") : "—"
    }

    function resetText(limit: var): string {
        if (!limit || limit.resetsAt === null || limit.resetsAt === undefined) return "Reset não informado"
        const raw = limit.resetsAt
        const reset = typeof raw === "number" ? new Date(raw * 1000) : new Date(raw)
        if (isNaN(reset.getTime())) return "Reset não informado"

        const remaining = reset.getTime() - Date.now()
        if (remaining <= 0) return "Janela reiniciada; atualize os dados"
        const minutes = Math.ceil(remaining / 60000)
        const relative = minutes < 60
            ? minutes + " min"
            : minutes < 1440
                ? Math.ceil(minutes / 60) + " h"
                : Math.ceil(minutes / 1440) + " d"
        return "󰥔 reinicia em " + relative + " · " + Qt.formatDateTime(reset, "ddd HH:mm")
    }

    function codexWindowTitle(limit: var, fallback: string): string {
        const minutes = limit?.windowDurationMins
        if (minutes === 300) return "Sessão atual (5 horas)"
        if (minutes === 10080) return "Semana atual"
        if (typeof minutes === "number") return "Janela de " + minutes + " minutos"
        return fallback
    }

    function updatedText(): string {
        const codexTime = aiUsage.codex?.updatedAt || 0
        const claudeTime = aiUsage.claude?.updatedAt || 0
        const newest = Math.max(codexTime, claudeTime)
        if (newest === 0) return "Sem dados de uso"
        return "Atualizado " + Qt.formatDateTime(new Date(newest * 1000), "ddd HH:mm")
    }

    function refreshAiUsage(): void {
        if (!usageLoader.running) usageLoader.running = true
    }

    Process {
        id: usageLoader
        command: ["ai-usage", "show"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.aiUsage = JSON.parse(this.text)
                } catch (error) {
                    root.aiUsage = {}
                }
            }
        }
    }

    Timer {
        interval: 300000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshAiUsage()
    }

    component UsageMeter: ColumnLayout {
        required property string title
        required property var limit

        readonly property real percentage: limit && typeof limit.usedPercent === "number"
            ? Math.max(0, Math.min(100, limit.usedPercent))
            : 0

        visible: limit !== null && limit !== undefined
        Layout.fillWidth: true
        spacing: 4

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: title
                color: "#e8eaed"
                font.pixelSize: 13
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.limitText(limit)
                color: "#e8eaed"
                font.bold: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 7
            radius: 4
            color: "#3c4043"

            Rectangle {
                width: parent.width * percentage / 100
                height: parent.height
                radius: parent.radius
                color: percentage >= 90 ? "#f28b82" : percentage >= 70 ? "#fdd663" : "#8ab4f8"
            }
        }

        Text {
            text: root.resetText(limit)
            color: "#9aa0a6"
            font.family: root.iconFont
            font.pixelSize: 11
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: bar

                required property var modelData

                screen: modelData
                implicitHeight: 32
                color: "transparent"

                anchors {
                    top: true
                    left: true
                    right: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#202124"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10

                        Row {
                            spacing: 4

                            Repeater {
                                model: root.workspaceCount

                                delegate: Rectangle {
                                    required property int index

                                    readonly property int workspaceId: index + 1

                                    width: 24
                                    height: 24
                                    radius: 6
                                    color: Hyprland.focusedWorkspace?.id === workspaceId ? "#e8eaed" : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: parent.workspaceId === root.workspaceCount ? "M" : parent.workspaceId
                                        color: Hyprland.focusedWorkspace?.id === parent.workspaceId ? "#202124" : "#e8eaed"
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: Hyprland.dispatch("workspace " + parent.workspaceId)
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            color: "#e8eaed"
                            text: Qt.formatDateTime(clock.date, "ddd d MMM  HH:mm")

                            SystemClock {
                                id: clock
                                precision: SystemClock.Minutes
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Row {
                            spacing: 12

                            Row {
                                id: aiIndicator
                                spacing: 7

                                Text {
                                    text: "󰚩"
                                    color: "#e8eaed"
                                    font.family: root.iconFont
                                }
                                Text { text: root.codexText(); color: "#e8eaed" }

                                Rectangle {
                                    width: 1
                                    height: 16
                                    color: "#5f6368"
                                }

                                Text {
                                    text: "󰧑"
                                    color: "#e8eaed"
                                    font.family: root.iconFont
                                }
                                Text { text: root.claudeText(); color: "#e8eaed" }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        usagePopup.visible = !usagePopup.visible
                                        root.refreshAiUsage()
                                    }
                                }

                                PopupWindow {
                                    id: usagePopup

                                    width: 410
                                    height: usageCard.implicitHeight + 24
                                    color: "transparent"
                                    grabFocus: true

                                    anchor {
                                        item: aiIndicator
                                        edges: Edges.Bottom | Edges.Right
                                        gravity: Edges.Bottom | Edges.Left
                                        margins.top: 7
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 14
                                        color: "#202124"
                                        border.color: "#3c4043"

                                        ColumnLayout {
                                            id: usageCard

                                            x: 14
                                            y: 12
                                            width: parent.width - 28
                                            spacing: 12

                                            RowLayout {
                                                Layout.fillWidth: true

                                                Text {
                                                    text: "󰓅  Uso de agentes"
                                                    color: "#e8eaed"
                                                    font.family: root.iconFont
                                                    font.pixelSize: 17
                                                    font.bold: true
                                                }

                                                Item { Layout.fillWidth: true }

                                                Text {
                                                    text: "󰑐"
                                                    color: "#e8eaed"
                                                    font.family: root.iconFont
                                                    font.pixelSize: 17

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        anchors.margins: -7
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.refreshAiUsage()
                                                    }
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true

                                                Text {
                                                    text: "󰚩  Codex"
                                                    color: "#e8eaed"
                                                    font.family: root.iconFont
                                                    font.pixelSize: 15
                                                    font.bold: true
                                                }

                                                Item { Layout.fillWidth: true }

                                                Text {
                                                    visible: root.aiUsage.codex?.available === true
                                                    text: root.aiUsage.codex?.planType || ""
                                                    color: "#9aa0a6"
                                                    font.capitalization: Font.Capitalize
                                                }
                                            }

                                            Text {
                                                visible: !root.aiUsage.codex?.available
                                                Layout.fillWidth: true
                                                text: "Execute codex login no terminal."
                                                color: "#9aa0a6"
                                            }

                                            UsageMeter {
                                                title: root.codexWindowTitle(root.aiUsage.codex?.primary, "Limite principal")
                                                limit: root.aiUsage.codex?.primary || null
                                            }

                                            UsageMeter {
                                                title: root.codexWindowTitle(root.aiUsage.codex?.secondary, "Limite secundário")
                                                limit: root.aiUsage.codex?.secondary || null
                                            }

                                            Text {
                                                visible: root.aiUsage.codex?.credits?.hasCredits === true
                                                Layout.fillWidth: true
                                                text: "Créditos disponíveis: " + (root.aiUsage.codex?.credits?.balance || "0")
                                                color: "#bdc1c6"
                                            }

                                            Text {
                                                visible: (root.aiUsage.codex?.availableResetCredits || 0) > 0
                                                Layout.fillWidth: true
                                                text: "󰑐  Resets gratuitos disponíveis: " + root.aiUsage.codex.availableResetCredits
                                                color: "#bdc1c6"
                                                font.family: root.iconFont
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                implicitHeight: 1
                                                color: "#3c4043"
                                            }

                                            Text {
                                                text: "󰧑  Claude Code"
                                                color: "#e8eaed"
                                                font.family: root.iconFont
                                                font.pixelSize: 15
                                                font.bold: true
                                            }

                                            Text {
                                                visible: !root.aiUsage.claude?.available
                                                Layout.fillWidth: true
                                                text: "Faça login e conclua uma interação no Claude Code."
                                                color: "#9aa0a6"
                                                wrapMode: Text.WordWrap
                                            }

                                            UsageMeter {
                                                title: "Sessão atual (5 horas)"
                                                limit: root.aiUsage.claude?.limits?.five_hour || null
                                            }

                                            UsageMeter {
                                                title: "Semana atual (todos os modelos)"
                                                limit: root.aiUsage.claude?.limits?.seven_day || null
                                            }

                                            UsageMeter {
                                                title: "Semana atual (Sonnet)"
                                                limit: root.aiUsage.claude?.limits?.seven_day_sonnet || null
                                            }

                                            UsageMeter {
                                                title: "Semana atual (Opus)"
                                                limit: root.aiUsage.claude?.limits?.seven_day_opus || null
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: root.updatedText()
                                                color: "#9aa0a6"
                                                horizontalAlignment: Text.AlignRight
                                                font.pixelSize: 11
                                            }
                                        }
                                    }
                                }
                            }

                            Text { text: "󰖩"; color: "#e8eaed"; font.family: root.iconFont }
                            Text { text: "󰕾"; color: "#e8eaed"; font.family: root.iconFont }
                            Text { text: "󰐥"; color: "#e8eaed"; font.family: root.iconFont }
                        }
                    }
                }
            }
        }
    }
}
