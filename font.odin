package not

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

// Hack Nerd Font, vendored under assets/. Looked up relative to the working
// directory first, then next to the binary so the editor still finds it when
// it is launched from somewhere else.
FONT_PATH :: "assets/nerd.ttf"

// Nerd Font glyphs we want baked into the atlas: powerline separators, a git
// branch, a lock and a file icon. Nothing draws them yet, but they are here so
// the status bar can use them without rebuilding the font.
NERD_ICONS := [?]rune{0xE0A0, 0xE0A2, 0xE0B0, 0xE0B1, 0xE0B2, 0xE0B3, 0xF023, 0xF15C, 0xF07B, 0xF0C7}

// Printable ASCII plus the icons above.
build_codepoints :: proc(allocator := context.allocator) -> []rune {
	cps := make([dynamic]rune, 0, 128 + len(NERD_ICONS), allocator)
	for c in 32 ..= 126 {
		append(&cps, rune(c))
	}
	append(&cps, ..NERD_ICONS[:])
	return cps[:]
}

resolve_font_path :: proc(allocator := context.allocator) -> (path: cstring, ok: bool) {
	cwd_path := strings.clone_to_cstring(FONT_PATH, allocator)
	if rl.FileExists(cwd_path) {
		return cwd_path, true
	}
	delete(cwd_path, allocator)

	app_dir := string(rl.GetApplicationDirectory())
	next_to_binary := strings.concatenate({app_dir, FONT_PATH}, allocator)
	app_path := strings.clone_to_cstring(next_to_binary, allocator)
	delete(next_to_binary, allocator)
	if rl.FileExists(app_path) {
		return app_path, true
	}
	delete(app_path, allocator)

	return nil, false
}

// Loads the nerd font at `size` and fills in the grid metrics the renderer
// lays everything out on. Falls back to raylib's built-in font if the ttf is
// missing so the editor still starts.
editor_load_font :: proc(size: i32) {
	cps := build_codepoints(context.temp_allocator)

	editor.has_nerd_font = false
	if path, ok := resolve_font_path(context.temp_allocator); ok {
		font := rl.LoadFontEx(path, size, raw_data(cps), i32(len(cps)))
		if rl.IsFontValid(font) && font.texture.id != rl.GetFontDefault().texture.id {
			editor.font = font
			editor.has_nerd_font = true
			fmt.printfln("Loaded nerd font: %s", path)
		}
	}
	if !editor.has_nerd_font {
		fmt.eprintfln("warning: could not load %s, falling back to the default font", FONT_PATH)
		editor.font = rl.GetFontDefault()
	}
	rl.SetTextureFilter(editor.font.texture, .BILINEAR)

	editor.font_size = size

	// The font is monospaced, so one glyph's advance is the width of every
	// cell. Measured with the same spacing DrawTextEx is called with, which
	// is what keeps the cursor rectangle on top of the character it marks.
	cell := rl.MeasureTextEx(editor.font, "M", f32(size), CHAR_SPACING)
	editor.cell_w = cell.x + CHAR_SPACING
	editor.line_h = max(i32(f32(size) * LINE_HEIGHT_RATIO), size)
}

editor_unload_font :: proc() {
	if editor.has_nerd_font {
		rl.UnloadFont(editor.font)
		editor.has_nerd_font = false
	}
}
