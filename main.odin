package main
import rl "vendor:raylib"
import clay "clay-odin"
import "core:strings"
import "base:runtime"
import "core:slice"
import editorui "editorui"

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

clay_raylib_render :: proc(elements: clay.ClayArray(clay.RenderCommand)) {
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
            case .Custom:
                unimplemented()
        }
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
    
    editor_ui := editorui.create_editorui()

    appdata := AppData {
        example = Example {
            range = 5,
            //sub = ExampleSubstruct {
            //    button = false,
            //    number = 0,
            //    vec = {0.2, 1}
            //}
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
        clay_raylib_render(elements)
        rl.EndDrawing()
    }
}
