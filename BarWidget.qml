import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "io.github.itsmoorgrove.protoncalendar"

  Service {
    id: calendar
    settings: root.settings
  }

  readonly property string labelMode: {
    var v = root.setting("barLabel", "Title and time")
    return root.vertical ? "Off" : String(v)
  }

  readonly property string barText: {
    if (labelMode === "Off") return ""
    var event = calendar.nextEvent
    if (!event) return ""

    var title = event.title
    if (title.length > 22) title = title.substring(0, 21) + "…"
    if (labelMode === "Title") return title

    var relative = calendar.nextRelative

    if (event.allDay)
      return relative === "" ? title : relative + " · " + title

    if (relative === "now" || (relative.indexOf("in ") === 0 && relative.indexOf("min") > 0))
      return relative + " · " + title
    return Qt.formatDateTime(event.start, "HH:mm") + " " + title
  }

  readonly property string tooltip: {
    if (!calendar.configured) return "Proton Calendar — no feed added yet"
    if (calendar.feedError !== "") return calendar.feedError
    var event = calendar.nextEvent
    if (!event) return "Nothing coming up"
    var relative = calendar.nextRelative
    return event.title + "\n" + root.whenText(event)
      + (relative ? " · " + relative : "")
      + (event.location ? "\n" + event.location : "")
  }

  function whenText(event) {
    if (!event) return ""
    if (!event.allDay) return Qt.formatDateTime(event.start, "ddd d MMM HH:mm")
    var from = Qt.formatDate(event.start, "ddd d MMM")
    if (!event.multiDay) return from
    return from + " – " + Qt.formatDate(event.lastDate, "ddd d MMM")
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function refresh() { calendar.refresh() }
  function cycleBarLabel() { if (panelLoader.item) panelLoader.item.cycleBarLabel() }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("service" in target) target.service = calendar
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "io.github.itsmoorgrove.protoncalendar"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function refresh(): void { root.broadcast("refresh") }
    function next(): string {
      var event = calendar.nextEvent
      if (!event) return "Nothing coming up"
      return root.whenText(event) + "  " + event.title
    }
    function today(): string {
      var list = calendar.todayEvents
      if (!list.length) return "Nothing today"
      var lines = []
      for (var i = 0; i < list.length; i++) {
        var event = list[i]
        lines.push((event.allDay ? "all day" : Qt.formatDateTime(event.start, "HH:mm"))
          + "  " + event.title)
      }
      return lines.join("\n")
    }
    function web(): void { calendar.openDay("", "", "", "week") }
    function cycleLabel(): void { root.cycleBarLabel() }
    function upcoming(): string {
      var list = Model.upcoming(calendar.events, calendar.now)
      if (!list.length) return "Nothing coming up"
      var lines = []
      for (var i = 0; i < list.length; i++)
        lines.push(root.whenText(list[i]) + "  " + list[i].title)
      return lines.join("\n")
    }
  }

  readonly property string labelFontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property real labelGap: Style.space(5)

  TextMetrics {
    id: labelMetrics
    font.family: root.labelFontFamily
    font.pixelSize: Style.font.caption
    text: root.barText
  }

  readonly property real labelExtra: root.barText !== ""
    ? labelMetrics.width + root.labelGap
    : 0

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.iconSlot + root.labelExtra
    tooltipText: root.tooltip

    iconComponent: Component {
      Item {
        anchors.fill: parent

        Row {
          anchors.centerIn: parent
          spacing: root.barText !== "" ? root.labelGap : 0

          CalendarIcon {
            anchors.verticalCenter: parent.verticalCenter
            iconSize: Style.bar.iconCanvas
            color: button.foreground
            accentColor: Color.accent
            casingColor: Color.background
            configured: calendar.configured
            warning: calendar.stale || calendar.feedError !== ""
            busy: calendar.syncing
            eventCount: calendar.todayEvents.length
          }

          Text {
            visible: root.barText !== ""
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.barText
            color: button.foreground
            font.family: root.labelFontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }

    onPressed: function (buttonCode) {
      if (buttonCode === Qt.RightButton) root.cycleBarLabel()
      else if (buttonCode === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }
  }
}
