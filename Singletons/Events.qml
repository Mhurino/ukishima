pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Local calendar events, persisted as a plain JSON array beside the session
 * flags (~/.local/state/ukishima/events.json). The in-memory `events` is the
 * source of truth: add/remove mutate it and write the file, which is read back
 * only at startup. The file is deliberately NOT watched — re-reading our own
 * write races the FileView's cached text and dropped the just-added event (it
 * flashed in, then vanished until the next write). The file holds an array
 * of { id, date, endDate, time, endTime, text, recur } with date/endDate as
 * "YYYY-MM-DD". endDate is "" for a single-day entry, otherwise the last day a
 * multi-day span covers. time and endTime may be "" for an all-day or open-ended
 * entry. Because the keys are zero-padded "YYYY-MM-DD", a plain string compare
 * orders and spans dates correctly, so coverage tests need no Date parsing.
 *
 * recur is "" for a one-off, "year" for a yearly entry (a birthday: shows on its
 * month and day in every year, matched on the "MM-DD" tail) or "month" (shows on
 * its day in every month, matched on the "DD" tail). A recurring entry ignores its
 * endDate. Day 31 monthly and Feb 29 yearly only land where the day exists, which
 * is fine for now. On load, entries written before this field are classified once:
 * a birthday-looking title becomes yearly, the legacy yearly flag folds into recur,
 * the rest stay one-off, and the healed list is persisted so it sticks.
 *
 * A bare array is simpler than a JsonAdapter for a growing list: read the text,
 * JSON.parse, mutate the array, JSON.stringify back through setText. Every parse
 * is guarded so a truncated or corrupt file never throws and never wipes the
 * singleton — a bad read just leaves the last good `events` in place.
 *
 * Ids come from a monotonic counter seeded past the highest id already on disk,
 * never Date.now() or Math.random() (both throw in this engine), so every add is
 * uniquely addressable for remove() even within the same minute.
 */
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/pill"

    property var events: []
    property int nextId: 1

    // Timed reminders: 24 hours, 1 hour and 30 minutes before.
    readonly property var reminderMinutes: [1440, 720, 60, 30]

    /**
     * Birthday-looking titles across the languages Erik's contacts use, so a new
     * entry can suggest yearly and old ones get classified on load. Plain substring
     * alternation, case-insensitive; accented forms are caught by a safe stem.
     */
    readonly property var birthdayRe: /geburtstag|geb\.|birthday|b-?day|🎂|cumplea|anniversaire|compleanno|anivers|verjaardag|рожд|誕生|생일|urodziny|do[ğg]um/i

    function isBirthday(t) {
        return root.birthdayRe.test(t || "");
    }

    /**
     * Re-read the file text into `events` and advance the id counter past every
     * id present, so a freshly added event can never collide with one loaded
     * from disk. A FileNotFound or malformed body is treated as an empty list.
     * Entries that predate the recurrence field get classified once and the healed
     * list is written back, so existing birthdays become yearly without a re-entry.
     */
function reloadEvents() {
    var arr = [];
        try {
            var t = file.text();
            if (t && t.trim().length > 0) {
                var parsed = JSON.parse(t);
                if (Array.isArray(parsed))
                    arr = parsed;
            }
        } catch (e) {
            arr = [];
        }
        var maxId = 0;
        var healed = false;
        for (var i = 0; i < arr.length; i++) {
            var n = Number(arr[i].id);
            if (n > maxId)
                maxId = n;
            var e = arr[i];
            if (e.recur === undefined) {
                e.recur = e.yearly === true ? "year" : (root.isBirthday(e.text) ? "year" : "");
                delete e.yearly;
                healed = true;
            }
        }
        root.nextId = maxId + 1;
 root.events = arr;
console.log("UKI EVENTS LOADED:", root.events.length)
        if (healed)
            root.persist();
    }

    function persist() {
        file.setText(JSON.stringify(root.events));
    }

    /** Last day an event covers: its endDate, or its start when single-day. */
    function lastDay(e) {
        return e.endDate && e.endDate.length > 0 ? e.endDate : e.date;
    }

    function covers(e, dateStr) {
        if (e.recur === "year")
            return dateStr.slice(5) === e.date.slice(5);
        if (e.recur === "month")
            return dateStr.slice(8) === e.date.slice(8);
        return dateStr >= e.date && dateStr <= root.lastDay(e);
    }

    /** Events covering `dateStr`, sorted by start time; an empty time sorts first. */
    function forDate(dateStr) {
        var out = root.events.filter(function (e) { return root.covers(e, dateStr); });
        out.sort(function (a, b) {
            var at = a.time || "";
            var bt = b.time || "";
            if (at === bt)
                return 0;
            if (at === "")
                return -1;
            if (bt === "")
                return 1;
            return at < bt ? -1 : 1;
        });
        return out;
    }

    function hasEvents(dateStr) {
        for (var i = 0; i < root.events.length; i++) {
            if (root.covers(root.events[i], dateStr))
                return true;
        }
        return false;
    }

    function dateKeyFromDate(d) {
        var y = d.getFullYear();
        var m = d.getMonth() + 1;
        var day = d.getDate();

        var mm = m < 10 ? "0" + m : "" + m;
        var dd = day < 10 ? "0" + day : "" + day;

        return y + "-" + mm + "-" + dd;
    }

    function reminderState(e) {
        if (!e.reminderState || typeof e.reminderState !== "object")
            e.reminderState = {};

        return e.reminderState;
    }

    function remainingLabel(seconds) {
        var totalMinutes = Math.max(1, Math.ceil(seconds / 60));

        if (totalMinutes >= 1440) {
            var days = Math.floor(totalMinutes / 1440);
            var hours = Math.floor((totalMinutes % 1440) / 60);

            if (hours > 0)
                return "tra " + days + " g " + hours + " h";

            return "tra " + days + " g";
        }

        if (totalMinutes >= 60) {
            var h = Math.floor(totalMinutes / 60);
            var m = totalMinutes % 60;

            if (m > 0)
                return "tra " + h + " h " + m + " min";

            return "tra " + h + " h";
        }

        return "tra " + totalMinutes + " min";
    }

    function notifyEvent(e, reminderKey, label) {
        var title = e.text && String(e.text).trim().length > 0
            ? String(e.text).trim()
            : "Impegno";

        var state = root.reminderState(e);
        state[reminderKey] = true;

        var safeKey = String(reminderKey)
            .replace(/[^a-zA-Z0-9_.-]/g, "_");

        // Atomic directory creation prevents duplicate notifications
        // when two Quickshell instances are running at the same time.
        var script =
            'dir="${XDG_RUNTIME_DIR:-/tmp}/ukishima-calendar-reminders"; ' +
            'mkdir -p "$dir"; ' +
            'if mkdir "$dir/$1" 2>/dev/null; then ' +
            'notify-send --app-name=Ukishima ' +
            '--urgency=normal ' +
            '--icon=office-calendar ' +
            '"Ukishima · Calendario" "$2 · $3"; ' +
            'fi';

        Quickshell.execDetached([
            "sh",
            "-c",
            script,
            "ukishima-calendar-reminder",
            safeKey,
            title,
            label
        ]);
    }

    function checkReminders() {
        var now = new Date();
        var todayKey = root.dateKeyFromDate(now);
        var tomorrow = new Date(
            now.getFullYear(),
            now.getMonth(),
            now.getDate() + 1,
            0,
            0,
            0,
            0
        );
        var tomorrowKey = root.dateKeyFromDate(tomorrow);
        var changed = false;

        for (var i = 0; i < root.events.length; i++) {
            var e = root.events[i];

            if (!e)
                continue;

            var state = root.reminderState(e);
            var occurrenceDate = "";
            var eventStart = null;

            // =================================================
            // ALL DAY
            // L'inizio effettivo è 00:00 del giorno dell'evento.
            // =================================================
            if (!e.time || String(e.time).trim() === "") {

                if (!e.recur) {
                    if (String(e.date || "") !== tomorrowKey)
                        continue;

                    occurrenceDate = tomorrowKey;
                } else {
                    if (!root.covers(e, tomorrowKey))
                        continue;

                    occurrenceDate = tomorrowKey;
                }

                eventStart = new Date(
                    tomorrow.getFullYear(),
                    tomorrow.getMonth(),
                    tomorrow.getDate(),
                    0,
                    0,
                    0,
                    0
                );

            } else {

                // =================================================
                // EVENTO CON ORARIO
                // =================================================

                if (!e.recur) {
                    occurrenceDate = String(e.date || "");

                    if (occurrenceDate !== todayKey)
                        continue;
                } else {
                    if (!root.covers(e, todayKey))
                        continue;

                    occurrenceDate = todayKey;
                }

                var parts = String(e.time).split(":");

                if (parts.length < 2)
                    continue;

                var hour = Number(parts[0]);
                var minute = Number(parts[1]);

                if (!isFinite(hour) || !isFinite(minute))
                    continue;

                if (hour < 0 || hour > 23 || minute < 0 || minute > 59)
                    continue;

                eventStart = new Date(
                    now.getFullYear(),
                    now.getMonth(),
                    now.getDate(),
                    hour,
                    minute,
                    0,
                    0
                );
            }

            if (!eventStart)
                continue;

            var diffSec = Math.floor(
                (eventStart.getTime() - now.getTime()) / 1000
            );

            if (diffSec < 0)
                continue;

            // We check every 30 seconds, so a 90-second window gives
            // enough tolerance without firing an old reminder.
            for (var r = 0; r < root.reminderMinutes.length; r++) {

                var threshold = Number(root.reminderMinutes[r]);
                var thresholdSec = threshold * 60;

                if (diffSec <= thresholdSec
                    && diffSec > thresholdSec - 90) {

                    var reminderKey =
                        String(e.id)
                        + "@"
                        + occurrenceDate
                        + "@"
                        + threshold;

                    if (state[reminderKey])
                        continue;

                    root.notifyEvent(
                        e,
                        reminderKey,
                        root.remainingLabel(diffSec)
                    );

                    changed = true;
                    break;
                }
            }
        }

        if (changed)
            root.persist();
    }

    /** Append an event and persist; reassigns `events` so bindings refresh. */
    function add(dateStr, endDate, time, endTime, text, recur) {
        var next = root.events.slice();
        next.push({
            id: root.nextId,
            date: dateStr,
            endDate: endDate || "",
            time: time || "",
            endTime: endTime || "",
            text: text || "",
            recur: recur || "",
            lastNotifiedKey: ""
        });
        root.nextId += 1;
        root.events = next;
        root.persist();
    }

    function remove(id) {
        root.events = root.events.filter(function (e) { return e.id !== id; });
        root.persist();
    }

Component.onCompleted: {
    console.log("UKI EVENTS START")
    reloadEvents()
    console.log("UKI EVENTS COUNT:", root.events.length)
}

    Timer {
        id: reminderTimer
        interval: 30000
        repeat: true
        running: true

        onTriggered: root.checkReminders()
    }

    FileView {
        id: file
        path: root.stateDir + "/events.json"
        blockLoading: false
        watchChanges: true
        printErrors: false

        onFileChanged: {
            file.reload();
        }

        onLoaded: {
            root.reloadEvents();
            Qt.callLater(root.checkReminders);
        }

        onLoadFailed: function (error) {
            if (error === FileViewError.FileNotFound)
                file.setText("[]");
        }
    }
}
