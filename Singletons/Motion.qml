pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property real mult: Flags.reduceMotion ? 0.4 : 1
    readonly property real styleScale:
        Flags.motionStyle === "snap" ? 0.55
        : Flags.motionStyle === "float" ? 1.45 : 1
    readonly property real durationMult: mult * styleScale
    readonly property int fast:     Math.round(140 * durationMult)
    readonly property int standard: Math.round(300 * durationMult)
    readonly property int morph:    Math.round(600 * durationMult)
    readonly property int shapeshift: Math.round(820 * durationMult)
    readonly property int glide:    Math.round(260 * durationMult)
    readonly property int heat:     Math.round(1100 * durationMult)
    readonly property int easeStandard:
        Flags.motionStyle === "bounce" ? Easing.OutBack
        : Flags.motionStyle === "float" ? Easing.InOutCubic : Easing.OutCubic
    readonly property int easeMorph:
        Flags.motionStyle === "bounce" ? Easing.OutBack
        : Flags.motionStyle === "float" ? Easing.InOutCubic
        : Flags.motionStyle === "snap" ? Easing.OutCubic : Easing.BezierSpline

    /**
     * Liquid morph curve, cubic-bezier(0.16, 1, 0.3, 1). Front-loaded like an
     * exponential chase but with a long, visible settle tail. Use with
     * easeMorph (BezierSpline).
     */
    readonly property var morphCurve: [0.16, 1, 0.3, 1, 1, 1]
    readonly property real rSmall: 7
    readonly property real rTile:  13

    /** Looping scan/pairing breath pulse. */
    readonly property int pulse: Math.round(420 * mult)
}
