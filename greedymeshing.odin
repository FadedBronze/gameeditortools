package main

import ut "utils"
import "core:testing"

greedy_mesh_grid_into_aabb_list :: proc(
    grid: Grid(Tile), 
    allocator := context.allocator, 
    temp_allocator := context.temp_allocator
) -> (gridspace_bounds: []ut.Bounds(f64)) {
    filled_grid: Grid(bool)
    resize_grid(&filled_grid, grid.bounds, temp_allocator)

    simplified_collision_hitboxes := make([dynamic]ut.Bounds(f64))

    min_x := grid.bounds.x;
    max_x := min_x + grid.bounds.width;

    min_y := grid.bounds.y;
    max_y := min_y + grid.bounds.height;

    for y in min_y..<max_y {
        x := min_x

        new_collision_row_start: i32 = 0;
        new_collision_row_start_found := false;

        for x < max_x {
            empty := .Blocked not_in get_tile(grid, {x, y}).environment.flags;
            filled := get_tile(filled_grid, {x, y});
            
            if !new_collision_row_start_found  {
                if !empty && !filled {
                    new_collision_row_start = x;
                    new_collision_row_start_found = true;
                }
            } else {
                if empty || filled {
                    new_collision_row_end := x;

                    collision_hitbox_y_layers: i32 = 0;
                    complete_row := true;
                    
                    for y + collision_hitbox_y_layers < max_y && complete_row {
                        for row_x in new_collision_row_start..<new_collision_row_end {
                            row_empty := .Blocked not_in get_tile(grid, {row_x, y+collision_hitbox_y_layers}).environment.flags;
                            row_filled := get_tile(filled_grid, {row_x, y+collision_hitbox_y_layers});

                            if row_empty || row_filled {
                                complete_row = false;
                                break;
                            }
                        }

                        if complete_row {
                            for row_x in new_collision_row_start..<new_collision_row_end {
                                set_tile(&filled_grid, {row_x, y+collision_hitbox_y_layers}, true);
                            }

                            collision_hitbox_y_layers += 1;
                        }
                    }

                    append(&simplified_collision_hitboxes, ut.Bounds(f64) {
                        width = f64(new_collision_row_end - new_collision_row_start),
                        height = f64(collision_hitbox_y_layers),
                        x = f64(new_collision_row_start),
                        y = f64(y),
                    });

                    new_collision_row_start_found = false;
                }
            }

            x += 1;
        }
    }

    return simplified_collision_hitboxes[0:]
}

@(test)
test_greedy_meshing_negative :: proc(t: ^testing.T) {
    // simple collidable tile
    s: Tile;
    s.environment.flags = { .Blocked, .Exists };

    grid: Grid(Tile)

    resize_grid(&grid, ut.Bounds(i32){
        x = -4,
        y = -3,
        width = 11,
        height = 9,
    }, context.allocator);

    set_tile(&grid, {-3, -2}, s);
    set_tile(&grid, {-3, -1}, s);
    set_tile(&grid, {-3, 0}, s);
    set_tile(&grid, {-3, 1}, s);
    
    set_tile(&grid, {-2, -2}, s);
    set_tile(&grid, {-2, -1}, s);
    set_tile(&grid, {-2, 0}, s);
    set_tile(&grid, {-2, 1}, s);
    
    set_tile(&grid, {-1, -2}, s);
    set_tile(&grid, {-1, -1}, s);
    set_tile(&grid, {-1, 0}, s);
    set_tile(&grid, {-1, 1}, s);
    
    set_tile(&grid, {0, -2}, s);
    set_tile(&grid, {0, -1}, s);
    set_tile(&grid, {0, 0}, s);
    
    set_tile(&grid, {1, -2}, s);
    set_tile(&grid, {1, -1}, s);
    set_tile(&grid, {1, 0}, s);
    set_tile(&grid, {1, 4}, s);
    
    set_tile(&grid, {2, 0}, s);
    set_tile(&grid, {2, 4}, s);
    
    set_tile(&grid, {3, 0}, s);
    set_tile(&grid, {3, 1}, s);
    set_tile(&grid, {3, 2}, s);
    set_tile(&grid, {3, 3}, s);
    set_tile(&grid, {3, 4}, s);
    
    set_tile(&grid, {4, 0}, s);
    set_tile(&grid, {4, 1}, s);
    set_tile(&grid, {4, 2}, s);
    set_tile(&grid, {4, 3}, s);
    set_tile(&grid, {4, 4}, s);

    set_tile(&grid, {5, 0}, s);
    set_tile(&grid, {5, 1}, s);
    set_tile(&grid, {5, 2}, s);
    set_tile(&grid, {5, 3}, s);
    set_tile(&grid, {5, 4}, s);

    bounds := greedy_mesh_grid_into_aabb_list(grid)

    expected_bounds: []ut.Bounds(f64) = {
        ut.Bounds(f64) {
            x = -3,
            y = -2,
            width = 5,
            height = 3,
        },
        ut.Bounds(f64) {
            x = 2,
            y = 0,
            width = 4,
            height = 1,
        },
        ut.Bounds(f64) {
            x = -3,
            y = 1,
            width = 3,
            height = 1,
        },
        ut.Bounds(f64) {
            x = 3,
            y = 1,
            width = 3,
            height = 4,
        },
        ut.Bounds(f64) {
            x = 1,
            y = 4,
            width = 2,
            height = 1,
        },
    }

    for bound, i in bounds {
        testing.expect_value(t, bound, expected_bounds[i]);
    }
}

@(test)
test_greedy_meshing_complex :: proc(t: ^testing.T) {
    // simple collidable tile
    s: Tile;
    s.environment.flags = { .Blocked, .Exists };

    grid: Grid(Tile)

    resize_grid(&grid, ut.Bounds(i32){
        x = 0,
        y = 0,
        width = 11,
        height = 9,
    }, context.allocator);

    set_tile(&grid, {1, 1}, s);
    set_tile(&grid, {1, 2}, s);
    
    set_tile(&grid, {2, 1}, s);
    set_tile(&grid, {2, 2}, s);
    set_tile(&grid, {2, 6}, s);
    set_tile(&grid, {2, 7}, s);

    set_tile(&grid, {3, 1}, s);
    set_tile(&grid, {3, 2}, s);
    set_tile(&grid, {3, 3}, s);
    set_tile(&grid, {3, 4}, s);
    set_tile(&grid, {3, 5}, s);
    set_tile(&grid, {3, 6}, s);
    set_tile(&grid, {3, 7}, s);
    
    set_tile(&grid, {4, 2}, s);
    set_tile(&grid, {4, 3}, s);
    set_tile(&grid, {4, 4}, s);
    set_tile(&grid, {4, 5}, s);
    set_tile(&grid, {4, 6}, s);
    set_tile(&grid, {4, 7}, s);
    
    set_tile(&grid, {5, 2}, s);
    set_tile(&grid, {5, 3}, s);
    set_tile(&grid, {5, 4}, s);
    set_tile(&grid, {5, 5}, s);
    
    set_tile(&grid, {6, 2}, s);
    set_tile(&grid, {6, 3}, s);
    set_tile(&grid, {6, 4}, s);
    set_tile(&grid, {6, 5}, s);
    
    set_tile(&grid, {7, 4}, s);
    set_tile(&grid, {7, 5}, s);
    
    set_tile(&grid, {8, 4}, s);
    set_tile(&grid, {8, 5}, s);
    
    set_tile(&grid, {9, 1}, s);
    set_tile(&grid, {9, 2}, s);
    set_tile(&grid, {9, 3}, s);
    set_tile(&grid, {9, 4}, s);
    set_tile(&grid, {9, 5}, s);
    set_tile(&grid, {9, 6}, s);
    set_tile(&grid, {9, 7}, s);

    bounds := greedy_mesh_grid_into_aabb_list(grid)

    expected_bounds: []ut.Bounds(f64) = {
        ut.Bounds(f64) {
            x = 1,
            y = 1,
            width = 3,
            height = 2,
        },
        ut.Bounds(f64) {
            x = 9,
            y = 1,
            width = 1,
            height = 7,
        },
        ut.Bounds(f64) {
            x = 4,
            y = 2,
            width = 3,
            height = 4,
        },
        ut.Bounds(f64) {
            x = 3,
            y = 3,
            width = 1,
            height = 5,
        },
        ut.Bounds(f64) {
            x = 7,
            y = 4,
            width = 2,
            height = 2,
        },
        ut.Bounds(f64) {
            x = 2,
            y = 6,
            width = 1,
            height = 2,
        },
        ut.Bounds(f64) {
            x = 4,
            y = 6,
            width = 1,
            height = 2,
        },
    }

    for bound, i in bounds {
        testing.expect_value(t, bound, expected_bounds[i]);
    }
}
