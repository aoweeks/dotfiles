-- User configuration overrides
local home = os.getenv("HOME")

hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

hl.config({
    exec_once = {
        "[workspace special:communication silent] kitty --class nchat -e nchat",
    },
    
    input = {
        kb_layout   = "gb",
        kb_options  = "caps:hyper, fkeys:basic_13-24",
        kb_file     = "/home/adam/.config/hypr/keymap.xkb",
        repeat_delay = 500,
    },

    general = {
        resize_on_border = true,

        snap = {
            enabled     = true,
            window_gap  = 50,
            monitor_gap = 50,
            respect_gaps = true,
        },
    },

    decoration = {
        border_part_of_window = false,
        dim_special           = 0.4,
        blur = {
            special = true,
        },
    },

    xwayland = {
        force_zero_scaling = true,
    },

    scrolling = {
        focus_fit_method = 0,
        wrap_focus       = true,
        wrap_swapcol     = true,
    },
})

-- Workspace rules for external monitors (use scrolling layout)
hl.workspace_rule({ workspace = "m:DP-1", layout = "scrolling" })
hl.workspace_rule({ workspace = "m:DP-2", layout = "scrolling" })
hl.workspace_rule({ workspace = "m:DP-3", layout = "scrolling" })
hl.workspace_rule({ workspace = "m:DP-7", layout = "scrolling" })
hl.workspace_rule({ workspace = "m:HDMI-A-1", layout = "scrolling" })
hl.workspace_rule({ workspace = "3", layout = "scrolling" })

-- Default monitor conf
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1.25,
})

hl.monitor({
    output   = "DP-1",
    mode     = "highres",
    position = "auto",
    scale    = 1.25,
})

-- Source user sub-configs
require("monitors")
local fn   = require("hyprland.functions")
local vars = require("variables")
require("animations")
require("rules")
require("keybinds")

-- Vertical workspace swipe gesture
hl.gesture({ fingers = vars.workspaceSwipeFingers, direction = "vertical", action = "workspace" })

-- Per-app column width rules for Scrolling layout
hl.window_rule({ match = { class = "codium|VSCodium|code" }, scrolling_width = 0.7 })
hl.window_rule({ match = { class = "godot|org.godotengine.Godot" }, scrolling_width = 0.7 })
hl.window_rule({ match = { class = "rio|foot|kitty|Alacritty" }, scrolling_width = 0.35 })

-- 3-finger pinch gestures: Toggle Fullscreen
hl.gesture({
    fingers   = 3,
    direction = "pinchin",
    action    = function()
        hl.dispatch(hl.dsp.window.fullscreen())
    end,
})
hl.gesture({
    fingers   = 3,
    direction = "pinchout",
    action    = function()
        hl.dispatch(hl.dsp.window.fullscreen())
    end,
})



