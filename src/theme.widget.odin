// this is a widget file generated through ./meta/structure_widget_creator.odin

package main

import    "project:editorui"
import ed "project:editor"
import ut "project:utils"
import rn "base:runtime"
import    "core:mem"
import    "core:slice"
import    "core:strings"

theme_widget_init :: proc(e: ^editorui.EditorUI, b: ^editorui.EditorUITheme, id: string) {
    e.ui_groups[id] = ed.InputIndex(len(e.panel_pool.inputs))

    {

        append(&e.panel_pool.inputs, ed.NumberInput(u8) {
            current = cast(^u8)&b.letter_spacing,
            max=18
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(u8) {
            current = cast(^u8)&b.font_size,
            min=8,
            max=18
        })
    }

    widget_init(e, &b.text_color, strings.concatenate({id, " text_color"}))

    widget_init(e, &b.background_color, strings.concatenate({id, " background_color"}))

    widget_init(e, &b.highlight_color, strings.concatenate({id, " highlight_color"}))
}

theme_widget :: proc(e: ^editorui.EditorUI, b: ^editorui.EditorUITheme, id: string, frame_allocator: mem.Allocator) {
    input_offset := e.ui_groups[id]

    if widget_block("Theme", e) {

        if label_block("Letter Spacing", e) {
            editorui.custom_component_panel(e, input_offset+0, frame_allocator)
        }

        if label_block("Font Size", e) {
            editorui.custom_component_panel(e, input_offset+1, frame_allocator)
        }


        widget(e, &b.text_color, strings.concatenate({id, " text_color"}), frame_allocator)

        widget(e, &b.background_color, strings.concatenate({id, " background_color"}), frame_allocator)

        widget(e, &b.highlight_color, strings.concatenate({id, " highlight_color"}), frame_allocator)
    }
}
