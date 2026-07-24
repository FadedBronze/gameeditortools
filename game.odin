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

GridPosition :: [2]i32

MoveType :: enum {
    Walk,
}

Direction :: enum {
    Up,
    Down,
    Left,
    Right
}

Move :: struct {
    type: MoveType,
    direction: Direction,
    momentum_required: u8,
    energy_cost: u8,
}

Player :: struct {
    move_queue: [32]Move,
    moves_queued: u8,
    energy_capacity: u8 "text",
    momentum: u8 "text",
    position: GridPosition "text",
}

Tile :: struct {
    platform: PlatformTileType "dropdown",
    entity: EntityTileType "dropdown",
}

EntityTileType :: enum {
    Empty,
    Player,
    Enemy,
}

PlatformTileType :: enum {
    Base,
    Elevation,
}

RectangleTileGrid :: struct(T: typeid) {
    width: f64 "text",
    height: f64 "text",
    bounds: ut.Bounds(i32) "group",
    tiles: []T,
    transform: ut.Transform(f64) "group" 
}

RootGameObject :: struct {}

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
    Player,
}

EditorSettings :: struct {
    open_views: bit_set[Views] "dropdown",
    selected_tile: Tile "group",
    active_tool: enum {
        CameraControl,
        TileBrush,
    } "dropdown",
}

SpriteSheet :: struct(T: typeid) {
    texture: rl.Texture,
    bounds: ut.Bounds(f32),
    divisions_x: i32,
    divisions_y: i32,
}

FirstGameSheetId :: enum {
    ChoosePlus,
    Sniper,
    Shotgunner,
    Elevation,
    Plane,
    DoubleJump,
    SwapReverse,
    Launch, 
    Slip,
    Heart,
    PortalIn,
    PortalOut,
    PlayerHappy,
    PlayerShocked,
    SuperDown,
    Flex,
    Around,
    Slot,
    Spikes,
    Ammo,
    Boss,
    Shield,
    Bat,
    Skateboard,
    Direction,
}

draw_sprite :: proc(id: $T, sheet: SpriteSheet(T), dest: ut.Bounds(f32)) {
    index := i32(id)

    column := index % sheet.divisions_x
    row := index / sheet.divisions_x

    cell_size_x := sheet.bounds.width / f32(sheet.divisions_x)
    cell_size_y := sheet.bounds.height / f32(sheet.divisions_y)

    x := sheet.bounds.x + f32(column) * cell_size_x
    y := sheet.bounds.y + f32(row) * cell_size_y

    width := cell_size_x
    height := cell_size_y

    rect := rl.Rectangle { x, y, width, height }
    fmt.println(rect)
    //rl.DrawTextureRec(sheet.texture, rect, {dest.x, dest.y}, rl.WHITE)
    rl.DrawTexturePro(sheet.texture, rect, {dest.x, dest.y, dest.width, dest.height}, {0, 0}, 0, rl.WHITE)
}

GameState :: enum {
    PlayingAttack,
    Planning,
}

LevelId :: distinct u32
Level :: struct {
    tilegrid: RectangleTileGrid(Tile),
}

EnemyType :: enum {
    Sniper,
    Shotgunner,
}

Enemy :: struct {
    type: EnemyType,
    position: GridPosition,
}

GridTranslation :: struct {
    easing: enum { Quadratic, Linear, Cosine },
    original_tile: Tile,
    start_cell: GridPosition,
    end_cell: GridPosition,
    progress: f64,
    speed: f64,
}

// doesn't really remove just removes from grid visually sort of 
RemoveFromGrid :: struct {
    cell: GridPosition,
}

AddToGrid :: struct {
    cell: GridPosition,
}

ActionPayload :: union {
    GridTranslation,
}

AppData :: struct {
    delta_time: f32,
    ui_context: ^clay.Context,
    frame_buffer: []u8,
    frame_allocator: mem.Arena,
    init_buffer: []u8,
    init_allocator: mem.Arena,

    editor_settings: EditorSettings,

    viewport_drag: ViewportDrag,
    sprite_sheet: SpriteSheet(FirstGameSheetId),

    viewports: [2]WorldViewport2D,
    tilegrid: RectangleTileGrid(Tile),
    player: Player,

    enemies: [32]Enemy,
    enemy_count: u8,

    // animations and things dependant on animations
    action_queue: [128]ActionPayload,
    action_count: u8,

    // hovered tile essentially
    active_tile: GridPosition,
    state: GameState,
}

direction_to_gridpos :: proc(dir: Direction) -> GridPosition {
    switch dir {
    case .Up:
        return { 1, 0 }
    case .Down:
        return { -1, 0 }
    case .Left:
        return { 1, 0 }
    case .Right:
        return { -1, 0 }
    }
    unreachable()
} 

queue_action :: proc(appdata: ^AppData, action: ActionPayload) {
    appdata.action_queue[appdata.action_count] = action
    appdata.action_count += 1
}

render_next_action :: proc(appdata: ^AppData, viewport_id: editorui.ViewportIndex) {
    next_action := appdata.action_queue[appdata.action_count-1]
    viewport := appdata.viewports[viewport_id]
    mat := get_viewport_matrix(viewport)*ut.create_matrix_from_transform(appdata.tilegrid.transform)

    switch v in next_action {
    case GridTranslation:
        if v.progress == 0 {
            prev_tile := get_tile(appdata.tilegrid, v.start_cell)
            set_tile(&appdata.tilegrid, v.start_cell, Tile {})
        }

        progress := v.progress

        switch v.easing {
            case .Quadratic:
                progress = progress * progress
            case .Linear:
                progress = progress
            case .Cosine:
                progress = (1 - math.cos_f64(math.PI * progress))/2
        }

        if v.start_cell.x != v.end_cell.x {
            y_delta := v.end_cell.y - v.start_cell.y
            y_position := (progress * f64(y_delta)) + f64(v.start_cell.y)

            render_tile(v.original_tile, {f64(v.start_cell.x), y_position}, mat, appdata.sprite_sheet)
        } else {
            x_delta := v.end_cell.x - v.start_cell.x
            x_position := (progress * f64(x_delta)) + f64(v.start_cell.x)
            
            render_tile(v.original_tile, {x_position, f64(v.start_cell.y)}, mat, appdata.sprite_sheet)
        }
    }
}

update_next_action :: proc(appdata: ^AppData, dt: f32) {
    next_action := appdata.action_queue[appdata.action_count-1]

    switch &v in &next_action {
    case GridTranslation:
        assert(v.start_cell.x == v.end_cell.x || v.start_cell.y == v.end_cell.y, message="only support horizontal and vertical translations")
        
        if v.progress == 0 {
            v.original_tile = get_tile(appdata.tilegrid, v.start_cell)
            set_tile(&appdata.tilegrid, v.start_cell, Tile {})
        }

        if v.start_cell.x != v.end_cell.x {
            y_delta := v.end_cell.y - v.start_cell.y
            v.progress += f64(dt) / f64(y_delta) * v.speed
        } else {
            x_delta := v.end_cell.x - v.start_cell.x
            v.progress += f64(dt) / f64(x_delta) * v.speed
        }
    }
}

do_gamestep :: proc(appdata: ^AppData) {
    player := &appdata.player
    tilegrid := &appdata.tilegrid

    if get_tile(appdata.tilegrid, player.position).entity == .Player {
        next_move := appdata.player.move_queue[player.moves_queued-1]
        player.moves_queued -= 1

        switch next_move.type {
        case .Walk:
            new_pos := direction_to_gridpos(next_move.direction) + player.position
            if !ut.position_within_bounds(new_pos, tilegrid.bounds) {
                //TODO: Some kind of failed to move sfx
                break
            }
            queue_action(appdata, GridTranslation {
                easing = .Cosine,
                start_cell = player.position,
                end_cell = new_pos,
                speed = 2.0,
            })
        }
    }

    i: u8 = 0
    for i < appdata.enemy_count {
        enemy := appdata.enemies[i]

        if get_tile(appdata.tilegrid, player.position).entity != .Enemy {
            appdata.enemies[i] = appdata.enemies[appdata.enemy_count-1]
            appdata.enemy_count-=1
        }
    }
}

render_tile_grid_lines :: proc(viewport: WorldViewport2D, tilegrid: RectangleTileGrid($T)) { 
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

move_player :: proc(appdata: ^AppData) {
    tile_pos := appdata.player.position
    set_tile(&appdata.tilegrid, tile_pos, Tile {})
}

offset: f32 = 0
update :: proc(appdata: rawptr, delta_time: f32) {
    appdata: ^AppData = cast(^AppData)appdata
    appdata.delta_time = delta_time

    switch appdata.state {
    case .PlayingAttack:
        if appdata.action_count > 0 {
            update_next_action(appdata, delta_time)
        } else if appdata.player.moves_queued != 0 {
            do_gamestep(appdata)
        }
    case .Planning:
    }
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

create_tile :: proc(appdata: ^AppData, position: GridPosition, allocator: mem.Allocator) {
    switch appdata.editor_settings.selected_tile.entity {
    case .Player:
        appdata.player = Player {
            momentum = 0,
            energy_capacity = 3,
            position = position,
        }
    case .Enemy:
        appdata.enemies[appdata.enemy_count] = Enemy {
            position = position,
            type = .Sniper,
        }
        appdata.enemy_count+=1
    case .Empty:
    }
    set_tile(&appdata.tilegrid, position, appdata.editor_settings.selected_tile, allocator)
}

place_tile :: proc(appdata: ^AppData, viewport_id: editorui.ViewportIndex, allocator: mem.Allocator) {
    viewport := &appdata.viewports[viewport_id]
    tile_grid := &appdata.tilegrid

    mouse_pos := rl.GetMousePosition()
    // TODO: needs to be replaced with pointer over from editor since ui may need to go over
    within := ut.position_within_bounds(la.Vector2f64{f64(mouse_pos.x), f64(mouse_pos.y)}, viewport.screen_rect)
    world_mouse_pos := screen_to_world_space(viewport^, auto_cast mouse_pos)

    tilegrid_position := [2]i32{
        i32(math.floor(world_mouse_pos.x / f64(tile_grid.width)) * tile_grid.width),
        i32(math.floor(world_mouse_pos.y / f64(tile_grid.height)) * tile_grid.height)
    }

    if rl.IsMouseButtonPressed(.LEFT) && within {
        appdata.active_tile = tilegrid_position
        create_tile(appdata, tilegrid_position, allocator)
    }
}

render_tile :: proc(tile: Tile, pos: la.Vector2f64, mat: la.Matrix3f64, sprite_sheet: SpriteSheet(FirstGameSheetId)) {
    viewport_bounds := ut.apply_matrix_to_bounds(mat, ut.Bounds(f64) {
        x = pos.x,
        y = pos.y,
        width = 1,
        height = 1,
    })

    id: FirstGameSheetId

    switch tile.entity {
    case .Player:
        id = .PlayerHappy
    case .Enemy:
        //TODO
        id = .Sniper
    case .Empty:
    }
    
    if tile.entity != .Empty {
        draw_sprite(id, sprite_sheet, ut.bounds_to_bounds(f32, viewport_bounds))
    }
}

render_tiles :: proc(viewport: WorldViewport2D, tilegrid: RectangleTileGrid(Tile), spritesheet: SpriteSheet(FirstGameSheetId)) {
    mat := ut.create_matrix_from_transform(tilegrid.transform) * get_viewport_matrix(viewport)
    b := tilegrid.bounds

    for y in b.y..<b.height+b.y {
        for x in b.x..<b.width+b.x {
            tile := get_tile(tilegrid, {x, y})
            render_tile(tile, {f64(x), f64(y)}, mat, spritesheet)
        }
    }
}

render :: proc(appdata: rawptr, screen_rect: ut.Bounds(f32), id: editorui.ViewportIndex) {
    appdata: ^AppData = cast(^AppData)appdata
    viewport := &appdata.viewports[id]
    viewport.screen_rect = ut.bounds_to_bounds(f64, screen_rect)

    rl.DrawRectangleRec(transmute(rl.Rectangle)screen_rect, rl.WHITE)

    render_tile_grid_lines(viewport^, appdata.tilegrid)
    render_tiles(viewport^, appdata.tilegrid, appdata.sprite_sheet)

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
    }

    render_next_action(appdata, id)

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

set_tile_base :: proc(tilegrid: ^RectangleTileGrid($T), position: GridPosition, tile: T) {
    assert(ut.position_within_bounds(position, tilegrid.bounds))
    idx_y := int(tilegrid.bounds.width) * int(position.y - tilegrid.bounds.y)
    idx_x := int(position.x - tilegrid.bounds.x)
    tilegrid.tiles[idx_y + idx_x] = tile
}

set_tile :: proc(tilegrid: ^RectangleTileGrid($T), position: GridPosition, tile: T, allocator: mem.Allocator = context.allocator) {
    empty := T{}
    if get_tile(tilegrid^, position) == empty  && tile == empty {
        return
    }

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
        tilegrid.tiles = make([]T, tilegrid.bounds.width * tilegrid.bounds.height, allocator)

        for x in old_bounds.x..<old_bounds.width+old_bounds.x {
            for y in old_bounds.y..<old_bounds.height+old_bounds.y {
                set_tile_base(tilegrid, {x, y}, get_tile_base(old_tiles, old_bounds.x, old_bounds.y, old_bounds.width, {x, y}))
            }
        }
    }

    // basic case
    set_tile_base(tilegrid, position, tile)
}

get_tile_base :: proc(tiles: []$T, x, y, width: i32, position: GridPosition) -> T {
    idx_y := int(width) * int(position.y - y)
    idx_x := int(position.x - x)
    return tiles[idx_y + idx_x]
}

get_tile :: proc(tilegrid: RectangleTileGrid($T), position: GridPosition) -> T {
    if !ut.position_within_bounds(position, tilegrid.bounds) {
        return T{}
    }
    return get_tile_base(tilegrid.tiles, tilegrid.bounds.x, tilegrid.bounds.y, tilegrid.bounds.width, position)
}

create_first_game_sheet :: proc() -> SpriteSheet(FirstGameSheetId) {
    texture := rl.LoadTexture("./assets/firstgamesheet.png")
    return SpriteSheet(FirstGameSheetId) {
        texture = texture,
        divisions_x = 6,
        divisions_y = 5,
        bounds = ut.Bounds(f32) {
            x = 55,
            y = 50,
            width = 535,
            height = 440,
        }
    }
}

init_game :: proc(appdata: ^AppData) {
    appdata.tilegrid = RectangleTileGrid(Tile) {
        width = 1,
        height = 1,
        transform = ut.TRANSFORM_IDENTITY_F64,
    }

    appdata.sprite_sheet = create_first_game_sheet()

    context.allocator = mem.arena_allocator(&appdata.init_allocator)
    
    //set_tile(&appdata.tilegrid, {0, 0}, .Blue)
    //set_tile(&appdata.tilegrid, {-1, -1}, .Red)
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
    Example :: enum {
        Empty,
        Red,
        Blue,
    }

    tilegrid := RectangleTileGrid(Example) {
        width = 1,
        height = 1,
        transform = ut.TRANSFORM_IDENTITY_F64,
    }
    
    set_tile(&tilegrid, {0, 0}, Example.Blue)
    set_tile(&tilegrid, {-1, -1}, Example.Red)
    set_tile(&tilegrid, {-2, -2}, Example.Blue)
    set_tile(&tilegrid, {-3, -3}, Example.Red)
    set_tile(&tilegrid, {1, 1}, Example.Red)
    set_tile(&tilegrid, {5, 1}, Example.Blue)
    set_tile(&tilegrid, {20, 20}, Example.Red)
    set_tile(&tilegrid, {50, 0}, Example.Blue)
    set_tile(&tilegrid, {50, 0}, Example.Red)

    //fmt.println(appdata.tilegrid.bounds)
    //for y in appdata.tilegrid.bounds.y..<appdata.tilegrid.bounds.height+appdata.tilegrid.bounds.y {
    //    for x in appdata.tilegrid.bounds.x..<appdata.tilegrid.bounds.width+appdata.tilegrid.bounds.x {
    //        fmt.printf("%d ", get_tile(&appdata.tilegrid, {x, y}))
    //    }
    //    fmt.println()
    //}

    testing.expect(t, get_tile(tilegrid, {50, 0}) == .Red)
}
