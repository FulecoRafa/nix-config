pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Brilho da tela via sysfs (leitura) e brightnessctl (escrita).
Singleton {
    id: root

    property int current: 0
    property int maximum: 0
    readonly property bool available: maximum > 0
    readonly property real value: available ? current / maximum : 0

    // Última escrita: leituras do sysfs logo depois podem vir atrasadas.
    property real lastSet: 0

    function set(amount: real): void {
        if (!available) return
        const percent = Math.round(Math.max(0.01, Math.min(1, amount)) * 100)
        current = Math.round(maximum * percent / 100)
        lastSet = Date.now()
        // execDetached: cada toque roda, mesmo com o anterior ainda em curso.
        Quickshell.execDetached(["brightnessctl", "-q", "set", percent + "%"])
    }

    function step(delta: real): void {
        set(Math.round((value + delta) * 20) / 20)
    }

    function refresh(): void {
        if (!reader.running) reader.running = true
    }

    Process {
        id: reader
        running: true
        command: ["sh", "-c", "d=$(ls -d /sys/class/backlight/* 2>/dev/null | head -1); [ -n \"$d\" ] && echo $(cat $d/brightness) $(cat $d/max_brightness)"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(" ").map(Number)
                if (parts.length === 2 && parts[1] > 0) {
                    if (Date.now() - root.lastSet > 1500) root.current = parts[0]
                    root.maximum = parts[1]
                }
            }
        }
    }

    // sysfs não avisa mudanças; checa de vez em quando.
    IpcHandler {
        target: "brightness"

        function up(): void { root.step(0.05) }
        function down(): void { root.step(-0.05) }
    }

    Timer {
        interval: 2000
        running: root.available || reader.running === false
        repeat: true
        onTriggered: root.refresh()
    }
}
