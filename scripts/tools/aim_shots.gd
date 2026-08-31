extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# 조준 여덟 갈래를 눈으로 본다. 한 갈래마다 특징이 드러나는 순간을 찍는다 —
# 잠긴 것은 어둡게 움직이는 것은 밝게, 그 규칙이 실제로 읽히는지가 요점이다.
#
#  실행:  godot --path . --script scripts/tools/aim_shots.gd

const FPS := 1.0 / 60.0

var g = null
var busy := false

# 이름 · 방식 · 1단계를 몇 틱 돌릴까 · 2단계까지 갈까 · 2단계를 몇 틱
const CUTS := [
	["std_1", "std", 22, false, 0],
	["std_2", "std", 22, true, 34],
	["ring_1", "ring", 30, false, 0],
	["ring_2", "ring", 30, true, 14],
	["ray_2", "ray", 34, true, 12],
	["tilt_1", "tilt", 24, false, 0],
	["tilt_2", "tilt", 24, true, 40],
	["cross", "cross", 26, false, 0],
	["drift", "drift", 47, false, 0],
	["place", "place", 12, false, 0],
	["pull", "pull", 12, false, 0],
]


func _initialize() -> void:
	Save.path = "user://_shot_aim.cfg"
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
	# 기다리지 않는다. _process 안에서 await 하면 이 함수가 코루틴이
	# 되어 프레임이 안 돌고, 안에서 기다리는 process_frame 이 영영
	# 안 온다 — 아무것도 안 찍고 조용히 끝난다.
	_run()
	return false


func _run() -> void:
	g._new_run()
	g._swap_skip()
	g._open_stage()
	g._swap_skip()
	for i in 8:
		g._process(FPS)

	for c in CUTS:
		await _cut(c[0], c[1], int(c[2]), bool(c[3]), int(c[4]))
	quit()


func _cut(name: String, mode: String, t1v: int, two: bool, t2: int) -> void:
	var t1 := t1v
	if g.remaining.is_empty():
		g._start_round()
	g.state = g.S.PICK
	g._pick_dart(0)
	g.aim_mode = mode
	g._aim_begin()
	# 손을 읽는 갈래는 커서를 놓아 준다. 당김은 쥔 자리까지 잡아 준다.
	g.mouse_at = g.BC + Vector2(46.0, -34.0)
	if mode == "pull":
		g.pull_at = g.BC + Vector2(38.0, -22.0)
		g.mouse_at = g.pull_at + Vector2(-52.0, 66.0)
		# 헤드리스는 버튼이 눌린 적이 없어서, 쥔 채로 한 틱만 돌려도
		# 그 자리에서 "놓았다" 로 읽혀 확인 칸으로 넘어간다.
		# 당기는 중의 그림을 보려면 틱을 안 돌리고 자리만 세운다.
		g.aim = g._pull_point()
		t1 = 0
	for i in t1:
		g._aim_tick(FPS)
	if two:
		g._advance()
		for i in t2:
			g._aim_tick(FPS)
	g.tip_a = 0.0
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/aim_%s.png" % name)
	print("저장: aim_%s.png  %s · %s · 조준 (%.0f, %.0f)"
			% [name, mode, "2단계" if two else "1단계", g.aim.x, g.aim.y])
