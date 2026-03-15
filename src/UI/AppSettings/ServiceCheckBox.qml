import QtQuick 2.15
import QtQuick.Controls 2.15

CheckBox {
    id: root
    property var rosBridge
    property string serviceStart
    property string serviceStop
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
            rosBridge.callService(serviceStart)
        } else {
            rosBridge.callService(serviceStop)
        }
    }

    Connections {
        target: root.rosBridge
        function onServiceResult(serviceName, success, message) {
            if (serviceName === root.serviceStart) {
                root.pending = false
                root.active = success
                if (root.logFn) root.logFn(success ? root.logPrefix + " enabled" : root.logPrefix + " enable failed: " + message)
            } else if (serviceName === root.serviceStop) {
                root.pending = false
                root.active = !success
                if (root.logFn) root.logFn(success ? root.logPrefix + " enabled" : root.logPrefix + " enable failed: " + message)
            }
        }
    }
}
