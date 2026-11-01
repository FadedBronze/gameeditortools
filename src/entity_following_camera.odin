package main

import la "core:math/linalg"
import "core:fmt"

CameraFollow :: struct {
    prev_pos: la.Vector2f64,
}

follow_player :: proc(camera_follow: ^CameraFollow, appdata: ^AppData, dt: f32) -> la.Vector2f64 {
    for i in 0..<appdata.entities_count {
        entity := appdata.entities[i]

        if .CameraFollow in entity.flags {
            camera_follow.prev_pos += (entity.transform.offset-camera_follow.prev_pos)*f64(dt)*10
            return camera_follow.prev_pos
        }
    }
    fmt.eprintln("No entity with camera follow")
    return camera_follow.prev_pos
}
