.pragma library

function env(name, fallback) {
    if (typeof Quickshell !== "undefined" && Quickshell && Quickshell.env) {
        var v = Quickshell.env(name);
        if (v !== undefined && v !== null && String(v).length > 0)
            return String(v);
    }
    return fallback || "";
}

function join(base, parts) {
    var out = String(base || "");
    for (var i = 0; i < parts.length; i++) {
        var next = String(parts[i] || "");
        if (!next)
            continue;
        if (out.length === 0)
            out = next;
        else if (out.slice(-1) === "/")
            out += next.replace(/^\//, "");
        else
            out += "/" + next.replace(/^\//, "");
    }
    return out;
}

function appConfigRoot() {
    var home = env("HOME", "");
    var xdg = env("XDG_CONFIG_HOME", home ? home + "/.config" : "");
    return env("PILL_CONFIG_DIR", xdg ? xdg + "/pill" : (home ? home + "/.config/pill" : "."));
}

function hyprConfigRoot() {
    var home = env("HOME", "");
    var xdg = env("XDG_CONFIG_HOME", home ? home + "/.config" : "");
    return env("PILL_HYPR_CONFIG_DIR", xdg ? xdg + "/pill/hypr" : (home ? home + "/.config/pill/hypr" : "."));
}

function stateRoot() {
    var home = env("HOME", "");
    var xdg = env("XDG_STATE_HOME", home ? home + "/.local/state" : "");
    return env("PILL_STATE_DIR", xdg || (home ? home + "/.local/state" : "."));
}

function cacheRoot() {
    var home = env("HOME", "");
    var xdg = env("XDG_CACHE_HOME", home ? home + "/.cache" : "");
    return env("PILL_CACHE_DIR", xdg || (home ? home + "/.cache" : "."));
}

function hyprPath() {
    var base = arguments.length > 0 ? arguments[0] : hyprConfigRoot();
    return join(base, Array.prototype.slice.call(arguments, 1));
}

function scriptPath(name) {
    return hyprPath(hyprConfigRoot(), "scripts", name);
}

function statePath() {
    var base = arguments.length > 0 ? arguments[0] : stateRoot();
    return join(base, Array.prototype.slice.call(arguments, 1));
}

function cachePath() {
    var base = arguments.length > 0 ? arguments[0] : cacheRoot();
    return join(base, Array.prototype.slice.call(arguments, 1));
}

function appPath() {
    var base = arguments.length > 0 ? arguments[0] : appConfigRoot();
    return join(base, Array.prototype.slice.call(arguments, 1));
}
