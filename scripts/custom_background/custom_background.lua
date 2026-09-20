local CustomBackground = {}

local CONFIG_NAME = "custom_background"
local SCREEN_MARGIN = 24
local FADE_DURATION = 0.28
local TYPING_DELAY = 0.7
local STATUS_TIME = 5.0
local MAX_SLOTS = 8
local MAX_TEXTURE = 2048

local DIRS = { "", "scripts/", "~/" }

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function set_widget(widget, value)
    if widget and widget.Set then
        pcall(widget.Set, widget, value)
    end
end

local function is_url(name)
    return name:find("^https?://") ~= nil
end

local B64 = {}
do
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    for i = 1, 64 do
        B64[i - 1] = alphabet:sub(i, i)
    end
end

local function base64(data)
    local out, count, length = {}, 0, #data
    local i = 1

    while i + 2 <= length do
        local a, b, c = data:byte(i, i + 2)
        local n = (a << 16) | (b << 8) | c
        count = count + 1
        out[count] = B64[(n >> 18) & 63] .. B64[(n >> 12) & 63] .. B64[(n >> 6) & 63] .. B64[n & 63]
        i = i + 3
    end

    local rest = length - i + 1
    if rest == 1 then
        local n = data:byte(i) << 16
        out[count + 1] = B64[(n >> 18) & 63] .. B64[(n >> 12) & 63] .. "=="
    elseif rest == 2 then
        local a, b = data:byte(i, i + 1)
        local n = (a << 16) | (b << 8)
        out[count + 1] = B64[(n >> 18) & 63] .. B64[(n >> 12) & 63] .. B64[(n >> 6) & 63] .. "="
    end

    return table.concat(out)
end

local function be16(data, pos)
    local a, b = data:byte(pos, pos + 1)
    return (a or 0) * 256 + (b or 0)
end

local function be32(data, pos)
    local a, b, c, d = data:byte(pos, pos + 3)
    return (a or 0) * 16777216 + (b or 0) * 65536 + (c or 0) * 256 + (d or 0)
end

local function le16(data, pos)
    local a, b = data:byte(pos, pos + 1)
    return (a or 0) + (b or 0) * 256
end

local function le24(data, pos)
    local a, b, c = data:byte(pos, pos + 2)
    return (a or 0) + (b or 0) * 256 + (c or 0) * 65536
end

local function jpeg_size(data)
    local pos = 3
    while pos < #data do
        if data:byte(pos) ~= 0xFF then
            break
        end
        local marker = data:byte(pos + 1)
        if marker and marker >= 0xC0 and marker <= 0xCF
            and marker ~= 0xC4 and marker ~= 0xC8 and marker ~= 0xCC then
            return be16(data, pos + 7), be16(data, pos + 5)
        end
        pos = pos + 2 + be16(data, pos + 2)
    end
    return 0, 0
end

local function describe(data)
    if #data < 12 then
        return nil
    end

    if data:sub(1, 8) == "\137PNG\r\n\26\n" then
        return "image/png", be32(data, 17), be32(data, 21)
    end

    if data:sub(1, 3) == "\255\216\255" then
        local width, height = jpeg_size(data)
        return "image/jpeg", width, height
    end

    if data:sub(1, 4) == "GIF8" then
        return "image/gif", le16(data, 7), le16(data, 9)
    end

    if data:sub(1, 4) == "RIFF" and data:sub(9, 12) == "WEBP" then
        local kind = data:sub(13, 16)
        if kind == "VP8X" then
            return "image/webp", le24(data, 25) + 1, le24(data, 28) + 1
        elseif kind == "VP8 " then
            return "image/webp", le16(data, 27) & 0x3FFF, le16(data, 29) & 0x3FFF
        end
        return "image/webp", 0, 0
    end

    if data:find("<svg", 1, true) then
        return "svg", 0, 0
    end

    return nil
end

local images = {}
local pending = {}

local function image_size(handle)
    if type(handle) ~= "number" or handle == 0 then
        return nil
    end
    if not Render.ImageSize then
        return 1, 1
    end
    local ok, size = pcall(Render.ImageSize, handle)
    if ok and size and size.x > 0 and size.y > 0 then
        return size.x, size.y
    end
    return nil
end

local function candidates(name)
    local list, seen = {}, {}

    local function add(path)
        if path and path ~= "" and not seen[path] then
            seen[path] = true
            list[#list + 1] = path
        end
    end

    local slashed = name:gsub("\\", "/")
    local absolute = slashed:match("^%a:/") ~= nil or slashed:match("^/") ~= nil

    add(name)
    add(slashed)

    if not absolute then
        for _, dir in ipairs(DIRS) do
            add(dir .. slashed)
        end
    end

    local base = slashed:match("([^/]+)$")
    if base and base ~= slashed then
        for _, dir in ipairs(DIRS) do
            add(dir .. base)
        end
    end

    return list
end

local function read_file(name)
    if not io or not io.open then
        return nil, "чтение файлов недоступно"
    end

    for _, path in ipairs(candidates(name)) do
        local ok, file = pcall(io.open, path, "rb")
        if ok and file then
            local data = file:read("*a")
            file:close()
            if type(data) == "string" and #data > 0 then
                return data
            end
        end
    end

    return nil, "файл не найден"
end

local function svg_handle(svg, width, height, cache_id)
    local ok, handle = pcall(Render.LoadSvgString, svg, Vec2(width, height), cache_id)
    if ok and type(handle) == "number" and handle ~= 0 then
        return handle
    end
    return nil
end

local function load_local(name)
    for _, path in ipairs(candidates(name)) do
        local ok, handle = pcall(Render.LoadImage, path)
        if ok and image_size(handle) then
            return handle
        end
    end

    local data, err = read_file(name)
    if not data then
        return nil, err
    end

    local mime, width, height = describe(data)
    if not mime then
        return nil, "это не картинка"
    end

    if mime == "svg" then
        return svg_handle(data, 1024, 1024, "bg_svg_" .. name), nil
    end

    if width <= 0 or height <= 0 then
        width, height = 1024, 1024
    end

    local scale = math.min(1.0, MAX_TEXTURE / math.max(width, height))
    local out_w = math.max(1, math.floor(width * scale))
    local out_h = math.max(1, math.floor(height * scale))

    local svg = ('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="%d" height="%d"><image width="%d" height="%d" preserveAspectRatio="none" xlink:href="data:%s;base64,%s"/></svg>')
        :format(out_w, out_h, out_w, out_h, mime, base64(data))

    local handle = svg_handle(svg, out_w, out_h, ("bg_%s_%d"):format(name, #data))
    if handle then
        return handle
    end

    return nil, "формат не поддерживается"
end

local function load_remote(url)
    local entry = pending[url]
    if not entry then
        local ok, handle = pcall(Render.LoadImage, url)
        entry = { handle = (ok and type(handle) == "number" and handle ~= 0) and handle or nil }
        pending[url] = entry
    end

    if entry.handle and image_size(entry.handle) then
        pending[url] = nil
        return entry.handle
    end

    return nil
end

local function load_image(name)
    if not name or name == "" then
        return nil
    end
    if images[name] then
        return images[name]
    end

    local handle, err
    if is_url(name) then
        handle = load_remote(name)
    else
        handle, err = load_local(name)
    end

    if handle then
        images[name] = handle
    end

    return handle, err
end

local tab = Menu.Create("Scripts", "Scripts", "Кастом фон")
pcall(tab.Icon, tab, "\u{f03e}")

local main = Menu.Create("Scripts", "Scripts", "Кастом фон", "Настройки", "Основное")
local picture = Menu.Create("Scripts", "Scripts", "Кастом фон", "Настройки", "Картинка")

local ui = {
    enabled = main:Switch("Включить", true, "\u{f03e}"),
    only_menu = main:Switch("Показывать только в меню", true, "\u{f0c9}"),
    count = main:Slider("Сколько картинок", 1, MAX_SLOTS, 1, "%d"),
    dimming = main:Slider("Затемнение фона", 0, 90, 0, "%d%%"),
}

ui.only_menu:ToolTip("Выключи, чтобы картинки висели и во время игры.")
ui.count:ToolTip("Сколько картинок показывать одновременно. Каждая настраивается отдельно в группе «Картинка».")

local slot_items = {}
for i = 1, MAX_SLOTS do
    slot_items[i] = "Картинка " .. i
end

local edit = {
    slot = picture:Combo("Какую настраиваем", slot_items, 0),
    source = picture:Input("Ссылка или файл", "", "\u{f0c1}"),
    enabled = picture:Switch("Показывать", true, "\u{f06e}"),
    locked = picture:Switch("Закрепить на месте", false, "\u{f023}"),
    size = picture:Slider("Размер", 120, 1200, 420, "%d px"),
    opacity = picture:Slider("Прозрачность", 10, 100, 100, "%d%%"),
}

edit.source:ToolTip("Прямая ссылка на картинку или имя файла рядом со скриптами. Применяется само.")
edit.locked:ToolTip("Пока выключено, картинку можно таскать левой кнопкой мыши.")

local state = { drag = nil, fade = 0, syncing = false, status = nil, status_at = 0, typed = nil, typed_at = 0 }

local function set_status(text)
    state.status = text
    state.status_at = os.clock()
end

local function key_of(index, key)
    return ("s%d_%s"):format(index, key)
end

local function read_int(index, key, default)
    if Config and Config.ReadInt then
        return Config.ReadInt(CONFIG_NAME, key_of(index, key), default)
    end
    return default
end

local function read_str(index, key, default)
    if Config and Config.ReadString then
        return Config.ReadString(CONFIG_NAME, key_of(index, key), default)
    end
    return default
end

local function write_int(index, key, value)
    if Config and Config.WriteInt then
        Config.WriteInt(CONFIG_NAME, key_of(index, key), math.floor(value))
    end
end

local function write_str(index, key, value)
    if Config and Config.WriteString then
        Config.WriteString(CONFIG_NAME, key_of(index, key), value)
    end
end

local slots = {}
for index = 1, MAX_SLOTS do
    slots[index] = {
        index = index,
        file = read_str(index, "file", ""),
        enabled = read_int(index, "on", index == 1 and 1 or 0) ~= 0,
        locked = read_int(index, "lock", 0) ~= 0,
        size = read_int(index, "h", 420),
        opacity = read_int(index, "a", 100),
        x = read_int(index, "x", -1),
        y = read_int(index, "y", -1),
        width = 0,
        height = 0,
        drag_x = 0,
        drag_y = 0,
    }
end

local function save_slot(slot)
    write_str(slot.index, "file", slot.file)
    write_int(slot.index, "on", slot.enabled and 1 or 0)
    write_int(slot.index, "lock", slot.locked and 1 or 0)
    write_int(slot.index, "h", slot.size)
    write_int(slot.index, "a", slot.opacity)
    write_int(slot.index, "x", slot.x + 0.5)
    write_int(slot.index, "y", slot.y + 0.5)
end

local function current_slot()
    return slots[clamp(edit.slot:Get() + 1, 1, MAX_SLOTS)]
end

local function apply_source(slot, source)
    slot.file = source
    save_slot(slot)

    if source == "" then
        set_status("вставь ссылку или имя файла")
        return
    end

    images[source] = nil
    pending[source] = nil

    local handle, err = load_image(source)
    if handle then
        set_status("готово")
    elseif is_url(source) then
        set_status("загружаю...")
    else
        set_status(err or "не получилось")
    end
end

local function sync_editor()
    local slot = current_slot()
    state.syncing = true
    set_widget(edit.source, slot.file)
    set_widget(edit.enabled, slot.enabled)
    set_widget(edit.locked, slot.locked)
    set_widget(edit.size, slot.size)
    set_widget(edit.opacity, slot.opacity)
    state.syncing = false
    state.typed = nil
end

local function pull_editor()
    if state.syncing then
        return
    end

    local slot = current_slot()
    local changed = false

    local enabled = edit.enabled:Get()
    if enabled ~= slot.enabled then slot.enabled, changed = enabled, true end

    local locked = edit.locked:Get()
    if locked ~= slot.locked then slot.locked, changed = locked, true end

    local size = edit.size:Get()
    if size ~= slot.size then slot.size, changed = size, true end

    local opacity = edit.opacity:Get()
    if opacity ~= slot.opacity then slot.opacity, changed = opacity, true end

    if changed then
        save_slot(slot)
    end

    local source = edit.source:Get() or ""
    if source ~= slot.file then
        if source ~= state.typed then
            state.typed, state.typed_at = source, os.clock()
        elseif os.clock() - state.typed_at >= TYPING_DELAY then
            state.typed = nil
            apply_source(slot, source)
        end
    end
end

picture:Button("Обновить картинку", function()
    apply_source(current_slot(), edit.source:Get() or "")
end)

picture:Button("Сбросить позицию", function()
    local slot = current_slot()
    slot.x, slot.y = -1, -1
    if state.drag == slot then
        state.drag = nil
    end
    save_slot(slot)
end)

sync_editor()

local font = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)

local function update_bounds(slot, handle)
    local screen = Render.ScreenSize()
    local image_w, image_h = image_size(handle)
    local aspect = (image_w and image_h) and (image_w / image_h) or 1.0

    local height = math.min(slot.size, math.max(1, screen.y))
    local width = math.min(math.floor(height * aspect + 0.5), math.max(1, screen.x))

    slot.width, slot.height = width, height

    if slot.x < 0 or slot.y < 0 then
        local column = (slot.index - 1) % 4
        slot.x = clamp(screen.x - (width + SCREEN_MARGIN) * (column + 1), 0, math.max(0, screen.x - width))
        slot.y = math.max(0, screen.y - height - SCREEN_MARGIN)
    end

    slot.x = clamp(slot.x, 0, math.max(0, screen.x - width))
    slot.y = clamp(slot.y, 0, math.max(0, screen.y - height))
end

local function slot_visible(slot)
    return slot.index <= ui.count:Get() and slot.enabled
end

local function cursor_inside(slot)
    return slot.width > 0 and slot.height > 0
        and Input.IsCursorInRect(slot.x, slot.y, slot.width, slot.height)
end

local function cursor_over_menu()
    if not Menu.Opened() then
        return false
    end

    local ok_pos, pos = pcall(Menu.Pos)
    local ok_size, size = pcall(Menu.Size)
    if not ok_pos or not ok_size or not pos or not size then
        return false
    end

    return Input.IsCursorInRect(pos.x, pos.y, size.x, size.y)
end

local function stop_drag()
    if state.drag then
        save_slot(state.drag)
        state.drag = nil
    end
end

local function update_drag()
    local slot = state.drag
    if not slot then
        return
    end

    if not slot_visible(slot) or slot.locked or not Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1, true) then
        stop_drag()
        return
    end

    local screen = Render.ScreenSize()
    local cursor_x, cursor_y = Input.GetCursorPos()
    slot.x = clamp(cursor_x - slot.drag_x, 0, math.max(0, screen.x - slot.width))
    slot.y = clamp(cursor_y - slot.drag_y, 0, math.max(0, screen.y - slot.height))
end

local function frame_time()
    local dt = GlobalVars and GlobalVars.GetAbsFrameTime and GlobalVars.GetAbsFrameTime() or 0.016
    if type(dt) ~= "number" or dt <= 0 or dt > 0.1 then
        return 0.016
    end
    return dt
end

local function draw_status(fade)
    if not state.status or not Menu.Opened() or os.clock() - state.status_at >= STATUS_TIME then
        return
    end

    local screen = Render.ScreenSize()
    local size = Render.TextSize(font, 15, state.status)
    local pos = Vec2(screen.x * 0.5 - size.x * 0.5, 60)

    Render.FilledRect(pos - Vec2(10, 6), pos + size + Vec2(10, 6), Color(0, 0, 0, 170), 4)
    Render.Text(font, 15, state.status, pos, Color(255, 220, 120, math.floor(255 * fade + 0.5)))
end

local last_slot = 1

function CustomBackground.OnFrame()
    local selected = clamp(edit.slot:Get() + 1, 1, MAX_SLOTS)
    if selected ~= last_slot then
        last_slot = selected
        sync_editor()
    else
        pull_editor()
    end

    local visible = ui.enabled:Get() and (not ui.only_menu:Get() or Menu.Opened())
    if not visible then
        stop_drag()
    end

    local step = frame_time() / FADE_DURATION
    state.fade = clamp(state.fade + (visible and step or -step), 0, 1)
    if state.fade <= 0 then
        return
    end

    local fade = state.fade * state.fade * (3 - 2 * state.fade)

    for _, slot in ipairs(slots) do
        slot.handle = nil
        if slot_visible(slot) and slot.file ~= "" then
            slot.handle = load_image(slot.file)
            if slot.handle then
                update_bounds(slot, slot.handle)
            end
        end
    end

    if visible then
        update_drag()
    end

    local dimming = ui.dimming:Get()
    if dimming > 0 then
        Render.FilledRect(Vec2(0, 0), Render.ScreenSize(),
            Color(0, 0, 0, math.floor(255 * dimming / 100 * fade + 0.5)))
    end

    for _, slot in ipairs(slots) do
        if slot.handle then
            Render.Image(slot.handle,
                Vec2(math.floor(slot.x + 0.5), math.floor(slot.y + 0.5)),
                Vec2(slot.width, slot.height),
                Color(255, 255, 255, math.floor(255 * slot.opacity / 100 * fade + 0.5)))
        end
    end

    draw_status(fade)
end

function CustomBackground.OnKeyEvent(data)
    if data == nil or data.key ~= Enum.ButtonCode.KEY_MOUSE1 then
        return true
    end
    if not ui.enabled:Get() or (ui.only_menu:Get() and not Menu.Opened()) then
        return true
    end

    if data.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
        if cursor_over_menu() then
            return true
        end

        for index = MAX_SLOTS, 1, -1 do
            local slot = slots[index]
            if slot.handle and slot_visible(slot) and not slot.locked and cursor_inside(slot) then
                local cursor_x, cursor_y = Input.GetCursorPos()
                state.drag = slot
                slot.drag_x = cursor_x - slot.x
                slot.drag_y = cursor_y - slot.y
                return false
            end
        end
    elseif data.event == Enum.EKeyEvent.EKeyEvent_KEY_UP and state.drag then
        stop_drag()
        return false
    end

    return true
end

return CustomBackground
