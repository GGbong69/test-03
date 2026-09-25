extends SceneTree

#  기획서용 — 조준 여덟 갈래와 「20 트리플 착탄」 순간.
#
#  aim_shots 는 검사용이라 저장을 지우고 들어가므로 튜토리얼 예고(조여 드는
#  어둠과 「!」)가 화면에 같이 찍힌다. 기획서에 그대로 넣었더니 판을 가렸다.
#  여기서는 찍기 직전에 예고와 설명창을 끈다.
#
#  착탄 그림은 판만 보여 주면 점수 이야기가 안 된다 — 명사수(place) 로 20
#  트리플에 꽂고 정산 카드(「+60 · 20 x 3」)가 뜬 순간을 찍는다.
#
#   godot --path . --quit-after 1800 --script scripts/tools/deck_shots3.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const FPS := 1.0 / 60.0

#  이름 · 방식 · 1단계 틱 · 2단계까지 갈까 · 2단계 틱
const CUTS := [
	["std", "std", 22, true, 34],
	["ring", "ring", 30, false, 0],
	["tilt", "tilt", 24, true, 40],
	["cross", "cross", 26, false, 0],
	["drift", "drift", 47, false, 0],
	["place", "place", 12, false, 0],
	["pull", "pull", 12, false, 0],
	["kick", "kick", 0, false, 0],
]

var g = null
var busy := false


func _initialize() -> void:
	Save.path = "user://_deck3.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _quiet() -> void:
	g.tip_a = 0.0
	g.tip_title = ""
	g.tip_lines = []
	g.tip_tags = []
	g.tutor_q.clear()
	g.tutor_id = ""
	g.tutor_pre = 0.0
	g.tutor_out = 0.0
	g.tutor_t = 0.0


func _shoot(name: String) -> void:
	_quiet()
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/" + name)
	print("저장: %s" % name)


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	return false


func _run() -> void:
	g._new_run()
	g._swap_skip()
	g._begin_leg()
	g._swap_skip()
	for i in 8:
		g._process(FPS)
	for c in CUTS:
		await _cut(c[0], c[1], int(c[2]), bool(c[3]), int(c[4]))
	await _hit20("deck_hit_20t.png", false)
	await _hit20("deck_hit_20t_item.png", true)
	quit(0)


func _cut(name: String, mode: String, t1v: int, two: bool, t2: int) -> void:
	var t1 := t1v
	if g.remaining.is_empty():
		g._start_leg()
	g.state = g.S.PICK
	g._pick_dart(0)
	g.aim_mode = mode
	g._aim_begin()
	_quiet()
	g.mouse_at = g.BC + Vector2(46.0, -34.0)
	if mode == "drift":
		t1 = 40
	if mode == "kick":
		var spot: Vector2 = g.BC + Vector2(14.0, 34.0)
		g.mouse_at = spot
		g._click(spot)
		for q in 16:
			g._aim_tick(FPS)
		t1 = 0
	if mode == "pull":
		var org: Vector2 = g._pull_org()
		g.mouse_down = true
		g.mouse_at = org
		g._pull_grab(org)
		var tgt: Vector2 = g.BC + Vector2(26.0, -44.0)
		var need: Vector2 = (tgt - org) / float(g.PULL.vs) * 0.08
		for q in 6:
			g.mouse_at = org.lerp(org + need, float(q + 1) / 6.0)
			g._aim_tick(0.08 / 6.0)
		t1 = 0
	for i in t1:
		g._aim_tick(FPS)
		_quiet()
	if two:
		g._advance()
		for i in t2:
			g._aim_tick(FPS)
			_quiet()
	g.mouse_down = false
	await _shoot("deck_aim_%s.png" % name)


#  20 트리플 한 발. 자리는 hit_info 에게 물어서 찾는다 — 반지름을 손으로
#  적으면 판 그림이 바뀔 때마다 조용히 빗나간다.
func _hit20(name: String, with_item: bool) -> void:
	if g.remaining.is_empty():
		g._start_leg()
	g.target = 999999          # 이 발로 판이 끝나 버리면 정산 카드를 못 찍는다
	g.total = 0
	g.owned = []
	if with_item:
		for it in GameData.items():
			if String(it.get("n", "")) == "발라트로의 조커":
				g.owned = [it.duplicate(true)]
				break
	g.state = g.S.PICK
	g._pick_dart(0)
	g.aim_mode = "place"
	g._aim_begin()
	_quiet()
	var p: Vector2 = g.BC
	for r in range(int(g.R * 0.30), int(g.R * 0.95)):
		var q: Vector2 = g.BC + Vector2(0.0, -float(r))
		var info: Dictionary = g.hit_info(q)
		if int(info.get("sector", 0)) == 20 and int(info.get("mult", 0)) == 3:
			p = q
			break
	g.mouse_at = p
	g._click(p)
	#  날아가 꽂히고 카드가 다 설 때까지 돌린다
	var t := 0
	while t < 900:
		g._process(FPS)
		t += 1
		if g.state == g.S.RESOLVE and g.card_mode == 1:
			break
	#  숫자가 다 올라간 뒤에 찍는다 — 카드가 뜨자마자 찍으면 「+58」 처럼
	#  세는 중간이 남는다
	for i in 45:
		g._process(FPS)
	await _shoot(name)
	print("   착탄 (%.0f, %.0f) · 이 발 %d점 · 카드 %d x %d"
			% [g.aim.x, g.aim.y, g.last_gain, g.cur_chip, g.cur_mult])
