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
  property date viewDay: today
  property string selectedKey: todayKey
  property bool addOpen: false
  property bool settingsOpen: false
  property string searchQuery: ""
  property string searchScope: "All"
  property var selectedEvent: null

  readonly property bool viewingMonth: view === "Month"
  readonly property bool viewingWeek: view === "Week"
  readonly property bool viewingDay: view === "Day"
  readonly property bool viewingAgenda: view === "Upcoming"

  readonly property var barModeRing: ["Off", "Next event", "Countdown", "Today count", "Current event", "Privacy"]
  readonly property string barMode: {
    var current = String(setting("barMode", ""))
    if (barModeRing.indexOf(current) >= 0) return current
    var legacy = String(setting("barLabel", "Title and time"))
    return legacy === "Off" ? "Off" : (legacy === "Title" ? "Next event" : "Countdown")
  }
  readonly property string nextBarMode: barModeRing[(barModeRing.indexOf(barMode) + 1) % barModeRing.length]
  readonly property bool atToday: {
    if (viewingAgenda) return true
    if (viewingMonth) return viewYear === today.getFullYear() && viewMonth === today.getMonth()
    if (viewingDay) return Model.keyForDate(viewDay) === todayKey
    return Model.keyForDate(Model.weekDays(viewWeek, weekStart, "")[0].date)
      === Model.keyForDate(Model.weekDays(today, weekStart, "")[0].date)
  }

  readonly property int weekStart: Model.normalizedWeekStart(setting("weekStartDay", "Sunday"), 0)
  readonly property string nextWeekStartLabel: Model.weekdayName(Model.toggledWeekStart(weekStart), false, language)
  readonly property bool showWeekNumbers: {
    var value = setting("showWeekNumbers", true)
    return value === true || String(value).toLowerCase() === "true" || String(value) === "1"
  }
  readonly property string language: service ? service.language
    : Model.resolvedLanguage(setting("language", "System"), Qt.locale().name)
  readonly property string timeFormat: service ? service.timeFormat : String(setting("timeFormat", "System"))

  readonly property var allEvents: service ? service.events : []
  readonly property var events: Model.filterEvents(allEvents, searchQuery, null,
    searchScope, service ? service.now : today, weekStart)
  readonly property var buckets: Model.bucketByDay(events)
  readonly property var weeks: Model.monthGrid(viewYear, viewMonth, weekStart, todayKey)
  readonly property var weekdays: Model.weekdayOrder(weekStart)
  readonly property var weekDayList: Model.weekDays(viewWeek, weekStart, todayKey)
  readonly property var dayList: Model.weekDays(viewDay, viewDay.getDay(), todayKey).slice(0, 1)
  readonly property var selectedEvents: Model.eventsOn(buckets, selectedKey)
  readonly property var nextEvent: service ? service.nextEvent : null
  readonly property int defaultReminderMinutes: service ? service.reminderMinutes : 60
  readonly property var defaultReminderValues: service ? service.reminderMinutesList : [60]
  readonly property var reminderOverrides: service ? service.reminderOverrides : ({})

  readonly property bool configured: service ? service.configured : false
  readonly property string statusLine: {
    if (!service) return ""
    if (service.error !== "") return service.error
    if (service.feedError !== "") return service.feedError
    if (service.stale) return Model.text("lastGoodCopy", language)
    if (!service.generatedAt) return ""
    var result = Model.text("updated", language) + " " + Model.formatTime(service.generatedAt, timeFormat)
    if (service.nextRefreshAt)
      result += " · " + Model.text("nextRefresh", language) + " " + Model.formatTime(service.nextRefreshAt, timeFormat)
    return result
  }

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color dim: Qt.darker(contentForeground, 1.55)

  readonly property string headingText: {
    if (viewingAgenda) {
      var count = agendaView.total
      return count === 0 ? Model.text("upcoming", language)
        : Model.text("upcoming", language) + " · " + count
    }
    if (viewingDay) return Model.formatDate(viewDay, "dddd d MMMM yyyy", language)
    if (viewingMonth) return Model.formatDate(new Date(viewYear, viewMonth, 1), "MMMM yyyy", language)
    return Model.text("week", language) + " " + Model.weekNumberOf(viewWeek, weekStart) + " · "
      + Model.formatDate(weekDayList[0].date, "MMM yyyy", language)
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
    // Hide first: nothing after this line may be able to strand the panel open.
    root.controller.hide()
    root.addOpen = false
    root.settingsOpen = false
    root.selectedEvent = null
    setCenterHoverRevealSuppressed(false)
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
    // The bar hands plugins a PluginBarApi where centerHoverRevealSuppressed is
    // readonly; assigning it throws and aborts whatever called us. Go through
    // the setter the api exposes for exactly this.
    if (root.bar && typeof root.bar.setCenterHoverRevealSuppressed === "function")
      root.bar.setCenterHoverRevealSuppressed(value)
  }

  function refresh() {
    root.today = new Date()
    goToToday()
  }

  function goToToday() {
    root.viewYear = today.getFullYear()
    root.viewMonth = today.getMonth()
    root.viewWeek = today
    root.viewDay = today
    root.selectedKey = todayKey
  }

  function step(delta) {
    if (viewingAgenda) return
    if (viewingMonth) {
      var next = Model.stepMonth(viewYear, viewMonth, delta)
      root.viewYear = next.year
      root.viewMonth = next.month
    } else if (viewingWeek) {
      root.viewWeek = Model.addDays(viewWeek, delta * 7)
    } else if (viewingDay) {
      root.viewDay = Model.addDays(viewDay, delta)
      root.selectedKey = Model.keyForDate(root.viewDay)
    }
  }

  function stepLarge(delta) {
    if (viewingAgenda) return
    if (viewingMonth) step(delta * 12)
    else if (viewingWeek) root.viewWeek = Model.addDays(viewWeek, delta * 28)
    else if (viewingDay) step(delta * 7)
  }

  function setView(next) {
    if (next === root.view) return
    var wasAgenda = root.viewingAgenda
    root.view = next
    if (next === "Week") root.viewWeek = Model.parseStamp(selectedKey) || today
    else if (next === "Day") root.viewDay = Model.parseStamp(selectedKey) || today
    else if (next === "Month") {
      var anchor = Model.parseStamp(selectedKey) || (wasAgenda ? today : viewWeek)
      root.viewYear = anchor.getFullYear()
      root.viewMonth = anchor.getMonth()
    }
    persistSettings({ defaultView: next })
  }

  function cycleBarLabel() {
    persistSettings({ barMode: root.nextBarMode })
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

  function setNotificationSettings(enabled, soundEnabled, sound, minutes) {
    persistSettings({
      notificationsEnabled: enabled,
      notificationSoundEnabled: soundEnabled,
      notificationSound: sound,
      reminderMinutes: minutes
    })
  }

  function setEventReminder(event, value) {
    if (!event) return
    var overrides = {}
    for (var key in root.reminderOverrides) overrides[key] = root.reminderOverrides[key]
    var eventKey = Model.reminderKey(event)
    if (value === null || value === undefined) delete overrides[eventKey]
    else overrides[eventKey] = value
    persistSettings({ reminderOverrides: overrides })
  }

  function whenText(event) {
    if (!event) return ""
    if (!event.allDay) return Model.formatDate(event.start, "ddd d MMM", language) + " "
      + Model.formatTime(event.start, timeFormat)
    var from = Model.formatDate(event.start, "ddd d MMM", language)
    if (!event.multiDay) return from
    return from + " – " + Model.formatDate(event.lastDate, "ddd d MMM", language)
  }

  function openEvent(event) {
    root.selectedEvent = event || null
  }

  function openEventInProton(event) {
    if (!service || !event) return
    service.openDay(Model.keyForDate(event.start), "", "", "week", "")
  }

  function submitAdd(title, time, endTime, allDay, calendar, location, clipboardText) {
    if (!service) return
    service.openDay(selectedKey, title, allDay ? "" : time, "week", clipboardText)
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
    contentWidth: panel.fittedContentWidth(Style.space(680))
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
        else if (t === "d" || t === "D") root.setView("Day")
        else if (t === "u" || t === "U") root.setView("Upcoming")
        else if (t === "b" || t === "B") root.cycleBarLabel()
        else if (t === "s" || t === "S") root.settingsOpen = !root.settingsOpen
        else if (t === "r" || t === "R") { if (root.service) root.service.refresh() }
        else if (t === "n" || t === "N" || t === "a" || t === "A") root.addOpen = true
        else if (t === "o" || t === "O") { if (root.service) root.service.openDay(root.selectedKey, "", "", "week") }
        else if (t === "/") searchField.forceActiveFocus()
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
            title: root.nextEvent ? root.nextEvent.title
              : Model.text("nothingComingUp", root.language)
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
            language: root.language
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onAddRequested: function (url) {
              if (root.service) root.service.addFeed(url, "")
            }
            onRemoveRequested: function (id) {
              if (root.service) root.service.removeFeed(id)
            }
            onUpdateRequested: function (id, values) {
              if (root.service) root.service.updateFeed(id, values)
            }
          }

          SettingsView {
            width: parent.width
            visible: root.configured && root.settingsOpen
            notificationsEnabled: root.service ? root.service.notificationsEnabled : true
            notificationSoundEnabled: root.service ? root.service.notificationSoundEnabled : true
            notificationSound: root.service ? root.service.notificationSound : "Alarm"
            reminderMinutes: root.defaultReminderMinutes
            reminderValues: root.defaultReminderValues
            weekStart: root.weekStart
            languageSetting: String(root.setting("language", "System"))
            resolvedLanguage: root.language
            timeFormat: root.service ? root.service.timeFormatSetting : "System"
            secondaryTimeZone: root.service ? root.service.secondaryTimeZone : ""
            showWeekNumbers: root.showWeekNumbers
            barMode: root.barMode
            allDayNotificationsEnabled: root.service ? root.service.allDayNotificationsEnabled : false
            allDayReminderDays: root.service ? root.service.allDayReminderDays : 1
            allDayReminderHour: root.service ? root.service.allDayReminderHour : 9
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onSettingsRequested: function (enabled, soundEnabled, sound, minutes) {
              root.setNotificationSettings(enabled, soundEnabled, sound, minutes)
            }
            onWeekStartRequested: function (day) {
              root.persistSettings({ weekStartDay: Model.weekStartSettingName(day) })
            }
            onPreferencesRequested: function (values) {
              root.persistSettings(values)
              if (values.secondaryTimeZone !== undefined && root.service)
                Qt.callLater(root.service.refresh)
            }
            onSoundPreviewRequested: function (sound) {
              if (root.service) root.service.previewSound(sound)
            }
            onTestRequested: {
              if (root.service) root.service.scheduleTestReminder()
            }
          }

          PanelSeparator {
            width: parent.width
            visible: root.configured && root.settingsOpen
          }

          Row {
            width: parent.width
            visible: root.configured
            height: Style.space(32)
            spacing: Style.space(6)

            TextField {
              id: searchField
              width: parent.width - scopeSwitch.width - clearSearch.width - searchCount.width - Style.space(18)
              height: parent.height
              placeholderText: Model.text("search", root.language)
              foreground: root.contentForeground
              font.family: root.contentFontFamily
              onTextChanged: root.searchQuery = text
              Keys.onEscapePressed: {
                text = ""
                keyCatcher.forceActiveFocus()
              }
            }

            ButtonGroup {
              id: scopeSwitch
              height: parent.height
              width: Style.space(180)
              options: [Model.scopeLabel("All", root.language),
                Model.scopeLabel("Today", root.language), Model.scopeLabel("Week", root.language)]
              value: Model.scopeLabel(root.searchScope, root.language)
              foreground: root.contentForeground
              background: Color.background
              fontFamily: root.contentFontFamily
              fontSize: Style.font.caption
              onChanged: function (value) { root.searchScope = Model.scopeFromLabel(value) }
            }

            Text {
              id: searchCount
              anchors.verticalCenter: parent.verticalCenter
              text: root.searchQuery === "" && root.searchScope === "All"
                ? "" : root.events.length + "/" + root.allEvents.length
              color: root.dim
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }

            Button {
              id: clearSearch
              height: parent.height
              text: root.language === "sv" ? "Rensa" : "Clear"
              bordered: true
              enabled: root.searchQuery !== "" || root.searchScope !== "All"
              opacity: enabled ? 1.0 : 0.4
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              fontSize: Style.font.caption
              onClicked: {
                searchField.text = ""
                root.searchScope = "All"
              }
            }
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
              options: [Model.viewLabel("Month", root.language),
                Model.viewLabel("Week", root.language), Model.viewLabel("Day", root.language),
                Model.viewLabel("Upcoming", root.language)]
              value: Model.viewLabel(root.view, root.language)
              foreground: root.contentForeground
              background: Color.background
              fontFamily: root.contentFontFamily
              fontSize: Style.font.caption
              onChanged: function (value) { root.setView(Model.viewFromLabel(value, root.view)) }
            }

            Item {
              id: centerRow
              anchors.left: viewSwitch.right
              anchors.leftMargin: Style.space(10)
              anchors.right: actionsRow.left
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              height: Math.max(previousButton.implicitHeight, nextButton.implicitHeight,
                headingLabel.implicitHeight)

              PanelActionButton {
                id: previousButton
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰅁"
                visible: !root.viewingAgenda
                tooltipText: root.viewingMonth ? Model.text("previousMonth", root.language)
                  : (root.viewingWeek ? Model.text("previousWeek", root.language)
                    : Model.text("previousDay", root.language))
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.step(-1)
              }

              Text {
                id: headingLabel
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: previousButton.right
                anchors.leftMargin: Style.space(4)
                anchors.right: nextButton.left
                anchors.rightMargin: Style.space(4)
                horizontalAlignment: Text.AlignHCenter
                text: root.headingText
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
              }

              PanelActionButton {
                id: nextButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰅂"
                visible: !root.viewingAgenda
                tooltipText: root.viewingMonth ? Model.text("nextMonth", root.language)
                  : (root.viewingWeek ? Model.text("nextWeek", root.language)
                    : Model.text("nextDay", root.language))
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
                iconText: root.barMode === "Off" ? "󰛐" : "󰛑"
                tooltipText: Model.text("bar", root.language) + ": "
                  + Model.barModeLabel(root.nextBarMode, root.language).toLowerCase()
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.cycleBarLabel()
              }

              PanelActionButton {
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰥔"
                visible: !root.atToday
                tooltipText: Model.text("backToday", root.language)
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.goToToday()
              }

              PanelActionButton {
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰑐"
                tooltipText: root.service && root.service.syncing
                  ? Model.text("refreshing", root.language) : Model.text("refresh", root.language)
                enabled: !(root.service && root.service.syncing)
                opacity: enabled ? 1.0 : 0.45
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: { if (root.service) root.service.refresh() }
              }

              PanelActionButton {
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰐕"
                tooltipText: Model.text("newEvent", root.language)
                bordered: true
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.addOpen = !root.addOpen
              }

              PanelActionButton {
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰒓"
                tooltipText: root.settingsOpen ? Model.text("hideSettings", root.language)
                  : Model.text("settings", root.language)
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
              : (root.viewingMonth ? monthView.implicitHeight
                : (root.viewingDay ? dayView.implicitHeight : weekView.implicitHeight))

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
              showWeekNumbers: root.showWeekNumbers
              language: root.language
              onDaySelected: function (key) { root.selectedKey = key }
              onDayActivated: function (key) {
                root.selectedKey = key
                root.setView("Day")
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
              defaultReminderMinutes: root.defaultReminderMinutes
              reminderOverrides: root.reminderOverrides
              timeFormat: root.timeFormat
              language: root.language
              onEventActivated: function (event) { root.openEvent(event) }
              onReminderChanged: function (event, value) { root.setEventReminder(event, value) }
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
              timeFormat: root.timeFormat
              language: root.language
              onEventActivated: function (event) { root.openEvent(event) }
              onDayActivated: function (key) {
                root.selectedKey = key
                root.setView("Day")
              }
            }

            WeekView {
              id: dayView
              anchors.horizontalCenter: parent.horizontalCenter
              visible: root.viewingDay
              width: content.width
              dayMode: true
              days: root.dayList
              buckets: root.buckets
              dayStartHour: root.service ? root.service.dayStartHour : 7
              dayEndHour: root.service ? root.service.dayEndHour : 22
              now: root.service ? root.service.now : new Date()
              todayKey: root.todayKey
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              timeFormat: root.timeFormat
              language: root.language
              onEventActivated: function (event) { root.openEvent(event) }
              onDayActivated: function (key) { root.selectedKey = key }
            }
          }

          EventDetails {
            width: parent.width
            event: root.selectedEvent
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            language: root.language
            timeFormat: root.timeFormat
            onCloseRequested: root.selectedEvent = null
            onOpenRequested: function (event) { root.openEventInProton(event) }
            onJoinRequested: function (url) { if (root.service) root.service.openUrl(url) }
            onCopyRequested: function (value) { if (root.service) root.service.copyText(value) }
            onSnoozeRequested: function (event, minutes) {
              if (root.service) root.service.snoozeEvent(event, minutes)
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
              text: Model.formatDate(Model.parseStamp(root.selectedKey) || root.today,
                "dddd d MMMM", root.language).toUpperCase()
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Text {
              width: parent.width
              visible: root.selectedEvents.length === 0
              text: Model.text("noEvents", root.language)
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
                timeFormat: root.timeFormat
                language: root.language
                reminderValues: Model.reminderMinutesList(modelData, root.reminderOverrides,
                  root.defaultReminderValues,
                  root.service && root.service.feedForEvent(modelData)
                    ? root.service.feedForEvent(modelData).reminderMinutes : null)
                reminderMinutes: Model.reminderMinutes(modelData, root.reminderOverrides, root.defaultReminderMinutes) < 0
                  ? root.defaultReminderMinutes
                  : Model.reminderMinutes(modelData, root.reminderOverrides, root.defaultReminderMinutes)
                reminderInherited: root.reminderOverrides[Model.reminderKey(modelData)] === undefined
                reminderOff: Model.reminderMinutes(modelData, root.reminderOverrides, root.defaultReminderMinutes) < 0
                onActivated: root.openEvent(modelData)
                onReminderChanged: function (event, value) { root.setEventReminder(event, value) }
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
            language: root.language
            defaultDurationMinutes: root.service ? root.service.quickAddDurationMinutes : 60
            onSubmitted: function (title, time, endTime, allDay, calendar, location, clipboardText) {
              root.submitAdd(title, time, endTime, allDay, calendar, location, clipboardText)
            }
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
              text: Model.text("openProton", root.language) + " →"
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
                onClicked: { if (root.service) root.service.openDay(root.selectedKey, "", "", "week", "") }
              }
            }
          }
        }
      }
    }
  }
}
