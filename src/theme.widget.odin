// this is a widget file generated through ./meta/structure_widget_creator.odin

package main

import    "project:editorui"
import ed "project:editor"
import ut "project:utils"
import rn "base:runtime"
import    "core:mem"
import    "core:slice"

theme_widget_init :: proc(e: ^editorui.EditorUI, b: ^editorui.EditorUITheme, id: string) {
    e.ui_groups[id] = ed.InputIndex(len(e.panel_pool.inputs))

    {

        append(&e.panel_pool.inputs, ed.NumberInput(u8) {
            current = cast(^u8)&b.letter_spacing,
            max=max(u8)
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(u8) {
            current = cast(^u8)&b.font_size,
            max=max(u8)
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(u8) {
            current = cast(^u8)&b.text_color[0],
            max=max(u8)
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(u8) {
            current = cast(^u8)&b.text_color[1],
            max=max(u8)
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(u8) {
            current = cast(^u8)&b.text_color[2],
            max=max(u8)
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(u8) {
            current = cast(^u8)&b.text_color[3],
            max=max(u8)
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(u8) {
            current = cast(^u8)&b.background_color[0],
            max=max(u8)
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(u8) {
            current = cast(^u8)&b.background_color[1],
            max=max(u8)
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(u8) {
            current = cast(^u8)&b.background_color[2],
            max=max(u8)
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(u8) {
            current = cast(^u8)&b.background_color[3],
            max=max(u8)
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(u8) {
            current = cast(^u8)&b.highlight_color[0],
            max=max(u8)
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(u8) {
            current = cast(^u8)&b.highlight_color[1],
            max=max(u8)
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(u8) {
            current = cast(^u8)&b.highlight_color[2],
            max=max(u8)
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(u8) {
            current = cast(^u8)&b.highlight_color[3],
            max=max(u8)
        })
    }
}

theme_widget :: proc(e: ^editorui.EditorUI, b: ^editorui.EditorUITheme, id: string, frame_allocator: mem.Allocator) {
    input_offset := e.ui_groups[id]

    if widget_block("Editor Uitheme", e) {

        if label_block("Letter Spacing", e) {
            editorui.custom_component_panel(e, input_offset+0, frame_allocator)
        }

        if label_block("Font Size", e) {
            editorui.custom_component_panel(e, input_offset+1, frame_allocator)
        }

        if widget_block("Color", e) {

            if label_block("Element 0", e) {
                editorui.custom_component_panel(e, input_offset+2, frame_allocator)
            }

            if label_block("Element 1", e) {
                editorui.custom_component_panel(e, input_offset+3, frame_allocator)
            }

            if label_block("Element 2", e) {
                editorui.custom_component_panel(e, input_offset+4, frame_allocator)
            }

            if label_block("Element 3", e) {
                editorui.custom_component_panel(e, input_offset+5, frame_allocator)
            }

        }
        if widget_block("Color", e) {

            if label_block("Element 0", e) {
                editorui.custom_component_panel(e, input_offset+6, frame_allocator)
            }

            if label_block("Element 1", e) {
                editorui.custom_component_panel(e, input_offset+7, frame_allocator)
            }

            if label_block("Element 2", e) {
                editorui.custom_component_panel(e, input_offset+8, frame_allocator)
            }

            if label_block("Element 3", e) {
                editorui.custom_component_panel(e, input_offset+9, frame_allocator)
            }

        }
        if widget_block("Color", e) {

            if label_block("Element 0", e) {
                editorui.custom_component_panel(e, input_offset+10, frame_allocator)
            }

            if label_block("Element 1", e) {
                editorui.custom_component_panel(e, input_offset+11, frame_allocator)
            }

            if label_block("Element 2", e) {
                editorui.custom_component_panel(e, input_offset+12, frame_allocator)
            }

            if label_block("Element 3", e) {
                editorui.custom_component_panel(e, input_offset+13, frame_allocator)
            }

        }
    }
}
