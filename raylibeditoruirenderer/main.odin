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

clay_raylib_render :: proc(editor_ui: ^editorui.EditorUI, elements: clay.ClayArray(clay.RenderCommand), allocator: mem.Allocator, frame_allocator: mem.Allocator) {
    slx := slice.from_ptr(elements.internalArray, auto_cast elements.length)

    for element in slx {
        render_command: clay.RenderCommand = element;

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
                render_custom_widget(editor_ui, render_command, allocator, frame_allocator)
            case .ScissorStart:
                unimplemented()
            case .ScissorEnd:
                unimplemented()
            case .Image:
                unimplemented()
            case .OverlayColorStart:
                unimplemented()
            case .OverlayColorEnd:
                unimplemented()
        }
    }
}

render_custom_widget :: proc(editor_ui: ^editorui.EditorUI, render_command: clay.RenderCommand, allocator: mem.Allocator, frame_allocator: mem.Allocator) {
    input_index: ed.InputIndex = cast(ed.InputIndex)(cast(uintptr)render_command.renderData.custom.customData-1)
    input := editor_ui.panel_pool.inputs[input_index]
    widget_color := ut.blend_two_colors(editor_ui.theme.background_color, editor_ui.theme.text_color, 0.1)
    widget_color_placeholder := ut.blend_two_colors(editor_ui.theme.background_color, editor_ui.theme.text_color, 0.3)
    widget_color_dark := ut.blend_two_colors(editor_ui.theme.background_color, editor_ui.theme.text_color, 0.9)

    slider_render_info := SliderRenderInfo {
        back_color = widget_color,
        font_size = editor_ui.theme.font_size,
        bar_color = widget_color_dark,
        handle_color = editor_ui.theme.highlight_color,
        text_color = editor_ui.theme.text_color,
        bar_height = 8,
        bar_padding_x = 3,
        handle_size = 10,
    }
    
    text_render_info := TextInputRenderInfo {
        back_color = widget_color,
        font_size = editor_ui.theme.font_size,
        border_color = widget_color_dark,
        caret_color = editor_ui.theme.highlight_color,
        caret_width = 1,
        text_color = editor_ui.theme.text_color,
        placeholder_text_color = widget_color_placeholder,
        padding = 3,
    }

    #partial switch input_data in input {
    case ed.Toggle:
        within := ut.position_within_bounds(rl.GetMousePosition(), auto_cast render_command.boundingBox)
        if within && rl.IsMouseButtonPressed(.LEFT) {
            input_data.current^ = !input_data.current^
        }
        if input_data.current^ {
            rl.DrawRectangleRec(auto_cast render_command.boundingBox, auto_cast widget_color_dark)
        } else {
            rl.DrawRectangleRec(auto_cast render_command.boundingBox, auto_cast widget_color)
        }
    case ed.TextInputString:
        render_text_input(editor_ui, render_command, input_data, input_index, text_render_info, allocator, frame_allocator)
    case ed.TextInputMutableBuffer:
        //input_data.
    case ed.NumberInput(f64):
        render_number_input(editor_ui, render_command, input_data, input_index, slider_render_info)
    case ed.NumberInput(i32):
        render_number_input(editor_ui, render_command, input_data, input_index, slider_render_info)
    case ed.NumberInput(u8):
        render_number_input(editor_ui, render_command, input_data, input_index, slider_render_info)
    case ed.NumberInput(f32):
        render_number_input(editor_ui, render_command, input_data, input_index, slider_render_info)
    case ed.NumberInput(u64):
        render_number_input(editor_ui, render_command, input_data, input_index, slider_render_info)
    case ed.NumberInput(u32):
        render_number_input(editor_ui, render_command, input_data, input_index, slider_render_info)
    }
}

TextInputRenderInfo :: struct {
    font_size: u8,
    padding: u8,
    caret_width: u8,
    caret_color: ut.Color,
    back_color: ut.Color,
    border_color: ut.Color,
    placeholder_text_color: ut.Color,
    text_color: ut.Color,
}

render_text_input :: proc(
    editor_ui: ^editorui.EditorUI,
    render_command: clay.RenderCommand, 
    text_input: ed.TextInputString, 
    input_index: ed.InputIndex,
    render_info: TextInputRenderInfo,
    allocator: mem.Allocator,
    frame_allocator: mem.Allocator,
) {
    mouse_within := ut.position_within_bounds(auto_cast rl.GetMousePosition(), auto_cast render_command.boundingBox)
    rl.DrawRectangleRec(auto_cast render_command.boundingBox, auto_cast render_info.back_color)
    active := editor_ui.active_index == input_index
    padding := f32(render_info.padding)

    if active {
        rl.DrawRectangleLinesEx(auto_cast render_command.boundingBox, 1, auto_cast render_info.border_color)
    }

    if mouse_within && rl.IsMouseButtonPressed(.LEFT) {
        // TODO: decide how this gets freed properly
        active_data := editorui.TextInputString {
            buf = make([]u8, 32),
            buf_len = 1,
        }

        prev_str := text_input.text == nil ? "" : text_input.text^

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
        active_data := &editor_ui.active_data.(editorui.TextInputString)
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
            }
            
            key = rl.GetKeyPressed()
        }
    }

    if (rl.IsKeyPressed(.ESCAPE) || rl.IsMouseButtonPressed(.LEFT) && !mouse_within) && active {
        editor_ui.active_index = max(ed.InputIndex)
        active_data := &editor_ui.active_data.(editorui.TextInputString)
        text_input.text^ = string(active_data.buf[0:active_data.buf_len])
    }
    
    empty := text_input.text == nil || text_input.text^ == ""
    render_string: cstring
    text_color: ut.Color

    if active {
        active_data := editor_ui.active_data.(editorui.TextInputString)

        text_cstring := strings.clone_to_cstring(string(active_data.buf[:active_data.buf_len]), frame_allocator)
        render_string = text_cstring
        text_color = render_info.text_color
    } else if empty {
        placeholder := strings.clone_to_cstring(text_input.placeholder, frame_allocator)
        render_string = placeholder
        text_color = render_info.placeholder_text_color
    } else {
        text_cstring := strings.clone_to_cstring(text_input.text^, frame_allocator)
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

SliderRenderInfo :: struct {
    font_size: u8,
    bar_height: u8,
    bar_padding_x: u8,
    handle_size: u8,
    back_color: ut.Color, 
    bar_color: ut.Color, 
    handle_color: ut.Color,
    text_color: ut.Color,
}

render_number_input :: proc(
    editor_ui: ^editorui.EditorUI,
    render_command: clay.RenderCommand, 
    number_input: ed.NumberInput($T), 
    input_index: ed.InputIndex,
    render_info: SliderRenderInfo,
) {
    handle_size := f32(render_info.handle_size)
    bar_padding_x := f32(render_info.bar_padding_x)
    bar_height := f32(render_info.bar_height)

    switch number_input.type {
        case .Slider:
            mouse_within := ut.position_within_bounds(auto_cast rl.GetMousePosition(), auto_cast render_command.boundingBox)
            active := editor_ui.active_index == input_index

            if mouse_within && rl.IsMouseButtonPressed(.LEFT) {
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
            min_text_len := len(strconv.write_float(min_text_buf[:], f64(number_input.min), 'f', 2, 64))
            min_text_buf[min_text_len] = '\x00'
            min_text_len += 1
            min_text_cstring := strings.unsafe_string_to_cstring(string(min_text_buf[0:min_text_len]))
            
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
            max_text_len := len(strconv.write_float(max_text_buf[:], f64(number_input.max), 'f', 2, 64))
            max_text_buf[max_text_len] = '\x00'
            max_text_len += 1
            max_text_cstring := strings.unsafe_string_to_cstring(string(max_text_buf[0:max_text_len]))
            
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
            text_len := len(strconv.write_float(text_buf[:], f64(current), 'f', 2, 64))
            text_buf[text_len] = '\x00'
            text_len += 1
            text_cstring := strings.unsafe_string_to_cstring(string(text_buf[0:text_len]))
            
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
    }
}

render_editor : editorui.RenderFunction = proc(
    editor_ui: ^editorui.EditorUI, 
    userdata: rawptr,
) {
    rl.InitWindow(1080, 720, "yay")
    rl.SetWindowState({.WINDOW_RESIZABLE})

    for !rl.WindowShouldClose() {
        mouse_position := rl.GetMousePosition()
        mouse_down := rl.IsMouseButtonDown(.LEFT)
        clay.SetPointerState(mouse_position, mouse_down)
        clay.SetLayoutDimensions({auto_cast rl.GetScreenWidth(), auto_cast rl.GetScreenHeight()})

        rl.BeginDrawing()
        rl.ClearBackground(rl.WHITE)
        clay_raylib_render(editor_ui, editor_ui.layout_fn(editor_ui, userdata, rl.GetFrameTime()), context.allocator, context.temp_allocator)
        rl.EndDrawing()
    }
}
