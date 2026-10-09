package main

import ut "utils"
import "core:math"
import "core:testing"

// T should be floating point
collide_aabb :: proc(a: ut.Bounds($T), b: ut.Bounds(T)) -> (hit: bool, normal: [2]T, depth: T) {
    dx := (b.x + b.width / 2) - (a.x + a.width / 2)
    dy := (b.y + b.height / 2) - (a.y + a.height / 2)

    ox := (a.width + b.width) / 2 - math.abs(dx)
    oy := (a.height + b.height) / 2 - math.abs(dy)

    if ox <= 0 || oy <= 0 {
        return false, {0, 0}, 0
    }

    if ox < oy {
        return true, {dx > 0 ? 1 : -1, 0}, ox
    }

    return true, {0, dy > 0 ? 1 : -1}, oy
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

@(test)
test_aabb_asymmetric_overlap_top_left :: proc(t: ^testing.T) {
    hit, normal, depth := collide_aabb(
        ut.Bounds(f64){x = 10, y = 10, width = 8, height = 3},
        ut.Bounds(f64){x = 12, y = 8, width = 2, height = 6},
    )

    testing.expect_value(t, hit, true)
}

@(test)
test_aabb_asymmetric_overlap_top_right :: proc(t: ^testing.T) {
    hit, normal, depth := collide_aabb(
        ut.Bounds(f64){x = 10, y = 10, width = 8, height = 3},
        ut.Bounds(f64){x = 16, y = 8, width = 4, height = 6},
    )

    testing.expect_value(t, hit, true)
}

@(test)
test_aabb_asymmetric_overlap_bottom_left :: proc(t: ^testing.T) {
    hit, normal, depth := collide_aabb(
        ut.Bounds(f64){x = 10, y = 10, width = 8, height = 3},
        ut.Bounds(f64){x = 8, y = 11, width = 4, height = 5},
    )

    testing.expect_value(t, hit, true)
}

@(test)
test_aabb_asymmetric_overlap_bottom_right :: proc(t: ^testing.T) {
    hit, normal, depth := collide_aabb(
        ut.Bounds(f64){x = 10, y = 10, width = 8, height = 3},
        ut.Bounds(f64){x = 16, y = 11, width = 5, height = 4},
    )

    testing.expect_value(t, hit, true)
}

@(test)
test_aabb_asymmetric_a_inside_b :: proc(t: ^testing.T) {
    hit, normal, depth := collide_aabb(
        ut.Bounds(f64){x = 13, y = 12, width = 2, height = 1},
        ut.Bounds(f64){x = 10, y = 10, width = 10, height = 8},
    )

    testing.expect_value(t, hit, true)
}

@(test)
test_aabb_asymmetric_b_inside_a :: proc(t: ^testing.T) {
    hit, normal, depth := collide_aabb(
        ut.Bounds(f64){x = 10, y = 10, width = 10, height = 8},
        ut.Bounds(f64){x = 13, y = 12, width = 2, height = 1},
    )

    testing.expect_value(t, hit, true)
}

@(test)
test_aabb_asymmetric_negative_coordinates :: proc(t: ^testing.T) {
    hit, normal, depth := collide_aabb(
        ut.Bounds(f64){x = -12, y = -7, width = 9, height = 4},
        ut.Bounds(f64){x = -6, y = -9, width = 3, height = 6},
    )

    testing.expect_value(t, hit, true)
}

@(test)
test_aabb_asymmetric_far_apart :: proc(t: ^testing.T) {
    hit, normal, depth := collide_aabb(
        ut.Bounds(f64){x = 10, y = 10, width = 12, height = 2},
        ut.Bounds(f64){x = 10, y = 13, width = 2, height = 9},
    )

    testing.expect_value(t, hit, false)
}

@(test)
test_aabb_asymmetric_horizontal_gap :: proc(t: ^testing.T) {
    hit, normal, depth := collide_aabb(
        ut.Bounds(f64){x = 0, y = 0, width = 3, height = 12},
        ut.Bounds(f64){x = 4, y = 2, width = 8, height = 3},
    )

    testing.expect_value(t, hit, false)
}

@(test)
test_aabb_asymmetric_vertical_gap :: proc(t: ^testing.T) {
    hit, normal, depth := collide_aabb(
        ut.Bounds(f64){x = 0, y = 0, width = 12, height = 3},
        ut.Bounds(f64){x = 2, y = 4, width = 3, height = 8},
    )

    testing.expect_value(t, hit, false)
}
