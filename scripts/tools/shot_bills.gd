extends SceneTree
# 상점 값표가 가려질 때 옮겨 앉는가 — 앞 동전이 뒤 동전의 값 자리를 덮는 배치.
#   godot --path . --quit-after 900 --script scripts/tools/shot_bills.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_bill_g.cfg"
	Save.path = "user://_shot_bill.cfg"
	Save.wipe()
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


#  물건을 자리에 못 박는다. 물리가 밀어내지 않게 게임의 _process 는 끈 채다.
func _pin(spots: Array) -> void:
	for k in spots.size():
		var d: Dictionary = g.drop[k]
		d.u = float(spots[k].x)
		d.w = float(spots[k].y)
		d.h = 0.0
		d.lift = 0.0
		d.into = true
		d.air = false
		d.sleep = true


func _shot(nm: String, spots: Array) -> void:
	for i in 3:
		_pin(spots)
		g._tutor_close()
		g.tutor_out = 0.0
		g.swap_live = false
		g.mouse_at = Vector2(-50.0, -50.0)
		g.tip_a = 0.0
		g.tip_spot = -1
		g.queue_redraw()
		await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)
	var sides := []
	for k in spots.size():
		sides.append(int(g.bill_side.get(k, 0)))
	print("  %s 자리 %s" % [nm, sides])


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g.state = g.S.TITLE
	g._new_run()
	await _wait(30)
	g.gold = 99
	g.leg_no = 3
	g._open_shop()
	await _wait(20)
	g.stock.clear()
	var items: Array = GameData.items()
	for k in 5:
		g.stock.append({"type": "item", "d": items[(k * 7) % items.size()],
				"cost": 3 + k, "sold": false})
	g._drop_roll()
	g._drop_settle()
	await _wait(10)
	g.set_process(false)
	#  맞닿은 동전의 간격은 동전 크기를 따라간다. 38 은 배율 전 지름이라
	#  GOODS_K 로 키운 뒤에는 그대로 두면 두 동전이 서로 파고든 채 찍힌다 —
	#  물리가 절대 안 만드는 배치다.
	var k: float = g.GOODS_K
	#  ① 제보 그대로 — 앞 동전이 뒤 동전의 값 자리를 덮는다
	await _shot("bill_front", [Vector2(260, 30), Vector2(260, 30 + 38 * k),
			Vector2(420, 40), Vector2(520, 90), Vector2(120, 100)])
	#  ② 앞도 위도 막혔다 — 옆으로
	await _shot("bill_crowd", [Vector2(300, 20 + 40 * k), Vector2(300, 20 + 78 * k),
			Vector2(300, 20), Vector2(460, 50), Vector2(150, 70)])
	#  ③ 안 가려지면 그대로 밑
	await _shot("bill_free", [Vector2(140, 40), Vector2(260, 60),
			Vector2(380, 40), Vector2(500, 60), Vector2(320, 120)])
	print("  찍음")
	quit(0)
