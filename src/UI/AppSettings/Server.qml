import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtPositioning 5.15

import QGroundControl

// TODO add clear button to fields

Item {
    anchors.fill: parent

    property var _serverManager: QGroundControl.serverManager
    property var latFields: []
    property var lonFields: []


    ScrollView {
        anchors.fill: parent

        ColumnLayout {
            width: parent.availableWidth
            spacing: 16

            /* ================= Header ================= */
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item { Layout.fillWidth: true }

                Label {
                    id: label
                    text: qsTr("Server")
                    font.pixelSize: 20
                    font.bold: true
                    color: "#FF0000"
                    horizontalAlignment: Text.AlignHCenter
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: qsTr("Check Server")
                    onClicked: _serverManager.checkConnection()
                }

                TextField {
                    id: baseUrlField
                    Layout.preferredWidth: 260
                    placeholderText: _serverManager.baseUrl()
                }

                Button {
                    text: qsTr("Set")
                    onClicked: {
                        if (baseUrlField.text.length > 0) {
                            _serverManager.setBaseUrl(baseUrlField.text)
                            baseUrlField.text = ""
                        }
                    }
                }

                Button {
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

            /* ================= Login ================= */
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                RowLayout {
                    spacing: 12
                    Label {
                        text: qsTr("Username")
                        Layout.preferredWidth: 120
                        horizontalAlignment: Text.AlignRight
                    }
                    TextField {
                        id: usrnameField
                        Layout.preferredWidth: 220
                    }
                }

                RowLayout {
                    spacing: 12
                    Label {
                        text: qsTr("Password")
                        Layout.preferredWidth: 120
                        horizontalAlignment: Text.AlignRight
                    }
                    TextField {
                        id: passwrdField
                        Layout.preferredWidth: 220
                        echoMode: TextInput.Password
                    }
                }

                Button {
                    id: loginBtn
                    text: qsTr("Login")
                    Layout.preferredWidth: 120
                    onClicked: {
                        _serverManager.login(
                            usrnameField.text,
                            passwrdField.text
                        )
                    }
                }
            }

            /* ================= Server Console ================= */
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 260
                radius: 6
                color: "#1e1e1e"
                border.color: "#404040"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 6

                    Label {
                        text: qsTr("Server Console")
                        color: "#cccccc"
                        font.bold: true
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ListView {
                            id: logView
                            model: _serverManager.logs
                            spacing: 2
                            clip: true

                            delegate: Text {
                                text: modelData
                                color: "#dddddd"
                                font.family: "monospace"
                                font.pixelSize: 12
                                wrapMode: Text.WrapAnywhere
                            }

                            onCountChanged: positionViewAtEnd()
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        Button {
                            text: qsTr("Clear")
                            onClicked: _serverManager.clearLogs()
                        }
                    }
                }
            }

            /* ================= Telemetry ================= */
            Button {
                text: _serverManager.telemRunning
                      ? qsTr("Stop telem loop")
                      : qsTr("Start telem loop")

                onClicked: _serverManager.toggleTelem()
            }

            /* ============= competition field ============== */
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: column.implicitHeight + 20
                radius: 6
                color: "#111111"
                border.color: "#444"

                ColumnLayout { id: column
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // Title
                    Label {
                        text: qsTr("Competition Field")
                        font.pixelSize: 14
                        font.bold: true
                        color: "white"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#333"
                    }

                    // Coordinates grid
                    Repeater {
                        model: 4

                        delegate: RowLayout {
                            spacing: 6
                            Layout.fillWidth: true

                            TextField {
                                placeholderText: qsTr("Lat %1").arg(index + 1)
                                Layout.fillWidth: true
                                Component.onCompleted: latFields[index] = this
                            }

                            TextField {
                                placeholderText: qsTr("Lon %1").arg(index + 1)
                                Layout.fillWidth: true
                                Component.onCompleted: lonFields[index] = this
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#222"
                    }

                    // Buttons row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Button {
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
                                            parseFloat(lon)))
                                    }
                                }
                                _serverManager.setCompetitionField(coords)
                            }
                        }

                        Button {
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
                                _serverManager.setCompetitionField(coords)
                            }
                        }
                    }
                }
            }
        }
    }
    /* ================= Status Signals ================= */
    Connections {
        target: _serverManager

        function onConnectionResult(ok) {
            label.color = ok ? "#00FF00" : "#FF0000"
        }

        function onLoginSucceeded() {
            loginBtn.palette.buttonText = "#00FF00"
        }

        function onLoginFailed() {
            loginBtn.palette.buttonText = "#FF0000"
        }
    }

    Component.onCompleted: {
        _serverManager.checkConnection()
    }
}
