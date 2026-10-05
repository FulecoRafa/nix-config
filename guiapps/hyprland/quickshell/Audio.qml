pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Saída e entrada padrão do PipeWire, mais os fluxos de aplicativos.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    // Saídas e entradas de verdade: o ALSA expõe HDMI e o microfone do
    // fone mesmo sem nada plugado. A disponibilidade fica nas rotas do
    // dispositivo (pw-dump); o PwNode só traz propriedades quando rastreado,
    // então o pw-dump já devolve os nomes dos nós sem rota disponível.
    property var unavailable: ({})
    readonly property var sinks: Pipewire.nodes.values.filter(node => node.isSink && !node.isStream && node.audio && isAvailable(node))
    readonly property var sources: Pipewire.nodes.values.filter(node => !node.isSink && !node.isStream && node.audio && isAvailable(node))

    function isAvailable(node: var): bool {
        const name = String(node?.name ?? "")
        if (/monitor$|dummy|null-sink/i.test(name)) return false
        return node === sink || node === source || !unavailable[name]
    }

    function refreshRoutes(): void {
        if (!routeReader.running) routeReader.running = true
    }

    Process {
        id: routeReader
        command: ["pw-dump"]
        stdout: StdioCollector {
            onStreamFinished: {
                let objects
                try {
                    objects = JSON.parse(text)
                } catch (error) {
                    return
                }
                const routes = {}
                for (const object of objects) {
                    if (object.type !== "PipeWire:Interface:Device") continue
                    for (const route of object.info?.params?.EnumRoute ?? []) {
                        if (route.available !== "no") continue
                        for (const device of route.devices ?? []) routes[object.id + ":" + device] = true
                    }
                    // Um mesmo nó pode servir rotas diferentes (fone e alto-falante):
                    // basta uma disponível para ele valer.
                    for (const route of object.info?.params?.EnumRoute ?? []) {
                        if (route.available === "no") continue
                        for (const device of route.devices ?? []) delete routes[object.id + ":" + device]
                    }
                }
                const result = {}
                for (const object of objects) {
                    const props = object.info?.props
                    if (object.type !== "PipeWire:Interface:Node" || !props?.["node.name"]) continue
                    if (routes[props["device.id"] + ":" + props["card.profile.device"]]) result[props["node.name"]] = true
                }
                root.unavailable = result
            }
        }
    }

    // Plugar um fone muda as rotas sem criar nós; relê de vez em quando.
    Timer {
        interval: 8000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshRoutes()
    }

    Connections {
        target: Pipewire.nodes
        function onValuesChanged() { root.refreshRoutes() }
    }

    // Fluxos de reprodução (um por aplicativo tocando áudio).
    readonly property var streams: Pipewire.nodes.values.filter(node => node.isStream && node.audio && !node.isSink)

    function setVolume(value: real): void {
        if (sink?.audio) {
            sink.audio.muted = false
            sink.audio.volume = Math.max(0, Math.min(1, value))
        }
    }

    function setMicVolume(value: real): void {
        if (source?.audio) source.audio.volume = Math.max(0, Math.min(1, value))
    }

    function toggleMute(): void {
        if (sink?.audio) sink.audio.muted = !sink.audio.muted
    }

    function toggleMicMute(): void {
        if (source?.audio) source.audio.muted = !source.audio.muted
    }

    // "Speaker", "HDMI 2", "Headphones"… em vez do nome comprido do chipset.
    function deviceName(node: var): string {
        const props = node?.properties ?? {}
        const name = props["device.profile.description"] || node?.nickname || props["node.nick"] || node?.description || node?.name || "?"
        return String(name).toLowerCase()
    }

    function streamName(node: var): string {
        const props = node?.properties ?? {}
        return props["application.name"] || node?.description || node?.name || "app"
    }

    PwObjectTracker {
        objects: [root.sink, root.source, ...root.streams]
    }
}
