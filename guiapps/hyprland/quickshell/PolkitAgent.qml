import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland

// Agente polkit da sessão (pkexec, run0, systemctl, apps gráficos). O PAM
// do polkit-1 pede a digital primeiro e, se ela não vier, cai para a senha:
// a mensagem do fprintd chega como supplementaryMessage e o campo só aceita
// texto quando isResponseRequired. O cadeado fecha ao errar e abre ao acertar.
Scope {
    id: root

    readonly property AuthFlow flow: agent.flow
    readonly property bool shown: agent.isActive && flow !== null
    // Fica um instante na tela depois do sucesso para mostrar o cadeado aberto.
    property bool unlocked: false
    property int shake: 0

    PolkitAgent {
        id: agent
    }

    Connections {
        target: root.flow
        ignoreUnknownSignals: true

        function onAuthenticationFailed(): void {
            input.text = ""
            root.shake++
        }

        function onAuthenticationSucceeded(): void {
            root.unlocked = true
            unlockedTimer.restart()
        }

        function onIsResponseRequiredChanged(): void {
            if (root.flow?.isResponseRequired) input.forceActiveFocus()
        }
    }

    Timer {
        id: unlockedTimer
        interval: 450
        onTriggered: root.unlocked = false
    }

    onShownChanged: if (shown) {
        unlocked = false
        input.text = ""
        input.forceActiveFocus()
    }

    function submit(): void {
        if (!flow || !flow.isResponseRequired) return
        flow.submit(input.text)
        input.text = ""
    }

    // O PAM fala inglês ("Password: "); traduz o caso comum.
    function promptText(prompt: string): string {
        const clean = (prompt || "").trim().replace(/:$/, "").toLowerCase()
        return clean === "" || clean === "password" ? "senha" : clean
    }

    function cancel(): void {
        flow?.cancelAuthenticationRequest()
    }

    PanelWindow {
        visible: root.shown || root.unlocked
        color: "transparent"

        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "fuleco-polkit"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        // Escurece o resto; clicar fora não cancela (evita perder o pedido).
        Rectangle {
            anchors.fill: parent
            color: "#99000000"
        }

        Rectangle {
            id: card

            width: 520
            height: column.implicitHeight + 48
            anchors.centerIn: parent
            radius: 28
            color: Theme.surface
            border.color: Theme.surfaceBorder
            border.width: 1

            // Brilho âmbar atrás do cadeado.
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 140
                radius: card.radius
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.alpha(Theme.yellow, 0.10) }
                    GradientStop { position: 1; color: "transparent" }
                }
            }

            transform: Translate { id: shakeOffset }
            SequentialAnimation {
                running: root.shake > 0
                id: shakeAnimation
                NumberAnimation { target: shakeOffset; property: "x"; to: -10; duration: 50 }
                NumberAnimation { target: shakeOffset; property: "x"; to: 10; duration: 70 }
                NumberAnimation { target: shakeOffset; property: "x"; to: -6; duration: 60 }
                NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 50 }
            }
            Connections {
                target: root
                function onShakeChanged(): void { shakeAnimation.restart() }
            }

            Keys.onEscapePressed: root.cancel()

            ColumnLayout {
                id: column

                x: 24
                y: 26
                width: parent.width - 48
                spacing: 14

                Icon {
                    Layout.alignment: Qt.AlignHCenter
                    name: root.unlocked ? "lock-open" : "lock"
                    size: 92
                    color: root.flow?.failed && !root.unlocked ? Theme.red : Theme.yellow
                    Behavior on color { ColorAnimation { duration: Theme.normal } }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "autenticação necessária"
                        color: Theme.textBright
                        font.family: Theme.font
                        font.pixelSize: 19
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: (root.flow?.message ?? "").toLowerCase()
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        color: Theme.textMuted
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }

                // Detalhes da ação pedida.
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: details.implicitHeight + 24
                    radius: 14
                    color: Theme.raised

                    GridLayout {
                        id: details
                        x: 14
                        y: 12
                        width: parent.width - 28
                        columns: 2
                        rowSpacing: 6

                        Text { text: "ação"; color: Theme.textFaint; font.family: Theme.font; font.pixelSize: 12 }
                        Text {
                            Layout.fillWidth: true
                            text: root.flow?.actionId ?? ""
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideLeft
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                        Text { text: "como"; color: Theme.textFaint; font.family: Theme.font; font.pixelSize: 12 }
                        Text {
                            Layout.fillWidth: true
                            text: root.flow?.selectedIdentity?.displayName ?? ""
                            horizontalAlignment: Text.AlignRight
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }
                }

                // Campo de senha: pontos âmbar, o texto nunca aparece.
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: 14
                    color: Theme.sunken
                    border.width: 1
                    border.color: input.activeFocus && root.flow?.isResponseRequired ? Theme.yellow : Theme.surfaceBorder
                    opacity: root.flow?.isResponseRequired ? 1 : 0.55

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        Icon { name: "user"; size: 15; color: Theme.textFaint }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            TextInput {
                                id: input
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                                passwordCharacter: "●"
                                readOnly: !(root.flow?.isResponseRequired ?? false)
                                color: Theme.yellow
                                font.family: Theme.font
                                font.pixelSize: 15
                                font.letterSpacing: 3
                                cursorDelegate: Rectangle { width: 2; color: Theme.yellow; visible: input.activeFocus }
                                Keys.onReturnPressed: root.submit()
                                Keys.onEnterPressed: root.submit()
                                Keys.onEscapePressed: root.cancel()
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: input.text === ""
                                text: root.flow?.isResponseRequired
                                    ? root.promptText(root.flow.inputPrompt)
                                    : "aguardando a digital…"
                                color: Theme.textGhost
                                font.family: Theme.font
                                font.pixelSize: 13
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Icon {
                        name: "fingerprint"
                        size: 14
                        color: root.flow?.supplementaryIsError ? Theme.red : Theme.cyan
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.flow?.supplementaryMessage
                            ? root.flow.supplementaryMessage.toLowerCase()
                            : "ou use a digital"
                        elide: Text.ElideRight
                        color: root.flow?.supplementaryIsError ? Theme.red : Theme.textMuted
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                    Text {
                        visible: root.flow?.failed ?? false
                        text: "senha incorreta"
                        color: Theme.red
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 10

                    Button {
                        label: "cancelar · esc"
                        background: Theme.raised
                        foreground: Theme.text
                        onClicked: root.cancel()
                    }
                    Button {
                        label: "autenticar · enter"
                        background: Theme.yellow
                        foreground: Theme.onAccent
                        enabled: root.flow?.isResponseRequired ?? false
                        onClicked: root.submit()
                    }
                }
            }
        }
    }

    component Button: Rectangle {
        id: button

        property string label
        property color background
        property color foreground
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 42
        radius: 14
        color: hover.hovered && enabled ? Qt.lighter(background, 1.12) : background
        opacity: enabled ? 1 : 0.5

        Text {
            anchors.centerIn: parent
            text: button.label
            color: button.foreground
            font.family: Theme.font
            font.pixelSize: 13
        }
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: if (button.enabled) button.clicked() }
    }
}
