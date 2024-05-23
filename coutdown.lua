obs = obslua

countdown_time = 180  -- 初期設定のカウントダウン時間（秒）
current_time = countdown_time  -- 現在のカウントダウン時間
text_source_name = ""  -- カウントダウンを表示するテキストソース名
is_paused = false
timer_active = false
show_timeup = true  -- TIMEUPを表示するかどうかのフラグ

hotkey_pause_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_reset_id = obs.OBS_INVALID_HOTKEY_ID

function script_description()
    return "カウントダウンタイマー（一時停止、リセット機能付き）"
end

function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_int(props, "countdown_time", "カウントダウン時間（秒）", 1, 3600, 1)
    obs.obs_properties_add_text(props, "text_source_name", "テキストソース名", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_bool(props, "show_timeup", "TIMEUPを表示")
    obs.obs_properties_add_button(props, "pause_button", "一時停止/再開", toggle_pause)
    obs.obs_properties_add_button(props, "reset_button", "リセット", reset_timer)
    return props
end

function script_update(settings)
    countdown_time = obs.obs_data_get_int(settings, "countdown_time")
    current_time = countdown_time
    text_source_name = obs.obs_data_get_string(settings, "text_source_name")
    show_timeup = obs.obs_data_get_bool(settings, "show_timeup")
end

function format_text(text)
    if text == "TIMEUP" then
        return string.format("%-10s", text)  -- TIMEUPを固定幅で左揃え
    else
        return string.format("%8d", tonumber(text))  -- 数字を固定幅で右揃え
    end
end

function update_text_source(text)
    local source = obs.obs_get_source_by_name(text_source_name)
    if source then
        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "text", format_text(text))
        obs.obs_data_set_int(settings, "alignment", 0)  -- テキストを左揃えに設定
        obs.obs_source_update(source, settings)
        obs.obs_data_release(settings)
        obs.obs_source_release(source)
    end
end

function timer_callback()
    if not timer_active then
        return
    end

    if not is_paused then
        if current_time > 0 then
            current_time = current_time - 1
            update_text_source(tostring(current_time))
        else
            if show_timeup then
                update_text_source("TIMEUP")
            else
                update_text_source("0")
            end
            obs.timer_remove(timer_callback)
            timer_active = false
        end
    end
end

function toggle_pause(pressed)
    if pressed then
        if not timer_active then
            timer_active = true
            is_paused = false
            obs.timer_add(timer_callback, 1000)
        else
            is_paused = not is_paused
        end
    end
end

function reset_timer()
    timer_active = false
    is_paused = false
    obs.timer_remove(timer_callback)
    current_time = countdown_time
    update_text_source(tostring(current_time))
end

function script_load(settings)
    script_update(settings)
    hotkey_pause_id = obs.obs_hotkey_register_frontend("toggle_pause", "一時停止/再開", toggle_pause)
    hotkey_reset_id = obs.obs_hotkey_register_frontend("reset_timer", "リセット", reset_timer)
    local hotkey_pause = obs.obs_data_get_array(settings, "toggle_pause")
    local hotkey_reset = obs.obs_data_get_array(settings, "reset_timer")
    obs.obs_hotkey_load(hotkey_pause_id, hotkey_pause)
    obs.obs_hotkey_load(hotkey_reset_id, hotkey_reset)
    obs.obs_data_array_release(hotkey_pause)
    obs.obs_data_array_release(hotkey_reset)
end

function script_save(settings)
    local hotkey_pause = obs.obs_hotkey_save(hotkey_pause_id)
    local hotkey_reset = obs.obs_hotkey_save(hotkey_reset_id)
    obs.obs_data_set_array(settings, "toggle_pause", hotkey_pause)
    obs.obs_data_set_array(settings, "reset_timer", hotkey_reset)
    obs.obs_data_array_release(hotkey_pause)
    obs.obs_data_array_release(hotkey_reset)
end
