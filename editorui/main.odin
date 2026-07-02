package editorui

import ed   "project:editor"
import clay "project:clay-odin"
import ut   "project:utils"
import      "project:editorui"

import "core:strings"
import "core:mem"
import "core:fmt"

TextInput :: struct {
    buf: []u8,
    buf_len: u8,
}

NumberTextInput :: struct {}

Slider :: struct {}

ActiveWidgetData :: union {
    Slider,
    TextInput,
}

EditorUITheme :: struct {
    font_size: u8 "slider min(10) max(30)",
    text_color: ut.Color "slider",
    background_color: ut.Color "slider",
    highlight_color: ut.Color "slider",
}

EditorUI :: struct {
    theme: EditorUITheme,
    active_data: ActiveWidgetData,
    active_index: ed.InputIndex,

    panel_pool: ed.PanelPool,
    panels: map[string]ed.GroupIndex,
    layout_fn: LayoutFunction,
    render_fn: RenderFunction,
}

color_to_clay_color :: proc(color: ut.Color) -> clay.Color {
    return {
        f32(color.r),
        f32(color.g),
        f32(color.b),
        f32(color.a),
    }
}

error_handler :: proc "c" (errorData: clay.ErrorData) {
    //fmt.println(errorData)
}

RenderFunction :: proc(^EditorUI, rawptr)

LayoutFunction :: proc (
    editor_ui: ^EditorUI, 
    appdata: rawptr, 
    delta_time: f32,
) -> clay.ClayArray(clay.RenderCommand)

MeasureTextFunction :: proc "c" (text: clay.StringSlice, config: ^clay.TextElementConfig, userData: rawptr) -> clay.Dimensions

initialize_fn_ptrs :: proc(
    editor_ui: ^EditorUI,
    measure_text: MeasureTextFunction,
    layout_fn: LayoutFunction,
    render_fn: RenderFunction,
) {
    editor_ui.layout_fn = layout_fn
    editor_ui.render_fn = render_fn
    clay.SetMeasureTextFunction(measure_text, nil)
}

create_editorui :: proc(theme: EditorUITheme, allocator: mem.Allocator) -> EditorUI {
    min_memory_size := clay.MinMemorySize()
    memory := make([^]u8, min_memory_size, allocator)
    arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(uint(min_memory_size), memory)

    clay.Initialize(arena, {1080, 720}, { handler = error_handler })

    return EditorUI {
        panel_pool = ed.create_panel_pool(allocator),
        panels = make(map[string]ed.GroupIndex, allocator),
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
                backgroundColor = color_to_clay_color(ut.change_opacity(ut.get_contrasting_color(editor_ui.theme.background_color), 20)),
            }) {
                if !strings.has_prefix(panel.label, "__") {
                    clay.Text(panel.label, clay.TextElementConfig {
                        fontSize = u16(editor_ui.theme.font_size)*5/4,
                        wrapMode = .Words,
                        textColor = color_to_clay_color(editor_ui.theme.text_color),
                    })
                }

                if clay.UI()({ 
                    layout = { 
                        sizing = { width = clay.SizingGrow({}), height = clay.SizingGrow({}) } ,
                        childGap = 5,
                        layoutDirection = .TopToBottom,
                    }, 
                }) {
                    for group_index in panel.subgroup {
                        if group_index != 0 {
                            render_panel_recurse(editor_ui, &editor_ui.panel_pool.groups[group_index])
                        }
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
                if !strings.has_prefix(panel.label, "__") {
                    clay.Text(panel.label, clay.TextElementConfig {
                        fontSize = u16(editor_ui.theme.font_size),
                        wrapMode = .Words,
                        textColor = color_to_clay_color(editor_ui.theme.text_color),
                    })
                }

                //fmt.println(panel.label)
                custom_component(editor_ui, panel.label, panel.input)
            }
    }
}

custom_component :: proc(editor_ui: ^EditorUI, id: string, widget: ed.InputIndex) {
    sizing: clay.Sizing
    
    size := clay.SizingFixed(f32(editor_ui.theme.font_size))
    z_index: i16 = 1

    number_input_sizing :: proc(editor_ui: ^EditorUI, number_input: ed.NumberInput($T)) -> clay.Sizing {
        switch number_input.type {
        case .Slider:
            return { width = clay.SizingGrow({}), height = clay.SizingFixed(f32(editor_ui.theme.font_size)*1.75+2) }
        case .Text:
            return { width = clay.SizingGrow({}), height = clay.SizingFixed(f32(editor_ui.theme.font_size)) }
        }
        unreachable()
    }

    switch v in editor_ui.panel_pool.inputs[widget] {
    case ed.Toggle:
        sizing = { width = size, height = size }
    case ed.TextInputMutableBuffer:
        sizing = { width = clay.SizingGrow({}), height = size }
    case ed.TextInputString:
        sizing = { width = clay.SizingGrow({}), height = size }

    case ed.NumberInput(f32):
        sizing = number_input_sizing(editor_ui, v)
    case ed.NumberInput(u32):
        sizing = number_input_sizing(editor_ui, v)
    case ed.NumberInput(u64):
        sizing = number_input_sizing(editor_ui, v)
    case ed.NumberInput(f64):
        sizing = number_input_sizing(editor_ui, v)
    case ed.NumberInput(i32):
        sizing = number_input_sizing(editor_ui, v)
    case ed.NumberInput(u8):
        sizing = number_input_sizing(editor_ui, v)

    case ed.Dropdown(u8):
        sizing = { width = clay.SizingGrow({}), height = size }
        z_index += 1
    case ed.Dropdown(u16):
        sizing = { width = clay.SizingGrow({}), height = size }
        z_index += 1
    case ed.Dropdown(u32):
        sizing = { width = clay.SizingGrow({}), height = size }
        z_index += 1
    case ed.Dropdown(u64):
        sizing = { width = clay.SizingGrow({}), height = size }
        z_index += 1
    }
    
    widget_id := clay.ID(id, 0)
    floating_id := clay.ID(id, 1)

    if clay.UI(widget_id)({ 
        layout = { 
            sizing = sizing,
            layoutDirection = .TopToBottom,
            padding = clay.Padding { 0, 0, 0, 0 },
        }
    }) {
        if clay.UI(floating_id)({ 
            layout = {
                sizing = { 
                    width = clay.SizingPercent(1.0), 
                    height = clay.SizingPercent(1.0) 
                }
            },
            floating = {
                zIndex = z_index,
                attachTo = .Parent,
            },
            custom = {customData = cast(rawptr)(cast(uintptr)widget+1)}
        }) {}
    }
}

run :: proc(editorui: ^EditorUI, data: ^$T) {
    editorui.render_fn(editorui, data)
}
