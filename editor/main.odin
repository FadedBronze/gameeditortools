package editor

import "core:fmt"
import "core:mem"
import "core:slice"
import rn "base:runtime"
import ut "project:utils"

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

TextInputString :: struct {
    placeholder: string,
    text: ^string,
}

TextInputMutableBuffer :: struct {
    placeholder: string,
    text: EditableText,
}

Dropdown :: struct(T: typeid) {
    enum_names: []string,
    enum_values: []rn.Type_Info_Enum_Value,
    current: ^T,
}

MultiDropdown :: struct {
    enum_names: []string,
    enum_values: []rn.Type_Info_Enum_Value,
    upper: u32,
    lower: u32,
    current: []u8,
}

InputComponent :: union {
    Toggle,
    TextInputString,
    TextInputMutableBuffer,
    MultiDropdown,
    Dropdown(u8),
    Dropdown(u16),
    Dropdown(u32),
    Dropdown(u64),
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

InputComponentType :: enum { Toggle,
    Slider,
    TextInputBuffer,
    TextInputLength,
    NumberInput,
}

TagFlags :: bit_set[enum {
    Min,
    Max,
    Placeholder,
    Slider,
    Toggle,
    Length,
    Empty,
    Text,
    Dropdown,
}]

ParsedTag :: struct {
    flags: TagFlags,
    min: f64,
    max: f64,
    placeholder: string,
    length: string,
}

import "core:strings"
import "core:strconv"

parse_tag :: proc(tag: string) -> ParsedTag {
    it := tag
    res: ParsedTag
    if tag == "" {
        res.flags += {.Empty}
        return res
    }
    for str in strings.split_iterator(&it, " ") {
        if strings.contains(str, "max") {
            res.flags += {.Max}
            ok: bool
            res.max, ok = strconv.parse_f64(str[3+1:len(str)-1])
            assert(ok)
        }
        if strings.contains(str, "min") {
            res.flags += {.Min}
            ok: bool
            res.min, ok = strconv.parse_f64(str[3+1:len(str)-1])
            assert(ok)
        }
        if strings.contains(str, "placeholder") {
            res.flags += {.Placeholder}
            res.placeholder = str[11+1:len(str)-1]
        }
        if strings.contains(str, "slider") {
            res.flags += {.Slider}
        }
        if strings.contains(str, "text") {
            res.flags += {.Text}
        }
        if strings.contains(str, "toggle") {
            res.flags += {.Toggle}
        }
        if strings.contains(str, "dropdown") {
            res.flags += {.Dropdown}
        }
        if strings.contains(str, "length") {
            res.flags += {.Length}
            res.length = str[6+1:len(str)-1]
        }
    }
    return res
}

create_panel_recurse_struct_fields :: proc(
    s: rawptr,
    o: uintptr,
    tag: ParsedTag,
    ti: ^rn.Type_Info, 
    panel_pool: ^PanelPool,
    parent: ^Group,
    parent_idx: GroupIndex,
    name: string,
) {
    inputs := &panel_pool.inputs
    groups := &panel_pool.groups

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
                tags := info.tags[i]
                parsed := parse_tag(tags)
                type := info.types[i]
                offset := info.offsets[i]

                create_panel_recurse_struct_fields(s, o + offset, parsed, type, panel_pool, &new_parent, GroupIndex(i), info.names[i])
            }
        case rn.Type_Info_Pointer:
            ptr_ptr := cast(^rawptr)(cast(uintptr)s+o)
            if .Empty not_in tag.flags && ptr_ptr^ != nil {
                create_panel_recurse_struct_fields(ptr_ptr^, 0, tag, info.elem, panel_pool, parent, parent_idx, name)
            }
        case rn.Type_Info_Named:
            if .Empty not_in tag.flags {
                create_panel_recurse_struct_fields(s, o, tag, info.base, panel_pool, parent, parent_idx, name)
            }
            //if info.name == "EditableSlice" {
            //    unimplemented()
            //} else if info.name == "EditableText" {
            //    unimplemented()
            //} else {
            //}
        case rn.Type_Info_Array:
            append(groups, Group {
                type = .Subgroup,
                label = name,
                subgroup = make([]GroupIndex, info.count),
            })
            new_size := GroupIndex(len(groups)-1)
            parent.subgroup[parent_idx] = new_size
            new_parent := groups[new_size]

            for i in 0..<info.count {
                create_panel_recurse_struct_fields(s, o + uintptr(info.elem_size*i), tag, info.elem, panel_pool, &new_parent, GroupIndex(i), "")
            } 
        case rn.Type_Info_Integer:
            assert(info.endianness == .Platform)
            
            if .Text in tag.flags || .Slider in tag.flags {
                assert(!(.Text in tag.flags && .Slider in tag.flags))
                real_type: NumberInputType = .Slider in tag.flags ? .Slider : .Text

                switch {
                case ti.size == 1:
                    append(inputs, NumberInput(u8) {
                        type = real_type,
                        placeholder = tag.placeholder,
                        min = u8(tag.min),
                        max = tag.max == 0 ? max(u8) : u8(tag.max),
                        current = cast(^u8)(cast(uintptr)s+o)
                    })
                case ti.size == 4 && !info.signed:
                    append(inputs, NumberInput(u32) {
                        type = real_type,
                        placeholder = tag.placeholder,
                        min = u32(tag.min),
                        max = tag.min == 0 ? max(u32) : u32(tag.max),
                        current = cast(^u32)(cast(uintptr)s+o)
                    })
                case ti.size == 4 && info.signed:
                    append(inputs, NumberInput(i32) {
                        type = real_type,
                        placeholder = tag.placeholder,
                        min = i32(tag.min),
                        max = tag.max == 0 ? max(i32) : i32(tag.max),
                        current = cast(^i32)(cast(uintptr)s+o)
                    })
                case ti.size == 8 && !info.signed:
                    append(inputs, NumberInput(u64) {
                        type = real_type,
                        placeholder = tag.placeholder,
                        min = u64(tag.min),
                        max = tag.max == 0 ? max(u64) : u64(tag.max),
                        current = cast(^u64)(cast(uintptr)s+o)
                    })
                case:
                    unimplemented()
                }

                append(groups, Group {
                    type = .Component,
                    input = InputIndex(len(inputs)-1),
                    label = name,
                })
                new_size := GroupIndex(len(groups)-1)
                parent.subgroup[parent_idx] = new_size
            } 
        case rn.Type_Info_Float:
            assert(info.endianness == .Platform)
            
            if .Text in tag.flags || .Slider in tag.flags {
                assert(!(.Text in tag.flags && .Slider in tag.flags))
                real_type: NumberInputType = .Slider in tag.flags ? .Slider : .Text

                switch {
                case ti.size == 4:
                    append(inputs, NumberInput(f32) {
                        type = real_type,
                        placeholder = tag.placeholder,
                        min = f32(tag.min),
                        max = f32(tag.max),
                        current = cast(^f32)(cast(uintptr)s+o)
                    })
                case ti.size == 8:
                    append(inputs, NumberInput(f64) {
                        type = real_type,
                        placeholder = tag.placeholder,
                        min = f64(tag.min),
                        max = f64(tag.max),
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
        case rn.Type_Info_Enum:
            if .Dropdown in tag.flags {
                #partial switch v in info.base.variant {
                case rn.Type_Info_Integer:
                    mapping_types: [2]typeid = {u8, u16}
                    mapping_sizes: []int = {1, 2}

                    switch info.base.size {
                    case 1:
                        append(inputs, Dropdown(u8) {
                            current = cast(^u8)(cast(uintptr)s+o),
                            enum_names = info.names,
                            enum_values = info.values,
                        })
                    case 2:
                        append(inputs, Dropdown(u8) {
                            current = cast(^u8)(cast(uintptr)s+o),
                            enum_names = info.names,
                            enum_values = info.values,
                        })
                    case 4:
                        append(inputs, Dropdown(u32) {
                            current = cast(^u32)(cast(uintptr)s+o),
                            enum_names = info.names,
                            enum_values = info.values,
                        })
                    case 8:
                        append(inputs, Dropdown(u64) {
                            current = cast(^u64)(cast(uintptr)s+o),
                            enum_names = info.names,
                            enum_values = info.values,
                        })
                    case:
                        unimplemented()
                    }

                    append(groups, Group {
                        type = .Component,
                        input = InputIndex(len(inputs)-1),
                        label = name,
                    })
                    new_size := GroupIndex(len(groups)-1)
                    parent.subgroup[parent_idx] = new_size
                case:
                    assert(false, "only supports integer backing type for enums")
                }
            }
        case rn.Type_Info_Boolean:
            if .Toggle in tag.flags {
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
        case rn.Type_Info_String:
            append(inputs, TextInputString {
                placeholder = tag.placeholder,
                text = cast(^string)(cast(uintptr)s+o),
            })

            append(groups, Group {
                type = .Component,
                input = InputIndex(len(inputs)-1),
                label = name,
            })
            new_size := GroupIndex(len(groups)-1)
            parent.subgroup[parent_idx] = new_size
        case rn.Type_Info_Bit_Set:
            if .Dropdown in tag.flags {
                base_enum: rn.Type_Info_Enum

                #partial switch bitsettype in info.elem.variant {
                case rn.Type_Info_Named:
                    #partial switch namedbase in bitsettype.base.variant {
                    case rn.Type_Info_Enum:
                        base_enum = namedbase
                    case:
                        unimplemented()
                    }
                case rn.Type_Info_Enum:
                    base_enum = bitsettype
                case:
                    unimplemented()
                } 

                if len(base_enum.values) > 0 {
                    append(inputs, MultiDropdown {
                        current = slice.from_ptr(cast([^]u8)(cast(uintptr)s+o), info.underlying.size),
                        enum_names = base_enum.names,
                        enum_values = base_enum.values,
                        lower = u32(info.lower),
                        upper = u32(info.upper),
                    })
                }

                append(groups, Group {
                    type = .Component,
                    input = InputIndex(len(inputs)-1),
                    label = name,
                })
                new_size := GroupIndex(len(groups)-1)
                parent.subgroup[parent_idx] = new_size
            }
        case rn.Type_Info_Slice:
            if .Empty not_in tag.flags {
                unimplemented()
            }
        case:
            fmt.println(info)
            unimplemented()
    }
}

PanelPool :: struct {
    inputs: [dynamic]InputComponent,
    groups: [dynamic]Group,
}

create_panel_pool :: proc(allocator: mem.Allocator) -> PanelPool {
    inputs := make([dynamic]InputComponent, allocator)
    groups := make([dynamic]Group, allocator)

    reserve(&inputs, 10000)
    reserve(&groups, 10000)

    return PanelPool {
        inputs = inputs, 
        groups = groups,
    }
}

create_panel :: proc(p: ^PanelPool, s: ^$T, name: string) -> GroupIndex {
    ti: ^rn.Type_Info = type_info_of(type_of(s))
    ptr: rn.Type_Info_Pointer = ti.variant.(rn.Type_Info_Pointer)
    ti = ptr.elem

    buf: [1]GroupIndex = {0}
    false_root := Group {
        type = .Subgroup,
        label = "root",
        subgroup = buf[:1],
    }
    groups_len := len(p.groups)

    tag := ParsedTag {}
    create_panel_recurse_struct_fields(s, 0, tag, ti, p, &false_root, 0, name)

    //fmt.println(p.groups)
    //fmt.println(p.inputs)
    
    return false_root.subgroup[0]
}

EditableText :: struct {
    buffer: []u8,
    length: u32,
}

EditableSlice :: struct($T: typeid) {
    buffer: []T,
    length: u32,
}

ExampleDropdown :: enum {
    Fire,
    Water,
    Earth,
}

main :: proc() {
    ExampleSubstruct :: struct {
        button: bool "toggle",
        number: i32 "text placeholder(hi)",
        hidden: bool,
        vec: [2]f32 "text min(0) max(10.5)"
    }
    
    EditorUITheme :: struct {
        font_size: u8 "text",
        text_color: ut.Color "slider",
        background_color: ut.Color "slider",
        highlight_color: ut.Color "slider",
    }

    Example :: struct {
        //range: f32 "slider min(-1.5) max(10)",
        //text: string "text placeholder(name)",
        //uni: ExampleDropdown "dropdown",
        //sub: ExampleSubstruct,
        theme: EditorUITheme "group",
    }

    theme := EditorUITheme{
        font_size = 16,
        background_color = ut.WHITE,
        text_color = ut.BLACK,
        highlight_color = ut.Color {255, 0, 0, 255}
    }

    ex := Example {
        //range = 5,
        //text = "hello",
        theme = theme,
        //sub = ExampleSubstruct {
        //    button = false,
        //    number = 0,
        //    vec = {0.2, 1}
        //}
    }

    //fmt.println(parse_tag("slider min(-1.5) max(10)"))

    p := create_panel_pool(context.allocator)
    //panel := create_panel(&p, &ex, "ex")
    panel2 := create_panel(&p, &ex, "ex")
    for group, i in p.groups {
        fmt.println(group, i)
    }
    for input, i in p.inputs {
        fmt.println(input, i)
    }
}
