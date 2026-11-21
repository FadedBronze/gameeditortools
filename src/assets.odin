package main

import ut "project:utils"
import rl "vendor:raylib"
import "core:container/small_array"

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

count_occurances :: proc(things: []$T, check_thing: T) -> (count: int = 0) {
    for thing in things {
        if thing == check_thing {
            count += 1
        }
    }
}

maxrects_split_rectangle :: proc(free_rect: ut.Bounds(u32), splitter_rect: ut.Bounds(u32), res_buffer: []ut.Bounds) -> (count: u8) {
    fw := free_rect.width
    fh := free_rect.height
    sw := splitter_rect.width
    sh := splitter_rect.height

    ste := splitter_rect.y
    fte := free_rect.y
    sre := splitter_rect.width + splitter_rect.x
    fre := free_rect.width + free_rect.x
    sle := splitter_rect.x
    fle := free_rect.x
    sbe := splitter_rect.height + splitter_rect.y
    fbe := free_rect.height + free_rect.y

    r := res < ref
    l := les < lef
    t := tes < tef
    b := bes < bef

    if !r && !l && !t && !b {
        return 0
    }

    if r && l && t && b {
        copy(res_buffer, []ut.Bounds(u32){{
            //top
            height = abs(fte-ste),
            width = fw,
            x = fle,
            y = fte,
        }, {
            //bottom
            height = abs(fbe-sbe),
            width = fw,
            x = fle,
            y = sbe,
        }, {
            //left
            height = fh,
            width = abs(fle-sle),
            x = fle,
            y = fte,
        }, {
            //right
            height = fh,
            width = abs(fre-sre),
            x = sre,
            y = fte,
        }})
        return 4
    } 
    
    if r && l && t && !b {
        copy(res_buffer, []ut.Bounds(u32){{
            //top
            height = abs(fte-ste),
            width = fw,
            x = fle,
            y = fte,
        }, {
            //left
            height = fh,
            width = abs(fle-sle),
            x = fle,
            y = fte,
        }, {
            //right
            height = fh,
            width = abs(fre-sre),
            x = sre,
            y = fte,
        }})
        return 3
    } 
    
    if r && l && !t && b {
        copy(res_buffer, []ut.Bounds(u32){
        {  
            //bottom
            height = abs(fbe-sbe),
            width = fw,
            x = fle,
            y = sbe,
        }, {
            //left
            height = fh,
            width = abs(fle-sle),
            x = fle,
            y = fte,
        }, {
            //right
            height = fh,
            width = abs(fre-sre),
            x = sre,
            y = fte,
        }})
        return 3
    } 
    
    if r && l && !t && !b {
        copy(res_buffer, []ut.Bounds(u32){
        {
            //left
            height = fh,
            width = abs(fle-sle),
            x = fle,
            y = fte,
        }, {
            //right
            height = fh,
            width = abs(fre-sre),
            x = sre,
            y = fte,
        }})
        return 2
    } 
    
    if r && l && t && b {
        copy(res_buffer, []ut.Bounds(u32){{
            //top
            height = abs(fte-ste),
            width = fw,
            x = fle,
            y = fte,
        }, {
            //bottom
            height = abs(fbe-sbe),
            width = fw,
            x = fle,
            y = sbe,
        }, })
        return 2
    } 
}

maxrects_split_rectangle_simplification_guess :: proc(free_rect: ut.Bounds(u32), splitter_rect: ut.Bounds(u32), res_buffer: []ut.Bounds) -> (count: u8) {
    fw := free_rect.width
    fh := free_rect.height
    sw := splitter_rect.width
    sh := splitter_rect.height

    ste := splitter_rect.y
    fte := free_rect.y
    sre := splitter_rect.width + splitter_rect.x
    fre := free_rect.width + free_rect.x
    sle := splitter_rect.x
    fle := free_rect.x
    sbe := splitter_rect.height + splitter_rect.y
    fbe := free_rect.height + free_rect.y

    r := res < ref
    l := lef < les
    t := tef < tes
    b := bes < bef

    if !r && !l && !t && !b {
        return 0
    }

    if r && l && t && b {
        sa: small_array.Small_Array(4, ut.Bounds)
        if t {
            small_array.append(&sa, {
                height = abs(fte-ste),
                width = fw,
                x = fle,
                y = fte,
            })
        }
        if b {
            small_array.append(&sa, {
                height = abs(fbe-sbe),
                width = fw,
                x = fle,
                y = sbe,
            })
        }
        if l {
            small_array.append(&sa, {
                height = fh,
                width = abs(fle-sle),
                x = fle,
                y = fte,
            })
        }
        if r {
            small_array.append(&sa, {
                height = fh,
                width = abs(fre-sre),
                x = sre,
                y = fte,
            })
        }
        copy(res_buffer, sa.data[sa.len])
        return sa.len
    } 
}

pack_sprites_nonuniform_maxrects :: proc(id: $T) -> SpriteSheet(T) {
    
}
