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
    property var _rosBridge: QGroundControl.rosBridge
    property bool _advancedExpanded: false

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

            ColumnLayout{
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCLabel {
                        text: qsTr("Pull-up Altitude (m)")
                        Layout.minimumWidth: 180
                        verticalAlignment: Text.AlignVCenter
                    }

                    QGCTextField {
                        id: pullUpAltField
                        Layout.fillWidth: true
                        text: "35.0"
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCLabel {
                        text: qsTr("Approach Heading (°)")
                        Layout.minimumWidth: 180
                        verticalAlignment: Text.AlignVCenter
                    }

                    QGCTextField {
                        id: approachHeadingField
                        Layout.fillWidth: true
                        text: "45.0"
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCLabel {
                        text: qsTr("Dive Angle (°)")
                        Layout.minimumWidth: 180
                        verticalAlignment: Text.AlignVCenter
                    }

                    QGCTextField {
                        id: diveAngleField
                        Layout.fillWidth: true
                        text: "25.0"
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCLabel {
                        text: qsTr("Climb Buffer Distance (m)")
                        Layout.minimumWidth: 180
                        verticalAlignment: Text.AlignVCenter
                    }

                    QGCTextField {
                        id: climbBufferField
                        Layout.fillWidth: true
                        text: "150.0"
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                    }
                }
            }

            // --- ADVANCED PARAMETERS PANEL ---
            Rectangle {
                id: advancedPanelRect
                Layout.fillWidth: true
                Layout.preferredHeight: _advancedExpanded ? headerRow.height + advancedLayout.implicitHeight + ScreenTools.defaultFontPixelWidth * 2 : headerRow.height
                radius: ScreenTools.defaultFontPixelWidth / 2
                color: qgcPal.windowShade
                border.color: qgcPal.buttonHighlight
                border.width: 1
                clip: true

                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: 200 }
                }

                RowLayout {
                    id: headerRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: ScreenTools.defaultFontPixelHeight * 1.5
                    spacing: ScreenTools.defaultFontPixelWidth

                    Item { width: ScreenTools.defaultFontPixelWidth / 4; height: 1 } // Spacer

                    Text {
                        text: _advancedExpanded ? "▼" : "▶"
                        font.pixelSize: ScreenTools.defaultFontPixelHeight
                        color: qgcPal.buttonText
                        opacity: _advancedExpanded ? 1.0 : 0.5
                    }

                    QGCLabel {
                        text: qsTr("Advanced Parameters")
                        font.bold: true
                        Layout.fillWidth: true
                        opacity: _advancedExpanded ? 1.0 : 0.5
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page._advancedExpanded = !page._advancedExpanded
                    }
                }

                ColumnLayout {
                    id: advancedLayout
                    anchors.top: headerRow.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: ScreenTools.defaultFontPixelWidth
                    spacing: 0
                    visible: _advancedExpanded

                    // Dive Start Altitude
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCLabel {
                            text: qsTr("Dive Start Altitude (m)")
                            Layout.minimumWidth: 180
                            verticalAlignment: Text.AlignVCenter
                        }

                        QGCTextField {
                            id: diveStartAltField
                            Layout.fillWidth: true
                            text: "110.0"
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }

                    // Max Dive Angle
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCLabel {
                            text: qsTr("Max Dive Angle (°)")
                            Layout.minimumWidth: 180
                            verticalAlignment: Text.AlignVCenter
                        }

                        QGCTextField {
                            id: maxDiveAngleField
                            Layout.fillWidth: true
                            text: "60.0"
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }

                    // Min Dive Angle
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCLabel {
                            text: qsTr("Min Dive Angle (°)")
                            Layout.minimumWidth: 180
                            verticalAlignment: Text.AlignVCenter
                        }

                        QGCTextField {
                            id: minDiveAngleField
                            Layout.fillWidth: true
                            text: "15.0"
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }

                    // Max Roll Angle
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCLabel {
                            text: qsTr("Max Roll Angle (°)")
                            Layout.minimumWidth: 180
                            verticalAlignment: Text.AlignVCenter
                        }

                        QGCTextField {
                            id: maxRollAngleField
                            Layout.fillWidth: true
                            text: "45.0"
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }

                    // Roll Deadband
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCLabel {
                            text: qsTr("Roll Deadband (°)")
                            Layout.minimumWidth: 180
                            verticalAlignment: Text.AlignVCenter
                        }

                        QGCTextField {
                            id: rollDeadbandField
                            Layout.fillWidth: true
                            text: "3.0"
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }

                    // Roll P Gain
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCLabel {
                            text: qsTr("Roll P Gain")
                            Layout.minimumWidth: 180
                            verticalAlignment: Text.AlignVCenter
                        }

                        QGCTextField {
                            id: rollPGainField
                            Layout.fillWidth: true
                            text: "1.1"
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }
                }
            }

            RowLayout{
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCButton {
                        text: qsTr("Send Parameters")
                        onClicked: {
                            const pullUp = parseFloat(pullUpAltField.text)
                            const heading = parseFloat(approachHeadingField.text)
                            const dive = parseFloat(diveAngleField.text)
                            const climb = parseFloat(climbBufferField.text)

                            if (isNaN(pullUp) || isNaN(heading) || isNaN(dive) || isNaN(climb)) {
                                console.warn("Invalid parameter values")
                                return
                            }

                            // If advanced panel is expanded, also validate and send advanced params
                            if (page._advancedExpanded) {
                                const diveStart = parseFloat(diveStartAltField.text)
                                const maxDive = parseFloat(maxDiveAngleField.text)
                                const minDive = parseFloat(minDiveAngleField.text)
                                const maxRoll = parseFloat(maxRollAngleField.text)
                                const rollDb = parseFloat(rollDeadbandField.text)
                                const rollGain = parseFloat(rollPGainField.text)

                                if (isNaN(diveStart) || isNaN(maxDive) || isNaN(minDive) ||
                                    isNaN(maxRoll) || isNaN(rollDb) || isNaN(rollGain)) {
                                    console.warn("Invalid advanced parameter values")
                                    return
                                }

                                page._rosBridge.setKamikazeParams(
                                    pullUp, heading, dive, climb,
                                    true, diveStart, maxDive, minDive, maxRoll, rollDb, rollGain
                                )
                            } else {
                                page._rosBridge.setKamikazeParams(
                                    pullUp, heading, dive, climb,
                                    false, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
                                )
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCButton {
                        text: qsTr("Start Kamikaze")
                        onClicked: {
                            page._rosBridge.startKamikaze()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCButton {
                        text: qsTr("ABORT")
                        textColor: qgcPal.text
                        backgroundColor: qgcPal.colorRed
                        Layout.fillWidth: true

                        onClicked: {
                            page._rosBridge.abortKamikaze()
                        }
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
