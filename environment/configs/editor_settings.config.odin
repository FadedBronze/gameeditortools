// if you want to see this generator create something else 
// modify the structure under ./config_generator/scone_generator.odin 

// this file is not read by the odin compiler
// its a config file that uses the same syntax and
// sits in same directory as the type for lsp completion

package configs

import main "project:src"

editor_settings_config: main.EditorSettings = {
    // options = WorldViewports, Player, State, TileEditor, Entities
    open_views = { .Player, .State, .TileEditor },
    selected_tile = {
        environment = {
            // options = Exists, Blocked
            flags = {},
            sprite = .ChoosePlus,
        },
    },
    // options = ShowGridOuterBounds
    flags = {},
    active_tool = .CameraControl,
}