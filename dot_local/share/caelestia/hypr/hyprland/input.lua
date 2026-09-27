local vars = require("variables")

hl.config({
    input = {
        kb_layout          = "us",
        numlock_by_default = false,
        repeat_delay       = 250,
        repeat_rate        = vars.repeatRate,
        focus_on_close     = 1,

        touchpad           = {
            natural_scroll       = true,
            disable_while_typing = vars.touchpadDisableTyping,
            tap_to_click         = vars.touchpadTapToClick,
            scroll_factor        = vars.touchpadScrollFactor,
        },
    },

    binds = {
        scroll_event_delay = 0,
    },

    cursor = {
        hotspot_padding = 1,
    },
})
