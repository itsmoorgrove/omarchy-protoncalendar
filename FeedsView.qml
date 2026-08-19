import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property var feeds: []
  property bool configured: false
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property string draft: ""
  property bool busy: false

  signal addRequested(string url)
  signal removeRequested(string url)

  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property bool draftValid: draft.indexOf("https://") === 0 && draft.length > 24

  implicitHeight: column.implicitHeight

  function clearDraft() {
    field.text = ""
  }

  Column {
    id: column
    width: parent.width
    spacing: Style.space(8)

    PanelSectionHeader {
      width: parent.width
      text: root.configured ? "CALENDARS" : "ADD YOUR PROTON CALENDAR"
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Text {
      width: parent.width
      visible: !root.configured
      wrapMode: Text.WordWrap
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      text: "In Proton Calendar: Settings → Calendars → your calendar → Share → "
        + "Share with anyone, then copy the link and paste it here.\n\n"
        + "That link is a secret URL: anyone holding it can read the calendar, "
        + "and it is not end-to-end encrypted the way the calendar itself is."
    }

    Column {
      width: parent.width
      spacing: Style.space(3)
      visible: root.feeds.length > 0

      Repeater {
        model: root.feeds

        Rectangle {
          id: feedRow
          required property var modelData

          width: column.width
          height: Math.max(Style.space(30), feedText.implicitHeight + Style.space(10))
          radius: Style.cornerRadius
          color: rowMouse.containsMouse
            ? Style.hoverFillFor(root.foreground, Color.accent)
            : "transparent"

          Rectangle {
            id: swatch
            anchors.verticalCenter: parent.verticalCenter
            x: Style.space(6)
            width: Style.space(8)
            height: Style.space(8)
            radius: width / 2
            antialiasing: true
            color: feedRow.modelData.color || Color.accent
            opacity: feedRow.modelData.ok === false ? 0.4 : 1.0
          }

          Column {
            id: feedText
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: swatch.right
            anchors.leftMargin: Style.space(9)
            anchors.right: removeButton.left
            anchors.rightMargin: Style.space(6)
            spacing: Style.space(1)

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: feedRow.modelData.name || "Calendar"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: {
                var data = feedRow.modelData
                if (data.error) return data.error
                var count = data.count === undefined ? 0 : data.count
                return count === 1 ? "1 event" : count + " events"
              }
              color: feedRow.modelData.error ? Color.urgent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }

          PanelActionButton {
            id: removeButton
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Style.space(4)
            iconText: "󰅖"
            tooltipText: "Remove this calendar"
            hoverColor: Color.urgent
            foreground: root.dim
            fontFamily: root.fontFamily
            onClicked: root.removeRequested(feedRow.modelData.url)
          }

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
          }
        }
      }
    }

    Row {
      width: parent.width
      spacing: Style.space(6)

      TextField {
        id: field
        width: parent.width - addButton.width - Style.space(6)
        enabled: !root.busy
        placeholderText: root.configured
          ? "Paste another share link…"
          : "https://calendar.proton.me/api/calendar/v1/url/…"
        foreground: root.foreground
        font.family: root.fontFamily
        onTextChanged: root.draft = text
        Keys.onReturnPressed: addButton.clicked()
        Keys.onEnterPressed: addButton.clicked()
      }

      Button {
        id: addButton
        anchors.verticalCenter: parent.verticalCenter
        text: "Add"
        bordered: true
        enabled: root.draftValid && !root.busy
        opacity: enabled ? 1.0 : 0.45
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: {
          if (!enabled) return
          root.addRequested(root.draft)
          root.clearDraft()
        }
      }
    }

    Text {
      width: parent.width
      visible: root.configured
      wrapMode: Text.WordWrap
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      text: "To swap a link, add the new one and remove the old. "
        + "Feeds are stored in ~/.config/omarchy/protoncalendar/feeds.json."
    }
  }
}
