package main

import la "core:math/linalg"
import "core:fmt"
import ut "project:utils"

CameraFollow :: struct {
    prev_pos: la.Vector2f64,
}

follow_player :: proc(camera_follow: ^CameraFollow, appdata: ^AppData, dt: f32) -> la.Vector2f64 {

    // find player
    following_entity: ^Entity
    for i in 0..<appdata.entities_count {
        entity := &appdata.entities[i]

        if .Something in entity.flags && .CameraFollow in entity.flags {
            following_entity = entity
        }
    }
    
    // change target focus to room we are in
    for i in 0..<appdata.entities_count {
        entity := &appdata.entities[i]

        if .CameraRoom in entity.flags {
            if ut.position_within_bounds(following_entity.transform.offset, ut.bounds_to_bounds(f64, entity.grid_area)) {
                following_entity = entity
                following_entity.transform.offset = auto_cast ut.bounds_center(entity.grid_area)
            }
        }
    }
    
    camera_follow.prev_pos += (following_entity.transform.offset-camera_follow.prev_pos)*f64(dt)*5

    fmt.eprintln("No entity with camera follow")
    return camera_follow.prev_pos
}
