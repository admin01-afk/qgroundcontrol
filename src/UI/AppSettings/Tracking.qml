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

            // --- Target Selector Card ---
            Rectangle {
                id: targetCard
                Layout.fillWidth: false
                Layout.preferredWidth: targetCardContent.implicitWidth + ScreenTools.defaultFontPixelWidth * 4
                Layout.preferredHeight: targetCardContent.implicitHeight + ScreenTools.defaultFontPixelHeight * 2
                implicitWidth: Layout.preferredWidth
                implicitHeight: Layout.preferredHeight

                color: qgcPal.windowShade
                border.color: qgcPal.windowShadeDark
                border.width: 1
                radius: 4

                ColumnLayout {
                    id: targetCardContent
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelWidth * 2
                    spacing: ScreenTools.defaultFontPixelHeight

                    QGCLabel {
                        text: qsTr("Target Selection Configuration")
                        font.bold: true
                    }

                    RowLayout {
                        spacing: ScreenTools.defaultFontPixelWidth * 2

                        QGCLabel {
                            text: qsTr("Target ID:")
                        }

                        QGCTextField {
                            id: targetIdField
                            text: "1"
                            Layout.fillWidth: true
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8
                            validator: IntValidator { bottom: 1; top: 999 }
                        }

                        QGCButton {
                            text: qsTr("Lock Target")
                            primary: true
                            onClicked: {
                                var tId = parseInt(targetIdField.text) || 0
                                page._rosBridge.setKonumHandlingConfig(tId, true)
                                page.addLog("Configured: Lock to Target " + tId)
                            }
                        }

                        QGCButton {
                            text: qsTr("Auto Selection")
                            onClicked: {
                                var tId = parseInt(targetIdField.text) || 0
                                page._rosBridge.setKonumHandlingConfig(tId, false)
                                page.addLog("Configured: Auto Selection (Pref: " + tId + ")")
                            }
                        }
                    }
                }
            }

            // --- Tracking mode checkboxes ---
            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                ServiceCheckBox {
                    text: "Yolo Active"
                    rosBridge: page._rosBridge
                    serviceStartMethod: "startYolo"
                    serviceStopMethod: "stopYolo"
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
        console.log(msg)
    }
}

