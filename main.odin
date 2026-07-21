package main

import rl "vendor:raylib"
import clay "clay-odin"
import editorui "editorui"
import rn "raylibeditoruirenderer"
import ut "utils"

import "core:slice"
import "core:strings"
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
                    sizing = { width = clay.SizingPercent(0.25), height = clay.SizingGrow({}) },
                    layoutDirection = .TopToBottom,
                    childGap = 5,
                }, 
                backgroundColor = ut.color_to_f32list(bg),
            }) {
                editorui.render_structure_panel(editor_ui, "Editor Settings", &appdata.editor_settings, "Editor Settings")

                if .WorldViewports in appdata.editor_settings.open_views {
                    lables := []string{
                        "Viewport 1",
                        "Viewport 2",
                    }
                    for i in 0..<2 {
                        viewport := &appdata.viewports[i]
                        label := lables[i]
                        editorui.render_structure_panel(editor_ui, label, &viewport, label)
                    }
                }

                if .TileEditor in appdata.editor_settings.open_views {
                    label := "Tilegrid"
                    editorui.render_structure_panel(editor_ui, label, &appdata.tilegrid, label)
                }
            }

            if clay.UI()({ 
                layout = { 
                    sizing = { width = clay.SizingPercent(0.5), height = clay.SizingGrow({}) },
                    layoutDirection = .TopToBottom,
                }, 
                backgroundColor = ut.color_to_f32list(bg),
            }) {
                if clay.UI()({ 
                    layout = { 
                        sizing = { width = clay.SizingPercent(1), height = clay.SizingPercent(0.5) } 
                    }, 
                }) {
                    editorui.gameview(0)
                }

                if clay.UI()({ 
                    layout = { 
                        sizing = { width = clay.SizingPercent(1), height = clay.SizingPercent(0.5) } 
                    }, 
                }) {
                    editorui.gameview(1)
                }
            }

            if clay.UI()({ 
                layout = { 
                    sizing = { width = clay.SizingPercent(0.25), height = clay.SizingGrow({}) } 
                }, 
                backgroundColor = ut.color_to_f32list(bg),
            }) {
                label := "Theme"
                editorui.render_structure_panel(editor_ui, label, &editor_ui.theme, label)
            }
        }
    }

    return clay.EndLayout(auto_cast delta_time)
}

clay_renderer :: proc(elements: clay.ClayArray(clay.RenderCommand)) {  
    slx := slice.from_ptr(elements.internalArray, auto_cast elements.length)

    for element in slx {
        render_command: clay.RenderCommand = element;
        //fmt.println(render_command.zIndex)

        switch render_command.commandType {
            case .None:
            case .Rectangle:
                color := render_command.renderData.rectangle.backgroundColor
                rl.DrawRectangleRec(auto_cast render_command.boundingBox, auto_cast ut.f32list_to_color(color))
            case .Border:
                //color := render_command.renderData.border.color
                //rl.DrawRectangleLines(auto_cast render_command.boundingBox, clay_to_raylib_color(color))
            case .Text:
                text_command := render_command.renderData.text
                text := text_command.stringContents
                s := strings.string_from_ptr(text.chars, auto_cast text.length)
                cs := strings.clone_to_cstring(s, context.temp_allocator)
                box := render_command.boundingBox

                rl.DrawTextEx(
                    rn.get_font(&rn.font_table, 0, text_command.fontSize),
                    cs, 
                    {auto_cast box.x, auto_cast box.y},
                    auto_cast text_command.fontSize, 
                    auto_cast text_command.letterSpacing, 
                    auto_cast ut.f32list_to_color(auto_cast text_command.textColor)
                )
            case .Custom:
            case .ScissorStart:
                rl.BeginScissorMode(
                    i32(render_command.boundingBox.x),
                    i32(render_command.boundingBox.y),
                    i32(render_command.boundingBox.width),
                    i32(render_command.boundingBox.height)
                )
            case .ScissorEnd:
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

error_handler :: proc "c" (errorData: clay.ErrorData) {
    //fmt.println(errorData)
}

main :: proc() { 
    editor_ui: editorui.EditorUI = editorui.create_editorui(editorui.EditorUITheme {
        font_size = 16,
        letter_spacing = 1,
        text_color = ut.Color {192, 192, 192, 240},
        background_color = ut.BLACK,
        highlight_color = ut.Color {255, 0, 0, 255}
    }, context.allocator)
    
    layout := proc(editor_ui: ^editorui.EditorUI, appdata: rawptr, delta_time: f32) -> clay.ClayArray(clay.RenderCommand) {
        return create_layout(editor_ui, cast(^AppData)appdata, rl.GetFrameTime())
    }
    
    appdata: AppData
    initialize_app(&appdata, context.allocator)
    
    editorui.initialize_fn_ptrs(
        &editor_ui, 
        rn.measure_text, 
        layout, 
        rn.render_editor, 
        { fn = render, data = &appdata },
        { fn = update, data = &appdata }
    )

    editorui.run(&editor_ui, &appdata)
}
