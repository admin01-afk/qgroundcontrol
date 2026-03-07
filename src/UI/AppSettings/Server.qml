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

    property var _serverManager: QGroundControl.serverManager
    property var _rosBridge: QGroundControl.rosBridge
    property var latFields: []
    property var lonFields: []

    QGCPalette { id: qgcPal; colorGroupEnabled: page.enabled }

    /* ---------------- Header / Server controls ---------------- */
    SettingsGroupLayout {
        Layout.fillWidth: true

        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth

            Item { Layout.fillWidth: true }

            QGCLabel { id: serverTitleLabel
                objectName: "serverTitleLabel"
                text: qsTr("Server")
                //font.pixelSize: 20
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth

            // Base URL label + text field
            RowLayout {
                spacing: ScreenTools.defaultFontPixelWidth
                Layout.preferredWidth: 250

                QGCLabel {
                    text: qsTr("Base URL")
                    verticalAlignment: Text.AlignVCenter
                    Layout.preferredWidth: 100
                }
                QGCTextField {
                    id: baseUrlField
                    placeholderText: _serverManager.baseUrl()
                    Layout.fillWidth: true
                }
            }

            QGCButton {
                text: qsTr("Set")
                onClicked: {
                    if (baseUrlField.text.length > 0) {
                        _serverManager.setBaseUrl(baseUrlField.text)
                        baseUrlField.text = ""
                    }
                }
            }

            QGCButton {
                text: qsTr("Check Server")
                onClicked: _serverManager.checkConnection()
            }

            QGCButton {
                text: _serverManager.serversimRunning
                      ? qsTr("Stop Server sim")
                      : qsTr("Run Server sim")
                onClicked: {
                    _serverManager.serversimRunning
                        ? _serverManager.stopServerSim()
                        : _serverManager.startServerSim()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth

            QGCLabel {
                text: qsTr("RosBridge: Running (Built-in)")
                color: "#00AA00"
                font.bold: true
                verticalAlignment: Text.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            QGCButton {
                text: "call /start_yolo"
                onClicked: {
                    _rosBridge.callService("/start_yolo")
                }
            }
        }
    }

    /* -------------------------- Login ------------------------- */
    SettingsGroupLayout {
        Layout.fillWidth: true
        heading: qsTr("Login")

        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth

            QGCLabel {
                text: qsTr("Username")
                verticalAlignment: Text.AlignVCenter
                Layout.preferredWidth: 120
            }
            QGCTextField {
                id: usrnameField
                Layout.preferredWidth: 280
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth

            QGCLabel {
                text: qsTr("Password")
                verticalAlignment: Text.AlignVCenter
                Layout.preferredWidth: 120
            }
            QGCTextField {
                id: passwrdField
                echoMode: TextInput.Password
                Layout.preferredWidth: 280
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth

            QGCButton {
                id: loginBtn
                text: qsTr("Login")
                onClicked: {
                    _serverManager.login(
                        usrnameField.text,
                        passwrdField.text
                    )
                }
            }

            Item { Layout.fillWidth: true }

            QGCLabel {
                text: qsTr("Login status:")
                verticalAlignment: Text.AlignVCenter
            }
            QGCLabel {
                id: loginStatus
                text: qsTr("Not logged")
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    /* ---------------- Server Console ---------------- */
    SettingsGroupLayout {
        Layout.fillWidth: true
        heading: qsTr("Server Console")

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 240
            radius: ScreenTools.defaultFontPixelWidth / 2
            color: qgcPal.windowShadeDark
            border.color: qgcPal.windowShade

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth
                spacing: ScreenTools.defaultFontPixelHeight / 2

                ListView {
                    id: logView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: _serverManager.logs
                    clip: true
                    spacing: 2

                    delegate: Text {
                        text: modelData
                        color: qgcPal.text
                        font.family: "monospace"
                        font.pixelSize: 12
                        wrapMode: Text.WrapAnywhere
                    }

                    // keep end visible when new lines are appended
                    onCountChanged: positionViewAtEnd()
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignRight

                    Button {
                        text: qsTr("Clear")
                        onClicked: _serverManager.clearLogs()
                    }
                }
            }
        }
    }

    /* ---------------- Telemetry control ---------------- */
    SettingsGroupLayout {
        Layout.fillWidth: true
        heading: qsTr("Telemetry")

        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth

            QGCButton {
                text: _serverManager.telemRunning
                      ? qsTr("Stop telem loop")
                      : qsTr("Start telem loop")
                onClicked: _serverManager.toggleTelem()
            }

            Item { Layout.fillWidth: true }

            QGCLabel { text: qsTr("Telem running:") }
            QGCLabel { text: _serverManager.telemRunning ? qsTr("Yes") : qsTr("No") }
        }
    }

    /* ---------------- Competition Field ---------------- */
    SettingsGroupLayout {
        Layout.fillWidth: true
        heading: qsTr("Competition Field")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelHeight / 2

            Repeater {
                model: 4
                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCLabel {
                        text: qsTr("Lat %1").arg(index + 1)
                        Layout.preferredWidth: 100
                        verticalAlignment: Text.AlignVCenter
                    }
                    QGCTextField {
                        id: latFieldDelegate
                        Layout.preferredWidth: 200
                        Component.onCompleted: latFields[index] = latFieldDelegate
                    }

                    QGCLabel {
                        text: qsTr("Lon %1").arg(index + 1)
                        Layout.preferredWidth: 100
                        verticalAlignment: Text.AlignVCenter
                    }
                    QGCTextField {
                        id: lonFieldDelegate
                        Layout.preferredWidth: 200
                        Component.onCompleted: lonFields[index] = lonFieldDelegate
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCButton {
                    text: qsTr("Display Field")
                    Layout.fillWidth: true
                    onClicked: {
                        var coords = []
                        for (var i = 0; i < latFields.length; i++) {
                            var lat = latFields[i].text
                            var lon = lonFields[i].text
                            if (lat !== "" && lon !== "") {
                                coords.push(QtPositioning.coordinate(
                                            parseFloat(lat),
                                            parseFloat(lon)
                                        ))
                            }
                        }
                        _serverManager.setCompetitionField(coords)
                    }
                }

                QGCButton {
                    text: qsTr("Load Test")
                    Layout.preferredWidth: 110
                    onClicked: {
                        var testField = [
                            [-35.3638, 149.1628],
                            [-35.3638, 149.1678],
                            [-35.3618, 149.1678],
                            [-35.3618, 149.1628]
                        ]
                        for (var i = 0; i < testField.length; i++) {
                            latFields[i].text = testField[i][0].toFixed(6)
                            lonFields[i].text = testField[i][1].toFixed(6)
                        }

                        var coords = []
                        for (var i = 0; i < latFields.length; i++) {
                            if (latFields[i].text !== "" && lonFields[i].text !== "")
                                coords.push(QtPositioning.coordinate(
                                    parseFloat(latFields[i].text),
                                    parseFloat(lonFields[i].text)
                                ))
                        }
                        _serverManager.setCompetitionField(coords)
                    }
                }
            }
        }
    }

    Connections {
        target: _serverManager

        function onConnectionResult(ok) {
            serverTitleLabel.color = ok ? "#00FF00" : "#FF0000"
        }

        function onLoginSucceeded() {
            loginStatus.text = qsTr("Success")
            loginStatus.color = "#00FF00"
        }

        function onLoginFailed() {
            loginStatus.text = qsTr("Failed")
            loginStatus.color = "#FF0000"
        }
    }

    Component.onCompleted: {
        // On page load, check server reachability so the Server label
        // reflects the current connection state.
        _serverManager.checkConnection(false)

        // Login status is not checked On page load !
        // Sending a login request on page load could have unintended
        // consequences depending on server behavior (session handling).
        // As a result, the Login status defaults to "Not logged".
    }
}
