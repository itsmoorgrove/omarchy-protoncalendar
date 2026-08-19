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

  readonly property string feedError: Model.firstFeedError(feeds)

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 900, 60, 86400)
  readonly property int dayStartHour: intSetting("dayStartHour", 7, 0, 23)
  readonly property int dayEndHour: Math.max(dayStartHour + 1, intSetting("dayEndHour", 22, 1, 24))
  readonly property string feedsFile: stringSetting("feedsFile", "")

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }
  readonly property date now: clock.date
  readonly property string todayKey: Model.keyForDate(now)

  readonly property var nextEvent: Model.nextUpcoming(events, now)
  readonly property string nextRelative: Model.relativeLabel(nextEvent, now)
  readonly property var todayEvents: Model.eventsOn(buckets, todayKey)

  function scriptPath(name) {
    return String(Qt.resolvedUrl("bin/" + name)).replace(/^file:\/\//, "")
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

  function syncArgs(extra) {
    var args = ["python3", scriptPath("protoncal-sync")]
    if (feedsFile !== "") args = args.concat(["--feeds", feedsFile])
    return extra ? args.concat(extra) : args
  }

  function apply(text) {
    var state = Model.readPayload(text)
    root.events = state.events
    root.buckets = Model.bucketByDay(state.events)
    root.feeds = state.feeds
    root.configured = state.configured
    root.stale = state.stale
    root.error = state.error
    root.generatedAt = state.generatedAt
    root.everLoaded = true
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
    feedProcess.command = syncArgs(["--add-feed", trimmed, "--name", String(name || "")])
    feedProcess.running = true
  }

  function removeFeed(url) {
    if (feedProcess.running) return
    feedProcess.command = syncArgs(["--remove-feed", String(url)])
    feedProcess.running = true
  }

  function openDay(dateKey, title, time, view) {
    var args = [scriptPath("protoncal-open"), "--view", String(view || "week")]
    if (dateKey) args = args.concat(["--date", String(dateKey)])
    if (title) args = args.concat(["--title", String(title)])
    if (time) args = args.concat(["--time", String(time)])
    Quickshell.execDetached(args)
  }

  Process {
    id: syncProcess
    command: []
    stdout: StdioCollector { id: syncStdout; waitForEnd: true }
    onExited: function (exitCode) {
      if (exitCode === 0) root.apply(String(syncStdout.text || ""))
      else root.error = "sync failed (exit " + exitCode + ")"
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

  Timer {
    id: refreshTimer
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    onTriggered: root.refresh()
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
