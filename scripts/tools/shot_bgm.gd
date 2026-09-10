extends SceneTree
# 시험대 화면을 png 로 뽑는다. 헤드리스로는 못 돈다 — 화소가 나와야 한다.
#     godot --path . -s scripts/tools/shot_bgm.gd
var t = null
var n := 0
func _process(_d: float) -> bool:
	n += 1
	if n == 1:
		t = load("res://tests/audio/music_test.tscn").instantiate()
		root.add_child(t)
	elif n == 20:
		t.mm.set_state(&"Shop", 1.0)     # 전환 한복판을 잡는다
	elif n == 44:
		var img := root.get_texture().get_image()
		img.save_png("res://shots/scr_bgm_test.png")
		print("저장: shots/scr_bgm_test.png")
		return true
	return false
