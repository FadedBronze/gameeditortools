package raylibeditorui

import clay "project:clay-odin"

import ed "project:editor"
import editorui "project:editorui"
import ut "project:utils"
import rl "vendor:raylib"

import "core:mem"
import "core:strconv"
import "core:strings"
import "core:slice"
import "core:fmt"
import "base:runtime"

measure_text :: proc "c" (
    text: clay.StringSlice,
    config: ^clay.TextElementConfig,
    userData: rawptr,
) -> clay.Dimensions {
    context = runtime.default_context()

    s := strings.string_from_ptr(text.chars, auto_cast text.length)
    cs := strings.clone_to_cstring(s, context.temp_allocator)

    return {
        width = f32(rl.MeasureText(cs, auto_cast config.fontSize)),
        height = f32(config.fontSize),
    }
}

clay_to_raylib_color :: proc(color: clay.Color) -> rl.Color {
    return {u8(color.r), u8(color.g), u8(color.b), u8(color.a)}
}

clay_raylib_render :: proc(editor_ui: ^editorui.EditorUI, elements: clay.ClayArray(clay.RenderCommand), allocator: mem.Allocator, frame_allocator: mem.Allocator, dt: f32) {  
    slx := slice.from_ptr(elements.internalArray, auto_cast elements.length)

    for element in slx {
        render_command: clay.RenderCommand = element;
        //fmt.println(render_command.zIndex)

        switch render_command.commandType {
            case .None:
            case .Rectangle:
                color := render_command.renderData.rectangle.backgroundColor
                rl.DrawRectangleRec(auto_cast render_command.boundingBox, clay_to_raylib_color(color))
            case .Border:
                //color := render_command.renderData.border.color
                //rl.DrawRectangleLines(auto_cast render_command.boundingBox, clay_to_raylib_color(color))
            case .Text:
                text_command := render_command.renderData.text
                text := text_command.stringContents
                s := strings.string_from_ptr(text.chars, auto_cast text.length)
                cs := strings.clone_to_cstring(s, context.temp_allocator)
                box := render_command.boundingBox

                rl.DrawText(cs, auto_cast box.x, auto_cast box.y, auto_cast text_command.fontSize, clay_to_raylib_color(text_command.textColor))
            case .Custom:
                //fmt.println(render_command.renderData.custom.customData)
                //TODO false
                render_custom_widget(editor_ui, render_command, editor_ui.render_infos, allocator, frame_allocator, dt)
                fmt.println("ran!")
            case .ScissorStart:
                fmt.println("ran?")
                rl.BeginScissorMode(
                    i32(render_command.boundingBox.x),
                    i32(render_command.boundingBox.y),
                    i32(render_command.boundingBox.width),
                    i32(render_command.boundingBox.height)
                )
            case .ScissorEnd:
                fmt.println("ran.")
                rl.EndScissorMode()
            case .Image:
                unimplemented()
            case .OverlayColorStart:
                unimplemented()
            case .OverlayColorEnd:
                unimplemented()
        }
    }
}

render_dropdown_floating_menu :: proc(
    editor_ui: ^editorui.EditorUI,
    render_command: clay.RenderCommand, 
    dropdown_input: ed.Dropdown($T), 
    input_index: ed.InputIndex,
    render_info: editorui.DropdownRenderInfo,
    within: bool,
) {
    padding := f32(render_info.padding)
    gap := f32(render_info.gap)
    font_size := f32(render_info.font_size)

    input_bounds := ut.Bounds(f32) {
        x = render_command.boundingBox.x,
        y = render_command.boundingBox.y,
        width = render_command.boundingBox.width,
        height = font_size,
    }

    mouse_within := ut.position_within_bounds(auto_cast rl.GetMousePosition(), auto_cast render_command.boundingBox)
    active := editor_ui.active_index == input_index

    rl.DrawRectangleRec(auto_cast render_command.boundingBox, auto_cast render_info.back_color)
    
    if !mouse_within && rl.IsMouseButtonPressed(.LEFT) && active {
        editor_ui.active_index = max(ed.InputIndex)
    }
    
    rl.DrawRectangleRec(auto_cast render_command.boundingBox, auto_cast render_info.back_color)

    rl.DrawRectangleLinesEx(auto_cast render_command.boundingBox, 1, auto_cast auto_cast render_info.outline_color)
    rl.DrawRectangleLinesEx(auto_cast input_bounds, 1, auto_cast render_info.border_color)

    for i in 0..<len(dropdown_input.enum_names) {
        name := dropdown_input.enum_names[i]
        value := dropdown_input.enum_values[i]
        offset := f32(i+1) * (gap + font_size)

        buf: [64]u8
        length := copy_from_string(buf[:], name)
        buf[length] = '\x00'
        length += 1

        bounds := ut.Bounds(f32) {
            x = render_command.boundingBox.x,
            y = render_command.boundingBox.y + offset + f32(render_info.inner_padding)-f32(render_info.gap)/2,
            width = render_command.boundingBox.width,
            height = f32(render_info.font_size)+f32(render_info.gap),
        }

        if ut.position_within_bounds(auto_cast rl.GetMousePosition(), bounds) {
            rl.DrawRectangleRec(auto_cast bounds, auto_cast ut.change_opacity(ut.get_contrasting_color(render_info.back_color), 20))

            if rl.IsMouseButtonDown(.LEFT) {
                dropdown_input.current^ = T(value)
                editor_ui.active_index = max(ed.InputIndex)
            }
        }

        rl.DrawText(
            strings.unsafe_string_to_cstring(string(buf[:length])),
            i32(padding + render_command.boundingBox.x),
            i32(render_command.boundingBox.y + offset + f32(render_info.inner_padding)),
            i32(font_size),
            auto_cast render_info.text_color,
        )
    }

    selected_name := dropdown_input.enum_names[dropdown_input.current^]
    buf: [64]u8
    length := copy_from_string(buf[:], selected_name)
    buf[length] = '\x00'
    length += 1

    rl.DrawText(
        strings.unsafe_string_to_cstring(string(buf[:length])),
        i32(padding + render_command.boundingBox.x),
        i32(render_command.boundingBox.y),
        i32(font_size),
        auto_cast render_info.text_color,
    )
}

render_dropdown_input :: proc(
    editor_ui: ^editorui.EditorUI,
    render_command: clay.RenderCommand, 
    dropdown_input: ed.Dropdown($T), 
    input_index: ed.InputIndex,
    render_info: editorui.DropdownRenderInfo,
    within: bool,
) {
    padding := f32(render_info.padding)
    font_size := f32(render_info.font_size)

    mouse_within := ut.position_within_bounds(auto_cast rl.GetMousePosition(), auto_cast render_command.boundingBox)

    rl.DrawRectangleRec(auto_cast render_command.boundingBox, auto_cast render_info.back_color)

    active := editor_ui.active_index == input_index
    
    if mouse_within && within && rl.IsMouseButtonPressed(.LEFT) {
        editor_ui.active_index = input_index
    }
    
    selected_name := dropdown_input.enum_names[dropdown_input.current^]
    buf: [64]u8
    length := copy_from_string(buf[:], selected_name)
    buf[length] = '\x00'
    length += 1
    
    if !active {
        rl.DrawText(
            strings.unsafe_string_to_cstring(string(buf[:length])),
            i32(padding + render_command.boundingBox.x),
            i32(render_command.boundingBox.y),
            i32(font_size),
            auto_cast render_info.text_color,
        )
    }
}

render_custom_widget :: proc(
    editor_ui: ^editorui.EditorUI, render_command: clay.RenderCommand, render_infos: editorui.RenderInfos, allocator: mem.Allocator, frame_allocator: mem.Allocator, dt: f32
) {
    custom_id := transmute(editorui.CustomId)render_command.renderData.custom.customData

    switch custom_id.type {
    case .Null:
        unreachable()
    case .Gameview:
        editor_ui.update_game.fn(editor_ui.update_game.data, auto_cast render_command.boundingBox, dt)
    case .DropdownFloatingMenu:
        input_index: ed.InputIndex = custom_id.value.input_index
        input := editor_ui.panel_pool.inputs[input_index]
        
        clay_id := clay.ID("widget-dropdown", auto_cast input_index)
        within := clay.PointerOver(clay_id)

        #partial switch input_data in input {
        case ed.Dropdown(u8):
            render_dropdown_floating_menu(editor_ui, render_command, input_data, input_index, render_infos.dropdown, within)
        case ed.Dropdown(u16):
            render_dropdown_floating_menu(editor_ui, render_command, input_data, input_index, render_infos.dropdown, within)
        case ed.Dropdown(u32):
            render_dropdown_floating_menu(editor_ui, render_command, input_data, input_index, render_infos.dropdown, within)
        case ed.Dropdown(u64):
            render_dropdown_floating_menu(editor_ui, render_command, input_data, input_index, render_infos.dropdown, within)
        case:
            unreachable()
        }
    case .InputIndex:
        input_index: ed.InputIndex = custom_id.value.input_index
        input := editor_ui.panel_pool.inputs[input_index]

        clay_id := clay.ID("widget", auto_cast input_index)
        within := clay.PointerOver(clay_id)

        switch input_data in input {
        case ed.Dropdown(u8):
            render_dropdown_input(editor_ui, render_command, input_data, input_index, render_infos.dropdown, within)
        case ed.Dropdown(u16):
            render_dropdown_input(editor_ui, render_command, input_data, input_index, render_infos.dropdown, within)
        case ed.Dropdown(u32):
            render_dropdown_input(editor_ui, render_command, input_data, input_index, render_infos.dropdown, within)
        case ed.Dropdown(u64):
            render_dropdown_input(editor_ui, render_command, input_data, input_index, render_infos.dropdown, within)
        case ed.Toggle:
            within_bounds := ut.position_within_bounds(rl.GetMousePosition(), auto_cast render_command.boundingBox)
            if within && within_bounds && rl.IsMouseButtonPressed(.LEFT) {
                input_data.current^ = !input_data.current^
            }
            if input_data.current^ {
                rl.DrawRectangleRec(auto_cast render_command.boundingBox, auto_cast render_infos.toggle.true_color)
            } else {
                rl.DrawRectangleRec(auto_cast render_command.boundingBox, auto_cast render_infos.toggle.false_color)
            }
        case ed.TextInputString:
            render_text_input(
                editor_ui, 
                render_command, 
                input_data.placeholder, 
                input_data.text == nil ? "" : input_data.text^, 
                cast(rawptr)input_data.text, 
                proc(str: rawptr, new_str: string) {
                    old_string: ^string = cast(^string)str
                    old_string^ = new_str
                }, 
                input_index, 
                render_infos.text, 
                allocator, 
                frame_allocator, 
                within
            )
        case ed.TextInputMutableBuffer:
            //input_data.
        case ed.NumberInput(f64):
            render_number_input(editor_ui, render_command, input_data, input_index, render_infos.slider, render_infos.text, allocator, frame_allocator, within)
        case ed.NumberInput(i32):
            render_number_input(editor_ui, render_command, input_data, input_index, render_infos.slider, render_infos.text, allocator, frame_allocator, within)
        case ed.NumberInput(u8):
            render_number_input(editor_ui, render_command, input_data, input_index, render_infos.slider, render_infos.text, allocator, frame_allocator, within)
        case ed.NumberInput(f32):
            render_number_input(editor_ui, render_command, input_data, input_index, render_infos.slider, render_infos.text, allocator, frame_allocator, within)
        case ed.NumberInput(u64):
            render_number_input(editor_ui, render_command, input_data, input_index, render_infos.slider, render_infos.text, allocator, frame_allocator, within)
        case ed.NumberInput(u32):
            render_number_input(editor_ui, render_command, input_data, input_index, render_infos.slider, render_infos.text, allocator, frame_allocator, within)
        }
    }
}

TextInputType :: union {
    ed.TextInputString,
    ed.NumberInput,
}

render_text_input :: proc(
    editor_ui: ^editorui.EditorUI,
    render_command: clay.RenderCommand, 

    placeholder: string,
    text: string,
    commit_user_ptr: rawptr,
    commit: proc (rawptr, string),

    input_index: ed.InputIndex,
    render_info: editorui.TextInputRenderInfo,
    allocator: mem.Allocator,
    frame_allocator: mem.Allocator,

    within: bool,
) {
    mouse_within := ut.position_within_bounds(auto_cast rl.GetMousePosition(), auto_cast render_command.boundingBox)
    rl.DrawRectangleRec(auto_cast render_command.boundingBox, auto_cast render_info.back_color)
    active := editor_ui.active_index == input_index
    padding := f32(render_info.padding)

    if active {
        rl.DrawRectangleLinesEx(auto_cast render_command.boundingBox, 1, auto_cast render_info.border_color)
    }

    if mouse_within && within && rl.IsMouseButtonPressed(.LEFT) {
        // TODO: decide how this gets freed properly
        active_data := editorui.TextInput{
            buf = make([]u8, 32),
            buf_len = 1,
        }

        prev_str := text

        copy_from_string(active_data.buf, prev_str)
        active_data.buf_len = u8(len(prev_str))

        if active_data.buf_len == 0 || active_data.buf[active_data.buf_len-1] != '\x00' {
            active_data.buf[active_data.buf_len] = '\x00'
            active_data.buf_len += 1
        }

        editor_ui.active_data = active_data
        editor_ui.active_index = input_index
    }

    //TODOs: 
    // - retrigger delete on backspace hold
    // - proper caret position
    // - undo/(redo??)
    if active {
        active_data := &editor_ui.active_data.(editorui.TextInput)
        ctrl := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)

        if !ctrl {
            char := u8(rl.GetCharPressed())

            for char != 0 && active_data.buf_len < u8(len(active_data.buf)-1){
                active_data.buf[active_data.buf_len-1] = char
                active_data.buf_len += 1
                active_data.buf[active_data.buf_len-1] = '\x00'

                char = u8(rl.GetCharPressed())
            }
        }

        key := rl.GetKeyPressed()

        for key != rl.KeyboardKey.KEY_NULL {
            #partial switch key {
            case .BACKSPACE:
                if ctrl {
                    i := active_data.buf_len-1
                    for active_data.buf[i] != ' ' && i != 0 {
                        i -= 1
                    }
                    active_data.buf_len = i+1
                    active_data.buf[active_data.buf_len-1] = '\x00'
                } else {
                    if active_data.buf_len > 1 {
                        active_data.buf_len -= 1
                        active_data.buf[active_data.buf_len-1] = '\x00'
                    }
                }
            case .V:
                if ctrl {
                    clipboard_string := string(rl.GetClipboardText())
                    copy_from_string(active_data.buf[active_data.buf_len-1:], clipboard_string)
                    active_data.buf_len += u8(len(clipboard_string))
                    active_data.buf[active_data.buf_len-1] = '\x00'
                }
            case .ENTER:
                editor_ui.active_index = max(ed.InputIndex)
                active_data := &editor_ui.active_data.(editorui.TextInput)
                commit(commit_user_ptr, string(active_data.buf[0:active_data.buf_len]))
            }
            
            key = rl.GetKeyPressed()
        }
    }

    if (rl.IsKeyPressed(.ESCAPE) || rl.IsMouseButtonPressed(.LEFT) && !mouse_within) && active {
        editor_ui.active_index = max(ed.InputIndex)
        active_data := &editor_ui.active_data.(editorui.TextInput)
        commit(commit_user_ptr, string(active_data.buf[0:active_data.buf_len]))
    }
    
    empty := text == ""
    render_string: cstring
    text_color: ut.Color

    if active {
        active_data := editor_ui.active_data.(editorui.TextInput)

        text_cstring := strings.clone_to_cstring(string(active_data.buf[:active_data.buf_len]), frame_allocator)
        render_string = text_cstring
        text_color = render_info.text_color
    } else if empty {
        placeholder := strings.clone_to_cstring(placeholder, frame_allocator)
        render_string = placeholder
        text_color = render_info.placeholder_text_color
    } else {
        text_cstring := strings.clone_to_cstring(text, frame_allocator)
        render_string = text_cstring
        text_color = render_info.text_color
    }
    
    text_width := rl.MeasureText(render_string, i32(render_info.font_size))

    if active {
        rl.DrawRectangle(
            i32(padding+render_command.boundingBox.x)+text_width, 
            i32(render_command.boundingBox.y+padding), 
            i32(render_info.caret_width),
            i32(render_command.boundingBox.height-padding*2),
            auto_cast render_info.caret_color,
        )
    }

    rl.DrawText(
        render_string, 
        i32(padding + render_command.boundingBox.x), 
        i32(render_command.boundingBox.y), 
        i32(render_info.font_size), 
        auto_cast text_color
    )
}

render_number_input :: proc(
    editor_ui: ^editorui.EditorUI,
    render_command: clay.RenderCommand, 
    number_input: ed.NumberInput($T), 
    input_index: ed.InputIndex,
    render_info: editorui.SliderRenderInfo,
    text_render_info: editorui.TextInputRenderInfo,
    allocator: mem.Allocator,
    frame_allocator: mem.Allocator,
    within: bool,
) {
    handle_size := f32(render_info.handle_size)
    bar_padding_x := f32(render_info.bar_padding_x)
    bar_height := f32(render_info.bar_height)

    fmt_number :: proc(buf: []u8, num: $T) -> cstring {
        type_info := type_info_of(T)

        #partial switch v in type_info.variant {
        case runtime.Type_Info_Float:
            buf_len := len(strconv.write_float(buf[:], cast(f64)num, 'f', 2, 64))
            buf[buf_len] = '\x00'
            buf_len += 1
            return strings.unsafe_string_to_cstring(string(buf[0:buf_len]))
        case runtime.Type_Info_Integer:
            buf_len := len(strconv.write_int(buf[:], i64(num), 10))
            buf[buf_len] = '\x00'
            buf_len += 1
            return strings.unsafe_string_to_cstring(string(buf[0:buf_len]))
        case:
            assert(false, message = "fmt_number requires number")
        }

        unreachable()
    }

    parse_number :: proc($T: typeid, numstr: string) -> (T, bool) {
        type_info := type_info_of(T)

        #partial switch v in type_info.variant {
        case runtime.Type_Info_Float:
            val, ok := strconv.parse_f64(numstr)
            return T(val), ok
        case runtime.Type_Info_Integer:
            val, ok := strconv.parse_i64(numstr)
            return T(val), ok
        case:
            assert(false, message = "parse_number requires number")
        }

        unreachable()
    }

    switch number_input.type {
        case .Slider:
            mouse_within := ut.position_within_bounds(auto_cast rl.GetMousePosition(), auto_cast render_command.boundingBox)
            active := editor_ui.active_index == input_index

            if mouse_within && within && rl.IsMouseButtonPressed(.LEFT) {
                editor_ui.active_index = input_index
            }

            rl.DrawRectangleRec(auto_cast render_command.boundingBox, auto_cast render_info.back_color)

            vertical_padding_1 := f32(render_info.font_size)/2-bar_height/2
            
            mouse_ratio_x := (rl.GetMousePosition().x - (render_command.boundingBox.x+bar_padding_x) - handle_size/2) / (f32(render_command.boundingBox.width) - bar_padding_x*2 - handle_size)
            mouse_ratio_x = max(0.0, min(1.0, mouse_ratio_x))
            
            rl.DrawRectangleRec(rl.Rectangle {
                x = render_command.boundingBox.x+bar_padding_x,
                y = render_command.boundingBox.y+vertical_padding_1,
                width = f32(render_command.boundingBox.width) - bar_padding_x*2,
                height = bar_height,
            }, auto_cast render_info.bar_color)

            range := f32(number_input.max - number_input.min)
            value := f32(number_input.current^ - number_input.min)
            ratio := value / range
            handle_region := render_command.boundingBox.width-bar_padding_x*2-handle_size
            
            if active && rl.IsMouseButtonReleased(.LEFT) {
                editor_ui.active_index = max(ed.InputIndex)
                number_input.current^ = auto_cast ((range * mouse_ratio_x)+f32(number_input.min))
            }

            vertical_padding_2 := f32(render_info.font_size)/2-f32(handle_size/2)

            if !active {
                mouse_ratio_x = ratio
            }

            rl.DrawRectangleRec(rl.Rectangle {
                x = render_command.boundingBox.x+bar_padding_x+mouse_ratio_x*handle_region,
                y = render_command.boundingBox.y+vertical_padding_2,
                width = handle_size,
                height = handle_size,
            }, auto_cast render_info.handle_color)
             
            min_text_buf: [16]u8
            min_text_cstring := fmt_number(min_text_buf[:], number_input.min)
            
            shrunk_font_size: i32 = auto_cast (render_info.font_size*3)/4

            min_text_x := f32(render_command.boundingBox.x+bar_padding_x)
            
            min_text_width: i32 = rl.MeasureText(min_text_cstring, shrunk_font_size)
            
            rl.DrawText(
                min_text_cstring, 
                auto_cast min_text_x, 
                auto_cast (render_command.boundingBox.y+f32(render_info.font_size)),
                auto_cast (render_info.font_size*3)/4, 
                auto_cast render_info.text_color
            )

            max_text_buf: [16]u8
            max_text_cstring := fmt_number(max_text_buf[:], number_input.max)
            
            max_text_width := rl.MeasureText(max_text_cstring, shrunk_font_size)

            max_text_x := f32(render_command.boundingBox.x+render_command.boundingBox.width-f32(bar_padding_x)-f32(max_text_width))
 
            rl.DrawText(
                max_text_cstring, 
                auto_cast max_text_x, 
                auto_cast (render_command.boundingBox.y+f32(render_info.font_size)),
                shrunk_font_size, 
                auto_cast render_info.text_color
            )

            current := ((range * mouse_ratio_x)+f32(number_input.min))
            
            text_buf: [16]u8
            text_cstring := fmt_number(text_buf[:], T(current))
            
            text_width := rl.MeasureText(text_cstring, shrunk_font_size)

            text_x: i32 = i32(render_command.boundingBox.x+f32(bar_padding_x)+mouse_ratio_x*handle_region-f32(text_width)/2+f32(handle_size)/2)
            
            rl.DrawText(
                text_cstring, 
                min(i32(max_text_x)-i32(bar_padding_x)-max_text_width, max(i32(min_text_x)+i32(bar_padding_x)+min_text_width, text_x)),
                auto_cast (render_command.boundingBox.y+f32(render_info.font_size)),
                auto_cast (render_info.font_size*3)/4, 
                auto_cast render_info.handle_color
            )
        case .Text:
            buf: [32]u8
            str := fmt_number(buf[:], number_input.current^)
            
            render_text_input(
                editor_ui, 
                render_command, 
                number_input.placeholder,
                string(str),
                cast(rawptr)number_input.current,
                proc(ptr: rawptr, new_string: string) {
                    parse_str := new_string
                    if new_string[len(new_string)-1] == '\x00' {
                        parse_str = new_string[:len(new_string)-1]
                    }

                    current := cast(^T)ptr
                    val, ok := parse_number(T, parse_str)

                    if ok {
                        current^ = val
                    }
                },
                input_index,
                text_render_info,
                allocator,
                frame_allocator,
                within,
            )
    }
}

render_editor : editorui.RenderFunction = proc(
    editor_ui: ^editorui.EditorUI, 
    userdata: rawptr,
) {
    rl.InitWindow(1080, 720, "yay")
    rl.SetWindowState({.WINDOW_RESIZABLE})

    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()

        mouse_position := rl.GetMousePosition()
        mouse_down := rl.IsMouseButtonDown(.LEFT)
        clay.SetPointerState(mouse_position, mouse_down)
        clay.SetLayoutDimensions({auto_cast rl.GetScreenWidth(), auto_cast rl.GetScreenHeight()})

        rl.BeginDrawing()
        rl.ClearBackground(auto_cast editor_ui.theme.background_color)
        clay_raylib_render(editor_ui, editor_ui.layout_fn(editor_ui, userdata, dt), context.allocator, context.temp_allocator, dt)

        rl.EndDrawing()
    }
}
