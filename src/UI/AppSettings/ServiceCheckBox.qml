import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQml 2.15

pragma NativeMethodBehavior: AcceptThisObject

CheckBox {
    id: root

    property var rosBridge
    property string serviceStartMethod
    property string serviceStopMethod

    property int currentRequestId: -1

    // Track what state the user is trying to change to
    property bool requestedState: false
    property bool active: false
    property bool pending: false

    property var logFn
    property string logPrefix: ""

    checkable: false
    enabled: !pending
    checked: active

    onClicked: {
        if (pending) return

        // Store what state we're requesting
        requestedState = !active
        pending = true

        if (!active) {
            // Try to start the service - call method on rosBridge directly
            currentRequestId = root.rosBridge[root.serviceStartMethod]()
        } else {
            // Try to stop the service - call method on rosBridge directly
            currentRequestId = root.rosBridge[root.serviceStopMethod]()
        }
    }

    Connections {
        target: root.rosBridge

        function onServiceResult(requestId, success, message) {
            if (requestId !== root.currentRequestId)
                return

            root.pending = false

            if (success) {
                // Service call succeeded, update the state
                root.active = root.requestedState
                if (root.logFn) {
                    root.logFn(root.logPrefix + " " + (root.active ? "enabled" : "disabled"))
                }
            } else {
                // Service call failed
                const msgLower = message ? message.toLowerCase() : ""

                // Check if error indicates already in desired state
                const alreadyActive = msgLower.includes("already") && msgLower.includes("active")
                const alreadyInactive = (msgLower.includes("not") || msgLower.includes("already")) &&
                                       (msgLower.includes("active") || msgLower.includes("inactive"))

                if (alreadyActive && root.requestedState) {
                    // Already in desired state
                    root.active = true
                    if (root.logFn) {
                        root.logFn(root.logPrefix + " was already enabled")
                    }
                } else if (alreadyInactive && !root.requestedState) {
                    // Already in desired state
                    root.active = false
                    if (root.logFn) {
                        root.logFn(root.logPrefix + " was already disabled")
                    }
                } else {
                    // Genuine error, keep state and log
                    if (root.logFn) {
                        root.logFn(root.logPrefix + " error: " + message)
                    }
                }
            }
        }
    }
}
