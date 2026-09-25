extends SceneTree
#  늦게 도착한 총합 · 잇는 선 — **살아 있는 한 발**을 프레임째 찍는다 (2026-09-26)
#
#     godot --path . --quit-after 20000 --script scripts/tools/shot_grow.gd [-- 꼬리표]
#
#  ⚠ **창이 있어야 돈다** — --headless 를 빼고 돈다. 꽂힌 자루가 3D
#  SubViewport 한 장이고, 선이 그 자루가 꽂힌 칸에서 출발하므로 **진짜로
#  화면에 서는 쪽**을 봐야 「출발점이 맞는가」를 눈으로 판정할 수 있다.
#
#  왜 card_shots 로 안 되는가
#    card_shots 는 카드만 세워 놓고 찍는다 — 판이 빈 상태라 선의 출발점이
#    없다. 이 도구는 **진짜로 다트를 꽂고 진짜 큐를 태운다.** 그래야
#    「판의 그 칸 → 카드의 그 칸」이 한 그림 안에 같이 선다.
#
#  시계는 g._process(DT) 로 **손으로** 감는다 — 엔진에 맡기면 어느 프레임을
#  찍었는지 못 적는다(shot_impact 가 먼저 간 길이다).
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
var g = null
var busy := false
var tag := "grow"
const DT := 1.0 / 60.0


func _initialize() -> void:
	var ua := OS.get_cmdline_user_args()
	if not ua.is_empty():
		tag = String(ua[0])
	Save.gpath = "user://_shot_grow_g.cfg"
	Save.path = "user://_shot_grow.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _process(_d: float) -> bool:
	if busy:
		return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for _i in n:
		await process_frame


#  ⚠ **g._process 를 손으로 안 부른다 — 재 보고 알았다.** 이 harness 에서는
#  await process_frame 한 번에 엔진이 이미 g 를 한 프레임 돌린다(set_process
#  (false) 를 걸어도 그렇다). 손으로 한 번 더 부르면 **한 번에 두 프레임**이
#  흘러, 걸음이 서는 프레임을 건너뛰고 꼬리가 반쯤 빨려 든 장면만 찍혔다
#  (배수 선이 「3」 위의 짧은 얼룩으로 남았다). 한 프레임 = await 한 번이다.
func _step(n: int) -> void:
	for _i in n:
		g._tutor_close()
		g.tutor_out = 0.0
		g.swap_live = false
		g.mouse_at = Vector2(-50.0, -50.0)
		g.queue_redraw()
		await process_frame
		g.swap_live = false


func _snap(nm: String) -> void:
	#  **안 기다린다.** _step 의 마지막 await 가 이미 그 프레임을 그렸다 —
	#  여기서 또 기다리면 그림만 한 프레임 늦어 숫자와 안 맞는다.
	root.get_texture().get_image().save_png("res://shots/%s_%s.png" % [tag, nm])
	var pl: Dictionary = g._link_plan()
	var sr: Vector2 = g._link_src()
	print("  %s_%s  띠 %.0f/%d · 굴림 %.2f · 흔들림 %.1f · src_t %.3f · card_p %.2f · 선 %s"
			% [tag, nm, g.shown, g.total, g.score_roll, g.shake, g.src_t, g.card_p,
			"없음" if pl.is_empty() else "%s→%s(출처 %s) %s 알파 %.2f%s 길이 %.0f"
					% [pl.a.round(), pl.b.round(), sr.round(),
					"배수" if bool(pl.ring) else "점수", float(pl.al),
					" +겉선" if bool(pl.case) else "",
					(pl.a as Vector2).distance_to(pl.b)]])


func _fresh() -> void:
	g._new_run()
	await _wait(2)
	g._start_leg()
	#  ⚠ **목표를 손으로 세운다.** _start_leg 는 target 을 안 건드린다 —
	#  그 한 줄은 _begin_leg 에 있다. 안 세우면 target 이 0 이라 _grow_n 의
	#  maxf(target, 1) 이 걸려 **어떤 값이든 r 이 천장**이 되고, 이 도구가
	#  찍는 흔들림이 늘 12.0 으로 나온다(처음 돌렸을 때 실제로 그랬다).
	#  게임에서는 _begin_leg 가 늘 앞서므로 이건 도구의 세움 문제다.
	g.target = GameData.target_of(g.leg_no)
	await _wait(2)
	g.swap_live = false
	g.state = g.S.PICK
	g._pick_dart(0)
	await _step(2)


#  다음 걸음이 **서는 그 프레임**까지 감는다. 걸음 길이는 박자·배속·갈래가
#  정하므로 프레임 수를 손으로 세면 갈래마다 틀린다 — 처음엔 세다가 동전
#  걸음 넷을 통째로 놓쳤다(선이 서기 전에 찍었다).
#  한 프레임 = await 한 번이므로
#  돌아온 자리가 곧 걸음이 선 프레임이고, 그때 선이 전체 길이로 서 있다.
func _to_edge() -> void:
	var ps: int = g.pitch_step
	var n := 0
	while g.state == g.S.RESOLVE and g.pitch_step == ps and n < 400:
		await _step(1)
		n += 1


#  판 꼭대기 칸(20) 쪽으로 반지름 f*R 인 점.
func _at(f: float) -> Vector2:
	return g.BC + Vector2(0.0, -g.R * f)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 돈다")
		quit(0)
		return

	# ── ① 살아 있는 한 발 — 트리플에 꽂고 걸음마다 찍는다 ──
	#  선이 서는 창이 걸음의 앞 26% 라, 걸음이 바뀌는 프레임마다 한 장씩
	#  찍으면 **선이 전체 길이로 선 그 프레임**이 잡힌다.
	print("── 살아 있는 한 발 (트리플) ──")
	await _fresh()
	g.aim = _at((g.rt_trp_in + g.rt_trp_out) * 0.5)
	g.state = g.S.FLY
	g.fly_t = 0.0
	g._land()
	print("  큐 %d걸음 · 꽂힌 칸 idx %d · 목표 %d"
			% [g.queue.size(), g.hit_idx, g.target])
	var shot := 0
	while g.state == g.S.RESOLVE and shot < 8:
		await _to_edge()
		#  _snap 의 await 가 걸음을 세운다 — 선이 통째로 선 그 프레임이다.
		await _snap("live_%02d_걸음" % shot)
		#  꼬리가 반쯤 빨려 든 자리도 한 장.
		await _step(1)
		await _snap("live_%02d_꼬리" % shot)
		shot += 1
	#  걸음이 다 끝난 뒤 — 띠가 아직 구르는 중인가를 본다.
	await _snap("live_99_끝")

	# ── ② 크기 넷 — 같은 화면에서 흔들림·굴림을 견준다 ──
	#  실제 경로로는 r 2.00 짜리 발을 손으로 못 만든다. 개발자 모드의
	#  「총합 걸음 다시 보기」와 같은 세움이다.
	print("── 총합 걸음 네 크기 ──")
	for pair in [[0.05, "바닥"], [0.50, "한방문턱"], [1.00, "목표"], [2.00, "천장"]]:
		var r: float = float(pair[0])
		await _fresh()
		g.state = g.S.RESOLVE
		g._card_reset()
		g.target = 1000
		g.total = 0
		g.shown = 0.0
		g.cur_chip = int(round(r * 1000.0))
		g.cur_mult = 1
		g.card_mode = 0
		g.card_item = ""
		g.card_side = 1
		g.card_y = 74.0
		g.card_p = 1.0
		g.card_target = 1.0
		g.queue.clear()
		g.queue.append({"k": "total"})
		g.settle_n = 1
		g.qt = g.beat * g._pace()
		await _to_edge()
		await _snap("size_%s_선다" % String(pair[1]))
		await _step(10)
		await _snap("size_%s_구른다" % String(pair[1]))
		await _step(30)
		await _snap("size_%s_늦다" % String(pair[1]))

	# ── ③ 동전이 낸 걸음 — 선이 슬롯에서 난다 ──────────
	print("── 동전이 낸 걸음 ──")
	await _fresh()
	g.state = g.S.RESOLVE
	g._card_reset()
	#  ⚠ **card_mode 를 손으로 내린다.** _card_reset 은 이걸 안 건드리고
	#  앞 절이 합계 카드(1)를 켜 둔 채 끝나서, 동전 걸음의 선이 칸도 없는
	#  총합 카드 한복판을 가리켰다. 게임에서는 _land 가 걸음을 세울 때마다
	#  0 으로 내리므로 이건 도구의 세움 문제다 — 게임 갈래는 안 난다.
	g.card_mode = 0
	g.card_item = ""
	g.target = 1000
	g.total = 0
	g.shown = 0.0
	g.cur_chip = 40
	g.cur_mult = 3
	g.card_side = 1
	g.card_y = 74.0
	g.card_p = 1.0
	g.card_target = 1.0
	g.hit_idx = 3
	g.hit_bull = false
	g.hit_r0 = g.R * 0.20
	g.hit_r1 = g.R * 0.60
	g.queue.clear()
	g.queue.append({"k": "item", "i": 0, "kind": "chip", "v": 80, "lbl": "동전"})
	g.queue.append({"k": "item", "i": 3, "kind": "mult", "v": 4, "lbl": "동전"})
	g.settle_n = 2
	g.qt = g.beat * g._pace()
	for j in 2:
		await _to_edge()
		await _snap("slot_%d_선다" % j)
		await _step(2)
		await _snap("slot_%d_꼬리" % j)

	print("끝")
	quit()
