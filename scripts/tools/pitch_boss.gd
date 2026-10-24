extends SceneTree
#  3분 영상 「깊이」 한 토막(2026-10-25 · 2차 레퍼런스 정리 17) — 튜토리얼은 판마다 첫 발에 끝나서 제약 · 사건 ·
#  동전 순서가 영상에 한 번도 안 나온다. 본편 3라운드 보스 판(「닫힌 문」)의 한 발을 찍는다: 꽂혀 있던 라이벌
#  자루를 맞혀 떨어뜨리고 · 그 칸에 참나무 쪽이 박히고 · 동전 넷이 차례로 터지는 정산. 앞 발이 닫은 20 위에
#  쪽 하나가 이미 박혀 있다. 필터 켬 · 설명 글 없이 · 게임은 제 시계로 돈다(사람이 누르는 자리만 누른다).
#    godot --path . --fixed-fps 60 --write-movie <절대경로>/boss_depth.avi --script scripts/tools/pitch_boss.gd
#  1920×1080 으로 찍는다 — 무비 메이커는 --resolution 이 아니라 창 크기 덮개를 따르므로 찍는 동안만 override.cfg 에
#  [display] window/size/window_width_override=1920 · window_height_override=1080 을 둔다(찍고 지운다).
#  실제 게임 그림(boot.tscn · 도트 화판)이다. 무비 메이커는 첫 틀부터 적으므로 판을 세우는 머리는 잘라 낸다 —
#  찍으면 「CUT 초」를 찍어 준다. 판 윗반쪽 와이드는 금고 패와 점수 칠판 · 규칙 명판 사이(동전 슬롯 · 정산 카드 ·
#  판 윗반)를 1:1 로 자른다 — 2026-10-25 에 구운 outputs/발표자료/clips/boss_depth.mp4 가 이 식이다:
#    ffmpeg -ss <CUT − 0.3> -t 6.9 -i boss_depth.avi -vf "crop=1176:662:246:0,scale=in_range=pc:out_range=tv:\
#        in_color_matrix=bt601:out_color_matrix=bt709,format=yuv420p" -c:v libx264 -preset slow -crf 12 \
#        -color_range tv -colorspace bt709 -c:a aac -b:a 256k -movflags +faststart boss_depth.mp4
#  음악은 끈다(영상에는 한 곡을 처음부터 깐다 — 플레이 영상 장면들과 같은 규약). 효과음은 남는다.
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")
const COINS := ["c33", "c01", "r14", "c02"]     # 다 조건 없이 늘 발동 — 슬롯 왼쪽부터 차례로 터진다 · 합이 목표 밑이라 판이 안 끝난다
const ROUND := 3
var b = null
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_pitch_boss_g.cfg"
	Save.path = "user://_pitch_boss.cfg"
	Save.prof_fmt = "user://_pitch_boss_%d.cfg"
	Save.wipe()
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give", "u_boot", "u_gift"]:
		Save.teach(id)
	b = load("res://scenes/boot.tscn").instantiate()
	root.add_child(b)


#  설명창 · 말상자 · 상인 말 · 음악을 내린다 — 틀마다.
func _quiet() -> void:
	if g == null:
		return
	g.tutor_q.clear()
	g.tutor_id = ""
	g.tutor_pre = 0.0
	g.tutor_out = 0.0
	g.tutor_t = 0.0
	g.tip_a = 0.0
	g._tip_clear()
	g.hover_live = false
	g.nsay_wait = -1.0
	g.nsay_row = {}
	var mb := AudioServer.get_bus_index("Music")
	if mb >= 0 and not AudioServer.is_bus_mute(mb):
		AudioServer.set_bus_mute(mb, true)


func _process(_d: float) -> bool:
	if g == null:
		g = b.game
		if g == null:
			return false
	_quiet()
	if busy:
		return false
	busy = true
	_run()
	return false


func _secs(t: float) -> void:
	for i in int(t * 60.0):
		_quiet()
		await process_frame


func _give(ids: Array) -> void:
	for id in ids:
		for it in GameData.items():
			if String(it.get("id", "")) == id:
				Dev._give_item(g, it)
				break
	g._panel_reset()


#  칸 i(sectors 의 자리)의 한가운데 각 · 반지름 rr(px) 의 판 위 점
func _at(i: int, rr: float) -> Vector2:
	var a: float = float(i) * g._sec_w()
	return g.BC + Vector2(sin(a), -cos(a)) * rr


#  기본 조준(두 축) 한 발 — 선이 p 의 3 화소 안을 지날 때 사람처럼 누르고 그 자리로 맞춘다(pitch_video.gd 와 같다).
func _aim_throw(p: Vector2) -> void:
	g.state = g.S.PICK
	g._pick_dart(0)
	g.aim_mode = "std"
	g._aim_begin()
	var f := 0
	while f < 900:
		await _secs(1.0 / 60.0)
		f += 1
		if f > 40 and absf(g.aim.y - p.y) < 3.0:
			break
	g.aim.y = p.y
	g._advance()
	f = 0
	while f < 900:
		await _secs(1.0 / 60.0)
		f += 1
		if f > 24 and absf(g.aim.x - p.x) < 3.0:
			break
	g.aim.x = p.x
	g._advance()


#  정산이 끝나 다음 발로 돌아올 때까지(던진 뒤 날기 · 정산을 지나 고르기 · 조준으로).
func _until_pick(cap := 12.0) -> void:
	var f := 0
	while f < 180 and g.state != g.S.FLY and g.state != g.S.RESOLVE:
		await _secs(1.0 / 60.0)
		f += 1
	f = 0
	while f < int(cap * 60.0) and (g.state == g.S.FLY or g.state == g.S.RESOLVE):
		await _secs(1.0 / 60.0)
		f += 1


func _run() -> void:
	await _secs(0.2)
	g.crt = g.CRT_DEF
	g.warp = g.WARP_DEF
	g.vhs = g.VHS_DEF
	g.dot = g.DOT_DEF
	g._crt_apply()
	GameData.pack = "base"
	Save.set_pick("pack", "base")
	g._new_run()
	g.tut_run = false
	var bn := 0
	for n in range(1, GameData.legs_n() + 1):
		if GameData.round_of(n) == ROUND and GameData.is_boss(n):
			bn = n
	g.boss_mods[bn] = PackedStringArray(["close"])
	g.leg_no = bn
	g._begin_leg()
	g._swap_skip()
	await _secs(1.2)
	var i20: int = g.sectors.find(20)
	var i1: int = g.sectors.find(1)
	#  앞 발 — 20 트리플. 동전을 받기 전이라 작은 값이고 20 이 닫힌다.
	await _aim_throw(_at(i20, g.R * (g.rt_trp_in + g.rt_trp_out) * 0.5))
	await _until_pick()
	_give(COINS)
	#  라이벌 — 1 칸 바깥 싱글 띠의 안쪽 끝에 곧장 꽂는다(던지기 전 말 · 손 없이 — 머리에서 잘린다).
	var pr: Vector2 = _at(i1, g.R * g.rt_trp_out + 2.5)
	g._rgl_open(g._rgl_at(pr), 7)
	g.rgl_p = pr
	g._rgl_in(0.0, 0.0)
	await _secs(1.0)
	print("CUT ", float(Engine.get_frames_drawn()) / 60.0, " 목표 ", g.target, " 점수 ", g.total,
			" 닫힌 칸 ", g.shut_idx, " 라이벌 ", g.rgl_st)
	#  이 발 — 라이벌 자루 곁 트리플(띠 경계 너머 · 반지름 안)에 꽂아 떨어뜨리고 1 칸을 닫는다.
	await _aim_throw(_at(i1, g.R * g.rt_trp_out - 1.5))
	await _until_pick()
	await _secs(0.8)
	print("끝 ", float(Engine.get_frames_drawn()) / 60.0, " 점수 ", g.total, " 닫힌 칸 ", g.shut_idx,
			" 라이벌 ", g.rgl_st, " state ", g.state)
	quit(0)
