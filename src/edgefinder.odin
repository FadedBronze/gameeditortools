package main

import la "core:math/linalg"
import ut "project:utils"
import "core:sort"
import "core:math"
import rl "vendor:raylib"

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

find_shadow_regions :: proc(light_sources: []la.Vector2f64, world_hitboxes: []ut.Bounds(f64), screen_rect: ut.Bounds(f64)) -> rl.Texture {
    lines := make([dynamic]la.Vector2f64)
    lines_light_source := make([dynamic]int)

    for light_source, i in light_sources {
        for hitbox in world_hitboxes {
            for corner in ut.get_aabb_corners(hitbox) {
                exit_point := ray_exit_aabb(light_source, corner-light_source, screen_rect)
                append(&lines, exit_point-light_source)
                append(&lines_light_source, i)
            }
        }
    }

    // sort by angle
    sort.quick_sort_proc(lines[:], proc (a: la.Vector2f64, b: la.Vector2f64) -> int {
        a1 := math.atan2(b.y, b.x)
        a2 := math.atan2(a.y, a.x)
        if a2 > a1 {
            return 1
        } else {
            return -1
        }
    })

    // create a shadow map
    render_texture := rl.LoadRenderTexture(auto_cast screen_rect.width, auto_cast screen_rect.height)

    rl.BeginTextureMode(render_texture)

    prev := lines[len(lines)-1]
    for i in 0..<len(lines) {
        curr := lines[i]
        light_source := light_sources[lines_light_source[i]]

        hitpoints := make([dynamic]la.Vector2f64)
        hitboxes := make([dynamic]ut.Bounds(f64))

        for hitbox in world_hitboxes {
            if ok, prev_entrance_point, _ := ut.ray_intersect_bounds(light_source, prev, hitbox); ok {
                if ok, entrance_point, _ := ut.ray_intersect_bounds(light_source, curr, hitbox); ok {
                    // add visible regions to map
                    rl.DrawTriangle(auto_cast light_source, auto_cast prev_entrance_point, auto_cast entrance_point, auto_cast ut.WHITE)
                }
            }
        }
    }

    rl.EndTextureMode()
    return render_texture.texture
}
