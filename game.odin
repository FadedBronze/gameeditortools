package main

import ut "utils"
import clay "clay-odin"
import rl "vendor:raylib"

import "core:mem"

ExamplePhysics :: struct {
    pause: bool "toggle",
    speed: f32 "slider min(-0.69) max(0.69)",
}

ExampleColor :: enum {
    Red,
    Orange,
    Blue,
}

Example :: struct {
    name: string "text placeholder(name)",
    color: ExampleColor "dropdown",
    physics: ExamplePhysics "group",
}

AppData :: struct {
    example: Example,
    delta_time: f32,
    ui_context: ^clay.Context,
    //tile_grid: RectangleTileGrid,
}

//RectangleTileGrid :: struct {
//    width: f32 "text",
//    height: f32 "text",
//    offset: rl.Vector2 "text",
//}
//
//render_tile_grid_lines :: proc(tilegrid: RectangleTileGrid, screen_to_world_space) {
//}

offset: f32 = 0
update :: proc(appdata: rawptr, delta_time: f32) {
    appdata: ^AppData = cast(^AppData)appdata
    appdata.delta_time = delta_time

    if !appdata.example.physics.pause {
        offset += appdata.example.physics.speed
    }
}

render :: proc(appdata: rawptr, screen_rect: ut.Bounds(f32)) {
    appdata: ^AppData = cast(^AppData)appdata

    color: ut.Color

    switch appdata.example.color {
        case .Red:
            color = ut.Color{255, 0, 0, 255}
        case .Orange:
            color = ut.Color{255, 125, 0, 255}
        case .Blue:
            color = ut.Color{0, 125, 255, 255}
    }

    rl.DrawRectangleRec(rl.Rectangle{
        x = f32(int(screen_rect.width/2+50 + offset) % int(screen_rect.width+100))+screen_rect.x-100,
        y = screen_rect.y+screen_rect.height/2-50,
        width = 100,
        height = 100,
    }, auto_cast color)

    clay.SetCurrentContext(appdata.ui_context)
    clay.BeginLayout()

    if clay.UI()({ 
        layout = { 
            sizing = { width = clay.SizingFixed(screen_rect.width), height = clay.SizingFixed(screen_rect.height) } 
        },
        floating = { 
            attachTo = .Root,
            offset = { screen_rect.x, screen_rect.y } 
        },
    }) {
    }
    
    elements := clay.EndLayout(appdata.delta_time)
    clay_renderer(elements)
}

initialize_app :: proc(appdata: ^AppData, allocator: mem.Allocator) {
    min_memory_size := clay.MinMemorySize()

    memory := make([^]u8, min_memory_size, allocator)
    arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(uint(min_memory_size), memory)
    game_ui_context := clay.Initialize(arena, {1080, 720}, { handler = error_handler })
    appdata.ui_context = game_ui_context
    //appdata.tile_grid = RectangleTileGrid {
    //    width = 10,
    //    height = 10,
    //    offset = {0, 0},
    //}
}
