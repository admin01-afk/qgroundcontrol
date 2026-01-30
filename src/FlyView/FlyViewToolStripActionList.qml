import QtQml.Models

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Viewer3D

ToolStripActionList {
    id: _root
    signal displayPreFlightChecklist

    // Helper objects for building individual action buttons
    property var _guidedController: globals.guidedControllerFlyView

    property var _additionalActions: FlyViewAdditionalActionsList {
        guidedController: _guidedController
    }

    property var _mavlinkActions: MavlinkActionManager {
        actionFileNameFact: QGroundControl.settingsManager.mavlinkActionsSettings.flyViewActionsFile

        property bool anyActionAvailable: QGroundControl.multiVehicleManager.activeVehicle && actions.count > 0
    }

    property var _customActions: FlyViewAdditionalCustomActionsList {
        guidedController: _guidedController
    }

    model: [
        Viewer3DShowAction { },
        PreFlightCheckListShowAction { onTriggered: displayPreFlightChecklist() },
        GuidedActionTakeoff { },
        GuidedActionLand { },
        GuidedActionRTL { },
        GuidedActionPause { },

        // Expand predefined guided additional actions (one ToolStripAction per entry)
        ToolStripAction {
            visible: _additionalActions.model[0].visible
            text: _additionalActions.model[0].title
            onTriggered: {
                _guidedController.closeAll()
                _guidedController.confirmAction(_additionalActions.model[0].action)
            }
        },
        ToolStripAction {
            visible: _additionalActions.model[1].visible
            text: _additionalActions.model[1].title
            onTriggered: {
                _guidedController.closeAll()
                _guidedController.confirmAction(_additionalActions.model[1].action)
            }
        },
        ToolStripAction {
            visible: _additionalActions.model[2].visible
            text: _additionalActions.model[2].title
            onTriggered: {
                _guidedController.closeAll()
                _guidedController.confirmAction(_additionalActions.model[2].action)
            }
        },
        ToolStripAction {
            visible: _additionalActions.model[3].visible
            text: _additionalActions.model[3].title
            onTriggered: {
                _guidedController.closeAll()
                _guidedController.confirmAction(_additionalActions.model[3].action)
            }
        },
        ToolStripAction {
            visible: _additionalActions.model[4].visible
            text: _additionalActions.model[4].title
            onTriggered: {
                _guidedController.closeAll()
                _guidedController.confirmAction(_additionalActions.model[4].action)
            }
        },
        ToolStripAction {
            visible: _additionalActions.model[5].visible
            text: _additionalActions.model[5].title
            onTriggered: {
                _guidedController.closeAll()
                _guidedController.confirmAction(_additionalActions.model[5].action)
            }
        },

        // Custom build actions (a few slots, visible only when entries exist)
        ToolStripAction {
            visible: _customActions.model.length > 0 && _customActions.model[0].visible
            text: _customActions.model.length > 0 ? _customActions.model[0].title : ""
            onTriggered: {
                _guidedController.closeAll()
                _guidedController.confirmAction(_customActions.model[0].action)
            }
        },
        ToolStripAction {
            visible: _customActions.model.length > 1 && _customActions.model[1].visible
            text: _customActions.model.length > 1 ? _customActions.model[1].title : ""
            onTriggered: {
                _guidedController.closeAll()
                _guidedController.confirmAction(_customActions.model[1].action)
            }
        },

        // User-defined mavlink actions: create a fixed number of slots bound to the actions list
        ToolStripAction {
            property var _act: (_mavlinkActions.actions && _mavlinkActions.actions.count > 0) ? _mavlinkActions.actions.get(0) : undefined
            visible: _act !== undefined && QGroundControl.multiVehicleManager.activeVehicle
            text: _act ? _act.label : ""
            onTriggered: { if (_act) { _act.sendTo(QGroundControl.multiVehicleManager.activeVehicle) } }
        },
        ToolStripAction {
            property var _act: (_mavlinkActions.actions && _mavlinkActions.actions.count > 1) ? _mavlinkActions.actions.get(1) : undefined
            visible: _act !== undefined && QGroundControl.multiVehicleManager.activeVehicle
            text: _act ? _act.label : ""
            onTriggered: { if (_act) { _act.sendTo(QGroundControl.multiVehicleManager.activeVehicle) } }
        },
        ToolStripAction {
            property var _act: (_mavlinkActions.actions && _mavlinkActions.actions.count > 2) ? _mavlinkActions.actions.get(2) : undefined
            visible: _act !== undefined && QGroundControl.multiVehicleManager.activeVehicle
            text: _act ? _act.label : ""
            onTriggered: { if (_act) { _act.sendTo(QGroundControl.multiVehicleManager.activeVehicle) } }
        },
        ToolStripAction {
            property var _act: (_mavlinkActions.actions && _mavlinkActions.actions.count > 3) ? _mavlinkActions.actions.get(3) : undefined
            visible: _act !== undefined && QGroundControl.multiVehicleManager.activeVehicle
            text: _act ? _act.label : ""
            onTriggered: { if (_act) { _act.sendTo(QGroundControl.multiVehicleManager.activeVehicle) } }
        },

        FlyViewGripperButton { }
    ]
}
