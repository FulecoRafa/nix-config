import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Lançador (super + espaço): resultados agrupados à esquerda, preview à
// direita. Prefixos: "=" calcula com o fend, ">" busca no clipboard, ":"
// busca emoji e símbolos, "/" busca arquivos na home (vazio = recentes) e
// "!" lista as janelas abertas para fechar ou matar. Sem prefixo, frases como
// "timer 10m", "alarme 7:30" e "ws 3" viram ações rápidas. Tab alterna o
// escopo da busca; arquivos podem ser arrastados para fora do lançador.
Scope {
    id: root

    readonly property bool shown: ShellState.panel === "launcher"
    readonly property var scopes: ["tudo", "apps", "comandos", "scripts", "arquivos"]
    readonly property string home: Quickshell.env("HOME")

    property string query: ""
    readonly property string prefix: query.startsWith("=") ? "calc"
        : query.startsWith(">") ? "clip"
        : query.startsWith(":") ? "glyph"
        : query.startsWith("/") ? "file"
        : query.startsWith("!") ? "win" : ""
    readonly property string needle: (prefix ? query.slice(1) : query).trim().toLowerCase()
    property int current: 0

    property var clipboard: []
    property var scripts: []
    property var files: []
    // Data de modificação (ms) dos arquivos recentes do "/" vazio.
    property var fileStamps: ({})
    property var windows: []
    property var bookmarks: []
    property string calcResult: ""
    property string calcError: ""
    property string clipPreview: ""
    property string clipImage: ""

    function open(text: string): void {
        query = text
        input.text = text
        current = 0
        ShellState.open("launcher")
        clipLoader.running = true
        scriptLoader.running = true
    }

    function close(): void {
        if (shown) ShellState.close()
    }

    onShownChanged: if (shown) {
        input.forceActiveFocus()
        clipLoader.running = true
        scriptLoader.running = true
    } else {
        input.text = ""
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            if (root.shown) root.close()
            else root.open("")
        }

        function clipboard(): void {
            if (root.shown && root.prefix === "clip") root.close()
            else root.open(">")
        }

        // Abre já com um texto (ex.: "=" para a calculadora, ":" para emoji).
        function search(text: string): void {
            root.open(text)
        }
    }

    // ── busca ────────────────────────────────────────────────────────────

    // Pontua um texto contra a busca: começo > início de palavra > meio >
    // letras em ordem. -1 = não casa.
    function score(text: string, needle: string): real {
        if (needle === "") return 0
        const hay = text.toLowerCase()
        if (hay.startsWith(needle)) return 100
        const index = hay.indexOf(needle)
        if (index > 0 && /[\s\-_.·/]/.test(hay[index - 1])) return 75
        if (index > 0) return 50
        let position = 0
        for (const char of needle) {
            position = hay.indexOf(char, position)
            if (position < 0) return -1
            position++
        }
        return 15
    }

    function rank(items: var, limit: int): var {
        const scored = []
        for (const item of items) {
            let best = score(item.title, needle)
            if (needle !== "" && best < 0) {
                const extra = score(item.search ?? "", needle)
                best = extra >= 0 ? extra * 0.6 : -1
            }
            if (best < 0) continue
            const usage = Store.usage(item.key)
            scored.push({ item, value: best + Math.log(usage.count + 1) * 12 })
        }
        scored.sort((a, b) => b.value - a.value || a.item.title.localeCompare(b.item.title))
        return scored.slice(0, limit).map(entry => entry.item)
    }

    function terminalApp(command: string, klass: string): var {
        return ["ghostty", "--class=fuleco." + klass, "-e", command]
    }

    function shell(command: string): void {
        Quickshell.execDetached(["sh", "-c", command])
    }

    function copy(text: string): void {
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", text])
    }

    // hyprctl dispatch na janela em foco (o lançador é layer, não rouba o foco).
    function dispatch(...args): void {
        Quickshell.execDetached(["hyprctl", "dispatch", ...args])
    }

    // Diretório do arquivo, ou a própria pasta.
    function folderOf(item: var): string {
        return item.kind === "pasta" ? item.path : item.path.slice(0, item.path.lastIndexOf("/")) || "/"
    }

    function fileUri(path: string): string {
        return "file://" + encodeURI(path)
    }

    function relativeTime(stamp: real): string {
        if (!stamp) return "nunca"
        const now = new Date()
        const then = new Date(stamp)
        const minutes = Math.round((now - then) / 60000)
        if (minutes < 1) return "agora"
        if (minutes < 60) return "há " + minutes + " min"
        const time = Qt.formatTime(then, "HH:mm")
        if (then.toDateString() === now.toDateString()) return "hoje, " + time
        const yesterday = new Date(now.getTime() - 86400000)
        if (then.toDateString() === yesterday.toDateString()) return "ontem, " + time
        return Theme.date(then, "dd MMM") + ", " + time
    }

    // TUIs que abrem numa janela flutuante do ghostty.
    readonly property var terminalApps: [
        { name: "wifitui", icon: "wifi-high", accent: "cyan", about: "gerenciar redes · TUI no ghostty", long: "TUI para conectar, esquecer e diagnosticar redes.\nAbre em janela flutuante do ghostty.", shortcut: "" },
        { name: "btop", icon: "gauge", accent: "green", about: "monitor de recursos", long: "CPU, memória, disco, rede e processos.", shortcut: "" },
        { name: "yazi", icon: "folder", accent: "yellow", about: "gerenciador de arquivos", long: "Navegue, visualize e mova arquivos pelo teclado.", shortcut: "" },
        { name: "calcure", icon: "calendar-dots", accent: "purple", about: "calendário e tarefas", long: "Eventos aparecem no badge da barra e na gaveta.", shortcut: "" },
        { name: "wiremix", icon: "faders", accent: "orange", about: "mixer do pipewire", long: "Volume por dispositivo e por aplicativo.", shortcut: "" },
        { name: "bluetui", icon: "bluetooth", accent: "cyan", about: "dispositivos bluetooth", long: "Parear, conectar e confiar em dispositivos.", shortcut: "" }
    ]

    readonly property var appItems: {
        const items = []
        for (const app of terminalApps) {
            const command = terminalApp(app.name, app.name)
            items.push({
                key: "tui:" + app.name, group: "aplicativos", kind: "aplicativo",
                title: app.name, subtitle: app.about, description: app.long,
                icon: app.icon, accent: app.accent, search: app.about,
                command: command.join(" ").replace("--class=fuleco." + app.name + " ", ""), shortcut: app.shortcut,
                pinId: "tui:" + app.name,
                run: () => Quickshell.execDetached(command)
            })
        }
        for (const entry of DesktopEntries.applications.values) {
            if (!entry.name || entry.noDisplay) continue
            // As TUIs acima já aparecem com ícone e descrição próprios.
            const base = entry.id.replace(/\.desktop$/, "").toLowerCase()
            if (terminalApps.some(app => app.name === base)) continue
            items.push({
                key: "app:" + entry.id, group: "aplicativos", kind: "aplicativo",
                title: entry.name.toLowerCase(), subtitle: (entry.comment || entry.genericName || "").toLowerCase(),
                description: entry.comment || entry.genericName || "",
                image: entry.icon, accent: "cyan",
                search: [entry.genericName, entry.comment, ...(entry.keywords ?? []), ...(entry.categories ?? [])].join(" "),
                command: (entry.command ?? []).join(" ").replace(/ %[fFuU]/g, ""), shortcut: "",
                pinId: entry.id,
                run: () => entry.execute()
            })
        }
        return items
    }

    readonly property var commandItems: {
        const list = [
            { title: "abrir painel de rede", subtitle: "central de controle → rede", icon: "sliders-horizontal", accent: "yellow", shortcut: "super + a", run: () => ShellState.openControl("rede") },
            { title: "abrir painel de som", subtitle: "central de controle → som", icon: "speaker-high", accent: "yellow", shortcut: "", run: () => ShellState.openControl("som") },
            { title: "abrir painel do sistema", subtitle: "central de controle → sistema", icon: "gear-six", accent: "yellow", shortcut: "", run: () => ShellState.openControl("sistema") },
            { title: "abrir gaveta de widgets", subtitle: "player, clima, energia, agenda", icon: "squares-four", accent: "purple", shortcut: "super + w", run: () => ShellState.open("drawer") },
            { title: "limites de uso de ia", subtitle: "claude code e codex", icon: "gauge", accent: "orange", shortcut: "super + u", run: () => ShellState.open("ai") },
            { title: "notificações", subtitle: "histórico e não perturbe", icon: "bell-simple", accent: "cyan", shortcut: "super + n", run: () => ShellState.open("notifications") },
            { title: "atalhos do teclado", subtitle: "hud com todos os atalhos", icon: "keyboard", accent: "cyan", shortcut: "super + /", run: () => ShellState.open("hud") },
            { title: "alternar modo avião", subtitle: "nmcli radio all", icon: "airplane-tilt", accent: "cyan", shortcut: "", run: () => root.shell("if nmcli radio wifi | grep -q enabled; then nmcli radio all off; else nmcli radio all on; fi") },
            { title: "alternar não perturbe", subtitle: NotifService.dnd ? "ligado agora" : "desligado agora", icon: "bell-slash", accent: "purple", shortcut: "", run: () => NotifService.dnd = !NotifService.dnd },
            { title: "alternar cafeína", subtitle: ShellState.caffeine ? "ligada agora" : "desligada agora", icon: "coffee", accent: "orange", shortcut: "", run: () => ShellState.caffeine = !ShellState.caffeine },
            { title: "capturar região", subtitle: "screenshot com anotação no gradia", icon: "selection", accent: "green", shortcut: "print", run: () => root.shell("sleep 0.3; hyprshot -m region -o /tmp -f fuleco-shot.png -s && gradia /tmp/fuleco-shot.png") },
            { title: "copiar texto da tela", subtitle: "ocr de uma região, abre o pdf pesquisável", icon: "text-aa", accent: "green", shortcut: "super + shift + o", run: () => root.shell("sleep 0.3; screenshot-ocr region") },
            { title: "seletor de cor", subtitle: "hyprpicker, copia o hex", icon: "eyedropper", accent: "orange", shortcut: "", run: () => root.shell("sleep 0.3; hyprpicker -a") },
            { title: "monitores", subtitle: "posição, resolução e escala", icon: "monitor", accent: "cyan", shortcut: "super + ctrl + m", run: () => Quickshell.execDetached(["quickshell", "-c", "fuleco", "ipc", "call", "monitors", "toggle"]) },
            { title: "bloquear tela", subtitle: "hyprlock", icon: "lock-key", accent: "cyan", shortcut: "super + ctrl + l", run: () => root.shell("hyprlock") },
            { title: "suspender", subtitle: "systemctl suspend", icon: "moon", accent: "purple", shortcut: "", run: () => root.shell("systemctl suspend") },
            { title: "recarregar shell", subtitle: "hyprctl reload + quickshell", icon: "arrows-clockwise", accent: "green", shortcut: "", run: () => root.shell("hyprctl reload; pkill -f 'quickshell -c fuleco'; sleep 0.3; hyprctl dispatch exec 'quickshell -c fuleco'") },
            { title: "limpar clipboard", subtitle: "cliphist wipe", icon: "trash", accent: "red", shortcut: "", run: () => root.shell("cliphist wipe") },
            // Atalhos para os modos do próprio lançador (não fecham o painel).
            { title: "encerrar app…", subtitle: "lista as janelas abertas · prefixo !", icon: "skull", accent: "red", shortcut: "!", stay: true, run: () => input.text = "!" },
            { title: "buscar arquivos", subtitle: "fd na home, vazio mostra os recentes · prefixo /", icon: "file-magnifying-glass", accent: "cyan", shortcut: "/", stay: true, run: () => input.text = "/" },
            // Janela em foco.
            { title: "fechar janela em foco", subtitle: "hyprctl dispatch killactive", icon: "x-circle", accent: "red", shortcut: "super + q", run: () => root.dispatch("killactive") },
            { title: "forçar encerrar janela em foco", subtitle: "sigkill no processo da janela", icon: "skull", accent: "red", shortcut: "", run: () => root.dispatch("forcekillactive") },
            { title: "alternar janela flutuante", subtitle: "togglefloating na janela em foco", icon: "app-window", accent: "purple", shortcut: "super + t", run: () => root.dispatch("togglefloating") },
            { title: "esconder janelas flutuantes", subtitle: "some com as flutuantes do workspace · de novo, elas voltam", icon: "eye-slash", accent: "purple", shortcut: "super + h", run: () => Windows.toggleFloats() },
            { title: "fixar janela em todos os workspaces", subtitle: "pin · só janelas flutuantes", icon: "push-pin", accent: "purple", shortcut: "", run: () => root.dispatch("pin") },
            { title: "tela cheia", subtitle: "fullscreen na janela em foco", icon: "corners-out", accent: "purple", shortcut: "", run: () => root.dispatch("fullscreen") },
            { title: "centralizar janela", subtitle: "centerwindow · só janelas flutuantes", icon: "crosshair", accent: "purple", shortcut: "", run: () => root.dispatch("centerwindow") },
            { title: "terminal flutuante", subtitle: "ghostty no centro da tela", icon: "terminal-window", accent: "green", shortcut: "super + alt + t", run: () => Quickshell.execDetached(["ghostty", "--class=fuleco.terminal"]) },
            { title: "pomodoro", subtitle: "timer de 25 minutos na gaveta", icon: "timer", accent: "orange", shortcut: "", run: () => Timers.startTimer(25, "pomodoro") },
            { title: "menu de energia", subtitle: "bloquear, sair, reiniciar, desligar", icon: "power", accent: "red", shortcut: "", run: () => ShellState.open("power") }
        ]
        return list.map(item => Object.assign({
            key: "cmd:" + item.title, group: "comandos do shell", kind: "comando",
            description: item.subtitle, command: item.subtitle, search: item.subtitle
        }, item))
    }

    readonly property var scriptItems: scripts.map(path => {
        const name = path.split("/").pop()
        const dir = path.slice(0, path.length - name.length - 1).replace(root.home, "~")
        return {
            key: "script:" + path, group: "scripts", kind: "script",
            title: name, subtitle: dir, description: "executável em " + dir,
            icon: "code", accent: "green", command: path.replace(root.home, "~"), shortcut: "", path: path,
            run: () => Quickshell.execDetached(["ghostty", "--class=fuleco.script", "-e", "sh", "-c", "\"$1\"; printf '\\n[enter fecha]'; read _", "sh", path])
        }
    })

    readonly property var fileEntries: files.map(path => {
        const name = path.replace(/\/$/, "").split("/").pop()
        const directory = path.endsWith("/")
        const parent = path.replace(/\/$/, "").slice(0, -name.length - 1).replace(root.home, "~")
        const stamp = fileStamps[path]
        return {
            key: "file:" + path, group: "arquivos & favoritos", kind: directory ? "pasta" : "arquivo",
            title: name, subtitle: (parent || "/") + (stamp ? " · " + root.relativeTime(stamp) : ""), description: path.replace(root.home, "~"),
            icon: directory ? "folder" : /\.(png|jpe?g|webp|gif|svg)$/i.test(name) ? "image" : /\.(md|txt|org)$/i.test(name) ? "file-text" : /\.(nix|qml|js|ts|py|rs|go|sh|fish)$/i.test(name) ? "file-code" : /\.pdf$/i.test(name) ? "file-pdf" : "file",
            accent: directory ? "yellow" : "cyan", command: "xdg-open " + path.replace(root.home, "~"), shortcut: "",
            path: path.replace(/\/$/, ""),
            run: () => Quickshell.execDetached(["xdg-open", path])
        }
    })

    readonly property var fileItems: {
        const result = fileEntries.slice()
        for (const mark of bookmarks) {
            result.push({
                key: "web:" + mark.url, group: "arquivos & favoritos", kind: "web",
                title: mark.name.toLowerCase(), subtitle: "favorito do helium", description: mark.url,
                icon: "star", accent: "yellow", command: mark.url, search: mark.url, shortcut: "", url: mark.url,
                run: () => Quickshell.execDetached(["helium", mark.url])
            })
        }
        return result
    }

    // Janelas abertas (prefixo "!"), da mais recente para a mais antiga.
    readonly property var windowItems: windows.map(client => {
        const entry = DesktopEntries.heuristicLookup(client.class)
        const name = (entry?.name || client.class || "janela").toLowerCase()
        return {
            key: "win:" + client.address, group: "janelas abertas", kind: "janela",
            title: name, subtitle: client.title + " · ws " + client.workspace.name,
            description: client.title + "\n" + client.class + " · pid " + client.pid,
            image: entry?.icon ?? "", icon: "app-window", accent: "red", search: client.title + " " + client.class,
            command: "hyprctl dispatch closewindow address:" + client.address, shortcut: "",
            address: client.address, pid: client.pid, windowClass: client.class,
            run: () => root.dispatch("closewindow", "address:" + client.address)
        }
    })

    // Frases que viram ação: "timer 10m chá", "alarme 7:30 acordar", "ws 3".
    readonly property var quickItems: {
        if (prefix !== "") return []
        const text = query.trim()
        const items = []
        let match = text.match(/^(?:timer|t)\s+(\d+(?:[.,]\d+)?)\s*(s|seg|m|min|h)?\b\s*(.*)$/i)
        if (match) {
            const value = Number(match[1].replace(",", "."))
            const unit = (match[2] ?? "m").toLowerCase()
            const minutes = unit.startsWith("s") ? value / 60 : unit === "h" ? value * 60 : value
            const label = match[3].trim()
            const span = unit.startsWith("s") ? value + " s" : unit === "h" ? value + " h" : value + " min"
            if (minutes > 0) items.push({
                title: "timer de " + span + (label ? " · " + label : ""), subtitle: "aparece na gaveta e avisa quando acabar",
                icon: "timer", accent: "orange", run: () => Timers.startTimer(minutes, label || "timer")
            })
        }
        match = text.match(/^(?:alarme|alarm|despertar)\s+(\d{1,2})(?:[:h](\d{2})?)?\s*(.*)$/i)
        if (match) {
            const time = match[1].padStart(2, "0") + ":" + (match[2] ?? "00")
            const label = match[3].trim()
            if (Number(match[1]) <= 23 && Number(match[2] ?? 0) <= 59) items.push({
                title: "alarme às " + time + (label ? " · " + label : ""), subtitle: "toca no próximo " + time,
                icon: "alarm", accent: "orange", run: () => Timers.addAlarm(time, label || "alarme")
            })
        }
        match = text.match(/^(?:ws|mover|mv)\s+(\d{1,2})$/i)
        if (match) items.push({
            title: "mover janela para o workspace " + match[1], subtitle: "e ir junto · use \"ir " + match[1] + "\" para só trocar",
            icon: "arrows-out-cardinal", accent: "purple", run: () => root.dispatch("movetoworkspace", match[1])
        })
        match = text.match(/^ir\s+(\d{1,2})$/i)
        if (match) items.push({
            title: "ir para o workspace " + match[1], subtitle: "hyprctl dispatch workspace " + match[1],
            icon: "squares-four", accent: "purple", run: () => root.dispatch("workspace", match[1])
        })
        return items.map(item => Object.assign({
            key: "quick:" + item.title, group: "ação rápida", kind: "ação", description: item.subtitle,
            command: item.subtitle, shortcut: ""
        }, item))
    }

    readonly property var clipItems: clipboard.map(line => {
        const tab = line.indexOf("\t")
        const id = line.slice(0, tab)
        const text = line.slice(tab + 1)
        const binary = text.startsWith("[[ binary data")
        return {
            key: "clip:" + id, group: "clipboard", kind: binary ? "imagem" : "texto",
            title: binary ? "imagem" : text.replace(/\s+/g, " ").trim(), subtitle: binary ? text.replace(/^\[\[ binary data |\]\]$/g, "") : text.length + " caracteres",
            description: "", icon: binary ? "image" : "clipboard-text", accent: "cyan", command: "cliphist decode " + id,
            shortcut: "", clipId: id, clipLine: line, binary,
            run: () => Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "sh", line])
        }
    })

    readonly property var glyphItems: {
        if (needle === "") return Emoji.list.slice(0, 40).map(glyphItem)
        // Nome exato e começo de palavra vêm antes de "contém".
        const result = []
        for (const pair of Emoji.list) {
            const name = pair[1]
            const value = name === needle ? 3 : name.startsWith(needle) ? 2 : (" " + name).includes(" " + needle) ? 1 : name.includes(needle) ? 0 : -1
            if (value >= 0) result.push({ pair, value })
        }
        result.sort((a, b) => b.value - a.value)
        return result.slice(0, 60).map(entry => glyphItem(entry.pair))
    }

    function glyphItem(pair: var): var {
        return {
            key: "glyph:" + pair[0], group: "emoji e símbolos", kind: "emoji",
            title: pair[1], subtitle: "U+" + pair[0].codePointAt(0).toString(16).toUpperCase(),
            description: "", glyph: pair[0], accent: "yellow", command: pair[0], shortcut: "",
            run: () => root.copy(pair[0])
        }
    }

    readonly property var results: {
        if (prefix === "calc") {
            if (needle === "") return []
            return [{
                key: "calc", group: "calculadora", kind: "fend",
                title: calcError !== "" ? "…" : calcResult, subtitle: "= " + query.slice(1).trim(),
                description: calcError, icon: "calculator", accent: "purple", command: "fend '" + query.slice(1).trim() + "'", shortcut: "",
                run: () => root.copy(root.calcResult)
            }]
        }
        if (prefix === "clip") return needle === "" ? clipItems.slice(0, 80) : rank(clipItems, 80)
        if (prefix === "glyph") return glyphItems
        if (prefix === "file") return fileEntries.map(item => Object.assign({}, item, { group: needle === "" ? "modificados nos últimos 7 dias" : "arquivos na home" }))
        if (prefix === "win") return needle === "" ? windowItems : rank(windowItems, 60)

        const scope = ShellState.launcherScope
        const all = scope === "tudo"
        let list = []
        if (all && needle === "") {
            const recent = [...appItems, ...commandItems]
                .filter(item => Store.usage(item.key).count > 0)
                .sort((a, b) => Store.usage(b.key).last - Store.usage(a.key).last)
                .slice(0, 5)
                .map(item => Object.assign({}, item, { group: "recentes" }))
            list = recent.concat(rank(appItems, 40))
        } else {
            list = quickItems.slice()
            if (all || scope === "apps") list = list.concat(rank(appItems, all ? 6 : 60))
            if (all || scope === "comandos") list = list.concat(rank(commandItems, all ? 4 : 40))
            if (all || scope === "scripts") list = list.concat(rank(scriptItems, all ? 3 : 40))
            if (all || scope === "arquivos") list = list.concat(rank(fileItems, all ? 6 : 40))
        }
        return list
    }

    readonly property var selected: results[Math.min(current, results.length - 1)] ?? null

    onResultsChanged: if (current >= results.length) current = Math.max(0, results.length - 1)
    onQueryChanged: {
        current = 0
        // prefix e needle são bindings: só ficam atualizados depois deste handler.
        Qt.callLater(root.queryAsync)
    }
    function queryAsync(): void {
        if (prefix === "calc") calcDebounce.restart()
        else if (prefix === "file") fileDebounce.restart()
        else if (prefix === "win") {
            files = []
            windowLoader.running = true
        } else if (prefix === "" && needle.length >= 2 && (ShellState.launcherScope === "tudo" || ShellState.launcherScope === "arquivos")) fileDebounce.restart()
        else files = []
    }
    onSelectedChanged: {
        clipPreview = ""
        clipImage = ""
        if (selected?.clipId) clipDecode.restart()
    }

    function run(item: var): void {
        if (!item) return
        if (item.key !== "calc" && !/^(clip|win|quick):/.test(item.key)) Store.used(item.key)
        if (!item.stay) close()
        item.run()
    }

    function actionsFor(item: var): var {
        if (!item) return []
        const kind = item.kind
        if (kind === "aplicativo") return [
            { icon: "arrow-elbow-down-left", label: item.key.startsWith("tui:") ? "abrir no ghostty" : "abrir", key: "enter", run: () => root.run(item) },
            { icon: "push-pin", label: Store.isPinned(item.pinId) ? "desafixar da barra" : "fixar na barra", key: "ctrl+p", run: () => Store.togglePin(item.pinId) },
            { icon: "terminal-window", label: "copiar comando", key: "ctrl+c", run: () => { root.copy(item.command); root.close() } }
        ]
        if (kind === "arquivo" || kind === "pasta") return [
            { icon: "arrow-elbow-down-left", label: "abrir", key: "enter", run: () => root.run(item) },
            { icon: "folder-open", label: "abrir no yazi", key: "ctrl+o", run: () => { root.close(); Quickshell.execDetached(["ghostty", "--class=fuleco.yazi", "-e", "yazi", item.path]) } },
            { icon: "files", label: kind === "pasta" ? "abrir no gerenciador" : "mostrar na pasta", key: "ctrl+f", run: () => { root.close(); Quickshell.execDetached(["xdg-open", root.folderOf(item)]) } },
            { icon: "terminal-window", label: "terminal aqui", key: "ctrl+t", run: () => { root.close(); Quickshell.execDetached(["ghostty", "--class=fuleco.terminal", "--working-directory=" + root.folderOf(item)]) } },
            ...(kind === "arquivo" ? [{ icon: "pencil-simple", label: "editar no helix", key: "ctrl+e", run: () => { root.close(); Quickshell.execDetached(["ghostty", "--class=fuleco.editor", "--working-directory=" + root.folderOf(item), "-e", "hx", item.path]) } }] : []),
            { icon: "copy", label: "copiar caminho", key: "ctrl+c", run: () => { root.copy(item.path); root.close() } },
            // Cola como arquivo no nautilus, telegram, navegador…
            { icon: "paperclip", label: "copiar como arquivo", key: "ctrl+u", run: () => { Quickshell.execDetached(["sh", "-c", "printf '%s\\r\\n' \"$1\" | wl-copy -t text/uri-list", "sh", root.fileUri(item.path)]); root.close() } }
        ]
        if (kind === "janela") return [
            { icon: "x-circle", label: "fechar janela", key: "enter", run: () => root.run(item) },
            { icon: "skull", label: "forçar encerrar (kill -9)", key: "ctrl+x", run: () => { root.close(); Quickshell.execDetached(["kill", "-9", String(item.pid)]) } },
            { icon: "arrow-square-out", label: "ir para a janela", key: "ctrl+f", run: () => { root.close(); root.dispatch("focuswindow", "address:" + item.address) } },
            { icon: "copy", label: "copiar classe", key: "ctrl+c", run: () => { root.copy(item.windowClass); root.close() } }
        ]
        if (kind === "web") return [
            { icon: "arrow-elbow-down-left", label: "abrir no helium", key: "enter", run: () => root.run(item) },
            { icon: "copy", label: "copiar link", key: "ctrl+c", run: () => { root.copy(item.url); root.close() } }
        ]
        if (kind === "texto" || kind === "imagem") return [
            { icon: "arrow-elbow-down-left", label: "copiar de volta", key: "enter", run: () => root.run(item) },
            { icon: "trash", label: "apagar do histórico", key: "ctrl+d", run: () => { Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "sh", item.clipLine]); root.clipboard = root.clipboard.filter(line => line !== item.clipLine) } }
        ]
        if (kind === "script") return [
            { icon: "arrow-elbow-down-left", label: "executar no ghostty", key: "enter", run: () => root.run(item) },
            { icon: "copy", label: "copiar caminho", key: "ctrl+c", run: () => { root.copy(item.path); root.close() } }
        ]
        return [{ icon: "arrow-elbow-down-left", label: item.kind === "fend" || item.kind === "emoji" ? "copiar" : "executar", key: "enter", run: () => root.run(item) }]
    }

    function shortcut(event: var): bool {
        const actions = actionsFor(selected)
        if (event.key < Qt.Key_A || event.key > Qt.Key_Z) return false
        const name = "ctrl+" + String.fromCharCode(event.key).toLowerCase()
        const action = actions.find(entry => entry.key === name)
        if (!action) return false
        action.run()
        return true
    }

    // ── fontes externas ─────────────────────────────────────────────────

    Process {
        id: clipLoader
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.clipboard = text.trim() === "" ? [] : text.trim().split("\n").slice(0, 300)
        }
    }

    Timer {
        id: clipDecode
        interval: 60
        onTriggered: {
            const item = root.selected
            if (!item?.clipId) return
            if (item.binary) {
                const out = Quickshell.env("XDG_RUNTIME_DIR") + "/fuleco-clip-" + item.clipId + ".png"
                clipDecoder.target = out
                clipDecoder.command = ["sh", "-c", "[ -s \"$2\" ] || printf '%s' \"$1\" | cliphist decode > \"$2\"; echo ok", "sh", item.clipLine, out]
            } else {
                clipDecoder.target = ""
                clipDecoder.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist decode | head -c 4000", "sh", item.clipLine]
            }
            clipDecoder.running = true
        }
    }

    Process {
        id: clipDecoder
        property string target
        stdout: StdioCollector {
            onStreamFinished: {
                if (clipDecoder.target !== "") root.clipImage = "file://" + clipDecoder.target
                else root.clipPreview = text
            }
        }
    }

    Process {
        id: scriptLoader
        command: ["sh", "-c", "for d in \"$HOME/.local/bin\" \"$HOME/bin\" \"$HOME/.config/fuleco/scripts\"; do [ -d \"$d\" ] && find \"$d\" -maxdepth 1 \\( -type f -o -type l \\) -perm -u+x; done 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.scripts = text.trim() === "" ? [] : text.trim().split("\n")
        }
    }

    Timer {
        id: fileDebounce
        interval: 180
        onTriggered: {
            const excludes = ["--exclude", ".git", "--exclude", "node_modules", "--exclude", ".cache", "--exclude", ".local/share"]
            fileSearch.running = false
            if (root.prefix === "file" && root.needle === "") {
                // "/" sozinho: arquivos mexidos na última semana, mais novos primeiro.
                fileSearch.command = ["sh", "-c", "fd --type f --changed-within 7d \"$@\" . \"$HOME\" -0 | xargs -0 -r stat -c '%Y\t%n' | sort -rn | head -30", "sh", ...excludes]
            } else {
                // Com "/" vale caminho parcial ("/ nix/hosts") e vem mais resultado.
                const full = root.prefix === "file" && root.needle.includes("/")
                fileSearch.command = ["fd", "--max-results", root.prefix === "file" ? "40" : "8", "--ignore-case", ...(full ? ["--full-path"] : []), ...excludes, "--", root.needle, root.home]
            }
            fileSearch.running = true
        }
    }

    Process {
        id: fileSearch
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim() === "" ? [] : text.trim().split("\n")
                const stamps = {}
                root.files = lines.map(line => {
                    const tab = line.indexOf("\t")
                    if (tab < 0) return line
                    const path = line.slice(tab + 1)
                    stamps[path] = Number(line.slice(0, tab)) * 1000
                    return path
                })
                root.fileStamps = stamps
            }
        }
    }

    Process {
        id: windowLoader
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.windows = JSON.parse(text)
                        .filter(client => client.mapped && !client.hidden && client.pid > 0)
                        .sort((a, b) => a.focusHistoryID - b.focusHistoryID)
                } catch (error) {
                    root.windows = []
                }
            }
        }
    }

    Timer {
        id: calcDebounce
        interval: 120
        onTriggered: {
            calc.running = false
            calc.command = ["fend", root.query.slice(1).trim()]
            calc.running = true
        }
    }

    Process {
        id: calc
        stdout: StdioCollector {
            onStreamFinished: {
                root.calcResult = text.trim()
                root.calcError = ""
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") root.calcError = text.trim()
        }
    }

    FileView {
        path: root.home + "/.config/net.imput.helium/Default/Bookmarks"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const marks = []
            const walk = node => {
                if (!node) return
                if (node.type === "url") marks.push({ name: node.name, url: node.url })
                for (const child of node.children ?? []) walk(child)
            }
            try {
                const roots = JSON.parse(text()).roots
                for (const key in roots) walk(roots[key])
            } catch (error) {}
            root.bookmarks = marks
        }
    }

    // ── janela ───────────────────────────────────────────────────────────

    PanelWindow {
        id: win

        readonly property int listHeight: Math.max(260, Math.min(580, (screen?.height ?? 1080) - Theme.hangTop - 220))

        screen: ShellState.screen
        visible: root.shown || card.opacity > 0
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "fuleco-launcher"
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        implicitWidth: 1020
        implicitHeight: content.implicitHeight

        anchors.top: true
        margins.top: Theme.hangTop

        HyprlandFocusGrab {
            active: root.shown && !ShellState.capturing
            windows: [win, ...ShellState.barWindows]
            onCleared: if (!ShellState.capturing) root.close()
        }

        Column {
            id: content

            width: parent.width
            spacing: 12
            opacity: root.shown ? 1 : 0
            y: root.shown ? 0 : -14

            Behavior on opacity { NumberAnimation { duration: Theme.fast } }
            Behavior on y { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }

            Rectangle {
                id: card

                width: parent.width
                height: cardColumn.implicitHeight
                opacity: content.opacity
                color: Theme.surface
                border.color: Theme.surfaceBorder
                radius: 28
                topLeftRadius: 0
                topRightRadius: 0
                clip: true

                Rectangle { x: 1; width: parent.width - 2; height: 2; color: Theme.surface }

                Column {
                    id: cardColumn
                    width: parent.width

                    // Campo de busca
                    RowLayout {
                        x: 24
                        width: parent.width - 48
                        height: 28 + 30 + 20
                        spacing: 14

                        Icon {
                            Layout.topMargin: 8
                            name: ({ calc: "calculator", clip: "clipboard-text", glyph: "smiley", file: "file-magnifying-glass", win: "skull" })[root.prefix] ?? "magnifying-glass"
                            size: 22
                            color: Theme.textMuted
                        }

                        TextInput {
                            id: input

                            Layout.fillWidth: true
                            Layout.topMargin: 8
                            color: Theme.textBright
                            selectionColor: Theme.yellow
                            selectedTextColor: Theme.onAccent
                            font.family: Theme.font
                            font.pixelSize: 22
                            cursorDelegate: Rectangle {
                                width: 2
                                color: Theme.yellow
                                visible: input.cursorVisible
                            }
                            onTextChanged: root.query = text

                            Text {
                                visible: input.text === ""
                                text: "buscar apps, comandos, arquivos…  / arquivos  ! apps abertos"
                                color: Theme.textGhost
                                font: input.font
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape) {
                                    root.close()
                                } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_N && event.modifiers & Qt.ControlModifier)) {
                                    root.current = Math.min(root.current + 1, root.results.length - 1)
                                } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && event.modifiers & Qt.ControlModifier)) {
                                    root.current = Math.max(root.current - 1, 0)
                                } else if (event.key === Qt.Key_PageDown) {
                                    root.current = Math.min(root.current + 8, root.results.length - 1)
                                } else if (event.key === Qt.Key_PageUp) {
                                    root.current = Math.max(root.current - 8, 0)
                                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                    const index = root.scopes.indexOf(ShellState.launcherScope)
                                    const step = event.key === Qt.Key_Backtab ? root.scopes.length - 1 : 1
                                    ShellState.launcherScope = root.scopes[(index + step) % root.scopes.length]
                                    root.current = 0
                                    if (root.needle.length >= 2) fileDebounce.restart()
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.run(root.selected)
                                } else if (event.modifiers & Qt.ControlModifier && !(input.selectedText !== "" && (event.key === Qt.Key_C || event.key === Qt.Key_X))) {
                                    if (!root.shortcut(event)) return
                                } else {
                                    return
                                }
                                event.accepted = true
                            }
                        }

                        Chip {
                            Layout.topMargin: 8
                            label: ({ calc: "fend", clip: "clipboard", glyph: "emoji", file: "arquivos", win: "janelas" })[root.prefix] ?? ShellState.launcherScope
                            active: false
                            fontSize: 11
                            onClicked: {
                                const index = root.scopes.indexOf(ShellState.launcherScope)
                                ShellState.launcherScope = root.scopes[(index + 1) % root.scopes.length]
                                input.forceActiveFocus()
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.raised }

                    Row {
                        width: parent.width
                        height: win.listHeight

                        // Resultados
                        ListView {
                            id: list

                            width: parent.width * 0.56
                            height: parent.height
                            topMargin: 14
                            bottomMargin: 14
                            leftMargin: 14
                            rightMargin: 14
                            clip: true
                            spacing: 4
                            model: root.results
                            currentIndex: root.current
                            highlightMoveDuration: 0
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Item {
                                id: row

                                required property var modelData
                                required property int index
                                readonly property bool isCurrent: index === root.current
                                // Título do grupo antes do primeiro item de cada grupo.
                                readonly property bool firstOfGroup: index === 0 || root.results[index - 1]?.group !== modelData.group

                                width: ListView.view.width - 28
                                height: 54 + (firstOfGroup ? groupTitle.height : 0)

                                Text {
                                    id: groupTitle
                                    visible: row.firstOfGroup
                                    topPadding: row.index === 0 ? 0 : 8
                                    leftPadding: 12
                                    bottomPadding: 6
                                    text: row.modelData.group
                                    color: Theme.textGhost
                                    font.family: Theme.font
                                    font.pixelSize: 11
                                }

                                Rectangle {
                                    y: rowBody.y
                                    width: parent.width
                                    height: rowBody.height
                                    radius: 16
                                    color: row.isCurrent ? "#2F3644" : rowHover.hovered ? Theme.raisedAlt : "transparent"
                                }

                                RowLayout {
                                    id: rowBody
                                    x: 12
                                    y: row.firstOfGroup ? groupTitle.height : 0
                                    width: parent.width - 24
                                    height: 54
                                    spacing: 12

                                    ItemTile {
                                        id: rowTile
                                        item: row.modelData
                                        size: 32
                                        radius: 11
                                        iconSize: 17
                                        highlighted: row.isCurrent
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            width: parent.width
                                            text: row.modelData.title
                                            elide: Text.ElideRight
                                            color: row.isCurrent ? Theme.textBright : Theme.text
                                            font.family: Theme.font
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            width: parent.width
                                            visible: text !== ""
                                            text: row.modelData.subtitle ?? ""
                                            elide: Text.ElideRight
                                            color: Theme.textMuted
                                            font.family: Theme.font
                                            font.pixelSize: 11
                                        }
                                    }

                                    Text {
                                        text: row.modelData.kind
                                        color: Theme.textFaint
                                        font.family: Theme.font
                                        font.pixelSize: 11
                                    }
                                }

                                HoverHandler {
                                    id: rowHover
                                    target: rowBody
                                    cursorShape: row.draggable ? (rowDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.PointingHandCursor
                                    // A imagem do arrasto precisa estar pronta antes de o arrasto começar.
                                    onHoveredChanged: if (hovered && row.draggable) rowTile.grabToImage(result => row.Drag.imageSource = result.url)
                                }
                                TapHandler {
                                    target: rowBody
                                    onTapped: root.current = row.index
                                    onDoubleTapped: root.run(row.modelData)
                                }

                                // Arquivos saem do lançador arrastando (text/uri-list, como do
                                // nautilus): solta no navegador, chat, terminal, yazi…
                                readonly property bool draggable: !!modelData.path && (modelData.kind === "arquivo" || modelData.kind === "pasta")

                                Drag.active: rowDrag.active
                                Drag.dragType: Drag.Automatic
                                Drag.supportedActions: Qt.CopyAction
                                Drag.hotSpot: Qt.point(16, 16)
                                Drag.mimeData: draggable ? {
                                    "text/uri-list": root.fileUri(modelData.path) + "\r\n",
                                    "text/plain": modelData.path
                                } : ({})
                                Drag.onDragFinished: dropAction => {
                                    if (dropAction !== Qt.IgnoreAction) root.close()
                                }

                                DragHandler {
                                    id: rowDrag
                                    target: null
                                    enabled: row.draggable
                                    onActiveChanged: if (active) root.current = row.index
                                }
                            }

                            Text {
                                visible: root.results.length === 0
                                anchors.centerIn: parent
                                text: root.prefix === "calc" && root.needle === "" ? "digite uma expressão, ex.: = 1440/9*16"
                                    : root.prefix === "file" && fileSearch.running ? "procurando…"
                                    : root.prefix === "file" && root.needle === "" ? "nenhum arquivo mudou nos últimos 7 dias"
                                    : root.prefix === "win" ? "nenhuma janela aberta"
                                    : "nada encontrado"
                                color: Theme.textGhost
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                        }

                        Rectangle { width: 1; height: parent.height; color: Theme.raised }

                        // Preview
                        Item {
                            width: parent.width * 0.44 - 1
                            height: parent.height
                            clip: true

                            ColumnLayout {
                                visible: root.selected !== null
                                x: 24
                                y: 24
                                width: parent.width - 48
                                height: parent.height - 48
                                spacing: 18

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 10
                                    spacing: 12

                                    ItemTile {
                                        visible: !root.clipImage
                                        Layout.alignment: Qt.AlignHCenter
                                        item: root.selected
                                        size: 72
                                        radius: 24
                                        iconSize: 38
                                        highlighted: false
                                    }

                                    Image {
                                        visible: root.clipImage !== ""
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: parent.width
                                        Layout.preferredHeight: 180
                                        fillMode: Image.PreserveAspectFit
                                        source: root.clipImage
                                        asynchronous: true
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: root.selected?.kind === "texto" ? "texto copiado" : root.selected?.title ?? ""
                                        elide: Text.ElideRight
                                        color: Theme.textBright
                                        font.family: Theme.font
                                        font.pixelSize: 18
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.maximumHeight: 140
                                        visible: text !== ""
                                        horizontalAlignment: root.clipPreview ? Text.AlignLeft : Text.AlignHCenter
                                        text: root.clipPreview || root.selected?.description || ""
                                        // Caminho numa linha só, cortado no meio.
                                        wrapMode: root.selected?.path ? Text.NoWrap : Text.Wrap
                                        elide: root.selected?.path ? Text.ElideMiddle : Text.ElideRight
                                        lineHeight: 1.4
                                        clip: true
                                        textFormat: Text.PlainText
                                        color: Theme.textMuted
                                        font.family: Theme.font
                                        font.pixelSize: 12
                                    }
                                }

                                // Detalhes
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: details.implicitHeight + 32
                                    radius: 18
                                    color: Theme.raisedAlt

                                    ColumnLayout {
                                        id: details

                                        x: 16
                                        y: 16
                                        width: parent.width - 32
                                        spacing: 10

                                        Repeater {
                                            model: {
                                                const item = root.selected
                                                if (!item) return []
                                                const usage = Store.usage(item.key)
                                                // Arquivo já mostra o caminho na descrição; sobra espaço para as ações.
                                                const rows = /^(file|quick):/.test(item.key) ? [] : [["comando", item.command, false]]
                                                if (!/^(clip|glyph|win|quick):/.test(item.key) && item.key !== "calc") {
                                                    rows.push(["último uso", root.relativeTime(usage.last), false])
                                                    rows.push(["frequência", usage.count === 1 ? "1 abertura" : usage.count + " aberturas", false])
                                                }
                                                if (item.shortcut) rows.push(["atalho", item.shortcut, true])
                                                return rows
                                            }

                                            RowLayout {
                                                required property var modelData
                                                Layout.fillWidth: true
                                                spacing: 12

                                                Text {
                                                    text: modelData[0]
                                                    color: Theme.textFaint
                                                    font.family: Theme.font
                                                    font.pixelSize: 12
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    horizontalAlignment: Text.AlignRight
                                                    text: modelData[1]
                                                    elide: Text.ElideMiddle
                                                    color: modelData[2] ? Theme.yellow : Theme.text
                                                    font.family: Theme.font
                                                    font.pixelSize: 12
                                                }
                                            }
                                        }
                                    }
                                }

                                // Ações
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: "ações"
                                        color: Theme.textGhost
                                        font.family: Theme.font
                                        font.pixelSize: 11
                                    }

                                    Repeater {
                                        model: root.actionsFor(root.selected)

                                        Rectangle {
                                            id: action
                                            required property var modelData
                                            required property int index

                                            Layout.fillWidth: true
                                            // Mais compacto quando a lista é longa (arquivos têm 7 ações).
                                            implicitHeight: root.actionsFor(root.selected).length > 5 ? 32 : 38
                                            radius: 14
                                            color: index === 0 ? Theme.raised : actionHover.hovered ? Theme.raisedAlt : "transparent"

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 12
                                                spacing: 10

                                                Icon {
                                                    name: action.modelData.icon
                                                    size: 14
                                                    color: action.index === 0 ? Theme.yellow : Theme.textMuted
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: action.modelData.label
                                                    color: action.index === 0 ? Theme.text : Theme.textMuted
                                                    font.family: Theme.font
                                                    font.pixelSize: 12
                                                }
                                                Text {
                                                    text: action.modelData.key
                                                    color: action.index === 0 ? Theme.textFaint : Theme.textGhost
                                                    font.family: Theme.font
                                                    font.pixelSize: 12
                                                }
                                            }

                                            HoverHandler { id: actionHover; cursorShape: Qt.PointingHandCursor }
                                            TapHandler { onTapped: action.modelData.run() }
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.raised }

                    // Rodapé
                    RowLayout {
                        x: 24
                        width: parent.width - 48
                        height: 43
                        spacing: 16

                        Text {
                            text: root.results.length === 1 ? "1 resultado" : root.results.length + " resultados"
                            color: Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
                        Item { Layout.fillWidth: true }
                        Repeater {
                            model: root.prefix === "file" ? ["arraste para outro app", "ctrl+f mostra na pasta", "ctrl+u copia o arquivo"]
                                : root.prefix === "win" ? ["ctrl+x força (kill -9)", "ctrl+f vai para a janela", "↑↓ navega"]
                                : ["tab alterna escopo", "ctrl+p fixa na barra", "↑↓ navega"]
                            Text {
                                required property string modelData
                                text: modelData
                                color: Theme.textFaint
                                font.family: Theme.font
                                font.pixelSize: 11
                            }
                        }
                        Text {
                            text: root.prefix === "win" ? "enter fecha" : "enter executa"
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
                    }
                }
            }

            // Dicas de prefixo
            Row {
                visible: root.prefix === ""
                width: parent.width
                spacing: 12

                Repeater {
                    // Também há "alarme 7:30 acordar", "ws 3" e "ir 3" sem prefixo.
                    model: [
                        { icon: "calculator", color: Theme.purple, code: "=", after: " calcula", text: "=" },
                        { icon: "smiley", color: Theme.yellow, code: ":", after: " emoji", text: ":" },
                        { icon: "clipboard-text", color: Theme.cyan, code: ">", after: " clipboard", text: ">" },
                        { icon: "file-magnifying-glass", color: Theme.green, code: "/", after: " arquivos", text: "/" },
                        { icon: "skull", color: Theme.red, code: "!", after: " fechar apps", text: "!" },
                        { icon: "timer", color: Theme.orange, code: "timer", after: " 10m chá", text: "timer " }
                    ]

                    Rectangle {
                        id: hint
                        required property var modelData

                        width: (parent.width - 60) / 6
                        height: 54
                        radius: 20
                        color: hintHover.hovered ? Theme.raisedAlt : Theme.surface
                        border.color: Theme.surfaceBorder

                        Row {
                            anchors.centerIn: parent
                            spacing: 10

                            Icon { name: hint.modelData.icon; size: 20; color: hint.modelData.color; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                textFormat: Text.StyledText
                                text: "<font color='" + Theme.text + "'>" + hint.modelData.code + "</font>" + hint.modelData.after
                                color: Theme.textMuted
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                        }

                        HoverHandler { id: hintHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                input.text = hint.modelData.text
                                input.forceActiveFocus()
                            }
                        }
                    }
                }
            }
        }
    }

    // Ícone do item: glifo Phosphor, ícone do app ou o próprio emoji.
    component ItemTile: Rectangle {
        id: tile

        property var item
        property int size: 32
        property int iconSize: 17
        property bool highlighted: false
        readonly property color accent: Theme[item?.accent ?? "cyan"] ?? Theme.cyan

        implicitWidth: size
        implicitHeight: size
        color: highlighted ? "#33383F" : Theme.raised

        Icon {
            anchors.centerIn: parent
            visible: !tile.item?.image && !tile.item?.glyph
            name: tile.item?.icon ?? "app-window"
            size: tile.iconSize
            color: tile.accent
        }

        Image {
            anchors.centerIn: parent
            visible: !!tile.item?.image
            width: tile.iconSize + 4
            height: tile.iconSize + 4
            sourceSize: Qt.size(width * 2, height * 2)
            source: tile.item?.image ? Quickshell.iconPath(tile.item.image, "application-x-executable") : ""
            asynchronous: true
        }

        Text {
            anchors.centerIn: parent
            visible: !!tile.item?.glyph
            text: tile.item?.glyph ?? ""
            font.pixelSize: tile.iconSize
        }
    }
}
