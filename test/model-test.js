const M = require(__dirname + "/../Model.js")
const fs = require("fs")

const payload = M.readPayload(fs.readFileSync(process.argv[2], "utf8"))
let fails = 0
function check(name, actual, expected) {
  const ok = String(actual) === String(expected)
  if (!ok) fails++
  console.log(`${ok ? "ok  " : "FAIL"} ${name}: ${actual}${ok ? "" : "   expected " + expected}`)
}

console.log(`-- payload: configured=${payload.configured} stale=${payload.stale} events=${payload.events.length}`)

const buckets = M.bucketByDay(payload.events)
const byTitle = t => payload.events.filter(e => e.title.includes(t))

// All-day: exclusive DTEND must become an inclusive last date.
const semester = byTitle("Semester")[0]
check("Semester lastDate", M.keyForDate(semester.lastDate), "2026-08-27")
check("Semester spans 4 days", [24,25,26,27].every(d => M.eventsOn(buckets, `2026-08-${d}`).includes(semester)), "true")
check("Semester not on the 28th", M.eventsOn(buckets, "2026-08-28").includes(semester), "false")

const tand = byTitle("tandlakare")[0]
check("single all-day lastDate", M.keyForDate(tand.lastDate), "2026-08-19")
check("single all-day one bucket", M.eventsOn(buckets, "2026-08-20").includes(tand), "false")

// Cross-midnight timed event must show on both days it touches.
const natt = byTitle("Nattpass")[0]
check("Nattpass on start day", M.eventsOn(buckets, "2026-08-21").includes(natt), "true")
check("Nattpass on end day", M.eventsOn(buckets, "2026-08-22").includes(natt), "true")

// DST: a daily 12:00 event stays at 12:00 wall-clock.
const dst = byTitle("sommartidsskiftet")
check("DST occurrences", dst.length, 4)
check("DST hours all 12", dst.every(e => e.start.getHours() === 12), "true")

// nextUpcoming
const before = new Date("2026-08-17T08:00:00+02:00")
check("next at 08:00 on the 17th", M.nextUpcoming(payload.events, before).title, "Standup")
const during = new Date("2026-08-17T09:30:00+02:00")
check("ongoing event wins", M.nextUpcoming(payload.events, during).title, "Standup")
check("relative during = now", M.relativeLabel(M.nextUpcoming(payload.events, during), during), "now")
check("relative 25 min out", M.relativeLabel(byTitle("Standup")[0], new Date("2026-08-17T08:35:00+02:00")), "in 25 min")
check("relative tomorrow", M.relativeLabel(byTitle("Standup")[0], new Date("2026-08-16T12:00:00+02:00")), "tomorrow")
// A timed event within the day outranks an all-day event already running:
// on the evening of the 19th the dentist all-day is under way, but the 11:00
// appointment next morning is the thing you can be late for.
check("timed within the day beats running all-day", M.nextUpcoming(payload.events, new Date("2026-08-19T20:00:00+02:00")).title, "Utan sluttid")
// Same rule from the other side: an all-day event running now still loses to
// a meeting later this evening.
check("evening meeting beats running trip", M.nextUpcoming(payload.events, new Date("2026-08-25T12:00:00+02:00")).title, "Traning")
// But once nothing timed is near, the all-day event is the answer rather than
// "nothing" -- that is the whole content of a trips-and-courses calendar.
check("falls back to all-day", M.nextUpcoming(payload.events, new Date("2026-08-23T12:00:00+02:00")).title, "Semester")
check("running all-day when nothing timed is near", M.nextUpcoming(payload.events, new Date("2026-08-26T12:00:00+02:00")).title, "Semester")
check("finished all-day is skipped", M.nextUpcoming(payload.events, new Date("2026-08-28T12:00:00+02:00")).title, "Traning")

const semesterEvent = byTitle("Semester")[0]
check("all-day relative: days out", M.relativeLabel(semesterEvent, new Date("2026-08-21T12:00:00+02:00")), "in 3 days")
check("all-day relative: tomorrow", M.relativeLabel(semesterEvent, new Date("2026-08-23T12:00:00+02:00")), "tomorrow")
check("all-day relative: running", M.relativeLabel(semesterEvent, new Date("2026-08-25T12:00:00+02:00")), "2 days left")
check("all-day relative: last day", M.relativeLabel(semesterEvent, new Date("2026-08-27T12:00:00+02:00")), "today")
check("all-day never says 00:00-ish 'now'", M.relativeLabel(semesterEvent, new Date("2026-08-24T09:00:00+02:00")), "3 days left")

// Week layout: overlapping events share the width.
const days = M.weekDays(new Date(2026, 7, 18), 1, "")
check("week starts Monday", M.keyForDate(days[0].date), "2026-08-17")
check("ISO week number", M.weekNumberOf(new Date(2026, 7, 18), 1), 34)
const cols = M.weekLayout(buckets, days, 7, 22)
const tue = cols.find(c => c.day.key === "2026-08-18")
check("Tuesday has 2 timed events", tue.segments.length, 2)
check("Tuesday events do not overlap -> 1 column", Math.max(...tue.segments.map(s => s.columns)), 1)

// Synthetic overlap check.
const overlap = M.layoutDay([
  { startMinutes: 600, endMinutes: 720 },
  { startMinutes: 630, endMinutes: 700 },
  { startMinutes: 660, endMinutes: 780 },
  { startMinutes: 900, endMinutes: 960 },
])
check("overlap cluster width", overlap.slice(0, 3).every(s => s.columns === 3), "true")
check("overlap columns distinct", new Set(overlap.slice(0, 3).map(s => s.column)).size, 3)
check("separate cluster is full width", overlap[3].columns, 1)

// Cross-midnight segment clipping.
const friSeg = M.daySegment(natt, new Date(2026, 7, 22), 7, 22)
check("continues from previous day", friSeg.continuesBefore, "true")

// Forgiving time entry.
for (const [input, expected] of [
  ["9", "09:00"], ["09", "09:00"], ["930", "09:30"], ["0930", "09:30"],
  ["9:30", "09:30"], ["9.30", "09:30"], ["9h30", "09:30"], [" 14:05 ", "14:05"],
  ["23:59", "23:59"], ["0", "00:00"],
]) check(`parseTime(${JSON.stringify(input)})`, M.parseTime(input).text, expected)

for (const bad of ["", "abc", "25:00", "9:60", "99999", "-1", "12:3:4"])
  check(`parseTime(${JSON.stringify(bad)}) rejected`, M.parseTime(bad), "null")

check("nextSlot rounds up to :30", M.nextSlot(new Date(2026, 7, 16, 9, 12)).text, "09:30")
check("nextSlot rolls the hour", M.nextSlot(new Date(2026, 7, 16, 9, 41)).text, "10:00")

// Upcoming list: sorted, nothing already finished, running multi-day kept.
{
  const now = new Date("2026-08-25T12:00:00+02:00")
  const list = M.upcoming(payload.events, now)
  check("upcoming is sorted", list.every((e, i) => i === 0 || list[i - 1].startMs <= e.startMs), "true")
  check("upcoming drops finished", list.some(e => e.title === "Standup"), "false")
  check("upcoming keeps running trip", list.some(e => e.title === "Semester"), "true")

  const groups = M.groupByMonth(list)
  check("grouped into months", groups.map(g => g.key).join(","), "2026-08,2026-09,2026-10")
  check("groups cover every event", groups.reduce((n, g) => n + g.events.length, 0), list.length)
  check("group months are ascending", groups.every((g, i) => i === 0 || groups[i - 1].key < g.key), "true")
}

console.log(fails ? `\n${fails} FAILED` : "\nall passed")
process.exit(fails ? 1 : 0)
