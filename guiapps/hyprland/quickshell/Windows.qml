pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Janelas do Hyprland na ordem de uso (a mais recente primeiro), para o
// Alt+Tab e o exposé. A ordem começa pelo focusHistoryID do hyprctl e
// depois acompanha cada troca de foco.
Singleton {
    id: root

    // Endereços, do foco atual para o mais antigo.
    property var recent: []

    function key(toplevel: HyprlandToplevel): string {
        return toplevel?.address ?? ""
    }

    function touch(address: string): void {
        if (address === "") return
        recent = [address, ...recent.filter(item => item !== address)]
    }

    // Janelas de um workspace, mais recentes primeiro.
    function on(workspaceId: int): var {
        const list = Hyprland.toplevels.values.filter(toplevel => toplevel.workspace?.id === workspaceId
            && !(toplevel.lastIpcObject?.hidden ?? false))
        const active = Hyprland.activeToplevel?.address ?? ""
        const rank = address => {
            if (address === active) return -1
            const index = recent.indexOf(address)
            return index < 0 ? recent.length : index
        }
        return list.sort((a, b) => rank(a.address) - rank(b.address))
    }

    // Janelas de um app em todos os workspaces (App Exposé), mais recentes
    // primeiro. `pattern` é uma regex do app-id/classe, sem diferenciar caixa.
    function ofApp(pattern: string): var {
        const regex = new RegExp(pattern, "i")
        const list = Hyprland.toplevels.values.filter(toplevel => {
            const id = toplevel.wayland?.appId ?? toplevel.lastIpcObject?.class ?? ""
            const name = toplevel.workspace?.name ?? ""
            return regex.test(id) && !(toplevel.lastIpcObject?.hidden ?? false)
                && (!name.startsWith("special:") || name.startsWith("special:floats-"))
        })
        const active = Hyprland.activeToplevel?.address ?? ""
        const rank = address => {
            if (address === active) return -1
            const index = recent.indexOf(address)
            return index < 0 ? recent.length : index
        }
        return list.sort((a, b) => rank(a.address) - rank(b.address))
    }

    function current(): var {
        return on(Hyprland.focusedWorkspace?.id ?? -1)
    }

    function focus(toplevel: HyprlandToplevel): void {
        if (!toplevel) return
        const address = toplevel.address.startsWith("0x") ? toplevel.address : "0x" + toplevel.address
        Hyprland.dispatch("focuswindow address:" + address)
        // Flutuante atrás de outra flutuante vem para a frente.
        Hyprland.dispatch("alterzorder top, address:" + address)
    }

    // Esconde as janelas flutuantes do workspace atual num especial próprio
    // (special:floats-N); de novo, devolve todas para o workspace.
    function hiddenFloats(workspaceId: int): var {
        return Hyprland.toplevels.values.filter(toplevel => toplevel.workspace?.name === "special:floats-" + workspaceId)
    }

    // Atualiza o estado (floating) antes de decidir quem esconder.
    function toggleFloats(): void {
        Hyprland.refreshToplevels()
        floatsDelay.restart()
    }

    Timer {
        id: floatsDelay
        interval: 150
        onTriggered: root.applyFloats()
    }

    function applyFloats(): void {
        const workspace = Hyprland.focusedWorkspace
        if (!workspace || workspace.id < 1) return
        const target = (toplevel, where) => {
            const address = toplevel.address.startsWith("0x") ? toplevel.address : "0x" + toplevel.address
            Hyprland.dispatch("movetoworkspacesilent " + where + ", address:" + address)
        }
        const hidden = hiddenFloats(workspace.id)
        if (hidden.length > 0) {
            hidden.forEach(toplevel => target(toplevel, workspace.id))
        } else {
            on(workspace.id).filter(toplevel => toplevel.lastIpcObject?.floating ?? false)
                .forEach(toplevel => target(toplevel, "special:floats-" + workspace.id))
        }
        Hyprland.refreshToplevels()
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            root.touch(root.key(Hyprland.activeToplevel))
        }
    }

    // Semente: o histórico de foco que o Hyprland já tem.
    Timer {
        id: seed
        interval: 800
        onTriggered: {
            const list = [...Hyprland.toplevels.values]
                .filter(toplevel => toplevel.lastIpcObject?.focusHistoryID !== undefined)
                .sort((a, b) => a.lastIpcObject.focusHistoryID - b.lastIpcObject.focusHistoryID)
                .map(toplevel => toplevel.address)
            root.recent = [...root.recent, ...list.filter(address => !root.recent.includes(address))]
        }
    }

    Component.onCompleted: {
        Hyprland.refreshToplevels()
        seed.start()
    }
}
