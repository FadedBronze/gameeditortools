package main

import "project:editorui"
import ut "project:utils"
import clay "project:clay-odin"
import rl "vendor:raylib"
import la "core:math/linalg"
import "core:math/rand"
import "core:fmt"
import "core:mem"
import "core:encoding/cbor"
import "core:os"
import "core:strings"

Direction :: enum u8 {
    Up,
    Left,
    Down,
    Right,
}

Entity :: struct {
    flags: bit_set[enum {Something, Physics, DrawHitbox}] "dropdown",
    velocity: la.Vector2f64,

    physics_surface: PhysicsSurface,
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
FRAME_MEMORY_BUFFER_SIZE :: 5000000

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
    flags: bit_set[enum {
        ShowGridOuterBounds
    }] "dropdown",
    active_tool: enum {
        CameraControl,
        GameTool,
        TileBrush
    } "dropdown",
}

Signals :: enum {
    Wait,
    GoUp,
    GoDown,
    GoLeft,
    GoRight,
}

EmptyDrag :: struct {}

Drag :: union {
    EmptyDrag,
    ViewportDrag,
}

// loaded at start but is modified at runtime -- currently not loaded though
BinaryLoadedData :: struct {
    grid: Grid(Tile),
}

ConfigLoadedData :: struct {
    editor_settings: EditorSettings,
    linegrid: RectangleLineGrid,
}

save_binary_data_to_disk :: proc(b: BinaryLoadedData, level: string, frame_allocator: mem.Allocator) -> bool {
    data, err_marshall := cbor.marshal_into_bytes(b, allocator=frame_allocator, temp_allocator=frame_allocator)
    if err_marshall != nil {
        fmt.println("failed to marshal data", err_marshall)
        return false
    }
    err := os.write_entire_file(strings.concatenate({"./leveldata/", level}, allocator=frame_allocator), data)
    if err != nil {
        fmt.println("failed to save level", level, "to disk")
        return false
    }
    fmt.println("data saved successfully")
    return true
}

load_binary_data_from_disk :: proc(b: ^BinaryLoadedData, level: string, init_allocator: mem.Allocator) -> bool {
    data, err := os.read_entire_file_from_path(strings.concatenate({"./leveldata/", level}), init_allocator)
    if err != nil {
        fmt.println("failed to load level", level, "from disk")
        return false
    }
    err_marshall := cbor.unmarshal_from_bytes(data, b)
    if err_marshall != nil {
        fmt.println("failed to unmarshal data", err_marshall)
        return false
    }
    fmt.println("data loaded successfully")
    return true
}

Actions :: bit_set[enum {
    LoadDataFromDisk,
    RecomputeGridHitboxes,
}]

AppData :: struct {
    // time
    delta_time: f32,
    sim_time: f32, // seconds since simulation start marks ability activation boundraries

    control: struct {
        actions: Actions "dropdown",
        load_level: enum {
            Level1,
        } "dropdown",
    },

    // intermediate state
    drag: Drag,
    ui_context: ^clay.Context,
    computed_simplified_collision_hitboxes: []ut.Bounds(f64), // greedy meshed hitboxes

    // true state
    active_tile: GridPosition, // hovered tile essentially

    viewports: [2]WorldViewport2D,
    grid_physics: PhysicsSurface,
    entities: []Entity,
    entities_count: u32, // zero corresponds to null

    // memory
    frame_buffer: []u8,
    frame_allocator: mem.Arena,
    init_buffer: []u8,
    init_allocator: mem.Arena,

    // loaded data
    using config_loaded: ConfigLoadedData,
    using binary_loaded: BinaryLoadedData,

    // assets
    sprite_sheet: SpriteSheet(FirstGameSheetId),
}

// TODO will have to redo the greedy mesher to support varying properties on different tiles
// OR apply different properties to different tiles sharing the same body (which I am leaning towards)
PhysicsSurface :: struct {
    restitution: f64,
    friction: f64,
}

update :: proc(appdata: rawptr, delta_time: f32) {
    appdata: ^AppData = cast(^AppData)appdata
    appdata.delta_time = delta_time
 
    b := appdata.grid.bounds

    for y in b.y..<b.height+b.y {
        for x in b.x..<b.width+b.x {
            //TODO
        }
    }

    for i in 0..<appdata.entities_count {
        entity := &appdata.entities[i]

        if .Physics in entity.flags {
            grid_mat := ut.create_matrix_from_transform(appdata.linegrid.transform)

            entity.velocity += grid_to_world_position({0.0, 0.00981}, appdata.linegrid) * f64(delta_time)
            
            box := ut.apply_matrix_to_bounds(ut.create_matrix_from_transform(entity.transform), entity.hitbox)

            for j in i+1..<appdata.entities_count {
                entity2 := &appdata.entities[j]
                box2 := ut.apply_matrix_to_bounds(ut.create_matrix_from_transform(entity2.transform), entity2.hitbox)

                hit, normal, depth := collide_aabb(box, box2)

                if hit {
                    entity.transform.offset -= normal * depth/2
                    entity2.transform.offset += normal * depth/2

                    delta_v := entity.velocity-entity2.velocity
                    vel_mag := la.length(delta_v)
                    vel_normal := la.normalize(delta_v)
                    surface_normal := normal
                    surface := la.vector2_orthogonal(surface_normal)

                    f := entity.physics_surface.friction*entity2.physics_surface.friction
                    e := entity2.physics_surface.restitution * entity.physics_surface.restitution
                    
                    friction := (la.dot(surface, vel_normal) * vel_mag * f) * surface

                    entity.velocity -= (la.dot(surface_normal, vel_normal) * vel_mag * (e + 1)) * surface_normal
                    entity.velocity -= friction
                    
                    entity2.velocity += (la.dot(surface_normal, vel_normal) * vel_mag * (e + 1)) * surface_normal
                    entity2.velocity += friction
                }
            }

            for bound, i in appdata.computed_simplified_collision_hitboxes {
                hit, normal, depth := collide_aabb(box, bound)

                if hit {
                    entity.transform.offset -= normal * depth

                    vel_mag := la.length(entity.velocity)
                    vel_normal := la.normalize(entity.velocity)
                    surface_normal := normal
                    surface := la.vector2_orthogonal(surface_normal)

                    entity.velocity -= (la.dot(surface_normal, vel_normal) * vel_mag * (appdata.grid_physics.restitution * entity.physics_surface.restitution + 1)) * surface_normal
                    friction := (la.dot(surface, vel_normal) * vel_mag * (appdata.grid_physics.friction * entity.physics_surface.friction)) * surface
                    entity.velocity -= friction
                }
            }
            
            if rl.IsKeyDown(.D) {
                entity.velocity.x = 0.005
            }
            if rl.IsKeyDown(.A) {
                entity.velocity.x = -0.005
            }
            if rl.IsKeyPressed(.W) {
                entity.velocity.y = -0.01
            }

            entity.transform.offset += entity.velocity
        }
    }
    
    if .LoadDataFromDisk in appdata.control.actions {
        load_binary_data_from_disk(&appdata.binary_loaded, "1", mem.arena_allocator(&appdata.init_allocator))

        appdata.control.actions -= {.LoadDataFromDisk}
        appdata.control.actions += {.RecomputeGridHitboxes}
    }

    if .RecomputeGridHitboxes in appdata.control.actions {
        worldspace_bounds := greedy_mesh_grid_into_worldspace_aabb_bounds_list(appdata.grid, appdata.linegrid)
        appdata.computed_simplified_collision_hitboxes = worldspace_bounds;

        appdata.control.actions -= {.RecomputeGridHitboxes}
    }

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

grid_to_world_position :: proc(position: la.Vector2f64, linegrid: RectangleLineGrid) -> la.Vector2f64 {
    mat := ut.create_matrix_from_transform(linegrid.transform)
    return ut.apply_matrix_to_point(mat, la.Vector2f64{position.x*linegrid.width, position.y*linegrid.height})
}

grid_bounds_to_worldspace_bounds :: proc(bound: ut.Bounds(f64), linegrid: RectangleLineGrid) -> (worldspace_bounds: ut.Bounds(f64)) {
    cellsize_scaled_cell_bound := ut.Bounds(f64) {
        bound.x*linegrid.width, 
        bound.y*linegrid.height, 
        bound.width*linegrid.width, 
        bound.height*linegrid.height
    }

    mat := ut.create_matrix_from_transform(linegrid.transform)
    return ut.apply_matrix_to_bounds(mat, cellsize_scaled_cell_bound)
}

render :: proc(appdata: rawptr, screen_rect: ut.Bounds(f32), id: editorui.ViewportIndex) {
    appdata: ^AppData = cast(^AppData)appdata
    viewport := &appdata.viewports[id]
    viewport.screen_rect = ut.bounds_to_bounds(f64, screen_rect)

    rl.DrawRectangleRec(transmute(rl.Rectangle)screen_rect, rl.WHITE)

    render_tile_grid_lines(viewport^, appdata.linegrid)

    // render tiles
    mat := ut.create_matrix_from_transform(appdata.linegrid.transform) * get_viewport_matrix(viewport^)
    b := appdata.grid.bounds

    for y in b.y..<b.height+b.y {
        for x in b.x..<b.width+b.x {
            tile := get_tile(appdata.grid, {x, y})

            if .Exists in tile.environment.flags {
                id: FirstGameSheetId = tile.environment.sprite
                
                viewport_bounds := ut.apply_matrix_to_bounds(mat, ut.Bounds(f64) {
                    x = f64(x),
                    y = f64(y),
                    width = 1,
                    height = 1,
                })

                draw_sprite(id, appdata.sprite_sheet, ut.bounds_to_bounds(f32, viewport_bounds))
            }
        }
    }

    // entities
    viewport_mat := get_viewport_matrix(viewport^)
    for i in 0..<appdata.entities_count {
        entity: ^Entity = &appdata.entities[i]

        if .DrawHitbox in entity.flags {
            world_hitbox := ut.apply_matrix_to_bounds(
                viewport_mat * ut.create_matrix_from_transform(entity.transform),
                entity.hitbox
            )

            rl.DrawRectangleLinesEx(
                transmute(rl.Rectangle)ut.bounds_to_bounds(f32, world_hitbox), 
                1.0,
                auto_cast ut.RED
            )
        }
    }

    // hitboxes
    for i in 0..<len(appdata.computed_simplified_collision_hitboxes) {
        box := appdata.computed_simplified_collision_hitboxes[i]
        box = ut.apply_matrix_to_bounds(viewport_mat, box)

        rl.DrawRectangleLinesEx(
            transmute(rl.Rectangle)ut.bounds_to_bounds(f32, box), 
            1.0,
            auto_cast ut.RED
        )
    }

    if .ShowGridOuterBounds in appdata.editor_settings.flags {
        box := ut.bounds_to_bounds(f64, appdata.grid.bounds)
        box = grid_bounds_to_worldspace_bounds(box, appdata.linegrid)
        box = ut.apply_matrix_to_bounds(viewport_mat, box)
        
        rl.DrawRectangleLinesEx(
            transmute(rl.Rectangle)ut.bounds_to_bounds(f32, box), 
            1.0,
            auto_cast ut.ORANGE,
        )
    }

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

init_app :: proc(appdata: ^AppData, allocator: mem.Allocator) {
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

    // ===== game initialization =====
    appdata.linegrid = RectangleLineGrid {
        width = 1,
        height = 1,
        transform = ut.TRANSFORM_IDENTITY_F64,
    }

    appdata.grid_physics = PhysicsSurface {
        friction = 0.6,
        restitution = 0.3,
    }

    appdata.sprite_sheet = create_first_game_sheet()

    resize_grid(&appdata.grid, ut.Bounds(i32){
        x = -8,
        y = -20,
        width = 16,
        height = 80,
    }, mem.arena_allocator(&appdata.init_allocator))

    //spawn_land_borders(appdata)
    
    // hitboxes
    appdata.control.actions += { .LoadDataFromDisk }

    for i in 0..<4 {
        create_entity(appdata, Entity {
            physics_surface = PhysicsSurface {
                friction = 0.6,
                restitution = 0.3,
            },
            flags = { .Physics, .DrawHitbox },
            sprite = .PlayerHappy,
            hitbox = ut.centered_bounds_from_lh(f64(1.3), 1.3),
            transform = {
                offset = {f64(2*i-5), 0},
                scale = {1, 1}
            }
        })
    }

    // ===== 
}

exit_app :: proc(appdata: ^AppData) {
    save_binary_data_to_disk(appdata.binary_loaded, "1", mem.arena_allocator(&appdata.frame_allocator))
}
