pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Eventos do calcure (~/.config/calcure/events.csv). Um horário no começo do
// nome ("15:00 revisão") vira a hora do evento na agenda.
Singleton {
    id: root

    property var events: []
    property date today: new Date()

    readonly property var todayEvents: eventsOn(today)
    readonly property int todayCount: todayEvents.length

    function sameDay(a: date, b: date): bool {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
    }

    function eventsOn(day: date): var {
        return events
            .filter(event => sameDay(event.date, day))
            .sort((a, b) => a.time.localeCompare(b.time))
    }

    function hasEvents(day: date): bool {
        return events.some(event => sameDay(event.date, day))
    }

    function parseLine(line: string): var {
        // id,ano,mês,dia,"nome",repetição,frequência,status
        const match = line.match(/^(\d+),(\d+),(\d+),(\d+),"((?:[^"]|"")*)",(\d+),(\w+),(\w+)/)
        if (!match) return null
        const name = match[5].replace(/""/g, "\"")
        const timed = name.match(/^(\d{1,2}[:h]\d{2})\s*[-–—·]?\s*(.*)$/)
        return {
            date: new Date(Number(match[2]), Number(match[3]) - 1, Number(match[4])),
            time: timed ? timed[1].replace("h", ":").padStart(5, "0") : "",
            title: timed ? timed[2] : name,
            status: match[8]
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/calcure/events.csv"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.events = text().split("\n").map(root.parseLine).filter(event => event !== null)
        onLoadFailed: root.events = []
    }

    // Vira o dia à meia-noite.
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            const now = new Date()
            if (!root.sameDay(now, root.today)) root.today = now
        }
    }
}
