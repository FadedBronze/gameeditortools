package main

import ut "utils"
import "core:math"
import "core:testing"

// T should be floating point
collide_aabb :: proc(a: ut.Bounds($T), b: ut.Bounds(T)) -> (hit: bool, normal: [2]T, depth: T) {
    dx := b.x - a.x    
    dy := b.y - a.y
    
    ox := a.width/2 + b.width/2 - math.abs(dx)
    if ox <= 0 {
        return false, {0, 0}, 0
    }

    oy := a.height/2 + b.height/2 - math.abs(dy)
    if oy <= 0 {
        return false, {0, 0}, 0
    }

    if ox < oy {
        return true, {dx > 0 ? 1.0 : 0, 0}, ox
    } else {
        return true, {0, dy > 0 ? 1.0 : 0}, oy
    }
}

// GPTed tests

@(test)
test_aabb :: proc(t: ^testing.T) {
    hit, normal, depth := collide_aabb(
        ut.Bounds(f64){x = 5, y = 5, width = 4, height = 4},
        ut.Bounds(f64){x = 8, y = 8, width = 4, height = 4},
    )

    testing.expect_value(t, hit, true)
    testing.expect_value(t, depth, 1.0)
}

@(test)
test_aabb_no_overlap :: proc(t: ^testing.T) {
    hit, normal, depth := collide_aabb(
        ut.Bounds(f64){x = 0, y = 0, width = 4, height = 4},
        ut.Bounds(f64){x = 10, y = 10, width = 4, height = 4},
    )

    testing.expect_value(t, hit, false)
}

@(test)
test_aabb_separated_x :: proc(t: ^testing.T) {
    hit, normal, depth := collide_aabb(
        ut.Bounds(f64){x = 0, y = 0, width = 4, height = 4},
        ut.Bounds(f64){x = 5, y = 0, width = 4, height = 4},
    )

    testing.expect_value(t, hit, false)
}

@(test)
test_aabb_separated_y :: proc(t: ^testing.T) {
    hit, normal, depth := collide_aabb(
        ut.Bounds(f64){x = 0, y = 0, width = 4, height = 4},
        ut.Bounds(f64){x = 0, y = 5, width = 4, height = 4},
    )

    testing.expect_value(t, hit, false)
}

@(test)
test_aabb_touching_edge :: proc(t: ^testing.T) {
    hit, normal, depth := collide_aabb(
        ut.Bounds(f64){x = 0, y = 0, width = 4, height = 4},
        ut.Bounds(f64){x = 4, y = 0, width = 4, height = 4},
    )

    testing.expect_value(t, hit, false)
}

@(test)
test_aabb_touching_corner :: proc(t: ^testing.T) {
    hit, normal, depth := collide_aabb(
        ut.Bounds(f64){x = 0, y = 0, width = 4, height = 4},
        ut.Bounds(f64){x = 4, y = 4, width = 4, height = 4},
    )

    testing.expect_value(t, hit, false)
}

@(test)
test_aabb_contained :: proc(t: ^testing.T) {
    hit, normal, depth := collide_aabb(
        ut.Bounds(f64){x = 0, y = 0, width = 10, height = 10},
        ut.Bounds(f64){x = 2, y = 2, width = 2, height = 2},
    )

    testing.expect_value(t, hit, true)
}

@(test)
test_aabb_identical :: proc(t: ^testing.T) {
    hit, normal, depth := collide_aabb(
        ut.Bounds(f64){x = 0, y = 0, width = 4, height = 4},
        ut.Bounds(f64){x = 0, y = 0, width = 4, height = 4},
    )

    testing.expect_value(t, hit, true)
}

@(test)
test_aabb_partial_x_overlap :: proc(t: ^testing.T) {
    hit, normal, depth := collide_aabb(
        ut.Bounds(f64){x = 0, y = 0, width = 4, height = 4},
        ut.Bounds(f64){x = 3, y = 1, width = 4, height = 4},
    )

    testing.expect_value(t, hit, true)
}

@(test)
test_aabb_partial_y_overlap :: proc(t: ^testing.T) {
    hit, normal, depth := collide_aabb(
        ut.Bounds(f64){x = 0, y = 0, width = 4, height = 4},
        ut.Bounds(f64){x = 1, y = 3, width = 4, height = 4},
    )

    testing.expect_value(t, hit, true)
}

@(test)
test_aabb_symmetry :: proc(t: ^testing.T) {
    a := ut.Bounds(f64){x = 0, y = 0, width = 4, height = 4}
    b := ut.Bounds(f64){x = 3, y = 1, width = 4, height = 4}

    hit_ab, normal_ab, depth_ab := collide_aabb(a, b)
    hit_ba, normal_ba, depth_ba := collide_aabb(b, a)

    testing.expect_value(t, hit_ab, true)
    testing.expect_value(t, hit_ba, true)
    testing.expect_value(t, depth_ab, depth_ba)
}
