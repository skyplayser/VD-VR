# Pictures shared by the start animation and the start screen: the Link-Suite icons (res://intro,
# same files as VD-Link's start animation), VD-Link's line icons and the VD sign (five suite
# colours as a stage floor, as VD-Link draws it in src/ui/dom.ts).
extends RefCounted

const BG := Color("0C0E13")
const PANEL := Color("151821")
const RAISE := Color("1E222E")
const LINE := Color("2A2F3D")
const TEXT := Color("DCE1EA")
const DIM := Color("7E879A")
const ACCENT := Color("FF5C93")
const GOOD := Color("3DDC84")
const WARN := Color("FFB020")
## Suite colours A–E (red, amber, green, cyan, violet).
const SUITE := [Color("FF3B3B"), Color("FFB020"), Color("3DDC84"), Color("22C8F0"), Color("B45CFF")]
## Order of the fan in the start animation (as in the Suite's intro): LJ, LJL, VJ, VD, NET, Crew, PL, dB.
const ORDER := ["lj", "ljl", "vj", "vd", "net", "cr", "pl", "db"]

## VD-Link's line icons (24 × 24, stroke), from src/ui/dom.ts.
const ICONS := {
	"play": '<circle cx="12" cy="12" r="9"/><path d="M10 8.5v7l6-3.5z"/>',
	"demo": '<path d="M8 3l3 7-3 11M16 3l-3 7 3 11"/><path d="M4 21h16"/>',
	"settings": '<path d="M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12M20 18h0"/><circle cx="16" cy="6" r="2"/><circle cx="10" cy="12" r="2"/><circle cx="18" cy="18" r="2"/>',
	"connect": '<rect x="3" y="13" width="18" height="7" rx="1.5"/><path d="M7 13V9M12 13V6M17 13v-3"/><circle cx="7" cy="16.5" r=".8"/><circle cx="12" cy="16.5" r=".8"/><circle cx="17" cy="16.5" r=".8"/>',
	"file": '<path d="M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"/><path d="M14 3v6h6"/><path d="M8 17l2-4 2 2 2-5 2 7"/>',
	"open": '<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v1"/><path d="M3 7v11a2 2 0 0 0 2 2h13l3-9H7l-4 9"/>',
	"net": '<circle cx="12" cy="5" r="2"/><circle cx="5" cy="19" r="2"/><circle cx="19" cy="19" r="2"/><path d="M12 7v5M12 12l-6 5M12 12l6 5"/>',
	"vr": '<path d="M3 9a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2h-4.2l-1.6-2.4h-2.4L9.2 17H5a2 2 0 0 1-2-2z"/><circle cx="8" cy="12" r="1.6"/><circle cx="16" cy="12" r="1.6"/>',
	"insta": '<rect x="3" y="3" width="18" height="18" rx="5"/><circle cx="12" cy="12" r="4"/><circle cx="17.5" cy="6.5" r="1" fill="#ee2a7b"/>',
	"scan": '<path d="M4 8V5a1 1 0 0 1 1-1h3M16 4h3a1 1 0 0 1 1 1v3M20 16v3a1 1 0 0 1-1 1h-3M8 20H5a1 1 0 0 1-1-1v-3"/><path d="M8 15l4-7 4 7z"/>',
	"music": '<path d="M9 17V5.5l11-2.5v12"/><circle cx="6.5" cy="17" r="2.5"/><circle cx="17.5" cy="15" r="2.5"/><path d="M9 9l11-2.5"/>',
	"club": '<rect x="4" y="5" width="16" height="9" rx="1.5"/><path d="M8 20h8M10 14v3M14 14v3"/><path d="M7 9.5h2M11 9.5h2M15 9.5h2"/>',
}

static var _cache := {}


static func _tex(img: Image, mip: bool) -> ImageTexture:
	if mip:
		img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## A Link-Suite picture from res://intro (`suite-symbol`, `suite-logo-dark`, `vd-logo-dark`, `<app>-icon`,
## `vr-icon` – VD VR's own icon, scripts/logo/render.cjs --vr).
static func suite(name: String, px := 512) -> Texture2D:
	var key := "%s@%d" % [name, px]
	if _cache.has(key):
		return _cache[key]
	var img := Image.new()
	if name == "ljl-icon" or name == "vr-icon":
		var t: Texture2D = load("res://intro/%s.png" % name)
		img = t.get_image()
		img.decompress()
		img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	else:
		var svg := FileAccess.get_file_as_string("res://intro/%s.svgdata" % name)
		var w := float(svg.get_slice("width=\"", 1).get_slice("\"", 0))
		if svg == "" or img.load_svg_from_string(svg, px / maxf(w, 1.0)) != OK:
			img = Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	var tex := _tex(img, true)
	_cache[key] = tex
	return tex


## Line icon in a colour, `px` pixels square.
static func icon(name: String, color: Color, px := 64) -> Texture2D:
	var key := "i:%s:%s:%d" % [name, color.to_html(), px]
	if _cache.has(key):
		return _cache[key]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="#%s" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % [color.to_html(false), ICONS.get(name, "")]
	var img := Image.new()
	img.load_svg_from_string(svg, px / 24.0)
	var tex := _tex(img, false)
	_cache[key] = tex
	return tex


## The VD sign: two rows of five tiles in perspective, back row dimmed (VD-Link's logoSlots).
static func slots_svg() -> String:
	var w := 166.0
	var h := 52.0
	var vx := w / 2.0
	var vy := -h * 2.2
	var paths := ""
	for row in [[0.0, h * 0.42, 0.38], [h * 0.5, h, 1.0]]:
		var y0: float = row[0]
		var y1: float = row[1]
		for i in 5:
			var a := i / 5.0 + 0.012
			var b := (i + 1) / 5.0 - 0.012
			var fx := func(t: float) -> float: return vx + (t * w - vx) * ((y0 - vy) / (h - vy))
			var bx := func(t: float) -> float: return vx + (t * w - vx) * ((y1 - vy) / (h - vy))
			paths += '<path d="M%.2f %.2fL%.2f %.2fL%.2f %.2fL%.2f %.2fZ" fill="#%s" fill-opacity="%.2f"/>' % [
				fx.call(a), y0, fx.call(b), y0, bx.call(b), y1, bx.call(a), y1, SUITE[i].to_html(false), row[2]]
	return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 166 52" width="166" height="52">%s</svg>' % paths


static func slots(px_w := 332) -> Texture2D:
	var key := "slots@%d" % px_w
	if _cache.has(key):
		return _cache[key]
	var img := Image.new()
	img.load_svg_from_string(slots_svg(), px_w / 166.0)
	var tex := _tex(img, true)
	_cache[key] = tex
	return tex


## Bold variant of Godot's built-in font (Open Sans).
static func bold(strength := 0.9) -> Font:
	var key := "bold:%.2f" % strength
	if _cache.has(key):
		return _cache[key]
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.variation_embolden = strength
	_cache[key] = f
	return f


## Font with wider letter spacing (small caps headings like VD-Link's „ZULETZT“).
static func spaced(px: int) -> Font:
	var key := "spaced:%d" % px
	if _cache.has(key):
		return _cache[key]
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.variation_embolden = 0.4
	f.spacing_glyph = px
	_cache[key] = f
	return f
