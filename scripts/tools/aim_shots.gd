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
	["tilt_1", "tilt", 24, false, 0],
	["tilt_2", "tilt", 24, true, 40],
	["cross", "cross", 26, false, 0],
	["drift", "drift", 47, false, 0],
	["place", "place", 12, false, 0],
	["pull", "pull", 12, false, 0],
	["kick", "kick", 0, false, 0],
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
	await _kick_card()
	quit()


# 연발 한 발의 점수 카드. 카드가 보여 주는 "칩 x 배수" 와 실제로 오르는
# 총점이 같아야 한다 — 정산 결과만 깎았을 때는 50x1 을 보여 주고 13 만
# 올랐다. 화면이 거짓말을 하던 자리라 사진으로 남긴다.
func _kick_card() -> void:
	if g.remaining.is_empty():
		g._start_leg()
	g.target = 999999
	g.owned = []
	g.sealed = -1
	g.total = 0
	g.state = g.S.PICK
	g._pick_dart(0)
	g.aim_mode = "kick"
	g._aim_begin()
	var p: Vector2 = g.BC
	g.mouse_at = p
	g._click(p)
	var t := 0
	while g.burst_left > 0 and t < 600:
		g.mouse_at = p + Vector2(0.0, -g.kick_o.y)   # 반동을 눌러 잡는다
		g._aim_tick(FPS)
		t += 1
	while t < 900 and g.card_mode != 1:
		g._process(FPS)
		t += 1
	g.tip_a = 0.0
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/aim_kick_card.png")
	print("저장: aim_kick_card.png  카드 %d x %d · 이 발 %d점 · 총점 %d"
			% [g.cur_chip, g.cur_mult, g.last_gain, g.total])


func _cut(name: String, mode: String, t1v: int, two: bool, t2: int) -> void:
	var t1 := t1v
	if g.remaining.is_empty():
		g._start_leg()
	g.state = g.S.PICK
	g._pick_dart(0)
	g.aim_mode = mode
	g._aim_begin()
	# 손을 읽는 갈래는 커서를 놓아 준다. 당김은 쥔 자리까지 잡아 준다.
	g.mouse_at = g.BC + Vector2(46.0, -34.0)
	if mode == "drift":
		t1 = 40                     # 흔들림이 자리를 잡을 만큼 돌린다
	if mode == "kick":
		# 연발 도중을 잡는다 — 두 발쯤 나가서 반동이 얹혔을 때.
		var spot: Vector2 = g.BC + Vector2(14.0, 34.0)
		g.mouse_at = spot
		g._click(spot)
		for q in 16:
			g._aim_tick(FPS)
		t1 = 0
	if mode == "pull":
		# 벽의 자루를 잡고 판 쪽으로 튕기는 도중을 잡는다. 쥔 채로 두어야
		# "놓았다" 로 안 읽히므로 mouse_down 을 세워 둔다.
		var org: Vector2 = g._pull_org()
		g.mouse_down = true
		g.mouse_at = org
		g._pull_grab(org)
		# 세기는 상수에서 거꾸로 뽑는다 — 손으로 적으면 vs 를 만질 때마다
		# 그림만 조용히 판을 벗어난다.
		var tgt: Vector2 = g.BC + Vector2(26.0, -44.0)
		var need: Vector2 = (tgt - org) / float(g.PULL.vs) * 0.08
		for q in 6:
			g.mouse_at = org.lerp(org + need, float(q + 1) / 6.0)
			g._aim_tick(0.08 / 6.0)
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
