package main

import "core:mem"
import "core:os"
import "core:strings"
import "core:fmt"
import "core:encoding/cbor"
import "core:encoding/json"
import "core:time"
import ut "project:utils"

REPLAY_DIRECTORY :: "replays"
LEVEL_DIRECTORY :: "leveldata"
CONFIG_DIRECTORY :: "configs"

// TODO: removing will break all levels but needs to be done eventually
VersionedFile :: struct(T: typeid) {
    version: u32 "text",
    data: T "group",
}

// loaded at start but is modified at runtime -- currently not loaded though
LevelFile :: struct {
    // incremented every time loaded file is overwritten
    level_version: u32 "readonly text",
    level_path: string "readonly text",

    random_seed: u32 "text",
    grid: Grid(Tile) "readonly group",
    base_entities: []Entity,
    grid_physics: PhysicsSurface "group",
    linegrid: RectangleLineGrid "group",
}

InputReplayFile :: struct {
    replay_name: string "readonly text",
    encoding_version: u32 "readonly text", // may switch to deltas of deltas for the frames

    // delta between every frame - indexed by the frame number
    delta_times: []f32,
    actions: []GameAction,
    action_frame: []u32,

    level_path: string "readonly text",
    level_version: u32 "readonly text",
}

LEVEL_REPLAY_FILE_VERSION :: 2
EDITOR_SETTINGS_VERSION :: 1
THEME_SETTINGS_VERSION :: 0
VIEWPORT_SETTINGS_VERSION :: 0

load_level_data_from_disk :: proc(
    appdata: ^AppData, 
    level_path: string, 
    frame_allocator: mem.Allocator, 
    init_allocator: mem.Allocator
) -> bool {
    data, err := os.read_entire_file_from_path(strings.concatenate({"./", LEVEL_DIRECTORY, "/", level_path}, allocator=frame_allocator), frame_allocator)
    if err != nil {
        fmt.println("failed to load level", level_path, "from disk")
        return false
    }
    level: VersionedFile(LevelFile)
    err_marshall := cbor.unmarshal_from_bytes(data, &level, allocator=init_allocator)
    if err_marshall != nil {
        fmt.println("failed to unmarshal data", err_marshall)
        return false
    }

    appdata.entities = make([]Entity, MAX_ENTITIES, allocator=init_allocator)
    appdata.entities_count = u32(len(level.data.base_entities))
    copy(appdata.entities, level.data.base_entities)

    //assert(level.data.name == level_path)
    fmt.println(level.data.level_path)

    appdata.level_data = level

    if len(appdata.grid.tiles) == 0 {
        resize_grid(&appdata.grid, ut.Bounds(i32) {
            x = -10,
            y = -10,
            width = 20,
            height = 20,
        }, init_allocator)
    }

    if appdata.linegrid.width == 0 {
        appdata.linegrid = RectangleLineGrid {
            width = 1,
            height = 1,
            transform = ut.TRANSFORM_IDENTITY_F64,
        }
    }

    appdata.new_bounds = appdata.grid.bounds

    if appdata.level_data.version != LEVEL_REPLAY_FILE_VERSION {
        fmt.println("WARNING: level data version mismatch")
    }

    appdata.computed_simplified_collision_hitboxes = greedy_mesh_grid_into_worldspace_aabb_bounds_list(
        appdata.grid, 
        appdata.linegrid,
        allocator = init_allocator,
    );

    // load replay file names

    directory := strings.concatenate({"./", REPLAY_DIRECTORY, "/", appdata.level_path, "/"}, allocator=frame_allocator)

    f, err_dir := os.open(directory)
    if err_dir != nil {
        fmt.println("failed to open replay files directory", err_dir)

        if err_dir != .Not_Exist {
            return false
        }

        err_create: os.Error
        err_create = os.mkdir(directory)

        if err_create != nil {
            fmt.println("failed to create directory", directory, err_create)
            return false
        }
        
        fmt.println("created directory", directory)

        f, err_dir = os.open(directory)
        if err_dir != nil {
            fmt.println("failed to open replay files directory again", err_dir)
        }
    }

    files, err_read := os.read_dir(f, 0, appdata.init_mem_alloc)
    if err_read != nil {
        fmt.println("failed to read replay files directory", err_read)
        return false
    }

    count := 0
    for file in files {
        if file.type == .Regular {
            count += 1
        }
    }

    i := 0
    appdata.replay_info.files_associated_with_level = make([]string, count, appdata.init_mem_alloc)
    for file in files {
        if file.type == .Regular {
            appdata.replay_info.files_associated_with_level[i] = file.name
            i += 1
        }
    }

    return true
}

save_config_data_to_disk :: proc(b: VersionedFile($T), filename: string, frame_allocator: mem.Allocator) -> bool {
    data, err_marhshall := json.marshal(b, allocator=frame_allocator)
    if err_marhshall != nil {
        fmt.println("failed to marshal JSON", err_marhshall)
        return false
    }
    fullpath := strings.concatenate({"./", CONFIG_DIRECTORY, "/", filename, ".json"}, allocator=frame_allocator)
    err := os.write_entire_file(fullpath, data)
    if err != nil {
        fmt.println("failed to save config file", fullpath, "to disk", err)
        return false
    }
    fmt.println("saved config", filename)
    return true
}

load_config_file_from_disk :: proc(b: ^VersionedFile($T), filename: string, frame_allocator: mem.Allocator, init_allocator: mem.Allocator) -> bool {
    data, err := os.read_entire_file_from_path(strings.concatenate({"./", CONFIG_DIRECTORY, "/", filename, ".json"}, allocator=frame_allocator), frame_allocator)
    if err != nil {
        fmt.println("failed to load config", filename, "from disk")
        return false
    }
    err_marshall := json.unmarshal(data, b, allocator=init_allocator)
    if err_marshall != nil {
        fmt.println("failed to unmarshal JSON", err_marshall)
        return false
    }
    fmt.println("data loaded successfully")
    return true
}

save_level_data_to_disk :: proc(appdata: ^AppData, level_path: string, frame_allocator: mem.Allocator) -> bool {
    level: VersionedFile(LevelFile) = appdata.level_data
    level.data.base_entities = appdata.entities[0:appdata.entities_count]
    level.data.level_path = level_path
    data, err_marshall := cbor.marshal_into_bytes(level, allocator=frame_allocator, temp_allocator=frame_allocator)
    if err_marshall != nil {
        fmt.println("failed to marshal data", err_marshall)
        return false
    }
    fullpath := strings.concatenate({"./", LEVEL_DIRECTORY, "/", level_path}, allocator=frame_allocator)
    err := os.write_entire_file(fullpath, data)
    if err != nil {
        fmt.println("failed to save level", fullpath, "to disk", err)
        return false
    }
    fmt.println("data saved successfully")
    return true
}

load_selected_replay_file_from_disk :: proc(replay_info: ^ReplayInfo, level_path: string, frame_allocator: mem.Allocator, init_allocator: mem.Allocator) -> bool {
    replay_file: string = replay_info.files_associated_with_level[replay_info.selected_file]

    fullpath := strings.concatenate(
       {"./", REPLAY_DIRECTORY, "/", level_path, "/", replay_file }, 
       allocator=frame_allocator
    )
    
    data, read_err := os.read_entire_file_from_path(fullpath, frame_allocator)

    if read_err != nil {
        fmt.println("replay load from file failed", read_err)
        return false
    }

    unmarshal_err := cbor.unmarshal_from_bytes(data, &replay_info.loaded, allocator = init_allocator, temp_allocator = frame_allocator)

    // some replays don't have names in the file right now
    replay_info.loaded.replay_name = replay_file
    
    if unmarshal_err != nil {
        fmt.println("replay load from file failed", unmarshal_err)
        return false
    }
    
    return true
}

save_replay_file_to_disk :: proc(replay_file: ^InputReplayFile, level_path: string, frame_allocator: mem.Allocator, init_allocator: mem.Allocator) -> bool {
    assert(replay_file.level_path == level_path)

    now := time.now()
    buf: [128]u8
    buf2: [128]u8
    timestamp := strings.concatenate({time.to_string_yy_mm_dd(now, buf[:]),"_", time.to_string_hms(now, buf2[:])})

    replay_file.replay_name = timestamp

    data, err_marshall := cbor.marshal_into_bytes(replay_file^, allocator=init_allocator, temp_allocator=frame_allocator)
    if err_marshall != nil {
        fmt.println("failed to marshal save replay data", err_marshall)
        return false
    }

    directory := strings.concatenate({"./", REPLAY_DIRECTORY, "/", level_path, "/"}, allocator=frame_allocator)
    fullpath := strings.concatenate({directory, timestamp}, allocator=frame_allocator)

    err := os.write_entire_file(fullpath, data)
    
    if err != nil {
        fmt.println("replay file write failed", err)
        return false
    }
    
    fmt.println("saved replay to: ", fullpath)
    return true
}
