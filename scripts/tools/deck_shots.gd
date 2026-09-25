extends SceneTree

#  기획서에 들어갈 화면. 설명창(툴팁)이 안 뜬 깨끗한 컬렉션 여섯 탭과,
#  일부러 세운 설명창 한 장, 새 런 화면을 찍는다.
#
#  qa_shots2 는 검사용이라 설명창이 스쳐 남는다 — 기획서 그림에는 그 틀이
#  거슬려서 여기서는 마우스를 화면 밖으로 빼고 틀까지 비운다.
#
#   godot --path . --quit-after 900 --script scripts/tools/deck_shots.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false


func _initialize() -> void:
	Save.path = "user://_deck_shots.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


#  설명창을 완전히 내린다 — 알파만 0 으로 두면 틀이 한 장 남는다.
#  튜토리얼도 끈다 — 저장을 지우고 들어오므로 첫 화면마다 예고(「!」와 조여 드는
#  어둠)가 걸려서 기획서 그림에 노란 상자가 같이 찍힌다.
func _no_tip() -> void:
	g.tip_a = 0.0
	g.tip_title = ""
	g.tip_lines = []
	g.tip_tags = []
	g.mouse_at = Vector2(-999.0, -999.0)
	_no_tutor()


#  튜토리얼만 끈다. 설명창을 일부러 세운 장면에서도 이건 꺼야 한다.
func _no_tutor() -> void:
	g.tutor_q.clear()
	g.tutor_id = ""
	g.tutor_pre = 0.0
	g.tutor_out = 0.0
	g.tutor_t = 0.0


func _shoot(name: String) -> void:
	_no_tutor()
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/" + name)
	print("저장: %s" % name)


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	g._new_run()
	g._swap_skip()
	for i in 20:
		g._process(1.0 / 60.0)

	#  컬렉션 여섯 탭 — 동전 · 보드 확장 · 다트 · 사탕 · 사진 · 제약
	g.state = g.S.COLLECT
	for t in 6:
		g.collect_tab = t
		g.collect_page = 0
		_no_tip()
		await _shoot("deck_col_%d.png" % t)

	#  설명창 한 장 — 조건이 붙은 동전(제목 · 효과 · 태그가 다 보이는 것)
	g.collect_tab = 0
	for i in GameData.items().size():
		var it: Dictionary = GameData.items()[i]
		if String(it.get("n", "")) == "천동설":
			g.collect_page = i / 24
			g._tip_build({"k": "citem", "i": i})
			g.tip_a = 1.0
			await _shoot("deck_tip_coin.png")
			break

	#  새 런 화면 — 다트통 고르기
	_no_tip()
	g.state = g.S.NEWRUN
	for i in 10:
		g._process(1.0 / 60.0)
	_no_tip()
	await _shoot("deck_newrun.png")
	quit(0)
