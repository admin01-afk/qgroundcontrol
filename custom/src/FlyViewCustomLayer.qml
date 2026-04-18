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

    QGCToolInsets {
        id:                     _totalToolInsets
        leftEdgeTopInset:       parentToolInsets.leftEdgeTopInset
        leftEdgeCenterInset:    0
        leftEdgeBottomInset:    parentToolInsets.leftEdgeBottomInset
        rightEdgeTopInset:      parentToolInsets.rightEdgeTopInset
        rightEdgeCenterInset:   parentToolInsets.rightEdgeCenterInset
        rightEdgeBottomInset:   0
        topEdgeLeftInset:       parentToolInsets.topEdgeLeftInset
        topEdgeCenterInset:     0
        topEdgeRightInset:      parentToolInsets.topEdgeRightInset
        bottomEdgeLeftInset:    parentToolInsets.bottomEdgeLeftInset
        bottomEdgeCenterInset:  parentToolInsets.bottomEdgeCenterInset
        bottomEdgeRightInset:   0
    }

    /* panel state */
    property bool panelOpen: false
    property int currentIndex: 0
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
        }
    ]

    QGCPalette { id: qgcPal; colorGroupEnabled: root.enabled }

    Shortcut {
        id: spaceShortcut
        sequence: "Space"
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
}
