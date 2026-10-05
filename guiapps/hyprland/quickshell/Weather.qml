pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Clima do wttr.in (local pelo IP), atualizado a cada 30 min. A última
// resposta fica em ~/.cache/fuleco-shell/weather.json para o widget já
// nascer preenchido.
Singleton {
    id: root

    readonly property string cache: Quickshell.env("HOME") + "/.cache/fuleco-shell/weather.json"

    property bool ready: false
    property string place: ""
    property int temperature: 0
    property int feelsLike: 0
    property int humidity: 0
    property int wind: 0
    property string description: ""
    property string icon: "cloud"
    property color color: Theme.yellow
    // Próximas três horas cheias de 3 em 3: { hour, temperature, icon, color, rain }
    property var hours: []

    // Códigos do WorldWeatherOnline (usados pelo wttr.in).
    readonly property var descriptions: ({
        113: "céu limpo", 116: "parcialmente nublado", 119: "nublado", 122: "encoberto",
        143: "névoa", 248: "neblina", 260: "neblina", 176: "chuva isolada", 263: "garoa",
        266: "garoa", 293: "chuva fraca", 296: "chuva fraca", 299: "chuva", 302: "chuva",
        305: "chuva forte", 308: "chuva forte", 353: "pancadas de chuva", 356: "pancadas fortes",
        359: "temporal", 200: "trovoadas", 386: "chuva com trovões", 389: "tempestade",
        392: "neve com trovões", 395: "neve forte"
    })

    function iconFor(code: int, night: bool): string {
        if (code === 113) return night ? "moon-stars" : "sun"
        if (code === 116) return night ? "cloud-moon" : "cloud-sun"
        if (code === 119 || code === 122) return "cloud"
        if ([143, 248, 260].includes(code)) return "cloud-fog"
        if ([200, 386, 389, 392, 395].includes(code)) return "cloud-lightning"
        if (code >= 179 && code <= 377 && ![263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359, 176].includes(code)) return "cloud-snow"
        return "cloud-rain"
    }

    function colorFor(icon: string): color {
        if (icon === "sun" || icon === "cloud-sun") return Theme.yellow
        if (icon === "moon-stars" || icon === "cloud-moon") return Theme.purple
        if (icon === "cloud-rain" || icon === "cloud-lightning" || icon === "cloud-snow") return Theme.cyan
        return Theme.textMuted
    }

    function parse(text: string): bool {
        let data
        try {
            data = JSON.parse(text)
        } catch (error) {
            return false
        }
        const current = data?.current_condition?.[0]
        if (!current) return false

        const hour = new Date().getHours()
        const night = hour < 6 || hour >= 18
        const code = Number(current.weatherCode)
        temperature = Number(current.temp_C)
        feelsLike = Number(current.FeelsLikeC)
        humidity = Number(current.humidity)
        wind = Number(current.windspeedKmph)
        description = descriptions[code] ?? (current.weatherDesc?.[0]?.value ?? "").trim().toLowerCase()
        icon = iconFor(code, night)
        color = colorFor(icon)
        place = (data.nearest_area?.[0]?.areaName?.[0]?.value ?? "").toLowerCase()

        // Horários de hoje e amanhã depois da hora atual.
        const upcoming = []
        for (const [dayIndex, day] of (data.weather ?? []).slice(0, 2).entries()) {
            for (const slot of day.hourly ?? []) {
                const slotHour = Number(slot.time) / 100
                if (dayIndex === 0 && slotHour <= hour) continue
                const slotNight = slotHour < 6 || slotHour >= 18
                const slotIcon = iconFor(Number(slot.weatherCode), slotNight)
                upcoming.push({
                    hour: slotHour + "h",
                    temperature: Number(slot.tempC),
                    icon: slotIcon,
                    color: colorFor(slotIcon),
                    rain: Number(slot.chanceofrain) / 100
                })
            }
        }
        hours = upcoming.slice(0, 3)
        ready = true
        return true
    }

    function refresh(): void {
        if (!fetcher.running) fetcher.running = true
    }

    FileView {
        id: cacheFile
        path: root.cache
        printErrors: false
        onLoaded: root.parse(text())
    }

    Process {
        id: fetcher
        command: ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && curl -sf -m 20 'https://wttr.in/?format=j1&lang=pt' -o \"$1.tmp\" && mv \"$1.tmp\" \"$1\" && cat \"$1\"", "sh", root.cache]
        stdout: StdioCollector {
            onStreamFinished: if (text !== "") root.parse(text)
        }
    }

    Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
