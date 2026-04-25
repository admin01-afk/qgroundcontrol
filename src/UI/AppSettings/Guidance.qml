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

    QGCPalette { id: qgcPal; colorGroupEnabled: page.enabled }

    property var _rosBridge: QGroundControl.rosBridge

    /* ---------------- Header ---------------- */
    SettingsGroupLayout {
        Layout.fillWidth: true
        heading: qsTr("Guidance")

        /* ------------- Guidance Info ------------- */
        SettingsGroupLayout {
            Layout.fillWidth: true
            heading: qsTr("Guidance Info")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelHeight * 0.5

                // Current Mode Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCLabel {
                        text: qsTr("Current Mode:")
                        font.bold: true
                        color: qgcPal.text
                    }
                    QGCLabel {
                        text: page._rosBridge.currentMode
                        color: qgcPal.highlight
                        font.italic: true
                        Layout.fillWidth: true
                    }
                }

                // Mode Lock Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCLabel {
                        text: qsTr("Mode Lock:")
                        font.bold: true
                        color: qgcPal.text
                    }
                    Rectangle {
                        width: ScreenTools.defaultFontPixelHeight
                        height: ScreenTools.defaultFontPixelHeight
                        radius: 3
                        color: page._rosBridge.modeLock ? qgcPal.highlight : qgcPal.windowShade
                        border.color: qgcPal.text
                        border.width: 1

                        QGCLabel {
                            anchors.centerIn: parent
                            text: page._rosBridge.modeLock ? "✓" : ""
                            font.bold: true
                            color: qgcPal.buttonText
                        }
                    }
                    Item { Layout.fillWidth: true }
                }

                // Method Names and Auths
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelHeight * 0.3

                    QGCLabel {
                        text: qsTr("Available Methods:")
                        font.bold: true
                        color: qgcPal.text
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: methodsColumn.implicitHeight + ScreenTools.defaultFontPixelHeight
                        color: qgcPal.windowShade
                        border.color: qgcPal.text
                        border.width: 1
                        radius: 3

                        ColumnLayout {
                            id: methodsColumn
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.5
                            spacing: ScreenTools.defaultFontPixelHeight * 0.3

                            Repeater {
                                model: page._rosBridge.methodNames.length
                                delegate: RowLayout {
                                    Layout.fillWidth: true
                                    spacing: ScreenTools.defaultFontPixelWidth

                                    Rectangle {
                                        width: ScreenTools.defaultFontPixelHeight
                                        height: ScreenTools.defaultFontPixelHeight
                                        radius: 2
                                        color: page._rosBridge.methodAuths[index] ? qgcPal.highlight : qgcPal.windowShade
                                        border.color: qgcPal.text
                                        border.width: 1

                                        QGCLabel {
                                            anchors.centerIn: parent
                                            text: page._rosBridge.methodAuths[index] ? "✓" : "✗"
                                            font.bold: true
                                            color: qgcPal.buttonText
                                            font.pixelSize: ScreenTools.smallFontPixelSize
                                        }
                                    }

                                    QGCLabel {
                                        text: page._rosBridge.methodNames[index]
                                        color: qgcPal.text
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                            }

                            QGCLabel {
                                visible: page._rosBridge.methodNames.length === 0
                                text: qsTr("No methods available")
                                color: qgcPal.textFieldText
                                font.italic: true
                            }
                        }
                    }
                }
            }
        }
        /* ------------- Guidance Command ------------- */
        SettingsGroupLayout {
            Layout.fillWidth: true
            heading: qsTr("Guidance Command")

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("Command:")
                    verticalAlignment: Text.AlignVCenter
                }

                QGCComboBox {
                    id: commandCombo
                    Layout.minimumWidth: contentItem.implicitWidth + ScreenTools.defaultFontPixelWidth * 4
                    Layout.fillWidth: false
                    model: [
                        {text: "NOTHING", value: 0},
                        {text: "DIRECT_PURSUIT", value: 1},
                        {text: "PREDICT_PURSUIT", value: 2},
                        {text: "LINE_PURSUIT", value: 3},
                        {text: "WINGMANLINE", value: 4},
                        {text: "MISSILE", value: 5},
                        {text: "WINGMAN", value: 6},
                        {text: "VISUAL_TRACK", value: 7},
                        {text: "DRAW_8", value: 10},
                        {text: "LOCK", value: 100},
                        {text: "UNLOCK", value: 200}
                    ]
                    textRole: "text"
                }

                QGCLabel {
                    text: qsTr("Force:")
                    verticalAlignment: Text.AlignVCenter
                }

                Switch {
                    id: forceSwitch
                    checked: false
                }

                QGCButton {
                    text: qsTr("SEND")
                    onClicked: {
                        var commandValue = commandCombo.model[commandCombo.currentIndex].value
                        page._rosBridge.sendGuidanceCommand(commandValue, forceSwitch.checked)
                    }
                }
            }
        }
    }

}
