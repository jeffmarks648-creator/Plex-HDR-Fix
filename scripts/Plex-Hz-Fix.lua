-- Define the monitor property:
-- TARGET_WIDTHS: the list of width for the monitor regarded as full screen playback.
-- MOVIE_HZ: the Hz supported by the monitor that is multiplier of 24fps and to be changed for fullscreen playback.
-- DESKTOP_HZ: the default Hz of the monitor (0 will be auto-detect, for VRR Monitor, better manually specify it)
--
-- Pls. download ChangeScreenResolution.exe and place it in same directory.
local TARGET_WIDTHS = { 1920, 2560, 3440, 3840, 5120, 7680 }
local MOVIE_HZ = 48
local DESKTOP_HZ = 0

-- Enable/disable the auto-switching
local enabled = true

-- When change width, the Hz fallback will be delayed (in seconds)
local width_change_timeout = 300

local script_path = debug.getinfo(1).source:match("@?(.+[\\/])")
local csr = script_path .. "ChangeScreenResolution.exe"

local is_target_movie = false
local is_hz_shifted = false
local hz_shifted = 0

local function is_fullscreen_width(w)
    for _, width in ipairs(TARGET_WIDTHS) do
        if w == width then return true end
    end
    return false
end

function change_hz(target_hz)
    if not target_hz or target_hz == 0 then return end

    local f = io.open(csr, "r")
    if f then f:close() else 
        mp.osd_message("Missing " .. csr)
        return 
    end

    local display_names = mp.get_property_native("display-names")
    if not display_names or #display_names == 0 then return end
    local current_display = (type(display_names) == "table") and display_names[1] or display_names

    target_hz = tonumber(target_hz)
    if (is_hz_shifted and target_hz ~= hz_shifted) or (not is_hz_shifted and target_hz ~= DESKTOP_HZ) then

        is_hz_shifted = (target_hz ~= DESKTOP_HZ)
            if is_hz_shifted then
                hz_shifted = target_hz
            else
                hz_shifted = 0
        end
        
        local vpy_snapshot = nil        
        local is_actually_playing = not mp.get_property_native("pause") and not mp.get_property_native("core-idle") and mp.get_property_native("video-out-params") ~= nil
        if is_actually_playing then
            mp.set_property_native("pause", true)

            local vf_table = mp.get_property_native("vf")
            for _, vf in ipairs(vf_table) do
                if vf.label == "VAPOUR" and vf.name ~= "null" then
                    vpy_snapshot = vf.name
                    if vf.params then
                        for p_name, p_val in pairs(vf.params) do
                            vpy_snapshot = vpy_snapshot .. ":" .. p_name .. '="' .. p_val .. '"'
                        end
                    end
                    break
                end
            end
            mp.command('vf add @VAPOUR:null')
        end

        mp.command_native({
            name = "subprocess",
            playback_only = false,
            args = {csr, "/d=" .. current_display, "/f=" .. tostring(target_hz)}
        })
        
        local old_vo = mp.get_property("vo")
        mp.set_property("vo", "null")
        mp.set_property("vo", old_vo)
        mp.osd_message("Syncing " .. current_display .. " to " .. target_hz .. "Hz", 2) 

        if is_actually_playing then
            mp.set_property_native("pause", false)

            if vpy_snapshot then
                mp.add_timeout(1, function()
                    mp.command(string.format('vf add @VAPOUR:%s', vpy_snapshot))
                end)
            end
        end
    end
end

local stability_timer = nil

mp.observe_property("osd-width", "number", function(_, width)
    if stability_timer then
        stability_timer:kill()
        stability_timer = nil
    end

    if is_target_movie then
        if enabled then
            if is_fullscreen_width(width) then
                if is_hz_shifted then
                    mp.osd_message("Cinema Mode: Window resumed.", 3)
                end
                stability_timer = mp.add_timeout(1, function()
                    change_hz(MOVIE_HZ)
                    stability_timer = nil
                end)
            elseif width > 0 and not is_fullscreen_width(width) then
                if is_hz_shifted then
                    mp.osd_message("Cinema Mode: Window minimized.\nRestoring Desktop Hz in " .. width_change_timeout .. " sec", 3)
                end
                stability_timer = mp.add_timeout(width_change_timeout, function()
                    change_hz(DESKTOP_HZ)
                    stability_timer = nil
                end)
            end
        end
    end
end)

mp.register_event("file-loaded", function()
    if DESKTOP_HZ == 0 then
        local initial_fps = mp.get_property_number("display-fps", 0)
        if initial_fps > 0 then
            DESKTOP_HZ = initial_fps
        end
    end

    local fps = mp.get_property_number("container-fps") or mp.get_property_number("video-params/fps") or 0
    is_target_movie = (fps > 23 and fps < 25)

    if is_target_movie then
        if enabled then
            mp.add_timeout(0.5, function()
                local w = mp.get_property_number("osd-width", 0)
                if is_fullscreen_width(w) then
                    change_hz(MOVIE_HZ)
                end
            end)
        end
    end
end)

mp.register_event("end-file", function()
    if stability_timer then
        stability_timer:kill()
        stability_timer = nil
    end

    if is_target_movie then
        if enabled then
            change_hz(DESKTOP_HZ)
        end
        is_target_movie= false
    end
end)

mp.register_event("shutdown", function()
    if stability_timer then
        stability_timer:kill()
        stability_timer = nil
    end

    if is_target_movie then
        if enabled then
            change_hz(DESKTOP_HZ)
        end
        is_target_movie= false
    end
end)

local function on_opts_change()
    if stability_timer then
        stability_timer:kill()
        stability_timer = nil
    end

    if is_target_movie then
        if not enabled then
            change_hz(DESKTOP_HZ)
        else
            local w = mp.get_property_number("osd-width", 0)
            if is_fullscreen_width(w) then
                change_hz(MOVIE_HZ)
            end
        end
    end
end

mp.add_key_binding("Q", "Hz-toggle", function()
    enabled = not enabled
    on_opts_change()
    mp.osd_message("Automatic Display Hz: " .. (enabled and "Enabled" or "Disabled"))
end)

mp.add_key_binding("q", "show-hz-toggle", function()
    local status = enabled and "Enabled" or "Disabled"
    local current = is_hz_shifted and MOVIE_HZ or DESKTOP_HZ
    mp.osd_message("Automatic Display Hz: " .. status .. " (" .. current .. "Hz)")
end)