extends SceneTree

const GameData = preload("res://scripts/data.gd")

# 판 갈이 촬영. "에러 없음" 은 "보기에 맞다" 가 아니다 — 0.30초짜리
# 연출은 여섯 시점을 박제해야 판단이 선다.
#
#   godot --path . --quit-after 900 --script scripts/tools/swap_shot.gd
#
# _new_run() 을 반드시 부른다. 안 부르면 magazine 이 비어(선언 초기값 [])
# 탄창 벽에 자루가 한 개도 안 꽂히고, 벽이 들어오는 그림을 못 찍는다.

var g = null
var busy := false

const SUB := 1.0 / 60.0
const AT := [0.0, 0.04, 0.09, 0.15, 0.22, 0.30]


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _process(_d: float) -> bool:
	# 한 번으로는 안 붙는다. 매 프레임 눌러 둬야 게임 시계가 우리 손에 있다
	# (안 누르면 대기하는 사이 엔진이 같이 감아 타임라인이 두 배로 간다).
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	return false


func _tick(n: int) -> void:
	for i in n:
		g._process(SUB)


func _shots(tag: String) -> void:
	var t := 0.0
	for k in AT.size():
		while t < float(AT[k]) - 0.0001:
			g._process(SUB)
			t += SUB
		g.tip_a = 0.0
		g.tip_title = ""
		g.queue_redraw()
		await process_frame
		await process_frame
		_save("%s%d.png" % [tag, k])


func _run() -> void:
	_tick(4)
	g._new_run()
	g.blind_t = 9.0
	_tick(4)

	# ① 테이블 → 판
	g._click(g._blind_go().get_center())
	await _shots("swapo")

	# ② 판 → 테이블. 정산을 거치지 않고 같은 통로만 연다.
	_tick(4)
	g.state = g.S.CLEAR
	g._open_shop()
	g._swap_begin(false)
	await _shots("swapb")

	# ③ 보스 판의 제약 화면 → 판. 카드 얼굴이 제 눕힘 행렬을 거는데
	#    그것이 전환 오프셋 **안**에서 돈다 — 카드가 draw_set_transform(shake_off)
	#    로 복귀하므로 오프셋을 shake_off 자체에 실은 판단이 여기서 증명된다.
	#    복귀가 어긋나면 카드가 제자리에 남고 테이블만 빠진다.
	_tick(4)
	g.round_no = GameData.blinds_per_ante()
	g._open_stage()
	g.stage_t = 9.0
	_tick(4)
	g._click(g._stage_rect(1).get_center())
	await _shots("swaps")
	quit()


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("res://shots/" + name)
	print("저장: ", name)
