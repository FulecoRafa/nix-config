import QtQuick

// Ícone Phosphor fill por nome (ex.: "wifi-high").
Text {
    property string name
    property int size: 18

    text: Icons.glyph(name)
    color: Theme.text
    font.family: Theme.iconFont
    font.pixelSize: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
