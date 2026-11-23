class_name Astro
extends RefCounted
## Un po' di astronomia: tempo siderale, coordinate orizzontali, Sole, Luna e pianeti (metodo a bassa precisione di Schlyter).

const LAT := 43.3936            # Rosignano Solvay
const LON := 10.4394

## Giorni dal 2000 gennaio 0.0 TU, dal tempo Unix.
static func day(unix: float) -> float:
	return unix / 86400.0 + 2440587.5 - 2451543.5

## Tempo siderale locale in gradi.
static func lst(unix: float) -> float:
	var jd := unix / 86400.0 + 2440587.5
	return fposmod(280.46061837 + 360.98564736629 * (jd - 2451545.0) + LON, 360.0)

## (azimut da nord verso est, altezza) in gradi.
static func horiz(ra: float, dec: float, sid: float) -> Vector2:
	var h := deg_to_rad(sid - ra)
	var d := deg_to_rad(dec)
	var f := deg_to_rad(LAT)
	var alt := asin(clampf(sin(d) * sin(f) + cos(d) * cos(f) * cos(h), -1, 1))
	var az := atan2(-cos(d) * sin(h), sin(d) * cos(f) - cos(d) * sin(f) * cos(h))
	return Vector2(fposmod(rad_to_deg(az), 360.0), rad_to_deg(alt))

const EL := {       # N, i, w, a, e, M con la loro variazione giornaliera
	"mercurio": [48.3313, 3.24587e-5, 7.0047, 5.0e-8, 29.1241, 1.01444e-5, 0.387098, 0.205635, 5.59e-10, 168.6562, 4.0923344368],
	"venere": [76.6799, 2.46590e-5, 3.3946, 2.75e-8, 54.8910, 1.38374e-5, 0.723330, 0.006773, -1.302e-9, 48.0052, 1.6021302244],
	"marte": [49.5574, 2.11081e-5, 1.8497, -1.78e-8, 286.5016, 2.92961e-5, 1.523688, 0.093405, 2.516e-9, 18.6021, 0.5240207766],
	"giove": [100.4542, 2.76854e-5, 1.3030, -1.557e-7, 273.8777, 1.64505e-5, 5.20256, 0.048498, 4.469e-9, 19.8950, 0.0830853001],
	"saturno": [113.6634, 2.38980e-5, 2.4886, -1.081e-7, 339.3939, 2.97661e-5, 9.55475, 0.055546, -9.499e-9, 316.9670, 0.0334442282],
}

static func _kepler(m: float, e: float) -> float:
	var r := deg_to_rad(fposmod(m, 360.0))
	var x := r + e * sin(r) * (1.0 + e * cos(r))
	for i in 6: x -= (x - e * sin(x) - r) / (1.0 - e * cos(x))
	return x

static func _sun(d: float) -> Array:
	var w := 282.9404 + 4.70935e-5 * d
	var e := 0.016709 - 1.151e-9 * d
	var m := 356.0470 + 0.9856002585 * d
	var E := _kepler(m, e)
	var x := cos(E) - e
	var y := sin(E) * sqrt(1.0 - e * e)
	var v := rad_to_deg(atan2(y, x))
	var r := sqrt(x * x + y * y)
	return [deg_to_rad(v + w), r, fposmod(m, 360.0), w]

static func _equ(x: float, y: float, z: float, d: float) -> Vector2:
	var ob := deg_to_rad(23.4393 - 3.563e-7 * d)
	var ye := y * cos(ob) - z * sin(ob)
	var ze := y * sin(ob) + z * cos(ob)
	return Vector2(fposmod(rad_to_deg(atan2(ye, x)), 360.0), rad_to_deg(atan2(ze, sqrt(x * x + ye * ye))))

static func sun(unix: float) -> Vector2:
	var d := day(unix)
	var s := _sun(d)
	return _equ(s[1] * cos(s[0]), s[1] * sin(s[0]), 0.0, d)

static func _orbit(N: float, i: float, w: float, a: float, e: float, M: float) -> Vector3:
	var E := _kepler(M, e)
	var x := a * (cos(E) - e)
	var y := a * sqrt(1.0 - e * e) * sin(E)
	var v := atan2(y, x) + deg_to_rad(w)
	var r := sqrt(x * x + y * y)
	var n := deg_to_rad(N)
	var c := deg_to_rad(i)
	return Vector3(r * (cos(n) * cos(v) - sin(n) * sin(v) * cos(c)), r * (sin(n) * cos(v) + cos(n) * sin(v) * cos(c)), r * sin(v) * sin(c))

static func planet(id: String, unix: float) -> Vector2:
	var d := day(unix)
	var q: Array = EL[id]
	var p := _orbit(q[0] + q[1] * d, q[2] + q[3] * d, q[4] + q[5] * d, q[6], q[7] + q[8] * d, q[9] + q[10] * d)
	# Giove e Saturno si disturbano a vicenda
	if id == "giove" or id == "saturno":
		var mj := deg_to_rad(19.8950 + 0.0830853001 * d)
		var ms := deg_to_rad(316.9670 + 0.0334442282 * d)
		var lo := atan2(p.y, p.x)
		var la := atan2(p.z, Vector2(p.x, p.y).length())
		var r := p.length()
		if id == "giove":
			lo += deg_to_rad(-0.332 * sin(2 * mj - 5 * ms - deg_to_rad(67.6)) - 0.056 * sin(2 * mj - 2 * ms + deg_to_rad(21)) + 0.042 * sin(3 * mj - 5 * ms + deg_to_rad(21)) - 0.036 * sin(mj - 2 * ms) + 0.022 * cos(mj - ms) + 0.023 * sin(2 * mj - 3 * ms + deg_to_rad(52)) - 0.016 * sin(mj - 5 * ms - deg_to_rad(69)))
		else:
			lo += deg_to_rad(0.812 * sin(2 * mj - 5 * ms - deg_to_rad(67.6)) - 0.229 * cos(2 * mj - 4 * ms - deg_to_rad(2)) + 0.119 * sin(mj - 2 * ms - deg_to_rad(3)) + 0.046 * sin(2 * mj - 6 * ms - deg_to_rad(69)) + 0.014 * sin(mj - 3 * ms + deg_to_rad(32)))
			la += deg_to_rad(-0.020 * cos(2 * mj - 4 * ms - deg_to_rad(2)) + 0.018 * sin(2 * mj - 6 * ms - deg_to_rad(49)))
		p = Vector3(r * cos(lo) * cos(la), r * sin(lo) * cos(la), r * sin(la))
	var s := _sun(d)
	# le longitudini sono riferite all'equinozio della data
	return _equ(p.x + s[1] * cos(s[0]), p.y + s[1] * sin(s[0]), p.z, d)

## Luna: [ascensione retta, declinazione, fase 0..1 illuminata, crescente].
static func moon(unix: float) -> Array:
	var d := day(unix)
	var N := 125.1228 - 0.0529538083 * d
	var w := 318.0634 + 0.1643573223 * d
	var M := 115.3654 + 13.0649929509 * d
	var p := _orbit(N, 5.1454, w, 60.2666, 0.054900, M)
	var s := _sun(d)
	var ms := deg_to_rad(s[2])
	var mm := deg_to_rad(M)
	var ls := rad_to_deg(s[0])
	var lm := N + w + M
	var D := deg_to_rad(lm - (s[2] + s[3]))
	var F := deg_to_rad(lm - N)
	var lo := rad_to_deg(atan2(p.y, p.x)) - 1.274 * sin(mm - 2 * D) + 0.658 * sin(2 * D) - 0.186 * sin(ms) - 0.059 * sin(2 * mm - 2 * D) - 0.057 * sin(mm - 2 * D + ms) + 0.053 * sin(mm + 2 * D) + 0.046 * sin(2 * D - ms) + 0.041 * sin(mm - ms) - 0.035 * sin(D) - 0.031 * sin(mm + ms)
	var la := rad_to_deg(atan2(p.z, Vector2(p.x, p.y).length())) - 0.173 * sin(F - 2 * D) - 0.055 * sin(mm - F - 2 * D) - 0.046 * sin(mm + F - 2 * D) + 0.033 * sin(F + 2 * D) + 0.017 * sin(2 * mm + F)
	var a := deg_to_rad(lo)
	var b := deg_to_rad(la)
	var q := _equ(cos(a) * cos(b), sin(a) * cos(b), sin(b), d)
	var el := fposmod(lo - ls, 360.0)
	return [q.x, q.y, (1.0 - cos(deg_to_rad(el))) / 2.0, el < 180.0]

## Precessione (abbastanza buona) dal 2000 alla data, per le stelle.
static func precess(ra: float, dec: float, unix: float) -> Vector2:
	var t := (unix / 86400.0 + 2440587.5 - 2451545.0) / 365.25
	var r := deg_to_rad(ra)
	return Vector2(ra + t * (46.124 + 20.043 * sin(r) * tan(deg_to_rad(clampf(dec, -85, 85)))) / 3600.0, dec + t * 20.043 * cos(r) / 3600.0)

## Le quattro lune di Giove: distanza apparente dal pianeta in raggi gioviani (positiva = ovest). Formule di Meeus, cap. 44.
static func jupiter_moons(unix: float) -> Array:
	var d := unix / 86400.0 + 2440587.5 - 2451545.0
	var r := func(x: float) -> float: return deg_to_rad(fposmod(x, 360.0))
	var V: float = r.call(172.74 + 0.00111588 * d)
	var M: float = r.call(357.529 + 0.9856003 * d)
	var N: float = r.call(20.020 + 0.0830853 * d + 0.329 * sin(V))
	var J: float = r.call(66.115 + 0.9025179 * d - 0.329 * sin(V))
	var A: float = r.call(1.915 * sin(M) + 0.020 * sin(2 * M))
	var B: float = r.call(5.555 * sin(N) + 0.168 * sin(2 * N))
	var K: float = J + A - B
	var R := 1.00014 - 0.01671 * cos(M) - 0.00014 * cos(2 * M)
	var q := 5.20872 - 0.25208 * cos(N) - 0.00611 * cos(2 * N)
	var D := sqrt(q * q + R * R - 2 * q * R * cos(K))
	var psi := rad_to_deg(asin(R / D * sin(K)))
	var l := d - D / 173.0
	var b := rad_to_deg(B)
	var u1 := 163.8069 + 203.4058646 * l + psi - b
	var u2 := 358.4140 + 101.2916335 * l + psi - b
	var u3 := 5.7176 + 50.2345180 * l + psi - b
	var u4 := 224.8092 + 21.4879800 * l + psi - b
	var g: float = r.call(331.18 + 50.310482 * l)
	var h: float = r.call(87.45 + 21.569231 * l)
	var c1 := 0.473 * sin(r.call(2 * (u1 - u2)))
	var c2 := 1.065 * sin(r.call(2 * (u2 - u3)))
	var c3 := 0.165 * sin(g)
	var c4 := 0.843 * sin(h)
	return [
		["Io", (5.9057 - 0.0244 * cos(r.call(2 * (u1 - u2)))) * sin(r.call(u1 + c1)), cos(r.call(u1 + c1))],
		["Europa", (9.3966 - 0.0882 * cos(r.call(2 * (u2 - u3)))) * sin(r.call(u2 + c2)), cos(r.call(u2 + c2))],
		["Ganimede", (14.9883 - 0.0216 * cos(g)) * sin(r.call(u3 + c3)), cos(r.call(u3 + c3))],
		["Callisto", (26.3627 - 0.1939 * cos(h)) * sin(r.call(u4 + c4)), cos(r.call(u4 + c4))],
	]
