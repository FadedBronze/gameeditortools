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
import "core:encoding/json"
import "core:os"
import "core:strings"
import rn "project:raylibeditoruirenderer"

Direction :: enum u8 {
    Up,
    Left,
    Down,
    Right,
}

Entity :: struct {
    flags: bit_set[enum {
        Something, 
        Physics, 
        DrawHitbox, 
        PlayerControl, 
        CameraFollow,
        CameraFocus,
    }] "dropdown",
    velocity: la.Vector2f64 "text",
    physics_surface: PhysicsSurface "group",
    hitbox: ut.Bounds(f64) "group",
    transform: ut.Transform(f64) "group",
    sprite: FirstGameSheetId "dropdown",
}

EntityType :: enum {
    None,
    CollisionSquare,
}

Environment :: struct {
    flags: bit_set[enum { Exists, Blocked }] "dropdown",
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
    TileEditor,
    Entities,
    ThemeEditor,
    NewWorldBounds,
    Actions,
    LevelData,
    ProgramControl,
    EditorSet,
}

EditorPlacement :: enum {
    Right,
    Left,
    InnerRight,
    Hidden,
}

// TODO: add to editor settings once enum arrays added to widget generator
view_placements :: [Views]EditorPlacement {
    .EditorSet = .Left,
    .WorldViewports = .Left,
    .TileEditor = .Left,
    .Entities = .Left,
    .LevelData = .Left,
    .ProgramControl = .Right,
    .ThemeEditor = .Right,
    .Actions = .Right,
    .NewWorldBounds = .Right,
}

EditorSettings :: struct {
    open_views: bit_set[Views] "dropdown",

    selected_tile: Tile,
    placing_entity: Entity,
    // staging entity
    selected_entity: Entity,
    selected_entity_id: u32 "readonly text",
    flags: bit_set[enum {
        EntityPlaceSnapGrid,
    }] "dropdown",
    active_tool: enum {
        Pointer,
        CameraControl,
        GameTool,
        TileBrush,
        EntityBrush,
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
LevelAndReplayFile :: struct {
    random_seed: u32 "text",
    grid: Grid(Tile) "readonly group",
    base_entities: []Entity,
    grid_physics: PhysicsSurface "group",
    linegrid: RectangleLineGrid "group",
    computed_simplified_collision_hitboxes: []ut.Bounds(f64), // greedy meshed hitboxes
}

ConfigFiles :: struct {
    editor_settings: ^EditorSettings,
}

save_replay_data_to_disk :: proc(appdata: ^AppData, level: string, frame_allocator: mem.Allocator) -> bool {
    replay: VersionedFile(LevelAndReplayFile) = appdata.level_data
    replay.data.base_entities = appdata.entities[0:appdata.entities_count]
    data, err_marshall := cbor.marshal_into_bytes(replay, allocator=frame_allocator, temp_allocator=frame_allocator)
    if err_marshall != nil {
        fmt.println("failed to marshal data", err_marshall)
        return false
    }
    fullpath := strings.concatenate({"./leveldata/", level}, allocator=frame_allocator)
    err := os.write_entire_file(fullpath, data)
    if err != nil {
        fmt.println("failed to save level", fullpath, "to disk", err)
        return false
    }
    fmt.println("data saved successfully")
    return true
}

load_replay_data_from_disk :: proc(appdata: ^AppData, level: string, frame_allocator: mem.Allocator, init_allocator: mem.Allocator) -> bool {
    data, err := os.read_entire_file_from_path(strings.concatenate({"./leveldata/", level}, allocator=frame_allocator), frame_allocator)
    if err != nil {
        fmt.println("failed to load level", level, "from disk")
        return false
    }
    replay: VersionedFile(LevelAndReplayFile)
    err_marshall := cbor.unmarshal_from_bytes(data, &replay, allocator=init_allocator)
    if err_marshall != nil {
        fmt.println("failed to unmarshal data", err_marshall)
        return false
    }

    appdata.entities = make([]Entity, MAX_ENTITIES)
    appdata.entities_count = u32(len(replay.data.base_entities))
    copy(appdata.entities, replay.data.base_entities)

    appdata.level_data = replay

    if len(appdata.replay.grid.tiles) == 0 {
        resize_grid(&appdata.grid, ut.Bounds(i32) {
            x = -10,
            y = -10,
            width = 20,
            height = 20,
        }, init_allocator)
    }

    if appdata.linegrid.width == 0 {
        appdata.linegrid = RectangleLineGrid {
            width = 1,
            height = 1,
            transform = ut.TRANSFORM_IDENTITY_F64,
        }
    }

    appdata.new_bounds = appdata.grid.bounds

    fmt.println("data loaded successfully")
    return true
}

save_config_data_to_disk :: proc(b: VersionedFile($T), filename: string, frame_allocator: mem.Allocator) -> bool {
    data, err_marhshall := json.marshal(b, allocator=frame_allocator)
    if err_marhshall != nil {
        fmt.println("failed to marshal JSON", err_marhshall)
        return false
    }
    fullpath := strings.concatenate({"./configs/", filename, ".json"}, allocator=frame_allocator)
    err := os.write_entire_file(fullpath, data)
    if err != nil {
        fmt.println("failed to save config file", fullpath, "to disk", err)
        return false
    }
    fmt.println("saved config", filename)
    return true
}

load_config_file_from_disk :: proc(b: ^VersionedFile($T), filename: string, frame_allocator: mem.Allocator, init_allocator: mem.Allocator) -> bool {
    data, err := os.read_entire_file_from_path(strings.concatenate({"./configs/", filename, ".json"}, allocator=frame_allocator), frame_allocator)
    if err != nil {
        fmt.println("failed to load config", filename, "from disk")
        return false
    }
    err_marshall := json.unmarshal(data, b, allocator=init_allocator)
    if err_marshall != nil {
        fmt.println("failed to unmarshal JSON", err_marshall)
        return false
    }
    fmt.println("data loaded successfully")
    return true
}

Actions :: bit_set[enum {
    LoadDataFromDisk,
    RecomputeGridHitboxes,
    SaveReplayOnExit,
    SaveAllConfigsOnExit,
    OverwriteSelectedEntity,
    ResizeWorldBounds,
}]

ViewportData :: struct {
    game_viewport: u32,

    // not used for game viewport splitting just for editor vs game view for now
    viewports: [2]WorldViewport2D,
}

AppData :: struct {
    // time
    delta_time: f32,
    sim_time: f32, // seconds since simulation start marks ability activation boundraries

    control: struct {
        actions: Actions "dropdown",
        load_level: enum {
            DefaultLevel,
        } "dropdown",
    },

    // intermediate state
    camera_follow: CameraFollow,
    drag: Drag,
    ui_context: ^clay.Context,

    // if you want to increase or decrease world bounds
    new_bounds: ut.Bounds(i32) "group",

    // true state
    active_tile: GridPosition, // hovered tile essentially

    // entities loaded into here from replay because cbor will marshall the empty space aswell
    entities: []Entity,
    entities_count: u32,

    // memory
    frame_buffer: []u8,
    frame_allocator: mem.Arena,
    init_buffer: []u8,
    init_allocator: mem.Arena,

    // loaded data
    level_data: VersionedFile(LevelAndReplayFile),
    editor_config_data: VersionedFile(EditorSettings),
    // should be moved perhaps idek how to architect this thing
    theme_config_data: VersionedFile(editorui.EditorUITheme),
    viewport_config_data: VersionedFile(ViewportData),

    // references to loaded data
    editor_settings: ^EditorSettings,
    using replay: ^LevelAndReplayFile,
    using viewport_data: ^ViewportData,

    // assets
    sprite_sheet: SpriteSheet(FirstGameSheetId),

    // editorui
    editor_ui: editorui.EditorUI,
}

// TODO will have to redo the greedy mesher to support varying properties on different tiles
// OR apply different properties to different tiles sharing the same body (which I am leaning towards)
PhysicsSurface :: struct {
    restitution: f64 "text",
    friction: f64 "text",
}

update :: proc(appdata: ^AppData, delta_time: f32) {
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
            
            if .PlayerControl in entity.flags {
                if rl.IsKeyDown(.D) {
                    entity.velocity.x = 0.005
                }
                if rl.IsKeyDown(.A) {
                    entity.velocity.x = -0.005
                }
                if rl.IsKeyPressed(.W) {
                    entity.velocity.y = -0.01
                }
            }

            entity.transform.offset += entity.velocity
        }
    }
    
    if .LoadDataFromDisk in appdata.control.actions {
        load_replay_data_from_disk(appdata, "default", mem.arena_allocator(&appdata.frame_allocator), mem.arena_allocator(&appdata.init_allocator))

        if appdata.level_data.version != LEVEL_REPLAY_FILE_VERSION {
            fmt.println("WARNING: level data version mismatch")
        }

        appdata.control.actions -= {.LoadDataFromDisk}
        appdata.control.actions += {.RecomputeGridHitboxes}
    }

    if .RecomputeGridHitboxes in appdata.control.actions {
        worldspace_bounds := greedy_mesh_grid_into_worldspace_aabb_bounds_list(appdata.grid, appdata.linegrid)
        appdata.computed_simplified_collision_hitboxes = worldspace_bounds;

        appdata.control.actions -= {.RecomputeGridHitboxes}
    }

    if .OverwriteSelectedEntity in appdata.control.actions {
        appdata.entities[appdata.editor_settings.selected_entity_id-1] = appdata.editor_settings.selected_entity
        appdata.control.actions -= { .OverwriteSelectedEntity }
    }

    if .ResizeWorldBounds in appdata.control.actions {
        resize_grid(&appdata.grid, appdata.new_bounds, mem.arena_allocator(&appdata.init_allocator))
        appdata.control.actions -= { .ResizeWorldBounds }
    }

    appdata.viewports[appdata.game_viewport].camera_position = follow_player(&appdata.camera_follow, appdata, delta_time)

    mem.arena_free_all(&appdata.frame_allocator)
}

find_closest_entity_within_distance :: proc(appdata: ^AppData, world_position: la.Vector2f64, distance: f64) -> (u32, ^Entity) {
    smallest_distance: f64 = distance
    closest_entity: ^Entity = nil
    closest_id: u32 = 0

    for i in 0..<appdata.entities_count {
        entity := &appdata.entities[i]

        if .Something in entity.flags {
            d := la.length(entity.transform.offset - world_position)
            if d < smallest_distance {
                smallest_distance = d
                closest_entity = entity
                closest_id = i+1
            }
        }
    }

    return closest_id, closest_entity
}

place_entity :: proc(appdata: ^AppData, viewport_id: editorui.ViewportIndex, allocator: mem.Allocator) {
    viewport := &appdata.viewports[viewport_id]
    tile_grid := &appdata.linegrid
    
    mouse_pos := rl.GetMousePosition()
    // TODO: needs to be replaced with pointer over from editor since ui may need to go over
    within := ut.position_within_bounds(la.Vector2f64{f64(mouse_pos.x), f64(mouse_pos.y)}, viewport.screen_rect)
    world_mouse_pos := screen_to_world_space(viewport^, auto_cast mouse_pos)
    
    // snapping stuff thinggy
    tilegrid_position := world_to_tile_pos(world_mouse_pos, appdata.linegrid)

    if rl.IsMouseButtonPressed(.LEFT) && within {
        if rl.IsKeyDown(.LEFT_SHIFT) {
            id, entity := find_closest_entity_within_distance(appdata, world_mouse_pos, 0.5)

            if entity != nil {
                appdata.editor_settings.selected_entity = entity^
                appdata.editor_settings.selected_entity_id = id

                fmt.println("found")
                fmt.println(entity)
            }
        } else {
            en := create_entity(appdata, appdata.editor_settings.placing_entity)
            en.transform.offset = world_mouse_pos
        }
    }
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


    if .RenderGrid in viewport.flags {
        render_tile_grid_lines(viewport^, appdata.linegrid)
    }

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

            if .HighlightSelectedEntity in viewport.flags && i+1 == appdata.editor_settings.selected_entity_id {
                rl.DrawRectangleLinesEx(
                    transmute(rl.Rectangle)ut.bounds_to_bounds(f32, world_hitbox), 
                    1.0,
                    auto_cast ut.BLUE
                )
            } else {
                rl.DrawRectangleLinesEx(
                    transmute(rl.Rectangle)ut.bounds_to_bounds(f32, world_hitbox), 
                    1.0,
                    auto_cast ut.RED
                )
            }
        }
    }

    // hitboxes
    if .RenderHitboxes in viewport.flags {
        for i in 0..<len(appdata.computed_simplified_collision_hitboxes) {
            box := appdata.computed_simplified_collision_hitboxes[i]
            box = ut.apply_matrix_to_bounds(viewport_mat, box)

            rl.DrawRectangleLinesEx(
                transmute(rl.Rectangle)ut.bounds_to_bounds(f32, box), 
                1.0,
                auto_cast ut.RED
            )
        }
    }

    if .ShowGridOuterBounds in viewport.flags {
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
    case .Pointer:
        drag_camera(appdata, id)
        zoom_camera(appdata, id)
        
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
    case .EntityBrush:
        if rl.IsKeyDown(.LEFT_CONTROL) {
            drag_camera(appdata, id)
        } else {
            place_entity(appdata, id, mem.arena_allocator(&appdata.init_allocator))
        }
        
        zoom_camera(appdata, id)
    case .GameTool:
    }

    clay.SetCurrentContext(appdata.ui_context)
    clay.BeginLayout()
    elements := clay.EndLayout(appdata.delta_time)
    clay_basic_renderer(elements)
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

create_entity :: proc(appdata: ^AppData, entity: Entity) -> ^Entity {
    fmt.println(appdata.entities_count)
    appdata.entities[appdata.entities_count] = entity
    appdata.entities_count += 1
    return &appdata.entities[appdata.entities_count-1]
}

base_theme := editorui.EditorUITheme {
    font_size = 16,
    letter_spacing = 1,
    text_color = ut.Color {192, 192, 192, 240},
    background_color = ut.BLACK,
    highlight_color = ut.Color {255, 0, 0, 255}
}

entity_stub := Entity {}

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
    
    // ===== game initialization =====
    appdata.sprite_sheet = create_first_game_sheet()

    //spawn_land_borders(appdata)
    
    // hitboxes
    appdata.control.actions += { .LoadDataFromDisk }

    // ===== editor ui
    load_config_file_from_disk(
        &appdata.theme_config_data, 
        "theme_settings", 
        mem.arena_allocator(&appdata.frame_allocator), 
        mem.arena_allocator(&appdata.init_allocator)
    )

    appdata.editor_ui = editorui.create_editorui(&appdata.theme_config_data.data, context.allocator)
    
    if appdata.editor_config_data.version != EDITOR_SETTINGS_VERSION {
        fmt.eprintln("Editor settings version mismatch")
    }
    
    load_config_file_from_disk(
        &appdata.editor_config_data, 
        "editor_settings", 
        mem.arena_allocator(&appdata.frame_allocator), 
        mem.arena_allocator(&appdata.init_allocator)
    )
    
    load_config_file_from_disk(
        &appdata.viewport_config_data, 
        "viewport_settings", 
        mem.arena_allocator(&appdata.frame_allocator), 
        mem.arena_allocator(&appdata.init_allocator)
    )

    appdata.editor_settings.selected_entity = entity_stub
    
    rn.init_font_table(&rn.font_table, context.allocator)
}

ConfigFileNames :: enum {
    EditorSettings,
    ThemeSettings,
}

config_file_paths: [ConfigFileNames]string = {
    .EditorSettings = "./configs/editor_settings.config.odin",
    .ThemeSettings = "./configs/theme_settings.config.odin"
}

VersionedFile :: struct(T: typeid) {
    version: u32 "text",
    data: T "group",
}

LEVEL_REPLAY_FILE_VERSION :: 2
EDITOR_SETTINGS_VERSION :: 1
THEME_SETTINGS_VERSION :: 0
VIEWPORT_SETTINGS_VERSION :: 0

exit_app :: proc(appdata: ^AppData) { 
    if .SaveReplayOnExit in appdata.control.actions {
        level_data: VersionedFile(LevelAndReplayFile) = {
            data = appdata.replay^,
            version = LEVEL_REPLAY_FILE_VERSION,
        }

        //if appdata.level_data.version == LEVEL_REPLAY_FILE_VERSION {
        save_replay_data_to_disk(appdata, "default", mem.arena_allocator(&appdata.frame_allocator))
        //} else {
        //    fmt.eprintln("WARNING: write updates file version")
        //}
    }    

    if .SaveAllConfigsOnExit in appdata.control.actions {
        //if appdata.theme_config_data.version == THEME_SETTINGS_VERSION {
            save_config_data_to_disk(
                appdata.theme_config_data, 
                "theme_settings", 
                mem.arena_allocator(&appdata.frame_allocator), 
            )
        //} else {
        //    fmt.eprintln("WARNING: write updates file version")
        //}

        //if appdata.editor_config_data.version == EDITOR_SETTINGS_VERSION {
            save_config_data_to_disk(
                appdata.editor_config_data, 
                "editor_settings", 
                mem.arena_allocator(&appdata.frame_allocator), 
            ) 
        //} else {
        //    fmt.eprintln("WARNING: write updates file version")
        //}

        save_config_data_to_disk(
            appdata.viewport_config_data, 
            "viewport_settings", 
            mem.arena_allocator(&appdata.frame_allocator), 
        ) 
    }
}
