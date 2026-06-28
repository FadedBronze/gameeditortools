package editorui
import ed "project:editor"
import clay "project:clay-odin"

TextInput :: struct {}

NumberTextInput :: struct {}

Slider :: struct {}

ActiveWidgetData :: union {
    Slider,
    NumberTextInput,
    TextInput,
}

EditorUI :: struct {
    active_data: ActiveWidgetData,
    active_id: clay.ElementId,
    panel_pool: ed.PanelPool,
    panels: map[string]ed.GroupIndex,
}

create_editorui :: proc() -> EditorUI {
    return EditorUI {
        panel_pool = ed.create_panel_pool(),
        panels = make(map[string]ed.GroupIndex),
    }
}

render_structure_panel :: proc(editor_ui: ^EditorUI, id: string, structure: ^$T, label: string) {
    if panel, ok := editor_ui.panels[id]; ok {
        render_panel_recurse(editor_ui, &editor_ui.panel_pool.groups[panel])
    } else {
        panel := ed.create_panel(&editor_ui.panel_pool, structure, label)
        editor_ui.panels[id] = panel
        render_panel_recurse(editor_ui, &editor_ui.panel_pool.groups[panel])
    }
}

render_panel_recurse :: proc(editor_ui: ^EditorUI, panel: ^ed.Group) {
    switch panel.type {
        case .Subgroup:
            if clay.UI()({ 
                layout = { 
                    sizing = { width = clay.SizingGrow({}), height = clay.SizingGrow({}) } ,
                    childGap = 5,
                    layoutDirection = .TopToBottom,
                    padding = clay.PaddingAll(10),
                }, 
                backgroundColor = {0, 0, 0, 20},
            }) {
                clay.Text(panel.label, clay.TextElementConfig {
                    fontSize = 24,
                    wrapMode = .Words,
                    textColor = {0, 0, 0, 255.0},
                })

                if clay.UI()({ 
                    layout = { 
                        sizing = { width = clay.SizingGrow({}), height = clay.SizingGrow({}) } ,
                        childGap = 5,
                        layoutDirection = .TopToBottom,
                    }, 
                }) {
                    for group_index in panel.subgroup {
                        render_panel_recurse(editor_ui, &editor_ui.panel_pool.groups[group_index])
                    }
                }
            }
        case .Component:
            if clay.UI()({ 
                layout = { 
                    sizing = { width = clay.SizingPercent(1.0), height = clay.SizingFit({}) } ,
                    childGap = 5,
                }, 
            }) {
                clay.Text(panel.label, clay.TextElementConfig {
                    fontSize = 18,
                    wrapMode = .Words,
                    textColor = {0, 0, 0, 255.0},
                })

                #partial switch input in editor_ui.panel_pool.inputs[panel.input] {
                case ed.Toggle:
                    render_toggle(panel.label, input.current)
                case ed.NumberInput(f32):
                    switch input.type {
                        case .Slider:
                            render_slider(panel.label, input.current, input.min, input.max)
                        case .Text:
                            render_number_text_input(panel.label, input.current, input.min, input.max, input.placeholder)
                    }
                case:
                }
            }
    }
}

render_toggle :: proc(id: string, current: ^bool) {
    bg_color: clay.Color = current^ ? {0, 0, 0, 255} : {0, 0, 0, 125}
    toggle_id := clay.ID(id, 1)

    if clay.UI(toggle_id)({ 
        layout = { 
            sizing = { width = clay.SizingFixed(20), height = clay.SizingFixed(20) } ,
            childGap = 5,
        }, 
        backgroundColor = bg_color
    }) {}

    ptrdata := clay.GetPointerState()

    if (clay.PointerOver(toggle_id) && ptrdata.state == .PressedThisFrame) {
        current^ = !(current^)
    }
}

render_number_text_input :: proc(id: string, current: ^$T, min: T, max: T, placeholder: string) {
    unimplemented()
}

render_slider :: proc(id: string, current: ^$T, min: T, max: T) {
    slider_id := clay.ID(id, 0)
    if clay.UI(slider_id)({ 
        layout = { 
            sizing = { width = clay.SizingGrow({}), height = clay.SizingGrow({}) },
            layoutDirection = .TopToBottom,
            padding = clay.Padding { 0, 0, 0, 0 },
        },
        backgroundColor = {0, 0, 0, 20},
    }) {}

    data := clay.GetElementData(slider_id)
    if data.found {
        data.boundingBox
    }
}
