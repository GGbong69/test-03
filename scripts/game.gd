extends Node2D

const GameData = preload("res://scripts/data.gd")

# ── 다트 로그라이트 프로토타입 ──────────────────────────────
# 흐름: 라운드 플레이 → 클리어 정산(보너스 3택) → 상점 → 다음 라운드
# 조작: 마우스 클릭 / 스페이스 (상하 → 좌우 → 확인 → 발사)
#       [ ] 조준 속도   - = 정산 속도   ; ' 확인 텀
# 밸런스 수치는 전부 scripts/data.gd 에 있다.

const VIEW := Vector2(640, 360)
const BC := Vector2(320, 202)
const R := 118.0
const SWING := 132.0

const CARD_W := 244.0
const CARD_H := 96.0

const SECTORS_BASE := [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]
const DBL_OUT := 1.00

const C_BG := Color("14111f")
const C_LIGHT := Color("e8dfc8")
const C_DARK := Color("2b2438")
const C_RED := Color("d8483d")
const C_GREEN := Color("479a58")
const C_WIRE := Color("7a7192")
const C_TXT := Color("f4efe2")
const C_DIM := Color("8f86a8")
const C_ACC := Color("f2b134")
const C_PANEL := Color("221d33")
const C_CHIP := Color("3f8fd8")
const C_MULT := Color("e2593f")
const C_GOLD := Color("f2c94c")

enum S { PICK, AIM_V, AIM_H, CONFIRM, FLY, RESOLVE, CLEAR, SHOP, STAGE, OVER }

# ── 보드 기하 (개조로 변한다) ──────────────────────────────
var sectors := SECTORS_BASE.duplicate()
var dbl_in := 0.90
var trp_in := 0.56
var trp_out := 0.66
var bull_o := 0.14
var bull_i := 0.06

# 라운드 동안 실제로 쓰이는 값 (영구 개조 + 이번 판 제약)
var rt_dbl_in := 0.90
var rt_trp_in := 0.56
var rt_trp_out := 0.66
var rt_bull_o := 0.14
var rt_bull_i := 0.06

# ── 스테이지 선택 ─────────────────────────────────────────
var stage_pick := []            # 이번에 제시된 3개 후보
var active_mods := []           # 이번 판에 걸린 제약
var stage_gold := 0             # 클리어 시 추가 골드
var stage_item := false         # 클리어 시 아이템 무료 지급
var sealed := -1                # "둔화"로 봉인된 아이템 인덱스

# ── 탄창 ──────────────────────────────────────────────────
var magazine := []              # 영구 구성 (상점에서 바꾼다)
var remaining := []             # 이번 라운드에 남은 다트
var cur_dart := {}              # 지금 던지는 다트

# ── 진행 상태 ─────────────────────────────────────────────
var state: int = S.AIM_V
var round_no := 1
var target := 60
var total := 0
var shown := 0.0
var darts_left := 6
var gold := 4
var owned := []
var won := false

var last_sector := -1
var streak := 0
var dart_index := 0
var round_miss := false         # 이번 라운드에 한 번이라도 빗나갔는가 (골드 칩 "본전" 판정)

# ── 상점 ──────────────────────────────────────────────────
var stock := []                 # {type:"item"/"mod", d:Dictionary, cost:int, sold:bool}
var reroll_cost := GameData.REROLL_BASE
var rerolls_used := 0
var deny_flash := 0.0
var clear_gold_detail := []

# ── 조준 / 정산 ───────────────────────────────────────────
var gauge_speed := 0.7
var beat := 0.34
var confirm_hold := 0.45
var gt := 0.0
var confirm_t := 0.0
var aim := Vector2(320, 202)
var fly_t := 0.0
var queue := []
var qt := 0.0
var cur_chip := 0
var cur_mult := 0

# ── 점수 카드 ─────────────────────────────────────────────
var card_p := 0.0
var card_v := 0.0
var card_target := 0.0
var card_side := 1
var card_y := 230.0
var card_mode := 0
var card_item := ""
var last_gain := 0
var total_flash := 0.0

# ── 이펙트 ────────────────────────────────────────────────
var darts := []
var pops := []
var slot_pop := []              # 아이템 패널 참고 — 아래 "아이템 패널" 구획
var slot_vel := []
var shake := 0.0
var board_punch := 0.0
var pitch_step := 0
var hit_flash := 0.0
var hit_flash_amt := 0.55
var hit_idx := -1
var hit_r0 := 0.0
var hit_r1 := 0.0
var hit_bull := false
var waves := []
var sparks := []
var ring_fx := []
var screen_flash := 0.0
var hitstop := 0.0

var _autoplay := false
var _auto_t := 0.0

var font: Font
var pb: AudioStreamGeneratorPlayback
var ph := 0.0
var freq := 440.0
var env := 0.0
var dec := 0.0
var amp := 0.0
var beep_q := []
var beep_t := 0.0
var beep_gap := 0.07


func _ready() -> void:
	_autoplay = OS.get_cmdline_user_args().has("autoplay")
	if _autoplay:
		# 검증 실행에서만 전 구간을 빠르게 통과시킨다 (실제 기본값은 위 선언부)
		gauge_speed = 2.2
		beat = 0.10
		confirm_hold = 0.05

	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Malgun Gothic", "Segoe UI", "Arial"])
	font = sf

	var p := AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 44100.0
	gen.buffer_length = 0.08
	p.stream = gen
	add_child(p)
	p.play()
	pb = p.get_stream_playback()

	_new_run()


# ══════════════════════════════════════════════════════════
#  런 / 라운드 진행
# ══════════════════════════════════════════════════════════

func _new_run() -> void:
	sectors = SECTORS_BASE.duplicate()
	dbl_in = 0.90
	trp_in = 0.56
	trp_out = 0.66
	bull_o = 0.14
	bull_i = 0.06
	round_no = 1
	gold = 4
	magazine.clear()
	for i in GameData.DARTS_BASE:
		magazine.append(GameData.DARTS[0])
	owned.clear()
	won = false
	_open_stage()


func _start_round() -> void:
	# 영구 개조값에서 출발해 이번 판 제약을 얹는다
	rt_dbl_in = dbl_in
	rt_trp_in = trp_in
	rt_trp_out = trp_out
	rt_bull_o = bull_o
	rt_bull_i = bull_i
	if has_mod("narrow"):
		var tc := (trp_in + trp_out) * 0.5
		var tb := (trp_out - trp_in) * 0.5
		rt_trp_in = tc - tb * 0.5
		rt_trp_out = tc + tb * 0.5
		rt_dbl_in = DBL_OUT - (DBL_OUT - dbl_in) * 0.5

	remaining = magazine.duplicate()
	if has_mod("short") and remaining.size() > 1:
		remaining.pop_back()
	cur_dart = GameData.DARTS[0]
	darts_left = remaining.size()
	sealed = randi() % owned.size() if has_mod("dull") and not owned.is_empty() else -1
	round_miss = false
	total = 0
	shown = 0.0
	dart_index = 0
	streak = 0
	last_sector = -1
	cur_chip = 0
	cur_mult = 0
	darts.clear()
	pops.clear()
	waves.clear()
	sparks.clear()
	ring_fx.clear()
	queue.clear()
	card_target = 0.0
	card_p = 0.0
	card_v = 0.0
	hit_flash = 0.0
	hitstop = 0.0
	screen_flash = 0.0
	_panel_reset()
	_to_pick()


func _to_pick() -> void:
	# 남은 다트가 전부 같은 종류면 고를 게 없으니 건너뛴다
	var uniform := true
	for r in remaining:
		if r.id != remaining[0].id:
			uniform = false
			break
	if uniform:
		_pick_dart(0)
	else:
		state = S.PICK


func _pick_dart(i: int) -> void:
	if i < 0 or i >= remaining.size():
		return
	cur_dart = remaining[i]
	remaining.remove_at(i)
	darts_left = remaining.size()
	state = S.AIM_V
	beep(262.0, 0.05, 0.10)


func _finish_round() -> void:
	if total < target:
		state = S.OVER
		won = false
		beep_seq([300.0, 240.0, 180.0], 0.13, 0.24, 0.22)
		return

	if round_no >= GameData.ROUNDS:
		state = S.OVER
		won = true
		beep_seq([262.0, 330.0, 392.0, 523.0, 659.0], 0.10, 0.22, 0.26)
		return

	# 정산 내역
	var dart_gold: int = darts_left * GameData.GOLD_PER_DART
	var interest: int = mini(gold / GameData.INTEREST_PER, GameData.INTEREST_MAX)
	# gold 를 더하기 전에 부른다 — "밑천"과 이자가 같은 잔액을 보게 하려는 것이다.
	var item_rows := _gold_from_items()
	var item_gold := 0
	for r in item_rows:
		item_gold += r.v
	clear_gold_detail = [
		{"n": "클리어", "v": GameData.CLEAR_GOLD},
		{"n": "남은 다트 %d개" % darts_left, "v": dart_gold},
		{"n": "이자", "v": interest},
	]
	if stage_gold > 0:
		clear_gold_detail.append({"n": "스테이지 보상", "v": stage_gold})
	for r in item_rows:
		clear_gold_detail.append(r)
	gold += GameData.CLEAR_GOLD + dart_gold + interest + stage_gold + item_gold

	# 극한 판은 아이템을 하나 무료로 준다
	if stage_item and owned.size() < GameData.MAX_ITEMS:
		var pool := GameData.ITEMS.duplicate()
		pool.shuffle()
		for it in pool:
			if not _has_item(it.id):
				owned.append(it)
				break
	stage_gold = 0
	stage_item = false

	state = S.CLEAR
	beep_seq([392.0, 494.0, 587.0], 0.09, 0.18, 0.22)


func _gold_from_items() -> Array:
	# 골드가 나오는 곳은 여기 하나뿐이다. 다트 단위로는 절대 지급하지 않는다.
	var rows := []
	for i in owned.size():
		if i == sealed:
			continue
		var it: Dictionary = owned[i]
		var v := 0
		match it.get("g", ""):
			"clear": v = it.gv
			"spare": v = it.gv * darts_left
			"clean": v = it.gv if not round_miss else 0
			"blitz": v = it.gv if darts_left >= GameData.GOLD_BLITZ else 0
			"broke": v = it.gv if gold <= GameData.GOLD_BROKE else 0
		if v > 0:
			rows.append({"n": it.n, "v": v})
	return rows


func _reroll_price() -> int:
	if rerolls_used < GameData.FREE_REROLLS:
		return 0
	return GameData.REROLL_BASE + (rerolls_used - GameData.FREE_REROLLS) * GameData.REROLL_STEP


func _open_shop() -> void:
	rerolls_used = 0
	reroll_cost = _reroll_price()
	_roll_stock()
	state = S.SHOP
	beep(440.0, 0.10, 0.18)


func _roll_stock() -> void:
	stock.clear()
	var pool := GameData.ITEMS.duplicate()
	pool.shuffle()
	var n := 0
	for it in pool:
		if n >= GameData.SHOP_ITEMS:
			break
		if _has_item(it.id):
			continue
		stock.append({"type": "item", "d": it, "cost": it.cost, "sold": false})
		n += 1
	var mods := GameData.MODS.duplicate()
	mods.shuffle()
	for i in GameData.SHOP_MODS:
		var m: Dictionary = mods[i]
		stock.append({"type": "mod", "d": m, "cost": m.cost, "sold": false})

	var darts_pool := GameData.DARTS.slice(1)
	darts_pool.shuffle()
	for i in GameData.SHOP_DARTS:
		var dd: Dictionary = darts_pool[i]
		stock.append({"type": "dart", "d": dd, "cost": dd.cost, "sold": false})


func _deny() -> void:
	deny_flash = 1.0
	shake = 4.0
	beep_seq([200.0, 150.0], 0.06, 0.10, 0.16)


func _has_item(id: String) -> bool:
	for it in owned:
		if it.id == id:
			return true
	return false


func _buy(i: int) -> void:
	var s: Dictionary = stock[i]
	if s.sold or gold < s.cost:
		_deny()
		return
	if s.type == "item" and owned.size() >= GameData.MAX_ITEMS:
		_deny()
		return

	if s.type == "dart" and _std_slot() < 0:
		_deny()
		return

	gold -= s.cost
	s.sold = true
	match s.type:
		"item":
			owned.append(s.d)
		"mod":
			_apply_mod(s.d.id)
		"dart":
			magazine[_std_slot()] = s.d
	beep_seq([523.0, 659.0], 0.07, 0.11, 0.20)


func _std_slot() -> int:
	for i in magazine.size():
		if magazine[i].id == "std":
			return i
	return -1


func _mag_text() -> String:
	var cnt := {}
	for d in magazine:
		cnt[d.n] = cnt.get(d.n, 0) + 1
	var parts := []
	for k in cnt:
		parts.append("%s×%d" % [k, cnt[k]])
	return "  ".join(parts)


func _apply_mod(id: String) -> void:
	match id:
		"trpw":
			var band := minf((trp_out - trp_in) * 1.6, GameData.TRP_BAND_MAX)
			var c := (trp_in + trp_out) * 0.5
			trp_in = maxf(c - band * 0.5, bull_o + 0.04)
			trp_out = minf(c + band * 0.5, dbl_in - 0.04)
		"dblw":
			var band := minf((DBL_OUT - dbl_in) * 1.6, GameData.DBL_BAND_MAX)
			dbl_in = maxf(DBL_OUT - band, trp_out + 0.04)
		"bulw":
			bull_o = minf(bull_o * 1.7, GameData.BULL_O_MAX)
			bull_o = minf(bull_o, trp_in - 0.04)
			bull_i = minf(bull_i * 1.7, bull_o * 0.55)
		"sw20":
			var lo := 0
			for i in sectors.size():
				if sectors[i] < sectors[lo]:
					lo = i
			sectors[lo] = 20


func _reroll() -> void:
	if gold < reroll_cost:
		_deny()
		return
	gold -= reroll_cost
	rerolls_used += 1
	reroll_cost = _reroll_price()
	_roll_stock()
	beep(392.0, 0.09, 0.18)


func _next_round() -> void:
	round_no += 1
	_open_stage()


# ── 스테이지 선택 ─────────────────────────────────────────

func has_mod(id: String) -> bool:
	for m in active_mods:
		if m.id == id:
			return true
	return false


func _open_stage() -> void:
	var base := GameData.target_of(round_no)
	stage_pick.clear()
	var pool := GameData.MODIFIERS.duplicate()
	pool.shuffle()
	var used := 0
	for st in GameData.STAGES:
		var picked := []
		for i in st.mods:
			picked.append(pool[(used + i) % pool.size()])
		used += st.mods
		stage_pick.append({
			"d": st,
			"mods": picked,
			"target": int(round(base * st.mul)),
		})
	state = S.STAGE
	beep_seq([392.0, 494.0], 0.09, 0.14, 0.18)


func _pick_stage(i: int) -> void:
	var sp: Dictionary = stage_pick[i]
	active_mods = sp.mods.duplicate()
	target = sp.target
	stage_gold = sp.d.gold
	stage_item = sp.d.item
	beep_seq([523.0, 659.0, 784.0], 0.07, 0.12, 0.20)
	_start_round()


# ══════════════════════════════════════════════════════════
#  오디오
# ══════════════════════════════════════════════════════════

func beep(f: float, decay: float, a: float) -> void:
	beep_q.clear()
	freq = f
	env = 1.0
	dec = 1.0 / (44100.0 * decay)
	amp = a


func beep_seq(freqs: Array, gap: float, decay: float, a: float) -> void:
	beep(freqs[0], decay, a)
	for i in range(1, freqs.size()):
		beep_q.append({"f": freqs[i], "d": decay, "a": a})
	beep_gap = gap
	beep_t = gap


func _fill_audio() -> void:
	if pb == null:
		return
	for i in pb.get_frames_available():
		var s := 0.0
		if env > 0.0:
			var w := sin(ph * TAU)
			s = (w * 0.55 + signf(w) * 0.45) * env * env * amp
			ph = fmod(ph + freq / 44100.0, 1.0)
			env = maxf(env - dec, 0.0)
		pb.push_frame(Vector2(s, s))


func add_wave(p: Vector2, r0: float, r1: float, c: Color, a0: float,
		w: float, life: float) -> void:
	waves.append({"p": p, "r0": r0, "r1": r1, "col": c, "a0": a0,
			"w": w, "t": 0.0, "life": life})


func add_ring_fx(r0: float, r1: float, c: Color, life: float) -> void:
	ring_fx.append({"r0": r0, "r1": r1, "col": c, "t": 0.0, "life": life})


func add_sparks(n: int, r0: float, r1: float, ln: float, c: Color, life: float) -> void:
	for i in n:
		sparks.append({"a": TAU * float(i) / float(n) + randf() * 0.2,
				"r0": r0, "r1": r1, "len": ln, "col": c, "t": 0.0, "life": life})


func gs() -> float:
	var g := gauge_speed * (2.0 if has_mod("gust") else 1.0)
	return g * (cur_dart.gauge if cur_dart.has("gauge") else 1.0)


func ch() -> float:
	return 0.0 if has_mod("fog") else confirm_hold


func tri(t: float) -> float:
	var f := fmod(t, 1.0)
	return f * 2.0 if f < 0.5 else (1.0 - f) * 2.0


func card_pos() -> Vector2:
	var sx := 82.0 if card_side < 0 else VIEW.x - 26.0 - CARD_W   # 왼쪽은 탄창 열을 피한다
	var hx := -CARD_W - 40.0 if card_side < 0 else VIEW.x + 40.0
	return Vector2(lerpf(hx, sx, card_p), card_y)


# ══════════════════════════════════════════════════════════
#  루프
# ══════════════════════════════════════════════════════════

func _process(d: float) -> void:
	_fill_audio()

	if not beep_q.is_empty():
		beep_t -= d
		if beep_t <= 0.0:
			var b = beep_q.pop_front()
			freq = b.f
			env = 1.0
			dec = 1.0 / (44100.0 * b.d)
			amp = b.a
			beep_t = beep_gap

	if hitstop > 0.0:
		hitstop -= d
		queue_redraw()
		return

	if _autoplay:
		_auto_t += d
		if _auto_t > 0.35:
			_auto_t = 0.0
			_auto_step()

	screen_flash = maxf(screen_flash - d * 5.0, 0.0)
	deny_flash = maxf(deny_flash - d * 2.6, 0.0)
	shake = maxf(shake - d * 34.0, 0.0)
	board_punch = maxf(board_punch - d * 3.4, 0.0)
	hit_flash = maxf(hit_flash - d * 2.6, 0.0)
	total_flash = maxf(total_flash - d * 3.0, 0.0)
	shown = lerpf(shown, float(total), 1.0 - pow(0.02, d))

	for w in waves:
		w.t += d
	waves = waves.filter(func(w): return w.t < w.life)
	for s in sparks:
		s.t += d
	sparks = sparks.filter(func(s): return s.t < s.life)
	for rf in ring_fx:
		rf.t += d
	ring_fx = ring_fx.filter(func(rf): return rf.t < rf.life)
	for p in pops:
		p.t += d
	pops = pops.filter(func(p): return p.t < p.life)

	card_v += (card_target - card_p) * 420.0 * d
	card_v *= exp(-17.0 * d)
	card_p = clampf(card_p + card_v * d, -0.35, 1.35)

	_panel_update(d)

	match state:
		S.AIM_V:
			gt += d * gs()
			aim.y = lerpf(BC.y - SWING, BC.y + SWING, tri(gt))
		S.AIM_H:
			gt += d * gs()
			aim.x = lerpf(BC.x - SWING, BC.x + SWING, tri(gt))
		S.CONFIRM:
			gt += d * gs()
			confirm_t += d
			if confirm_t >= ch():
				if cur_dart.get("magnet", 0.0) > 0.0:
					aim = aim.lerp(BC, cur_dart.magnet)
				state = S.FLY
				fly_t = 0.0
		S.FLY:
			fly_t += d
			if fly_t >= 0.2:
				_land()
		S.RESOLVE:
			qt -= d
			if qt <= 0.0:
				_next_step()

	queue_redraw()


func _auto_step() -> void:
	match state:
		S.PICK:
			_click(_mag_rect(randi() % maxi(remaining.size(), 1)).get_center())
		S.AIM_V, S.AIM_H:
			_advance()
		S.CLEAR:
			_click(Vector2(-1, -1))
		S.STAGE:
			_click(_stage_rect(randi() % stage_pick.size()).get_center())
		S.SHOP:
			var buyable := []
			for i in stock.size():
				if not stock[i].sold and gold >= stock[i].cost:
					buyable.append(i)
			var roll := randf()
			if not buyable.is_empty() and roll < 0.55:
				_click(_stock_rect(buyable[randi() % buyable.size()]).get_center())
			elif gold >= reroll_cost and roll < 0.8:
				_click(_reroll_rect().get_center())
			else:
				_click(_next_rect().get_center())
		S.OVER:
			_click(Vector2(320, 180))


func _advance() -> void:
	match state:
		S.AIM_V:
			state = S.AIM_H
			beep(300.0, 0.05, 0.10)
		S.AIM_H:
			state = S.CONFIRM
			confirm_t = 0.0
			beep(400.0, 0.06, 0.12)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey:
		var k := e as InputEventKey
		if k.pressed and not k.echo:
			match k.keycode:
				KEY_BRACKETLEFT:
					gauge_speed = maxf(gauge_speed - 0.05, 0.15)
				KEY_BRACKETRIGHT:
					gauge_speed = minf(gauge_speed + 0.05, 4.0)
				KEY_MINUS:
					beat = minf(beat + 0.03, 1.0)
				KEY_EQUAL:
					beat = maxf(beat - 0.03, 0.08)
				KEY_SEMICOLON:
					confirm_hold = maxf(confirm_hold - 0.05, 0.0)
				KEY_APOSTROPHE:
					confirm_hold = minf(confirm_hold + 0.05, 1.5)
				KEY_SPACE:
					if state == S.PICK:
						_pick_dart(0)
					else:
						_click(Vector2(-1, -1))
		return

	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_click(mb.position)


func _click(m: Vector2) -> void:
	match state:
		S.PICK:
			for i in remaining.size():
				if _mag_rect(i).has_point(m):
					_pick_dart(i)
					return
		S.AIM_V, S.AIM_H:
			_advance()
		S.CLEAR:
			# 좌표를 보지 않는다 — 아무 데나 누르든 스페이스든 상점으로 넘어간다
			_open_shop()
			return
		S.STAGE:
			for i in stage_pick.size():
				if _stage_rect(i).has_point(m):
					_pick_stage(i)
					return
		S.SHOP:
			for i in stock.size():
				if _stock_rect(i).has_point(m):
					_buy(i)
					return
			if _reroll_rect().has_point(m):
				_reroll()
			elif _next_rect().has_point(m):
				_next_round()
		S.OVER:
			_new_run()


# ══════════════════════════════════════════════════════════
#  판정 / 정산
# ══════════════════════════════════════════════════════════

func hit_info(p: Vector2) -> Dictionary:
	var v := p - BC
	var r := v.length()
	if r > R:
		return {"base": 0, "mult": 0, "sector": -1, "idx": -1, "r0": 0.0, "r1": 0.0}
	if r <= R * rt_bull_i:
		return {"base": 50, "mult": 1, "sector": 50, "idx": -1, "r0": 0.0, "r1": R * rt_bull_i}
	if r <= R * rt_bull_o:
		return {"base": 25, "mult": 1, "sector": 25, "idx": -1, "r0": 0.0, "r1": R * rt_bull_o}

	var ang := atan2(v.x, -v.y)
	if ang < 0.0:
		ang += TAU
	var idx := int(floor((ang + PI / 20.0) / (TAU / 20.0))) % 20
	var val: int = sectors[idx]

	var m := 1
	var r0 := R * rt_bull_o
	var r1 := R * rt_trp_in
	if r >= R * rt_dbl_in:
		m = 2
		r0 = R * rt_dbl_in
		r1 = R * DBL_OUT
	elif r >= R * rt_trp_in and r <= R * rt_trp_out:
		m = 3
		r0 = R * rt_trp_in
		r1 = R * rt_trp_out
	elif r > R * rt_trp_out:
		r0 = R * rt_trp_out
		r1 = R * rt_dbl_in

	return {"base": val, "mult": m, "sector": val, "idx": idx, "r0": r0, "r1": r1}


func _impact(info: Dictionary) -> void:
	var lbl := Vector2(0.0, 26.0) if aim.y < BC.y else Vector2(0.0, -24.0)

	var grade := 1
	if info.mult == 0:
		grade = 0
	elif info.sector == 50:
		grade = 5
	elif info.sector == 25:
		grade = 4
	elif info.mult == 3:
		grade = 3
	elif info.mult == 2:
		grade = 2

	match grade:
		0:
			shake = 1.5
			board_punch = 0.15
			hit_flash_amt = 0.25
			beep_seq([150.0], 0.0, 0.22, 0.11)
		1:
			shake = 3.0
			board_punch = 0.45
			hit_flash_amt = 0.4
			beep_seq([160.0], 0.0, 0.13, 0.19)
			add_wave(aim, 3.0, 24.0, C_TXT, 0.35, 1.0, 0.28)
		2:
			shake = 6.5
			board_punch = 0.8
			hitstop = 0.05
			hit_flash_amt = 0.7
			beep_seq([330.0, 330.0], 0.075, 0.11, 0.20)
			add_wave(aim, 3.0, 42.0, C_ACC, 0.75, 1.5, 0.40)
			add_ring_fx(R * rt_dbl_in, R * DBL_OUT, C_ACC, 0.50)
			pop(aim + lbl, "더블", C_ACC, 15, 0.8)
		3:
			shake = 9.5
			board_punch = 1.0
			hitstop = 0.09
			hit_flash_amt = 0.9
			beep_seq([330.0, 415.0, 494.0], 0.07, 0.12, 0.22)
			add_wave(aim, 3.0, 54.0, C_ACC, 0.85, 2.0, 0.45)
			add_wave(aim, 3.0, 32.0, C_TXT, 0.60, 1.0, 0.32)
			add_ring_fx(R * rt_trp_in, R * rt_trp_out, C_ACC, 0.55)
			pop(aim + lbl, "트리플", C_ACC, 17, 0.9)
		4:
			shake = 11.0
			board_punch = 1.0
			hitstop = 0.11
			hit_flash_amt = 0.9
			beep_seq([262.0, 392.0, 523.0], 0.07, 0.15, 0.24)
			add_wave(BC, R * rt_bull_o, R * 1.15, C_GREEN.lightened(0.45), 0.80, 2.0, 0.50)
			add_wave(BC, 4.0, 46.0, C_TXT, 0.70, 1.5, 0.35)
			add_sparks(10, R * rt_bull_o, R * 0.95, 12.0, C_GREEN.lightened(0.5), 0.42)
			pop(BC + Vector2(0.0, -34.0), "아우터 불", C_GREEN.lightened(0.55), 16, 0.9)
		5:
			shake = 15.0
			board_punch = 1.0
			hitstop = 0.15
			hit_flash_amt = 1.0
			screen_flash = 1.0
			beep_seq([262.0, 392.0, 523.0, 659.0], 0.07, 0.17, 0.26)
			add_wave(BC, R * rt_bull_i, R * 1.35, C_RED.lightened(0.45), 0.90, 2.5, 0.60)
			add_wave(BC, R * rt_bull_i, R * 0.90, C_ACC, 0.80, 2.0, 0.45)
			add_wave(BC, 3.0, 52.0, C_TXT, 0.80, 1.5, 0.32)
			add_sparks(16, R * rt_bull_i, R * 1.10, 16.0, C_ACC, 0.55)
			pop(BC + Vector2(0.0, -38.0), "불스아이", C_ACC, 20, 1.1)


func _land() -> void:
	if _autoplay:
		# 검증 실행은 보드 안에 고르게 꽂아서 라운드가 진행되게 한다
		var a := randf() * TAU
		aim = BC + Vector2(cos(a), sin(a)) * sqrt(randf()) * R * 0.95

	var info := hit_info(aim)
	if has_mod("dead") and info.sector == 20:
		info.base = 0
	if info.mult == 0:
		round_miss = true

	# 다트 특성
	var pierce_gain := 0
	if info.mult > 0:
		if cur_dart.get("fix1", false):
			info.mult = 1
		if cur_dart.get("mult", 0) != 0:
			info.mult = maxi(1, info.mult + cur_dart.mult)
		if cur_dart.get("pierce", false) and info.idx >= 0:
			var l: int = sectors[(info.idx + 19) % 20]
			var r: int = sectors[(info.idx + 1) % 20]
			pierce_gain = int((l + r) * 0.5)

	darts.append(aim)
	_impact(info)

	hit_flash = 1.0
	hit_idx = info.idx
	hit_r0 = info.r0
	hit_r1 = info.r1
	hit_bull = info.idx == -1 and info.mult > 0

	var same: bool = info.sector > 0 and info.sector == last_sector
	streak = streak + 1 if same else 0

	var ctx := {
		"sector": info.sector,
		"mult": info.mult,
		"miss": info.mult == 0,
		"left": aim.x < BC.x,
		"same": same,
		"first": dart_index == 0,
		"last": darts_left == 0,
		"streak": streak,
	}

	cur_chip = 0
	cur_mult = 0
	card_item = ""
	card_mode = 0
	pitch_step = 0
	queue.clear()

	card_side = -1 if aim.x > BC.x else 1
	card_y = 232.0 if aim.y < BC.y else 74.0
	card_target = 1.0

	var fired := []
	for i in owned.size():
		if i == sealed:
			continue
		if GameData.check(owned[i].c, ctx):
			fired.append(i)

	if info.mult == 0 and fired.is_empty():
		queue.append({"k": "miss"})
	else:
		if info.mult == 0:
			queue.append({"k": "miss"})
			queue.append({"k": "chip", "v": 0})
			queue.append({"k": "mult", "v": 1})
		else:
			queue.append({"k": "chip", "v": info.base})
			queue.append({"k": "mult", "v": info.mult})
		if pierce_gain > 0:
			queue.append({"k": "pierce", "v": pierce_gain})
		for i in fired:
			var it: Dictionary = owned[i]
			var amt: int = it.v * streak if it.k == "mult_streak" else it.v
			queue.append({"k": "item", "i": i, "kind": it.k, "v": amt,
					"lbl": "%s  %s" % [it.n, GameData.eff_text(it.k, amt)]})
		queue.append({"k": "total"})

	last_sector = info.sector
	dart_index += 1
	state = S.RESOLVE
	qt = beat * 1.1


func _next_step() -> void:
	if queue.is_empty():
		card_target = 0.0
		# 목표를 넘긴 순간 라운드 종료 — 남은 다트는 골드로 환산된다
		if total >= target or darts_left <= 0:
			_finish_round()
		else:
			_to_pick()
		return

	var st = queue.pop_front()
	qt = beat
	pitch_step += 1
	var f := 392.0 * pow(2.0, float(pitch_step) / 12.0)
	var cc := card_pos() + Vector2(CARD_W * 0.5, 12.0)

	match st.k:
		"miss":
			card_item = "빗나감"
			beep(180.0, 0.20, 0.14)
			qt = beat * 1.4
		"chip":
			cur_chip += st.v
			beep(f, 0.10, 0.16)
		"pierce":
			cur_chip += st.v
			card_item = "관통  점수 +%d" % st.v
			pop(cc, "+%d" % st.v, C_CHIP, 17, 0.9)
			beep(f, 0.11, 0.18)
		"mult":
			cur_mult = st.v
			beep(f, 0.10, 0.16)
		"item":
			_panel_fire(st.i)
			card_item = st.lbl
			match st.kind:
				"chip":
					cur_chip += st.v
				"mult", "mult_streak":
					cur_mult += st.v
				"xmult":
					cur_mult *= st.v
			var col: Color = C_CHIP if st.kind == "chip" else C_MULT
			pop(cc, GameData.eff_text(st.kind, st.v), col, 17, 0.9)
			beep(f, 0.11, 0.18)
			shake = 3.0
		"total":
			var was_short := total < target
			last_gain = cur_chip * cur_mult
			total += last_gain
			card_mode = 1
			total_flash = 1.0
			shake = 9.0
			board_punch = 1.0
			qt = beat * 2.6
			if was_short and total >= target:
				# 목표 돌파 — 라운드가 여기서 끝난다
				beep_seq([392.0, 523.0, 659.0, 784.0], 0.08, 0.26, 0.26)
				screen_flash = 0.7
				shake = 13.0
				pop(BC + Vector2(0.0, -46.0), "목표 달성", C_ACC, 22, 1.2)
				qt = beat * 3.4
			else:
				beep(196.0, 0.34, 0.26)


func pop(p: Vector2, txt: String, c: Color, sz: int, life: float) -> void:
	pops.append({"p": p, "txt": txt, "c": c, "sz": sz, "t": 0.0, "life": life})


# ══════════════════════════════════════════════════════════
#  UI 좌표 (그리기와 클릭 판정이 같은 값을 쓴다)
# ══════════════════════════════════════════════════════════

func _stage_rect(i: int) -> Rect2:
	return Rect2(Vector2(32.0 + i * 196.0, 112.0), Vector2(176.0, 152.0))


func _stock_rect(i: int) -> Rect2:
	return Rect2(Vector2(16.0 + i * 154.0, 104.0), Vector2(146.0, 132.0))


func _mag_rect(i: int) -> Rect2:
	return Rect2(Vector2(6.0, 72.0 + i * 32.0), Vector2(66.0, 28.0))


func _reroll_rect() -> Rect2:
	return Rect2(Vector2(32.0, 250.0), Vector2(152.0, 42.0))


func _next_rect() -> Rect2:
	return Rect2(Vector2(432.0, 250.0), Vector2(176.0, 42.0))


# ══════════════════════════════════════════════════════════
#  그리기
# ══════════════════════════════════════════════════════════

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), C_BG)
	draw_set_transform(Vector2(randf_range(-shake, shake), randf_range(-shake, shake)))

	_draw_board()
	_draw_fx()
	_draw_magazine()
	_draw_darts()
	_draw_aim()
	_draw_topbar()
	_panel_draw()
	_draw_card()
	_draw_pops()

	if state == S.CLEAR:
		_draw_clear()
	elif state == S.STAGE:
		_draw_stage()
	elif state == S.SHOP:
		_draw_shop()
	elif state == S.OVER:
		_draw_over()
	else:
		_draw_hint()

	draw_set_transform(Vector2.ZERO)
	if screen_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, VIEW), Color(1.0, 1.0, 1.0, screen_flash * 0.34))


func annulus_at(c: Vector2, ri: float, ro: float, a0: float, a1: float,
		seg: int = 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg + 1:
		var a := lerpf(a0, a1, float(i) / float(seg))
		pts.append(c + Vector2(sin(a), -cos(a)) * ro)
	for i in seg + 1:
		var a := lerpf(a1, a0, float(i) / float(seg))
		pts.append(c + Vector2(sin(a), -cos(a)) * ri)
	return pts


func annulus(ri: float, ro: float, a0: float, a1: float) -> PackedVector2Array:
	return annulus_at(BC, ri, ro, a0, a1)


func _draw_board() -> void:
	var sw := 18.0 * PI / 180.0
	var push := 1.0 + board_punch * 0.028

	draw_circle(BC, R * 1.07 * push, C_DARK.darkened(0.4))

	for i in 20:
		var a0 := i * sw - sw * 0.5
		var a1 := a0 + sw
		var base_c: Color = C_LIGHT if i % 2 == 0 else C_DARK
		var ring_c: Color = C_RED if i % 2 == 0 else C_GREEN
		draw_colored_polygon(annulus(R * rt_bull_o * push, R * rt_trp_in * push, a0, a1), base_c)
		draw_colored_polygon(annulus(R * rt_trp_out * push, R * rt_dbl_in * push, a0, a1), base_c)
		draw_colored_polygon(annulus(R * rt_trp_in * push, R * rt_trp_out * push, a0, a1), ring_c)
		draw_colored_polygon(annulus(R * rt_dbl_in * push, R * DBL_OUT * push, a0, a1), ring_c)

	for i in 20:
		var a := i * sw - sw * 0.5
		var dir := Vector2(sin(a), -cos(a))
		draw_line(BC + dir * R * rt_bull_o * push, BC + dir * R * push, C_WIRE, 1.0)

	draw_circle(BC, R * rt_bull_o * push, C_GREEN)
	draw_circle(BC, R * rt_bull_i * push, C_RED)

	if hit_flash > 0.0:
		var fc := Color(1.0, 1.0, 1.0, hit_flash * hit_flash_amt)
		if hit_bull:
			draw_circle(BC, hit_r1 * push, fc)
		elif hit_idx >= 0:
			var a0 := hit_idx * sw - sw * 0.5
			draw_colored_polygon(annulus(hit_r0 * push, hit_r1 * push, a0, a0 + sw), fc)

	for i in 20:
		var a := i * sw
		var p := BC + Vector2(sin(a), -cos(a)) * R * 1.13
		draw_string(font, p + Vector2(-14, 5), str(sectors[i]),
				HORIZONTAL_ALIGNMENT_CENTER, 28, 12, C_DIM)


func _draw_fx() -> void:
	for rf in ring_fx:
		var kr: float = rf.t / rf.life
		var mid: float = (rf.r0 + rf.r1) * 0.5
		var band: float = rf.r1 - rf.r0
		var base: Color = rf.col
		base.a = (1.0 - kr) * 0.40
		draw_arc(BC, mid, 0.0, TAU, 40, base, band)
		var lead: Color = rf.col.lightened(0.45)
		lead.a = 1.0 - kr
		var sa := kr * TAU * 1.3 - PI * 0.5
		draw_arc(BC, mid, sa, sa + 1.0, 14, lead, band)

	for w in waves:
		var kw: float = w.t / w.life
		var rad: float = lerpf(w.r0, w.r1, 1.0 - pow(1.0 - kw, 2.6))
		var cw: Color = w.col
		cw.a = (1.0 - kw) * w.a0
		draw_arc(w.p, rad, 0.0, TAU, 32, cw, w.w)

	for s in sparks:
		var ks: float = s.t / s.life
		var dist: float = lerpf(s.r0, s.r1, 1.0 - pow(1.0 - ks, 2.2))
		var dir := Vector2(cos(s.a), sin(s.a))
		var cs: Color = s.col
		cs.a = 1.0 - ks
		draw_line(BC + dir * dist, BC + dir * (dist + s.len), cs, 1.5)


func _draw_magazine() -> void:
	if state == S.CLEAR or state == S.SHOP or state == S.OVER:
		return

	var picking := state == S.PICK
	var head := "탄창 — 고르세요"
	if not picking:
		head = "▶ " + (cur_dart.n if not cur_dart.is_empty() else "표준")
	draw_string(font, Vector2(6, 62), head,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_ACC if picking else C_CHIP.lightened(0.25))

	for i in remaining.size():
		var r := _mag_rect(i)
		var d: Dictionary = remaining[i]
		var special: bool = d.id != "std"
		var body: Color = C_PANEL.lightened(0.16 if picking else 0.04)
		draw_rect(r, body)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 2)),
				C_CHIP.lightened(0.2) if special else C_DIM.darkened(0.4))
		draw_string(font, r.position + Vector2(0, 13), d.n,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11,
				C_TXT if picking else C_DIM)
		if special:
			draw_string(font, r.position + Vector2(0, 24), _dart_tag(d),
					HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, C_DIM)


func _dart_tag(d: Dictionary) -> String:
	if d.get("pierce", false):
		return "양옆 절반"
	if d.get("magnet", 0.0) > 0.0:
		return "중심 당김"
	if d.gauge < 1.0:
		return "느림 · 배수-1"
	if d.gauge > 1.0:
		return "빠름 · 배수+3"
	return ""


func _draw_darts() -> void:
	for d in darts:
		draw_line(d + Vector2(6, -10), d, C_TXT, 1.0)
		draw_circle(d, 2.5, C_ACC)


func _draw_aim() -> void:
	if state == S.AIM_V:
		draw_line(Vector2(BC.x - 168.0, aim.y), Vector2(BC.x + 168.0, aim.y), C_ACC, 1.0)
	elif state == S.AIM_H:
		draw_line(Vector2(BC.x - 168.0, aim.y), Vector2(BC.x + 168.0, aim.y),
				C_ACC.darkened(0.55), 1.0)
		draw_line(Vector2(aim.x, BC.y - 168.0), Vector2(aim.x, BC.y + 168.0), C_ACC, 1.0)
	elif state == S.CONFIRM:
		draw_line(Vector2(BC.x - 168.0, aim.y), Vector2(BC.x + 168.0, aim.y), C_ACC, 1.0)
		draw_line(Vector2(aim.x, BC.y - 168.0), Vector2(aim.x, BC.y + 168.0), C_ACC, 1.0)
		var e := 1.0 - pow(1.0 - clampf(confirm_t / maxf(ch(), 0.001), 0.0, 1.0), 3.0)
		draw_arc(aim, lerpf(22.0, 7.0, e), 0.0, TAU, 24, C_TXT, 1.0)
		draw_arc(aim, lerpf(30.0, 11.0, e), 0.0, TAU, 24, Color(C_TXT, 0.3), 1.0)
	elif state == S.FLY:
		var k := 1.0 - fly_t / 0.2
		draw_circle(aim, 3.0 + k * 26.0, Color(C_TXT, 0.2 + k * 0.55))


func _draw_topbar() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW.x, 18)), C_PANEL)
	draw_string(font, Vector2(8, 13), "R%d/%d" % [round_no, GameData.ROUNDS],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TXT)
	draw_string(font, Vector2(48, 13), "다트 %d" % darts_left,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_DIM)
	draw_gold_at(96.0, 13.0, str(gold), 11, C_GOLD)

	var bar := clampf(shown / float(target), 0.0, 1.0)
	draw_rect(Rect2(Vector2(146, 6), Vector2(360, 7)), C_BG)
	draw_rect(Rect2(Vector2(146, 6), Vector2(360.0 * bar, 7)), C_ACC)
	draw_string(font, Vector2(514, 13), "%d / %d" % [int(shown), target],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TXT)


# ══════════════════════════════════════════════════════════
#  칩 랙  (아이템 패널)
# ──────────────────────────────────────────────────────────
#  바깥과 닿는 곳은 이 넷뿐이다.
#    _panel_fire(i)    아이템이 발동할 때        (_next_step)
#    _panel_update(d)  매 프레임 진행           (_process)
#    _panel_draw()     매 프레임 그리기          (_draw, _draw_stage)
#    _panel_reset()    라운드 시작 시 정지        (_start_round)
#  owned / sealed 를 읽기만 하고 게임 상태는 건드리지 않는다.
#  그래서 이 구획만 지우고 다시 써도 나머지는 영향을 안 받는다.
#
#  아이템은 카지노 칩이다. 골드는 칩이 아니라 플라크로 그린다
#  (draw_gold). 원반과 직사각으로 형태를 갈라 둘을 안 헷갈리게 한다.
# ══════════════════════════════════════════════════════════

# 감각 조정은 이 표에서만 한다.
const PANEL := {
	# 배치
	"y": 21.0,           # 랙 위쪽
	"h": 46.0,           # 랙 높이
	"cell": 46.0,        # 칩 한 칸 폭
	"pad": 6.0,          # 랙 안쪽 여백
	"r": 15.0,           # 칩 반지름
	"chip_dy": -3.0,     # 칸 안에서 칩 중심을 얼마나 올릴지

	# 튀는 정도 — 사각 슬롯 때 값을 그대로 쓴다. 꽂는 곳만 바뀌었다.
	"kick": 7.4,         # 발동 순간 튀어오르는 힘
	"stiff": 190.0,      # 제자리로 당기는 힘 (클수록 빨리 진동)
	"damp": 9.0,         # 감쇠 (클수록 빨리 멈춘다)
	"rise": 9.0,         # 최대 몇 픽셀 떠오르는가

	# 원반에 맞는 변형 — 세로로 늘리면 원이 깨지므로 안 쓴다
	"swell": 0.13,       # 등방 부풀림
	"spin": 0.55,        # 스팟 회전량(rad)
	"lift": 2.6,         # 떠오를 때 드러나는 옆면 두께
	"shadow": 0.34,      # 그림자 진하기

	# 이름 표시
	"hot": 0.62,         # 발동 후 이름을 몇 초 보여줄지
}

# 등급(가격)별 칩 색 — 명도가 단조 하강해서 저해상도에서도 순서가 읽힌다
const CHIP_TIERS := [
	{"max": 4, "body": "ded5c0", "spot": "8d3b34", "edge": "b8ae97"},
	{"max": 7, "body": "7d5ad0", "spot": "e8dfc8", "edge": "5b3fa0"},
	{"max": 99, "body": "241e33", "spot": "f2b134", "edge": "4a3f66"},
]
const CHIP_SPOTS := [3, 6, 8]
const C_FELT := Color("16281f")

var slot_hot := []              # 발동 후 이름을 띄우는 잔여 시간


func _panel_ensure() -> void:
	# 슬롯 수는 아이템 보유 한계를 그대로 따라간다.
	var n: int = GameData.MAX_ITEMS
	if slot_pop.size() != n:
		slot_pop.resize(n)
		slot_vel.resize(n)
		slot_hot.resize(n)
		slot_pop.fill(0.0)
		slot_vel.fill(0.0)
		slot_hot.fill(0.0)


func _panel_reset() -> void:
	_panel_ensure()
	slot_pop.fill(0.0)
	slot_vel.fill(0.0)
	slot_hot.fill(0.0)


func _panel_fire(i: int) -> void:
	_panel_ensure()
	if i < 0 or i >= slot_pop.size():
		return
	slot_vel[i] = PANEL.kick
	slot_hot[i] = PANEL.hot


func _panel_update(d: float) -> void:
	_panel_ensure()
	for i in slot_pop.size():
		# 0 으로 당기는 스프링. 지나쳐서 반대로 눌리는 게 "통통" 의 정체다.
		slot_vel[i] -= slot_pop[i] * PANEL.stiff * d
		slot_vel[i] *= exp(-PANEL.damp * d)
		slot_pop[i] = clampf(slot_pop[i] + slot_vel[i] * d, -0.6, 1.4)
		slot_hot[i] = maxf(slot_hot[i] - d, 0.0)


func _panel_rect() -> Rect2:
	var n: int = GameData.MAX_ITEMS
	var w: float = PANEL.cell * n + PANEL.pad * 2.0
	return Rect2(Vector2((VIEW.x - w) * 0.5, PANEL.y), Vector2(w, PANEL.h))


func _slot_rect(i: int) -> Rect2:
	var pr := _panel_rect()
	return Rect2(Vector2(pr.position.x + PANEL.pad + i * PANEL.cell, pr.position.y),
			Vector2(PANEL.cell, pr.size.y))


func _chip_tier(cost: int) -> Dictionary:
	for t in CHIP_TIERS:
		if cost <= t.max:
			return t
	return CHIP_TIERS[CHIP_TIERS.size() - 1]


func draw_chip(c: Vector2, r: float, tier: Dictionary, spots: int, rot: float,
		lift: float, gold_ring: bool, dim: float) -> void:
	var body := Color(tier.body).darkened(dim)
	var edge := Color(tier.edge).darkened(dim)
	var spot := Color(tier.spot).darkened(dim)

	# 옆면 — 떠오를수록 두꺼워져서 원반이 실제로 들린 것처럼 보인다
	if lift > 0.05:
		draw_circle(c + Vector2(0.0, lift), r, edge.darkened(0.35))
	draw_circle(c, r, edge)
	draw_circle(c, r - 1.5, body)

	# 가장자리 스팟 — 바깥 반지름까지 나가야 실루엣이 갈려 칩으로 읽힌다
	var step := TAU / float(spots * 2)
	for i in spots:
		var a := rot + float(i) * step * 2.0
		draw_colored_polygon(annulus_at(c, r * 0.66, r, a - step * 0.42,
				a + step * 0.42, 3), spot)

	# 인레이 홈
	draw_arc(c, r * 0.58, 0.0, TAU, 18, edge.lightened(0.18), 1.0)
	if gold_ring:
		# 돈 버는 칩이라는 표식 — 매대에서 한눈에 잡히라고
		draw_arc(c, r - 0.5, 0.0, TAU, 22, C_GOLD, 1.0)


# ── 플라크 (통화) ─────────────────────────────────────────
#  칩보다 위 등급인 직사각 화폐판. 아이템이 원반이므로 통화는
#  직사각으로 형태를 갈랐다. 대각 광택과 어두운 옆면이 금속감의
#  전부라 둘 중 하나만 빼도 그냥 노란 네모가 된다.
func draw_plaque(p: Vector2, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(p + Vector2(0.0, h * 0.22), Vector2(w, h)), c.darkened(0.55))
	draw_rect(Rect2(p, Vector2(w, h)), c)
	draw_rect(Rect2(p + Vector2(1.0, 1.0), Vector2(w - 2.0, 1.0)), c.lightened(0.45))
	draw_line(p + Vector2(w * 0.18, h - 1.0), p + Vector2(w * 0.72, 1.0),
			c.lightened(0.5), 1.0)
	draw_rect(Rect2(p + Vector2(w * 0.28, h * 0.34), Vector2(w * 0.44, h * 0.3)),
			c.darkened(0.4))


func gold_w(n: String, size: int) -> float:
	return float(size) * 0.85 + 4.0 \
			+ font.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


# 왼쪽 정렬로 그리고 차지한 폭을 돌려준다 — 문장 중간에 끼워 넣을 때 쓴다.
func draw_gold_at(x: float, y: float, n: String, size: int, c: Color) -> float:
	var iw := float(size) * 0.85
	draw_plaque(Vector2(x, y - float(size) * 0.62), iw, iw * 0.64, c)
	draw_string(font, Vector2(x + iw + 4.0, y), n,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
	return gold_w(n, size)


func draw_gold(cx: float, y: float, n: String, size: int, c: Color) -> void:
	draw_gold_at(cx - gold_w(n, size) * 0.5, y, n, size, c)


func _panel_draw() -> void:
	_panel_ensure()
	var pr := _panel_rect()
	draw_rect(pr, C_FELT)
	draw_rect(Rect2(pr.position, Vector2(pr.size.x, 1.0)), C_FELT.lightened(0.14))

	for i in GameData.MAX_ITEMS:
		if i < owned.size():
			_panel_slot(i)
		else:
			# 딜러 칩 랙의 빈 홈
			var e := _slot_rect(i).get_center() + Vector2(0.0, PANEL.chip_dy)
			draw_circle(e, PANEL.r * 0.72, C_FELT.darkened(0.45))
			draw_arc(e, PANEL.r * 0.72, 0.0, TAU, 16, C_FELT.lightened(0.10), 1.0)


func _panel_slot(i: int) -> void:
	var it: Dictionary = owned[i]
	var lock: bool = i == sealed
	var cell := _slot_rect(i)
	var bounce: float = slot_pop[i]
	var up: float = maxf(bounce, 0.0)

	var c := cell.get_center() + Vector2(0.0, PANEL.chip_dy - bounce * PANEL.rise)
	var r: float = PANEL.r * (1.0 + bounce * PANEL.swell)

	if up > 0.01:
		draw_circle(c + Vector2(1.5, 3.0 + up * PANEL.lift), r,
				Color(0.0, 0.0, 0.0, up * PANEL.shadow))

	draw_chip(c, r, _chip_tier(it.cost), CHIP_SPOTS[CHIP_TIERS.find(_chip_tier(it.cost))],
			bounce * PANEL.spin, up * PANEL.lift,
			it.get("g", "") != "" and not lock, 0.55 if lock else 0.0)

	# 인레이 숫자 — 효과 수치만. 색으로 점수인지 배수인지 가른다
	var val := str(it.v)
	if it.k == "xmult":
		val = "×" + str(it.v)
	var ink: Color = C_CHIP.lightened(0.5) if it.k == "chip" else C_MULT.lightened(0.45)
	draw_string(font, c + Vector2(-r, 4.0), val,
			HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 12,
			ink.darkened(0.55) if lock else ink)

	# 평소엔 조건 태그, 발동 직후엔 이름 — 자리를 옮기지 않고 덮어쓴다
	var tag := GameData.gold_tag(it.get("g", "")) if it.get("g", "") != "" else ""
	if tag == "":
		tag = GameData.cond_text(it.c).replace(" 명중 시", "").replace(" 시", "")
	var label := tag
	var col: Color = C_DIM.darkened(0.15)
	if lock:
		label = "봉인"
		col = C_MULT.darkened(0.2)
	elif slot_hot[i] > 0.0:
		label = it.n
		col = C_TXT
	draw_string(font, cell.position + Vector2(0.0, cell.size.y - 3.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, cell.size.x, 9, col)


func _draw_card() -> void:
	if card_p <= 0.004:
		return
	var p := card_pos()
	draw_rect(Rect2(p + Vector2(3, 4), Vector2(CARD_W, CARD_H)), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(p, Vector2(CARD_W, CARD_H)), C_PANEL)
	draw_rect(Rect2(p, Vector2(CARD_W, 3)), C_ACC)

	if card_mode == 0:
		draw_rect(Rect2(p + Vector2(12, 18), Vector2(98, 44)), C_CHIP.darkened(0.55))
		draw_string(font, p + Vector2(12, 48), str(cur_chip),
				HORIZONTAL_ALIGNMENT_CENTER, 98, 24, C_CHIP.lightened(0.45))
		draw_string(font, p + Vector2(12, 60), "점수",
				HORIZONTAL_ALIGNMENT_CENTER, 98, 9, C_DIM)
		draw_string(font, p + Vector2(110, 46), "×",
				HORIZONTAL_ALIGNMENT_CENTER, 24, 17, C_DIM)
		draw_rect(Rect2(p + Vector2(134, 18), Vector2(98, 44)), C_MULT.darkened(0.55))
		draw_string(font, p + Vector2(134, 48), str(cur_mult),
				HORIZONTAL_ALIGNMENT_CENTER, 98, 24, C_MULT.lightened(0.45))
		draw_string(font, p + Vector2(134, 60), "배수",
				HORIZONTAL_ALIGNMENT_CENTER, 98, 9, C_DIM)
		if card_item != "":
			draw_string(font, p + Vector2(10, 84), card_item,
					HORIZONTAL_ALIGNMENT_CENTER, CARD_W - 20, 11, C_TXT)
	else:
		var sz := int(34.0 * (1.0 + 0.55 * total_flash))
		draw_string(font, p + Vector2(0, 58), "+" + str(last_gain),
				HORIZONTAL_ALIGNMENT_CENTER, CARD_W, sz, C_ACC)
		draw_string(font, p + Vector2(0, 80), "%d × %d" % [cur_chip, cur_mult],
				HORIZONTAL_ALIGNMENT_CENTER, CARD_W, 11, C_DIM)


func _draw_pops() -> void:
	for p in pops:
		var k: float = p.t / p.life
		var y: float = p.p.y - k * 24.0
		var sz: int = int(p.sz * (1.0 + 0.45 * exp(-p.t * 12.0)))
		var c: Color = p.c
		c.a = clampf(1.0 - k * k, 0.0, 1.0)
		draw_string(font, Vector2(p.p.x - 60.0, y), p.txt,
				HORIZONTAL_ALIGNMENT_CENTER, 120, sz, c)


func _scrim() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.04, 0.03, 0.07, 0.94))


func _btn(r: Rect2, label: String, sub: String, on: bool) -> void:
	draw_rect(r, C_PANEL.lightened(0.10) if on else C_PANEL.darkened(0.2))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), C_ACC if on else C_DIM.darkened(0.5))
	draw_string(font, r.position + Vector2(0, 20), label,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, C_TXT if on else C_DIM)
	if sub != "":
		draw_string(font, r.position + Vector2(0, 35), sub,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, C_GOLD if on else C_DIM.darkened(0.3))


func _draw_clear() -> void:
	_scrim()
	draw_string(font, Vector2(0, 46), "라운드 %d 클리어" % round_no,
			HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 22, C_ACC)

	var y := 74.0
	for row in clear_gold_detail:
		draw_string(font, Vector2(210, y), row.n, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_DIM)
		draw_gold_at(340.0, y, "+%d" % row.v, 12, C_GOLD)
		y += 17.0

	# 내역 아래에 합계선을 긋고 보유액을 크게 — 3택1이 있던 자리다
	draw_rect(Rect2(Vector2(210, y + 4), Vector2(174, 1)), C_WIRE.darkened(0.4))
	draw_gold(VIEW.x * 0.5, y + 36.0, str(gold), 22, C_GOLD)

	_btn(Rect2(Vector2(232, 258), Vector2(176, 42)), "상점으로", "아무 키", true)


func _draw_stage() -> void:
	# 보드가 비쳐 보이게 얇게 덮는다 — 개조 상태를 확인하면서 고르라고
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.04, 0.03, 0.07, 0.80))

	# 아이템 패널이 y 21~65 를 차지하므로 그 아래에서 시작한다
	var s_pre := "라운드 %d / %d    " % [round_no, GameData.ROUNDS]
	var s_post := "    아이템 %d / %d" % [owned.size(), GameData.MAX_ITEMS]
	var w_pre := font.get_string_size(s_pre, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var w_post := font.get_string_size(s_post, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var sx := (VIEW.x - (w_pre + gold_w(str(gold), 11) + w_post)) * 0.5
	draw_string(font, Vector2(sx, 82), s_pre, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_DIM)
	sx += w_pre + draw_gold_at(sx + w_pre, 82.0, str(gold), 11, C_GOLD)
	draw_string(font, Vector2(sx, 82), s_post, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_DIM)
	draw_string(font, Vector2(0, 98), "제약이 셀수록 상점 자금이 커진다",
			HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 10, C_DIM.darkened(0.2))

	for i in stage_pick.size():
		var r := _stage_rect(i)
		var sp: Dictionary = stage_pick[i]
		var tone: Color = [C_GREEN, C_ACC, C_MULT][i]

		draw_rect(r, C_PANEL.lightened(0.10))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), tone)

		draw_string(font, r.position + Vector2(0, 24), sp.d.n,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, C_TXT)
		draw_string(font, r.position + Vector2(0, 38), sp.d.sub,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, C_DIM)

		draw_string(font, r.position + Vector2(0, 66), str(sp.target),
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, tone.lightened(0.3))
		draw_string(font, r.position + Vector2(0, 78), "목표 점수",
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, C_DIM)

		var y := 98.0
		for m in sp.mods:
			draw_string(font, r.position + Vector2(8, y), "· " + m.n,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_MULT.lightened(0.25))
			draw_string(font, r.position + Vector2(8, y + 11), "  " + m.d,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 8, C_DIM)
			y += 24.0

		var rw := "보상 없음"
		if sp.d.gold > 0:
			rw = "+%d" % sp.d.gold
		if sp.d.item:
			rw += "  ·  아이템 1개"
		draw_string(font, r.position + Vector2(0, r.size.y - 10), rw,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x,
				11, C_GOLD if sp.d.gold > 0 else C_DIM)

	_panel_draw()

	draw_string(font, Vector2(0, 292), "판을 눌러 시작",
			HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 11, C_TXT)
	draw_string(font, Vector2(0, 312), "뒤에 보이는 보드가 지금 네 보드다",
			HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 9, C_DIM.darkened(0.25))


func _draw_shop() -> void:
	_scrim()
	draw_string(font, Vector2(0, 40), "상점", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 20, C_ACC)
	var gc: Color = C_GOLD.lerp(C_MULT, deny_flash)
	var gx := randf_range(-deny_flash, deny_flash) * 3.0
	var h_post := "    아이템 %d / %d" % [owned.size(), GameData.MAX_ITEMS]
	var h_w := font.get_string_size(h_post, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var hx := gx + (VIEW.x - (gold_w(str(gold), 12) + h_w)) * 0.5
	hx += draw_gold_at(hx, 62.0, str(gold), 12, gc)
	draw_string(font, Vector2(hx, 62), h_post, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, gc)
	if deny_flash > 0.0:
		draw_string(font, Vector2(0, 300), "골드가 부족하거나 슬롯이 꽉 찼다",
				HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 11,
				Color(C_MULT.lightened(0.3), deny_flash))
	draw_string(font, Vector2(0, 80), "탄창  " + _mag_text(),
			HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 10, C_CHIP.lightened(0.25))
	for i in stock.size():
		var r := _stock_rect(i)
		var s: Dictionary = stock[i]
		var can: bool = not s.sold and gold >= s.cost
		draw_rect(r, C_PANEL.lightened(0.02) if s.sold else C_PANEL.lightened(0.10))
		var top: Color = C_DIM.darkened(0.5)
		if not s.sold:
			top = C_ACC
			if s.type == "mod":
				top = C_CHIP.lightened(0.2)
			elif s.type == "dart":
				top = C_GREEN.lightened(0.3)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), top)

		if s.sold:
			draw_string(font, r.position + Vector2(0, 70), "구매함",
					HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, C_DIM.darkened(0.3))
			continue

		var kind := "아이템"
		if s.type == "mod":
			kind = "보드 개조"
		elif s.type == "dart":
			kind = "다트"
		draw_string(font, r.position + Vector2(0, 24), kind,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, C_DIM)
		draw_string(font, r.position + Vector2(0, 52), s.d.n,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, C_TXT if can else C_DIM)
		var desc: String = GameData.item_desc(s.d) if s.type == "item" else s.d.d
		draw_string(font, r.position + Vector2(8, 82), desc,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 16, 10, C_DIM)
		# 골드 칩은 정산 때 따로 도는 반쪽이 있다 — 금색 줄로 분리해 보여준다
		if s.type == "item" and s.d.get("g", "") != "":
			draw_string(font, r.position + Vector2(8, 98),
					GameData.gold_text(s.d.g, s.d.gv),
					HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 16, 9, C_GOLD.darkened(0.15))
		draw_gold(r.position.x + r.size.x * 0.5, r.position.y + 116.0, str(s.cost), 14,
				C_GOLD if can else C_DIM.darkened(0.3))

	_btn(_reroll_rect(), "리롤", "무료" if reroll_cost == 0 else "", gold >= reroll_cost)
	if reroll_cost > 0:
		var rr := _reroll_rect()
		draw_gold(rr.position.x + rr.size.x * 0.5, rr.position.y + 35.0,
				str(reroll_cost), 10, C_GOLD if gold >= reroll_cost else C_DIM.darkened(0.3))
	_btn(_next_rect(), "다음 라운드 →", "R%d  목표 %d"
			% [round_no + 1, GameData.target_of(round_no + 1)], true)

	draw_string(font, Vector2(0, 316), "카드를 눌러 구매",
			HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 10, C_DIM.darkened(0.2))


func _draw_over() -> void:
	_scrim()
	if won:
		draw_string(font, Vector2(0, 150), "완주!", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 34, C_ACC)
		draw_string(font, Vector2(0, 186), "%d개 라운드를 모두 넘겼다" % GameData.ROUNDS,
				HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 13, C_TXT)
	else:
		draw_string(font, Vector2(0, 150), "실패", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 34, C_MULT)
		draw_string(font, Vector2(0, 186), "라운드 %d — %d / %d" % [round_no, total, target],
				HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 13, C_TXT)
	draw_string(font, Vector2(0, 226), "클릭 → 새 런", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 12, C_DIM)


func _draw_hint() -> void:
	var hint := ""
	match state:
		S.PICK:
			hint = "던질 다트를 고르세요"
		S.AIM_V:
			hint = "클릭 → 높이 결정"
		S.AIM_H:
			hint = "클릭 → 좌우 결정"
		S.CONFIRM:
			hint = "조준 확인"
	if hint != "":
		draw_string(font, Vector2(0, 348), hint,
				HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 12, C_ACC)
	if not active_mods.is_empty():
		var names := []
		for m in active_mods:
			names.append(m.n)
		draw_string(font, Vector2(8, 334), "제약  " + "  ·  ".join(names),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_MULT.lightened(0.25))

	draw_string(font, Vector2(8, 356), "[ ] 조준 %.2f    - = 정산 %.2f    ; ' 확인텀 %.2f"
			% [gauge_speed, beat, confirm_hold], HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			C_DIM.darkened(0.25))
