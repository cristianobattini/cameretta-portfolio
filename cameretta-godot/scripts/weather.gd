class_name Weather
extends RefCounted
## Il tempo che fa davvero a Rosignano (lo dà il server). Senza rete resta quello della stagione.

static var kind := ""          # sereno | nuvole | nebbia | pioggia | neve | temporale | "" (non si sa)
static var temp := 0
static var flash := 0.0
static var _next := 0.0
static var _busy := false

static func poll(dt: float) -> void:
	flash = maxf(0, flash - dt * 2.4)
	if kind == "temporale" and active() and randf() < dt * 0.09: flash = 1.0
	_next -= dt
	if _next > 0 or _busy: return
	_next = 600.0
	_busy = true
	var r: Array = await Shop._call("/api/weather")
	_busy = false
	if r[0] == 200 and typeof(r[1]) == TYPE_DICTIONARY and r[1].get("ok", false):
		kind = str(r[1].kind)
		temp = int(r[1].temp)
	else: kind = ""

static func active() -> bool:
	return G.real_weather and kind != ""

static func rain() -> bool:
	return active() and kind in ["pioggia", "temporale"]

static func label() -> String:
	return "%s, %d°" % [G.t("weather")[kind], temp] if active() else ""

## Velo davanti alla strada: nebbia, nuvole, lampi.
static func veil(ci: CanvasItem, time: float) -> void:
	if not active(): return
	if kind == "nebbia":
		for k in 4: ci.draw_rect(Rect2(0, 70 + k * 30 + sin(time * 0.3 + k) * 6, 320, 46), Color(0.78, 0.82, 0.92, 0.16))
	elif kind in ["nuvole", "pioggia", "temporale"]: ci.draw_rect(Rect2(0, 0, 320, 200), Color(0.1, 0.12, 0.2, 0.14 if kind == "nuvole" else 0.24))
	if flash > 0: ci.draw_rect(Rect2(0, 0, 320, 200), Color(0.85, 0.9, 1, 0.5 * flash * flash))

## Nuvole dietro le case.
static func clouds(ci: CanvasItem, time: float) -> void:
	if not active() or kind == "sereno" or kind == "neve": return
	for k in 7:
		var x := fposmod(k * 67 + time * (2.0 + k % 3), 420) - 60
		var y := 14 + (k * 23) % 44
		var c := Color(0.2, 0.22, 0.36, 0.75) if kind != "nuvole" else Color(0.34, 0.36, 0.52, 0.6)
		for q in [[0, 0, 14], [13, -4, 11], [25, 1, 12], [-12, 3, 9], [36, 4, 8]]: ci.draw_circle(Vector2(x + q[0], y + q[1]).round(), q[2], c)
