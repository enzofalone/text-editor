package not

import "core:fmt"
import rl "vendor:raylib"

GUTTER_PADDING :: 12
LINE_N_SPACING :: 8


// Pixel geometry of the current frame, derived from the font metrics.
Layout :: struct {
	total_lines:   i32, // total lines in the buffer
	digits:        i32, // widest line number, in characters
	gutter_width:  i32,
	text_x:        i32, // left edge of the text column
	line_capacity: i32, // rows of text that fit above the status bar
	status_y:      i32, // top edge of the status bar
	status_h:      i32,
	text_pad_y:    f32,
}

// Computes the layout of the editor, including gutter width and text position.
compute_layout :: proc() -> Layout {
	total_lines := i32(len(editor.buf))

	digits := i32(1)
	for n := total_lines; n >= 10; n /= 10 {
		digits += 1
	}

	text_pad_y := f32(editor.line_h - editor.font_size) / 2

	// The status bar is exactly one row tall and sits flush against the bottom
	// edge, so everything above it is the text area and the row capacity falls
	// out of where the bar starts. The window height is rarely an exact
	// multiple of line_h; the leftover pixels stay just above the bar, where
	// they read as empty editor background.
	status_h := editor.line_h
	status_y := rl.GetScreenHeight() - status_h
	line_capacity := max(status_y / editor.line_h, 1)

	gutter_width := i32(f32(digits) * editor.cell_w) + GUTTER_PADDING * 2
	return Layout {
		total_lines = total_lines,
		digits = digits,
		gutter_width = gutter_width,
		text_x = gutter_width + LINE_N_SPACING,
		text_pad_y = text_pad_y,
		line_capacity = line_capacity,
		status_y = status_y,
		status_h = status_h,
	}
}

draw_editor :: proc(l: Layout) {
	total_lines := i32(len(editor.buf))
	if total_lines == 0 do return


	draw_current_line_hightlight(l)
	draw_gutter(l)
	draw_lines(l)
	draw_cursor(l)
	draw_status_bar(l)
}

draw_current_line_hightlight :: proc(l: Layout) {
	row := screen_row(editor.cy)
	if row < 0 || row >= l.line_capacity do return

	line_y := row * editor.line_h
	current_line_color := rl.Color{35, 38, 46, 255}
	rl.DrawRectangle(0, line_y, rl.GetScreenWidth(), editor.line_h, current_line_color)
}

// Draws 1. the gutter bar's line numbers and 2. actual text content.
draw_lines :: proc(l: Layout) {
	// Stop at whichever runs out first: the rows that fit on screen, or the
	// lines left in the buffer below the camera.
	visible := min(l.line_capacity, l.total_lines - editor.camera_y)
	for i in 0 ..< visible {
		y := f32(i * editor.line_h) + l.text_pad_y

		// Lines drawn are offset by the camera_y
		line_idx := i + editor.camera_y

		// Draw line number.
		num_str := fmt.ctprintf("%*d", l.digits, line_idx + 1)
		num_color := rl.YELLOW if line_idx == editor.cy else rl.Color{100, 105, 120, 255}
		rl.DrawTextEx(
			editor.font,
			num_str,
			rl.Vector2{f32(GUTTER_PADDING), y},
			f32(editor.font_size),
			CHAR_SPACING,
			num_color,
		)

		// Draw line text content.
		line_bytes := editor.buf[line_idx]
		if len(line_bytes) == 0 do continue
		line_str := string(line_bytes[:])

		line_cstr := fmt.ctprintf("%s", line_str)
		rl.DrawTextEx(
			editor.font,
			line_cstr,
			rl.Vector2{f32(l.text_x), y},
			f32(editor.font_size),
			CHAR_SPACING,
			rl.RAYWHITE,
		)
	}
}

// Draws the gutter section.
draw_gutter :: proc(l: Layout) {
	gutter_color := rl.Color{24, 25, 30, 255}
	gutter_line_color := rl.Color{45, 48, 58, 255}
	rl.DrawRectangle(0, 0, l.gutter_width, rl.GetScreenHeight(), gutter_color)
	rl.DrawLine(l.gutter_width, 0, l.gutter_width, rl.GetScreenHeight(), gutter_line_color)
}

// Draws the bottom status bar.
draw_status_bar :: proc(l: Layout) {
	// TODO: deduplicate
	bg_color := rl.Color{24, 25, 30, 255}
	bg_line_color := rl.Color{45, 48, 58, 255}

	rl.DrawRectangle(0, l.status_y, rl.GetScreenWidth(), l.status_h, bg_color)
	rl.DrawLine(0, l.status_y, rl.GetScreenWidth(), l.status_y, bg_line_color)

	// Same vertical centering the text area uses, so the bar's text sits on
	// the row baseline instead of floating inside it.
	text_y := f32(l.status_y) + l.text_pad_y

	cord_cstr := fmt.ctprintf("%d:%d", editor.cy + 1, editor.cx + 1)
	cord_w := f32(len(cord_cstr)) * editor.cell_w + GUTTER_PADDING
	rl.DrawTextEx(
		editor.font,
		cord_cstr,
		rl.Vector2{f32(rl.GetScreenWidth()) - cord_w, text_y},
		f32(editor.font_size),
		CHAR_SPACING,
		rl.RAYWHITE,
	)

	mode_cstr: cstring
	switch editor.mode {
	case .NORMAL:
		mode_cstr = fmt.ctprint("-- NORMAL --")
	case .INSERT:
		mode_cstr = fmt.ctprint("-- INSERT --")
	case .VISUAL:
		mode_cstr = fmt.ctprint("-- VISUAL --")
	}
	rl.DrawTextEx(
		editor.font,
		mode_cstr,
		rl.Vector2{GUTTER_PADDING, text_y},
		f32(editor.font_size),
		CHAR_SPACING,
		rl.RAYWHITE,
	)
}
