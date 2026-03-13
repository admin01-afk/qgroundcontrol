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

                CheckBox {
                    id: gpsCheck
                    text: qsTr("GPS Track Active")
                    checked: gpsTrackActive
                    onCheckedChanged: {
                        gpsTrackActive = checked
                        addLog("GPS Track " + (checked ? "enabled" : "disabled"))
                        if(checked){_rosBridge.startNavigation()}else{_rosBridge.stopNavigation()}
                    }
                }

                CheckBox {
                    id: visualCheck
                    text: qsTr("Visual Track Active")
                    checked: visualTrackActive
                    onCheckedChanged: {
                        visualTrackActive = checked
                        addLog("Visual Track " + (checked ? "enabled" : "disabled"))
                        if(checked){_rosBridge.startVisualTrack()}else{_rosBridge.stopVisualTrack()}
                    }
                }

                CheckBox {
                    id: yoloCheck
                    text: qsTr("Yolo Active")
                    checked: yoloActive
                    onCheckedChanged: {
                        yoloActive = checked
                        addLog("Yolo " + (checked ? "enabled" : "disabled"))
                        if(checked){_rosBridge.startYolo()}else{_rosBridge.stopYolo()}
                    }
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
                                font.pixelSize: ScreenTools.defaultFontPixelHeight - 2
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
        var t = new Date()
        var ts = t.toLocaleTimeString()
        trackLogModel.append({ message: ts + " - " + msg })
        // keep view scrolled to bottom
        Qt.callLater(function() { trackLogView.positionViewAtEnd() })
    }

    // optional: expose a method to append logs from C++ via context property
    // e.g., QmlEngine->rootContext()->setContextProperty("trackingLogPage", rootObject)
}
