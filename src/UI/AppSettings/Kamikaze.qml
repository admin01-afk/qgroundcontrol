import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtPositioning 5.15

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

SettingsPage {
    id: page
    anchors.fill: parent

    property var _kamikazeLocManager: QGroundControl.kamikazeLocManager
    property var _serverManager:      QGroundControl.serverManager

    QGCPalette { id: qgcPal; colorGroupEnabled: page.enabled }

    SettingsGroupLayout {
        Layout.fillWidth: true
        heading: qsTr("Kamikaze Settings")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelHeight

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("Target latitude")
                    Layout.preferredWidth: 140
                    verticalAlignment: Text.AlignVCenter
                }

                QGCTextField {
                    id: latField
                    Layout.fillWidth: true
                    text: (_kamikazeLocManager && _kamikazeLocManager.coordinate && !isNaN(_kamikazeLocManager.coordinate.latitude))
                                     ? _kamikazeLocManager.coordinate.latitude.toFixed(6)
                                     : ""
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("Target longitude")
                    Layout.preferredWidth: 140
                    verticalAlignment: Text.AlignVCenter
                }

                QGCTextField {
                    id: lonField
                    Layout.fillWidth: true
                    text: (_kamikazeLocManager && _kamikazeLocManager.coordinate && !isNaN(_kamikazeLocManager.coordinate.longitude))
                                     ? _kamikazeLocManager.coordinate.longitude.toFixed(6)
                                     : ""
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCButton {
                    text: qsTr("Get QR coords")
                    onClicked: _serverManager.getQRCoordinates()
                }

                Item { Layout.fillWidth: true }

                QGCButton {
                    text: qsTr("Send to vehicle")
                    onClicked: {
                        const lat = parseFloat(latField.text)
                        const lon = parseFloat(lonField.text)

                        _kamikazeLocManager.sendParameters(
                            QtPositioning.coordinate(lat, lon)
                        )
                    }
                }
            }
        }
    }

    Connections {
        target: _serverManager

        function onQrCoordinatesReceived(coord) {
            if (!coord) {
                console.warn("Received empty QR coordinate")
                return
            }

            latField.text = "" + coord.latitude
            lonField.text = "" + coord.longitude

            _kamikazeLocManager.coordinate = coord

            console.log("QR coords received:", latField.text, lonField.text)
        }

        function onErrorOccurred(header, message) {
            console.warn("Server error:", header, message)
        }
    }
}
