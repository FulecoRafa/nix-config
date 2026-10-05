pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris

// O player "da vez" para o cartão de mídia e os atalhos (Super+P/,/.).
// Com vários tocando, vale o último que começou a tocar; escolher um no
// cartão o fixa até outro começar a tocar ou ele sumir. Também acha a
// janela de cada player (pelo PID do dono no D-Bus) para levar até ela.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    // dbusName dos players, do que começou a tocar por último para trás.
    property var recent: []
    // Escolha manual (dbusName); "" = automático.
    property string pinned: ""
    // dbusName → PID do processo dono.
    property var pids: ({})
    // dbusName → endereço da última janela que mostrou a música no título.
    // Pausado, o título volta a ser só o do app ("YouTube Music") e empata
    // com as outras janelas do navegador; isto desempata.
    property var seen: ({})

    readonly property MprisPlayer player: {
        const list = players
        if (list.length === 0) return null
        const byName = name => list.find(p => p.dbusName === name)
        if (pinned !== "" && byName(pinned)) return byName(pinned)
        const rank = p => {
            const index = recent.indexOf(p.dbusName)
            return index < 0 ? recent.length : index
        }
        const ordered = [...list].sort((a, b) => rank(a) - rank(b))
        return ordered.find(p => p.isPlaying) ?? ordered[0]
    }

    function started(player: MprisPlayer): void {
        recent = [player.dbusName, ...recent.filter(name => name !== player.dbusName)]
        // Outro player começou: a escolha manual deixa de valer.
        if (pinned !== player.dbusName) pinned = ""
    }

    function choose(player: MprisPlayer): void {
        pinned = player?.dbusName ?? ""
    }

    function cycle(delta: int): void {
        const list = players
        if (list.length < 2) return
        const index = list.indexOf(player)
        choose(list[(index + delta + list.length) % list.length])
    }

    function playPause(): void { if (player?.canTogglePlaying) player.togglePlaying() }
    function next(): void { if (player?.canGoNext) player.next() }
    function previous(): void { if (player?.canGoPrevious) player.previous() }

    // ── janela do player ─────────────────────────────────────────────────

    function pidOf(player: MprisPlayer): int {
        if (!player) return -1
        // O Chromium (Helium) põe o PID no próprio nome: chromium.instance442072.
        const match = /\.chromium\.instance(\d+)$/.exec(player.dbusName)
        if (match) return Number(match[1])
        return pids[player.dbusName] ?? -1
    }

    // A melhor janela do player entre as do processo: a que tem a música no
    // título (a aba/PWA certa do navegador), depois um PWA, depois qualquer.
    function windowOf(player: MprisPlayer): var {
        if (!player) return null
        const pid = pidOf(player)
        let candidates = pid > 0
            ? Hyprland.toplevels.values.filter(t => t.lastIpcObject?.pid === pid)
            : []
        if (candidates.length === 0) {
            // Sem PID (ainda): pelo nome do app na classe da janela.
            const names = [player.desktopEntry, player.identity].filter(Boolean).map(n => n.toLowerCase())
            candidates = Hyprland.toplevels.values.filter(t => {
                const cls = (t.lastIpcObject?.class ?? "").toLowerCase()
                return cls !== "" && names.some(n => cls === n || cls.endsWith("." + n))
            })
        }
        const remembered = seen[player.dbusName] ?? ""
        const rememberedClass = Store.data.mediaApps?.[player.identity] ?? ""
        const score = t => {
            const cls = t.lastIpcObject?.class ?? ""
            return (showsTrack(player, t.title) ? 8 : 0)
                + (address(t) === remembered ? 4 : 0)
                + (cls === rememberedClass ? 2 : 0)
                + (cls.startsWith("chrome-") ? 1 : 0)
        }
        return candidates.sort((a, b) => score(b) - score(a))[0] ?? null
    }

    function address(toplevel: var): string {
        const value = toplevel?.address ?? ""
        return value.startsWith("0x") ? value.slice(2) : value
    }

    function showsTrack(player: MprisPlayer, title: string): bool {
        const track = (player?.trackTitle ?? "").toLowerCase()
        return track !== "" && (title ?? "").toLowerCase().includes(track)
    }

    function remember(player: MprisPlayer, windowAddress: string): void {
        if (seen[player.dbusName] !== windowAddress)
            seen = Object.assign({}, seen, { [player.dbusName]: windowAddress })
        const window = Hyprland.toplevels.values.find(t => address(t) === windowAddress)
        const cls = window?.lastIpcObject?.class ?? ""
        const apps = Store.data.mediaApps ?? {}
        if (cls !== "" && player.identity && apps[player.identity] !== cls) {
            Store.data.mediaApps = Object.assign({}, apps, { [player.identity]: cls })
            Store.save()
        }
    }

    // Procura, entre as janelas abertas, a que mostra a música de cada player.
    function rescan(): void {
        for (const player of players) {
            const match = Hyprland.toplevels.values.find(t => showsTrack(player, t.title))
            if (match) remember(player, address(match))
        }
    }

    // Nome para mostrar: o do .desktop da janela (um PWA vira "YouTube
    // Music"), senão o identity do MPRIS.
    function nameOf(player: MprisPlayer): string {
        if (!player) return ""
        const cls = windowOf(player)?.lastIpcObject?.class ?? ""
        const entry = cls !== "" ? DesktopEntries.byId(cls) : null
        if (entry?.name && cls.startsWith("chrome-")) return entry.name
        return player.identity || player.desktopEntry || "player"
    }

    property MprisPlayer focusTarget: null

    function focusApp(player: MprisPlayer): void {
        if (!player) return
        focusTarget = player
        Hyprland.refreshToplevels()
        resolve(player)
        focusDelay.restart()
    }

    Timer {
        id: focusDelay
        interval: 150
        onTriggered: {
            const player = root.focusTarget
            root.focusTarget = null
            const window = root.windowOf(player)
            if (window) Windows.focus(window)
            else if (player?.canRaise) player.raise()
        }
    }

    // PIDs dos outros players, um busctl por vez.
    property var queue: []

    function resolve(player: MprisPlayer): void {
        const name = player?.dbusName ?? ""
        if (name === "" || /\.chromium\.instance\d+$/.test(name) || pids[name] !== undefined) return
        if (!queue.includes(name)) queue = [...queue, name]
        if (!pidReader.running) resolveNext()
    }

    function resolveNext(): void {
        if (queue.length === 0) return
        pidReader.name = queue[0]
        queue = queue.slice(1)
        pidReader.running = true
    }

    Process {
        id: pidReader
        property string name
        command: ["busctl", "--user", "call", "org.freedesktop.DBus", "/", "org.freedesktop.DBus",
            "GetConnectionUnixProcessID", "s", name]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = /^u (\d+)/.exec(text.trim())
                if (match) root.pids = Object.assign({}, root.pids, { [pidReader.name]: Number(match[1]) })
            }
        }
        onExited: root.resolveNext()
    }

    Instantiator {
        model: Mpris.players

        Connections {
            required property MprisPlayer modelData
            target: modelData
            function onIsPlayingChanged() {
                if (modelData.isPlaying) root.started(modelData)
            }
            function onTrackTitleChanged() { root.rescan() }
            Component.onCompleted: {
                root.resolve(modelData)
                if (modelData.isPlaying && !root.recent.includes(modelData.dbusName))
                    root.recent = [...root.recent, modelData.dbusName]
            }
        }
    }

    // O título da aba/PWA muda logo depois da faixa; cada troca é uma chance
    // de ligar o player à janela.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "windowtitlev2") return
            const comma = event.data.indexOf(",")
            const windowAddress = event.data.slice(0, comma).replace(/^0x/, "")
            const title = event.data.slice(comma + 1)
            for (const player of root.players)
                if (root.showsTrack(player, title)) root.remember(player, windowAddress)
        }
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: root.rescan()
    }

    // Esquece quem saiu.
    onPlayersChanged: {
        const names = players.map(p => p.dbusName)
        recent = recent.filter(name => names.includes(name))
        if (pinned !== "" && !names.includes(pinned)) pinned = ""
    }

    IpcHandler {
        target: "media"

        function playPause(): void { root.playPause() }
        function next(): void { root.next() }
        function previous(): void { root.previous() }
        function focus(): void { root.focusApp(root.player) }
        function cycle(): void { root.cycle(1) }
        function list(): string {
            return root.players.map(p => (p === root.player ? "* " : "  ") + p.dbusName
                + " [" + (p.isPlaying ? "tocando" : "parado") + "] pid=" + root.pidOf(p)
                + " " + root.nameOf(p) + " — " + (p.trackTitle || "")
                + " → " + (root.windowOf(p)?.lastIpcObject?.class ?? "sem janela")).join("\n")
        }
    }
}
