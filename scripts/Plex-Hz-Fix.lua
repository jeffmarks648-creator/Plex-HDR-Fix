-- Define the monitor property:
-- TARGET_WIDTHS: the list of width for the monitor regarded as full screen playback.
-- MOVIE_HZ: the Hz supported by the monitor that is multiplier of 24fps and to be changed for fullscreen playback.
-- DESKTOP_HZ: the default Hz of the monitor (0 will be auto-detect)
--
-- Pls. download ChangeScreenResolution.exe and place it in same directory.
local TARGET_WIDTHS = { 1920, 2560, 3440, 3840, 5120, 7680 }
local MOVIE_HZ = 48
local DESKTOP_HZ = 0

local script_path = debug.getinfo(1).source:match("@?(.+[\\/])")
local csr = script_path .. "ChangeScreenResolution.exe"

local is_target_movie = false
local is_hz_shifted = false

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

    if is_hz_shifted or target_hz ~= DESKTOP_HZ then

        mp.command_native({
            name = "subprocess",
            playback_only = false,
            args = {csr, "/d=" .. current_display, "/f=" .. tostring(target_hz)}
        })

        local old_vo = mp.get_property("vo")
        mp.set_property("vo", "null")
        mp.set_property("vo", old_vo)
        mp.osd_message("Syncing " .. current_display .. " to " .. target_hz .. "Hz", 2)
    end

    is_hz_shifted = (target_hz ~= DESKTOP_HZ)
end

mp.observe_property("osd-width", "number", function(_, width)
    if is_target_movie then
        if is_fullscreen_width(width) then
            change_hz(MOVIE_HZ)
        elseif width > 0 and not is_fullscreen_width(width) then
            change_hz(DESKTOP_HZ)
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
        mp.add_timeout(0.5, function()
            local w = mp.get_property_number("osd-width", 0)
            if is_fullscreen_width(w) then
                change_hz(MOVIE_HZ)
            end
        end)
    end
end)

mp.register_event("end-file", function()
    if is_target_movie then
        change_hz(DESKTOP_HZ)
    end
end)

mp.register_event("shutdown", function()
    if is_target_movie then
        change_hz(DESKTOP_HZ)
    end
end)
