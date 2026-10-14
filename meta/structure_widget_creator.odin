package meta

import "core:fmt"
import main "project:src"
import "core:strings"
import "core:strconv"
import rn "base:runtime"
import ut "project:utils"
import "core:os"

create_widget_program_init_recurse :: proc(type_info: ^rn.Type_Info, output: ^[dynamic]u8, tab_size: int, field_name: string, field_path: string) {
    context.allocator = context.temp_allocator

    buf: [32]u8
    is_single := string(buf[0:tab_size])
    is_double := string(buf[0:tab_size*2])
    is_triple := string(buf[0:tab_size*3])

    for i in 0..<tab_size*3 {
        buf[i] = ' '
    }

    function_call := "\n%sappend(&e.panel_pool.inputs, %s)\n"
    fn_sb: strings.Builder

    #partial switch info in type_info.variant {
    case rn.Type_Info_Struct:
        for i in 0..<info.field_count {
            name := info.names[i]
            subtype_info := info.types[i]
            path := strings.concatenate({field_path, ".", name})

            create_widget_program_init_recurse(subtype_info, output, tab_size, name, path)
        }
    case rn.Type_Info_Bit_Set:
        enum_info: rn.Type_Info_Enum

        #partial switch v in info.elem.variant {
            case rn.Type_Info_Named:    
                enum_info = v.base.variant.(rn.Type_Info_Enum)
            case rn.Type_Info_Enum:
                enum_info = v
        }

        sb: strings.Builder
        struct_decl := "ed.MultiDropdown {{\n%senum_names = info.enum_info.names,\n%supper=info.upper,\n%slower=info.lower,\n%scurrent = slice.from_ptr(cast(^%s)&%s, %s) \n%s}}"

        buf: [32]u8
        //TODO
        bitset_bytes := 1
        bitset_base := strings.concatenate({"u", strconv.write_int(buf[:], i64(bitset_bytes*8), 10)})
        buf2: [32]u8
        bitset_bytes_str := strconv.write_int(buf2[:], i64(bitset_bytes), 10)

        formatted_struct_decl := fmt.sbprintf(&sb, struct_decl, is_triple, is_triple, is_triple, is_triple, bitset_base, field_path, bitset_bytes_str, is_double)

        i_sb: strings.Builder
        type_info_line := "info := ut.bitset_enum_type_info(type_of(%s))"
        formatted_type_info_line := fmt.sbprintf(&i_sb, type_info_line, field_path)

        append(output, "\n")
        append(output, is_single)
        append(output, "{\n")
        append(output, is_double)
        append(output, formatted_type_info_line)
        append(output, "\n")
        append(output, fmt.sbprintf(&fn_sb, function_call, is_double, formatted_struct_decl))
        append(output, is_single)
        append(output, "}\n")
    case rn.Type_Info_Enum:
        sb: strings.Builder
        struct_decl := "ed.Dropdown(%s) {{\n%senum_names = info.names,\n%senum_values = info.values,\n%scurrent = cast(^%s)&%s \n%s}}"

        buf: [32]u8
        enum_base := strings.concatenate({"u", strconv.write_int(buf[:], i64(info.base.size*8), 10)})

        formatted_struct_decl := fmt.sbprintf(&sb, struct_decl, enum_base, is_triple, is_triple, is_triple, enum_base, field_path, is_double)

        i_sb: strings.Builder
        type_info_line := "info := ut.enum_type_info(type_of(%s))"
        formatted_type_info_line := fmt.sbprintf(&i_sb, type_info_line, field_path)

        append(output, "\n")
        append(output, is_single)
        append(output, "{\n")
        append(output, is_double)
        append(output, formatted_type_info_line)
        append(output, "\n")
        append(output, fmt.sbprintf(&fn_sb, function_call, is_double, formatted_struct_decl))
        append(output, is_single)
        append(output, "}\n")
    case rn.Type_Info_Named:
        create_widget_program_init_recurse(info.base, output, tab_size, field_name, field_path)
    case:
        //unimplemented()
    }
}

create_widget_program_from_structure_type :: proc(T: typeid, name: string, path: string, pkg_import: string, pkg_alias: string) {
    type_info: ^rn.Type_Info = type_info_of(T)
    named := type_info.variant.(rn.Type_Info_Named)

    output: [dynamic]u8

    append(&output, "// this is a widget file generated through ./meta/structure_widget_creator.odin\n\n")

    append(&output, "package main\n\n")

    imports: []string = {
        "   \"project:editorui\"",
        "ed \"project:editor\"",
        "ut \"project:utils\"",
        "rn \"base:runtime\"",
        "   \"core:mem\"",
        "   \"core:slice\"",
        strings.concatenate({pkg_alias, " \"", pkg_import, "\""}),
    }

    for imp in imports {
        append(&output, "import ")
        append(&output, imp)
        append(&output, "\n")
    }

    append(&output, "\n")

    function_line := "%s_widget_init :: proc(e: ^editorui.EditorUI, b: ^%s, id: string)"

    type_alias := strings.concatenate({pkg_alias, ".", named.name})
    
    tab_size := 4

    buf: [32]u8
    indent_spaces := string(buf[0:tab_size])
    for i in 0..<tab_size do buf[i] = ' '

    sb: strings.Builder
    function_sig := fmt.sbprintf(&sb, function_line, name, type_alias)

    append(&output, function_sig)
    append(&output, " {\n")

    append(&output, indent_spaces)
    append(&output, "e.ui_groups[id] = ed.InputIndex(len(e.panel_pool.inputs))\n")

    create_widget_program_init_recurse(named.base, &output, tab_size, "", "b")
    
    append(&output, "}\n\n")

    function_body_line :: "%s_widget :: proc(e: ^editorui.EditorUI, b: ^%s, id: string, frame_allocator: mem.Allocator)"
    
    sb_b: strings.Builder
    function_body_sig := fmt.sbprintf(&sb_b, function_body_line, name, type_alias)    

    append(&output, function_body_sig)
    append(&output, " {\n")
    append(&output, indent_spaces)
    append(&output, "input_offset := e.ui_groups[id]\n\n")

    append(&output, "")
    
    name_formatted, _ := strings.replace_all(strings.to_ada_case(named.name), "_", " ")

    input_offset := 0
    create_widget_program_body_recurse(named.base, &output, &input_offset, tab_size, 1, name_formatted)
    
    append(&output, "}")

    err := os.write_entire_file(path, string(output[:]))
}

create_widget_program_body_recurse :: proc(type_info: ^rn.Type_Info, output: ^[dynamic]u8, input_offset: ^int, tab_size: int, indent_level: int, field_name: string) {
    field_name_formatted, _ := strings.replace_all(strings.to_ada_case(field_name), "_", " ")

    buf: [32]u8
    indent_spaces := string(buf[0:tab_size*indent_level])
    indent_spaces_max := string(buf[0:tab_size*(indent_level+1)])
    indent_spaces_mini := string(buf[0:tab_size*max(indent_level-1, 0)])

    for i in 0..<tab_size*(indent_level+1) do buf[i] = ' '

    #partial switch info in type_info.variant {
    case rn.Type_Info_Named:
        create_widget_program_body_recurse(info.base, output, input_offset, tab_size, indent_level, info.name)
    case rn.Type_Info_Struct:
        block := "%sif widget_block(\"%s\", e) {{\n\n"
        bf_sb: strings.Builder
        block_formatted := fmt.sbprintf(&bf_sb, block, indent_spaces, field_name_formatted)
        append(output, block_formatted)
        for i in 0..<info.field_count {
            name := info.names[i]
            subtype_info := info.types[i]

            create_widget_program_body_recurse(subtype_info, output, input_offset, tab_size, indent_level+1, name)
        }
        append(output, indent_spaces)
        append(output, "}\n")
    case:
        block := "%sif label_block(\"%s\", e) {{\n%seditorui.custom_component_panel(e, input_offset+%s, frame_allocator)\n%s}}\n\n"
        bf_sb: strings.Builder
        int_buf: [32]u8
        int_str := strconv.write_int(int_buf[:], auto_cast input_offset^, 10)
        block_formatted := fmt.sbprintf(&bf_sb, block, indent_spaces, field_name_formatted, indent_spaces_max, int_str, indent_spaces)
        append(output, block_formatted)
        input_offset^ += 1
    }
}

main :: proc() {
    create_widget_program_from_structure_type(ut.Color, "color", "./src/color.widget.odin", "project:utils", "ut")
    create_widget_program_from_structure_type(main.EditorSettings, "editor_settings", "./src/editor_settings.widget.odin", "project:src", "main")
}
