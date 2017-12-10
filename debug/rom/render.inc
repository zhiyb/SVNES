; asmsyntax=asmM6502

	; Start offset (dword), fill colour (word), width (word), height (word)
	.importzp	r_s, r_c, r_w, r_h

	; Render dots
	; Parameters: r_s, r_c, r_w
	.import render_dots

	; Render a filled rectangle
	; Parameters: r_s, r_c, r_w, r_h
	; Modifies: r_s
	.import render_rect

	; Render a character
	; Parameters: r_s, r_c, A
	; Modifies: r_s
	.import render_char

	; Render a string
	; Parameters: r_s, r_c, r_w(ptr)
	; Modifies: r_s
	.import render_string
