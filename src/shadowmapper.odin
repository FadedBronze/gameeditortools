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

    // create a shadow map

    rl.BeginTextureMode(viewport.shadow_map_texture)
    rl.ClearBackground(rl.Color{0, 0, 0, 125})
    //rl.BeginBlendMode(.CUSTOM_SEPARATE)
    //rlgl.SetBlendFactorsSeparate(rlgl.BLEND_SRC_ALPHA, rlgl.ONE_MINUS_SRC_ALPHA, rlgl.ONE, rlgl.ZERO, rlgl.FUNC_ADD, rlgl.FUNC_ADD)

    granularity := 2*math.PI/256

    for light_source in light_sources {
        angle: f64 = 0
        prev := la.Vector2f64{0, 0}
        first := true

        for angle < 2*math.PI {
            angle += granularity
            rd := la.Vector2f64{math.cos(angle), math.sin(angle)}

            closest := la.Vector2f64{-100000000, 100000000}

            for i in 0..<len(world_hitboxes)+1 {
                bound := worldspace_bounds
                if i != len(world_hitboxes) {
                    bound = world_hitboxes[i]
                }
                if count, intersections := ut.ray_intersect_bounds(light_source, rd, bound); count != 0 {
                    for intersection in intersections[0:count] {
                        scalar := (intersection-light_source) / rd
                        if la.distance(light_source, intersection) < la.distance(light_source, closest) && scalar.x > 0 && scalar.y > 0 {
                            closest = intersection
                        }
                    }
                }
            }

            if !first {
                cu := ut.apply_matrix_to_point(mat, closest)
                ls := ut.apply_matrix_to_point(mat, light_source)
                pr := ut.apply_matrix_to_point(mat, prev)
                fmt.println(prev, cu, ls)
                rl.DrawTriangle(auto_cast ls, auto_cast pr, auto_cast cu, rl.Color{255, 255, 255, 125})
                //rl.DrawLineV(auto_cast ls, auto_cast cu, rl.Color{255, 255, 255, 125})
                //rl.DrawLineV(auto_cast ls, auto_cast pr, rl.Color{255, 255, 255, 125})
            }

            prev = closest
            first = false
        }
    }

    //rl.EndBlendMode()
    rl.EndTextureMode()
}


