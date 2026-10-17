// if you want to see this generator create something else 
// modify the structure under ./config_generator/scone_generator.odin 

// this file is not read by the odin compiler
// its a config file that uses the same syntax and
// sits in same directory as the type for lsp completion

package configs

import edui "project:editorui"

theme_settings_config: edui.EditorUITheme = {
    letter_spacing = 0,
    font_size = 16,
    text_color = {
        176,
        210,
        255,
        255,
    },
    background_color = {
        2,
        0,
        48,
        35,
    },
    highlight_color = {
        78,
        19,
        0,
        119,
    },
}