package utils

import "core:mem"
import la "core:math/linalg"

// colors 

Color :: distinct [4]u8

WHITE :: Color { 255, 255, 255, 255 }
BLACK :: Color { 0, 0, 0, 255 }
RED :: Color { 255, 0, 0, 255 }
BLUE :: Color { 0, 0, 255, 255 }
ORANGE :: Color { 255, 125, 0, 255 }

concatenate :: proc(buf: []u8, strs: ..string) -> string {
    offset := 0
    for str in strs {
        copy_from_string(buf[offset:offset+len(str)], str)
        offset += len(str)
    }
    return transmute(string)buf[0:offset]
}

get_contrasting_color :: proc(col: Color) -> Color {
    if col.r/3 + col.g/3 + col.b/3 > 255/2 {
        return BLACK
    } else {
        return WHITE
    }
}

change_opacity :: proc(col: Color, a: u8) -> Color {
    col := col
    col.a = a
    return col
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

// bounds -----

Bounds :: struct(T: typeid) {
    x: T "text",
    y: T "text",
    width: T "text",
    height: T "text",
}

bounds_to_bounds :: proc($T: typeid, from: Bounds($U)) -> Bounds(T) {
    return Bounds(T) {
        x = T(from.x),
        y = T(from.y),
        width = T(from.width),
        height = T(from.height),
    }
}

position_within_bounds :: proc(position: [2]$T, bounds: Bounds(T)) -> bool {
    within_x := bounds.x < position.x && bounds.x + bounds.width > position.x
    within_y := bounds.y < position.y && bounds.y + bounds.height > position.y
    return within_x && within_y
}

f32list_to_color :: proc(color: [4]f32) -> Color {
    return {u8(color.r), u8(color.g), u8(color.b), u8(color.a)}
}

color_to_f32list :: proc(color: Color) -> [4]f32 {
    return {
        f32(color.r),
        f32(color.g),
        f32(color.b),
        f32(color.a),
    }
}

// transforms -----

Transform :: struct(T: typeid) {
    scale: [2]T "text",
    offset: [2]T "text",
    rotation_rad: T "slider min(0) max(6.283)",
}

apply_matrix :: proc {
    apply_matrix_to_bounds,
    apply_matrix_to_point,
}

create_matrix :: proc {
    create_matrix_from_transform,
    create_matrix_from_values
}

create_matrix_from_transform :: proc(a: Transform(f64)) -> la.Matrix3x3f64 {
    return create_matrix_from_values(a.offset, a.scale, a.rotation_rad)
}

create_matrix_from_values :: proc(offset: la.Vector2f64, scale: la.Vector2f64, radians: f64) -> la.Matrix3x3f64 {
    scale := la.Matrix3x3f64 {
        scale.x, 0,       0, 
        0,       scale.y, 0, 
        0,       0,       1,
    }
    rotate := la.matrix3_rotate_f64(radians, la.Vector3f64{0, 0, 1})
    matrix3x3 := la.matrix_mul(scale, rotate)
    matrix3x3[0, 2] += offset.x
    matrix3x3[1, 2] += offset.y
    return matrix3x3
}

apply_matrix_to_point :: proc(a_mat: la.Matrix3f64, b: la.Vector2f64) -> la.Vector2f64 {
    return la.matrix_mul_vector(a_mat, la.Vector3f64{b.x, b.y, 1}).xy
}

apply_matrix_to_bounds :: proc(mat: la.Matrix3f64, b: Bounds(f64)) -> Bounds(f64) {
    p1 := la.Vector3f64{b.x, b.y, 1}
    p2 := la.Vector3f64{b.x+b.width, b.y+b.height, 1}

    p1t := la.matrix_mul_vector(mat, p1)
    p2t := la.matrix_mul_vector(mat, p2)

    return Bounds(f64) {
        x = p1t.x,
        y = p1t.y,
        width = p2t.x-p1t.x,
        height = p2t.y-p1t.y,
    }
}

TRANSFORM_IDENTITY_F64 :: Transform(f64) {
    offset = {0, 0},
    scale = {1, 1},
    rotation_rad = 0,
}

// Object pool stuff ----

ObjectIndex :: distinct u32
ObjectId :: distinct u32

ObjectPool :: struct(T: typeid) {
    mapping_id_to_index: []ObjectIndex,
    mapping_id_to_index_next_free: ObjectId,
    mapping_index_to_id: []ObjectId,
    game_objects: []T,
    next_free_game_object: ObjectIndex,
    max_objects: u32,
}

object_pool_min_memory :: proc(pool: ^ObjectPool($T)) -> u8 {
    return (size_of(ObjectIndex) + size_of(ObjectId) + size_of(T)) * max_objects
}

object_pool_init :: proc(pool: ^ObjectPool($T), allocator: mem.Allocator) {
    assert(pool.max_objects != 0)
    pool.game_objects = make([]T, pool.max_objects, allocator)
    pool.mapping_id_to_index = make([]ObjectIndex, pool.max_objects, allocator)
    pool.mapping_index_to_id = make([]ObjectId, pool.max_objects, allocator)
}

create_object :: proc(pool: ^ObjectPool($T), object: T) -> ObjectId {
    assert(pool.next_free_game_object < max(ObjectIndex) && pool.next_free_game_object <= ObjectIndex(pool.max_objects))

    pool.mapping_id_to_index[pool.mapping_id_to_index_next_free] = pool.next_free_game_object
    pool.mapping_index_to_id[pool.next_free_game_object] = pool.mapping_id_to_index_next_free
    pool.game_objects[pool.next_free_game_object] = object
    pool.next_free_game_object += 1
    pool.mapping_id_to_index_next_free += 1

    return pool.mapping_id_to_index_next_free-1
}

delete_object :: proc(pool: ^ObjectPool($T), id: ObjectId) {
    assert(pool.next_free_game_object > 0)

    // get the index
    index := pool.mapping_id_to_index[id]
    // invalidated the mapping
    pool.mapping_id_to_index[id] = max(ObjectIndex)
    // replace the free cell with the last cell
    pool.game_objects[index] = pool.game_objects[pool.next_free_game_object-1]
    // mark last cell as free
    pool.next_free_game_object -= 1
    // point last cell id to moved cell
    last_id := pool.mapping_index_to_id[pool.next_free_game_object]
    pool.mapping_id_to_index[last_id] = index
    // fix mapping -> not nessisary because mapping invalidated
    pool.mapping_index_to_id[pool.next_free_game_object] = 0
}

/// pointer is only valid until next deletion
get_object :: proc(pool: ^ObjectPool($T), id: ObjectId) -> ^T {
    index := pool.mapping_id_to_index[id]
    if index > ObjectIndex(pool.max_objects) {
        return nil
    }
    return &pool.game_objects[index]
}

//@(test)
//object_reference_test :: proc(t: ^testing.T) {
//    object_pool: ObjectPool(la.Vector2f32)
//    object_pool.max_objects = 1000000
//    object_pool_init(&object_pool, context.allocator)
//
//    a := create_object(&object_pool, la.Vector2f32{45, 5})
//
//    a_obj := get_object(&object_pool, a)
//
//    testing.expect(t, a_obj != nil && a_obj^ == la.Vector2f32{45, 5}, "incorrectly referenced")
//}
//
//@(test)
//object_mass_deletion_creation_test :: proc(t: ^testing.T) {
//    object_pool: ObjectPool(la.Vector2f32)
//    object_pool.max_objects = 1000000
//    object_pool_init(&object_pool, context.allocator)
//
//    for i in 0..<1000000 {
//        create_object(&object_pool, la.Vector2f32{f32(i) * 2 + 5, 5})
//    }
//
//    for i in 0..<1000000 {
//        expectation := la.Vector2f32{f32(i) * 2 + 5, 5}
//        obj := get_object(&object_pool, ObjectId(i))
//        testing.expect(t, expectation == obj^, "expected equal")
//        
//        delete_object(&object_pool, ObjectId(i))
//    }
//}
//
//@(test)
//object_random_deletion_creation_test :: proc(t: ^testing.T) {
//    object_pool: ObjectPool(la.Vector2f32)
//    object_pool.max_objects = 1000000
//    object_pool_init(&object_pool, context.allocator)
//
//    for _ in 0..<1000 {
//        ids := make([]u32, 1000000)
//        for i in 0..<1000000 {
//            ids[i] = u32(i)
//            id := create_object(&object_pool, la.Vector2f32{f32(i) * 2 + 5, 5})
//            testing.expect(t, ids[i] == u32(id), "ids should always increment")
//        }
//
//        rand.shuffle(ids)
//
//        for j in 0..<1000000 {
//            i := ids[j]
//
//            expectation := la.Vector2f32{f32(i) * 2 + 5, 5}
//            obj := get_object(&object_pool, ObjectId(i))
//            testing.expect(t, expectation == obj^, "expected equal")
//            
//            delete_object(&object_pool, ObjectId(i))
//        }
//    }
//}
