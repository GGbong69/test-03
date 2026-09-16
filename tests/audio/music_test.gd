extends Control
# ══════════════════════════════════════════════════════════
#  적응형 BGM 시험대
# ──────────────────────────────────────────────────────────
#  두 가지로 쓴다.
#    창으로 열면   네 상태를 눌러 보고 진단을 눈으로 본다(듣는 검사)
#    헤드리스로    run_all() 이 T01~T11·T14 를 스스로 돌고 표를 낸다
#
#  게임 코드에 시험용 단추를 박지 않으려고 여기 따로 둔다 — 명세의 지침이고,
#  실제로도 이 화면은 게임의 640x360 규격을 안 따른다.
# ══════════════════════════════════════════════════════════

const Adapter = preload("res://audio/music/music_state_adapter.gd")

var mm: Node = null
var log_lines: PackedStringArray = []
var diag: Label = null
var settled_seen: Array[StringName] = []
var requested_seen: Array[StringName] = []
var errors_seen: Array = []


func _ready() -> void:
	mm = get_node_or_null("/root/MusicManager")
	if mm == null:
		push_error("MusicManager Autoload 이 없다")
		return
	mm.state_settled.connect(func(s): settled_seen.append(s))
	mm.state_requested.connect(func(s): requested_seen.append(s))
	mm.music_error.connect(func(c, m): errors_seen.append([c, m]))
	if DisplayServer.get_name() != "headless":
		_build_ui()


# ══════════════════════════════════════════════════════════
#  듣는 검사용 화면
# ══════════════════════════════════════════════════════════

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 6)
	add_child(v)

	var t := Label.new()
	t.text = "적응형 BGM 시험대 — 상태를 눌러도 타임라인은 안 끊긴다"
	v.add_child(t)

	var row := HBoxContainer.new()
	v.add_child(row)
	for s in ["Main", "Shop", "Aim", "Final"]:
		var b := Button.new()
		b.text = s
		b.pressed.connect(func(): mm.set_state(StringName(s)))
		row.add_child(b)

	var row2 := HBoxContainer.new()
	v.add_child(row2)
	for spec in [["start", func(): mm.start()],
			["stop", func(): mm.stop_music()],
			["pause", func(): mm.set_music_paused(true)],
			["resume", func(): mm.set_music_paused(false)],
			["즉시 Shop(0초)", func(): mm.set_state(&"Shop", 0.0)],
			["빠른 왕복", func(): _quick_cycle()]]:
		var b := Button.new()
		b.text = String(spec[0])
		b.pressed.connect(spec[1])
		row2.add_child(b)

	var row3 := HBoxContainer.new()
	v.add_child(row3)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.01
	sl.value = 1.0
	sl.custom_minimum_size = Vector2(200, 0)
	sl.value_changed.connect(func(x):
		mm.set_bus_ownership(true)
		mm.set_music_volume_linear(x))
	row3.add_child(sl)
	var mb := CheckBox.new()
	mb.text = "음소거"
	mb.toggled.connect(func(on):
		mm.set_bus_ownership(true)
		mm.set_music_muted(on))
	row3.add_child(mb)

	diag = Label.new()
	diag.add_theme_font_size_override("font_size", 13)
	v.add_child(diag)
	mm.start()


func _quick_cycle() -> void:
	# 전환 도중 재전환을 손으로 들어 보는 자리. 0.3초 · 0.2초는 명세 T04 가
	# 고른 간격이다.
	mm.set_state(&"Shop")
	await get_tree().create_timer(0.3).timeout
	mm.set_state(&"Aim")
	await get_tree().create_timer(0.2).timeout
	mm.set_state(&"Final")


func _process(_d: float) -> void:
	if diag == null or mm == null:
		return
	var s: Dictionary = mm.get_debug_snapshot()
	var g: Array = s.gains
	var db: Array = s.applied_stream_db
	var txt := "요청 %s → 안착 %s · 페이드 %s %.0f%%\n" % [
			s.requested_state, s.settled_state,
			"도는 중" if s.fade_active else "쉼", s.fade_progress * 100.0]
	for i in 4:
		txt += "  %-6s 게인 %.4f  적용 %6.1f dB\n" % [
				mm.STATE_ORDER[i], g[i], db[i] if i < db.size() else 0.0]
	txt += "게인 합 %.6f · 재생 위치 %.2f초 · 볼륨 %.2f%s · start %d" % [
			_sum(g), s.playback_position_seconds, s.user_volume_linear,
			" (음소거)" if s.effective_mute else "", s.start_count]
	diag.text = txt


func _sum(a: Array) -> float:
	var t := 0.0
	for x in a:
		t += float(x)
	return t


# ══════════════════════════════════════════════════════════
#  자동 검사
# ══════════════════════════════════════════════════════════

var results := []


func _note(id: String, ok: bool, why: String) -> void:
	results.append({"id": id, "ok": ok, "why": why})


func _skip(id: String, why: String) -> void:
	results.append({"id": id, "ok": null, "why": why})


# 실제 시간으로 sec 초를 기다린다. 페이드가 Time.get_ticks_usec 을 쓰므로
# 프레임 수가 아니라 시계로 기다려야 같은 것을 재게 된다.
func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - t0) / 1000000.0 < sec:
		await get_tree().process_frame


func _fresh_manager(cfg: String) -> Node:
	var n: Node = load("res://audio/music/music_manager.gd").new()
	n.config_path = cfg
	add_child(n)
	return n


func run_all() -> Array:
	results.clear()
	await _t01()
	await _t02()
	await _t03()
	await _t04()
	await _t05()
	await _t06()
	await _t07()
	await _t08()
	await _t09()
	await _t10()
	await _t11()
	_skip("T12", "듣기·파형 캡처가 필요하다. 이 자리에서는 못 한다")
	_skip("T13", "엔진 출력 녹음이 필요하다. 이 자리에서는 못 한다")
	await _t14()
	_skip("T15", "대상 플랫폼 내보내기가 필요하다. export_presets 가 이미 깨져 있다")
	return results


# T01 — 구성 검증. 어긋난 넷을 하나씩 먹여 **거절되는지** 본다.
func _t01() -> void:
	var cases := [
		["bad_length.json", &"length_mismatch"],
		["bad_missing_asset.json", &"missing_asset"],
		["bad_dup_index.json", &"bad_config"],
		["bad_bus.json", &"missing_bus"],
		# 지금 게임 음악 넷을 그대로 먹인다. 루프가 리소스에 안 걸려 있어
		# 거기서 먼저 걸리는데, **먼저 걸리는 것도 거절**이라 통과하면 안 된다.
		["real_music.json", &"loop_mismatch"],
	]
	var bad := []
	for c in cases:
		var n := _fresh_manager("res://tests/audio/fixtures/%s" % c[0])
		if n.ready_ok:
			bad.append("%s 가 통과해 버렸다" % c[0])
		elif n.last_error_code != c[1]:
			bad.append("%s → %s (기대 %s)" % [c[0], n.last_error_code, c[1]])
		# 거절당한 관리자에게 start 를 시켜도 안 켜져야 한다
		if n.start():
			bad.append("%s 가 준비 실패인데 start 가 true 였다" % c[0])
		n.queue_free()
	_note("T01", bad.is_empty(),
			"어긋난 구성 넷을 다 거절했다" if bad.is_empty() else "; ".join(bad))


# T02 — 첫 시작과 재호출.
func _t02() -> void:
	mm.stop_music()
	settled_seen.clear()
	var c0: int = mm.start_count
	var ok1: bool = mm.start()
	var s1: Dictionary = mm.get_debug_snapshot()
	var ok2: bool = mm.start()          # 두 번째는 아무것도 안 바꿔야 한다
	var s2: Dictionary = mm.get_debug_snapshot()
	var bad := []
	if not (ok1 and ok2):
		bad.append("start 가 false 를 냈다")
	if s2.start_count != c0 + 1:
		bad.append("start_count 가 %d 늘었다" % (int(s2.start_count) - c0))
	if not is_equal_approx(float(s1.gains[0]), 1.0):
		bad.append("Main 게인이 1 이 아니다")
	for i in range(1, 4):
		if float(s1.gains[i]) != 0.0 or float(s1.applied_stream_db[i]) != mm.SILENT_DB:
			bad.append("%s 가 무음 바닥이 아니다" % mm.STATE_ORDER[i])
	_note("T02", bad.is_empty(),
			"start_count=%d · Main one-hot · 재호출이 타임라인을 안 건드렸다"
			% s2.start_count if bad.is_empty() else "; ".join(bad))


# T03 — 순수 보간. 시간을 안 쓰고 u 를 직접 넣어 본다.
func _t03() -> void:
	mm.set_state(&"Shop", 1.0)
	var bad := []
	var want := {0.0: [1, 0, 0, 0], 0.5: [0.5, 0.5, 0, 0], 1.0: [0, 1, 0, 0]}
	for u in want:
		var got: PackedFloat64Array = mm.fade_at(u)
		for i in 4:
			if absf(got[i] - float(want[u][i])) > 1e-9:
				bad.append("u=%.1f 의 %d번이 %.6f (기대 %.1f)"
						% [u, i, got[i], float(want[u][i])])
	if absf(mm._gain_to_db(1.0)) > 1e-9:
		bad.append("게인 1 이 0dB 가 아니다")
	if mm._gain_to_db(0.0) != mm.SILENT_DB:
		bad.append("게인 0 이 바닥값이 아니다")
	settled_seen.clear()
	await _wait(1.35)
	var n_settle := 0
	for s in settled_seen:
		if s == &"Shop":
			n_settle += 1
	if n_settle != 1:
		bad.append("완료 신호가 %d번 왔다" % n_settle)
	if mm.settled_state != &"Shop":
		bad.append("안착이 %s 다" % mm.settled_state)
	_note("T03", bad.is_empty(),
			"u=0/0.5/1 이 [1,0,0,0]/[.5,.5,0,0]/[0,1,0,0] · 완료 신호 1회"
			if bad.is_empty() else "; ".join(bad))


# T04 — 전환 도중 재전환. 끊기지 않고 이어지는가.
func _t04() -> void:
	mm.set_state(&"Main", 0.0)
	settled_seen.clear()
	var bad := []
	var worst_sum := 0.0
	var seen_three := false

	mm.set_state(&"Shop", 1.0)
	await _wait(0.3)
	var before: Array = mm.get_debug_snapshot().gains.duplicate()
	mm.set_state(&"Aim", 1.0)
	var after: Array = mm.get_debug_snapshot().gains
	for i in 4:
		if absf(float(before[i]) - float(after[i])) > 1e-9:
			bad.append("새 요청 첫 게인이 직전과 다르다(%d번)" % i)

	await _wait(0.2)
	mm.set_state(&"Final", 1.0)
	var t0 := Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - t0) / 1000000.0 < 1.3:
		var g: Array = mm.get_debug_snapshot().gains
		var pos := 0
		var sm := 0.0
		for x in g:
			var f := float(x)
			if f < -1e-9 or f > 1.0 + 1e-9:
				bad.append("게인이 0~1 밖이다: %f" % f)
			if f > 1e-6:
				pos += 1
			sm += f
		if pos >= 3:
			seen_three = true
		worst_sum = maxf(worst_sum, absf(sm - 1.0))
		await get_tree().process_frame

	if worst_sum > 1e-6:
		bad.append("게인 합이 %.9f 만큼 벗어났다" % worst_sum)
	if mm.settled_state != &"Final":
		bad.append("마지막이 Final 이 아니라 %s 다" % mm.settled_state)
	for s in settled_seen:
		if s == &"Shop" or s == &"Aim":
			bad.append("취소된 목표(%s)가 완료를 알렸다" % s)
	_note("T04", bad.is_empty(),
			"합 오차 %.9f · 셋 이상 양수 구간 %s · Final 수렴"
			% [worst_sum, "봤다" if seen_three else "없었다"]
			if bad.is_empty() else "; ".join(bad))


# T05 — 같은 목표를 매 프레임 100번.
func _t05() -> void:
	mm.set_state(&"Main", 0.0)
	settled_seen.clear()
	requested_seen.clear()
	mm.set_state(&"Shop", 1.0)
	await _wait(0.3)
	var mid: float = mm.get_debug_snapshot().fade_progress
	for i in 100:
		mm.set_state(&"Shop")
	var after: float = mm.get_debug_snapshot().fade_progress
	var bad := []
	if after < mid:
		bad.append("진행도가 %.3f 에서 %.3f 로 되감겼다" % [mid, after])
	if requested_seen.size() != 1:
		bad.append("요청 신호가 %d번 왔다" % requested_seen.size())
	await _wait(0.9)
	var n := 0
	for s in settled_seen:
		if s == &"Shop":
			n += 1
	if n != 1:
		bad.append("완료 신호가 %d번 왔다" % n)
	_note("T05", bad.is_empty(),
			"100번 요청에도 재시작·중복 신호 없음" if bad.is_empty() else "; ".join(bad))


# T06 — 잘못된 입력.
func _t06() -> void:
	mm.set_state(&"Main", 0.0)
	mm.set_state(&"Shop", 1.0)
	await _wait(0.3)
	var keep: float = mm.get_debug_snapshot().fade_progress
	var bad := []
	for c in [[&"Aim", -3.0], [&"Aim", NAN], [&"Aim", INF], [&"없는상태", 1.0]]:
		if mm.set_state(c[0], c[1]):
			bad.append("%s/%s 가 true 를 냈다" % [c[0], c[1]])
	if mm.requested_state != &"Shop":
		bad.append("거절된 요청이 목표를 바꿨다: %s" % mm.requested_state)
	if mm.get_debug_snapshot().fade_progress < keep:
		bad.append("거절된 요청이 페이드를 되감았다")
	# 0 은 즉시, -1 은 기본값
	mm.set_state(&"Aim", 0.0)
	if mm.settled_state != &"Aim":
		bad.append("0초 요청이 즉시 적용되지 않았다")
	mm.set_state(&"Final", -1.0)
	if not is_equal_approx(mm.fade_duration, mm.cfg_fade_seconds):
		bad.append("-1 이 기본값(%.2f)이 아니라 %.2f 였다"
				% [mm.cfg_fade_seconds, mm.fade_duration])
	await _wait(1.2)
	_note("T06", bad.is_empty(),
			"음수·NaN·Inf·모르는 상태를 거절하고 페이드 보존 · 0=즉시 · -1=기본"
			if bad.is_empty() else "; ".join(bad))


# T07 — 사용자 볼륨과 음소거. 버스만 움직이고 게인은 그대로여야 한다.
func _t07() -> void:
	var bad := []
	mm.set_bus_ownership(true)
	var bi := AudioServer.get_bus_index(mm.bus_name)
	var si := AudioServer.get_bus_index("SFX")
	var sfx_before := AudioServer.get_bus_volume_db(si) if si >= 0 else 0.0
	var g_before: Array = mm.get_debug_snapshot().gains.duplicate()

	mm.set_music_volume_linear(0.5)
	if absf(AudioServer.get_bus_volume_db(bi) - linear_to_db(0.5)) > 0.01:
		bad.append("0.5 에서 버스 dB 가 %.3f" % AudioServer.get_bus_volume_db(bi))
	mm.set_music_volume_linear(0.0)
	if not AudioServer.is_bus_mute(bi):
		bad.append("0 에서 음소거가 안 됐다")
	mm.set_music_volume_linear(0.5)
	if AudioServer.is_bus_mute(bi):
		bad.append("0.5 로 올렸는데 음소거가 남았다")
	mm.set_music_muted(true)
	mm.set_music_volume_linear(1.0)
	if not AudioServer.is_bus_mute(bi):
		bad.append("명시적 음소거 중에 볼륨을 올리자 음소거가 풀렸다")
	mm.set_music_muted(false)
	mm.set_music_volume_linear(1.0)

	if si >= 0 and absf(AudioServer.get_bus_volume_db(si) - sfx_before) > 1e-6:
		bad.append("SFX 버스가 움직였다")
	var g_after: Array = mm.get_debug_snapshot().gains
	for i in 4:
		if absf(float(g_before[i]) - float(g_after[i])) > 1e-9:
			bad.append("게인이 볼륨 때문에 움직였다")
	mm.set_bus_ownership(false)
	_note("T07", bad.is_empty(),
			"버스만 움직이고 게인·SFX 는 그대로" if bad.is_empty() else "; ".join(bad))


# T08 — 트리 일시정지와 time_scale. 음악은 실제 시간에 붙는다.
func _t08() -> void:
	var bad := []
	var ts := Engine.time_scale
	mm.set_state(&"Main", 0.0)
	get_tree().paused = true
	Engine.time_scale = 0.25
	mm.set_state(&"Shop", 1.0)
	var t0 := Time.get_ticks_usec()
	while mm.fade_active and float(Time.get_ticks_usec() - t0) / 1000000.0 < 3.0:
		await get_tree().process_frame
	var took := float(Time.get_ticks_usec() - t0) / 1000000.0
	get_tree().paused = false
	Engine.time_scale = ts
	if mm.settled_state != &"Shop":
		bad.append("트리가 멈춘 동안 페이드가 안 돌았다")
	if took < 0.85 or took > 1.35:
		bad.append("time_scale 0.25 에서 %.2f초 걸렸다(약 1초여야 한다)" % took)
	_note("T08", bad.is_empty(),
			"트리 정지·time_scale 0.25 에서도 %.2f초에 끝났다" % took
			if bad.is_empty() else "; ".join(bad))


# T09 — 명시적 음악 일시정지. 진행률이 얼어야 한다.
func _t09() -> void:
	var bad := []
	mm.set_state(&"Main", 0.0)
	mm.set_state(&"Aim", 2.0)
	await _wait(0.4)
	var p0: float = mm.get_debug_snapshot().fade_progress
	mm.set_music_paused(true)
	await _wait(1.0)
	var p1: float = mm.get_debug_snapshot().fade_progress
	if absf(p1 - p0) > 0.02:
		bad.append("멈춘 동안 진행률이 %.3f → %.3f 로 움직였다" % [p0, p1])
	if not mm.player.stream_paused:
		bad.append("Player.stream_paused 가 안 켜졌다")
	# 멈춘 중에도 0초 요청은 즉시 든다
	mm.set_state(&"Final", 0.0)
	if mm.settled_state != &"Final":
		bad.append("멈춘 중 0초 요청이 즉시 안 들었다")
	mm.set_music_paused(false)
	if mm.player.stream_paused:
		bad.append("재개했는데 stream_paused 가 남았다")
	_note("T09", bad.is_empty(),
			"멈춘 1초 동안 진행률 %.3f 고정 · 0초 요청은 즉시" % p0
			if bad.is_empty() else "; ".join(bad))


# T10 — stop 뒤 start.
func _t10() -> void:
	var bad := []
	mm.set_bus_ownership(true)
	mm.set_music_volume_linear(0.7)
	mm.set_music_muted(true)
	mm.stop_music()
	var s: Dictionary = mm.get_debug_snapshot()
	if s.running or s.fade_active or s.paused:
		bad.append("stop 뒤에도 뭔가 살아 있다")
	if s.settled_state != &"Main" or absf(float(s.gains[0]) - 1.0) > 1e-9:
		bad.append("stop 이 Main one-hot 으로 안 돌아갔다")
	if not is_equal_approx(float(s.user_volume_linear), 0.7) or not s.user_muted:
		bad.append("stop 이 사용자 설정을 지웠다")
	if mm.set_state(&"Shop"):
		bad.append("정지 상태에서 set_state 가 true 를 냈다")
	mm.set_music_muted(false)
	mm.set_music_volume_linear(1.0)
	mm.set_bus_ownership(false)
	var c: int = mm.start_count
	mm.start()
	if mm.start_count != c + 1:
		bad.append("stop 뒤 start 가 안 늘었다")
	_note("T10", bad.is_empty(),
			"페이드·일시정지 초기화 · 사용자 설정 보존 · 다음 start 만 재시작"
			if bad.is_empty() else "; ".join(bad))


# T11 — 조건 우선순위.
func _t11() -> void:
	var bad := []
	var cases := [
		[false, false, false, &"Main"],
		[false, false, true, &"Aim"],
		[false, true, false, &"Final"],
		[false, true, true, &"Final"],      # 마지막 라운드에서 조준해도 Final
		[true, false, false, &"Shop"],
		[true, true, true, &"Shop"],        # 상점이 가장 세다
	]
	for c in cases:
		var got := Adapter.resolve(c[0], c[1], c[2])
		if got != c[3]:
			bad.append("shop=%s final=%s aim=%s → %s (기대 %s)"
					% [c[0], c[1], c[2], got, c[3]])
	# 상점을 닫으면 남은 조건으로 돌아가는가 — 무조건 Main 이면 안 된다
	if Adapter.resolve(false, true, false) != &"Final":
		bad.append("상점을 닫자 Final 을 잃었다")
	var n := 0
	for c in get_tree().root.get_children():
		if c.name == "MusicManager":
			n += 1
	if n != 1:
		bad.append("MusicManager 가 %d개다" % n)
	_note("T11", bad.is_empty(),
			"Shop > Final > Aim > Main · 나갈 때 조건 재평가 · 인스턴스 1개"
			if bad.is_empty() else "; ".join(bad))


# T14 — 장시간. 명세는 30분 이상·10회 이상 루프를 요구한다.
#
# **얼마나 돌았는지로 판정한다.** 예전에는 이 자리가 조건과 상관없이
# "줄여 돌렸다"를 찍었는데, 실제로 30분을 돌린 날에도 같은 말을 해서
# 검사 결과가 사실과 달랐다. 줄여 돌리는 것 자체는 괜찮지만 줄이지 않은
# 날에 줄였다고 적으면 그건 검사가 아니라 소설이다.
func _t14() -> void:
	var secs := 90.0
	if OS.has_environment("BGM_SOAK_SECONDS"):
		secs = maxf(5.0, float(OS.get_environment("BGM_SOAK_SECONDS")))
	var loop_len := 22.857143
	mm.start()
	mm.set_state(&"Main", 0.0)
	var bad := []
	var worst := 0.0
	var flips := 0
	var mem0 := OS.get_static_memory_usage()
	var t0 := Time.get_ticks_usec()
	var next := 0.0
	var i := 0
	while true:
		var el := float(Time.get_ticks_usec() - t0) / 1000000.0
		if el >= secs:
			break
		if el >= next:
			i += 1
			mm.set_state(mm.STATE_ORDER[i % 4], 0.6)
			flips += 1
			next = el + 0.1 + float(i % 3) * 0.1     # 0.1~0.3초 간격
		var g: Array = mm.get_debug_snapshot().gains
		var sm := 0.0
		for x in g:
			sm += float(x)
		worst = maxf(worst, absf(sm - 1.0))
		if not mm.running:
			bad.append("도중에 재생이 멈췄다(%.1f초 지점)" % el)
			break
		await get_tree().process_frame
	var last: StringName = mm.STATE_ORDER[i % 4]
	await _wait(0.8)
	if mm.settled_state != last:
		bad.append("마지막 목표(%s)에 안 앉고 %s 였다" % [last, mm.settled_state])
	if worst > 1e-6:
		bad.append("게인 합이 %.9f 벗어났다" % worst)
	if not bad.is_empty():
		_note("T14", false, "; ".join(bad))
		return

	var loops := secs / loop_len
	var mem_kb := float(OS.get_static_memory_usage() - mem0) / 1024.0
	# 명세는 "지속 증가"를 막으라고 한다. 30분에 4MB 를 넘게 자라면 그건
	# 흔들림이 아니라 새는 것이다.
	if mem_kb > 4096.0:
		_note("T14", false, "정적 메모리가 %.0fKB 자랐다 — 새는 것으로 본다" % mem_kb)
		return
	# 서식과 값을 두 줄로 가른다. 괄호를 닫은 **다음 줄**에 % 를 놓으면
	# 표현식이 거기서 끊겨서 파서가 문장을 기대한다.
	var fmt := ("%.0f초 · 전환 %d회 · 루프 %.1f회 · 게인 합 오차 %.9f · "
			+ "최신 목표 수렴 · 정적 메모리 %+.0fKB. "
			+ "오디오 드라이버가 %s 라 **underrun 은 못 쟀다**")
	var body := fmt % [secs, flips, loops, worst, mem_kb,
			AudioServer.get_driver_name()]
	if secs >= 1800.0 and loops >= 10.0:
		_note("T14", true, body)
	else:
		_skip("T14", body + " · **명세의 30분·10회 루프에 못 미친다**"
				+ "(BGM_SOAK_SECONDS 로 늘린다)")
