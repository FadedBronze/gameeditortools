package main

import rl "vendor:raylib"
import clay "project:clay-odin"
import editorui "project:editorui"
import ut "project:utils"
import rn "project:raylibeditoruirenderer"

import "core:slice"
import "core:strings"
import "base:runtime"
import "core:fmt"

super_panel :: proc(
    editor_ui: ^editorui.EditorUI, 
    appdata: ^AppData,
    placement: EditorPlacement,
) {
    if view_placements[.EditorSet] == placement {
        label := "Editor Settings"
        editorui.render_structure_panel(editor_ui, label, &appdata.editor_settings, label)
    }

    if .PerformanceInfo in appdata.editor_settings.open_views && view_placements[.PerformanceInfo] == placement {
        label := "Performance"
        editorui.render_structure_panel(editor_ui, label, &appdata.pref_stats, label)
    }

    if .NewWorldBounds in appdata.editor_settings.open_views && view_placements[.NewWorldBounds] == placement {
        editorui.render_structure_panel(editor_ui, "New World Bounds", &appdata.new_bounds, "New World Bounds")
    }

    if .Actions in appdata.editor_settings.open_views && view_placements[.Actions] == placement {
        editorui.render_structure_panel(editor_ui, "Actions", &appdata.control, "Actions")
    }

    if .LevelData in appdata.editor_settings.open_views && view_placements[.LevelData] == placement {
        editorui.render_structure_panel(editor_ui, "Level Data", &appdata.level_data, "Level Data")
    }
    
    if .Replays in appdata.editor_settings.open_views && view_placements[.Replays] == placement {
        label := "Replay"
        view_data: struct {
            state: ^ReplayAction "dropdown",
            selected_replay: ^u8 "text",
            replay_file: ^InputReplayFile "group",
        } = {
            state = &appdata.replay_info.action,
            selected_replay = &appdata.replay_info.selected_file,
            replay_file = &appdata.replay_info.loaded,
        }
        editorui.render_structure_panel(editor_ui, label, &view_data, label)
    }

    if .WorldViewports in appdata.editor_settings.open_views && view_placements[.WorldViewports] == placement {
        editorui.render_structure_panel(editor_ui, "Viewport Data", &appdata.viewport_data, "Viewport Data")
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

    if .TileEditor in appdata.editor_settings.open_views && view_placements[.TileEditor] == placement {
        label := "TileEditor"
        editorui.render_structure_panel(editor_ui, label, &appdata.linegrid, label)
        editorui.render_structure_panel(editor_ui, "Selected Tile", &appdata.editor_settings.selected_tile, "Selected Tile")
    }
    
    if .Entities in appdata.editor_settings.open_views && view_placements[.Entities] == placement {
        editorui.render_structure_panel(editor_ui, "Selected Entity", &appdata.editor_settings.selected_entity, "Selected Entity")
        editorui.render_structure_panel(editor_ui, "Placing Entity", &appdata.editor_settings.placing_entity, "Placing Entity")

        for i in 0..<appdata.entities_count {
            entity := &appdata.entities[i]
            if .Something not_in entity.flags {
                continue
            }
            buf: [32]u8
            sb := strings.builder_from_bytes(buf[:])
            label := fmt.sbprintf(&sb, "Entity ID: %d", i+1)
            editorui.render_structure_panel(editor_ui, label, entity, label)
        }
    }

    if .ProgramControl in appdata.editor_settings.open_views && view_placements[.ProgramControl] == placement {
        editorui.render_structure_panel(editor_ui, "Control Panel", &editor_ui.control_panel, "Control Panel")
    }

    if .ThemeEditor in appdata.editor_settings.open_views && view_placements[.ThemeEditor] == placement {
        label := "Theme"
        editorui.render_structure_panel(editor_ui, label, editor_ui.theme, label)
    }
}

create_layout :: proc(
    editor_ui: ^editorui.EditorUI, 
    appdata: rawptr,
    delta_time: f32,
) -> clay.ClayArray(clay.RenderCommand) {
    appdata := cast(^AppData)appdata
    clay.BeginLayout()

    bg := ut.change_opacity(ut.get_contrasting_color(editor_ui.theme.background_color), 20)

    if appdata.fullscreen_viewport_id == max(editorui.ViewportIndex) {
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
                    clip = { vertical = true,
                        childOffset = clay.GetScrollOffset(),
                    },
                    backgroundColor = ut.color_to_f32list(bg),
                }) {
                    super_panel(editor_ui, appdata, .Left)
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
                        sizing = { width = clay.SizingPercent(0.25), height = clay.SizingGrow({}) },
                        layoutDirection = .TopToBottom
                    }, 
                    backgroundColor = ut.color_to_f32list(bg),
                    clip = { vertical = true,
                        childOffset = clay.GetScrollOffset(),
                    },
                }) {
                    super_panel(editor_ui, appdata, .Right)
                }
            }
        }
    } else {
        if clay.UI()({ 
            layout = { 
                padding = clay.PaddingAll(16),
                sizing = { width = clay.SizingGrow({}), height = clay.SizingGrow({}) } 
            }
        }) {
            editorui.gameview(appdata.fullscreen_viewport_id)
        }
    }

    return clay.EndLayout(auto_cast delta_time)
}

clay_basic_renderer :: proc(elements: clay.ClayArray(clay.RenderCommand)) {  
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
    rl.InitWindow(0, 0, "yay")
    rl.SetWindowState({.FULLSCREEN_MODE})

    appdata: AppData
    appdata.level = &appdata.level_data.data
    appdata.editor_settings = &appdata.editor_config_data.data
    appdata.viewport_data = &appdata.viewport_config_data.data
    init_app(&appdata, context.allocator)     

    irenderer := rn.get_interface()
    irenderer.init(irenderer.implementation_data)

    for !irenderer.should_close(irenderer.implementation_data, &appdata.editor_ui) {  
        dt := rl.GetFrameTime()

        irenderer.draw_editor(irenderer.implementation_data, editorui.DrawEditorParams{
            editor_ui = &appdata.editor_ui,
            layout_fn = create_layout, 
            game_render_fn = render, 
            appdata = &appdata, 
            dt = dt
        })

        update(&appdata, dt)
    }

    exit_app(&appdata)
}
