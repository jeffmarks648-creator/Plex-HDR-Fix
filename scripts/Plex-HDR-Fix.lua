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