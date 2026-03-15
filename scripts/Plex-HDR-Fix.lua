mp.observe_property("hwdec", "string", function(name, val)
    local w = mp.get_property_number("width", 0)
    local h = mp.get_property_number("height", 0)

    if val == "auto-copy" then
        if (w % 4 ~= 0) or (h % 2 ~= 0) then
            mp.command('vf add @PAD:pad=ceil(iw/4)*4:ceil(ih/2)*2')
        end
    else
        mp.command('vf add @PAD:null')
    end
end)

local crop_modes = {
    "null",
    "crop=ceil(ih*16/9/4)*4:ih",
    "crop=ceil(iw*0.8/4)*4:ceil(ih*0.8/4)*4:floor((iw-ow)/2/2)*2:floor((ih-oh)/2/2)*2",
    "crop=ceil(ih*1.9/4)*4:ih"
}

local crop_current_idx = 1

local function crop_apply()
    mp.command("vf add @CROP:" .. crop_modes[crop_current_idx])
    mp.osd_message("Filter:\n" .. crop_modes[crop_current_idx])
end

local function crop_cycle()
    crop_current_idx = (crop_current_idx % #crop_modes) + 1
    crop_apply()
end

local function crop_reset()
    crop_current_idx = 1
    mp.command("vf add @CROP:null")
    mp.osd_message("Filter reset")
end

mp.add_key_binding("F", "crop-cycle", crop_cycle)
mp.add_key_binding("Alt+F", "crop-reset", crop_reset)

mp.register_event("file-loaded", function()
    crop_current_idx = 1
end)

local vapoursynth_mp = require 'mp'
local vapoursynth_label = "VAPOUR"
local vapoursynth_safe_label = "VAPOURSAFE"
local vapoursynth_rife_styles = {"400", "406", "410"}
local vapoursynth_rife_names = {["400"]="Action", ["406"]="Cinema", ["410"]="Realistic"}
local vapoursynth_rife_paths = {}
for _, s in ipairs(vapoursynth_rife_styles) do
    vapoursynth_rife_paths[s] = vapoursynth_mp.command_native({"expand-path", "~~/scripts/Plex-VapourSynth-" .. s .. ".vpy"})
end
local vapoursynth_rife_idx = 1

local vapoursynth_original_interpolation = vapoursynth_mp.get_property("interpolation", "no")
local vapoursynth_original_hwdec = vapoursynth_mp.get_property("hwdec", "auto")

function vapoursynth_toggle_rife()
    local vapoursynth_vf_table = vapoursynth_mp.get_property_native("vf")
    local vapoursynth_is_null_value = true

      for _, vapoursynth_vf in ipairs(vapoursynth_vf_table) do
        if vapoursynth_vf.label == vapoursynth_label then
              if vapoursynth_vf.name ~= "null" then
                vapoursynth_is_null_value = false
            end
            break
        end
    end

    if vapoursynth_is_null_value then
        local vapoursynth_height = vapoursynth_mp.get_property_native("height") or 0     
        if vapoursynth_height > 1080 then
            local vapoursynth_original_hwdec = vapoursynth_mp.get_property("hwdec", "auto")
            vapoursynth_mp.set_property("hwdec", "auto-copy")           
            local vapoursynth_scale_cmd = string.format('vf add @%s:scale=iw/2:ih/2:flags=lanczos+accurate_rnd', vapoursynth_safe_label)
            vapoursynth_mp.command(vapoursynth_scale_cmd)
        end
        local vapoursynth_current_style = vapoursynth_rife_styles[vapoursynth_rife_idx]
        local vapoursynth_current_path = vapoursynth_rife_paths[vapoursynth_current_style]
        local vapoursynth_cmd = string.format('vf add @%s:vapoursynth="%s":buffered-frames=2', vapoursynth_label, vapoursynth_current_path)
        vapoursynth_mp.command(vapoursynth_cmd)
        vapoursynth_original_interpolation = vapoursynth_mp.get_property("interpolation")
        vapoursynth_mp.set_property("interpolation", "yes")
        vapoursynth_mp.osd_message("VapourSynth: ENABLED (" .. vapoursynth_rife_names[vapoursynth_current_style] .. ")")
    else
        local vapoursynth_current_style = vapoursynth_rife_styles[vapoursynth_rife_idx]
        vapoursynth_mp.command('vf add @' .. vapoursynth_safe_label .. ':null')
        vapoursynth_mp.command('vf add @' .. vapoursynth_label .. ':null')
        vapoursynth_mp.set_property("interpolation", vapoursynth_original_interpolation)
        vapoursynth_mp.osd_message("VapourSynth: DISABLED (" .. vapoursynth_rife_names[vapoursynth_current_style] .. ")")

        vapoursynth_mp.add_timeout(1, function()
            vapoursynth_mp.set_property("hwdec", vapoursynth_original_hwdec)
        end)
    end
end

function vapoursynth_cycle_rife()
    vapoursynth_rife_idx = (vapoursynth_rife_idx % #vapoursynth_rife_styles) + 1
    local vapoursynth_current = vapoursynth_rife_styles[vapoursynth_rife_idx]
    local vapoursynth_name = vapoursynth_rife_names[vapoursynth_current]

    local vapoursynth_vf_table = vapoursynth_mp.get_property_native("vf")
    local vapoursynth_is_active = false
    
    for _, vf in ipairs(vapoursynth_vf_table) do
        if vf.label == vapoursynth_label and vf.name ~= "null" then
            vapoursynth_is_active = true
            break
        end
    end

    local vapoursynth_current_style = vapoursynth_rife_styles[vapoursynth_rife_idx]
    if vapoursynth_is_active then
        local vapoursynth_current_path = vapoursynth_rife_paths[vapoursynth_current_style]
        local vapoursynth_cmd = string.format('vf add @%s:vapoursynth="%s":buffered-frames=2', vapoursynth_label, vapoursynth_current_path)
        vapoursynth_mp.command(vapoursynth_cmd)
        vapoursynth_mp.osd_message("VapourSynth: ENABLED (" .. vapoursynth_rife_names[vapoursynth_current_style] .. ")")
    else
        vapoursynth_mp.osd_message("VapourSynth: DISABLED (" .. vapoursynth_rife_names[vapoursynth_current_style] .. ")")
    end
end

function vapoursynth_show_status()
    local vapoursynth_vf_table = vapoursynth_mp.get_property_native("vf")
    local vapoursynth_current_status = "DISABLED"
    local vapoursynth_current_style = vapoursynth_rife_styles[vapoursynth_rife_idx]

    for _, vapoursynth_vf in ipairs(vapoursynth_vf_table) do
        if vapoursynth_vf.label == vapoursynth_label then
            if vapoursynth_vf.name ~= "null" then
                vapoursynth_current_status = "ENABLED"
            end
            break
        end
    end

    vapoursynth_mp.osd_message("VapourSynth: " .. vapoursynth_current_status .. " (" .. vapoursynth_rife_names[vapoursynth_current_style] .. ")")
end

vapoursynth_mp.add_key_binding("E", "vapoursynth_toggle_rife", vapoursynth_toggle_rife)
vapoursynth_mp.add_key_binding("e", "vapoursynth_show_status", vapoursynth_show_status)
vapoursynth_mp.add_key_binding("alt+e", "vapoursynth_cycle_rife", vapoursynth_cycle_rife)