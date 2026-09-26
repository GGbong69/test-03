extends SceneTree
#  달아오르는 가장자리와 빈 박 — **살아 있는 한 발**을 단마다 찍는다 (2026-09-26)
#
#     godot --path . --quit-after 40000 --script scripts/tools/shot_fire.gd [-- 꼬리표]
#
#  ⚠ **창이 있어야 돈다** — --headless 를 빼고 돈다. 이 층은 화면 가장자리
#  열여덟 픽셀이 전부라, 실제로 화면에 서는 쪽을 봐야 「상단 띠를 안 덮는가 ·
#  카드와 뜨는가 · 자금판이 얼마나 씻기는가」를 눈으로 판정할 수 있다.
#
#  왜 네 단을 다 찍는가
#    이 설계의 계약이 **0단이 손대기 전과 한 톨도 다르지 않다**는 것이다.
#    0단 그림이 손대기 전 그림과 같지 않으면 그 계약이 거짓이다 — 그래서
#    0단을 반드시 한 장 찍는다(가장자리에 한 픽셀도 없어야 한다).
#
#  시계는 shot_grow 와 같은 규약이다: 한 프레임 = await 한 번. 손으로
#  g._process 를 부르면 한 번에 두 프레임이 흘러 걸음이 서는 프레임을 놓친다.
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
const Dev = preload("res://scripts/dev.gd")
var g = null
var busy := false
var tag := "fire"


func _initialize() -> void:
	var ua := OS.get_cmdline_user_args()
	if not ua.is_empty():
		tag = String(ua[0])
	Save.gpath = "user://_shot_fire_g.cfg"
	Save.path = "user://_shot_fire.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	#  ⚠ **씨를 못 박는다.** 단마다 _fresh() 로 런을 새로 여는데, 씨가 안
	#  박히면 딜링과 동전이 달라져 장면이 단마다 다르다 — 위 고리 평균을
	#  단끼리 견주는 일이 통째로 헛것이 된다(처음에 실제로 그랬다:
	#  0단은 동전 2/5 · 3단은 0/5 였다).
	seed(20260926)


func _process(_d: float) -> bool:
	if busy:
		return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for _i in n:
		await process_frame


func _step(n: int) -> void:
	for _i in n:
		g._tutor_close()
		g.tutor_out = 0.0
		g.swap_live = false
		g.mouse_at = Vector2(-50.0, -50.0)
		g.queue_redraw()
		await process_frame
		g.swap_live = false


#  ⚠ **처음 쓴 자는 쓸모가 없었다.** 「빨강이 배경보다 올랐는가」로 세었더니
#  판·펠트·카드의 제 색이 다 걸려 0단에서도 2만 픽셀이 잡혔고, 상단 띠의
#  금빛 게이지가 「띠가 덮였다」로 찍혔다. **그림 하나를 절대값으로 읽는 자는
#  이 층을 못 잰다.**
#
#  대신 화면의 바깥 여섯 픽셀 고리(상단 띠 밑)만 훑어 **평균 색**을 낸다.
#  같은 장면을 단만 바꿔 찍으므로 그 수가 단을 따라 오르면 층이 실제로
#  칠해진 것이고, 0단이 손대기 전과 같은 수면 0단 계약이 픽셀로 증명된다.
#  (seed 를 못 박아 장면이 단마다 같도록 했다 — 안 그러면 이 비교가 헛것이다.)
func _ring(img: Image) -> Dictionary:
	var w := int(g.FIRE.w)
	var top := int(float(g.LAY.bar.size.y))
	var sx := int(g.VIEW.x)
	var sy := int(g.VIEW.y)
	var sr := 0.0
	var sg := 0.0
	var sb := 0.0
	var n := 0
	for y in range(top, sy):
		for x in range(sx):
			if not (x < w or x >= sx - w or y < top + w or y >= sy - w):
				continue
			var c := img.get_pixel(x, y)
			sr += c.r
			sg += c.g
			sb += c.b
			n += 1
	var d: float = float(maxi(n, 1))
	return {"r": sr / d, "g": sg / d, "b": sb / d, "n": n}


func _snap(nm: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("res://shots/%s_%s.png" % [tag, nm])
	var k := _ring(img)
	#  ⚠ 단(fire_hot)과 겹 단(fire_lay)을 **둘 다** 찍는다(2026-09-26). 그림이
	#  읽는 것은 겹 단이고 멈춤·침묵이 읽는 것은 단이다 — 하나만 찍으면 「4단인데
	#  겹이 둘」인 그림을 앞에 두고 무엇이 맞는지 못 가른다.
	print("  %s_%s  단 %d · 겹 %d · 창 %.2f · 봉투 %.3f · 멈춤 %.3f · 흔들림 %.1f"
			% [tag, nm, g.fire_hot, g.fire_lay, g.fire_t, g._fire_env(),
			g.hitstop, g.shake]
			+ " · 늦춘소리 %.0f · 바깥 %dpx 고리 평균 RGB %.4f %.4f %.4f"
			% [g.fire_snd, int(g.FIRE.w), k.r, k.g, k.b])


func _fresh() -> void:
	g._new_run()
	await _wait(2)
	g._start_leg()
	#  ⚠ **목표를 손으로 세운다** — shot_grow 가 적어 둔 그 함정이다.
	#  _start_leg 는 target 을 안 건드리므로 안 세우면 r 이 늘 천장이 되고
	#  이 도구가 찍는 단이 늘 4단으로 나온다.
	g.target = GameData.target_of(g.leg_no)
	await _wait(2)
	g.swap_live = false
	g.state = g.S.PICK
	g._pick_dart(0)
	await _step(2)


func _to_edge() -> void:
	var ps: int = g.pitch_step
	var n := 0
	while g.state == g.S.RESOLVE and g.pitch_step == ps and n < 400:
		await _step(1)
		n += 1


func _at(f: float) -> Vector2:
	return g.BC + Vector2(0.0, -g.R * f)


#  합계 걸음 하나를 손으로 세운다(qa_fire 의 _stage 와 같은 어법).
func _stage(r: float, tgt := 1000) -> void:
	g.state = g.S.RESOLVE
	g._card_reset()
	g.target = tgt
	g.total = 0
	g.shown = 0.0
	g.cur_chip = int(round(r * float(tgt)))
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


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 돈다")
		quit(0)
		return

	# ── ① 단 다섯 — 0단이 손대기 전과 같은가가 이 절의 본문이다 ──
	print("── 단 다섯 (단 강제) ──")
	for t in range(5):
		await _fresh()
		_stage(0.90)
		g.fire_lock = t
		await _to_edge()
		#  ⚠ **이 절에서만 흔들림을 0 으로 눌러 찍는다.** 흔들림은 프레임마다
		#  randf_range 라 밑에 깔린 그림이 프레임마다 달라, 고리 평균을 단끼리
		#  견주는 일이 통째로 헛것이 된다(처음 찍었을 때 0단 0.2355 · 2단
		#  0.2525 · 4단 0.2288 로 단을 안 따랐다 — 층이 아니라 흔들림이 낸 수다).
		#  누르면 밑그림이 단마다 똑같아져 **차이가 곧 이 층**이다.
		#  흔들림이 같이 선 그림은 아래 「살아 있는 한 발」과 「돌파」가 맡는다.
		g.shake = 0.0
		await _step(1)
		#  **여기가 가장 밝은 프레임이다** — rise 0 이라 값이 난 프레임에 가득
		#  차고, 멈춤이 걸린 단에서는 그대로 얼어 있다.
		await _snap("tier%d_선다" % t)
		#  가장 긴 멈춤(4단 7.2프레임)을 지난 자리 — 풀리며 빠지기 시작한다.
		await _step(8)
		await _snap("tier%d_풀림" % t)
		await _step(14)
		await _snap("tier%d_꺼진다" % t)
		g.fire_lock = -1

	# ── ② 살아 있는 한 발 — 진짜로 꽂고 진짜 큐를 태운다 ──
	#  **반드시 있어야 하는 장이다.** 위 ①은 검사대 값이고 이 절만
	#  「판·카드·상단 띠가 다 선 화면에서 어떻게 보이는가」를 말한다.
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
		await _snap("live_%02d" % shot)
		shot += 1
	await _snap("live_99_끝")

	# ── ③ 가장 붐비는 프레임 — 목표 돌파에 테두리가 겹친다 ──
	#  층 열 개가 켜진 프레임에 한 겹 더 얹는 자리다. 여기서 읽을 수 없으면
	#  되돌려야 한다.
	print("── 가장 붐비는 프레임 (목표 돌파) ──")
	await _fresh()
	_stage(2.00)
	await _to_edge()
	await _snap("brk_선다")
	await _step(2)
	await _snap("brk_봉우리")
	await _step(8)
	await _snap("brk_뒤")

	# ── ④ 모션 끄기 — 빛은 살고 움직임만 죽는다 ──
	print("── 모션 끄기 ──")
	await _fresh()
	_stage(0.90)
	g.motion_off = true
	g.fire_lock = 4
	await _to_edge()
	await _snap("motionoff_선다")
	await _step(3)
	await _snap("motionoff_봉우리")
	g.motion_off = false
	g.fire_lock = -1

	# ── ⑤ 빨리 보기 2.5 — 창이 걸음을 안 넘는가 ──
	print("── 빨리 보기 2.5 ──")
	await _fresh()
	_stage(0.90)
	g.fire_lock = 3
	g.fast_lock = true
	g.fast_mul = 2.5
	await _to_edge()
	await _snap("fast_선다")
	await _step(2)
	await _snap("fast_봉우리")
	g.fast_lock = false
	g.fire_lock = -1

	# ── ⑥ 개발자 5쪽 — 새 줄 둘이 안 잘리는가 ──
	print("── 개발자 5쪽 ──")
	await _fresh()
	_stage(0.90)
	Dev.on = true
	Dev.page = 5
	await _step(2)
	await _snap("dev5")
	#  테두리가 개발자 판을 안 덮는가 — Dev.draw 앞에 그리므로.
	g.fire_lock = 4
	await _to_edge()
	await _step(3)
	await _snap("dev5_불")
	g.fire_lock = -1
	Dev.on = false

	# ── ⑦ 한 판 안에서 값이 오른다 — 겹이 안 줄어드는가 ──
	#  (2026-09-26 · 되짚어 고침) 손대기 전에는 그림이 fire_hot 을 읽었고 4단은
	#  「판에 한 번」 깃발을 태운 값이라, 같은 판에서 r 0.55 두 겹 → r 0.62 **세
	#  겹** → r 0.70 두 겹이 났다. 뒤에 온 더 큰 발이 앞의 것보다 **얇아 보인**
	#  것이다. 이 절은 그 셋을 나란히 찍어 눈으로 판정하는 자리다 — 단 강제를
	#  안 쓰고 **살아 있는 값**으로 돌려야 하므로 total 을 목표 위에서 출발시켜
	#  돌파를 뺀다(무한 런과 반동으로 목표를 넘긴 뒤 걸음이 이어지는 그 자리다).
	print("── 한 판 안에서 값이 오른다 (살아 있는 값) ──")
	await _fresh()
	_stage(0.55)
	g.total = g.target * 5
	g.shown = float(g.total)
	g.queue.clear()
	for _q in 3:
		g.queue.append({"k": "total"})
	var rs := [0.55, 0.62, 0.70]
	for j in rs.size():
		g.cur_chip = int(round(float(rs[j]) * float(g.target)))
		g.cur_mult = 1
		await _to_edge()
		g.shake = 0.0
		await _step(1)
		await _snap("rise%d_r%03d" % [j, int(round(float(rs[j]) * 100.0))])

	print("끝")
	quit()
