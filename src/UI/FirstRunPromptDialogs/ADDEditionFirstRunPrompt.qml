import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

FirstRunPrompt {
    title:      qsTr("QGC ADD Edition")
    promptId:   QGroundControl.corePlugin.ADDEditionFirstRunPromptId

    ColumnLayout {
        Layout.fillWidth: true
        spacing: ScreenTools.defaultFontPixelHeight

        QGCLabel {
            text: qsTr("<for future modifications to UI, may put user needed info here>")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
