import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

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
        sequence: "Shift+Space"
        context: Qt.ApplicationShortcut

        onActivated: {
            if (Qt.focusItem && Qt.focusItem.cursorPosition !== undefined)
                return
            var wasMaximized = root.imagePanelMaximized
            imagePanel.toggleMaximize()
            if (!wasMaximized) {
                root.imagePanelOpen = true
            }
        }
    }
    Shortcut {
        sequence: "Space"
        context: Qt.ApplicationShortcut

        onActivated: {
            if (Qt.focusItem && Qt.focusItem.cursorPosition !== undefined)
                return
            imagePanel.toggleCollapse()
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

    Item {
        id: imagePanel
        property bool debug: false
        property real headerH: ScreenTools.defaultFontPixelHeight * 2.2
        property real minContentW: 320
        property real minContentH: minContentW * ratio

        // This is the actual visible image area size
        property real contentW: 320
        property real contentH: minContentW
        property real ratio: (rosImage.sourceSize.width == 0) ? 1 : rosImage.sourceSize.height / rosImage.sourceSize.width


        // Save/restore the content size, not the outer panel size
        property bool savedOpen: true
        property real savedX: 0
        property real savedY: 0
        property real savedContentW: 0
        property real savedContentH: 0

        function syncImageMetrics() {
            if (rosImage.sourceSize.width > 0 && rosImage.sourceSize.height > 0) {
                ratio = rosImage.sourceSize.height / rosImage.sourceSize.width
                contentH = contentW * ratio
            }
        }
        function updatePanelGeometry() {
            if (!parent) {
                return
            }

            if (root.imagePanelMaximized) {
                x = 0
                y = 0
                width = parent.width
                //height = parent.height
            } else {
                width = contentW
                //height = headerH + contentH
                y = root.imagePanelOpen ? parent.height - height : parent.height - headerH
            }
        }
        function toggleMaximize() {
            if (!parent) { return }

            if (!root.imagePanelMaximized) {
                // Entering maximize mode - save current state
                savedX = x
                // Only save Y if panel is OPEN (valid floating position)
                if (root.imagePanelOpen) {
                    savedY = y
                }
                savedOpen = root.imagePanelOpen
                savedContentW = contentW
                savedContentH = contentH
                root.imagePanelMaximized = true
                root.imagePanelOpen = true
                updatePanelGeometry()
            } else {
                // Exiting maximize mode - restore previous state
                root.imagePanelMaximized = false

                if (savedContentW > 0 && savedContentH > 0) {
                    contentW = savedContentW
                    contentH = savedContentH
                }

                x = savedX
                root.imagePanelOpen = savedOpen

                if (savedOpen) {
                    y = savedY              // restore floating position
                } else {
                    y = parent.height - headerH   // restore collapsed position
                }
            }
        }
        function toggleCollapse(){
            // Save y only when collapsing from expanded non-maximized state
            if (root.imagePanelOpen && !root.imagePanelMaximized) {
                savedY = y
            }

            root.imagePanelOpen = !root.imagePanelOpen

            if (root.imagePanelMaximized) {
                // Maximized state
                y = root.imagePanelOpen ? 0 : parent.height - headerH
            } else {
                // Non-maximized state
                if (root.imagePanelOpen) {
                    // Expanding - restore saved y
                    y = savedY
                } else {
                    // Collapsing - move to header at bottom
                    y = parent.height - headerH
                }
            }
        }
        function updateY() {
            if (!parent) return

            if (root.imagePanelMaximized) {
                y = 0
            } else if (root.imagePanelOpen) {
                y = parent.height - height
            } else {
                y = parent.height - headerH
            }
        }
        property string debugText: {
            const w = rosImage.sourceSize.width
            const h = rosImage.sourceSize.height
            const r = imagePanel.ratio.toFixed(3)
            const cw = imagePanel.contentW.toFixed(0)
            const ch = imagePanel.contentH.toFixed(0)

            if (w === 0 || h === 0) {
                if(debug){
                    return qsTr(`No image | r=${r} W=${cw} H=${ch}`)
                }else{
                    return qsTr("No image")
                }
            }
            if(debug){
                return qsTr(`Live Feed ${w}x${h} | r=${r} W=${cw} H=${ch}`)
            }else{
                return qsTr(`Live Feed ${w}x${h}`)
            }
        }

        Component.onCompleted: {
            RosBridgeNode.subscribeImageTopic("/plane1/image_processed")
            rosImage.source = "image://ros/plane1/image_processed?" + Math.random()

            if (rosImage.implicitWidth > 0 && rosImage.implicitHeight > 0) {
                contentW = Math.min(rosImage.implicitWidth, parent.width * 0.4)
                contentH = contentW * (rosImage.implicitHeight / rosImage.implicitWidth)
            }

            updatePanelGeometry()
        }

        Connections {
            target: RosBridgeNode
            function onImageRevisionChanged() {
                rosImage.source = "image://ros/plane1/image_processed?" + Math.random()
            }
        }

        width: root.imagePanelMaximized ? parent.width : contentW
        height: root.imagePanelMaximized ? parent.height : headerH + contentH
        x: 0
        y: parent.height - headerH
        z: 50

        Behavior on x { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 50 } }
        Behavior on height { NumberAnimation { duration: 50 } }

        // Background with shadow effect
        RectangularShadow {
            id: panelShadow
            anchors.fill: panelBackground
            visible: !imagePanel.maximized
            radius: panelBackground.radius
            blur: 8
            spread: 0
            color: Qt.rgba(0, 0, 0, 0.4)
            offset.x: 0
            offset.y: 2
        }

        Rectangle {
            id: panelBackground
            anchors.fill: parent
            color: qgcPal.windowShadeDark
            radius: root.imagePanelMaximized ? 0 : 8
            border.color: qgcPal.buttonBorder
            border.width: 1
            opacity: 0.95
        }

        // Header with gradient and controls
        Rectangle {
            id: header
            x: 0
            y: 0
            width: parent.width
            height: imagePanel.headerH
            color: qgcPal.buttonHighlight
            radius: root.imagePanelMaximized ? 0 : 8
            z: 10

            // Gradient overlay for depth
            Rectangle {
                anchors.fill: parent
                color: qgcPal.text
                opacity: 0.08
                radius: root.imagePanelMaximized ? 0 : 8
            }

            // Drag handle (title area)
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.OpenHandCursor
                drag.target: root.imagePanelOpen ? imagePanel : undefined
                drag.axis: Drag.XAndYAxis
                drag.minimumX: 0
                drag.minimumY: 0
                drag.maximumX: imagePanel.parent ? Math.max(0, imagePanel.parent.width - imagePanel.width) : 0
                drag.maximumY: imagePanel.parent ? Math.max(0, imagePanel.parent.height - imagePanel.height) : 0

                onClicked: {
                    cursorShape = Qt.OpenHandCursor
                }

                onDoubleClicked: {
                    imagePanel.toggleMaximize()
                    root.imagePanelOpen = true
                }

                onPressed: cursorShape = Qt.ClosedHandCursor
                onReleased: cursorShape = Qt.OpenHandCursor

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: imagePanel.debugText
                    color: rosImage.sourceSize.width === 0 ? qgcPal.colorRed : qgcPal.text
                    font.bold: true
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.9
                }
            }

            // Control buttons (right side)
            RowLayout {
                anchors.right: parent.right
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.5
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                // Minimize/Maximize button
                Button {
                    id: maximizeBtn
                    focusPolicy: Qt.NoFocus
                    text: root.imagePanelMaximized ? "⊙" : "▢"
                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.8
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8

                    ToolTip.visible: hovered
                    ToolTip.text: imagePanel.maximized ? qsTr("Restore") : qsTr("Maximize")

                    onClicked: {
                        var wasMaximized = root.imagePanelMaximized
                        imagePanel.toggleMaximize()
                        // Only force open when entering maximize mode
                        if (!wasMaximized) {
                            root.imagePanelOpen = true
                        }
                    }

                    background: Rectangle {
                        color: maximizeBtn.hovered ? Qt.lighter(qgcPal.buttonHighlight, 1.2) : "transparent"
                        radius: 4
                        border.color: maximizeBtn.hovered ? qgcPal.text : "transparent"
                        border.width: 1
                    }

                    contentItem: Text {
                        text: parent.text
                        color: qgcPal.text
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.2
                        font.bold: true
                    }
                }

                // Toggle open/close button
                Button {
                    id: toggleButton
                    focusPolicy: Qt.NoFocus
                    text: root.imagePanelOpen ? "▼" : "▲"
                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.8
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8

                    ToolTip.visible: hovered
                    ToolTip.text: root.imagePanelOpen ? qsTr("Collapse") : qsTr("Expand")

                    onClicked: {
                        imagePanel.toggleCollapse()
                    }

                    background: Rectangle {
                        color: toggleButton.hovered ? Qt.lighter(qgcPal.buttonHighlight, 1.2) : "transparent"
                        radius: 4
                        border.color: toggleButton.hovered ? qgcPal.text : "transparent"
                        border.width: 1
                    }

                    contentItem: Text {
                        text: parent.text
                        color: qgcPal.text
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.1
                    }
                }
            }
        }

        // Image display area
        Item {
            id: imageArea
            x: 0
            y: header.height
            width: parent.width
            height: parent.height - header.height
            clip: true

            Image {
                id: rosImage
                anchors.fill: parent
                source: "image://ros/plane1/image_processed"
                fillMode: Image.PreserveAspectFit
                cache: false
                opacity: 1.0
                onSourceSizeChanged: {
                    if (rosImage.sourceSize.width > 0 && rosImage.sourceSize.height > 0) {
                        var r = rosImage.sourceSize.height / rosImage.sourceSize.width
                        imagePanel.contentH = imagePanel.contentW * r
                        imagePanel.updatePanelGeometry()
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: qsTr("No image ")
                color: qgcPal.text
                visible: rosImage.status === Image.Null || rosImage.status === Image.Error
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.2
            }
        }

        // Resize handle - FIXED: Now positioned outside imageArea to avoid clipping
        Rectangle {
            id: resizeHandle
            width: 24
            height: 24
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -1
            anchors.bottomMargin: -1
            color: Qt.rgba(0, 0, 0, 0.3)
            border.color: qgcPal.buttonBorder
            border.width: 1
            radius: 4
            visible: !imagePanel.maximized
            z: 11

            // Diagonal lines indicator
            Canvas {
                anchors.fill: parent
                anchors.margins: 2
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = qgcPal.text
                    ctx.lineWidth = 1.5
                    ctx.lineCap = "round"

                    // Three diagonal lines for resize indicator
                    for (var i = 0; i < 3; i++) {
                        ctx.beginPath()
                        ctx.moveTo(width - 4 - i * 4, height - 2)
                        ctx.lineTo(width - 2, height - 4 - i * 4)
                        ctx.stroke()
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.SizeFDiagCursor
                hoverEnabled: true
                enabled: !imagePanel.maximized

                property real startMouseX: 0
                property real startMouseY: 0
                property real startContentW: 0
                property real startContentH: 0
                property bool isDragging: false

                onEntered: {
                    resizeHandle.color = Qt.rgba(0.3, 0.5, 0.8, 0.5)
                    resizeHandle.border.width = 2
                }

                onExited: {
                    if (!isDragging) {
                        resizeHandle.color = Qt.rgba(0, 0, 0, 0.3)
                        resizeHandle.border.width = 1
                    }
                }

                onPressed: {
                    startMouseX = mouse.x
                    startMouseY = mouse.y
                    startContentW = imagePanel.contentW
                    startContentH = imagePanel.contentH
                    isDragging = true
                    resizeHandle.color = Qt.rgba(0.5, 0.7, 1, 0.4)
                }

                onPositionChanged: {
                    if (!isDragging || imagePanel.maximized)
                        return

                    var dx = mouse.x - startMouseX
                    var dy = mouse.y - startMouseY
                    var delta = dx + dy

                    var newW = Math.max(imagePanel.minContentW, startContentW + delta)


                    imagePanel.contentW = newW
                    imagePanel.contentH = newW * imagePanel.ratio
                }

                onReleased: {
                    isDragging = false
                    resizeHandle.color = Qt.rgba(0, 0, 0, 0.3)
                    resizeHandle.border.width = 1
                }
            }
        }
    }
}
