package main

import la "core:math/linalg"
import ut "project:utils"
import "core:sort"
import "core:math"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

//// finds the point where a ray exits AABB
//ray_exit_aabb :: proc(position: la.Vector2f64, direction: la.Vector2f64, cage: ut.Bounds(f64)) -> (bool, la.Vector2f64) {
//    if ok, intersection := ut.ray_intersect_line_segment(
//        position, 
//        direction, 
//        la.Vector2f64{cage.x, cage.y}, 
//        la.Vector2f64{cage.x+cage.width, cage.y}
//    ); ok {
//        return true, intersection
//    }
//    if ok, intersection := ut.ray_intersect_line_segment(
//        position, 
//        direction, 
//        la.Vector2f64{cage.x+cage.width, cage.y}, 
//        la.Vector2f64{cage.x+cage.width, cage.height+cage.y}
//    ); ok {
//        return true, intersection
//    }
//    if ok, intersection := ut.ray_intersect_line_segment(
//        position, 
//        direction, 
//        la.Vector2f64{cage.x+cage.width, cage.y+cage.height}, 
//        la.Vector2f64{cage.x, cage.y+cage.height}
//    ); ok {
//        return true, intersection
//    }
//    if ok, intersection := ut.ray_intersect_line_segment(
//        position, 
//        direction, 
//        la.Vector2f64{cage.x, cage.y+cage.height}, 
//        la.Vector2f64{cage.x, cage.y}
//    ); ok {
//        return true, intersection
//    }
//    //assert(false, "we should be intersecting one of them maybe exact corner case?")
//    return false, la.Vector2f64{0, 0}
//}

import "core:fmt"

//closest_collision_point :: proc(rp: la.Vector2f64, rd: la.Vector2f64, world_hitboxes: []ut.Bounds(f64)) -> la.Vector2f64 {
//    //for hitbox in world_hitboxes {
//    //}
//}

closest_intersection :: proc(rp: la.Vector2f64, rd: la.Vector2f64, world_hitboxes: []ut.Bounds(f64), worldspace_bounds: ut.Bounds(f64)) -> la.Vector2f64 {
    closest := la.Vector2f64{-100000000, 100000000}

    for i in 0..<len(world_hitboxes)+1 {
        bound := worldspace_bounds
        if i != len(world_hitboxes) {
            bound = world_hitboxes[i]
        }
        if count, intersections := ut.ray_intersect_bounds(rp, rd, bound); count != 0 {
            for intersection in intersections[0:count] {
                scalar := (intersection-rp) / rd
                if la.distance(rp, intersection) < la.distance(rp, closest) && scalar.x > 0 && scalar.y > 0 {
                    closest = intersection
                }
            }
        }
    }

    return closest
}

create_shadow_map :: proc(light_sources: []la.Vector2f64, world_hitboxes: []ut.Bounds(f64), viewport: WorldViewport2D) {
    mat := get_viewport_matrix_without_offset(viewport)
    inv_mat := la.inverse(mat)
    bounds_without_offset: ut.Bounds(f64) = {
        x = 0,
        y = 0,
        width = viewport.screen_rect.width,
        height = viewport.screen_rect.height,
    }
    worldspace_bounds := ut.apply_matrix_to_bounds(inv_mat, bounds_without_offset)

    angles := make([dynamic]f64)
    
    granularity := 2*math.PI/2048

    for light_source in light_sources {
        for bound in world_hitboxes {
            for corner in ut.get_aabb_corners(bound) {
                c := corner - light_source
                append(&angles, math.atan2(c.y, c.x)+granularity/2)
                append(&angles, math.atan2(c.y, c.x)-granularity/2)
            }
        }
        for corner in ut.get_aabb_corners(worldspace_bounds) {
            c := corner - light_source
            append(&angles, math.atan2(c.y, c.x)+granularity/2)
            append(&angles, math.atan2(c.y, c.x)-granularity/2)
        }
    }

    sort.quick_sort(angles[:])
    fmt.println(len(angles))

    // create a shadow map

    rl.BeginTextureMode(viewport.shadow_map_texture)
    rl.ClearBackground(rl.Color{0, 0, 0, 125})
    rl.BeginBlendMode(.CUSTOM)
    rlgl.SetBlendFactors(rlgl.ONE, rlgl.ZERO, rlgl.FUNC_ADD);

    for light_source in light_sources {
        prev := la.Vector2f64{0, 0}
        first := true
        first_closest := la.Vector2f64{0, 0}

        for angle in angles {
            if !first {
                rd := la.Vector2f64{math.cos(angle), math.sin(angle)}

                closest := closest_intersection(light_source, rd, world_hitboxes, worldspace_bounds)

                cu := ut.apply_matrix_to_point(mat, closest)
                ls := ut.apply_matrix_to_point(mat, light_source)
                pr := ut.apply_matrix_to_point(mat, prev)
                rl.DrawTriangle(auto_cast ls, auto_cast pr, auto_cast cu, rl.BLANK)

                prev = closest
            } else {
                angle := angles[len(angles)-1]
                rd := la.Vector2f64{math.cos(angle), math.sin(angle)}
                prev = closest_intersection(light_source, rd, world_hitboxes, worldspace_bounds)
                first = false
            }
        }
    }

    rl.EndBlendMode()
    rl.EndTextureMode()
}


