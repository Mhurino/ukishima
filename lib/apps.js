/**
 * Shared application helpers.
 *
 * Resolves a Hyprland window class/app id to the corresponding
 * Quickshell DesktopEntry.
 */

function normalizeClass(cls) {
    return String(cls)
        .replace(/\[(.)(.)\]/g, "$2")
        .toLowerCase()
        .replace(/[^a-z0-9]/g, "");
}

function allEntries(apps) {
    var src = apps || [];
    var out = [];

    for (var i = 0; i < src.length; i++) {
        if (src[i] && !src[i].noDisplay)
            out.push(src[i]);
    }

    return out;
}

function resolveEntry(cls, apps) {
    var want = normalizeClass(cls);

    if (want.length === 0)
        return null;

    var entries = allEntries(apps);

    // 1. Exact normalized match.
    for (var i = 0; i < entries.length; i++) {
        var entry = entries[i];
        if (!entry)
            continue;

        var candidates = [
            entry.startupClass,
            entry.id,
            entry.name
        ];

        for (var j = 0; j < candidates.length; j++) {
            if (candidates[j] &&
                normalizeClass(candidates[j]) === want) {
                return entry;
            }
        }
    }

    // 2. Normalized substring fallback.
    // Prefer the longest matching desktop field.
    var best = null;
    var bestLen = 0;

    for (var k = 0; k < entries.length; k++) {
        var entry2 = entries[k];
        if (!entry2)
            continue;

        var candidates2 = [
            entry2.startupClass,
            entry2.id,
            entry2.name
        ];

        for (var n = 0; n < candidates2.length; n++) {
            if (!candidates2[n])
                continue;

            var got = normalizeClass(candidates2[n]);

            if (got.length < 4)
                continue;

            var hit =
                (want.length >= 4 && got.indexOf(want) !== -1) ||
                want.indexOf(got) !== -1;

            if (hit && got.length > bestLen) {
                best = entry2;
                bestLen = got.length;
            }
        }
    }

    return best;
}

function resolveEntryById(id, apps) {
    if (!id)
        return null;

    var target = String(id).toLowerCase();
    var entries = allEntries(apps);

    for (var i = 0; i < entries.length; i++) {
        var entry = entries[i];
        if (!entry || !entry.id)
            continue;

        if (String(entry.id).toLowerCase() === target)
            return entry;
    }

    return null;
}
