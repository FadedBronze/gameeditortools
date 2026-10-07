package main
import "project:editorui"
import la "core:math/linalg"
import rl "vendor:raylib"
import ut "utils"

WorldViewport2D :: struct {
    world_to_screenspace_scale: f64 "text", 
    screen_rect: ut.Bounds(f64),
    camera_position: la.Vector2f64 "text",
    camera_scale: la.Vector2f64 "text",
    camera_rotation: f64 "slider min(0) max(6.283)",
}

drag_camera :: proc(appdata: ^AppData, index: editorui.ViewportIndex) {
    viewport := &appdata.viewports[index]

    mouse_pos := rl.GetMousePosition()
    // TODO: needs to be replaced with pointer over from editor since ui may need to go over
    within := ut.position_within_bounds(la.Vector2f64{f64(mouse_pos.x), f64(mouse_pos.y)}, viewport.screen_rect)

    if rl.IsMouseButtonPressed(.LEFT) && within {
        appdata.drag = ViewportDrag {
            mouse_start = mouse_pos,
            camera_start = viewport.camera_position,
            active = index,
            camera_inverse_transform_matrix = la.matrix3_inverse(get_viewport_matrix(viewport^)),
        }
    }

    if viewport_drag, ok := &appdata.drag.(ViewportDrag); ok {
        if rl.IsMouseButtonDown(.LEFT) && viewport_drag.active == index {
            inverse := viewport_drag.camera_inverse_transform_matrix

            start_world := ut.apply_matrix_to_point(inverse, auto_cast viewport_drag.mouse_start)
            current_world := ut.apply_matrix_to_point(inverse, auto_cast mouse_pos)

            drag_world := current_world - start_world

            viewport.camera_position = viewport_drag.camera_start - drag_world
        }

        if rl.IsMouseButtonReleased(.LEFT) && viewport_drag.active == index {
            viewport_drag.active = max(editorui.ViewportIndex)
        }
    }
}

zoom_camera :: proc(appdata: ^AppData, index: editorui.ViewportIndex) {
    viewport := &appdata.viewports[index]

    mouse_pos := rl.GetMousePosition()

    within := ut.position_within_bounds(la.Vector2f64{f64(mouse_pos.x), f64(mouse_pos.y)}, viewport.screen_rect)

    if within {
        viewport.camera_scale.x *= 1+f64(rl.GetMouseWheelMove() * appdata.delta_time * 100)
        viewport.camera_scale.y *= 1+f64(rl.GetMouseWheelMove() * appdata.delta_time * 100)
    }
}

screen_to_world_space :: proc(viewport: WorldViewport2D, screen_position: la.Vector2f64) -> la.Vector2f64 {
    transform := get_viewport_matrix(viewport)
    screen_to_world_mat := la.matrix3_inverse(transform)

    return ut.apply_matrix_to_point(screen_to_world_mat, screen_position)
}

get_viewport_matrix :: proc(viewport: WorldViewport2D) -> la.Matrix3x3f64 {
    camera_offset := ut.create_matrix(-viewport.camera_position, {1, 1}, 0)
    camera_matrix := ut.create_matrix({0, 0}, viewport.camera_scale, viewport.camera_rotation)
    view_matrix := ut.create_matrix_from_transform(ut.Transform(f64) {
        rotation_rad = 0,
        offset = {viewport.screen_rect.x+viewport.screen_rect.width/2, viewport.screen_rect.y+viewport.screen_rect.height/2},
        scale = {viewport.world_to_screenspace_scale, viewport.world_to_screenspace_scale},
    })

    return la.matrix_mul(view_matrix, la.matrix_mul(camera_matrix, camera_offset))
}
