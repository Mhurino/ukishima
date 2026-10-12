var normalizedFieldsCache = Object.create(null);

function normalizedFields(e) {
    var key = e && e.id ? "$" + String(e.id) : "";
    if (key && normalizedFieldsCache[key])
        return normalizedFieldsCache[key];

    var name = String((e && e.name) || "").toLowerCase();
    var fields = [];
    if (e && e.name) fields.push(String(e.name).toLowerCase());
    if (e && e.genericName) fields.push(String(e.genericName).toLowerCase());
    if (e && e.keywords) {
        for (var i = 0; i < e.keywords.length; i++)
            fields.push(String(e.keywords[i]).toLowerCase());
    }

    var value = { name: name, fields: fields };
    if (key)
        normalizedFieldsCache[key] = value;
    return value;
}

function subsequence(needle, hay) {
    var j = 0;
    for (var i = 0; i < hay.length && j < needle.length; i++)
        if (hay[i] === needle[j]) j++;
    return j === needle.length;
}

function score(e, q) {
    var normalized = normalizedFields(e);
    if (normalized.name.indexOf(q) === 0) return 0;
    var best = 99;
    for (var i = 0; i < normalized.fields.length; i++) {
        var f = normalized.fields[i];
        if (f.indexOf(q) !== -1) { best = 1; break; }
        if (subsequence(q, f)) best = 2;
    }
    return best;
}

function uses(usage, e) {
    if (!usage || !e || !e.id) return 0;
    var c = usage[e.id];
    return typeof c === "number" ? c : 0;
}

function rank(entries, query, usage) {
    usage = usage || {};
    var visible = [];
    for (var i = 0; i < entries.length; i++)
        if (!entries[i].noDisplay) visible.push(entries[i]);

    var q = (query || "").trim().toLowerCase();
    if (q.length === 0)
        return visible.slice().sort(function (a, b) {
            var ua = uses(usage, a);
            var ub = uses(usage, b);
            if (ua !== ub) return ub - ua;
            return normalizedFields(a).name.localeCompare(normalizedFields(b).name);
        });

    var scored = [];
    for (var k = 0; k < visible.length; k++) {
        var s = score(visible[k], q);
        if (s < 99) scored.push({ e: visible[k], s: s });
    }
    scored.sort(function (a, b) {
        if (a.s !== b.s) return a.s - b.s;
        var ua = uses(usage, a.e);
        var ub = uses(usage, b.e);
        if (ua !== ub) return ub - ua;
        return normalizedFields(a.e).name.localeCompare(normalizedFields(b.e).name);
    });
    return scored.map(function (x) { return x.e; });
}
