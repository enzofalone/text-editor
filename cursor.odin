package not

import "core:fmt"
import rl "vendor:raylib"

update_input :: proc() {
	shift_down := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	switch editor.mode {
	case .NORMAL:
		// Mode switching
		if rl.IsKeyPressed(.I) {
			editor.mode = .INSERT
		}
		if rl.IsKeyPressed(.V) {
			editor.mode = .VISUAL
		}

		// Navigation
		if rl.IsKeyPressed(.L) {
			cursor_move_right()
		}
		if rl.IsKeyPressed(.K) {
			cursor_move_up()
		}
		if rl.IsKeyPressed(.J) {
			cursor_move_down()
		}
		if rl.IsKeyPressed(.H) {
			cursor_move_left()
		}

		if rl.IsKeyPressed(.O) {
			if shift_down {
				write_new_line(0)
			} else {
				write_new_line(1)
			}
			editor.mode = .INSERT
		}

		if rl.IsKeyPressed(.ZERO) {
			editor.cx = 0
		}
		if shift_down && rl.IsKeyPressed(.FOUR) {
			editor.cx = i32(len(editor.buf[editor.cy]) - 1)
		}

	case .INSERT:
		if rl.IsKeyPressed(.ESCAPE) {
			editor.mode = .NORMAL
			clamp_cursor_x()
			return
		}
		if rl.IsKeyPressed(.BACKSPACE) {
			delete_char()
			return
		}
		if rl.IsKeyPressed(.ENTER) {
			write_line()
			return
		}

		write_char(rl.GetCharPressed())

	case .VISUAL:
		if rl.IsKeyPressed(.ESCAPE) {
			editor.mode = .NORMAL
			clamp_cursor_x()
		}
	}
}

cursor_move_right :: proc() {
	if len(editor.buf) == 0 do return
	line_len := i32(len(editor.buf[editor.cy]))
	max_x := line_len if editor.mode == .INSERT else max(i32(0), line_len - 1)
	if editor.cx < max_x {
		editor.cx += 1
	}
}

cursor_move_left :: proc() {
	if editor.cx > 0 {
		editor.cx -= 1
	}
}

cursor_move_up :: proc() {
	if editor.cy > 0 {
		editor.cy -= 1
		clamp_cursor_x()
	}
}

cursor_move_down :: proc() {
	if editor.cy < i32(len(editor.buf)) - 1 {
		editor.cy += 1
		clamp_cursor_x()
	}
}

// write_new_line creates a new empty line.
//
// Returns a pointer to the new line.
write_new_line :: proc(y_offset: i32) {
	new_line := [dynamic]u8{}
	inject_at(&editor.buf, editor.cy + y_offset, new_line)

	editor.cy += y_offset
	editor.cx = 0
}

// write_line slices the current line at editor.cx and inserts a new line with the sliced content
write_line :: proc() {
	cur_line := &editor.buf[editor.cy]
	tail := cur_line[editor.cx:]
	resize(cur_line, editor.cx)

	write_new_line(1)

	new_line := &editor.buf[editor.cy]
	append(new_line, ..tail)
}

write_char :: proc(r: rune) {
	if r == 0 do return

	char := u8(r)

	cur_line := &editor.buf[editor.cy]
	inject_at(cur_line, editor.cx, char)
	editor.cx += 1
}

// Deletes the line and moves the content to the previous line.
delete_line_tail :: proc() {
	if editor.cy == 0 do return
	cur_line := &editor.buf[editor.cy]

	// get anything remaining in the current line and append to previous line
	tail := cur_line[editor.cx:]
	prev_line := &editor.buf[editor.cy - 1]
	prev_end := len(prev_line)
	append(prev_line, ..tail)

	ordered_remove(&editor.buf, editor.cy)
	editor.cy -= 1
	editor.cx = i32(prev_end)
}

// Deletes the character at the current cursor position.
delete_char :: proc() {
	if editor.cx == 0 {
		delete_line_tail()
		return
	}
	cur_line := &editor.buf[editor.cy]

	if editor.mode == .INSERT {
		// cursor is at x+1 on insert mode
		ordered_remove(cur_line, editor.cx - 1)
		editor.cx -= 1
	}
}

// Adjusts the cursor's x position to stay within the bounds of the current line.
//
// Used to readjust the cursor's x position while moving up or down.
clamp_cursor_x :: proc() {
	if len(editor.buf) == 0 do return
	line_len := i32(len(editor.buf[editor.cy]))
	max_x := line_len if editor.mode == .INSERT else max(i32(0), line_len - 1)
	if editor.cx > max_x {
		editor.cx = max_x
	}
}

cell_pos :: proc(l: Layout, col, row: i32) -> rl.Vector2 {
	return rl.Vector2{f32(l.text_x) + f32(col) * editor.cell_w, f32(row * editor.line_h)}
}

draw_cursor :: proc(l: Layout) {
	if editor.cy < 0 || editor.cy >= i32(len(editor.buf)) do return

	row := screen_row(editor.cy)
	if row < 0 || row >= l.line_capacity do return

	line := editor.buf[editor.cy]
	col := clamp(editor.cx, 0, i32(len(line)))
	pos := cell_pos(l, col, row)

	switch editor.mode {
	case .INSERT:
		draw_insert_cursor(l, col, pos)
	case .VISUAL, .NORMAL:
		draw_block_cursor(l, col, pos)
	}
}

@(private = "file")
draw_insert_cursor :: proc(l: Layout, col: i32, pos: rl.Vector2) {
	rl.DrawRectangleRec(
		rl.Rectangle{pos.x, pos.y, 2, f32(editor.line_h)},
		rl.Color{255, 255, 255, 255},
	)
}

@(private = "file")
draw_block_cursor :: proc(l: Layout, col: i32, pos: rl.Vector2) {
	block_color := rl.Color{220, 220, 220, 255}
	if editor.mode == .VISUAL {
		// TODO: Decouple so this is not hardcoded here.
		block_color = rl.Color{100, 160, 220, 255}
	}
	rl.DrawRectangleRec(rl.Rectangle{pos.x, pos.y, editor.cell_w, f32(editor.line_h)}, block_color)

	// Redraw the covered character in the background colour so it reads
	// through the block, the way a terminal cursor does.
	line := editor.buf[editor.cy]
	if col < i32(len(line)) {
		char_cstr := fmt.ctprintf("%s", string(line[col:col + 1]))
		rl.DrawTextEx(
			editor.font,
			char_cstr,
			rl.Vector2{pos.x, pos.y + l.text_pad_y},
			f32(editor.font_size),
			CHAR_SPACING,
			rl.Color{18, 18, 18, 255},
		)
	}
}
