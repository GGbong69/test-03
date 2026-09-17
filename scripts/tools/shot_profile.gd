extends SceneTree
# 프로필 화면을 눈으로 본다.
#   godot --path . --quit-after 900 --script scripts/tools/shot_profile.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false

func _initialize() -> void:
	Save.gpath = "user://_shot_prof_g.cfg"
	Save.prof_fmt = "user://_shot_prof_%d.cfg"
	for i in range(1, Save.SLOTS + 1):
		Save.erase_slot(i)
	Save.use_slot(1)
	Save.unlock("pack:p_mag")
	Save.unlock("league:green")
	Save.bump("runs", 12)
	Save.bump("wins", 3)
	Save.peak("best_leg", 14)
	Save.peak("best_score", 418)
	Save.flush()
	Save.use_slot(2)
	Save.bump("runs", 2)
	Save.peak("best_leg", 4)
	Save.peak("best_score", 96)
	Save.flush()
	Save.use_slot(1)
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)

func _process(_d: float) -> bool:
	if busy: return false
	busy = true
	_run()
	return false

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _shot(nm: String) -> void:
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)

func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g.state = g.S.TITLE
	await _wait(20)
	await _shot("prof_title")
	g._open_profile()
	await _wait(20)
	await _shot("prof_1")
	g.prof_sel = 2
	await _wait(6)
	await _shot("prof_2")
	g.prof_sel = 3
	await _wait(6)
	await _shot("prof_3")
	g.prof_sel = 2
	g.prof_arm = 2
	await _wait(6)
	await _shot("prof_del")
	print("찍었다 · 슬롯 %d" % Save.slot())
	for i in range(1, Save.SLOTS + 1):
		Save.erase_slot(i)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.gpath))
	quit(0)
