import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import Custom.Widgets

Item {
    id: root
    property var parentToolInsets                       // These insets tell you what screen real estate is available for positioning the controls in your overlay
    property var mapControl

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

    /* panel state */
    property bool panelOpen: false
    property int currentIndex: 0
    property var allPages: [
        {
            name: qsTr("Server"),
            url: "qrc:/qml/QGroundControl/AppSettings/Server.qml",
            icon: "qrc:/InstrumentValueIcons/servers.svg",
            pageVisible: function() { return true }
        },
        {
            name: qsTr("Kamikaze"),
            url: "qrc:/qml/QGroundControl/AppSettings/Kamikaze.qml",
            icon: "qrc:/InstrumentValueIcons/target.svg",
            pageVisible: function() { return true }
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
            pagesModel.append({ name: allPages[i].name, url: allPages[i].url, icon: allPages[i].icon })
        }
        if (pagesModel.count === 0) currentIndex = -1
        else if (currentIndex < 0 || currentIndex >= pagesModel.count) currentIndex = 0
    }

    Component.onCompleted: buildModel()

    Rectangle {
        id: panel
        width: parent.width
        height: Math.min(parent.height * 0.65, 900)
        x: 0
        y: panelOpen ? 0 : -height
        z: 100
        color: qgcPal.windowShade
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
                        checkable: true
                        checked: index === root.currentIndex

                        // friendly fixed button size so layout is stable
                        property real btnHeight: ScreenTools.defaultFontPixelHeight * 2.4
                        height: btnHeight
                        width: Math.max(120, implicitWidth)   // allows label to define width but keeps a minimum

                        onClicked: {
                            console.log("TAB CLICK:", index, name)
                            root.currentIndex = index
                        }

                        // content: icon + label, centered
                        contentItem: Row {
                            anchors.centerIn: parent
                            spacing: ScreenTools.defaultFontPixelWidth / 2

                            Image {
                                id: tabIcon
                                source: (typeof icon === "object" && icon && icon.source) ? icon.source : icon
                                width: ScreenTools.defaultFontPixelWidth * 1.6
                                height: ScreenTools.defaultFontPixelHeight * 1.6
                                fillMode: Image.PreserveAspectFit
                                visible: source !== undefined && source !== ""
                            }

                            Label {
                                id: tabLabel
                                text: name
                                font.pixelSize: ScreenTools.defaultFontPixelHeight
                                color: tb.checked ? qgcPal.textOnHighlight : qgcPal.text
                                // let label set implicitWidth naturally
                            }
                        }

                        // background fills the whole button (no implicit bindings to content)
                        background: Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: tb.checked ? qgcPal.buttonHighlight : "transparent"
                            border.color: tb.checked ? qgcPal.highlightColor : "transparent"
                            border.width: tb.checked ? 1 : 0
                        }

                        // subtle hover effect (QtQuick Controls standard states)
                        hoverEnabled: true
                        onPressedChanged: { /* keep default behavior */ }
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
                    asynchronous: true
                    active: pagesModel.count>0 && root.currentIndex >= 0
                    source: (pagesModel.count>0 && root.currentIndex >= 0) ? pagesModel.get(root.currentIndex).url : ""

                    onStatusChanged: {
                        console.log("Loader.status:", status, "source:", source)
                        if (status === Loader.Error) {
                            console.warn("Loader failed:", pageLoader.errorString)
                        } else if (status === Loader.Ready) {
                            console.log("Loaded item:", pageLoader.item ? pageLoader.item : "null")
                        }
                    }
                }
                Text { anchors.centerIn: parent; text: qsTr("No pages"); visible: !pageLoader.active }
            }
        }
    }
}
