package main

import ut "utils"

import "core:math"
import "core:mem"
import "core:testing"

GridPosition :: [2]i32

Grid :: struct(T: typeid) {
    bounds: ut.Bounds(i32) "group",
    tiles: []T,
}

// ========= utils ===========

create_tile :: proc(appdata: ^AppData, position: GridPosition) {
    set_tile_base(&appdata.grid, position, appdata.editor_settings.selected_tile);
}

copy_grid :: proc(grid: Grid($T), allocator: mem.Allocator) -> Grid(T) {
    new_grid := grid
    new_grid.tiles = make([]T, len(grid.tiles), allocator)
    copy(new_grid.tiles, grid.tiles)
    return new_grid
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

// ========= tests ===========

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
