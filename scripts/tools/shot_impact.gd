extends SceneTree
#  착탄 한 벌 — 등급 여섯이 나는 첫 프레임 · 둘째 · 여섯째 · 열둘째,
#  확인 고리가 조여드는 네 시점, 꽂힌 자루가 크림 칸 위에 선 그림.
#
#     godot --path . --quit-after 20000 --script scripts/tools/shot_impact.gd [-- 꼬리표]
#
#  ⚠ **창이 있어야 돈다** — --headless 를 빼고 돈다. 꽂힌 자루는 3D
#  SubViewport 한 장(_draw_darts 의 bd_vp)이라 헤드리스에서는 2D 받침
#  (_draw_darts_2d)이 대신 서는데, 이 도구가 보려는 것이 바로 **진짜로
#  화면에 서는 쪽**이다.
#
#  시계는 g._process(DT) 로 **손으로** 감는다 — 엔진에 맡기면 어느 프레임을
#  찍었는지 못 적는다(shot_dart 가 먼저 간 길이다).
#
#  사람의 저장을 안 건드린다 — 도구는 Save.gpath / Save.path 를 제 자리로 박는다.
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
var g = null
var busy := false
var tag := "imp"
const DT := 1.0 / 60.0
#  찍는 프레임. 0 은 착탄 그 프레임이고 11 은 물결이 거의 스러진 뒤다.
const AT := [0, 2, 6, 11]


func _initialize() -> void:
	var ua := OS.get_cmdline_user_args()
	if not ua.is_empty():
		tag = String(ua[0])
	Save.gpath = "user://_shot_imp_g.cfg"
	Save.path = "user://_shot_imp.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	#  ⚠ **엔진의 _process 를 끈다.** 안 끄면 게임이 제 시계로도 돌아
	#  _step 의 손 시계와 **두 번** 흐르고, 판 갈이가 제멋대로 살아나
	#  판이 누운 프레임이 섞여 찍힌다(shot_dart 가 먼저 간 길이다).
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


#  게임 시계를 n 프레임 감는다. 멈춤(hitstop)도 그대로 먹으므로 등급이
#  높을수록 같은 n 에 덜 흐른다 — 그것이 재려는 값이다.
func _step(n: int) -> void:
	for _i in n:
		g._tutor_close()
		g.tutor_out = 0.0
		#  판 갈이를 내린다 — 안 내리면 _swap_rise() 가 0 이라 **판이 아예
		#  안 그려진 채** 물결만 허공에 뜬다. shot_break · shot_aimglow 가
		#  먼저 간 길이고 같은 한 줄이다.
		g.swap_live = false
		g.mouse_at = Vector2(-50.0, -50.0)
		g._process(DT)
		g.swap_live = false
		g.queue_redraw()
		await process_frame


func _snap(nm: String) -> void:
	await _wait(1)
	root.get_texture().get_image().save_png("res://shots/%s_%s.png" % [tag, nm])
	print("  %s_%s" % [tag, nm])


#  판 꼭대기 칸(20) 쪽으로 반지름 f*R 인 점. 등급마다의 자리를 여기서 뽑는다.
func _at(f: float) -> Vector2:
	return g.BC + Vector2(0.0, -g.R * f)


func _fresh() -> void:
	g._new_run()
	await _wait(2)
	g._start_leg()
	await _wait(2)
	g.swap_live = false
	g.state = g.S.PICK
	g._pick_dart(0)
	#  3D 자루 무대가 첫 프레임에 안 열려 있다 — 한 번 돌려 세운다.
	await _step(2)


#  한 등급을 꽂고 네 프레임을 찍는다.
func _land_at(nm: String, f: float) -> void:
	await _fresh()
	g.aim = _at(f)
	g.state = g.S.FLY
	g.fly_t = 0.0
	#  찍기 전에 **판정을 로그로 적는다** — 그림만 보면 어느 띠에 꽂혔는지
	#  눈으로 되짚어야 하고, 반지름비가 바뀌면 조용히 딴 띠를 찍는다.
	var hi: Dictionary = g.hit_info(g.aim)
	print("  [%s] f=%.3f  sector=%d mult=%d idx=%d" % [nm, f,
			int(hi.sector), int(hi.mult), int(hi.idx)])
	g._land()
	var dp: Vector2 = Vector2(-9999.0, -9999.0)
	if not g.darts.is_empty():
		dp = g.darts[g.darts.size() - 1].p
	print("      꽂힌 자리 %s  BC %s  R %.1f  darts %d  state %d"
			% [dp, g.BC, g.R, g.darts.size(), g.state])
	var last := 0
	for k in AT.size():
		var n: int = int(AT[k]) - last
		if n > 0:
			await _step(n)
		last = int(AT[k])
		await _snap("%s_f%02d" % [nm, int(AT[k])])


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 돈다")
		quit(0)
		return
	#  ── 등급 여섯 ──
	#  자리는 반지름비 표에서 뽑는다. 띠 한가운데라 경계에서 안 흔들린다.
	var zones := {
		"miss":   g.rt_dbl_out + 0.10,                   # 판벌이 — 테 **밖**(r > R*rt_dbl_out)
		"single": (g.rt_bull_o + g.rt_trp_in) * 0.5,
		"triple": (g.rt_trp_in + g.rt_trp_out) * 0.5,
		"double": (g.rt_dbl_in + g.rt_dbl_out) * 0.5,
		"bullo":  (g.rt_bull_i + g.rt_bull_o) * 0.5,
		"bulli":  g.rt_bull_i * 0.3,
	}
	for z in zones:
		await _land_at(z, float(zones[z]))

	#  ── 확인 고리 ── 창(ch())의 0 · 1/3 · 2/3 · 끝. 곡선이 꼬리를 남기는지 본다.
	await _fresh()
	g.aim = _at((g.rt_trp_in + g.rt_trp_out) * 0.5)
	g.state = g.S.CONFIRM
	for k in 4:
		g.confirm_t = g.ch() * float(k) / 3.0
		g.queue_redraw()
		await _snap("confirm_%d" % k)

	#  ── 꽂힌 자루 ── 크림 칸 위에 다섯. 확인 조준선이 그 위를 지나는지 본다.
	await _fresh()
	g.darts.clear()
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.55
		var rr: float = g.R * (0.34 + 0.12 * float(i))
		g.darts.append({"p": g.BC + Vector2(cos(a), sin(a)) * rr,
				"id": "std", "rot": randf_range(-0.26, 0.26)})
	g.aim = _at((g.rt_trp_in + g.rt_trp_out) * 0.5)
	g.state = g.S.CONFIRM
	g.confirm_t = g.ch() * 0.5
	await _step(1)
	await _snap("stuck_aim")
	g.state = g.S.PICK
	await _step(1)
	await _snap("stuck")

	#  ── 상단 띄 오른쪽 끝 ─────────────────────
	#  제약 아이콘이 서는 자리다(LAY.bar_mod x 584~640). 심사가 여기를
	#  「정산 빨리 보기 조작(‖ · ≫ · +2)」으로 읽었는데, 실제로는
	#  narrow(막대 둘 — 원래 폭 grey + 남은 폭 loss) · gust(겹화살) ·
	#  넘친 개수다. 누를 수 있는 것이 아니라 **표시**라 단추 문법을
	#  입히면 오히려 거짓말이 된다 — 눈으로 보려고 넣는 한 장이다. 2026-09-24
	await _fresh()
	g.active_mods.clear()
	var mfs: Array = GameData.modifiers()
	for i in mini(4, mfs.size()):
		g.active_mods.append(mfs[i])
	await _step(1)
	await _snap("modband")
	print("  찍음")
	quit(0)
