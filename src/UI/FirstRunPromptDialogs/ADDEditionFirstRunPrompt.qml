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
            text: qsTr(
`P: panel toggle
1-4: change tab in panel

Space: camera feed toggle
Shift+Space: maximize/minimize image`
            )
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
