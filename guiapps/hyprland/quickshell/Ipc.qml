import QtQuick
import Quickshell
import Quickshell.Io

// `quickshell -c fuleco ipc call shell toggle drawer`, usado pelos atalhos.
Scope {
    IpcHandler {
        target: "shell"

        function toggle(name: string): void {
            ShellState.toggle(name)
        }

        function open(name: string): void {
            ShellState.open(name)
        }

        function close(): void {
            ShellState.close()
        }

        function control(tab: string): void {
            if (ShellState.panel === "control" && ShellState.controlTab === tab) ShellState.close()
            else ShellState.openControl(tab)
        }
    }
}
