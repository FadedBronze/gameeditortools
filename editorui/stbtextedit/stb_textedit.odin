package stbtextedit

foreign import lib "./linux/stb_textedit.a"
_ :: lib

STB_TEXTEDIT_UNDOSTATECOUNT   :: 99
STB_TEXTEDIT_UNDOCHARCOUNT   :: 999

StbUndoRecord :: struct {
	// private data
	_where:        i32,
	insert_length: i32,
	delete_length: i32,
	char_storage:  i32,
}

StbUndoState :: struct {
	// private data
	undo_rec:                         [99]StbUndoRecord,
	undo_char:                        [999]i32,
	undo_point, redo_point:           i16,
	undo_char_point, redo_char_point: i32,
}

STB_TexteditState :: struct {
	/////////////////////
	//
	// public data
	//
	cursor: i32,

	// position of the text cursor within the string
	select_start: i32, // selection start point
	select_end:   i32,

	// selection start and end point in characters; if equal, no selection.
	// note that start may be less than or greater than end (e.g. when
	// dragging the mouse, start is where the initial click was, and you
	// can drag in either direction)
	insert_mode: u8,

	// each textfield keeps its own insert mode state. to keep an app-wide
	// insert mode, copy this value in/out of the app state
	row_count_per_page: i32,

	// page size in number of row.
	// this value MUST be set to >0 for pageup or pagedown in multilines documents.
	
	/////////////////////
	//
	// private data
	//
	cursor_at_end_of_line:        u8,  // not implemented yet
	initialized:                  u8,
	has_preferred_x:              u8,
	single_line:                  u8,
	padding1, padding2, padding3: u8,
	preferred_x:                  f32, // this determines where the cursor up/down tries to seek to along x
	undostate:                    StbUndoState,
}

// result of layout query
StbTexteditRow :: struct {
	x0, x1:           f32, // starting x location, end x location (allows for align=right, etc)
	baseline_y_delta: f32, // position of baseline relative to previous row's baseline
	ymin, ymax:       f32, // height of row above and below baseline
	num_chars:        i32,
}

TextControl :: struct {
    str: [^]u8,
    string_len: u32,
    state: STB_TexteditState,
}

STB_TEXTEDIT_STRING :: TextControl

foreign lib {
    stb_textedit_initialize_state :: proc "c"(state: ^STB_TexteditState, is_single_line: i32) ---
    stb_textedit_click :: proc "c"(str: ^STB_TEXTEDIT_STRING, state: ^STB_TexteditState, x, y: f32) ---
    stb_textedit_drag :: proc "c"(str: ^STB_TEXTEDIT_STRING, state: ^STB_TexteditState, x, y: f32) ---
    stb_textedit_cut :: proc "c"(str: ^STB_TEXTEDIT_STRING, state: ^STB_TexteditState) -> i32 ---
    stb_textedit_paste :: proc "c"(str: ^STB_TEXTEDIT_STRING, state: ^STB_TexteditState, text: [^]u8, len: i32) -> i32 ---
    stb_textedit_key :: proc "c"(str: ^STB_TEXTEDIT_STRING, state: ^STB_TexteditState, key: i32) ---
}
