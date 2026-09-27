-- User keybind overrides
local vars = require("variables")

local launchHere        = "SUPER + ALT"
local variant           = "SUPER + SHIFT"
local variantLaunchHere = "SUPER + ALT + SHIFT"
local hyper             = "SUPER + CTRL + ALT + SHIFT"


-- Send Shortcuts
-- ==============
-- Hyper + 1-9  
for i = 10, 18 do -- keycodes for number keys 1-9
	hl.bind(hyper .. " + code:" .. tostring(i), function()
		hl.dispatch(hl.dsp.send_shortcut({ mods = "", key = "code:" .. tostring(i), window = "class:antigravity" }) )
		hl.dispatch(hl.dsp.send_shortcut({ mods = "", key = "Return", window = "class:antigravity" }) )
	end )
end

hl.bind(hyper .. " + equal", hl.dsp.pass({ window = "class:" .. vars.editor }))
hl.bind(hyper .. " + minus", hl.dsp.pass({ window = "class:" .. vars.editor }))



-- Window Actions
-- ==============
-- Fullscreen
hl.unbind("SCROLL_LOCK")
hl.bind("SCROLL_LOCK", hl.dsp.window.fullscreen(), { locked = true })
-- Resize
hl.unbind("SUPER + equal")
hl.bind("SUPER + equal", hl.dsp.window.resize({ x = 50, y = 0, relative = true }), { repeating = true })
hl.unbind("SUPER + minus")
hl.bind("SUPER + minus", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true })
hl.unbind("SUPER + plus")
hl.bind("SUPER + plus", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { repeating = true })
hl.unbind(variant .. " + minus")
hl.bind(variant .. " + minus", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true })
-- Move To Workspace
hl.unbind(launchHere .. " + up")
hl.bind(launchHere .. " + up", hl.dsp.window.move({ workspace = "-1" }), { locked = true })
hl.unbind(launchHere .. " + down")
hl.bind(launchHere .. " + down", hl.dsp.window.move({ workspace = "+1" }), { locked = true })
-- Float
-- hl.unbind("SYSREQ")
-- hl.bind("SYS_RQ", hl.dsp.window.float(), { locked = true })


-- Pointer Speed (F13 to slow down, Shift+F13 to restore)
-- Kanata natively sends F13 on press, and Shift+F13 on physical release, 
-- bypassing Hyprland's bindr suppression completely!
local f13_mods = {
    "", "CTRL + ", "ALT + ", "SUPER + ",
    "CTRL + ALT + ", "CTRL + SUPER + ", "ALT + SUPER + ",
    "CTRL + ALT + SUPER + "
}

for _, mod in ipairs(f13_mods) do
    -- Slow down cursor when F13 is pressed (Kanata hold)
    -- Key repeat speed is handled by the caelestia-repeat daemon, not Hyprland
    hl.bind(mod .. "F13", function()
        hl.config({ input = { sensitivity = -2 } })
    end)
    
    -- Restore cursor speed when Shift+F13 is received (Kanata release hook)
    hl.bind(mod .. "SHIFT + F13", function()
        hl.config({ input = { sensitivity = 0 } })
    end)
end

-- Playerctl Commands (F15 and mods)
hl.bind("F15", hl.dsp.exec_cmd("playerctl position 10+"))
hl.bind("SHIFT + F15", hl.dsp.exec_cmd("playerctl position 30+"))

-- Terminals
hl.unbind("SUPER + T")
hl.bind("SUPER + T", hl.dsp.exec_cmd("~/.config/caelestia/scripts/hyprfocus.sh --client \"kitty\" --launcher \"kitty\""), { release = true })
hl.bind(launchHere .. " + T", hl.dsp.exec_cmd("app2unit -- kitty"), { release = true })
hl.unbind("PAUSE")
hl.bind("PAUSE", hl.dsp.exec_cmd("caelestia toggle terminal"))

-- Game Engines
hl.unbind("SUPER + G")
hl.bind("SUPER + G", hl.dsp.exec_cmd("~/.config/caelestia/scripts/hyprfocus.sh --client \"Godot\" --launcher \"godot\""))
hl.bind(launchHere .. " + G", hl.dsp.exec_cmd("app2unit -- godot"), { release = true })

-- Code Editors
hl.unbind("SUPER + C")
hl.unbind(launchHere .. " + C")
hl.bind("SUPER + C", hl.dsp.exec_cmd("~/.config/caelestia/scripts/hyprfocus.sh --client \"" .. vars.editor .. "\" --launcher \"" .. vars.editor .. "\""))
hl.bind(launchHere .. " + C", hl.dsp.exec_cmd("app2unit -- " .. vars.editor), { release = true })

-- Web Browsers
hl.unbind("SUPER + W")
hl.bind("SUPER + W", hl.dsp.exec_cmd("~/.config/caelestia/scripts/hyprfocus.sh --client \"zen\" --launcher \"zen-browser\""))
hl.bind(launchHere .. " + W", hl.dsp.exec_cmd("app2unit -- zen-browser"), { release = true })
hl.bind(variant .. " + W", hl.dsp.exec_cmd("~/.config/caelestia/scripts/hyprfocus.sh --client \"vivaldi-stable\" --launcher \"vivaldi\""))
hl.bind(variantLaunchHere .. " + W", hl.dsp.exec_cmd("app2unit -- vivaldi"), { release = true })

-- Audio Apps
hl.unbind("SUPER + A")
hl.bind("SUPER + A", hl.dsp.exec_cmd("caelestia toggle audio"), { release = true })

-- Communication Apps
hl.unbind("SUPER + M")
hl.bind("SUPER + M", hl.dsp.exec_cmd("caelestia toggle communication"), { release = true })
hl.unbind("SUPER + E")
hl.bind("SUPER + E", hl.dsp.exec_cmd("~/.config/caelestia/scripts/hyprfocus.sh --client \"thunderbird\" --launcher \"thunderbird\""))

-- Notetaking Apps
hl.unbind("SUPER + O")
hl.bind("SUPER + O", hl.dsp.exec_cmd("~/.config/caelestia/scripts/hyprfocus.sh --client \"obsidian\" --launcher \"obsidian\""), { release = true })
hl.bind(launchHere .. " + O", hl.dsp.exec_cmd("app2unit -- obsidian"), { release = true })
hl.bind(variant .. " + O", hl.dsp.exec_cmd("'~/.config/caelestia/scripts/hyprfocus.sh --client \"obsidian\" --launcher \"obsidian\""))
hl.bind(variantLaunchHere .. " + O", hl.dsp.exec_cmd("app2unit -- obsidian"), { release = true })

-- Todo Apps
hl.unbind("SUPER + S")
hl.bind("SUPER + S", hl.dsp.exec_cmd("caelestia toggle todo"), { release = true })

-- Writing Apps
hl.unbind("SUPER + P")
hl.bind("SUPER + P", hl.dsp.exec_cmd(
    [[fish -c '~/.config/caelestia/scripts/hyprfocus.sh --client "steam_proton" --launcher "~/.wine/drive_c/Program\ Files/Aeon\ Timeline/AeonTimeline.exe"']]
), { release = true })

-- CyberSecurity
hl.unbind("SUPER + B")
hl.bind("SUPER + B", hl.dsp.exec_cmd('~/.config/caelestia/scripts/hyprfocus.sh --client \"burp-StartBurp\" --launcher \"burpsuite\"'))
hl.bind(launchHere .. " + B", hl.dsp.exec_cmd("app2unit -- burpsuite"), { release = true })
hl.bind(variant .. " + B", hl.dsp.exec_cmd('~/.config/caelestia/scripts/hyprfocus.sh --client \"chromium-browser\"'))

-- AI
hl.unbind("SUPER + R")
hl.bind("SUPER + R", hl.dsp.exec_cmd('~/.config/caelestia/scripts/hyprfocus.sh --client \"antigravity\" --launcher \"antigravity\"'))

-- EBooks
hl.unbind("SUPER + L")
hl.bind("SUPER + L", hl.dsp.exec_cmd('~/.config/caelestia/scripts/hyprfocus.sh --client \"calibre\" --launcher \"calibre\"'))
hl.bind(launchHere .. " + L", hl.dsp.exec_cmd("app2unit -- calibre"), { release = true })

-- Discworld
hl.unbind("SUPER + D")
hl.bind("SUPER + D", hl.dsp.exec_cmd(
    '~/.config/caelestia/scripts/hyprfocus.sh --client "discworld" --launcher "kitty --class discworld -e blightmud -c discworld.starturtle.net:4242"'
), { release = true })
hl.bind(launchHere .. " + D", hl.dsp.exec_cmd("app2unit -- 'Discworld MUD'"), { release = true })
hl.bind(variant .. " + D", hl.dsp.exec_cmd(
    '~/.config/caelestia/scripts/hyprfocus.sh --client "clone" --launcher "kitty -e --class clone blightmud -c discworld.starturtle.net:4242"'
), { release = true })
hl.unbind("SUPER + F")
hl.bind("SUPER + F", hl.dsp.exec_cmd("caelestia toggle ftp"), { release = true })

-- ── Safe close (double Super+Q to close) ────────────────────────────────────
local safe_close_script = os.getenv("HOME") .. "/.config/caelestia/scripts/safe-close.sh"
local safe_close_state  = "/tmp/hypr-safe-close-state"

-- Register window rule for safe_close_pending tag using configured warning color
hl.window_rule({
    name         = "safe_close_pending_rule",
    match        = { tag = "safe_close_pending" },
    border_color = vars.closingWindowBorderColour or "rgba(e67e80ee)",
})

hl.unbind("SUPER + Q")
hl.bind("SUPER + Q", hl.dsp.exec_cmd("bash " .. safe_close_script), { release = true })

-- Reset when focus moves away from pending window
hl.on("window.active", function(_win)
    local f = io.open(safe_close_state, "r")
    if not f then return end

    local line = f:read("*l")
    f:close()

    local pending_addr = line and line:match("^([^|]+)")
    if not pending_addr then return end

    local active = hl.get_active_window()
    local current_addr = active and tostring(active.address) or ""

    if current_addr ~= pending_addr then
        hl.exec_cmd("bash " .. safe_close_script .. " --reset")
    end
end)
