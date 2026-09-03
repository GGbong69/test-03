extends SceneTree

#  썸네일 소재 촬영
#
#  shot.gd 는 640×360 그대로 뜬다. 유튜브 썸네일은 1280×720 이 최소라
#  그 그림을 늘리면 뭉갠 티가 난다. 이 게임의 화면은 전부 draw_* 로 그은
#  벡터라 노드 배율만 올리면 그 배율의 실해상도로 다시 그려진다 —
#  늘리는 게 아니라 크게 그리는 것이다.
#
#  배율마다 화면에서 보이는 범위가 좁아지므로, 어디를 가운데에 둘지도
#  같이 준다. 창에 대고 그리면 창 크기에 잘리므로 서브뷰포트에 그린다.
#
#  헤드리스로는 못 돈다 — 뷰포트를 실제로 그려야 화소가 나온다.
#
#  실행:  godot --path . -s scripts/tools/thumb.gd
#  결과:  shots/tb_*.png  (합치는 것은 tools/thumb_build.py)

const OUT := Vector2i(1920, 1080)

var vp: SubViewport = null
var g = null
var frames := 0
var mode := 0        # 0 판 · 1 상인


func _initialize() -> void:
	vp = SubViewport.new()
	vp.size = OUT
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	g = load("res://scenes/main.tscn").instantiate()
	vp.add_child(g)
	# 게임 시계를 우리가 돈다 (shot.gd 와 같은 이유).
	g.set_process(false)


func _process(_d: float) -> bool:
	if g == null:
		return true
	g.set_process(false)
	g._process(1.0 / 60.0)
	g.tip_a = 0.0
	g.tip_title = ""
	if mode == 0:
		_hold_board()
	g.queue_redraw()

	frames += 1

	if frames == 6:
		g._new_run()
		g._start_leg()

	# ── 판. 3배면 판 지름이 700px 가 되어 1280×720 한 장을 채운다.
	if frames == 20:
		_look(3.0, g.BC)
	if frames == 24:
		_save("tb_board.png")
		mode = 1
		g.gold = 24
		g._open_shop()
		g._drop_settle()

	# ── 상인와 펠트. 상점 화면 전체가 한 장에 들어오는 배율이다.
	if frames == 70:
		_look(3.0, Vector2(320.0, 180.0))
	if frames == 74:
		_save("tb_felt.png")
		g._tip_clear()
		g._sweep_begin()

	# 쓸기 중반 — 팔이 테이블 위로 뻗은 자세.
	if frames > 74 and frames < 96:
		var sub: float = g.DROP.sub
		g.sweep_t += sub
		g.sweep_on = g.sweep_t >= g.SWEEP.reach \
				and g.sweep_t < g.SWEEP.reach + g.SWEEP.rake
		g.drop_t += sub
		g._drop_step(sub)

	if frames == 96:
		_save("tb_sweep.png")
		quit()

	return false


#  게임 화면의 fc 지점이 뷰포트 한가운데 오도록 배율과 위치를 잡는다.
func _look(sc: float, fc: Vector2) -> void:
	g.scale = Vector2(sc, sc)
	g.position = Vector2(OUT) * 0.5 - fc * sc


#  판 화면을 원하는 순간에 고정한다. _process 가 매 프레임 깎으므로
#  값은 그릴 때마다 다시 눌러 준다.
func _hold_board() -> void:
	g.state = g.S.FLY          # 힌트 줄도 조준선도 안 뜨는 유일한 놀이 상태
	g.fly_t = 0.2
	g.aim = Vector2(-999.0, -999.0)
	g.shake = 0.0
	g.screen_flash = 0.0
	g.board_punch = 0.6

	# 불에 한 발, 트리플 20 에 두 발. 작은 그림에서 읽히는 건 가운데다.
	var id := "std"
	g.darts = [
		{"p": g.BC + Vector2(-2.0, 1.0), "id": id, "rot": -0.15},
		{"p": g.BC + _polar(-0.09, 0.61), "id": id, "rot": 0.22},
		{"p": g.BC + _polar(0.11, 0.63), "id": id, "rot": -0.30},
	]

	# 흰 섬광도 고리도 안 쓴다 — 한 번 켜 보니 불이 분홍 얼룩으로 떴다.
	# 빛은 합성 쪽(파이썬)에서 준다. 거기서는 세기를 눈으로 맞출 수 있다.
	g.hit_flash = 0.0
	g.hit_bull = false
	g.hit_idx = -1
	g.ring_fx = []

	# 왼쪽 벽에 꽂히는 탄창 다트는 판 초반에 오른쪽에서 날아온다. 그
	# 도중을 찍으면 판 옆 허공에 자루가 하나 떠 있다 (한 번 그렇게 나왔다).
	# 배열을 비우면 다른 데가 터진다 — 시계만 끝까지 감아 다 꽂아 둔다.
	g.grip_t = 999.0

	# 정산 카드가 오른쪽 아래에 걸린다. 썸네일에는 안 쓴다.
	g.card_p = 0.0
	g.card_target = 0.0


func _polar(a: float, k: float) -> Vector2:
	return Vector2(sin(a), -cos(a)) * g.R * k


func _save(name: String) -> void:
	var img := vp.get_texture().get_image()
	img.save_png("res://shots/" + name)
	print("저장: ", name, "  ", img.get_width(), "x", img.get_height())
