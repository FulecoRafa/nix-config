pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memória, temperatura e disco lidos do /proc e /sys a cada 2 s.
Singleton {
    id: root

    property real cpu: 0
    property real memory: 0
    property real memoryUsedGiB: 0
    property real memoryTotalGiB: 0
    property real temperature: 0
    property real disk: 0
    property real diskUsedGiB: 0
    property real diskTotalGiB: 0
    property var cpuHistory: []

    property var lastCpu: null

    function parse(text: string): void {
        const lines = text.trim().split("\n")
        const values = {}
        for (const line of lines) {
            const separator = line.indexOf("=")
            if (separator > 0) values[line.slice(0, separator)] = line.slice(separator + 1)
        }

        const fields = (values.cpu || "").trim().split(/\s+/).slice(1).map(Number)
        if (fields.length >= 4) {
            const idle = fields[3] + (fields[4] || 0)
            const total = fields.reduce((sum, value) => sum + value, 0)
            if (lastCpu) {
                const deltaTotal = total - lastCpu.total
                const deltaIdle = idle - lastCpu.idle
                if (deltaTotal > 0) cpu = Math.round(100 * (1 - deltaIdle / deltaTotal))
            }
            lastCpu = { total, idle }
            const history = cpuHistory.slice(-29)
            history.push(cpu)
            cpuHistory = history
        }

        const total = Number(values.memTotal || 0)
        const available = Number(values.memAvailable || 0)
        if (total > 0) {
            memory = Math.round(100 * (1 - available / total))
            memoryTotalGiB = total / 1048576
            memoryUsedGiB = (total - available) / 1048576
        }

        temperature = Math.round(Number(values.temp || 0) / 1000)
        const diskFields = (values.disk || "").trim().split(/\s+/).map(Number)
        if (diskFields.length === 2 && diskFields[1] > 0) {
            diskUsedGiB = diskFields[0] / 1048576
            diskTotalGiB = diskFields[1] / 1048576
            disk = Math.round(100 * diskFields[0] / diskFields[1])
        }
    }

    Process {
        id: reader
        command: ["sh", "-c",
            "echo cpu=$(head -1 /proc/stat);"
            + "awk '/MemTotal/{print \"memTotal=\"$2} /MemAvailable/{print \"memAvailable=\"$2}' /proc/meminfo;"
            + "echo temp=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1);"
            + "echo disk=$(df -Pk / | awk 'NR==2{print $3, $2}')"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!reader.running) reader.running = true
    }
}
