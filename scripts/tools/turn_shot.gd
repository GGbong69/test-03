extends SceneTree

const GameData = preload("res://scripts/data.gd")

#  라운드 경계 촬영. 「에러 없음」은 「보기에 맞다」가 아니다 — 0.56초짜리
#  연출은 여섯 시점을 박제해야 판단이 선다.
#
#    godot --path . --quit-after 900 --script scripts/tools/turn_shot.gd
#
#  보는 것
#    (ㄱ) 큰 줄이 선 카드 윗변(122.68)을 안 덮는가
#    (ㄴ) 스크림 0.62 밑에서 카드 딜 세 장이 보이는가
#    (ㄷ) **불이 한 칸 옮겨 붙은 것이 글자 없이 읽히는가**
#
#  라운드 2 · 4 · 7 에서 넘긴다 — 불이 붙는 칸이 왼쪽 · 한가운데 ·
#  오른쪽 끝일 때 줄이 다 화면 안인지가 눈으로도 갈린다.
#  **8 을 안 쓴다**: 라운드 8 은 런의 끝이라 넘어갈 곳이 없어 안 난다
#  (round_of 가 legs_n 에서 물리므로 r0 와 같다 — 찍어 보고 알았다).
#  _new_run() 을 반드시 부른다. 안 부르면 magazine 이 비어 HUD 가 반만 선다.

var g = null
var busy := false

const SUB := 1.0 / 60.0
#  rise 끝 · hold 끝 · douse 끝(도장) · light 끝 · 집
const AT := [0.0, 0.151, 0.229, 0.347, 0.433, 0.520]
#  모션 끄기 타임라인은 0.190초뿐이라 따로 잰다(douse 0.118 · light 0.073)
const AT_OFF := [0.0, 0.060, 0.118, 0.150, 0.180, 0.188]


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _process(_d: float) -> bool:
	#  한 번으로는 안 붙는다. 매 프레임 눌러 둬야 게임 시계가 우리 손에 있다.
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
	var at: Array = AT_OFF if g.motion_off else AT
	var t := 0.0
	for k in at.size():
		while t < float(at[k]) - 0.0001:
			g._process(SUB)
			t += SUB
		g.tip_a = 0.0
		g.tip_title = ""
		g.queue_redraw()
		await process_frame
		await process_frame
		#  **박자를 수로 남긴다.** 배움 띠가 서 있으면 _tutor_slow() 가 d 를
		#  눌러 타임라인이 늘어나는데, 그림만 보면 그것을 못 잡는다 — 한 번
		#  속았다(같은 두 프레임을 서로 다른 시각으로 찍고 있었다). 2026-09-20
		print("  %s%d  t=%.3f  k=%.3f  live=%s"
				% [tag, k, g.turn_t, g._turn_k(), g.turn_live])
		_save("%s%d.png" % [tag, k])


func _run() -> void:
	_tick(4)
	g._new_run()
	_tick(4)
	var per := GameData.legs_per_round()
	#  라운드 2 · 4 · 7 의 경계를 연다. 마지막 판(보스)에서 넘긴다.
	for r in [2, 4, 7]:
		g._turn_skip()
		g.leg_no = int(r) * per
		g._open_leg()
		#  배움 띠를 내린다. 서 있으면 _tutor_slow() 가 d 를 눌러 AT 의
		#  여섯 시각이 거짓말이 된다 — 그리고 띠 자체가 화면을 가린다.
		g._tutor_close()
		g.tutor_out = 0.0
		_tick(4)
		g._next_leg()
		g._tutor_close()
		g.tutor_out = 0.0
		await _shots("turn%d_" % int(r))
	#  모션 끄기 — 걸음 **수**만 줄고 불은 그대로 옮겨 붙어야 한다. 0.190초.
	#  **큰 줄이 컷으로 서고 한 프레임도 안 움직인다**(k 가 늘 1). 고리만 없다.
	#  한동안 여기서 k 가 0 이었고, 그러면 줄이 5px 이고 스크림도 0 이라 여섯
	#  장이 평소 판 선택 화면과 구별이 안 됐다 — 값만 치르고 읽을 것은 하나도
	#  못 주는 자리였다. 그것이 이 여섯 장으로 잡혔다. 2026-09-20
	g.motion_off = true
	g._turn_skip()
	g.leg_no = 4 * per
	g._open_leg()
	g._tutor_close()
	g.tutor_out = 0.0
	_tick(4)
	g._next_leg()
	g._tutor_close()
	g.tutor_out = 0.0
	await _shots("turnoff_")
	g.motion_off = false
	quit()


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("res://shots/" + name)
	print("저장: ", name)
