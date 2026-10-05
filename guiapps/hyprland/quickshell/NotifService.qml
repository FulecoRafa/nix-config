pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Servidor de notificações. Guarda o histórico (painel) e a fila de popups.
Singleton {
    id: root

    readonly property var list: [...server.trackedNotifications.values].reverse()
    readonly property int count: server.trackedNotifications.values.length
    property var popups: []
    property bool dnd: false
    property var receivedTimes: ({})

    function clearAll(): void {
        for (const notification of [...server.trackedNotifications.values]) notification.dismiss()
        popups = []
    }

    function dropPopup(notification: var): void {
        popups = popups.filter(item => item !== notification)
    }

    // "agora", "4 min", "2 h", "ontem"
    function age(notification: var): string {
        const time = receivedTimes[notification?.id] ?? 0
        if (!time) return ""
        const minutes = Math.floor((Date.now() - time) / 60000)
        if (minutes < 1) return "agora"
        if (minutes < 60) return minutes + " min"
        if (minutes < 1440) return Math.floor(minutes / 60) + " h"
        return Math.floor(minutes / 1440) + " d"
    }

    // Cor do ícone redondo por app, seguindo o design.
    function accent(notification: var): string {
        const app = (notification?.appName || "").toLowerCase()
        if (notification?.urgency === NotificationUrgency.Critical) return "red"
        if (/calen|calcure|agenda/.test(app)) return "purple"
        if (/timer|pomodoro|alarm|relógio|clock/.test(app)) return "green"
        if (/claude|codex|ai-usage/.test(app)) return "orange"
        if (/discord|telegram|slack|mail/.test(app)) return "yellow"
        return "cyan"
    }

    // Corpo com o markup da especificação (b, i, u, a, br) para o StyledText;
    // qualquer outra tag aparece como texto.
    function markup(body: string): string {
        return (body ?? "")
            .replace(/&(?!(amp|lt|gt|quot|apos|#\d+|#x[0-9a-f]+);)/gi, "&amp;")
            .replace(/<(?!\/?(b|i|u)>|br\s*\/?>|a\s+href="[^"]*"\s*>|\/a>)/gi, "&lt;")
            .replace(/\n/g, "<br>")
    }

    function icon(notification: var): string {
        const app = (notification?.appName || "").toLowerCase()
        if (/calen|calcure|agenda/.test(app)) return "calendar-dots"
        if (/timer|pomodoro|alarm/.test(app)) return "timer"
        if (/download|helium|firefox|browser/.test(app)) return "download-simple"
        if (/screenshot|hyprshot|gradia/.test(app)) return "crop"
        if (/claude|codex|ai-usage/.test(app)) return "gauge"
        if (/discord|telegram|slack/.test(app)) return "chat-circle-dots"
        if (/mail/.test(app)) return "envelope-simple"
        if (/battery|power|upower/.test(app)) return "battery-warning"
        return "bell-simple"
    }

    NotificationServer {
        id: server

        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true
            root.receivedTimes[notification.id] = Date.now()
            if (!root.dnd) root.popups = [notification, ...root.popups].slice(0, 4)
        }
    }
}
