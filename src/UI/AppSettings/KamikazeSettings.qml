import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtPositioning 5.15

import QGroundControl

Item {
    property var _kamikazeLocManager: QGroundControl.kamikazeLocManager
    property var _serverManager:      QGroundControl.serverManager

    anchors.fill: parent

    ScrollView {
        anchors.fill: parent

        Column {
            width: parent.width
            spacing: 16
            padding: 16

            /* ---- Title ---- */
            Label {
                text: qsTr("Kamikaze Settings")
                font.pixelSize: 20
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
            }

            /* ---- Latitude ---- */
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                Label {
                    text: qsTr("Target latitude")
                    Layout.preferredWidth: 140
                    horizontalAlignment: Text.AlignRight
                }

                TextField {
                    id: latField
                    Layout.preferredWidth: 220
                    placeholderText: _kamikazeLocManager.coordinate.latitude
                }
            }

            /* ---- Longitude ---- */
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                Label {
                    text: qsTr("Target longitude")
                    Layout.preferredWidth: 140
                    horizontalAlignment: Text.AlignRight
                }

                TextField {
                    id: lonField
                    Layout.preferredWidth: 220
                    placeholderText: _kamikazeLocManager.coordinate.longitude
                }
            }

            /* ---- Actions ---- */
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 16

                Button {
                    text: qsTr("Get QR coords")
                    onClicked: _serverManager.getQRCoordinates()
                }

                Button {
                    text: qsTr("Send to vehicle")
                    onClicked: {
                        const lat = parseFloat(latField.text)
                        const lon = parseFloat(lonField.text)

                        if (isNaN(lat) || isNaN(lon)) {
                            console.warn("Invalid coordinates")
                            return
                        }

                        _kamikazeLocManager.setCoordinate(
                            QtPositioning.coordinate(lat, lon)
                        )
                    }
                }
            }
        }
    }

    /* ---- Server → UI wiring ---- */

    Connections {
        target: _serverManager

        function onQrCoordinatesReceived(coord) {
            latField.text = coord.latitude
            lonField.text = coord.longitude

            _kamikazeLocManager.coordinate = coord //TODO? move to ServerManager::getQRCoordinates

            console.log("QR coords received:",
                        coord.latitude,
                        coord.longitude)
        }

        function onErrorOccurred(err) {
            console.warn("QR fetch failed:", err)
        }
    }
}
