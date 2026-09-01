extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# 새 런 화면을 리그 여덟 단 전부 찍는다.
#
#   godot --path . --quit-after 1200 --script scripts/tools/newrun_shots.gd
#
# 단마다 설명 줄 수가 1~7 로 다른데(검정 리그이 일곱 줄), 한 단만 찍고
# 넘어가면 긴 단의 글자 겹침을 못 본다 — 실제로 그렇게 놓쳤다.
# 자리 겹침 자체는 stake_probe 가 수로 재고, 여기는 눈으로 본다.
#
# 진짜 저장은 안 건드린다. 제 대역 저장에 여덟 단을 심고 그 위에서 찍는다.
#
# 팩 통은 3D 강체다(_cup3_*). 손으로 감은 _process 로는 물리가 한 발도
# 안 나가므로 여기서는 게임 시계를 **엔진에 맡기고** 진짜 프레임을 센다 —
# 다른 촬영 도구가 _process 를 눌러 두는 것은 커서 때문인데, 이 화면에는
# 툴팁이 없어서 눌러 둘 이유가 없다.

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


func _process(_d: float) -> bool:
	if busy:
		return false
	busy = true
	_run()
	return false


# 진짜 프레임을 센다. 물리(통·자루)와 넘기기가 이 사이에 돈다.
func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _wait(6)
	g._open_newrun()
	await _wait(150)          # 자루가 통 안에서 가라앉기를 기다린다
	# 팩을 하나씩 넘겨 본다 — 잠긴 히든이 어떻게 보이는지가 여기서만 보인다.
	for pi in GameData.packs().size():
		if pi > 0:
			g._pack_step(1)   # 넘기기(=미끄러짐)를 그대로 태운다
			await _wait(220)
		await process_frame
		var pn := "pack_%d_%s.png" % [pi, GameData.packs()[pi].get("id", "")]
		root.get_texture().get_image().save_png("res://shots/" + pn)
		print("저장: %-22s 자루 %d개" % [pn,
				g.cup_rigs[0].darts.size() if not g.cup_rigs.is_empty() else -1])
	g._pack_step(1)
	await _wait(220)
	var st := GameData.stakes()
	for k in st.size():
		GameData.stake = String(st[k].get("id", ""))
		await _wait(2)
		var name := "newrun_%d_%s.png" % [k, GameData.stake]
		root.get_texture().get_image().save_png("res://shots/" + name)
		print("저장: %-22s (%d줄)" % [name, g._stake_lines().size()])
	quit()
