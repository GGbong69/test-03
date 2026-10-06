extends SceneTree
# ══════════════════════════════════════════════════════════
#  잇는 선 — **값이 어디서 왔는지 말하는가 · 안 물리는가** (2026-09-26)
#
#  실행:  godot --headless --path . --script scripts/tools/qa_link.gd
#  종료 코드 = 실패 개수
#
#  왜 있는가
#    한 런에 정산 걸음이 약 700번 난다. 그 자리에 층을 얹을 때 무서운 것은
#    「안 예쁘다」가 아니라 **「물린다」와 「거짓말한다」** 둘이다.
#      · 물린다  — 화면에 쌓이거나, 걸음을 넘겨 다음 걸음의 선과 겹치거나,
#                  한 프레임에 여럿이 서거나.
#      · 거짓말  — 출처가 없는 걸음(빗나감 · 저울 · 물음표)에 선이 서거나,
#                  0 만큼 바뀐 걸음이 「올랐다」고 하거나, 동전이 낸 값인데
#                  판을 가리키거나.
#    그래서 이 자는 그림을 안 본다 — **_link_plan 이 낸 답**을 센다.
#    그리는 쪽(_draw_link)이 그 답을 그대로 긋기 때문에 호출 수와 문턱이
#    화면 없이 증명된다.
# ══════════════════════════════════════════════════════════
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")

var g = null
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_link_g.cfg"
	Save.path = "user://_qa_link.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	_run()
	print("\n통과 %d · 실패 %d" % [ok, bad])
	quit(bad)


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-48s %s" % ["통과" if cond else "실패", nm, note])


#  점이 사각의 **테두리 위**인가. 안(0.6px 줄인 사각)에 들면 거짓이고, 밖
#  (0.6px 키운 사각)에 있어도 거짓이다. 2026-09-26
func _on_edge(p: Vector2, r: Rect2) -> bool:
	return r.grow(0.6).has_point(p) and not r.grow(-0.6).has_point(p)


func _calm() -> void:
	g.swap_live = false
	g.photo = ""
	g.photo_rack = ""
	g._tutor_close()
	g.tutor_id = ""
	g.tutor_q.clear()
	g.tutor_out = 0.0
	g.pause_from = -1
	g.hand_st = g.H.NONE
	g._autoplay = false
	Dev.on = false
	g.fast_lock = false
	g.fast_mul = 2.5
	g.motion_off = false
	g.grow_roll = 1.0
	g.grow_shake = 1.0
	g.link_mode = 3


#  큐를 손으로 세운다. 오토플레이 150발에 miss·pierce·bal·rnd·연발이 한 번도
#  안 나오더라는 보고가 있었다 — 그 갈래들은 손으로 세워야 돈다.
func _stage(q: Array, load_n := 1) -> void:
	g.set_process(false)
	g._start_leg()
	g._card_reset()
	g.target = 1000
	g.total = 0
	g.shown = 0.0
	g.cur_chip = 0
	g.cur_mult = 1
	g.score_mul = 1.0
	g.score_mode = "std"
	g.card_mode = 0
	g.calc_lit = false
	g.roll_t = -1.0
	g.pitch_step = 0
	g.queue.clear()
	for e in q:
		g.queue.append(e)
	g.settle_n = load_n
	g.burst_n = 0
	g.burst_hits.clear()
	g.card_side = 1
	g.card_y = 74.0
	g.card_p = 1.0
	g.card_target = 1.0
	g.hitstop = 0.0
	g.state = g.S.RESOLVE
	g.qt = g.beat * g._pace()
	g.gold = 50
	#  판에 꽂힌 자리를 세운다 — 판 갈래의 출발점이 여기서 난다.
	g.hit_idx = 3
	g.hit_bull = false
	g.hit_r0 = g.R * 0.20
	g.hit_r1 = g.R * 0.60
	_calm()


#  정산을 끝까지 돌리며 프레임마다 _link_plan 을 센다.
func _walk(fast := false) -> Dictionary:
	var frames := 0
	var lines := 0            # 선이 선 프레임 수
	var calls := 0            # draw_line 호출 총수(겉선 포함)
	var most := 0             # 한 프레임 최대 호출
	var tot_calls := 0        # 합계 걸음 프레임에 난 호출
	var leak := false         # 걸음이 바뀐 프레임에 앞 걸음 선이 남았나
	var kinds := {}
	g.fast_lock = fast
	while g.state == g.S.RESOLVE and frames < 6000:
		var ps0: int = g.pitch_step
		g._process(1.0 / 60.0)
		frames += 1
		var pl: Dictionary = g._link_plan()
		var c := 0
		if not pl.is_empty():
			c = 2 if bool(pl.case) else 1
			lines += 1
			kinds[bool(pl.ring)] = true
		calls += c
		most = maxi(most, c)
		if g.card_mode == 1:
			tot_calls += c
		if g.pitch_step > ps0 and c > 0 and g.src_t >= 1.0 - 0.0001:
			pass              # 새 걸음이 제 선을 세운 프레임이다 — 샌 것이 아니다
	g.fast_lock = false
	return {"frames": frames, "lines": lines, "calls": calls, "most": most,
			"tot": tot_calls, "leak": leak, "kinds": kinds.size()}


func _chip(n: int) -> Dictionary:
	return {"k": "chip", "v": n}


func _item(slot: int, kind: String, v: int) -> Dictionary:
	return {"k": "item", "i": slot, "kind": kind, "v": v, "lbl": "검사"}


func _run() -> void:
	g._new_run()
	_calm()

	# ── ⑫ 걸음이 끝나면 선이 하나도 안 남는다 ─────────────
	_stage([_chip(40), {"k": "mult", "v": 5}, {"k": "total"}])
	var w := _walk()
	_ok("⑫ 정산이 끝나면 선이 안 남는다",
			g.src_t <= 0.0 and g._link_plan().is_empty(),
			"src_t %.4f · slot %d" % [g.src_t, g.src_slot])

	# ── ⑬ 한 프레임에 선이 둘 이상 안 난다 ────────────────
	#  걸음은 한 번에 하나뿐이라 상한이 **호출 2개**(속선 + 겉선)다.
	_ok("⑬ 한 프레임 호출이 2를 안 넘는다", w.most <= 2, "최대 %d" % w.most)
	#  ⚠ **합계 걸음에는 0개다.** 이 게임에서 가장 붐비는 프레임이고 판 깨짐이
	#  서는 프레임이라, 거기에 아무것도 안 얹는 것이 설계의 약속이다.
	_ok("⑬-b 합계 걸음에는 선이 0개다", w.tot == 0, "%d 호출" % w.tot)
	_ok("⑬-c 점수 선과 배수 선이 둘 다 났다", int(w.kinds) == 2,
			"갈래 %d" % w.kinds)

	# ── ⑬-d 큐 열여섯 · 연발 · 무한 런에서도 상한이 같다 ────
	var many := []
	for i in 8:
		many.append(_chip(10 + i))
		many.append({"k": "mult", "v": 2 + i})
	many.append({"k": "total"})
	_stage(many, 40)
	var w16 := _walk()
	_ok("⑬-d 큐 열일곱에서도 상한이 2다", w16.most <= 2 and w16.tot == 0,
			"최대 %d · 합계 %d · 선 %d프레임" % [w16.most, w16.tot, w16.lines])

	# ── ⑭ 출처가 없는 걸음은 선을 안 낸다 ────────────────
	_stage([{"k": "miss"}])
	var wm := _walk()
	_ok("⑭ 빗나감에 선이 안 난다", wm.calls == 0, "%d 호출" % wm.calls)
	_stage([{"k": "bal"}])
	var wb := _walk()
	_ok("⑭-b 저울에 선이 안 난다", wb.calls == 0, "%d 호출" % wb.calls)
	_stage([{"k": "rnd"}])
	var wr := _walk()
	_ok("⑭-c 물음표에 선이 안 난다", wr.calls == 0, "%d 호출" % wr.calls)
	#  모음 걸음(2026-10-06)도 출처가 없다. 바로 앞 chip 걸음이 선을 세운 채
	#  넘어가므로, 모음 걸음(pitch_step 2) 프레임에서만 센다.
	_stage([_chip(40), {"k": "wind"}])
	var wd_calls := 0
	var wd_fr := 0
	var ch_calls := 0
	while g.state == g.S.RESOLVE and wd_fr < 900:
		g._process(1.0 / 60.0)
		wd_fr += 1
		var pw: Dictionary = g._link_plan()
		if pw.is_empty():
			continue
		if g.pitch_step == 1:
			ch_calls += 1
		elif g.pitch_step == 2:
			wd_calls += 1
	_ok("⑭-g 모음 걸음에 선이 안 난다", ch_calls > 0 and wd_calls == 0,
			"앞 chip 걸음 %d프레임 · 모음 걸음 %d프레임" % [ch_calls, wd_calls])

	# ── ⑭-d 0 만큼 바뀐 걸음은 선을 안 낸다 ───────────────
	#  판 칸 춤과 **같은 가드**를 물려받았는지. mult_rand 는 0 을 실제로 굴린다.
	_stage([_chip(0)])
	var w0 := _walk()
	_ok("⑭-d 0점 chip 걸음에 선이 안 난다", w0.calls == 0, "%d 호출" % w0.calls)
	_stage([{"k": "mult", "v": 1}])        # cur_mult 가 이미 1 이다 — 같은 값 재대입
	var wsame := _walk()
	_ok("⑭-e 같은 값 재대입에 선이 안 난다", wsame.calls == 0,
			"%d 호출" % wsame.calls)
	_stage([_item(0, "mult_rand", 0)])
	var wz := _walk()
	_ok("⑭-f 0 을 굴린 동전 걸음에 선이 안 난다", wz.calls == 0,
			"%d 호출" % wz.calls)

	# ── ⑮ 출발점이 제자리다 ───────────────────────────
	_stage([_chip(40)])
	g._process(1.0 / 60.0)
	while g.src_t <= 0.0 and g.state == g.S.RESOLVE:
		g._process(1.0 / 60.0)
	var bs: Vector2 = g._link_src()
	var bd: Vector2 = g._link_dst(bs)
	var bb: Rect2 = g._link_box()
	_ok("⑮ 판 걸음 출발점이 판 위다",
			g.src_slot < 0 and bs.distance_to(g.BC) <= g.R + 1.0,
			"BC 에서 %.1f (R %.1f)" % [bs.distance_to(g.BC), g.R])
	#  **가운데가 아니라 테두리다**(2026-09-26 수선). 가운데로 꽂으면 선이 그
	#  칸의 수를 긁는다 — 꼬리만 빨려 드는 구조라 칸에 걸친 토막이 가장 오래
	#  남고, 640×360 에서 수의 획이 2~3px 인데 겉선 3 + 속선 1 이 그 위를 지났다.
	_ok("⑮-b 점수 걸음 도착점이 점수 칸 **테두리**다",
			not g.src_ring and _on_edge(bd, bb)
					and is_equal_approx(bb.position.x - g.card_pos().x, 12.0),
			"%s · 칸 %s" % [bd, bb])

	_stage([_item(2, "mult", 3)])
	g._process(1.0 / 60.0)
	while g.src_t <= 0.0 and g.state == g.S.RESOLVE:
		g._process(1.0 / 60.0)
	var cs: Vector2 = g._link_src()
	var cd: Vector2 = g._link_dst(cs)
	var cb: Rect2 = g._link_box()
	var sr: Rect2 = g._slot_rect(2)
	_ok("⑮-c 동전 걸음이 그 슬롯에서 난다",
			g.src_slot == 2 and sr.grow(2.0).has_point(cs),
			"slot %d · %s in %s" % [g.src_slot, cs, sr])
	_ok("⑮-d 배수 걸음 도착점이 배수 칸 **테두리**다",
			g.src_ring and _on_edge(cd, cb)
					and is_equal_approx(cb.position.x - g.card_pos().x, 134.0),
			"%s · 칸 %s" % [cd, cb])
	#  동전이 낸 걸음은 **판을 안 가리킨다** — 안 그러면 거짓말이다.
	_ok("⑮-e 동전 걸음은 판에서 출발하지 않는다",
			cs.distance_to(g.BC) > 1.0)
	#  ⑮-f **선이 칸 안으로 한 픽셀도 안 든다.** 이 자가 「수를 안 긁는다」의
	#  본체다 — 머리가 어디에 있든 그 획 전체가 칸 밖이어야 한다.
	_stage([_chip(40), {"k": "mult", "v": 5}, _item(0, "chip", 20),
			_item(3, "mult", 2)])
	var into := 0
	var seen_f := 0
	var wn := 0
	while g.state == g.S.RESOLVE and wn < 900:
		g._process(1.0 / 60.0)
		wn += 1
		var p: Dictionary = g._link_plan()
		if p.is_empty():
			continue
		seen_f += 1
		var inner: Rect2 = (g._link_box() as Rect2).grow(-0.6)
		for q in 33:
			if inner.has_point((p.a as Vector2).lerp(p.b as Vector2, q / 32.0)):
				into += 1
	_ok("⑮-f 선이 칸 안으로 안 든다(수를 안 긁는다)", into == 0 and seen_f > 0,
			"칸 안에 든 표본 %d / %d프레임 × 33" % [into, seen_f])

	# ── ⑯ 꼬리가 닿는 프레임이 칸 봉우리와 같다 ─────────────
	#  ARC.drain 0.34 를 고른 유일한 까닭이다. 선의 마지막 픽셀이 빨려 드는
	#  그 프레임에 칸이 가장 크다 — 이 층의 유일한 주장이라 그것을 잠근다.
	#  칸에 적히는 수(_card_num)도 같은 프레임에 새 값에 선다(2026-10-06) — 봉우리
	#  프레임의 센 값이 cur_chip 이고, 그 앞에 앞 값과 새 값 **사이**의 수가 적힌
	#  프레임이 있어야 한다(늘 새 값을 돌려주는 함수는 여기서 걸린다).
	_stage([_chip(40)])
	var f_tail := -1
	var f_peak := -1
	var peak := -9.0
	var n_peak := -1
	var n_mid := false
	var fi := 0
	while g.state == g.S.RESOLVE and fi < 600:
		g._process(1.0 / 60.0)
		fi += 1
		if g.src_t > 0.0:
			if f_tail < 0 and g._link_plan().is_empty():
				f_tail = fi
			var j: float = g._card_juice(g.chip_j)
			var nv: int = g._card_num(g.chip_from, g.cur_chip, g.chip_j)
			if nv > g.chip_from and nv < g.cur_chip:
				n_mid = true
			if j > peak:
				peak = j
				f_peak = fi
				n_peak = nv
	_ok("⑯ 꼬리 도착과 칸 봉우리가 같은 프레임이다",
			f_tail > 0 and f_peak > 0 and absi(f_tail - f_peak) <= 1,
			"꼬리 %d프레임 · 봉우리 %d프레임(%.3f)" % [f_tail, f_peak, peak])
	_ok("⑯-b 점수 칸이 봉우리 프레임에 새 값까지 센다",
			n_mid and n_peak == g.cur_chip and g.cur_chip == 40,
			"봉우리 %d · 새 값 %d · 사이 값 %s" % [n_peak, g.cur_chip, n_mid])
	#  배수 칸 — 1 → 5 · 동전 ×3 이 15 로 세운다. 걸음마다 제 봉우리에서 선다.
	_stage([{"k": "mult", "v": 5}, _item(0, "xmult", 3)])
	var m_ok := 0
	var m_mid := 0
	var m_note := []
	var mpk := -9.0
	var mnv := -1
	var mps: int = g.pitch_step
	fi = 0
	while g.state == g.S.RESOLVE and fi < 600:
		g._process(1.0 / 60.0)
		fi += 1
		if g.pitch_step != mps:
			mps = g.pitch_step
			mpk = -9.0
		if g.mult_j <= 0.0:
			continue
		var jm: float = g._card_juice(g.mult_j)
		var mv: int = g._card_num(g.mult_from, g.cur_mult, g.mult_j)
		if mv > g.mult_from and mv < g.cur_mult:
			m_mid += 1
		if jm > mpk:
			mpk = jm
			mnv = mv
		elif mpk > 0.9 and mnv >= 0:
			#  봉우리를 막 지났다 — 그 프레임의 센 값을 적는다.
			m_note.append("%d→%d:%d" % [g.mult_from, g.cur_mult, mnv])
			if mnv == g.cur_mult:
				m_ok += 1
			mnv = -1
	_ok("⑯-c 배수 칸도 봉우리 프레임에 새 값까지 센다 (1→5 · 5→15)",
			m_ok == 2 and m_mid >= 2, "%s · 사이 값 %d프레임" % [m_note, m_mid])
	#  그림만 센다 — 걸음이 서는 프레임에 셈 값은 이미 새 값이다.
	_stage([_chip(40)])
	var c_at := -1
	fi = 0
	while g.state == g.S.RESOLVE and fi < 600 and c_at < 0:
		g._process(1.0 / 60.0)
		fi += 1
		if g.chip_j >= 1.0 - 0.0001:
			c_at = g.cur_chip
	_ok("⑯-d 셈 값은 걸음이 서는 프레임에 이미 새 값이다",
			c_at == 40 and g._card_num(0, 40, 1.0) == 0, "cur_chip %d" % c_at)

	# ── ⑰ 눌린 박자 · 빨리 보기에서도 안 새고 안 사라진다 ────
	_stage([_chip(40), {"k": "mult", "v": 5}, _chip(80)], 40)
	var wp := _walk()
	_ok("⑰ pace 바닥에서도 선이 적어도 한 프레임 뜬다", wp.lines >= 3,
			"%d프레임 · 걸음 셋" % wp.lines)
	_stage([_chip(40), {"k": "mult", "v": 5}, _chip(80)], 40)
	var wf := _walk(true)
	_ok("⑰-b 빨리 보기에서도 상한이 2고 안 샌다",
			wf.most <= 2 and g.src_t <= 0.0,
			"최대 %d · 끝 src_t %.4f" % [wf.most, g.src_t])

	# ── ⑱ 세기 사다리가 값을 탄다 ──────────────────────
	#  겉선 문턱이 **피로 밸브와 호출 밸브 둘 다**라, 이 줄이 「한 발에 굵은
	#  선 두셋 · 가는 선 여럿」을 잠근다.
	_stage([_chip(40)])                    # 0 → 40 · share 1.0
	while g.src_t <= 0.0 and g.state == g.S.RESOLVE:
		g._process(1.0 / 60.0)
	var pl_big: Dictionary = g._link_plan()
	g.cur_chip = 160
	_stage([_chip(8)])                     # 160 → 168 · share 0.048
	g.cur_chip = 160
	while g.src_t <= 0.0 and g.state == g.S.RESOLVE:
		g._process(1.0 / 60.0)
	var pl_sml: Dictionary = g._link_plan()
	_ok("⑱ 0→40 은 겉선이 걸린다",
			not pl_big.is_empty() and bool(pl_big.case),
			"세기 %.3f · 알파 %.2f" % [0.0 if pl_big.is_empty()
					else float(pl_big.k), 0.0 if pl_big.is_empty()
					else float(pl_big.al)])
	_ok("⑱-b 160→168 은 겉선이 안 걸린다",
			not pl_sml.is_empty() and not bool(pl_sml.case),
			"세기 %.3f · 알파 %.2f" % [0.0 if pl_sml.is_empty()
					else float(pl_sml.k), 0.0 if pl_sml.is_empty()
					else float(pl_sml.al)])
	#  연발 넷째 알갱이에서 겉선이 **스스로** 꺼진다 — 새 코드 0줄이고
	#  _card_amt 가 원래 하던 일이다. share 1.00 → 0.50 → 0.33 → 0.25.
	var case_on := []
	for st in [[0, 40], [40, 80], [80, 120], [120, 160]]:
		var amt: float = g._card_amt(int(st[0]), int(st[1]))
		case_on.append(clampf((amt - 0.15) / 0.30, 0.0, 1.0)
				>= float(g.ARC.case_at))
	_ok("⑱-d 연발 넷째 알갱이에서 겉선이 스스로 꺼진다",
			bool(case_on[0]) and not bool(case_on[3]), "%s" % [case_on])

	# ── ⑱-c 한 발 평균 호출이 프레임당 0.40 밑이다 ──────────
	#  판은 상시 다각형 여든 장을 그린다. 그 대비 몇 % 인가를 잰다.
	_stage([_chip(40), {"k": "mult", "v": 5}, _item(0, "chip", 20),
			_item(1, "mult", 2), {"k": "total"}])
	var wa := _walk()
	var per: float = float(wa.calls) / maxf(float(wa.frames), 1.0)
	_ok("⑱-c 한 발 평균 호출이 프레임당 0.40 밑", per < 0.40,
			"%d 호출 / %d프레임 = %.3f (판 80장 대비 +%.2f%%)"
			% [wa.calls, wa.frames, per, per / 80.0 * 100.0])

	# ── ⑲ 개발자 손잡이가 층을 정말 끈다 ────────────────
	g.link_mode = 0
	_stage([_chip(40)])
	g.link_mode = 0
	var woff := _walk()
	_ok("⑲ 「끔」이면 호출이 0 이다", woff.calls == 0, "%d 호출" % woff.calls)
	g.link_mode = 1
	_stage([_item(0, "chip", 20)])
	g.link_mode = 1
	var wboard := _walk()
	_ok("⑲-b 「판에서만」이면 동전 걸음에 안 난다", wboard.calls == 0,
			"%d 호출" % wboard.calls)
	g.link_mode = 2
	_stage([_chip(40)])
	g.link_mode = 2
	var wslot := _walk()
	_ok("⑲-c 「동전에서만」이면 판 걸음에 안 난다", wslot.calls == 0,
			"%d 호출" % wslot.calls)
	g.link_mode = 3

	# ── ⑳ 모션 끄기 — 움직임만 죽고 빛은 산다 ──────────────
	_stage([_chip(40)])
	g.motion_off = true
	while g.src_t <= 0.0 and g.state == g.S.RESOLVE:
		g._process(1.0 / 60.0)
	var pm: Dictionary = g._link_plan()
	var head_fixed: bool = not pm.is_empty() \
			and (pm.a as Vector2).distance_to(g._link_src()) < 0.01
	var seen := 0
	var mfr := 0
	while g.state == g.S.RESOLVE and mfr < 600:
		g._process(1.0 / 60.0)
		mfr += 1
		if not g._link_plan().is_empty():
			seen += 1
	g.motion_off = false
	_ok("⑳ 모션 끄기 — 선이 전체 길이로 고정된다", head_fixed,
			"머리가 출발점에 못 박혔다" if head_fixed else "머리가 움직인다")
	_ok("⑳-b 모션 끄기에서도 선은 보인다",
			not pm.is_empty() and float(pm.al) > 0.0,
			"알파 %.2f · 창 %d프레임" % [0.0 if pm.is_empty()
					else float(pm.al), seen + 1])

	# ── ㉑ 정산 팝이 한 자리에 안 쌓인다 ──────────────────
	#  팝은 전부 카드 윗변 **한 점**(cc)에서 난다. 수명이 0.9초 붙박이였을 때는
	#  pace 1.0 에서도 세 걸음, pace 바닥에서 아홉 걸음이 한 수명에 들어
	#  「점수 +80」 위에 「배수 +4」가 얹혔다 — 무엇인지 못 읽는 덩어리가 카드
	#  바로 위에 섰고, 그 위를 새로 그은 선이 또 지났다. 「점수 획득할 때 더 잘
	#  알 수 있으면」의 정반대라 여기서 프레임으로 잠근다.
	#  자: 같은 x(2px 안) · 읽을 만한 알파(≥0.25) 둘이 12px 안에 겹치면 실패다.
	#  수명을 걸음에 매면 다음 팝이 날 때 앞 팝이 18.5px 위 · 알파 0.41 이라
	#  세로로 갈리고, **박자를 어떻게 눌러도 그 픽셀 수가 같다.**
	for pc in [1, 40]:
		_stage([_item(0, "chip", 20), _item(1, "mult", 4),
				_item(2, "chip", 30), _item(3, "mult", 2)], pc)
		var clash := 0
		var most_pop := 0
		var pf := 0
		while g.state == g.S.RESOLVE and pf < 900:
			g._process(1.0 / 60.0)
			pf += 1
			var vis := []
			for p in g.pops:
				var k: float = float(p.t) / maxf(float(p.life), 0.0001)
				if 1.0 - k * k < 0.25:
					continue
				vis.append(Vector2(float(p.p.x), float(p.p.y) - k * 24.0))
			most_pop = maxi(most_pop, vis.size())
			for a in range(vis.size()):
				for b in range(a + 1, vis.size()):
					if absf(vis[a].x - vis[b].x) < 2.0 \
							and absf(vis[a].y - vis[b].y) < 12.0:
						clash += 1
		_ok("㉑%s 정산 팝이 한 자리에 안 겹친다"
				% ("" if pc == 1 else "-b 눌린 박자에서도"),
				clash == 0,
				"겹침 %d · 한 프레임 최대 %d장 · 걸음 넷" % [clash, most_pop])
