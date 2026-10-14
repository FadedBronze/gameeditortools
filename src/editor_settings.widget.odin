// this is a widget file generated through ./meta/structure_widget_creator.odin

package main

import    "project:editorui"
import ed "project:editor"
import ut "project:utils"
import rn "base:runtime"
import    "core:mem"
import    "core:slice"
import main "project:src"

editor_settings_widget_init :: proc(e: ^editorui.EditorUI, b: ^main.EditorSettings, id: string) {
    e.ui_groups[id] = ed.InputIndex(len(e.panel_pool.inputs))

    {
        info := ut.bitset_enum_type_info(type_of(b.open_views))

        append(&e.panel_pool.inputs, ed.MultiDropdown {
            enum_names = info.enum_info.names,
            upper=info.upper,
            lower=info.lower,
            current = slice.from_ptr(cast(^u8)&b.open_views, 1) 
        })
    }

    {
        info := ut.bitset_enum_type_info(type_of(b.selected_tile.environment.flags))

        append(&e.panel_pool.inputs, ed.MultiDropdown {
            enum_names = info.enum_info.names,
            upper=info.upper,
            lower=info.lower,
            current = slice.from_ptr(cast(^u8)&b.selected_tile.environment.flags, 1) 
        })
    }

    {
        info := ut.enum_type_info(type_of(b.selected_tile.environment.sprite))

        append(&e.panel_pool.inputs, ed.Dropdown(u64) {
            enum_names = info.names,
            enum_values = info.values,
            current = cast(^u64)&b.selected_tile.environment.sprite 
        })
    }

    {
        info := ut.bitset_enum_type_info(type_of(b.flags))

        append(&e.panel_pool.inputs, ed.MultiDropdown {
            enum_names = info.enum_info.names,
            upper=info.upper,
            lower=info.lower,
            current = slice.from_ptr(cast(^u8)&b.flags, 1) 
        })
    }

    {
        info := ut.enum_type_info(type_of(b.active_tool))

        append(&e.panel_pool.inputs, ed.Dropdown(u64) {
            enum_names = info.names,
            enum_values = info.values,
            current = cast(^u64)&b.active_tool 
        })
    }
}

editor_settings_widget :: proc(e: ^editorui.EditorUI, b: ^main.EditorSettings, id: string, frame_allocator: mem.Allocator) {
    input_offset := e.ui_groups[id]

    if widget_block("Editor Settings", e) {

        if label_block("Open Views", e) {
            editorui.custom_component_panel(e, input_offset+0, frame_allocator)
        }

        if widget_block("Tile", e) {

            if widget_block("Environment", e) {

                if label_block("Flags", e) {
                    editorui.custom_component_panel(e, input_offset+1, frame_allocator)
                }

                if label_block("First Game Sheet Id", e) {
                    editorui.custom_component_panel(e, input_offset+2, frame_allocator)
                }

            }
        }
        if label_block("Flags", e) {
            editorui.custom_component_panel(e, input_offset+3, frame_allocator)
        }

        if label_block("Active Tool", e) {
            editorui.custom_component_panel(e, input_offset+4, frame_allocator)
        }

    }
}