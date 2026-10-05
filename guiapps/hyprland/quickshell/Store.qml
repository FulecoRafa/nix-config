pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Estado persistente do shell em ~/.local/state/fuleco-shell/state.json:
// uso do lançador, apps fixados, tarefas, rascunho e timers.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.local/state/fuleco-shell"
    readonly property alias data: adapter

    // Registra uma abertura pelo lançador (ordenação por frequência).
    function used(key: string): void {
        const usage = Object.assign({}, adapter.usage)
        const entry = usage[key] ?? { count: 0, last: 0 }
        usage[key] = { count: entry.count + 1, last: Date.now() }
        adapter.usage = usage
        save()
    }

    function usage(key: string): var {
        return adapter.usage[key] ?? { count: 0, last: 0 }
    }

    function isPinned(id: string): bool {
        return adapter.pinned.indexOf(id) >= 0
    }

    function togglePin(id: string): void {
        const pinned = [...adapter.pinned]
        const index = pinned.indexOf(id)
        if (index >= 0) pinned.splice(index, 1)
        else pinned.push(id)
        adapter.pinned = pinned
        save()
    }

    function save(): void {
        saver.restart()
    }

    Timer {
        id: saver
        interval: 300
        onTriggered: file.writeAdapter()
    }

    Process {
        running: true
        command: ["mkdir", "-p", root.dir]
    }

    FileView {
        id: file

        path: root.dir + "/state.json"
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()

        JsonAdapter {
            id: adapter

            property var usage: ({})
            property var pinned: []
            property var tasks: []
            property string draft: ""
            property var timers: []
            // Legado: cartões escondidos antes do layout; só lido na migração.
            property var hiddenWidgets: []
            // Gaveta: [{ key: "media", size: "full" | "half" }, …]. Nulo até a
            // primeira edição (aí vale o layout padrão).
            property var drawerLayout: null
            // Pico diário da sessão (5h) de cada IA: { claude: { "2026-10-05": 62 } }.
            property var aiHistory: ({})
        }
    }
}
