import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

Dialog {
    id: root
    modal: true
    standardButtons: Dialog.Ok | Dialog.Cancel
    title: qsTr("Enter value")

    property alias value: numberField.text
    property string units: ""
    property real minimum: -1e9
    property real maximum: 1e9

    signal acceptedValue(real value)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth

        QGCLabel {
            text: root.title
            font.pointSize: ScreenTools.defaultFontPointSize
            Layout.alignment: Qt.AlignHCenter
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth

            TextField {
                id: numberField
                placeholderText: qsTr("Number")
                inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhDigitsOnly
                horizontalAlignment: Text.AlignLeft
                Layout.fillWidth: true
                validator: DoubleValidator { }
                onAccepted: root.accept()
            }

            QGCLabel {
                text: root.units
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    onAccepted: {
        var v = parseFloat(numberField.text)
        if (isNaN(v)) {
            // ignore if invalid
            root.close()
            return
        }
        if (v < minimum) v = minimum
        if (v > maximum) v = maximum
        root.acceptedValue(v)
        root.close()
    }

    onVisibleChanged: {
        if (visible) {
            // Ensure text field has keyboard focus when dialog opens
            numberField.forceActiveFocus()
        }
    }
}
