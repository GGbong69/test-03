extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# 저울 다트통의 정산 카드를 네 자리에서 찍는다.
#
#   godot --path . --quit-after 1500 --script scripts/tools/bal_shots.gd
#
# 왜 있는가
#   저울 걸음은 반 박(약 0.5초)에 지나가고, 그 안에서 색이 한 번 달아올랐다
#   가라앉는다. 눈으로는 「보라색이 스쳤다」까지만 잡히므로 화면을 세워
#   두고 찍는다 — 다른 촬영 도구와 같은 어법이다.
#
#   네 자리가 곧 이 다트통이 화면에 하는 말 전부다.
#     앞    파랑 120 · 빨강 7           — 아직 안 골랐다
#     바뀜  보라가 희게 달아오른 64 64  — 방금 갈아 끼웠다
#     저울  가라앉은 보라 64 · 64       — 이것이 고른 값이다
#     합계  +4096 과 되짚는 한 줄       — 어디서 온 값인가
#
#   점수와 배수를 일부러 크게 벌린다(동전 둘을 쥐여 준다). 안 벌리면 두 수가
#   원래 비슷해서 「같아졌다」가 화면에 안 난다.
#
# 진짜 저장은 안 건드린다. 제 대역 저장 위에서 찍는다.

var g = null
var busy := false


func _initialize() -> void:
	Save.path = "user://_shot_bal.cfg"
	Save.wipe()
	for r in GameData.packs():
		Save.unlock("pack:" + String(r.get("id", "")))
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


func _coin(id: String) -> Dictionary:
	for it in GameData.items():
		if String(it.id) == id:
			var c: Dictionary = it.duplicate()
			c.gs = 0
			c.bought = 1
			return c
	return {}


# 트리플 띠의 한 점. 띠 반지름을 손으로 안 적는다 — 판정에 직접 물어 첫
# 자리를 쓴다. 튜닝 표가 판을 줄이면 이 도구가 조용히 빗나가는 것을 막는다.
func _triple_pt() -> Vector2:
	for i in 90:
		var rr := 0.10 + 0.01 * float(i)
		var p: Vector2 = g.BC + Vector2(0.0, -g.R * rr)
		if int(g.hit_info(p).get("mult", 0)) == 3:
			return p
	return g.BC + Vector2(0.0, -g.R * 0.62)


# 화면을 세우고 한 장. 흔들림은 끈다 — 프레임마다 화면이 통째로 밀려서
# 자리를 재는 데 쓸 수가 없다.
func _shot(name: String) -> void:
	g.set_process(false)
	g.shake = 0.0
	g.card_p = 1.0
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/_bal_%s.png" % name)
	print("저장: _bal_%s.png" % name)


func _run() -> void:
	await _wait(6)
	# **여기서** 다트통을 세운다. 게임이 _ready 에서 저장을 읽어
	# GameData.pack 을 한 번 덮으므로, _initialize 에서 잡으면 지워진다.
	GameData.pack = "p_x1"
	g._new_run()
	g.owned = [_coin("l01"), _coin("c34"), _coin("c01")]
	g._start_leg()
	if g.score_mode != "bal":
		print("★ 계산 방식이 %s 다 — packs.csv 의 p_x1 score 열을 봐라" % g.score_mode)
		quit(1)
		return
	await _wait(4)

	# 저울 다트통이 쥐여 준 데칼코마니를 **그대로 둔 채** 점수 100 · 배수 4 를
	# 얹는다. 계산 방식은 이제 그 동전이 쥐므로 빼면 bal 이 안 선다.
	g.owned = [_coin("l01"), _coin("c34"), _coin("c01")]
	g.sealed = -1
	g.aim = _triple_pt()
	g.queue.clear()
	g._land()

	# ① 앞 — 저울 걸음과 합산만 남은 순간이 「아직 안 고른」 마지막 프레임이다
	var guard := 0
	while g.queue.size() > 2 and guard < 900:
		await process_frame
		guard += 1
	await _shot("1_앞")
	g.set_process(true)

	# ② 바뀜 — 걸음이 서는 그 프레임. 번쩍임이 아직 1 에 가깝다
	guard = 0
	while not g.calc_lit and guard < 900:
		await process_frame
		guard += 1
	if not g.calc_lit:
		print("★ 저울 걸음이 안 섰다")
		quit(1)
		return
	print("저울 걸음: 점수 %d · 배수 %d → 합 %d ÷ 2 = %d"
			% [g.calc_c, g.calc_m, g.calc_c + g.calc_m, g.cur_chip])
	await _shot("2_바뀜")

	# ③ 저울 — 번쩍임만 꺼서 가라앉은 뒤의 색을 본다
	g.calc_flash = 0.0
	await _shot("3_저울")

	# ④ 합계 — 되짚는 한 줄이 붙어 있는지가 여기서만 보인다
	g.set_process(true)
	guard = 0
	while g.card_mode == 0 and guard < 900:
		await process_frame
		guard += 1
	await _shot("4_합계")
	print("  합계 +%d" % g.last_gain)
	quit()
