package main

import "project:editorui"
import ut "utils"
import clay "clay-odin"
import rl "vendor:raylib"
import la "core:math/linalg"

import "core:math"
import "core:mem"
import "core:fmt"
import "core:sort"

WorldViewport2D :: struct {
    world_to_screenspace_scale: f64 "text", 
    screen_rect: ut.Bounds(f64),
    camera_position: la.Vector2f64 "text",
    camera_scale: la.Vector2f64 "text",
    camera_rotation: f64 "slider min(0) max(6.283)",
}

Player :: struct {
    sprite: Sprite,
}

TileType :: enum {
    Empty,
    Red,
    Blue,
}

RectangleTileGrid :: struct {
    width: f64 "text",
    height: f64 "text",
    bounds: ut.Bounds(i32) "group",
    tiles: []TileType,
    transform: ut.Transform(f64) "group" 
}

RootGameObject :: struct {}

Tile :: struct {
    sprite: Sprite
}

//GameObject :: struct {
//    transform: ut.Transform(f64),
//    z_index: u16,
//    data: union {
//        RootGameObject,
//        Player,
//        Tile,
//        RectangleTileGrid,
//    },
//    children: []ut.ObjectId,
//}

MAX_GAMEOBJECTS :: 10000
INIT_MEMORY_BUFFER_SIZE :: 10000000
FRAME_MEMORY_BUFFER_SIZE :: 5000

ViewportDrag :: struct {
    active: editorui.ViewportIndex,
    mouse_start: la.Vector2f32,
    camera_start: la.Vector2f64,
    camera_inverse_transform_matrix: la.Matrix3f64,
}

Views :: enum {
    WorldViewports,    
    TileEditor,
}

EditorSettings :: struct {
    open_views: bit_set[Views] "dropdown",
    selected_tile: TileType "text",
    active_tool: enum {
        CameraControl,
        TileBrush,
    } "dropdown",
}

AppData :: struct {
    delta_time: f32,
    ui_context: ^clay.Context,
    viewports: [2]WorldViewport2D,

    tilegrid: RectangleTileGrid,
    
    viewport_drag: ViewportDrag,

    frame_buffer: []u8,
    frame_allocator: mem.Arena,
    
    init_buffer: []u8,
    init_allocator: mem.Arena,

    //draw_callbacks: []DrawCallback,
    //draw_callback_next_free: u32,

    editor_settings: EditorSettings,
}

RectangleSprite :: struct {
    rect: ut.Bounds(f64),
    color: ut.Color,
}

Sprite :: union {
    RectangleSprite
}

render_tile_grid_lines :: proc(viewport: WorldViewport2D, tilegrid: RectangleTileGrid) { 
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

        rl.DrawLineEx(auto_cast p1, auto_cast p2, 1, auto_cast ut.WHITE/3)
    }
    
    for i in -lines_y/2..<lines_y/2 {
        spacing := f64(i)*tilegrid.height+bounds_worldspace.height/2-math.mod_f64(viewport.camera_position.y, tilegrid.height)

        p1 := la.Vector2f64{-outer_radius*2, spacing} + bounds_worldspace_offset
        p2 := la.Vector2f64{outer_radius*2, spacing} + bounds_worldspace_offset
        
        p1 = ut.apply_matrix_to_point(mat, p1)
        p2 = ut.apply_matrix_to_point(mat, p2)

        rl.DrawLineEx(auto_cast p1, auto_cast p2, 1, auto_cast ut.WHITE/3)
    }
}

offset: f32 = 0
update :: proc(appdata: rawptr, delta_time: f32) {
    appdata: ^AppData = cast(^AppData)appdata
    appdata.delta_time = delta_time
}

drag_camera :: proc(appdata: ^AppData, index: editorui.ViewportIndex) {
    viewport := &appdata.viewports[index]

    mouse_pos := rl.GetMousePosition()
    // TODO: needs to be replaced with pointer over from editor since ui may need to go over
    within := ut.position_within_bounds(la.Vector2f64{f64(mouse_pos.x), f64(mouse_pos.y)}, viewport.screen_rect)

    if rl.IsMouseButtonPressed(.LEFT) && within {
        appdata.viewport_drag.mouse_start = mouse_pos
        appdata.viewport_drag.camera_start = viewport.camera_position
        appdata.viewport_drag.active = index
        appdata.viewport_drag.camera_inverse_transform_matrix = la.matrix3_inverse(get_viewport_matrix(viewport^))
    }

    if rl.IsMouseButtonDown(.LEFT) && appdata.viewport_drag.active == index {
        inverse := appdata.viewport_drag.camera_inverse_transform_matrix

        start_world := ut.apply_matrix_to_point(inverse, auto_cast appdata.viewport_drag.mouse_start)
        current_world := ut.apply_matrix_to_point(inverse, auto_cast mouse_pos)

        drag_world := current_world - start_world

        viewport.camera_position = appdata.viewport_drag.camera_start - drag_world
    }

    if rl.IsMouseButtonReleased(.LEFT) && appdata.viewport_drag.active == index {
        appdata.viewport_drag.active = max(editorui.ViewportIndex)
    }

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

place_tile :: proc(appdata: ^AppData, tile_grid: RectangleTileGrid, viewport_id: editorui.ViewportIndex) {
    viewport := &appdata.viewports[viewport_id]

    mouse_pos := rl.GetMousePosition()
    // TODO: needs to be replaced with pointer over from editor since ui may need to go over
    within := ut.position_within_bounds(la.Vector2f64{f64(mouse_pos.x), f64(mouse_pos.y)}, viewport.screen_rect)
    world_mouse_pos := screen_to_world_space(viewport^, auto_cast mouse_pos)

    tilegrid_position := [2]int{
        int(math.mod_f64(world_mouse_pos.x, tile_grid.width)),
        int(math.mod_f64(world_mouse_pos.y, tile_grid.height))
    }

    //TODO
    //tile_grid.tiles[tilegrid_position.y*int(tile_grid.columns)+tilegrid_position.x] = appdata.editor_settings.selected_tile
}

render :: proc(appdata: rawptr, screen_rect: ut.Bounds(f32), id: editorui.ViewportIndex) {
    appdata: ^AppData = cast(^AppData)appdata
    viewport := &appdata.viewports[id]
    viewport.screen_rect = ut.bounds_to_bounds(f64, screen_rect)

    render_tile_grid_lines(viewport^, appdata.tilegrid)

    switch appdata.editor_settings.active_tool {
    case .CameraControl:
        drag_camera(appdata, id)
    case .TileBrush:
        //place_tile(appdata, id)
    }

    clay.SetCurrentContext(appdata.ui_context)
    clay.BeginLayout()
    elements := clay.EndLayout(appdata.delta_time)
    clay_renderer(elements)
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

color_square :: proc(color: ut.Color) -> Sprite {
    return RectangleSprite {
        color = color,
        rect = ut.Bounds(f64) {
            height = 1,
            width = 1,
            x = -0.5,
            y = -0.5,
        },
    }
}

//set_tile :: proc(appdata: ^AppData, tilegrid_id: ut.ObjectId, position: [2]i32, tile: TileType) {
//    go := ut.get_object(&appdata.objects, tilegrid_id)
//    fmt.println(go)
//    tilegrid := &go.data.(RectangleTileGrid)
//
//    // resize case
//    if !ut.position_within_bounds(position, tilegrid.bounds) {
//        if position.x-tilegrid.bounds.x >= tilegrid.bounds.width {
//            tilegrid.bounds.width = position.x-tilegrid.bounds.x
//        }
//
//        if position.x-tilegrid.bounds.x < 0 {
//            tilegrid.bounds.width += math.abs(position.x-tilegrid.bounds.x)
//        }
//        
//        if position.y-tilegrid.bounds.y >= tilegrid.bounds.height {
//            tilegrid.bounds.height = position.x-tilegrid.bounds.x
//        }
//
//        if position.y-tilegrid.bounds.y < 0 {
//            tilegrid.bounds.height += math.abs(position.x-tilegrid.bounds.x)
//        }
//    } else {
//        // basic case
//        tilegrid.tiles[int(tilegrid.bounds.width) * int(position.y) + int(position.x)] = tile
//    }
//}
//
//get_tile :: proc(appdata: ^AppData, tilegrid_id: ut.ObjectId, position: [2]u16) -> TileType {
//    tilegrid := ut.get_object(&appdata.objects, tilegrid_id).data.(RectangleTileGrid)
//    return tilegrid.tiles[int(tilegrid.bounds.width) * int(position.y) + int(position.x)]
//}

init_game :: proc(appdata: ^AppData) {
    appdata.tilegrid = RectangleTileGrid {
        width = 1,
        height = 1,
        transform = ut.TRANSFORM_IDENTITY_F64,
    }
    
    //set_tile(appdata, tilegrid, {0, 0}, .Blue)
    //set_tile(appdata, tilegrid, {1, 0}, .Red)
    //set_tile(appdata, tilegrid, {5, 0}, .Blue)
    //set_tile(appdata, tilegrid, {500, 0}, .Red)

    //assert(get_tile(appdata, tilegrid, {500, 0}) == .Red)

    //for obj in appdata.objects.game_objects[:appdata.objects.next_free_game_object-1] {
    //    fmt.println(obj)
    //}
}

initialize_app :: proc(appdata: ^AppData, allocator: mem.Allocator) {
    // memory
    appdata.frame_buffer = make([]u8, FRAME_MEMORY_BUFFER_SIZE)
    mem.arena_init(&appdata.frame_allocator, appdata.frame_buffer)

    appdata.init_buffer = make([]u8, INIT_MEMORY_BUFFER_SIZE)
    mem.arena_init(&appdata.init_allocator, appdata.init_buffer)

    // clay
    min_memory_size := clay.MinMemorySize()
    memory := make([^]u8, min_memory_size, mem.arena_allocator(&appdata.init_allocator))
    arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(uint(min_memory_size), memory)
    game_ui_context := clay.Initialize(arena, {1080, 720}, { handler = error_handler })
    appdata.ui_context = game_ui_context
    
    // camera
    appdata.viewports = {
        WorldViewport2D {
            world_to_screenspace_scale = 20,
            camera_scale = {1, 1}
        },
        WorldViewport2D {
            world_to_screenspace_scale = 20,
            camera_scale = {1, 1}
        },
    }

    // game
    init_game(appdata)
}
