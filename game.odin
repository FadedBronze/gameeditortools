package main

import "project:editorui"
import ut "utils"
import clay "clay-odin"
import rl "vendor:raylib"
import la "core:math/linalg"

import "core:math"
import "core:mem"
import "core:testing"

GridPosition :: [2]i32

MoveType :: enum {
    Walk,
    Dodge
}

Direction :: enum {
    Up,
    Left,
    Down,
    Right,
}

Move :: struct {
    type: MoveType "dropdown",
    sprite: FirstGameSheetId,
    sprite_rotation_offset: f64,
    momentum_required: u8 "text",
    energy_cost: u8 "text",
    
    direction: Direction "dropdown",
}

Entity :: struct {
    flags: bit_set[enum {Something}] "dropdown",
    sprite: FirstGameSheetId "dropdown",
    team: u8 "text",
}

Environment :: struct {
    sprite: FirstGameSheetId "dropdown",
}

Tile :: struct {
    flags: bit_set[enum {EntityExists, EnvironmentExists}] "dropdown",
    entity: Entity "group",
    environment: Environment "group",
}

Grid :: struct(T: typeid) {
    bounds: ut.Bounds(i32) "group",
    tiles: []T,
}

RectangleLineGrid :: struct {
    width: f64 "text",
    height: f64 "text",
    transform: ut.Transform(f64) "group" 
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

Views :: enum {
    WorldViewports,    
    TileEditor,
    Player,
    ActionQueue,
}

EditorSettings :: struct {
    open_views: bit_set[Views] "dropdown",
    selected_tile: Tile "group",
    active_tool: enum {
        GameTool,
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

draw_sprite :: proc(id: $T, sheet: SpriteSheet(T), dest: ut.Bounds(f32), rotate_deg: f32 = 0) {
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
    //rl.DrawTextureRec(sheet.texture, rect, {dest.x, dest.y}, rl.WHITE)
    rl.DrawTexturePro(sheet.texture, rect, {dest.x+dest.width/2, dest.y+dest.height/2, dest.width, dest.height}, {dest.width/2, dest.height/2}, rotate_deg, rl.WHITE)
}

GameState :: enum {
    Planning,
    PlayingAttack,
}

//LevelId :: distinct u32
//Level :: struct {
//    tilegrid: RectangleTileGrid(Tile),
//}

Player :: struct {
    // unlocked moves
    moves: [32]Move,
    move_count: u8,

    // queued moves
    move_queue: [32]Move,
    moves_queued: u8,

    energy_capacity: u8 "text",
    momentum: u8 "text",
}

MoveDrag :: struct {
    mouse_start: la.Vector2f32,
    dragging_move: u8,
}

QueueMoveDrag :: struct {
    mouse_start: la.Vector2f32,
    dragging_move: u8,
}

EmptyDrag :: struct {}

Drag :: union {
    EmptyDrag,
    ViewportDrag,
}

Team :: struct {
    grid: Grid(Tile),
}

AppData :: struct {
    delta_time: f32,
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

    teams: []Team,

    player_team: u8,

    drag: Drag,

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

do_gamestep :: proc(appdata: ^AppData) {
    linegrid := &appdata.linegrid

    //if get_tile(appdata.tilegrid, player.position).entity == .Player {
    //    next_move := appdata.player.move_queue[player.moves_queued-1]
    //    player.moves_queued -= 1

    //    switch next_move.type {
    //    case .Walk:
    //        new_pos := direction_to_gridpos(next_move.direction) + player.position
    //        if !ut.position_within_bounds(new_pos, tilegrid.bounds) {
    //            //TODO: Some kind of failed to move sfx
    //            break
    //        }
    //        queue_action(appdata, GridTranslation {
    //            easing = .Cosine,
    //            start_cell = player.position,
    //            end_cell = new_pos,
    //            speed = 2.0,
    //        })
    //    }
    //}

    //i: u8 = 0
    //for i < appdata.enemy_count {
    //    enemy := appdata.enemies[i]

    //    if get_tile(appdata.tilegrid, player.position).entity != .Enemy {
    //        appdata.enemies[i] = appdata.enemies[appdata.enemy_count-1]
    //        appdata.enemy_count-=1
    //    }
    //}
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

offset: f32 = 0
update :: proc(appdata: rawptr, delta_time: f32) {
    appdata: ^AppData = cast(^AppData)appdata
    appdata.delta_time = delta_time

    update_tiles(appdata, delta_time)
}

create_tile :: proc(appdata: ^AppData, position: GridPosition, allocator: mem.Allocator) {
    set_tile(&appdata.grid, position, appdata.editor_settings.selected_tile, allocator)
}

place_tile :: proc(appdata: ^AppData, viewport_id: editorui.ViewportIndex, allocator: mem.Allocator) {
    viewport := &appdata.viewports[viewport_id]
    tile_grid := &appdata.linegrid

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
    id: FirstGameSheetId = tile.entity.sprite
    
    viewport_bounds := ut.apply_matrix_to_bounds(mat, ut.Bounds(f64) {
        x = pos.x,
        y = pos.y,
        width = 1,
        height = 1,
    })

    if .EntityExists in tile.flags {
        draw_sprite(id, sprite_sheet, ut.bounds_to_bounds(f32, viewport_bounds))
    }
}

update_tile :: proc(appdata: ^AppData, position: GridPosition, dt: f32) {
}

update_tiles :: proc(appdata: ^AppData, dt: f32) {
    b := appdata.grid.bounds

    for y in b.y..<b.height+b.y {
        for x in b.x..<b.width+b.x {
            update_tile(appdata, {x, y}, dt)
        }
    }
}

import "core:fmt"

render_tiles :: proc(viewport: WorldViewport2D, linegrid: RectangleLineGrid, grid: Grid($T), spritesheet: SpriteSheet(FirstGameSheetId)) {
    mat := ut.create_matrix_from_transform(linegrid.transform) * get_viewport_matrix(viewport)
    b := grid.bounds

    for y in b.y..<b.height+b.y {
        for x in b.x..<b.width+b.x {
            fmt.println("hello?")
            tile := get_tile(grid, {x, y})
            render_tile(tile, {f64(x), f64(y)}, mat, spritesheet)
        }
    }
}

render :: proc(appdata: rawptr, screen_rect: ut.Bounds(f32), id: editorui.ViewportIndex) {
    appdata: ^AppData = cast(^AppData)appdata
    viewport := &appdata.viewports[id]
    viewport.screen_rect = ut.bounds_to_bounds(f64, screen_rect)

    rl.DrawRectangleRec(transmute(rl.Rectangle)screen_rect, rl.WHITE)

    render_tile_grid_lines(viewport^, appdata.linegrid)
    render_tiles(viewport^, appdata.linegrid, appdata.grid, appdata.sprite_sheet)

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

set_tile_base :: proc(grid: ^Grid($T), position: GridPosition, tile: T) {
    assert(ut.position_within_bounds(position, grid.bounds))
    idx_y := int(grid.bounds.width) * int(position.y - grid.bounds.y)
    idx_x := int(position.x - grid.bounds.x)
    grid.tiles[idx_y + idx_x] = tile
}

set_tile :: proc(grid: ^Grid($T), position: GridPosition, tile: T, allocator: mem.Allocator = context.allocator) {
    empty := T{}
    if get_tile(grid^, position) == empty  && tile == empty {
        return
    }

    // resize case
    if !ut.position_within_bounds(position, grid.bounds) {
        old_bounds := grid.bounds
        
        // resizing
        if position.x-grid.bounds.x >= grid.bounds.width {
            grid.bounds.width = position.x-grid.bounds.x+1
        }

        if position.x < grid.bounds.x {
            increment := math.abs(position.x-grid.bounds.x)
            grid.bounds.width += increment
            grid.bounds.x = position.x
        } 

        if position.y-grid.bounds.y >= grid.bounds.height {
            grid.bounds.height = position.y-grid.bounds.y+1
        }

        if position.y < grid.bounds.y {
            increment := math.abs(position.y-grid.bounds.y)
            grid.bounds.height += increment
            grid.bounds.y = position.y
        }

        old_tiles := grid.tiles
        grid.tiles = make([]T, grid.bounds.width * grid.bounds.height, allocator)

        for x in old_bounds.x..<old_bounds.width+old_bounds.x {
            for y in old_bounds.y..<old_bounds.height+old_bounds.y {
                set_tile_base(grid, {x, y}, get_tile_base(old_tiles, old_bounds.x, old_bounds.y, old_bounds.width, {x, y})^)
            }
        }
    }

    // basic case
    set_tile_base(grid, position, tile)
}

get_tile_base :: proc(tiles: []$T, x, y, width: i32, position: GridPosition) -> ^T {
    idx_y := int(width) * int(position.y - y)
    idx_x := int(position.x - x)
    return &tiles[idx_y + idx_x]
}

get_tile :: proc(grid: Grid($T), position: GridPosition) -> T {
    if !ut.position_within_bounds(position, grid.bounds) {
        return T{}
    }
    return get_tile_base(grid.tiles, grid.bounds.x, grid.bounds.y, grid.bounds.width, position)^
}

get_tile_ptr :: proc(tilegrid: ^Grid($T), position: GridPosition) -> ^T {
    if !ut.position_within_bounds(position, tilegrid.bounds) {
        return nil
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
    appdata.linegrid = RectangleLineGrid {
        width = 1,
        height = 1,
        transform = ut.TRANSFORM_IDENTITY_F64,
    }

    appdata.sprite_sheet = create_first_game_sheet()

    appdata.player_team = 0

    //context.allocator = mem.arena_allocator(&appdata.init_allocator)
    
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

    grid := Grid(Example) {}
    
    set_tile(&grid, {0, 0}, Example.Blue)
    set_tile(&grid, {-1, -1}, Example.Red)
    set_tile(&grid, {-2, -2}, Example.Blue)
    set_tile(&grid, {-3, -3}, Example.Red)
    set_tile(&grid, {1, 1}, Example.Red)
    set_tile(&grid, {5, 1}, Example.Blue)
    set_tile(&grid, {20, 20}, Example.Red)
    set_tile(&grid, {50, 0}, Example.Blue)
    set_tile(&grid, {50, 0}, Example.Red)

    //fmt.println(appdata.bounds)
    //for y in appdata.bounds.y..<appdata.bounds.height+appdata.bounds.y {
    //    for x in appdata.bounds.x..<appdata.bounds.width+appdata.bounds.x {
    //        fmt.printf("%d ", get_tile(&appdata. {x, y}))
    //    }
    //    fmt.println()
    //}

    testing.expect(t, get_tile(grid, {50, 0}) == .Red)
}
