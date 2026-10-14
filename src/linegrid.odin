package main

import rl "vendor:raylib"
import la "core:math/linalg"
import ut "project:utils"

import "core:math"

RectangleLineGrid :: struct {
    // cell width and height
    width: f64 "text",
    height: f64 "text",
    // tranform applied after
    transform: ut.Transform(f64) "group" 
}

get_tile_bounds :: proc(linegrid: RectangleLineGrid, grid: Grid($T), position: GridPosition) -> ut.Bounds(f64) {
    return auto_cast {f64(position.x)*linegrid.width, f64(position.y)*linegrid.height, linegrid.width, linegrid.height}
}

world_to_tile_pos :: proc(world_mouse_pos: la.Vector2f64, linegrid: RectangleLineGrid) -> GridPosition {
    tilegrid_position := [2]i32{
        i32(math.floor(world_mouse_pos.x / f64(linegrid.width)) * linegrid.width),
        i32(math.floor(world_mouse_pos.y / f64(linegrid.height)) * linegrid.height)
    }
    return tilegrid_position
}

render_tile_grid_lines :: proc(viewport: WorldViewport2D, tilegrid: RectangleLineGrid) { 
    mat := ut.create_matrix_from_transform(tilegrid.transform) * get_viewport_matrix(viewport)
    inverse := la.matrix3_inverse(mat)

    bounds_worldspace := ut.apply_matrix_to_bounds(inverse, viewport.screen_rect)
    
    // create a big 'ol circle filled with lines
    // but we are not trimming so its really a commically large square
    outer_radius := math.sqrt(
      math.pow(bounds_worldspace.width, 2) + 
        math.pow(bounds_worldspace.height, 2)
    ) / 2

    // unrounded line counts
    line_count_x := outer_radius*2 / tilegrid.width
    line_count_y := outer_radius*2 / tilegrid.height
    
    // rounded line counts
    lines_x := int(line_count_x/2)*2
    lines_y := int(line_count_y/2)*2
    
    bounds_worldspace_offset := la.Vector2f64{bounds_worldspace.x, bounds_worldspace.y}

    for i in -lines_x/2..<lines_x/2 {
        spacing := f64(i)*tilegrid.width+bounds_worldspace.width/2-math.mod_f64(viewport.camera_position.x, tilegrid.width)

        p1 := la.Vector2f64{spacing, -outer_radius*2} + bounds_worldspace_offset
        p2 := la.Vector2f64{spacing, outer_radius*2} + bounds_worldspace_offset

        p1 = ut.apply_matrix_to_point(mat, p1)
        p2 = ut.apply_matrix_to_point(mat, p2)

        rl.DrawLineEx(auto_cast p1, auto_cast p2, 1, auto_cast ut.BLACK/3)
    }
    
    for i in -lines_y/2..<lines_y/2 {
        spacing := f64(i)*tilegrid.height+bounds_worldspace.height/2-math.mod_f64(viewport.camera_position.y, tilegrid.height)

        p1 := la.Vector2f64{-outer_radius*2, spacing} + bounds_worldspace_offset
        p2 := la.Vector2f64{outer_radius*2, spacing} + bounds_worldspace_offset
        
        p1 = ut.apply_matrix_to_point(mat, p1)
        p2 = ut.apply_matrix_to_point(mat, p2)

        rl.DrawLineEx(auto_cast p1, auto_cast p2, 1, auto_cast ut.BLACK/3)
    }
}
