class_name UI
extends RefCounted
## Mattoncini dell'interfaccia: font, riquadri in stile pixel, etichette, pulsanti.

static var f_head: Font
static var f_ui: Font
static var f_body: Font
static var theme: Theme

static func init() -> void:
	var pix: FontFile = load("res://fonts/PixelifySans.ttf")
	var vt: FontFile = load("res://fonts/VT323-Regular.ttf")
	var ts := TextServerManager.get_primary_interface()
	# i font pixel non hanno frecce e simboli: li prendono da Noto (sottoinsieme)
	var fb: Array[Font] = [load("res://fonts/SymbolsB.ttf"), load("res://fonts/SymbolsA.ttf")]
	pix.fallbacks = fb
	vt.fallbacks = fb
	for f in [pix, vt] + fb:
		f.allow_system_fallback = false   # come nel browser: nessun font di sistema
	var bold := FontVariation.new()
	bold.base_font = pix
	bold.variation_opentype = {ts.name_to_tag("wght"): 700}
	f_head = bold
	var reg := FontVariation.new()
	reg.base_font = pix
	reg.variation_opentype = {ts.name_to_tag("wght"): 400}
	f_ui = reg
	f_body = vt
	theme = Theme.new()
	theme.default_font = vt
	theme.default_font_size = 22
	theme.set_color("font_color", "Label", G.C_CREAM)
	theme.set_color("default_color", "RichTextLabel", G.C_MUTED)
	theme.set_font("normal_font", "RichTextLabel", vt)
	theme.set_font("bold_font", "RichTextLabel", bold)
	theme.set_font_size("normal_font_size", "RichTextLabel", 22)
	theme.set_font_size("bold_font_size", "RichTextLabel", 21)
	theme.set_constant("line_separation", "RichTextLabel", 0)
	# barre di scorrimento in stile pixel
	var grab := box(G.C_LINE)
	var grab_h := box(G.gold)
	var track := box(Color(0, 0, 0, 0.25))
	for sb in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", sb, track)
		theme.set_stylebox("grabber", sb, grab)
		theme.set_stylebox("grabber_highlight", sb, grab_h)
		theme.set_stylebox("grabber_pressed", sb, grab_h)
	# slider
	theme.set_stylebox("slider", "HSlider", box(G.C_INK, G.C_LINE, 2, 4))
	theme.set_stylebox("grabber_area", "HSlider", box(G.gold))
	theme.set_stylebox("grabber_area_highlight", "HSlider", box(G.gold))

static func box(bg: Color, border := Color(0, 0, 0, 0), bw := 0, pad := 0, pad_y := -1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.anti_aliasing = false
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad if pad_y < 0 else pad_y
	s.content_margin_bottom = pad if pad_y < 0 else pad_y
	return s

static func label(text: String, size := 22, color := G.C_CREAM, font: Font = null, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font: l.add_theme_font_override("font", font)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 10
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l

static func rich(bb: String, size := 22, color := G.C_MUTED) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", color)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.text = bb
	r.custom_minimum_size.x = 10
	r.meta_clicked.connect(func(m): G.open_url(str(m)))
	return r

## kind: "tool" (HUD), "solid" (oro), "ghost", "flat", "link"
static func button(text: String, cb: Callable, kind := "tool", size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", f_ui)
	b.add_theme_font_size_override("font_size", size)
	var n: StyleBoxFlat
	var h: StyleBoxFlat
	var fc := G.C_CREAM
	var hc := G.C_INK
	match kind:
		"solid":
			n = box(G.gold, G.C_INK, 3, 14, 6); h = box(G.C_CREAM, G.C_INK, 3, 14, 6); fc = G.C_INK
		"ghost":
			n = box(Color(0, 0, 0, 0), G.C_LINE, 2, 12, 5); h = box(G.C_PANEL2, G.gold, 2, 12, 5); hc = G.gold
		"flat":
			n = box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6, 2); h = box(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 0, 6, 2); hc = G.gold
		"link":
			n = box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0); h = n; fc = G.gold; hc = G.C_CREAM
		_:
			n = box(G.C_PANEL, G.C_INK, 3, 12, 6); h = box(G.gold, G.C_INK, 3, 12, 6)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", n)
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", hc)
	b.add_theme_color_override("font_pressed_color", hc)
	b.add_theme_color_override("font_focus_color", fc)
	b.add_theme_color_override("font_disabled_color", Color(fc, 0.6))
	b.pressed.connect(cb)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	return b

## Riquadro "pixel" con doppio bordo (crema dentro, inchiostro fuori).
static func px_panel(bg := G.C_PANEL, border := G.C_CREAM, pad := 0) -> PanelContainer:
	var outer := PanelContainer.new()
	outer.add_theme_stylebox_override("panel", box(G.C_INK, Color(0, 0, 0, 0), 0, 4))
	var inner := PanelContainer.new()
	inner.add_theme_stylebox_override("panel", box(bg, border, 4, pad))
	inner.name = "Inner"
	outer.add_child(inner)
	return outer

static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func margin(c: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(c)
	return m

## Icone in pixel delle cinque sezioni (rettangoli su griglia 12x12).
const ICONS := {
	"letto": [[1,5,10,4,"f6e9c8"],[4,5,7,4,"d97a4b"],[1,9,1,2,"8a5a36"],[10,9,1,2,"8a5a36"]],
	"scrivania": [[1,2,10,7,"1a1733"],[2,3,8,5,"8fb2ee"],[3,4,3,1,"f2b85b"],[3,6,5,1,"a3bb8c"],[3,10,6,1,"f6e9c8"]],
	"lavagna": [[0,2,12,8,"8a5a36"],[1,3,10,6,"2f5d48"],[2,4,4,1,"f6e9c8"],[2,6,6,1,"f6e9c8"],[8,4,2,2,"f2b85b"]],
	"libreria": [[1,0,10,12,"8a5a36"],[2,1,8,4,"3d2616"],[2,6,8,4,"3d2616"],[2,2,2,3,"d97a4b"],[4,1,1,4,"8fb2ee"],[6,2,2,3,"a3bb8c"],[3,7,2,3,"f2b85b"],[6,6,2,4,"f6e9c8"]],
	"finestra": [[1,0,10,12,"8a5a36"],[2,1,8,10,"1b2350"],[5,1,1,10,"8a5a36"],[2,6,8,1,"8a5a36"],[7,2,2,2,"fff0c8"],[3,3,1,1,"f6e9c8"]],
}

static func icon(id: String, px := 4) -> TextureRect:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for r in ICONS.get(id, ICONS.scrivania):
		img.fill_rect(Rect2i(r[0], r[1], r[2], r[3]), Color(r[4]))
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.custom_minimum_size = Vector2(12 * px, 12 * px)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr
