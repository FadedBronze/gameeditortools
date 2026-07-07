package main

import "project:editorui"
import ut "utils"
import clay "clay-odin"
import rl "vendor:raylib"
import la "core:math/linalg"

import "core:mem"

WorldViewport2D :: struct {
    // viewport transform
    world_to_screenspace_scale: f64, 

    screen_rect: ut.Bounds(f64),

    // camera transform
    camera_transform: ut.Transform(f64),
}

Player :: struct {
    sprite: Sprite,
}

RectangleTileGrid :: struct {
    width: f32 "text",
    height: f32 "text",
    offset: rl.Vector2 "text",
}

GameObject :: struct {
    transform: ut.Transform(f64),
    data: union {
        Player,
        RectangleTileGrid,
    },
    children: []ut.ObjectId,
}

MAX_GAMEOBJECTS :: 10000
INIT_MEMORY_BUFFER_SIZE :: 10000000
FRAME_MEMORY_BUFFER_SIZE :: 5000

AppData :: struct {
    delta_time: f32,
    ui_context: ^clay.Context,
    viewports: [2]WorldViewport2D,
    objects: ut.ObjectPool(GameObject),
    
    frame_buffer: []u8,
    frame_allocator: mem.Arena,
    
    init_buffer: []u8,
    init_allocator: mem.Arena,
}

RectangleSprite :: struct {
    rect: ut.Bounds(f64),
    color: ut.Color,
}

Sprite :: union {
    RectangleSprite
}

//render_tile_grid_lines :: proc(tilegrid: RectangleTileGrid, screen_to_world_space) {
//}

import "core:fmt"

render_game_objects :: proc(appdata: ^AppData, viewport_index: editorui.ViewportIndex, id: ut.ObjectId=0) {
    game_object := ut.get_object(&appdata.objects, id)

    viewport_transform := get_viewport_matrix(appdata.viewports[viewport_index])

    switch object_type in game_object.data {
        case Player:
            render_sprite(appdata.viewports[viewport_index], ut.create_matrix_from_transform(game_object.transform)*viewport_transform, object_type.sprite)
        case RectangleTileGrid:
            unimplemented()
    }

    for child_id in game_object.children {
        render_game_objects(appdata, viewport_index, child_id)
    }
}

render_sprite :: proc(viewport: WorldViewport2D, transform_matrix: la.Matrix3x3f64, sprite: Sprite) {
    switch sprite_type in sprite {
    case RectangleSprite:
        transformed_bounds := ut.bounds_to_bounds(f32, ut.apply_matrix(transform_matrix, sprite_type.rect))
        rl.DrawRectangleRec(auto_cast transformed_bounds, auto_cast sprite_type.color)
    }
}

offset: f32 = 0
update :: proc(appdata: rawptr, delta_time: f32) {
    appdata: ^AppData = cast(^AppData)appdata
    appdata.delta_time = delta_time
}

render :: proc(appdata: rawptr, screen_rect: ut.Bounds(f32), id: editorui.ViewportIndex) {
    appdata: ^AppData = cast(^AppData)appdata
    appdata.viewports[id].screen_rect = ut.bounds_to_bounds(f64, screen_rect)

    render_game_objects(appdata, id)

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
    parent.children = make([]ut.ObjectId, len(objects), mem.arena_allocator(&appdata.init_allocator))

    for object, i in objects {
        id := ut.create_object(&appdata.objects, object)
        parent.children[i] = id
    }

    return parent.children
}

get_viewport_matrix :: proc(viewport: WorldViewport2D) -> la.Matrix3x3f64 {
    camera_matrix := ut.create_matrix_from_transform(viewport.camera_transform)
    view_matrix := ut.create_matrix_from_transform(ut.Transform(f64) {
        rotation_rad = 0,
        offset = {viewport.screen_rect.x+viewport.screen_rect.width/2, viewport.screen_rect.y+viewport.screen_rect.height/2},
        scale = {viewport.world_to_screenspace_scale, viewport.world_to_screenspace_scale},
    })

    return la.matrix_mul(camera_matrix, view_matrix)
}

init_game :: proc(appdata: ^AppData) {
    parent := add_game_object(appdata, 0, GameObject{
        transform = ut.TRANSFORM_IDENTITY_F64,
        data = Player {
            sprite = RectangleSprite {
                color = ut.WHITE,
                rect = ut.Bounds(f64) {
                    x = -1,
                    y = -1,
                    width = 2,
                    height = 2,
                }
            }
        }
    })
}

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
            camera_transform = ut.TRANSFORM_IDENTITY_F64,
        },
        WorldViewport2D {
            world_to_screenspace_scale = 20,
            camera_transform = ut.TRANSFORM_IDENTITY_F64,
        },
    }

    // root element
    ut.create_object(&appdata.objects, GameObject {})

    // game
    init_game(appdata)

    //appdata.tile_grid = RectangleTileGrid {
    //    width = 10,
    //    height = 10,
    //    offset = {0, 0},
    //}
}
