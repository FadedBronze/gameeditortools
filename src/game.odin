package main

import "core:math/rand"
import "core:fmt"
import "core:mem"
import la "core:math/linalg"

import "project:editorui"
import ut "project:utils"
import clay "project:clay-odin"
import rn "project:raylibeditoruirenderer"

import rl "vendor:raylib"

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
        CameraRoom,
    }] "dropdown",
    grid_area: ut.Bounds(i32) "group",
    velocity: la.Vector2f64 "text",
    physics_surface: PhysicsSurface "group",
    hitbox: ut.Bounds(f64) "group",
    transform: ut.Transform(f64) "group",
    sprite: FirstGameSheetId "dropdown",
    mass: f64 "text",
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
    Replays,
    PerformanceInfo,
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
    .PerformanceInfo = .Left,
    .WorldViewports = .Left,
    .TileEditor = .Left,
    .Entities = .Left,
    .LevelData = .Left,
    .Replays = .Left,
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

EmptyDrag :: struct {}

Drag :: union {
    EmptyDrag,
    ViewportDrag,
}

Signals :: enum {
    Wait,
    GoUp,
    GoDown,
    GoLeft,
    GoRight,
}

GameActionTrigger :: enum { Pressed, Held, Released }

GameAction :: struct {
    type: GameActionNames,
    trigger: GameActionTrigger,
}

// Things bound to keys in game 
GameActionNames :: enum {
    GoLeft,
    GoRight,
    Jump,
    RushDown,
}

Actions :: bit_set[enum {
    LoadDataFromDisk,
    RecomputeGridHitboxes,
    SaveLevelOnExit,
    SaveAllConfigsOnExit,
    OverwriteSelectedEntity,
    ResizeWorldBounds,
    DeleteSelectedEntityID,
}]

ViewportData :: struct {
    game_viewport: editorui.ViewportIndex "readonly text",
    fullscreen_viewport_id: editorui.ViewportIndex "readonly text",

    // not used for game viewport splitting just for editor vs game view for now
    viewports: [2]WorldViewport2D,
}

ReplayState :: enum { 
    NotRecordingReplay, 
    ReloadLevelToStartReplay, 
    RecordingReplay,
    SaveReplayToDisk,
    ReloadLevelToPlaybackReplayFromDisk,
    PlayingBack,
}

AppData :: struct {
    input_actions_this_frame: [8]GameAction,
    input_actions_count: u8,
    // used when playing back actions
    replay_playback_action_index: u32,

    pref_stats: struct {
        fps: f32 "readonly text",
        memory_used_bytes: u32 "readonly text",
    },

    // time
    delta_time: f32,
    frame_number: u32,

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
    computed_simplified_collision_hitboxes: []ut.Bounds(f64), // greedy meshed hitboxes

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
    frame_mem_alloc: mem.Allocator,

    init_buffer: []u8,
    init_allocator: mem.Arena,
    init_mem_alloc: mem.Allocator,

    // loaded data
    level_data: VersionedFile(LevelFile),
    editor_config_data: VersionedFile(EditorSettings),
    // should be moved perhaps idek how to architect this thing
    theme_config_data: VersionedFile(editorui.EditorUITheme),
    viewport_config_data: VersionedFile(ViewportData),

    // references to loaded data
    editor_settings: ^EditorSettings,
    using level: ^LevelFile,
    using viewport_data: ^ViewportData,

    // assets
    sprite_sheet: SpriteSheet(FirstGameSheetId),

    // editorui
    editor_ui: editorui.EditorUI,

    replay_files_associated_with_level: []string,
    selected_replay_file: u8,

    // recording inputs
    replay_state: ReplayState,
    loaded_replay: InputReplayFile,
}

// TODO will have to redo the greedy mesher to support varying properties on different tiles
// OR apply different properties to different tiles sharing the same body (which I am leaning towards)
PhysicsSurface :: struct {
    restitution: f64 "text",
    friction: f64 "text",
}

_general_action :: proc(appdata: ^AppData, action_name: GameActionNames, trigger: GameActionTrigger) -> bool {
    for action in appdata.input_actions_this_frame[0:appdata.input_actions_count] {
        if action.type == action_name && trigger == action.trigger {
            return true
        }
    }
    return false
}

held_action :: proc(appdata: ^AppData, action_name: GameActionNames) -> bool {
    return _general_action(appdata, action_name, .Held)
}

pressed_action :: proc(appdata: ^AppData, action_name: GameActionNames) -> bool {
    return _general_action(appdata, action_name, .Pressed)
}

released_action :: proc(appdata: ^AppData, action_name: GameActionNames) -> bool {
    return _general_action(appdata, action_name, .Released)
}

update_input_actions :: proc(appdata: ^AppData) {
    appdata.input_actions_count = 0

    action_binding := [GameActionNames]rl.KeyboardKey {
         .GoRight = .D,
         .GoLeft = .A,
         .Jump = .W,
         .RushDown = .S,
    }

    for binding, action in action_binding {
        if rl.IsKeyPressed(binding) {
            appdata.input_actions_this_frame[appdata.input_actions_count] = GameAction {
                trigger = .Pressed,
                type = action,
            }
            appdata.input_actions_count += 1
        } else if rl.IsKeyReleased(binding) {
            appdata.input_actions_this_frame[appdata.input_actions_count] = GameAction {
                trigger = .Released,
                type = action,
            }
            appdata.input_actions_count += 1
        } else if rl.IsKeyDown(binding) {
            appdata.input_actions_this_frame[appdata.input_actions_count] = GameAction {
                trigger = .Held,
                type = action,
            }
            appdata.input_actions_count += 1
        }
        
        assert(appdata.input_actions_count < 8, message = "increase input actions per frame limit")
    }
}

update :: proc(appdata: ^AppData, delta: f32) {
    appdata.pref_stats.fps = 1/appdata.delta_time
    // we don't dealloc from init memory
    appdata.pref_stats.memory_used_bytes = u32(appdata.init_allocator.peak_used)

    // overriden if doing replay
    if appdata.replay_state != .PlayingBack {
        appdata.delta_time = delta
        update_input_actions(appdata)
    }

    //TODO
    switch appdata.replay_state {
    case .ReloadLevelToStartReplay:
        appdata.loaded_replay = {
            level_path = appdata.level_path,
            level_version = appdata.level_version,
            encoding_version = 0,
            action_frame = make([dynamic]u32),
            actions = make([dynamic]GameAction),
            delta_times = make([dynamic]f32),
        }

        if (load_level_data_from_disk(appdata, "default", appdata.frame_mem_alloc, appdata.frame_mem_alloc)) {
            appdata.replay_state = .RecordingReplay
            appdata.frame_number = 0
        }
    case .RecordingReplay:
        append(&appdata.loaded_replay.delta_times, appdata.delta_time)

        for action in appdata.input_actions_this_frame[0:appdata.input_actions_count] {
            append(&appdata.loaded_replay.actions, action)
            append(&appdata.loaded_replay.action_frame, appdata.frame_number)
        }
    case .SaveReplayToDisk:
        save_replay_file_to_disk(appdata, appdata.frame_mem_alloc, appdata.init_mem_alloc)

        appdata.replay_state = .NotRecordingReplay
    case .ReloadLevelToPlaybackReplayFromDisk:
        load_level_data_from_disk(appdata, "default", appdata.frame_mem_alloc, appdata.init_mem_alloc)
        load_selected_replay_file_from_disk(appdata, appdata.frame_mem_alloc, appdata.init_mem_alloc)

        appdata.replay_state = .PlayingBack
        appdata.frame_number = 0
        appdata.replay_playback_action_index = 0
    case .PlayingBack:
        appdata.delta_time = appdata.loaded_replay.delta_times[appdata.frame_number]
        appdata.input_actions_count = 0

        i := appdata.replay_playback_action_index
        frame: u32 = 0
        for frame <= appdata.frame_number {
            fmt.println(frame, appdata.frame_number)
            assert(frame == appdata.frame_number)
            action := appdata.loaded_replay.actions[i]

            appdata.input_actions_this_frame[appdata.input_actions_count] = action
            appdata.input_actions_count += 1
            assert(appdata.input_actions_count < 8, "increase input actions per frame limit")

            i += 1
            frame = appdata.loaded_replay.action_frame[i]
        }
        appdata.replay_playback_action_index = i
    case .NotRecordingReplay:
    }        

    dt := f64(appdata.delta_time)
    b := appdata.grid.bounds

    for y in b.y..<b.height+b.y {
        for x in b.x..<b.width+b.x {
            //TODO?
        }
    }

    for i in 0..<appdata.entities_count {
        entity := &appdata.entities[i]

        if .Something not_in entity.flags {
            continue
        }

        if .Physics in entity.flags {
            grid_mat := ut.create_matrix_from_transform(appdata.linegrid.transform)

            entity.velocity += grid_to_world_position({0.0, 9.81}, appdata.linegrid) * f64(appdata.delta_time)
            
            box := ut.apply_matrix_to_bounds(ut.create_matrix_from_transform(entity.transform), entity.hitbox)

            for j in i+1..<appdata.entities_count {
                entity2 := &appdata.entities[j]

                if .Something not_in entity2.flags {
                    continue
                }

                box2 := ut.apply_matrix_to_bounds(ut.create_matrix_from_transform(entity2.transform), entity2.hitbox)

                hit, normal, depth := collide_aabb(box, box2)

                if hit {
                    mass_sum := entity.mass + entity2.mass

                    entity.transform.offset -= normal * depth * entity2.mass / mass_sum
                    entity2.transform.offset += normal * depth * entity.mass / mass_sum

                    delta_v := entity.velocity-entity2.velocity
                    vel_mag := la.length(delta_v)
                    vel_normal := la.normalize(delta_v)
                    surface_normal := normal
                    surface := la.vector2_orthogonal(surface_normal)

                    f := entity.physics_surface.friction*entity2.physics_surface.friction
                    e := entity2.physics_surface.restitution * entity.physics_surface.restitution
                    
                    friction := (la.dot(surface, vel_normal) * vel_mag * f) * surface

                    assert(entity.mass != 0)
                    assert(entity2.mass != 0)

                    J := la.dot(surface_normal, vel_normal) * vel_mag * (e + 1)

                    entity.velocity -= J * entity2.mass / mass_sum * surface_normal
                    entity.velocity -= friction * entity2.mass / mass_sum
                    
                    entity2.velocity += J * entity.mass / mass_sum * surface_normal
                    entity2.velocity += friction * entity.mass / mass_sum
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
                if held_action(appdata, .GoRight) {
                    if entity.velocity.x < 10 {
                        entity.velocity.x = 10
                    }
                    entity.velocity.x += 5 * dt
                }
                if held_action(appdata, .GoLeft) {
                    if entity.velocity.x > -10 {
                        entity.velocity.x = -10
                    }
                    entity.velocity.x += 5 * dt
                }
                if held_action(appdata, .Jump) {
                    entity.velocity.y = -20
                }
                if held_action(appdata, .RushDown) {
                    entity.velocity.y += 200 * dt
                }
            }

            entity.transform.offset += entity.velocity * dt
        }
    }
    
    if .LoadDataFromDisk in appdata.control.actions {
        load_level_data_from_disk(appdata, "default", appdata.frame_mem_alloc, appdata.init_mem_alloc)

        appdata.control.actions -= {.LoadDataFromDisk}
    }

    if .RecomputeGridHitboxes in appdata.control.actions {
        appdata.computed_simplified_collision_hitboxes = greedy_mesh_grid_into_worldspace_aabb_bounds_list(appdata.grid, appdata.linegrid);

        appdata.control.actions -= {.RecomputeGridHitboxes}
    }

    if .OverwriteSelectedEntity in appdata.control.actions {
        appdata.entities[appdata.editor_settings.selected_entity_id-1] = appdata.editor_settings.selected_entity
        appdata.control.actions -= { .OverwriteSelectedEntity }
    }

    if .ResizeWorldBounds in appdata.control.actions {
        resize_grid(&appdata.grid, appdata.new_bounds, appdata.init_mem_alloc)
        appdata.control.actions -= { .ResizeWorldBounds }
    }

    if .DeleteSelectedEntityID in appdata.control.actions {
        appdata.entities[appdata.editor_settings.selected_entity_id-1].flags -= { .Something }
        appdata.control.actions -= { .DeleteSelectedEntityID }
    }

    appdata.viewports[appdata.game_viewport].camera_position = follow_player(&appdata.camera_follow, appdata, appdata.delta_time)

    mem.arena_free_all(&appdata.frame_allocator)
    
    // frame incremented after
    appdata.frame_number += 1
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

            if entity != nil && .Something in entity.flags {
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
    within := ut.position_within_bounds(rl.GetMousePosition(), screen_rect)

    if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyDown(.LEFT_SHIFT) && rl.IsKeyPressed(.F) && within {
        if appdata.fullscreen_viewport_id == id {
            appdata.fullscreen_viewport_id = max(editorui.ViewportIndex)
        } else {
            appdata.fullscreen_viewport_id = id
        }
    }

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

        if .Something not_in entity.flags {
            continue
        }

        if .CameraRoom in entity.flags && .HighlightCameraRooms in viewport.flags {
            box := ut.bounds_to_bounds(f64, entity.grid_area)
            box = grid_bounds_to_worldspace_bounds(box, appdata.linegrid)
            box = ut.apply_matrix_to_bounds(viewport_mat, box)
            
            rl.DrawRectangleLinesEx(
                transmute(rl.Rectangle)ut.bounds_to_bounds(f32, box), 
                1.0,
                auto_cast ut.GREEN,
            )
        }

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
        
        if rl.IsKeyDown(.LEFT_CONTROL) {
            // This section of the code needs to be refactor maybe we have some temporary data that
            // says where we are on the tilegrid and our world transform position and if we are clicking
            // ect and then the indiviual logic can be more simple
        }
    case .CameraControl:
        drag_camera(appdata, id)
        zoom_camera(appdata, id)
    case .TileBrush:
        if rl.IsKeyDown(.LEFT_CONTROL) {
            drag_camera(appdata, id)
        } else {
            place_tile(appdata, id, appdata.init_mem_alloc)
        }
        zoom_camera(appdata, id)
    case .EntityBrush:
        if rl.IsKeyDown(.LEFT_CONTROL) {
            drag_camera(appdata, id)
        } else {
            place_entity(appdata, id, appdata.init_mem_alloc)
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
    frame_allocator := appdata.frame_mem_alloc
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
    frame_allocator := appdata.frame_mem_alloc
    
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
    appdata.frame_mem_alloc = mem.arena_allocator(&appdata.frame_allocator)

    appdata.init_buffer = make([]u8, INIT_MEMORY_BUFFER_SIZE)
    mem.arena_init(&appdata.init_allocator, appdata.init_buffer)
    appdata.init_mem_alloc = mem.arena_allocator(&appdata.init_allocator)

    // clay
    min_memory_size := clay.MinMemorySize()
    memory := make([^]u8, min_memory_size, appdata.init_mem_alloc)
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
        appdata.frame_mem_alloc, 
        appdata.init_mem_alloc
    )

    appdata.editor_ui = editorui.create_editorui(&appdata.theme_config_data.data, context.allocator)
    
    if appdata.editor_config_data.version != EDITOR_SETTINGS_VERSION {
        fmt.eprintln("Editor settings version mismatch")
    }
    
    load_config_file_from_disk(
        &appdata.editor_config_data, 
        "editor_settings", 
        appdata.frame_mem_alloc, 
        appdata.init_mem_alloc
    )
    
    load_config_file_from_disk(
        &appdata.viewport_config_data, 
        "viewport_settings", 
        appdata.frame_mem_alloc, 
        appdata.init_mem_alloc
    )

    appdata.editor_settings.selected_entity = entity_stub
    
    rn.init_font_table(&rn.font_table, context.allocator)
}

exit_app :: proc(appdata: ^AppData) { 
    if .SaveLevelOnExit in appdata.control.actions {
        level_data: VersionedFile(LevelFile) = {
            data = appdata.level^,
            version = LEVEL_REPLAY_FILE_VERSION,
        }

        //if appdata.level_data.version == LEVEL_REPLAY_FILE_VERSION {
        save_level_data_to_disk(appdata, "default", appdata.frame_mem_alloc)
        //} else {
        //    fmt.eprintln("WARNING: write updates file version")
        //}
    }    

    if .SaveAllConfigsOnExit in appdata.control.actions {
        //if appdata.theme_config_data.version == THEME_SETTINGS_VERSION {
            save_config_data_to_disk(
                appdata.theme_config_data, 
                "theme_settings", 
                appdata.frame_mem_alloc, 
            )
        //} else {
        //    fmt.eprintln("WARNING: write updates file version")
        //}

        //if appdata.editor_config_data.version == EDITOR_SETTINGS_VERSION {
            save_config_data_to_disk(
                appdata.editor_config_data, 
                "editor_settings", 
                appdata.frame_mem_alloc, 
            ) 
        //} else {
        //    fmt.eprintln("WARNING: write updates file version")
        //}

        save_config_data_to_disk(
            appdata.viewport_config_data, 
            "viewport_settings", 
            appdata.frame_mem_alloc, 
        ) 
    }
}
