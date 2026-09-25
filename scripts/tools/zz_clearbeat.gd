extends SceneTree

#  판 끝의 박자를 프레임으로 잰다 — 돌파 걸음 · leg_clear · 정산 줄 · 총액 굴림.
#  판 깨짐 연출을 어디에 끼울지 조사하려고 하루 쓰는 자다(2026-09-24).
#
#   godot --headless --path . --script scripts/tools/zz_clearbeat.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var log_rows := []
var snd := []          # [프레임, 이름]
var last_next := 0


func _initialize() -> void:
	Save.path = "user://_zz_clearbeat.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return true
	busy = true
	_run()
	return true


func _snd_poll(fr: int) -> void:
	var pool: Array = g.sfx_pool
	if pool.is_empty():
		return
	var n: int = g.sfx_next
	while last_next != n:
		var i: int = (last_next) % pool.size()
		var st = pool[i].stream
		var nm := "?" if st == null else String(st.resource_path).get_file().get_basename()
		snd.append([fr, nm])
		last_next = (last_next + 1) % pool.size()


func _step(fr: int) -> void:
	g._process(1.0 / 60.0)
	_snd_poll(fr)


func _enter() -> void:
	g.state = g.S.TITLE
	g._new_run()
	g._click(g._leg_go().get_center())
	for k in 60:
		g._process(1.0 / 60.0)
	last_next = g.sfx_next
	snd.clear()


func _run() -> void:
	for i in 20:
		g._process(1.0 / 60.0)
	print("\n판 끝 박자 — 프레임으로")
	print("  beat %.3f · MO.fast %d프레임(%.4f초) · SWAP.dur %.2f"
			% [g.beat, int(g.MO.fast), g._mo("fast"), float(g.SWAP.dur)])
	print("  판 수 %d(라운드 %d × %d) · 무한 %d"
			% [GameData.legs_n(), GameData.rounds_n(), GameData.legs_per_round(),
			GameData.endless_legs_n()])

	_once(false)          # 몸풀기 — 배움 말상자가 첫 런에서만 시간을 늦춘다
	_once(false)
	_once(true)
	_once(false, true)    # 빨리 보기를 누른 채 — 창이 얼마나 줄어드는가
	_rows_table()
	_turn_check()
	quit()


func _once(mo: bool, fast := false) -> void:
	_enter()
	g.motion_off = mo
	g.fast_lock = fast
	g.target = 1
	g.state = g.S.CONFIRM
	g.confirm_t = 99.0
	g.aim = g.BC
	var f_break := -1
	var f_clear := -1
	var f_row1 := -1
	var f_allin := -1
	var f_done := -1
	var max_shake := 0.0
	var max_flash := 0.0
	var hs := 0
	var slow := 1.0
	for k in 900:
		_step(k)
		if g.hitstop > 0.0:
			hs += 1
		if f_break < 0 and g.total >= g.target:
			f_break = k
			slow = g._tutor_slow()
		if f_break >= 0 and f_clear < 0:
			max_shake = maxf(max_shake, g.shake)
			max_flash = maxf(max_flash, g.screen_flash)
			if not mo:
				log_rows.append([k - f_break, g.shake, g.screen_flash,
						g.board_punch, (g.pops as Array).size(), g.card_burst,
						g.hitstop > 0.0])
		if f_clear < 0 and g.state == g.S.CLEAR:
			f_clear = k
			continue
		if f_clear >= 0:
			var step: float = g._mo("fast")
			var n: int = (g.clear_gold_detail as Array).size()
			if f_row1 < 0 and (step <= 0.0 or g.clear_t > 0.0):
				f_row1 = k
			if f_allin < 0 and (step <= 0.0 or g.clear_t >= float(n) * step):
				f_allin = k
			if f_done < 0 and g._clear_done():
				f_done = k
				break
	print("\n  ── 모션 %s · 빨리보기 %s ──"
			% ["끔" if mo else "켬", "누름" if fast else "안 누름"])
	print("    판에 꽂힌 다트 %d개 · 칸 %d · 보드 옷 '%s' · 남은 다트 %d"
			% [(g.darts as Array).size(), g._sec_n(), g._board_theme(), g.darts_left])
	print("    돌파 프레임 %d · 정산 열림 %d · 사이 %d프레임(%.3f초)"
			% [f_break, f_clear, f_clear - f_break, float(f_clear - f_break) / 60.0])
	print("    돌파~정산 사이 최대 흔들림 %.1f · 최대 섬광 %.2f · 멈춤 %d프레임 · 배움늦춤 %.2f"
			% [max_shake, max_flash, hs, slow])
	print("    첫 줄 보임 +%d · 줄 다 듦 +%d · 굴림 끝 +%d (정산 열린 프레임 기준)"
			% [f_row1 - f_clear, f_allin - f_clear, f_done - f_clear])
	print("    내역 줄 수 %d · 총액 %d" % [(g.clear_gold_detail as Array).size(), g.gold])
	print("    소리(프레임: 이름) — 돌파 앞뒤")
	for s in snd:
		if int(s[0]) >= f_break - 4:
			print("      %4d  %s" % [int(s[0]), String(s[1])])
	if not log_rows.is_empty():
		print("    돌파~정산 한 프레임씩 — 흔들림 · 섬광 · 판움찔 · 팝업 · 카드터짐 · 멈춤")
		for r in log_rows:
			print("      +%2d  %5.2f  %4.2f  %4.2f  %d  %4.2f  %s"
					% [int(r[0]), float(r[1]), float(r[2]), float(r[3]),
					int(r[4]), float(r[5]), "멈춤" if bool(r[6]) else ""])
		log_rows.clear()


func _rows_table() -> void:
	print("\n  ── 정산 길이 — 줄 수와 총액별(초) ──")
	var step := 7.0 / 60.0
	for n in [3, 4, 5, 6, 7, 9]:
		var line := "    %d줄  줄다듦 %.3f" % [n, float(n) * step]
		for gd in [20, 200, 2000]:
			var span: float = clampf(0.25 + 0.12 * log(float(gd)) / log(10.0), 0.25, 0.8)
			line += "  |  %d골드 끝 %.3f" % [gd, float(n) * step + span]
		print(line)


func _turn_check() -> void:
	print("\n  ── 판 갈이 · 라운드 넘김이 정산과 겹치는가 ──")
	print("    S.CLEAR 에서 swap_live %s · turn_live %s"
			% [str(g.swap_live), str(g.turn_live)])
	#  정산에서 누르면 무엇이 도는가
	g.clear_t = 99.0
	g._click(Vector2(320, 340))
	print("    누른 뒤: state %d · swap_live %s · turn_live %s · swap_t %.3f"
			% [g.state, str(g.swap_live), str(g.turn_live), g.swap_t])
	var fr := 0
	while (g.swap_live or g.turn_live) and fr < 200:
		g._process(1.0 / 60.0)
		fr += 1
	print("    판 갈이가 끝나기까지 %d프레임(%.3f초)" % [fr, float(fr) / 60.0])
