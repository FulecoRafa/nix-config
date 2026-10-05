import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Captura de tela. PRINT abre a barra de modos (região/janela/tela); a seleção
// em si é o slurp puro, via shell-capture. Tudo que é escolha acontece depois,
// no cartão "captura pronta": copiar, salvar, abrir no gradia, extrair texto.
// O cartão fica 8 s e vai para as notificações (clicar abre no gradia).
Scope {
    id: root

    readonly property var modes: [
        { id: "region", label: "região", icon: "selection" },
        { id: "window", label: "janela", icon: "app-window" },
        { id: "output", label: "tela", icon: "monitor" }
    ]
    property int modeIndex: 0
    property bool picking: false

    // Captura atual no cartão.
    property string path: ""
    property bool shown: false
    property string saved: ""
    property string ocrState: ""   // "", "running", "done", "error"
    property string ocrText: ""
    property string ocrPdf: ""
    property int shotWidth: 0
    property int shotHeight: 0

    readonly property string sizeText: shotWidth > 0 ? shotWidth + " × " + shotHeight : ""

    function open(): void {
        if (shown) dismiss(true)
        picking = true
    }

    function pick(index: int): void {
        modeIndex = index
        picking = false
        // Dá tempo da barra sumir antes do slurp congelar a tela.
        launch.restart()
    }

    function ready(file: string): void {
        if (shown) dismiss(true)
        path = file
        saved = ""
        ocrState = ""
        ocrText = ""
        ocrPdf = ""
        shotWidth = 0
        shotHeight = 0
        shown = true
        expiry.restart()
    }

    // Some com o cartão; com notify, a captura segue nas notificações.
    function dismiss(notify: bool): void {
        if (!shown) return
        shown = false
        ocr.running = false
        if (!notify) return
        const body = (saved ? "salva em <i>" + saved + "</i>" : "copiada para o clipboard")
            + (sizeText ? " · " + sizeText : "")
        Quickshell.execDetached(["sh", "-c",
            'a=$(notify-send -a screenshot -i "$1" -A default=editar -A edit="abrir no gradia" -A ocr="abrir OCR" "captura pronta" "$2"); '
            + 'case "$a" in default|edit) exec gradia "$1" ;; '
            // Sem OCR feito ainda, roda agora (abre o PDF pesquisável no fim).
            + 'ocr) if [ -n "$3" ]; then exec papers "$3"; else exec screenshot-ocr "$1"; fi ;; esac',
            "sh", path, body, ocrPdf])
    }

    function copy(): void {
        Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"', "sh", path])
        dismiss(true)
    }

    function save(): void {
        saver.running = true
    }

    function edit(): void {
        Quickshell.execDetached(["gradia", path])
        dismiss(false)
    }

    function extract(): void {
        if (ocrState === "running") return
        ocrState = "running"
        ocr.running = true
    }

    IpcHandler {
        target: "capture"

        function open(): void { root.open() }
        function ready(path: string): void { root.ready(path) }
        function cancel(): void {
            root.picking = false
            root.dismiss(true)
        }
    }

    Timer {
        id: launch
        interval: 200
        onTriggered: Quickshell.execDetached(["shell-capture", root.modes[root.modeIndex].id])
    }

    // Pausa com o mouse em cima e enquanto o OCR roda.
    Timer {
        id: expiry
        interval: 8000
        running: root.shown && !cardHover.hovered && root.ocrState !== "running"
        onTriggered: root.dismiss(true)
    }

    Process {
        id: saver
        command: ["sh", "-c",
            'd=$(xdg-user-dir PICTURES 2>/dev/null); '
            + '{ [ -n "$d" ] && [ "$d" != "$HOME" ]; } || d="$HOME/Imagens"; '
            + 'mkdir -p "$d" && cp "$1" "$d/" && printf "%s" "$d/${1##*/}"',
            "sh", root.path]
        stdout: StdioCollector {
            onStreamFinished: if (text !== "") {
                root.saved = text.replace(Quickshell.env("HOME"), "~")
                expiry.restart()
            }
        }
    }

    Process {
        id: ocr
        command: ["screenshot-ocr", "--quiet", root.path]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                root.ocrPdf = lines[0] ?? ""
                root.ocrText = lines.slice(1).join("\n").trim()
            }
        }
        onExited: code => {
            root.ocrState = code === 0 ? "done" : "error"
            // PDF pesquisável: a captura com o texto selecionável por cima.
            if (code === 0 && root.ocrPdf !== "") Quickshell.execDetached(["papers", root.ocrPdf])
            expiry.restart()
        }
    }

    // Barra de modos, embaixo no centro.
    PanelWindow {
        id: bar

        screen: ShellState.focusedScreen()
        visible: root.picking
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "fuleco-capture-modes"
        WlrLayershell.keyboardFocus: root.picking ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        implicitWidth: modeBar.width
        implicitHeight: modeBar.height

        anchors.bottom: true
        margins.bottom: 96

        HyprlandFocusGrab {
            active: root.picking
            windows: [bar]
            onCleared: root.picking = false
        }

        Rectangle {
            id: modeBar

            width: modeRow.implicitWidth + 16
            height: 46
            radius: 23
            color: Theme.surface
            border.color: Theme.surfaceBorder
            focus: true

            Keys.onPressed: event => {
                const count = root.modes.length
                if (event.key === Qt.Key_Escape) root.picking = false
                else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right || event.key === Qt.Key_L)
                    root.modeIndex = (root.modeIndex + 1) % count
                else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left || event.key === Qt.Key_H)
                    root.modeIndex = (root.modeIndex + count - 1) % count
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                    root.pick(root.modeIndex)
                else if (event.key >= Qt.Key_1 && event.key < Qt.Key_1 + count)
                    root.pick(event.key - Qt.Key_1)
                else return
                event.accepted = true
            }

            RowLayout {
                id: modeRow

                anchors.verticalCenter: parent.verticalCenter
                x: 8
                spacing: 4

                Text {
                    Layout.leftMargin: 8
                    Layout.rightMargin: 6
                    text: "captura"
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                Repeater {
                    model: root.modes

                    Rectangle {
                        id: chip

                        required property var modelData
                        required property int index
                        readonly property bool active: index === root.modeIndex

                        implicitWidth: chipRow.implicitWidth + 24
                        implicitHeight: 30
                        radius: 15
                        color: active ? Theme.yellow : chipHover.hovered ? Theme.raised : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.fast } }

                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 7

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: chip.modelData.icon
                                size: 13
                                color: chip.active ? Theme.onAccent : Theme.textMuted
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData.label
                                color: chip.active ? Theme.onAccent : Theme.text
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                        }

                        HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.pick(chip.index) }
                    }
                }

                Rectangle {
                    Layout.leftMargin: 6
                    implicitWidth: 1
                    implicitHeight: 18
                    color: Theme.surfaceBorder
                }

                Text {
                    Layout.leftMargin: 6
                    Layout.rightMargin: 8
                    text: "tab troca · enter captura · esc cancela"
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }
        }
    }

    // Cartão do resultado, no canto superior direito.
    PanelWindow {
        id: cardWindow

        screen: ShellState.focusedScreen()
        visible: root.shown || column.opacity > 0
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "fuleco-capture"
        // Teclado só com o mouse em cima: colar logo depois da captura continua
        // indo para a janela em foco.
        WlrLayershell.keyboardFocus: root.shown && cardHover.hovered ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        implicitWidth: 380
        implicitHeight: column.implicitHeight
        mask: Region { item: column }

        anchors {
            top: true
            right: true
        }

        margins {
            top: Theme.barBottom + 14
            right: 22
        }

        ColumnLayout {
            id: column

            width: parent.width
            spacing: 12
            opacity: root.shown ? 1 : 0
            focus: true

            Behavior on opacity { NumberAnimation { duration: Theme.normal } }

            HoverHandler { id: cardHover }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.copy()
                else if (event.key === Qt.Key_S) root.save()
                else if (event.key === Qt.Key_G) root.edit()
                else if (event.key === Qt.Key_O) root.extract()
                else if (event.key === Qt.Key_Escape) root.dismiss(true)
                else return
                event.accepted = true
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: shotColumn.implicitHeight + 36
                radius: 24
                color: Theme.surface
                border.color: Theme.surfaceBorder

                ColumnLayout {
                    id: shotColumn

                    x: 18
                    y: 18
                    width: parent.width - 36
                    spacing: 8

                    Header {
                        icon: "crop"
                        title: "captura pronta"
                        detail: root.sizeText
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        Layout.bottomMargin: 6
                        implicitHeight: 150
                        radius: 14
                        color: Theme.raisedAlt
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 6
                            source: root.path ? "file://" + root.path : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                            mipmap: true
                            onStatusChanged: if (status === Image.Ready) {
                                root.shotWidth = implicitWidth
                                root.shotHeight = implicitHeight
                            }
                        }
                    }

                    Action { icon: "clipboard-text"; tint: Theme.cyan; label: "copiar"; hint: "enter"; onActivated: root.copy() }
                    Action {
                        icon: root.saved ? "check" : "floppy-disk"
                        tint: Theme.green
                        label: root.saved ? "salva em " + root.saved : "salvar em ~/Imagens"
                        hint: "s"
                        onActivated: root.save()
                    }
                    Action { icon: "paint-brush"; tint: Theme.purple; label: "abrir no gradia"; hint: "g"; onActivated: root.edit() }
                    Action {
                        icon: "text-t"
                        tint: Theme.yellow
                        label: root.ocrState === "running" ? "extraindo texto…" : "extrair texto"
                        hint: "o"
                        onActivated: root.extract()
                    }

                    RowLayout {
                        Layout.topMargin: 4
                        spacing: 8

                        Icon { name: "clock-counter-clockwise"; size: 12; color: Theme.textFaint }
                        Text {
                            text: "o cartão fica 8 s e vai para as notificações"
                            color: Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: 10
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: root.ocrState === "done" || root.ocrState === "error"
                implicitHeight: ocrColumn.implicitHeight + 36
                radius: 24
                color: Theme.surface
                border.color: Theme.surfaceBorder

                ColumnLayout {
                    id: ocrColumn

                    x: 18
                    y: 18
                    width: parent.width - 36
                    spacing: 12

                    Header {
                        icon: "text-t"
                        title: "texto extraído"
                        detail: "tesseract · por+eng"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Math.min(160, ocrBody.implicitHeight + 24)
                        radius: 12
                        color: Theme.raisedAlt
                        clip: true

                        Text {
                            id: ocrBody
                            x: 12
                            y: 12
                            width: parent.width - 24
                            text: root.ocrState === "error" ? "o tesseract não conseguiu ler a imagem"
                                : root.ocrText || "nenhum texto encontrado"
                            color: root.ocrText ? Theme.text : Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: 11
                            lineHeight: 1.3
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Icon {
                            visible: root.ocrText !== ""
                            name: "check-square"
                            size: 13
                            color: Theme.green
                        }
                        Text {
                            visible: root.ocrText !== ""
                            text: "copiado para o clipboard"
                            color: Theme.green
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: root.ocrPdf !== ""
                            text: "abrir pdf"
                            color: pdfHover.hovered ? Theme.text : Theme.textMuted
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.underline: pdfHover.hovered

                            HoverHandler { id: pdfHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                margin: 6
                                onTapped: {
                                    Quickshell.execDetached(["papers", root.ocrPdf])
                                    root.dismiss(false)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component Header: RowLayout {
        id: header

        property string icon
        property string title
        property string detail

        Layout.fillWidth: true
        spacing: 10

        Rectangle {
            implicitWidth: 30
            implicitHeight: 30
            radius: 10
            color: Theme.yellowTint
            Icon { anchors.centerIn: parent; name: header.icon; size: 15; color: Theme.yellow }
        }
        Text {
            text: header.title
            color: Theme.textBright
            font.family: Theme.font
            font.pixelSize: 13
        }
        Item { Layout.fillWidth: true }
        Text {
            text: header.detail
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: 11
        }
    }

    component Action: Rectangle {
        id: action

        property string icon
        property color tint
        property string label
        property string hint
        signal activated

        Layout.fillWidth: true
        implicitHeight: 40
        radius: 12
        color: actionHover.hovered ? Theme.raised : Theme.raisedAlt

        Behavior on color { ColorAnimation { duration: Theme.fast } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            Icon { name: action.icon; size: 15; color: action.tint }
            Text {
                Layout.fillWidth: true
                text: action.label
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 12
                elide: Text.ElideMiddle
            }
            Text {
                text: action.hint
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: 10
            }
        }

        HoverHandler { id: actionHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: action.activated() }
    }
}
