-- Define the monitor property:
-- TARGET_WIDTH: the width for the monitor regarded as full screen playback.
-- MOVIE_HZ: the Hz supported by the monitor that is multiplier of 24fps and to be changed for fullscreen playback.
-- DESKTOP_HZ: the default Hz of the monitor.
--
-- Pls. download ChangeScreenResolution.exe and place it in same directory.
local TARGET_WIDTH = 1920
local MOVIE_HZ = 48
local DESKTOP_HZ = 60

local script_path = debug.getinfo(1).source:match("@?(.+[\\/])")
local csr = script_path .. "ChangeScreenResolution.exe"

function change_hz(target_hz)

    local display_names = mp.get_property_native("display-names")
    if not display_names or #display_names == 0 then 
        return 
    end
    
    local current_display = display_names[1]

    target_hz = tonumber(target_hz)
    local current_fps = mp.get_property_number("display-fps", 0)
    if math.abs(current_fps - target_hz) < 0.5 then 
        return 
    end

    mp.command_native({
        name = "subprocess",
        playback_only = false,
        args = {csr, "/d=" .. current_display, "/f=" .. tostring(target_hz)}
    })


    local old_vo = mp.get_property("vo")
    mp.set_property("vo", "null")
    mp.set_property("vo", old_vo)
    mp.set_property("video-sync", "display-resample")
    mp.osd_message("Syncing " .. current_display .. " to " .. target_hz .. "Hz", 2)

end

mp.observe_property("osd-width", "number", function(_, width)
    if width == TARGET_WIDTH then
        change_hz(MOVIE_HZ)
    elseif width > 0 and width < TARGET_WIDTH then
        change_hz(DESKTOP_HZ)
    end
end)

mp.register_event("file-loaded", function()
    mp.add_timeout(0.5, function()
        local w = mp.get_property_number("osd-width", 0)
        if w == TARGET_WIDTH then
            change_hz(MOVIE_HZ)
        end
    end)
end)

mp.register_event("end-file", function()
    change_hz(DESKTOP_HZ)
end)

mp.register_event("shutdown", function()
    change_hz(DESKTOP_HZ)
end)
