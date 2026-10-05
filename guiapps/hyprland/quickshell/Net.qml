pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower

// Estado de rede, bluetooth e bateria usado pela barra e pela central.
Singleton {
    id: root

    // Wi-fi
    readonly property var wifiDevice: Networking.devices.values.find(device => device.type === DeviceType.Wifi) ?? null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property var wifiNetworks: wifiDevice ? [...wifiDevice.networks.values]
        .filter(network => network.name)
        .sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength)) : []
    readonly property var activeNetwork: wifiNetworks.find(network => network.connected) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(device => device.type === DeviceType.Wired && device.connected) ?? null

    function strength(network: var): real {
        const value = network?.signalStrength ?? 0
        return value > 1 ? value / 100 : value
    }

    function wifiIcon(network: var): string {
        if (!network) return "wifi-slash"
        const value = strength(network)
        if (value > 0.66) return "wifi-high"
        if (value > 0.33) return "wifi-medium"
        return "wifi-low"
    }

    readonly property string icon: wiredDevice ? "network" : wifiEnabled ? wifiIcon(activeNetwork) : "wifi-slash"
    readonly property bool online: wiredDevice !== null || activeNetwork !== null

    function setWifi(enabled: bool): void {
        Networking.wifiEnabled = enabled
    }

    function scan(): void {
        if (wifiDevice) wifiDevice.scannerEnabled = true
    }

    // Bluetooth
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothEnabled: adapter?.enabled ?? false
    readonly property var bluetoothDevices: Bluetooth.devices.values.filter(device => device.paired || device.connected)
    readonly property var bluetoothConnected: bluetoothDevices.filter(device => device.connected)
    // Achados na busca, ainda não pareados (só os que têm nome).
    readonly property var bluetoothNearby: Bluetooth.devices.values.filter(device => !device.paired && !device.connected && (device.name || device.deviceName))

    function setBluetooth(enabled: bool): void {
        if (adapter) adapter.enabled = enabled
    }

    // Bateria
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    readonly property real batteryPercent: {
        const value = battery?.percentage ?? 0
        return Math.round(value <= 1 ? value * 100 : value)
    }
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging
        || battery?.state === UPowerDeviceState.FullyCharged
        || battery?.state === UPowerDeviceState.PendingCharge
    readonly property string batteryIcon: {
        if (charging) return "battery-charging"
        if (batteryPercent > 85) return "battery-full"
        if (batteryPercent > 55) return "battery-high"
        if (batteryPercent > 25) return "battery-medium"
        if (batteryPercent > 10) return "battery-low"
        return "battery-warning"
    }
    readonly property color batteryColor: batteryPercent <= 15 && !charging ? Theme.red
        : batteryPercent <= 30 && !charging ? Theme.orange : Theme.green

    // "4h12" até esvaziar (ou encher, carregando)
    function durationText(seconds: real): string {
        if (!seconds || seconds <= 0) return ""
        const minutes = Math.round(seconds / 60)
        return Math.floor(minutes / 60) + "h" + String(minutes % 60).padStart(2, "0")
    }

    readonly property string batteryTime: durationText(charging ? battery?.timeToFull : battery?.timeToEmpty)
    readonly property real watts: Math.abs(battery?.changeRate ?? 0)
}
