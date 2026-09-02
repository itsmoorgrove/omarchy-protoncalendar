var MS_PER_DAY = 86400000
var MS_PER_MINUTE = 60000
var WEEKDAY_NAMES = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
var DATE_NAMES = {
  en: {
    weekdays: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
    weekdaysShort: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
    months: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],
    monthsShort: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  },
  sv: {
    weekdays: ["söndag", "måndag", "tisdag", "onsdag", "torsdag", "fredag", "lördag"],
    weekdaysShort: ["sön", "mån", "tis", "ons", "tors", "fre", "lör"],
    months: ["januari", "februari", "mars", "april", "maj", "juni", "juli", "augusti", "september", "oktober", "november", "december"],
    monthsShort: ["jan", "feb", "mars", "apr", "maj", "juni", "juli", "aug", "sep", "okt", "nov", "dec"]
  }
}
var MEETING_HOSTS = /(meet\.google\.com|zoom\.us|teams\.microsoft\.com|meet\.proton\.me|jitsi\.|whereby\.com|webex\.com)/i
var TEXT = {
  en: {
    allDay: "all day", backToday: "Back to today", calendar: "Calendar",
    calendars: "Calendars", copy: "Copy", copyLocation: "Copy location",
    day: "Day", description: "Description", dismiss: "Dismiss", ended: "ended",
    eventDetails: "Event details", join: "Join meeting", location: "Location",
    monday: "Monday", month: "Month", next: "Next", noEvents: "Nothing scheduled.",
    noResults: "No matching events.", notifications: "Notifications", now: "now",
    openProton: "Open in Proton", organizer: "Organizer", participants: "Participants",
    recurring: "Recurring", refresh: "Refresh", refreshing: "Refreshing…", search: "Search events…",
    settings: "Settings", snooze15: "Snooze 15 min", snooze5: "Snooze 5 min",
    starting: "starting", sunday: "Sunday", today: "today", tomorrow: "tomorrow",
    upcoming: "Upcoming", week: "Week", bar: "Bar", busy: "Busy", free: "Free",
    hideSettings: "Hide settings", lastGoodCopy: "Showing the last good copy — refresh failed.",
    newEvent: "New event", nextDay: "Next day", nextMonth: "Next month",
    nextRefresh: "next", nextWeek: "Next week", noFeed: "Proton Calendar — no feed added yet",
    nothingComingUp: "Nothing coming up", nothingToday: "Nothing today",
    previousDay: "Previous day", previousMonth: "Previous month", previousWeek: "Previous week",
    reminderOff: "Reminder off", selectedDay: "the selected day", startWeeksOn: "Start weeks on",
    updated: "Updated", weekAbbreviation: "W"
  },
  sv: {
    allDay: "hela dagen", backToday: "Tillbaka till idag", calendar: "Kalender",
    calendars: "Kalendrar", copy: "Kopiera", copyLocation: "Kopiera plats",
    day: "Dag", description: "Beskrivning", dismiss: "Stäng", ended: "avslutad",
    eventDetails: "Eventdetaljer", join: "Anslut till möte", location: "Plats",
    monday: "Måndag", month: "Månad", next: "Nästa", noEvents: "Inget planerat.",
    noResults: "Inga matchande event.", notifications: "Notiser", now: "nu",
    openProton: "Öppna i Proton", organizer: "Organisatör", participants: "Deltagare",
    recurring: "Återkommande", refresh: "Uppdatera", refreshing: "Uppdaterar…", search: "Sök event…",
    settings: "Inställningar", snooze15: "Skjut upp 15 min", snooze5: "Skjut upp 5 min",
    starting: "startar", sunday: "Söndag", today: "idag", tomorrow: "imorgon",
    upcoming: "Kommande", week: "Vecka", bar: "Menyrad", busy: "Upptagen", free: "Ledig",
    hideSettings: "Dölj inställningar", lastGoodCopy: "Visar den senaste fungerande kopian — uppdateringen misslyckades.",
    newEvent: "Nytt event", nextDay: "Nästa dag", nextMonth: "Nästa månad",
    nextRefresh: "nästa", nextWeek: "Nästa vecka", noFeed: "Proton Calendar — ingen kalender tillagd",
    nothingComingUp: "Inget kommande", nothingToday: "Inget idag",
    previousDay: "Föregående dag", previousMonth: "Föregående månad", previousWeek: "Föregående vecka",
    reminderOff: "Påminnelse av", selectedDay: "den valda dagen", startWeeksOn: "Starta veckor på",
    updated: "Uppdaterad", weekAbbreviation: "V"
  }
}

function pad2(value) {
  var n = Number(value)
  return (n < 10 ? "0" : "") + n
}

function plainText(value) {
  return String(value === undefined || value === null ? "" : value).replace(/[<>]/g, "")
}

function resolvedLanguage(value, localeName) {
  var configured = String(value || "System").toLowerCase()
  if (configured === "swedish" || configured === "sv") return "sv"
  if (configured === "english" || configured === "en") return "en"
  return String(localeName || "").toLowerCase().indexOf("sv") === 0 ? "sv" : "en"
}

function text(key, language) {
  var lang = language === "sv" ? "sv" : "en"
  return TEXT[lang][key] || TEXT.en[key] || key
}

function weekdayName(index, shortFormat, language) {
  var lang = language === "sv" ? "sv" : "en"
  var day = ((Number(index) % 7) + 7) % 7
  return DATE_NAMES[lang][shortFormat ? "weekdaysShort" : "weekdays"][day]
}

function formatDate(date, pattern, language) {
  if (!date || isNaN(date.getTime())) return ""
  var lang = language === "sv" ? "sv" : "en"
  var names = DATE_NAMES[lang]
  var values = {
    dddd: names.weekdays[date.getDay()], ddd: names.weekdaysShort[date.getDay()],
    MMMM: names.months[date.getMonth()], MMM: names.monthsShort[date.getMonth()],
    yyyy: String(date.getFullYear()), yy: pad2(date.getFullYear() % 100),
    dd: pad2(date.getDate()), d: String(date.getDate())
  }
  return String(pattern || "").replace(/dddd|ddd|MMMM|MMM|yyyy|yy|dd|d/g, function (token) {
    return values[token]
  })
}

function languageSettingLabel(value, language) {
  return labeledValue(value, language, {
    System: { en: "System", sv: "System" }, English: { en: "English", sv: "Engelska" },
    Swedish: { en: "Swedish", sv: "Svenska" }
  })
}

function languageSettingFromLabel(value) {
  return valueFromLabel(value, "", {
    System: { en: "System", sv: "System" }, English: { en: "English", sv: "Engelska" },
    Swedish: { en: "Swedish", sv: "Svenska" }
  }, "System")
}

function timeFormatLabel(value, language) {
  return labeledValue(value, language, {
    System: { en: "System", sv: "System" }, "24-hour": { en: "24-hour", sv: "24-timmars" },
    "12-hour": { en: "12-hour", sv: "12-timmars" }
  })
}

function timeFormatFromLabel(value) {
  return valueFromLabel(value, "", {
    System: { en: "System", sv: "System" }, "24-hour": { en: "24-hour", sv: "24-timmars" },
    "12-hour": { en: "12-hour", sv: "12-timmars" }
  }, "System")
}

function soundLabel(value, language) {
  return labeledValue(value, language, {
    Gentle: { en: "Gentle", sv: "Mjuk" }, Bell: { en: "Bell", sv: "Klocka" },
    Chime: { en: "Chime", sv: "Signal" }, Alarm: { en: "Alarm", sv: "Alarm" }
  })
}

function soundFromLabel(value) {
  return valueFromLabel(value, "", {
    Gentle: { en: "Gentle", sv: "Mjuk" }, Bell: { en: "Bell", sv: "Klocka" },
    Chime: { en: "Chime", sv: "Signal" }, Alarm: { en: "Alarm", sv: "Alarm" }
  }, "Alarm")
}

function reminderPresetLabel(minutes, language) {
  var value = Number(minutes)
  if (value === 15 || value === 30) return value + " min"
  if (value === 60) return language === "sv" ? "1 timme" : "1 hour"
  if (value === 120) return language === "sv" ? "2 timmar" : "2 hours"
  return ""
}

function reminderPresetFromLabel(value) {
  var labels = { "15 min": 15, "30 min": 30, "1 hour": 60, "1 timme": 60,
    "2 hours": 120, "2 timmar": 120 }
  return labels[String(value || "")] || 0
}

function eventCountLabel(count, language) {
  var value = Number(count) || 0
  if (language === "sv") return value + " event"
  return value + (value === 1 ? " event" : " events")
}

function labeledValue(value, language, values) {
  var lang = language === "sv" ? "sv" : "en"
  return values[value] ? values[value][lang] : String(value || "")
}

function valueFromLabel(label, language, values, fallback) {
  var raw = String(label || "")
  for (var value in values)
    if (values[value].en === raw || values[value].sv === raw) return value
  return fallback
}

function viewLabel(value, language) {
  return labeledValue(value, language, {
    Month: { en: "Month", sv: "Månad" }, Week: { en: "Week", sv: "Vecka" },
    Day: { en: "Day", sv: "Dag" }, Upcoming: { en: "Upcoming", sv: "Kommande" }
  })
}

function viewFromLabel(value, fallback) {
  return valueFromLabel(value, "", {
    Month: { en: "Month", sv: "Månad" }, Week: { en: "Week", sv: "Vecka" },
    Day: { en: "Day", sv: "Dag" }, Upcoming: { en: "Upcoming", sv: "Kommande" }
  }, fallback || "Month")
}

function scopeLabel(value, language) {
  return labeledValue(value, language, {
    All: { en: "All", sv: "Alla" }, Today: { en: "Today", sv: "Idag" },
    Week: { en: "Week", sv: "Vecka" }
  })
}

function scopeFromLabel(value) {
  return valueFromLabel(value, "", {
    All: { en: "All", sv: "Alla" }, Today: { en: "Today", sv: "Idag" },
    Week: { en: "Week", sv: "Vecka" }
  }, "All")
}

function barModeLabel(value, language) {
  return labeledValue(value, language, {
    Off: { en: "Off", sv: "Av" }, "Next event": { en: "Next event", sv: "Nästa event" },
    Countdown: { en: "Countdown", sv: "Nedräkning" },
    "Today count": { en: "Today count", sv: "Antal idag" },
    "Current event": { en: "Current event", sv: "Pågående event" },
    Privacy: { en: "Privacy", sv: "Privat" }
  })
}

function barModeFromLabel(value) {
  return valueFromLabel(value, "", {
    Off: { en: "Off", sv: "Av" }, "Next event": { en: "Next event", sv: "Nästa event" },
    Countdown: { en: "Countdown", sv: "Nedräkning" },
    "Today count": { en: "Today count", sv: "Antal idag" },
    "Current event": { en: "Current event", sv: "Pågående event" },
    Privacy: { en: "Privacy", sv: "Privat" }
  }, "Countdown")
}

function formatTime(date, mode) {
  if (!date || isNaN(date.getTime())) return ""
  var hour = date.getHours()
  var minute = pad2(date.getMinutes())
  if (String(mode) === "12-hour") {
    var suffix = hour < 12 ? "AM" : "PM"
    return (hour % 12 || 12) + ":" + minute + " " + suffix
  }
  return pad2(hour) + ":" + minute
}

function validWebUrl(value) {
  var url = String(value || "").replace(/^\s+|\s+$/g, "")
  return /^https:\/\/[^\s]+$/i.test(url) ? url : ""
}

function meetingLinkOf(raw) {
  if (!raw) return ""
  var direct = validWebUrl(raw.url)
  if (direct && MEETING_HOSTS.test(direct)) return direct
  var haystack = [raw.location, raw.description, raw.url].join(" ")
  var links = haystack.match(/https:\/\/[^\s<>()]+/ig) || []
  for (var i = 0; i < links.length; i++) {
    var cleaned = links[i].replace(/[.,;!?]+$/, "")
    if (MEETING_HOSTS.test(cleaned)) return cleaned
  }
  return direct
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
  var name = WEEKDAY_NAMES[normalizedWeekStart(index, 1)]
  return name.charAt(0).toUpperCase() + name.slice(1)
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

  var attendees = []
  var rawAttendees = raw.attendees || []
  if (typeof rawAttendees.length === "number")
    for (var i = 0; i < rawAttendees.length; i++) attendees.push(plainText(rawAttendees[i]))

  var event = {
    uid: String(raw.uid || ""),
    title: plainText(raw.title).replace(/^\s+|\s+$/g, "") || "(no title)",
    location: plainText(raw.location),
    description: plainText(raw.description),
    calendar: plainText(raw.calendar),
    feedId: String(raw.feedId || ""),
    color: String(raw.color || ""),
    url: validWebUrl(raw.url),
    organizer: plainText(raw.organizer),
    attendees: attendees,
    recurring: raw.recurring === true,
    sourceStart: parseStamp(raw.sourceStart),
    sourceEnd: parseStamp(raw.sourceEnd),
    sourceTimezone: plainText(raw.sourceTimezone),
    secondaryStart: parseStamp(raw.secondaryStart),
    secondaryEnd: parseStamp(raw.secondaryEnd),
    secondaryTimezone: plainText(raw.secondaryTimezone),
    cancelled: String(raw.status || "").toUpperCase() === "CANCELLED",
    allDay: allDay,
    start: start,
    end: end,
    lastDate: lastDate,
    startMs: start.getTime(),
    endMs: end.getTime(),
    multiDay: keyForDate(start) !== keyForDate(lastDate)
  }
  event.meetingLink = meetingLinkOf(event)
  return event
}

function reminderKey(event) {
  if (!event) return ""
  return encodeURIComponent(event.uid || event.title) + "@" + event.startMs
}

function reminderMinutes(event, overrides, fallback) {
  var values = reminderMinutesList(event, overrides, [fallback], null)
  return values.length ? values[0] : -1
}

function normalizeMinuteList(value, fallback) {
  if (value === false || value === "off") return []
  var source = value
  if (source === undefined || source === null || source === "") source = fallback
  if (!Array.isArray(source)) source = [source]
  var unique = {}
  var out = []
  for (var i = 0; i < source.length; i++) {
    var parsed = parseInt(source[i], 10)
    if (!isFinite(parsed)) continue
    parsed = Math.max(1, Math.min(10080, parsed))
    if (!unique[parsed]) {
      unique[parsed] = true
      out.push(parsed)
    }
  }
  out.sort(function (a, b) { return b - a })
  return out
}

function reminderMinutesList(event, overrides, fallback, feedDefault) {
  var value = overrides ? overrides[reminderKey(event)] : undefined
  var inherited = feedDefault === undefined || feedDefault === null ? fallback : [feedDefault]
  return normalizeMinuteList(value, inherited)
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

function currentEvent(events, now) {
  var stamp = now.getTime()
  var best = null
  for (var i = 0; events && i < events.length; i++) {
    var event = events[i]
    if (event.cancelled || event.allDay || event.startMs > stamp || event.endMs <= stamp) continue
    if (!best || event.endMs < best.endMs) best = event
  }
  return best
}

function eventProgress(event, now) {
  if (!event || event.allDay || event.endMs <= event.startMs) return 0
  return Math.max(0, Math.min(1, (now.getTime() - event.startMs) / (event.endMs - event.startMs)))
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

function relativeLabel(event, now, language) {
  if (!event) return ""
  var stamp = now.getTime()
  var today = startOfDay(now).getTime()
  var eventDay = startOfDay(event.start).getTime()
  var dayGap = Math.round((eventDay - today) / MS_PER_DAY)

  if (event.allDay) {
    if (dayGap > 0) return dayGap === 1 ? text("tomorrow", language) : (language === "sv" ? "om " + dayGap + " dagar" : "in " + dayGap + " days")
    if (allDayEndMs(event) <= stamp) return text("ended", language)
    var lastDay = startOfDay(event.lastDate).getTime()
    var remaining = Math.round((lastDay - today) / MS_PER_DAY)
    if (remaining <= 0) return text("today", language)
    return remaining === 1 ? (language === "sv" ? "till imorgon" : "until tomorrow")
      : (language === "sv" ? remaining + " dagar kvar" : remaining + " days left")
  }

  if (event.startMs <= stamp && event.endMs > stamp) return text("now", language)

  var minutes = Math.round((event.startMs - stamp) / MS_PER_MINUTE)
  if (minutes < 0) return text("ended", language)
  if (minutes < 1) return text("starting", language)
  if (minutes < 60) return language === "sv" ? "om " + minutes + " min" : "in " + minutes + " min"

  if (dayGap === 0) {
    var hours = Math.floor(minutes / 60)
    var rest = minutes % 60
    return (language === "sv" ? "om " : "in ") + hours + " h" + (rest ? " " + rest + " min" : "")
  }
  if (dayGap === 1) return text("tomorrow", language)
  if (dayGap <= 30) return language === "sv" ? "om " + dayGap + " dagar" : "in " + dayGap + " days"
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

function eventMatches(event, query) {
  var needles = String(query || "").toLowerCase().split(/\s+/).filter(function (needle) {
    return needle !== ""
  })
  if (!needles.length) return true
  var values = [event.title, event.location, event.description, event.calendar,
    event.organizer]
  if (event.attendees) values = values.concat(event.attendees)
  // Whitespace is dropped inside each value, so a query typed without it still
  // lands: "utansluttid" finds "Utan sluttid". The other direction is already
  // covered, since the query is matched one word at a time. Values are squashed
  // before they are joined, so a needle cannot run from one into the next.
  var squashed = []
  for (var v = 0; v < values.length; v++) {
    squashed.push(String(values[v] || "").replace(/\s+/g, ""))
  }
  var haystack = squashed.join(" ").toLowerCase()
  for (var i = 0; i < needles.length; i++) {
    if (haystack.indexOf(needles[i]) < 0) return false
  }
  return true
}

function eventInScope(event, scope, now, weekStart) {
  if (!scope || scope === "All") return true
  var first = scope === "Today" ? startOfDay(now)
    : weekDays(now, weekStart, "")[0].date
  var last = scope === "Today" ? addDays(first, 1) : addDays(first, 7)
  var eventEnd = event.allDay ? allDayEndMs(event) : event.endMs
  return event.startMs < last.getTime() && eventEnd > first.getTime()
}

function filterEvents(events, query, visibleFeeds, scope, now, weekStart) {
  var out = []
  for (var i = 0; events && i < events.length; i++) {
    var event = events[i]
    if (visibleFeeds && visibleFeeds[event.feedId] === false) continue
    if (!eventInScope(event, scope, now || new Date(), weekStart)) continue
    if (eventMatches(event, query)) out.push(event)
  }
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

  var feeds = []
  var stale = false
  var rawFeeds = raw.feeds || []
  for (var i = 0; i < rawFeeds.length; i++) {
    var feed = rawFeeds[i] || {}
    if (feed.stale || !feed.ok) stale = true
    var sanitized = {}
    for (var key in feed) sanitized[key] = feed[key]
    sanitized.name = plainText(feed.name)
    sanitized.error = plainText(feed.error)
    feeds.push(sanitized)
  }

  state.ok = raw.ok === true
  state.configured = raw.configured === true
  state.error = plainText(raw.error)
  state.feeds = feeds
  state.stale = stale
  state.events = parseEvents(raw.events)
  state.generatedAt = parseStamp(raw.generatedAt)
  state.feedsFile = String(raw.feedsFile || "")
  return state
}

function firstFeedError(feeds, language) {
  if (!feeds) return ""
  for (var i = 0; i < feeds.length; i++) {
    if (feeds[i] && feeds[i].error) {
      var name = feeds[i].name || text("calendar", language)
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
    reminderKey: reminderKey, reminderMinutes: reminderMinutes,
    reminderMinutesList: reminderMinutesList, normalizeMinuteList: normalizeMinuteList,
    bucketByDay: bucketByDay, eventsOn: eventsOn, allDayOn: allDayOn, timedOn: timedOn,
    nextUpcoming: nextUpcoming, currentEvent: currentEvent, eventProgress: eventProgress,
    relativeLabel: relativeLabel,
    upcoming: upcoming, groupByMonth: groupByMonth, hasEnded: hasEnded,
    daySegment: daySegment, layoutDay: layoutDay, weekLayout: weekLayout,
    visibleHours: visibleHours, minutesOfDay: minutesOfDay,
    parseTime: parseTime, nextSlot: nextSlot, plainText: plainText,
    resolvedLanguage: resolvedLanguage, text: text, formatTime: formatTime,
    weekdayName: weekdayName, formatDate: formatDate,
    languageSettingLabel: languageSettingLabel, languageSettingFromLabel: languageSettingFromLabel,
    timeFormatLabel: timeFormatLabel, timeFormatFromLabel: timeFormatFromLabel,
    soundLabel: soundLabel, soundFromLabel: soundFromLabel,
    reminderPresetLabel: reminderPresetLabel, reminderPresetFromLabel: reminderPresetFromLabel,
    eventCountLabel: eventCountLabel,
    viewLabel: viewLabel, viewFromLabel: viewFromLabel,
    scopeLabel: scopeLabel, scopeFromLabel: scopeFromLabel,
    barModeLabel: barModeLabel, barModeFromLabel: barModeFromLabel,
    validWebUrl: validWebUrl, meetingLinkOf: meetingLinkOf,
    eventMatches: eventMatches, eventInScope: eventInScope, filterEvents: filterEvents,
    readPayload: readPayload, firstFeedError: firstFeedError, emptyState: emptyState
  }
}
