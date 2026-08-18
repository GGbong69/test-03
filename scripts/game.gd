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

# ══════════════════════════════════════════════════════════
#  HUD 배치표
#  화면 좌표는 전부 여기서만 정한다. 각 판 구획은 자기 줄만 읽는다.
#  줄을 지우고 _hud_draw() 의 호출 한 줄을 지우면 그 판만 사라진다.
#  (매대·스테이지 카드·점수 카드·진행바는 기존 좌표 함수 그대로 둔다)
# ══════════════════════════════════════════════════════════
const LAY := {
	"bar":        Rect2(0.0, 0.0, 640.0, 18.0),
	"bar_cut":    [100.0, 584.0],
	"bar_pip":    Rect2(44.0, 7.0, 5.0, 5.0),
	"bar_pip_dx": 7.0,
	"bar_gauge":  Rect2(146.0, 6.0, 360.0, 7.0),
	"bar_score":  514.0,
	"bar_mod":    588.0,

	"bank":       Rect2(4.0, 21.0, 72.0, 46.0),
	"sell":       Rect2(80.0, 21.0, 74.0, 46.0),
	"cap":        Rect2(445.0, 21.0, 37.0, 46.0),

	"mag":        Rect2(4.0, 71.0, 72.0, 228.0),
	"mag_hand":   Rect2(8.0, 88.0, 64.0, 18.0),
	"mag_slot":   Rect2(8.0, 110.0, 64.0, 27.0),
	"mag_dy":     31.0,

	"strip":      Rect2(160.0, 71.0, 320.0, 25.0),
	"strip_x0":   206.0,
	"strip_dx":   44.0,
}

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
	@warning_ignore("integer_division")  # 보유 5당 1, 내림이 규칙이다
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
	if stage_item and stage_slots < GameData.MAX_ITEMS \
			and owned.size() < GameData.MAX_ITEMS:
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
	# 라운드가 끝났다. 상점에 랙이 서므로 안 지우면 지난 판 "봉인" 딱지가
	# 유령으로 남는다. _gold_from_items() 가 sealed 를 읽으므로
	# _finish_round 안에서는 지우면 안 된다 — 여기가 유일하게 안전한 지점이다.
	sealed = -1
	sell_sel = -1
	_panel_reset()
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
	# 봉인은 _start_round 에서만 다시 뽑힌다. 지우지 않으면 스테이지 선택
	# 화면의 칩 랙이 지난 라운드 봉인을 그대로 보여준다.
	sealed = -1
	sell_sel = -1
	# 극한 무료 아이템은 "고르기 전에 자리가 있었는가" 로 판정한다. 이 스냅샷이
	# 없으면 [스테이지에서 잉여칩 판매 → 극한 선택 → 무료 칩으로 리필] 이
	# 골드까지 받으면서 도는 무손실 루프가 된다.
	stage_slots = owned.size()
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

	if sell_sel >= 0:
		sell_t += d
		if not _can_sell() or sell_sel >= owned.size():
			sell_sel = -1
	_tip_update(d)
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
			if _sell_hit(m):
				return
			for i in stage_pick.size():
				if _stage_rect(i).has_point(m):
					_pick_stage(i)
					return
		S.SHOP:
			if _sell_hit(m):
				return
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
	# 툴팁이 대상 테두리만 같이 흔들고 판은 고정하려면 이 값을 알아야 한다
	var sh := Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	draw_set_transform(sh)

	_draw_board()
	_draw_fx()
	_draw_darts()
	_draw_aim()
	_draw_card()

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

	# 화면이 바뀌어도 같은 자리에 남는 것만 판이다 — 그래서 스크림 뒤에 그린다.
	_hud_draw()
	_tip_draw(sh)
	draw_set_transform(Vector2.ZERO)
	if screen_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, VIEW), Color(1.0, 1.0, 1.0, screen_flash * 0.34))


# ══════════════════════════════════════════════════════════
#  HUD 배급기
# ──────────────────────────────────────────────────────────
#  상태별 노출은 여기 한 곳에만 있다. 각 판은 자기 그리기만 안다.
# ══════════════════════════════════════════════════════════

func _is_play() -> bool:
	return state == S.PICK or state == S.AIM_V or state == S.AIM_H \
			or state == S.CONFIRM or state == S.FLY or state == S.RESOLVE


func _hud_draw() -> void:
	if state == S.OVER:
		return
	_draw_topbar()
	if state != S.CLEAR:            # 정산 화면은 그 자체가 명세다
		_bank_draw()
		if _can_sell():
			_sell_draw()
		_panel_draw()
		_cap_draw()
		if _is_play():
			_draw_magazine()
	# 판매 팝업이 스크림(알파 0.94) 밑에 깔리면 안 보인다 — 판 다음에 그린다.
	_draw_pops()


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
		draw_line(Vector2(aim.x, 70.0), Vector2(aim.x, 336.0), C_ACC, 1.0)
	elif state == S.CONFIRM:
		draw_line(Vector2(BC.x - 168.0, aim.y), Vector2(BC.x + 168.0, aim.y), C_ACC, 1.0)
		draw_line(Vector2(aim.x, 70.0), Vector2(aim.x, 336.0), C_ACC, 1.0)
		var e := 1.0 - pow(1.0 - clampf(confirm_t / maxf(ch(), 0.001), 0.0, 1.0), 3.0)
		draw_arc(aim, lerpf(22.0, 7.0, e), 0.0, TAU, 24, C_TXT, 1.0)
		draw_arc(aim, lerpf(30.0, 11.0, e), 0.0, TAU, 24, Color(C_TXT, 0.3), 1.0)
	elif state == S.FLY:
		var k := 1.0 - fly_t / 0.2
		draw_circle(aim, 3.0 + k * 26.0, Color(C_TXT, 0.2 + k * 0.55))


func _draw_topbar() -> void:
	var r: Rect2 = LAY.bar
	draw_rect(r, C_PANEL)
	draw_rect(Rect2(Vector2(0.0, r.size.y - 1.0), Vector2(r.size.x, 1.0)), C_BG)
	# 1px 두 줄이 "칸이 나뉘어 있다"를 만드는 전부다. 640x360 에서 테두리는 사치다.
	for cx in LAY.bar_cut:
		draw_line(Vector2(cx, 3.0), Vector2(cx, 15.0), C_BG, 1.0)

	# 1칸 x[0,100] — 런 진행
	draw_string(font, Vector2(8, 13), "R%d/%d" % [round_no, GameData.ROUNDS],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TXT)
	var done: int = round_no if (state == S.CLEAR or state == S.SHOP) else round_no - 1
	var pip: Rect2 = LAY.bar_pip
	for i in GameData.ROUNDS:
		var q := Rect2(pip.position + Vector2(float(i) * LAY.bar_pip_dx, 0.0), pip.size)
		if i < done:
			draw_rect(q, C_ACC)
		elif i == done:
			draw_rect(q, C_ACC.darkened(0.62))
			draw_rect(q, C_ACC, false, 1.0)
		else:
			draw_rect(q, C_BG)

	# 2칸 x[100,584] — 목표. 진행바 좌표는 기존 그대로다.
	var g: Rect2 = LAY.bar_gauge
	draw_string(font, Vector2(108, 13), "목표",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, C_DIM.darkened(0.2))
	draw_rect(g, C_BG)
	if state == S.SHOP or state == S.STAGE:
		# STAGE 에서 목표 숫자를 쓰면 안 된다 — 등급 배수(극한 ×1.25)가
		# 아직 안 정해졌고 카드 셋이 서로 다른 숫자를 이미 크게 띄운다.
		var msg := "판을 고르는 중"
		if state == S.SHOP:
			msg = "다음 R%d  ·  목표 %d" % [round_no + 1, GameData.target_of(round_no + 1)]
		draw_string(font, Vector2(g.position.x, 13.0), msg,
				HORIZONTAL_ALIGNMENT_CENTER, g.size.x, 10, C_DIM)
	else:
		var k := clampf(shown / float(maxi(target, 1)), 0.0, 1.0)
		draw_rect(Rect2(g.position, Vector2(g.size.x * k, g.size.y)), C_ACC)
		draw_string(font, Vector2(LAY.bar_score, 13.0), "%d / %d" % [int(shown), target],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TXT)

	# 3칸 x[584,640] — 이번 판 제약 수. 이름 전체는 하단 y341 줄이 갖는다.
	# active_mods 는 _pick_stage 에서만 갈리므로 SHOP 에는 지난 판 값이 남는다.
	if _is_play() and not active_mods.is_empty():
		draw_string(font, Vector2(LAY.bar_mod, 13.0), "제약 %d" % active_mods.size(),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_MULT.lightened(0.25))


# ── 자금 ──────────────────────────────────────────────────
func _bank_draw() -> void:
	var r: Rect2 = LAY.bank
	draw_rect(r, C_PANEL)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), C_GOLD.darkened(0.35))
	draw_string(font, r.position + Vector2(5.0, 12.0), "자금",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, C_DIM.darkened(0.15))

	# deny_flash 는 상점 중앙 골드 텍스트가 쓰던 값을 그대로 물려받는다
	var gc: Color = C_GOLD.lerp(C_MULT, deny_flash)
	var jx := randf_range(-deny_flash, deny_flash) * 2.0
	draw_gold(r.get_center().x + jx, r.position.y + 30.0, str(gold), 16, gc)

	# 이자 미리보기. 계산식은 _finish_round 와 같고 둘 다 지급 전 잔액을 본다.
	if state == S.SHOP and round_no + 1 >= GameData.ROUNDS:
		# R8 은 정산이 없다 (_finish_round 의 round_no >= ROUNDS 조기 return 이
		# 골드 지급 블록보다 앞선다). 남긴 골드는 영원히 안 돌아온다.
		draw_string(font, r.position + Vector2(0.0, 42.0), "마지막 판",
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, C_MULT.lightened(0.2))
	else:
		@warning_ignore("integer_division")  # 위 _finish_round 와 같은 식이어야 한다
		var itr: int = mini(gold / GameData.INTEREST_PER, GameData.INTEREST_MAX)
		draw_string(font, r.position + Vector2(0.0, 42.0), "이자 +%d" % itr,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9,
				C_GOLD.darkened(0.3) if itr > 0 else C_DIM.darkened(0.35))


# ── 칩 꼬리표 ─────────────────────────────────────────────
func _cap_draw() -> void:
	var r: Rect2 = LAY.cap
	draw_rect(r, C_FELT)                                   # 랙과 같은 재질
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), C_FELT.lightened(0.14))
	draw_string(font, r.position + Vector2(0.0, 20.0), "칩",
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, C_DIM.darkened(0.1))
	draw_string(font, r.position + Vector2(0.0, 36.0),
			"%d/%d" % [owned.size(), GameData.MAX_ITEMS],
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13,
			C_ACC if owned.size() >= GameData.MAX_ITEMS else C_TXT)


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


func _chip_ti(cost: int) -> int:
	for i in CHIP_TIERS.size():
		if cost <= CHIP_TIERS[i].max:
			return i
	return CHIP_TIERS.size() - 1


# 아이템 하나를 칩으로 그린다. 랙과 상점이 같은 그림을 쓰도록 여기 하나로 모았다.
func draw_item_chip(c: Vector2, r: float, it: Dictionary, rot: float, lift: float,
		dim: float, num_sz: int) -> void:
	var ti := _chip_ti(it.cost)
	draw_chip(c, r, CHIP_TIERS[ti], CHIP_SPOTS[ti], rot, lift,
			it.get("g", "") != "", dim)
	var val := ("×" + str(it.v)) if it.k == "xmult" else str(it.v)
	var ink: Color = C_CHIP.lightened(0.5) if it.k == "chip" else C_MULT.lightened(0.45)
	draw_string(font, c + Vector2(-r, float(num_sz) * 0.34), val,
			HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, num_sz, ink.darkened(dim))


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

	var sel: bool = i == sell_sel and _can_sell()
	var c := cell.get_center() + Vector2(0.0,
			PANEL.chip_dy - bounce * PANEL.rise - (4.0 if sel else 0.0))
	var r: float = PANEL.r * (1.0 + bounce * PANEL.swell)

	if up > 0.01:
		draw_circle(c + Vector2(1.5, 3.0 + up * PANEL.lift), r,
				Color(0.0, 0.0, 0.0, up * PANEL.shadow))

	draw_item_chip(c, r, it, bounce * PANEL.spin, up * PANEL.lift,
			0.55 if lock else 0.0, 12)

	# 호버 링 — 리프트는 안 쓴다. 발동 스프링의 실제 최대 리프트가 3px 뿐이라
	# 호버까지 들어올리면 두 어휘가 뒤집힌다. 링은 하나만 그린다 — 폭 1.0 짜리
	# 둘을 겹치면 nearest 에서 한 덩어리 띠로 뭉개져 상태가 안 갈린다.
	if sel:
		var k := 0.5 + 0.5 * sin(sell_t * 9.0)
		draw_arc(c, r + 2.0, 0.0, TAU, 24,
				Color(C_MULT.lightened(0.25), 0.45 + 0.55 * k), 1.0)
	elif i == tip_slot and tip_a > 0.004:
		draw_arc(c, r + 2.0, 0.0, TAU, 24, Color(C_ACC, tip_a), 1.0)

	# 상점·스테이지에서는 랙이 매물대가 된다 — 태그 자리에 회수액을 건다.
	if _can_sell():
		draw_gold(cell.get_center().x, cell.position.y + cell.size.y - 3.0,
				str(GameData.sell_value(it)), 9,
				C_ACC if sel else C_GOLD.darkened(0.30))
		return

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



# ══════════════════════════════════════════════════════════
#  판매 (칩 랙 → 골드)
# ──────────────────────────────────────────────────────────
#  바깥과 닿는 곳은 넷뿐이다.
#    _sell_hit(m)   랙·판매판 클릭 판정   (_click 의 S.SHOP / S.STAGE)
#    _sell_draw()   판매판 그리기         (_hud_draw)
#    _can_sell()    지금 팔 수 있는가      (_panel_slot / _tip_build / _process)
#    sell_sel       고른 칸 (-1 = 없음)
#
#  두 번 눌러야 팔린다. 첫 클릭은 칩(랙 안), 두 번째는 판매판(x[80,154])이다.
#  두 표적이 물리적으로 갈려 있어 더블클릭이 판매로 흘러들 수 없다 —
#  같은 자리를 두 번 누르는 방식이었다면 필요했을 타이머가 여기선 필요 없다.
#  판매판이 자금 판 바로 옆인 것도 의도다. 파는 건 물건 옆이 아니라 지갑 옆이다.
#
#  S.CLEAR 에는 절대 붙이지 않는다 — 정산 지급(_finish_round 의 gold +=)이
#  이미 끝난 시점이라 골드 칩의 "받고 즉시 되팔기" 창이 열린다.
# ══════════════════════════════════════════════════════════

var sell_sel := -1
var sell_t := 0.0               # 선택 링 맥동에만 쓴다
var stage_slots := 0            # 스테이지 화면에 들어설 때의 칩 개수


func _can_sell() -> bool:
	# R8 스테이지에서는 골드를 쓸 곳이 수학적으로 0개다 — 정산도(조기 return)
	# 상점도 없고 슬롯을 비워도 채울 무료 아이템이 안 나온다. 기대값이 음수뿐이다.
	if state == S.STAGE and round_no >= GameData.ROUNDS:
		return false
	return state == S.SHOP or state == S.STAGE


func _sell_hit(m: Vector2) -> bool:
	# 랙 y[21,67] 은 매대 y[104,236] · 스테이지 카드 y[112,264] 와 y 로 갈려
	# 있어 먼저 검사해도 그쪽 클릭을 훔칠 수 없다.
	if not _can_sell():
		return false
	if sell_sel >= 0 and sell_sel < owned.size() and LAY.sell.has_point(m):
		_sell(sell_sel)
		return true
	for i in GameData.MAX_ITEMS:
		if _slot_rect(i).has_point(m):
			sell_sel = -1 if (sell_sel == i or i >= owned.size()) else i
			sell_t = 0.0
			beep(349.0, 0.05, 0.10)
			return true
	sell_sel = -1                   # 딴 데를 누르면 선택만 풀고 그대로 흘려보낸다
	return false


func _sell(i: int) -> void:
	if i < 0 or i >= owned.size():
		return
	var v := GameData.sell_value(owned[i])
	var at := _slot_rect(i).get_center()
	gold += v
	owned.remove_at(i)
	sell_sel = -1
	# sealed 는 owned 의 인덱스다. 판매는 SHOP/STAGE 에서만 일어나고 두 화면
	# 모두 진입할 때 -1 로 지우므로 이미 -1 이지만, 인덱스가 밀린 뒤에 남아
	# 있으면 엉뚱한 칩이 봉인으로 보인다. 여기서도 못 박는다.
	sealed = -1
	# slot_pop/slot_vel/slot_hot 은 owned 와 인덱스를 공유하고 _panel_ensure 는
	# 크기만 맞출 뿐 내용을 안 옮긴다. 이 두 화면에서는 스프링이 전부 정지
	# 상태라 0 으로 돌리는 것이 옮기는 것과 같은 결과이고 더 안전하다.
	_panel_reset()
	pop(at + Vector2(0.0, -14.0), "+%d" % v, C_GOLD, 15, 0.8)
	beep_seq([659.0, 880.0], 0.06, 0.09, 0.18)


func _sell_draw() -> void:
	var r: Rect2 = LAY.sell
	var live: bool = sell_sel >= 0 and sell_sel < owned.size()
	draw_rect(r, C_PANEL.lightened(0.10) if live else C_PANEL)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)),
			C_ACC if live else C_WIRE.darkened(0.35))
	if not live:
		draw_string(font, r.position + Vector2(0.0, 21.0), "판매",
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, C_DIM.darkened(0.1))
		draw_string(font, r.position + Vector2(0.0, 36.0), "칩을 고르세요",
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, C_DIM.darkened(0.35))
		return
	draw_string(font, r.position + Vector2(0.0, 21.0), "팔기",
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, C_TXT)
	draw_gold(r.get_center().x, r.position.y + 38.0,
			"+%d" % GameData.sell_value(owned[sell_sel]), 11, C_GOLD)


# ══════════════════════════════════════════════════════════
#  매대 아이콘
# ──────────────────────────────────────────────────────────
#  상점에 세 종류가 나란히 선다. 실루엣이 서로 갈려야 글자를
#  안 읽고도 무엇인지 안다.
#    아이템 → 원반 (draw_item_chip)
#    개조   → 사각판 위의 미니 보드
#    다트   → 대각선
#  _icon_mod / _icon_dart 만 바깥에서 부른다.
# ══════════════════════════════════════════════════════════

# 미니 보드는 실제 링 비율(트리플 띠 0.10)을 쓰면 17px 반지름에서 1.7px 라
# 사라진다. 읽히는 도식 비율을 따로 둔다 — 계측도가 아니라 기호다.
const MB := {"bi": 0.13, "bo": 0.27, "ti": 0.46, "to": 0.60, "di": 0.84}
const MB_SEG := 10              # 20 칸이면 한 칸 호가 5px 라 뭉갠다


func _icon_mod(c: Vector2, r: float, id: String, dim: float) -> void:
	# 사각 캐비닛 — 이게 없으면 칩과 똑같은 원반이라 실루엣이 안 갈린다
	var pl := Rect2(c - Vector2(r + 3.0, r + 3.0), Vector2(r * 2.0 + 6.0, r * 2.0 + 6.0))
	draw_rect(pl, C_PANEL.darkened(0.35 + dim * 0.3))
	draw_rect(Rect2(pl.position, Vector2(pl.size.x, 1.0)), C_WIRE.darkened(0.35))

	# 바탕 보드는 죽여 깔고, 바뀌는 곳만 원색으로 덮는다
	var d := 0.42 + dim * 0.35
	draw_circle(c, r, C_DARK.darkened(d * 0.5))
	var step := TAU / float(MB_SEG)
	for i in MB_SEG:
		var a := float(i) * step
		draw_colored_polygon(annulus_at(c, r * MB.bo, r * MB.di, a, a + step, 3),
				(C_LIGHT if i % 2 == 0 else C_DARK).darkened(d))
	# 링 강조는 draw_arc 로만 그린다. 전체 링을 폴리곤으로 넘기면 이음매가
	# 겹친 비볼록 도형이라 삼각분할이 튄다.
	draw_arc(c, r * (MB.ti + MB.to) * 0.5, 0.0, TAU, 20,
			C_GREEN.darkened(d), (MB.to - MB.ti) * r)
	draw_arc(c, r * (MB.di + 1.0) * 0.5, 0.0, TAU, 20,
			C_RED.darkened(d), (1.0 - MB.di) * r)
	draw_circle(c, r * MB.bo, C_GREEN.darkened(d))
	draw_circle(c, r * MB.bi, C_RED.darkened(d))

	var acc := C_ACC.darkened(dim)
	var ghost := Color(C_TXT, 0.45 - dim * 0.3)
	match id:
		"trpw":
			draw_arc(c, r * 0.53, 0.0, TAU, 24, acc, r * 0.34)
			draw_arc(c, r * MB.ti, 0.0, TAU, 20, ghost, 1.0)
			draw_arc(c, r * MB.to, 0.0, TAU, 20, ghost, 1.0)
		"dblw":
			draw_arc(c, r * 0.84, 0.0, TAU, 24, acc, r * 0.32)
			draw_arc(c, r * MB.di, 0.0, TAU, 22, ghost, 1.0)
		"bulw":
			draw_circle(c, r * MB.bo * 1.7, acc)
			draw_arc(c, r * MB.bo, 0.0, TAU, 16, ghost, 1.0)
		"sw20":
			# 가장 작은 섹터가 20으로 바뀐다 — 두 칸이 같은 색이 된다
			for k in [0, 5]:
				var a := float(k) * step
				draw_colored_polygon(annulus_at(c, r * MB.bo, r * MB.di, a, a + step, 3), acc)


func _icon_dart(c: Vector2, dl: float, id: String, dim: float) -> void:
	# 보드에 꽂힌 다트와 같은 각도로 눕는다 (_draw_darts 의 Vector2(6, -10))
	var dir := Vector2(6.0, -10.0).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	var bw := 2.6
	var fin := 3.2
	var col := C_TXT
	match id:
		"hvy":
			bw = 4.0
			fin = 2.4
			col = C_WIRE.lightened(0.30)
		"lgt":
			bw = 1.5
			fin = 4.6
			col = C_GREEN.lightened(0.35)
		"prc":
			bw = 2.2
			fin = 2.8
			col = C_CHIP.lightened(0.25)
		"mag":
			bw = 3.0
			fin = 3.4
			col = C_MULT.lightened(0.25)
	col = col.darkened(dim)

	var tip := c + dir * dl
	var tail := c - dir * dl
	var brl := c + dir * dl * 0.1

	draw_line(tip + Vector2(1.5, 3.0), tail + Vector2(1.5, 3.0),
			Color(0.0, 0.0, 0.0, 0.28), bw)
	# 촉
	draw_colored_polygon(PackedVector2Array([tip,
			brl + nrm * bw * 0.5, brl - nrm * bw * 0.5]), C_LIGHT.darkened(dim))
	# 배럴
	draw_line(brl, c - dir * dl * 0.35, col, bw)
	# 샤프트
	draw_line(c - dir * dl * 0.35, c - dir * dl * 0.6,
			C_DARK.lightened(0.25).darkened(dim), 1.6)
	# 날개
	var w0 := c - dir * dl * 0.6
	draw_colored_polygon(PackedVector2Array([w0, w0 + nrm * fin - dir * dl * 0.2,
			tail, w0 - nrm * fin - dir * dl * 0.2]), col)

	match id:
		"hvy":
			for t in [0.55, 0.75]:
				var q := brl.lerp(c - dir * dl * 0.35, t)
				draw_line(q + nrm * bw * 0.6, q - nrm * bw * 0.6, C_DARK.darkened(dim), 2.0)
		"lgt":
			for k in [-1.0, 1.0]:
				draw_line(tail + nrm * k * 2.5 - dir * 2.0,
						tail + nrm * k * 2.5 - dir * 6.0, col, 1.0)
		"prc":
			draw_line(tip, tip + dir * 5.0, C_CHIP.lightened(0.4).darkened(dim), 1.0)
		"mag":
			draw_arc(tip + dir * 4.0, 4.5, PI * 0.15, PI * 0.85,
					10, C_MULT.lightened(0.4).darkened(dim), 1.0)


# ══════════════════════════════════════════════════════════
#  제약 아이콘
# ──────────────────────────────────────────────────────────
#  GameData.MODIFIERS 6종. 세 자리에서 크기만 달리 쓴다.
#    스테이지 카드 r=9(18px) · 하단 제약 줄 r=7(14px) · 툴팁 r=7(14px)
#  이름을 _icon_mod 로 못 짓는다 — 코드에서 mod 는 이미 보드 개조다.
#
#  ── 실루엣 ──
#  이 게임은 이미 네 실루엣을 썼다.
#    아이템     꽉 찬 원반      draw_item_chip
#    개조       불투명 사각판    _icon_mod
#    다트       긴 대각 획      _icon_dart
#    빈 랙 홈   속 빈 고리      _panel_draw
#  마지막 것이 결정적이다. 스테이지 화면 y 21~67 에 지름 21.6px 짜리
#  빈 고리가 최대 5개 떠 있고 그 뜻이 "아직 아무것도 없음"이다.
#  그래서 제약은 원도 사각도 대각선도 테두리도 쓰지 않는다. 바탕 없이
#  2r 정사각 안에 획과 덩어리만 놓고 여섯이 지배 형태를 하나씩 갖는다.
#    narrow 세로 막대쌍 · gust 겹화살 · fog 십자
#    short  가로 층    · dead 부채꼴  · dull 자물쇠
#  색을 다 빼도 여섯이 갈린다.
#
#  ── 세 톤 ──
#    grey  살아남은 것       C_WIRE.lightened(0.18)
#    loss  제약이 부순 것     C_MULT.lightened(0.25)  ← 옆 이름 글자와 같은 값
#    cut   덩어리에 파낸 홈    loss 위에만 얹는다
#  유령선(반투명 옛 형태)은 안 쓴다. 카드 바탕 C_PANEL.lightened(0.10) 은
#  하단 줄 바탕 C_BG 보다 밝기가 5배라, 반투명 1px 선은 카드 위에서
#  grey 와 명암이 붙어 구조선과 구별이 안 되고 오히려 더 진해진다.
#  파선으로 끊기엔 14px 에서 호가 3~5px 라 자리가 없다. 없어진 것은
#  "없음"과 "그 자리를 덮은 loss" 로만 말한다.
#  cut 을 바탕색이 아니라 고정 어두운 색으로 둔 것도 같은 이유다.
#  항상 loss 덩어리 위에만 찍으므로 대비가 7:1 로 고정이고 자리를
#  안 탄다. 바탕색으로 구멍을 뚫으면 하단 줄에선 C_BG 와 같아져
#  그리나 마나가 된다.
#
#  ── 극성 ──
#  _icon_mod 는 좋아진 곳을 C_ACC 로 덮는다. 여기는 정확히 뒤집어
#  나빠진 곳만 loss 로 칠한다. 이 세트에 C_ACC / C_GOLD 는 한 번도
#  안 나온다 — 금색이 한 점만 섞여도 "얻는 것"으로 읽힌다.
#  loss 와 grey 의 휘도차는 1.23:1 뿐이라 회색조에서 색은 못 믿는다.
#  그래서 loss 는 여섯 중 다섯에서 그 아이콘의 가장 큰 단일 도형이다.
#  narrow 만 예외인데, 주제가 "얇아짐" 자체라 loss 가 얇은 것이 곧 뜻이다.
#
#  ── 크기 ──
#  좌표는 전부 r 비율, 두께에만 하한을 건다. narrow 의 2:1 은 하한이
#  걸린 뒤에도 유지된다 — 굵은 쪽이 2.0 에 눌리면 얇은 쪽은 그 절반인
#  1.0 이 되므로 비가 안 무너진다.
#  여섯 전부 2r 정사각을 넘지 않는다. 하나라도 넘으면 세 자리의 여백
#  검산이 아이콘마다 달라져 전부 거짓말이 된다.
#  r=7 에서 가장 가는 획 1.05px, 가장 좁은 틈 1.09px. 하한은 r=6.5 다.
# ══════════════════════════════════════════════════════════

const LIM := {
	"thin": 0.15, "thin_lo": 1.0,   # 맥락 획
	"bold": 0.30, "bold_lo": 2.0,   # 구조 획
}


func _icon_modifier(c: Vector2, r: float, id: String, dim: float,
		a: float = 1.0) -> void:
	var grey := Color(C_WIRE.lightened(0.18).darkened(dim), a)
	var loss := Color(C_MULT.lightened(0.25).darkened(dim), a)
	var cut := Color(C_DARK.darkened(0.45), a)          # loss 덩어리 안에만
	var w1: float = maxf(r * float(LIM.thin), float(LIM.thin_lo))
	var w2: float = maxf(r * float(LIM.bold), float(LIM.bold_lo))

	match id:
		# ── 좁은 판 ──────────────────────────────────────
		# 세로 막대 둘, 굵기비 정확히 2:1. 왼쪽 grey 가 원래 폭,
		# 오른쪽 loss 가 남은 폭이다. 한 프레임에 before/after 를 같이
		# 넣으므로 유령선이 필요 없다 — 왼쪽 막대가 이미 그 유령이다.
		"narrow":
			var nh := r * 1.60
			var nw := maxf(r * 0.34, 2.0)
			draw_rect(Rect2(c + Vector2(-r * 0.40 - nw * 0.5, -nh * 0.5),
					Vector2(nw, nh)), grey)
			draw_rect(Rect2(c + Vector2(r * 0.40 - nw * 0.25, -nh * 0.5),
					Vector2(nw * 0.5, nh)), loss)

		# ── 역풍 ────────────────────────────────────────
		# 겹화살. 배속 버튼 관례 그대로라 "2배"를 개수로 말한다 —
		# 학습 비용이 0 이고, 각진 획이라 세트에서 유일하다.
		# 아래 가는 선은 게이지 궤도, 이 아이콘에서 유일하게 멀쩡한 것.
		"gust":
			draw_line(c + Vector2(-r * 0.88, r * 0.86),
					c + Vector2(r * 0.88, r * 0.86), grey, w1)
			for i in 2:
				var gx := r * (-0.80 + 0.80 * float(i))
				draw_line(c + Vector2(gx, -r * 0.46),
						c + Vector2(gx + r * 0.44, 0.0), loss, w2)
				draw_line(c + Vector2(gx + r * 0.44, 0.0),
						c + Vector2(gx, r * 0.46), loss, w2)

		# ── 안개 ────────────────────────────────────────
		# CONFIRM 은 조준 십자에 링 두 개(22→7, 30→11)를 조여 붙여
		# "멈춰 볼 틈"을 만든다. 그 링이 통째로 없다. 남은 것은 십자와
		# 가운데 표적점뿐이고, 둘 사이의 빈 고리가 사라진 확인 구간이다.
		"fog":
			var hole := r * 0.34
			for i in 4:
				var fa := TAU * float(i) * 0.25
				var fd := Vector2(cos(fa), sin(fa))
				draw_line(c + fd * hole, c + fd * r * 0.86, loss, w2)
			draw_circle(c, r * 0.16, grey)

		# ── 단벌 ────────────────────────────────────────
		# 탄창 그대로 — 가로 칸을 세로로 쌓는다(_mag_rect 도 그 배치다).
		# 남은 두 칸은 grey, 없어진 맨 윗칸 자리에는 칸보다 긴 loss 막대를
		# 눕힌다. 칸보다 길어야 "줄의 일원"이 아니라 "가로지른 마이너스"다.
		"short":
			var sbw := r * 1.30
			var sbh := r * 0.30
			draw_rect(Rect2(c + Vector2(-r * 0.86, -r * 0.72),
					Vector2(r * 1.72, r * 0.34)), loss)
			for i in 2:
				draw_rect(Rect2(c + Vector2(-sbw * 0.5,
						r * (-0.13 + 0.50 * float(i))), Vector2(sbw, sbh)), grey)

		# ── 금지 구역 ────────────────────────────────────
		# 20번은 화면에서 12시다 — sectors[0]=20 이고 annulus_at 의 각 0 이
		# Vector2(sin, -cos) 라 위쪽이며 _draw_board 의 0번 칸이 그 자리를
		# 걸친다. 그래서 꼭짓점을 아래 두고 위로 벌어지는 조각을 그린다.
		# 여섯 중 이것만 grey 가 없다 — 조각이 통째로 죽으므로 살아남은
		# 것이 없고, 없는 것을 그리면 거짓말이 된다.
		"dead":
			var ap := c + Vector2(0.0, r * 0.74)
			var fan := PackedVector2Array([ap])
			for i in 9:
				var da := lerpf(-0.52, 0.52, float(i) / 8.0)
				fan.append(ap + Vector2(sin(da), -cos(da)) * r * 1.58)
			draw_colored_polygon(fan, loss)
			# 0점. 폭을 조각 폭에서 역산했으므로 어느 크기에서도 안 샌다
			# (아래 모서리 안쪽으로 0.156r = r=7 에서 1.09px 남는다).
			draw_rect(Rect2(c + Vector2(-r * 0.44, -r * 0.54),
					Vector2(r * 0.88, maxf(r * 0.24, 1.4))), cut)

		# ── 둔화 ────────────────────────────────────────
		# 여섯 중 유일하게 보드가 아니라 칩을 건드리는 제약이라 혼자만
		# 기하가 아니라 물건이다 — 그 어긋남이 곧 "대상이 다르다"는 표시다.
		# 랙이 봉인 칩에 이미 "봉인"을 C_MULT 로 찍으므로 자물쇠는
		# 이 게임에 이미 있는 어휘다. 아치가 dead 의 부채꼴과 갈라준다.
		"dull":
			var ly := c.y - r * 0.13
			draw_arc(Vector2(c.x, ly), r * 0.44, PI, TAU, 12, grey, w2)
			draw_rect(Rect2(Vector2(c.x - r * 0.68, ly),
					Vector2(r * 1.36, r * 0.86)), loss)
			draw_circle(Vector2(c.x, c.y + r * 0.18), r * 0.15, cut)
			draw_rect(Rect2(c + Vector2(-r * 0.12, r * 0.18),
					Vector2(r * 0.24, r * 0.38)), cut)

# ══════════════════════════════════════════════════════════
#  툴팁 (마우스 오버)
# ──────────────────────────────────────────────────────────
#  바깥과 닿는 곳은 둘뿐이다.
#    _tip_update(d)  매 프레임 진행     (_process 끝)
#    _tip_draw(sh)   오버레이 다음에    (_draw)
#  칩 랙의 호버 링만 tip_slot / tip_a 를 읽는다.
#
#  대상은 매 프레임 새로 찾아 그 프레임에 소비한다. 인덱스를
#  프레임 너머로 들고 가지 않으므로 상점이 갈리거나 아이템이
#  사라져도 범위를 넘을 수 없다.
# ══════════════════════════════════════════════════════════

const TIP := {
	"w": 178.0,          # 판 폭 (고정 — 대상마다 크기가 출렁이면 눈이 다시 초점을 잡는다)
	"pad": 7.0,
	"gap": 6.0,          # 대상과 판 사이
	"title": 15.0,       # 제목 줄 높이
	"line": 13.0,        # 본문 줄 높이
	"fade": 14.0,        # 페이드 속도
	"quiet": 6.0,        # shake 가 이보다 크면 아예 안 그린다 (읽을 수 없다)
}

var tip_title := ""
var tip_lines := []             # [{"s": String, "sz": int, "c": Color}]
var tip_chip := {}              # 제목 옆 미니칩으로 그릴 아이템 (없으면 빈 사전)
var tip_mark := Rect2()         # 대상 테두리 (칩 랙은 링으로 대신하므로 빈 값)
var tip_slot := -1              # 호버 중인 칩 랙 칸
var tip_a := 0.0                # 페이드


# ic  왼쪽에 붙일 제약 아이콘 id (없으면 빈 문자열 — 기존 호출은 3인자 그대로)
# tl  이름 뒤에 9pt 로 이어 붙일 설명 (제약 줄에서만 쓴다)
func _tip_add(t: String, sz: int, c: Color, ic := "", tl := "", gd := "") -> void:
	if t != "":
		tip_lines.append({"s": t, "sz": sz, "c": c, "ic": ic, "tl": tl, "gd": gd})


func _tip_clear() -> void:
	tip_title = ""
	tip_lines = []
	tip_chip = {}
	tip_mark = Rect2()
	tip_slot = -1


# 지금 커서 아래에 무엇이 있는가. 없으면 빈 사전.
func _tip_hit(m: Vector2) -> Dictionary:
	match state:
		S.SHOP:
			for i in stock.size():
				if _stock_rect(i).has_point(m):
					return {"k": "stock", "i": i}
			for i in GameData.MAX_ITEMS:
				if _slot_rect(i).has_point(m):
					return {"k": "rack", "i": i}
		S.STAGE:
			for i in stage_pick.size():
				if _stage_rect(i).has_point(m):
					return {"k": "stage", "i": i}
			for i in GameData.MAX_ITEMS:
				if _slot_rect(i).has_point(m):
					return {"k": "rack", "i": i}
		S.PICK, S.AIM_V, S.AIM_H:
			if state == S.PICK:
				for i in remaining.size():
					if _mag_rect(i).has_point(m):
						return {"k": "mag", "i": i}
			# 점수 카드가 떠 있으면 랙 툴팁이 카드를 정면으로 덮는다.
			# 위는 상단바라 앵커를 뒤집어서 못 피한다 — 그동안 대상에서 뺀다.
			if card_p <= 0.004:
				for i in GameData.MAX_ITEMS:
					if _slot_rect(i).has_point(m):
						return {"k": "rack", "i": i}
	return {}


func _tip_build(hit: Dictionary) -> void:
	_tip_clear()
	if hit.is_empty():
		return

	var i: int = hit.i
	match hit.k:
		"rack":
			tip_mark = Rect2()
			tip_slot = i
			if i >= owned.size():
				tip_title = "빈 칸"
				_tip_add("상점에서 칩을 사면 여기 꽂힌다", 9, C_DIM)
				_tip_add("최대 %d개" % GameData.MAX_ITEMS, 9, C_DIM.darkened(0.2))
				return
			var it: Dictionary = owned[i]
			tip_title = it.n
			tip_chip = it
			_tip_add(GameData.cond_text(it.c), 10, C_DIM)
			_tip_add(GameData.eff_text(it.k, it.v), 11,
					C_CHIP.lightened(0.35) if it.k == "chip" else C_MULT.lightened(0.3))
			if it.get("g", "") != "":
				_tip_add(GameData.gold_text(it.g, it.gv), 9, C_GOLD)
			if i == sealed:
				_tip_add("이번 판 봉인 — 발동하지 않는다", 9, C_MULT.lightened(0.25))
			if _can_sell():
				_tip_add("판매가", 10, C_GOLD, "", "", str(GameData.sell_value(it)))
				_tip_add("왼쪽 판매 판을 눌러 확정" if i == sell_sel else "누르면 고른다",
						9, C_DIM.darkened(0.2))
			elif state == S.STAGE:
				_tip_add("마지막 라운드 — 골드를 쓸 곳이 없다", 9, C_DIM.darkened(0.3))
		"stock":
			var s: Dictionary = stock[i]
			tip_mark = _stock_rect(i)
			tip_title = s.d.n
			if s.type == "item":
				tip_chip = s.d
				_tip_add(GameData.cond_text(s.d.c), 10, C_DIM)
				_tip_add(GameData.eff_text(s.d.k, s.d.v), 11,
						C_CHIP.lightened(0.35) if s.d.k == "chip" else C_MULT.lightened(0.3))
				if s.d.get("g", "") != "":
					_tip_add(GameData.gold_text(s.d.g, s.d.gv), 9, C_GOLD)
			else:
				_tip_add(s.d.d, 10, C_DIM)
				_tip_add("보드를 바꾼다 — 런이 끝날 때까지 남는다" if s.type == "mod"
						else "탄창의 표준 다트 1개와 바꾼다", 9, C_DIM.darkened(0.2))
			# 못 사는 이유를 누르기 전에 알려준다. _deny() 는 세 원인을 한 문장으로 뭉갠다.
			if s.sold:
				_tip_add("이미 구매함", 9, C_DIM.darkened(0.3))
			elif gold < s.cost:
				_tip_add("골드가 %d 모자란다" % (s.cost - gold), 9, C_RED.lightened(0.2))
			elif s.type == "item" and owned.size() >= GameData.MAX_ITEMS:
				_tip_add("칩 랙이 꽉 찼다 (%d/%d)" % [owned.size(), GameData.MAX_ITEMS],
						9, C_RED.lightened(0.2))
			elif s.type == "dart" and _std_slot() < 0:
				_tip_add("바꿀 표준 다트가 없다", 9, C_RED.lightened(0.2))
		"stage":
			var sp: Dictionary = stage_pick[i]
			tip_mark = _stage_rect(i)
			tip_title = "%s · 목표 %d" % [sp.d.n, sp.target]
			if sp.mods.is_empty():
				_tip_add("제약 없음 — 기본 목표 그대로", 10, C_DIM)
			else:
				for md in sp.mods:
					_tip_add(md.n, 11, C_MULT.lightened(0.25), md.id, md.d)
			var rw := []
			if sp.d.gold > 0:
				rw.append("골드 +%d" % sp.d.gold)
			if sp.d.item:
				rw.append("아이템 1개")
			if sp.d.item and stage_slots >= GameData.MAX_ITEMS:
				_tip_add("칩 랙이 꽉 차 아이템은 못 받는다", 9, C_RED.lightened(0.2))
			_tip_add(("클리어 시  " + "  ·  ".join(rw)) if not rw.is_empty()
					else "추가 보상 없음", 9, C_GOLD if not rw.is_empty() else C_DIM.darkened(0.2))
		"mag":
			var dd: Dictionary = remaining[i]
			tip_mark = _mag_rect(i)
			tip_title = dd.n
			_tip_add(dd.d, 10, C_DIM)
			_tip_add("게이지 ×%.2f" % dd.gauge, 9, C_DIM.darkened(0.2))


func _tip_size() -> Vector2:
	var h: float = TIP.pad * 2.0 + TIP.title
	for l in tip_lines:
		# 아이콘 줄만 14px 아이콘이 들어가게 2px 키운다. 극한 카드(제약 2개)가
		# 14+15+15+15+13 = 72 로, 뒤집기 한계 86 에 14px 여유가 남는다.
		h += TIP.line + (2.0 if l.ic != "" else 0.0)
	return Vector2(TIP.w, h)


# 대상 옆에 붙이되 화면 밖으로 나가지 않게 민다.
func _tip_pos(sz: Vector2) -> Vector2:
	var t := tip_mark
	if tip_slot >= 0:
		t = _slot_rect(tip_slot)
	var x: float = clampf(t.get_center().x - sz.x * 0.5, 4.0, VIEW.x - sz.x - 4.0)
	var y: float = t.end.y + TIP.gap
	if y + sz.y > VIEW.y - 4.0:
		y = t.position.y - TIP.gap - sz.y
	return Vector2(x, maxf(y, 4.0))


func _tip_update(d: float) -> void:
	var hit := _tip_hit(get_local_mouse_position())
	_tip_build(hit)
	if hit.is_empty():
		tip_a = maxf(tip_a - d * TIP.fade, 0.0)
	else:
		tip_a = minf(tip_a + d * TIP.fade, 1.0)


func _tip_draw(sh: Vector2) -> void:
	if tip_a <= 0.004 or tip_title == "" or shake > TIP.quiet:
		return

	# 테두리는 대상과 같이 흔들려야 어긋나 보이지 않는다 — 현재 transform 그대로.
	if tip_mark.size.x > 0.0:
		draw_rect(tip_mark, Color(C_TXT, tip_a * 0.9), false, 1.0)

	# 판과 글자는 흔들리면 못 읽는다 — 흔들림 밖에서 그린다.
	draw_set_transform(Vector2.ZERO)
	var sz := _tip_size()
	var p := _tip_pos(sz)
	draw_rect(Rect2(p + Vector2(2.0, 3.0), sz), Color(0.0, 0.0, 0.0, tip_a * 0.4))
	draw_rect(Rect2(p, sz), Color(C_PANEL.lightened(0.06), tip_a))
	draw_rect(Rect2(p, Vector2(sz.x, 2.0)), Color(C_ACC, tip_a))

	var tx: float = p.x + TIP.pad
	if not tip_chip.is_empty():
		draw_item_chip(p + Vector2(TIP.pad + 8.0, TIP.pad + 8.0), 8.0, tip_chip,
				0.42, 0.0, 0.0, 8)
		tx += 20.0
	draw_string(font, Vector2(tx, p.y + TIP.pad + 11.0), tip_title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(C_TXT, tip_a))

	# _tip_draw 의 본문 루프. 이 시점에 transform 은 이미 Vector2.ZERO 라
	# 아이콘도 안 흔들린다. 페이드는 tip_a 를 알파로 넘겨 글자와 같이 뜬다.
	# 아이콘 없는 줄은 ic == "" 로 예전 경로 그대로 간다.
	var y: float = p.y + TIP.pad + TIP.title + 10.0
	for l in tip_lines:
		var lx: float = p.x + TIP.pad
		if l.ic != "":
			_icon_modifier(Vector2(lx + 7.0, y - 4.0), 7.0, l.ic, 0.0, tip_a)
			lx += 18.0
		draw_string(font, Vector2(lx, y), l.s, HORIZONTAL_ALIGNMENT_LEFT,
				p.x + sz.x - TIP.pad - lx, l.sz, Color(l.c, tip_a))
		if l.tl != "":
			var tw: float = font.get_string_size(l.s, HORIZONTAL_ALIGNMENT_LEFT,
					-1, l.sz).x + 5.0
			draw_string(font, Vector2(lx + tw, y), l.tl, HORIZONTAL_ALIGNMENT_LEFT,
					p.x + sz.x - TIP.pad - lx - tw, 9, Color(C_DIM, tip_a))
		if l.gd != "":
			draw_gold_at(p.x + sz.x - TIP.pad - gold_w(l.gd, l.sz), y,
					l.gd, l.sz, Color(l.c, tip_a))
		y += TIP.line + (2.0 if l.ic != "" else 0.0)

	draw_set_transform(sh)

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

		# 8pt 설명 줄은 없앤다 — 640×360, texture_filter=0 에서 8px 한글은
		# 자모 성분이 1px 밑으로 내려가 회색 얼룩이 된다. 정확한 문구는
		# 툴팁이 그대로 들고 있으므로 잃는 정보가 없다. 카드는 셋을 훑어
		# 하나를 고르는 면이고, 훑기에 쓰이는 채널은 글자가 아니라 실루엣이다.
		var my := 110.0 if sp.mods.size() == 1 else 99.0
		for m in sp.mods:
			_icon_modifier(r.position + Vector2(20.0, my), 9.0, m.id, 0.0)
			draw_string(font, r.position + Vector2(34.0, my + 4.0), m.n,
					HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 42.0, 11,
					C_MULT.lightened(0.25))
			my += 22.0

		var rw := "보상 없음"
		# R8 은 정산이 없다 — 극한 보상이 조기 return 뒤에 있어 전부 사라지고
		# 목표 ×1.25 만 남는다. 함정을 얼굴에 쓴다.
		if round_no >= GameData.ROUNDS and (sp.d.gold > 0 or sp.d.item):
			rw = "마지막 판 · 보상 없음"
		elif sp.d.gold > 0:
			rw = "+%d" % sp.d.gold
		if sp.d.item:
			rw += "  ·  아이템 1개"
		draw_string(font, r.position + Vector2(0, r.size.y - 10), rw,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x,
				11, C_GOLD if sp.d.gold > 0 else C_DIM)

	draw_string(font, Vector2(0, 292), "판을 눌러 시작",
			HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 11, C_TXT)
	draw_string(font, Vector2(0, 312), "뒤에 보이는 보드가 지금 네 보드다",
			HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 9, C_DIM.darkened(0.25))


func _draw_shop() -> void:
	_scrim()
	if deny_flash > 0.0:
		draw_string(font, Vector2(0, 300), "골드가 부족하거나 슬롯이 꽉 찼다",
				HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 11,
				Color(C_MULT.lightened(0.3), deny_flash))
	for i in stock.size():
		var r := _stock_rect(i)
		var s: Dictionary = stock[i]
		var can: bool = not s.sold and gold >= s.cost
		var hov: bool = tip_mark == r and tip_a > 0.004
		draw_rect(r, C_PANEL.lightened(0.02) if s.sold
				else C_PANEL.lightened(0.22 if hov else 0.10))
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
		var dim: float = 0.0 if can else 0.42

		# 머리줄 — 종류는 왼쪽, 가격은 오른쪽. 가격을 여기로 올려야
		# 아이콘이 들어갈 40px 이 나온다.
		draw_string(font, r.position + Vector2(8, 15), kind,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, C_DIM.darkened(0.1))
		draw_gold_at(r.end.x - 8.0 - gold_w(str(s.cost), 11), r.position.y + 15.0,
				str(s.cost), 11, C_GOLD if can else C_DIM.darkened(0.3))

		# 아이콘 띠
		var ic := r.position + Vector2(73, 39)
		match s.type:
			"item":
				draw_circle(ic + Vector2(1.5, 3.0), 17.0, Color(0.0, 0.0, 0.0, 0.30))
				draw_item_chip(ic, 17.0, s.d, 0.42, 0.0, dim, 14)
			"mod":
				_icon_mod(ic, 15.0, s.d.id, dim)
			"dart":
				_icon_dart(ic, 19.0, s.d.id, dim)

		draw_string(font, r.position + Vector2(0, 76), s.d.n,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, C_TXT if can else C_DIM)
		# 설명을 조건/효과 두 줄로 쪼갠다. 한 줄로 두면 폭을 넘겨
		# draw_string 이 줄바꿈 없이 조용히 잘라낸다.
		if s.type == "item":
			draw_string(font, r.position + Vector2(6, 92), GameData.cond_text(s.d.c),
					HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 12, 10, C_DIM)
			var ec: Color = C_CHIP.lightened(0.35) if s.d.k == "chip" else C_MULT.lightened(0.3)
			draw_string(font, r.position + Vector2(6, 107),
					GameData.eff_text(s.d.k, s.d.v),
					HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 12, 11, ec.darkened(dim))
			if s.d.get("g", "") != "":
				draw_string(font, r.position + Vector2(4, 122),
						GameData.gold_text(s.d.g, s.d.gv),
						HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 8,
						C_GOLD.darkened(0.15 + dim))
		else:
			draw_string(font, r.position + Vector2(6, 99), s.d.d,
					HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 12, 10, C_DIM)

	_btn(_reroll_rect(), "리롤", "무료" if reroll_cost == 0 else "", gold >= reroll_cost)
	if reroll_cost > 0:
		var rr := _reroll_rect()
		draw_gold(rr.position.x + rr.size.x * 0.5, rr.position.y + 35.0,
				str(reroll_cost), 10, C_GOLD if gold >= reroll_cost else C_DIM.darkened(0.3))
	_btn(_next_rect(), "다음 라운드 →", "R%d  목표 %d"
			% [round_no + 1, GameData.target_of(round_no + 1)], true)

	draw_string(font, Vector2(0, 316), "카드를 눌러 구매    ·    위쪽 칩을 눌러 판매",
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
		# baseline 을 334 → 341 로 내린다. 진짜 이웃은 힌트 줄(가운데 정렬이라
		# 가로로 안 만난다)이 아니라 점수 카드다 — card_y=232 + CARD_H=96 =
		# 바닥 328 이고 card_side<0 이면 x 82~326 을 덮는다. 334 짜리 10pt 는
		# 지금도 캡 상단이 ~326 이라 카드 안으로 들어가 있었다.
		var mx := 8.0
		draw_string(font, Vector2(mx, 341), "제약",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_MULT.darkened(0.15))
		mx += font.get_string_size("제약", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 9.0
		for m in active_mods:
			_icon_modifier(Vector2(mx + 7.0, 337.0), 7.0, m.id, 0.0)
			mx += 18.0
			draw_string(font, Vector2(mx, 341), m.n,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_MULT.lightened(0.25))
			mx += font.get_string_size(m.n, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 12.0

	draw_string(font, Vector2(8, 356), "[ ] 조준 %.2f    - = 정산 %.2f    ; ' 확인텀 %.2f"
			% [gauge_speed, beat, confirm_hold], HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			C_DIM.darkened(0.25))
