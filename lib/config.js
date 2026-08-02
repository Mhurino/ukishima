.pragma library

var home = Quickshell.env("HOME") || "";
var xdgConfig = Quickshell.env("XDG_CONFIG_HOME") || (home ? home + "/.config" : "");
var xdgState = Quickshell.env("XDG_STATE_HOME") || (home ? home + "/.local/state" : "");
var xdgCache = Quickshell.env("XDG_CACHE_HOME") || (home ? home + "/.cache" : "");

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
    return Quickshell.env("PILL_CONFIG_DIR") || (xdgConfig ? xdgConfig + "/pill" : (home ? home + "/.config/pill" : "."));
}

function hyprConfigRoot() {
    return Quickshell.env("PILL_HYPR_CONFIG_DIR") || (xdgConfig ? xdgConfig + "/hypr" : (home ? home + "/.config/hypr" : "."));
}

function stateRoot() {
    return Quickshell.env("PILL_STATE_DIR") || (xdgState || (home ? home + "/.local/state" : "."));
}

function cacheRoot() {
    return Quickshell.env("PILL_CACHE_DIR") || (xdgCache || (home ? home + "/.cache" : "."));
}

function hyprPath() {
    return join(hyprConfigRoot(), Array.prototype.slice.call(arguments));
}

function scriptPath(name) {
    return hyprPath("scripts", name);
}

function statePath() {
    return join(stateRoot(), Array.prototype.slice.call(arguments));
}

function cachePath() {
    return join(cacheRoot(), Array.prototype.slice.call(arguments));
}

function appPath() {
    return join(appConfigRoot(), Array.prototype.slice.call(arguments));
}
