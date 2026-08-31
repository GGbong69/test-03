extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# 새 런 화면을 리그 여덟 단 전부 찍는다.
#
#   godot --path . --quit-after 1200 --script scripts/tools/newrun_shots.gd
#
# 단마다 설명 줄 수가 1~7 로 다른데(금 리그이 일곱 줄), 한 단만 찍고
# 넘어가면 긴 단의 글자 겹침을 못 본다 — 실제로 그렇게 놓쳤다.
# 자리 겹침 자체는 stake_probe 가 수로 재고, 여기는 눈으로 본다.
#
# 진짜 저장은 안 건드린다. 제 대역 저장에 여덟 단을 심고 그 위에서 찍는다.

var g = null
var busy := false


func _initialize() -> void:
	Save.path = "user://_shot_newrun.cfg"
	Save.wipe()
	for r in GameData.stakes():
		Save.unlock(GameData.stake_key(String(r.get("id", ""))))
	# 팩도 전부 연다 — 잠긴 팩은 효과 줄 대신 조건 줄이 뜬다.
	for r in GameData.packs():
		Save.unlock("pack:" + String(r.get("id", "")))
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


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	g._open_newrun()
	# 팩을 하나씩 넘겨 본다 — 잠긴 히든이 어떻게 보이는지가 여기서만 보인다.
	for pi in GameData.packs().size():
		g._pack_view(pi)
		for i in 4:
			g._process(1.0 / 60.0)
			g.tip_a = 0.0
		g.queue_redraw()
		await process_frame
		await process_frame
		var pn := "pack_%d_%s.png" % [pi, GameData.packs()[pi].get("id", "")]
		root.get_texture().get_image().save_png("res://shots/" + pn)
		print("저장: %s" % pn)
	g._pack_view(0)
	var st := GameData.stakes()
	for k in st.size():
		GameData.stake = String(st[k].get("id", ""))
		for i in 4:
			g._process(1.0 / 60.0)
			g.tip_a = 0.0
		g.queue_redraw()
		await process_frame
		await process_frame
		var name := "newrun_%d_%s.png" % [k, GameData.stake]
		root.get_texture().get_image().save_png("res://shots/" + name)
		print("저장: %s  (%d줄)" % [name, g._stake_lines().size()])
	quit()
