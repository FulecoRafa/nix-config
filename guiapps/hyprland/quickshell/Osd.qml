import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// OSD vertical na borda direita: volume (amarelo) e brilho (ciano). Aparece
// sozinho quando um dos dois muda e some em 1,5 s; com o mouse em cima ele
// fica, e clicar, arrastar ou rolar nas barras ajusta.
Scope {
    id: root

    property bool shown: false
    property bool ready: false

    function poke(): void {
        if (!ready) return
        shown = true
        if (!hover.hovered) expiry.restart()
    }

    IpcHandler {
        target: "osd"

        // Compatível com os binds antigos: qualquer mensagem só mostra o OSD.
        function show(message: string): void {
            Brightness.refresh()
            root.poke()
        }
    }

    Connections {
        target: Audio
        function onVolumeChanged() { root.poke() }
        function onMutedChanged() { root.poke() }
    }

    Connections {
        target: Brightness
        function onCurrentChanged() { root.poke() }
    }

    // Ignora os valores iniciais ao carregar o shell.
    Timer { running: true; interval: 1500; onTriggered: root.ready = true }
    Timer { id: expiry; interval: 1500; onTriggered: root.shown = false }

    PanelWindow {
        id: osd

        screen: ShellState.focusedScreen()
        visible: root.shown || card.opacity > 0
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "fuleco-osd"
        implicitWidth: 96 + 40
        implicitHeight: column.implicitHeight + 34
        mask: Region { item: card }

        anchors.right: true
        margins.right: 22

        Rectangle {
            id: card

            x: root.shown ? 40 : 70
            width: 96
            height: parent.height
            radius: 26
            color: Theme.surface
            border.color: Theme.surfaceBorder
            opacity: root.shown ? 1 : 0

            HoverHandler {
                id: hover
                onHoveredChanged: hovered ? expiry.stop() : expiry.restart()
            }

            Behavior on x { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }

            Column {
                id: column

                anchors.horizontalCenter: parent.horizontalCenter
                y: 16
                spacing: 12

                Gauge {
                    icon: Audio.muted ? "speaker-slash" : Audio.volume > 0.5 ? "speaker-high" : Audio.volume > 0 ? "speaker-low" : "speaker-none"
                    value: Audio.volume
                    accent: Audio.muted ? Theme.dim : Theme.yellow
                    onMoved: value => Audio.setVolume(value)
                    onIconClicked: Audio.toggleMute()
                }

                Rectangle {
                    visible: Brightness.available
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 34
                    height: 1
                    color: Theme.raised
                }

                Gauge {
                    visible: Brightness.available
                    icon: "sun-dim"
                    value: Brightness.value
                    accent: Theme.cyan
                    onMoved: value => Brightness.set(value)
                }
            }
        }
    }

    component Gauge: Column {
        id: gauge
        property string icon
        property real value
        property color accent
        signal moved(real value)
        signal iconClicked
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: gauge.icon
            size: 18
            color: Theme.text
            TapHandler { onTapped: gauge.iconClicked() }
        }
        Meter {
            anchors.horizontalCenter: parent.horizontalCenter
            vertical: true
            thickness: 10
            implicitHeight: 120
            value: gauge.value
            accent: gauge.accent
            onMoved: value => gauge.moved(value)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(gauge.value * 100)
            color: Theme.textMuted
            font.family: Theme.font
            font.pixelSize: 11
        }
    }
}
