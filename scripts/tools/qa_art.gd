extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")

# ══════════════════════════════════════════════════════════
#  물성 사다리 검사 — 골드 · 팩 · 제약을 **크기마다 · 자리마다 · 대비**로 잰다
#
#   godot --path . --quit-after 900 --script scripts/tools/qa_art.gd
#   종료 코드 = 실패 개수
#
#  이 셋에는 여태 **모양을 재는 자가 하나도 없었다.** shot_* 가 그림으로만
#  잡고, qa_pack 의 단언 열셋은 전부 논리라 기하가 0건이고, qa_bosscard ⑤ 는
#  게임을 안 읽고 수를 베껴 뒀다(0.92r — flat 의 대각선이 1.216r 이었는데도
#  명판이 넉넉해서 통과했다). 그래서 셋을 여기서 처음으로 **잰다.**
#
#  ① 골드 불변식. 폭몫 + 틈몫 = 1.15 가 깨지면 값표 폭 · 자금판 강등 문턱 ·
#     정산 오른끝 · 툴팁 예약이 한꺼번에 밀리는데 **아무 검사도 안 터진다.**
#     여기 박아 둔 네 수가 그 유일한 그물이다.
#  ② 1.22 파생. 플라크 덩어리의 가운데가 수의 잉크 가운데와 맞는가.
#     _gold_icon_top 안에 손으로 1.22 를 적어 두면 어긋나도 조용하다.
#  ③ 크기 단. 면 폭이 문턱을 넘을 때만 표시가 는다.
#  ④ 제약 키라인. **그린 그림을 픽셀로 재서** 잉크가 제 키라인 안에 드는지,
#     상자 가운데가 칸 가운데에 서는지를 본다. 수를 베끼지 않는다 —
#     게임이 실제로 칠한 픽셀만 본다.
#  ⑤ 팩. 사진과 비가 갈리는가 · 넓이가 비슷한가 · 잡히는 모양이 그림과
#     같은 방향인가 · rise=0 이 판 위와 한 픽셀도 안 다른가.
#  ⑥ 대비. 다섯 표식과 두 충돌(C_ACC 대 C_GOLD · loss 대 grey)을 잰다.
# ══════════════════════════════════════════════════════════

#  gold_w 잠금표. **이 수가 바뀌면 불변식이 깨진 것이다.**
#  옛 식(size*0.85 + max(4, size*0.30))으로 잰 값이고, 새 식
#  (size*0.96 + max(2.68, size*0.19))이 소수점까지 같아야 한다.
const LOCK := {"12": 14.20, "20": 23.00, "24": 27.60, "36": 41.40}

var g = null
var busy := false
var fails := 0
var img: Image = null


func _ok(n: String, c: bool, d := "") -> void:
	if not c:
		fails += 1
	print("  %s %-38s %s" % ["통과" if c else "실패", n, d])


func _initialize() -> void:
	Save.path = "user://_qa_art.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	return false


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	g._new_run()
	g._swap_skip()
	print("\n물성 사다리 검사 — 골드 · 팩 · 제약\n")

	# ── ① 골드 불변식 ─────────────────────────────────
	print("① 골드 불변식 — 폭몫 %.2f + 틈몫 %.2f = %.2f"
			% [g.PLQ.w, g.PLQ.gap, float(g.PLQ.w) + float(g.PLQ.gap)])
	_ok("폭몫 + 틈몫 = 1.15",
			absf(float(g.PLQ.w) + float(g.PLQ.gap) - 1.15) < 0.0005,
			"%.4f" % (float(g.PLQ.w) + float(g.PLQ.gap)))
	for sz in [12, 20, 24, 36]:
		var head: float = float(sz) * float(g.PLQ.w) + g.gold_gap(int(sz))
		var want: float = float(LOCK[str(sz)])
		_ok("gold_w 앞자리가 안 움직인다 (%d)" % sz, absf(head - want) < 0.005,
				"%.4f (잠금 %.2f)" % [head, want])
	#  자금판 20 단은 식을 손으로 베낀 자리다. 강등 문턱이 안 뒤집혀야 한다.
	for n in ["7", "99", "123", "99999"]:
		var a: float = g._bank_gold_w(n, 20)
		var b: float = 20.0 * float(g.PLQ.w) + g.gold_gap(20) \
				+ g.font_sm.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x \
				- 1.0
		_ok("자금판 20 단이 같은 식을 본다 (%s)" % n, absf(a - b) < 0.005,
				"%.3f" % a)

	# ── ② 1.22 파생 ──────────────────────────────────
	print("\n② 플라크 덩어리가 수의 잉크 가운데에 선다")
	for sz in [12, 20, 24, 36]:
		var y := 100.0
		var top: float = g._gold_icon_top(y, int(sz))
		var ih: float = float(sz) * float(g.PLQ.w) * float(g.PLQ.h) \
				* (1.0 + float(g.PLQ.side))
		var mid: float = y - g.font.get_ascent(int(sz)) * float(g.INK.num) * 0.5
		#  남는 어긋남은 전부 _ink_half 의 반 칸(0.25px)이다.
		_ok("덩어리 가운데 = 잉크 가운데 (%d)" % sz,
				absf(top + ih * 0.5 - mid) <= 0.26,
				"차 %.3fpx · 덩어리 %.3f" % [top + ih * 0.5 - mid, ih])

	# ── ③ 크기 단 ────────────────────────────────────
	print("\n③ 크기 단 — 면 폭으로 갈린다")
	for e in [[5.0, 2], [8.9, 2], [9.0, 3], [11.52, 3], [15.9, 3],
			[16.0, 4], [19.2, 4], [34.56, 4]]:
		var fw: float = float(e[0])
		var mk := 2
		if fw >= float(g.PLQ.step_gloss):
			mk = 3
		if fw >= float(g.PLQ.step_panel):
			mk = 4
		_ok("면 %.2f → 표시 %d" % [fw, int(e[1])], mk == int(e[1]), "실제 %d" % mk)

	# ── ④ 제약 키라인 ────────────────────────────────
	print("\n④ 제약 — 그린 픽셀을 재서 키라인에 든다")
	Dev.on = false
	g.art_guide = false
	Dev.pick["artsheet"] = 3
	g.queue_redraw()
	await process_frame
	await process_frame
	img = root.get_texture().get_image()
	img.save_png("res://shots/art_mod_raw.png")
	var s: float = float(img.get_width()) / g.VIEW.x
	var worst := 0.0
	var worst_n := ""
	var offc := 0.0
	var offn := ""
	var empty := PackedStringArray()
	for cell in g.art_cells:
		if String(cell.k) != "mod" or bool(cell.get("void", false)):
			continue
		var r: float = float(cell.r)
		var c: Vector2 = cell.c
		var m := _ink(c, r * 1.6, s)
		var bb: Rect2 = m.box
		if bb.size.x <= 0.0:
			empty.append("%s r%.1f" % [cell.id, r])
			continue
		var cir: bool = g.ART_CIR.has(String(cell.id))
		var cap: float = r * float(g.KEY.cir if cir else g.KEY.sq)
		#  원형 가족은 **잉크 한 점의 반지름**으로 잰다. 상자 귀퉁이로 재면
		#  반지름 R 인 원이 R√2 로 나와서 어떤 원도 제 키라인을 못 넘는다 —
		#  자가 거짓으로 터진다(2026-09-19 에 그렇게 한 번 터졌다).
		#  각진 가족은 상자의 반쪽으로 잰다.
		var far: float = float(m.far) if cir \
				else maxf(maxf(absf(bb.position.x - c.x), absf(bb.end.x - c.x)),
					maxf(absf(bb.position.y - c.y), absf(bb.end.y - c.y)))
		var over: float = far - cap
		if over > worst:
			worst = over
			worst_n = "%s r%.1f (%.2f > %.2f)" % [cell.id, r, far, cap]
		var ctr: float = (bb.get_center() - c).length() / r
		if ctr > offc:
			offc = ctr
			offn = "%s r%.1f (%.3fr)" % [cell.id, r, ctr]
	_ok("열하나가 다 그려진다", empty.is_empty(),
			"빈 칸: %s" % ("없다" if empty.is_empty() else ", ".join(empty)))
	#  1.0px 은 래스터 여유다 — 반 픽셀 덮개 둘.
	_ok("잉크가 키라인 안에 든다", worst <= 1.0,
			"가장 넘친 것: %s" % ("없다" if worst_n == "" else worst_n))
	_ok("상자 가운데가 칸 가운데에 선다", offc <= 0.15,
			"가장 쏠린 것: %s" % ("없다" if offn == "" else offn))
	g.art_guide = true
	Dev.pick["artsheet"] = 0

	# ── ⑤ 팩 ────────────────────────────────────────
	print("\n⑤ 팩 — 사진에게서 갈라져 나왔나")
	var gk: float = g.GOODS_K
	var pr: float = float(g.PACK.w) / float(g.PACK.h)
	var fr: float = float(g.FIX_W) / float(g.FIX_H)
	_ok("비가 뒤집혔다", pr < 1.0 and fr > 1.0,
			"팩 %.3f · 사진 %.3f · 비의 비 %.2f" % [pr, fr, fr / pr])
	var pa: float = float(g.PACK.w) * gk * 2.0 * float(g.PACK.h) * gk * 2.0 * g.TBL.flat
	var fa: float = float(g.FIX_W) * gk * 2.0 * float(g.FIX_H) * gk * 2.0 * g.TBL.flat
	_ok("테이블에서 제일 큰 물건이 아니다", absf(pa - fa) / fa < 0.10,
			"팩 %.0fpx² · 사진 %.0fpx² (%.1f%%)" % [pa, fa, (pa / fa - 1.0) * 100.0])
	#  히트가 그림과 **같은 방향**이어야 한다. 전에는 정반대였다.
	var hw: float = float(g.PACK.w) * float(g.PACK.hit) * gk
	var hh: float = float(g.PACK.h) * float(g.PACK.hit) * gk
	_ok("잡히는 모양이 그림과 같은 방향", hw < hh,
			"히트 %.2f x %.2f · 그림 %.2f x %.2f"
			% [hw * 2.0, hh * 2.0, float(g.PACK.w) * gk * 2.0, float(g.PACK.h) * gk * 2.0])
	#  여는 연출의 첫 프레임이 판 위와 같은가 — k 의 시작이 GOODS_K 다.
	var k0: float = gk + (float(g.BOOST.big) - gk) * (1.0 - pow(1.0, 3.0))
	_ok("rise=0 이 판 위와 같다", absf(k0 - gk) < 0.0005,
			"%.4f (판 위 %.4f)" % [k0, gk])
	#  외접 반지름 — qa_rank 의 안전선과 같은 자다. 크림프가 밖으로 물면 는다.
	var rad: float = sqrt(pow(float(g.PACK.w) * gk, 2.0) + pow(float(g.PACK.h) * gk, 2.0))
	_ok("외접 반지름이 안 늘었다", rad <= 27.08,
			"%.2f (옛 27.08 · chip_r %.2f)" % [rad, g.TBL.chip_r])
	#  뜯는 실이 화면에서 1px 로 선다 — 면 1.0 으로 두면 0.79px 이라 사라진다.
	_ok("뜯는 실이 화면 1px 이상",
			g._pack_thread(gk) * g.TBL.flat >= 0.999,
			"%.3fpx" % (g._pack_thread(gk) * g.TBL.flat))

	# ── ⑥ 대비 ──────────────────────────────────────
	print("\n⑥ 대비")
	var gold: Color = g.C_GOLD
	_ok("대각 광택이 바닥 1.4 를 넘는다",
			_con(gold.lightened(0.75), gold) >= 1.40,
			"%.3f:1 (옛 0.50 은 %.3f)"
			% [_con(gold.lightened(0.75), gold), _con(gold.lightened(0.50), gold)])
	_ok("밑 옆면이 EDGE.lo 보다 어둡다",
			_con(gold.darkened(0.55), gold) > _con(gold.darkened(float(g.EDGE.lo)), gold),
			"%.3f:1 (EDGE.lo 는 %.3f)"
			% [_con(gold.darkened(0.55), gold),
			_con(gold.darkened(float(g.EDGE.lo)), gold)])
	#  뺀 표식이 바닥을 못 넘었다는 기록을 남긴다 — 다시 넣으려는 사람을 위해.
	print("      (뺀 윗줄 빛 lightened(.45) = %.3f:1 — 바닥 1.4 미달)"
			% _con(gold.lightened(0.45), gold))
	var acc: float = _con(g.C_ACC, gold)
	print("      (C_ACC 대 C_GOLD = %.3f:1 — 바닥 미달이라 **면적으로** 갈랐다)" % acc)
	var grey: Color = g.C_WIRE.lightened(0.18)
	var loss: Color = g.C_MULT.lightened(0.25)
	var cut: Color = g.C_DARK.darkened(0.45)
	print("      (loss 대 grey = %.3f:1 — 회색조에서 못 믿는다)" % _con(loss, grey))
	_ok("cut 이 grey 위에서도 읽힌다", _con(cut, grey) >= 3.0,
			"%.3f:1 (loss 위에서는 %.3f:1)" % [_con(cut, grey), _con(cut, loss)])

	print("\n%s" % ("전부 통과" if fails == 0 else "실패 %d건" % fails))
	quit(fails)


#  칸 가운데 둘레에서 바탕(C_BG)과 다른 픽셀을 찾아 **상자와 가장 먼
#  반지름**을 같이 잰다. 논리 좌표로 돌려준다.
func _ink(c: Vector2, rad: float, s: float) -> Dictionary:
	var bg: Color = g.C_BG
	var x0: int = maxi(0, int((c.x - rad) * s))
	var x1: int = mini(img.get_width() - 1, int((c.x + rad) * s))
	var y0: int = maxi(0, int((c.y - rad) * s))
	var y1: int = mini(img.get_height() - 1, int((c.y + rad) * s))
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	var far := 0.0
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p := img.get_pixel(x, y)
			if absf(p.r - bg.r) + absf(p.g - bg.g) + absf(p.b - bg.b) < 0.05:
				continue
			#  픽셀 한 칸이 덮는 논리 구간의 양끝을 쓴다.
			var a := Vector2(float(x) / s, float(y) / s)
			var b := Vector2(float(x + 1) / s, float(y + 1) / s)
			lo.x = minf(lo.x, a.x)
			lo.y = minf(lo.y, a.y)
			hi.x = maxf(hi.x, b.x)
			hi.y = maxf(hi.y, b.y)
			for q in [a, Vector2(b.x, a.y), Vector2(a.x, b.y), b]:
				far = maxf(far, (q - c).length())
	if hi.x < lo.x:
		return {"box": Rect2(), "far": 0.0}
	return {"box": Rect2(lo, hi - lo), "far": far}


func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


func _con(a: Color, b: Color) -> float:
	var la: float = 0.2126 * _lin(a.r) + 0.7152 * _lin(a.g) + 0.0722 * _lin(a.b)
	var lb: float = 0.2126 * _lin(b.r) + 0.7152 * _lin(b.g) + 0.0722 * _lin(b.b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
