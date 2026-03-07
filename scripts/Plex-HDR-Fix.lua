mp.observe_property("hwdec", "string", function(name, val)
    if val == "auto-copy" then     
        local vf = mp.get_property("vf")
        if vf ~= "" then
            mp.set_property("vf", "")
            mp.set_property("vf", vf)
            mp.osd_message("AUTO-COPY Mode: Filters reloaded.")
        end
    end
end)