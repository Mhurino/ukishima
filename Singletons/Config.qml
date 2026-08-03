pragma Singleton
import QtQuick
import Quickshell

/**
 * Path authority for the pill, kept as one self-locating source of truth. The
 * app root is this file's own directory tree (the quickshell project folder),
 * so nothing depends on where the shell was launched from or on exported
 * UKISHIMA_* environment variables. Hyprland-compat outputs (generated modules/*,
 * hypridle.conf, hyprsunset.conf and scripts/) all resolve under the same
 * project folder; user state and caches land under the standard XDG dirs in
 * the pill's own namespace.
 */
Singleton {
    id: root

    /** Absolute filesystem path of the quickshell project folder (parent of Singletons/). */
    readonly property string configDir: {
        var p = root._localPath(Qt.resolvedUrl("../"));
        return p.length > 1 && p.slice(-1) === "/" ? p.slice(0, -1) : p;
    }

    readonly property string _app: configDir
    readonly property string _hypr: configDir
    readonly property string _state: root._xdgDir("XDG_STATE_HOME", "/.local/state") + "/ukishima"
    readonly property string _cache: root._xdgDir("XDG_CACHE_HOME", "/.cache") + "/ukishima"

    function _localPath(url) {
        var s = String(url);
        if (s.indexOf("file://") === 0) {
            s = s.substring(7);
            try { s = decodeURIComponent(s); } catch (e) {}
        }
        return s;
    }

    function _xdgDir(name, suffix) {
        var v = Quickshell.env(name);
        if (v !== undefined && v !== null && String(v).length > 0)
            return String(v);
        return (Quickshell.env("HOME") || "") + suffix;
    }

    function env(name, fallback) {
        var v = Quickshell.env(name);
        if (v !== undefined && v !== null && String(v).length > 0)
            return String(v);
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

    function appConfigRoot() { return root._app; }
    function hyprConfigRoot() { return root._hypr; }
    function stateRoot() { return root._state; }
    function cacheRoot() { return root._cache; }

    function hyprPath() {
        var parts = Array.prototype.slice.call(arguments);
        if (parts.length > 0 && parts[0] === root._hypr)
            return root.join(root._hypr, parts.slice(1));
        return root.join(root._hypr, parts);
    }

    function scriptPath(name) {
        return root.hyprPath(root._hypr, "scripts", name);
    }

    function statePath() {
        var base = arguments.length > 0 ? arguments[0] : root._state;
        return root.join(base, Array.prototype.slice.call(arguments, 1));
    }

    function cachePath() {
        var base = arguments.length > 0 ? arguments[0] : root._cache;
        return root.join(base, Array.prototype.slice.call(arguments, 1));
    }

    function appPath() {
        var base = arguments.length > 0 ? arguments[0] : root._app;
        return root.join(base, Array.prototype.slice.call(arguments, 1));
    }
}
