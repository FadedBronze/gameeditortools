package editor
import "core:fmt"
import rn "base:runtime"
import "core:strings"
import "core:slice"

GroupIndex :: distinct u32
InputIndex :: distinct u32

Toggle :: struct {
    current: ^bool,
}

NumberInputType :: enum {
    Slider,
    Text,
}

NumberInput :: struct(T: typeid) {
    type: NumberInputType,
    placeholder: string,
    min: T,
    current: ^T,
    max: T,
}

TextInput :: struct {
    placeholder: string,
    text: []u8,
    text_len: ^int,
}

InputComponent :: union {
    Toggle,
    TextInput,
    NumberInput(f32),
    NumberInput(f64),
    NumberInput(u32),
    NumberInput(u64),
    NumberInput(u8),
    NumberInput(i32),
}

GroupType :: enum {
    Component,
    Subgroup
}

Group :: struct {
    type: GroupType,
    label: string, // either the name of the component or the group
    input: InputIndex, // points into PanelPool.inputs
    subgroup: []GroupIndex
}

InputComponentType :: enum {
    Toggle,
    Slider,
    TextInputBuffer,
    TextInputLength,
    NumberInput,
}

ParsedKVs :: struct {
    keys: []string,
    values: []string,
}

parse_tag :: proc(tag: string) -> ParsedKVs { 
    if tag == "" {
        return ParsedKVs {
            keys = slice.from_ptr(cast(^string)nil, 0), 
            values = slice.from_ptr(cast(^string)nil, 0),
        }
    }
    
    keys := make([dynamic]string)
    values := make([dynamic]string)

    //type: 'slider', min: '-1.5', max: '10'

    start := 0
    end := 0
    for {
        for {
            end += 1
            assert(end < len(tag))
            if tag[end] == ':' {
                append(&keys, strings.trim(tag[start:end], " "))
                start = end+1
                end = start
                break
            }
        }
        
        start_tag: u8 = '\x00'

        for {
            end += 1
            assert(end < len(tag))
            if tag[end] == '\'' || tag[end] == '"' {
                start_tag = tag[end]
                start = end+1
                end = start
                break;
            }
        }

        for {
            end += 1
            assert(end < len(tag))
            if tag[end] == start_tag {
                append(&values, strings.trim(tag[start:end], " "))
                start = end
                end = start
                break;
            }
        }
        
        fully_ended := false
        
        for {
            if tag[end] == ',' {
                start = end+1
                end = start
                break;
            }
            end += 1
            if end >= len(tag) {
                fully_ended = true
                break;
            }
        }

        if (fully_ended) {
            break
        }
    }

    return ParsedKVs {
        keys = keys[0:len(keys)], 
        values = values[0:len(values)],
    }
}

get_value :: proc(tags: ParsedKVs, key: string) -> string {
    for i in 0..<len(tags.keys) {
        if tags.keys[i] == key {
            return tags.values[i]
        }
    }
    return ""
}

import "core:strconv"

create_panel_recurse_struct_fields :: proc(
    s: rawptr,
    o: uintptr,
    tags: ParsedKVs,
    ti: ^rn.Type_Info, 
    inputs: ^[dynamic]InputComponent, 
    groups: ^[dynamic]Group,
    parent: ^Group,
    parent_idx: GroupIndex,
    name: string,
) {
    #partial switch info in ti.variant {
        case rn.Type_Info_Struct:
            append(groups, Group {
                type = .Subgroup,
                label = name,
                subgroup = make([]GroupIndex, info.field_count),
            })
            new_size := GroupIndex(len(groups)-1)
            parent.subgroup[parent_idx] = new_size
            new_parent := groups[new_size]

            for i in 0..<info.field_count {
                tag := info.tags[i]
                parsed := parse_tag(tag)
                type := info.types[i]
                offset := info.offsets[i]

                create_panel_recurse_struct_fields(s, o + offset, parsed, type, inputs, groups, &new_parent, GroupIndex(i), info.names[i])
            }
        case rn.Type_Info_Named:
            //if info.name == "EditableSlice" {
            //    unimplemented()
            //} else if info.name == "EditableText" {
            //    unimplemented()
            //} else {
                create_panel_recurse_struct_fields(s, o, tags, info.base, inputs, groups, parent, parent_idx, name)
            //}
        case rn.Type_Info_Array:
            type := get_value(tags, "type")
            if type != "hidden" {
                append(groups, Group {
                    type = .Subgroup,
                    label = name,
                    subgroup = make([]GroupIndex, info.count),
                })
                new_size := GroupIndex(len(groups)-1)
                parent.subgroup[parent_idx] = new_size
                new_parent := groups[new_size]

                for i in 0..<info.count {
                    create_panel_recurse_struct_fields(s, o + uintptr(info.elem_size*i), tags, info.elem, inputs, groups, &new_parent, GroupIndex(i), "")
                } 
            }
        case rn.Type_Info_Integer:
            assert(info.endianness == .Platform)
            
            type := get_value(tags, "type")
            if type == "hidden" {
                // nothing
            } else {
                // default type 'text'
                real_type: NumberInputType = type == "slider" ? .Slider : .Text
                placeholder := get_value(tags, "placeholder")

                mini := get_value(tags, "min")
                if mini == "" {
                    mini = "0"
                }
                maxi := get_value(tags, "max")
                if maxi == "" {
                    maxi = "0"
                }
                
                min_int, ok := strconv.parse_u64(mini, nil)
                assert(ok)
                max_int, _ok := strconv.parse_u64(maxi, nil)
                assert(_ok)

                switch {
                case ti.size == 1:
                    append(inputs, NumberInput(u8) {
                        type = real_type,
                        placeholder = placeholder,
                        min = u8(min_int),
                        max = max_int == 0 ? max(u8) : u8(max_int),
                        current = cast(^u8)(cast(uintptr)s+o)
                    })
                case ti.size == 4 && !info.signed:
                    append(inputs, NumberInput(u32) {
                        type = real_type,
                        placeholder = placeholder,
                        min = u32(min_int),
                        max = max_int == 0 ? max(u32) : u32(max_int),
                        current = cast(^u32)(cast(uintptr)s+o)
                    })
                case ti.size == 4 && info.signed:
                    append(inputs, NumberInput(i32) {
                        type = real_type,
                        placeholder = placeholder,
                        min = i32(min_int),
                        max = max_int == 0 ? max(i32) : i32(max_int),
                        current = cast(^i32)(cast(uintptr)s+o)
                    })
                case ti.size == 8 && !info.signed:
                    append(inputs, NumberInput(u64) {
                        type = real_type,
                        placeholder = placeholder,
                        min = u64(min_int),
                        max = max_int == 0 ? max(u64) : u64(max_int),
                        current = cast(^u64)(cast(uintptr)s+o)
                    })
                case:
                    unimplemented()
                }
            }
            
            append(groups, Group {
                type = .Component,
                input = InputIndex(len(inputs)-1),
                label = name,
            })
            new_size := GroupIndex(len(groups)-1)
            parent.subgroup[parent_idx] = new_size
        case rn.Type_Info_Float:
            assert(info.endianness == .Platform)
            
            type := get_value(tags, "type")
            if type == "hidden" {
                // nothing
            } else {
                // default type 'text'
                real_type: NumberInputType = type == "slider" ? .Slider : .Text
                placeholder := get_value(tags, "placeholder")

                min := get_value(tags, "min")
                if min == "" {
                    min = "0"
                }
                max := get_value(tags, "max")

                min_int, ok := strconv.parse_f64(min, nil)
                assert(ok)
                max_int, _ok := strconv.parse_f64(max, nil)
                assert(_ok)

                switch {
                case ti.size == 4:
                    append(inputs, NumberInput(f32) {
                        type = real_type,
                        placeholder = placeholder,
                        min = f32(min_int),
                        max = f32(max_int),
                        current = cast(^f32)(cast(uintptr)s+o)
                    })
                case ti.size == 8:
                    append(inputs, NumberInput(f64) {
                        type = real_type,
                        placeholder = placeholder,
                        min = f64(min_int),
                        max = f64(max_int),
                        current = cast(^f64)(cast(uintptr)s+o)
                    })
                case:
                    unimplemented()
                }
            }
            
            append(groups, Group {
                type = .Component,
                input = InputIndex(len(inputs)-1),
                label = name,
            })
            new_size := GroupIndex(len(groups)-1)
            parent.subgroup[parent_idx] = new_size
        case rn.Type_Info_Boolean:
            type := get_value(tags, "type")

            if type != "hidden" {
                append(inputs, Toggle {
                    current = cast(^bool)(cast(uintptr)s+o)
                })

                append(groups, Group {
                    type = .Component,
                    input = InputIndex(len(inputs)-1),
                    label = name,
                })
                new_size := GroupIndex(len(groups)-1)
                parent.subgroup[parent_idx] = new_size
            }
        case:
            unimplemented()
    }
}

PanelPool :: struct {
    inputs: [dynamic]InputComponent,
    groups: [dynamic]Group
}

create_panel_pool :: proc() -> PanelPool {
    inputs := make([dynamic]InputComponent)
    groups := make([dynamic]Group)

    reserve(&inputs, 10000)
    reserve(&groups, 10000)

    return PanelPool {
        inputs = inputs, 
        groups = groups
    }
}

create_panel :: proc(p: ^PanelPool, s: ^$T, name: string) -> GroupIndex {
    ti: ^rn.Type_Info = type_info_of(type_of(s))
    ptr: rn.Type_Info_Pointer = ti.variant.(rn.Type_Info_Pointer)
    ti = ptr.elem

    buf: [1]GroupIndex = {0}
    append_elem(&p.groups, Group {
        type = .Subgroup,
        label = "root",
        subgroup = buf[:],
    })
    groups_len := len(p.groups)

    create_panel_recurse_struct_fields(s, 0, parse_tag(""), ti, &p.inputs, &p.groups, &p.groups[groups_len-1], 0, name)

    fmt.println(p)
    
    return p.groups[groups_len-1].subgroup[0]
}

EditableText :: struct {
    buffer: []u8,
    length: u32,
}

EditableSlice :: struct($T: typeid) {
    buffer: []T,
    length: u32,
}

main :: proc() {
    ExampleSubstruct :: struct {
        button: bool "type: 'toggle'",
        number: i32 "placeholder: 'hi'",
        hidden: bool "type: 'hidden'",
        vec: [2]f32 "min: '0', max: '10.5'"
    }

    Example :: struct {
        range: f32 "type: 'slider', min: '-1.5', max: '10'",
        //text: EditableText "placeholder: 'value'",
        sub: ExampleSubstruct,
    }

    ex := Example {
        range = 5,
        sub = ExampleSubstruct {
            button = false,
            number = 0,
            vec = {0.2, 1}
        }
    }
    p := create_panel_pool()
    panel := create_panel(&p, &ex, "ex")
    //panel2 := create_panel(&p, &ex, "ex")
    for group, i in p.groups {
        fmt.println(group, i)
    }
    for input, i in p.inputs {
        fmt.println(input, i)
    }
}
