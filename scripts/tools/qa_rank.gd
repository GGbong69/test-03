extends SceneTree

#  등급 표식의 자 (2026-09-18). 사용자 지시 —
#    "동전의 등급도 사실 잘 모르겠어. 지금은 밑에 태그로 달려 있는데 그래도
#     잘 모르겠거든? … 레전더리랑 레어급들은 좀 외형적으로 변화가 있어도
#     잘 구분이 될 거 같아"
#
#  **그림이 아니라 값을 잰다.** 갈무리는 눈으로 보는 것이고, 여기는 눈이 못
#  보는 것을 본다 — 인접 색끼리의 대비와, 물리가 안 깨지는 유일한 조건인
#  「그려지는 것의 외접 반지름 ≤ TBL.chip_r」다.
#
#  **물리는 자가 못 잡는다.** 겹침은 충돌 원(A.r+B.r)만 재므로 그림이 원
#  밖으로 나가도 shot_shopsize 가 통과시킨다. 그래서 ⓕ 를 여기 따로 박는다.
#
#    godot --path . --headless --script scripts/tools/qa_rank.gd

const GameData = preload("res://scripts/data.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-40s %s" % ["통과" if c else "실패", n, d])


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


func _run() -> void:
	print("\n── 등급 표식 ───────────────────────────────")
	var tiers: Array = g.STK_TIERS
	var rank: Dictionary = g.RANK

	# ⓐ 표가 등급 목록과 같은 순서·이름인가
	var same := tiers.size() == GameData.RARITIES.size()
	if same:
		for i in tiers.size():
			if String(tiers[i].rarity) != String(GameData.RARITIES[i]):
				same = false
	_ok("STK_TIERS 가 RARITIES 와 같은 순서", same,
			"%d단" % tiers.size())

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

	# ⓒ **턱 색 != 옆면 색.** 이 한 줄이 그 회귀를 영구히 막는다 —
	#    고치기 전 레어·레전더리가 대비 1.00 으로 깨져 있었다.
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

	# ⓔ 밴드가 바깥 이웃과 갈리는가. 누운 자세는 펠트, 선 자세는 UI 배경이다
	print("  ── 밴드 대 바깥 이웃 ──")
	for t in tiers:
		if int(t.band) <= 0:
			continue
		var rc: Color = GameData.rarity_color(String(t.rarity))
		for nb in [["펠트", g.C_TABLE], ["C_DARK", g.C_DARK], ["C_BG", g.C_BG]]:
			var c := _cr(rc, nb[1])
			_ok("%s 밴드/%s >= 3:1" % [t.rarity, nb[0]], c >= 3.0, "%.2f" % c)

	# ⓕ **플라크 외접 반지름 <= TBL.chip_r.** 물리가 안 깨지는 유일한 조건이고
	#    다른 자가 못 잡는다. a²+b² 는 우연이 아니라 설계값이다.
	print("  ── 플라크의 안전선 ──")
	var pa: float = rank.plq_a
	var pb: float = rank.plq_b
	var pc: float = rank.plq_cut
	var chip: float = g.TBL.chip_r
	var hull := maxf(sqrt(pa * pa + (pb - pc) * (pb - pc)),
			sqrt((pa - pc) * (pa - pc) + pb * pb))
	_ok("a²+b² 가 chip_r 에 묶여 있다",
			absf(sqrt(pa * pa + pb * pb) - chip) < 0.01,
			"√(%.3f²+%.3f²) = %.3f · chip_r %.3f" % [pa, pb,
			sqrt(pa * pa + pb * pb), chip])
	_ok("그려지는 외접 반지름 <= chip_r", hull <= chip + 0.001,
			"%.2f <= %.2f (모서리를 깎아 더 안쪽이다)" % [hull, chip])

	# ⓖ 최악 기울임에서 아래끝 잉크가 _obj_box 안인가
	var tl: float = rank.plq_tilt
	var psd: float = float(g.TBL.chip_t) * float(g.TBL.tall) * float(rank.plq_side)
	var low: float = ((pa - pc) * sin(tl) + pb * cos(tl)) * float(g.TBL.flat)
	var boxry: float = float(g.TBL.chip_r) * float(g.TBL.flat) \
			+ float(g.TBL.chip_t) * float(g.TBL.tall)
	_ok("±10° 에서 아래끝 잉크 <= _obj_box 의 ry", low + psd <= boxry,
			"%.2f + %.2f = %.2f <= %.2f (여유 %.2f)"
			% [low, psd, low + psd, boxry, boxry - low - psd])

	# ⓗ 물린 원은 **안으로만** 판다. 밖으로 한 번이라도 나가면 물리가 깨진다
	var worst := 0.0
	for i in 720:
		var f: float = g._mill_f(TAU * float(i) / 720.0, chip, float(rank.mill_deep))
		worst = maxf(worst, f)
	_ok("물린 원의 최대 반지름 <= rx", worst <= 1.0 + 1e-6,
			"최대 배율 %.6f · 골 깊이 %.2f 면px" % [worst, rank.mill_deep])

	# ⓗ-b 말림 — 플라크는 활꼴이 아니라 볼록 다각형 자르기다(_plq_seg ·
	#    _plq_fold). 접는 선 **아래로 한 점도 안 새야** 한다 — 새면 떨어져
	#    나간 자리에 인쇄가 떠서 종이가 아니라 유령이 된다.
	print("  ── 말림(볼록 자르기) ──")
	var leak := 0
	var empty := 0
	for k in 9:
		var ly: float = lerpf(-pb * 0.8, pb * 0.9, float(k) / 8.0)
		var pp: PackedVector2Array = g._plq_pts(Vector2.ZERO, 0.12, pa, pb, pc,
				float(g.TBL.flat))
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
	_ok("말린 조각이 접는 선 아래로 안 샌다", leak == 0, "샌 점 %d개 / 9단" % leak)
	_ok("접는 선 안쪽에서는 윗조각이 남는다", empty <= 1,
			"빈 단 %d개 (맨 위 한 단은 비는 것이 맞다)" % empty)

	# ⓘ 맥동 — 광과민. 초당 3회 한계에서 멀찍이 떨어져 있어야 한다
	print("  ── 맥동 ──")
	for t in tiers:
		var per: float = float(t.pulse)
		if per <= 0.0:
			continue
		_ok("%s 맥동 주기 >= 2.0초" % t.rarity, per >= 2.0,
				"%.1f초 = %.2fHz (한계 3Hz 의 %.1f배 아래)"
				% [per, 1.0 / per, 3.0 * per])
	#    모션 끄기면 시계가 안 자란다 — dev 의 「모션 끄기/켜기」가 그대로
	#    「움직임을 뺀 상태에서도 등급이 읽히는가」를 재는 자가 된다.
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

	# ⓙ 작은 자리에서는 박음·물림을 안 그린다
	_ok("박음 바닥이 12 · 물림 바닥이 16",
			float(rank.r_spot) == 12.0 and float(rank.r_mill) == 16.0,
			"런 끝 10 · 툴팁 8 · 판 선택 뱃지 5.5 는 밴드 색만 남는다")

	# ⓚ 표에 등급마다 다섯이 다 있는가 — 어느 하나가 죽어도 나머지가 말한다
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

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
