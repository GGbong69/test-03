extends SceneTree

const GameData = preload("res://scripts/data.gd")

#  스티커 그림을 눈으로 검산한다. 오토플레이는 "안 죽었다" 만 말한다 —
#  다이컷 폭·마감 셋·말림이 실제로 갈려 보이는지는 화소로만 알 수 있다.
#
#  실행:  godot --path . -s scripts/tools/sticker_shot.gd   (헤드리스 불가)
#
#  찍는 것 넷:
#    stk_rack     랙에 다섯 장 — 매트·유광·홀로 + 금박 테두리
#    stk_peel     막 뗀 스티커(말림 최대)
#    stk_peel2    손에서 정착한 말림
#    stk_collect  컬렉션 격자 — 87장이 한 화면에서 안 뭉개지는가

var g = null
var frames := 0


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


# 등급 셋과 금박이 다 나오게 고른다. 앞에서 다섯 장 집으면 흔함만 나온다.
func _stock_rack() -> void:
	g.owned.clear()
	var want := [
		func(it): return int(it.cost) <= 4 and String(it.get("g", "")) == "",
		func(it): return int(it.cost) <= 4 and String(it.get("g", "")) != "",
		func(it): return int(it.cost) > 4 and int(it.cost) <= 7,
		func(it): return int(it.cost) > 7 and String(it.get("g", "")) == "",
		func(it): return int(it.cost) > 7 and String(it.get("g", "")) != "",
	]
	for f in want:
		for it in GameData.items():
			if f.call(it) and not g.owned.has(it):
				g.owned.append(it)
				break
	g._panel_reset()


func _process(_d: float) -> bool:
	if g == null:
		return true
	g.set_process(false)
	g._process(1.0 / 60.0)
	g.tip_a = 0.0
	g.tip_title = ""
	g.queue_redraw()
	frames += 1

	if frames == 10:
		g.gold = 24
		g._open_shop()
		g._drop_settle()
		_stock_rack()
	if frames == 40:
		_save("stk_rack.png")
	# 손 상태를 직접 박는다. _hand_press/_hand_motion 으로 몰면 그다음 프레임의
	# _hand_update 가 진짜 커서(촬영에는 없다)를 읽어 손이 화면 밖으로 샌다.
	# 여기서 보려는 것은 손의 판정이 아니라 스티커 그림이다 — shop_probe 가
	# 판정을 따로 본다.
	if frames >= 40 and frames <= 48:
		g.hand_st = g.H.CARRY
		g.hand_src = 1
		g.hand_i = 0
		g.hand_m = Vector2(320.0, 150.0)
		g.hand_zone = -1
		g.queue_redraw()
	if frames == 40:
		g.peel_t = 0.0
	if frames == 42:
		_save("stk_peel.png")     # 떼는 순간 (튕김 최대)
		g.peel_t = 0.6            # 0.1초 상수의 여섯 배 — 완전히 정착한 값
	if frames == 45:
		_save("stk_peel2.png")    # 손에서 정착한 말림
		g.hand_st = g.H.NONE
	if frames == 50:
		g.state = g.S.COLLECT
		g.collect_tab = 0
		g.collect_page = 0
	if frames == 70:
		_save("stk_collect.png")
		quit(0)
	return false


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("res://shots/" + name)
	print("저장: %s  %dx%d" % [name, img.get_width(), img.get_height()])
