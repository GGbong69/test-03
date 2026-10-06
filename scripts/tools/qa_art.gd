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
#  **창을 달고 돌려라.** ④ 는 그린 픽셀을 재는 자라 --headless 에서는
#  텍스처가 없다. 헤드리스로 돌리면 ④ 만 건너뛰고 나머지는 다 돌며
#  끝맺음도 한다 — 그러나 그때의 초록은 「제약 그림은 아직 안 쟀다」다.
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
#  ⑤ 팩(겉 셋 — 포일 봉투 · 봉인 편지봉투 · 놋쇠 깡통, 2026-10-06). 사진과 비가 갈리는가 ·
#     넓이가 비슷한가 · 잡히는 모양이 그림과 같은 방향인가 · rise=0 이 판 위와 같은가 ·
#     겉마다 — 뜯는 실 1px(포일) · 너덜한 결 1px · 그림이 면 크기(편지봉투) · 작은/큰 팩
#     갈림 · 뚜껑 그림 1:1 · 잡히는 칸이 깡통 둘레를 덮는가(깡통). 창이 있으면 셋 다
#     **그린 잉크가 잡히는 칸 안에 드는가**와 찢긴 변의 톱니(봉투) · 일어서는 뚜껑(깡통).
#  ⑥ 대비. 다섯 표식과 두 충돌(C_ACC 대 C_GOLD · loss 대 grey)을 잰다.
# ══════════════════════════════════════════════════════════

#  gold_w 잠금표. **이 수가 바뀌면 불변식이 깨진 것이다.**
#  옛 식(size*0.85 + max(4, size*0.30))으로 잰 값이고, 새 식
#  (size*0.96 + max(2.68, size*0.19))이 소수점까지 같아야 한다.
const LOCK := {"12": 14.20, "20": 23.00, "24": 27.60, "36": 41.40}

var g = null
var busy := false
var fails := 0
var skipped := false
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
	#  **헤드리스에서는 못 잰다.** root.get_texture() 가 null 을 주고,
	#  가드 없이 save_png 를 부르면 그 자리에서 _run 이 끊겨 **quit 에
	#  영영 못 간다** — 프로세스가 바깥 timeout 까지 살아 있고 종료 코드가
	#  124 로 나온다. 「종료 코드 = 실패 개수」 약속이 거기서 깨지고
	#  ⑤⑥ 열셋이 조용히 안 돈다(2026-09-20 에 실제로 그랬다).
	#  저장소 선례(shot_bills · shot_bank)와 같은 자로 가른다.
	var eyes: bool = DisplayServer.get_name() != "headless"
	Dev.on = false
	g.art_guide = false
	Dev.pick["artsheet"] = 3
	g.queue_redraw()
	await process_frame
	await process_frame
	if eyes:
		var tex := root.get_texture()
		img = tex.get_image() if tex != null else null
	if img == null:
		skipped = true
		print("  ⚠ 건너뜀 — **창이 있어야 돈다.** 이 셋은 그린 픽셀을 재는")
		print("    자라 --headless 로는 아무것도 못 본다. 제약 그림을")
		print("    고쳤으면 --quit-after 900 으로 한 번 더 돌려라.")
	else:
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
	print("\n⑤ 팩 — 사진에게서 갈라져 나왔나 · 겉 셋이 한 물건인가")
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
	#  여는 연출의 첫 프레임이 판 위와 같은가 — k 의 시작이 GOODS_K(·몸 배율)다.
	var k0: float = g._boost_k(0.0)
	var k0b: float = g._boost_k(0.0, g._pack_s({"size": 4, "look": "foil"}))
	_ok("rise=0 이 판 위와 같다", absf(k0 - gk) < 0.0005
			and absf(k0b - gk * float(g.PACK.big)) < 0.0005,
			"%.4f · 포일 큰 팩 %.4f (판 위 %.4f · %.4f)" % [k0, k0b, gk, gk * float(g.PACK.big)])
	#  외접 반지름 — qa_rank 의 안전선과 같은 자다. 크림프 · 결이 밖으로 물면 는다.
	var rad: float = sqrt(pow(float(g.PACK.w) * gk, 2.0) + pow(float(g.PACK.h) * gk, 2.0))
	_ok("외접 반지름이 안 늘었다", rad <= 27.08,
			"%.2f (옛 27.08 · chip_r %.2f)" % [rad, g.TBL.chip_r])
	#  포일 큰 팩(×1.10)의 귀퉁이 끝도 넓은 판정 칸(_obj_box + 2)에 든다.
	var bigr: float = rad * float(g.PACK.big)
	var boxr: float = (maxf(float(g.PACK.w), float(g.PACK.h)) * gk + 3.0) * float(g.PACK.big) + 2.0
	_ok("포일 큰 팩 귀퉁이가 판정 칸 안", bigr <= boxr, "%.2f ≤ %.2f" % [bigr, boxr])

	print("  ── 포일 봉투")
	#  뜯는 실이 화면에서 1px 로 선다 — 면 1.0 으로 두면 0.79px 이라 사라진다.
	_ok("뜯는 실이 화면 1px 이상",
			g._pack_thread(gk) * g.TBL.flat >= 0.999,
			"%.3fpx" % (g._pack_thread(gk) * g.TBL.flat))
	for sz in [2, 4]:
		var ft: Texture2D = g._foil_tex({"size": sz})
		_ok("포일 %s 그림이 있다" % ("작은" if sz == 2 else "큰"), ft != null,
				"없다" if ft == null else "%d x %d" % [ft.get_width(), ft.get_height()])

	print("  ── 봉인 편지봉투")
	#  너덜한 결이 화면에서 1px 로 선다 — 사진과 실루엣을 가르는 것이 이 결이다.
	#  눌리는 세로(flat)에서 재야 한다. 1px 밑이면 640x360 에서 곧은 변이 된다.
	var dk: float = float(g.ENV.deckle) * gk * g.TBL.flat
	_ok("너덜한 결이 화면 1px 이상", dk >= 0.999, "%.3fpx" % dk)
	#  봉투 그림은 테이블에서 **도트 하나가 화면 한 칸**이다(동전 · 사진과 같은 결).
	#  면 크기와 1px 넘게 어긋나면 늘어나거나 줄어든 도트가 섞인다.
	for pid in ["env_small", "env_big"]:
		var tx: Texture2D = g._env_tex(pid)
		var tw: float = float(g.PACK.w) * gk * 2.0
		var th: float = float(g.PACK.h) * gk * 2.0
		_ok("%s 그림이 면 크기로 구워졌다" % pid,
				tx != null and absf(tx.get_width() - tw) < 1.0
						and absf(tx.get_height() - th) < 1.0,
				"그림 %s · 면 %.2f x %.2f" % ["없다" if tx == null
						else "%d x %d" % [tx.get_width(), tx.get_height()], tw, th])

	print("  ── 놋쇠 깡통")
	#  작은 팩 · 큰 팩이 **한눈에** 갈리는가 — 크기 · 벽 높이 · 경첩 · 색. 넷 중 하나만
	#  남으면 30px 물건 위에서 눈금 두 점의 차이로 되돌아간다.
	var ts: Dictionary = g.TIN.s
	var tb: Dictionary = g.TIN.b
	_ok("작은 팩이 한 뼘 작다", float(ts.k) < float(tb.k) and float(tb.k) == 1.0,
			"%.2f 대 %.2f" % [float(ts.k), float(tb.k)])
	_ok("작은 팩 벽이 낮다", float(ts.z) < float(tb.z),
			"화면 %.2f 대 %.2fpx" % [float(ts.z) * gk * g.TBL.tall, float(tb.z) * gk * g.TBL.tall])
	_ok("경첩은 큰 팩만", not bool(ts.hinge) and bool(tb.hinge))
	_ok("에나멜 색상이 갈린다", absf(Color(ts.e1).h - Color(tb.e1).h) > 0.15,
			"색상 차 %.2f" % absf(Color(ts.e1).h - Color(tb.e1).h))
	#  뚜껑 그림 도트 하나 = 테이블 화면 한 칸 — 놋쇠 실선(1도트)이 판 위에서 안 죽는다.
	#  표의 th · tw(헤드리스에서 띠 · 메달 자리를 재는 수)가 그림과 같은지도 본다.
	for key in ["s", "b"]:
		var tn: Dictionary = g.TIN[key]
		var im := Image.load_from_file("res://assets/tin/%s.png" % String(tn.tex))
		var want := Vector2(float(g.PACK.w), float(g.PACK.h)) * float(tn.k) * gk * 2.0
		var ok: bool = im != null and not im.is_empty() \
				and absf(float(im.get_width()) - want.x) <= 1.0 \
				and absf(float(im.get_height()) - want.y) <= 1.0 \
				and im.get_width() == int(tn.tw) and im.get_height() == int(tn.th)
		_ok("뚜껑 그림이 면에 1:1 (%s)" % key, ok,
				"그림 %s · 면 %.1f x %.1f" % ["없음" if im == null or im.is_empty()
				else "%d x %d" % [im.get_width(), im.get_height()], want.x, want.y])
	#  **잡히는 칸이 깡통 둘레를 덮는가** — 히트(_obj_shape)는 큰 팩 네모 × hit 그대로다.
	#  깡통이 그리는 둘레(바닥 · 닿는 그림자 · 뚜껑 윗면 · 경첩)를 psi 한 바퀴(5° 마다)
	#  돌려, 점마다 「네모 안 · 또는 들림 덮개(lz)만큼 올린 네모 안」인지 잰다 —
	#  _shop_hit 의 두 점 OR 과 같은 자다. 테 빛 한 줄(1px)이 밖으로 반 칸 나가므로
	#  네모를 0.5px 씩 넓혀 본다. 넓은 판정 칸(_obj_box + 덮개)도 같이 본다.
	var lz: float = (float(g.DROP.lift_hov) + float(g.DROP.knock_h)) * float(g.TBL.tall)
	var nout := 0
	var npt := 0
	var worst_n := ""
	for key in ["s", "b"]:
		var tn: Dictionary = g.TIN[key]
		var bd := {"size": 4 if key == "b" else 2, "pick": 1}
		var e: Vector2 = g._tin_ext(bd, gk)
		var zt: float = float(tn.z) * gk
		var sk: float = float(tn.skirt) * gk
		var loc: PackedVector2Array = g._tin_loc(e.x, e.y, float(tn.r) * gk)
		for d in 72:
			var psi: float = TAU * float(d) / 72.0
			var co := cos(psi)
			var si := sin(psi)
			var c := Vector2(320.0, 180.0)
			var pts := PackedVector2Array()
			for q in loc:
				pts.append(g._tin_p3(c, co, si, q.x, q.y, 0.0) + Vector2(0.0, 1.2))
				pts.append(g._tin_p3(c, co, si, q.x, q.y, zt))
			if bool(tn.hinge):
				for sx in [-1.0, 1.0]:
					for xx in [-0.15, 0.15]:
						var hx: float = (float(sx) * 0.46 + float(xx)) * e.x
						for hz in [zt - sk - 0.5 * gk, zt - 0.4 * gk]:
							pts.append(g._tin_p3(c, co, si, hx, -e.y - 1.3 * gk, float(hz)))
			var poly: PackedVector2Array = g._quad_at(c, psi, hw + 0.5, hh + 0.5)
			var br: float = maxf(float(g.PACK.w), float(g.PACK.h)) * gk + 3.0
			var eb := Vector2(br, br * g.TBL.flat + 3.0)
			var box := Rect2(c - eb, eb * 2.0).grow_individual(2.0, 2.0 + lz, 2.0, 2.0)
			for p in pts:
				npt += 1
				if box.has_point(p) and (g._in_poly(p, poly)
						or g._in_poly(p + Vector2(0.0, lz), poly)):
					continue
				nout += 1
				if worst_n == "":
					worst_n = "%s psi %d° (%.1f, %.1f)" % [key, d * 5, p.x - c.x, p.y - c.y]
	_ok("잡히는 칸이 깡통을 덮는다 (psi 한 바퀴)", nout == 0,
			"둘레 점 %d · 밖 %d%s" % [npt, nout, "" if worst_n == "" else " — 첫 자리 " + worst_n])

	#  ⑤-2 **그린 픽셀로 본다** — 겉 하나씩 그림 표본 ②를 그려 잰다.
	#  필터(CRT · 굴곡 · VHS · 도트)를 잠깐 끈다 — 굴곡이 가장자리를 몇 px 씩 옮기고
	#  낟알이 바탕을 흔들어 잉크 경계가 자가 아니라 필터가 된다.
	if img != null:
		var keep := [g.crt, g.warp, g.vhs, g.dot]
		g.crt = 0.0
		g.warp = 0.0
		g.vhs = 0.0
		g.dot = 0.0
		g._crt_apply()
		g.art_guide = false
		var bg: Color = g.C_BG
		for lk in ["foil", "env", "tin"]:
			g.pack_look_force = lk
			Dev.pick["artsheet"] = 2
			g.queue_redraw()
			for i in 4:
				await process_frame
			img = root.get_texture().get_image()
			img.save_png("res://shots/art_pack_%s_raw.png" % lk)
			var sp: float = float(img.get_width()) / g.VIEW.x
			var nm: String = {"foil": "포일", "env": "편지봉투", "tin": "깡통"}[lk]
			#  그린 잉크가 잡히는 칸 안에 든다 — 히트 네모(포일 큰 팩은 ×1.10) 또는 들림
			#  덮개만큼 올린 네모. 위 수의 자가 정말 그려지는 그것을 재는지를 본다.
			var outs := 0
			var inks := 0
			var wn := ""
			for cell in g.art_cells:
				if String(cell.k) != "pack":
					continue
				var c: Vector2 = cell.c
				var psi: float = float(cell.r)
				var hs: float = g._pack_s({"size": int(cell.n), "look": lk})
				var poly: PackedVector2Array = g._quad_at(c, psi, hw * hs + 1.0, hh * hs + 1.0)
				for py in range(int((c.y - 34.0) * sp), int((c.y + 30.0) * sp)):
					for px in range(int((c.x - 31.0) * sp), int((c.x + 31.0) * sp)):
						var col := img.get_pixel(px, py)
						if absf(col.r - bg.r) + absf(col.g - bg.g) + absf(col.b - bg.b) < 0.05:
							continue
						inks += 1
						var m := Vector2((float(px) + 0.5) / sp, (float(py) + 0.5) / sp)
						if not (g._in_poly(m, poly) or g._in_poly(m + Vector2(0.0, lz), poly)):
							outs += 1
							if wn == "":
								wn = "%d칸 psi %.0f° (%.1f, %.1f)" % [int(cell.n),
										rad_to_deg(psi), m.x - c.x, m.y - c.y]
			_ok("%s — 그린 잉크가 잡히는 칸 안에 든다" % nm, outs == 0 and inks > 2000,
					"잉크 %d 화소 · 밖 %d%s" % [inks, outs, "" if wn == "" else " — 첫 자리 " + wn])
			#  여는 칸(rise 1 · tear 0.5 — 그림 표본 ② 의 마지막 칸, 가운데 (480, 250)).
			var gp: float = float(g.BOOST.gap) * (1.0 - pow(0.5, 2.4))
			match lk:
				"foil":
					#  **찢긴 자리가 톱니인가.** 수로는 못 잡는다 — 봉인띠가 곧은 턱으로 톱니를
					#  통째로 덮고 있었는데(파인 이가 나오려면 tear > 0.659) 수의 단언은 전부
					#  초록이었다. 두 쪽은 기울어 있으므로 **곧은 자를 맞춰 본다** — 기울기는
					#  직선이 다 먹고 톱니만 잔차로 남는다. 아래 쪽의 **찢긴 변**이다.
					var kb: float = g._boost_k(1.0, g._pack_s({"size": 4, "look": "foil"}))
					var sm: float = float(g.PACK.seam) * kb
					var lo: float = (float(g.PACK.h) * kb - sm) * 0.5
					var bt: float = minf(1.7 * kb * 0.5, sm) * g.TBL.flat
					var cy: float = 250.0 + (sm + lo) * g.TBL.flat + gp * g.TBL.flat
					var dev: float = _edge_dev(480.0 + gp * 0.16, float(g.PACK.w) * kb * 0.78,
							cy - (lo + sm) * g.TBL.flat, 20.0, sp)
					_ok("포일 — 찢긴 변이 톱니다", dev >= bt * 0.5,
							"잔차 %.2fpx (이 진폭 ±%.2fpx)" % [dev, bt])
				"env":
					#  아래 쪽의 찢긴 변은 팩 가운데(봉인 자리)에서 벌어진 만큼 내려와 있다.
					var kv: float = g._boost_k(1.0)
					var bv: float = minf(1.7 * kv * 0.5, 1.6 * kv) * g.TBL.flat
					var dv: float = _edge_dev(480.0 + gp * 0.16, float(g.PACK.w) * kv * 0.78,
							250.0 + gp * g.TBL.flat, 20.0, sp)
					_ok("편지봉투 — 찢긴 변이 톱니다", dv >= bv * 0.5,
							"잔차 %.2fpx (이 진폭 ±%.2fpx)" % [dv, bv])
				"tin":
					#  뚜껑이 일어선다 — 잉크 맨 위가 닫힌 깡통 윗면보다 한참 위다. 여닫이가
					#  말없이 0 으로 돌아가면(자세가 안 먹으면) 여기가 먼저 터진다.
					var oc := Vector2(480.0, 250.0)
					var kt: float = g._boost_k(1.0)
					var shut_top: float = oc.y - g._tin_ext({"size": 4}, kt).y * g.TBL.flat \
							- float(tb.z) * kt * g.TBL.tall
					var top := 1e9
					for py in range(int(80.0 * sp), int(shut_top * sp)):
						for px in range(int((oc.x - 30.0) * sp), int((oc.x + 30.0) * sp)):
							var col2 := img.get_pixel(px, py)
							if absf(col2.r - bg.r) + absf(col2.g - bg.g) + absf(col2.b - bg.b) >= 0.05:
								top = minf(top, float(py) / sp)
					_ok("깡통 — 뚜껑이 일어선다", top < shut_top - 40.0,
							"잉크 맨 위 %.1f · 닫힌 윗면 %.1f" % [top, shut_top])
		g.pack_look_force = ""
		g.crt = keep[0]
		g.warp = keep[1]
		g.vhs = keep[2]
		g.dot = keep[3]
		g._crt_apply()
		g.art_guide = true
		Dev.pick["artsheet"] = 0

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

	#  **건너뛴 것을 통과로 읽으면 안 된다.** ④ 는 이 셋에 걸린 **유일한
	#  기하 그물**이라, 창 없이 돌린 초록은 「제약 그림은 아직 안 쟀다」는
	#  뜻이다. 종료 코드는 그대로 실패 개수다(건너뜀은 실패가 아니다).
	print("\n%s%s" % ["전부 통과" if fails == 0 else "실패 %d건" % fails,
			"  ⚠ ④ 는 안 쟀다 — 창을 달고 한 번 더 돌려라" if skipped else ""])
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


#  가로 [cx−hw, cx+hw] 의 칸마다 **맨 위 잉크**를 찾아 곧은 자를 맞추고,
#  가장 큰 잔차를 논리 px 로 돌려준다. 기울어도 직선이 다 먹으므로 남는
#  것은 톱니뿐이다. 곧은 변이면 0.5px 안(래스터 반 칸)에 든다.
func _edge_dev(cx: float, hw: float, ey: float, win: float, s: float) -> float:
	var bg: Color = g.C_BG
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	for px in range(int((cx - hw) * s), int((cx + hw) * s) + 1):
		if px < 0 or px >= img.get_width():
			continue
		for py in range(maxi(0, int((ey - win) * s)),
				mini(img.get_height() - 1, int((ey + win) * s)) + 1):
			var p := img.get_pixel(px, py)
			if absf(p.r - bg.r) + absf(p.g - bg.g) + absf(p.b - bg.b) < 0.05:
				continue
			xs.append(float(px) / s)
			ys.append(float(py) / s)
			break
	var n: int = xs.size()
	if n < 8:
		return -1.0
	var sx := 0.0
	var sy := 0.0
	for i in n:
		sx += xs[i]
		sy += ys[i]
	sx /= float(n)
	sy /= float(n)
	var num := 0.0
	var den := 0.0
	for i in n:
		num += (xs[i] - sx) * (ys[i] - sy)
		den += (xs[i] - sx) * (xs[i] - sx)
	var a: float = num / den if den > 0.0001 else 0.0
	var worst := 0.0
	for i in n:
		worst = maxf(worst, absf(ys[i] - (sy + a * (xs[i] - sx))))
	return worst


func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


func _con(a: Color, b: Color) -> float:
	var la: float = 0.2126 * _lin(a.r) + 0.7152 * _lin(a.g) + 0.0722 * _lin(a.b)
	var lb: float = 0.2126 * _lin(b.r) + 0.7152 * _lin(b.g) + 0.0722 * _lin(b.b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
