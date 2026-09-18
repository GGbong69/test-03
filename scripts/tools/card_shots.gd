extends SceneTree
# 점수 카드의 춤을 걸음의 자리마다 한 장씩 찍는다.
#   godot --path . --quit-after 900 --script scripts/tools/card_shots.gd -- before
#   → shots/card_<태그>_<이름>.png  (태그를 안 주면 now)
#
# 왜 있는가
#   춤 한 번이 0.265초(16프레임)에 끝난다. 예비 눌림은 3프레임, 봉우리는 한
#   프레임이다 — 눈으로는 「뭔가 튀었다」까지만 잡히므로 화면을 세워 두고 찍는다.
#   게임의 _process 는 끄고 축을 손으로 그 자리에 놓은 뒤 그린다(shot_text_a 어법).
#
#   자리마다 무엇을 보는가
#     1_참        아무것도 안 움직인 카드. **고치기 전과 한 픽셀도 같아야 한다**
#     2_예비      수가 3px 내려앉고 몸이 1px 가라앉은 프레임
#     3_봉우리    수 24 → 33 · 몸 4px. 소리가 3프레임 먼저 나고 여기서 받는다
#     4_작은뉴스  같은 봉우리인데 160→168 이라 24 → 29 밖에 안 큰다
#     5_배수만    **바뀐 칸만 튄다** — 왼쪽은 제 색으로 가만있다
#     6_저울      두 수가 진짜로 같이 바뀌는 유일한 걸음. 색은 calc_flash 가 쥔다
#     7_합계      36 → 55px. 런 통틀어 카드가 가장 크게 사는 자리
#     8_굴림      「+n」이 아직 굴러오르는 중
#     9_한방      금빛 테두리가 판 뒤에 물었다. 글자를 한 픽셀도 안 가려야 한다
#     10_모션끔   축을 다 달궈 놓고 모션만 끈다. **자리와 글자 크기가 1_참 과
#                 한 픽셀도 달라선 안 된다** — 판도 그림자도 금빛도 안 뜬다.
#                 칸 색만 다르다: 달아오름은 움직임이 아니라 색이라 motion_off
#                 가 안 끈다. calc_flash · total_flash · screen_flash 도 원래
#                 그렇다 — 새 축만 끄면 오히려 어법이 갈린다(2026-09-18).
#
#   그리고 마지막에 **살아 있는 정산**을 두 번 돌려 숫자로 잰다 —
#   몸이 쌓이는가 · 7px 에서 멎는가 · 걸음 길이가 안 늘었는가.
#
# 진짜 저장은 안 건드린다. 제 대역 저장 위에서 찍는다.
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var keep := {}
var tag := "now"
var live := true       # 거짓이면 게임 시계를 안 민다(카드가 제멋대로 걸음을 넘기지 않게)


func _initialize() -> void:
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 0:
		tag = String(ua[0])
	Save.gpath = "user://_shot_card_g.cfg"
	Save.path = "user://_shot_card.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if g != null and busy:
		_hold()
	if busy:
		return false
	busy = true
	_run()
	return false


func _hold() -> void:
	g._tutor_close()
	g.tutor_out = 0.0
	for k in keep.keys():
		g.set(k, keep[k])
	g.mouse_at = Vector2(-50.0, -50.0)
	g.queue_redraw()


# 게임 시계를 손으로 민다. 판 갈이(_swap_begin)와 새 런 연출이 _process 로만
# 끝나므로, 그냥 process_frame 만 기다리면 무대 고르는 화면에 앉은 채로 찍힌다.
func _tick(n: int) -> void:
	for i in n:
		if live:
			g._process(1.0 / 60.0)
		_hold()
		await process_frame


func _shot(nm: String) -> void:
	await _tick(3)
	root.get_texture().get_image().save_png("res://shots/card_%s_%s.png" % [tag, nm])
	print("  찍음 %s" % nm)


# 카드가 떠 있는 기본 상태. 걸음마다 여기에 축만 얹는다.
func _base() -> Dictionary:
	return {"state": g.S.RESOLVE, "shown": 120.0, "card_p": 1.0, "card_v": 0.0,
			"card_target": 1.0, "card_side": 1, "card_y": 206.0, "card_mode": 0,
			"cur_chip": 40, "cur_mult": 3, "calc_lit": false, "roll_t": -1.0,
			"card_item": "", "score_mode": "std",
			"calc_flash": 0.0, "total_flash": 0.0,
			"card_pop": 0.0, "card_vel": 0.0, "chip_j": 0.0, "mult_j": 0.0,
			"chip_amt": 0.30, "mult_amt": 0.30, "card_burst": 0.0,
			"gain_roll": 0.0, "card_jrate": 4.0, "motion_off": false}


# 춤 곡선의 자리를 f 로 되짚는다. u = 1 − f 이므로
#   u 0.09 = 예비 바닥 · u 0.338 = 봉우리 · u 0.77 = 되눌림
const F_PRE := 0.91
const F_TOP := 0.662


func _run() -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g.set_process(false)
	await _tick(10)
	g._new_run()
	await _tick(20)
	g._start_leg()
	await _tick(30)          # 판 갈이가 다 서야 펠트 위가 제 모습이다
	live = false             # 여기서부터 시계를 멈추고 축만 손으로 놓는다

	# ── 1. 참 — 아무것도 안 움직인 카드 ──────────────────
	keep = _base()
	await _shot("1_참")

	# ── 2. 예비 — 소리는 이미 났고 그림이 아직 안 받았다 ──
	keep = _base()
	keep["chip_j"] = F_PRE
	keep["chip_amt"] = 0.40          # 0 → 40
	keep["card_pop"] = -0.20
	await _shot("2_예비")

	# ── 3. 봉우리 — 수 24 → 33 · 몸 4px ──────────────────
	keep = _base()
	keep["chip_j"] = F_TOP
	keep["chip_amt"] = 0.40
	keep["card_pop"] = 0.609         # kick 16
	await _shot("3_봉우리")

	# ── 4. 작은 뉴스 — 같은 봉우리인데 160 → 168 이다 ────
	keep = _base()
	keep["cur_chip"] = 168
	keep["chip_j"] = F_TOP
	keep["chip_amt"] = 0.221
	keep["card_pop"] = 0.609
	await _shot("4_작은뉴스")

	# ── 5. 배수만 — 왼쪽 칸은 제 색으로 가만있어야 한다 ──
	keep = _base()
	keep["cur_mult"] = 9
	keep["mult_j"] = F_TOP
	keep["mult_amt"] = 0.297         # 3 → 9
	keep["card_pop"] = 0.609
	await _shot("5_배수만")

	# ── 6. 저울 — 두 칸이 같이. 색은 calc_flash 가 쥔다 ──
	keep = _base()
	keep["cur_chip"] = 64
	keep["cur_mult"] = 64
	keep["calc_lit"] = true
	keep["score_mode"] = "bal"
	keep["calc_c"] = 120
	keep["calc_m"] = 7
	keep["calc_flash"] = F_TOP
	keep["chip_j"] = F_TOP
	keep["mult_j"] = F_TOP
	keep["chip_amt"] = 0.397
	keep["mult_amt"] = 0.45
	keep["card_pop"] = 0.761         # kick 20
	await _shot("6_저울")

	# ── 7. 합계 — 36 → 55px. 굴림은 끝났다 ───────────────
	keep = _base()
	keep["card_mode"] = 1
	keep["cur_chip"] = 1240
	keep["cur_mult"] = 33
	keep["last_gain"] = 40920
	keep["total_flash"] = F_TOP
	keep["gain_roll"] = 0.0
	keep["card_pop"] = 0.989         # kick 26
	await _shot("7_합계")

	# ── 8. 굴림 — 수가 아직 올라오는 중 ──────────────────
	keep = _base()
	keep["card_mode"] = 1
	keep["cur_chip"] = 1240
	keep["cur_mult"] = 33
	keep["last_gain"] = 40920
	keep["total_flash"] = 0.86
	keep["gain_roll"] = 0.55
	keep["card_pop"] = 0.60
	await _shot("8_굴림")

	# ── 9. 한 방 — 금빛이 판 뒤에 물었다 ─────────────────
	keep = _base()
	keep["card_mode"] = 1
	keep["cur_chip"] = 1240
	keep["cur_mult"] = 33
	keep["last_gain"] = 40920
	keep["total_flash"] = F_TOP
	keep["card_burst"] = 1.0
	keep["card_pop"] = 1.20          # clamp
	await _shot("9_한방")

	# ── 10. 모션 끔 — 축을 다 달궈 놓고 끈다 ─────────────
	#  카드가 **한 픽셀도 안 움직여야** 한다. 한 축이라도 살아 있으면
	#  도우미 하나에 가드를 빠뜨린 것이다.
	keep = _base()
	keep["motion_off"] = true
	keep["chip_j"] = F_TOP
	keep["mult_j"] = F_TOP
	keep["chip_amt"] = 0.45
	keep["mult_amt"] = 0.45
	keep["card_pop"] = 1.20
	keep["card_burst"] = 1.0
	await _shot("10_모션끔")

	keep = {}
	live = true
	g.motion_off = false
	await _live()
	quit()


# ── 살아 있는 정산을 숫자로 잰다 ─────────────────────────
#  그림으로는 안 보이는 셋을 여기서만 잡는다.
#    ① 걸음이 촘촘하면 몸이 **쌓이는가**
#    ② 그 쌓임이 clamp 1.20(7px)에서 **멎는가** — 안 멎으면 카드 윗변이
#       동전 슬롯 밑변 64 를 밟는다
#    ③ 걸음 벽시계 길이가 **안 늘었는가** — 한 방의 60ms 를 qt 에서 뺐으므로
func _live() -> void:
	print("── 살아 있는 정산 ──")
	for n in [4, 20]:
		g.set_process(false)
		g._start_leg()
		g._card_reset()
		g.cur_chip = 0
		g.cur_mult = 0
		g.card_mode = 0
		g.calc_lit = false
		g.roll_t = -1.0
		g.pitch_step = 0
		g.queue.clear()
		for i in n:
			g.queue.append({"k": "chip", "v": 40 + i * 13})
		g.settle_n = g.queue.size()
		g.burst_n = 0
		g.card_side = 1
		g.card_y = 74.0
		g.card_p = 1.0
		g.card_target = 1.0
		g.state = g.S.RESOLVE
		g.qt = g.beat * 1.1

		var top := 0.0
		var lift := 0.0
		var secs := 0.0
		var fr := 0
		while g.state == g.S.RESOLVE and fr < 3000:
			g._process(1.0 / 60.0)
			secs += 1.0 / 60.0
			fr += 1
			top = maxf(top, float(g.card_pop))
			lift = maxf(lift, -float(g._card_lift()))
		# 카드 윗변 = card_y − 리프트. 동전 슬롯 밑변은 20 + 44 = 64 다.
		var edge: float = float(g.card_y) - lift
		print("  걸음 %2d · 배속 %.2f → 최고 pop %.3f · 리프트 %dpx · 카드 윗변 %d · %.2f초"
				% [n, g._pace(), top, int(lift), int(edge), secs])
		if lift > 7.0:
			print("  ★ 리프트가 7px 를 넘었다 — clamp 나 rise 를 봐라")
		if edge <= 64.0:
			print("  ★ 카드 윗변이 동전 슬롯 밑변 64 를 밟았다")

	# 한 방의 멈춤이 걸음을 늘리는지. **목표는 양쪽 다 안 넘긴다** — 넘기면
	# qt 가 beat×2.6 에서 beat×3.4 로 갈아 끼워져(원래 그렇다) 멈춤이 아니라
	# 그 갈래를 재게 된다. 값만 크고 작게 해서 big 문턱만 가른다.
	#
	# **보통 박자와 눌린 박자(0.015)를 둘 다 잰다.** 눌린 쪽이 curve_probe ·
	# score_probe 가 도는 조건이고, 2026-09-15 의 「16런이 900초를 넘김」이
	# 났던 자리다. 멈춤을 상수 0.06 으로 박으면 거기서 걸음(0.012초)보다 멈춤이
	# 길어져 발마다 60ms 가 통째로 얹힌다 — 프레임 수가 갈리면 그것이다.
	for bt in [0.34, 0.015]:
		await _stop_test(bt)


func _stop_test(bt: float) -> void:
	print("── 한 방의 멈춤이 걸음을 늘리는가 (박자 %.3f) ──" % bt)
	var got := []
	for hi in [false, true]:
		g.set_process(false)
		g._start_leg()
		g._card_reset()
		g.beat = bt
		g.cur_chip = 1000 if hi else 10
		g.cur_mult = 60 if hi else 2
		g.card_mode = 0
		g.total = 0
		g.target = 100000            # 60000 도 20 도 못 넘는다
		g.queue.clear()
		g.queue.append({"k": "total"})
		g.settle_n = 1
		g.burst_n = 0
		g.card_side = 1
		g.card_y = 206.0
		g.card_p = 1.0
		g.card_target = 1.0
		g.state = g.S.RESOLVE
		g.qt = g.beat * 1.1
		var secs := 0.0
		var fr := 0
		var burst := 0.0
		while fr < 3000 and g.state == g.S.RESOLVE:
			g._process(1.0 / 60.0)
			secs += 1.0 / 60.0
			fr += 1
			burst = maxf(burst, float(g.card_burst))
		print("  %s (+%d) → %.3f초 · %d프레임 · burst %.2f"
				% ["큰 값" if hi else "작은 값", g.last_gain, secs, fr, burst])
		got.append(secs)
	if abs(got[0] - got[1]) > 0.02:
		print("  ★ 두 길이가 %.3f초 다르다 — 멈춤을 qt 에서 안 뺀 것이다"
				% abs(got[0] - got[1]))
	else:
		print("  걸음 길이 차 %.3f초 — 멈춤을 qt 에서 뺀 것이 맞다"
				% abs(got[0] - got[1]))
