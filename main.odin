package main
import rl "vendor:raylib"
import clay "clay-odin"
import "core:strings"
import "base:runtime"
import "core:slice"
import editorui "editorui"
import ut "utils"
import "core:strconv"

error_handler :: proc "c" (errorData: clay.ErrorData) {
    //fmt.println(errorData)
}

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

ExampleSubstruct :: struct {
    button: bool "type: 'toggle'",
    //number: i32 "placeholder: 'hi'",
    //hidden: bool "type: 'hidden'",
    //vec: [2]f32 "min: '0', max: '10.5'"
}

Example :: struct {
    range: f32 "type: 'slider', min: '-1.5', max: '10'",
    epic_button: bool "type: 'toggle'",
    //text: EditableText "placeholder: 'value'",
    sub: ExampleSubstruct,
}

AppData :: struct {
    example: Example,
}

create_layout :: proc(wm: ^editorui.EditorUI, appdata: ^AppData, delta_time: f32) -> clay.ClayArray(clay.RenderCommand) {
    clay.BeginLayout()

    if clay.UI()({ 
        layout = { 
            padding = clay.PaddingAll(16),
            sizing = { width = clay.SizingGrow({}), height = clay.SizingGrow({}) } 
        }
    }) {
        if clay.UI()({ 
            layout = { 
                sizing = { width = clay.SizingGrow({}), height = clay.SizingGrow({}) } ,
                childGap = 5,
            }, 
        }) {
            if clay.UI()({ 
                layout = { 
                    sizing = { width = clay.SizingPercent(0.25), height = clay.SizingGrow({}) } 
                }, 
                backgroundColor = {0, 0, 0, 20},
            }) {
                label := "extra thinggy thing"
                editorui.render_structure_panel(wm, label, &appdata.example, label)
            }

            if clay.UI()({ 
                layout = { 
                    sizing = { width = clay.SizingPercent(0.5), height = clay.SizingGrow({}) } 
                }, 
                backgroundColor = {0, 0, 0, 20},
            }) {
            }

            if clay.UI()({ 
                layout = { 
                    sizing = { width = clay.SizingPercent(0.25), height = clay.SizingGrow({}) } 
                }, 
                backgroundColor = {0, 0, 0, 20},
            }) {
            }
        }
    }

    return clay.EndLayout(auto_cast delta_time)
}

clay_to_raylib_color :: proc(color: clay.Color) -> rl.Color {
    return {u8(color.r), u8(color.g), u8(color.b), u8(color.a)}
}

clay_raylib_render :: proc(editor_ui: ^editorui.EditorUI, elements: clay.ClayArray(clay.RenderCommand)) {
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
                render_custom_widget(editor_ui, render_command)
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

import ed "editor"

render_custom_widget :: proc(editor_ui: ^editorui.EditorUI, render_command: clay.RenderCommand) {
    input_index: ed.InputIndex = cast(ed.InputIndex)(cast(uintptr)render_command.renderData.custom.customData-1)
    input := editor_ui.panel_pool.inputs[input_index]
    widget_color := ut.blend_two_colors(editor_ui.theme.background_color, editor_ui.theme.text_color, 0.1)
    widget_color_dark := ut.blend_two_colors(editor_ui.theme.background_color, editor_ui.theme.text_color, 0.9)

    slider_render_info := SliderRenderInfo {
        back_color = widget_color,
        font_size = editor_ui.theme.font_size,
        bar_color = widget_color_dark,
        handle_color = editor_ui.theme.highlight_color,
        text_color = editor_ui.theme.text_color,
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

SliderRenderInfo :: struct {
    font_size: u8,
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
    bar_height := 8
    bar_padding_x := 3

    handle_size: f32 = 10

    switch number_input.type {
        case .Slider:
            mouse_within := ut.position_within_bounds(auto_cast rl.GetMousePosition(), auto_cast render_command.boundingBox)
            active := editor_ui.active_index == input_index

            if mouse_within && rl.IsMouseButtonPressed(.LEFT) {
                editor_ui.active_index = input_index
            }

            rl.DrawRectangleRec(auto_cast render_command.boundingBox, auto_cast render_info.back_color)

            vertical_padding_1 := f32(render_info.font_size)/2-f32(bar_height/2)
            
            mouse_ratio_x := (rl.GetMousePosition().x - (render_command.boundingBox.x+f32(bar_padding_x)) - handle_size/2) / (f32(render_command.boundingBox.width) - f32(bar_padding_x)*2 - handle_size)
            mouse_ratio_x = max(0.0, min(1.0, mouse_ratio_x))
            
            rl.DrawRectangleRec(rl.Rectangle {
                x = render_command.boundingBox.x+f32(bar_padding_x),
                y = render_command.boundingBox.y+vertical_padding_1,
                width = f32(render_command.boundingBox.width) - f32(bar_padding_x)*2,
                height = f32(bar_height),
            }, auto_cast render_info.bar_color)

            range := f32(number_input.max - number_input.min)
            value := f32(number_input.current^ - number_input.min)
            ratio := value / range
            handle_region := render_command.boundingBox.width-f32(bar_padding_x)*2-handle_size
            
            if active && rl.IsMouseButtonReleased(.LEFT) {
                editor_ui.active_index = max(ed.InputIndex)
                number_input.current^ = auto_cast ((range * mouse_ratio_x)+f32(number_input.min))
            }

            vertical_padding_2 := f32(render_info.font_size)/2-f32(handle_size/2)

            if !active {
                mouse_ratio_x = ratio
            }

            rl.DrawRectangleRec(rl.Rectangle {
                x = render_command.boundingBox.x+f32(bar_padding_x)+mouse_ratio_x*handle_region,
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

            min_text_x := f32(render_command.boundingBox.x+f32(bar_padding_x))
            
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

main :: proc() {
    min_memory_size := clay.MinMemorySize()
    memory := make([^]u8, min_memory_size)
    arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(uint(min_memory_size), memory)
    clay.Initialize(arena, {1080, 720}, { handler = error_handler })
    clay.SetMeasureTextFunction(measure_text, nil)

    rl.InitWindow(1080, 720, "yay")
    rl.SetWindowState({.WINDOW_RESIZABLE})
    
    editor_ui := editorui.create_editorui(editorui.EditorUITheme {
        font_size = 16,
        text_color = ut.BLACK,
        background_color = ut.WHITE,
        highlight_color = ut.Color {255, 0, 0, 255}
    })

    appdata := AppData {
        example = Example {
            range = 4.25,
            epic_button = false,
            sub = ExampleSubstruct {
                button = false,
                //number = 0,
                //vec = {0.2, 1}
            }
        }
    }

    for !rl.WindowShouldClose() {
        mouse_position := rl.GetMousePosition()
        mouse_down := rl.IsMouseButtonDown(.LEFT)
        clay.SetPointerState(mouse_position, mouse_down)
        clay.SetLayoutDimensions({auto_cast rl.GetScreenWidth(), auto_cast rl.GetScreenHeight()})

        elements := create_layout(&editor_ui, &appdata, rl.GetFrameTime())

        rl.BeginDrawing()
        rl.ClearBackground(rl.WHITE)
        clay_raylib_render(&editor_ui, elements)
        rl.EndDrawing()
    }
}
