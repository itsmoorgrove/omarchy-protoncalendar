import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})

  property var events: []
  property var buckets: ({})
  property var feeds: []
  property bool configured: false
  property bool stale: false
  property string error: ""
  property var generatedAt: null
  property bool syncing: syncProcess.running || feedProcess.running
  property bool everLoaded: false

  readonly property string feedError: Model.firstFeedError(feeds, language)
  readonly property var nextRefreshAt: generatedAt
    ? new Date(generatedAt.getTime() + refreshIntervalSec * 1000) : null

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 900, 60, 86400)
  readonly property int dayStartHour: intSetting("dayStartHour", 7, 0, 23)
  readonly property int dayEndHour: Math.max(dayStartHour + 1, intSetting("dayEndHour", 22, 1, 24))
  readonly property int quickAddDurationMinutes: intSetting("quickAddDurationMinutes", 60, 5, 1440)
  readonly property string feedsFile: stringSetting("feedsFile", "")
  readonly property string language: Model.resolvedLanguage(stringSetting("language", "System"), Qt.locale().name)
  readonly property string timeFormatSetting: stringSetting("timeFormat", "System")
  readonly property string timeFormat: timeFormatSetting === "System"
    ? (String(Qt.locale().timeFormat(Locale.ShortFormat)).indexOf("AP") >= 0
      || String(Qt.locale().timeFormat(Locale.ShortFormat)).indexOf("ap") >= 0
      ? "12-hour" : "24-hour")
    : timeFormatSetting
  readonly property string secondaryTimeZone: stringSetting("secondaryTimeZone", "")
  readonly property bool notificationsEnabled: boolSetting("notificationsEnabled", true)
  readonly property bool notificationSoundEnabled: boolSetting("notificationSoundEnabled", true)
  readonly property string notificationSound: normalizedSound(stringSetting("notificationSound", "Alarm"))
  readonly property int reminderMinutes: intSetting("reminderMinutes", 60, 1, 10080)
  readonly property var reminderMinutesList: Model.normalizeMinuteList(
    settings ? settings.reminderMinutesList : null, [reminderMinutes])
  readonly property bool allDayNotificationsEnabled: boolSetting("allDayNotificationsEnabled", false)
  readonly property int allDayReminderDays: intSetting("allDayReminderDays", 1, 0, 30)
  readonly property int allDayReminderHour: intSetting("allDayReminderHour", 9, 0, 23)
  readonly property var reminderOverrides: settings && settings.reminderOverrides
    ? settings.reminderOverrides : ({})
  property var firedReminders: ({})
  property var testEvent: null
  property var notificationQueue: []
  property string notificationPayload: ""
  property string copyPayload: ""
  property string pendingSound: ""

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }
  readonly property date now: clock.date
  readonly property string todayKey: Model.keyForDate(now)

  readonly property var nextEvent: Model.nextUpcoming(events, now)
  readonly property string nextRelative: Model.relativeLabel(nextEvent, now, language)
  readonly property var todayEvents: Model.eventsOn(buckets, todayKey)

  function scriptPath(name) {
    return String(Qt.resolvedUrl("bin/" + name)).replace(/^file:\/\//, "")
  }

  function assetPath(name) {
    return String(Qt.resolvedUrl("assets/" + name)).replace(/^file:\/\//, "")
  }

  function intSetting(name, fallback, min, max) {
    var v = parseInt(settings ? settings[name] : undefined, 10)
    if (isNaN(v)) return fallback
    return Math.max(min, Math.min(max, v))
  }

  function stringSetting(name, fallback) {
    var v = settings ? settings[name] : undefined
    if (v === undefined || v === null) return fallback
    return String(v)
  }

  function boolSetting(name, fallback) {
    var v = settings ? settings[name] : undefined
    if (v === undefined || v === null) return fallback
    return v === true || String(v).toLowerCase() === "true" || String(v) === "1"
  }

  function feedForEvent(event) {
    if (!event) return null
    for (var i = 0; i < feeds.length; i++)
      if (feeds[i] && feeds[i].id === event.feedId) return feeds[i]
    return null
  }

  function webUrlFor(event) {
    var date = event && event.start ? event.start : now
    return "https://calendar.proton.me/u/0/week/" + date.getFullYear() + "/"
      + (date.getMonth() + 1) + "/" + date.getDate()
  }

  function normalizedSound(value) {
    var sounds = { "Gentle": true, "Bell": true, "Chime": true, "Alarm": true }
    return sounds[value] ? value : "Alarm"
  }

  function soundId(value) {
    var sounds = {
      "Gentle": "message-new-instant",
      "Bell": "bell",
      "Chime": "complete",
      "Alarm": "alarm-clock-elapsed"
    }
    return sounds[normalizedSound(value)]
  }

  function previewSound(value) {
    var sound = normalizedSound(value)
    if (soundProcess.running) {
      pendingSound = sound
      soundProcess.running = false
      return
    }
    playSound(sound)
  }

  function playSound(sound) {
    soundProcess.command = ["canberra-gtk-play", "--id", soundId(sound),
      "--description", language === "sv" ? "Proton Calendar-påminnelse" : "Proton Calendar reminder"]
    soundProcess.running = true
  }

  function checkReminders() {
    if (!notificationsEnabled || !events) return
    var stamp = now.getTime()
    var soundNeeded = false
    for (var i = 0; i < events.length; i++) {
      var event = events[i]
      if (!event || event.cancelled) continue
      var feed = feedForEvent(event)
      if (feed && feed.notificationsEnabled === false) continue
      var targets = []
      if (event.allDay) {
        if (!allDayNotificationsEnabled) continue
        var allDayTarget = new Date(event.start.getFullYear(), event.start.getMonth(),
          event.start.getDate() - allDayReminderDays, allDayReminderHour, 0, 0, 0)
        targets.push({ key: "all-day", stamp: allDayTarget.getTime() })
      } else {
        if (event.startMs <= stamp) continue
        var minutesList = event === testEvent ? [1] : Model.reminderMinutesList(
          event, reminderOverrides, reminderMinutesList,
          feed ? feed.reminderMinutes : null)
        for (var m = 0; m < minutesList.length; m++)
          targets.push({ key: String(minutesList[m]), stamp: event.startMs - minutesList[m] * 60000 })
      }
      for (var t = 0; t < targets.length; t++) {
        var target = targets[t]
        if (stamp < target.stamp || stamp >= target.stamp + 300000) continue
        var key = Model.reminderKey(event) + ":" + target.key
        if (firedReminders[key]) continue
        var next = {}
        for (var existing in firedReminders) next[existing] = firedReminders[existing]
        next[key] = true
        firedReminders = next
        var when = event.allDay ? Model.text("allDay", language)
          : Model.formatTime(event.start, timeFormat)
        var body = when + (event.location ? " · " + event.location : "")
        sendNotification(event, body, 0)
        soundNeeded = true
      }
    }
    if (soundNeeded && notificationSoundEnabled) previewSound(notificationSound)
  }

  function sendNotification(event, body, delaySeconds) {
    var payload = JSON.stringify({
      title: event ? event.title : "Proton Calendar",
      body: String(body || ""),
      icon: assetPath("proton-calendar.svg"),
      url: webUrlFor(event),
      language: language,
      delaySeconds: Math.max(0, Number(delaySeconds || 0))
    })
    notificationQueue = notificationQueue.concat([payload])
    runNextNotification()
  }

  function runNextNotification() {
    if (notificationProcess.running || notificationQueue.length === 0) return
    notificationPayload = notificationQueue[0]
    notificationQueue = notificationQueue.slice(1)
    notificationProcess.command = ["python3", scriptPath("protoncal-notify")]
    notificationProcess.running = true
  }

  function snoozeEvent(event, minutes) {
    if (!event) return
    sendNotification(event, Model.text("starting", language) + " · "
      + Model.formatTime(event.start, timeFormat), Math.max(1, minutes) * 60)
  }

  function scheduleTestReminder() {
    var start = new Date(now.getTime() + 120000)
    start.setSeconds(0, 0)
    var end = new Date(start.getTime() + 1800000)
    root.testEvent = Model.parseEvent({
      uid: "protoncalendar-notification-test-" + start.getTime(),
      title: language === "sv" ? "Proton Calendar-test" : "Proton Calendar test",
      location: language === "sv" ? "Notistest" : "Notification test",
      start: start.toISOString(),
      end: end.toISOString(),
      allDay: false
    })
    var nextEvents = events.slice()
    nextEvents.push(root.testEvent)
    nextEvents.sort(function (a, b) { return a.startMs - b.startMs })
    root.events = nextEvents
    root.buckets = Model.bucketByDay(nextEvents)
  }

  function syncArgs(extra) {
    var args = ["python3", scriptPath("protoncal-sync")]
    if (feedsFile !== "") args = args.concat(["--feeds", feedsFile])
    if (secondaryTimeZone !== "") args = args.concat(["--secondary-time-zone", secondaryTimeZone])
    return extra ? args.concat(extra) : args
  }

  function apply(text) {
    var state = Model.readPayload(text)
    var appliedEvents = state.events
    if (testEvent && testEvent.endMs > now.getTime()) {
      appliedEvents = state.events.slice()
      appliedEvents.push(testEvent)
      appliedEvents.sort(function (a, b) { return a.startMs - b.startMs })
    }
    root.events = appliedEvents
    root.buckets = Model.bucketByDay(appliedEvents)
    root.feeds = state.feeds
    root.configured = state.configured
    root.stale = state.stale
    root.error = state.error
    root.generatedAt = state.generatedAt
    root.everLoaded = true
    Qt.callLater(root.checkReminders)
  }

  function refresh() {
    if (syncProcess.running) return
    syncProcess.command = syncArgs(null)
    syncProcess.running = true
  }

  function ensureFresh() {
    if (!everLoaded) { loadCached(); return }
    if (!generatedAt) { refresh(); return }
    var age = (now.getTime() - generatedAt.getTime()) / 1000
    if (age >= refreshIntervalSec) refresh()
  }

  function loadCached() {
    if (cacheProcess.running) return
    cacheProcess.command = syncArgs(["--cached"])
    cacheProcess.running = true
  }

  function addFeed(url, name) {
    var trimmed = String(url || "").replace(/^\s+|\s+$/g, "")
    if (trimmed === "" || feedProcess.running) return
    feedProcess.environment = { "PROTONCAL_FEED_URL": trimmed }
    feedProcess.command = syncArgs(["--add-feed-env", "--name", String(name || "")])
    feedProcess.running = true
  }

  function removeFeed(id) {
    if (feedProcess.running) return
    feedProcess.environment = ({})
    feedProcess.command = syncArgs(["--remove-feed-id", String(id)])
    feedProcess.running = true
  }

  function updateFeed(id, values) {
    if (feedProcess.running) return
    var patch = { id: String(id) }
    for (var key in values) patch[key] = values[key]
    feedProcess.environment = { "PROTONCAL_FEED_UPDATE": JSON.stringify(patch) }
    feedProcess.command = syncArgs(["--update-feed-env"])
    feedProcess.running = true
  }

  function openDay(dateKey, title, time, view, clipboardText) {
    if (openProcess.running) return
    var args = [scriptPath("protoncal-open"), "--view", String(view || "week")]
    if (dateKey) args = args.concat(["--date", String(dateKey)])
    if (time) args = args.concat(["--time", String(time)])
    if (title) args = args.concat(["--title-env", "--clipboard-env", "--prefill"])
    openProcess.environment = {
      "PROTONCAL_TITLE": String(title || ""),
      "PROTONCAL_CLIPBOARD_TEXT": String(clipboardText || title || "")
    }
    openProcess.command = args
    openProcess.running = true
  }

  function copyText(value) {
    if (copyProcess.running) return
    copyPayload = String(value || "")
    copyProcess.command = ["python3", scriptPath("protoncal-copy")]
    copyProcess.running = true
  }

  function openUrl(value) {
    var url = Model.validWebUrl(value)
    if (url) Qt.openUrlExternally(url)
  }

  Process {
    id: syncProcess
    command: []
    stdout: StdioCollector { id: syncStdout; waitForEnd: true }
    onExited: function (exitCode) {
      if (exitCode === 0) root.apply(String(syncStdout.text || ""))
      else root.error = language === "sv" ? "synkronisering misslyckades (kod " + exitCode + ")"
        : "sync failed (exit " + exitCode + ")"
    }
  }

  Process {
    id: cacheProcess
    command: []
    stdout: StdioCollector { id: cacheStdout; waitForEnd: true }
    onExited: function (exitCode) {
      if (exitCode === 0) root.apply(String(cacheStdout.text || ""))
      root.everLoaded = true
    }
  }

  Process {
    id: feedProcess
    command: []
    stdout: StdioCollector { id: feedStdout; waitForEnd: true }
    onExited: function (exitCode) {
      if (exitCode === 0) root.apply(String(feedStdout.text || ""))
    }
  }

  Process {
    id: notificationProcess
    command: []
    stdinEnabled: true
    onStarted: {
      write(root.notificationPayload + "\n")
      root.notificationPayload = ""
    }
    onExited: root.runNextNotification()
  }

  Process {
    id: openProcess
    command: []
  }

  Process {
    id: soundProcess
    command: []
    onExited: function () {
      if (root.pendingSound === "") return
      var next = root.pendingSound
      root.pendingSound = ""
      root.playSound(next)
    }
  }

  Process {
    id: copyProcess
    command: []
    stdinEnabled: true
    onStarted: {
      write(JSON.stringify(root.copyPayload) + "\n")
      root.copyPayload = ""
    }
  }

  Timer {
    id: refreshTimer
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Timer {
    interval: 30000
    repeat: true
    running: true
    onTriggered: root.checkReminders()
  }

  Component.onCompleted: {
    loadCached()
    firstSync.start()
  }

  Timer {
    id: firstSync
    interval: 1200
    repeat: false
    onTriggered: root.refresh()
  }
}
