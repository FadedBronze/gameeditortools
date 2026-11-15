package main

import "base:runtime"
import clay "project:clay-odin"

import "project:editorui"
import ut "project:utils"

import "core:mem"
import "core:time"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:slice"

FileViewer :: struct {
    current_path: string,
    root_path: string,
    tree: AssetTreeIndex,
}

AssetFile :: struct {
    name: string,
    modifed: time.Time,
    size: i64,
    parent: ^AssetDirectory,
}

AssetDirectory :: struct {
    path: string,
    children: []AssetFileTree,
    parent: ^AssetDirectory,
}

AssetFileTree :: union {
    AssetDirectory,
    AssetFile
}

AssetTreeIndex :: struct {
    root: AssetFileTree,
    index: AssetTreeMap,
}

AssetTreeMap :: map[string]^AssetDirectory

load_all_files_into_structure :: proc(structure: ^AssetTreeIndex, base_path: string, frame_allocator: mem.Allocator, init_allocator: mem.Allocator) {
    f, err := os.open(base_path)
    
    structure.index = make(map[string]^AssetDirectory)
    structure.root = AssetDirectory {
        path = base_path
    }

    if err == nil {
        load_all_files_into_structure_recurse(f, &structure.root.(AssetDirectory), &structure.index, frame_allocator, init_allocator)
        map_insert(&structure.index, base_path, &structure.root.(AssetDirectory))
    } else {
        fmt.eprintln("open directory error", err)
    }
}

load_all_files_into_structure_recurse :: proc(f: ^os.File, root: ^AssetDirectory, index: ^AssetTreeMap, frame_allocator: mem.Allocator, init_allocator: mem.Allocator) {
    children: [dynamic]AssetFileTree
    fi, err := os.read_directory(f, 0, frame_allocator)

    if err == nil {
        for &file in fi {
            if file.type == .Directory {
                f, err := os.open(file.fullpath)
                if err == nil {
                    path_clone, err := strings.clone(file.fullpath, init_allocator)
                    assert(err == nil, message="init allocator memory ran out")
                    append(&children, AssetDirectory {
                        path = path_clone,
                        parent = root,
                    })
                    load_all_files_into_structure_recurse(f, &children[len(children)-1].(AssetDirectory), index, frame_allocator, init_allocator)
                    map_insert(index, file.fullpath, &children[len(children)-1].(AssetDirectory))
                } else {
                    fmt.eprintln("open directory error", err)
                }
            }

            if file.type == .Regular {
                name_clone, err := strings.clone(file.name, init_allocator)
                assert(err == nil, message="init allocator memory ran out")
                append(&children, AssetFile {
                    parent = root,
                    name = name_clone,
                    size = file.size,
                    modifed = file.modification_time,
                })
            }
        }
    } else {
        fmt.eprintln("read directory error", err)
    }

    root.children = children[:]
}

init_fileviewer_data_with_cwd :: proc(file_viewer: ^FileViewer, init_allocator: mem.Allocator, frame_allocator: mem.Allocator) {
    dir, err := os.get_working_directory(init_allocator)

    if err != nil {
        fmt.println("error getting cwd", err)
        assert(false)
    }

    file_viewer.current_path = dir
    file_viewer.root_path = dir
    load_all_files_into_structure(&file_viewer.tree, file_viewer.root_path, frame_allocator, init_allocator)

    //for key, _ in file_viewer.tree.index {
    //    fmt.println(key)
    //}
}

fileviewer :: proc(editor_ui: ^editorui.EditorUI, file_viewer: ^FileViewer, init_allocator: mem.Allocator, frame_allocator: mem.Allocator) {
    if clay.UI()({ 
        layout = { 
            layoutDirection = .LeftToRight,
            childGap = 5,
            sizing = { width = clay.SizingPercent(1), height = clay.SizingGrow() } 
        }, 
    }) {
        if clay.UI()({ 
            backgroundColor = auto_cast ut.color_to_f32list(ut.change_opacity(ut.get_contrasting_color(editor_ui.theme.background_color), 20)),
            layout = { 
                sizing = { width = clay.SizingGrow({ max = 200 }), height = clay.SizingGrow() } 
            }, 
        }) {
        }

        if clay.UI()({ 
            backgroundColor = auto_cast ut.color_to_f32list(ut.change_opacity(ut.get_contrasting_color(editor_ui.theme.background_color), 20)),
            layout = { 
                sizing = { width = clay.SizingGrow(), height = clay.SizingGrow() },
                layoutDirection = .TopToBottom,
                childGap = 0
            }, 
        }) {
            splitpath := strings.split(file_viewer.current_path, "/", frame_allocator)

            if file_viewer.tree.index[file_viewer.current_path].parent != nil {
                if clay.UI()({ 
                    backgroundColor = auto_cast ut.color_to_f32list(
                        ut.change_opacity(ut.get_contrasting_color(editor_ui.theme.background_color), 
                        clay.Hovered() ? 30 : 0
                    )),
                    layout = { 
                        padding = clay.Padding {0, 0, 2, 2},
                        sizing = { width = clay.SizingGrow(), height = clay.SizingFit() } 
                    }, 
                }) {
                    clay.OnHover(proc "c" (id: clay.ElementId, pointerData: clay.PointerData, userData: rawptr) {
                        file_viewer: ^FileViewer = auto_cast userData

                        if pointerData.state == .ReleasedThisFrame {
                            context = runtime.default_context()
                            //fmt.println(file_viewer.tree.index[file_viewer.current_path].parent.path)
                            file_viewer.current_path = file_viewer.tree.index[file_viewer.current_path].parent.path
                        }
                    }, file_viewer)

                    clay.Text("..", clay.TextElementConfig{
                        fontSize = auto_cast editor_ui.theme.font_size,
                        letterSpacing = auto_cast editor_ui.theme.letter_spacing,
                        textColor = ut.color_to_f32list(editor_ui.theme.text_color),
                    })
                }
            }

            for file, i in file_viewer.tree.index[file_viewer.current_path].children {
                switch v in file {
                case AssetDirectory:
                    if clay.UI(clay.ID(v.path))({ 
                        backgroundColor = auto_cast ut.color_to_f32list(
                            ut.change_opacity(ut.get_contrasting_color(editor_ui.theme.background_color), 
                            clay.Hovered() ? 30 : (i % 2 == 0 ? 20 : 0)
                        )),
                        layout = { 
                            padding = clay.Padding {0, 0, 2, 2},
                            sizing = { width = clay.SizingGrow(), height = clay.SizingFit() } 
                        }, 
                    }) {
                        clay.OnHover(proc "c" (id: clay.ElementId, pointerData: clay.PointerData, userData: rawptr) {
                            file_viewer: ^FileViewer = auto_cast userData

                            if pointerData.state == .ReleasedThisFrame {
                                file_viewer.current_path = string(slice.from_ptr(id.stringId.chars, auto_cast id.stringId.length))
                            }
                        }, file_viewer)

                        splitpath := strings.split(v.path, "/", frame_allocator)
                        clay.Text(splitpath[len(splitpath)-1], clay.TextElementConfig{
                            fontSize = auto_cast editor_ui.theme.font_size,
                            letterSpacing = auto_cast editor_ui.theme.letter_spacing,
                            textColor = ut.color_to_f32list(editor_ui.theme.text_color),
                        })
                    }
                case AssetFile:
                    if clay.UI()({ 
                        backgroundColor = auto_cast ut.color_to_f32list(ut.change_opacity(ut.get_contrasting_color(editor_ui.theme.background_color), i % 2 == 0 ? 20 : 0)),
                        layout = { 
                            padding = clay.Padding {0, 0, 2, 2},
                            sizing = { width = clay.SizingGrow(), height = clay.SizingFit() } 
                        }, 
                    }) {
                        clay.Text(v.name, clay.TextElementConfig{
                            fontSize = auto_cast editor_ui.theme.font_size,
                            letterSpacing = auto_cast editor_ui.theme.letter_spacing,
                            textColor = ut.color_to_f32list(editor_ui.theme.text_color),
                        })
                    }
                }
            }
        }
    }
}
