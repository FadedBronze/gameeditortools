package main

import rn "base:runtime"
import ut "project:utils"

import "core:testing"
import "core:strings"
import "core:os"
import "core:fmt"
import "core:strconv"
import "core:slice"

find_next :: proc(offset: u32, str: string, search: string) -> u32 {
    i := offset
    j := 0
    start: u32 = 0
    found_match := false

    for true {
        if str[i] == search[j] {
            if !found_match {
                start = i
                found_match = true
            }

            j += 1
        }

        i += 1

        if i >= u32(len(str)) {
            break;
        }
        
        if j >= len(search) {
            break;
        }

        if str[i] != search[j] {
            if found_match {
                j = 0
                found_match = false
            }
        }
    }
    
    assert(str[start:start+u32(len(search))] == search, message=str[start:start+u32(len(search))])

    return start
}

@(test)
test_find_next :: proc(t: ^testing.T) {
    str := "the cat is in the bag"
    strhard := "aababbaba"

    testing.expect_value(t, find_next(0, str, "bag"), 18)
    testing.expect_value(t, find_next(0, str, "e c"), 2)
    testing.expect_value(t, find_next(0, str, "the"), 0)
    testing.expect_value(t, find_next(1, str, "the"), 14)
    testing.expect_value(t, find_next(1, strhard, "abb"), 3)
}

skip_over_next :: proc(offset: u32, scone: string, search: string) -> u32 {
    return find_next(offset, scone, search) + u32(len(search))
}

// skips to next nonempty line without comment
skip_to_next_line :: proc(offset: u32, scone: string) -> u32 {
    offset := offset
    offset = skip_over_next(offset, scone, "\n")
    for offset < u32(len(scone)) {
        if scone[offset] == '/' && int(offset+1) < len(scone) && scone[offset+1] == '/' {
            offset += 2
        } else if scone[offset] == '\n' || scone[offset] == ' ' {
            offset += 1
        } else {
            break;
        }
    }
    return offset
}

skip_spaces :: proc(offset: u32, scone: string) -> u32 {
    offset := offset
    for scone[offset] == ' ' {
        offset += 1
    }
    return offset
}

skip_spaces_and_newlines :: proc(offset: u32, scone: string) -> u32 {
    offset := offset
    for scone[offset] == ' ' || scone[offset] == '\n' {
        offset += 1
    }
    return offset
}

scone_to_struct :: proc(scone: string, s: ^$T) {
    type_info: ^rn.Type_Info = type_info_of(type_of(s))
    pointer_type := type_info.variant.(rn.Type_Info_Pointer)
    named_type := pointer_type.elem.variant.(rn.Type_Info_Named)

    scone_to_struct_recurse(scone, 0, named_type.base, cast(rawptr)s, 0)
}

get_index_of_fieldname :: proc(type_info: ^rn.Type_Info_Struct, fieldname: string) -> i32 {
    for i in 0..<type_info.field_count {
        if type_info.names[i] == fieldname {
            return i
        }
    }
    return -1
}

get_index_of_tagname :: proc(type_info: ^rn.Type_Info_Enum, tagname: string) -> int {
    for i in 0..<len(type_info.names) {
        if type_info.names[i] == tagname {
            return i
        }
    }
    return -1
}

scone_to_struct_recurse :: proc(scone: string, offset: u32, type_info: ^rn.Type_Info, data: rawptr, nested_level: int) -> u32 {
    offset := offset

    #partial switch info in type_info.variant {
    case rn.Type_Info_Struct:
        offset = skip_over_next(offset, scone, "{")
        offset = skip_spaces(offset, scone)
        offset = skip_to_next_line(offset, scone)

        type_info := type_info.variant.(rn.Type_Info_Struct)

        for scone[offset] != '}' {
            key_start := offset
            offset = find_next(offset, scone, "=")

            key := strings.trim(scone[key_start:offset], " ")

            offset = skip_over_next(offset, scone, "=")
            offset = skip_spaces(offset, scone)
            
            index := get_index_of_fieldname(&type_info, key)
            subtype := type_info.types[index]

            offset = scone_to_struct_recurse(
                scone, 
                offset, 
                subtype, 
                cast(rawptr)(cast(uintptr)data+type_info.offsets[index]),
                nested_level + 1,
            )
        } 
        
        offset = skip_over_next(offset, scone, "}")
        offset = skip_spaces(offset, scone)
    case rn.Type_Info_String:
        str := cast(^string)data
        
        offset = skip_over_next(offset, scone, "\"")
        str_start := offset
        offset = find_next(offset, scone, "\"")

        str^ = scone[str_start:offset]

        offset = skip_over_next(offset, scone, ",")
    case rn.Type_Info_Boolean:
        bo := cast(^bool)data
        
        offset = skip_spaces(offset, scone)
        bool_start := offset
        offset = find_next(offset, scone, ",")

        boo_str := strings.trim(scone[bool_start:offset], " ")

        bo^ = boo_str == "true" ? true : false
        assert(boo_str == "false" || boo_str == "true")

        offset = skip_over_next(offset, scone, ",")
    case rn.Type_Info_Float:  
        offset = skip_spaces(offset, scone)
        bool_start := offset
        offset = find_next(offset, scone, ",")

        float_str := strings.trim(scone[bool_start:offset], " ")

        switch type_info.size {
            case 4:
                f := cast(^f32)data
                f^, _ = strconv.parse_f32(float_str)
            case 8:
                f := cast(^f64)data
                f^, _ = strconv.parse_f64(float_str)
        }

        offset = skip_over_next(offset, scone, ",")
    case rn.Type_Info_Bit_Set:
        offset = skip_over_next(offset, scone, "{")

        underlying_info: rn.Type_Info_Enum

        #partial switch v in info.elem.variant {
        case rn.Type_Info_Enum:
            underlying_info = v
        case rn.Type_Info_Named:
            underlying_info = v.base.variant.(rn.Type_Info_Enum)
        case:
            assert(false, "only supports enum bitsets")
        }

        finished := false

        for !finished {
            offset = skip_over_next(offset, scone, ".")
            flag_start := offset

            next_comma := find_next(offset, scone, ",")
            next_curly := find_next(offset, scone, "}")

            tag: string

            if next_curly < next_comma {
                tag = strings.trim(scone[flag_start:next_curly], " ")
                offset = next_curly
                finished = true
            } else {
                tag = strings.trim(scone[flag_start:next_comma], " ")
                offset = next_comma
            }

            index := get_index_of_tagname(&underlying_info, tag)
            ut.set_bit(slice.from_ptr(cast(^u8)data, int(info.upper)), u32(info.lower)+u32(index), true)
        }
    case:
        offset = skip_over_next(offset, scone, ",")
    }
    
    offset = skip_to_next_line(offset, scone)
    return offset
}

parse_scone_from_file :: proc(path: string, s: ^$T) {
    scone, _ := os.read_entire_file(path, context.allocator)
    scone_to_struct(string(scone), s)
}

@(test)
test_parse_scone :: proc(t: ^testing.T) {
    s: Test_RandomThinggy
    parse_scone_from_file("./test.meta.odin", &s)
}

main :: proc() {
    s: Test_RandomThinggy
    parse_scone_from_file("./test.meta.odin", &s)
    fmt.println(s)
}
