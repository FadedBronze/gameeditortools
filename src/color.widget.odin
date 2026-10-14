// this is a widget file generated through ./meta/structure_widget_creator.odin

package main

import    "project:editorui"
import ed "project:editor"
import ut "project:utils"
import rn "base:runtime"
import    "core:mem"
import    "core:slice"
import ut "project:utils"

color_widget_init :: proc(e: ^editorui.EditorUI, b: ^ut.Color, id: string) {
    e.ui_groups[id] = ed.InputIndex(len(e.panel_pool.inputs))
}

color_widget :: proc(e: ^editorui.EditorUI, b: ^ut.Color, id: string, frame_allocator: mem.Allocator) {
    input_offset := e.ui_groups[id]

    if label_block("Color", e) {
        editorui.custom_component_panel(e, input_offset+0, frame_allocator)
    }

}