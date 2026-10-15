// this is a widget file generated through ./meta/structure_widget_creator.odin

package main

import    "project:editorui"
import ed "project:editor"
import ut "project:utils"
import rn "base:runtime"
import    "core:mem"
import    "core:slice"

color_widget_init :: proc(e: ^editorui.EditorUI, b: ^ut.Color, id: string) {
    e.ui_groups[id] = ed.InputIndex(len(e.panel_pool.inputs))

    {

        append(&e.panel_pool.inputs, ed.NumberInput(u8) {
            current = cast(^u8)&b[0],
            max=max(u8)
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(u8) {
            current = cast(^u8)&b[1],
            max=max(u8)
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(u8) {
            current = cast(^u8)&b[2],
            max=max(u8)
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(u8) {
            current = cast(^u8)&b[3],
            max=max(u8)
        })
    }
}

color_widget :: proc(e: ^editorui.EditorUI, b: ^ut.Color, id: string, frame_allocator: mem.Allocator) {
    input_offset := e.ui_groups[id]

    if widget_block("Color", e) {

        if label_block("Red", e) {
            editorui.custom_component_panel(e, input_offset+0, frame_allocator)
        }

        if label_block("Green", e) {
            editorui.custom_component_panel(e, input_offset+1, frame_allocator)
        }

        if label_block("Blue", e) {
            editorui.custom_component_panel(e, input_offset+2, frame_allocator)
        }

        if label_block("Alpha", e) {
            editorui.custom_component_panel(e, input_offset+3, frame_allocator)
        }

    }
}
