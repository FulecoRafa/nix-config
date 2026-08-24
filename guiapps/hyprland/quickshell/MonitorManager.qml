import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var monitors: []
    property string message: ""

    function open(): void {
        window.visible = true
        loader.running = true
    }

    function close(): void {
        window.visible = false
    }

    function selectMonitor(index: int): void {
        if (index < 0 || index >= monitors.length) return
        const monitor = monitors[index]
        mode.model = monitor.availableModes || []

        const currentMode = monitor.width + "x" + monitor.height + "@"
            + Number(monitor.refreshRate).toFixed(2) + "Hz"
        const modeIndex = mode.find(currentMode)
        mode.currentIndex = modeIndex
        if (modeIndex < 0) mode.editText = currentMode

        positionX.text = String(monitor.x)
        positionY.text = String(monitor.y)
        scale.text = String(monitor.scale)
        transform.currentIndex = Math.max(0, Math.min(7, Number(monitor.transform)))
        message = ""
    }

    function apply(save: bool): void {
        const monitor = monitors[outputs.currentIndex]
        if (!monitor) return

        const selectedMode = mode.editText || mode.currentText
        const selectedPosition = positionX.text + "x" + positionY.text
        Quickshell.execDetached([
            "hyprland-monitorctl",
            save ? "save" : "apply",
            monitor.name,
            selectedMode,
            selectedPosition,
            scale.text,
            String(transform.currentIndex)
        ])
        message = save ? "Aplicado e salvo para as próximas sessões" : "Aplicado nesta sessão"
        refreshAfterApply.restart()
    }

    IpcHandler {
        target: "monitors"

        function toggle(): void {
            if (window.visible) root.close()
            else root.open()
        }

        function refresh(): void {
            loader.running = true
        }
    }

    Process {
        id: loader
        command: ["hyprctl", "monitors", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(this.text)
                    outputs.currentIndex = root.monitors.length > 0 ? 0 : -1
                    root.selectMonitor(outputs.currentIndex)
                } catch (error) {
                    root.message = "Não foi possível ler os monitores: " + error
                }
            }
        }
    }

    Timer {
        id: refreshAfterApply
        interval: 700
        onTriggered: loader.running = true
    }

    PanelWindow {
        id: window

        visible: false
        color: "#99000000"
        focusable: true
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 720)
            height: Math.min(parent.height - 96, 500)
            radius: 14
            color: "#202124"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: "Monitores"
                        color: "#e8eaed"
                        font.pixelSize: 22
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Atualizar"
                        onClicked: loader.running = true
                    }

                    Button {
                        text: "Fechar"
                        onClicked: root.close()
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: "As mudanças são aplicadas pelo Hyprland sem reiniciar a sessão."
                    color: "#bdc1c6"
                    wrapMode: Text.WordWrap
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 12

                    Label { text: "Saída"; color: "#e8eaed" }
                    ComboBox {
                        id: outputs
                        Layout.fillWidth: true
                        model: root.monitors.map(monitor => monitor.name + " — " + monitor.description)
                        onActivated: root.selectMonitor(currentIndex)
                    }

                    Label { text: "Resolução e frequência"; color: "#e8eaed" }
                    ComboBox {
                        id: mode
                        Layout.fillWidth: true
                        editable: true
                    }

                    Label { text: "Posição X"; color: "#e8eaed" }
                    TextField {
                        id: positionX
                        Layout.fillWidth: true
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        placeholderText: "0"
                    }

                    Label { text: "Posição Y"; color: "#e8eaed" }
                    TextField {
                        id: positionY
                        Layout.fillWidth: true
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        placeholderText: "0"
                    }

                    Label { text: "Escala"; color: "#e8eaed" }
                    TextField {
                        id: scale
                        Layout.fillWidth: true
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        placeholderText: "1"
                    }

                    Label { text: "Rotação"; color: "#e8eaed" }
                    ComboBox {
                        id: transform
                        Layout.fillWidth: true
                        model: [
                            "0°", "90°", "180°", "270°",
                            "Espelhado", "Espelhado 90°", "Espelhado 180°", "Espelhado 270°"
                        ]
                    }
                }

                Item { Layout.fillHeight: true }

                Label {
                    Layout.fillWidth: true
                    text: root.message
                    color: "#bdc1c6"
                    horizontalAlignment: Text.AlignRight
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight

                    Button {
                        text: "Aplicar"
                        enabled: outputs.currentIndex >= 0
                        onClicked: root.apply(false)
                    }

                    Button {
                        text: "Aplicar e salvar"
                        enabled: outputs.currentIndex >= 0
                        onClicked: root.apply(true)
                    }
                }
            }

            Keys.onEscapePressed: root.close()
        }
    }
}
