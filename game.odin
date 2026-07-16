package main

import "project:editorui"
import ut "utils"
import clay "clay-odin"
import rl "vendor:raylib"
import la "core:math/linalg"
import "core:sort"

import "core:math"
import "core:mem"

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

TileTypeIndex :: distinct u32

TileType :: struct {
    sprite: Sprite,
}

RectangleTileGrid :: struct {
    width: f64 "text",
    height: f64 "text",
    x: u16,
    y: u16,
    columns: u16,
    rows: u16,
    tile_types: []TileType,
    tiles: []TileTypeIndex,
}

RootGameObject :: struct {}

GameObject :: struct {
    transform: ut.Transform(f64),
    z_index: u16,
    data: union {
        RootGameObject,
        Player,
        RectangleTileGrid,
    },
    children: []ut.ObjectId,
}

MAX_GAMEOBJECTS :: 10000
INIT_MEMORY_BUFFER_SIZE :: 10000000
FRAME_MEMORY_BUFFER_SIZE :: 5000

ViewportDrag :: struct {
    active: editorui.ViewportIndex,
    mouse_start: la.Vector2f32,
    camera_start: la.Vector2f64,
    camera_inverse_transform_matrix: la.Matrix3f64,
}

DrawCallback :: struct {
    z_index: u16,
    fn: proc (param: CallbackParams),
    params: CallbackParams,
}

CallbackParams :: union {
    RenderSprite,
    RenderTileGridLines,
    RenderTileGridCells,
}

EditorSettings :: struct {
    open_views: bit_set[enum {
        WorldViewports,    
        ActiveToolSelector,
    }] "dropdown",
    //active_tool: enum {
    //    CameraControl,
    //    TileBrush,
    //} "dropdown",
}

AppData :: struct {
    delta_time: f32,
    ui_context: ^clay.Context,
    viewports: [2]WorldViewport2D,
    objects: ut.ObjectPool(GameObject),
    
    viewport_drag: ViewportDrag,

    frame_buffer: []u8,
    frame_allocator: mem.Arena,
    
    init_buffer: []u8,
    init_allocator: mem.Arena,

    draw_callbacks: []DrawCallback,
    draw_callback_next_free: u32,

    editor_settings: EditorSettings,
}

RectangleSprite :: struct {
    rect: ut.Bounds(f64),
    color: ut.Color,
}

Sprite :: union {
    RectangleSprite
}

RenderTileGridCells :: struct {
    viewport: WorldViewport2D, 
    transform: la.Matrix3f64, 
    tilegrid: RectangleTileGrid
}

render_tile_grid_cells :: proc(params: CallbackParams) {
    params := params.(RenderTileGridCells)

    for y in 0..<params.tilegrid.rows {
        for x in 0..<params.tilegrid.columns {
            tile_type := params.tilegrid.tiles[y * params.tilegrid.columns + x]
            tile := params.tilegrid.tile_types[tile_type]
            render_sprite(RenderSprite{params.transform, tile.sprite})
        }
    }
}

RenderTileGridLines :: struct {
    viewport: WorldViewport2D, 
    transform: la.Matrix3f64, 
    tilegrid: RectangleTileGrid
}

render_tile_grid_lines :: proc(params: CallbackParams) { 
    params := params.(RenderTileGridLines)
    
    mat := params.transform
    inverse := la.matrix3_inverse(params.transform)

    bounds_worldspace := ut.apply_matrix_to_bounds(inverse, params.viewport.screen_rect)
    
    // create a big 'ol circle filled with lines
    // but we are not trimming so its really a commically large square
    outer_radius := math.sqrt(
      math.pow(bounds_worldspace.width, 2) + 
        math.pow(bounds_worldspace.height, 2)
    ) / 2

    // unrounded line counts
    line_count_x := outer_radius*2 / params.tilegrid.width
    line_count_y := outer_radius*2 / params.tilegrid.height
    
    // rounded line counts
    lines_x := int(line_count_x/2)*2
    lines_y := int(line_count_y/2)*2
    
    bounds_worldspace_offset := la.Vector2f64{bounds_worldspace.x, bounds_worldspace.y}

    for i in -lines_x/2..<lines_x/2 {
        spacing := f64(i)*params.tilegrid.width+bounds_worldspace.width/2-math.mod_f64(params.viewport.camera_position.x, params.tilegrid.width)

        p1 := la.Vector2f64{spacing, -outer_radius*2} + bounds_worldspace_offset
        p2 := la.Vector2f64{spacing, outer_radius*2} + bounds_worldspace_offset

        p1 = ut.apply_matrix_to_point(mat, p1)
        p2 = ut.apply_matrix_to_point(mat, p2)

        rl.DrawLineEx(auto_cast p1, auto_cast p2, 1, auto_cast ut.WHITE/3)
    }
    
    for i in -lines_y/2..<lines_y/2 {
        spacing := f64(i)*params.tilegrid.height+bounds_worldspace.height/2-math.mod_f64(params.viewport.camera_position.y, params.tilegrid.height)

        p1 := la.Vector2f64{-outer_radius*2, spacing} + bounds_worldspace_offset
        p2 := la.Vector2f64{outer_radius*2, spacing} + bounds_worldspace_offset
        
        p1 = ut.apply_matrix_to_point(mat, p1)
        p2 = ut.apply_matrix_to_point(mat, p2)

        //p1 = ut.apply_matriy_to_point(mat, p1)
        //p2 = ut.apply_matriy_to_point(mat, p2)

        rl.DrawLineEx(auto_cast p1, auto_cast p2, 1, auto_cast ut.WHITE/3)
    }
}

queue_draw :: proc(appdata: ^AppData, callback: DrawCallback) {
    appdata.draw_callbacks[appdata.draw_callback_next_free] = callback
    appdata.draw_callback_next_free += 1
}

RenderSprite :: struct {
    full_transform: la.Matrix3f64,
    sprite: Sprite,
}

render_sprite :: proc(params: CallbackParams) {
    params := params.(RenderSprite)
    switch sprite_type in params.sprite {
    case RectangleSprite:
        transformed_bounds := ut.bounds_to_bounds(f32, ut.apply_matrix(params.full_transform, sprite_type.rect))
        rl.DrawRectangleRec(auto_cast transformed_bounds, auto_cast sprite_type.color)
    }
}

queue_render_game_objects :: proc(appdata: ^AppData, viewport_index: editorui.ViewportIndex, id: ut.ObjectId=0) {
    game_object := ut.get_object(&appdata.objects, id)

    viewport := appdata.viewports[viewport_index]
    viewport_transform := get_viewport_matrix(viewport)
    full_transform := la.matrix_mul(viewport_transform, ut.create_matrix_from_transform(game_object.transform))
    z := game_object.z_index

    switch object_type in game_object.data {
        case Player:
            queue_draw(appdata, {z, render_sprite, RenderSprite{full_transform, object_type.sprite}})
        case RootGameObject:
        case RectangleTileGrid:
            queue_draw(appdata, {z, render_tile_grid_lines, RenderTileGridLines{viewport, full_transform, object_type}})
            queue_draw(appdata, {z, render_tile_grid_cells, RenderTileGridCells{viewport, full_transform, object_type}})
    }

    for child_id in game_object.children {
        queue_render_game_objects(appdata, viewport_index, child_id)
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
    // needs to be replaced with pointer over from editor since ui may need to go over
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

render :: proc(appdata: rawptr, screen_rect: ut.Bounds(f32), id: editorui.ViewportIndex) {
    appdata: ^AppData = cast(^AppData)appdata
    appdata.viewports[id].screen_rect = ut.bounds_to_bounds(f64, screen_rect)

    queue_render_game_objects(appdata, id)

    sort.quick_sort_proc(appdata.draw_callbacks[0:appdata.draw_callback_next_free], proc (a, b: DrawCallback) -> int {
        return a.z_index > b.z_index ? 1 : 0
    })

    for draw_callback in appdata.draw_callbacks[0:appdata.draw_callback_next_free] {
        if draw_callback.fn != nil {
            draw_callback.fn(draw_callback.params)
        } else {
            fmt.println(draw_callback)
        }
    }

    appdata.draw_callback_next_free = 0

    drag_camera(appdata, id)

    clay.SetCurrentContext(appdata.ui_context)
    clay.BeginLayout()
    elements := clay.EndLayout(appdata.delta_time)
    clay_renderer(elements)
}

add_game_object :: proc(appdata: ^AppData, parent_id: ut.ObjectId, object: GameObject) -> ut.ObjectId {
    return add_game_objects(appdata, parent_id, {object})[0]
}

add_game_objects :: proc(appdata: ^AppData, parent_id: ut.ObjectId, objects: []GameObject) -> []ut.ObjectId {
    parent := ut.get_object(&appdata.objects, parent_id)

    new_children := make([]ut.ObjectId, len(objects)+len(parent.children), mem.arena_allocator(&appdata.init_allocator))
    copy_slice(new_children, parent.children)

    for object, i in objects {
        id := ut.create_object(&appdata.objects, object)
        new_children[i+len(parent.children)] = id
    }

    parent.children = new_children

    return parent.children
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

init_game :: proc(appdata: ^AppData) {
    add_game_object(appdata, 0, GameObject{
        transform = ut.TRANSFORM_IDENTITY_F64,
        z_index = 1,
        data = Player {
            sprite = RectangleSprite {
                color = ut.WHITE,
                rect = ut.Bounds(f64) {
                    x = -3,
                    y = -1,
                    width = 2,
                    height = 2,
                }
            }
        }
    })
    
    add_game_object(appdata, 0, GameObject{
        transform = ut.TRANSFORM_IDENTITY_F64,
        z_index = 1,
        data = Player {
            sprite = RectangleSprite {
                color = ut.WHITE,
                rect = ut.Bounds(f64) {
                    x = 1,
                    y = -1,
                    width = 2,
                    height = 2,
                }
            }
        }
    })
    
    add_game_object(appdata, 0, GameObject{
        transform = ut.TRANSFORM_IDENTITY_F64,
        data = RectangleTileGrid {
            width = 1,
            height = 1,
            tile_types = {
                TileType { color_square(ut.ORANGE) },
                TileType { color_square(ut.RED) },
            },
        }
    })

    for obj in appdata.objects.game_objects[:appdata.objects.next_free_game_object-1] {
        fmt.println(obj)
    }
}

import "core:fmt"

initialize_app :: proc(appdata: ^AppData, allocator: mem.Allocator) {
    // memory
    appdata.frame_buffer = make([]u8, FRAME_MEMORY_BUFFER_SIZE)
    mem.arena_init(&appdata.frame_allocator, appdata.frame_buffer)

    appdata.init_buffer = make([]u8, INIT_MEMORY_BUFFER_SIZE)
    mem.arena_init(&appdata.init_allocator, appdata.init_buffer)

    appdata.objects.max_objects = 10000
    ut.object_pool_init(&appdata.objects, mem.arena_allocator(&appdata.init_allocator))

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

    // root element
    ut.create_object(&appdata.objects, GameObject {})    
    
    // draw callback
    appdata.draw_callbacks = make([]DrawCallback, 10000, mem.arena_allocator(&appdata.init_allocator))

    // game
    init_game(appdata)

    //appdata.tile_grid = RectangleTileGrid {
    //    width = 10,
    //    height = 10,
    //    offset = {0, 0},
    //}
}
