extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")

# 개발자 모드의 목록 고르개를 찍고, 칸을 눌러 실제로 들어오는지 본다.
#
#     godot --path . --headless --script scripts/tools/dev_pick_shot.gd
#
# 화살표로 한 장씩 넘기던 자리에 목록을 붙였다. 그림이 없으면 "칸이 겹치나 ·
# 이름이 잘리나 · 두 쪽이 맞나" 를 눈으로 못 본다.
var g = null
var busy := false


func _initialize() -> void:
	Save.path = "user://_shot_devpick.cfg"
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


func _shot(nm: String) -> void:
	for i in 4:
		g._process(1.0 / 60.0)
		g.tip_a = 0.0
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/" + nm)
	print("저장: " + nm)


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	g._new_run()
	g._swap_skip()
	g.leg_no = 1
	g._start_leg()
	g._swap_skip()

	Dev.on = true
	Dev.page = 1                       # 물건
	await _shot("devpick_0_판.png")

	# 「동전 주기」 줄의 값 칸을 누른 것과 같은 상태
	Dev.open_k = "item"
	Dev.open_n1 = "동전 주기"
	Dev.open_page = 0
	await _shot("devpick_1_목록.png")

	Dev.open_page = 1
	await _shot("devpick_2_둘째쪽.png")

	# 칸을 실제로 눌러 본다 — 그림만 맞고 안 들어오면 소용이 없다.
	var before: int = g.owned.size()
	Dev.open_page = 0
	var cell := Dev._pick_cell(20)      # 둘째 칸 두 번째 줄쯤
	var ok: bool = Dev.click(g, cell.get_center())
	print("칸 클릭: 삼켰나=%s · 고르개 닫혔나=%s · 동전 %d → %d"
			% [ok, Dev.open_k == "", before, g.owned.size()])
	if g.owned.size() > before:
		print("  들어온 동전: %s" % g.owned[-1].get("n", "?"))
	await _shot("devpick_3_적용후.png")

	# 쪽 나누기가 실제 장수와 맞는가
	var n: int = GameData.items().size()
	var per: int = Dev.PCOL * Dev.PROW
	print("동전 %d장 · 한 쪽 %d칸 · %d쪽" % [n, per, (n + per - 1) / per])
	quit()
