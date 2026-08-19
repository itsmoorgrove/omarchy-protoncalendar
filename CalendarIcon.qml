import QtQuick
import qs.Commons

Item {
  id: root

  property real iconSize: 24
  property color color: "#cacccc"
  property color accentColor: Color.accent
  property color warningColor: "#d1a24a"
  property color casingColor: Color.background

  property int eventCount: 0
  property bool busy: false
  property bool warning: false
  property bool configured: true

  readonly property int maxPips: 3
  readonly property color bandColor: warning ? warningColor : accentColor

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  readonly property real stroke: Math.max(1, Math.round(iconSize * 0.075))
  readonly property real bodyW: Math.round(iconSize * 0.76)
  readonly property real bodyH: Math.round(iconSize * 0.70)
  readonly property real tabH: Math.max(2, Math.round(iconSize * 0.13))

  opacity: (configured ? 1.0 : 0.6) * pulse.value

  Row {
    id: tabs
    anchors.horizontalCenter: parent.horizontalCenter
    y: body.y - root.tabH + root.stroke
    spacing: Math.round(root.bodyW * 0.34)

    Repeater {
      model: 2
      Rectangle {
        width: root.stroke
        height: root.tabH
        radius: root.stroke / 2
        color: root.color
      }
    }
  }

  Rectangle {
    id: body
    width: root.bodyW
    height: root.bodyH
    anchors.horizontalCenter: parent.horizontalCenter
    y: Math.round((root.iconSize - root.bodyH) / 2 + root.tabH * 0.35)
    radius: Math.max(1.5, root.iconSize * 0.09)
    color: "transparent"
    border.width: root.stroke
    border.color: root.color
    antialiasing: true

    Rectangle {
      id: band
      width: parent.width - root.stroke * 2
      height: Math.max(2, Math.round(root.bodyH * 0.26))
      x: root.stroke
      y: root.stroke
      color: root.configured ? root.bandColor : "transparent"
      topLeftRadius: parent.radius - root.stroke / 2
      topRightRadius: parent.radius - root.stroke / 2

      Rectangle {
        visible: !root.configured
        anchors.bottom: parent.bottom
        width: parent.width
        height: root.stroke
        color: root.color
      }
    }

    Row {
      id: pips
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: band.bottom
      anchors.topMargin: Math.max(1.5, root.bodyH * 0.16)
      spacing: Math.max(1.5, Math.round(root.bodyW * 0.11))
      visible: root.configured && root.eventCount > 0

      Repeater {
        model: Math.min(root.eventCount, root.maxPips)
        Rectangle {
          readonly property bool overflow: root.eventCount > root.maxPips
            && index === root.maxPips - 1
          width: overflow ? root.stroke * 3 : root.stroke * 1.5
          height: root.stroke * 1.5
          radius: height / 2
          color: root.color
          antialiasing: true
        }
      }
    }
  }

  QtObject {
    id: pulse
    property real value: 1.0
  }

  SequentialAnimation {
    running: root.busy
    loops: Animation.Infinite
    alwaysRunToEnd: true
    onStopped: pulse.value = 1.0

    NumberAnimation { target: pulse; property: "value"; from: 1.0; to: 0.45; duration: 620; easing.type: Easing.InOutQuad }
    NumberAnimation { target: pulse; property: "value"; from: 0.45; to: 1.0; duration: 620; easing.type: Easing.InOutQuad }
  }
}
