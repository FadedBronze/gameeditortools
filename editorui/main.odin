package editorui
import ed "project:editor"
import clay "project:clay-odin"
import ut "project:utils"

TextInput :: struct {}

NumberTextInput :: struct {}

Slider :: struct {}

ActiveWidgetData :: union {
    Slider,
    NumberTextInput,
    TextInput,
}

EditorUITheme :: struct {
    font_size: u8,
    text_color: ut.Color,
    background_color: ut.Color,
    highlight_color: ut.Color,
}

EditorUI :: struct {
    theme: EditorUITheme,
    active_data: ActiveWidgetData,
    active_index: ed.InputIndex,
    panel_pool: ed.PanelPool,
    panels: map[string]ed.GroupIndex,
}

create_editorui :: proc(theme: EditorUITheme) -> EditorUI {
    return EditorUI {
        panel_pool = ed.create_panel_pool(),
        panels = make(map[string]ed.GroupIndex),
        active_index = max(ed.InputIndex),
        theme = theme,
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
                    fontSize = u16(editor_ui.theme.font_size)*5/4,
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
                    fontSize = u16(editor_ui.theme.font_size),
                    wrapMode = .Words,
                    textColor = {0, 0, 0, 255.0},
                })

                custom_component(editor_ui, panel.label, panel.input)
            }
    }
}

custom_component :: proc(editor_ui: ^EditorUI, id: string, widget: ed.InputIndex) {
    widget_id := clay.ID(id, 0)
    sizing: clay.Sizing
    
    size := clay.SizingFixed(f32(editor_ui.theme.font_size))

    switch v in editor_ui.panel_pool.inputs[widget] {
    case ed.Toggle:
        sizing = { width = size, height = size }
    case ed.TextInput:
        sizing = { width = clay.SizingGrow({}), height = size }
    case ed.NumberInput(f32), ed.NumberInput(u32), ed.NumberInput(u64), ed.NumberInput(f64), ed.NumberInput(i32), ed.NumberInput(u8):
        sizing = { width = clay.SizingGrow({}), height = clay.SizingFixed(f32(editor_ui.theme.font_size)*1.75+2) }
    }

    if clay.UI(widget_id)({ 
        layout = { 
            sizing = sizing,
            layoutDirection = .TopToBottom,
            padding = clay.Padding { 0, 0, 0, 0 },
        },
        custom = {customData = cast(rawptr)(cast(uintptr)widget+1)}
    }) {}
}
