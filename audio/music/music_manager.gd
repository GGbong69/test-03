extends Node
# ══════════════════════════════════════════════════════════
#  적응형 BGM — 같은 타임라인 위에서 편곡만 갈아 끼운다
# ──────────────────────────────────────────────────────────
#  명세: docs/adaptive_bgm/godot_adaptive_bgm_spec.md
#
#  곡을 바꾸는 것이 아니라 **네 편곡을 처음부터 끝까지 같이 틀어 놓고 각각의
#  게인만 민다.** 그래서 상점에 들어가도 음악이 처음으로 안 돌아간다 —
#  마디 열둘에 있었으면 상점 편곡의 마디 열둘로 이어진다. 발라트로가 그렇게
#  들리는 이유가 이것이고, 곡을 갈아 끼우는 방식으로는 흉내가 안 난다.
#
#  안 들리는 편곡도 계속 재생·디코딩한다. 낭비처럼 보이지만 멈췄다 다시
#  틀면 그 순간 타임라인이 어긋나고, 어긋남은 되돌릴 방법이 없다.
#
#  AudioStreamSynchronized 가 넷의 공통 시작을 맡는다(4.3+). 이 프로젝트는
#  4.6.3 이다. Autoload 이름(MusicManager)과 겹치면 안 되므로 class_name 은
#  달지 않는다.
#
#  **이 관리자는 스스로 시작하지 않는다.** 부트스트랩이 start() 를 한 번
#  부를 때만 소리가 난다. 지금 게임 음악은 game.gd 가 따로 쥐고 있고 둘이
#  같이 울리면 안 되기 때문이다. 넘기는 방법은 audio/music/README.md 에 있다.
# ══════════════════════════════════════════════════════════

const CONFIG_PATH := "res://audio/music/music_config.json"

# 바깥이 대는 이름과 안에서 쓰는 자리의 대응. 명세가 못 박은 고정 매핑이다.
const STATE_INDEX := {&"Main": 0, &"Shop": 1, &"Aim": 2, &"Final": 3}
const STATE_ORDER := [&"Main", &"Shop", &"Aim", &"Final"]
const N := 4

const DEFAULT_FADE_SECONDS := 1.0
const SILENT_DB := -80.0
const DEFAULT_HEADROOM_DB := -6.0
const DEFAULT_BUS := "Music"
const LENGTH_TOLERANCE := 0.001

signal state_requested(state: StringName)
signal state_settled(state: StringName)
signal music_error(code: StringName, message: String)

var player: AudioStreamPlayer = null
var sync_stream: AudioStreamSynchronized = null

var ready_ok := false          # 검증을 통과해 start 를 받을 수 있는가
var running := false
var music_paused := false
var start_count := 0

var requested_state: StringName = &"Main"
var settled_state: StringName = &"Main"

# 게인은 **선형 진폭**이다. dB 를 0 에서 -80 으로 바로 보간하면 가운데가 뚝
# 꺼진다 — 데시벨은 로그라 절반 지점이 -40dB(진폭 1%)이기 때문이다.
var gains := PackedFloat64Array([1.0, 0.0, 0.0, 0.0])
var from_gains := PackedFloat64Array([1.0, 0.0, 0.0, 0.0])
var to_gains := PackedFloat64Array([1.0, 0.0, 0.0, 0.0])
var fade_active := false
var fade_elapsed := 0.0
var fade_duration := DEFAULT_FADE_SECONDS

# 페이드 시계는 _process 의 delta 를 안 쓴다. Engine.time_scale 이 걸리면
# 음악만 같이 느려지는데, 음악은 게임 시간이 아니라 실제 시간에 붙어야 한다.
var last_tick_usec := 0

var user_volume_linear := 1.0
var user_muted := false

var bus_name := DEFAULT_BUS
# **버스는 한 곳만 만진다.** 명세가 못 박은 규칙이고, 지금 이 프로젝트에서
# Music 버스를 쥔 것은 game.gd 의 설정 화면이다. 그래서 기본은 false 다 —
# 사용자 볼륨·음소거를 받아 두기는 하되 버스에 쓰지는 않는다. 음악을 이
# 관리자에게 넘길 때 config 의 owns_bus 를 켜면 그때부터 여기가 쥔다.
var owns_bus := false
var headroom_db := DEFAULT_HEADROOM_DB
var cfg_fade_seconds := DEFAULT_FADE_SECONDS
var cfg_initial_state: StringName = &"Main"
# 검증을 시험하려면 **일부러 틀린 구성**을 먹여 봐야 한다. 상수를 그대로
# 쓰면 그 길이 없어서, 자리를 하나 열어 둔다. add_child 앞에 바꿔 넣는다.
var config_path := CONFIG_PATH
var asset_paths := ["", "", "", ""]
var music_meta := {}
var last_error_code: StringName = &""


# ══════════════════════════════════════════════════════════
#  준비
# ══════════════════════════════════════════════════════════

func _ready() -> void:
	# 씬 트리가 멈춰도(일시정지 메뉴) 음악과 페이드는 돈다. 명세의 기본이고,
	# 멈추게 하려면 set_music_paused 를 명시적으로 부른다.
	process_mode = Node.PROCESS_MODE_ALWAYS
	last_tick_usec = Time.get_ticks_usec()
	player = get_node_or_null("Player")
	if player == null:
		# 씬 없이 붙여도 돌게 한다. 테스트가 이 경로를 쓴다.
		player = AudioStreamPlayer.new()
		player.name = "Player"
		add_child(player)
	player.autoplay = false
	player.max_polyphony = 1
	player.pitch_scale = 1.0
	player.stream_paused = false
	if not player.finished.is_connected(_on_finished):
		player.finished.connect(_on_finished)
	ready_ok = _prepare()


# 구성과 에셋을 전부 읽고 검증한다. **하나라도 어긋나면 통째로 거절한다** —
# 셋만 준비된 채로 시작하면 빠진 편곡이 나중에 "조용한 자리"로 나타나고,
# 그건 소리만 듣고는 원인을 못 찾는다.
func _prepare() -> bool:
	if not _load_config():
		return false

	if AudioServer.get_bus_index(bus_name) < 0:
		return _fail(&"missing_bus",
				"'%s' 버스가 없다. 버스 레이아웃에 %s→Master 를 두어라"
				% [bus_name, bus_name])

	var streams := []
	var base_len := -1.0
	for i in N:
		var p: String = asset_paths[i]
		if not ResourceLoader.exists(p):
			return _fail(&"missing_asset", "에셋이 없다: %s" % p)
		var st: AudioStream = load(p)
		if st == null:
			return _fail(&"load_failed", "에셋을 못 읽었다: %s" % p)
		var l := st.get_length()
		if l <= 0.0:
			return _fail(&"bad_length", "길이가 0 이하다: %s" % p)
		if base_len < 0.0:
			base_len = l
		elif absf(l - base_len) > LENGTH_TOLERANCE:
			return _fail(&"length_mismatch",
					"길이가 %.6f초 어긋난다(허용 %.3f): %s"
					% [absf(l - base_len), LENGTH_TOLERANCE, p])
		var loop_msg := _loop_problem(st)
		if loop_msg != "":
			return _fail(&"loop_mismatch", "%s — %s" % [p, loop_msg])
		streams.append(st)

	sync_stream = AudioStreamSynchronized.new()
	sync_stream.stream_count = N
	for i in N:
		sync_stream.set_sync_stream(i, streams[i])

	if not STATE_INDEX.has(cfg_initial_state):
		return _fail(&"bad_initial_state", "모르는 첫 상태: %s" % cfg_initial_state)
	requested_state = cfg_initial_state
	settled_state = cfg_initial_state
	_set_one_hot(gains, cfg_initial_state)
	from_gains = gains.duplicate()
	to_gains = gains.duplicate()
	_apply_gains()

	player.bus = bus_name
	player.volume_db = headroom_db
	player.stream = sync_stream
	_apply_bus_volume()
	return true


# 루프가 켜져 있는가. 형식마다 묻는 자리가 다르다 — 안 켜진 채로 두면
# 한 바퀴 뒤에 음악이 조용히 끝나고, finished 로 되살리는 것은 명세가 금한다.
func _loop_problem(st: AudioStream) -> String:
	if st is AudioStreamWAV:
		if (st as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
			return "루프가 꺼져 있다(임포트의 edit/loop_mode 를 Forward 로)"
		return ""
	if st is AudioStreamOggVorbis:
		return "" if (st as AudioStreamOggVorbis).loop else "루프가 꺼져 있다"
	if st is AudioStreamMP3:
		# 명세가 mp3 를 검증 대상에서 뺐다. 막지는 않되 루프는 본다.
		return "" if (st as AudioStreamMP3).loop else "루프가 꺼져 있다"
	return ""


# 구성 파일을 읽고 검증한다. 성공하면 필드를 채우고 true.
func _load_config() -> bool:
	var f := FileAccess.open(config_path, FileAccess.READ)
	if f == null:
		return _fail(&"missing_config", "구성 파일을 못 열었다: %s" % config_path)
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fail(&"bad_config", "구성 파일이 사전이 아니다")
	var cfg: Dictionary = parsed

	var rows: Variant = cfg.get("states", null)
	if typeof(rows) != TYPE_ARRAY or (rows as Array).size() != N:
		return _fail(&"bad_config", "states 는 %d줄이어야 한다" % N)
	var seen := {}
	for row in (rows as Array):
		if typeof(row) != TYPE_DICTIONARY:
			return _fail(&"bad_config", "states 의 줄이 사전이 아니다")
		var d: Dictionary = row
		var id := StringName(String(d.get("id", "")))
		if not STATE_INDEX.has(id):
			return _fail(&"bad_config", "모르는 상태 이름: %s" % id)
		var idx := int(d.get("index", -1))
		if idx != int(STATE_INDEX[id]):
			return _fail(&"bad_config",
					"%s 의 index 는 %d 여야 한다" % [id, int(STATE_INDEX[id])])
		if seen.has(idx):
			return _fail(&"bad_config", "index %d 가 겹친다" % idx)
		seen[idx] = true
		var a := String(d.get("asset", ""))
		if a == "":
			return _fail(&"bad_config", "%s 의 asset 이 비었다" % id)
		asset_paths[idx] = a
	if seen.size() != N:
		return _fail(&"bad_config", "index 가 0..%d 를 다 안 덮는다" % (N - 1))

	cfg_initial_state = StringName(String(cfg.get("initial_state", "Main")))
	cfg_fade_seconds = _finite_or(cfg.get("fade_seconds", DEFAULT_FADE_SECONDS),
			DEFAULT_FADE_SECONDS)
	if cfg_fade_seconds < 0.0:
		cfg_fade_seconds = DEFAULT_FADE_SECONDS
	headroom_db = _finite_or(cfg.get("player_headroom_db", DEFAULT_HEADROOM_DB),
			DEFAULT_HEADROOM_DB)
	bus_name = String(cfg.get("bus", DEFAULT_BUS))
	owns_bus = bool(cfg.get("owns_bus", false))
	music_meta = cfg.get("music_meta", {})
	return true


func _finite_or(v: Variant, dflt: float) -> float:
	var x := float(v)
	return x if is_finite(x) else dflt


func _fail(code: StringName, msg: String) -> bool:
	last_error_code = code
	push_error("음악: [%s] %s" % [code, msg])
	music_error.emit(code, msg)
	return false


# ══════════════════════════════════════════════════════════
#  공개 API
# ══════════════════════════════════════════════════════════

func start(initial_state: StringName = &"Main") -> bool:
	if not STATE_INDEX.has(initial_state):
		return _fail(&"invalid_request", "모르는 상태: %s" % initial_state)
	if not ready_ok or sync_stream == null or player == null:
		return _fail(&"not_ready", "준비가 안 끝났다. 오류를 먼저 보라")
	if running:
		# 이미 돌고 있으면 아무것도 안 한다. 여기서 다시 play 하면 타임라인이
		# 처음으로 돌아가고, 그것이 이 시스템이 막으려는 바로 그 일이다.
		return true
	requested_state = initial_state
	settled_state = initial_state
	_set_one_hot(gains, initial_state)
	from_gains = gains.duplicate()
	to_gains = gains.duplicate()
	fade_active = false
	fade_elapsed = 0.0
	music_paused = false
	player.stream_paused = false
	_apply_gains()
	player.play(0.0)
	running = true
	start_count += 1
	last_tick_usec = Time.get_ticks_usec()
	state_settled.emit(settled_state)
	return true


func set_state(state: StringName, fade_seconds: float = -1.0) -> bool:
	# **검증이 먼저다.** 실패한 요청이 돌던 페이드를 흔들면 안 된다.
	if not STATE_INDEX.has(state):
		return _fail(&"invalid_request", "모르는 상태: %s" % state)
	if not is_finite(fade_seconds):
		return _fail(&"invalid_duration", "유한한 수가 아니다")
	if fade_seconds < 0.0 and not is_equal_approx(fade_seconds, -1.0):
		return _fail(&"invalid_duration", "-1 이거나 0 이상이어야 한다: %f" % fade_seconds)
	if not running or sync_stream == null:
		return _fail(&"not_running", "start 뒤에만 상태를 바꾼다")
	if state == requested_state:
		# 같은 목표를 매 프레임 보내도 페이드는 그대로 이어진다.
		return true

	# 지금 **실제로 나고 있는** 게인이 출발점이다. 목표가 출발점이 아니다 —
	# 전환 도중에 또 바뀌면 셋이나 넷이 동시에 양수인 채로 이어져야 한다.
	from_gains = gains.duplicate()
	to_gains = PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	to_gains[int(STATE_INDEX[state])] = 1.0
	requested_state = state
	fade_duration = cfg_fade_seconds if is_equal_approx(fade_seconds, -1.0) else fade_seconds
	fade_elapsed = 0.0
	fade_active = false
	last_tick_usec = Time.get_ticks_usec()

	if fade_duration == 0.0:
		gains = to_gains.duplicate()
		_apply_gains()
		settled_state = state
		state_requested.emit(state)
		state_settled.emit(state)
		return true

	fade_active = true
	state_requested.emit(state)
	return true


func set_music_volume_linear(value: float) -> void:
	if not is_finite(value):
		_fail(&"invalid_volume", "유한한 수가 아니다")
		return
	user_volume_linear = clampf(value, 0.0, 1.0)
	_apply_bus_volume()


func set_music_muted(muted: bool) -> void:
	user_muted = muted
	_apply_bus_volume()


func set_music_paused(paused: bool) -> void:
	if not running or music_paused == paused:
		return
	music_paused = paused
	player.stream_paused = paused
	# 재개할 때 기준 tick 을 다시 잡는다. 안 잡으면 멈춰 있던 5초가
	# 재개 첫 프레임에 통째로 페이드에 실린다.
	last_tick_usec = Time.get_ticks_usec()


func stop_music() -> void:
	fade_active = false
	fade_elapsed = 0.0
	if player != null:
		player.stop()
		player.stream_paused = false
	music_paused = false
	running = false
	requested_state = &"Main"
	settled_state = &"Main"
	_set_one_hot(gains, &"Main")
	from_gains = gains.duplicate()
	to_gains = gains.duplicate()
	_apply_gains()
	# 사용자 볼륨·음소거는 안 건드린다. 그건 음악의 상태가 아니라 사람의
	# 설정이라, 껐다 켰다고 되돌아가면 안 된다.


func get_debug_snapshot() -> Dictionary:
	var db := []
	if sync_stream != null:
		for i in N:
			db.append(sync_stream.get_sync_stream_volume(i))
	return {
		"ready": ready_ok,
		"running": running,
		"paused": music_paused,
		"requested_state": requested_state,
		"settled_state": settled_state,
		"gains": Array(gains),
		"applied_stream_db": db,
		"fade_active": fade_active,
		"fade_progress": (clampf(fade_elapsed / fade_duration, 0.0, 1.0)
				if fade_active and fade_duration > 0.0 else 0.0),
		# 진단값이다. 믹싱 청크 단위라 하위 스트림의 동기화 증거로 쓰면 안 된다.
		"playback_position_seconds": (player.get_playback_position()
				if player != null and running else 0.0),
		"user_volume_linear": user_volume_linear,
		"user_muted": user_muted,
		"effective_mute": _effective_mute(),
		"start_count": start_count,
		"last_error_code": last_error_code,
	}


# ══════════════════════════════════════════════════════════
#  안쪽
# ══════════════════════════════════════════════════════════

func _process(_delta: float) -> void:
	# 기준 tick 은 **언제나** 새로 잡는다. 멈춰 있는 동안 쌓지만 않으면 되고,
	# 여기서 안 잡으면 멈춘 시간이 재개 첫 프레임에 한꺼번에 실린다.
	var now := Time.get_ticks_usec()
	var dt := maxf(0.0, float(now - last_tick_usec) / 1000000.0)
	last_tick_usec = now
	if not running or music_paused or not fade_active:
		return
	fade_elapsed += dt
	var u := clampf(fade_elapsed / fade_duration, 0.0, 1.0)
	gains = fade_at(u)
	var done := u >= 1.0
	if done:
		# 끝에서는 보간값이 아니라 **목표를 그대로** 넣는다. 부동소수의
		# 찌꺼기가 남으면 게인 합이 1 에서 미세하게 벗어난 채로 굳는다.
		gains = to_gains.duplicate()
		fade_active = false
		settled_state = requested_state
	_apply_gains()
	if done:
		state_settled.emit(settled_state)


# 진행도 u 에서의 게인. **순수 함수다** — 시계도 상태도 안 만진다. 페이드를
# 시간 없이 검사할 수 있는 자리가 여기 하나뿐이라 따로 떼어 둔다(T03).
func fade_at(u: float) -> PackedFloat64Array:
	var out := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	var c := clampf(u, 0.0, 1.0)
	for i in N:
		out[i] = lerpf(from_gains[i], to_gains[i], c)
	return out


func _set_one_hot(arr: PackedFloat64Array, state: StringName) -> void:
	for i in N:
		arr[i] = 0.0
	arr[int(STATE_INDEX[state])] = 1.0


func _gain_to_db(gain: float) -> float:
	# linear_to_db(0) 은 -inf 다. 0 은 아예 안 넘긴다.
	if gain <= 0.0:
		return SILENT_DB
	return maxf(SILENT_DB, linear_to_db(gain))


func _apply_gains() -> void:
	if sync_stream == null:
		return
	for i in N:
		sync_stream.set_sync_stream_volume(i, _gain_to_db(gains[i]))


func _effective_mute() -> bool:
	return user_muted or user_volume_linear <= 0.0


func _apply_bus_volume() -> void:
	if not owns_bus:
		return          # 값은 기억하되 버스는 쥔 쪽이 따로 있다
	var bi := AudioServer.get_bus_index(bus_name)
	if bi < 0:
		return
	AudioServer.set_bus_mute(bi, _effective_mute())
	AudioServer.set_bus_volume_db(bi,
			SILENT_DB if user_volume_linear <= 0.0 else linear_to_db(user_volume_linear))


# 버스를 누가 쥐는가를 바꾼다. 켜는 순간 지금 값이 버스에 반영된다.
func set_bus_ownership(owned: bool) -> void:
	owns_bus = owned
	_apply_bus_volume()


func _on_finished() -> void:
	# 루프가 켜져 있으면 여기 안 온다. 왔다는 것은 루프가 풀렸다는 뜻이고,
	# 여기서 다시 play 하면 타임라인이 처음으로 돌아가 버린다. 되살리지
	# 않고 말만 한다 — 명세가 finished 자동 루프를 금한다.
	if not running:
		return
	running = false
	fade_active = false
	_fail(&"unexpected_finished",
			"재생이 끝났다. 루프 설정을 보라 — 자동으로 다시 틀지 않는다")
