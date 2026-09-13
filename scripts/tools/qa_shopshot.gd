extends SceneTree

# 갈래를 자리마다 굴리는 상점을 눈으로 본다.
#   ① 여러 번 굴린 테이블 — 구성이 매번 다른가
#   ② 개발자 모드 「테이블에 사진 깔기」 — 사진이 테이블 위에 서는가
#
#   godot --path . --quit-after 900 --script scripts/tools/qa_shopshot.gd

const GameData = preload("res://scripts/data.gd")

var g = null
var busy := false


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _shot(nm: String) -> void:
	for i in 6:
		g._process(1.0 / 60.0)
	g.queue_redraw()
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png("res://shots/%s.png" % nm)


func _line() -> String:
	var out := PackedStringArray()
	for s in g.stock:
		var nm := String(s.d.get("n", s.d.get("name", "?")))
		out.append("%s %s%s" % [String(s.type), nm,
				" (공짜)" if bool(s.get("free", false)) else ""])
	return " · ".join(out)


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	g.gold = 99
	g.leg_no = 4
	g._open_shop()
	print("\n상점 다섯 번 — 매번 구성이 다르다\n")
	for i in 5:
		g._roll_stock()
		g._drop_settle()
		print("  %d. %s" % [i + 1, _line()])
		await _shot("shop_roll%d" % (i + 1))

	# 등급마다 하나씩 깔아 번짐을 눈으로 본다. 일반은 안 빛나는 것이 규약이다.
	print("\n등급 번짐 — 네 등급을 한 테이블에\n")
	g.owned = []
	var pick := {}
	for it in GameData.items():
		var rr := String(it.get("rarity", "common"))
		if not pick.has(rr):
			pick[rr] = it
	g.stock.clear()
	for rr in ["common", "uncommon", "rare", "legendary"]:
		if pick.has(rr):
			g.stock.append({"type": "item", "d": pick[rr],
					"cost": 4, "sold": false})
	g._drop_roll()
	g._drop_settle()
	print("  %s" % _line())
	await _shot("shop_glow")

	print("\n개발자 모드 — 테이블에 사진 깔기\n")
	var Dev = load("res://scripts/dev.gd")
	Dev._run(g, {"t": "act", "a": "restock_fix"})
	g._drop_settle()
	print("  %s" % _line())
	await _shot("shop_fix")
	print("\n스크린샷: user://shot_shop_roll1..5.png · user://shot_shop_fix.png\n")
	quit(0)
