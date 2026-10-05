pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Limites do Claude Code e do Codex, lidos de `ai-usage show` a cada 5 min.
Singleton {
    id: root

    property var data: ({})
    property real loadedAt: 0

    readonly property bool claudeAvailable: data.claude?.available === true
    readonly property bool codexAvailable: data.codex?.available === true
    readonly property var claudeSession: data.claude?.limits?.five_hour ?? null
    readonly property var claudeWeek: data.claude?.limits?.seven_day ?? null
    readonly property var claudeOpus: data.claude?.limits?.seven_day_opus ?? null
    readonly property var claudeSonnet: data.claude?.limits?.seven_day_sonnet ?? null
    readonly property var codexPrimary: data.codex?.primary ?? null
    readonly property var codexSecondary: data.codex?.secondary ?? null

    function percent(limit: var): real {
        if (!limit || typeof limit.usedPercent !== "number") return -1
        return Math.max(0, Math.min(100, limit.usedPercent))
    }

    function percentText(limit: var): string {
        const value = percent(limit)
        return value < 0 ? "—" : Math.round(value) + "%"
    }

    function resetDate(limit: var): var {
        if (!limit || limit.resetsAt === null || limit.resetsAt === undefined) return null
        const raw = limit.resetsAt
        const date = typeof raw === "number" ? new Date(raw * 1000) : new Date(raw)
        return isNaN(date.getTime()) ? null : date
    }

    // "2h11", "4d", "35min"
    function remainingText(limit: var): string {
        const date = resetDate(limit)
        if (!date) return ""
        const minutes = Math.max(0, Math.round((date.getTime() - Date.now()) / 60000))
        if (minutes < 60) return minutes + "min"
        if (minutes < 1440) return Math.floor(minutes / 60) + "h" + String(minutes % 60).padStart(2, "0")
        return Math.round(minutes / 1440) + "d"
    }

    // "reseta 16:43 · em 2h11"
    function resetText(limit: var): string {
        const date = resetDate(limit)
        if (!date) return "reset não informado"
        const sameDay = date.toDateString() === new Date().toDateString()
        const when = sameDay ? Qt.formatDateTime(date, "HH:mm") : Theme.date(date, "ddd HH:mm")
        return "reseta " + when + " · em " + remainingText(limit)
    }

    function updatedText(): string {
        const newest = Math.max(data.codex?.updatedAt || 0, data.claude?.updatedAt || 0)
        if (newest === 0) return "sem dados"
        const minutes = Math.round((Date.now() / 1000 - newest) / 60)
        if (minutes < 1) return "atualizado agora"
        if (minutes < 60) return "atualizado há " + minutes + " min"
        return "atualizado " + Theme.date(new Date(newest * 1000), "ddd HH:mm")
    }

    // Guarda o pico do dia da sessão de cada IA (últimos 14 dias).
    function record(): void {
        const today = Qt.formatDate(new Date(), "yyyy-MM-dd")
        const history = Object.assign({}, Store.data.aiHistory ?? {})
        let changed = false
        for (const [name, limit] of [["claude", claudeSession], ["codex", codexPrimary]]) {
            const value = percent(limit)
            if (value < 0) continue
            const days = Object.assign({}, history[name] ?? {})
            if ((days[today] ?? -1) >= value) continue
            days[today] = value
            for (const key of Object.keys(days).sort().slice(0, -14)) delete days[key]
            history[name] = days
            changed = true
        }
        if (!changed) return
        Store.data.aiHistory = history
        Store.save()
    }

    // Últimos 7 dias (mais antigo primeiro), 0 quando não houve uso.
    function week(name: string): var {
        const days = Store.data.aiHistory?.[name] ?? {}
        const result = []
        for (let i = 6; i >= 0; i--) {
            const date = new Date()
            date.setDate(date.getDate() - i)
            result.push(days[Qt.formatDate(date, "yyyy-MM-dd")] ?? 0)
        }
        return result
    }

    function refresh(): void {
        if (!loader.running) loader.running = true
    }

    Process {
        id: loader
        command: ["ai-usage", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.data = JSON.parse(this.text)
                } catch (error) {
                    root.data = {}
                }
                root.loadedAt = Date.now()
                root.record()
            }
        }
    }

    Timer {
        interval: 300000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
