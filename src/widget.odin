package main

import "project:editorui"
import clay "project:clay-odin"
import ut "project:utils"

@(deferred_none=label_block_close)
label_block :: proc(label: string, editor_ui: ^editorui.EditorUI) -> bool {
    clay._OpenElement()
    clay.ConfigureOpenElement({
        layout = { 
            sizing = { width = clay.SizingPercent(1.0), height = clay.SizingFit({}) } ,
            childGap = 5,
        }, 
    })
    
    clay.Text(label, clay.TextElementConfig {
        letterSpacing = u16(editor_ui.theme.letter_spacing),
        fontSize = u16(editor_ui.theme.font_size),
        wrapMode = .Words,
        textColor = auto_cast ut.color_to_f32list(editor_ui.theme.text_color),
    })

    return true
}

label_block_close :: proc() {
    clay._CloseElement()
}

@(deferred_none=widget_block_close)
widget_block :: proc(label: string, editor_ui: ^editorui.EditorUI) -> bool {
    clay._OpenElement()
    clay.ConfigureOpenElement({
        layout = { 
            sizing = { width = clay.SizingGrow({}), height = clay.SizingFit({}) } ,
            childGap = 5,
            layoutDirection = .TopToBottom,
            padding = clay.PaddingAll(10),
        }, 
        backgroundColor = auto_cast ut.color_to_f32list(ut.change_opacity(ut.get_contrasting_color(editor_ui.theme.background_color), 20)),
    })
    
    clay.Text(label, clay.TextElementConfig {
        fontSize = u16(editor_ui.theme.font_size)*5/4,
        wrapMode = .Words,
        letterSpacing = u16(editor_ui.theme.letter_spacing),
        textColor = auto_cast ut.color_to_f32list(editor_ui.theme.text_color),
    })
    
    clay._OpenElement()
    clay.ConfigureOpenElement({
        layout = { 
            sizing = { width = clay.SizingGrow({}), height = clay.SizingGrow({}) } ,
            childGap = 5,
            layoutDirection = .TopToBottom,
        }, 
    })

    return true
}

widget_block_close :: proc() {
    clay._CloseElement()
    clay._CloseElement()
}
