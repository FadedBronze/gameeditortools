package main

import "project:editorui"
import ut "utils"
import clay "clay-odin"
import rl "vendor:raylib"
import la "core:math/linalg"
import "core:math/rand"
import "core:fmt"

import "core:math"
import "core:mem"
import "core:testing"

GridPosition :: [2]i32

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

Grid :: struct(T: typeid) {
    bounds: ut.Bounds(i32) "group",
    tiles: []T,
}

RectangleLineGrid :: struct {
    width: f64 "text",
    height: f64 "text",
    transform: ut.Transform(f64) "group" 
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

    entities: []Entity,
    entities_count: u32, // zero corresponds to null ig

    player: Player,

    drag: Drag,

    // hovered tile essentially
    active_tile: GridPosition,
    state: GameState,
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

copy_grid :: proc(grid: Grid($T), allocator: mem.Allocator) -> Grid(T) {
    new_grid := grid
    new_grid.tiles = make([]T, len(grid.tiles), allocator)
    copy(new_grid.tiles, grid.tiles)
    return new_grid
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
        entity := &appdata.entities[i]

        if .Physics in entity.flags {
            rx := i32(entity.hitbox.width / appdata.linegrid.width)
            ry := i32(entity.hitbox.height / appdata.linegrid.height)

            entity.velocity.y += 0.00000981
            entity.velocity.y = max(abs(entity.velocity.y), 0.01)*math.sign(entity.velocity.y)
            entity.transform.offset += entity.velocity

            gridpos := world_to_tile_pos(entity.transform.offset, appdata.linegrid)
            highest_pentration: f64 = 0
            highest_box: ut.Bounds(f64)
            highest_normal: la.Vector2f64
            collide := false

            for x in -rx/2..=rx/2 {
                for y in -ry/2..=ry/2 {
                    world_hitbox := ut.apply_matrix_to_bounds(
                        ut.create_matrix_from_transform(entity.transform), 
                        entity.hitbox
                    )

                    tile_pos := gridpos + {x, y}
                    tile := get_tile(appdata.grid, tile_pos)
                    
                    if .Blocked in tile.environment.flags {
                        tile_world_hitbox := get_tile_bounds(appdata.linegrid, appdata.grid, tile_pos)
                        hit, normal, depth := collide_aabb(world_hitbox, tile_world_hitbox)

                        if hit && depth > highest_pentration {
                            highest_box = tile_world_hitbox
                            highest_pentration = depth
                            highest_normal = normal
                            collide = true
                        }
                    }
                }
            }
            
            if collide {
                entity.transform.offset -= highest_normal * highest_pentration
                entity.velocity = {0, 0}
            }
        }
    }
}

update :: proc(appdata: rawptr, delta_time: f32) {
    appdata: ^AppData = cast(^AppData)appdata
    appdata.delta_time = delta_time
 
    update_tiles(appdata, delta_time)
    update_entities(appdata, delta_time)

    mem.arena_free_all(&appdata.frame_allocator)
}

create_tile :: proc(appdata: ^AppData, position: GridPosition) {
    set_tile_base(&appdata.grid, position, appdata.editor_settings.selected_tile)
}

world_to_tile_pos :: proc(world_mouse_pos: la.Vector2f64, linegrid: RectangleLineGrid) -> GridPosition {
    tilegrid_position := [2]i32{
        i32(math.floor(world_mouse_pos.x / f64(linegrid.width)) * linegrid.width),
        i32(math.floor(world_mouse_pos.y / f64(linegrid.height)) * linegrid.height)
    }
    return tilegrid_position
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

resize_grid :: proc(grid: ^Grid($T), new_bounds: ut.Bounds(i32), allocator: mem.Allocator) {
    old_tiles := grid.tiles
    old_bounds := grid.bounds

    grid.tiles = make([]T, new_bounds.width * new_bounds.height, allocator)
    grid.bounds = new_bounds

    for x in old_bounds.x..<old_bounds.width+old_bounds.x {
        for y in old_bounds.y..<old_bounds.height+old_bounds.y {
            set_tile_base(grid, {x, y}, get_tile_base(old_tiles, old_bounds.x, old_bounds.y, old_bounds.width, {x, y})^)
        }
    }
}

set_tile :: proc(grid: ^Grid($T), position: GridPosition, tile: T, allocator: mem.Allocator = context.allocator) {
    empty := T{}
    if get_tile(grid^, position) == empty  && tile == empty {
        return
    }

    // resize case
    if !ut.position_within_bounds(position, grid.bounds) {
        new_bounds := grid.bounds
        
        // resizing
        if position.x-new_bounds.x >= new_bounds.width {
            new_bounds.width = position.x-new_bounds.x+1
        }

        if position.x < new_bounds.x {
            increment := math.abs(position.x-new_bounds.x)
            new_bounds.width += increment
            new_bounds.x = position.x
        } 

        if position.y-new_bounds.y >= new_bounds.height {
            new_bounds.height = position.y-new_bounds.y+1
        }

        if position.y < new_bounds.y {
            increment := math.abs(position.y-new_bounds.y)
            new_bounds.height += increment
            new_bounds.y = position.y
        }

        resize_grid(grid, new_bounds, allocator)
    }

    // basic case
    set_tile_base(grid, position, tile)
}

get_tile_base :: proc(tiles: []$T, x, y, width: i32, position: GridPosition) -> ^T {
    idx_y := int(width) * int(position.y - y)
    idx_x := int(position.x - x)
    return &tiles[idx_y + idx_x]
}

get_tile_bounds :: proc(linegrid: RectangleLineGrid, grid: Grid($T), position: GridPosition) -> ut.Bounds(f64) {
    return auto_cast {f64(position.x)*linegrid.width, f64(position.y)*linegrid.height, linegrid.width, linegrid.height}
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
