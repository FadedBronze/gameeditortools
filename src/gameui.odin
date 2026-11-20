package main

import clay "project:clay-odin"

gameui :: proc() {
    if clay.UI()({
        layout = {
            padding = clay.PaddingAll(10),
            layoutDirection = .TopToBottom, 
        }
    }){
        if clay.UI()({
            layout = {
                sizing = clay.Sizing{
                    width = clay.SizingGrow(),
                    height = clay.SizingFixed(200)
                },
                layoutDirection = .LeftToRight, 
            }
        }){
            if clay.UI()({
                layout = {
                    sizing = clay.Sizing{
                        width = clay.SizingFixed(100),
                        height = clay.SizingGrow()
                    }
                }
            }){
                
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
                    }
                }){
                    if clay.UI()({
                        layout = {
                            sizing = clay.Sizing{
                                width = clay.SizingGrow(),
                                height = clay.SizingGrow()
                            }
                        }
                    }){
                    }

                    if clay.UI()({
                        layout = {
                            sizing = clay.Sizing{
                                width = clay.SizingGrow(),
                                height = clay.SizingGrow()
                            }
                        }
                    }){
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
                            }
                        }
                    }){
                    }
                    
                    if clay.UI()({
                        layout = {
                            sizing = clay.Sizing{
                                width = clay.SizingGrow(),
                                height = clay.SizingGrow()
                            }
                        }
                    }){
                    }
                }    
            }
        }
    }
}
