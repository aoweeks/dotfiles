-- User animation overrides
-- These bezier curves and animation rules override the defaults from hyprland/animations.lua

-- Override animation curves
hl.curve("specialWorkSwitch", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("emphasizedAccel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
hl.curve("emphasizedDecel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("standard", { type = "bezier", points = { { 0.2, 0 }, { 0, 1 } } })

-- Override animation configs
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "emphasizedDecel", style = "slidevert" })
hl.animation({
    leaf    = "specialWorkspace",
    enabled = true,
    speed   = 3,
    bezier  = "emphasizedDecel",
    style   = "slidefadevert -20%",
})
