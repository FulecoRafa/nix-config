import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string mode: "apps"
    property list<string> clipboardEntries: []

    function open(nextMode: string): void {
        mode = nextMode
        query.text = ""
        launcher.visible = true
        if (mode === "clipboard") clipboardLoader.running = true
        query.forceActiveFocus()
    }

    function close(): void {
        launcher.visible = false
    }

    function activate(): void {
        if (mode === "apps") {
            if (appList.currentItem?.modelData) appList.currentItem.modelData.execute()
        } else {
            const entry = clipboardList.currentItem?.modelData
            if (entry) {
                Quickshell.execDetached([
                    "sh", "-c",
                    "printf '%s' \"$1\" | cliphist decode | wl-copy",
                    "sh", entry
                ])
            }
        }
        close()
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            if (launcher.visible) root.close()
            else root.open("apps")
        }

        function clipboard(): void {
            if (launcher.visible && root.mode === "clipboard") root.close()
            else root.open("clipboard")
        }
    }

    Process {
        id: clipboardLoader
        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                const output = this.text.trim()
                root.clipboardEntries = output === "" ? [] : output.split("\n")
            }
        }
    }

    ScriptModel {
        id: filteredApps
        values: {
            const entries = [...DesktopEntries.applications.values]
                .filter(entry => entry.name)
                .sort((a, b) => a.name.localeCompare(b.name))
            const needle = query.text.trim().toLowerCase()
            if (needle === "") return entries
            return entries.filter(entry => {
                const haystack = [
                    entry.name || "",
                    entry.comment || "",
                    ...(entry.keywords || []),
                    ...(entry.categories || [])
                ].join(" ").toLowerCase()
                return haystack.includes(needle)
            })
        }
    }

    ScriptModel {
        id: filteredClipboard
        values: {
            const needle = query.text.trim().toLowerCase()
            if (needle === "") return root.clipboardEntries
            return root.clipboardEntries.filter(entry => entry.toLowerCase().includes(needle))
        }
    }

    PanelWindow {
        id: launcher

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
            width: Math.min(parent.width - 48, 620)
            height: Math.min(parent.height - 96, 540)
            radius: 14
            color: "#202124"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                TextField {
                    id: query

                    Layout.fillWidth: true
                    placeholderText: root.mode === "apps" ? "Aplicações" : "Histórico do clipboard"

                    Keys.onEscapePressed: root.close()
                    Keys.onDownPressed: {
                        const list = root.mode === "apps" ? appList : clipboardList
                        list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1)
                    }
                    Keys.onUpPressed: {
                        const list = root.mode === "apps" ? appList : clipboardList
                        list.currentIndex = Math.max(list.currentIndex - 1, 0)
                    }
                    Keys.onReturnPressed: root.activate()
                }

                ListView {
                    id: appList

                    visible: root.mode === "apps"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: filteredApps
                    currentIndex: count > 0 ? 0 : -1

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: ListView.view.width
                        height: 42
                        radius: 6
                        color: ListView.isCurrentItem ? "#3c4043" : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10

                            Image {
                                width: 24
                                height: 24
                                source: Quickshell.iconPath(modelData.icon, true)
                            }

                            Text {
                                width: parent.width - 42
                                text: modelData.name
                                color: "#e8eaed"
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: appList.currentIndex = index
                            onDoubleClicked: root.activate()
                        }
                    }
                }

                ListView {
                    id: clipboardList

                    visible: root.mode === "clipboard"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: filteredClipboard
                    currentIndex: count > 0 ? 0 : -1

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: ListView.view.width
                        height: 38
                        radius: 6
                        color: ListView.isCurrentItem ? "#3c4043" : "transparent"

                        Text {
                            anchors.fill: parent
                            anchors.margins: 8
                            text: String(modelData).replace(/^\d+\t/, "")
                            color: "#e8eaed"
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: clipboardList.currentIndex = index
                            onDoubleClicked: root.activate()
                        }
                    }
                }
            }
        }
    }
}
