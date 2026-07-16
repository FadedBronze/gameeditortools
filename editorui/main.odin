package editorui

import ed   "project:editor"
import clay "project:clay-odin"
import ut   "project:utils"
import      "project:editorui"

import "core:strings"
import "core:mem"
import "core:fmt"

SliderRenderInfo :: struct {
    font_size: u8,
    bar_height: u8,
    bar_padding_x: u8,
    handle_size: u8,
    back_color: ut.Color, 
    bar_color: ut.Color, 
    handle_color: ut.Color,
    text_color: ut.Color,
}

ToggleRenderInfo :: struct {
    true_color: ut.Color,
    false_color: ut.Color,
}

RenderInfos :: struct {
    slider: SliderRenderInfo,
    text: TextInputRenderInfo,
    dropdown: DropdownRenderInfo,
    toggle: ToggleRenderInfo,
}

DropdownRenderInfo :: struct {
    font_size: u8,
    letter_spacing: u8,
    padding: u8,
    gap: u8,
    inner_padding: u8,
    back_color: ut.Color,
    border_color: ut.Color,
    text_color: ut.Color,
    outline_color: ut.Color,
}

TextInputRenderInfo :: struct {
    font_size: u8,
    letter_spacing: u8,
    padding: u8,
    caret_width: u8,
    caret_color: ut.Color,
    back_color: ut.Color,
    border_color: ut.Color,
    placeholder_text_color: ut.Color,
    text_color: ut.Color,
}

TextInput :: struct {
    buf: []u8,
    buf_len: u8,
}

MultiDropdown :: struct {
    search_string: string,
    selected: u8,
}

ActiveWidgetData :: union {
    TextInput,
    MultiDropdown,
}

EditorUITheme :: struct {
    letter_spacing: u8 "slider min(0) max(5)",
    font_size: u8 "slider min(10) max(30)",
    text_color: ut.Color "slider",
    background_color: ut.Color "slider",
    highlight_color: ut.Color "slider",
}

ActiveInfo :: struct {
    active_id: CustomId,
    active_data: ActiveWidgetData,
}

EditorUI :: struct {
    theme: EditorUITheme,
    render_infos: RenderInfos,

    using active: ActiveInfo,

    panel_pool: ed.PanelPool,
    panels: map[string]ed.GroupIndex,
    layout_fn: LayoutFunction,
    render_fn: RenderFunction,
    update_game: GameUpdateCallback,
    render_game: GameRenderCallback,

    editor_context: ^clay.Context,
}

IndexType :: enum u16 {
    Null = 0,
    InputIndex,
    DropdownFloatingMenu,
    Gameview,
}

ViewportIndex :: distinct u32

IndexValue :: struct #raw_union {
    input_index: ed.InputIndex,
    gameview_id: ViewportIndex,
}

CustomId :: struct {
    type: IndexType,
    value: IndexValue
}

error_handler :: proc "c" (errorData: clay.ErrorData) {
    //fmt.println(errorData)
}

GameUpdateCallback :: struct {
    fn: proc(rawptr, f32),
    data: rawptr,
}

GameRenderCallback :: struct {
    fn: proc(rawptr, ut.Bounds(f32), ViewportIndex),
    data: rawptr,
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
    game_render_fn: GameRenderCallback,
    update_fn: GameUpdateCallback,
) {
    editor_ui.layout_fn = layout_fn
    editor_ui.render_fn = render_fn
    editor_ui.render_game = game_render_fn
    editor_ui.update_game = update_fn
    clay.SetMeasureTextFunction(measure_text, nil)
}

create_render_infos :: proc(theme: EditorUITheme) -> RenderInfos {
    widget_color := ut.blend_two_colors(theme.background_color, theme.text_color, 0.1)
    widget_color_placeholder := ut.blend_two_colors(theme.background_color, theme.text_color, 0.3)
    widget_color_middle := ut.blend_two_colors(theme.background_color, theme.text_color, 0.5)
    widget_color_dark := ut.blend_two_colors(theme.background_color, theme.text_color, 0.9)

    render_infos := RenderInfos {
        slider = SliderRenderInfo {
            back_color = widget_color,
            font_size = theme.font_size,
            bar_color = widget_color_dark,
            handle_color = theme.highlight_color,
            text_color = theme.text_color,
            bar_height = 8,
            bar_padding_x = 3,
            handle_size = 10,
        },
        text = TextInputRenderInfo {
            back_color = widget_color,
            font_size = theme.font_size,
            border_color = widget_color_dark,
            caret_color = theme.highlight_color,
            caret_width = 1,
            text_color = theme.text_color,
            placeholder_text_color = widget_color_placeholder,
            padding = 3,
        },
        dropdown = DropdownRenderInfo {
            back_color = widget_color,
            font_size = theme.font_size,
            letter_spacing = theme.letter_spacing,
            border_color = widget_color_dark,
            text_color = theme.text_color,
            outline_color = widget_color_middle,
            padding = 3,
            gap = 3,
        },
        toggle = ToggleRenderInfo {
            false_color = widget_color_dark,
            true_color = widget_color,
        }
    }
    return render_infos
}

custom_input_id :: proc(input_index: ed.InputIndex) -> CustomId {
    return CustomId {
        type = .InputIndex,
        value = {
            input_index = input_index,
        },
    }
}

custom_is_input :: proc(custom_id: CustomId, input_index: ed.InputIndex) -> bool {
    return custom_id.type == .InputIndex && custom_id.value.input_index == input_index
}

create_editorui :: proc(theme: EditorUITheme, allocator: mem.Allocator) -> EditorUI {
    min_memory_size := clay.MinMemorySize()

    editor_memory := make([^]u8, min_memory_size, allocator)
    arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(uint(min_memory_size), editor_memory)
    editor_context := clay.Initialize(arena, {1080, 720}, { handler = error_handler })
    
    return EditorUI {
        panel_pool = ed.create_panel_pool(allocator),
        render_infos = create_render_infos(theme),
        panels = make(map[string]ed.GroupIndex, allocator),
        active_id = custom_input_id(max(ed.InputIndex)),
        theme = theme,
        editor_context = editor_context,
    }
}

render_structure_panel :: proc(editor_ui: ^EditorUI, id: string, structure: ^$T, label: string) {
    editor_ui.render_infos = create_render_infos(editor_ui.theme)
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
                    sizing = { width = clay.SizingGrow({}), height = clay.SizingFit({}) } ,
                    childGap = 5,
                    layoutDirection = .TopToBottom,
                    padding = clay.PaddingAll(10),
                }, 
                backgroundColor = auto_cast ut.color_to_f32list(ut.change_opacity(ut.get_contrasting_color(editor_ui.theme.background_color), 20)),
            }) {
                clay.Text(panel.label, clay.TextElementConfig {
                    fontSize = u16(editor_ui.theme.font_size)*5/4,
                    wrapMode = .Words,
                    letterSpacing = u16(editor_ui.theme.letter_spacing),
                    textColor = auto_cast ut.color_to_f32list(editor_ui.theme.text_color),
                })

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
                clay.Text(panel.label, clay.TextElementConfig {
                    letterSpacing = u16(editor_ui.theme.letter_spacing),
                    fontSize = u16(editor_ui.theme.font_size),
                    wrapMode = .Words,
                    textColor = auto_cast ut.color_to_f32list(editor_ui.theme.text_color),
                })

                //fmt.println(panel.label)
                custom_component(editor_ui, panel.input)
            }
    }
}

calculate_dropdown_height :: proc(input: ed.Dropdown($T), theme: editorui.EditorUITheme, dropdown: DropdownRenderInfo) -> f32 {
    gap := f32(dropdown.gap)
    font_size := f32(theme.font_size)
    inner_padding := f32(dropdown.inner_padding)
    
    return (gap+font_size)*f32(len(input.enum_names)+1)-gap+inner_padding
}

custom_component :: proc(editor_ui: ^EditorUI, widget: ed.InputIndex) {
    sizing: clay.Sizing
    
    size := clay.SizingFixed(f32(editor_ui.theme.font_size))

    number_input_sizing :: proc(editor_ui: ^EditorUI, number_input: ed.NumberInput($T)) -> clay.Sizing {
        switch number_input.type {
        case .Slider:
            return { width = clay.SizingGrow({}), height = clay.SizingFixed(f32(editor_ui.theme.font_size)*1.75+2) }
        case .Text:
            return { width = clay.SizingGrow({}), height = clay.SizingFixed(f32(editor_ui.theme.font_size)) }
        }
        unreachable()
    }

    input := editor_ui.panel_pool.inputs[widget]

    switch v in input {
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
    case ed.Dropdown(u16):
        sizing = { width = clay.SizingGrow({}), height = size }
    case ed.Dropdown(u32):
        sizing = { width = clay.SizingGrow({}), height = size }
    case ed.Dropdown(u64):
        sizing = { width = clay.SizingGrow({}), height = size }
    case ed.MultiDropdown:
        sizing = { width = clay.SizingGrow({}), height = size }
    }
    
    widget_id := clay.ID("widget", auto_cast widget)

    custom_id := CustomId {
        type = .InputIndex,
        value = {
            input_index = widget,
        }
    }

    dropdown_menu :: proc(input_index: ed.InputIndex, height: f32) {
        custom_id := CustomId {
            type = .DropdownFloatingMenu,
            value = {
                input_index = input_index,
            }
        }
        if clay.UI(clay.ID("widget-dropdown", auto_cast input_index))({ 
            layout = {
                sizing = { 
                    width = clay.SizingPercent(1.0), 
                    height = clay.SizingFixed(height)
                }
            },
            floating = {
                zIndex = 1,
                attachTo = .Parent,
            },
            custom = {customData = transmute(rawptr)(custom_id)}
        }) {}
    }

    if clay.UI(widget_id)({ 
        layout = { 
            sizing = sizing,
            layoutDirection = .TopToBottom,
            padding = clay.Padding { 0, 0, 0, 0 },
        },
        custom = {customData = transmute(rawptr)(custom_id)}
    }) {
        if custom_is_input(editor_ui.active_id, widget) {
            #partial switch v in input {
                case ed.Dropdown(u8):
                    height := calculate_dropdown_height(v, editor_ui.theme, editor_ui.render_infos.dropdown)
                    dropdown_menu(widget, height)
                case ed.Dropdown(u16):
                    height := calculate_dropdown_height(v, editor_ui.theme, editor_ui.render_infos.dropdown)
                    dropdown_menu(widget, height)
                case ed.Dropdown(u32):
                    height := calculate_dropdown_height(v, editor_ui.theme, editor_ui.render_infos.dropdown)
                    dropdown_menu(widget, height)
                case ed.Dropdown(u64):
                    height := calculate_dropdown_height(v, editor_ui.theme, editor_ui.render_infos.dropdown)
                    dropdown_menu(widget, height)
                case:
            }
        }
    }
}

run :: proc(editorui: ^EditorUI, data: ^$T) {
    editorui.render_fn(editorui, data)
}

gameview :: proc(id: ViewportIndex) {
    custom_id := CustomId {
        type = .Gameview,
        value = IndexValue {
            gameview_id = id,
        },
    }
    
    if clay.UI()({ 
        layout = { 
            sizing = { width = clay.SizingPercent(1), height = clay.SizingPercent(1) } 
        }, 
        backgroundColor = {0, 0, 0, 255},
        clip = {
            horizontal = true,
            vertical = true,
        }
    }) {
        if clay.UI()({ 
            layout = { 
                sizing = { width = clay.SizingPercent(1), height = clay.SizingPercent(1) } 
            },
            custom = {
                customData = transmute(rawptr)custom_id
            }
        }) {}
    }
}
