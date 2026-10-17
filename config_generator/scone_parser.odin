package configen

import rn "base:runtime"
import ut "project:utils"
import pr "project:parsing"

import "core:strings"
import "core:os"
import "core:fmt"
import "core:strconv"
import "core:slice"
import "core:odin/tokenizer"

scone_to_struct :: proc(tok: []tokenizer.Token, s: ^$T) {
    type_info: ^rn.Type_Info = type_info_of(type_of(s))
    pointer_type := type_info.variant.(rn.Type_Info_Pointer)
    named_type := pointer_type.elem.variant.(rn.Type_Info_Named)

    // TODO make an assert here
    //assert(named_type.name == )

    scone_to_struct_recurse(tok, 0, named_type.base, cast(rawptr)s, 0)
    fmt.println(s)
}

get_index_of_fieldname :: proc(type_info: rn.Type_Info_Struct, fieldname: string) -> i32 {
    for i in 0..<type_info.field_count {
        if type_info.names[i] == fieldname {
            return i
        }
    }
    return -1
}

get_index_of_tagname :: proc(type_info: rn.Type_Info_Enum, tagname: string) -> int {
    for i in 0..<len(type_info.names) {
        if type_info.names[i] == tagname {
            return i
        }
    }
    return -1
}

scone_to_struct_recurse :: proc(tokens: []tokenizer.Token, offset: int, type_info: ^rn.Type_Info, data: rawptr, nested_level: int) -> int {
    offset := offset

    #partial switch info in type_info.variant {
    case rn.Type_Info_Named:
        offset = scone_to_struct_recurse(
            tokens, 
            offset, 
            info.base, 
            data,
            nested_level,
        )
    case rn.Type_Info_Struct:
        if offset >= len(tokens) {
            return offset
        }

        for tokens[offset].kind != .Open_Brace do offset += 1
        open_brace_loc := offset
        
        for true {
            key_start := offset

            for tokens[offset].kind != .Ident && tokens[offset].kind != .Close_Brace {
                offset += 1
            }

            if tokens[offset].kind == .Close_Brace {
                return offset+1
            }

            ident := offset
            for tokens[offset].kind != .Eq do offset += 1

            index := get_index_of_fieldname(info, tokens[ident].text)
            subtype := info.types[index]

            if index == -1 {
                panic("invalid fieldname")
            }

            offset = scone_to_struct_recurse(
                tokens, 
                offset, 
                subtype, 
                cast(rawptr)(cast(uintptr)data+info.offsets[index]),
                nested_level + 1,
            )
            
            for tokens[offset].kind != .Comma && tokens[offset].kind != .Close_Brace do offset += 1

            if tokens[offset].kind == .Close_Brace {
                return offset+1
            }
        } 
    case rn.Type_Info_String:
        str := cast(^string)data
        
        for tokens[offset].kind != .String do offset += 1

        str^ = strings.trim(tokens[offset].text, "\"")

        for tokens[offset].kind != .Comma do offset += 1
    case rn.Type_Info_Boolean:
        bo := cast(^bool)data
        
        for tokens[offset].kind != .Ident do offset += 1
        if true do unimplemented()

        boo_str := tokens[offset].text
        bo^ = boo_str == "true" ? true : false
        assert(boo_str == "false" || boo_str == "true")

        for tokens[offset].kind != .Comma do offset += 1
    case rn.Type_Info_Float:  
        for tokens[offset].kind != .Ident do offset += 1
        float_str := tokens[offset].text

        switch type_info.size {
            case 4:
                f := cast(^f32)data
                f^, _ = strconv.parse_f32(float_str)
            case 8:
                f := cast(^f64)data
                f^, _ = strconv.parse_f64(float_str)
        }

        for tokens[offset].kind != .Comma do offset += 1
    case rn.Type_Info_Bit_Set:
        for tokens[offset].kind != .Open_Brace do offset += 1
        open_brace_loc := offset

        underlying_info: rn.Type_Info_Enum

        #partial switch v in info.elem.variant {
        case rn.Type_Info_Enum:
            underlying_info = v
        case rn.Type_Info_Named:
            underlying_info = v.base.variant.(rn.Type_Info_Enum)
        case:
            assert(false, "only supports enum bitsets")
        }

        for true {
            for tokens[offset].kind != .Close_Brace && tokens[offset].kind != .Period { 
                offset += 1
            }

            if tokens[offset].kind == .Close_Brace {
                return offset+1
            } else {
                offset += 1
                assert(tokens[offset].kind == .Ident)
            }

            index := get_index_of_tagname(underlying_info, tokens[offset].text)
            assert(index != -1, tokens[offset].text)
            ut.set_bit(slice.from_ptr(cast(^u8)data, int(info.upper / 8)+1), u32(info.lower)+u32(index), true)
        }
    case rn.Type_Info_Enum:
        for tokens[offset].kind != .Ident do offset += 1
        enum_offset := offset
        
        i := get_index_of_tagname(info, tokens[enum_offset].text)

        switch type_info.size {
            case 1:
                backing := cast(^u8)data
                backing^ = auto_cast info.values[i]
            case 4:
                backing := cast(^u32)data
                backing^ = auto_cast info.values[i]
            case 8:
                backing := cast(^u64)data
                backing^ = auto_cast info.values[i]
            case:
                unimplemented()
        }
    case rn.Type_Info_Integer:
        if offset > len(tokens) {
            return offset
        }

        for tokens[offset].kind != .Integer do offset += 1
        int_offset := offset

        if info.signed {
            parsed_int, _ := strconv.parse_i64(tokens[int_offset].text)

            switch type_info.size {
            case 1:
                number := cast(^i8)data
                number^ = auto_cast parsed_int
            case 2:
                number := cast(^i16)data
                number^ = auto_cast parsed_int
            case 4:
                number := cast(^i32)data
                number^ = auto_cast parsed_int
            case 8:
                number := cast(^i64)data
                number^ = auto_cast parsed_int
            case:
                unimplemented()
            }
        } else {
            parsed_int, _ := strconv.parse_u64(tokens[int_offset].text)

            switch type_info.size {
            case 1:
                number := cast(^u8)data
                number^ = auto_cast parsed_int
            case 2:
                number := cast(^u16)data
                number^ = auto_cast parsed_int
            case 4:
                number := cast(^u32)data
                number^ = auto_cast parsed_int
            case 8:
                number := cast(^u64)data
                number^ = auto_cast parsed_int
            case:
                unimplemented()
            }
        }
    case rn.Type_Info_Array:
        for tokens[offset].kind != .Open_Brace do offset += 1

        subtype := info.elem

        i := 0
        for true {
            if tokens[offset].kind == .Close_Brace {
                return offset+1
            }

            offset = scone_to_struct_recurse(
                tokens, 
                offset, 
                subtype, 
                cast(rawptr)(cast(uintptr)data+uintptr(info.elem_size*i)),
                nested_level + 1,
            )

            for tokens[offset].kind != .Close_Brace && tokens[offset].kind != .Comma {
                offset+=1
            }

            if tokens[offset].kind == .Close_Brace {
                return offset+1
            }

            offset+=1
            i += 1
        } 
    case:
    }

    return offset
}

parse_scone_from_file :: proc(path: string, s: ^$T) {
    scone, err := os.read_entire_file(path, context.allocator)

    tokens: [dynamic]tokenizer.Token

    tok: tokenizer.Tokenizer
    tokenizer.init(&tok, string(scone), path)

    i := 0
    // Loop through tokens until EOF
    for {
        token := tokenizer.scan(&tok)
        append(&tokens, token)
        i += 1
        if token.kind == .EOF do break
    }

    if err != nil {
        panic(fmt.aprintf("parse config failed with: %v", err, context.allocator))
    }

    scone_to_struct(tokens[:], s)
}

input_main :: proc() {
    // This was working I will fix it at some point look at the other stuff for now

    parse_target := `// if you want to see this generator create something else
// modify the structure under ./config_generator/scone_generator.odin

// this file is not read by the odin compiler
// its a config file that uses the same syntax and
// sits in same directory as the type for lsp completion

package mega

test_config: Test_RandomThinggy = {
    test_int = 0,
                                                                                 valuee = +0.000000,                                                                           some_str = "",                                                                                some_enum = .Good,
    nested = {                                                                                        nested_bool = false,
    },                                                                                            // options = Voldemort, Fish, JohnCena
    flags = {},
}
    `

    fmt.println("try running with flag -mkconfig then pasting the result here")
    fmt.println("make sure the desired type is used in scone_generator.odin eg. Test_RandomThinggy")

    // change this to configen.Test_AnotherRandomThinggy 
    // if you generated that one
    s: Test_RandomThinggy

    //scone_to_struct(parse_target, &s)

    fmt.println(s)
}
