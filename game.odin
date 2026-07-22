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
import "core:testing"

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
    selected_tile: TileType "dropdown",
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

place_tile :: proc(appdata: ^AppData, viewport_id: editorui.ViewportIndex, allocator: mem.Allocator) {
    viewport := &appdata.viewports[viewport_id]
    tile_grid := &appdata.tilegrid

    mouse_pos := rl.GetMousePosition()
    // TODO: needs to be replaced with pointer over from editor since ui may need to go over
    within := ut.position_within_bounds(la.Vector2f64{f64(mouse_pos.x), f64(mouse_pos.y)}, viewport.screen_rect)
    world_mouse_pos := screen_to_world_space(viewport^, auto_cast mouse_pos)

    tilegrid_position := [2]i32{
        i32(math.mod_f64(world_mouse_pos.x, tile_grid.width)),
        i32(math.mod_f64(world_mouse_pos.y, tile_grid.height))
    }

    if rl.IsMouseButtonPressed(.LEFT) {
        set_tile(tile_grid, tilegrid_position, appdata.editor_settings.selected_tile, allocator)
    }
}

render_tiles :: proc(viewport: WorldViewport2D, tilegrid: RectangleTileGrid) {
    mat := ut.create_matrix_from_transform(tilegrid.transform) * get_viewport_matrix(viewport)
    b := tilegrid.bounds

    for y in b.y..<b.height+b.y {
        for x in b.x..<b.width+b.x {
            pos := la.Vector2f64{f64(x), f64(y)}

            viewport_bounds := ut.apply_matrix_to_bounds(mat, ut.Bounds(f64) {
                x = pos.x,
                y = pos.y,
                width = 1,
                height = 1,
            })

            tile_type := get_tile(tilegrid, {x, y})
            color := ut.BLACK

            switch tile_type {
                case .Empty:
                case .Red:
                    color = ut.RED
                case .Blue:
                    color = ut.BLUE
            }

            rl.DrawRectangleRec(transmute(rl.Rectangle)ut.bounds_to_bounds(f32, viewport_bounds), auto_cast color)
        }
    }
}

render :: proc(appdata: rawptr, screen_rect: ut.Bounds(f32), id: editorui.ViewportIndex) {
    appdata: ^AppData = cast(^AppData)appdata
    viewport := &appdata.viewports[id]
    viewport.screen_rect = ut.bounds_to_bounds(f64, screen_rect)

    render_tile_grid_lines(viewport^, appdata.tilegrid)

    render_tiles(viewport^, appdata.tilegrid)

    switch appdata.editor_settings.active_tool {
    case .CameraControl:
        drag_camera(appdata, id)
    case .TileBrush:
        place_tile(appdata, id, mem.arena_allocator(&appdata.init_allocator))
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

set_tile_base :: proc(tilegrid: ^RectangleTileGrid, position: [2]i32, tile: TileType) {
    idx_y := int(tilegrid.bounds.width) * int(position.y - tilegrid.bounds.y)
    idx_x := int(position.x - tilegrid.bounds.x)
    tilegrid.tiles[idx_y + idx_x] = tile
}

set_tile :: proc(tilegrid: ^RectangleTileGrid, position: [2]i32, tile: TileType, allocator: mem.Allocator = context.allocator) {
    // resize case
    if !ut.position_within_bounds(position, tilegrid.bounds) {
        old_bounds := tilegrid.bounds
        
        // resizing
        if position.x-tilegrid.bounds.x >= tilegrid.bounds.width {
            tilegrid.bounds.width = position.x-tilegrid.bounds.x+1
        }

        if position.x < tilegrid.bounds.x {
            increment := math.abs(position.x-tilegrid.bounds.x)
            tilegrid.bounds.width += increment
            tilegrid.bounds.x = position.x
        } 

        if position.y-tilegrid.bounds.y >= tilegrid.bounds.height {
            tilegrid.bounds.height = position.y-tilegrid.bounds.y+1
        }

        if position.y < tilegrid.bounds.y {
            increment := math.abs(position.y-tilegrid.bounds.y)
            tilegrid.bounds.height += increment
            tilegrid.bounds.y = position.y
        }

        old_tiles := tilegrid.tiles
        tilegrid.tiles = make([]TileType, tilegrid.bounds.width * tilegrid.bounds.height, allocator)

        for x in old_bounds.x..<old_bounds.width+old_bounds.x {
            for y in old_bounds.y..<old_bounds.height+old_bounds.y {
                set_tile_base(tilegrid, {x, y}, get_tile_base(old_tiles, old_bounds.x, old_bounds.y, old_bounds.width, {x, y}))
            }
        }
    }

    // basic case
    set_tile_base(tilegrid, position, tile)
}

get_tile_base :: proc(tiles: []TileType, x, y, width: i32, position: [2]i32) -> TileType {
    idx_y := int(width) * int(position.y - y)
    idx_x := int(position.x - x)
    return tiles[idx_y + idx_x]
}

get_tile :: proc(tilegrid: RectangleTileGrid, position: [2]i32) -> TileType {
    if !ut.position_within_bounds(position, tilegrid.bounds) {
        return .Empty
    }
    return get_tile_base(tilegrid.tiles, tilegrid.bounds.x, tilegrid.bounds.y, tilegrid.bounds.width, position)
}

init_game :: proc(appdata: ^AppData) {
    appdata.tilegrid = RectangleTileGrid {
        width = 1,
        height = 1,
        transform = ut.TRANSFORM_IDENTITY_F64,
    }

    context.allocator = mem.arena_allocator(&appdata.init_allocator)
    
    set_tile(&appdata.tilegrid, {0, 0}, .Blue)
    set_tile(&appdata.tilegrid, {-1, -1}, .Red)
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

@(test)
create_tiles :: proc(t: ^testing.T) {
    tilegrid := RectangleTileGrid {
        width = 1,
        height = 1,
        transform = ut.TRANSFORM_IDENTITY_F64,
    }
    
    set_tile(&tilegrid, {0, 0}, .Blue)
    set_tile(&tilegrid, {-1, -1}, .Red)
    set_tile(&tilegrid, {-2, -2}, .Blue)
    set_tile(&tilegrid, {-3, -3}, .Red)
    set_tile(&tilegrid, {1, 1}, .Red)
    set_tile(&tilegrid, {5, 1}, .Blue)
    set_tile(&tilegrid, {20, 20}, .Red)
    set_tile(&tilegrid, {50, 0}, .Blue)
    set_tile(&tilegrid, {50, 0}, .Red)

    //fmt.println(appdata.tilegrid.bounds)
    //for y in appdata.tilegrid.bounds.y..<appdata.tilegrid.bounds.height+appdata.tilegrid.bounds.y {
    //    for x in appdata.tilegrid.bounds.x..<appdata.tilegrid.bounds.width+appdata.tilegrid.bounds.x {
    //        fmt.printf("%d ", get_tile(&appdata.tilegrid, {x, y}))
    //    }
    //    fmt.println()
    //}

    testing.expect(t, get_tile(tilegrid, {50, 0}) == .Red)
}
