import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtPositioning 5.15

import QGroundControl

Item {
    property var _serverManager: QGroundControl.serverManager

    anchors.fill: parent

    ScrollView {
        anchors.fill: parent

        ColumnLayout {
            width: parent.availableWidth
            spacing: 16

            /* ---- Header ---- */
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

                    /* ---- Base URL editor ---- */
                TextField {
                    id: baseUrlField
                    Layout.preferredWidth: 260
                    placeholderText: _serverManager.baseUrl()
                    text: ""
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
                    text: _serverManager.serversimRunning ? "Stop Server sim" : "Run Server sim"
                    palette.buttonText: _serverManager.serversimRunning ? "white" : "orange"
                    onClicked: {
                        if (_serverManager.serversimRunning)
                            _serverManager.stopServerSim()
                        else
                            _serverManager.startServerSim()
                    }
                }
            }

            /* ---- Login panel ---- */
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

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter

                    Button { id: loginBtn
                        text: qsTr("Login")
                        Layout.preferredWidth: 120
                        onClicked: {
                            console.log("send:",
                                        usrnameField.text,
                                        passwrdField.text)
                            _serverManager.login(
                                usrnameField.text,
                                passwrdField.text
                            )
                        }
                    }
                }
            }

            /* ---- Server sim console ---- */
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 220
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

                        TextArea {
                            id: serverConsole
                            readOnly: true
                            wrapMode: Text.WrapAnywhere
                            font.family: "monospace"
                            font.pixelSize: 12
                            color: "#dddddd"
                            background: null
                            selectByMouse: true
                            textFormat: Text.RichText
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight

                        Button {
                            text: qsTr("Clear")
                            onClicked: serverConsole.clear()
                        }
                    }
                }
            }
        }
    }

    /* ---- Server status ---- */
    Connections {
        target: _serverManager

        function onConnectionResult(ok) {
            console.log("Server reachable:", ok)
            label.color = ok ? "#00FF00" : "#FF0000"
        }

        function onLoginSucceeded(){
            loginBtn.palette.buttonText = "#00FF00"
        }

        function onLoginFailed(){
            loginBtn.palette.buttonText = "#FF0000"
        }

        function onServerLog(line) {
            serverConsole.append("<font color='#13b51b'>" + line + "</font>")
            serverConsole.cursorPosition = serverConsole.length
        }

        function onServerError(line) {
            serverConsole.append("<font color='#ff5555'>[ERR] " + line + "</font>")
            serverConsole.cursorPosition = serverConsole.length
        }
    }
}
