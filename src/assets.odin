package main

import ut "project:utils"
import rl "vendor:raylib"
import "core:container/small_array"
import "core:math/rand"
import "core:fmt"

SpriteSheet :: union(T: typeid) {
    UniformSpritesheet,
    NonuniformAABBSpriteSheet,
}

NonuniformAABBSpriteSheet :: struct {
    bounds: []ut.Bounds(i32),
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

maxrects_split_rectangle_simplification :: proc(free_rect: ut.Bounds(i32), splitter_rect: ut.Bounds(i32), res_buffer: []ut.Bounds(i32)) -> (count: u8) {
    if !ut.overlapping_bounds(free_rect, splitter_rect) {
        res_buffer[0] = free_rect
        return 1
    }

    fw := free_rect.width
    fh := free_rect.height

    ste := splitter_rect.y
    fte := free_rect.y
    sre := splitter_rect.width + splitter_rect.x
    fre := free_rect.width + free_rect.x
    sle := splitter_rect.x
    fle := free_rect.x
    sbe := splitter_rect.height + splitter_rect.y
    fbe := free_rect.height + free_rect.y

    // we don't want to add an extra free rect on equals because they'd be empty
    r := sre < fre
    l := fle < sle
    t := fte < ste
    b := sbe < fbe

    if !r && !l && !t && !b {
        return 0
    }

    sa: small_array.Small_Array(4, ut.Bounds(i32))

    if t {
        small_array.append_elem(&sa, ut.Bounds(i32){
            height = abs(fte-ste),
            width = fw,
            x = fle,
            y = fte,
        })
    }

    if b {
        small_array.append_elem(&sa, ut.Bounds(i32){
            height = abs(fbe-sbe),
            width = fw,
            x = fle,
            y = sbe,
        })
    }

    if l {
        small_array.append_elem(&sa, ut.Bounds(i32){
            height = fh,
            width = abs(fle-sle),
            x = fle,
            y = fte,
        })
    }

    if r {
        small_array.append_elem(&sa, ut.Bounds(i32){
            height = fh,
            width = abs(fre-sre),
            x = sre,
            y = fte,
        })
    }

    copy(res_buffer, sa.data[0:sa.len])
    return u8(sa.len)
}

Sprite :: struct {
    bounds: ut.Bounds(i32),
    rotated_90: bool,
}

pack_random_sprites_and_output :: proc(gen := context.random_generator) { 
    textures: [dynamic]rl.Texture

    for i in 0..<30 {
        w := rand.int32_range(24, 128, gen)
        h := rand.int32_range(24, 128, gen)

        random_sprite := rl.LoadRenderTexture(w, h)

        rl.BeginTextureMode(random_sprite)
        rl.ClearBackground(transmute(rl.Color)ut.random_rgb_color(gen))
        rl.EndTextureMode()

        append_elem(&textures, random_sprite.texture)
    }

    success, fulltexture, sprites := pack_raylib_textures_maxrects(u32, textures[:], 512, 512)

    if success {
        img := rl.LoadImageFromTexture(fulltexture)
        rl.ExportImage(img, "./megatex.png")
    }
}

pack_raylib_textures_maxrects :: proc($T: typeid, textures: []rl.Texture, width: i32, height: i32) -> (bool, rl.Texture, []Sprite) {
    free_rects := make([dynamic]ut.Bounds(i32))
    append(&free_rects, ut.Bounds(i32) {
        x = 0,
        y = 0,
        width = width,
        height = height,
    })

    sprites := make([dynamic]Sprite)
    output_texture := rl.LoadRenderTexture(width, height)

    rl.BeginTextureMode(output_texture)

    for texture in textures {
        // best short side fit
        bignum: i32 = 10000000
        best_ssf_score := bignum
        best_ssf_rotated: bool = false
        best_ssf_free_rect := -1

        for free_rect, i in free_rects {
            min_ssf_score: i32
            min_sff_rotated: bool

            if texture.width < texture.height {
                ssf_score := free_rect.width - texture.width
                sff_rot_score := free_rect.height - texture.width

                lsf_fits := free_rect.height - texture.height >= 0
                lsf_rot_fits := free_rect.width - texture.height >= 0

                min_ssf_score = min(lsf_fits && ssf_score>=0 ? ssf_score : bignum, lsf_rot_fits && sff_rot_score>=0 ? sff_rot_score : bignum)
                min_sff_rotated = min_ssf_score == sff_rot_score
            } else {
                ssf_score := free_rect.height - texture.height
                sff_rot_score := free_rect.width - texture.height
                
                lsf_fits := free_rect.width - texture.width >= 0
                lsf_rot_fits := free_rect.height - texture.width >= 0

                min_ssf_score = min(lsf_fits && ssf_score>=0 ? ssf_score : bignum, lsf_rot_fits && sff_rot_score>=0 ? sff_rot_score : bignum)
                min_sff_rotated = min_ssf_score == sff_rot_score
            }

            if min_ssf_score < best_ssf_score {
                best_ssf_score = min_ssf_score
                best_ssf_rotated = min_sff_rotated
                best_ssf_free_rect = i
            }
        }

        rect := free_rects[best_ssf_free_rect]

        splitter: ut.Bounds(i32)
        // TODO: add to sprites list
        if best_ssf_rotated {
            splitter = ut.Bounds(i32) {
                x = rect.x,
                y = rect.y,
                width = texture.height,
                height = texture.width, 
            }
        } else {
            splitter = ut.Bounds(i32) {
                x = rect.x,
                y = rect.y,
                width = texture.width,
                height = texture.height,
            }
        }

        // we have to split all of them not just the one we found
        length := len(free_rects)
        new_free_rects := make([dynamic]ut.Bounds(i32))

        for free_rect in free_rects {
            buf: [4]ut.Bounds(i32)
            count := maxrects_split_rectangle_simplification(free_rect, splitter, buf[:])

            for b in buf[0:count] {
                assert(!ut.overlapping_bounds(splitter, b))
                append_elem(&new_free_rects, b)
            }
        }

        free_rects = new_free_rects

        append_elem(&sprites, Sprite {
            rotated_90 = best_ssf_rotated,
            bounds = splitter,
        })

        rl.DrawTextureRec(
            texture, 
            rl.Rectangle{
                x = auto_cast splitter.x,
                y = auto_cast splitter.y,
                width = auto_cast splitter.width,
                height = auto_cast splitter.height
            },
            rl.Vector2{f32(rect.x), f32(rect.y)},
            rl.WHITE,
        )
    }
    
    rl.EndTextureMode()

    return true, output_texture.texture, sprites[:]
}
