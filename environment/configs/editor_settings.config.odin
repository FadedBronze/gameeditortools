// if you want to see this generator create something else 
// modify the structure under ./config_generator/scone_generator.odin 

// this file is not read by the odin compiler
// its a config file that uses the same syntax and
// sits in same directory as the type for lsp completion

package configs

import main "project:src"

editor_settings_config: main.EditorSettings = {
    // options = WorldViewports, Player, State, TileEditor, Entities
    open_views = {},
    selected_tile = {
        environment = {
            // options = Exists, Blocked
            flags = {},
            sprite = .ChoosePlus,
        },
    },
    placing_entity = {
        // options = Something, Physics, DrawHitbox
        flags = {},
        velocity = {
            +0.000000,
            +0.000000,
        },
        physics_surface = {
            restitution = +0.000000,
            friction = +0.000000,
        },
        hitbox = {
            x = +0.000000,
            y = +0.000000,
            width = +0.000000,
            height = +0.000000,
        },
        transform = {
            scale = {
                +0.000000,
                +0.000000,
            },
            offset = {
                +0.000000,
                +0.000000,
            },
            rotation_rad = +0.000000,
        },
        sprite = .ChoosePlus,
    },
    // options = ShowGridOuterBounds, EntityPlaceSnapGrid
    flags = {},
    active_tool = .CameraControl,
}