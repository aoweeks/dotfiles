-- User window, workspace, and layer rules

-----------------------------
---- HyprDark Window Plugin ----
-----------------------------

-- hl.config({
--     plugin = {
--         darkwindow = {
--             load_shaders = "chromakey",
-- 
--             ["shader[chromakey_dark_bg]"] = {
--                 from                    = "chromakey",
--                 args                    = "bkg=[0 0 0] similarity=0.5 amount=0.1 targetOpacity=0.7",
--                 introduces_transparency = true,
--             },
--         },
--     },
-- })

--------------------------
---- Workspace Rules -----
--------------------------

-- Fullscreen Apps (gaps only — border/shadow/opaque are window rule properties)
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 10, gaps_in = 10 })
hl.workspace_rule({ workspace = "w[f1]", gaps_out = 10, gaps_in = 10 })

-- Apply visual overrides to fullscreen windows via window rules
hl.window_rule({ match = { fullscreen = true }, border_size = 0, no_shadow = true, opaque = true })

-- External Monitor
hl.workspace_rule({ workspace = "m[DP-1]", gaps_out = 16, gaps_in = 8 })

-- Special Workspaces
hl.workspace_rule({ workspace = "special:terminal", on_created_empty = "kitty --class dropdown-terminal" })
hl.workspace_rule({ workspace = "special:audio", on_created_empty = "spotify-launcher --skip-update" })
hl.workspace_rule({ workspace = "special:ftp", on_created_empty = "kitty --class termscp -e termscp" })
hl.workspace_rule({ workspace = "special:communication", on_created_empty = "kitty --class nchat -e nchat" })
hl.workspace_rule({ workspace = "special:todo", on_created_empty = "superproductivity" })

--------------------------
---- Window Rules --------
--------------------------

-- Default
hl.window_rule({
    match            = { class = "(.*)" },
    opacity          = "0.99 override 0.75 override 1 override",
    persistent_size  = false,
    center           = false,
})

-- Video Players
hl.window_rule({ match = { class = "vlc|Plex|mpv" }, opacity = "1.0 override", no_dim = true })
hl.window_rule({ match = { title = ".*YouTube.*|.*Udemy.*|Picture-in-Picture" }, opacity = "1.0 override", no_dim = true })

-- Game Engines
hl.window_rule({ match = { initial_title = "Godot" }, tile = true })

-- Code Editors
hl.window_rule({ match = { class = "codium" }, min_size = "800 monitor_h*1" })

-- Dropdown Terminal
hl.window_rule({
    match     = { class = "dropdown-terminal" },
    workspace = "special:terminal",
    float     = true,
    center    = true,
    size      = "1200 monitor_h*0.8",
})

-- FTP
hl.window_rule({
    match     = { class = "termscp" },
    workspace = "special:ftp",
    float     = true,
    center    = true,
    size      = "1780 monitor_h*0.8",
})

-- Sysmon
hl.window_rule({
    match  = { class = "btop" },
    float  = true,
    center = true,
    size   = "1780 1000",
})

-- Communication
hl.window_rule({
    name      = "special-communication-layout-rules",
    match     = { class = "nchat|vesktop" },
    workspace = "special:communication",
    pseudo    = true,
    size      = "monitor_w*0.8 monitor_h*0.8",
})

-- Audio
hl.window_rule({
    name      = "special-music-layout-rules",
    match     = { class = "Spotify|Plexamp|dev.aunetx.deezer|pocket-casts" },
    workspace = "special:audio",
    pseudo    = true,
    size      = "monitor_w*0.5 monitor_h*0.8",
})

hl.window_rule({
    name      = "spotify-wayland-layout-rules",
    match     = { initial_title = "Spotify( Free)?" },
    workspace = "special:audio",
    pseudo    = true,
})

-- Notes
hl.window_rule({
    name      = "special-todo-layout-rules",
    match     = { class = "superproductivity" },
    workspace = "special:todo",
    float     = true,
    center    = true,
    size      = "1780 monitor_h*0.9",
})

--------------------------
---- Lid Switch ----------
--------------------------

-- Lid switch binds (locked so they fire even when screen is locked)
-- Removed Lid Switch binds (now handled natively by monitors.lua)

