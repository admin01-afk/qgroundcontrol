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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCLabel {
                        text: qsTr("Reach Distance (m)")
                        Layout.minimumWidth: 180
                        verticalAlignment: Text.AlignVCenter
                    }

                    QGCTextField {
                        id: reachDistanceField
                        Layout.fillWidth: true
                        text: "15.0"
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

                    // Pitch P Gain
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCLabel {
                            text: qsTr("Pitch P Gain")
                            Layout.minimumWidth: 180
                            verticalAlignment: Text.AlignVCenter
                        }

                        QGCTextField {
                            id: pitchPGainField
                            Layout.fillWidth: true
                            text: "1.5"
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }

                    // Pitch I Gain
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCLabel {
                            text: qsTr("Pitch I Gain")
                            Layout.minimumWidth: 180
                            verticalAlignment: Text.AlignVCenter
                        }

                        QGCTextField {
                            id: pitchIGainField
                            Layout.fillWidth: true
                            text: "0.05"
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }

                    // Pitch D Gain
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCLabel {
                            text: qsTr("Pitch D Gain")
                            Layout.minimumWidth: 180
                            verticalAlignment: Text.AlignVCenter
                        }

                        QGCTextField {
                            id: pitchDGainField
                            Layout.fillWidth: true
                            text: "0.3"
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

                    // Roll I Gain
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCLabel {
                            text: qsTr("Roll I Gain")
                            Layout.minimumWidth: 180
                            verticalAlignment: Text.AlignVCenter
                        }

                        QGCTextField {
                            id: rollIGainField
                            Layout.fillWidth: true
                            text: "0.01"
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }

                    // Roll D Gain
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCLabel {
                            text: qsTr("Roll D Gain")
                            Layout.minimumWidth: 180
                            verticalAlignment: Text.AlignVCenter
                        }

                        QGCTextField {
                            id: rollDGainField
                            Layout.fillWidth: true
                            text: "0.2"
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
                            const lat = parseFloat(latField.text)
                            const lon = parseFloat(lonField.text)
                            const pullUp = parseFloat(pullUpAltField.text)
                            const heading = parseFloat(approachHeadingField.text)
                            const dive = parseFloat(diveAngleField.text)
                            const climb = parseFloat(climbBufferField.text)
                            const reach = parseFloat(reachDistanceField.text)

                            if (isNaN(lat) || isNaN(lon) || isNaN(pullUp) || isNaN(heading) || isNaN(dive) || isNaN(climb) || isNaN(reach)) {
                                function richValue(value) {
                                    return isNaN(value)
                                        ? '<span style="color:red">NaN</span>'
                                        : '<span style="color:#ffffff">' + value + '</span>'
                                }

                                function styledLine(label, value) {
                                    return '<span style="color:#80bfff">' + label + '</span> ' + richValue(value)
                                }

                                const message = '<p>' +
                                    '<b>' + qsTr('Invalid parameter values:') + '</b><br/>' +
                                    styledLine(qsTr('lat:'), lat) + '<br/>' +
                                    styledLine(qsTr('lon:'), lon) + '<br/>' +
                                    styledLine(qsTr('pullUp:'), pullUp) + '<br/>' +
                                    styledLine(qsTr('heading:'), heading) + '<br/>' +
                                    styledLine(qsTr('dive:'), dive) + '<br/>' +
                                    styledLine(qsTr('climb:'), climb) + '<br/>' +
                                    styledLine(qsTr('reach:'), reach) +
                                    '</p>'
                                console.warn(message)
                                QGroundControl.showMessageDialog(
                                    mainWindow,
                                    qsTr("Error"),
                                    message,
                                    Dialog.Ok
                                )
                                return
                            }

                            const diveStart = parseFloat(diveStartAltField.text)
                            const pitchP = parseFloat(pitchPGainField.text)
                            const pitchI = parseFloat(pitchIGainField.text)
                            const pitchD = parseFloat(pitchDGainField.text)
                            const rollP = parseFloat(rollPGainField.text)
                            const rollI = parseFloat(rollIGainField.text)
                            const rollD = parseFloat(rollDGainField.text)

                            if (isNaN(diveStart) || isNaN(pitchP) || isNaN(pitchI) || isNaN(pitchD) || isNaN(rollP) || isNaN(rollI) || isNaN(rollD)) {
                                console.warn("Invalid advanced parameter values")
                                return
                            }

                            page._rosBridge.setKamikazeParams(
                                lat, lon,
                                pullUp, heading, dive, climb, reach,
                                page._advancedExpanded,
                                diveStart,
                                pitchP, pitchI, pitchD,
                                rollP, rollI, rollD
                            )
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
