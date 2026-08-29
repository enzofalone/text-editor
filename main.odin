package not

import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

TARGET_FPS :: 60

CHAR_SPACING :: 0
LINE_HEIGHT_RATIO :: 1.35
FONT_SIZE :: 16

COMMAND_MODE :: enum {
	NORMAL,
	INSERT,
	VISUAL,
}

// Global editor state.
Editor :: struct {
	// 2D buffer of characters representing the editor's current loaded content.
	buf:           [dynamic][dynamic]u8,
	cx:            i32,
	cy:            i32,
	mode:          COMMAND_MODE,
	camera_y:      i32, // camera line offset
	// font and size specific
	font:          rl.Font,
	font_size:     i32,
	// Width of one character cell and height of one row, in pixels. Every
	// horizontal position in the editor is a multiple of cell_w.
	cell_w:        f32,
	line_h:        i32,
	has_nerd_font: bool,
}

editor: Editor

init_editor :: proc() -> bool {
	editor = Editor {
		buf       = nil,
		cx        = 0,
		cy        = 0,
		camera_y  = 0,
		font_size = FONT_SIZE,
		mode      = .NORMAL,
	}

	// Load the file into the editor buffer.
	filename := os.args[1]
	fmt.printfln("Opening %s", filename)
	editor.buf = read_file(filename)
	return editor.buf != nil
}

main :: proc() {
	if len(os.args) < 2 {
		fmt.println("Missing file to load")
		return
	}

	if !init_editor() {
		fmt.println("Failed to initialize editor")
		return
	}

	rl.InitWindow(800, 600, "Text Editor")
	defer rl.CloseWindow()
	rl.SetTargetFPS(TARGET_FPS)

	rl.SetExitKey(.KEY_NULL)

	editor_load_font(FONT_SIZE)
	defer editor_unload_font()

	for !rl.WindowShouldClose() {
		update_input()
		l := compute_layout()
		update_camera(l)

		rl.BeginDrawing()
		rl.ClearBackground(rl.Color{18, 18, 18, 255})

		draw_editor(l)

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}
}

// Reads the entire file at once in a 2D buffer of chars.
//
// Returns nil if the file could not be read.
// TODO: This will not scale to very large files. Update with a chunked approach.
read_file :: proc(filepath: string) -> [dynamic][dynamic]u8 {
	data, err := os.read_entire_file(filepath, context.allocator)
	if err != nil {
		fmt.println("Could not read file", filepath)
		return nil
	}

	buf := [dynamic][dynamic]u8{}
	it := string(data)
	for line in strings.split_lines_iterator(&it) {
		line_buf := [dynamic]u8{}
		for i in 0 ..< len(line) {
			append(&line_buf, line[i])
		}
		append(&buf, line_buf)
	}

	if len(buf) == 0 {
		append(&buf, [dynamic]u8{})
	}
	return buf
}
