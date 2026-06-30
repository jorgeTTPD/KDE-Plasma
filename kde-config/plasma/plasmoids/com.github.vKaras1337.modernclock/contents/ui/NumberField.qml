import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

RowLayout {
    id: numberField
    property alias label: numberField_label.text;
    property alias value: numberField_spinbox.value

    Label {
        id: numberField_label
    }
    SpinBox {
        id: numberField_spinbox
        from: 1
        to: 999
    }
}

