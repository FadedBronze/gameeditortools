package main

import rn "base:runtime"
import ut "project:utils"
import "core:fmt"
import "core:slice"
import "core:strconv"
import "core:testing"
import "core:os"

output_scone :: proc(
    s: ^$T, 
    name_prefix: string, 
    package_name: string,
    package_directory: string,
    tab_size: u8 = 2, 
) {
    buf: [128]u8
    file_path := ut.concatenate(buf[:], package_directory, "/", name_prefix, ".meta.odin")
    
    scone := struct_to_scone(s, name_prefix, package_name, tab_size)
    _ = os.write_entire_file_from_string(file_path, scone)
}

// struct can be recursive
struct_to_scone :: proc(
    s: ^$T, 
    name_prefix: string, 
    package_name: string,
    tab_size: u8 = 2, 
) -> string {
    output := make([dynamic]u8)

    append(&output, "// this file is not read by the odin compiler\n// its a config file that uses the same syntax and\n// sits in same directory as the type for lsp completion\n\n")

    append(&output, "package ")
    append(&output, package_name)
    append(&output, "\n\n")

    type_info_ptr: rn.Type_Info_Pointer = type_info_of(type_of(s)).variant.(rn.Type_Info_Pointer)
    named := type_info_ptr.elem.variant.(rn.Type_Info_Named)
    name := named.name
    struct_to_scone_recurse(type_info_ptr.elem, &output, cast(rawptr)s, 1, tab_size, name_prefix)

    return string(output[:]);
}

struct_to_scone_recurse :: proc(
    type_info: ^rn.Type_Info, 
    output: ^[dynamic]u8,
    data: rawptr,
    indent_level: u8,
    tab_size: u8,
    name: string,
) {
    indent_spaces_buf: [32]u8;
    indent_spaces: string = ""
    
    for i in 0..<indent_level {
        for j in 0..<tab_size {
            indent_spaces_buf[i*tab_size+j] = ' '
        }
    }

    indent_spaces = string(indent_spaces_buf[0:tab_size*indent_level])

    smaller_indent := indent_spaces[0:len(indent_spaces)-int(tab_size)]

    #partial switch info in type_info.variant {
    case rn.Type_Info_Named:
        if indent_level == 1 {
            append(output, name)
            append(output, "_config: ")
            append(output, info.name)
            append(output, " = ")

            struct_to_scone_recurse(info.base, output, data, indent_level, tab_size, info.name)
        } else {
            struct_to_scone_recurse(info.base, output, data, indent_level, tab_size, info.name)
        }
    case rn.Type_Info_Struct:
        append(output, "{\n")

        for i in 0..<info.field_count {
            name := info.names[i]
            subtype := info.types[i]
            offset := info.offsets[i]
            // allows child to insert its own name and text before eg '<here>name = '
            skip := false

            if _, ok := subtype.variant.(rn.Type_Info_Bit_Set); ok {
                skip = true
            }
            if v, ok := subtype.variant.(rn.Type_Info_Named); ok {
                if _, ok := v.base.variant.(rn.Type_Info_Bit_Set); ok {
                    skip = true
                }
            }

            if !skip {
                append(output, indent_spaces)
                append(output, name)
                append(output, " = ")
            }
            struct_to_scone_recurse(subtype, output, cast(rawptr)(uintptr(data)+offset), indent_level+1, tab_size, name)
            if !skip {
                append(output, ",\n")
            }
        } 
        
        append(output, smaller_indent)
        append(output, "}")
    case rn.Type_Info_Bit_Set:
        fmt.println(info)
        underlying_info: rn.Type_Info_Enum

        #partial switch v in info.elem.variant {
        case rn.Type_Info_Enum:
            underlying_info = v
        case rn.Type_Info_Named:
            underlying_info = v.base.variant.(rn.Type_Info_Enum)
        case:
            assert(false, "only supports enum bitsets")
        }

        append(output, smaller_indent)
        append(output, "// options = ")

        if len(underlying_info.names) > 0 {
            append(output, underlying_info.names[0])
        }

        for i in 1..<len(underlying_info.names) {
            name := underlying_info.names[i]
            append(output, ", ")
            append(output, name)
        }
        
        append(output, "\n")

        append(output, smaller_indent)
        append(output, name)
        append(output, " = { ")

        for i in 0..<len(underlying_info.names) {
            name := underlying_info.names[i]
            value := underlying_info.values[i] 
            
            if (ut.get_bit(slice.from_ptr(cast(^u8)data, int(info.upper)), u32(info.lower)+u32(i))) {
                append(output, ".")
                append(output, name)
                append(output, ", ")
            }
        }

        pop(output)
        pop(output)

        append(output, " },\n")
    case rn.Type_Info_Boolean:
        if (cast(^bool)data)^ {
            append(output, "true")
        } else {
            append(output, "false")
        }
    case rn.Type_Info_Float:
        num: f64 = 0

        switch type_info.size {
            case 4:
                number := (cast(^f32)data)^
                num = f64(number)
            case 8:
                number := (cast(^f64)data)^
                num = f64(number)
        }
        
        buf: [64]u8
        append(output, strconv.write_float(buf[:], num, 'f', 6, 64))
    case rn.Type_Info_Integer:
        num: i64 = 0

        switch type_info.size {
        case 1:
            if info.signed {
                number := (cast(^i8)data)^
                num = cast(i64)number
            } else {
                number := (cast(^u8)data)^
                num = cast(i64)number
            }
        case 2:
            if info.signed {
                number := (cast(^i16)data)^
                num = cast(i64)number
            } else {
                number := (cast(^u16)data)^
                num = cast(i64)number
            }
        case 4:
            if info.signed {
                number := (cast(^i32)data)^
                num = cast(i64)number
            } else {
                number := (cast(^u32)data)^
                num = cast(i64)number
            }
        case 8:
            if info.signed {
                number := (cast(^i64)data)^
                num = cast(i64)number
            } else {
                number := (cast(^u64)data)^
                num = cast(i64)number
            }
        case:
            unimplemented()
        }

        buf: [64]u8
        append(output, strconv.write_int(buf[:], num, 10))
    case rn.Type_Info_String:
        str := (cast(^string)data)^
        append(output, '"')
        append(output, str)
        append(output, '"')
    case:
        fmt.println(info)
    }
}

Test_RandomThinggy :: struct {
    valuee: f32,
    some_str: string,
    nested: struct {
        nested_bool: bool,
    },
    flags: bit_set[enum {
        Voldemort,
        Yaoi,
        JohnCena
    }]
}

//@(test)
//test_struct_to_scone :: proc(t: ^testing.T) {
//    parse_target := Test_RandomThinggy {
//        valuee = 69.696969,
//        some_str = "idek",
//        nested = {
//            nested_bool = true,
//        },
//        flags = {
//            .Yaoi, .JohnCena
//        }
//    }
//
//    output_scone(&parse_target, "test", "main", ".")
//}
