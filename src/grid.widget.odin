// this is a widget file generated through ./meta/structure_widget_creator.odin

package main

import    "project:editorui"
import ed "project:editor"
import ut "project:utils"
import rn "base:runtime"
import    "core:mem"
import    "core:slice"
import    "core:strings"
import main "project:src"

grid_widget_init :: proc(e: ^editorui.EditorUI, b: ^main.RectangleLineGrid, id: string) {
    e.ui_groups[id] = ed.InputIndex(len(e.panel_pool.inputs))

    {

        append(&e.panel_pool.inputs, ed.NumberInput(f64) {
            current = cast(^f64)&b.width,
            max=100.0
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(f64) {
            current = cast(^f64)&b.height,
            max=100.0
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(f64) {
            current = cast(^f64)&b.transform.scale[0],
            max=100.0
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(f64) {
            current = cast(^f64)&b.transform.scale[1],
            max=100.0
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(f64) {
            current = cast(^f64)&b.transform.offset[0],
            max=100.0
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(f64) {
            current = cast(^f64)&b.transform.offset[1],
            max=100.0
        })
    }

    {

        append(&e.panel_pool.inputs, ed.NumberInput(f64) {
            current = cast(^f64)&b.transform.rotation_rad,
            max=100.0
        })
    }
}

grid_widget :: proc(e: ^editorui.EditorUI, b: ^main.RectangleLineGrid, id: string, frame_allocator: mem.Allocator) {
    input_offset := e.ui_groups[id]

    if widget_block("Grid", e) {

        if label_block("Width", e) {
            editorui.custom_component_panel(e, input_offset+0, frame_allocator)
        }

        if label_block("Height", e) {
            editorui.custom_component_panel(e, input_offset+1, frame_allocator)
        }

        if widget_block("Transform($t=f64)", e) {

            if widget_block("Scale", e) {

                if label_block("Element 0", e) {
                    editorui.custom_component_panel(e, input_offset+2, frame_allocator)
                }

                if label_block("Element 1", e) {
                    editorui.custom_component_panel(e, input_offset+3, frame_allocator)
                }

            }
            if widget_block("Offset", e) {

                if label_block("Element 0", e) {
                    editorui.custom_component_panel(e, input_offset+4, frame_allocator)
                }

                if label_block("Element 1", e) {
                    editorui.custom_component_panel(e, input_offset+5, frame_allocator)
                }

            }
            if label_block("Rotation Rad", e) {
                editorui.custom_component_panel(e, input_offset+6, frame_allocator)
            }

        }
    }
}