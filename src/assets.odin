package main

import ut "project:utils"
import rl "vendor:raylib"

SpriteSheet :: union(T: typeid) {
    UniformSpritesheet,
    NonuniformAABBSpriteSheet,
}

NonuniformAABBSpriteSheet :: struct {
    bounds: []ut.Bounds(u32),
    texture: rl.Texture,
}

UniformSpritesheet :: struct {
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

draw_sprite :: proc(id: $T, sh: SpriteSheet(T), dest: ut.Bounds(f32), rotate_deg: f32 = 0) {
    index := i32(id)

    switch sheet in sh {
    case UniformSpritesheet:
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
    case NonuniformAABBSpriteSheet:
        bounds := ut.bounds_to_bounds(f32, sheet.bounds[index])
        
        rl.DrawTexturePro(sheet.texture, rl.Rectangle {
            width = bounds.width,
            height = bounds.height,
            x = bounds.x,
            y = bounds.y,
        }, {dest.x+dest.width/2, dest.y+dest.height/2, dest.width, dest.height}, {dest.width/2, dest.height/2}, rotate_deg, rl.WHITE)
    }
}

create_first_game_sheet :: proc() -> SpriteSheet(FirstGameSheetId) {
    texture := rl.LoadTexture("./assets/firstgamesheet.png")
    return UniformSpritesheet {
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
