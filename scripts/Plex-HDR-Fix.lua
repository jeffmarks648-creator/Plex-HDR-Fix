local crop_current_idx = 1
local vapoursynth_is_active = false
local temppath = mp.command_native({"expand-path", "~~/scripts/Plex-HDR-Fix.tmp"})

local function create_temp_file()
    local matrix = mp.get_property("video-params/colormatrix")
    local range  = mp.get_property("video-params/colorlevels")
    local prim   = mp.get_property("video-params/primaries")
    local transfer = mp.get_property("video-params/gamma")
  
    local f = io.open(temppath, "w")
    if f then
        f:write(string.format("%s\n%s\n%s\n%s", matrix, range, prim, transfer))
        f:close()
    end
end

local function cleanup_temp_file()
    local f = io.open(temppath, "r")
    if f ~= nil then
        f:close()
        os.remove(temppath)
    end
end

mp.register_event("file-loaded", function()
    local w = mp.get_property_number("width", 0)
    local h = mp.get_property_number("height", 0)

    if (w % 4 ~= 0) or (h % 2 ~= 0) then
        mp.set_property("hwdec", "auto-copy")  
        mp.command('vf add @PAD:pad=ceil(iw/4)*4:ceil(ih/2)*2')
    end

    vapoursynth_is_active = false
    crop_current_idx = 1
    mp.add_timeout(1, function()
        create_temp_file()
    end)
end)

mp.register_event("end-file", cleanup_temp_file)
mp.register_event("shutdown", cleanup_temp_file)

local function check_hwdec()
    local w = mp.get_property_number("width", 0)
    local h = mp.get_property_number("height", 0)
    
    if not ((crop_current_idx ~= 1) or (w % 4 ~= 0) or (h % 2 ~= 0) or vapoursynth_is_active) then
        mp.set_property("hwdec", "auto")
    end
end

local crop_modes = {
    "null",
    "crop=ceil(ih*16/9/4)*4:ih",
    "crop=ceil(iw*0.8/4)*4:ceil(ih*0.8/4)*4:floor((iw-ow)/2/2)*2:floor((ih-oh)/2/2)*2",
    "crop=ceil(ih*1.9/4)*4:ih"
}

local function crop_apply()
    vapoursynth_toggle_rife(true)

    if crop_current_idx ~= 1 then
        mp.set_property("hwdec", "auto-copy")
    end
    mp.command("vf add @CROP:" .. crop_modes[crop_current_idx])

    check_hwdec()

    mp.osd_message("Filter:\n" .. crop_modes[crop_current_idx])
end

local function crop_cycle()
    crop_current_idx = (crop_current_idx % #crop_modes) + 1
    crop_apply()
end

local function crop_reset()
    crop_current_idx = 1
    crop_apply()
end

mp.add_key_binding("F", "crop-cycle", crop_cycle)
mp.add_key_binding("Alt+F", "crop-reset", crop_reset)

local vapoursynth_mp = require 'mp'
local vapoursynth_label = "VAPOUR"
local vapoursynth_rife_styles = {"400", "406", "410"}
local vapoursynth_rife_names = {["400"]="Action", ["406"]="Cinema", ["410"]="Realistic"}
local vapoursynth_rife_paths = {}

local vapoursynth_rife_idx = 1

local vapoursynth_original_interpolation = nil
local vapoursynth_rife_timer = nil
local vapoursynth_original_is_playing = false

local vapoursynth_scale_target_w = {1920, 2560, 3840}
local vapoursynth_scale_target_h = {1080, 1440, 2160}
local vapoursynth_scale_idx = 1

for _, s in ipairs(vapoursynth_rife_styles) do
    vapoursynth_rife_paths[s] = vapoursynth_mp.command_native({"expand-path", "~~/scripts/Plex-VapourSynth-" .. s .. ".vpy"})
    
    for _, w in ipairs(vapoursynth_scale_target_w) do
        local full_style = s .. "-" .. tostring(w)
        vapoursynth_rife_paths[full_style] = vapoursynth_mp.command_native({"expand-path", "~~/scripts/Plex-VapourSynth-" .. full_style .. ".vpy"})
    end
end

function vapoursynth_toggle_rife(reinit)
    local vapoursynth_was_pending = vapoursynth_rife_timer ~= nil
    if vapoursynth_rife_timer then
        vapoursynth_rife_timer:kill()
        vapoursynth_rife_timer = nil
    end

    if reinit and not vapoursynth_is_active then return end

    if reinit or not vapoursynth_is_active or vapoursynth_was_pending then
        vapoursynth_is_active = true

        local is_actually_playing = not mp.get_property_native("pause") and not mp.get_property_native("core-idle") and mp.get_property_native("video-out-params") ~= nil
        if is_actually_playing then
           vapoursynth_original_is_playing = true
           vapoursynth_mp.set_property_native("pause", true)
        end
        
        vapoursynth_mp.command('vf add @' .. vapoursynth_label .. ':null')            
        mp.set_property("hwdec", "auto-copy")

        vapoursynth_rife_timer = vapoursynth_mp.add_timeout(1, function()
            local vapoursynth_h = vapoursynth_mp.get_property_native("video-out-params/h") or 0
            local vapoursynth_current_style = vapoursynth_rife_styles[vapoursynth_rife_idx]
            
            local vapoursynth_cmd = nil
            if vapoursynth_h > vapoursynth_scale_target_h[vapoursynth_scale_idx] then
                vapoursynth_cmd = string.format('vf add @%s:vapoursynth="%s":buffered-frames=2', vapoursynth_label, 
                    vapoursynth_rife_paths[vapoursynth_current_style .. "-" .. vapoursynth_scale_target_w[vapoursynth_scale_idx]])
            else
                vapoursynth_cmd = string.format('vf add @%s:vapoursynth="%s":buffered-frames=2', vapoursynth_label, 
                    vapoursynth_rife_paths[vapoursynth_current_style])         
            end
            
            vapoursynth_mp.command(vapoursynth_cmd)

            if vapoursynth_original_interpolation == nil then
                vapoursynth_original_interpolation = vapoursynth_mp.get_property("interpolation")
                vapoursynth_mp.set_property("interpolation", "yes")
                vapoursynth_mp.osd_message("RIFE Interpolation: ENABLED (" .. vapoursynth_rife_names[vapoursynth_current_style] .. ")", 3)
            end

            if vapoursynth_original_is_playing then
                vapoursynth_original_is_playing = false
                vapoursynth_mp.set_property_native("pause", false)
            end                           
            
            vapoursynth_rife_timer = nil
        end)
    else
        vapoursynth_is_active = false

        local vapoursynth_current_style = vapoursynth_rife_styles[vapoursynth_rife_idx]
        vapoursynth_mp.command('vf add @' .. vapoursynth_label .. ':null')
        
        vapoursynth_mp.set_property("interpolation", vapoursynth_original_interpolation)
        vapoursynth_original_interpolation = nil
        
        check_hwdec()

        vapoursynth_mp.osd_message("RIFE Interpolation: DISABLED (" .. vapoursynth_rife_names[vapoursynth_current_style] .. ")", 3)
    end
end

function vapoursynth_cycle_rife()
    vapoursynth_rife_idx = (vapoursynth_rife_idx % #vapoursynth_rife_styles) + 1
    local vapoursynth_current_style = vapoursynth_rife_styles[vapoursynth_rife_idx]
    if vapoursynth_is_active then
        vapoursynth_toggle_rife(true)
        vapoursynth_mp.osd_message("RIFE Interpolation: ENABLED (" .. vapoursynth_rife_names[vapoursynth_current_style] .. ")", 3)
    else
        vapoursynth_mp.osd_message("RIFE Interpolation: DISABLED (" .. vapoursynth_rife_names[vapoursynth_current_style] .. ")", 3)
    end
end

function vapoursynth_cycle_downscaler()
    vapoursynth_scale_idx = (vapoursynth_scale_idx % #vapoursynth_scale_target_h) + 1
    if vapoursynth_is_active then
        vapoursynth_toggle_rife(true)
    end
    vapoursynth_mp.osd_message("RIFE Interpolation Scaler: (" .. vapoursynth_scale_target_w[vapoursynth_scale_idx] .. "x" .. vapoursynth_scale_target_h[vapoursynth_scale_idx] ..  ")", 3)
end

function vapoursynth_show_status()   
    local vapoursynth_current_style = vapoursynth_rife_styles[vapoursynth_rife_idx]
    local vapoursynth_current_status = "DISABLED"
    if vapoursynth_is_active then
        vapoursynth_current_status = "ENABLED"
    end
    vapoursynth_mp.osd_message("RIFE Interpolation: " .. vapoursynth_current_status .. " (" .. vapoursynth_rife_names[vapoursynth_current_style] .. ")", 3)
end

vapoursynth_mp.add_key_binding("E", "vapoursynth_toggle_rife", function() vapoursynth_toggle_rife(false) end)
vapoursynth_mp.add_key_binding("e", "vapoursynth_show_status", vapoursynth_show_status)
vapoursynth_mp.add_key_binding("alt+e", "vapoursynth_cycle_rife", vapoursynth_cycle_rife)
vapoursynth_mp.add_key_binding("Alt+E", "vapoursynth_cycle_downscaler", vapoursynth_cycle_downscaler)