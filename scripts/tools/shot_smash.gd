extends SceneTree
#  턱에 처박히는 리롤을 박자마다 굽는다.
#
#  **시계를 손으로 감는다**(g.set_process(false)). 창을 띄우고 프레임을 그냥
#  세면 한 프레임이 0.03초씩 들쭉날쭉이라, 흰 실루엣(0.045초)과 부딪힘
#  창(0.36~0.49초)이 샘플 사이로 통째로 빠진다 — 실제로 한 번 놓쳤다.
#  감는 폭은 1/60 이고 물리는 DROP.sub 로 쪼개 넣는다(게임의 _drop_update 와
#  같은 차례 · 같은 이월).
#
#  매물 넷과 아홉 두 벌 — 조각 예산이 매물 수로 갈린다(5/4/3).
#
#  창이 필요하다(--headless 를 뺀다):
#    godot --path . --quit-after 2500 --script scripts/tools/shot_smash.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false
var acc := 0.0

#  볼 자리(초). 뻗기 · 후리기 · 첫 부딪힘 앞뒤 · 열차 · 정적 · 복귀.
const AT := [0.05, 0.15, 0.25, 0.317, 0.35, 0.367, 0.383, 0.40,
		0.417, 0.433, 0.467, 0.50, 0.55, 0.617, 0.70, 0.80]


func _initialize() -> void:
	Save.gpath = "user://_shot_sm_g.cfg"
	Save.path = "user://_shot_sm.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if busy:
		return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _shot(nm: String) -> void:
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)


#  한 프레임. _drop_update 의 차례 그대로다.
#
#  **3D 팔을 손으로 같이 민다.** _hand3_sync / _body3_sync 는 _process 안에만
#  있는데(game.gd 의 _npc_on 갈래) 여기는 set_process(false) 라 안 돈다 —
#  안 밀면 열여섯 장 내내 상인이 **쉬는 자세로 얼어 있고 후리는 팔이 한 장도
#  안 찍힌다**(2026-09-18 에 실제로 그렇게 찍었다). 그러면 이 도구가 재려던
#  「마지막 물건의 조각이 손에 안 가리는가」(_smash_draw 를 _cover_draw 뒤에
#  둔 이유)를 이 그림으로는 못 본다.
#  여는 것(_hand3_open/_body3_open)은 set_process(false) 전 30프레임이 이미
#  했고 두 번 불러도 _hand3_live 가 막으므로, 차례를 통째로 옮겨 적는다.
func _frame(d: float) -> void:
	g._sweep_update(d)
	g._waste_update(d)
	g._smash_update(d)
	acc += d
	while acc >= g.DROP.sub:
		acc -= g.DROP.sub
		g.drop_t += g.DROP.sub
		g._drop_step(g.DROP.sub)
	g._drop_extras(d)
	g.npc_clock += d         # 숨 · 쉬는 팔이 읽는 시계
	if g._npc_on():
		g._hand3_open()
		g._hand3_sync()
		g._body3_open()
		g._body3_sync()


func _stack(n: int) -> void:
	g._roll_stock()
	var n0: int = g.stock.size()
	if n0 > 0:
		while g.stock.size() < n:
			g.stock.append(g.stock[g.stock.size() % n0].duplicate(true))
		while g.stock.size() > n:
			g.stock.remove_at(g.stock.size() - 1)
	g._drop_roll()
	g._drop_settle()


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀")
		quit(0)
		return
	g.state = g.S.TITLE
	g._new_run()
	g.gold = 40
	g.leg_no = 3
	g._open_shop()
	await _wait(30)
	g.set_process(false)
	var dt := 1.0 / 60.0
	for pass_i in 2:
		var n: int = 4 if pass_i == 0 else 9
		_stack(n)
		g._sweep_begin()
		acc = 0.0
		var t := 0.0
		var k := 0
		var step := 0
		while k < AT.size() and step < 200:
			step += 1
			_frame(dt)
			t += dt
			while k < AT.size() and t >= float(AT[k]):
				await _shot("sm%d_%02d" % [n, k])
				print("%d k=%02d t=%.3f 조각 %d 가루 %d 먼지 %d 자국 %d 흔들 %.1f"
						% [n, k, t, g.shards.size(), g.grit.size(),
						g.smash_dust.size(), g.lip_marks.size(), g.shake])
				k += 1
	print("끝")
	quit(0)
