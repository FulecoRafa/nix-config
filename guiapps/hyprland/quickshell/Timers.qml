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

    function addAlarm(time: string, label: string): bool {
        const match = time.trim().match(/^(\d{1,2})[:h]?(\d{2})$/)
        if (!match || Number(match[1]) > 23 || Number(match[2]) > 59) return false
        const normalized = match[1].padStart(2, "0") + ":" + match[2]
        write([...items, { id: newId(), kind: "alarm", time: normalized, days: [], label: label, enabled: true, fired: "" }])
        return true
    }

    // Interpreta o campo da gaveta. Alarmes: "06:40 acordar", "7h", "7h30",
    // "19.30", "0715", "7pm", com ou sem "alarme:" na frente. Timers: "10m",
    // "25 min foco", "1h30m". Devolve "" quando criou, ou a mensagem de erro.
    function create(text: string): string {
        const rest = text.trim().replace(/^(alarme|alarm)\s*:?\s*/i, "")
        if (rest === "") return "digite um horário"

        let match = rest.match(/^(?:(\d+)\s*h\s*)?(\d+)\s*(?:m|min|mins|minutos?)(?:\s+(.*))?$/i)
        if (match) {
            const minutes = Number(match[1] || 0) * 60 + Number(match[2])
            if (minutes <= 0) return "duração inválida"
            startTimer(minutes, (match[3] || "").trim() || "timer")
            return ""
        }

        match = rest.match(/^(\d{1,2})(?:\s*[:h.]\s*(\d{2})|(\d{2}))?\s*(h|am|pm)?(?:\s+(.*))?$/i)
        if (!match) return "use 06:40, 7h30 ou 10m"
        let hours = Number(match[1])
        const minutes = Number(match[2] || match[3] || 0)
        const suffix = (match[4] || "").toLowerCase()
        if (suffix === "pm" && hours < 12) hours += 12
        if (suffix === "am" && hours === 12) hours = 0
        if (hours > 23 || minutes > 59) return "horário inválido"
        addAlarm(String(hours) + ":" + String(minutes).padStart(2, "0"), (match[5] || "").trim())
        return ""
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

    // Para testes e atalhos: `quickshell -c fuleco ipc call timers alarm 06:40 acordar`.
    IpcHandler {
        target: "timers"

        function alarm(time: string, label: string): string {
            return root.addAlarm(time, label) ? "ok" : "horário inválido: " + time
        }
        function timer(minutes: real, label: string): void { root.startTimer(minutes, label) }
        // O mesmo texto do campo da gaveta: "7h30 acordar", "10m chá".
        function add(text: string): string { return root.create(text) || "ok" }
        function remove(id: string): void { root.remove(id) }
        function list(): string { return JSON.stringify(root.items) }
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
