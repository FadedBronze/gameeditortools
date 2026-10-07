package main

import "project:editorui"
import ut "utils"
import clay "clay-odin"
import rl "vendor:raylib"
import la "core:math/linalg"
import "core:math/rand"
import "core:fmt"

import "core:mem"

Direction :: enum u8 {
    Up,
    Left,
    Down,
    Right,
}

Entity :: struct {
    flags: bit_set[enum {Something, Physics, DrawHitbox}] "dropdown",
    velocity: la.Vector2f64,

    hitbox: ut.Bounds(f64),
    transform: ut.Transform(f64),
    sprite: FirstGameSheetId "dropdown",
}

Environment :: struct {
    flags: bit_set[enum { Exists, Blocked }],
    sprite: FirstGameSheetId "dropdown",
}

EntityId :: distinct u32

Tile :: struct {
    environment: Environment "group",
}

MAX_ENTITIES :: 10000
INIT_MEMORY_BUFFER_SIZE :: 10000000
FRAME_MEMORY_BUFFER_SIZE :: 50000

ViewportDrag :: struct {
    active: editorui.ViewportIndex,
    mouse_start: la.Vector2f32,
    camera_start: la.Vector2f64,
    camera_inverse_transform_matrix: la.Matrix3f64,
}

Views :: enum {
    WorldViewports,    
    Player,
    State,
    TileEditor,
    Entities,
}

EditorSettings :: struct {
    open_views: bit_set[Views] "dropdown",
    selected_tile: Tile,
    active_tool: enum {
        CameraControl,
        GameTool,
        TileBrush
    } "dropdown",
}

GameState :: enum {
    Planning,
    PlayingAttack,
}

Signals :: enum {
    Wait,
    GoUp,
    GoDown,
    GoLeft,
    GoRight,
}

Player :: struct {
    signals: Signals "dropdown",
}

EmptyDrag :: struct {}

Drag :: union {
    EmptyDrag,
    ViewportDrag,
}

AppData :: struct {
    delta_time: f32,
    sim_time: f32, // seconds since simulation start marks ability activation boundraries

    ui_context: ^clay.Context,
    frame_buffer: []u8,
    frame_allocator: mem.Arena,
    init_buffer: []u8,
    init_allocator: mem.Arena,

    editor_settings: EditorSettings,

    sprite_sheet: SpriteSheet(FirstGameSheetId),

    viewports: [2]WorldViewport2D,
    linegrid: RectangleLineGrid,

    grid: Grid(Tile),

    // greedy meshed hitboxes
    computed_simplified_collision_hitboxes: []ut.Bounds(f64),

    entities: []Entity,
    entities_count: u32, // zero corresponds to null

    player: Player,

    drag: Drag,

    // hovered tile essentially
    active_tile: GridPosition,
    state: GameState,
}

update :: proc(appdata: rawptr, delta_time: f32) {
    appdata: ^AppData = cast(^AppData)appdata
    appdata.delta_time = delta_time
 
    update_tiles(appdata, delta_time)
    update_entities(appdata, delta_time)

    mem.arena_free_all(&appdata.frame_allocator)
}

place_tile :: proc(appdata: ^AppData, viewport_id: editorui.ViewportIndex, allocator: mem.Allocator) {
    viewport := &appdata.viewports[viewport_id]
    tile_grid := &appdata.linegrid

    mouse_pos := rl.GetMousePosition()
    // TODO: needs to be replaced with pointer over from editor since ui may need to go over
    within := ut.position_within_bounds(la.Vector2f64{f64(mouse_pos.x), f64(mouse_pos.y)}, viewport.screen_rect)
    world_mouse_pos := screen_to_world_space(viewport^, auto_cast mouse_pos)

    tilegrid_position := world_to_tile_pos(world_mouse_pos, appdata.linegrid)

    if rl.IsMouseButtonPressed(.LEFT) && within {
        if rl.IsKeyDown(.LEFT_SHIFT) {
            fmt.println(get_tile(appdata.grid, tilegrid_position), tilegrid_position)
        } else {
            appdata.active_tile = tilegrid_position
            create_tile(appdata, tilegrid_position)
        }
    }
}

render_tile :: proc(appdata: ^AppData, pos: GridPosition, render_pos: la.Vector2f64, mat: la.Matrix3f64) {
    tile := get_tile(appdata.grid, pos)

    if .Exists in tile.environment.flags {
        id: FirstGameSheetId = tile.environment.sprite
        
        viewport_bounds := ut.apply_matrix_to_bounds(mat, ut.Bounds(f64) {
            x = render_pos.x,
            y = render_pos.y,
            width = 1,
            height = 1,
        })

        draw_sprite(id, appdata.sprite_sheet, ut.bounds_to_bounds(f32, viewport_bounds))
    }
}

update_tile :: proc(appdata: ^AppData, position: GridPosition, dt: f32) {
    //TODO
}

update_tiles :: proc(appdata: ^AppData, dt: f32) {
    b := appdata.grid.bounds

    for y in b.y..<b.height+b.y {
        for x in b.x..<b.width+b.x {
            update_tile(appdata, {x, y}, dt)
        }
    }
}

render_tiles :: proc(appdata: ^AppData, viewport: WorldViewport2D, linegrid: RectangleLineGrid, grid: Grid($T)) {
    mat := ut.create_matrix_from_transform(linegrid.transform) * get_viewport_matrix(viewport)
    b := grid.bounds

    for y in b.y..<b.height+b.y {
        for x in b.x..<b.width+b.x {
            tile := get_tile(grid, {x, y})
            render_tile(appdata, {x, y}, {f64(x), f64(y)}, mat)
        }
    }
}

render :: proc(appdata: rawptr, screen_rect: ut.Bounds(f32), id: editorui.ViewportIndex) {
    appdata: ^AppData = cast(^AppData)appdata
    viewport := &appdata.viewports[id]
    viewport.screen_rect = ut.bounds_to_bounds(f64, screen_rect)

    rl.DrawRectangleRec(transmute(rl.Rectangle)screen_rect, rl.WHITE)

    render_tile_grid_lines(viewport^, appdata.linegrid)
    render_tiles(appdata, viewport^, appdata.linegrid, appdata.grid)

    render_entities(appdata, viewport^)

    switch appdata.editor_settings.active_tool {
    case .CameraControl:
        drag_camera(appdata, id)
        zoom_camera(appdata, id)
    case .TileBrush:
        if rl.IsKeyDown(.LEFT_CONTROL) {
            drag_camera(appdata, id)
        } else {
            place_tile(appdata, id, mem.arena_allocator(&appdata.init_allocator))
        }
        zoom_camera(appdata, id)
    case .GameTool:
    }

    clay.SetCurrentContext(appdata.ui_context)
    clay.BeginLayout()
    elements := clay.EndLayout(appdata.delta_time)
    clay_renderer(elements)
}

render_entities :: proc(appdata: ^AppData, viewport: WorldViewport2D) {
    mat := get_viewport_matrix(viewport)

    for i in 0..<appdata.entities_count {
        entity: ^Entity = &appdata.entities[i]

        if .DrawHitbox in entity.flags {
            world_hitbox := ut.apply_matrix_to_bounds(
                mat * ut.create_matrix_from_transform(entity.transform),
                entity.hitbox
            )

            rl.DrawRectangleLinesEx(
                transmute(rl.Rectangle)ut.bounds_to_bounds(f32, world_hitbox), 
                1.0,
                auto_cast ut.RED
            )
        }
    }
}

update_entities :: proc(appdata: ^AppData, delta_time: f32) {
    for i in 0..<appdata.entities_count {
        //entity := &appdata.entities[i]

        //if .Physics in entity.flags {
        //    entity.velocity.y += 0.00000981
        //    entity.velocity.y = max(abs(entity.velocity.y), 0.01)*math.sign(entity.velocity.y)
        //    entity.transform.offset += entity.velocity

        //    normal, depth, collide := check_collision_aabb_tilegrid(entity, appdata.grid, appdata.linegrid)

        //    if collide {
        //        entity.transform.offset -= normal * depth
        //        entity.velocity = {0, 0}
        //    }
        //}
    }
}

spawn_random_land :: proc(appdata: ^AppData) {
    frame_allocator := mem.arena_allocator(&appdata.frame_allocator)
    land := make([]bool, len(appdata.grid.tiles))
    for i in 0..<len(appdata.grid.tiles)/30 {
        land[i] = true
    }
    rand.shuffle(land)
    
    for i in 0..<len(appdata.grid.tiles) {
        if land[i] {
            appdata.grid.tiles[i].environment = Environment {
                sprite = .ChoosePlus,
                flags = { .Exists, .Blocked }
            }
        }
    }
}

spawn_land_borders :: proc(appdata: ^AppData) {
    frame_allocator := mem.arena_allocator(&appdata.frame_allocator)
    
    block := Tile {
        environment = Environment {
            flags = { .Blocked, .Exists },
            sprite = .ChoosePlus
        }
    }

    for x in 1..<appdata.grid.bounds.width-1 {
        set_tile_base(&appdata.grid, {x + appdata.grid.bounds.x, appdata.grid.bounds.y}, block)
        set_tile_base(&appdata.grid, {x + appdata.grid.bounds.x, appdata.grid.bounds.y+appdata.grid.bounds.height-1}, block)
    }
    for y in 0..<appdata.grid.bounds.height {
        set_tile_base(&appdata.grid, {appdata.grid.bounds.x, appdata.grid.bounds.y + y}, block)
        set_tile_base(&appdata.grid, {appdata.grid.bounds.x+appdata.grid.bounds.width-1, appdata.grid.bounds.y + y}, block)
    }
}

create_entity :: proc(appdata: ^AppData, entity: Entity) {
    appdata.entities[appdata.entities_count] = entity
    appdata.entities_count += 1
}

init_game :: proc(appdata: ^AppData) {
    appdata.linegrid = RectangleLineGrid {
        width = 1,
        height = 1,
        transform = ut.TRANSFORM_IDENTITY_F64,
    }

    appdata.sprite_sheet = create_first_game_sheet()

    appdata.player = Player {
        signals = .Wait,
    }

    resize_grid(&appdata.grid, ut.Bounds(i32){
        x = -8,
        y = -20,
        width = 16,
        height = 80,
    }, mem.arena_allocator(&appdata.init_allocator))

    //spawn_random_land(appdata)
    spawn_land_borders(appdata)

    create_entity(appdata, Entity {
        flags = { .Physics, .DrawHitbox },
        sprite = .PlayerHappy,
        hitbox = ut.centered_bounds_from_lh(f64(1.3), 1.3),
        transform = {
            offset = {0, 0},
            scale = {1, 1}
        }
    })
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
    
    appdata.entities = make([]Entity, MAX_ENTITIES)
    appdata.entities_count = 0
    
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

    appdata.editor_settings.open_views += { .State }

    // game
    init_game(appdata)
}
