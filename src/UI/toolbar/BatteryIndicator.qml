import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

//-------------------------------------------------------------------------
//-- Battery Indicator (safe version)
Item {
    id:             control
    anchors.top:    parent.top
    anchors.bottom: parent.bottom
    width:          batteryIndicatorRow.width

    property bool       showIndicator:      _activeVehicle && _activeVehicle.batteries.count > 0
    property bool       waitForParameters:  true    // UI won't show until parameters are ready
    property Component  expandedPageComponent

    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property var    _batterySettings:   QGroundControl.settingsManager ? QGroundControl.settingsManager.batteryIndicatorSettings : null

    // safe indicator display raw value (fall back to 0)
    property int    _indicatorDisplayRaw: (_batterySettings && _batterySettings.valueDisplay) ? _batterySettings.valueDisplay.rawValue : 0
    property bool   _showPercentage:    _indicatorDisplayRaw === 0
    property bool   _showVoltage:       _indicatorDisplayRaw === 1
    property bool   _showBoth:          _indicatorDisplayRaw === 2

    property int    _lowestBatteryId:   -1      // -1: show all batteries, otherwise show only battery with this id
    property real   _nominalV:          0
    property int    _nominalWeightCount: 0
    property bool   _warning1warned:    false
    property bool   _warning2warned:    false

    // cached first-battery reference to avoid .get(0) evaluation hazards
    property var _battery0: (_activeVehicle && _activeVehicle.batteries.count > 0)
                            ? _activeVehicle.batteries.get(0)
                            : null

    // safe thresholds with fallbacks
    property int threshold1: (_batterySettings && _batterySettings.threshold1) ? _batterySettings.threshold1.rawValue : 20
    property int threshold2: (_batterySettings && _batterySettings.threshold2) ? _batterySettings.threshold2.rawValue : 10

    // warning thresholds
    property int warnThreshold1: (_batterySettings && _batterySettings.warnThreshold1) ? _batterySettings.warnThreshold1.rawValue : 60
    property int warnThreshold2: (_batterySettings && _batterySettings.warnThreshold2) ? _batterySettings.warnThreshold2.rawValue : 30

    //---------------------------------------------------------------------
    function _recalcLowestBatteryIdFromVoltage() {
        if (!_activeVehicle || _activeVehicle.batteries.count === 0) {
            _lowestBatteryId = -1
            return
        }

        var list = _activeVehicle.batteries
        if (list.count === 1) {
            _lowestBatteryId = list.get(0).id.rawValue
            return
        }

        var allHaveVoltage = true
        for (var i = 0; i < list.count; i++) {
            var b = list.get(i)
            if (isNaN(b.voltage.rawValue)) {
                allHaveVoltage = false
                break
            }
        }
        if (allHaveVoltage) {
            var lowest = list.get(0)
            var lowestId = lowest.id.rawValue
            for (var j = 1; j < list.count; j++) {
                var bb = list.get(j)
                if (bb.voltage.rawValue < lowest.voltage.rawValue) {
                    lowest = bb
                    lowestId = bb.id.rawValue
                }
            }
            _lowestBatteryId = lowestId
            return
        }

        _lowestBatteryId = -1
    }

    function _recalcLowestBatteryIdFromPercentage() {
        if (!_activeVehicle || _activeVehicle.batteries.count === 0) {
            _lowestBatteryId = -1
            return
        }

        var list = _activeVehicle.batteries
        if (list.count === 1) {
            _lowestBatteryId = list.get(0).id.rawValue
            return
        }

        var allHavePercentage = true
        for (var i = 0; i < list.count; i++) {
            var b = list.get(i)
            if (isNaN(b.percentRemaining.rawValue)) {
                allHavePercentage = false
                break
            }
        }
        if (allHavePercentage) {
            var lowest = list.get(0)
            var lowestId = lowest.id.rawValue
            for (var j = 1; j < list.count; j++) {
                var bb = list.get(j)
                if (bb.percentRemaining.rawValue < lowest.percentRemaining.rawValue) {
                    lowest = bb
                    lowestId = bb.id.rawValue
                }
            }
            _lowestBatteryId = lowestId
            return
        }

        _lowestBatteryId = -1
    }

    function _recalcLowestBatteryIdFromChargeState() {
        if (!_activeVehicle || _activeVehicle.batteries.count === 0) {
            _lowestBatteryId = -1
            return
        }

        var list = _activeVehicle.batteries
        if (list.count === 1) {
            _lowestBatteryId = list.get(0).id.rawValue
            return
        }

        var allHaveChargeState = true
        for (var i = 0; i < list.count; i++) {
            var b = list.get(i)
            if (b.chargeState.rawValue === MAVLink.MAV_BATTERY_CHARGE_STATE_UNDEFINED) {
                allHaveChargeState = false
                break
            }
        }
        if (allHaveChargeState) {
            var lowest = list.get(0)
            var lowestId = lowest.id.rawValue
            for (var j = 1; j < list.count; j++) {
                var bb = list.get(j)
                if (bb.chargeState.rawValue > lowest.chargeState.rawValue) {
                    lowest = bb
                    lowestId = bb.id.rawValue
                }
            }
            _lowestBatteryId = lowestId
            return
        }

        _lowestBatteryId = -1
    }

    function _recalcLowestBatteryId() {
        if (!_activeVehicle || _activeVehicle.batteries.count === 0) {
            _lowestBatteryId = -1
            return
        }

        if ((_batterySettings && _batterySettings.valueDisplay && _batterySettings.valueDisplay.rawValue === 0) || _indicatorDisplayRaw === 0) {
            _recalcLowestBatteryIdFromPercentage()
        } else if ((_batterySettings && _batterySettings.valueDisplay && _batterySettings.valueDisplay.rawValue === 1) || _indicatorDisplayRaw === 1) {
            _recalcLowestBatteryIdFromVoltage()
        } else {
            // fallback: try voltage then chargeState
            _recalcLowestBatteryIdFromVoltage()
            if (_lowestBatteryId === -1) {
                _recalcLowestBatteryIdFromChargeState()
            }
        }

        if (_lowestBatteryId === -1) {
            _recalcLowestBatteryIdFromChargeState()
        }
    }

    function _updateNominalV() {
        if (!_battery0) return

        var currentV = _battery0.voltage ? _battery0.voltage.rawValue : NaN
        if (isNaN(currentV)) return

        // exponential-like bounded averaging to avoid unbounded weight growth
        var alpha = 0.05
        if (isNaN(_nominalV) || _nominalWeightCount === 0) {
            _nominalV = currentV
            _nominalWeightCount = 1
        } else {
            _nominalV = (_nominalV * (1 - alpha)) + (currentV * alpha)
            _nominalWeightCount = Math.min(_nominalWeightCount + 1, 1000)
        }
    }

    function _checkRemainingPossiblyWarn() {
        if (!_battery0) return
        if (!_activeVehicle || !_activeVehicle.armed) return

        var percent = _battery0.percentRemaining ? _battery0.percentRemaining.rawValue : NaN
        if (isNaN(percent)) return

        // Critical first (lower threshold)
        if (percent <= warnThreshold2 && !_warning2warned) {
            QGroundControl.showMessageDialog(mainWindow,
                qsTr("Battery Warning"),
                qsTr("Battery critically low (%1%).\nLand immediately.").arg(percent.toFixed(1)),
                Dialog.Ok
            )
            _warning2warned = true
            return
        }

        // Low warning
        if (percent <= warnThreshold1 && !_warning1warned) {
            QGroundControl.showMessageDialog(mainWindow,
                qsTr("Battery Warning"),
                qsTr("Battery low (%1%).").arg(percent.toFixed(1)),
                Dialog.Ok
            )
            _warning1warned = true
        }
    }

    Component.onCompleted: {
        _recalcLowestBatteryId()
    }

    // Re-evaluate lowest battery when battery list size changes
    Connections {
        target: _activeVehicle ? _activeVehicle.batteries : null
        function onCountChanged() { _recalcLowestBatteryId() }
    }

    QGCPalette { id: qgcPal }

    RowLayout {
        id:             batteryIndicatorRow
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        spacing:        ScreenTools.defaultFontPixelWidth / 2

        Repeater {
            model: _activeVehicle ? _activeVehicle.batteries : 0

            Loader {
                Layout.fillHeight:  true
                sourceComponent:    batteryVisual
                visible:            control._lowestBatteryId === -1 ||
                                    (object && object.id && object.id.rawValue === control._lowestBatteryId) ||
                                    !control._batterySettings || !control._batterySettings.consolidateMultipleBatteries || !control._batterySettings.consolidateMultipleBatteries.rawValue

                property var battery: object
            }
        }
    }

    MouseArea {
        anchors.fill:   parent
        onClicked:      if (batteryPopup) mainWindow.showIndicatorDrawer(batteryPopup, control)
    }

    Component {
        id: batteryPopup

        ToolIndicatorPage {
            showExpand:         expandedComponent ? true : false
            waitForParameters:  control.waitForParameters
            contentComponent:   batteryContentComponent
            expandedComponent:  batteryExpandedComponent
        }
    }

    Component {
        id: batteryVisual

        Row {
            Layout.fillHeight:  true
            spacing:            ScreenTools.defaultFontPixelWidth / 4

            function getBatteryColor() {
                if (!battery) return qgcPal.text
                switch (battery.chargeState.rawValue) {
                    case MAVLink.MAV_BATTERY_CHARGE_STATE_OK:
                        if (!isNaN(battery.percentRemaining.rawValue)) {
                            if (battery.percentRemaining.rawValue > threshold1) {
                                return qgcPal.colorGreen
                            } else if (battery.percentRemaining.rawValue > threshold2) {
                                return qgcPal.colorYellowGreen
                            } else {
                                return qgcPal.colorYellow
                            }
                        } else {
                            return qgcPal.text
                        }
                    case MAVLink.MAV_BATTERY_CHARGE_STATE_LOW:
                        return qgcPal.colorOrange
                    case MAVLink.MAV_BATTERY_CHARGE_STATE_CRITICAL:
                    case MAVLink.MAV_BATTERY_CHARGE_STATE_EMERGENCY:
                    case MAVLink.MAV_BATTERY_CHARGE_STATE_FAILED:
                    case MAVLink.MAV_BATTERY_CHARGE_STATE_UNHEALTHY:
                        return qgcPal.colorRed
                    default:
                        return qgcPal.text
                }
            }

            function getBatterySvgSource() {
                if (!battery) return "/qmlimages/Battery.svg"
                switch (battery.chargeState.rawValue) {
                    case MAVLink.MAV_BATTERY_CHARGE_STATE_OK:
                        if (!isNaN(battery.percentRemaining.rawValue)) {
                            if (battery.percentRemaining.rawValue > threshold1) {
                                return "/qmlimages/BatteryGreen.svg"
                            } else if (battery.percentRemaining.rawValue > threshold2) {
                                return "/qmlimages/BatteryYellowGreen.svg"
                            } else {
                                return "/qmlimages/BatteryYellow.svg"
                            }
                        }
                        break
                    case MAVLink.MAV_BATTERY_CHARGE_STATE_LOW:
                        return "/qmlimages/BatteryOrange.svg"
                    case MAVLink.MAV_BATTERY_CHARGE_STATE_CRITICAL:
                        return "/qmlimages/BatteryCritical.svg"
                    case MAVLink.MAV_BATTERY_CHARGE_STATE_EMERGENCY:
                    case MAVLink.MAV_BATTERY_CHARGE_STATE_FAILED:
                    case MAVLink.MAV_BATTERY_CHARGE_STATE_UNHEALTHY:
                        return "/qmlimages/BatteryEMERGENCY.svg"
                    default:
                        return "/qmlimages/Battery.svg"
                }
            }

            function getBatteryPercentageText() {
                if (!battery) return qsTr("n/a")
                if (!isNaN(battery.percentRemaining.rawValue)) {
                    if (battery.percentRemaining.rawValue > 98.9) {
                        return qsTr("100%")
                    } else {
                        return battery.percentRemaining.valueString + battery.percentRemaining.units
                    }
                } else if (!isNaN(battery.voltage.rawValue)) {
                    return battery.voltage.valueString + battery.voltage.units
                } else if (battery.chargeState.rawValue !== MAVLink.MAV_BATTERY_CHARGE_STATE_UNDEFINED) {
                    return battery.chargeState.enumStringValue
                }
                return qsTr("n/a")
            }

            function getBatteryVoltageText() {
                if (!battery) return qsTr("n/a")
                if (!isNaN(battery.voltage.rawValue)) {
                    return battery.voltage.valueString + battery.voltage.units
                } else if (battery.chargeState.rawValue !== MAVLink.MAV_BATTERY_CHARGE_STATE_UNDEFINED) {
                    return battery.chargeState.enumStringValue
                }
                return qsTr("n/a")
            }

            Timer {
                id:         debounceRecalcTimer
                interval:   50
                running:    false
                repeat:     false
                onTriggered: {
                    control._recalcLowestBatteryId()
                }
            }

            Connections {
                target: battery && battery.percentRemaining ? battery.percentRemaining : null
                function onRawValueChanged() {
                    debounceRecalcTimer.restart()
                }
            }
            Connections {
                target: battery && battery.voltage ? battery.voltage : null
                function onRawValueChanged() {
                    debounceRecalcTimer.restart()
                }
            }
            Connections {
                target: battery && battery.chargeState ? battery.chargeState : null
                function onRawValueChanged() {
                    debounceRecalcTimer.restart()
                }
            }

            QGCColoredImage {
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                width:              height
                sourceSize.width:   width
                source:             getBatterySvgSource()
                fillMode:           Image.PreserveAspectFit
                color:              getBatteryColor()
            }

            ColumnLayout {
                id:                     batteryInfoColumn
                anchors.top:            parent.top
                anchors.bottom:         parent.bottom
                spacing:                0

                QGCLabel {
                    Layout.alignment:       Qt.AlignHCenter
                    verticalAlignment:      Text.AlignVCenter
                    color:                  qgcPal.windowTransparentText
                    text:                   getBatteryPercentageText()
                    font.pointSize:         _showBoth ? ScreenTools.smallFontPointSize : ScreenTools.defaultFontPointSize
                    visible:                _showBoth || _showPercentage
                }

                QGCLabel {
                    Layout.alignment:       Qt.AlignHCenter
                    font.pointSize:         _showBoth ? ScreenTools.smallFontPointSize : ScreenTools.defaultFontPointSize
                    color:                  qgcPal.windowTransparentText
                    text:                   getBatteryVoltageText()
                    visible:                _showBoth || _showVoltage
                }

                QGCLabel {
                    Layout.alignment:       Qt.AlignHCenter
                    font.pointSize:         _showBoth ? ScreenTools.smallFontPointSize : ScreenTools.defaultFontPointSize
                    color:                  qgcPal.windowTransparentText
                    text: qsTr("Nominal: ") + (isNaN(_nominalV) ? qsTr("n/a") : _nominalV.toFixed(2) + " V")
                    visible: !isNaN(_nominalV)
                }
            }
        }
    }

    Component {
        id: batteryContentComponent

        ColumnLayout {
            spacing: ScreenTools.defaultFontPixelHeight / 2

            Component {
                id: batteryValuesAvailableComponent

                QtObject {
                    property bool functionAvailable:         battery && battery.function ? battery.function.rawValue !== MAVLink.MAV_BATTERY_FUNCTION_UNKNOWN : false
                    property bool showFunction:              functionAvailable && battery.function.rawValue != MAVLink.MAV_BATTERY_FUNCTION_ALL
                    property bool temperatureAvailable:      battery && battery.temperature ? !isNaN(battery.temperature.rawValue) : false
                    property bool currentAvailable:          battery && battery.current ? !isNaN(battery.current.rawValue) : false
                    property bool mahConsumedAvailable:      battery && battery.mahConsumed ? !isNaN(battery.mahConsumed.rawValue) : false
                    property bool timeRemainingAvailable:    battery && battery.timeRemaining ? !isNaN(battery.timeRemaining.rawValue) : false
                    property bool percentRemainingAvailable: battery && battery.percentRemaining ? !isNaN(battery.percentRemaining.rawValue) : false
                    property bool chargeStateAvailable:      battery && battery.chargeState ? battery.chargeState.rawValue !== MAVLink.MAV_BATTERY_CHARGE_STATE_UNDEFINED : false
                }
            }

            Repeater {
                model: _activeVehicle ? _activeVehicle.batteries : 0

                SettingsGroupLayout {
                    heading:        qsTr("Battery %1").arg(_activeVehicle && _activeVehicle.batteries ? (_activeVehicle.batteries.length === 1 ? qsTr("Status") : object.id.rawValue) : qsTr(""))
                    contentSpacing: 0
                    showDividers:   false

                    property var batteryValuesAvailable: batteryValuesAvailableLoader.item

                    Loader {
                        id:                 batteryValuesAvailableLoader
                        sourceComponent:    batteryValuesAvailableComponent

                        property var battery: object
                    }

                    LabelledLabel {
                        label:  qsTr("Charge State")
                        labelText:  object.chargeState ? object.chargeState.enumStringValue : ""
                        visible:    batteryValuesAvailable.chargeStateAvailable
                    }

                    LabelledLabel {
                        label:      qsTr("Remaining")
                        labelText:  object.timeRemainingStr ? object.timeRemainingStr.value : ""
                        visible:    batteryValuesAvailable.timeRemainingAvailable
                    }

                    LabelledLabel {
                        label:      qsTr("Remaining")
                        labelText:  object.percentRemaining ? (object.percentRemaining.valueString + " " + object.percentRemaining.units) : ""
                        visible:    batteryValuesAvailable.percentRemainingAvailable
                    }

                    LabelledLabel {
                        label:      qsTr("Voltage")
                        labelText:  object.voltage ? (object.voltage.valueString + " " + object.voltage.units) : ""
                    }

                    LabelledLabel {
                        label:      qsTr("Consumed")
                        labelText:  object.mahConsumed ? (object.mahConsumed.valueString + " " + object.mahConsumed.units) : ""
                        visible:    batteryValuesAvailable.mahConsumedAvailable
                    }

                    LabelledLabel {
                        label:      qsTr("Temperature")
                        labelText:  object.temperature ? (object.temperature.valueString + " " + object.temperature.units) : ""
                        visible:    batteryValuesAvailable.temperatureAvailable
                    }

                    LabelledLabel {
                        label:      qsTr("Function")
                        labelText:  object.function ? object.function.enumStringValue : ""
                        visible:    batteryValuesAvailable.showFunction
                    }
                }
            }
        }
    }

    Component {
        id: batteryExpandedComponent

        ColumnLayout {
            spacing: ScreenTools.defaultFontPixelHeight / 2

            property real batteryIconHeight: ScreenTools.defaultFontPixelWidth * 3

            FactPanelController { id: controller }

            SettingsGroupLayout {
                heading:            qsTr("Battery Display")
                Layout.fillWidth:   true

                FactCheckBoxSlider {
                    Layout.fillWidth:   true
                    fact:               _batterySettings ? _batterySettings.consolidateMultipleBatteries : null
                    text:               qsTr("Only show battery with lowest charge")
                    visible:            fact ? fact.visible : false
                }

                LabelledFactComboBox {
                    label:      qsTr("Value")
                    fact:       _batterySettings ? _batterySettings.valueDisplay : null
                    visible:    fact ? fact.visible : false
                }

                ColumnLayout {
                    RowLayout {
                        Layout.fillWidth: true
                        QGCLabel {
                            text: qsTr("Warn Threshold 1 (higher)")
                            verticalAlignment: Text.AlignVCenter
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 25
                            wrapMode: Text.NoWrap
                        }

                        FactTextField {
                            Layout.fillWidth: true
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth
                            fact: _batterySettings ? _batterySettings.warnThreshold1 : null
                            onEditingFinished: {
                                _warning1warned = false
                                if (fact) fact.value = parseInt(text)
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        QGCLabel {
                            text: qsTr("Warn Threshold 2 (lower)")
                            verticalAlignment: Text.AlignVCenter
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 25
                            wrapMode: Text.NoWrap
                        }

                        FactTextField {
                            Layout.fillWidth: true
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth
                            fact: _batterySettings ? _batterySettings.warnThreshold2 : null
                            onEditingFinished: {
                                _warning2warned = false
                                if (fact) fact.value = parseInt(text)
                            }
                        }
                    }
                }

                ColumnLayout {
                    QGCLabel { text: qsTr("Coloring") }

                    RowLayout {
                        spacing: ScreenTools.defaultFontPixelWidth

                        // Battery 100%
                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 0.05  // Tighter spacing for icon and label
                            QGCColoredImage {
                                source: "/qmlimages/BatteryGreen.svg"
                                width: height
                                height: batteryIconHeight
                                fillMode: Image.PreserveAspectFit
                                color: qgcPal.colorGreen
                            }
                            QGCLabel { text: qsTr("100%") }
                        }

                        // Threshold 1
                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 0.05  // Tighter spacing for icon and field
                            QGCColoredImage {
                                source: "/qmlimages/BatteryYellowGreen.svg"
                                width: height
                                height: batteryIconHeight
                                fillMode: Image.PreserveAspectFit
                                color: qgcPal.colorYellowGreen
                            }
                            FactTextField {
                                id: threshold1Field
                                fact: _batterySettings ? _batterySettings.threshold1 : null
                                implicitWidth: ScreenTools.defaultFontPixelWidth * 6
                                height: ScreenTools.defaultFontPixelHeight * 1.5
                                enabled: fact ? fact.visible : false
                                onEditingFinished: {
                                    if (fact) _batterySettings.setThreshold1(parseInt(text));
                                }
                            }
                        }

                        // Threshold 2
                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 0.05  // Tighter spacing for icon and field
                            QGCColoredImage {
                                source: "/qmlimages/BatteryYellow.svg"
                                width: height
                                height: batteryIconHeight
                                fillMode: Image.PreserveAspectFit
                                color: qgcPal.colorYellow
                            }
                            FactTextField {
                                fact: _batterySettings ? _batterySettings.threshold2 : null
                                implicitWidth: ScreenTools.defaultFontPixelWidth * 6
                                height: ScreenTools.defaultFontPixelHeight * 1.5
                                enabled: fact ? fact.visible : false
                                onEditingFinished: {
                                    if (fact) _batterySettings.setThreshold2(parseInt(text));
                                }
                            }
                        }

                        // Low state
                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 0.05  // Tighter spacing for icon and label
                            QGCColoredImage {
                                source: "/qmlimages/BatteryOrange.svg"
                                width: height
                                height: batteryIconHeight
                                fillMode: Image.PreserveAspectFit
                                color: qgcPal.colorOrange
                            }
                            QGCLabel { text: qsTr("Low") }
                        }

                        // Critical state
                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 0.05  // Tighter spacing for icon and label
                            QGCColoredImage {
                                source: "/qmlimages/BatteryCritical.svg"
                                width: height
                                height: batteryIconHeight
                                fillMode: Image.PreserveAspectFit
                                color: qgcPal.colorRed
                            }
                            QGCLabel { text: qsTr("Critical") }
                        }
                    }
                }
            }

            Loader {
                Layout.fillWidth:   true
                source:             _activeVehicle ? _activeVehicle.expandedToolbarIndicatorSource("Battery") : ""
            }

            SettingsGroupLayout {
                visible: _activeVehicle && _activeVehicle.autopilotPlugin && _activeVehicle.autopilotPlugin.knownVehicleComponentAvailable(AutoPilotPlugin.KnownPowerVehicleComponent) &&
                            QGroundControl.corePlugin.showAdvancedUI

                LabelledButton {
                    label:      qsTr("Vehicle Power")
                    buttonText: qsTr("Configure")

                    onClicked: {
                        if (mainWindow) {
                            mainWindow.showKnownVehicleComponentConfigPage(AutoPilotPlugin.KnownPowerVehicleComponent)
                            mainWindow.closeIndicatorDrawer()
                        }
                    }
                }
            }
        }
    }

    // safely watch underlying battery telemetry
    Connections {
        target: _battery0 ? _battery0.voltage : null
        function onRawValueChanged() {
            control._updateNominalV()
            control._checkRemainingPossiblyWarn()
        }
    }

    Connections {
        target: _activeVehicle
        function onArmedChanged() {
            if (!_activeVehicle || !_activeVehicle.armed) {
                _warning1warned = false
                _warning2warned = false
            }
        }
    }
}
