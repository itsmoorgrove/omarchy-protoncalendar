import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var weeks: []
  property var weekdays: []
  property var buckets: ({})
  property string todayKey: ""
  property string selectedKey: ""
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property string nextWeekStartLabel: ""

  signal daySelected(string key)
  signal dayActivated(string key)
  signal weekStartToggled()

  readonly property int cellWidth: Style.space(52)
  readonly property int cellHeight: Style.space(40)
  readonly property int cellSpacing: Style.space(2)
  readonly property int weekColumnWidth: Style.space(28)
  readonly property int gutterWidth: Style.space(12)
  readonly property int maxDots: 4

  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property color fainter: Qt.darker(foreground, 1.9)

  implicitWidth: grid.width
  implicitHeight: grid.height

  function weekdayLabel(weekday) {
    return String(Qt.locale().dayName(weekday, Locale.ShortFormat)).replace(/\.$/, "").toUpperCase()
  }

  Column {
    id: grid
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: Style.space(3)

    Row {
      spacing: root.cellSpacing

      Rectangle {
        width: root.weekColumnWidth
        height: Style.space(16)
        radius: Style.cornerRadius
        color: weekStartMouse.containsMouse
          ? Style.hoverFillFor(root.foreground, Color.accent)
          : "transparent"

        Text {
          anchors.centerIn: parent
          text: "W"
          color: weekStartMouse.containsMouse
            ? Style.hoverStateColor(root.foreground, Color.accent)
            : root.fainter
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          font.bold: true
        }

        MouseArea {
          id: weekStartMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.weekStartToggled()
        }

        PanelToolTip {
          visible: weekStartMouse.containsMouse
          text: "Start weeks on " + root.nextWeekStartLabel
          fontFamily: root.fontFamily
        }
      }

      Item {
        width: root.gutterWidth
        height: Style.space(16)
      }

      Repeater {
        model: root.weekdays

        Text {
          required property var modelData
          width: root.cellWidth
          height: Style.space(16)
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          text: root.weekdayLabel(modelData)
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          font.bold: true
        }
      }
    }

    Repeater {
      model: root.weeks

      Row {
        required property var modelData
        spacing: root.cellSpacing

        Text {
          width: root.weekColumnWidth
          height: root.cellHeight
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          text: modelData.week
          color: root.fainter
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Item {
          width: root.gutterWidth
          height: root.cellHeight
        }

        Repeater {
          model: modelData.days

          Rectangle {
            id: cell
            required property var modelData

            readonly property var dayEvents: Model.eventsOn(root.buckets, modelData.key)
            readonly property bool selected: modelData.key === root.selectedKey

            width: root.cellWidth
            height: root.cellHeight
            radius: Style.cornerRadius
            color: selected
              ? Style.selectionFillFor(root.foreground, Color.accent)
              : (dayMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent")
            border.width: modelData.today ? Style.spacing.hairline : 0
            border.color: Style.normalBorderFor(root.foreground, Color.accent)

            Column {
              anchors.centerIn: parent
              spacing: Style.space(3)

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: cell.modelData.day
                color: cell.modelData.inMonth
                  ? (cell.modelData.today || cell.selected ? root.foreground : Qt.darker(root.foreground, 1.15))
                  : Qt.darker(root.foreground, 2.6)
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: cell.modelData.today
              }

              Row {
                anchors.horizontalCenter: parent.horizontalCenter
                height: Style.space(4)
                spacing: Style.space(2)

                Repeater {
                  model: Math.min(cell.dayEvents.length, root.maxDots)

                  Rectangle {
                    required property int index
                    readonly property var event: cell.dayEvents[index]
                    readonly property bool overflow: cell.dayEvents.length > root.maxDots
                      && index === root.maxDots - 1

                    width: overflow ? Style.space(8) : Style.space(4)
                    height: Style.space(4)
                    radius: height / 2
                    antialiasing: true
                    color: event && event.color !== "" ? event.color : Color.accent
                    opacity: cell.modelData.inMonth ? (event && event.cancelled ? 0.4 : 0.95) : 0.4
                  }
                }
              }
            }

            MouseArea {
              id: dayMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.daySelected(cell.modelData.key)
              onDoubleClicked: root.dayActivated(cell.modelData.key)
            }
          }
        }
      }
    }
  }
}
