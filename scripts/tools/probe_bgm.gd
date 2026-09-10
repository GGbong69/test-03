extends SceneTree
# 적응형 BGM 자동 검사를 헤드리스로 돌린다.
#     godot --headless --script scripts/tools/probe_bgm.gd
#     BGM_SOAK_SECONDS=1800 godot --headless --script scripts/tools/probe_bgm.gd
#
# 검사 자체는 tests/audio/music_test.gd 에 있다. 여기는 그것을 띄우고 표를
# 찍기만 한다 — 창으로 열어 듣는 검사와 **같은 코드**를 돌려야 한다.

var t: Node = null
var n := 0
var busy := false

func _process(_d: float) -> bool:
	if busy:
		return false
	n += 1
	if n == 1:
		t = load("res://tests/audio/music_test.tscn").instantiate()
		root.add_child(t)
	elif n == 4:
		busy = true
		_go()
	return false

func _go() -> void:
	var rows: Array = await t.run_all()
	print("")
	print("%-5s %-8s %s" % ["검사", "결과", "근거"])
	print("-".repeat(78))
	var pass_n := 0
	var fail_n := 0
	var skip_n := 0
	for r in rows:
		var mark := ""
		if r.ok == null:
			mark = "not_run"; skip_n += 1
		elif r.ok:
			mark = "pass"; pass_n += 1
		else:
			mark = "FAIL"; fail_n += 1
		print("%-5s %-8s %s" % [r.id, mark, r.why])
	print("-".repeat(78))
	print("pass %d · fail %d · not_run %d" % [pass_n, fail_n, skip_n])
	print("고닷 %s · 플랫폼 %s · 오디오 드라이버 %s"
			% [Engine.get_version_info().string, OS.get_name(), AudioServer.get_driver_name()])
	quit(1 if fail_n > 0 else 0)
