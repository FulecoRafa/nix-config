pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Espectro do áudio tocando, via cava (cava.conf ao lado). Só roda enquanto
// `active` (a gaveta liga quando o player está visível e tocando).
Singleton {
    id: root

    property bool active: false
    // Barras de 0 a 1, graves à esquerda, e a média delas.
    property var bars: []
    property real level: 0
    // Há quadros chegando (sem cava instalado, a onda fica fixa).
    readonly property bool live: cava.running && bars.length > 0

    function frame(line: string): void {
        const values = line.split(";").filter(value => value !== "").map(value => Math.min(1, Number(value) / 100))
        if (values.length === 0) return
        bars = values
        level = values.reduce((sum, value) => sum + value, 0) / values.length
    }

    Process {
        id: cava
        running: root.active
        command: ["cava", "-p", Quickshell.shellPath("cava.conf")]
        stdout: SplitParser { onRead: line => root.frame(line) }
        onRunningChanged: if (!running) {
            root.bars = []
            root.level = 0
        }
    }
}
