import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var days: []
  property var buckets: ({})
  property int dayStartHour: 7
  property int dayEndHour: 22
  property date now: new Date()
  property string todayKey: ""
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  signal eventActivated(var event)
  signal dayActivated(string key)

  readonly property var hours: Model.visibleHours(buckets, days, dayStartHour, dayEndHour)
  readonly property var columns: Model.weekLayout(buckets, days, hours.start, hours.end)
  readonly property int hourCount: Math.max(1, hours.end - hours.start)

  readonly property int gutterWidth: Style.space(34)
  readonly property int columnWidth: Style.space(64)
  readonly property int columnSpacing: Style.space(2)
  readonly property int hourHeight: Style.space(30)
  readonly property int gridHeight: hourCount * hourHeight

  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property color fainter: Qt.darker(foreground, 2.1)
  readonly property color rule: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.10)

  readonly property real allDayHeight: {
    var most = 0
    for (var i = 0; i < columns.length; i++) most = Math.max(most, columns[i].allDay.length)
    return most === 0 ? 0 : most * Style.space(17) + Style.space(6)
  }

  implicitWidth: gutterWidth + days.length * (columnWidth + columnSpacing)
  implicitHeight: header.height + allDayHeight + Math.min(gridHeight, Style.space(320)) + Style.space(6)

  function columnX(index) {
    return gutterWidth + index * (columnWidth + columnSpacing)
  }

  Item {
    id: header
    width: parent.width
    height: Style.space(34)

    Repeater {
      model: root.days

      Item {
        required property var modelData
        required property int index

        x: root.columnX(index)
        width: root.columnWidth
        height: header.height

        Rectangle {
          anchors.centerIn: parent
          width: Math.max(dayNumber.implicitWidth, dayName.implicitWidth) + Style.space(12)
          height: parent.height - Style.space(6)
          radius: Style.cornerRadius
          color: dayMouse.containsMouse
            ? Style.hoverFillFor(root.foreground, Color.accent)
            : "transparent"
          border.width: modelData.key === root.todayKey ? Style.spacing.hairline : 0
          border.color: Style.normalBorderFor(root.foreground, Color.accent)
        }

        Column {
          anchors.centerIn: parent
          spacing: 0

          Text {
            id: dayName
            anchors.horizontalCenter: parent.horizontalCenter
            text: String(Qt.locale().dayName(modelData.weekday, Locale.ShortFormat))
              .replace(/\.$/, "").toUpperCase()
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
            font.bold: true
          }

          Text {
            id: dayNumber
            anchors.horizontalCenter: parent.horizontalCenter
            text: modelData.day
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: modelData.key === root.todayKey
          }
        }

        MouseArea {
          id: dayMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.dayActivated(modelData.key)
        }
      }
    }
  }

  Item {
    id: allDayBand
    y: header.height
    width: parent.width
    height: root.allDayHeight
    visible: height > 0

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.035)
      radius: Style.cornerRadius
    }

    Repeater {
      model: root.columns

      Column {
        required property var modelData
        required property int index

        x: root.columnX(index)
        y: Style.space(3)
        width: root.columnWidth
        spacing: Style.space(2)

        Repeater {
          model: modelData.allDay

          Rectangle {
            required property var modelData
            width: root.columnWidth
            height: Style.space(15)
            radius: Style.cornerRadius
            color: Qt.rgba(modelData.color ? Qt.color(modelData.color).r : 0.5,
                           modelData.color ? Qt.color(modelData.color).g : 0.5,
                           modelData.color ? Qt.color(modelData.color).b : 0.5, 0.30)

            Text {
              anchors.fill: parent
              anchors.leftMargin: Style.space(5)
              anchors.rightMargin: Style.space(3)
              verticalAlignment: Text.AlignVCenter
              text: modelData.title
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.eventActivated(modelData)
            }
          }
        }
      }
    }
  }

  Flickable {
    id: scroll
    y: header.height + root.allDayHeight + Style.space(4)
    width: parent.width
    height: Math.max(0, parent.height - y)
    contentHeight: root.gridHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    Item {
      width: scroll.width
      height: root.gridHeight

      Repeater {
        model: root.hourCount

        Item {
          required property int index
          y: index * root.hourHeight
          width: parent.width
          height: root.hourHeight

          Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: -Style.space(5)
            width: root.gutterWidth - Style.space(6)
            horizontalAlignment: Text.AlignRight
            text: (root.hours.start + index < 10 ? "0" : "") + (root.hours.start + index) + ":00"
            color: root.fainter
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Rectangle {
            x: root.gutterWidth
            width: parent.width - root.gutterWidth
            height: Style.spacing.hairline
            color: root.rule
          }
        }
      }

      Repeater {
        model: root.columns

        Item {
          required property var modelData
          required property int index

          x: root.columnX(index)
          width: root.columnWidth
          height: root.gridHeight

          Repeater {
            model: modelData.segments

            Rectangle {
              required property var modelData

              readonly property color base: modelData.event.color !== ""
                ? modelData.event.color : Color.accent
              readonly property real slot: root.columnWidth / Math.max(1, modelData.columns)

              x: modelData.column * slot
              width: Math.max(Style.space(6), slot - Style.spacing.hairline)
              y: modelData.top * root.gridHeight
              height: Math.max(Style.space(13), modelData.height * root.gridHeight)
              radius: Style.cornerRadius
              color: Qt.rgba(base.r, base.g, base.b, modelData.event.cancelled ? 0.16 : 0.34)
              topLeftRadius: modelData.continuesBefore ? 0 : radius
              topRightRadius: modelData.continuesBefore ? 0 : radius
              bottomLeftRadius: modelData.continuesAfter ? 0 : radius
              bottomRightRadius: modelData.continuesAfter ? 0 : radius

              Rectangle {
                width: Style.space(2)
                height: parent.height
                color: parent.base
                opacity: 0.9
              }

              Text {
                anchors.fill: parent
                anchors.leftMargin: Style.space(5)
                anchors.rightMargin: Style.space(2)
                anchors.topMargin: Style.space(1)
                text: modelData.event.title
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.strikeout: modelData.event.cancelled
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                verticalAlignment: parent.height > Style.space(26)
                  ? Text.AlignTop : Text.AlignVCenter
              }

              MouseArea {
                id: blockMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.eventActivated(modelData.event)

                PanelToolTip {
                  visible: blockMouse.containsMouse
                  fontFamily: root.fontFamily
                  text: modelData.event.title + "\n"
                    + Qt.formatDateTime(modelData.event.start, "HH:mm") + "–"
                    + Qt.formatDateTime(modelData.event.end, "HH:mm")
                    + (modelData.event.location ? "\n" + modelData.event.location : "")
                }
              }
            }
          }
        }
      }

      Item {
        id: nowLine
        readonly property int index: {
          for (var i = 0; i < root.days.length; i++)
            if (root.days[i].key === root.todayKey) return i
          return -1
        }
        readonly property real fraction: {
          var minutes = Model.minutesOfDay(root.now) - root.hours.start * 60
          return minutes / Math.max(1, (root.hours.end - root.hours.start) * 60)
        }

        visible: index >= 0 && fraction >= 0 && fraction <= 1
        x: root.columnX(index)
        y: fraction * root.gridHeight
        width: root.columnWidth
        height: Style.space(2)

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          height: Style.spacing.hairline * 2
          color: Color.accent
        }

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(5)
          height: Style.space(5)
          radius: width / 2
          color: Color.accent
          antialiasing: true
        }
      }
    }

    Component.onCompleted: scrollToNow()

    function scrollToNow() {
      if (nowLine.index < 0) return
      var target = nowLine.fraction * root.gridHeight - height / 2
      contentY = Math.max(0, Math.min(target, Math.max(0, contentHeight - height)))
    }
  }
}
