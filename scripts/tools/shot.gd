extends SceneTree

# 화면을 png 로 뽑는다. "에러 없음" 은 "보기에 맞다" 가 아니다 —
# 오토플레이가 통과한 프레임이 실제로 어떻게 보이는지는 눈으로만 알 수 있다.
# 헤드리스로는 못 돈다 — 렌더러가 있어야 뷰포트가 그려진다.
#
# 쓸기는 시간이 있는 연출이라 한 장으로는 판단이 안 된다. 게임의 _process 를
# 끄고 물리를 손으로 감아 여섯 시점을 박제한다. 안 끄면 await 하는 동안
# 게임 시계가 같이 흘러 타임라인이 두 배로 간다 (한 번 당했다).

var g = null
var frames := 0
var busy := false

# 쓸기 타임라인의 여섯 지점(초). reach 0.16 · rake 0.52 · back 0.30
const SWEEP_AT := [0.10, 0.26, 0.42, 0.56, 0.68, 0.86]


func _initialize() -> void:
	var scn: PackedScene = load("res://scenes/main.tscn")
	g = scn.instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if busy:
		return false
	frames += 1
	if frames == 10:
		# 상점으로 보낸다. 낙하를 즉시 감아 정착 상태를 찍는다.
		g.gold = 24
		g._open_shop()
		g._drop_settle()
	if frames == 50:
		_save("shot_shop.png")
	if frames == 55:
		g._open_stage()
	if frames == 110:
		_save("shot_stage.png")
		busy = true
		_sweep_shots()
	return false


# 물리를 실제로 감아 각 시점의 화면을 만든다. 팔이 민 결과가 그림에
# 반영돼야 하므로 sweep_t 만 옮기고 그리는 것으로는 부족하다.
func _sweep_shots() -> void:
	g.set_process(false)
	g.state = g.S.SHOP
	g.gold = 24
	g._open_shop()
	g._drop_settle()
	g._sweep_begin()
	var sub: float = g.DROP.sub
	var t := 0.0
	for k in SWEEP_AT.size():
		while t < float(SWEEP_AT[k]):
			t += sub
			g.sweep_t += sub
			g.sweep_on = g.sweep_t >= g.SWEEP.reach \
					and g.sweep_t < g.SWEEP.reach + g.SWEEP.rake
			if not g.sweep_dealt and g.sweep_t >= g.SWEEP.reach + g.SWEEP.rake:
				g.sweep_dealt = true
				g._sweep_deal()
			if g.sweep_t >= g.SWEEP.reach + g.SWEEP.rake + g.SWEEP.back:
				g.sweep_live = false
				g.sweep_on = false
			g.drop_t += sub
			g._drop_step(sub)
			g._waste_update(sub)
		g.queue_redraw()
		await process_frame
		await process_frame
		_save("shot_sweep%d.png" % k)
	quit()


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("res://" + name)
	print("저장: ", name, "  ", img.get_width(), "x", img.get_height())
