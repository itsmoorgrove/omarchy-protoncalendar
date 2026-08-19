import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property string dateKey: ""
  property date today: new Date()
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property bool expanded: false

  signal submitted(string title, string time, bool allDay)
  signal dismissed()

  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property var parsedTime: Model.parseTime(timeField.text)
  readonly property bool valid: titleField.text.replace(/^\s+|\s+$/g, "") !== ""
    && (allDayToggle.checked || parsedTime !== null)

  implicitHeight: expanded ? column.implicitHeight : 0
  clip: true

  Behavior on implicitHeight {
    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
  }

  function reset() {
    titleField.text = ""
    allDayToggle.checked = false
    timeField.text = Model.nextSlot(root.today).text
  }

  function focusTitle() {
    titleField.forceActiveFocus()
    titleField.selectAll()
  }

  function submit() {
    if (!valid) return
    root.submitted(titleField.text.replace(/^\s+|\s+$/g, ""),
                   allDayToggle.checked ? "" : parsedTime.text,
                   allDayToggle.checked)
    reset()
  }

  function handleKey(event) {
    if (event.key === Qt.Key_Escape) {
      root.dismissed()
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.submit()
      event.accepted = true
    }
  }

  Column {
    id: column
    width: parent.width
    spacing: Style.space(6)

    Row {
      width: parent.width
      spacing: Style.space(6)

      TextField {
        id: titleField
        width: parent.width - timeField.width - allDayToggle.width - submitButton.width
          - Style.space(18)
        placeholderText: "New event"
        foreground: root.foreground
        font.family: root.fontFamily
        Keys.onPressed: function (event) { root.handleKey(event) }
      }

      TextField {
        id: timeField
        width: Style.space(64)
        enabled: !allDayToggle.checked
        opacity: enabled ? 1.0 : 0.45
        placeholderText: "09:00"
        foreground: root.foreground
        font.family: root.fontFamily
        Keys.onPressed: function (event) { root.handleKey(event) }
      }

      Button {
        id: allDayToggle
        property bool checked: false
        anchors.verticalCenter: parent.verticalCenter
        text: "All day"
        selected: checked
        bordered: true
        foreground: root.foreground
        fontFamily: root.fontFamily
        fontSize: Style.font.caption
        onClicked: checked = !checked
      }

      Button {
        id: submitButton
        anchors.verticalCenter: parent.verticalCenter
        text: "Open in Proton"
        iconText: "󰏋"
        bordered: true
        enabled: root.valid
        opacity: enabled ? 1.0 : 0.45
        foreground: root.foreground
        fontFamily: root.fontFamily
        fontSize: Style.font.caption
        onClicked: root.submit()
      }
    }

    Text {
      width: parent.width
      text: {
        var when = root.dateKey === "" ? "the selected day"
          : Qt.formatDate(Model.parseStamp(root.dateKey), "ddd d MMM")
        if (!root.valid && titleField.text === "")
          return "Proton has no write API — the title is copied and the web app opens on the day."
        if (!root.valid) return "That is not a time. Try 9, 930, or 9:30."
        return "Copies the title and opens Proton Calendar on " + when + " for a paste."
      }
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
  }

  onExpandedChanged: {
    if (expanded) {
      reset()
      Qt.callLater(focusTitle)
    }
  }
}
