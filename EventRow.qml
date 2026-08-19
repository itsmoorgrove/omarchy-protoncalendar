import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property var event: null
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property bool showDate: false

  signal activated()

  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color accentColor: event && event.color !== "" ? event.color : Color.accent

  readonly property real timeColumn: Style.space(showDate ? 132 : 52)

  height: Math.max(Style.space(26), label.implicitHeight + Style.space(8))
  radius: Style.cornerRadius
  color: mouse.containsMouse
    ? Style.hoverFillFor(foreground, Color.accent)
    : "transparent"

  Rectangle {
    id: stripe
    anchors.verticalCenter: parent.verticalCenter
    x: Style.space(6)
    width: Style.space(3)
    height: parent.height - Style.space(9)
    radius: width / 2
    color: root.accentColor
    opacity: root.event && root.event.cancelled ? 0.35 : 1.0
  }

  Text {
    id: time
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: stripe.right
    anchors.leftMargin: Style.space(8)
    width: root.timeColumn
    horizontalAlignment: Text.AlignLeft
    text: {
      if (!root.event) return ""
      if (root.event.allDay) {
        if (!root.showDate) return "all day"
        var from = Qt.formatDate(root.event.start, "ddd d MMM")
        if (!root.event.multiDay) return from
        var sameMonth = root.event.start.getMonth() === root.event.lastDate.getMonth()
        return Qt.formatDate(root.event.start, sameMonth ? "ddd d" : "ddd d MMM")
          + "–" + Qt.formatDate(root.event.lastDate, "ddd d MMM")
      }
      var clock = Qt.formatDateTime(root.event.start, "HH:mm")
      return root.showDate
        ? Qt.formatDate(root.event.start, "ddd d MMM") + " " + clock
        : clock
    }
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }

  Column {
    id: label
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: time.right
    anchors.leftMargin: Style.space(8)
    anchors.right: parent.right
    anchors.rightMargin: Style.space(8)
    spacing: Style.space(1)

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: root.event ? root.event.title : ""
      color: mouse.containsMouse
        ? Style.hoverStateColor(root.foreground, Color.accent)
        : root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.strikeout: root.event ? root.event.cancelled : false
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      visible: root.event && root.event.location !== ""
      text: root.event ? root.event.location : ""
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()

    PanelToolTip {
      visible: mouse.containsMouse && root.event && root.event.description !== ""
      text: root.event ? root.event.description : ""
      fontFamily: root.fontFamily
    }
  }
}
