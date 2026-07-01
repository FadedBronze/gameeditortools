package main

import rl "vendor:raylib"
import clay "clay-odin"
import editorui "editorui"
import rn "raylibeditoruirenderer"
import ut "utils"

import "base:runtime"

create_layout :: proc(
    wm: ^editorui.EditorUI, 
    appdata: ^AppData, 
    delta_time: f32,
) -> clay.ClayArray(clay.RenderCommand) {
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

ExampleSubstruct :: struct {
    button: bool "toggle",
    //number: i32 "text placeholder(hi)",
    //hidden: bool,
    //vec: [2]f32 "text min(0) max(10.5)"
}

Example :: struct {
    range: f32 "text min(-1.5) max(10.5)",
    text: string "text placeholder(name)",
    sub: ExampleSubstruct,
}

AppData :: struct {
    example: Example,
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
    
    editorui.initialize_fn_ptrs(&editor_ui, rn.measure_text, layout, rn.render_editor)

    appdata := AppData {
        example = Example {
            range = 4,
            sub = ExampleSubstruct {
                button = false,
                //number = 0,
                //vec = {0.2, 1}
            }
        }
    }    

    editorui.run(&editor_ui, &appdata)
}
