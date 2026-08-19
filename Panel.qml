import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.itsmoorgrove.protoncalendar"
  ipcTarget: "io.github.itsmoorgrove.protoncalendar"
  manageIpc: false

  property var anchorItem: null
  property var service: null

  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property date today: new Date()
  readonly property string todayKey: Model.keyForDate(today)

  property string view: String(setting("defaultView", "Month"))
  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth()
  property date viewWeek: today
  property string selectedKey: todayKey
  property bool addOpen: false
  property bool settingsOpen: false

  readonly property bool viewingMonth: view === "Month"
  readonly property bool viewingWeek: view === "Week"
  readonly property bool viewingAgenda: view === "Upcoming"

  readonly property var barLabelRing: ["Off", "Title", "Title and time"]
  readonly property string barLabel: {
    var current = String(setting("barLabel", "Title and time"))
    return barLabelRing.indexOf(current) < 0 ? "Title and time" : current
  }
  readonly property string nextBarLabel: barLabelRing[(barLabelRing.indexOf(barLabel) + 1) % barLabelRing.length]
  readonly property bool atToday: {
    if (viewingAgenda) return true
    if (viewingMonth) return viewYear === today.getFullYear() && viewMonth === today.getMonth()
    return Model.keyForDate(Model.weekDays(viewWeek, weekStart, "")[0].date)
      === Model.keyForDate(Model.weekDays(today, weekStart, "")[0].date)
  }

  readonly property int weekStart: Model.normalizedWeekStart(setting("weekStartDay", null), Qt.locale().firstDayOfWeek)
  readonly property string nextWeekStartLabel: Qt.locale().dayName(Model.toggledWeekStart(weekStart), Locale.LongFormat)

  readonly property var events: service ? service.events : []
  readonly property var buckets: service ? service.buckets : ({})
  readonly property var weeks: Model.monthGrid(viewYear, viewMonth, weekStart, todayKey)
  readonly property var weekdays: Model.weekdayOrder(weekStart)
  readonly property var weekDayList: Model.weekDays(viewWeek, weekStart, todayKey)
  readonly property var selectedEvents: Model.eventsOn(buckets, selectedKey)
  readonly property var nextEvent: service ? service.nextEvent : null

  readonly property bool configured: service ? service.configured : false
  readonly property string statusLine: {
    if (!service) return ""
    if (service.error !== "") return service.error
    if (service.feedError !== "") return service.feedError
    if (service.stale) return "Showing the last good copy — refresh failed."
    if (!service.generatedAt) return ""
    return "Updated " + Qt.formatDateTime(service.generatedAt, "HH:mm")
  }

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color dim: Qt.darker(contentForeground, 1.55)

  readonly property string headingText: {
    if (viewingAgenda) {
      var count = agendaView.total
      return count === 0 ? "Upcoming" : "Upcoming · " + count
    }
    if (viewingMonth) return Qt.formatDate(new Date(viewYear, viewMonth, 1), "MMMM yyyy")
    return "Week " + Model.weekNumberOf(viewWeek, weekStart) + " · "
      + Qt.formatDate(weekDayList[0].date, "MMM yyyy")
  }

  function open() {
    refresh()
    if (service) service.ensureFresh()
    root.controller.show()
    Qt.callLater(function () {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.addOpen = false
    root.settingsOpen = false
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function refresh() {
    root.today = new Date()
    goToToday()
  }

  function goToToday() {
    root.viewYear = today.getFullYear()
    root.viewMonth = today.getMonth()
    root.viewWeek = today
    root.selectedKey = todayKey
  }

  function step(delta) {
    if (viewingAgenda) return
    if (viewingMonth) {
      var next = Model.stepMonth(viewYear, viewMonth, delta)
      root.viewYear = next.year
      root.viewMonth = next.month
    } else {
      root.viewWeek = Model.addDays(viewWeek, delta * 7)
    }
  }

  function stepLarge(delta) {
    if (viewingAgenda) return
    if (viewingMonth) step(delta * 12)
    else root.viewWeek = Model.addDays(viewWeek, delta * 28)
  }

  function setView(next) {
    if (next === root.view) return
    var wasAgenda = root.viewingAgenda
    root.view = next
    if (next === "Week") root.viewWeek = Model.parseStamp(selectedKey) || today
    else if (next === "Month") {
      var anchor = Model.parseStamp(selectedKey) || (wasAgenda ? today : viewWeek)
      root.viewYear = anchor.getFullYear()
      root.viewMonth = anchor.getMonth()
    }
    persistSettings({ defaultView: next })
  }

  function cycleBarLabel() {
    persistSettings({ barLabel: root.nextBarLabel })
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function toggleWeekStart() {
    persistSettings({ weekStartDay: Model.weekStartSettingName(Model.toggledWeekStart(root.weekStart)) })
  }

  function whenText(event) {
    if (!event) return ""
    if (!event.allDay) return Qt.formatDateTime(event.start, "ddd d MMM HH:mm")
    var from = Qt.formatDate(event.start, "ddd d MMM")
    if (!event.multiDay) return from
    return from + " – " + Qt.formatDate(event.lastDate, "ddd d MMM")
  }

  function openEvent(event) {
    if (!service || !event) return
    service.openDay(Model.keyForDate(event.start), "", "", "week")
  }

  function submitAdd(title, time, allDay) {
    if (!service) return
    service.openDay(selectedKey, title, allDay ? "" : time, "week")
    root.addOpen = false
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: {
      if (Model.keyForDate(clock.date) === String(root.todayKey)) return
      var followToday = root.atToday
      root.today = clock.date
      if (followToday) root.goToToday()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(620))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.addOpen || root.settingsOpen || !root.configured
      onMoveRequested: function (dx, dy) {
        if (dx !== 0) root.step(dx)
        if (dy !== 0) root.stepLarge(dy)
      }
      onActivateRequested: root.goToToday()
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }
      onTextKey: function (t) {
        if (t === "[") root.step(-1)
        else if (t === "]") root.step(1)
        else if (t === "{") root.stepLarge(-1)
        else if (t === "}") root.stepLarge(1)
        else if (t === "t" || t === "T") root.goToToday()
        else if (t === "w" || t === "W") root.toggleWeekStart()
        else if (t === "m" || t === "M") root.setView("Month")
        else if (t === "e" || t === "E") root.setView("Week")
        else if (t === "u" || t === "U") root.setView("Upcoming")
        else if (t === "b" || t === "B") root.cycleBarLabel()
        else if (t === "s" || t === "S") root.settingsOpen = !root.settingsOpen
        else if (t === "r" || t === "R") { if (root.service) root.service.refresh() }
        else if (t === "n" || t === "N" || t === "a" || t === "A") root.addOpen = true
        else if (t === "o" || t === "O") { if (root.service) root.service.openDay(root.selectedKey, "", "", "week") }
      }

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: content.width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height || contentWidth > width

        Column {
          id: content
          width: Math.max(scroll.width, monthView.implicitWidth, weekView.implicitWidth)
          spacing: Style.space(10)

          PanelHero {
            width: parent.width
            visible: root.configured
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            title: root.nextEvent ? root.nextEvent.title : "Nothing coming up"
            meta: {
              if (!root.nextEvent) return ""
              var relative = root.service ? root.service.nextRelative : ""
              var when = root.whenText(root.nextEvent)
              return relative === "" ? when : relative.toUpperCase() + " · " + when
            }
            detail: root.nextEvent ? root.nextEvent.location : ""
            iconOpacity: root.nextEvent ? 1.0 : 0.5

            iconComponent: Component {
              CalendarIcon {
                iconSize: Style.font.display
                color: root.contentForeground
                accentColor: root.nextEvent && root.nextEvent.color !== ""
                  ? root.nextEvent.color : Color.accent
                configured: true
                eventCount: root.service ? root.service.todayEvents.length : 0
                busy: root.service ? root.service.syncing : false
              }
            }

            MouseArea {
              anchors.fill: parent
              enabled: root.nextEvent !== null
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              acceptedButtons: Qt.LeftButton
              onClicked: root.openEvent(root.nextEvent)
            }
          }

          FeedsView {
            id: feedsView
            width: parent.width
            visible: !root.configured || root.settingsOpen
            feeds: root.service ? root.service.feeds : []
            configured: root.configured
            busy: root.service ? root.service.syncing : false
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onAddRequested: function (url) {
              if (root.service) root.service.addFeed(url, "")
            }
            onRemoveRequested: function (url) {
              if (root.service) root.service.removeFeed(url)
            }
          }

          PanelSeparator {
            width: parent.width
            visible: root.configured && root.settingsOpen
          }

          Item {
            width: parent.width
            visible: root.configured
            height: Math.max(viewSwitch.implicitHeight, centerRow.implicitHeight, actionsRow.implicitHeight)

            ButtonGroup {
              id: viewSwitch
              anchors.left: parent.left
              anchors.leftMargin: Style.space(1)
              anchors.verticalCenter: parent.verticalCenter
              options: ["Month", "Week", "Upcoming"]
              value: root.view
              foreground: root.contentForeground
              background: Color.background
              fontFamily: root.contentFontFamily
              fontSize: Style.font.caption
              onChanged: function (value) { root.setView(value) }
            }

            Row {
              id: centerRow
              anchors.centerIn: parent
              spacing: Style.space(4)

              PanelActionButton {
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰅁"
                visible: !root.viewingAgenda
                tooltipText: root.viewingMonth ? "Previous month" : "Previous week"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.step(-1)
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(150)
                horizontalAlignment: Text.AlignHCenter
                text: root.headingText
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
              }

              PanelActionButton {
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰅂"
                visible: !root.viewingAgenda
                tooltipText: root.viewingMonth ? "Next month" : "Next week"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.step(1)
              }
            }

            Row {
              id: actionsRow
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)

              PanelActionButton {
                anchors.verticalCenter: parent.verticalCenter
                iconText: root.barLabel === "Off" ? "󰛐" : "󰛑"
                tooltipText: root.nextBarLabel === "Off"
                  ? "Bar: icon only"
                  : "Bar: show " + root.nextBarLabel.toLowerCase()
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.cycleBarLabel()
              }

              PanelActionButton {
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰥔"
                visible: !root.atToday
                tooltipText: "Back to today"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.goToToday()
              }

              PanelActionButton {
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰑐"
                tooltipText: root.service && root.service.syncing ? "Refreshing…" : "Refresh"
                enabled: !(root.service && root.service.syncing)
                opacity: enabled ? 1.0 : 0.45
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: { if (root.service) root.service.refresh() }
              }

              PanelActionButton {
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰐕"
                tooltipText: "New event"
                bordered: true
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.addOpen = !root.addOpen
              }

              PanelActionButton {
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰒓"
                tooltipText: root.settingsOpen ? "Hide calendars" : "Calendars"
                bordered: root.settingsOpen
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.settingsOpen = !root.settingsOpen
              }
            }
          }

          Item {
            width: parent.width
            visible: root.configured
            height: root.viewingAgenda ? agendaView.implicitHeight
              : (root.viewingMonth ? monthView.implicitHeight : weekView.implicitHeight)

            WheelHandler {
              enabled: !root.viewingAgenda
              onWheel: function (event) {
                if (event.angleDelta.y === 0) return
                root.step(event.angleDelta.y > 0 ? -1 : 1)
              }
            }

            MonthView {
              id: monthView
              anchors.horizontalCenter: parent.horizontalCenter
              visible: root.viewingMonth
              weeks: root.weeks
              weekdays: root.weekdays
              buckets: root.buckets
              todayKey: root.todayKey
              selectedKey: root.selectedKey
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              nextWeekStartLabel: root.nextWeekStartLabel
              onDaySelected: function (key) { root.selectedKey = key }
              onDayActivated: function (key) {
                if (root.service) root.service.openDay(key, "", "", "week")
              }
              onWeekStartToggled: root.toggleWeekStart()
            }

            AgendaView {
              id: agendaView
              anchors.horizontalCenter: parent.horizontalCenter
              visible: root.viewingAgenda
              width: content.width
              events: root.events
              now: root.service ? root.service.now : new Date()
              todayKey: root.todayKey
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onEventActivated: function (event) { root.openEvent(event) }
            }

            WeekView {
              id: weekView
              anchors.horizontalCenter: parent.horizontalCenter
              visible: root.viewingWeek
              days: root.weekDayList
              buckets: root.buckets
              dayStartHour: root.service ? root.service.dayStartHour : 7
              dayEndHour: root.service ? root.service.dayEndHour : 22
              now: root.service ? root.service.now : new Date()
              todayKey: root.todayKey
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onEventActivated: function (event) { root.openEvent(event) }
              onDayActivated: function (key) {
                root.selectedKey = key
                root.setView("Month")
              }
            }
          }

          PanelSeparator {
            width: parent.width
            visible: root.configured
          }

          Column {
            width: parent.width
            visible: root.configured && root.viewingMonth
            spacing: Style.space(4)

            PanelSectionHeader {
              width: parent.width
              text: Qt.formatDate(Model.parseStamp(root.selectedKey) || root.today, "dddd d MMMM").toUpperCase()
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Text {
              width: parent.width
              visible: root.selectedEvents.length === 0
              text: "Nothing scheduled."
              color: root.dim
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Repeater {
              model: root.selectedEvents

              EventRow {
                required property var modelData
                width: content.width
                event: modelData
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onActivated: root.openEvent(modelData)
              }
            }
          }

          QuickAdd {
            id: quickAdd
            width: parent.width
            visible: root.configured
            expanded: root.addOpen
            dateKey: root.selectedKey
            today: root.today
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onSubmitted: function (title, time, allDay) { root.submitAdd(title, time, allDay) }
            onDismissed: root.addOpen = false
          }

          Item {
            width: parent.width
            visible: root.configured && root.statusLine !== ""
            height: Style.space(16)

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - Style.space(70)
              textFormat: Text.PlainText
              text: root.statusLine
              color: root.service && (root.service.stale || root.service.feedError !== "")
                ? Color.urgent : root.dim
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "Open Proton →"
              color: webMouse.containsMouse
                ? Style.hoverStateColor(root.contentForeground, Color.accent)
                : root.dim
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption

              MouseArea {
                id: webMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { if (root.service) root.service.openDay(root.selectedKey, "", "", "week") }
              }
            }
          }
        }
      }
    }
  }
}
