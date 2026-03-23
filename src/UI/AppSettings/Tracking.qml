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

    property var _rosBridge: QGroundControl.rosBridge
    property var _serverManager: QGroundControl.serverManager

    // state properties
    property bool gpsTrackActive: false
    property bool visualTrackActive: false
    property bool yoloActive: false

    // simple model for the track log
    ListModel { id: trackLogModel }

    // exported signals for selection actions (implement in C++ / parent QML)
    signal selectManually()
    signal startAutoSelection()
    signal targetChanged(string targetId)

    QGCPalette { id: qgcPal; colorGroupEnabled: page.enabled }

    SettingsGroupLayout {
        Layout.fillWidth: true
        heading: qsTr("Tracking Control")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelHeight

            // --- Target selector row ---
            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("Target ID:")
                    Layout.preferredWidth: 120
                    verticalAlignment: Text.AlignVCenter
                }

                ComboBox { enabled: false
                    id: targetCombo
                    Layout.preferredWidth: 140
                    // replace with dynamic model if you have one
                    // model: [ "1", "2", "3", "4" ]
                    onCurrentTextChanged: {
                        targetChanged(currentText)
                        addLog("Target selected: " + currentText)
                    }
                }

                QGCButton { enabled: false
                    text: qsTr("Select manually")
                    onClicked: {
                        selectManually()
                        addLog("Manual target selection requested")
                    }
                }

                QGCButton { enabled: false
                    text: qsTr("Start auto selection")
                    onClicked: {
                        startAutoSelection()
                        addLog("Auto selection started")
                    }
                }
            }

            // --- Tracking mode checkboxes ---
            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                ServiceCheckBox {
                    text: "GPS Track Active"
                    rosBridge: page._rosBridge
                    serviceStartFn: rosBridge.startNavigation
                    serviceStopFn: rosBridge.stopNavigation
                    active: page.gpsTrackActive
                    logPrefix: "GPS_Track"
                    logFn: page.addLog
                }

                ServiceCheckBox {
                    text: "Visual Track Active"
                    rosBridge: page._rosBridge
                    serviceStartFn: rosBridge.startVisualTrack
                    serviceStopFn: rosBridge.stopVisualTrack
                    active: page.visualTrackActive
                    logPrefix: "Visual_Track"
                    logFn: page.addLog
                }

                ServiceCheckBox {
                    text: "Yolo Active"
                    rosBridge: page._rosBridge
                    serviceStartFn: rosBridge.startYolo
                    serviceStopFn: rosBridge.stopYolo
                    active: page.yoloActive
                    logPrefix: "Yolo"
                    logFn: page.addLog
                }
            }

            // --- Track log rectangle ---
            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelHeight

                    QGCLabel {
                        text: qsTr("Track log")
                        Layout.fillWidth: true
                        verticalAlignment: Text.AlignVCenter
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 160
                        radius: 4
                        border.width: 1
                        color: qgcPal.windowShade // uses QGC palette
                        border.color: qgcPal.windowShadeDark

                        ListView {
                            id: trackLogView
                            anchors.fill: parent
                            model: trackLogModel
                            interactive: true
                            clip: true
                            delegate: Text {
                                text: message
                                wrapMode: Text.Wrap
                                font.pixelSize: ScreenTools.defaultFontPixelHeight - 4
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }

            // small control row to clear log if desired
            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                Item { Layout.fillWidth: true }

                QGCButton {
                    text: qsTr("Clear log")
                    onClicked: {
                        trackLogModel.clear()
                    }
                }
            }
        }
    }

    // helper function to add time-stamped log entries
    function addLog(msg) {
        trackLogModel.append({ message: msg })
        Qt.callLater(function() { trackLogView.positionViewAtEnd() }) // keep view scrolled to bottom
    }
}

