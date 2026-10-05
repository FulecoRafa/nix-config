pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Timers, pomodoro e alarmes da gaveta. Ficam no Store (sobrevivem a
// reinícios do shell) e disparam notificações mesmo com a gaveta fechada.
//   timer: { id, kind: "timer", label, duration, end, remaining, paused }
//   alarm: { id, kind: "alarm", time: "06:40", days: [1..5], label, enabled, fired }
Singleton {
    id: root

    readonly property var items: Store.data.timers ?? []
    readonly property var timers: items.filter(item => item.kind === "timer")
    readonly property var alarms: items.filter(item => item.kind === "alarm").sort((a, b) => a.time.localeCompare(b.time))
    readonly property int activeAlarms: alarms.filter(alarm => alarm.enabled).length

    // Avança a cada segundo enquanto houver algo para contar.
    property real now: Date.now()

    readonly property var weekdays: ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]

    function write(list: var): void {
        Store.data.timers = list
        Store.save()
    }

    function update(id: string, changes: var): void {
        write(items.map(item => item.id === id ? Object.assign({}, item, changes) : item))
    }

    function remove(id: string): void {
        write(items.filter(item => item.id !== id))
    }

    function newId(): string {
        return Date.now().toString(36) + Math.random().toString(36).slice(2, 6)
    }

    function startTimer(minutes: real, label: string): void {
        const duration = Math.round(minutes * 60000)
        write([...items, { id: newId(), kind: "timer", label: label, duration: duration, end: Date.now() + duration, remaining: duration, paused: false }])
    }

    function addAlarm(time: string, label: string): void {
        const match = time.trim().match(/^(\d{1,2})[:h]?(\d{2})$/)
        if (!match || Number(match[1]) > 23 || Number(match[2]) > 59) return
        const normalized = match[1].padStart(2, "0") + ":" + match[2]
        write([...items, { id: newId(), kind: "alarm", time: normalized, days: [], label: label, enabled: true, fired: "" }])
    }

    function remaining(timer: var): real {
        return Math.max(0, timer.paused ? timer.remaining : timer.end - now)
    }

    function togglePause(timer: var): void {
        if (timer.paused) update(timer.id, { paused: false, end: Date.now() + timer.remaining })
        else update(timer.id, { paused: true, remaining: Math.max(0, timer.end - Date.now()) })
    }

    function clock(ms: real): string {
        const total = Math.ceil(ms / 1000)
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor(total / 60) % 60
        const seconds = total % 60
        const mmss = String(minutes).padStart(2, "0") + ":" + String(seconds).padStart(2, "0")
        return hours > 0 ? hours + ":" + mmss : mmss
    }

    function daysText(alarm: var): string {
        const days = alarm.days ?? []
        if (days.length === 0 || days.length === 7) return alarm.label || "todo dia"
        if (days.join() === "1,2,3,4,5") return "seg a sex"
        return days.map(day => weekdays[day]).join(" ")
    }

    function notify(summary: string, body: string): void {
        Quickshell.execDetached(["notify-send", "-a", "timer", "-i", "alarm", "-u", "critical", summary, body])
    }

    function tick(): void {
        now = Date.now()
        const date = new Date(now)
        const today = Qt.formatDate(date, "yyyy-MM-dd")
        const hhmm = Qt.formatTime(date, "HH:mm")
        let changed = false
        const next = []

        for (const item of items) {
            if (item.kind === "timer" && !item.paused && item.end <= now) {
                changed = true
                finished(item)
                continue
            }
            if (item.kind === "alarm" && item.enabled && item.time === hhmm && item.fired !== today
                    && ((item.days ?? []).length === 0 || item.days.includes(date.getDay()))) {
                changed = true
                notify("alarme · " + item.time, item.label || "hora de levantar")
                next.push(Object.assign({}, item, { fired: today }))
                continue
            }
            next.push(item)
        }
        if (changed) write(next)
    }

    function finished(timer: var): void {
        const done = clock(timer.duration) + " concluído."
        if (timer.label === "pomodoro · foco") {
            // Pergunta pela pausa direto na notificação.
            pomodoroAsk.command = ["notify-send", "-a", "timer", "-i", "alarm", "-u", "critical",
                "-A", "pausa=iniciar pausa", "-A", "dispensar=dispensar",
                "timer · pomodoro", done + " Pausa de 5 minutos?"]
            pomodoroAsk.running = true
        } else {
            notify("timer · " + (timer.label || "timer"), done)
        }
    }

    Process {
        id: pomodoroAsk
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() === "pausa") root.startTimer(5, "pomodoro · pausa")
        }
    }

    Timer {
        interval: 1000
        running: root.items.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.tick()
    }
}
