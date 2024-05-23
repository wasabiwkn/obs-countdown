obs = obslua

countdown_time = 180  -- 初期設定のカウントダウン時間（秒）
current_time = countdown_time  -- 現在のカウントダウン時間
text_source_name = ""  -- カウントダウンを表示するテキストソース名
image_source_name = ""  -- 表示する画像ソース名
is_paused = false
timer_active = false
fade_enabled = true  -- 画像をフェードアウトするかどうか
fade_duration = 1000  -- フェードアウトの時間（ミリ秒）
display_duration = 1000  -- 画像の表示時間（ミリ秒）
fade_step = 50  -- フェードアウトのステップ時間（ミリ秒）
current_alpha = 255  -- 現在の透明度（初期値：255）

hotkey_pause_id = obs.OBS_INVALID_HOTKEY_ID
hotkey_reset_id = obs.OBS_INVALID_HOTKEY_ID

function script_description()
    return "カウントダウンタイマー（一時停止、リセット機能付き）"
end

function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_int(props, "countdown_time", "カウントダウン時間（秒）", 1, 3600, 1)
    obs.obs_properties_add_text(props, "text_source_name", "テキストソース名", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "image_source_name", "画像ソース名", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_bool(props, "fade_enabled", "画像をフェードアウト")
    obs.obs_properties_add_int(props, "fade_duration", "フェードアウトの時間（ミリ秒）", 100, 10000, 100)
    obs.obs_properties_add_int(props, "display_duration", "画像の表示時間（ミリ秒）", 100, 10000, 100)
    obs.obs_properties_add_button(props, "pause_button", "開始/一時停止/再開", toggle_pause)
    obs.obs_properties_add_button(props, "reset_button", "リセット", reset_timer)
    return props
end

function script_update(settings)
    countdown_time = obs.obs_data_get_int(settings, "countdown_time")
    current_time = countdown_time
    text_source_name = obs.obs_data_get_string(settings, "text_source_name")
    image_source_name = obs.obs_data_get_string(settings, "image_source_name")
    fade_enabled = obs.obs_data_get_bool(settings, "fade_enabled")
    fade_duration = obs.obs_data_get_int(settings, "fade_duration")
    display_duration = obs.obs_data_get_int(settings, "display_duration")
end

function format_text(text)
    return string.format("%10d", tonumber(text))  -- 数字を固定幅で右揃え
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

function show_image_source()
    current_alpha = 255
    local source = obs.obs_get_source_by_name(image_source_name)
    if source then
        obs.obs_source_set_enabled(source, true)
        set_image_alpha(source, current_alpha)
        obs.timer_add(hide_image_source, display_duration)  -- 一定時間後に画像を非表示
    end
end

function hide_image_source()
    if fade_enabled then
        obs.timer_add(fade_out_image_source, fade_step)  -- フェードアウトを開始
    else
        local source = obs.obs_get_source_by_name(image_source_name)
        if source then
            obs.obs_source_set_enabled(source, false)
        end
    end
    obs.timer_remove(hide_image_source)
end

function fade_out_image_source()
    local source = obs.obs_get_source_by_name(image_source_name)
    if source then
        current_alpha = current_alpha - (255 * fade_step / fade_duration)
        if current_alpha < 0 then
            current_alpha = 0
        end
        set_image_alpha(source, current_alpha)
        if current_alpha == 0 then
            obs.obs_source_set_enabled(source, false)
            obs.timer_remove(fade_out_image_source)
        end
    end
end

function set_image_alpha(source, alpha)
    local filter = obs.obs_source_get_filter_by_name(source, "フェードアウトフィルター")
    if not filter then
        local settings = obs.obs_data_create()
        filter = obs.obs_source_create_private("color_filter", "フェードアウトフィルター", settings)
        obs.obs_source_filter_add(source, filter)
        obs.obs_data_release(settings)
    end

    local settings = obs.obs_source_get_settings(filter)
    obs.obs_data_set_int(settings, "opacity", math.floor(alpha))
    obs.obs_source_update(filter, settings)
    obs.obs_data_release(settings)
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
            update_text_source("0")
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
            show_image_source()  -- 画像ソースを表示
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
    hotkey_pause_id = obs.obs_hotkey_register_frontend("toggle_pause", "開始/一時停止/再開", toggle_pause)
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
