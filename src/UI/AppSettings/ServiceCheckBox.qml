import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQml 2.15

CheckBox {
    id: root

    property var rosBridge
    property var serviceStartFn
    property var serviceStopFn

    property int currentRequestId: -1

    property bool active: false
    property bool pending: false

    property var logFn
    property string logPrefix: ""

    checkable: false
    enabled: !pending
    checked: active

    onClicked: {
        if (pending) return
        pending = true

        if (!active) {
            currentRequestId = serviceStartFn()
        } else {
            currentRequestId = serviceStopFn()
        }
    }

    Connections {
        target: root.rosBridge

        function onServiceResult(requestId, success, message) {
            if (requestId !== root.currentRequestId)
                return

            root.pending = false

            if (success) {
                root.active = !root.active
            }

            if (root.logFn) {
                root.logFn(
                    success
                    ? root.logPrefix + " " + (root.active ? "enabled" : "disabled")
                    : root.logPrefix + " failed: " + message
                )
            }
        }
    }
}