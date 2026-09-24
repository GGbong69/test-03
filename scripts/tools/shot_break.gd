extends SceneTree
#  판 깨짐(BRK) 한 벌 — 금이 나는 동안 · 조각이 나는 순간 · 흩어지는 중 ·
#  다 지나간 뒤 · 층 셋 · 테마 다섯 · 모션 끄기를 찍는다.
#    godot --path . --quit-after 1500 --script scripts/tools/shot_break.gd [-- 꼬리표]
#
#  ⚠ **창이 있어야 돈다** — --headless 를 빼고 돌린다. 피자 판은 SubViewport
#  텍스처 한 장이라 헤드리스에서는 애초에 안 그려지고, 이 연출에서 가장
#  중요한 눈 검사가 「피자에서 부채가 8 로 접히는가」다.
#
#  화면은 S.PICK 으로 둔다. 진짜로는 S.RESOLVE(점수 카드가 떠 있다) 안에서
#  나지만, 여기서 보려는 것은 **조각 경계가 그 판의 철선 위에 앉는가**라
#  카드가 판 옆을 가리면 그 판단이 흐려진다. 카드와 겹치는지는 qa_break 가
#  프레임으로 잰다.
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false
var tag := "brk"
const DT := 1.0 / 60.0


func _initialize() -> void:
	var ua := OS.get_cmdline_user_args()
	if not ua.is_empty():
		tag = String(ua[0])
	#  사람의 저장을 안 건드린다 — 도구는 제 자리를 박는다.
	Save.gpath = "user://_shot_brk_g.cfg"
	Save.path = "user://_shot_brk.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if busy: return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for _i in n:
		await process_frame


#  화면을 한 장 세운다. 연출 시계는 **손으로** 감는다 — g._process 를 돌리면
#  걸음과 카드까지 같이 흘러 어느 프레임을 찍었는지 못 적는다.
func _hold(n: int) -> void:
	for _i in n:
		g._tutor_close()
		g.tutor_out = 0.0
		g.swap_live = false
		g.grip_t = 9.0
		g.mouse_at = Vector2(-50.0, -50.0)
		g._brk_tick(DT)
		g.queue_redraw()
		await process_frame


func _snap(nm: String) -> void:
	root.get_texture().get_image().save_png("res://shots/%s_%s.png" % [tag, nm])


func _leg(mods: Array) -> void:
	g.set_process(true)
	g.mods_own = mods
	g._board_bake()
	g._start_leg()
	g._swap_skip()
	g.state = g.S.PICK
	g._pick_dart(0)
	await _wait(6)
	g.set_process(false)
	g.aim_dim = 0.0
	g._bd3_close()


#  판에 다트 넷을 꽂는다. 깨질 때 꽂힌 것이 어떻게 되는지가 보여야 한다.
func _darts() -> void:
	var bc: Vector2 = g.BC
	var r: float = g.R
	g.darts = [
		{"p": bc + Vector2(2.0, -r * 0.62), "id": "std", "rot": 0.10},
		{"p": bc + Vector2(r * 0.52, r * 0.40), "id": "std", "rot": 0.30},
		{"p": bc + Vector2(-r * 0.46, r * 0.22), "id": "std", "rot": -0.22},
		{"p": bc + Vector2(-r * 0.04, r * 0.02), "id": "std", "rot": 0.05},
	]


func _arm(tier: int) -> void:
	g._brk_skip()
	g._brk_arm(tier)
	g.brk_free = true          # 걸음(S.RESOLVE) 밖에서도 제 시계로 돈다


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다(--headless 를 빼고 --quit-after 1500)")
		quit(0)
		return
	g._new_run()
	await _wait(20)

	# ── ① 기본 판 · 보스 층 — 금 → 조각 → 흩어짐 → 숨 ──────
	await _leg([])
	_darts()
	print("  기본 판 칸 %d" % g._sec_n())
	_arm(2)
	print("  보스 — 부채 %d · 겹 %d · 단 %d" % [g.brk_w,
			(g.brk_rings as Array).size(), (g.brk_rings as Array).size() * 2])
	await _hold(1)
	await _snap("01_crack_a")          # 첫 단 — 불 둘레가 갈라진다
	await _hold(19)
	await _snap("02_crack_b")          # 절반쯤 — 살과 테가 번갈아 바깥으로
	await _hold(21)
	await _snap("03_crack_c")          # 거의 다 — 금이 조각 경계를 다 적었다
	#  발화까지 남은 프레임을 다 감는다(brk_span 0.676초 ≈ 41프레임)
	while not g.brk_fired:
		await _hold(1)
	await _snap("04_fire")             # 뜬 프레임 — 흰 실루엣으로 얼어 있다
	await _hold(2)
	await _snap("05_hold")             # 언 채로. 판은 이미 안 그려진다
	await _hold(3)
	await _snap("06_fly_a")            # 막 뜬다 · 다트가 먼저 떨어진다
	await _hold(6)
	await _snap("07_fly_b")
	await _hold(8)
	await _snap("08_fly_c")            # 다트가 다 졌다
	await _hold(10)
	await _snap("09_sink")             # 마지막 조각이 배경으로 가라앉는다
	while not (g.brk_shards as Array).is_empty():
		await _hold(1)
	await _snap("10_gone")             # 판이 없는 숨 — 화면에 아무것도 없다
	g._brk_skip()
	await _hold(2)
	await _snap("11_back")             # 손잡이를 내리면 판이 그대로 돌아온다

	# ── ② 층 셋을 같은 프레임에서 ──────────────────────────
	for t in 3:
		await _leg([])
		_darts()
		_arm(t)
		while not g.brk_fired:
			await _hold(1)
		await _hold(7)
		await _snap("2%d_tier_%s" % [t, ["small", "big", "boss"][t]])
		g._brk_skip()

	# ── ③ 테마 다섯 — 조각 경계가 그 판의 철선 위에 앉는가 ──
	for m in [["", ""], ["pizz", "pizza"], ["clok", "clock"],
			["dnut", "donut"], ["aimb", "target"], ["arst", "ring"]]:
		await _leg([] if String(m[0]) == "" else [String(m[0])])
		_darts()
		_arm(2)
		#  금이 다 그어진 프레임 — **조각을 자르는 그 선**이 판의 철선과
		#  한 픽셀도 안 어긋나는지가 여기서 드러난다.
		while not g.brk_fired \
				and g.brk_stage < (g.brk_rings as Array).size() * 2:
			await _hold(1)
		await _snap("3_%s_crack" % String(m[1]))
		while not g.brk_fired:
			await _hold(1)
		await _hold(1)
		await _snap("3_%s_fire" % String(m[1]))
		await _hold(8)
		await _snap("3_%s_fly" % String(m[1]))
		print("  %s — 칸 %d · 부채 %d · 겹 %d · 조각 %d · 톱밥 %d"
				% [String(m[1]) if String(m[1]) != "" else "기본", g._sec_n(),
						g.brk_w, (g.brk_rings as Array).size(),
						(g.brk_shards as Array).size(),
						(g.brk_bits as Array).size()])
		g._brk_skip()

	# ── ④ 모션 끄기 — 금만 남고 판은 안 사라진다 ────────────
	await _leg([])
	_darts()
	g.motion_off = true
	_arm(2)
	while not g.brk_fired:
		await _hold(1)
	await _hold(2)
	await _snap("40_motion_off")
	g.motion_off = false
	g._brk_skip()

	print("  찍음 %s" % tag)
	quit(0)
