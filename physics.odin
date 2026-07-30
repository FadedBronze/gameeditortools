package main

import ut "utils"
import "core:math"

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
