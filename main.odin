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
                label := "example"
                editorui.render_structure_panel(editor_ui, label, &appdata.example, label)
            }

            if clay.UI()({ 
                layout = { 
                    sizing = { width = clay.SizingPercent(0.5), height = clay.SizingGrow({}) },
                    layoutDirection = .TopToBottom,
                }, 
                backgroundColor = editorui.color_to_clay_color(bg),
            }) {
                if clay.UI()({ 
                    layout = { 
                        sizing = { width = clay.SizingPercent(1), height = clay.SizingPercent(0.5) } 
                    }, 
                }) {
                    editorui.gameview()
                }
                if clay.UI()({ 
                    layout = { 
                        sizing = { width = clay.SizingPercent(1), height = clay.SizingPercent(0.5) } 
                    }, 
                }) {
                    editorui.gameview()
                }
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

ExamplePhysics :: struct {
    pause: bool "toggle",
    speed: f32 "slider min(-0.69) max(0.69)",
}

ExampleColor :: enum {
    Red,
    Orange,
    Blue,
}

Example :: struct {
    name: string "text placeholder(name)",
    color: ExampleColor "dropdown",
    physics: ExamplePhysics "group",
}

AppData :: struct {
    example: Example,
}

offset: f32 = 0
update :: proc(appdata: rawptr, screen_rect: ut.Bounds(f32), delta_time: f32) {
    appdata: ^AppData = cast(^AppData)appdata

    if !appdata.example.physics.pause {
        offset += appdata.example.physics.speed
    }

    color: ut.Color

    switch appdata.example.color {
        case .Red:
            color = ut.Color{255, 0, 0, 255}
        case .Orange:
            color = ut.Color{255, 125, 0, 255}
        case .Blue:
            color = ut.Color{0, 125, 255, 255}
    }

    rl.DrawRectangleRec(rl.Rectangle{
        x = f32(int(screen_rect.width/2+50 + offset) % int(screen_rect.width+100))+screen_rect.x-100,
        y = screen_rect.y+screen_rect.height/2-50,
        width = 100,
        height = 100,
    }, auto_cast color)
}

main :: proc() { 
    editor_ui: editorui.EditorUI = editorui.create_editorui(editorui.EditorUITheme {
        font_size = 16,
        text_color = ut.Color {192, 192, 192, 240},
        background_color = ut.BLACK,
        highlight_color = ut.Color {255, 0, 0, 255}
    }, context.allocator)
    
    layout := proc(editor_ui: ^editorui.EditorUI, appdata: rawptr, delta_time: f32) -> clay.ClayArray(clay.RenderCommand) {
        return create_layout(editor_ui, cast(^AppData)appdata, rl.GetFrameTime())
    }
    
    appdata := AppData {
        example = Example {}
    }    
    
    editorui.initialize_fn_ptrs(&editor_ui, rn.measure_text, layout, rn.render_editor, {
        fn = update,
        data = &appdata
    })

    editorui.run(&editor_ui, &appdata)
}
