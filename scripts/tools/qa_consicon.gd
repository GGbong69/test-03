extends SceneTree

# 사탕·사진 칸 검사. 2026-09-13 사용자 제보 — "왜 사탕으로 표시돼?"
#   사진을 손에 들면 사탕·사진 칸에 **사탕 그림**으로 떴다. 사탕과 사진이 한 표에
#   살고 같은 칸을 쓰는데, 그리는 쪽이 id 만 보고 안 갈랐다.
#
#   godot --path . --quit-after 900 --script scripts/tools/qa_consicon.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_ci.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-34s %s" % ["통과" if c else "실패", n, d])


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _shoot(nm: String) -> void:
	for i in 4:
		g._process(1.0 / 60.0)
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	print("\n사탕·사진 칸 검사 — 사탕과 사진을 가른다\n")

	# ① 갈래 판정. 이름이나 앞글자로는 못 가른다 — 구성 VIII 의 id 가 c_again 이다
	var cd := GameData.candies()
	var fx := GameData.fixtures()
	var bad := PackedStringArray()
	for c in cd:
		if GameData.is_fixture(String(c.id)):
			bad.append("사탕 %s" % c.n)
	for f in fx:
		if not GameData.is_fixture(String(f.id)):
			bad.append("사진 %s" % f.n)
	_ok("사탕 %d · 사진 %d 를 다 가른다" % [cd.size(), fx.size()], bad.is_empty(),
			"틀린 것: %s" % ("없다" if bad.is_empty() else ", ".join(bad)))

	# 앞글자 규칙으로 갈랐다면 이 한 장이 틀린다
	var again := GameData.fixture_of("c_again")
	_ok("구성 VIII 를 사진으로 본다",
			not again.is_empty() and GameData.is_fixture("c_again"),
			"id c_again · 이름 %s" % again.get("n", "(없음)"))
	_ok("모르는 id 는 사진이 아니다", not GameData.is_fixture("없는id"), "")

	# ② 손에 들면 칸이 사진으로 뜬다 — 그림은 눈으로, 갈래는 자로
	g.cons = [GameData.fixture_of("v_cash"), cd[0]]
	g.state = g.S.SHOP
	var kinds := PackedStringArray()
	for c in g.cons:
		kinds.append("사진" if GameData.is_fixture(String(c.id)) else "사탕")
	_ok("한 칸씩 갈래가 갈린다", kinds[0] == "사진" and kinds[1] == "사탕",
			"%s · %s" % [kinds[0], kinds[1]])

	# ③ 칸 이름이 사탕만 말하지 않는다
	var src := FileAccess.open("res://scripts/game.gd", FileAccess.READ)
	var txt := src.get_as_text()
	src.close()
	_ok("칸 이름이 「사탕」 하나가 아니다",
			txt.find('box.end.y + 9.0), "사탕",') < 0, "사탕·사진")

	await _shoot("cons_slot")
	print("\n스크린샷: shots/cons_slot.png")
	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
