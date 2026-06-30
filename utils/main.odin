package utils

import "core:mem"

Color :: distinct [4]u8

WHITE :: Color { 255, 255, 255, 255 }
BLACK :: Color { 0, 0, 0, 255 }

concatenate :: proc(buf: []u8, strs: ..string) -> string {
    offset := 0
    for str in strs {
        copy_from_string(buf[offset:offset+len(str)], str)
        offset += len(str)
    }
    return transmute(string)buf[0:offset]
}

blend_two_colors :: proc(b: Color, a: Color, t: f32) -> Color {
    rr := (f32(a.r) - f32(b.r)) * t + f32(b.r)
    gg := (f32(a.g) - f32(b.g)) * t + f32(b.g)
    bb := (f32(a.b) - f32(b.b)) * t + f32(b.b)
    aa := (f32(a.a) - f32(b.a)) * t + f32(b.a)

    return Color{u8(rr), u8(gg), u8(bb), u8(aa)}
}

blend_colors :: proc(colors: []Color, t: f32) -> Color {
    assert(len(colors)>0)

    if len(colors) == 1 {
        return colors[0]
    }

    t := t
    if t == 1 {
        t = 0.999
    }

    curr := t * f32(len(colors)-1)

    colorIdxDown: int = int(curr)
    colorIdxUp: int = int(curr)+1

    t = (curr - f32(colorIdxDown)) / f32(len(colors))

    return blend_two_colors(colors[colorIdxDown], colors[colorIdxUp], t)
}

Bounds :: struct(T: typeid) {
    x: T,
    y: T,
    width: T,
    height: T,
}

position_within_bounds :: proc(position: [2]$T, bounds: Bounds(T)) -> bool {
    within_x := bounds.x < position.x && bounds.x + bounds.width > position.x
    within_y := bounds.y < position.y && bounds.y + bounds.height > position.y
    return within_x && within_y
}
