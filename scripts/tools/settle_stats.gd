extends SceneTree

# ══════════════════════════════════════════════════════════
#  settle_stats — 정착 실측 (상인 팔 크롭 · 리롤 쓸기 설계용 치수)
#
#  실행:  "D:/Godot/Godot_v4.7.1-stable_win64_console.exe" --path . --script scripts/tools/settle_stats.gd
#
#  한 롤 = _open_shop() → _drop_settle().  매물 4개(기본 점수2·보드 확장1·다트1).
#  낙하를 감은 뒤 물건의 면 좌표(u,w)와 화면 좌표를 그대로 긁는다.
#
#  잰 것 다섯
#    ① 타입별 정착 u·w 분포 (min/p1/p50/p99/max)
#    ② 창구 빗변까지의 u 거리        — 쓸기 이동거리 예산
#    ③ w 밴드를 덮는 선분과 그 화면 길이 — 아래팔 길이
#    ④ 화면 y 점유 (몸통 / +그림자 / +가격판)
#    ⑤ 실제로 그려지는 화면 반폭
#
#  ⚠ 화면 기하는 game.gd 를 **옮겨 적은 사본**이다. 그리기가 바뀌면 이 도구는
#     조용히 거짓말을 한다. 상인·팔·손 치수 주석이 여기 나온 숫자를 인용하고
#     있으므로, 그리기를 고쳤으면 아래 목록을 따라가 같이 고쳐라.
#  옮긴 자리:
#    기본 점수   _chip_flat   game.gd:3358-3363  (ry = chip_r*flat, 옆면 sd = chip_t*tall)
#    보드 확장 _icon_mod    game.gd:3479       (pl = c-(r+3,r+3), 2r+6 정사각)
#    다트 _icon_dart   game.gd:3574-3644
#    그림자 _obj_shadow game.gd:3312-3324 (light*3.35, 타원 r × r*flat)
#    가격판 _bill_draw  game.gd:3393-3401 + draw_gold_at game.gd:2185-2191
# ══════════════════════════════════════════════════════════

#  롤 수와 시드는 사용자 인자로 갈 수 있다:  ... --script ... -- 12345 800
const ROLLS := 500
const RSEED := 20260821

var g = null
var step := 0
var rolls := ROLLS
var rseed := RSEED

# 타입별 표본. 각 원소 = 사전 하나.
var rows := {"item": [], "mod": [], "dart": []}
var seen_dart := {}
var t_hit := 0          # 정착 상한(t_max) 에 걸린 롤 수
var wall_w := 0         # w = w_hi 에 붙어 멈춘 물건 수
var wall_u := 0         # u 벽에 붙어 멈춘 물건 수


#  _initialize 안에서는 root 가 아직 트리 밖이라 _ready 가 안 돈다
#  (실측: is_inside_tree() == false, g.font == null). 폰트가 없으면
#  가격판 세로 치수를 못 재므로 click_probe 처럼 _process 로 미룬다.
func _initialize() -> void:
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 0 and String(ua[0]).is_valid_int():
		rseed = int(ua[0])
	if ua.size() > 1 and String(ua[1]).is_valid_int():
		rolls = int(ua[1])
	seed(rseed)
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	step += 1
	if step < 4:
		return false
	if g.font == null:
		push_error("_ready 가 안 돌았다 — font 가 비었다")
		quit(1)
		return true

	for n in rolls:
		g.leg_no = 1 + (n % 7)      # 테이블 구성은 1~7 판 모두 2/1/1 로 같다
		g._open_shop()
		g._drop_settle()
		if g.drop_t > g.DROP.t_max:
			t_hit += 1
		_collect()

	_report()
	quit(0)
	return true


# ── 수집 ──────────────────────────────────────────────
func _collect() -> void:
	for i in mini(g.drop.size(), g.stock.size()):
		var it: Dictionary = g.drop[i]
		var s: Dictionary = g.stock[i]
		var ty: String = s.type
		var cy: float = g._p2g(it.w)             # h=0 · lift=0 이므로 _p2s 와 같다
		var body := _body_box(it, s)
		var shad := _shadow_box(it)
		var bill := _bill_box(it, s)
		var e: float = g._chute_edge(cy)         # 그 높이의 창구 빗변 x
		var foot := _w_foot(it)
		if ty == "dart":
			seen_dart[String(s.d.id)] = true
		if is_equal_approx(float(it.w), g.DROP.w_hi):
			wall_w += 1
		if is_equal_approx(float(it.u), g.DROP.u_lo + float(it.hw)) \
				or is_equal_approx(float(it.u), g.DROP.u_hi - float(it.hw)):
			wall_u += 1
		rows[ty].append({
			"u": float(it.u), "w": float(it.w), "cy": cy, "psi": float(it.psi),
			"hw": float(it.hw), "wob": absf(float(it.wob)),
			"e": e,
			"d_c": float(it.u) - e,                     # 중심 → 빗변
			"d_l": body.position.x - e,                 # 그려지는 왼쪽 끝 → 빗변
			"d_hw": float(it.u) - float(it.hw) - e,     # 물리 반폭 왼쪽 끝 → 빗변
			"b_t": body.position.y, "b_b": body.end.y,
			"b_l": body.position.x, "b_r": body.end.x,
			"s_t": shad.position.y, "s_b": shad.end.y,
			"p_t": bill.position.y, "p_b": bill.end.y,
			"x_t": g._obj_box(i).position.y, "x_b": g._obj_box(i).end.y,
			"w_lo": foot.x, "w_hi": foot.y,
		})


# ── 그려지는 몸통의 화면 AABB ─────────────────────────
func _body_box(it: Dictionary, s: Dictionary) -> Rect2:
	var c := Vector2(float(it.u), g._p2g(it.w))
	match String(s.type):
		"mod":
			# game.gd:3479  pl := Rect2(c - (r+3, r+3), (2r+6, 2r+6))
			var r: float = g.TBL.mod_r + 3.0
			return Rect2(c - Vector2(r, r), Vector2(r * 2.0, r * 2.0))
		"dart":
			return _dart_box(it, String(s.d.id))
	# 기본 점수 — game.gd:3358-3363. 옆면 타원이 sd 만큼 아래로 한 겹 더 깔린다.
	var rx: float = g.TBL.chip_r
	var ry: float = g.TBL.chip_r * g.TBL.flat
	var sd: float = g.TBL.chip_t * g.TBL.tall
	return Rect2(Vector2(c.x - rx, c.y - ry),
			Vector2(rx * 2.0, ry * 2.0 + sd))


func _seg_box(a: Vector2, b: Vector2, w: float) -> Rect2:
	var r := Rect2(a, Vector2.ZERO).expand(b)
	return r.grow(w * 0.5)


func _dart_box(it: Dictionary, id: String) -> Rect2:
	var c := Vector2(float(it.u), g._p2g(it.w))
	var de := Vector2(cos(it.psi), sin(it.psi) * g.TBL.flat)
	var dl: float = g.TBL.dart_l * de.length()
	# _obj_draw 가 넘기는 rot = de.angle() + 1.0304 이라 dir 은 사실상 de 방향
	var dir := Vector2(6.0, -10.0).normalized().rotated(de.angle() + 1.0304)
	var nrm := Vector2(-dir.y, dir.x)
	var k: float = maxf(0.75, dl / 19.0)
	var bw := 2.6 * k
	var fin := 3.2 * k
	match id:
		"hvy":
			bw = 4.0 * k
			fin = 2.4 * k
		"lgt":
			bw = 1.5 * k
			fin = 4.6 * k
		"prc":
			bw = 2.2 * k
			fin = 2.8 * k
		"mag":
			bw = 3.0 * k
			fin = 3.4 * k
	var tip := c + dir * dl
	var tail := c - dir * dl
	var brl := c + dir * dl * 0.1
	var b0 := c - dir * dl * 0.35
	var w0 := c - dir * dl * 0.6

	var r := Rect2(tip, Vector2.ZERO)
	for p in [brl + nrm * bw * 0.5, brl - nrm * bw * 0.5, tail,
			w0 + nrm * fin - dir * dl * 0.2, w0 - nrm * fin - dir * dl * 0.2]:
		r = r.expand(p)
	r = r.merge(_seg_box(brl, b0, bw))          # 배럴
	r = r.merge(_seg_box(b0, w0, 1.6))          # 샤프트
	match id:
		"hvy":
			for t in [0.55, 0.75]:
				var q := brl.lerp(b0, t)
				r = r.merge(_seg_box(q + nrm * bw * 0.6, q - nrm * bw * 0.6, 2.0))
		"lgt":
			for sd in [-1.0, 1.0]:
				r = r.expand(tail + nrm * sd * 2.5 * k - dir * 2.0 * k)
				r = r.expand(tail + nrm * sd * 2.5 * k - dir * 6.0 * k)
		"prc":
			r = r.merge(_seg_box(tip, tip + dir * 5.0 * k, 1.0))
		"mag":
			# draw_arc(tip + dir*4k, 4.5k, 0.15π → 0.85π). y 는 아래쪽 반만 쓴다.
			var mc := tip + dir * 4.0 * k
			var mr: float = 4.5 * k
			r = r.merge(Rect2(mc + Vector2(-0.892 * mr, 0.454 * mr),
					Vector2(1.784 * mr, 0.546 * mr)).grow(0.5))
	return r


# ── 그림자 (game.gd:3312-3324) ────────────────────────
func _shadow_box(it: Dictionary) -> Rect2:
	var off: Vector2 = g.TBL.light * 3.35        # h=0 · lift=0
	var rr: float = float(it.r)
	var ry: float = rr * g.TBL.flat
	var box := Rect2()
	var first := true
	for s in int(it.nb):
		var sp: Vector2 = g._drop_sub(it, s)
		var gp := Vector2(sp.x, g._p2g(sp.y)) + off
		var b := Rect2(gp - Vector2(rr, ry), Vector2(rr * 2.0, ry * 2.0))
		box = b if first else box.merge(b)
		first = false
	return box


# ── 가격판 (game.gd:3401 · 2185-2191) ─────────────────
func _bill_box(it: Dictionary, s: Dictionary) -> Rect2:
	var txt := str(s.cost)
	var bw: float = g.gold_w(txt, 9)
	var x: float = float(it.u) - bw * 0.5
	var y: float = g._p2g(it.w) + g.DROP.bill_dy
	var iw: float = 9.0 * 0.85                   # 금화 아이콘 폭
	var ih: float = iw * 0.64
	var py: float = y - 9.0 * 0.62
	# draw_plaque: 그림자 rect 가 h*0.22 만큼 아래로 더 간다
	var top: float = minf(py, y - g.font.get_ascent(9))
	var bot: float = maxf(py + ih * 0.22 + ih, y + g.font.get_descent(9))
	return Rect2(Vector2(x, top), Vector2(bw, bot - top))


# 면 w 축 발자국 — 충돌 원(다트는 3개)이 실제로 덮는 w 구간
func _w_foot(it: Dictionary) -> Vector2:
	var lo := 1e9
	var hi := -1e9
	for s in int(it.nb):
		var sp: Vector2 = g._drop_sub(it, s)
		lo = minf(lo, sp.y - float(it.r))
		hi = maxf(hi, sp.y + float(it.r))
	return Vector2(lo, hi)


# ── 통계 ──────────────────────────────────────────────
func _col(ty: String, key: String) -> Array:
	var a := []
	for r in rows[ty]:
		a.append(float(r[key]))
	a.sort()
	return a


func _pct(a: Array, p: float) -> float:
	if a.is_empty():
		return NAN
	var x: float = p * 0.01 * float(a.size() - 1)
	var i := int(floor(x))
	var j := mini(i + 1, a.size() - 1)
	return lerpf(a[i], a[j], x - float(i))


func _five(ty: String, key: String) -> String:
	var a := _col(ty, key)
	return "%8.2f %8.2f %8.2f %8.2f %8.2f" % [a[0], _pct(a, 1.0), _pct(a, 50.0),
			_pct(a, 99.0), a[a.size() - 1]]


func _all(key: String) -> Array:
	var a := []
	for ty in ["item", "mod", "dart"]:
		for r in rows[ty]:
			a.append(float(r[key]))
	a.sort()
	return a


func _lo(key: String) -> float:
	return _all(key)[0]


func _hi(key: String) -> float:
	var a := _all(key)
	return a[a.size() - 1]


func _report() -> void:
	var n := 0
	for ty in ["item", "mod", "dart"]:
		n += rows[ty].size()
	print("\n═══ _m_settle · %d롤 · seed %d · 표본 %d개 ═══" % [rolls, rseed, n])
	print("  타입별 개수  item %d · mod %d · dart %d"
			% [rows.item.size(), rows.mod.size(), rows.dart.size()])
	print("  다트 종류 관측: ", ", ".join(seen_dart.keys()))
	print("  t_max 발동 %d롤 · w_hi 벽에 붙은 물건 %d/%d (%.1f%%) · u 벽 %d개"
			% [t_hit, wall_w, n, 100.0 * float(wall_w) / float(n), wall_u])
	print("  트레이 한계  u[%.1f, %.1f]  w[%.1f, %.1f]"
			% [g.DROP.u_lo, g.DROP.u_hi, g.DROP.w_lo, g.DROP.w_hi])
	print("  TBL.fy %.1f · ny %.1f · flat %.3f · tall %.3f"
			% [g.TBL.fy, g.TBL.ny, g.TBL.flat, g.TBL.tall])

	print("\n── ① 정착 면 좌표 ──────────────────────────────")
	print("                       min       p1      p50      p99      max")
	for ty in ["item", "mod", "dart"]:
		print("  u  %-5s      %s" % [ty, _five(ty, "u")])
	for ty in ["item", "mod", "dart"]:
		print("  w  %-5s      %s" % [ty, _five(ty, "w")])
	print("  u  전체      %8.2f %8.2f %8.2f %8.2f %8.2f"
			% [_lo("u"), _pct(_all("u"), 1.0), _pct(_all("u"), 50.0),
			_pct(_all("u"), 99.0), _hi("u")])
	print("  w  전체      %8.2f %8.2f %8.2f %8.2f %8.2f"
			% [_lo("w"), _pct(_all("w"), 1.0), _pct(_all("w"), 50.0),
			_pct(_all("w"), 99.0), _hi("w")])
	print("  지면 화면 y (=_p2g(w))")
	print("     전체      %8.2f %8.2f %8.2f %8.2f %8.2f"
			% [_lo("cy"), _pct(_all("cy"), 1.0), _pct(_all("cy"), 50.0),
			_pct(_all("cy"), 99.0), _hi("cy")])

	print("\n── ② 창구(왼쪽 판매) 빗변까지의 거리 ────────────")
	print("  빗변 x = _chute_edge(_p2g(w)) = 80*(1 - (y-112)/132)")
	print("  빗변 x 자체  %8.2f %8.2f %8.2f %8.2f %8.2f"
			% [_lo("e"), _pct(_all("e"), 1.0), _pct(_all("e"), 50.0),
			_pct(_all("e"), 99.0), _hi("e")])
	print("                       min       p1      p50      p99      max")
	for ty in ["item", "mod", "dart"]:
		print("  중심u-빗변 %-5s %s" % [ty, _five(ty, "d_c")])
	print("  중심u-빗변 전체 %8.2f %8.2f %8.2f %8.2f %8.2f"
			% [_lo("d_c"), _pct(_all("d_c"), 1.0), _pct(_all("d_c"), 50.0),
			_pct(_all("d_c"), 99.0), _hi("d_c")])
	print("  그림 왼끝-빗변 %8.2f %8.2f %8.2f %8.2f %8.2f"
			% [_lo("d_l"), _pct(_all("d_l"), 1.0), _pct(_all("d_l"), 50.0),
			_pct(_all("d_l"), 99.0), _hi("d_l")])
	print("  물리 hw끝-빗변 %8.2f %8.2f %8.2f %8.2f %8.2f"
			% [_lo("d_hw"), _pct(_all("d_hw"), 1.0), _pct(_all("d_hw"), 50.0),
			_pct(_all("d_hw"), 99.0), _hi("d_hw")])
	print("  → 쓸기 최대 이동거리(중심 기준) = %.2f px" % _hi("d_c"))

	print("\n── ③ w 밴드를 덮는 선분 ───────────────────────")
	var wa := _all("w")
	var w1: float = _pct(wa, 1.0)
	var w99: float = _pct(wa, 99.0)
	print("  중심 w   min~max  %.2f ~ %.2f   폭 %.2f  → 화면 %.2f px"
			% [wa[0], wa[wa.size() - 1], wa[wa.size() - 1] - wa[0],
			(wa[wa.size() - 1] - wa[0]) * g.TBL.flat])
	print("  중심 w   p1~p99   %.2f ~ %.2f   폭 %.2f  → 화면 %.2f px"
			% [w1, w99, w99 - w1, (w99 - w1) * g.TBL.flat])
	var fl := _all("w_lo")
	var fh := _all("w_hi")
	print("  발자국 w min~max  %.2f ~ %.2f   폭 %.2f  → 화면 %.2f px"
			% [fl[0], fh[fh.size() - 1], fh[fh.size() - 1] - fl[0],
			(fh[fh.size() - 1] - fl[0]) * g.TBL.flat])
	print("  발자국 w p1~p99   %.2f ~ %.2f   폭 %.2f  → 화면 %.2f px"
			% [_pct(fl, 1.0), _pct(fh, 99.0), _pct(fh, 99.0) - _pct(fl, 1.0),
			(_pct(fh, 99.0) - _pct(fl, 1.0)) * g.TBL.flat])
	print("  (트레이 상한 w_lo..w_hi = %.1f..%.1f → 화면 %.2f px)"
			% [g.DROP.w_lo, g.DROP.w_hi, (g.DROP.w_hi - g.DROP.w_lo) * g.TBL.flat])

	print("\n── ④ 화면 y 점유 ──────────────────────────────")
	print("  (각 칸은 그 타입 표본 전체의 top 최소 / bot 최대)")
	print("  타입      몸통만 t/b      | 그림자만 t/b    | 가격판만 t/b    | 몸통+그림자+가격판 | _obj_box t/b")
	for ty in ["item", "mod", "dart"]:
		var bt := _col(ty, "b_t")
		var bb := _col(ty, "b_b")
		var st := _col(ty, "s_t")
		var sb := _col(ty, "s_b")
		var pt := _col(ty, "p_t")
		var pb := _col(ty, "p_b")
		var xt := _col(ty, "x_t")
		var xb := _col(ty, "x_b")
		print("  %-5s %7.2f %7.2f | %7.2f %7.2f | %7.2f %7.2f | %7.2f %7.2f | %7.2f %7.2f"
				% [ty, bt[0], bb[bb.size() - 1], st[0], sb[sb.size() - 1],
				pt[0], pb[pb.size() - 1],
				minf(bt[0], minf(st[0], pt[0])),
				maxf(bb[bb.size() - 1], maxf(sb[sb.size() - 1], pb[pb.size() - 1])),
				xt[0], xb[xb.size() - 1]])
	var Bt: float = _lo("b_t")
	var Bb: float = _hi("b_b")
	var St: float = minf(Bt, _lo("s_t"))
	var Sb: float = maxf(Bb, _hi("s_b"))
	var Pt: float = minf(St, _lo("p_t"))
	var Pb: float = maxf(Sb, _hi("p_b"))
	print("  전체 몸통만          y [%.2f, %.2f]  높이 %.2f" % [Bt, Bb, Bb - Bt])
	print("  전체 몸통+그림자      y [%.2f, %.2f]  높이 %.2f" % [St, Sb, Sb - St])
	print("  전체 몸통+그림자+가격판 y [%.2f, %.2f]  높이 %.2f" % [Pt, Pb, Pb - Pt])
	print("  전체 몸통+가격판      y [%.2f, %.2f]  높이 %.2f"
			% [minf(Bt, _lo("p_t")), maxf(Bb, _hi("p_b")),
			maxf(Bb, _hi("p_b")) - minf(Bt, _lo("p_t"))])
	print("  (참고: 카운터 fy %.0f · 레일 ny %.0f)" % [g.TBL.fy, g.TBL.ny])
	var wo := _all("wob")
	print("  정착 순간 |wob| max %.4f  (몸통 ry 를 최대 %.2f배 늘린다 — 0.09초 내 소멸)"
			% [wo[wo.size() - 1], 1.0 + wo[wo.size() - 1] * 0.12])

	print("\n── ⑤ 화면 반폭 ────────────────────────────────")
	for ty in ["item", "mod", "dart"]:
		var mx := 0.0
		for r in rows[ty]:
			mx = maxf(mx, maxf(r.u - r.b_l, r.b_r - r.u))
		print("  %-5s  그려지는 반폭 max %6.2f · DROP.hw %5.1f"
				% [ty, mx, rows[ty][0].hw])
	var gmx := 0.0
	var gty := ""
	for ty in ["item", "mod", "dart"]:
		for r in rows[ty]:
			var h: float = maxf(r.u - r.b_l, r.b_r - r.u)
			if h > gmx:
				gmx = h
				gty = ty
	print("  → 최대 %.2f px (%s)" % [gmx, gty])

	print("\n── ⑥ 중심(지면점) 기준 최대 돌출 · psi 에만 걸린다 ──")
	print("  타입    위   아래 |그림자 위 아래|가격판 위 아래|  왼   오른")
	var UP := {}
	var DN := {}
	for ty in ["item", "mod", "dart"]:
		var up := 0.0
		var dn := 0.0
		var su := 0.0
		var sd := 0.0
		var pu := 0.0
		var pd := 0.0
		var lf := 0.0
		var rt := 0.0
		for r in rows[ty]:
			up = maxf(up, r.cy - r.b_t)
			dn = maxf(dn, r.b_b - r.cy)
			su = maxf(su, r.cy - r.s_t)
			sd = maxf(sd, r.s_b - r.cy)
			pu = maxf(pu, r.cy - r.p_t)
			pd = maxf(pd, r.p_b - r.cy)
			lf = maxf(lf, r.u - r.b_l)
			rt = maxf(rt, r.b_r - r.u)
		UP[ty] = maxf(up, maxf(su, pu))
		DN[ty] = maxf(dn, maxf(sd, pd))
		print("  %-5s %6.2f %6.2f | %5.2f %5.2f | %5.2f %5.2f | %5.2f %5.2f"
				% [ty, up, dn, su, sd, pu, pd, lf, rt])
	var mu := 0.0
	var md := 0.0
	for ty in ["item", "mod", "dart"]:
		mu = maxf(mu, UP[ty])
		md = maxf(md, DN[ty])
	print("  → 전부 포함 최대 돌출  위 %.2f · 아래 %.2f" % [mu, md])

	print("\n── ⑦ 이론 상한 (트레이 한계 w[%.0f,%.0f] · u[%.0f,%.0f]) ──"
			% [g.DROP.w_lo, g.DROP.w_hi, g.DROP.u_lo, g.DROP.u_hi])
	print("  화면 y (그림자·가격판 포함)  [%.2f, %.2f]  높이 %.2f"
			% [g._p2g(g.DROP.w_lo) - mu, g._p2g(g.DROP.w_hi) + md,
			g._p2g(g.DROP.w_hi) + md - (g._p2g(g.DROP.w_lo) - mu)])
	var hard := 0.0
	var hty := ""
	for ty in ["item", "mod", "dart"]:
		var hw: float = rows[ty][0].hw
		var d: float = (g.DROP.u_hi - hw) - g._chute_edge(g._p2g(g.DROP.w_hi))
		if d > hard:
			hard = d
			hty = ty
	print("  중심u-빗변 최대 = (u_hi - hw) - _chute_edge(_p2g(w_hi)) = %.2f px (%s)"
			% [hard, hty])
	print("  w 밴드 최대 = %.1f..%.1f → 화면 %.2f px"
			% [g.DROP.w_lo, g.DROP.w_hi, (g.DROP.w_hi - g.DROP.w_lo) * g.TBL.flat])

	print("\n── ⑧ 가로 도달 (팔이 훑어야 하는 x 구간) ──────")
	var bl := _all("b_l")
	var br := _all("b_r")
	print("  그려지는 왼끝 min %.2f · 오른끝 max %.2f" % [bl[0], br[br.size() - 1]])
	print("  빗변 x 는 %.2f~%.2f 이므로 훑을 x 구간 = [%.2f, %.2f]  폭 %.2f px"
			% [_lo("e"), _hi("e"), _lo("e"), br[br.size() - 1],
			br[br.size() - 1] - _lo("e")])
	print("")
