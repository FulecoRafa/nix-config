import QtQuick
import Quickshell

// Faixa de ações de energia (clique no relógio): sair, desligar, suspender,
// bloquear, recarregar o shell. Botões perigosos pedem um segundo clique.
HangingPanel {
    id: panel

    name: "power"
    side: "right"
    panelWidth: strip.implicitWidth + 32
    padding: 16
    topPadding: 26

    property string armed: ""

    onOpened: armed = ""

    function trigger(action: var): void {
        if (action.confirm && armed !== action.id) {
            armed = action.id
            disarm.restart()
            return
        }
        ShellState.close()
        Quickshell.execDetached(action.command)
    }

    Timer { id: disarm; interval: 3000; onTriggered: panel.armed = "" }

    Row {
        id: strip
        spacing: 10

        Repeater {
            model: [
                { id: "logout", icon: "sign-out", color: Theme.red, tint: Theme.redTint, confirm: true, label: "sair", command: ["sh", "-c", "uwsm stop || hyprctl dispatch exit"] },
                { id: "poweroff", icon: "power", color: Theme.text, tint: Theme.raised, confirm: true, label: "desligar", command: ["systemctl", "poweroff"] },
                { id: "suspend", icon: "moon", color: Theme.purple, tint: Theme.raised, confirm: false, label: "suspender", command: ["systemctl", "suspend"] },
                { id: "lock", icon: "lock-key", color: Theme.cyan, tint: Theme.raised, confirm: false, label: "bloquear", command: ["loginctl", "lock-session"] },
                { id: "reload", icon: "arrows-clockwise", color: Theme.green, tint: Theme.raised, confirm: false, label: "recarregar", command: ["sh", "-c", "hyprctl reload; pkill -f 'quickshell -c fuleco'; sleep 0.3; hyprctl dispatch exec 'quickshell -c fuleco'"] }
            ]

            Rectangle {
                id: button
                required property var modelData
                readonly property bool isArmed: panel.armed === modelData.id

                width: 46
                height: 46
                radius: 16
                color: isArmed ? modelData.color : hover.hovered ? Qt.lighter(modelData.tint, 1.25) : modelData.tint

                Behavior on color { ColorAnimation { duration: Theme.fast } }

                Icon {
                    anchors.centerIn: parent
                    name: button.modelData.icon
                    size: 21
                    color: button.isArmed ? Theme.onAccent : button.modelData.color
                }

                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: panel.trigger(button.modelData) }

                // Dica embaixo do botão
                Text {
                    anchors.top: parent.bottom
                    anchors.topMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: hover.hovered || button.isArmed
                    text: button.isArmed ? "de novo" : button.modelData.label
                    color: button.isArmed ? button.modelData.color : Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: 9
                }
            }
        }
    }
}
