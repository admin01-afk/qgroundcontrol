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

    // managers from QGroundControl context (same as your other file)
    property var _kamikazeLocManager: QGroundControl.kamikazeLocManager
    property var _serverManager:      QGroundControl.serverManager
    property var _rosBridge: QGroundControl.rosBridge

    property bool recordingActive: false

    signal competitionStarted(int competitionNo)

    QGCPalette { id: qgcPal; colorGroupEnabled: page.enabled }

    SettingsGroupLayout {
        Layout.fillWidth: true
        heading: qsTr("Competition Control")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelHeight

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel { enabled: false
                    text: qsTr("Competition no")
                    Layout.preferredWidth: 140
                    verticalAlignment: Text.AlignVCenter
                }

                ComboBox { enabled: false
                    id: competitionNoCombo
                    Layout.preferredWidth: 120
                    // simple numeric list — adapt / expand as needed
                    model: [ "1", "2", "3", "4", "5" ]
                    currentIndex: 0
                }

                Item { Layout.fillWidth: true }

                QGCLabel {
                    id: competitionStatusLabel
                    text: qsTr("Competition status: ") + (competitionRunning ? qsTr("Online") : qsTr("Offline"))
                    verticalAlignment: Text.AlignVCenter
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCButton {
                    id: startCompetitionBtn
                    text: qsTr("Start competition")
                    onClicked: {
                        // start 15 minute countdown
                        if (!competitionRunning) {
                            competitionRunning = true
                            timeLeftSeconds = 15 * 60
                            countdownTimer.start()
                            competitionStarted(parseInt(competitionNoCombo.currentText))
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                QGCLabel {
                    id: timeLeftLabel
                    text: qsTr("Time left: ") + formatTimeLeft(timeLeftSeconds)
                    verticalAlignment: Text.AlignVCenter
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                ServiceCheckBox {
                    text: active ? qsTr("Stop recording") : qsTr("Start recording")
                    rosBridge: page._rosBridge
                    serviceStartMethod: "startRecording"
                    serviceStopMethod: "stopRecording"
                    active: page.recordingActive
                    logPrefix: "Recording"
                    logFn: page.addLog
                }

                QGCButton {
                    text: qsTr("HSS Pull&Push")
                    onClicked: {
                        _serverManager.getHSS()
                    }
                }
            }
        }
    }

    // --- countdown logic ---
    property bool competitionRunning: false
    property int timeLeftSeconds: 15 * 60

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            if (timeLeftSeconds > 0) {
                timeLeftSeconds--
            } else {
                // countdown finished
                running = false
                competitionRunning = false
            }
        }
    }

    function formatTimeLeft(seconds) {
        if (!seconds || seconds <= 0) return "00:00"
        var mm = Math.floor(seconds / 60)
        var ss = seconds % 60
        return (mm < 10 ? "0" + mm : "" + mm) + ":" + (ss < 10 ? "0" + ss : "" + ss)
    }

    // keep label updated reactively
    Connections {
        target: countdownTimer
        onTriggered: {
            timeLeftLabel.text = qsTr("Time left: ") + formatTimeLeft(timeLeftSeconds)
        }
    }

    // handle QR response if server manager emits it (same as your other file)
    Connections {
        target: _serverManager
        function onQrCoordinatesReceived(coord) {
            if (!coord) {
                console.warn("Received empty QR coordinate")
                return
            }
            // update kamikaze manager coordinate if available
            if (_kamikazeLocManager) {
                _kamikazeLocManager.coordinate = coord
            }
            console.log("QR coords received:", coord.latitude, coord.longitude)
        }

        function onErrorOccurred(header, message) {
            console.warn("Server error:", header, message)
        }
    }

    // helper function to add time-stamped log entries
    function addLog(msg) {
        console.log(msg)
    }
}
