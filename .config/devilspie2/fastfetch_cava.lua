-- Terminal do Fastfetch (ffa)
if (get_class_instance_name() == "ffa_term") then
    set_skip_tasklist(true)
    set_skip_pager(true)
    set_keep_below(true)
    set_on_all_workspaces(true)
    undecorate_window()
    pin_window()
end

-- Terminal do Cava
if (get_class_instance_name() == "cava_term") then
    set_skip_tasklist(true)
    set_skip_pager(true)
    set_keep_below(true)
    set_on_all_workspaces(true)
    undecorate_window()
    pin_window()
end
