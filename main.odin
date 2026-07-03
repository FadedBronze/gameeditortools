package main

import rl "vendor:raylib"
import clay "clay-odin"
import editorui "editorui"
import rn "raylibeditoruirenderer"
import ut "utils"

import "core:fmt"
import "base:runtime"

create_layout :: proc(
    editor_ui: ^editorui.EditorUI, 
    appdata: ^AppData, 
    delta_time: f32,
) -> clay.ClayArray(clay.RenderCommand) {
    clay.BeginLayout()

    bg := ut.change_opacity(ut.get_contrasting_color(editor_ui.theme.background_color), 20)

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
                backgroundColor = editorui.color_to_clay_color(bg),
            }) {
            }

            if clay.UI()({ 
                layout = { 
                    sizing = { width = clay.SizingPercent(0.5), height = clay.SizingGrow({}) } 
                }, 
                backgroundColor = editorui.color_to_clay_color(bg),
            }) {
                editorui.gameview()
            }

            if clay.UI()({ 
                layout = { 
                    sizing = { width = clay.SizingPercent(0.25), height = clay.SizingGrow({}) } 
                }, 
                backgroundColor = editorui.color_to_clay_color(bg),
            }) {
                label := "theme"
                editorui.render_structure_panel(editor_ui, label, &editor_ui.theme, label)
            }
        }
    }

    return clay.EndLayout(auto_cast delta_time)
}

ExampleSubstruct :: struct {
    button: bool "toggle",
    //number: i32 "text placeholder(hi)",
    range: f32 "slider min(-1.5) max(10.5)",
    hidden: bool,
    //vec: [2]f32 "text min(0) max(10.5)"
}

Example :: struct {
    yuh: i32 "text min(0) max(100)",
    text: string "text placeholder(name)",
    element: Element "dropdown",
    sub: ExampleSubstruct "group",
}

AppData :: struct {
    example: Example,
}

Element :: enum {
    Fire,
    Water,
    Earth,
    Air,
}

update :: proc(appdata: rawptr, screen_rect: ut.Bounds(f32), delta_time: f32) {
    fmt.println(delta_time, screen_rect)
}

main :: proc() { 
    editor_ui: editorui.EditorUI = editorui.create_editorui(editorui.EditorUITheme {
        font_size = 16,
        text_color = ut.BLACK,
        background_color = ut.WHITE,
        highlight_color = ut.Color {255, 0, 0, 255}
    }, context.allocator)
    
    layout := proc(editor_ui: ^editorui.EditorUI, appdata: rawptr, delta_time: f32) -> clay.ClayArray(clay.RenderCommand) {
        return create_layout(editor_ui, cast(^AppData)appdata, rl.GetFrameTime())
    }
    
    appdata := AppData {
        example = Example {
            sub = ExampleSubstruct {
            range = 4,
                button = false,
                //number = 0,
                //vec = {0.2, 1}
            },
            element = .Earth,
        }
    }    
    
    editorui.initialize_fn_ptrs(&editor_ui, rn.measure_text, layout, rn.render_editor, {
        fn = update,
        data = &appdata
    })

    editorui.run(&editor_ui, &appdata)
}
