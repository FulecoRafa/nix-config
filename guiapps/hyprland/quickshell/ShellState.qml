pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Qual painel está aberto e em que monitor. Só um painel por vez:
// abrir outro fecha o anterior, como no design.
Singleton {
    id: root

    // "", "control", "power", "notifications", "drawer", "ai", "launcher", "hud"
    property string panel: ""
    property string controlTab: "rede"
    property string launcherScope: "tudo"
    property ShellScreen screen: focusedScreen()
    // Janelas da barra: cliques nelas não fecham o painel aberto (o próprio
    // botão da barra decide se alterna ou troca de painel).
    property var barWindows: []
    // Cafeína: impede a suspensão por inatividade enquanto ligada.
    // caffeineUntil: fim em ms desde a época; 0 = sem prazo.
    property bool caffeine: false
    property real caffeineUntil: 0
    property int caffeineMinutes: 0

    function setCaffeine(minutes: int): void {
        caffeineMinutes = minutes
        caffeineUntil = minutes > 0 ? Date.now() + minutes * 60000 : 0
        caffeine = true
    }

    onCaffeineChanged: if (!caffeine) {
        caffeineUntil = 0
        caffeineMinutes = 0
    }

    Timer {
        running: root.caffeine && root.caffeineUntil > 0
        interval: Math.max(1000, root.caffeineUntil - Date.now())
        repeat: true
        onTriggered: if (root.caffeineUntil > 0 && Date.now() >= root.caffeineUntil - 500) root.caffeine = false
    }

    function focusedScreen(): ShellScreen {
        const name = Hyprland.focusedMonitor?.name
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0] ?? null
    }

    function open(name: string): void {
        screen = focusedScreen()
        panel = name
    }

    function toggle(name: string): void {
        if (panel === name) panel = ""
        else open(name)
    }

    function close(): void {
        panel = ""
    }

    function openControl(tab: string): void {
        controlTab = tab
        if (panel !== "control") open("control")
    }
}
