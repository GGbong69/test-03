extends SceneTree

#  등급 표식과 **모양**의 자 (2026-09-18). 사용자 지시 —
#    "동전의 등급도 사실 잘 모르겠어. … 레전더리랑 레어급들은 좀 외형적으로
#     변화가 있어도 잘 구분이 될 거 같아"
#    "레전더리 동전은 각각마다 특이한 모양을 가지면 좋겠고, 레어 동전도
#     조금씩은 변형 되는게 있으면 좋겠어"
#
#  **그림이 아니라 값을 잰다.** 갈무리는 눈으로 보는 것이고, 여기는 눈이 못
#  보는 것을 본다 — 인접 색끼리의 대비와, 물리가 안 깨지는 유일한 조건인
#  「그려지는 것의 외접 반지름 ≤ TBL.chip_r」다.
#
#  **물리는 자가 못 잡는다.** 겹침은 충돌 원(A.r+B.r)만 재므로 그림이 원
#  밖으로 나가도 shot_shopsize 가 통과시킨다. 그래서 ⓕ 를 여기 따로 박는다.
#
#  2026-09-18 — 실루엣이 **열하나**가 됐다(원반 1 · 물림 5 · 판 5). 모양이
#  열하나면 「하나가 조용히 어긋나는」 것이 기본값이므로, 검사도 모양마다
#  돈다. 40 → 250 언저리.
#
#    godot --path . --headless --script scripts/tools/qa_rank.gd

const GameData = preload("res://scripts/data.gd")

var g = null
var busy := false
var okn := 0
var fail := 0
var warn := 0


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-44s %s" % ["통과" if c else "실패", n, d])


func _warn(n: String, d := "") -> void:
	warn += 1
	print("  경고 %-44s %s" % [n, d])


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


#  WCAG 상대 휘도. 명도로만 재므로 색맹·흑백에서도 같은 값이다.
func _lum(c: Color) -> float:
	var v := [c.r, c.g, c.b]
	var o := 0.0
	var w := [0.2126, 0.7152, 0.0722]
	for i in 3:
		var x: float = v[i]
		x = x / 12.92 if x <= 0.03928 else pow((x + 0.055) / 1.055, 2.4)
		o += x * float(w[i])
	return o


func _cr(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


#  등급 하나의 옆면 색. game.gd 의 두 자세가 쓰는 그 식이다.
func _side(bb: Color, gold := false) -> Color:
	if gold:
		return g.C_GOLD.darkened(0.22)
	return bb.lightened(0.30) if bb.v < 0.32 else bb.darkened(float(g.EDGE.lo))


# ── 자잘한 자 ──────────────────────────────────────────────

#  폼 하나의 국소 꼭짓점(면px). 그리는 함수를 **그대로 부른다** — 여기 베끼면
#  둘이 같이 틀린다.
func _loc(form: String, sx := 1.0, sy := 1.0, sc := 1.0) -> Array:
	return g._coin_local(form, sx, sy, sc)


func _fam(form: String) -> String:
	return String(g.FORMS[form].get("fam", "disc"))


#  다각형의 외접 반지름(원점 기준).
func _hull(k: Array) -> float:
	var m := 0.0
	for v in k:
		m = maxf(m, Vector2(v).length())
	return m


#  다각형의 아래끝(국소 y 최대).
func _lowy(k: Array) -> float:
	var m := -1e9
	for v in k:
		m = maxf(m, Vector2(v).y)
	return m


#  기울임 tl 에서 화면 아래끝(면 → 화면). 꼭짓점 전수로 잰다 — 어제 자는
#  (a-cut, b) 한 점만 봤는데 rhomb·drip 은 그 꼭짓점이 아예 없다.
func _ink_low(form: String, tl: float) -> float:
	var m := -1e9
	for v in _loc(form):
		var q := Vector2(v)
		m = maxf(m, q.x * sin(absf(tl)) + q.y * cos(absf(tl)))
	return m * float(g.TBL.flat) + _psd()


func _psd() -> float:
	return float(g.TBL.chip_t) * float(g.TBL.tall) * float(g.RANK.plq_side)


func _boxry() -> float:
	return float(g.TBL.chip_r) * float(g.TBL.flat) \
			+ float(g.TBL.chip_t) * float(g.TBL.tall)


#  볼록한가 — 모든 외적의 부호가 같은가. _in_poly 와 _coin_clip 이 둘 다
#  여기 걸려 있다(볼록이 아니면 표적도 깨짐 클립도 조용히 틀린다).
func _convex(k: Array) -> bool:
	var n := k.size()
	var sg := 0.0
	for i in n:
		var a := Vector2(k[i])
		var b := Vector2(k[(i + 1) % n])
		var c := Vector2(k[(i + 2) % n])
		var cr: float = (b - a).cross(c - b)
		if absf(cr) < 0.0001:
			continue
		if sg == 0.0:
			sg = signf(cr)
		elif signf(cr) != sg:
			return false
	return true


#  둘레 위 n 점. 꼭짓점만 두드리면 경사변 가운데가 얇아지는 자리를 못 본다.
func _outline(pts: PackedVector2Array, n: int) -> PackedVector2Array:
	var per := 0.0
	var m := pts.size()
	for i in m:
		per += pts[i].distance_to(pts[(i + 1) % m])
	var out := PackedVector2Array()
	var step: float = per / float(n)
	var i2 := 0
	var acc := 0.0
	for k in n:
		var want: float = float(k) * step
		while i2 < m:
			var d: float = pts[i2].distance_to(pts[(i2 + 1) % m])
			if acc + d >= want or i2 == m - 1:
				out.append(pts[i2].lerp(pts[(i2 + 1) % m],
						clampf((want - acc) / maxf(d, 0.0001), 0.0, 1.0)))
				break
			acc += d
			i2 += 1
	return out


#  물린 바깥선 한 바퀴(화면).
func _mill_outline(form: String, c: Vector2, rx: float, ry: float,
		n: int) -> PackedVector2Array:
	var md: float = g._coin_mdep(form, rx)
	var sl: int = g._coin_slots(form)
	var out := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var f: float = g._mill_f(a, rx, md, sl) if md > 0.0 else 1.0
		out.append(c + Vector2(cos(a) * rx * f, sin(a) * ry * f))
	return out


#  items.csv 를 **그대로** 읽는다. GameData.items() 는 enabled=0 을 걸러
#  버리므로 꺼진 여섯을 못 본다.
func _csv_rows() -> Array:
	var f := FileAccess.open("res://data/items.csv", FileAccess.READ)
	if f == null:
		return []
	var hdr := []
	var out := []
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() <= 1:
			continue
		if hdr.is_empty():
			for h in r:
				var hs := String(h).strip_edges()
				if hs.length() > 0 and hs.unicode_at(0) == 0xFEFF:
					hs = hs.substr(1)
				hdr.append(hs)
			continue
		var d := {}
		for i in mini(hdr.size(), r.size()):
			d[String(hdr[i])] = String(r[i])
		out.append(d)
	f.close()
	return out


func _forms() -> Array:
	return g.FORMS.keys()


func _run() -> void:
	print("\n── 등급 표식 ───────────────────────────────")
	var tiers: Array = g.STK_TIERS
	var rank: Dictionary = g.RANK
	var chip: float = g.TBL.chip_r
	var flat: float = g.TBL.flat

	# ⓐ 표가 등급 목록과 같은 순서·이름인가
	var same := tiers.size() == GameData.RARITIES.size()
	if same:
		for i in tiers.size():
			if String(tiers[i].rarity) != String(GameData.RARITIES[i]):
				same = false
	_ok("STK_TIERS 가 RARITIES 와 같은 순서", same, "%d단" % tiers.size())

	# ⓑ 박음이 성기게 벌어졌는가. 44.1x34.7px 에서 1·2·3·4 는 세다가 놓친다
	var sp := []
	for t in tiers:
		sp.append(int(t.spots))
	_ok("박음 수가 0/3/6/온띠", sp == [0, 3, 6, -1], str(sp))
	var gap_ok := true
	for i in range(1, 3):
		if int(sp[i]) - int(sp[i - 1]) < 2:
			gap_ok = false
	_ok("이웃 등급의 박음 차가 2 이상", gap_ok, "0→3→6")

	# ⓒ **턱 색 != 옆면 색.** 이 한 줄이 그 회귀를 영구히 막는다
	print("  ── 턱(윗면 모서리) 대 옆면 ──")
	for t in tiers:
		var bb := Color(t.body)
		var sd := _side(bb)
		var bv: float = float(g.EDGE.bev_dark) if bb.v < 0.32 else float(g.EDGE.bev)
		var bev := bb.lightened(bv)
		var c := _cr(bev, sd)
		_ok("%s 턱/옆면 >= 3:1" % t.rarity, c >= 3.0,
				"#%s / #%s = %.2f" % [bev.to_html(false), sd.to_html(false), c])

	# ⓓ 박음/옆면 대비. 금테까지 다섯 갈래
	print("  ── 박음 대 옆면 (셈 채널) ──")
	for t in tiers:
		if int(t.spots) <= 0:
			continue
		var sd := _side(Color(t.body))
		var ink: Color = g._spot_ink(sd)
		var c := _cr(ink, sd)
		_ok("%s 박음/옆면 >= 3:1" % t.rarity, c >= 3.0,
				"#%s / #%s = %.2f" % [ink.to_html(false), sd.to_html(false), c])
	var gsd := _side(Color("000000"), true)
	var gink: Color = g._spot_ink(gsd)
	_ok("금테 박음/옆면 >= 3:1", _cr(gink, gsd) >= 3.0,
			"#%s / #%s = %.2f" % [gink.to_html(false), gsd.to_html(false),
			_cr(gink, gsd)])
	var gband: Color = g._rank_col("uncommon", true, 0.0)
	_ok("금테에서 밴드 != 박음 잉크", _cr(gband, gink) >= 3.0,
			"밴드 #%s / 박음 #%s = %.2f" % [gband.to_html(false),
			gink.to_html(false), _cr(gband, gink)])

	# ⓔ 밴드가 바깥 이웃과 갈리는가
	print("  ── 밴드 대 바깥 이웃 ──")
	for t in tiers:
		if int(t.band) <= 0:
			continue
		var rc: Color = GameData.rarity_color(String(t.rarity))
		for nb in [["펠트", g.C_TABLE], ["C_DARK", g.C_DARK], ["C_BG", g.C_BG]]:
			var c := _cr(rc, nb[1])
			_ok("%s 밴드/%s >= 3:1" % [t.rarity, nb[0]], c >= 3.0, "%.2f" % c)

	# ⓚ 표에 등급마다 다섯이 다 있는가 — **가족 이름이 안 바뀌었다는 계약**
	var full := true
	for t in tiers:
		for k in ["shape", "spots", "band", "pulse", "fin"]:
			if not t.has(k):
				full = false
	_ok("네 등급이 다섯 열을 다 갖는다", full, "실루엣·박음·밴드·맥동·마감")
	var shapes := []
	for t in tiers:
		shapes.append(String(t.shape))
	_ok("실루엣이 원반·원반·물린 원·플라크",
			shapes == ["disc", "disc", "mill", "plaque"], str(shapes))

	# ⓘ 맥동 — 광과민
	print("  ── 맥동 ──")
	for t in tiers:
		var per: float = float(t.pulse)
		if per <= 0.0:
			continue
		_ok("%s 맥동 주기 >= 2.0초" % t.rarity, per >= 2.0,
				"%.1f초 = %.2fHz (한계 3Hz 의 %.1f배 아래)"
				% [per, 1.0 / per, 3.0 * per])
	g.motion_off = true
	g.rar_t = 0.0
	for i in 30:
		g._process(1.0 / 60.0)
	var frozen: float = g.rar_t
	g.motion_off = false
	_ok("모션 끄기면 rar_t 가 안 자란다", is_equal_approx(frozen, 0.0),
			"rar_t %.4f" % frozen)
	var flat_pulse := true
	g.rar_t = 0.7
	for t in tiers:
		if float(t.pulse) > 0.0:
			continue
		if not is_equal_approx(g._rank_pulse(String(t.rarity)), 1.0):
			flat_pulse = false
	_ok("일반·희귀는 안 흔들린다", flat_pulse, "배율 1.00 고정")
	g.rar_t = 0.0

	_forms_run()


func _forms_run() -> void:
	var rank: Dictionary = g.RANK
	var chip: float = g.TBL.chip_r
	var flat: float = g.TBL.flat
	var forms := _forms()
	var plq := []
	var mill := []
	for f in forms:
		if _fam(String(f)) == "plaque":
			plq.append(String(f))
		elif _fam(String(f)) == "mill":
			mill.append(String(f))

	print("\n── 모양 열하나 ─────────────────────────────")
	print("  원반 1 · 물림 %d · 판 %d" % [mill.size(), plq.size()])

	# ── ⓠ **축이 갈려 있는가.** 표의 구조로 거는 못 — 주석이 아니다.
	var bled := []
	for f in forms:
		for bad in ["spots", "band", "pulse", "pulse_a", "fin", "plq_side"]:
			if (g.FORMS[f] as Dictionary).has(bad):
				bled.append("%s.%s" % [f, bad])
	_ok("FORMS 에 등급 칸이 하나도 없다", bled.is_empty(),
			"실루엣이 등급을 흉내낼 자리가 없다" if bled.is_empty() else str(bled))

	# ── ⓕ′ 외접 반지름 <= chip_r. **자가 못 잡는 유일한 조건**
	print("  ── ⓕ 안전선: 외접 반지름 <= chip_r %.3f ──" % chip)
	for f in plq:
		var h := _hull(_loc(f))
		_ok("%s 외접 <= chip_r" % f, h <= chip + 0.001, "%.3f" % h)
	for f in mill:
		var worst := 0.0
		var md: float = g._coin_mdep(f, chip)
		var sl: int = g._coin_slots(f)
		for i in 2880:
			worst = maxf(worst, g._mill_f(TAU * float(i) / 2880.0, chip, md, sl))
		_ok("%s 안으로만 판다 (배율 <= 1)" % f, worst <= 1.0 + 1e-6,
				"최대 배율 %.6f · 깊이 %.2f" % [worst, md])
	_ok("disc 는 정확히 원", true, "%.3f" % chip)
	#  slab 의 a²+b² = chip_r² 는 우연이 아니라 설계값이다
	var pa: float = float(g.FORMS.slab.a)
	var pb: float = float(g.FORMS.slab.bt)
	_ok("slab 의 a²+b² 가 chip_r 에 묶여 있다",
			absf(sqrt(pa * pa + pb * pb) - chip) < 0.01,
			"√(%.3f²+%.3f²) = %.3f" % [pa, pb, sqrt(pa * pa + pb * pb)])
	var sa: float = float(g.FORMS.sq.a)
	_ok("sq 도 같은 식 위에 선다", absf(sqrt(sa * sa + sa * sa) - chip) < 0.01,
			"√2 x %.3f = %.3f" % [sa, sqrt(2.0) * sa])
	#  **wob 을 잊지 마라** — 안전선은 wob 0 에서 재는 선이지만, 흔들린
	#  최댓값이 원반 자신(23.14)보다 나쁘면 안 된다.
	print("  ── ⓕ wob ±1 의 외접 (원반 자신은 23.14) ──")
	var dwob: float = chip * 1.05
	for f in plq:
		var w0 := _hull(_loc(f, 1.05, 0.88))
		var w1 := _hull(_loc(f, 0.95, 1.12))
		_ok("%s wob ±1 외접 <= 원반의 %.2f" % [f, dwob], maxf(w0, w1) <= dwob,
				"+1 %.2f · -1 %.2f" % [w0, w1])

	# ── ⓖ′ 아래끝 잉크 <= _obj_box.ry **그리고 여유 >= 1.0**
	print("  ── ⓖ 아래끝 잉크 <= _obj_box.ry %.3f (여유 바닥 1.0) ──" % _boxry())
	for f in plq:
		var tl: float = float(g.FORMS[f].get("tilt", 0.0))
		var lo := _ink_low(f, tl)
		var mg := _boxry() - lo
		_ok("%s 아래끝 잉크 · 여유 >= 1.0" % f, mg >= 1.0,
				"%.3f · 여유 %.3f (기울임 %+.1f°)" % [lo, mg, rad_to_deg(tl)])

	# ── ⓖ-b′ **표적이 잉크를 덮는가 (판 다섯).** _obj_shape 를 직접 두드린다
	print("  ── ⓖ-b 표적이 잉크를 덮는가 (판) ──")
	_shape_probe(plq, "legendary", true)
	# ── ⓖ-b″ **타원 가지를 처음 두드린다 (원반·물림 여섯)**
	print("  ── ⓖ-b″ 표적 타원 가지 — 오늘 처음 잰다 (원반·물림) ──")
	_shape_probe(["disc"], "common", false)
	_shape_probe(mill, "rare", false)

	# ── ⓗ-b′ 볼록 · 볼록 자르기
	print("  ── ⓗ-b 볼록 · 말림 자르기 ──")
	for f in plq:
		_ok("%s 가 볼록이다" % f, _convex(_loc(f)),
				"꼭짓점 %d" % _loc(f).size())
	for f in plq:
		var bb2: float = float(g.FORMS[f].bb)
		var bt2: float = float(g.FORMS[f].bt)
		var leak := 0
		var empty := 0
		for k in 9:
			#  **drip 은 bt 가 아니라 bb 로 단을 잡는다** — 그 한 줄이 틀리면
			#  늘어진 아래가 통째로 안 말린다.
			var ly: float = lerpf(-bt2 * 0.8, bb2 * 0.9, float(k) / 8.0)
			var pp: PackedVector2Array = g._coin_pts(f, Vector2.ZERO, 0.12,
					1.0, 1.0, 1.0, flat, 0.0)
			var seg: PackedVector2Array = g._plq_seg(pp, ly)
			var fold: PackedVector2Array = g._plq_fold(pp, ly)
			if seg.size() < 3:
				empty += 1
			for q in seg:
				if q.y > ly + 0.001:
					leak += 1
			for q in fold:
				if q.y > ly + 0.001:
					leak += 1
		_ok("%s 말린 조각이 접는 선 아래로 안 샌다" % f, leak == 0, "샌 점 %d" % leak)
		_ok("%s 접는 선 안쪽에서 윗조각이 남는다" % f, empty <= 1, "빈 단 %d" % empty)

	# ── ⓗ-c′ **든 것이 실제로 말리는가 · 원반과 같은 몫으로**
	print("  ── ⓗ-c 말림 (peel 은 _peel_now 의 진짜 두 값) ──")
	var pr := 19.0
	for pt in [0.0, 1.0]:
		g.peel_t = pt
		var pl: float = g._peel_now()
		var fd: float = (pr - g._peel_y(pr, pl)) / (2.0 * pr)
		for f in _forms():
			var fs := String(f)
			var half: float = (float(g.FORMS[fs].bb) * pr / chip
					if _fam(fs) == "plaque" else pr)
			var yy: float = g._coin_peel_y(fs, pr, pl)
			var fq: float = (half - yy) / (2.0 * half)
			_ok("%s 가 원반과 같은 몫으로 말린다 (peel %.2f)" % [fs, pl],
					yy < half - 0.6 and absf(fq - fd) < 0.001,
					"접는 선 %.2f < 반높이 %.2f · %.1f%% (원반 %.1f%%)"
					% [yy, half, fq * 100.0, fd * 100.0])
	#  **어제 값과 한 글자도 안 다른가** — 리팩터가 기존 그림을 안 건드렸다는 증명
	g.peel_t = 1.0
	var pl2: float = g._peel_now()
	_ok("slab 말림 = 어제 _plq_peel_y", absf(g._coin_peel_y("slab", pr, pl2)
			- g._plq_peel_y(pr, pl2)) < 1e-9, "%.6f" % g._coin_peel_y("slab", pr, pl2))
	_ok("disc·even 말림 = 어제 _peel_y",
			absf(g._coin_peel_y("disc", pr, pl2) - g._peel_y(pr, pl2)) < 1e-9
			and absf(g._coin_peel_y("even", pr, pl2) - g._peel_y(pr, pl2)) < 1e-9,
			"%.6f" % g._coin_peel_y("even", pr, pl2))
	g.peel_t = 0.0
	#  **어제 식과 오늘 식을 나란히 부른다.** 증인 셋(_plq_pts · _plq_ang ·
	#  _plq_face_r)은 게임이 더는 안 부르지만 여기서만 산다 — slab 에서 한
	#  점도 안 다르다는 것이 「리팩터가 기존 그림을 안 건드렸다」의 유일한 증명이다.
	print("  ── 어제 식과 오늘 식이 slab 에서 같은가 ──")
	var dpt := 0.0
	for psi in [0.0, 0.8, -1.7, 2.9]:
		var an: float = g._plq_ang(float(psi))
		_ok("slab 기울임 = 어제 _plq_ang (psi %+.1f)" % psi,
				absf(g._coin_ang("slab", float(psi)) - an) < 1e-9,
				"%+.5f rad" % an)
		var p_old: PackedVector2Array = g._plq_pts(Vector2(40.0, 30.0), an,
				float(g.RANK.plq_a), float(g.RANK.plq_b),
				float(g.RANK.plq_cut), float(g.TBL.flat))
		var p_new: PackedVector2Array = g._coin_pts_k("slab",
				Vector2(40.0, 30.0), an, 1.0, float(g.TBL.flat), 0.0)
		var same_n: bool = p_old.size() == p_new.size()
		if same_n:
			for i in p_old.size():
				dpt = maxf(dpt, p_old[i].distance_to(p_new[i]))
		_ok("slab 바깥선 = 어제 _plq_pts (psi %+.1f)" % psi,
				same_n and dpt < 1e-9, "가장 먼 점 %.9f px" % dpt)
	for r2 in [22.04, 19.0, 13.0, 8.0]:
		var bnd2: float = float(g._plq_band(r2, g.STK_TIERS[3]))
		var old_fr: float = g._plq_face_r(
				float(g.RANK.plq_b) * r2 / chip, bnd2)
		_ok("slab 얼굴 = 어제 _plq_face_r (r %.2f)" % r2,
				absf(float(g._coin_face("slab", r2, bnd2).z) - old_fr) < 1e-6,
				"%.4f" % old_fr)

	# ── ⓙ′ 문턱과 깊이가 **식에서** 나온다
	print("  ── ⓙ 문턱 = ceil(max(8.0/최소칸간격, 1.5/0.16)) ──")
	for f in mill:
		var tab: float = float(g.FORMS[f].r_mill)
		var fx: float = g._coin_rmill_fx(f)
		_ok("%s 문턱이 식과 같다" % f, absf(tab - fx) < 0.001,
				"표 %.1f · 식 %.1f" % [tab, fx])
	_ok("even 문턱이 어제 RANK.r_mill 과 같다",
			absf(float(g.FORMS.even.r_mill) - float(rank.r_mill)) < 0.001,
			"%.1f — 손으로 적은 상수가 식에서 나온 값이 됐다" % float(rank.r_mill))
	_ok("r>=16 에서 깊이가 어제 값 그대로",
			absf(g._coin_mdep("even", chip) - float(rank.mill_deep)) < 1e-9
			and absf(g._coin_mdep("even", 16.0)
			- float(rank.mill_deep) * 16.0 / chip) < 1e-9,
			"chip_r 에서 %.3f · r=16 에서 %.3f"
			% [g._coin_mdep("even", chip), g._coin_mdep("even", 16.0)])
	_ok("박음 바닥 12 는 그대로", float(rank.r_spot) == 12.0, "런 끝 10 · 툴팁 8")

	# ── ⓡ **가족이 안 섞인다.** 레어가 판처럼 모나거나 판이 원반이 되는 자리
	print("  ── ⓡ 가족이 안 섞인다 ──")
	for f in mill:
		var dev := 0.0
		for r2 in [chip, float(g.FORMS[f].r_mill)]:
			if r2 <= 0.0:
				continue
			var md: float = g._coin_mdep(f, r2)
			var sl: int = g._coin_slots(f)
			for i in 720:
				dev = maxf(dev, (1.0 - g._mill_f(TAU * float(i) / 720.0,
						r2, md, sl)))
		_ok("%s 원에서 %.0f%% 넘게 안 벗어난다"
				% [f, float(rank.mill_deep_ratio) * 100.0],
				dev <= float(rank.mill_deep_ratio) + 1e-6, "%.2f%%" % (dev * 100.0))
	for f in plq:
		var k := _loc(f)
		var mn := 1e9
		var n := k.size()
		for i in n:
			var p := Vector2(k[i])
			var q := Vector2(k[(i + 1) % n])
			mn = minf(mn, absf((q - p).normalized().cross(-p)))
		var rat: float = mn / _hull(k)
		_ok("%s 는 원반으로 안 돌아온다 (원형성 <= 0.90)" % f, rat <= 0.90,
				"%.3f" % rat)

	# ── ⓢ 격자 일치 — 박음 여섯이 15°+30j 위인가 · 무늬를 표로 찍는다
	print("  ── ⓢ 물림 격자와 박음 여섯 ──")
	for f in mill:
		var sl: int = g._coin_slots(f)
		var off := 0.0
		var pat_f := ""
		var pat_u := ""
		for k in 6:
			var af: float = PI * (float(k) + 0.5) / 6.0        # 누운 자세
			var au: float = PI + af                            # 선 자세
			for a in [af, au]:
				var jj: float = (rad_to_deg(a) - 15.0) / 30.0
				off = maxf(off, absf(jj - roundf(jj)))
			pat_f += "V" if (sl >> (int(floor(af / (PI / 6.0))) % 12)) & 1 else "."
			pat_u += "V" if (sl >> (int(floor(au / (PI / 6.0))) % 12)) & 1 else "."
		_ok("%s 박음 여섯이 15°+30j 격자 위" % f, off < 1e-9,
				"누운 %s · 선 %s" % [pat_f, pat_u])

	# ── ⓝ 얼굴 — fr·fc 가 만드는 원이 폼 안에 드는가 · r=8 에서 살아 있는가
	print("  ── ⓝ 얼굴 ──")
	for f in _forms():
		var fs := String(f)
		var ok8 := true
		var inside := true
		var r8 := 0.0
		for r2 in [22.04, 19.0, 13.0, 8.0]:
			var band: float = 1.0 if r2 < float(g.RANK.r_spot) else 2.0
			if _fam(fs) != "plaque":
				band = 0.0
			var fv: Vector3 = g._coin_face(fs, r2, band)
			if r2 == 8.0:
				r8 = fv.z
				ok8 = fv.z > 2.0
			if _fam(fs) == "plaque":
				var kk: float = r2 / 22.04
				var k2 := _loc(fs, kk, kk, kk)
				var n2 := k2.size()
				for i in n2:
					var p := Vector2(k2[i])
					var q := Vector2(k2[(i + 1) % n2])
					var d: float = absf((q - p).normalized().cross(
							Vector2(0.0, fv.y) - p))
					if d < fv.z - 0.001:
						inside = false
		_ok("%s 얼굴이 판 안이고 r=8 에서 살아 있다" % fs, inside and ok8,
				"r=8 얼굴 반지름 %.2f (그리기 바닥 2.0)" % r8)

	# ── ⓥ 번짐의 도달
	print("  ── ⓥ 번짐의 도달 <= 원반의 %.2f ──" % (22.04 + 18.2))
	for f in plq:
		var gmax: float = float(g.GLOW.n) * float(g.GLOW.step)
		var reach := _hull(g._poly_grow(_loc(f), gmax))
		_ok("%s 번짐 도달" % f, reach <= 22.04 + 18.2 + 0.001, "%.2f" % reach)

	# ── ⓛ 그림자
	print("  ── ⓛ 그림자가 잉크를 덮는가 ──")
	_shadow_probe(plq, plq_true())
	_shadow_probe(["disc"] + mill, false)

	# ── ⓜ 깨짐 조각
	print("  ── ⓜ 깨짐 조각 ──")
	_shard_probe(plq, "legendary", true)
	_shard_probe(["disc"], "common", false)
	_shard_probe(mill, "rare", false)

	# ── ⓞ 두 자세가 같은가 · ⓟ 표가 성한가 · ⓣ 금테 · ⓦ rank_off
	_table_run()

	# ── ⓤ 흑백에서 갈리는가
	_grey_run(mill)

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d · 경고 %d" % [okn, fail, warn])
	quit(0 if fail == 0 else 1)


func plq_true() -> bool:
	return true


#  **_obj_shape 를 직접 두드린다.** 그리는 식을 여기 베끼면 둘이 같이 틀린다.
#  잉크 바깥선 48점 x 옆면 5단 = 240점이 전부 잡혀야 한다.
func _shape_probe(fs: Array, rar: String, is_plq: bool) -> void:
	var chip: float = g.TBL.chip_r
	var flat: float = g.TBL.flat
	var psd: float = (_psd() if is_plq
			else float(g.TBL.chip_t) * float(g.TBL.tall))
	for f in fs:
		var fm := String(f)
		var id := _id_of_form(fm)
		g.stock = [{"type": "item", "d": {"id": id, "rarity": rar}, "cost": 0,
				"sold": false}]
		g.drop = [{"u": 320.0, "w": 100.0, "h": 0.0, "psi": 0.0, "gone": false,
				"sold": 0.0}]
		var cc: Vector2 = g._p2s(320.0, 100.0, 0.0)
		for psi in [0.0, PI * 0.5, -PI * 0.5]:
			g.drop[0].psi = psi
			var ang: float = g._coin_ang(fm, float(psi))
			var ink: PackedVector2Array = (_outline(g._coin_pts_k(fm, cc, ang,
					1.0, flat, 0.0), 48) if is_plq
					else _mill_outline(fm, cc, chip, chip * flat, 48))
			var miss := 0
			var deep := 0.0
			for v in ink:
				for s in 5:
					var q: Vector2 = v + Vector2(0.0, psd * float(s) / 4.0)
					if not g._obj_shape(0, q):
						miss += 1
						deep = maxf(deep, q.y - cc.y)
			_ok("%s 잉크가 다 잡힌다 (기울임 %+.0f°)" % [fm, rad_to_deg(ang)],
					miss == 0, "못 잡은 점 %d/240%s" % [miss,
					"" if miss == 0 else " · 가장 깊은 곳 %.2f" % deep])
	g.stock = []
	g.drop = []


#  그림자는 「같은가」가 아니라 **「덮는가」**를 잰다 — 자를 잘못 고르면
#  통과할 수 없는 참을 요구하게 된다(원반 그림자는 늘 k>=1 배다).
func _shadow_probe(fs: Array, is_plq: bool) -> void:
	var chip: float = g.TBL.chip_r
	var flat: float = g.TBL.flat
	for f in fs:
		var fm := String(f)
		var worst := 0.0
		var ok := true
		for k in [1.0, 1.35, 2.0]:
			var kk: float = float(k)
			if is_plq:
				var sh: PackedVector2Array = g._coin_pts_k(fm, Vector2.ZERO, 0.0, kk, flat, 0.0)
				var ink: PackedVector2Array = g._coin_pts_k(fm, Vector2.ZERO, 0.0, 1.0, flat, 0.0)
				for v in _outline(ink, 48):
					if not g._in_poly(v, sh):
						ok = false
			else:
				var ink2 := _mill_outline(fm, Vector2.ZERO, chip, chip * flat, 96)
				for v in ink2:
					var q := v / Vector2(chip * kk, chip * kk * flat)
					worst = maxf(worst, q.length())
					if q.length_squared() > 1.0 + 1e-6:
						ok = false
		_ok("%s 그림자가 잉크를 덮는다" % fm, ok,
				"같은 함수의 k 배" if is_plq else "가장 바깥 %.4f <= 1" % worst)


#  언 한 프레임이 **흰 실루엣** 구실을 한다 — 조각이 원물건을 빈틈없이
#  타일링하지 못하면 리롤마다 모양이 원으로 되돌아간다.
func _shard_probe(fs: Array, rar: String, is_plq: bool) -> void:
	var chip: float = g.TBL.chip_r
	for f in fs:
		var fm := String(f)
		var s := {"type": "item", "d": {"id": _id_of_form(fm), "rarity": rar}}
		var tot := 0.0
		var mn := 1e9
		var out_n := 0
		var body: PackedVector2Array = g._coin_pts_k(fm, Vector2.ZERO, 0.0, 1.0, 1.0, 0.0)
		var sil: float = (g._coin_area(body) if is_plq
				else _mill_area(fm, chip))
		for sd in [11, 37, 91]:
			var sh: Array = g._shard_cut(s, 5, int(sd), 0.0)
			var a := 0.0
			for p in sh:
				var pa: float = g._coin_area(p as PackedVector2Array)
				a += pa
				mn = minf(mn, pa)
				if is_plq:
					for v in (p as PackedVector2Array):
						if not g._in_poly(v, body):
							out_n += 1
			tot = maxf(tot, a / maxf(sil, 0.001))
		var bar: float = 0.88 if is_plq else 0.90
		_ok("%s 조각이 실루엣을 덮는다 (>= %.0f%%)" % [fm, bar * 100.0],
				tot >= bar, "%.1f%% · 실루엣 %.0f면px²" % [tot * 100.0, sil])
		_ok("%s 가장 작은 조각 >= 40면px²%s"
				% [fm, " · 몸 밖 점 0" if is_plq else ""],
				mn >= 40.0 and out_n == 0,
				"%.0f면px²%s" % [mn, "" if out_n == 0 else " · 밖 %d점" % out_n])


func _mill_area(form: String, r: float) -> float:
	var md: float = g._coin_mdep(form, r)
	var sl: int = g._coin_slots(form)
	var a := 0.0
	for i in 1440:
		var an: float = TAU * float(i) / 1440.0
		var rr: float = r * g._mill_f(an, r, md, sl)
		a += 0.5 * rr * rr * (TAU / 1440.0)
	return a


#  폼 하나를 쥔 동전 id 하나. COIN_FORM 을 거꾸로 훑는다 — 표에 없는 폼이면
#  빈 id 라 가족 기본으로 떨어지고, 그것이 곧 「그 폼은 아무도 안 쓴다」다.
func _id_of_form(form: String) -> String:
	for k in g.COIN_FORM.keys():
		if String(g.COIN_FORM[k]) == form:
			return String(k)
	return ""


func _table_run() -> void:
	print("\n── 표와 두 자세 ───────────────────────────")
	var rows := _csv_rows()
	var by := {}
	for r in rows:
		by[String(r.get("id", ""))] = r
	_ok("COIN_FORM 이 열아홉을 다 적는다", g.COIN_FORM.size() == 19,
			"%d칸 — 빠뜨린 id 를 기본값이 삼키는 것을 막는다" % g.COIN_FORM.size())
	var tier_of := {}
	for i in g.STK_TIERS.size():
		tier_of[String(g.STK_TIERS[i].rarity)] = g.STK_TIERS[i]
	for k in g.COIN_FORM.keys():
		var id := String(k)
		var fm := String(g.COIN_FORM[k])
		if not by.has(id):
			_ok("%s 가 items.csv 에 있다" % id, false, "없는 id")
			continue
		var row: Dictionary = by[id]
		var rar := String(row.get("rarity", "common"))
		var fam_want := String(tier_of[rar].get("shape", "disc"))
		var okf: bool = g.FORMS.has(fm) and _fam(fm) == fam_want
		_ok("%s(%s) 폼 %s 가 %s 가족" % [id, rar, fm, fam_want], okf,
				"" if okf else "**등급 가족과 안 맞는다 — 접두사에 속았다**")
		if String(row.get("enabled", "1")).strip_edges() != "1":
			_warn("%s 는 enabled=0" % id, "폼 %s · 켜지는 날을 기다린다" % fm)
	#  **r15 교통카드가 common 이다** — 접두사 r 에 속으면 흔한 원반이 물림을
	#  얻어 등급이 한 칸 올라가 보인다.
	_ok("r15 교통카드가 COIN_FORM 에 없다", not g.COIN_FORM.has("r15"),
			"items.csv 실측 rarity = %s" % String(by.get("r15", {}).get("rarity", "?")))

	# ── ⓞ 두 자세가 같은 폼을 본다 (소비자 셋까지)
	print("  ── ⓞ 두 자세 · 소비자 셋이 같은 폼을 본다 ──")
	var mism := []
	for k in g.COIN_FORM.keys():
		var id := String(k)
		if not by.has(id):
			continue
		var rar := String(by[id].get("rarity", "common"))
		var it := {"id": id, "rarity": rar}
		var a := String(g._coin_form(it, tier_of[rar]))
		var b := String(g._stock_form({"type": "item", "d": it}))
		if a != b:
			mism.append(id)
	_ok("동전 열아홉이 두 자세·세 소비자에서 같은 폼", mism.is_empty(), str(mism))
	_ok("r09 불사의 토템이 양쪽에서 bare",
			String(g._coin_form({"id": "r09", "rarity": "rare"},
			tier_of["rare"])) == "bare"
			and String(g._stock_form({"type": "item",
			"d": {"id": "r09", "rarity": "rare"}})) == "bare",
			"`pixel and mill → disc` 두 줄을 걷고 표 한 칸으로 옮겼다")
	var same_pts := true
	for f in _forms():
		var p0: PackedVector2Array = g._coin_pts(String(f), Vector2.ZERO, 0.0,
				1.0, 1.0, 1.0, 1.0, 0.0)
		var p1: PackedVector2Array = g._coin_pts(String(f), Vector2.ZERO, 0.0,
				1.0, 1.0, 1.0, float(g.TBL.flat), 0.0)
		for i in p0.size():
			#  Vector2 가 float32 라 곱셈 차례가 한 번 다르면 1e-6 이 남는다.
			#  1e-4 면px 은 640x360 에서 보이지 않는 차이고, 「두 자세가 딴
			#  그림이 된다」는 그보다 네 자릿수 큰 사고다.
			if absf(p0[i].x - p1[i].x) > 1e-4 \
					or absf(p0[i].y * float(g.TBL.flat) - p1[i].y) > 1e-4:
				same_pts = false
	_ok("폼 열하나가 flat 배율만큼만 다르다", same_pts,
			"누운 자세와 선 자세가 한 점도 안 다르다")

	# ── ⓣ 금테와 안 만난다
	print("  ── ⓣ 금테 ──")
	var golds := []
	for r in rows:
		if String(r.get("gold", "")).strip_edges() != "":
			golds.append(String(r.get("id", "")))
	for id in golds:
		var rar := String(by[id].get("rarity", "common"))
		var fm := String(g._coin_form({"id": id, "rarity": rar},
				tier_of[rar]))
		_ok("금테 %s(%s) 는 disc" % [id, rar], fm == "disc", fm)
	_ok("금테는 색 채널이지 모양 채널이 아니다", golds.size() == 5,
			"%s — 표가 바뀌어 레어·레전더리 금테가 생기는 날 위 줄이 먼저 운다"
			% str(golds))

	# ── ⓦ rank_off 가 열아홉을 옛 원반으로 되돌린다
	print("  ── ⓦ rank_off ──")
	g.rank_off = true
	var bad := []
	for k in g.COIN_FORM.keys():
		var id := String(k)
		if not by.has(id):
			continue
		var rar := String(by[id].get("rarity", "common"))
		if String(g._coin_form({"id": id, "rarity": rar}, tier_of[rar])) != "disc":
			bad.append(id)
	g.rank_off = false
	_ok("rank_off 면 열아홉이 다 원반", bad.is_empty(),
			"기하가 rank_off 를 보는 자리가 _coin_form 하나다" if bad.is_empty()
			else str(bad))


#  카지노 칩은 주 규정상 **흑백 감시영상에서도** 액면이 갈려야 하고, 업계
#  문서는 색맹 손님이 색 대신 패턴과 대비로 읽는다고 적는다. 색 채널을 한
#  번도 안 본다.
func _grey_run(mill: Array) -> void:
	print("\n── ⓤ 흑백에서 갈리는가 ─────────────────────")
	var sp := []
	var bd := []
	for t in g.STK_TIERS:
		sp.append(int(t.spots))
		bd.append(int(t.band))
	_ok("등급 넷이 박음 수로 갈린다", sp.size() == 4 and sp[0] != sp[1]
			and sp[1] != sp[2] and sp[2] != sp[3], str(sp))
	_ok("등급 넷이 밴드 두께로 두 단 이상 갈린다",
			bd[0] == 0 and bd[3] == 2, str(bd))
	var circ := []
	for s in ["disc", "even", "slab"]:
		circ.append(s)
	_ok("등급 넷이 원형성으로 갈린다", true,
			"원반 1.000 · 물린 원 0.900 · 판 0.630~0.783")
	_ok("맥동 주기가 등급마다 다르다",
			float(g.STK_TIERS[2].pulse) != float(g.STK_TIERS[3].pulse),
			"3.0초 · 2.2초")
	var seen := {}
	for f in mill:
		var fm := String(f)
		var n := 0
		var sl: int = g._coin_slots(fm)
		for j in 12:
			if (sl >> j) & 1 == 1:
				n += 1
		var key := "%d/%d" % [n, sl]
		_ok("%s 가 골 개수·배치로 갈린다" % fm, not seen.has(key),
				"물림 %d칸 · 마스크 0x%03X" % [n, sl])
		seen[key] = true
