pragma Singleton

import QtQuick
import Quickshell

// Tokens do Ayu Shell (paleta Ayu Mirage escura, raios e durações).
Singleton {
    // Superfícies
    readonly property color desk: "#1A1F29"
    readonly property color surface: "#232834"
    readonly property color surfaceBorder: "#2E3542"
    readonly property color raised: "#2C333F"
    readonly property color raisedAlt: "#2A303B"
    readonly property color track: "#333B47"
    readonly property color divider: "#333B49"
    readonly property color sunken: "#1B2028"
    readonly property color dim: "#4A5262"
    readonly property color dimmer: "#3A4250"
    readonly property color onAccent: "#1F2430"

    // Texto
    readonly property color text: "#CCCAC2"
    readonly property color textBright: "#E6E1CF"
    readonly property color textMuted: "#8A9199"
    readonly property color textFaint: "#707A8C"
    readonly property color textGhost: "#5C6773"

    // Acentos
    readonly property color yellow: "#FFCC66"
    readonly property color cyan: "#5CCFE6"
    readonly property color green: "#BAE67E"
    readonly property color purple: "#DFBFFF"
    readonly property color orange: "#FFA759"
    readonly property color red: "#FF6666"

    // Fundos tingidos dos acentos (ícones redondos, badges)
    readonly property color greenTint: "#2F3A33"
    readonly property color purpleTint: "#3A3242"
    readonly property color cyanTint: "#2A3A42"
    readonly property color redTint: "#3A2A2E"
    readonly property color yellowTint: "#3A3528"
    readonly property color orangeTint: "#3A3029"

    readonly property string font: "CaskaydiaCove Nerd Font"
    readonly property string iconFont: "Phosphor-Fill"

    // Geometria
    readonly property int gap: 14
    // Barra compacta: margem de cima menor que o gap lateral.
    readonly property int barMargin: 8
    readonly property int barHeight: 48
    readonly property int barRadius: 20
    // Altura ocupada pela barra (margem + barra); painéis pendurados começam
    // um pouco acima disso para se fundir com a borda inferior da barra.
    readonly property int barBottom: barMargin + barHeight
    readonly property int hangTop: barBottom - 8

    // Animações: curtas e com desaceleração no fim.
    readonly property int fast: 110
    readonly property int normal: 160
    readonly property int slow: 220
    readonly property int easing: Easing.OutCubic

    // Datas sempre em português, minúsculas e sem pontos ("qui 03 set").
    readonly property var locale: Qt.locale("pt_BR")

    function date(value: var, format: string): string {
        return value.toLocaleString(locale, format).toLowerCase().replace(/\./g, "")
    }

    function usageColor(percent: real): color {
        if (percent >= 85) return red
        if (percent >= 50) return orange
        return green
    }
}
