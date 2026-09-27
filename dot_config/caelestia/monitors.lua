local M = {}

local function get_client_monitor_name(client)
    if type(client.monitor) == "string" then
        return client.monitor
    elseif type(client.monitor) == "table" and client.monitor.name then
        return client.monitor.name
    elseif type(client.monitor) == "number" then
        local f = io.popen("hyprctl monitors all -j")
        if f then
            local content = f:read("*a")
            f:close()
            for id, name in content:gmatch('"id":%s*(%d+),%s*"name":%s*"([^"]+)"') do
                if tonumber(id) == client.monitor then
                    return name
                end
            end
        end
    end
    return nil
end

local function migrate_windows(target_mon)
    local clients = hl.get_windows()
    for _, client in ipairs(clients) do
        if get_client_monitor_name(client) == "eDP-1" then
            pcall(function() hl.dispatch(hl.dsp.window.move({ monitor = target_mon, window = "address:" .. client.address })) end)
        end
    end
    pcall(function() hl.dispatch(hl.dsp.focus({ monitor = target_mon })) end)
end

-- Define global functions so our bash daemon can safely call them via hyprctl eval
-- This completely bypasses the hyprland-lua plugin's bugged interceptor for hyprctl dispatch

function caelestia_migrate_workspaces(target_mon)
    if target_mon and target_mon ~= "" then
        local workspaces = hl.get_workspaces()
        for _, ws in ipairs(workspaces) do
            if ws.monitor.name == "eDP-1" and not string.match(ws.name, "special:") then
                pcall(function() hl.dispatch(hl.dsp.workspace.move({ monitor = target_mon, workspace = ws.name })) end)
            end
        end
    end
end

function caelestia_focus_monitor(target_mon)
    if target_mon and target_mon ~= "" then
        pcall(function() hl.dispatch(hl.dsp.focus({ monitor = target_mon })) end)
    end
end

function caelestia_dpms_off(monitor_name)
    if monitor_name and monitor_name ~= "" then
        pcall(function() hl.dispatch(hl.dsp.dpms({ action = "off", monitor = monitor_name })) end)
    end
end

function caelestia_dpms_on(monitor_name)
    if monitor_name and monitor_name ~= "" then
        pcall(function() hl.dispatch(hl.dsp.dpms({ action = "on", monitor = monitor_name })) end)
    end
end

return M
