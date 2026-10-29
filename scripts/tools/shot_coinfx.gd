extends SceneTree
#  동전 얼굴의 지금 상태(game.gd COINFX) 한 장 — 열(동전) × 행(단계). 보이는 값(_fxs)을 단계마다
#  박아 동전 슬롯 그림 그대로(draw_item_sticker) 찍는다. 필터는 끈다. 게임 파일은 안 고친다
#  (그리기는 poster/coin_sheet_game.gd 가 가른다).
#    godot --path . --script scripts/tools/shot_coinfx.gd -- out=<png 경로> r=18 k=6
#  창이 있어야 돈다.
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
const COIN_SUB := "res://scripts/tools/poster/coin_sheet_game.gd"
#  동전마다 다섯 단계 — 맨 그림 → 가득(윅 존은 불씨 → 금).
const STEPS := {
	"c04": [8.0, 6.0, 4.5, 2.0, 0.0], "c34": [100.0, 75.0, 50.0, 25.0, 0.0],
	"c35": [0.0, 1.0, 3.0, 6.0, 12.0], "c45": [0.0, 15.0, 45.0, 90.0, 180.0],
	"r13": [0.0, 8.0, 24.0, 64.0, 100.0], "c03": [0.0, 1.0, 2.5, 4.0, 6.0],
	"c06": [0.0, 1.0, 3.5, 5.0, 8.0], "c31": [0.0, 1.0, 2.0, 3.5, 5.0],
	"c33": [0.0, 2.0, 4.5, 6.0, 9.0], "u18": [0.0, 5.0, 12.0, 22.0, 30.0],
	"c38": [0.0, 1.0, 2.5, 4.0, 8.0], "c37": [0.0, 3.0, 7.5, 12.0, 24.0],
	"c36": [0.0, 2.0, 4.5, 7.0, 10.0], "c02": [0.0, 1.0, 2.5, 4.0, 8.0],
	"c30": [1.0, 0.5, 0.0, -0.5, -1.0],
}
var A := {"out": "user://coinfx_sheet.png", "r": 18.0, "k": 6, "cell": 40.0}
var g = null
var vp: SubViewport = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_coinfx_g.cfg"
	Save.path = "user://_coinfx.cfg"
	Save.wipe()
	for s in OS.get_cmdline_user_args():
		var kv := String(s).split("=", false, 1)
		if kv.size() == 2 and A.has(kv[0]):
			match typeof(A[kv[0]]):
				TYPE_INT: A[kv[0]] = int(kv[1])
				TYPE_FLOAT: A[kv[0]] = float(kv[1])
				_: A[kv[0]] = String(kv[1])
	var K: int = A.k
	vp = SubViewport.new()
	vp.size = Vector2i(640 * K, 360 * K)
	vp.size_2d_override = Vector2i(640, 360)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load(COIN_SUB))
	vp.add_child(g)


func _process(_d: float) -> bool:
	if busy:
		return false
	busy = true
	_run()
	return false


func _run() -> void:
	for _i in 10:
		await process_frame
	g.set_process(false)
	g.crt = 0.0
	g.warp = 0.0
	g.vhs = 0.0
	g.dot = 0.0
	g._crt_apply()
	var by := {}
	for it in GameData.items():
		by[String(it.id)] = it
	var cell: float = float(A.cell)
	var ids: Array = STEPS.keys()
	var x0: float = (640.0 - float(ids.size()) * cell) * 0.5
	var sheet := []
	for i in ids.size():
		var id: String = ids[i]
		if not by.has(id):
			push_error("없는 동전 " + id)
			continue
		var steps: Array = STEPS[id]
		for j in steps.size():
			var it: Dictionary = (by[id] as Dictionary).duplicate(true)
			it["_fxs"] = float(steps[j])
			sheet.append({"c": Vector2(x0 + (float(i) + 0.5) * cell, 20.0 + (float(j) + 0.5) * cell),
					"r": float(A.r), "it": it})
	g.sheet = sheet
	g.queue_redraw()
	for _i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	img.save_png(String(A.out))
	print("saved ", A.out, " ", img.get_size(), " ", ids)
	quit(0)
