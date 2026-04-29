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

                const isAlready =
                    msgLower.includes("already")         ||
                    msgLower.includes("not active")      ||
                    msgLower.includes("ALREADY_ACTIVE")  ||
                    msgLower.includes("ALREADY_INACTIVE")

                if (isAlready) {
                    root.active = root.requestedState // Force state to what user wanted
                    if (root.logFn) {
                        root.logFn(
                            root.logPrefix +
                            (root.active ? " was already enabled" : " was already disabled")
                        )
                    }
                } else { // Genuine error, keep state and log
                    if (root.logFn) {
                        root.logFn(root.logPrefix + " error: " + message)
                    }
                }
            }
        }
    }
}
