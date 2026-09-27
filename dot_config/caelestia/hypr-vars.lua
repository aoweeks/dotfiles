-- User variable overrides
-- These get merged into the base variables table by hyprland.lua
return {
    -- Apps
    terminal                   = "rio",
    browser                    = "zen-browser",
    editor                     = "codium",
    fileExplorer               = "dolphin",

    -- Gaps
    windowGapsOut              = 10,
    windowGapsIn               = 5,
    singleWindowGapsOut        = 0,

    -- Touchpad
    workspaceSwipeFingers      = 3,
    gestureFingers             = 4,
    gestureFingersMore         = 3,

    -- Blur
    blurSize                   = 4,
    blurPasses                 = 3,
    blurSpecialWs              = true,

    -- Shadow
    shadowEnabled              = true,
    shadowRange                = 20,
    shadowRenderPower          = 2,
    shadowColour               = "rgba(00000088)",

    -- Window styling
    windowRounding             = 20,
    windowBorderSize           = 2,
    inactiveWindowBorderColour = "rgba(00000000)",
    activeWindowBorderColour   = "rgba(a7c080ee)",
    closingWindowBorderColour  = "rgba(e67e80ee)",
        

    -- Misc
    volumeStep                 = 5,
    cursorTheme                = "everforest-dark",
    cursorSize                 = 24,

    -- Keybinds
    kbNextWs                   = "CTRL + SUPER + down",
    kbPrevWs                   = "CTRL + SUPER + up",
}
