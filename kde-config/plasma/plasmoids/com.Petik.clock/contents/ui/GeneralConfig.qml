import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.11
import Qt.labs.platform
import org.kde.plasma.core 2.0 as PlasmaCore

Item {
    id: configRoot

    QtObject {
        id: initialValue
        property var value
    }

    signal configurationChanged

    property alias cfg_fontSize: sizeFontSpinBox.value
    property alias cfg_dayInitial: initialValue.value
    property alias cfg_customColors: colorDialog.color

    // Función para obtener el nombre del día de la semana traducido
    function getTranslatedDayName(dayIndex) {
        var date = new Date();
        date.setDate(date.getDate() - date.getDay() + dayIndex); // Ajustar al día correcto
        return Qt.locale().standaloneDayName(date.getDay(), Locale.LongFormat);
    }

    ColorDialog {
        id: colorDialog
    }

    ColumnLayout {
        spacing: units.smallSpacing * 2

        GridLayout {
            columns: 2

            Label {
                Layout.minimumWidth: configRoot.width / 2
                text: i18n("Font Size:")
                horizontalAlignment: Text.AlignRight
            }
            SpinBox {
                id: sizeFontSpinBox
                from: 0
                to: 300
            }

            Label {
                Layout.minimumWidth: configRoot.width / 2
                text: i18n("Day initial:")
                horizontalAlignment: Text.AlignRight
            }
            ComboBox {
                id: initial
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: getTranslatedDayName(0), value: 0 }, // Domingo
                    { text: getTranslatedDayName(1), value: 1 }, // Lunes
                    { text: getTranslatedDayName(2), value: 2 }, // Martes
                    { text: getTranslatedDayName(3), value: 3 }, // Miércoles
                    { text: getTranslatedDayName(4), value: 4 }, // Jueves
                    { text: getTranslatedDayName(5), value: 5 }, // Viernes
                    { text: getTranslatedDayName(6), value: 6 }  // Sábado
                ]
                onActivated: initialValue.value = currentValue
                Component.onCompleted: currentIndex = indexOfValue(initialValue.value)
            }

            Label {
                Layout.minimumWidth: configRoot.width / 2
                text: i18n("Color:")
                horizontalAlignment: Text.AlignRight
            }
            Item {
                width: 64
                height: 24
                opacity: checkColorCustom.checked ? 1.0 : 0.2
                Rectangle {
                    width: 64
                    radius: 4
                    height: 24
                    border.color: "black"
                    opacity: 0.5
                    color: "transparent"
                    border.width: 2
                }
                Rectangle {
                    color: colorDialog.color
                    border.color: "#B3FFFFFF"
                    border.width: 1
                    width: 64
                    radius: 4
                    height: 24
                    MouseArea {
                        anchors.fill: parent
                        enabled: checkColorCustom.checked
                        onClicked: {
                            colorDialog.open()
                        }
                    }
                }
            }
        }
    }
}
