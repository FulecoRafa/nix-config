pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Layout ativo do teclado: "us" (código) ou "intl" (US internacional, com
// teclas mortas para acentos). A troca é do Hyprland (Super+Alt+Espaço);
// aqui só se acompanha o evento activelayout.
Singleton {
    id: root

    property string layout: "us"
    readonly property bool intl: layout === "intl"
    readonly property string label: intl ? "intl" : "us"
    // Avisado só em trocas de verdade, não na leitura inicial.
    signal switched

    function fromName(name: string): string {
        return /intl|international/i.test(name) ? "intl" : "us"
    }

    function toggle(): void {
        // Índice explícito: com "next" cada teclado vira por conta própria.
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", intl ? "0" : "1"])
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout") return
            // data: "<teclado>,<nome do layout>"; o nome pode ter vírgulas.
            const name = event.data.split(",").slice(1).join(",")
            const next = root.fromName(name)
            if (next === root.layout) return
            root.layout = next
            root.switched()
        }
    }

    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(text).keyboards ?? []
                    const main = keyboards.find(keyboard => keyboard.main) ?? keyboards[0]
                    if (main) root.layout = root.fromName(main.active_keymap ?? "")
                } catch (error) {}
            }
        }
    }
}
