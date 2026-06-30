import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQControls

RowLayout {
    id: root
    property var color;

    Label {
        text: i18n("Font Color")
    }             
    KQControls.ColorButton {
      id: colorbutton
      color: root.color
      showAlphaChannel: false

      onAccepted: {
        root.color = color
      }
    }
}

