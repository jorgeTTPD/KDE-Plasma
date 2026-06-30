import QtQuick
import QtQuick.Layouts 1.2
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid 2.0
import Qt5Compat.GraphicalEffects

PlasmoidItem {
    id: root

    property int startDay: plasmoid.configuration.dayInitial
    property var fSize: plasmoid.configuration.fontSize
    property var sizeBunble: fSize*1.3
    property string generalColor: Plasmoid.configuration.customColors

    property var days: []

    property date currentDateTime: new Date()

    readonly property int currentDayOfWeek: currentDateTime.getDay()

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: "NoBackground"

    function getRemainingMilliseconds() {
        var endOfDay = new Date(currentDateTime);
        endOfDay.setHours(23, 59, 59, 999);

        var remainingMilliseconds = endOfDay.getTime() - currentDateTime.getTime();
        return remainingMilliseconds;
    }

    Timer {
        id: timer
        interval: 86400000
        running: false
        repeat: true
        onTriggered: {
            currentDateTime = new Date()
            interval = 86400000
        }
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: fSize/2

        Repeater {
            model: 7
            delegate: Item {
                width: sizeBunble
                height: sizeBunble

                Rectangle {
                    id: circle
                    anchors.fill:  parent
                    radius: height/2
                    color: generalColor
                    visible: modelData === (currentDayOfWeek - startDay + 7) % 7
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: day
                        invert: true
                    }
                }
                Rectangle {
                    id: day
                    anchors.fill:  parent
                    color: "transparent"
                    visible: !circle.visible
                    anchors.centerIn: circle
                    Kirigami.Heading {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: days[(modelData + startDay)% 7]
                        color: generalColor
                        font.pixelSize: fSize
                        font.bold: true
                    }
                }
            }
        }
    }

    DayOfWeekRow {
        id: daysWeek
        visible:  false
        delegate: Item {
            Component.onCompleted: {
                days.push(narrowName)
            }
        }
    }

    Component.onCompleted: {
        timer.interval = getRemainingMilliseconds()
        timer.start()
    }
}


