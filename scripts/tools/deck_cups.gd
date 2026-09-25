extends SceneTree

#  기획서용 — 다트통 열셋을 한 종씩 찍는다.
#
#  기획서에 통이 셋만 실려 있었다. 게임에는 열셋이고 겉이 다 다르다.
#  잠긴 통은 새 런 화면에서 물음표로 서므로 **먼저 전부 해금해 둔다** —
#  이 도구의 저장은 user://_deck_cups.cfg 라 실제 프로필을 안 건드린다.
#
#   godot --path . --quit-after 1800 --script scripts/tools/deck_cups.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const FPS := 1.0 / 60.0

var g = null
var busy := false


func _initialize() -> void:
	Save.path = "user://_deck_cups.cfg"
	Save.wipe()
	for row in GameData.packs():
		Save.unlock("pack:" + String(row.get("id", "")))
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


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	return false


func _run() -> void:
	for i in 8:
		g._process(FPS)
	g.state = g.S.NEWRUN
	g._open_newrun()
	for i in 20:
		g._process(FPS)
	var rows := GameData.packs()
	for i in rows.size():
		#  _pack_view 만 부르면 번호만 바뀌고 3D 통은 그대로다 — 통을 다시
		#  짓는 것은 _cup3_step 이라 화면이 쓰는 길(_pack_step)을 그대로 쓴다
		if i > 0:
			g._pack_step(1)
		#  미끄러짐이 멎고 새 통이 설 때까지 돌린다
		for t in 60:
			g._process(FPS)
			_quiet()
		var id: String = String(rows[i].get("id", ""))
		await _shoot("deck_cup_%02d_%s.png" % [i, id])
		print("저장: deck_cup_%02d_%s.png  %s" % [i, id, String(rows[i].get("name", ""))])
	quit(0)
