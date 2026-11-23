package main

import clay "project:clay-odin"
import ut "project:utils"

gameui :: proc() {
    if clay.UI()({
        layout = {
            padding = clay.PaddingAll(10),
            layoutDirection = .TopToBottom, 
            sizing = {
                height = clay.SizingPercent(1.0),
                width = clay.SizingPercent(1.0),
            }
        },
    }){
        if clay.UI()({
            layout = {
                sizing = clay.Sizing{
                    height = clay.SizingGrow(),
                    width = clay.SizingGrow()
                }
            }
        }) {}

        if clay.UI()({
            layout = {
                sizing = clay.Sizing{
                    width = clay.SizingGrow(),
                    height = clay.SizingFixed(150)
                },
                layoutDirection = .LeftToRight, 
            },
            backgroundColor = ut.color_to_f32list(ut.change_opacity(ut.WHITE, 55)),
        }){
            // menu selection - items, attack
            if clay.UI()({
                layout = {
                    sizing = clay.Sizing{
                        width = clay.SizingFixed(100),
                        height = clay.SizingGrow()
                    },
                    layoutDirection = .TopToBottom,
                },
                backgroundColor = ut.color_to_f32list(ut.change_opacity(ut.BLACK, 55)),
            }){
                if clay.UI()({
                    layout = {
                        padding = clay.PaddingAll(10),
                        sizing = clay.Sizing{
                            width = clay.SizingGrow(),
                            height = clay.SizingFit()
                        }
                    },
                    backgroundColor = ut.color_to_f32list(ut.change_opacity(ut.BLUE, 55)),
                }){
                    clay.Text("Items", clay.TextElementConfig{
                        textColor = ut.color_to_f32list(ut.BLACK),
                        fontSize = 16,
                        letterSpacing = 0,
                    })
                }
                
                if clay.UI()({
                    layout = {
                        padding = clay.PaddingAll(10),
                        sizing = clay.Sizing{
                            width = clay.SizingGrow(),
                            height = clay.SizingFit()
                        }
                    },
                    backgroundColor = ut.color_to_f32list(ut.change_opacity(ut.RED, 55)),
                }){
                    clay.Text("Attack", clay.TextElementConfig{
                        textColor = ut.color_to_f32list(ut.BLACK),
                        fontSize = 16,
                        letterSpacing = 0,
                    })
                }
            }
            
            if clay.UI()({
                layout = {
                    sizing = clay.Sizing{
                        width = clay.SizingGrow(),
                        height = clay.SizingGrow()
                    },
                    layoutDirection = .TopToBottom,
                }
            }){
                if clay.UI()({
                    layout = {
                        sizing = clay.Sizing{
                            width = clay.SizingGrow(),
                            height = clay.SizingGrow()
                        },
                        layoutDirection = .LeftToRight,
                    },
                }){
                    if clay.UI()({
                        layout = {
                            sizing = clay.Sizing{
                                width = clay.SizingGrow(),
                                height = clay.SizingGrow()
                            },
                            childAlignment = {
                                x = .Center,
                                y = .Center,
                            }
                        },
                        backgroundColor = ut.color_to_f32list(ut.change_opacity(ut.BLUE, 55)),
                    }){
                        clay.Text("Attack1", clay.TextElementConfig{
                            textColor = ut.color_to_f32list(ut.BLACK),
                            fontSize = 16,
                            letterSpacing = 0,
                        })
                    }

                    if clay.UI()({
                        layout = {
                            sizing = clay.Sizing{
                                width = clay.SizingGrow(),
                                height = clay.SizingGrow()
                            },
                            childAlignment = {
                                x = .Center,
                                y = .Center,
                            }
                        },
                        backgroundColor = ut.color_to_f32list(ut.change_opacity(ut.GREEN, 55)),
                    }){
                        clay.Text("Attack2", clay.TextElementConfig{
                            textColor = ut.color_to_f32list(ut.BLACK),
                            fontSize = 16,
                            letterSpacing = 0,
                        })
                    }
                }    

                if clay.UI()({
                    layout = {
                        sizing = clay.Sizing{
                            width = clay.SizingGrow(),
                            height = clay.SizingGrow()
                        }
                    }
                }){
                    if clay.UI()({
                        layout = {
                            sizing = clay.Sizing{
                                width = clay.SizingGrow(),
                                height = clay.SizingGrow()
                            },
                            childAlignment = {
                                x = .Center,
                                y = .Center,
                            }
                        },
                        backgroundColor = ut.color_to_f32list(ut.change_opacity(ut.RED, 55)),
                    }){
                        clay.Text("Attack3", clay.TextElementConfig{
                            textColor = ut.color_to_f32list(ut.BLACK),
                            fontSize = 16,
                            letterSpacing = 0,
                        })
                    }
                    
                    if clay.UI()({
                        layout = {
                            sizing = clay.Sizing{
                                width = clay.SizingGrow(),
                                height = clay.SizingGrow()
                            },
                            childAlignment = {
                                x = .Center,
                                y = .Center,
                            }
                        },
                        backgroundColor = ut.color_to_f32list(ut.change_opacity(ut.ORANGE, 55)),
                    }){
                        clay.Text("Attack4", clay.TextElementConfig{
                            textColor = ut.color_to_f32list(ut.BLACK),
                            fontSize = 16,
                            letterSpacing = 0,
                        })
                    }
                }    
            }
        }
    }
}
