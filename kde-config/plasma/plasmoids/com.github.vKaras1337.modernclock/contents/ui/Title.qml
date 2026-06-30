import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.extras as PlasmaExtras

ColumnLayout {
    id: mainGroup
    property alias title: groupLabel.text 

    Item {
        height: 10
    }
    PlasmaExtras.Heading {
        id: groupLabel
    }
}
