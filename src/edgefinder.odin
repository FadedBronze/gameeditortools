package main

import la "core:math/linalg"
import ut "project:utils"

// finds the point where a ray exits AABB
ray_exit_aabb :: proc(position: la.Vector2f64, direction: la.Vector2f64, cage: ut.Bounds(f64)) -> la.Vector2f64 {
    if ok, intersection := ut.ray_intersect_line_segment(
        position, 
        direction, 
        la.Vector2f64{cage.x, cage.y}, 
        la.Vector2f64{cage.x+cage.width, cage.y}
    ); ok {
        return intersection
    }
    if ok, intersection := ut.ray_intersect_line_segment(
        position, 
        direction, 
        la.Vector2f64{cage.x+cage.width, cage.y}, 
        la.Vector2f64{cage.x+cage.width, cage.height+cage.y}
    ); ok {
        return intersection
    }
    if ok, intersection := ut.ray_intersect_line_segment(
        position, 
        direction, 
        la.Vector2f64{cage.x+cage.width, cage.y+cage.height}, 
        la.Vector2f64{cage.x, cage.y+cage.height}
    ); ok {
        return intersection
    }
    if ok, intersection := ut.ray_intersect_line_segment(
        position, 
        direction, 
        la.Vector2f64{cage.x, cage.y+cage.height}, 
        la.Vector2f64{cage.x, cage.y}
    ); ok {
        return intersection
    }
    assert(false, "we should be intersecting one of them maybe exact corner case?")
    return la.Vector2f64{0, 0}
}

find_shadow_regions :: proc(light_sources: []la.Vector2f64, world_hitboxes: []ut.Bounds(f64), screen_rect: ut.Bounds(f64)) -> (shadow_regions: []la.Vector2f64) {
    lines := make([dynamic]la.Vector2f64)

    // sort corner by angle?
    // the ones that don't hit anything goes to edge of screen
    // shadows are where there is a throughline then 1 or more intersections then another throughline

    for light_source in light_sources {
        for hitbox in world_hitboxes {
            
        }
    }
}
