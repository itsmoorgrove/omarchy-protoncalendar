var MS_PER_DAY = 86400000
var MS_PER_MINUTE = 60000
var WEEKDAY_NAMES = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

function pad2(value) {
  var n = Number(value)
  return (n < 10 ? "0" : "") + n
}

function dateKey(year, month, day) {
  return year + "-" + pad2(Number(month) + 1) + "-" + pad2(day)
}

function keyForDate(date) {
  return dateKey(date.getFullYear(), date.getMonth(), date.getDate())
}

function coerceWeekStart(value) {
  if (value === undefined || value === null) return null
  if (typeof value === "number")
    return isFinite(value) ? ((Math.round(value) % 7) + 7) % 7 : null

  var text = String(value).replace(/^\s+|\s+$/g, "").toLowerCase()
  if (text === "") return null

  for (var i = 0; i < WEEKDAY_NAMES.length; i++)
    if (WEEKDAY_NAMES[i] === text || WEEKDAY_NAMES[i].substr(0, 3) === text) return i

  var parsed = parseInt(text, 10)
  return isFinite(parsed) ? ((parsed % 7) + 7) % 7 : null
}

function normalizedWeekStart(value, fallback) {
  var configured = coerceWeekStart(value)
  if (configured !== null) return configured
  var fallbackStart = coerceWeekStart(fallback)
  return fallbackStart === null ? 1 : fallbackStart
}

function toggledWeekStart(index) {
  return normalizedWeekStart(index, 1) === 1 ? 0 : 1
}

function weekStartSettingName(index) {
  return WEEKDAY_NAMES[normalizedWeekStart(index, 1)]
}

function weekdayOrder(weekStart) {
  var start = normalizedWeekStart(weekStart, 1)
  var out = []
  for (var i = 0; i < 7; i++) out.push((start + i) % 7)
  return out
}

function isoWeek(year, month, day) {
  var date = new Date(Date.UTC(year, month, day))
  var weekday = date.getUTCDay() || 7
  date.setUTCDate(date.getUTCDate() + 4 - weekday)
  var yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1))
  return Math.ceil(((date.getTime() - yearStart.getTime()) / MS_PER_DAY + 1) / 7)
}

function startOfDay(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate())
}

function addDays(date, days) {
  var out = new Date(date.getTime())
  out.setDate(out.getDate() + days)
  return out
}

function stepMonth(year, month, delta) {
  var target = new Date(year, Number(month) + Number(delta), 1)
  return { year: target.getFullYear(), month: target.getMonth() }
}

function monthGrid(year, month, weekStart, todayKey) {
  var start = normalizedWeekStart(weekStart, 1)
  var leading = (new Date(year, month, 1).getDay() - start + 7) % 7
  var cursor = new Date(year, month, 1 - leading)
  var today = String(todayKey || "")
  var weeks = []

  for (var w = 0; w < 6; w++) {
    var days = []
    var thursday = null
    for (var d = 0; d < 7; d++) {
      var cellYear = cursor.getFullYear()
      var cellMonth = cursor.getMonth()
      var cellDay = cursor.getDate()
      var weekday = cursor.getDay()
      var key = dateKey(cellYear, cellMonth, cellDay)
      if (weekday === 4) thursday = { year: cellYear, month: cellMonth, day: cellDay }
      days.push({
        key: key, year: cellYear, month: cellMonth, day: cellDay, weekday: weekday,
        inMonth: cellMonth === month && cellYear === year,
        weekend: weekday === 0 || weekday === 6,
        today: key === today
      })
      cursor.setDate(cursor.getDate() + 1)
    }
    var anchor = thursday || days[0]
    weeks.push({ week: isoWeek(anchor.year, anchor.month, anchor.day), days: days })
  }
  return weeks
}

function weekDays(date, weekStart, todayKey) {
  var start = normalizedWeekStart(weekStart, 1)
  var offset = (date.getDay() - start + 7) % 7
  var first = addDays(startOfDay(date), -offset)
  var today = String(todayKey || "")
  var days = []
  for (var i = 0; i < 7; i++) {
    var cursor = addDays(first, i)
    var key = keyForDate(cursor)
    days.push({
      key: key, date: cursor,
      year: cursor.getFullYear(), month: cursor.getMonth(), day: cursor.getDate(),
      weekday: cursor.getDay(),
      weekend: cursor.getDay() === 0 || cursor.getDay() === 6,
      today: key === today
    })
  }
  return days
}

function weekNumberOf(date, weekStart) {
  var days = weekDays(date, weekStart, "")
  for (var i = 0; i < days.length; i++)
    if (days[i].weekday === 4) return isoWeek(days[i].year, days[i].month, days[i].day)
  return isoWeek(days[0].year, days[0].month, days[0].day)
}

function parseStamp(text) {
  var value = String(text || "")
  var bare = value.match(/^(\d{4})-(\d{2})-(\d{2})$/)
  if (bare)
    return new Date(Number(bare[1]), Number(bare[2]) - 1, Number(bare[3]))
  var parsed = new Date(value)
  return isNaN(parsed.getTime()) ? null : parsed
}

function parseEvent(raw) {
  if (!raw) return null
  var start = parseStamp(raw.start)
  if (!start) return null
  var end = parseStamp(raw.end) || start

  var allDay = raw.allDay === true
  var lastDate = allDay ? addDays(end, -1) : end
  if (allDay && lastDate.getTime() < start.getTime()) lastDate = start

  return {
    uid: String(raw.uid || ""),
    title: String(raw.title || "").replace(/^\s+|\s+$/g, "") || "(no title)",
    location: String(raw.location || ""),
    description: String(raw.description || ""),
    calendar: String(raw.calendar || ""),
    color: String(raw.color || ""),
    cancelled: String(raw.status || "").toUpperCase() === "CANCELLED",
    allDay: allDay,
    start: start,
    end: end,
    lastDate: lastDate,
    startMs: start.getTime(),
    endMs: end.getTime(),
    multiDay: keyForDate(start) !== keyForDate(lastDate)
  }
}

function parseEvents(list) {
  var out = []
  if (!list || typeof list.length !== "number") return out
  for (var i = 0; i < list.length; i++) {
    var event = parseEvent(list[i])
    if (event) out.push(event)
  }
  out.sort(function (a, b) {
    if (a.allDay !== b.allDay) return a.allDay ? -1 : 1
    return a.startMs - b.startMs || a.title.localeCompare(b.title)
  })
  return out
}

function bucketByDay(events) {
  var buckets = {}
  if (!events) return buckets
  for (var i = 0; i < events.length; i++) {
    var event = events[i]
    var cursor = startOfDay(event.start)
    var last = startOfDay(event.lastDate)
    if (!event.allDay && event.endMs === last.getTime() && event.endMs > event.startMs)
      last = addDays(last, -1)
    if (last.getTime() < cursor.getTime()) last = cursor

    var guard = 0
    while (cursor.getTime() <= last.getTime() && guard++ < 400) {
      var key = keyForDate(cursor)
      if (!buckets[key]) buckets[key] = []
      buckets[key].push(event)
      cursor = addDays(cursor, 1)
    }
  }
  return buckets
}

function eventsOn(buckets, key) {
  return (buckets && buckets[key]) ? buckets[key] : []
}

var SOON_MS = 16 * 3600 * 1000

function allDayEndMs(event) {
  return startOfDay(event.lastDate).getTime() + MS_PER_DAY
}

function hasEnded(event, stamp) {
  return (event.allDay ? allDayEndMs(event) : event.endMs) <= stamp
}

function nextUpcoming(events, now) {
  if (!events) return null
  var stamp = now.getTime()

  var timed = null
  for (var i = 0; i < events.length; i++) {
    var event = events[i]
    if (event.cancelled || event.allDay || hasEnded(event, stamp)) continue
    if (event.startMs > stamp + SOON_MS) continue
    if (!timed) timed = event
    else if (event.startMs <= stamp && timed.startMs <= stamp) {
      if (event.endMs < timed.endMs) timed = event
    } else if (event.startMs < timed.startMs) timed = event
  }
  if (timed) return timed

  var best = null
  for (var j = 0; j < events.length; j++) {
    var candidate = events[j]
    if (candidate.cancelled || hasEnded(candidate, stamp)) continue
    if (!best) best = candidate
    else if (candidate.startMs < best.startMs) best = candidate
  }
  return best
}

function allDayOn(buckets, key) {
  var out = []
  var list = eventsOn(buckets, key)
  for (var i = 0; i < list.length; i++) if (list[i].allDay) out.push(list[i])
  return out
}

function timedOn(buckets, key) {
  var out = []
  var list = eventsOn(buckets, key)
  for (var i = 0; i < list.length; i++) if (!list[i].allDay) out.push(list[i])
  return out
}

function relativeLabel(event, now) {
  if (!event) return ""
  var stamp = now.getTime()
  var today = startOfDay(now).getTime()
  var eventDay = startOfDay(event.start).getTime()
  var dayGap = Math.round((eventDay - today) / MS_PER_DAY)

  if (event.allDay) {
    if (dayGap > 0) return dayGap === 1 ? "tomorrow" : "in " + dayGap + " days"
    if (allDayEndMs(event) <= stamp) return "ended"
    var lastDay = startOfDay(event.lastDate).getTime()
    var remaining = Math.round((lastDay - today) / MS_PER_DAY)
    if (remaining <= 0) return "today"
    return remaining === 1 ? "until tomorrow" : remaining + " days left"
  }

  if (event.startMs <= stamp && event.endMs > stamp) return "now"

  var minutes = Math.round((event.startMs - stamp) / MS_PER_MINUTE)
  if (minutes < 0) return "ended"
  if (minutes < 1) return "starting"
  if (minutes < 60) return "in " + minutes + " min"

  if (dayGap === 0) {
    var hours = Math.floor(minutes / 60)
    var rest = minutes % 60
    return "in " + hours + " h" + (rest ? " " + rest + " min" : "")
  }
  if (dayGap === 1) return "tomorrow"
  if (dayGap <= 30) return "in " + dayGap + " days"
  return ""
}

function minutesOfDay(date) {
  return date.getHours() * 60 + date.getMinutes()
}

function daySegment(event, dayDate, dayStartHour, dayEndHour) {
  var windowStart = dayStartHour * 60
  var windowEnd = dayEndHour * 60
  var span = windowEnd - windowStart
  if (span <= 0) return null

  var dayBegin = startOfDay(dayDate).getTime()
  var dayEnd = dayBegin + MS_PER_DAY
  if (event.endMs <= dayBegin || event.startMs >= dayEnd) return null

  var from = Math.max(event.startMs, dayBegin)
  var to = Math.min(event.endMs, dayEnd)
  var fromMinutes = Math.round((from - dayBegin) / MS_PER_MINUTE)
  var toMinutes = Math.round((to - dayBegin) / MS_PER_MINUTE)

  var clippedTop = Math.max(fromMinutes, windowStart)
  var clippedBottom = Math.min(Math.max(toMinutes, fromMinutes), windowEnd)
  if (clippedBottom <= clippedTop) {
    if (toMinutes <= windowStart) { clippedTop = windowStart; clippedBottom = windowStart }
    else if (fromMinutes >= windowEnd) { clippedTop = windowEnd; clippedBottom = windowEnd }
  }

  return {
    event: event,
    top: (clippedTop - windowStart) / span,
    height: (clippedBottom - clippedTop) / span,
    continuesBefore: fromMinutes < windowStart || event.startMs < dayBegin,
    continuesAfter: toMinutes > windowEnd || event.endMs > dayEnd,
    startMinutes: fromMinutes,
    endMinutes: toMinutes
  }
}

function layoutDay(segments) {
  if (!segments || !segments.length) return []
  var sorted = segments.slice().sort(function (a, b) {
    return a.startMinutes - b.startMinutes || b.endMinutes - a.endMinutes
  })

  var placed = []
  var cluster = []
  var clusterEnd = -1
  var columnEnds = []

  function flush() {
    for (var i = 0; i < cluster.length; i++) cluster[i].columns = columnEnds.length || 1
    cluster = []
    columnEnds = []
    clusterEnd = -1
  }

  for (var s = 0; s < sorted.length; s++) {
    var item = sorted[s]
    var itemEnd = Math.max(item.endMinutes, item.startMinutes + 1)
    if (clusterEnd >= 0 && item.startMinutes >= clusterEnd) flush()

    var column = -1
    for (var c = 0; c < columnEnds.length; c++) {
      if (item.startMinutes >= columnEnds[c]) { column = c; break }
    }
    if (column < 0) { column = columnEnds.length; columnEnds.push(0) }
    columnEnds[column] = itemEnd

    item.column = column
    cluster.push(item)
    placed.push(item)
    clusterEnd = Math.max(clusterEnd, itemEnd)
  }
  flush()
  return placed
}

function weekLayout(buckets, days, dayStartHour, dayEndHour) {
  var columns = []
  for (var d = 0; d < days.length; d++) {
    var day = days[d]
    var segments = []
    var timed = timedOn(buckets, day.key)
    for (var i = 0; i < timed.length; i++) {
      var segment = daySegment(timed[i], day.date, dayStartHour, dayEndHour)
      if (segment) segments.push(segment)
    }
    columns.push({ day: day, segments: layoutDay(segments), allDay: allDayOn(buckets, day.key) })
  }
  return columns
}

function visibleHours(buckets, days, dayStartHour, dayEndHour) {
  var first = dayStartHour
  var last = dayEndHour
  for (var d = 0; d < days.length; d++) {
    var timed = timedOn(buckets, days[d].key)
    for (var i = 0; i < timed.length; i++) {
      var event = timed[i]
      if (keyForDate(event.start) === days[d].key)
        first = Math.min(first, event.start.getHours())
      if (event.endMs > event.startMs) {
        var endDate = new Date(event.endMs)
        if (keyForDate(endDate) === days[d].key)
          last = Math.max(last, endDate.getHours() + (endDate.getMinutes() ? 1 : 0))
      }
    }
  }
  return { start: Math.max(0, Math.min(first, 23)), end: Math.min(24, Math.max(last, first + 1)) }
}

function upcoming(events, now) {
  if (!events) return []
  var stamp = now.getTime()
  var out = []
  for (var i = 0; i < events.length; i++) {
    var event = events[i]
    if (hasEnded(event, stamp)) continue
    out.push(event)
  }
  out.sort(function (a, b) {
    return a.startMs - b.startMs
      || (a.allDay === b.allDay ? 0 : (a.allDay ? -1 : 1))
      || a.title.localeCompare(b.title)
  })
  return out
}

function groupByMonth(events) {
  var groups = []
  var current = null
  for (var i = 0; i < events.length; i++) {
    var event = events[i]
    var year = event.start.getFullYear()
    var month = event.start.getMonth()
    if (!current || current.year !== year || current.month !== month) {
      current = { year: year, month: month, key: year + "-" + pad2(month + 1), events: [] }
      groups.push(current)
    }
    current.events.push(event)
  }
  return groups
}

function parseTime(text) {
  var raw = String(text || "").replace(/^\s+|\s+$/g, "")
  if (raw === "") return null

  var match = raw.match(/^(\d{1,2})\s*[:.h]\s*(\d{1,2})$/)
  if (!match) {
    var digits = raw.match(/^(\d{1,4})$/)
    if (!digits) return null
    var value = digits[1]
    if (value.length <= 2) match = [null, value, "0"]
    else if (value.length === 3) match = [null, value.substr(0, 1), value.substr(1)]
    else match = [null, value.substr(0, 2), value.substr(2)]
  }

  var hour = parseInt(match[1], 10)
  var minute = parseInt(match[2], 10)
  if (!isFinite(hour) || !isFinite(minute)) return null
  if (hour > 23 || minute > 59) return null

  return { hour: hour, minute: minute, text: pad2(hour) + ":" + pad2(minute) }
}

function nextSlot(now) {
  var slot = new Date(now.getTime())
  slot.setSeconds(0, 0)
  slot.setMinutes(slot.getMinutes() > 30 ? 60 : 30)
  return { hour: slot.getHours(), minute: slot.getMinutes(), text: pad2(slot.getHours()) + ":" + pad2(slot.getMinutes()) }
}

function emptyState() {
  return {
    ok: false, configured: false, stale: false, error: "",
    feeds: [], events: [], generatedAt: null
  }
}

function readPayload(text) {
  var state = emptyState()
  if (!text) return state
  var raw
  try {
    raw = JSON.parse(text)
  } catch (e) {
    state.error = "backend returned unparseable output"
    return state
  }
  if (!raw || typeof raw !== "object") return state

  var feeds = raw.feeds || []
  var stale = false
  for (var i = 0; i < feeds.length; i++) if (feeds[i].stale || !feeds[i].ok) stale = true

  state.ok = raw.ok === true
  state.configured = raw.configured === true
  state.error = String(raw.error || "")
  state.feeds = feeds
  state.stale = stale
  state.events = parseEvents(raw.events)
  state.generatedAt = parseStamp(raw.generatedAt)
  state.feedsFile = String(raw.feedsFile || "")
  return state
}

function firstFeedError(feeds) {
  if (!feeds) return ""
  for (var i = 0; i < feeds.length; i++) {
    if (feeds[i] && feeds[i].error) {
      var name = feeds[i].name || "Calendar"
      return name + ": " + feeds[i].error
    }
  }
  return ""
}

if (typeof module !== "undefined") {
  module.exports = {
    dateKey: dateKey, keyForDate: keyForDate, isoWeek: isoWeek,
    normalizedWeekStart: normalizedWeekStart, toggledWeekStart: toggledWeekStart,
    weekStartSettingName: weekStartSettingName, weekdayOrder: weekdayOrder,
    monthGrid: monthGrid, stepMonth: stepMonth, weekDays: weekDays,
    weekNumberOf: weekNumberOf, startOfDay: startOfDay, addDays: addDays,
    parseStamp: parseStamp, parseEvent: parseEvent, parseEvents: parseEvents,
    bucketByDay: bucketByDay, eventsOn: eventsOn, allDayOn: allDayOn, timedOn: timedOn,
    nextUpcoming: nextUpcoming, relativeLabel: relativeLabel,
    upcoming: upcoming, groupByMonth: groupByMonth, hasEnded: hasEnded,
    daySegment: daySegment, layoutDay: layoutDay, weekLayout: weekLayout,
    visibleHours: visibleHours, minutesOfDay: minutesOfDay,
    parseTime: parseTime, nextSlot: nextSlot,
    readPayload: readPayload, firstFeedError: firstFeedError, emptyState: emptyState
  }
}
