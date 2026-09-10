extends SceneTree
# 화면마다 어느 곡을 원하는가 · 갈릴 때 겹쳐 넘어가는가.
#     godot --headless --script scripts/tools/probe_music.gd
#
# _ready 는 첫 프레임에 돈다 — 소리 자리(mus_pl)가 그때 선다. 그래서
# shot_*.gd 와 같이 몇 프레임 기다린 뒤에 본다.

var g = null
var n := 0
var busy := false

func _process(_d: float) -> bool:
	if busy:
		return false
	n += 1
	if n == 1:
		g = load("res://scenes/main.tscn").instantiate()
		root.add_child(g)
	elif n == 6:
		busy = true
		_go()
	return false

func _go() -> void:
	var gd = load("res://scripts/data.gd")
	g._new_run()
	print("자리 %s 개 (겹치지 않으므로 하나면 된다)"
			% ("0" if g.mus_pl == null else "1"))

	print("- 화면별 곡 -")
	var cases := [
		[g.S.TITLE, -1, 1, "타이틀"],
		[g.S.COLLECT, -1, 1, "컬렉션"],
		[g.S.STAGE, -1, 1, "판 선택"],
		[g.S.SHOP, -1, 1, "상점"],
		[g.S.CLEAR, -1, 1, "정산"],
		[g.S.PICK, -1, 1, "판 위"],
	]
	for c in cases:
		g.state = c[0]
		g.pause_from = c[1]
		g.leg_no = c[2]
		print("  %-10s -> %s" % [c[3], g._mus_want()])
	for k in range(1, gd.legs_n() + 1):
		if gd.is_boss(k):
			g.state = g.S.PICK
			g.leg_no = k
			print("  %-10s -> %s (판 %d)" % ["보스 판 위", g._mus_want(), k])
			break

	print("- 덮개는 뒤를 따르는가 -")
	g.state = g.S.SHOP
	g.leg_no = 1
	g.run_from = g.S.SHOP
	g.state = g.S.RUNINFO
	print("  런 정보 -> %s %s" % [g._mus_want(), "ok" if g._mus_want() == "select" else "실패"])
	g.state = g.S.SETTINGS
	g.pause_from = g.S.PICK
	print("  판 위 일시정지 -> %s %s" % [g._mus_want(), "ok" if g._mus_want() == "game" else "실패"])

	# ── 보스 속도 ─────────────────────────────────
	# 라운드마다 보스가 얼마나 급한가. 값이 아니라 **차이**가 요점이라
	# 라운드 1과 마지막의 간격을 같이 적는다.
	print("- 보스 속도 -")
	g.state = g.S.PICK
	var lo := 0.0
	var hi := 0.0
	for k in range(1, gd.legs_n() + 1):
		if not gd.is_boss(k):
			continue
		g.leg_no = k
		var pv: float = g._mus_pitch_want()
		if lo == 0.0:
			lo = pv
		hi = pv
		print("  라운드 %d 보스 -> x%.4f" % [gd.round_of(k), pv])
	g.leg_no = 1
	print("  판 위(보스 아님) -> x%.4f" % g._mus_pitch_want())
	g.state = g.S.TITLE
	print("  로비 -> x%.4f" % g._mus_pitch_want())
	print("  처음과 끝 차이: %.1f%% (반음 %.2f)"
			% [(hi / lo - 1.0) * 100.0, 12.0 * log(hi / lo) / log(2.0)])

	# 속도가 툭 안 바뀌고 걸어가는가. 보스에 들어선 뒤 몇 초에 다 오르나.
	print("- 속도가 걸어가는가 -")
	g.state = g.S.PICK
	g.leg_no = 1
	g.mus_pitch = 1.0
	for k in range(1, gd.legs_n() + 1):
		if gd.is_boss(k):
			g.leg_no = k
			break
	var t := 0.0
	var tgt: float = g._mus_pitch_want()
	while g.mus_pitch < tgt - 0.0005 and t < 10.0:
		g._mus_update(0.016)
		t += 0.016
		if is_equal_approx(t, 0.48) or is_equal_approx(t, 0.96):
			print("  %.2f초: x%.4f" % [t, g.mus_pitch])
	print("  다 오르기까지 %.2f초 (넘김은 %.2f초) · 자리 x%.4f"
			% [t, g.MUS_FADE, g.mus_pl.pitch_scale])

	# ── 적응형 관리자 연결 ────────────────────────
	# MUS_ADAPTIVE 는 const 라 런타임에 못 뒤집는다. 대신 연결부를 직접
	# 불러 본다 — 켰을 때 실제로 도는 길이 이 함수 하나뿐이라 이걸 재면
	# 스위치를 켠 것과 같은 것을 잰 셈이 된다.
	print("- 적응형 연결 -")
	var Adapter = load("res://audio/music/music_state_adapter.gd")
	var mm = g.get_node_or_null("/root/MusicManager")
	if mm == null:
		print("  MusicManager Autoload 이 없다")
	else:
		print("  준비 %s · 버스 소유 %s" % [mm.ready_ok, mm.owns_bus])
		var boss_leg := 1
		for k in range(1, gd.legs_n() + 1):
			if gd.is_boss(k):
				boss_leg = k
				break
		var norm_leg := 1
		for k in range(1, gd.legs_n() + 1):
			if not gd.is_boss(k):
				norm_leg = k
				break
		var acases := [
			[g.S.TITLE, norm_leg, &"Main", "타이틀"],
			[g.S.SHOP, norm_leg, &"Shop", "상점"],
			[g.S.AIM_V, norm_leg, &"Aim", "조준(보통 판)"],
			[g.S.AIM_H, boss_leg, &"Final", "조준(보스) — Final 이 이긴다"],
			[g.S.PICK, boss_leg, &"Final", "보스 판 위"],
			[g.S.PICK, norm_leg, &"Main", "보통 판 위"],
			[g.S.FLY, norm_leg, &"Main", "날아가는 중은 조준이 아니다"],
			[g.S.SHOP, boss_leg, &"Shop", "보스 중 상점 — 상점이 이긴다"],
		]
		var bad := 0
		g.pause_from = -1
		for c in acases:
			g.state = c[0]
			g.leg_no = c[1]
			var got = Adapter.from_game(g)
			var ok: bool = (got == c[2])
			if not ok:
				bad += 1
			print("  %-26s -> %-6s %s" % [c[3], got, "ok" if ok else "실패(기대 %s)" % c[2]])
		# 상점을 닫으면 보스로 돌아가는가 — 무조건 Main 이면 여기서 걸린다
		g.state = g.S.PICK
		g.leg_no = boss_leg
		print("  %-26s -> %-6s %s" % ["상점을 닫은 뒤", Adapter.from_game(g),
				"ok" if Adapter.from_game(g) == &"Final" else "실패"])
		# 연결부를 실제로 불러 본다
		var before = mm.start_count
		g._mus_adaptive()
		g._mus_adaptive()
		print("  _mus_adaptive 2회 -> 요청 %s · start %d회(늘어난 값 %d)"
				% [mm.requested_state, mm.start_count, mm.start_count - before])
		print("  틀린 자리 %d 개" % bad)

	# ── 나갔다 들어오기 ───────────────────────────
	# 겹쳐 넘기던 것을 순차로 바꿨다. 그러면 **겹치지 않는다**는 것이 이
	# 방식의 전부이므로, 여기서 재는 것도 그거 하나다 — 넘기는 내내
	# 소리가 나는 곡이 언제나 하나 이하인가.
	print("- 나갔다 들어오기 -")
	g.pause_from = -1
	g.state = g.S.TITLE
	g._mus_update(0.016)
	print("  타이틀: key=%s 재생=%s 크기 %.2f"
			% [g.mus_key, g.mus_pl.playing, g.mus_vol])
	# 타이틀 곡이 다 들어올 때까지 둔다
	for k in 200:
		g._mus_update(0.016)
	print("  다 들어온 뒤: key=%s 단계=%s 크기 %.2f"
			% [g.mus_key, _ph(g), g.mus_vol])

	var from_key := String(g.mus_key)
	g.state = g.S.SHOP
	var steps := []
	var quiet := 0.0
	var heard := {}
	var t2 := 0.0
	for k in 140:
		g._mus_update(0.016)
		t2 += 0.016
		if g.mus_vol > 0.001 and g.mus_pl.playing:
			heard[String(g.mus_key)] = true
		else:
			quiet += 0.016
		steps.append([t2, String(g.mus_key), g.mus_vol, _ph(g)])
		if g.mus_ph == g.MP.REST and t2 > 0.1:
			break
	print("  %s -> %s : %.2f초 걸렸다 (예상 %.2f)" % [from_key, g.mus_key, t2, g.MUS_FADE])
	print("  숨(아무 소리도 안 나는 동안) %.2f초 (예상 %.2f 안팎)" % [quiet, g.MUS_GAP])
	# 겹치지 않는다는 것은 **재는 것이 아니라 구조다** — 자리가 하나라
	# 두 곡이 같이 울리는 일이 일어날 수 없다. 그래서 여기서 세는 것은
	# "겹쳤는가"가 아니라 "차례로 지나갔는가"다.
	print("  차례로 지난 곡 %d개 %s · 자리는 하나라 겹칠 수가 없다"
			% [heard.size(), heard.keys()])
	# 자취를 몇 점만 찍는다
	for at in [0.0, 0.3, 0.56, 0.66, 1.0, 1.4]:
		for row in steps:
			if row[0] >= at:
				print("    %.2f초  %-7s 크기 %.2f  %s" % [row[0], row[1], row[2], row[3]])
				break

	# ── 되돌아오기 ────────────────────────────────
	# 나가던 도중에 원래 화면으로 돌아오면 **다시 틀지 않고** 도로 올라와야
	# 한다. 다시 틀면 잠깐 열었다 닫은 창 하나에 곡이 처음으로 돌아간다.
	print("- 나가다 되돌아오기 -")
	var pos_before: float = g.mus_pl.get_playback_position()
	var key_before := String(g.mus_key)
	g.state = g.S.TITLE                       # lobby 로 나가기 시작
	for k in 15:
		g._mus_update(0.016)
	print("  0.24초 나갔다: key=%s 크기 %.2f 단계=%s"
			% [g.mus_key, g.mus_vol, _ph(g)])
	g.state = g.S.SHOP                        # 도로 select
	g._mus_update(0.016)
	print("  되돌아온 직후: key=%s 단계=%s %s"
			% [g.mus_key, _ph(g),
			"ok — 안 끊겼다" if g.mus_key == key_before else "곡이 바뀌었다"])
	for k in 60:
		g._mus_update(0.016)
	# 재생 위치는 헤드리스(Dummy 드라이버)에서 안 움직인다. 곡이 안 끊겼다는
	# 증거는 위의 key 가 그대로라는 것이고, 이 줄은 참고값이다.
	print("  1초 뒤: 크기 %.2f · 재생 위치 %.2f초(되돌기 전 %.2f, 헤드리스라 참고만)"
			% [g.mus_vol, g.mus_pl.get_playback_position(), pos_before])
	quit()


# 단계를 사람 말로.
func _ph(g) -> String:
	match g.mus_ph:
		g.MP.REST: return "쉼"
		g.MP.OUT: return "나감"
		g.MP.GAP: return "숨"
		g.MP.IN: return "들어옴"
	return "?"
