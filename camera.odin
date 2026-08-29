package not

// updates the camera position
//
// The visible rows are camera_y ..< camera_y + line_capacity, so the last row
// the camera can show without scrolling is camera_y + line_capacity - 1.
update_camera :: proc(l: Layout) {
	if editor.cy < editor.camera_y {
		editor.camera_y = editor.cy
	}
	if editor.cy >= editor.camera_y + l.line_capacity {
		editor.camera_y = editor.cy - l.line_capacity + 1
	}
}

// Row the cursor line occupies on screen, in rows from the top of the window.
screen_row :: proc(line: i32) -> i32 {
	return line - editor.camera_y
}
