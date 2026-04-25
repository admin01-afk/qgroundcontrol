import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import Custom.Widgets
import QGroundControl.AppSettings

Item {
    id: root
    property var parentToolInsets                       // These insets tell you what screen real estate is available for positioning the controls in your overlay
    property var mapControl
    property var appSettings: QGroundControl.settingsManager.appSettings

    readonly property string noGPS:         qsTr("NO GPS")
    readonly property real   indicatorValueWidth:   ScreenTools.defaultFontPixelWidth * 7

    property var    _activeVehicle:         QGroundControl.multiVehicleManager.activeVehicle
    property real   _indicatorDiameter:     ScreenTools.defaultFontPixelWidth * 18
    property real   _indicatorsHeight:      ScreenTools.defaultFontPixelHeight
    property var    _sepColor:              qgcPal.globalTheme === QGCPalette.Light ? Qt.rgba(0,0,0,0.5) : Qt.rgba(1,1,1,0.5)
    property color  _indicatorsColor:       qgcPal.text
    property bool   _isVehicleGps:          _activeVehicle ? _activeVehicle.gps.count.rawValue > 1 && _activeVehicle.gps.hdop.rawValue < 1.4 : false
    property string _altitude:              _activeVehicle ? (isNaN(_activeVehicle.altitudeRelative.value) ? "0.0" : _activeVehicle.altitudeRelative.value.toFixed(1)) + ' ' + _activeVehicle.altitudeRelative.units : "0.0"
    property string _distanceStr:           isNaN(_distance) ? "0" : _distance.toFixed(0) + ' ' + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString
    property real   _heading:               _activeVehicle   ? _activeVehicle.heading.rawValue : 0
    property real   _distance:              _activeVehicle ? _activeVehicle.distanceToHome.rawValue : 0
    property string _messageTitle:          ""
    property string _messageText:           ""
    property real   _toolsMargin:           ScreenTools.defaultFontPixelWidth * 3

    /**
     * Calculate tool insets based on panel states
     * These tell the map what screen areas are occupied by UI so it doesn't pan under them
     * minimized image panel is occupied, panel and maximized imagePanel ignored
     */
    QGCToolInsets {
        id:                     _totalToolInsets
        // Inherit parent insets
        leftEdgeTopInset:       parentToolInsets.leftEdgeTopInset
        leftEdgeCenterInset:    parentToolInsets.leftEdgeCenterInset
        leftEdgeBottomInset:    parentToolInsets.leftEdgeBottomInset + (imagePanelOpen && !imagePanelMaximized ? imagePanel.width : 0)

        rightEdgeTopInset:      parentToolInsets.rightEdgeTopInset
        rightEdgeCenterInset:   parentToolInsets.rightEdgeCenterInset
        rightEdgeBottomInset:   parentToolInsets.rightEdgeBottomInset

        topEdgeLeftInset:       parentToolInsets.topEdgeLeftInset
        topEdgeCenterInset:     parentToolInsets.topEdgeCenterInset
        topEdgeRightInset:      parentToolInsets.topEdgeRightInset

        bottomEdgeLeftInset:    parentToolInsets.bottomEdgeLeftInset + (imagePanelOpen && !imagePanelMaximized ? imagePanel.height : 0)
        bottomEdgeCenterInset:  parentToolInsets.bottomEdgeCenterInset + (imagePanelOpen && !imagePanelMaximized ? imagePanel.height : 0)
        bottomEdgeRightInset:   parentToolInsets.bottomEdgeRightInset
    }

    /**
     * Public property to expose calculated tool insets to FlyView
     */
    readonly property var totalToolInsets: _totalToolInsets

    /* panel state */
    property bool panelOpen: false
    property int currentIndex: 0
    property bool imagePanelOpen: false
    property bool imagePanelMaximized: false
    property var allPages: [
        {
            name: qsTr("Server"),
            url: "qrc:/qml/QGroundControl/AppSettings/Server.qml",
            iconUrl: "qrc:/InstrumentValueIcons/servers.svg",
            pageVisible: function() { return true }
        },
        {
            name: qsTr("Kamikaze"),
            url: "qrc:/qml/QGroundControl/AppSettings/Kamikaze.qml",
            iconUrl: "qrc:/res/qr_set.png",
            pageVisible: function() { return QGroundControl.settingsManager.appSettings.operationMode === AppSettings.SAVASAN}
        },
        {
            name: qsTr("General"),
            url: "qrc:/qml/QGroundControl/AppSettings/General.qml",
            iconUrl: "qrc:/InstrumentValueIcons/wrench.svg",
            pageVisible: function() { return true }
        },
        {
            name: qsTr("Tracking"),
            url: "qrc:/qml/QGroundControl/AppSettings/Tracking.qml",
            iconUrl: "qrc:/InstrumentValueIcons/target.svg",
            pageVisible: function() { return QGroundControl.settingsManager.appSettings.operationMode === AppSettings.SAVASAN}
        },
        {
            name: qsTr("Guidance"),
            url: "qrc:/qml/QGroundControl/AppSettings/Guidance.qml",
            iconUrl: "qrc:/InstrumentValueIcons/target.svg",
            pageVisible: true
        }
    ]

    QGCPalette { id: qgcPal; colorGroupEnabled: root.enabled }

    Shortcut {
        id: shiftSpaceShortcut
        sequence: "Shift+Space"
        context: Qt.ApplicationShortcut

        onActivated: {
            if (Qt.focusItem && Qt.focusItem.cursorPosition !== undefined) {
                return
            }
            if(!imagePanelMaximized){ imagePanelOpen = true }
            imagePanelMaximized = !imagePanelMaximized
        }
    }
    Shortcut {
        id: spaceShortcut
        sequence: "Space"
        context: Qt.ApplicationShortcut // Make it application-wide so other focused items don't swallow it
        onActivated: {
            if (Qt.focusItem && Qt.focusItem.cursorPosition !== undefined) {
                // user is typing: ignore spacebar toggle
                return
            }
            imagePanelOpen = !imagePanelOpen
        }
    }
    Shortcut {
        id: pShortcut
        sequence: "P"
        context: Qt.ApplicationShortcut // Make it application-wide so other focused items don't swallow it
        onActivated: {
            if (Qt.focusItem && Qt.focusItem.cursorPosition !== undefined) {
                // user is typing: ignore spacebar toggle
                return
            }
            panelOpen = !panelOpen
        }
    }
    Repeater {
        model: pagesModel
        delegate: Item { width: 0 ; height: 0
            Shortcut {
                sequence: (index + 1).toString()
                context: Qt.ApplicationShortcut

                onActivated: {
                    if (Qt.focusItem && Qt.focusItem.cursorPosition !== undefined) return
                    root.currentIndex = index
                }
            }
        }
    }

    ListModel { id: pagesModel }

    function buildModel() {
        pagesModel.clear()
        for (var i=0; i<allPages.length; i++) {
            try {
                if (typeof allPages[i].pageVisible === "function" && !allPages[i].pageVisible()) continue
            } catch (e) {
                console.warn("pageVisible threw", allPages[i].name, e)
                continue
            }
            pagesModel.append({ name: allPages[i].name, url: allPages[i].url, iconUrl: allPages[i].iconUrl })
        }
        if (pagesModel.count === 0) currentIndex = -1
        else if (currentIndex < 0 || currentIndex >= pagesModel.count) currentIndex = 0
    }

    Component.onCompleted: buildModel()

    Rectangle {
        id: panel
        width: parent.width
        height: Math.min(parent.height * 0.90, 900)
        x: 0
        y: panelOpen ? 0 : (appSettings.panelSlideFromTop ? -1 : 1) * (parent.height + (toolbar ? toolbar.height : 0))
        z: 100
        color: qgcPal.windowShadeDark
        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // Prevent wheel events from propagating to map
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            // --- improved tab bar (icon + text) ---
            RowLayout {
                id: tabBar
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth
                visible: pagesModel.count > 0

                Repeater {
                    model: pagesModel
                    delegate: ToolButton {
                        id: tb

                        property bool selected: index === root.currentIndex

                        checkable: false
                        width: Math.max(120, implicitWidth)
                        height: ScreenTools.defaultFontPixelHeight * 2.4

                        onClicked: { if (root.currentIndex !== index) root.currentIndex = index }

                        contentItem: RowLayout {
                            anchors.centerIn: parent
                            spacing: ScreenTools.defaultFontPixelWidth / 2
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter

                            // --- Icon ---
                            Item {
                                width: tabLabel.font.pixelSize       // limit width to label height
                                height: tabLabel.font.pixelSize      // limit height to label height
                                Layout.alignment: Qt.AlignVCenter

                                Image {
                                    anchors.fill: parent
                                    source: iconUrl
                                    fillMode: Image.PreserveAspectFit
                                }
                            }

                            // --- Label ---
                            Label {
                                id: tabLabel
                                text: name
                                font.pixelSize: ScreenTools.defaultFontPixelHeight
                                color: tb.selected ? qgcPal.text : qgcPal.text
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        background: Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: tb.selected ? qgcPal.buttonHighlight : "transparent"
                            border.color: tb.selected ? qgcPal.buttonHighlight : "transparent"
                            border.width: tb.selected ? 1 : 0
                        }
                    }
                }
                Item { Layout.fillWidth: true } // spacer
            }

            // --- content area: lazy load selected page ---
            Rectangle {
                id: contentArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"

                Loader {
                    id: pageLoader
                    anchors.fill: parent
                    asynchronous: false
                    active: pagesModel.count>0 && root.currentIndex >= 0
                    source: (pagesModel.count>0 && root.currentIndex >= 0) ? pagesModel.get(root.currentIndex).url : ""
                }
                Text { anchors.centerIn: parent; text: qsTr("No pages"); visible: !pageLoader.active }
            }
        }
    }

    Rectangle {
        id: imagePanel
        anchors.left: parent.left
        anchors.bottom: parent.bottom

        width:  (imagePanelMaximized) ? parent.width : parent.width * 0.40
        height: (imagePanelMaximized) ? parent.height : parent.height * 0.45

        z: 50
        color: "transparent"
        anchors.bottomMargin: imagePanelOpen ? 0 : -(height - 30)
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // Prevent wheel events from propagating to map
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        }

        ColumnLayout {
            anchors.fill: parent

            // --- Expand/Collapse Button ---
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2

                Button {
                    text: imagePanelOpen ? "▼" : "▲"
                    Layout.preferredWidth: 150
                    anchors.centerIn: parent
                    onClicked: imagePanelOpen = !imagePanelOpen
                    background: Rectangle {
                        color: qgcPal.buttonHighlight
                        radius: 4
                        border.color: qgcPal.buttonBorder
                        border.width: 1
                    }
                    contentItem: Text {
                        text: parent.text
                        color: qgcPal.text
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.9
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // --- Image Display Area ---
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "black"
                radius: 4

                Image {
                    id: rosImage
                    anchors.fill: parent
                    anchors.margins: 4
                    source: "image://ros/plane1/image_processed"
                    fillMode: Image.PreserveAspectFit
                    cache: false
                }

                Text {
                    anchors.centerIn: parent
                    text: "No image"
                    color: qgcPal.text
                    visible: rosImage.status === Image.Null || rosImage.status === Image.Error
                    font.pixelSize: ScreenTools.defaultFontPixelHeight
                }
            }
        }

        Component.onCompleted: {
            RosBridgeNode.subscribeImageTopic("/plane1/image_processed")
        }

        Connections {
            target: RosBridgeNode
            onImageRevisionChanged: rosImage.source = "image://ros/plane1/image_processed?" + Math.random()
        }
    }
}
