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
    vapoursynth_toggle_rife(true)

    mp.osd_message("Filter:\n" .. crop_modes[crop_current_idx])
end

local function crop_cycle()
    crop_current_idx = (crop_current_idx % #crop_modes) + 1
    crop_apply()
end

local function crop_reset()
    crop_current_idx = 1
    mp.command("vf add @CROP:null")
    vapoursynth_toggle_rife(true)

    mp.osd_message("Filter reset")
end

mp.add_key_binding("F", "crop-cycle", crop_cycle)
mp.add_key_binding("Alt+F", "crop-reset", crop_reset)

mp.register_event("file-loaded", function()
    crop_current_idx = 1
end)

local vapoursynth_mp = require 'mp'
local vapoursynth_label = "VAPOUR"
local vapoursynth_safe_label_1 = "VAPOURSAFE1"
local vapoursynth_safe_label_2 = "VAPOURSAFE2"
local vapoursynth_rife_styles = {"400", "406", "410"}
local vapoursynth_rife_names = {["400"]="Action", ["406"]="Cinema", ["410"]="Realistic"}
local vapoursynth_rife_paths = {}
for _, s in ipairs(vapoursynth_rife_styles) do
    vapoursynth_rife_paths[s] = vapoursynth_mp.command_native({"expand-path", "~~/scripts/Plex-VapourSynth-" .. s .. ".vpy"})
end
local vapoursynth_rife_idx = 1

local vapoursynth_original_interpolation = vapoursynth_mp.get_property("interpolation", "no")
local vapoursynth_scale_timer = nil
local vapoursynth_rife_timer = nil

function vapoursynth_toggle_rife(reinit)
    local vapoursynth_was_pending = (vapoursynth_scale_timer ~= nil or vapoursynth_rife_timer ~= nil)
    
    if vapoursynth_scale_timer then
        vapoursynth_scale_timer:kill()
        vapoursynth_scale_timer = nil
    end
    if vapoursynth_rife_timer then
        vapoursynth_rife_timer:kill()
        vapoursynth_rife_timer = nil
    end

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

    local vapoursynth_is_truly_off = (vapoursynth_is_null_value and not vapoursynth_was_pending)

    if reinit and vapoursynth_is_truly_off then return end

    if reinit or vapoursynth_is_truly_off  then

        vapoursynth_mp.set_property_native("pause", true)

        if reinit then
            vapoursynth_mp.command('vf-command @' .. vapoursynth_label .. ' disable yes')
            vapoursynth_mp.command('vf add @' .. vapoursynth_label .. ':null')            
            vapoursynth_mp.command('vf add @' .. vapoursynth_safe_label_1.. ':null')
            vapoursynth_mp.command('vf add @' .. vapoursynth_safe_label_2.. ':null')
        end

        vapoursynth_mp.command("frame-step")

        vapoursynth_scale_timer = vapoursynth_mp.add_timeout(1, function()
            local vapoursynth_h = vapoursynth_mp.get_property_native("video-out-params/h") or 0
            if vapoursynth_h > 1080 then
                vapoursynth_mp.set_property("hwdec", "auto-copy")           

                local vapoursynth_scale_cmd = string.format(
                    'vf add @%s:scale=w=iw*%d/iw:h=ih*%d/iw:force_original_aspect_ratio=decrease:flags=lanczos+accurate_rnd', 
                        vapoursynth_safe_label_1, 1920, 1920
                )
                vapoursynth_mp.command(vapoursynth_scale_cmd)

                local vapoursynth_pad_cmd = string.format(
                    'vf add @%s:pad=ceil(iw/2)*2:ceil(ih/2)*2', 
                    vapoursynth_safe_label_2
                )
                vapoursynth_mp.command(vapoursynth_pad_cmd)
            end

            vapoursynth_mp.command("frame-step")

            vapoursynth_rife_timer = vapoursynth_mp.add_timeout(1, function()
                local vapoursynth_current_style = vapoursynth_rife_styles[vapoursynth_rife_idx]
                local vapoursynth_current_path = vapoursynth_rife_paths[vapoursynth_current_style]
                local vapoursynth_cmd = string.format('vf add @%s:vapoursynth="%s":buffered-frames=2', vapoursynth_label, vapoursynth_current_path)
                vapoursynth_mp.command(vapoursynth_cmd)
             
                if vapoursynth_is_truly_off then
                    vapoursynth_original_interpolation = vapoursynth_mp.get_property("interpolation")
                    vapoursynth_mp.set_property("interpolation", "yes")
                    vapoursynth_mp.osd_message("VapourSynth: ENABLED (" .. vapoursynth_rife_names[vapoursynth_current_style] .. ")")
                end

                vapoursynth_mp.set_property_native("pause", false)

                vapoursynth_rife_timer = nil
            end)

            vapoursynth_scale_timer = nil
        end)
    else
        local vapoursynth_current_style = vapoursynth_rife_styles[vapoursynth_rife_idx]
        vapoursynth_mp.command('vf add @' .. vapoursynth_safe_label_1.. ':null')
        vapoursynth_mp.command('vf add @' .. vapoursynth_safe_label_2.. ':null')
        vapoursynth_mp.command('vf-command @' .. vapoursynth_label .. ' disable yes')
        vapoursynth_mp.command('vf add @' .. vapoursynth_label .. ':null')
        vapoursynth_mp.set_property("interpolation", vapoursynth_original_interpolation)
        vapoursynth_mp.osd_message("VapourSynth: DISABLED (" .. vapoursynth_rife_names[vapoursynth_current_style] .. ")")
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
        vapoursynth_mp.command('vf-command @' .. vapoursynth_label .. ' disable yes')
        
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

vapoursynth_mp.add_key_binding("E", "vapoursynth_toggle_rife", function() vapoursynth_toggle_rife(false) end)
vapoursynth_mp.add_key_binding("e", "vapoursynth_show_status", vapoursynth_show_status)
vapoursynth_mp.add_key_binding("alt+e", "vapoursynth_cycle_rife", vapoursynth_cycle_rife)