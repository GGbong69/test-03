extends Node2D

const GameData = preload("res://scripts/data.gd")

# ── 다트 로그라이트 프로토타입 ──────────────────────────────
# 흐름: 라운드 플레이 → 클리어 정산(보너스 3택) → 상점 → 다음 라운드
# 조작: 마우스 클릭 / 스페이스 (상하 → 좌우 → 확인 → 발사)
#       [ ] 조준 속도   - = 정산 속도   ; ' 확인 텀
# 밸런스 수치는 전부 scripts/data.gd 에 있다.

const VIEW := Vector2(640, 360)
const BC := Vector2(320, 196)
# 판 반지름과 조준 진폭은 tuning.csv 에 나란히 있다. SWING 은 R 에 비례해야
# 하고(보드만 줄이면 빗나갈 확률이 조용히 오른다), 그 비 1.1226 이 빗나감
# 37.68% 를 만든다. 둘을 같은 표에 둔 덕에 검증기가 비를 직접 잰다.
var R := GameData.tune("board_r")
var SWING := GameData.tune("aim_swing")

const CARD_W := 244.0
const CARD_H := 96.0


# ══════════════════════════════════════════════════════════
#  HUD 배치표
#  상시 HUD 띠(상단바·자금·판매·용량)의 좌표만 여기서 정한다.
#  줄을 지우고 _hud_draw() 의 호출 한 줄을 지우면 그 판만 사라진다.
#
#  주의 — 화면 좌표가 여기에만 있는 것이 아니다. 나머지 소유자는 이렇다.
#    _stage_rect / _obj_box / _mag_rect / _reroll_rect / _next_rect
#    PANEL · _panel_rect · _slot_rect        (칩 랙)
#    card_pos                                 (점수 카드)
#    _draw_hint 의 341 · 348 · 356            (하단 세 줄)
#  이 목록을 사실과 다르게 두면 다음 사람이 잘못된 전제로 판단한다.
#
#  전제 — 이 파일의 모든 화면 좌표는 stretch/aspect = "keep" 위에 서 있다.
#  뷰포트 640x360 이 창 크기와 무관하게 유지되고 마우스가 그 공간으로
#  정확히 환산된다는 뜻이다. "expand" 로 바꾸면 뷰포트가 커져서 여기 적힌
#  숫자와 _tip_pos 의 clamp, 상점 계산대 판정이 전부 어긋난다.
#  project.godot 에 명시할 수는 없다 — keep 이 엔진 기본값이라 에디터가
#  저장할 때마다 그 줄을 지운다. 그래서 근거를 코드 쪽에 남긴다.
# ══════════════════════════════════════════════════════════
# 상점·스테이지는 카지노 테이블이 화면 전부를 쓴다. 런 바를 내리고
# 그 자리(16px)를 딜러에게 준다 — 딜러가 사람으로 읽히려면 세로가 필요하고,
# 목표·점수 진행은 던지는 중에만 쓸모가 있다. 다음 라운드 목표는
# "다음" 버튼이 이미 들고 있다.
const HUD_UP := -16.0


func _bar_hidden() -> bool:
	return state == S.SHOP or state == S.STAGE


func _hud_dy() -> float:
	return HUD_UP if _bar_hidden() else 0.0


# 자금판은 상점·스테이지에서 이자 줄이 붙어 46 으로 자란다.
func _bank_rect() -> Rect2:
	var r: Rect2 = LAY.bank
	r.position.y += _hud_dy()
	if _bar_hidden() or state == S.CLEAR:
		r.size.y = 46.0
	return r


# 런 바가 없는 화면에서도 몇 판째인지는 남아야 한다. 자금판 머리띠가 진행바다.
func _run_done() -> int:
	return round_no if (state == S.CLEAR or state == S.SHOP) else round_no - 1


const LAY := {
	"bar":        Rect2(0.0, 0.0, 640.0, 18.0),
	"bar_cut":    [100.0, 584.0],
	"bar_pip":    Rect2(44.0, 7.0, 5.0, 5.0),
	"bar_pip_dx": 7.0,
	"bar_gauge":  Rect2(146.0, 6.0, 360.0, 7.0),
	"bar_score":  514.0,
	"bar_mod":    588.0,

	# 자금판은 플레이 중 34 높이. 이자/마지막판 줄이 필요한 상점·스테이지에서만
	# _bank_draw 가 46 으로 늘린다. 늘 46 이면 탄창 헤더가 판 안으로 들어간다.
	"bank":       Rect2(4.0, 20.0, 72.0, 34.0),
	# 옛 판매판 자리(x[80,154])는 소비 아이템 칸(_cons_rect)이 쓴다.
	"cap":        Rect2(436.0, 20.0, 37.0, 32.0),
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

enum S { PICK, AIM_V, AIM_H, CONFIRM, FLY, RESOLVE, CLEAR, SHOP, STAGE, OVER,
		TITLE, SETTINGS, COLLECT }

# ── 보드 기하 (개조로 변한다) ──────────────────────────────
#  판의 유일한 출처는 mods_own 이다. 아래 여덟은 그것을 구운 결과일 뿐이다.
var mods_own := []
var sectors := GameData.SECTORS_BASE.duplicate()
var dbl_out := 1.00
var dbl_in := 0.90
var trp_in := 0.56
var trp_out := 0.66
var trp2_in := 0.0
var trp2_out := 0.0
var bull_o := 0.14
var bull_i := 0.06

# 라운드 동안 실제로 쓰이는 값 (영구 개조 + 이번 판 제약)
var rt_dbl_out := 1.00
var rt_dbl_in := 0.90
var rt_trp_in := 0.56
var rt_trp_out := 0.66
var rt_trp2_in := 0.0
var rt_trp2_out := 0.0
var rt_bull_o := 0.14
var rt_bull_i := 0.06
var dead_idx := -1              # "금지 구역"이 죽이는 칸. -1 이면 안 걸렸다

# ── 스테이지 선택 ─────────────────────────────────────────
var stage_pick := []            # 이번에 깔린 제약 카드들
var active_mods := []           # 이번 판에 걸린 제약 (지금은 언제나 한 장)
var sealed := -1                # "둔화"로 봉인된 아이템 인덱스

# ── 탄창 ──────────────────────────────────────────────────
var magazine := []              # 영구 구성 (상점에서 바꾼다)
var remaining := []             # 이번 라운드에 남은 다트
var cur_dart := {}              # 지금 던지는 다트

# ── 진행 상태 ─────────────────────────────────────────────
var state: int = S.AIM_V
var round_no := 1
var target := 0
var total := 0
var shown := 0.0
var darts_left := 0
var gold := 0
var owned := []
var won := false

var last_sector := -1
var last_miss := false          # 직전 투척이 빗나갔는가 — 조건 missp 가 읽는다
# ── 조커 이식이 들여온 라운드 추적 ──
# 패턴 조건("같은 숫자 2회 이후" 류)은 명중 이력에서 나온다. 라운드마다 비운다.
var sec_cnt := {}               # 숫자 → 이번 라운드 명중 수
var zone_cnt := {}              # 영역 종류(single/double/triple/bull) → 명중 수
var pat := {}                   # 완성된 패턴 깃발. "이후" 조건이 읽는다
var seen_risk := false          # risk1 용 — 이번 라운드에 risk 명중이 있었나
var low_hit := 0                # 이번 라운드 최저 명중 숫자 (0 = 아직 없음)
var round_darts := 6            # 이번 라운드 시작 다트 수 (few·missing 이 읽는다)
var throw6 := 0                 # sixth 용 던진 수 카운터 (런 단위 · 발동 시 리셋)
var zone_hist := {}             # 런 단위 영역 종류 누적 명중 (zonehist 배율)
var streak := 0
var dart_index := 0
var round_miss := false
var round_trp := false          # 이번 라운드에 트리플이 나왔는가 ("손맛")         # 이번 라운드에 한 번이라도 빗나갔는가 (골드 칩 "본전" 판정)

# ── 상점 ──────────────────────────────────────────────────
var stock := []                 # {type:"item"/"mod", d:Dictionary, cost:int, sold:bool}
var reroll_cost := GameData.reroll_base()
var rerolls_used := 0
var deny_flash := 0.0
var clear_gold_detail := []

# ── 조준 / 정산 ───────────────────────────────────────────
var gauge_speed := GameData.tune("gauge_speed")
var beat := GameData.tune("resolve_beat")
var confirm_hold := GameData.tune("confirm_hold")
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
var darts := []                 # 보드에 꽂힌 것들 {p 착탄점, id 다트 종류, rot 기울기}
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
	drop_fast = _autoplay          # 헤드리스는 낙하를 안 기다린다
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

	if _autoplay:
		_new_run()
	else:
		# 제목 화면. 판을 배경으로 깔아야 하므로 기본 판만 먼저 굽는다.
		_board_bake()
		state = S.TITLE


# ══════════════════════════════════════════════════════════
#  런 / 라운드 진행
# ══════════════════════════════════════════════════════════

func _new_run() -> void:
	mods_own.clear()
	_board_bake()
	round_no = 1
	gold = GameData.start_gold()
	magazine.clear()
	for i in GameData.tune_i("darts_base"):
		magazine.append(GameData.darts()[0])
	owned.clear()
	cons.clear()
	track_lv.clear()
	throw6 = 0
	zone_hist.clear()
	won = false
	_open_stage()


func _start_round() -> void:
	# 영구 개조값에서 출발해 이번 판 제약을 얹는다
	rt_dbl_out = dbl_out
	rt_dbl_in = dbl_in
	rt_trp_in = trp_in
	rt_trp_out = trp_out
	rt_trp2_in = trp2_in
	rt_trp2_out = trp2_out
	rt_bull_o = bull_o
	rt_bull_i = bull_i
	var bw := mod_v("band_mul", 1.0)
	if not is_equal_approx(bw, 1.0):
		var tc := (trp_in + trp_out) * 0.5
		var tb := (trp_out - trp_in) * 0.5
		rt_trp_in = tc - tb * bw
		rt_trp_out = tc + tb * bw
		rt_dbl_in = dbl_out - (dbl_out - dbl_in) * bw

	remaining = magazine.duplicate()
	# 이번 라운드의 기본 다트 수는 rounds.csv 의 darts 열이 정한다.
	# tuning.csv 비고가 오래전부터 그렇게 적혀 있었는데 코드가 안 읽고
	# 있었다 — 표가 거짓말을 하던 자리다. 탄창보다 많으면 순환해서 채운다.
	var want := GameData.darts_of(round_no)
	while remaining.size() > want and remaining.size() > 1:
		remaining.pop_back()
	while remaining.size() < want and not magazine.is_empty():
		remaining.append(magazine[remaining.size() % magazine.size()])
	var dadd := int(mod_v("darts_add", 0.0))
	# 아이템이 주고받는 다트 (조커 이식 — 곡예 다트맨 -2 등)
	for o in owned:
		dadd += int(o.get("dadd", 0))
	while dadd < 0 and remaining.size() > 1:
		remaining.pop_back()
		dadd += 1
	while dadd > 0:
		remaining.append(magazine[remaining.size() % magazine.size()])
		dadd -= 1
	cur_dart = GameData.darts()[0]
	darts_left = remaining.size()
	round_darts = remaining.size()
	grip_t = 0.0
	# 칸은 시작 때 한 번 정하고 끝까지 안 바꾼다. 자루가 빠질 때마다 다시
	# 가운데 맞추면 남은 것들이 미끄러져 꽂혀 있는 것으로 안 보인다.
	grip_slot.clear()
	for gi in remaining.size():
		grip_slot.append(gi)
	grip_n = remaining.size()
	grip_pick = -1
	var seal := int(mod_v("seal_items", 0.0))
	sealed = randi() % owned.size() if seal > 0 and not owned.is_empty() else -1
	dead_idx = int(mod_v("sector_kill", -1.0))
	round_miss = false
	round_trp = false
	total = 0
	shown = 0.0
	dart_index = 0
	streak = 0
	last_sector = -1
	last_miss = false     # 직전 칸과 같은 규칙 — 라운드가 바뀌면 "직전" 이 없다
	sec_cnt.clear()
	zone_cnt.clear()
	pat.clear()
	seen_risk = false
	low_hit = 0
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
	# 먼저 고르는 상태로 들어선다. _pick_dart 가 "고르는 중일 때만 조준으로
	# 넘어간다" 는 가드를 갖고 있어(조준 중 갈아타기가 상태를 되돌리면 안 된다),
	# 여기서 상태를 안 세우면 이전 화면에 그대로 머문다.
	state = S.PICK
	# 남은 다트가 전부 같은 종류면 고를 게 없으니 건너뛴다
	var uniform := true
	for r in remaining:
		if r.id != remaining[0].id:
			uniform = false
			break
	if uniform:
		_pick_dart(0)


# 고를 때 벽에서 빼지 않는다. 뽑아 든 것으로만 표시하고 실제로 빠지는 것은
# 던지는 순간이다. 그래서 조준 중에도 마음이 바뀌면 다른 자루로 갈아탈 수 있다.
func _pick_dart(i: int) -> void:
	if i < 0 or i >= remaining.size():
		return
	grip_pick = i
	cur_dart = remaining[i]
	darts_left = remaining.size() - 1     # 이번 자루를 뺀 나머지
	if state == S.PICK:
		state = S.AIM_V
	beep(262.0, 0.05, 0.10)


# 던지는 순간 벽에서 실제로 빠진다.
func _grip_consume() -> void:
	if grip_pick < 0 or grip_pick >= remaining.size():
		return
	remaining.remove_at(grip_pick)
	grip_slot.remove_at(grip_pick)
	grip_pick = -1
	darts_left = remaining.size()


func _finish_round() -> void:
	if total < target:
		# 목숨 아이템(조커 이식 110099) — 총점이 목표의 일정 비율 이상이면
		# 실패를 한 번 무르고 자신을 부순다. 라운드는 클리어로 친다.
		for i in owned.size():
			var sv: Dictionary = owned[i]
			if String(sv.get("k", "")) == "save" 					and float(total) >= float(target) * float(sv.v) / 100.0:
				var at := _slot_rect(mini(i, GameData.max_items() - 1)).get_center()
				owned.remove_at(i)
				_panel_reset()
				pop(at + Vector2(0.0, 24.0), "%s — 실패를 막았다" % sv.n,
						C_ACC, 11, 1.2)
				beep_seq([392.0, 523.0], 0.09, 0.16, 0.22)
				_round_end_wear()
				_settle_clear()
				return
		state = S.OVER
		won = false
		beep_seq([300.0, 240.0, 180.0], 0.13, 0.24, 0.22)
		return

	if round_no >= GameData.rounds_n():
		state = S.OVER
		won = true
		beep_seq([262.0, 330.0, 392.0, 523.0, 659.0], 0.10, 0.22, 0.26)
		return

	_round_end_wear()
	_settle_clear()


# 정산 — 실패 방지로 넘어온 라운드도 같은 길을 걷는다.
func _settle_clear() -> void:
	# 정산 내역
	var dart_gold: int = darts_left * GameData.gold_per_dart()
	@warning_ignore("integer_division")  # 보유 5당 1, 내림이 규칙이다
	var interest: int = mini(gold / GameData.interest_per(), GameData.interest_max())
	# gold 를 더하기 전에 부른다 — "밑천"과 이자가 같은 잔액을 보게 하려는 것이다.
	var item_rows := _gold_from_items()
	var item_gold := 0
	for r in item_rows:
		item_gold += r.v
	clear_gold_detail = [
		{"n": "클리어", "v": GameData.clear_gold()},
		{"n": "남은 다트 %d개" % darts_left, "v": dart_gold},
		{"n": "이자", "v": interest},
	]
	for r in item_rows:
		clear_gold_detail.append(r)
	gold += GameData.clear_gold() + dart_gold + interest + item_gold

	state = S.CLEAR
	beep_seq([392.0, 494.0, 587.0], 0.09, 0.18, 0.22)


# 라운드 종료의 마모 — 감쇠(rdec)와 확률 파괴(boom). 조커 이식이 들여왔다.
# 정산보다 먼저 부른다: 이번 라운드 일한 값은 이미 점수로 냈고, 골드 정산은
# 남은 자만 받는 것이 "라운드 종료 시 파괴" 의 뜻에 맞다.
func _round_end_wear() -> void:
	var i := owned.size() - 1
	while i >= 0:
		var it: Dictionary = owned[i]
		var dead := false
		if String(it.get("grow", "")) == "rdec":
			it.gs = int(it.get("gs", 0)) + 1
			if int(it.v) - int(it.gstep) * int(it.gs) <= 0:
				dead = true
		match String(it.get("boom", "")):
			"r6":
				if randf() < 1.0 / 6.0:
					dead = true
			"r1000":
				if randf() < 0.001:
					dead = true
		if dead:
			pop(_slot_rect(mini(i, GameData.max_items() - 1)).get_center()
					+ Vector2(0.0, 24.0), "%s — 부서졌다" % it.n, C_MULT, 11, 1.1)
			owned.remove_at(i)
			_panel_reset()
		i -= 1


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
			"blitz": v = it.gv if darts_left >= GameData.gold_blitz() else 0
			"broke": v = it.gv if gold <= GameData.gold_broke() else 0
			"round": v = it.gv
		if v > 0:
			rows.append({"n": it.n, "v": v})
	return rows


func _reroll_price() -> int:
	if rerolls_used < GameData.free_rerolls():
		return 0
	return GameData.reroll_base() + (rerolls_used - GameData.free_rerolls()) * GameData.reroll_step()


func _open_shop() -> void:
	# 라운드가 끝났다. 상점에 랙이 서므로 안 지우면 지난 판 "봉인" 딱지가
	# 유령으로 남는다. _gold_from_items() 가 sealed 를 읽으므로
	# _finish_round 안에서는 지우면 안 된다 — 여기가 유일하게 안전한 지점이다.
	sealed = -1
	sell_sel = -1
	buy_sel = -1
	_panel_reset()
	_sweep_reset()
	rerolls_used = 0
	reroll_cost = _reroll_price()
	_roll_stock()
	state = S.SHOP
	beep(440.0, 0.10, 0.18)


#  가중치 뽑기. 칩과 제약이 같은 저울을 쓴다 — 제약은 행에 w 를 들고 있고,
#  칩은 등급 표에서 가져온다. 균등 shuffle 이던 시절에는 14골드 희귀가
#  4골드 흔함과 같은 확률로 R2 매대에 떴다.
func _draw_weighted(pool: Array) -> Dictionary:
	if pool.is_empty():
		return {}
	var sum := 0.0
	var ws := []
	for e in pool:
		var w: float = float(e.w) if e.has("w") else GameData.item_weight(e)
		ws.append(maxf(w, 0.0))
		sum += maxf(w, 0.0)
	if sum <= 0.0:
		return pool[randi() % pool.size()]
	var r := randf() * sum
	for i in pool.size():
		r -= ws[i]
		if r <= 0.0:
			return pool[i]
	return pool[pool.size() - 1]


#  매대는 라운드 N 을 클리어한 뒤 N+1 을 위해 열린다. 그래서 폭도 해금도
#  다음 라운드 번호로 본다 — rounds.csv 의 마지막 행이 비어 있는 이유다.
func _roll_stock() -> void:
	stock.clear()
	var nxt := round_no + 1
	var w := GameData.shop_of(nxt)

	# 후보를 먼저 거른다 — 이미 가진 칩과 아직 안 풀린 칩은 애초에 안 뜬다.
	var pool := []
	for it in GameData.items():
		if _has_item(it.id) or GameData.item_min_round(it) > nxt:
			continue
		pool.append(it)

	var n := 0
	while n < int(w.items):
		var it := _draw_weighted(pool)
		if it.is_empty():
			break
		pool.erase(it)
		stock.append({"type": "item", "d": it, "cost": it.cost, "sold": false})
		n += 1

	# 판이 더는 못 받는 개조와 이미 산 개조를 여기서 뺀다.
	# 무효 구매가 사라지는 자리는 여기 한 곳이다.
	var mods := []
	for m in GameData.mods():
		if _mod_room(m.id):
			mods.append(m)
	mods.shuffle()
	var mn := 0
	for m in mods:
		if mn >= int(w.mods):
			break
		stock.append({"type": "mod", "d": m, "cost": m.cost, "sold": false})
		mn += 1
	# 개조를 다 샀거나 판이 꽉 찼다. 예전 코드는 여기서 mods[i] 로 죽었다.
	# 자리는 정확히 4개여야 하므로(_table_draw 의 ax/ay 주석) 칩으로 메운다.
	while mn < int(w.mods):
		var fill := _draw_weighted(pool)
		if fill.is_empty():
			break
		pool.erase(fill)
		stock.append({"type": "item", "d": fill, "cost": fill.cost, "sold": false})
		mn += 1

	var darts_pool := GameData.darts().slice(1)
	darts_pool.shuffle()
	for i in mini(int(w.darts), darts_pool.size()):
		var dd: Dictionary = darts_pool[i]
		stock.append({"type": "dart", "d": dd, "cost": dd.cost, "sold": false})

	# 소비 아이템 — 상점 구성이 미정(기획 메모 990006)이라 임시 규칙로 낸다:
	# shop_cons 가 켜져 있으면 칩 자리 하나를 소비 아이템으로 바꾼다.
	# 자리 수 4는 안 변한다 — _table_draw 의 ax/ay 전제가 사는 이유다.
	if GameData.tune_i("shop_cons") == 1:
		var cp := GameData.consumables()
		if not cp.is_empty():
			for k in stock.size():
				if stock[k].type == "item":
					var cd: Dictionary = cp[randi() % cp.size()]
					stock[k] = {"type": "cons", "d": cd, "cost": cd.cost,
							"sold": false}
					break

	# 딜러가 판을 쓸고 다시 던진다. 리롤이 배치를 안 바꾸면 낙하가 배치를
	# 결정한다는 전제 자체가 거짓말이 된다.
	_drop_roll()


func _deny() -> void:
	deny_flash = 1.0
	shake = 4.0
	beep_seq([200.0, 150.0], 0.06, 0.10, 0.16)


func _has_item(id: String) -> bool:
	for it in owned:
		if it.id == id:
			return true
	return false


# 못 사는 이유는 여기 한 곳에서만 판정한다.
# _buy 의 거절과 툴팁 문구가 갈라지면 "살 수 있어 보이는데 안 사지는" 상태가 생긴다.
# 빈 문자열이면 살 수 있다는 뜻이다. 5단계의 계산대 라벨이 세 번째 소비자가 된다.
func _buy_block(i: int) -> String:
	if i < 0 or i >= stock.size():
		return "없는 매물"
	var s: Dictionary = stock[i]
	if s.sold:
		return "이미 구매함"
	if gold < s.cost:
		return "골드가 %d 모자란다" % (s.cost - gold)
	if s.type == "item" and owned.size() >= GameData.max_items():
		return "칩 랙이 꽉 찼다 (%d/%d)" % [owned.size(), GameData.max_items()]
	if s.type == "dart" and _std_slot() < 0:
		return "바꿀 표준 다트가 없다"
	if s.type == "cons" and cons.size() >= GameData.cons_slots():
		return "소비 아이템 칸이 꽉 찼다 (%d/%d)" % [cons.size(), GameData.cons_slots()]
	return ""


func _buy(i: int) -> void:
	if _buy_block(i) != "":
		_deny()
		return

	var s: Dictionary = stock[i]
	gold -= s.cost
	s.sold = true
	match s.type:
		"item":
			# 사본이다. 성장 상태(gs)가 원본 카탈로그에 붙으면 다음 런까지
			# 살아남는다 — 컬렉션과 매대가 같은 사전을 읽기 때문이다.
			var cp: Dictionary = s.d.duplicate()
			cp.gs = 0
			owned.append(cp)
		"mod":
			_apply_mod(s.d.id)
		"dart":
			magazine[_std_slot()] = s.d
		"cons":
			# 칸으로 들어간다. 상점 즉시 사용은 칸에서 바로 누르면 되므로
			# 별도 경로가 없다 — 확인 버튼을 만들지 않는 규칙과도 맞는다.
			cons.append(s.d)
	beep_seq([523.0, 659.0], 0.07, 0.11, 0.20)


func _std_slot() -> int:
	for i in magazine.size():
		if magazine[i].id == "std":
			return i
	return -1


# ══════════════════════════════════════════════════════════
#  보드 개조
#
#  판은 상태가 아니라 mods_own 의 함수다. 살 때마다 GameData.BOARD_BASE 에서
#  MODS 표 순서대로 다시 굽는다 — 그래서 "먼저 산 개조가 나중 개조를 흔드는가"
#  라는 물음이 아예 성립하지 않는다. 순서 무관성은 증명이 아니라 구성이다.
#
#  바깥과 닿는 곳은 넷뿐이다.
#    _mod_room(id)   매대에 낼 수 있는가   (_roll_stock · _buy_block · _tip_build)
#    _apply_mod(id)  산다                  (_buy)
#    _board_bake()   판을 다시 굽는다       (_new_run · _apply_mod)
#    sectors / bull_* / trp_* / trp2_* / dbl_*   (_start_round 가 rt_* 로 복사)
#  이 구획만 지우고 다시 써도 나머지는 영향을 안 받는다.
# ══════════════════════════════════════════════════════════

# 표 한 줄을 판 한 판에 얹는다. b 와 sec 을 제자리에서 고친다.
func _mod_step(b: Dictionary, sec: Array, m: Dictionary) -> void:
	match m.k:
		"band":
			# 폭을 주고받는다. 트리플은 중심을 지키고, 더블은 바깥이 판의 끝이라
			# 안쪽만 민다. 두 증분의 합이 0 이므로 링 총 폭 0.20 이 보존된다.
			var dt: float = float(m.v[0]) * 0.5
			b.ti -= dt
			b.to += dt
			b.din -= float(m.v[1])
		"slide":
			# 절대 좌표가 아니라 din 기준이다. 속살·겉살이 먼저 걸려도 결과가 산다.
			var w: float = b.to - b.ti
			b.to = b.din - float(m.v)
			b.ti = b.to - w
		"ring":
			b.t2i = float(m.v[0])
			b.t2o = float(m.v[1])
		"bull":
			# 불은 넓어지고 한복판은 좁아진다. 둘을 같게 두면 25 칸이 사라져
			# 연속 불이 늘 same 이 되고 외골수·정밀이 터진다 — 그래서 안 붙인다.
			b.bi = float(m.v[0])
			b.bo = float(m.v[1])
		"out":
			b.dout = float(m.v)
		"swap":
			for k in int(m.v):
				var lo := 0
				for i in sec.size():
					if sec[i] < sec[lo]:
						lo = i
				sec[lo] = GameData.sector_max()
		"odd":
			# {2k-1, 2k} → 2k-1. 결과로 홀수 열 개가 정확히 두 번씩 남는다.
			for i in sec.size():
				if sec[i] % 2 == 0:
					sec[i] -= 1


# 이 개조 목록이면 판이 어떻게 되는가. 사지 않고 물어볼 수 있어야
# 매대 필터·거절 문구·실제 적용 셋이 같은 답을 쓴다.
func _board_of(ids: Array) -> Array:
	var b: Dictionary = GameData.BOARD_BASE.duplicate()
	var sec: Array = GameData.SECTORS_BASE.duplicate()
	for m in GameData.mods():      # 표 순서가 곧 적용 순서다
		if ids.has(m.id):
			_mod_step(b, sec, m)
	return [b, sec]


# 판이 성립하는가. 링 순서는 hit_info 의 if 사슬이 전제하는 그것이고,
# 판값 상한은 조합의 유일한 천장이다 — 개조마다 따로 두지 않는다.
func _board_ok(b: Dictionary, sec: Array) -> bool:
	var L := GameData.GEO
	var e: float = L.eps
	if b.bi < L.bi_min - e or b.bi > b.bo - L.bull_gap + e:
		return false
	if b.bo < L.bo_min - e:
		return false
	var inner: float = b.ti
	if b.t2o > 0.0:
		if b.t2o - b.t2i < L.band_min - e or b.t2o > b.ti - L.gap + e:
			return false
		inner = b.t2i
	if inner < b.bo + L.gap - e or inner < L.ti_min - e:
		return false
	if b.to - b.ti < L.band_min - e or b.to > b.din - L.gap + e:
		return false
	if b.dout - b.din < L.band_min - e:
		return false
	for v in sec:
		if v < 1 or v > GameData.sector_max():
			return false
	return GameData.board_val(b, sec) <= GameData.board_val_max() + e


func _board_same(b0: Dictionary, s0: Array, b1: Dictionary, s1: Array) -> bool:
	for k in b0:
		if absf(float(b0[k]) - float(b1[k])) > 0.0005:
			return false
	return s0 == s1


# 매대에 낼 수 있는가. 산 기록 · 배타 짝 · 기하 · 판값 · "정말 바뀌는가" 를
# 여기 한 곳에서 묻는다. 무효 구매가 생길 자리 자체가 없어지는 것이
# 이 함수의 존재 이유다. 새 개조를 만들면 여기만 통과시켜라.
func _mod_room(id: String) -> bool:
	if mods_own.has(id):
		return false
	var m := GameData.mod_of(id)
	if m.is_empty():
		return false
	if m.excl != "" and mods_own.has(m.excl):
		return false
	var nx := _board_of(mods_own + [id])
	if not _board_ok(nx[0], nx[1]):
		return false
	var cur := _board_of(mods_own)
	# 지금 여덟 종으로는 걸리지 않는다(배타 짝이 유일한 상쇄 경로였다).
	# 남겨 두는 것은 다음 사람이 개조를 늘릴 때의 계약이다.
	return not _board_same(cur[0], cur[1], nx[0], nx[1])


func _apply_mod(id: String) -> void:
	if not _mod_room(id):
		return
	mods_own.append(id)
	_board_bake()


# 판을 굽는다. 개조를 산 뒤와 런 초기화, 두 곳에서만 부른다.
func _board_bake() -> void:
	var r := _board_of(mods_own)
	var b: Dictionary = r[0]
	sectors = r[1]
	bull_i = b.bi
	bull_o = b.bo
	trp_in = b.ti
	trp_out = b.to
	trp2_in = b.t2i
	trp2_out = b.t2o
	dbl_in = b.din
	dbl_out = b.dout


func _in_stock(id: String) -> bool:
	for s in stock:
		if s.type == "item" and s.d.id == id:
			return true
	return false

# 골드 정산은 즉시 끝낸다 — 재진입 방지의 근거이자 버튼 가격표의 출처다.
# 판을 갈아 끼우는 일만 딜러에게 넘긴다.
func _reroll() -> void:
	if sweep_live:
		return                   # 쓸기는 중단도 재진입도 없다
	_hand_abort()
	if gold < reroll_cost:
		_deny()
		return
	gold -= reroll_cost
	rerolls_used += 1
	reroll_cost = _reroll_price()
	if drop_fast:
		_roll_stock()            # 헤드리스는 팔을 안 기다린다. 새 판이 곧 결과다
	else:
		_sweep_begin()           # 끝에서 _sweep_deal 이 _roll_stock 을 부른다
	beep(392.0, 0.09, 0.18)


func _next_round() -> void:
	_hand_abort()
	round_no += 1
	_open_stage()


# ── 스테이지 선택 ─────────────────────────────────────────

# 제약은 이름이 아니라 축으로 읽는다. modifiers.csv 에 band_mul 1.50 "넓은 판"
# 을 한 줄 더해도 여기는 안 늘어난다 — 그것이 이 표가 데이터인 이유다.
func mod_v(axis: String, dflt: float) -> float:
	for m in active_mods:
		if m.k == axis:
			return float(m.v)
	return dflt


func has_axis(axis: String) -> bool:
	for m in active_mods:
		if m.k == axis:
			return true
	return false


func _open_stage() -> void:
	# 봉인은 _start_round 에서만 다시 뽑힌다. 지우지 않으면 스테이지 선택
	# 화면의 칩 랙이 지난 라운드 봉인을 그대로 보여준다.
	sealed = -1
	sell_sel = -1
	buy_sel = -1
	stage_slots = owned.size()
	# 등급(정공·도전·극한)이 없다. 매 라운드 제약 셋을 깔고 하나를 고른다 —
	# 고르는 질문이 "얼마나 무리할까" 에서 "어느 쪽이 내 빌드에 덜 아픈가" 로
	# 바뀌었다. 보상은 붙지 않는다. 제약은 대가를 치르는 것이 아니라 그냥 판이다.
	var base := GameData.target_of(round_no)
	stage_pick.clear()
	stage_t = 0.0
	var left := GameData.modifiers().duplicate()
	for i in GameData.stage_picks():
		var md := _draw_weighted(left)
		if md.is_empty():
			break
		left.erase(md)               # 같은 카드가 두 장 깔리지 않는다
		# "높은 목표"(스펙 700001 · 확정)는 목표 자체를 올린다. 카드에 오른
		# 목표가 곧 그 라운드의 목표다 — 화면과 판정이 같은 수를 읽는다.
		var tgt := base
		if String(md.k) == "target_mul":
			tgt = int(ceil(float(base) * float(md.v)))
		stage_pick.append({"d": md, "target": tgt})
	state = S.STAGE
	beep_seq([392.0, 494.0], 0.09, 0.14, 0.18)


func _pick_stage(i: int) -> void:
	var sp: Dictionary = stage_pick[i]
	active_mods = [sp.d]
	target = sp.target
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
	var g := gauge_speed * mod_v("gauge_mul", 1.0)
	return g * (cur_dart.gauge if cur_dart.has("gauge") else 1.0)


func ch() -> float:
	return confirm_hold * mod_v("confirm_mul", 1.0)


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
	_drop_update(d)

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
				_grip_consume()
				state = S.FLY
				fly_t = 0.0
		S.FLY:
			fly_t += d
			if fly_t >= GameData.tune("fly_time"):
				_land()
		S.RESOLVE:
			qt -= d
			if qt <= 0.0:
				_next_step()

	if sell_sel >= 0:
		sell_t += d
		if not _can_sell() or sell_sel >= owned.size():
			sell_sel = -1
	if _is_play():
		grip_t += d

	# 벽에 꽂힌 다트 — 커서가 올라간 자루만 뽑혀 나온다.
	# 히트는 뽑히기 전 자리(_grip_pose 의 hit)로 하므로 표적이 안 도망간다.
	if grip_hov.size() != remaining.size():
		grip_hov.resize(remaining.size())
		grip_hov.fill(0.0)
	var gi := -1
	if state == S.PICK or state == S.AIM_V or state == S.AIM_H:
		var gm := get_local_mouse_position()
		for i in remaining.size():
			# 뒤에 그려진 것이 위에 있다. 마지막 명중을 택해 그리기 순서와 맞춘다.
			if _grip_pose(i).hit.has_point(gm):
				gi = i
	for i in grip_hov.size():
		grip_hov[i] = move_toward(grip_hov[i], 1.0 if i == gi else 0.0, d * 7.0)

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
			# 좌표가 아니라 함수를 직접 부른다. 4단계에서 _stock_rect 가 사라지므로
			# 여기서 미리 끊어 둬야 그 삭제가 순수 삭제가 된다.
			var buyable := []
			for i in stock.size():
				if _buy_block(i) == "":
					buyable.append(i)
			var roll := randf()
			if not buyable.is_empty() and roll < 0.55:
				_buy(buyable[randi() % buyable.size()])
			elif gold >= reroll_cost and roll < 0.8:
				_reroll()
			else:
				_next_round()
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
				KEY_F11:
					_toggle_fullscreen()
				KEY_ESCAPE:
					if state == S.SETTINGS or state == S.COLLECT:
						state = S.TITLE
					elif hand_st != H.NONE:
						_hand_abort()
					else:
						buy_sel = -1
				KEY_SPACE:
					if hand_st != H.NONE:
						_hand_abort()
					elif state == S.TITLE:
						_new_run()
					elif state == S.SETTINGS or state == S.COLLECT:
						state = S.TITLE
					elif state == S.PICK:
						_pick_dart(0)
					else:
						_click(Vector2(-1, -1))
		return

	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if _hand_press(mb.position):
				return                    # 삼킨다 — 탭인지 드래그인지 아직 모른다
			_click(mb.position)
		else:
			_hand_release(mb.position)
	elif e is InputEventMouseMotion:
		_hand_motion((e as InputEventMouseMotion).position)


func _click(m: Vector2) -> void:
	match state:
		S.PICK:
			for i in remaining.size():
				if _mag_rect(i).has_point(m):
					_pick_dart(i)
					return
		S.AIM_V, S.AIM_H:
			# 조준이 시작되면 다트를 못 바꾼다 — 확정 규칙이다
			# (조준중다트변경=False). 전에는 벽의 자루를 눌러 갈아탈 수
			# 있었는데, 그러면 "이 자루로 던진다" 는 결정이 끝까지 결정이
			# 아니게 된다. 고르는 자리는 PICK 하나다.
			#
			# 다트판 위에서만 잠긴다. 아무 데나 눌러도 되면 빗나간 클릭이
			# 그대로 조준이 되어, 무르지 못하는 실수가 생긴다.
			# 숫자 고리까지 포함해 R*1.22 로 넉넉히 잡는다.
			# m.x < 0 은 키보드에서 온 것이다 — 좌표가 없으므로 통과시킨다.
			if m.x < 0.0 or (m - BC).length() <= R * GameData.tune("aim_click_r"):
				_advance()
		S.CLEAR:
			# 좌표를 보지 않는다 — 아무 데나 누르든 스페이스든 상점으로 넘어간다
			_open_shop()
			return
		S.STAGE:
			# 마지막 장이 설 때까지는 못 고른다. 움직이는 것을 누르면
			# 무엇을 눌렀는지가 커서와 카드 중 어느 쪽 기준인지 갈린다.
			if stage_t < _deal_time():
				return
			for i in stage_pick.size():
				if _stage_rect(i).has_point(m):
					_pick_stage(i)
					return
		S.SHOP:
			if sweep_live:
				return          # 쓸기는 중단 불가다. 클릭을 통째로 삼킨다
			# 창구가 먼저다. 자리가 고정이라 낙하 검사보다 앞이고, _sell_hit
			# 보다도 앞이어야 한다 — 뒤에 두면 _sell_hit 이 sell_sel 을 지운 뒤
			# 창구가 "먼저 랙에서 팔 칩을 고른다" 로 거절해 2클릭 판매가 통째로
			# 죽는다. 랙(y[4,36])과 창구(y[112,244])는 y 로 갈려 있어 순서를
			# 바꿔도 서로 안 훔친다.
			var cz := _chute_at(m, 0.0)
			if cz >= 0:
				_chute_click(cz)
				return
			if _sell_hit(m):
				buy_sel = -1            # 펜딩 액션은 언제나 하나다
				return
			# 버튼이 먼저다 — 이 둘만은 낙하와 무관하게 자리가 고정이다.
			if _reroll_rect().has_point(m):
				_hand_abort()
				_reroll()
				return
			if _next_rect().has_point(m):
				_hand_abort()
				_next_round()
				return
			if _drop_busy():
				# 커서 밑에서 물건이 움직이는 동안 구매가 성립하면 "누른 것" 과
				# "산 것" 이 갈린다. 첫 클릭은 "지금 세운다" 로만 쓴다.
				_drop_settle()
				beep(330.0, 0.05, 0.10)
				return
			var hi := _shop_hit(m)
			if hi >= 0:
				_shop_tap(hi)           # 1클릭 즉시 구매 → 고르기로 내린다
			else:
				buy_sel = -1            # 맨 펠트 = 취소
		S.OVER:
			# 검증 실행은 소크 테스트라 곧장 다음 런으로 돈다. 사람은 제목으로.
			if _autoplay:
				_new_run()
			else:
				state = S.TITLE
				beep(330.0, 0.06, 0.12)
		S.TITLE:
			for i in 4:
				if _menu_rect(i).has_point(m):
					match i:
						0:
							_new_run()
						1:
							collect_tab = 0
							state = S.COLLECT
						2:
							state = S.SETTINGS
						3:
							get_tree().quit()
					beep(523.0, 0.06, 0.14)
					return
		S.SETTINGS:
			for i in 3:
				if _menu_rect(i).has_point(m):
					match i:
						0:
							_toggle_fullscreen()
						1:
							muted = not muted
							AudioServer.set_bus_mute(0, muted)
						2:
							state = S.TITLE
					beep(440.0, 0.05, 0.12)
					return
		S.COLLECT:
			for t in 5:
				if _col_tab_rect(t).has_point(m):
					collect_tab = t
					collect_page = 0
					beep(392.0, 0.04, 0.10)
					return
			if _col_pages() > 1:
				if _col_arrow_rect(false).has_point(m):
					collect_page = (collect_page - 1 + _col_pages()) % _col_pages()
					beep(392.0, 0.04, 0.08)
					return
				if _col_arrow_rect(true).has_point(m):
					collect_page = (collect_page + 1) % _col_pages()
					beep(392.0, 0.04, 0.08)
					return
			if _menu_back_rect().has_point(m):
				state = S.TITLE
				beep(330.0, 0.05, 0.10)


# ══════════════════════════════════════════════════════════
#  판정 / 정산
# ══════════════════════════════════════════════════════════

func hit_info(p: Vector2) -> Dictionary:
	var v := p - BC
	var r := v.length()
	# 기본점수·기본배수는 areas.csv(착탄 영역 · 전부 확정)가 정한다.
	# 여기 있던 50/25/0 하드코딩이 그리로 갔다. 기하(반지름)는 판의 모양이라
	# 개조가 주무르는 값이고, 영역의 값은 데이터다 — 소유가 다르다.
	if r > R * rt_dbl_out:                                    # ← ① 판벌이
		var ao := GameData.area("out")
		return {"base": ao.base, "mult": 0, "sector": -1, "idx": -1,
				"r0": 0.0, "r1": 0.0, "track": ao.track}
	if r <= R * rt_bull_i:
		var bi := GameData.area("bull_i")
		return {"base": bi.base, "mult": bi.mult, "sector": bi.base, "idx": -1,
				"r0": 0.0, "r1": R * rt_bull_i, "track": bi.track}
	if r <= R * rt_bull_o:
		var bo := GameData.area("bull_o")
		return {"base": bo.base, "mult": bo.mult, "sector": bo.base, "idx": -1,
				"r0": 0.0, "r1": R * rt_bull_o, "track": bo.track}

	var ang := atan2(v.x, -v.y)
	if ang < 0.0:
		ang += TAU
	var idx := int(floor((ang + PI / 20.0) / (TAU / 20.0))) % 20
	var val: int = sectors[idx]

	var m: int = GameData.area("single").mult
	var trk: int = GameData.area("single").track
	var r0 := R * rt_bull_o
	var r1 := R * rt_trp_in
	if r >= R * rt_dbl_in:
		m = GameData.area("double").mult
		trk = GameData.area("double").track
		r0 = R * rt_dbl_in
		r1 = R * rt_dbl_out                                   # ← ① 판벌이
	elif r >= R * rt_trp_in and r <= R * rt_trp_out:
		m = GameData.area("triple").mult
		trk = GameData.area("triple").track
		r0 = R * rt_trp_in
		r1 = R * rt_trp_out
	elif r > R * rt_trp_out:
		r0 = R * rt_trp_out
		r1 = R * rt_dbl_in
	elif rt_trp2_out > 0.0:                                   # ← ② 아랫목
		# 기존 네 가지의 조건식은 한 글자도 안 건드렸다. 이 가지가 잡는 구간은
		# "불 바깥 ~ 첫 트리플 안쪽" 하나뿐이고, 그건 지금까지 마지막 else 가
		# r0/r1 만 채우고 지나가던 죽은 땅이다. 배수를 바꾸는 새 경로는 하나다.
		if r >= R * rt_trp2_in and r <= R * rt_trp2_out:
			m = GameData.area("triple").mult
			trk = GameData.area("triple").track
			r0 = R * rt_trp2_in
			r1 = R * rt_trp2_out
		elif r < R * rt_trp2_in:
			r1 = R * rt_trp2_in        # 명중 섬광이 새 띠를 덮지 않게 구간을 자른다
		else:
			r0 = R * rt_trp2_out

	return {"base": val, "mult": m, "sector": val, "idx": idx, "r0": r0, "r1": r1,
			"track": trk}

# 반환값의 치역이 안 변한다:  mult ∈ {0,1,2,3}   sector ∈ {-1} ∪ [1,20] ∪ {25,50}
# 그래서 data.gd 의 check() 와 cond_text() 는 한 글자도 안 고친다.

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
			add_ring_fx(R * rt_dbl_in, R * rt_dbl_out, C_ACC, 0.50)
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
	if dead_idx >= 0 and info.idx == dead_idx:
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

	# 영역 강화 — 소비 아이템이 올린 트랙 레벨. 레벨별 수치 행이 전부
	# 미정이라 track_bonus 는 지금 0 을 돌려준다 — 자리만 세워 둔 훅이다.
	# 다트 보정 뒤에 얹는 순서는 임시다(공식 내 위치 미정 · 기획 메모 990008).
	# 빗나감(보드 아웃)의 점수는 정산 큐가 0 을 직접 넣으므로, 보드 아웃
	# 강화가 확정되면 그쪽 줄부터 고쳐야 한다.
	var tlv := int(track_lv.get(int(info.get("track", 0)), 0))
	if tlv > 0:
		var tb := GameData.track_bonus(int(info.track), tlv)
		info.base += int(tb.s)
		if info.mult > 0:
			info.mult += int(tb.m)

	# 꽂힌 자루마다 살짝 다른 각. 한 번 정하고 저장하므로 프레임 간 안 흔들린다.
	darts.append({"p": aim, "id": String(cur_dart.get("id", "std")),
			"rot": randf_range(-0.26, 0.26)})
	_impact(info)

	hit_flash = 1.0
	hit_idx = info.idx
	hit_r0 = info.r0
	hit_r1 = info.r1
	hit_bull = info.idx == -1 and info.mult > 0

	var same: bool = info.sector > 0 and info.sector == last_sector
	streak = streak + 1 if same else 0

	# 이번 발의 영역 종류. 패턴 추적의 화폐다.
	var zone := ""
	if info.mult > 0:
		if info.idx == -1:
			zone = "bull"
		elif info.mult == 3:
			zone = "triple"
		elif info.mult == 2:
			zone = "double"
		else:
			zone = "single"
	var is_risk: bool = info.mult >= 2 or info.sector >= 25
	throw6 += 1

	# rackval 배율 — 이 발에서 파는 값이 아니라 지금 랙의 값이다.
	var rv_all := 0
	for o in owned:
		rv_all += GameData.sell_value(o)

	var mag_hvy := 0
	for md in magazine:
		if String(md.get("id", "")) == "hvy":
			mag_hvy += 1

	var ctx := {
		"sector": info.sector,
		"mult": info.mult,
		"miss": info.mult == 0,
		"missp": last_miss,
		"left": aim.x < BC.x,
		"same": same,
		"first": dart_index == 0,
		"last": darts_left == 0,
		"streak": streak,
		"warm": round_trp,
		# ── 조커 이식 조건 재료. 패턴 깃발은 이번 발 이전의 것이다 —
		#    "맞힌 뒤" 는 완성한 발이 아니라 그 다음 발부터라는 뜻이다.
		"risk1": is_risk and not seen_risk,
		"few": round_darts <= 3,
		"sixth": throw6 >= 6,
		"pair": pat.get("pair", false),
		"trip": pat.get("trip", false),
		"quad": pat.get("quad", false),
		"pair2": pat.get("pair2", false),
		"spread": pat.get("spread", false),
		"zone3": pat.get("zone3", false),
		"zones2": pat.get("zones2", false),
		"zones4": pat.get("zones4", false),
		"rezone": zone != "" and zone_cnt.get(zone, 0) > 0,
		# ── 배율 재료 ──
		"darts_left": darts_left,
		"items_n": owned.size(),
		"gold": gold,
		"mag_hvy": mag_hvy,
		"round_darts": round_darts,
		"low": low_hit,
		"zonehist": zone_hist.get(zone, 0) + 1 if zone != "" else 0,
		"empty_n": GameData.max_items() - owned.size(),
		"rackval_all": rv_all,
		"rand01": randf(),
	}

	cur_chip = 0
	cur_mult = 0
	card_item = ""
	card_mode = 0
	pitch_step = 0
	queue.clear()

	card_side = -1 if aim.x > BC.x else 1
	# 왼쪽 카드는 반드시 위로 간다. 아래 왼쪽은 손 부채가 통째로 쓴다.
	card_y = 74.0 if card_side < 0 else (206.0 if aim.y < BC.y else 74.0)
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
			if it.k == "save":
				continue          # 목숨은 정산이 아니라 라운드 실패가 읽는다
			# fire 성장은 발동 자체가 걸음이다 — 먼저 오르고 그 값으로 낸다.
			if String(it.get("grow", "")) == "fire":
				it.gs = int(it.get("gs", 0)) + int(it.get("gstep", 0))
			# rackval 은 자기 몫을 뺀다 — 자기 판매가로 자기가 커지면 순환이다.
			ctx.rackval_others = ctx.rackval_all - GameData.sell_value(it)
			var amt: int = GameData.item_amt(it, ctx)
			if amt != 0:
				queue.append({"k": "item", "i": i, "kind": it.k, "v": amt,
						"lbl": "%s  %s" % [it.n, GameData.eff_text(
								"mult" if it.k == "mult_rand" else it.k, amt)]})
			# 보조 효과 — 복합 아이템(점수+배수)의 두 번째 줄
			if String(it.get("k2", "")) != "" and it.v2 != 0:
				queue.append({"k": "item", "i": i, "kind": it.k2, "v": it.v2,
						"lbl": "%s  %s" % [it.n, GameData.eff_text(it.k2, it.v2)]})
			# 즉시 골드 — 위험 영역 절반 확률
			if String(it.get("g", "")) == "risk50" and randf() < 0.5:
				gold += int(it.get("gv", 0))
				pop(_slot_rect(mini(i, GameData.max_items() - 1)).get_center()
						+ Vector2(0.0, 24.0), "+%d" % it.gv, C_GOLD, 11, 0.8)
			# 영역 승급 — 발동 4회 중 1회꼴로 맞은 영역의 강화 트랙이 오른다
			if String(it.get("side", "")) == "trackup25" and randf() < 0.25 \
					and int(info.get("track", 0)) > 0:
				track_lv[info.track] = int(track_lv.get(info.track, 0)) + 1
				pop(BC + Vector2(0.0, -52.0), "영역 강화 +1", C_ACC, 10, 0.9)
		queue.append({"k": "total"})

	# 이력 갱신은 ctx 를 만든 뒤다 — 패턴은 다음 발부터 산다.
	if zone != "":
		if info.sector >= 1 and info.sector <= 20:
			sec_cnt[info.sector] = int(sec_cnt.get(info.sector, 0)) + 1
		zone_cnt[zone] = int(zone_cnt.get(zone, 0)) + 1
		zone_hist[zone] = int(zone_hist.get(zone, 0)) + 1
		if is_risk:
			seen_risk = true
		if info.sector >= 1 and info.sector <= 20:
			low_hit = info.sector if low_hit == 0 else mini(low_hit, info.sector)
		# 깃발 — 한 번 서면 라운드 끝까지 산다
		var pairs := 0
		var maxrep := 0
		for kx in sec_cnt:
			maxrep = maxi(maxrep, int(sec_cnt[kx]))
			if int(sec_cnt[kx]) >= 2:
				pairs += 1
		if maxrep >= 2: pat.pair = true
		if maxrep >= 3: pat.trip = true
		if maxrep >= 4: pat.quad = true
		if pairs >= 2: pat.pair2 = true
		if sec_cnt.size() >= 3: pat.spread = true
		for kz in zone_cnt:
			if int(zone_cnt[kz]) >= 3:
				pat.zone3 = true
		if zone_cnt.size() >= 2: pat.zones2 = true
		if zone_cnt.size() >= 4: pat.zones4 = true
	if throw6 >= 6:
		throw6 = 0
	# 성장 걸음 — hitmiss 는 매 발, tdec 는 던질 때마다
	for o in owned:
		match String(o.get("grow", "")):
			"hitmiss":
				o.gs = maxi(0, int(o.get("gs", 0))
						+ (int(o.gstep) if info.mult > 0 else -int(o.gstep)))
			"tdec":
				o.gs = int(o.get("gs", 0)) + 1

	last_sector = info.sector
	last_miss = info.mult == 0
	# ctx 를 만든 뒤여야 한다 — 불을 붙인 그 다트에는 손맛이 안 뜬다.
	# 그게 삼중고(트리플 위에)와 손맛(트리플 뒤에)이 갈리는 지점이다.
	if info.mult == 3:
		round_trp = true
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

# ══════════════════════════════════════════════════════════
#  스테이지 카드 — 펠트에 눕는다
#
#  52° 정사영에서 면 위의 축정렬 사각형은 화면에서도 축정렬 사각형이고
#  깊이만 flat(0.788) 배로 눌린다. 전단도 원근 배율도 없다 — 그래서
#  "눕히기" 는 h 에 곱셈 하나이고 draw_set_transform 금지 불변식을 안 건드린다.
#  화면 높이 86 = 면 깊이 109.1 × 0.788.
#
#  ⚠ 정직하게 적는다: 지금 카드도 이미 가로가 긴 1.39:1 이고 위 주석이
#  이미 "카드는 펠트 위에 눕는다" 고 적어 뒀다. 이번 변경의 실체는 투영을
#  바꾸는 것이 **아니라** 다음 넷이다.
#    ① h 108 → 86, 비 1.39 → 1.78. 더 납작해진다.
#    ② 그림자 벡터를 임의값 (3,4) 에서 매물과 같은 TBL.light*3.35 = (1.5,3.0)
#       으로 바꾼다. 같은 빛 아래 있다는 진술이 "눕혔다" 의 절반이다.
#    ③ 가까운 모서리에 두께 2px. 칩 옆면(4.5*tall=2.77)과 같은 어법이고,
#       두께가 없으면 카드가 펠트에 인쇄된 무늬로 읽힌다.
#    ④ 폭을 상수에서 n 역산으로 바꾼다. 지금 값은 n=4 에서
#       150*4+14*3 = 642 > 640 으로 실제로 터진다.
#  ①만으로도 딜러 여유가 7px(현재 딜러 아래끝 119 vs 카드 126)에서
#  28.5px 로 벌어진다. 새 딜러(111.5)와 합쳐 "안 가린다" 가 성립한다.
#
#  ── 글자는 왜 안 눕히는가 ────────────────────────────
#  카드는 눌리고 카드 위의 인쇄는 안 눌린다. 새 예외가 아니라 네 번째 사례다.
#    _chip_flat  0.788 로 눌린 원반 위에 정면 숫자 12px
#    _bill_draw  누운 물건 앞에 정면 가격 플라크
#    _icon_mod   펠트에 놓인 캐비닛의 판 그림이 등방 원
#  상점 한 번에 여덟 번 일어나는 일이다. 카드만 글자를 눕히면 한 화면에
#  활자법이 둘이 된다. 그리고 크기 9 한글 몸통 ≈7px × 0.788 = 5.5px 라
#  가로획 셋짜리(목·표·풍)가 뭉갠다 — 착시는 0 을 사고 가독성을 전부 판다.
#  아이콘도 같은 이유로 안 눕힌다. 카드의 인쇄물이다.
#
#  ── 넓이 불변식 ────────────────────────────────────
#  줄은 x[76,564] = 488 에 갇힌다. 카드 윗변 y=140 에서 창구 빗변이
#  _chute_edge(140) = 63.0 이므로 양쪽 13px 이 남고, 닫힌 셔터(y138·151,
#  x 최대 64.2/56.4)에도 안 닿는다.
#    n=3 → w 153.3 ✔   n=4 → w 111.5 ✔   n=5 → w 86.4 ✘
#  n=5 가 죽는 이유는 폭이 아니라 글자다. 설명 최장 "트리플·더블 링 폭
#  0.5배" 가 크기 9 에서 실측 95.0px 이고, n=4 의 안쪽 폭 99.5 가 마지막
#  여유다. stage_picks 를 5 이상으로 올리려면 설명을 툴팁으로 내리는
#  별개 결정이 먼저다.
# ══════════════════════════════════════════════════════════
const CARD := {
	"x0": 76.0, "y": 140.0, "h": 86.0, "gap": 14.0, "th": 2.0,
	"icon": 30.0, "icon_r": 17.0, "name": 64.0, "desc": 81.0,
}


func _stage_rect(i: int) -> Rect2:
	var n: float = maxf(float(stage_pick.size()), 1.0)
	var span: float = VIEW.x - CARD.x0 * 2.0
	var w: float = (span - CARD.gap * (n - 1.0)) / n
	return Rect2(Vector2(CARD.x0 + float(i) * (w + CARD.gap), CARD.y),
			Vector2(w, CARD.h))


#  딜러가 한 장씩 밀어 내려 준다. 카운터 뒤에서 나와 자리에 서고 한 번 튄다.
#  물리 트레이에 안 넣는다 — 카드 셋이 트레이 폭(408)보다 넓어 솔버에 넣으면
#  서로 밀려나 자리가 안 선다. 여기서 필요한 것은 충돌이 아니라 손짓이다.
const DEAL := {
	"dur": 0.34,     # 한 장이 미끄러져 자리에 서는 시간
	"stag": 0.11,    # 장 사이 시차. 왼쪽부터 나온다
	"hop": 4.0,      # 착지 뒤 튀는 높이(px)
}


func _deal_time() -> float:
	return float(DEAL.dur) + float(DEAL.stag) * maxf(float(stage_pick.size()) - 1.0, 0.0)


func _stage_pose(i: int) -> Vector2:
	var r := _stage_rect(i)
	var t: float = stage_t - float(i) * float(DEAL.stag)
	var k: float = clampf(t / float(DEAL.dur), 0.0, 1.0)
	var e: float = 1.0 - pow(1.0 - k, 3.0)
	var from := Vector2(VIEW.x * 0.5 - r.size.x * 0.5, TBL.fy - r.size.y - 4.0)
	var p := from.lerp(r.position, e)
	if k >= 1.0:
		var bt: float = t - float(DEAL.dur)
		if bt < 0.6:
			p.y -= float(DEAL.hop) * exp(-bt * 11.0) * absf(sin(bt * 19.0))
	return p


# 칸 번호에서 0~1 을 뽑는다.
# sin(i * 12.9898) 을 그대로 쓰면 작은 i 에서 값이 한쪽으로 몰린다 —
# 0, 0.41, 0.75, 0.95, 0.99 로 전부 양수에 커지기만 해서 다섯 자루가
# 같은 방향으로 거의 같은 각이 됐다. 큰 수를 곱해 소수부만 남겨야 흩어진다.
func _grip_rnd(i: int, seed: float) -> float:
	return fposmod(sin(float(i) * 12.9898 + seed) * 43758.5453, 1.0)


# 자루마다 살짝 다른 기울기. 칸 번호로만 정해지므로 프레임 간 안 흔들리고
# 리롤·재입장에도 같은 배치가 나온다.
func _grip_tilt(i: int) -> float:
	return GRIP.tilt + (_grip_rnd(i, 78.233) - 0.5) * 2.0 * GRIP.jit


# i 번 다트가 벽 어디에 어떤 각으로 꽂혀 있는가.
# 그리기와 잡기가 같은 함수를 본다 — 갈라지면 보이는 곳과 눌리는 곳이 어긋난다.
func _grip_pose(i: int) -> Dictionary:
	# 칸은 시작 때 배정된 그대로다. 남은 개수가 아니라 시작 개수로 가운데를
	# 맞추므로, 자루가 빠져도 나머지가 제자리에 그대로 꽂혀 있다.
	var slot: int = grip_slot[i] if i < grip_slot.size() else i
	# 깊이와 높이도 같이 흔든다. 각도만 흔들면 자로 잰 듯 줄 맞춘 티가 남는다.
	var base := Vector2(
			GRIP.x + (_grip_rnd(slot, 12.77) - 0.5) * 2.0 * GRIP.deep,
			GRIP.cy - float(maxi(grip_n, 1) - 1) * GRIP.dy * 0.5 + float(slot) * GRIP.dy
					+ (_grip_rnd(slot, 41.31) - 0.5) * 2.0 * GRIP.sway)
	var rot: float = _grip_tilt(slot)
	# 뽑히는 방향은 자루 축을 따라 꼬리 쪽이다. 옆으로 밀면 뽑는 것으로 안 보인다.
	var axis := Vector2(6.0, -10.0).normalized().rotated(rot)
	var lf: float = GRIP.lift * (grip_hov[i] if i < grip_hov.size() else 0.0)
	if i == grip_pick:
		lf += GRIP.pull
	return {
		"c": base - axis * lf,
		"rot": rot,
		# 히트 상자는 뽑히기 전 자리에 고정한다. 그리는 자리를 따라가면
		# 커서를 올린 순간 표적이 도망가 다시 잡아야 한다.
		"hit": Rect2(base - Vector2(GRIP.hit, GRIP.hit),
				Vector2(GRIP.hit * 2.0, GRIP.hit * 2.0)),
	}


func _mag_rect(i: int) -> Rect2:
	return _grip_pose(i).hit


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
	elif state == S.TITLE:
		_draw_title()
	elif state == S.SETTINGS:
		_draw_settings()
	elif state == S.COLLECT:
		_draw_collect()
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
	if state == S.OVER or state == S.TITLE or state == S.SETTINGS \
			or state == S.COLLECT:
		return
	if not _bar_hidden():
		_draw_topbar()
	if state != S.CLEAR:            # 정산 화면은 그 자체가 명세다
		_bank_draw()
		_cons_draw()
		_panel_draw()
		_cap_draw()
		if _is_play():
			_grip_draw()
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
		draw_colored_polygon(annulus(R * rt_dbl_in * push, R * rt_dbl_out * push, a0, a1), ring_c)

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


func _grip_draw() -> void:
	if state == S.CLEAR or state == S.SHOP or state == S.STAGE or state == S.OVER:
		return
	var n := remaining.size()
	var picking := state == S.PICK

	# 왼쪽 벽. 꽂힐 면이 없으면 다트가 그냥 떠 있는 것으로 읽힌다.
	var w: float = GRIP.wall
	draw_rect(Rect2(0.0, 18.0, w, VIEW.y - 18.0), C_DARK.lightened(0.06))
	draw_line(Vector2(w, 18.0), Vector2(w, VIEW.y), C_WIRE.darkened(0.25), 1.0)
	# 결 — 벽이 면이라는 것만 알리면 된다
	for gy in range(30, 356, 14):
		draw_line(Vector2(2.0, float(gy)), Vector2(w - 2.0, float(gy) + 3.0),
				C_DARK.darkened(0.25), 1.0)
	# 꽂힌 자리마다 파인 자국
	for i in n:
		var ps := _grip_pose(i)
		if grip_t >= float(i) * GRIP.gap + GRIP.fly:
			draw_circle(Vector2(w - 1.0, ps.c.y), 2.4, C_BG.darkened(0.25))

	var hov := -1
	for i in n:
		if i < grip_hov.size() and grip_hov[i] > 0.5:
			hov = i

	# 고른 자루와 커서가 얹힌 자루를 맨 나중에 그려 위로 올린다.
	var top: int = hov if hov >= 0 else grip_pick
	for i in n:
		if i != top:
			_grip_one(i, picking)
	if top >= 0:
		_grip_one(top, picking)


# 라운드에 들어서면 오른쪽에서 날아와 하나씩 꽂힌다.
# 들어서자마자 이미 꽂혀 있으면 누가 언제 꽂았는지가 설명되지 않는다.
func _grip_one(i: int, picking: bool) -> void:
	var ps := _grip_pose(i)
	var slot: int = grip_slot[i] if i < grip_slot.size() else i
	var t: float = clampf((grip_t - float(slot) * GRIP.gap) / GRIP.fly, 0.0, 1.0)
	if t <= 0.0:
		return
	var e: float = 1.0 - pow(1.0 - t, 3.0)
	var from: Vector2 = ps.c + Vector2(760.0, -46.0)
	# 나는 동안은 진행 방향으로 눕고, 꽂히면서 제 기울기로 선다.
	var rr: float = lerpf(GRIP.tilt - 0.16, ps.rot, e)
	# 고른 자루는 뽑혀 나와 밝게 선다 — 지금 던질 것이 무엇인지가 벽 위에서 읽힌다.
	var dim: float = 0.0 if (picking or i == grip_pick) else 0.26
	_icon_dart(from.lerp(ps.c, e), GRIP.dl + (3.0 if i == grip_pick else 0.0),
			remaining[i].id, dim, rr, 1.0)


func _draw_darts() -> void:
	for e in darts:
		# 촉이 착탄점에 오도록 중심을 뒤로 물린다 — _icon_dart 는 tip = c + dir*dl 이다.
		# 예전에는 선 하나와 점 하나로 그려서 다트가 아니라 압정으로 보였다.
		var dir := Vector2(6.0, -10.0).normalized().rotated(e.rot)
		_icon_dart(e.p - dir * DART_DL, DART_DL, e.id, 0.0, e.rot, 1.0)


func _draw_aim() -> void:
	if state == S.AIM_V:
		draw_line(Vector2(BC.x - 151.0, aim.y), Vector2(BC.x + 151.0, aim.y), C_ACC, 1.0)
	elif state == S.AIM_H:
		draw_line(Vector2(BC.x - 151.0, aim.y), Vector2(BC.x + 151.0, aim.y),
				C_ACC.darkened(0.55), 1.0)
		draw_line(Vector2(aim.x, 68.0), Vector2(aim.x, 334.0), C_ACC, 1.0)
	elif state == S.CONFIRM:
		draw_line(Vector2(BC.x - 151.0, aim.y), Vector2(BC.x + 151.0, aim.y), C_ACC, 1.0)
		draw_line(Vector2(aim.x, 68.0), Vector2(aim.x, 334.0), C_ACC, 1.0)
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
	draw_string(font, Vector2(8, 13), "R%d/%d" % [round_no, GameData.rounds_n()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TXT)
	var done: int = round_no if (state == S.CLEAR or state == S.SHOP) else round_no - 1
	var pip: Rect2 = LAY.bar_pip
	for i in GameData.rounds_n():
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
		# 숫자 대신 아이콘. 하단의 제약 줄을 지웠으므로 여기가 유일한 상시 표기다.
		# 무엇이 걸렸는지까지 보이므로 "제약 2" 보다 담는 정보가 오히려 많다.
		for k in mini(active_mods.size(), 3):
			_icon_modifier(Vector2(LAY.bar_mod + 8.0 + float(k) * 16.0, 9.0),
					6.0, active_mods[k].id, 0.0)


# ── 자금 ──────────────────────────────────────────────────
func _bank_draw() -> void:
	# 이자 줄은 상점·스테이지에서만 의미가 있다. 그때만 판을 늘려 담는다.
	# 플레이 중에는 짧게 끝나야 그 아래 탄창 헤더가 들어갈 자리가 난다.
	var r := _bank_rect()
	draw_rect(r, C_PANEL)
	# 런 바가 없는 화면에서는 머리띠가 진행바다. 몇 판째인지가 안 사라진다.
	if _bar_hidden():
		var k := clampf(float(_run_done()) / float(GameData.rounds_n()), 0.0, 1.0)
		draw_rect(Rect2(r.position, Vector2(r.size.x * k, 2.0)), C_ACC)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), C_GOLD.darkened(0.35))
	# deny_flash 는 상점 중앙 골드 텍스트가 쓰던 값을 그대로 물려받는다
	var gc: Color = C_GOLD.lerp(C_MULT, deny_flash)
	var jx := randf_range(-deny_flash, deny_flash) * 2.0
	draw_gold(r.get_center().x + jx, r.position.y + 26.0, str(gold), 16, gc)

	# 이자 줄은 판이 늘어난 화면에서만 담긴다.
	if r.size.y < 46.0:
		return

	# 이자 미리보기. 계산식은 _finish_round 와 같고 둘 다 지급 전 잔액을 본다.
	if state == S.SHOP and round_no + 1 >= GameData.rounds_n():
		# R8 은 정산이 없다 (_finish_round 의 round_no >= ROUNDS 조기 return 이
		# 골드 지급 블록보다 앞선다). 남긴 골드는 영원히 안 돌아온다.
		draw_string(font, r.position + Vector2(0.0, 42.0), "마지막 판",
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, C_MULT.lightened(0.2))
	else:
		@warning_ignore("integer_division")  # 위 _finish_round 와 같은 식이어야 한다
		var itr: int = mini(gold / GameData.interest_per(), GameData.interest_max())
		draw_string(font, r.position + Vector2(0.0, 42.0), "이자 +%d" % itr,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9,
				C_GOLD.darkened(0.3) if itr > 0 else C_DIM.darkened(0.35))


# ── 칩 꼬리표 ─────────────────────────────────────────────
func _cap_draw() -> void:
	var r: Rect2 = LAY.cap
	r.position.y += _hud_dy()
	draw_rect(r, C_FELT)                                   # 랙과 같은 재질
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), C_FELT.lightened(0.14))
	draw_string(font, r.position + Vector2(0.0, 20.0), "칩",
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, C_DIM.darkened(0.1))
	draw_string(font, r.position + Vector2(0.0, 36.0),
			"%d/%d" % [owned.size(), GameData.max_items()],
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13,
			C_ACC if owned.size() >= GameData.max_items() else C_TXT)


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
	"y": 20.0,           # 랙 위쪽. 아래 y[56,112] 가 딜러 자리다
	# 높이 46 을 38 로 줄인 것은 딜러 때문이다. 랙 아래끝(58)과 카운터(77)
	# 사이의 19px 이 머리가 들어갈 유일한 자리다 — 랙을 그대로 두면 실루엣이
	# 통째로 랙 뒤에 숨어 "누가 판다" 가 화면에서 안 읽힌다.
	"h": 32.0,           # 랙 높이
	"cell": 42.0,        # 칩 한 칸 폭
	"pad": 6.0,          # 랙 안쪽 여백
	"r": 13.0,           # 칩 반지름
	"chip_dy": -1.0,     # 칸 안에서 칩 중심을 얼마나 올릴지

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

# 쥔 손 — 남은 다트를 부채로 쥐고 있다.
#  실제 다트 선수는 남은 다트를 반대쪽 손에 쥔다. 그걸 그대로 둔다.
#  남은 개수를 숫자나 슬롯이 아니라 손의 무게가 말한다.
#  중심이 화면 아래 밖이라 부채가 화면 하단에서 올라오는 것으로 읽힌다.
const GRIP := {
	# 왼쪽 벽에 꽂아 둔 다트. 손을 그리지 않는다 — 도형으로 그린 손은
	# 어느 각도로 그려도 색 덩어리로 읽혔다.
	# 촉 끝 = x - dl. 이 값이 벽 두께보다 작아야 꽂힌 것으로 읽힌다.
	# 34 - 26 = 8 이라 벽(0~12) 안으로 4px 물린다.
	"x": 34.0,           # 꽂힌 다트의 중심 x
	"cy": 224.0,         # 세로 가운데 — 자루 수와 무관하게 여기 모인다
	"dy": 31.0,          # 자루 사이 간격
	"dl": 26.0,          # 다트 반길이
	# 왼쪽 벽에 수직으로 = 화면에서 수평으로 꽂힌다. 촉이 왼쪽, 꼬리가 오른쪽.
	# _icon_dart 가 이미 atan2(6,10) 만큼 기울어 있으므로 그만큼 빼 준다.
	"tilt": -2.111,      # -PI/2 - 0.5404
	"jit": 0.105,        # 자루마다 ±6도. 넘으면 흩어져 보이고 없으면 찍어낸 것으로 보인다
	"deep": 4.0,         # 박힌 깊이 편차 — 어떤 건 더 들어가고 어떤 건 덜 들어간다
	"sway": 2.5,         # 높이 편차 — 칸 간격은 그대로 두고 자리만 살짝 흔든다
	"lift": 11.0,        # 커서를 올린 자루가 뽑혀 나오는 거리
	"pull": 26.0,        # 고른 자루가 뽑혀 나오는 거리 — 든 것으로 읽혀야 한다
	"hit": 18.0,         # 잡기 반경
	"fly": 0.26,         # 한 자루가 날아와 꽂히기까지
	"gap": 0.085,        # 자루 사이 시차
	"wall": 12.0,        # 왼쪽 벽 두께
	"ang": 0.5404,       # _icon_dart 가 이미 기울어 있는 각 = atan2(6, 10)
}



var grip_hov := []              # 다트별 뽑힘 정도 0~1
var grip_t := 0.0               # 라운드 시작 후 경과 — 날아와 꽂히는 연출용
var grip_slot := []             # remaining[i] 가 벽의 몇 번 칸에 꽂혀 있는가
var grip_n := 0                 # 이번 라운드 시작 자루 수 — 칸 배치의 기준
var grip_pick := -1             # 지금 고른 자루 (remaining 인덱스). 던져야 빠진다

var slot_hot := []              # 발동 후 이름을 띄우는 잔여 시간


func _panel_ensure() -> void:
	# 슬롯 수는 아이템 보유 한계를 그대로 따라간다.
	var n: int = GameData.max_items()
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
	# _slot_rect 가 이걸 파생하므로 판매 판정·툴팁 앵커·구매 비행 목표가
	# 전부 따라온다. 좌표 소유자를 안 늘리는 자리다.
	var n: int = GameData.max_items()
	var w: float = PANEL.cell * n + PANEL.pad * 2.0
	return Rect2(Vector2((VIEW.x - w) * 0.5, PANEL.y + _hud_dy()), Vector2(w, PANEL.h))


func _slot_rect(i: int) -> Rect2:
	var pr := _panel_rect()
	return Rect2(Vector2(pr.position.x + PANEL.pad + i * PANEL.cell, pr.position.y),
			Vector2(PANEL.cell, pr.size.y))


func _chip_ti(cost: int) -> int:
	for i in CHIP_TIERS.size():
		if cost <= CHIP_TIERS[i].max:
			return i
	return CHIP_TIERS.size() - 1


# 조건 그림 — 칩이 "언제" 터지는가를 얼굴에 새긴다.
#
# 지금까지 칩은 값(얼마나)만 보였다. 그래서 등급·잉크·숫자가 같으면
# 조건이 정반대여도 똑같이 보였다 — 홀수 애호와 짝수 애호, 좌익수와 우익수가
# 화면에서 구분 불가였다. 재미의 절반은 조건 쪽인데 그게 안 그려지고 있었다.
#
# 열여섯 조건을 원시 도형만으로 가른다. 글자는 안 쓴다 — 랙 반지름 15 에서
# 얼굴에 남는 자리가 지름 17px 라 한글은 물론 숫자도 둘은 안 들어간다.
# 갈리는 축을 도형 갈래로 나눠 뒀다: 선 / 점 / 반원 / 삼각 / 원 / 원쌍 / 막대 / X.
# 같은 갈래 안에서만 개수와 방향으로 갈리므로 실루엣이 먼저 읽힌다.
func _icon_cond(c: Vector2, r: float, cond: String, col: Color) -> void:
	var u := r * 0.62          # 도형 반경 — 얼굴 안에 머무는 상한
	# 숫자 지정 조건 — 숫자가 곧 아이콘이다. 셋 넘으면 첫 수에 점을 단다.
	if cond.begins_with("sec:"):
		var parts := cond.substr(4).split(",")
		var txt := "·".join(parts) if parts.size() <= 2 else parts[0] + "⋯"
		draw_string(font, c + Vector2(-r, u * 0.55), txt,
				HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, maxi(6, int(u * 1.1)), col)
		return
	match cond:
		"always":
			draw_circle(c, u * 0.78, col)
		"triple":
			for i in 3:
				var y := c.y + (float(i) - 1.0) * u * 0.62
				draw_line(Vector2(c.x - u, y), Vector2(c.x + u, y), col, 1.0)
		"double":
			for i in 2:
				var y := c.y + (float(i) * 2.0 - 1.0) * u * 0.42
				draw_line(Vector2(c.x - u, y), Vector2(c.x + u, y), col, 1.0)
		"bull":
			draw_arc(c, u * 0.86, 0.0, TAU, 14, col, 1.0)
			draw_circle(c, u * 0.34, col)
		"odd":
			draw_circle(c, u * 0.46, col)
		"even":
			for k in [-1.0, 1.0]:
				draw_circle(c + Vector2(k * u * 0.48, 0.0), u * 0.42, col)
		"left":
			draw_colored_polygon(_half_disc(c, u, true), col)
			draw_arc(c, u, 0.0, TAU, 16, col, 1.0)
		"right":
			draw_colored_polygon(_half_disc(c, u, false), col)
			draw_arc(c, u, 0.0, TAU, 16, col, 1.0)
		"big":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -u),
					c + Vector2(u * 0.9, u * 0.62), c + Vector2(-u * 0.9, u * 0.62)]), col)
		"small":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, u),
					c + Vector2(u * 0.9, -u * 0.62), c + Vector2(-u * 0.9, -u * 0.62)]), col)
		"same":
			# 두 원이 반쯤 겹친다 — 겹침이 곧 "같다"
			for k in [-1.0, 1.0]:
				draw_arc(c + Vector2(k * u * 0.34, 0.0), u * 0.62, 0.0, TAU, 14, col, 1.0)
		"diff":
			# 하나는 채우고 하나는 비운다 — 대비가 곧 "다르다"
			draw_circle(c + Vector2(-u * 0.46, 0.0), u * 0.44, col)
			draw_arc(c + Vector2(u * 0.46, 0.0), u * 0.44, 0.0, TAU, 12, col, 1.0)
		"first":
			draw_line(c + Vector2(-u * 0.8, -u * 0.7), c + Vector2(-u * 0.8, u * 0.7), col, 1.6)
			draw_circle(c + Vector2(u * 0.3, 0.0), u * 0.38, col)
		"last":
			draw_circle(c + Vector2(-u * 0.3, 0.0), u * 0.38, col)
			draw_line(c + Vector2(u * 0.8, -u * 0.7), c + Vector2(u * 0.8, u * 0.7), col, 1.6)
		"streak":
			for i in 3:
				draw_circle(c + Vector2((float(i) - 1.0) * u * 0.66,
						(1.0 - float(i)) * u * 0.52), u * 0.28, col)
		"miss":
			for k in [-1.0, 1.0]:
				draw_line(c + Vector2(-u * 0.75, k * u * 0.75),
						c + Vector2(u * 0.75, -k * u * 0.75), col, 1.4)
		"missp":
			# 빗나감이 이어졌다 — 작은 X 둘이 나란히 선다
			for dx in [-0.52, 0.52]:
				for k in [-1.0, 1.0]:
					draw_line(c + Vector2((dx - 0.38) * u, k * u * 0.62),
							c + Vector2((dx + 0.38) * u, -k * u * 0.62), col, 1.2)
		"risk":
			# 위험 영역 셋 — 두 호(띠) + 중심 점(불)
			draw_arc(c, u * 0.92, -2.2, -0.9, 8, col, 1.0)
			draw_arc(c, u * 0.92, 0.9, 2.2, 8, col, 1.0)
			draw_circle(c, u * 0.3, col)
		"risk1":
			draw_arc(c, u * 0.92, -2.2, 2.2, 14, col, 1.0)
			draw_string(font, c + Vector2(-u, u * 0.5), "1",
					HORIZONTAL_ALIGNMENT_CENTER, u * 2.0, maxi(6, int(u * 1.2)), col)
		"few":
			for i in 3:
				var bx := c.x + (float(i) - 1.0) * u * 0.6
				draw_line(Vector2(bx, c.y + u * 0.5), Vector2(bx, c.y - u * 0.1
						- float(i == 1) * u * 0.4), col, 1.3)
		"sixth":
			draw_string(font, c + Vector2(-u, u * 0.55), "6",
					HORIZONTAL_ALIGNMENT_CENTER, u * 2.0, maxi(7, int(u * 1.5)), col)
		"pair":
			for dx in [-0.45, 0.45]:
				draw_circle(c + Vector2(dx * u, 0.0), u * 0.3, col)
		"trip":
			for dx in [-0.66, 0.0, 0.66]:
				draw_circle(c + Vector2(dx * u, 0.0), u * 0.26, col)
		"quad":
			for dx in [-0.45, 0.45]:
				for dy in [-0.45, 0.45]:
					draw_circle(c + Vector2(dx * u, dy * u), u * 0.26, col)
		"pair2":
			for dx in [-0.72, -0.3, 0.3, 0.72]:
				draw_circle(c + Vector2(dx * u, float(absf(dx) < 0.5) * u * 0.4
						- u * 0.2), u * 0.22, col)
		"spread":
			draw_circle(c + Vector2(-u * 0.6, u * 0.45), u * 0.26, col)
			draw_circle(c + Vector2(u * 0.1, -u * 0.55), u * 0.26, col)
			draw_circle(c + Vector2(u * 0.65, u * 0.25), u * 0.26, col)
		"zone3":
			for rr in [0.35, 0.65, 0.95]:
				draw_arc(c, u * rr, -2.4, -0.7, 8, col, 1.0)
		"zones2":
			draw_arc(c, u * 0.85, PI * 0.6, PI * 1.4, 10, col, 1.2)
			draw_arc(c, u * 0.85, -PI * 0.4, PI * 0.4, 10, col, 1.2)
		"zones4":
			for aa in [0.785, 2.356, 3.927, 5.498]:
				draw_circle(c + Vector2(cos(aa), sin(aa)) * u * 0.62, u * 0.24, col)
		"rezone":
			draw_arc(c, u * 0.7, -2.6, 1.6, 12, col, 1.2)
			var tp := c + Vector2(cos(1.6), sin(1.6)) * u * 0.7
			draw_colored_polygon(PackedVector2Array([tp + Vector2(0.3, -0.4) * u,
					tp + Vector2(-0.5, -0.1) * u, tp + Vector2(0.2, 0.5) * u]), col)
		"band":
			# 랙 r=15 → r_icon 6.30 → u 3.906. 두 호의 중심 간격 2.227px,
			# 굵기 1.0 을 빼면 배경이 1.23px 남는다 — 1배에서 두 겹으로 갈린다.
			var a0 := -PI * 0.5 - 1.22
			var a1 := -PI * 0.5 + 1.22
			draw_arc(c, u * 0.95, a0, a1, 12, col, 1.0)
			draw_arc(c, u * 0.38, a0, a1, 8, col, 1.0)
		"warm":
			# 내림 사선. 오름은 정밀(점 3개)이 이미 쓴다. 획 사이 수직 간격 2.20px.
			for i in 3:
				var o := (float(i) - 1.0) * u * 0.62
				draw_line(c + Vector2(-u * 0.34 + o, -u * 0.74),
						c + Vector2(u * 0.34 + o, u * 0.74), col, 1.0)
		"mid":
			# 대물 ▲ 과 소물 ▼ 이 꼭짓점에서 만난다. 만나는 곳이 곧 가운데다.
			draw_colored_polygon(PackedVector2Array([
					c + Vector2(-u * 0.85, -u * 0.72),
					c + Vector2(u * 0.85, -u * 0.72), c]), col)
			draw_colored_polygon(PackedVector2Array([
					c + Vector2(-u * 0.85, u * 0.72),
					c + Vector2(u * 0.85, u * 0.72), c]), col)


func _half_disc(c: Vector2, u: float, left: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI * 0.5 + PI * float(i) / 12.0 * (1.0 if left else -1.0)
		pts.append(c + Vector2(cos(a), sin(a)) * u)
	return pts


# 아이템 하나를 칩으로 그린다. 랙과 상점이 같은 그림을 쓰도록 여기 하나로 모았다.
func draw_item_chip(c: Vector2, r: float, it: Dictionary, rot: float, lift: float,
		dim: float, num_sz: int) -> void:
	var ti := _chip_ti(it.cost)
	draw_chip(c, r, CHIP_TIERS[ti], CHIP_SPOTS[ti], rot, lift,
			it.get("g", "") != "", dim)
	# 등급 고리. 색은 rarity.csv 가 정한다 — 정의만 있고 아무도 안 부르던
	# rarity_color() 가 이 한 줄로 산다. 흔함은 안 그린다(고리가 곧 "귀하다").
	if String(it.get("rarity", "common")) != "common":
		draw_arc(c, r - 3.0, 0.0, TAU, 24,
				Color(GameData.rarity_color(String(it.rarity)), 1.0 - dim), 1.0)
	# 얼굴을 위아래로 가른다 — 위는 조건(언제 터지는가), 아래는 값(얼마나).
	# 값만 있으면 조건이 정반대인 짝이 똑같이 보인다.
	var ink: Color = C_CHIP.lightened(0.5) if it.k == "chip" else C_MULT.lightened(0.45)
	_icon_cond(c + Vector2(0.0, -r * 0.33), r * 0.42, String(it.c), ink.darkened(dim + 0.08))
	var val := ("×" + str(it.v)) if it.k == "xmult" else str(it.v)
	var vs: int = maxi(7, int(float(num_sz) * 0.84))
	draw_string(font, c + Vector2(-r, r * 0.34 + float(vs) * 0.34), val,
			HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, vs, ink.darkened(dim))


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

	for i in GameData.max_items():
		if i < owned.size():
			_panel_slot(i)
		else:
			# 딜러 칩 랙의 빈 홈
			var e := _slot_rect(i).get_center() + Vector2(0.0, PANEL.chip_dy)
			draw_circle(e, PANEL.r * 0.72, C_FELT.darkened(0.45))
			draw_arc(e, PANEL.r * 0.72, 0.0, TAU, 16, C_FELT.lightened(0.10), 1.0)


# 칩 i 의 고정 기울기 계수(-0.5~0.5). 인덱스로만 결정되므로 프레임 간 안 흔들린다.
# 상시 기울기는 정적이라 히트박스와 싸우지 않는다 — 그래서 calm 게이트를 안 탄다.
# 3단계에서 PANEL.tilt 를 곱해 쓴다. (지금은 미사용)
func _panel_tilt(i: int) -> float:
	return sin(float(i) * 2.399963) * 0.5


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
#  바깥과 닿는 곳은 셋뿐이다.
#    _sell_hit(m)   랙 클릭 판정          (_click 의 S.SHOP)
#    _can_sell()    지금 팔 수 있는가      (_panel_slot / _tip_build / _process)
#    sell_sel       고른 칸 (-1 = 없음)
#
#  두 번 눌러야 팔린다. 첫 클릭은 칩(랙 안), 두 번째는 왼쪽 창구다.
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
var stage_t := 0.0              # 카드가 깔리는 경과. _open_stage 에서 0 으로 선다


func _can_sell() -> bool:
	# 상점에서만 판다. 스테이지는 창구에 셔터가 내려 있고, 파는 자리가
	# 창구 하나뿐이므로 창구가 없는 화면에서는 팔 방법도 없다.
	# (R8 예외는 같이 사라졌다 — 스테이지에서 못 파니 따질 일이 없다.)
	return state == S.SHOP


func _sell_hit(m: Vector2) -> bool:
	# 랙 y[44,76] 은 매대 y[104,236] · 스테이지 카드 y[112,264] 와 y 로 갈려
	# 있어 먼저 검사해도 그쪽 클릭을 훔칠 수 없다.
	# (판매판 분기가 여기 있었다 — _can_sell 이 SHOP 전용이 되면서 영원히
	#  못 닿는 가지가 됐고, 그리는 쪽 _sell_draw 도 호출이 0이었다. 걷어냈다.)
	if not _can_sell():
		return false
	for i in GameData.max_items():
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


# ══════════════════════════════════════════════════════════
#  소비 아이템 — 사서 쟁여 뒀다가 한 번 쓰고 사라지는 것
# ──────────────────────────────────────────────────────────
#  확정 규칙: 칸 2 · 상점 즉시 사용 가능 · 보관 가능 · 라운드 중 사용 가능 ·
#  사용 확정은 누르고 뗄 때 · 확인 버튼과 비교 팝업은 만들지 않는다.
#  칸 두 개는 옛 판매판이 쓰던 자리(자금판 오른쪽)에 선다.
#
#  영역 강화형은 대상이 트랙 하나로 정해져 있어 "대상 클릭" 이 곧 사용이다.
#  가공형(제안)은 대상을 골라야 하므로 흐름이 다르다 — 데이터만 실려 있고
#  사용은 아직 막혀 있다.
# ══════════════════════════════════════════════════════════

var cons := []                  # 보유 소비 아이템 (최대 cons_slots)
var track_lv := {}              # 영역 강화 트랙 레벨 {트랙ID: int}


func _cons_rect(i: int) -> Rect2:
	return Rect2(80.0 + float(i) * 27.0, 21.0, 24.0, 24.0)


func _cons_hit(m: Vector2) -> int:
	for i in cons.size():
		if _cons_rect(i).has_point(m):
			return i
	return -1


func _cons_use(i: int) -> void:
	if i < 0 or i >= cons.size():
		return
	var c: Dictionary = cons[i]
	if c.cat != "area":
		# 가공형은 대상 선택 흐름이 아직 없다 — 데이터 스캐폴드 단계다
		pay_msg = "가공은 아직 준비 중이다"
		pay_msg_t = HAND.msg_t
		_deny()
		return
	track_lv[c.track] = int(track_lv.get(c.track, 0)) + 1
	var at := _cons_rect(i).get_center()
	cons.remove_at(i)
	pop(at + Vector2(0.0, 26.0), "%s  Lv%d" % [c.n, track_lv[c.track]],
			C_ACC, 10, 0.9)
	beep_seq([523.0, 659.0], 0.06, 0.10, 0.18)


func _cons_draw() -> void:
	for i in GameData.cons_slots():
		var r := _cons_rect(i)
		var live: bool = i < cons.size()
		draw_rect(r, C_PANEL.lightened(0.08) if live else C_PANEL.darkened(0.15))
		draw_rect(r, C_WIRE.darkened(0.15) if live else C_WIRE.darkened(0.45),
				false, 1.0)
		if live:
			draw_string(font, r.position + Vector2(0.0, 15.0),
					String(cons[i].n).substr(0, 2), HORIZONTAL_ALIGNMENT_CENTER,
					r.size.x, 9, C_TXT)


# ══════════════════════════════════════════════════════════
#  상점 테이블  (카지노 펠트 · 오버헤드 · 낙하)
# ──────────────────────────────────────────────────────────
#  정사영 기울임. 테이블 면에서 앙각 52°(수직에서 38°). 원근 배율은 없다 —
#  640x360 에서 깊이 164px 짜리 판의 참원근은 1.08배라 안 보이고, 안 쓰면
#  면 위의 축정렬 사각형이 화면에서도 축정렬 사각형이 되어 draw_rect 가
#  근사가 아니라 정확해진다.
#
#  계수가 둘인 것이 이 구획의 존재 이유다.
#    면에 누운 것의 y → sin 52° = 0.788   (TBL.flat)
#    면에서 선 것의 y → cos 52° = 0.616   (TBL.tall — 칩 옆면에만 쓴다)
#  하나였다면 draw_set_transform 의 scale 한 줄로 끝났다. 그리고 그 한 줄은
#  _tip_draw(2249행)가 draw_set_transform(sh) 로 복구할 때 조용히 사라지고,
#  _hud_draw 가 _draw_shop 다음이라 남은 scale 은 HUD 를 통째로 누른다.
#  → 이 구획은 draw_set_transform 을 한 번도 부르지 않는다. 불변식이다.
#
#  바깥과 닿는 곳은 여섯뿐이다.
#    _table_draw()      판·자리·물건·이름       (_draw_shop 맨 앞)
#    _shop_hit(m)       커서 아래 매물 번호      (_click · _tip_hit)
#    _spot_mark(i)      툴팁 앵커 (Rect2 규약)   (_tip_pos)
#    _drop_roll()       새로 던진다             (_roll_stock 끝)
#    _drop_update(d)    매 프레임 진행           (_process)
#    _drop_settle()     즉시 착지               (_click 말미 · _auto_step)
#  게임 상태(gold/owned/magazine)를 읽지도 쓰지도 않는다. 보는 것은
#  stock[i].type 과 stock[i].sold 둘뿐이고 그리기 직전에만 본다.
#
#  자리는 정확히 4개다. SHOP_ITEMS+SHOP_MODS+SHOP_DARTS 가 4가 아니게 되면
#  ax / ay 를 같이 늘려야 한다.
# ══════════════════════════════════════════════════════════
const C_TABLE := Color("1b3126")   # 펠트. 랙(C_FELT "16281f")보다 한 단 밝다 —
								   # 랙이 앞에 놓인 별개 물건으로 읽히게.
const C_WOOD := Color("3a2a24")


# ══════════════════════════════════════════════════════════
#  딜러 — 크롭된 상반신
#
#  얼굴도 목도 어깨도 화면에 없다. 카메라가 그만큼 가깝다는 뜻이고, 그래서
#  몸통이 커진다. 얼굴을 안 그리는 이유는 예전과 같다 — 640x360 에서 사람
#  얼굴은 어떤 각도로도 뭉개진다. 달라진 것은 그 결론을 "작게 그려 실루엣만"
#  에서 "잘라내고 크게" 로 뒤집은 것이다.
#
#  ── 크롭이 성립하는 사각은 화면에 딱 하나다 ──────────────
#  딜러보다 나중에 그려지는 불투명 판은 _hud_draw 의 셋뿐이다 — 자금판
#  x[4,76] · 칩 랙 x[209,431] · 칩 카운터 x[436,473], 전부 y 가 4 에서
#  시작한다. 그중 딜러의 x 와 겹치는 것은 랙 하나다. 그래서 제약이 둘이다.
#    ① 실루엣 최상단은 y ≥ 4 다. 위로 더 가면 상단바가 상점·스테이지에서
#       꺼져 있어(_bar_hidden) 덮개가 아예 없고, 화면 맨 위에 조끼색 띠가
#       폭 전체로 남는다. 6 을 쓴다 — 랙과 딜러가 같은 transform(shake) 안이라
#       상대 가림은 흔들려도 안 변하고, 2px 은 반올림 여유다.
#    ② y < 36 에서 반폭은 111 이하다. 넘으면 랙 왼쪽 구멍(x[76,209])이나
#       오른쪽 5px 틈(x[431,436])으로 샌다. "크게" 가 부딪히는 벽이 이것이다.
#  보이는 세로는 y[36,109] 의 73px 이다 — 109 에서 먼 레일이 몸통을 자른다.
#  스테이지 화면은 상단 UI 가 완전히 같아서 계산이 하나로 끝난다.
#
#  ── 옷걸이 판별식은 그대로다 ─────────────────────────────
#  옛 그림이 옷걸이였던 이유는 크기가 아니라 자세였다. 좌우 대칭 V 는 팔이
#  몸보다 커지는 순간 철사가 된다. 여기서는 팔꿈치를 몸통 **안**에 두고
#  아래팔만 바깥아래로 내보낸다 — 뿌리가 안 보이므로 어깨를 안 그리고도
#  팔이 어딘가에서 온다. 대칭 V 가 아니라 몸통 하나에 두 갈래다.
#
#  ── 73px 짜리 검은 사다리꼴은 사람이 아니라 구멍이다 ────
#  그려서 확인했다. 형태를 주는 것은 크기도 테두리도 아니고 옷이다. 셔츠 V
#  하나와 단추 세 개면 같은 실루엣이 조끼 입은 딜러가 된다. V 꼭짓점은
#  반드시 랙 밑변(36)보다 아래여야 한다 — 위면 통째로 랙 뒤라 아무 일도 안 한다.
#
#  ── 값 사다리 ────────────────────────────────────────────
#  조끼 9 < 소매 24 < 벽 41 < 셔츠 93 < 커프 111 < 림 141.
#  앞의 간격 15(소매−조끼) 와 17(벽−소매) 은 옛 주석이 실측으로 못 박은
#  값이라 그대로 지킨다 — 10 은 실패했고 15 는 됐다.
#
#  ── 움직이는 것은 둘이다 ────────────────────────────────
#  숨과 쓸기. 숨은 몸통 윗변이 아니라 **V 꼭짓점·단추·팔꿈치**를 움직인다 —
#  윗변은 y=4 라 랙 뒤이고, 거기를 흔들면 아무 데서도 안 보인다.
# ══════════════════════════════════════════════════════════
const NPC := {
	"cx": 320.0,
	"top": 6.0,          # 실루엣 최상단. 랙 윗변(4)보다 2px 안쪽이다
	"cut": 112.0,        # 허리 = 카운터
	"hc": 72.0,          # 가슴 반폭 (y=top). 111 이 한계다
	"hw": 60.0,          # 허리 반폭 (y=cut)
	"vee_w": 27.0,       # 셔츠 V 반폭 (y=top)
	"vee_y": 58.0,       # V 꼭짓점. 랙 밑변 36 보다 22px 아래다
	"btn_y": 70.0, "btn_dy": 13.0, "btn_r": 2.9,
	"belt": 5.0,
	# 팔은 **판 위에 누운 상자**다. 몸통은 서 있고 팔은 누워 있으므로 같은
	# 도형으로 그리면 안 된다 — 누운 것은 화면 좌표가 아니라 면 좌표(u,w)로
	# 그려야 52° 정사영이 공짜로 붙는다. 옆면(h=0)을 깔고 윗면(h=t)을 얹는
	# 어법은 칩(_chip_flat)과 같다. 이 게임이 이미 쓰는 문법이다.
	#
	# ── 다섯 번 실패한 뒤에 알아낸 것 ────────────────────────
	# 선 · V자 · 커프 · 타원 · 상자를 차례로 시도했고 전부 졌다. 다섯 가지는
	# 전부 **그리는 어법**을 바꾼 시도였는데, 진 이유는 어법이 아니라 세 수치가
	# 동시에 0 이었기 때문이다 — 실루엣 구멍 0개, 폭 변화 0(팔꿈치 9 = 손목 9),
	# 좌우 차이 0(±100·±20 완전 미러). 그래서 무엇을 그려도 옷걸이였다.
	# 여기 값들은 그 셋을 각각 깨라고 골라 둔 것이다. 만질 때 셋 중 하나라도
	# 0 으로 돌아가면 다섯 번째 실패가 여섯 번째가 된다.
	#
	# ── 갈라짐 ──────────────────────────────────────────────
	# 팔꿈치를 몸통 **밖**·랙 **뒤**로 뺀다. 뿌리가 랙(x[209,431] y[4,36])에
	# 잘리므로 어깨를 안 그리고도 팔이 몸에서 나오고, 팔과 옆구리 사이에
	# 12px 짜리 배경 골이 세로로 75px 뚫린다.
	#
	# 설계할 때는 이걸 "닫힌 구멍" 으로 잡았는데 재 보니 아니었다 — 위는
	# 랙에, 아래는 카운터(cut 112)에 열려 있어서 닫히지가 않는다. 대신
	# 더 센 것이 나왔다: 팔이 검사 칸 안에서 몸통과 **아예 다른 덩어리**가
	# 된다. 실루엣을 단색으로 칠하면 셋으로 갈린다(몸통 · 팔 · 팔).
	"el_l": Vector2(-94.0, -104.0), "wr_l": Vector2(-78.0, -2.0),
	# 오른쪽 손목이 왼쪽보다 밖(104)·뒤(−14)인 것은 손이 143° 로 몸통을
	# 향해 돌아오기 때문이다. u 88 에 두면 손끝이 몸통 위로 8px 올라타
	# 팔과 몸이 한 덩어리로 붙고(실측), 그렇다고 각을 세우면 손끝 w 가
	# 31 까지 나가 정착 물건 최상단(131.8)을 뚫는다. 통로가 그만큼 좁다.
	"el_r": Vector2(96.0, -103.0), "wr_r": Vector2(104.0, -14.0),
	# 팔꿈치 26 → 손목 13 → 너클 18. **손목이 전체 최소폭**이고 손이 거기서
	# 1.66배로 되벌어진다. 이 계단이 관절이 있다는 유일한 표시다 —
	# 옛 값은 팔꿈치도 9, 손목도 9, 손도 9 라 팔 하나가 통짜 막대였다.
	"el_w": 13.0, "wr_w": 6.5,
	"arm_t": 12.0, "hand_t": 9.0,
	# 좌우가 다르다. 각도 17° 차 · 길이 12% 차 · 팔꿈치 u 2 / w 1 차.
	# 둘 다 왼쪽을 가리키는 것은 일부러다 — 미러링은 둘이 서로 반대를
	# 볼 때 생기고, 같은 쪽을 보면 그 순간 자세가 된다. 쓸기가 왼쪽으로
	# 가므로 쉬는 자세가 그쪽을 미리 가리키는 것이기도 하다.
	"ang_l": 160.0, "sc_l": 0.88,
	"ang_r": 143.0, "ang_sw": 150.0,
	# 위팔은 따로 안 그린다. 팔은 상자 **하나**다 — 팔꿈치에서 손목까지 한
	# 덩어리로 누워 있고, 팔꿈치를 꺾으면 서 있는 도형과 누운 도형이
	# 한 팔 안에서 섞여 이음매가 부러져 보인다(그려서 확인했다).
	"breathe": 1.4,
}

# 손 하나. 손목이 원점이고 +x 가 손가락 방향, +y 가 새끼손가락 쪽이다.
# 길이 43 · 최대폭 22 = 1.95:1 — 사람 손이 2.1:1 이다. 옛 손은 길이 12 ·
# 폭 18 로 **비율이 뒤집혀** 있었다. 길이보다 넓고 모서리가 둥근 밝은
# 덩어리는 무엇을 붙여도 빵으로 읽힌다. 그것이 진짜 원인이었다.
#
# 실루엣이 가진 정보는 **엄지 하나**다. p2 가 8px 튀어나오고 p4 에서
# 7px 도로 들어오는 그 V 하나가 덩어리를 손으로 만든다. 처음에 1px
# 만 튀우고 넘어갔더니 그 자리에서 다시 빵이 됐다 — 노치는 픽셀 하나로
# 안 되고, 이 크기에서는 폭의 3분의 1 은 파야 보인다.
#
# 손가락은 하나씩 안 그린다. 1px 획을 넷 넣으면 서로 붙어 얼룩이 된다.
# 대신 p6 의 베벨과 p8 의 너클이 손끝과 손등을 대신한다.
# 손목폭 11 → 너클폭 18 = 1.66배. 손목이 팔 전체의 최소폭이다.
const PALM := [
	Vector2(0.0, -5.5), Vector2(11.0, -8.0),
	Vector2(17.0, -16.0), Vector2(24.0, -12.0),   # 엄지
	Vector2(20.0, -5.0),                          # 노치
	Vector2(39.0, -6.0), Vector2(43.0, 1.0), Vector2(38.0, 8.0),
	Vector2(26.0, 13.0),                          # 너클 — 최대폭
	Vector2(0.0, 5.5),
]
var npc_clock := 0.0


# ══════════════════════════════════════════════════════════
#  쓸기 — 리롤이 하는 일
# ──────────────────────────────────────────────────────────
#  딜러가 판을 쓸어 왼쪽(판매) 창구로 넣고 새로 뿌린다. 세 박자다 —
#  뻗기 · 훑기 · 복귀. 물리가 열리는 것은 훑기 동안뿐이다(sweep_on).
#
#  아래팔은 면 위의 직선이고, 52° 정사영에서 면 위 직선은 화면 직선이라
#  **그려지는 아래팔이 곧 미는 선이다.** 근사가 아니라 _sweep_line 하나를
#  그리기와 물리가 같이 읽는 것이다.
#
#  선은 트레이 w[24,126] 을 정확히 덮는다 — 팔꿈치가 w 24 (화면 y 130.9),
#  손이 w 126 (y 211.3). 물건 중심은 _drop_walls·_drop_clamp 가 그 구간에
#  못 박으므로 팔이 못 만나는 물건이 존재할 수 없다. 경우를 안 따져도 된다.
#
#  기울기를 창구 빗변과 **평행**으로 잡은 것이 이 표의 유일한 묘수다.
#  e(w) = 80 − 0.477576·w 이고 tilt 가 같은 0.477576 이므로
#     line(w) − e(w) = u1 − 19.83      … w 와 무관한 상수
#  가 된다. 그래서 "어느 깊이에서 빠지는가" 를 따질 일이 없다. 물건이
#  놓이는 자리가 line(w) − r 이므로 조건이 u1 − 19.83 ≤ r 하나로 줄고,
#  가장 빡빡한 칩(r 19)이 u1 ≤ 38.8 을 준다. 18 은 그 안이다.
#  시작점 u0 = 529 는 반대쪽이다. 물건이 물리적으로 닿을 수 있는 가장
#  오른쪽 실체가 u_hi − hw + r = 524 − 19 + 19 = 524 이므로(실측 최대는
#  486) 선이 거기보다 오른쪽에서 출발하면 팔 오른쪽에 남는 물건이 없다.
#
#  물건이 빗변을 넘으면 물리를 떠나 waste 로 간다. drop 은 stock 과 인덱스를
#  나누므로 거기 남겨 두면 "쓸려 가는 중인데 살 수 있는" 상태가 생긴다.
const SWEEP := {
	"reach": 0.16,       # 팔을 오른쪽 끝까지 뻗는다
	"rake": 0.52,        # 훑는다. 이 동안만 왼쪽 벽이 열린다
	"back": 0.30,        # 복귀. 새 매물은 이 동안 이미 떨어지고 있다
	"u0": 529.0, "u1": 18.0,
	"w_el": 24.0, "w_hd": 126.0,
	# 그리는 팔은 미는 구간보다 뒤로 더 뻗는다. 같은 직선 위이므로 물리는
	# 한 글자도 안 바뀌고, 팔이 몸 쪽(w −52 → 화면 y 71)까지 이어져
	# 펠트 위에 상자가 동강 떠 있는 그림이 안 된다.
	"w_back": -52.0,
	"tilt": 0.477576,    # 창구 빗변의 기울기 그대로. 아래 주석이 이유다
	"lean": 20.0,        # 몸통이 팔을 따라가는 거리. 320±(20+72) 는 랙 안이다
	"push": 620.0,       # 밀린 물건이 받는 최소 좌향 속도 (면px/s)
	"up_w": 23.0,        # 위팔 두께. 아래팔(16)보다 굵어야 관절이 읽힌다
	"fall_g": 900.0, "fall_c": 3.2, "fall_t": 0.44,
}
var sweep_t := 0.0       # 쓸기 경과(초)
var sweep_live := false  # 연출 전체가 도는 중 — 입력을 통째로 삼킨다
var sweep_on := false    # 훑기 중 — 물리가 열린 구간
var sweep_dealt := false # 새 판을 이미 깔았는가
var waste := []          # 창구로 빠진 물건. stock 사본을 들고 다닌다

const TBL := {
	# ── 시점 ──────────────────────────────────────────
	"flat": 0.788,       # sin 52°  — 면에 누운 것의 y 압축. w 에만 곱한다
	"tall": 0.616,       # cos 52°  — 면에서 선 것의 y 압축. h 에만 곱한다

	# ── 판 ────────────────────────────────────────────
	# 80 에서 112 로 내렸다. 카운터 위 62px 로는 사람 실루엣이 안 읽힌다 —
	# 머리·목·어깨가 한 줄에 겹쳐 검은 막대가 된다(두 번 그려 보고 확인했다).
	# 94px 이면 머리(56~76) · 목 · 어깨(84~112)가 세로로 갈린다.
	# 펠트가 164 에서 132 로 얕아진 대신 트레이 w 범위를 같이 줄였다.
	"fy": 112.0,         # 펠트 far 모서리
	"ny": 244.0,         # 펠트 near 모서리. 레일 6px 뒤가 기존 버튼 y=250

	# ── 물건 ─────────────────────────────────────────
	"chip_r": 19.0,      # 38 x 29.9 타원. 랙 칩은 30 x 30 정원이다 (일부러 다르다)
	"chip_t": 4.5,       # 옆면 = 4.5 * tall = 2.77px
	"mod_r": 19.0,       # 캐비닛 실폭 2r+6 = 44, 화면 높이 2*r*flat+6 = 35.9
	"dart_l": 24.0,      # 반길이. 최대 도달은 dl+8.5 ("mag" 자기장 호)
	"light": Vector2(0.447, 0.894),   # 기존 그림자 벡터 (1.5,3.0) 의 정규화
}


#  테이블을 두 조각으로 나눠 둔다. 사이에 무엇을 끼우느냐가 화면을 가른다 —
#  상점은 매물을, 스테이지는 제약 카드를 끼운다. 카운터 뒤에서 나오는 것이
#  덮개에 잘리는 순서가 두 화면에서 정확히 같아진다.
func _table_draw() -> void:
	_felt_draw()
	_goods_draw()
	_waste_draw()
	_cover_draw()
	_bill_draw()


func _felt_draw() -> void:
	# 화면이 곧 테이블의 크롭이다. 640 폭에 D자 테이블 전체를 넣으면 매물이
	# 그 안에서 다시 쪼그라든다. 좌우는 화면 밖으로 이어진다.
	# 0 에서 시작한다. _draw_stage 는 _scrim() 을 안 부르므로 바를 지운
	# 자리에 다트판이 그대로 비친다.
	draw_rect(Rect2(0.0, 0.0, VIEW.x, VIEW.y), C_WOOD)
	# 펠트는 사다리꼴이다. 좌우 빗변이 그대로 창구라 모양이 곧 규칙이다.
	var felt := PackedVector2Array([
			Vector2(CHUTE.back, TBL.fy), Vector2(VIEW.x - CHUTE.back, TBL.fy),
			Vector2(VIEW.x, TBL.ny), Vector2(0.0, TBL.ny)])
	draw_colored_polygon(felt, C_TABLE)
	var ink: Color = C_TABLE.lightened(0.34)

	# 결 — 도트 격자는 프레임당 수천 콜이라 못 쓴다. 가로 1px 줄 7px 간격 = 23콜.
	# 빗변까지만 긋는다.
	var yy: float = TBL.fy + 7.0
	while yy < TBL.ny:
		var e := _chute_edge(yy)
		draw_line(Vector2(e, yy), Vector2(VIEW.x - e, yy), Color(ink, 0.05), 1.0)
		yy += 7.0

	_chute_draw()

	# 딜러 라인 — 면 위에서 좌우로 뻗은 선은 이 정사영에서 정확히 화면
	# 수평선이 된다. 근사가 아니라 공짜로 맞다.
	var dly: float = TBL.fy + 7.0
	var de := _chute_edge(dly)
	draw_line(Vector2(de + 8.0, dly), Vector2(VIEW.x - de - 8.0, dly), Color(ink, 0.5), 1.0)


func _cover_draw() -> void:
	# 덮개 — 물건은 카운터 뒤에서 나온다. 그 위로 삐져나온 부분을
	# 먼 쪽 레일이 덮는다. 클리핑 대신 불투명 사각 하나다. 상시 HUD 는
	# _hud_draw 가 이 위에 판을 다시 얹으므로 멀쩡하고, 결과적으로 칩 랙이
	# 테이블 쿠션 위에 놓인 딜러 트레이로 읽힌다.
	draw_rect(Rect2(0.0, 0.0, VIEW.x, TBL.fy), C_WOOD.darkened(0.30))
	_npc_body()
	draw_rect(Rect2(0.0, TBL.fy - 3.0, VIEW.x, 3.0), C_WOOD)
	draw_rect(Rect2(0.0, TBL.fy - 1.0, VIEW.x, 1.0), C_WOOD.lightened(0.18))
	_npc_arms()
	# 가까운 쪽 레일 — 리롤·다음 버튼이 그 아래 앞치마에 얹힌다
	draw_rect(Rect2(0.0, TBL.ny, VIEW.x, 2.0), C_WOOD.lightened(0.24))
	draw_rect(Rect2(0.0, TBL.ny + 6.0, VIEW.x, VIEW.y - TBL.ny - 6.0),
			C_WOOD.darkened(0.35))


# 창구 둘. 펠트 빗변 바깥의 삼각형이 몸통이고, 결이 미끄럼틀이라고 말한다.
func _chute_draw() -> void:
	var open: bool = state == S.SHOP
	for z in 2:
		var lit: bool = open and hand_zone == z
		var body: Color = C_WOOD.darkened(0.46)
		if pay_flash > 0.0 and lit:
			body = body.lerp(C_ACC, pay_flash * 0.5)
		elif lit:
			body = C_WOOD.darkened(0.22)
		var p := PackedVector2Array()
		if z == Z_SELL:
			p.append(Vector2(0.0, TBL.fy))
			p.append(Vector2(CHUTE.back, TBL.fy))
			p.append(Vector2(0.0, TBL.ny))
		else:
			p.append(Vector2(VIEW.x, TBL.fy))
			p.append(Vector2(VIEW.x - CHUTE.back, TBL.fy))
			p.append(Vector2(VIEW.x, TBL.ny))
		draw_colored_polygon(p, body)
		var gr := Color(C_WOOD.lightened(0.55), 0.16 if lit else 0.10)
		var yy: float = TBL.fy + 4.0
		while yy < TBL.ny:
			var e := _chute_edge(yy)
			if e > 2.0:
				if z == Z_SELL:
					draw_line(Vector2(0.0, yy), Vector2(e, yy), gr, 1.0)
				else:
					draw_line(Vector2(VIEW.x - e, yy), Vector2(VIEW.x, yy), gr, 1.0)
			yy += 5.0
		draw_line(p[1], p[2], Color(C_ACC if lit else C_WOOD.lightened(0.34),
				0.95 if lit else 0.50), 1.0)
		if not open:
			# 닫힌 창구 — 셔터 두 줄. 스테이지 화면에서는 사고팔 것이 없다.
			for k in 2:
				var sy: float = TBL.fy + 26.0 + float(k) * 13.0
				var e := _chute_edge(sy)
				if e < 6.0:
					continue
				var x0: float = 2.0 if z == Z_SELL else VIEW.x - e
				draw_rect(Rect2(x0, sy, e - 2.0, 3.0),
						Color(C_WOOD.darkened(0.70), 0.85))
	if open:
		_chute_label()


# 창구 얼굴. 무엇을 들었는지에 따라 왼쪽이나 오른쪽 하나만 값을 말한다.
func _chute_label() -> void:
	var ly: float = TBL.fy + 12.0
	var si: int = hand_i if (hand_st == H.CARRY and hand_src == 1) else sell_sel
	var slive: bool = _can_sell() and si >= 0 and si < owned.size()
	draw_string(font, Vector2(5.0, ly), "판매", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			C_TXT if slive else C_DIM)
	if slive:
		draw_gold_at(5.0, ly + 17.0, "+%d" % GameData.sell_value(owned[si]), 11, C_GOLD)

	var bi: int = hand_i if (hand_st == H.CARRY and hand_src == 0) else buy_sel
	var blive: bool = bi >= 0 and bi < stock.size()
	var ok: bool = blive and _buy_block(bi) == ""
	draw_string(font, Vector2(VIEW.x - 27.0, ly), "구매", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			(C_TXT if ok else C_MULT.lightened(0.2)) if blive else C_DIM)
	if blive:
		var cs := str(stock[bi].cost)
		draw_gold_at(VIEW.x - 5.0 - gold_w(cs, 11), ly + 17.0, cs, 11,
				C_GOLD if ok else C_DIM.darkened(0.25))


# 딜러 몸통 — 카운터 위로 올라온 부분만. 랙이 이 위에 얹혀 트레이로 읽힌다.
# 딜러 몸통 — 카운터 위로 올라온 부분만. 랙이 이 위에 얹혀 트레이로 읽힌다.
func _npc_body() -> void:
	var br: float = sin(npc_clock * 1.5) * float(NPC.breathe)
	var cx: float = NPC.cx + _sweep_lean()
	# 141 에서 내렸다. 손 윗면(133)보다 밝은 것이 화면에 있으면 안 된다 —
	# 눈은 가장 밝은 데로 먼저 가고, 그게 옆구리 획이면 딜러가 안 읽힌다.
	var rim: Color = C_WOOD.lightened(0.26)
	# 몸통. 위는 랙(y<36) 뒤로 사라지고 아래는 카운터에 박힌다. 사다리꼴
	# 하나면 충분하다 — 이 크롭에서 어깨 사면은 화면 밖이라 그릴 것이 없다.
	draw_colored_polygon(PackedVector2Array([
			Vector2(cx - NPC.hc, NPC.top), Vector2(cx + NPC.hc, NPC.top),
			Vector2(cx + NPC.hw, NPC.cut), Vector2(cx - NPC.hw, NPC.cut)]),
			C_WOOD.darkened(0.84))
	# 셔츠 V — 조끼가 벌어진 자리. 이 한 조각이 사다리꼴을 옷으로 만든다.
	# 꼭짓점만 숨을 탄다. 윗변은 랙 뒤라 움직여도 아무 데서도 안 보인다.
	draw_colored_polygon(PackedVector2Array([
			Vector2(cx - NPC.vee_w, NPC.top), Vector2(cx + NPC.vee_w, NPC.top),
			Vector2(cx, NPC.vee_y + br)]), C_LIGHT.darkened(0.60))
	# 단추 셋. 세로 한 줄이 가운데를 잡아 좌우 대칭을 몸으로 읽게 한다.
	for k in 3:
		draw_colored_polygon(_e_pts(
				Vector2(cx, NPC.btn_y + float(k) * NPC.btn_dy + br),
				NPC.btn_r, NPC.btn_r, 12), C_WOOD.lightened(0.13))
	# 허리띠 — 몸통이 카운터에서 끊기는 자리에 가로 획을 하나 준다.
	draw_rect(Rect2(cx - NPC.hw - 1.0, NPC.cut - NPC.belt,
			(NPC.hw + 1.0) * 2.0, NPC.belt), C_WOOD.darkened(0.90))
	# 옆선 빛. 벽과 100/255 갈리는 유일한 고대비 획이고, 이게 없으면
	# 조끼(9)와 벽(41)의 32 차이만 남아 실루엣이 벽에 잠긴다.
	for s in [-1.0, 1.0]:
		draw_line(Vector2(cx + s * NPC.hc, NPC.top),
				Vector2(cx + s * NPC.hw, NPC.cut), Color(rim, 0.55), 1.0)


# 팔 — 먼 레일 다음이라 "카운터에 얹혔다" 가 된다.
# 오른쪽(화면) 팔만 쓸기를 한다. 마주 본 사람이므로 그것이 딜러의 **왼팔**
# 이다 — 쓸기는 u 529 에서 18 로 가는데 529 에 닿는 팔이 그쪽뿐이라
# 물리가 이미 팔을 골라 놨다.
func _npc_arms() -> void:
	var br: float = sin(npc_clock * 1.5) * float(NPC.breathe)
	var cx: float = NPC.cx + _sweep_lean()
	var a := _sweep_amt()
	# 쉬는 팔. 숨은 팔꿈치를 손목보다 크게 흔든다 — 뿌리가 랙 뒤라
	# 팔꿈치 쪽 진폭은 안 보이고 팔 전체의 기울기로만 나온다.
	_npc_limb(Vector2(cx + NPC.el_l.x, NPC.el_l.y + br * 0.5),
			Vector2(cx + NPC.wr_l.x, NPC.wr_l.y + br * 0.2),
			deg_to_rad(NPC.ang_l), NPC.sc_l)
	# 쓸는 팔. 끝점도 면 좌표라 팔이 그대로 미는 선 위에 눕는다.
	var el := Vector2(cx + NPC.el_r.x, NPC.el_r.y + br * 0.5)
	var wr := Vector2(cx + NPC.wr_r.x, NPC.wr_r.y + br * 0.2)
	var ang: float = deg_to_rad(NPC.ang_r)
	if a > 0.004:
		el = _sweep_elbow()
		wr = _sweep_hand()
		# 손목이 꺾인다. 옛 코드는 손 방향이 (hd−el) 이라 팔과 손이 한
		# 직선이었고, 그래서 관절이 없는 막대가 됐다. 150° 는 손끝이
		# w 146(화면 y 227)에서 멈추는 각이다 — 레일(244)에 안 닿는다.
		ang = lerp_angle(ang, deg_to_rad(NPC.ang_sw), a)
	_npc_limb(el, wr, ang, 1.0)


# 팔 하나 + 손 하나. 면 좌표(u,w) 로 받는다.
# 값 사다리를 여기서 못 박는다 — 소매 윗면 66 은 벽 41 보다 **밝다**.
# 옛 소매 24 는 벽보다 어두워서 팔이 벽에 잠겨 있었다. 손 윗면 133 은
# 화면에서 가장 밝은 덩어리이고, 그래서 눈이 손부터 본다.
func _npc_limb(el: Vector2, wr: Vector2, ang: float, sc: float) -> void:
	var ex := Vector2(cos(ang), sin(ang))
	# 엄지는 **늘 관객 쪽(+w)** 이다. 좌우를 거울로 뒤집어 봤더니 한쪽
	# 엄지가 뒤로 넘어가고, 그쪽은 정사영이 0.788 로 눌러서 8px 짜리
	# 노치가 6px 이 되며 통째로 사라졌다 — 그 손만 다시 빵이 됐다.
	# 손바닥을 아래로 두고 손끝을 옆으로 두면 실제로도 엄지가 앞이다.
	# 덤으로 두 손이 거울상이 아니라 평행이동이 돼 대칭 점수가 더 깨진다.
	var ey := Vector2(-ex.y, ex.x)
	var hand := PackedVector2Array()
	for q in PALM:
		hand.append(wr + ex * (q.x * sc) + ey * (q.y * sc))
	# 접지 그림자 — 같은 손을 면에서 w+3 밀어 어둡게 깐다. 화면에서는
	# 2.4px 아래다. 이 한 조각이 "떠 있는 손"과 "판에 놓인 손"을 가른다.
	var sh := PackedVector2Array()
	for q in hand:
		sh.append(_p2s(q.x, q.y + 3.0, 0.0))
	draw_colored_polygon(sh, C_WOOD.darkened(0.84))
	_npc_taper(el, wr, NPC.el_w, NPC.wr_w, NPC.arm_t,
			C_WOOD.darkened(0.84), C_WOOD.lightened(0.04))
	# 손목 이음선은 **어둡게**. 밝은 커프 띠로 갈라 봤다가 옷이 아니라
	# 띠 자체로 읽혀서 졌다 — 양옆보다 밝은 좁은 획은 형태를 자른다.
	# 어두운 획은 반대로 잇는다. 여기서는 손 옆면(84)이 그 역할을 한다.
	_npc_flat(hand, NPC.hand_t, C_WOOD.lightened(0.13),
			C_WOOD.lightened(0.38))


# 면 위에 누운 다각형 하나. 옆면(h=0)을 먼저 깔고 윗면(h=t)을 얹는다 —
# 윗면이 t*tall 만큼 위로 올라가므로 아래로 삐져나온 옆면이 그대로
# 두께가 된다. 칩과 같은 수법이다. 옆면 색을 **인자로 받는** 것이 중요하다:
# 옛 _npc_slab 은 col.darkened(0.58) 로 자동 파생했는데, 그 결과가
# 조끼색과 같은 값이라 몸통 위에 겹치는 구간에서 두께가 통째로 사라졌다.
func _npc_flat(pts: PackedVector2Array, t: float, side: Color,
		top: Color) -> void:
	var lo := PackedVector2Array()
	var hi := PackedVector2Array()
	for q in pts:
		lo.append(_p2s(q.x, q.y, 0.0))
		hi.append(_p2s(q.x, q.y, t))
	draw_colored_polygon(lo, side)
	draw_colored_polygon(hi, top)


# 굵기가 변하는 누운 상자. 테이퍼가 이 팔의 전부다 —
# 같은 폭으로 이으면 도형이 무엇이든 막대로 읽힌다.
func _npc_taper(a: Vector2, b: Vector2, ra: float, rb: float, t: float,
		side: Color, top: Color) -> void:
	var d := (b - a).normalized()
	var nv := Vector2(-d.y, d.x)
	_npc_flat(PackedVector2Array([a + nv * ra, b + nv * rb,
			b - nv * rb, a - nv * ra]), t, side, top)

# ══ 쓸기 자세 — 그리기와 물리가 같은 식을 읽는다 ═════════

# 훑는 선. 면 좌표 w 에서의 u 다. 화면에서는 이 선이 곧 아래팔이다 —
# 52° 정사영에서 면 위 직선은 화면 직선이라 근사가 아니라 같은 선이다.
func _sweep_line(w: float) -> float:
	return _sweep_u() + SWEEP.tilt * (SWEEP.w_hd - w)


# 손의 u. 훑기 전이면 시작점, 후면 끝점에 머문다 — 복귀는 _sweep_amt 가 한다.
func _sweep_u() -> float:
	return lerpf(SWEEP.u0, SWEEP.u1,
			_ease_io((sweep_t - SWEEP.reach) / SWEEP.rake))


# 쉬는 자세와 훑는 자세를 섞는 비율. 뻗기에 0→1, 훑기에 1, 복귀에 1→0.
func _sweep_amt() -> float:
	if not sweep_live:
		return 0.0
	if sweep_t < SWEEP.reach:
		return _ease_io(sweep_t / SWEEP.reach)
	var t: float = sweep_t - SWEEP.reach - SWEEP.rake
	if t <= 0.0:
		return 1.0
	return 1.0 - _ease_io(t / SWEEP.back)


# 몸통이 팔을 따라간다. 뻗을 때 오른쪽, 훑으면서 왼쪽으로 실린다.
# 팔 길이를 늘리는 대신 몸을 옮기는 것이 사람이 하는 일이다.
# 320 ± (20 + 72) = [228, 412] 이라 랙 x[209,431] 을 안 벗어난다.
func _sweep_lean() -> float:
	if not sweep_live:
		return 0.0
	var k: float = clampf((_sweep_u() - SWEEP.u1) / (SWEEP.u0 - SWEEP.u1), 0.0, 1.0)
	return lerpf(-SWEEP.lean, SWEEP.lean, k) * _sweep_amt()


# 쉴 때와 훑을 때를 섞는다. 둘 다 **면 좌표**(u,w) 다 — 훑는 선이 이미
# 면 위의 직선이므로, 팔을 면에서 그리는 순간 그림과 물리가 같은 수를 읽는다.
func _sweep_elbow() -> Vector2:
	var rest := Vector2(NPC.cx + _sweep_lean() + NPC.el_r.x, NPC.el_r.y)
	return rest.lerp(Vector2(_sweep_line(SWEEP.w_back), SWEEP.w_back), _sweep_amt())


func _sweep_hand() -> Vector2:
	var rest := Vector2(NPC.cx + _sweep_lean() + NPC.wr_r.x, NPC.wr_r.y)
	return rest.lerp(Vector2(_sweep_line(SWEEP.w_hd), SWEEP.w_hd), _sweep_amt())


func _ease_io(t: float) -> float:
	var k := clampf(t, 0.0, 1.0)
	return 2.0 * k * k if k < 0.5 else 1.0 - pow(-2.0 * k + 2.0, 2.0) * 0.5


# ══ 쓸기 타임라인 ════════════════════════════════════════

# 훑는 중인가. 가격판·코스터 자국·안내 문구가 이걸 읽는다 —
# 복귀 구간은 이미 새 판이 떨어지는 중이라 평소처럼 굴어야 한다.
func _sweep_wipe() -> bool:
	return sweep_live and not sweep_dealt


func _sweep_reset() -> void:
	sweep_t = 0.0
	sweep_live = false
	sweep_on = false
	sweep_dealt = false
	waste.clear()


# 골드 정산은 _reroll 이 이미 끝냈다. 여기는 연출과 물리만 연다.
func _sweep_begin() -> void:
	# 팔은 h 를 안 읽는다. 낙하 중에 리롤을 누르면 공중에 뜬 물건을 그대로
	# 관통하므로, 시작 전에 h ≡ 0 으로 만들어 전제를 세운다.
	if drop_awake:
		_drop_settle()
	_sweep_reset()
	sweep_live = true
	buy_sel = -1
	# t_max(2.6초) 감시가 쓸기 도중에 터져 _drop_settle 이 물건을 트레이 안으로
	# 되끌어오는 것을 막는다. 지난 낙하의 경과는 여기서 버린다.
	drop_t = 0.0
	drop_acc = 0.0
	drop_awake = true
	for it in drop:
		it.sleep = false
		it.rest = 0.0


func _sweep_update(d: float) -> void:
	if not sweep_live:
		return
	sweep_t += d
	var t1: float = SWEEP.reach + SWEEP.rake
	sweep_on = sweep_t >= SWEEP.reach and sweep_t < t1
	if not sweep_dealt and sweep_t >= t1:
		sweep_dealt = true
		_sweep_deal()
	if sweep_t >= t1 + SWEEP.back:
		sweep_live = false
		sweep_on = false


# 훑기가 끝났다. 남은 것이 있으면(선이 트레이를 전부 덮으므로 있을 수 없다)
# 같이 구멍으로 보내고 새 판을 깐다. _roll_stock 은 한 글자도 안 고쳤다 —
# 그것이 상점 입장(_open_shop)에 쓸기가 안 붙는 유일한 무조건 보장이다.
func _sweep_deal() -> void:
	for i in mini(drop.size(), stock.size()):
		_sweep_sink(i)
	_roll_stock()


# 팔이 미는 한 번. 다트는 원 3개라 중심만 보면 촉이 팔을 통과한다 —
# _drop_sub 로 부분원마다 보고 가장 깊이 물린 만큼 중심을 옮긴다.
# 팔은 무한질량이라 한쪽만 움직이고, h 는 한 번도 안 건드린다.
func _sweep_push(i: int) -> void:
	var it: Dictionary = drop[i]
	if it.gone or it.sold > 0.0 or it.held:
		return
	var over := 0.0
	for k in int(it.nb):
		var sp := _drop_sub(it, k)
		over = maxf(over, sp.x - (_sweep_line(sp.y) - it.r))
	if over > 0.0:
		it.u -= over
		it.vu = minf(it.vu, -SWEEP.push)
		it.sleep = false
		it.rest = 0.0
	# 빗변을 넘었으면 물리를 떠난다. _drop_lo 가 왼쪽 벽을 여기까지 물렸으므로
	# _drop_walls 가 정확히 이 값으로 잘라 놓은 뒤다.
	if it.u <= _chute_dock_u(Z_SELL, it.w) + 0.02:
		_sweep_sink(i)


# 빗변을 넘었다. 물리를 떠나 구멍으로 간다. drop 에서는 gone 이 되고 그림만
# waste 로 옮겨 간다 — stock 과 인덱스를 안 나누는 사본이라, 쓸려 가는 물건이
# 여전히 팔리거나 툴팁을 띄우는 상태가 생길 수 없다.
func _sweep_sink(i: int) -> void:
	var it: Dictionary = drop[i]
	if it.gone or it.sold > 0.0:
		return
	var wd: Dictionary = it.duplicate()
	wd["s"] = stock[i]
	wd["t"] = 0.0
	wd["vh"] = 0.0
	waste.append(wd)
	it.gone = true
	it.vu = 0.0
	it.vw = 0.0
	it.om = 0.0
	beep(196.0, 0.05, 0.09)


# 구멍 속. 면을 떠났으므로 벽도 쌍 충돌도 안 본다 — h 를 음수로 떨어뜨리면
# _p2s 가 알아서 화면 아래로 보낸다. 빗면을 미끄러지는 그림이 공짜로 나온다.
func _waste_update(d: float) -> void:
	var k := waste.size() - 1
	while k >= 0:
		var it: Dictionary = waste[k]
		it.t += d / SWEEP.fall_t
		if it.t >= 1.0:
			waste.remove_at(k)
		else:
			it.vh -= SWEEP.fall_g * d
			it.h += it.vh * d
			it.u += it.vu * d
			it.vu *= exp(-SWEEP.fall_c * d)
			it.psi += it.om * d
		k -= 1


func _waste_draw() -> void:
	for it in waste:
		_obj_paint(it, it.s, minf(float(it.t) * 1.3, 0.94))


func _e_pts(c: Vector2, rx: float, ry: float, seg := 22) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * float(i) / float(seg)
		pts.append(c + Vector2(sin(a) * rx, -cos(a) * ry))
	return pts


# 타원 띠 한 조각. annulus_at 과 같은 규약(각 0 = 12시, 시계 방향)이다.
func _e_band(c: Vector2, rx: float, ry: float, ix: float, iy: float,
		a0: float, a1: float, seg: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg + 1:
		var a := lerpf(a0, a1, float(i) / float(seg))
		pts.append(c + Vector2(sin(a) * rx, -cos(a) * ry))
	for i in seg + 1:
		var a := lerpf(a1, a0, float(i) / float(seg))
		pts.append(c + Vector2(sin(a) * maxf(ix, 0.3), -cos(a) * maxf(iy, 0.3)))
	return pts


# 온 고리는 비볼록이라 한 폴리곤으로 넘기면 삼각분할이 튄다 — 4등분한다.
# (_icon_mod 1774행 주석이 이미 밟아 본 함정이다. 여기선 draw_arc 로 피할
#  수 없다 — 폭 1px arc 는 눌린 12시·6시에서 0.79px 가 되어 사라진다.)
#
# 두 규약을 이름부터 갈라 둔다. 바꿔 쓰면 결과가 정반대로 틀린다.
#   _e_ring_w  화면 인셋 — 폭 w 가 어느 각에서도 w.  테두리·금테·인레이 홈
#   _e_ring_r  칩 좌표계 비율 — 12시에서 flat 배로 준다.  면의 구역
func _e_ring_w(c: Vector2, rx: float, ry: float, w: float, col: Color) -> void:
	for q in 4:
		draw_colored_polygon(_e_band(c, rx, ry, rx - w, ry - w,
				TAU * float(q) * 0.25, TAU * float(q + 1) * 0.25, 6), col)


func _e_ring_r(c: Vector2, rx: float, ry: float, k0: float, k1: float,
		col: Color) -> void:
	for q in 4:
		draw_colored_polygon(_e_band(c, rx * k1, ry * k1, rx * k0, ry * k0,
				TAU * float(q) * 0.25, TAU * float(q + 1) * 0.25, 6), col)


# ══════════════════════════════════════════════════════════
#  낙하 물리  (면 좌표계)
# ──────────────────────────────────────────────────────────
#  물리는 테이블 면 위의 2D 다. 화면은 그것을 52° 로 눌러 그린 그림자일 뿐이다.
#    면 좌표   u 가로(화면 x 와 1:1) · w 깊이 · h 면에서 뜬 높이  ← 물리는 이것만 안다
#    화면 좌표 x · y                                            ← 그리기·히트만 안다
#  다리는 _p2s / _p2g 둘뿐이다. TBL.flat / TBL.tall 이 곱해지는 곳은 그 둘과
#  _dart_e · _obj_box · _obj_shape · _obj_shadow · _chip_flat 뿐이다. grep 으로 검산된다.
#  역변환(_s2p)은 만들지 않는다 — 화면 y 하나에 w 와 h 가 섞여 있어 유일하지 않다.
#  그래서 히트는 마우스를 면으로 보내지 않고 물건을 화면으로 보낸다.
#
#  수치는 이 표 하나다. 주석의 실측값은 이 코드를 그대로 옮긴 검증기로 1500롤
#  돌려 잰 것이다 (매물 4개 · 고정 서브스텝 1/160).
# ══════════════════════════════════════════════════════════
const DROP := {
	# ── 트레이 (면 좌표) ─────────────────────────────
	#  u 는 물체 화면 반폭(hw)을 뺀 값이 중심 한계. w 는 중심 기준.
	#  w_hi 165 를 정한 것은 레일이 아니라 가격판이다 — 지면 y = 80+165*0.788 = 210,
	#  가격 baseline 240, 글자 바닥 242, 레일 244. 물건 자체는 훨씬 위에서 멈춘다.
	#  w_lo 52 는 펠트 인쇄 문구(글자 y[88,98]) 아래 4px. 실측 최상단 108.2.
	#  좌우 한계는 창구가 정한다. 펠트는 사다리꼴이고 가장 좁은 곳이 뒤쪽이라,
	#  거기서 물건의 바깥 모서리가 빗변을 안 넘도록 잡았다 (다트 반폭 37.5 ·
	#  화면 위쪽 끝 y 119 에서 빗변 x 75.8 → 최소 u 113.3 < 153.5). 손으로
	#  끌지 않는 한 어떤 물건도 창구에 못 닿는다 — 계산대가 레일 아래였을 때의
	#  죽은 띠를 세로에서 가로로 옮긴 것이고, 솔버는 여전히 이 사실을 모른다.
	#
	#  w 위쪽 24 는 물건 윗모서리가 카운터(112)를 안 넘는 선이고, 아래쪽 126 은
	#  가격판(지면 +30)이 앞 레일(244)을 안 넘는 선이다. 둘 다 그림이 정한다.
	"u_lo": 116.0, "u_hi": 524.0, "w_lo": 24.0, "w_hi": 126.0,
	"lane": 0.55,        # 출발 u 의 레인 혼합비. 0=난장 1=정렬. 구석 몰림 손잡이

	# ── 던지기 (먼 레일 뒤 슈트에서 앞으로 던진다) ──
	#  h0 는 화면으로 62~74px. w0=-10 이라 출발점 화면 y 는 -2~10 — 덮개와 HUD 뒤다.
	#  물건은 낙하 후반(y>80)에 레일 밑에서 튀어나온다. 착지 w 실측 p50 79.
	"w0": -10.0, "h0_lo": 100.0, "h0_hi": 120.0,   # 지면 y 104 · 화면 y 30~42
	"vw_lo": 160.0, "vw_hi": 250.0, "vu_amp": 36.0, "vh_hi": 40.0,
	"om_amp": 7.0, "stag": 0.08,

	# ── 적분 (반음시 오일러 · 고정 서브스텝) ────────
	#  sub 은 터널링 때문이 아니다 — 실측 최대 상대변위가 1/160 에서 1.45px 이고
	#  가장 작은 상호작용 현이 2(19+9)=56px 이라 1/60 이어도 안 뚫린다.
	#  sub 이 실제로 사는 이유는 바닥 관통 깊이다: |vh| 최대 575 에서
	#  1/160 은 3.6면px(화면 2.2), 1/60 은 9.6면px(화면 5.9) — 반발이 펠트 위
	#  공중에서 일어나기 시작한다.
	"g": 1400.0, "sub": 0.00625, "max_d": 0.033, "sub_max": 8,

	# ── 반발 · 마찰 ──────────────────────────────────
	"e_item": 0.34, "e_mod": 0.16, "e_dart": 0.24,
	"e_wall": 0.30, "e_pair": 0.30, "mu_b": 0.22,
	"a_fric": 520.0,     # 쿨롱(등감속). 지수감쇠로 두면 정착이 증명 안 된다
	"a_spin": 30.0, "inv_i": 0.010, "om_cap": 10.0, "v_wake": 10.0,
	"h_touch": 0.5, "v_land": 42.0,

	# ── 정착 ─────────────────────────────────────────
	#  증명 상한 2.15초. 실측 p50 1.23 · 최대 1.37 (1500롤, t_max 발동 0회).
	#  마지막 가시 움직임과 drop_awake=false 사이의 죽은 꼬리는 최대 0.20초다.
	"v_sleep": 6.0, "om_sleep": 0.35, "t_sleep": 0.12,
	"t_max": 2.6, "relax": 3, "relax_hard": 12,

	# ── 면 위 충돌 원 ────────────────────────────────
	#  칩 원 1개(실루엣과 정확히 일치) · 개조 원 1개 · 다트 원 3개(캡슐).
	#  다트에 가운데 원이 있어 칩-다트 최소 중심거리가 방위와 무관하게 28 이다.
	#  이 28 이 가격판 겹침 불가 정리의 전제다 (아래 _bill_draw 주석).
	"r_item": 19.0, "r_mod": 21.0, "r_dart": 9.0, "d_dart": 16.0,

	# ── 화면 반폭 (좌우 벽 전용 — 충돌 반지름과 다르다) ──
	#  벽은 "그려지는 것" 을 가두고 충돌은 "형상" 이라 두 일에 각각 맞는 값이다.
	"hw_item": 19.0, "hw_mod": 22.0, "hw_dart": 37.5,

	# ── 연출 (전부 그리기 전용. 물리에 한 방울도 안 흘린다) ──
	"lift_hov": 6.0, "lift_k": 260.0, "lift_c": 22.0,
	"wob_k": 150.0, "wob_c": 11.0,
	"sold_t": 0.46, "dim_off": 0.30, "sh_a": 0.34, "sh_grow": 0.030,
	"bill_dy": 30.0,
}

var drop := []          # 물체 하나 = 사전 하나. stock 과 인덱스를 공유한다.
var drop_t := 0.0       # 이번 낙하의 경과
var drop_acc := 0.0     # 서브스텝 누적기 (나머지를 이월해 프레임률 독립을 만든다)
var drop_awake := false
var drop_toss := false  # 지금 깨어 있는 이유가 던지기인가 (낙하와 다른 상태다)
var drop_fast := false  # 헤드리스 — 낙하를 안 기다리고 즉시 감는다


# ══ 투영 — flat/tall 이 곱해지는 원점 ══
func _p2s(u: float, w: float, h: float) -> Vector2:
	return Vector2(u, TBL.fy + w * TBL.flat - h * TBL.tall)


func _p2g(w: float) -> float:
	return TBL.fy + w * TBL.flat


# 면 위 방위각 psi → 화면 방향. 벡터 길이가 곧 전경축소율이다 (|e| ∈ [0.788, 1.0]).
# 정사영이라 근사가 아니다. 최소가 0.788 배라 다트가 점으로 뭉개지지 않는다.
func _dart_e(it: Dictionary) -> Vector2:
	return Vector2(cos(it.psi), sin(it.psi) * TBL.flat)


# ══ 던지기 — 난수를 쓰는 유일한 곳 (물체당 7뽑기) ══
func _drop_roll() -> void:
	_hand_abort()
	drop.clear()
	drop_t = 0.0
	drop_acc = 0.0
	drop_toss = false
	var n := stock.size()
	for i in n:
		var r: float = DROP.r_item
		var nb := 1
		var e: float = DROP.e_item
		var hw: float = DROP.hw_item
		match stock[i].type:
			"mod":
				r = DROP.r_mod
				e = DROP.e_mod
				hw = DROP.hw_mod
			"dart":
				r = DROP.r_dart
				nb = 3
				e = DROP.e_dart
				hw = DROP.hw_dart
		# 완전 난수면 넷 중 둘이 같은 지점에 쏟아지는 판이 잦고, 그 둘이 같이
		# 벽으로 밀린다. 레인은 출발만 벌려 둘 뿐 정착 위치를 통제하지 않는다.
		var lane: float = lerpf(DROP.u_lo + 90.0, DROP.u_hi - 90.0,
				(float(i) + 0.5) / float(n))
		var u0 := randf_range(DROP.u_lo + hw, DROP.u_hi - hw)
		drop.append({
			"u": lerpf(u0, lane, DROP.lane), "w": DROP.w0,
			"h": randf_range(DROP.h0_lo, DROP.h0_hi),
			"vu": randf_range(-DROP.vu_amp, DROP.vu_amp),
			"vw": randf_range(DROP.vw_lo, DROP.vw_hi),
			"vh": randf_range(0.0, DROP.vh_hi),
			"psi": randf() * TAU,
			"om": randf_range(-DROP.om_amp, DROP.om_amp),
			"r": r, "nb": nb, "e": e, "hw": hw, "t0": float(i) * DROP.stag,
			"held": false, "slot": -1, "mark": Vector2.ZERO, "scuff": [],
			"air": true, "into": false, "sleep": false, "rest": 0.0,
			"wob": 0.0, "wv": 0.0, "lift": 0.0, "lv": 0.0,
			"sold": 0.0, "to": Vector2.ZERO, "gone": false,
		})
	drop_awake = true
	if drop_fast:
		_drop_settle()


# "떨어지는 중" 이다. 던져서 미끄러지는 것은 여기 안 든다 — 물건이 이미
# 펠트 위에 있고 읽히므로, 툴팁을 끄거나 클릭을 "지금 세운다" 로 삼키거나
# 다음 물건 집기를 막을 이유가 없다. 소비자 넷이 전부 그 뜻으로 쓴다.
func _drop_busy() -> bool:
	return drop_awake and not drop_toss


func _drop_update(d: float) -> void:
	_hand_update(d)
	if state == S.STAGE:
		stage_t += d
		npc_clock += d
	if state != S.SHOP:
		return
	var dd: float = minf(d, DROP.max_d)
	npc_clock += dd
	_sweep_update(dd)
	_waste_update(dd)
	if drop_awake or sweep_live:
		# 나머지를 버리지 않고 이월한다. 모든 스텝이 정확히 sub 이라 프레임률이
		# 배치를 못 흔든다 — 60/144/30/75fps 와 즉시정착의 최대 위치차 0.000000px.
		drop_acc += dd
		var n := 0
		while drop_acc >= DROP.sub and n < DROP.sub_max:
			drop_acc -= DROP.sub
			drop_t += DROP.sub
			_drop_step(DROP.sub)
			n += 1
		if drop_t > DROP.t_max and drop_awake:
			_drop_settle()      # 증명(2.15초) 밖이다. 이유를 안 캐고 못 박는다
	_drop_extras(dd)


func _drop_step(dt: float) -> void:
	for i in drop.size():
		var it: Dictionary = drop[i]
		if it.gone or it.sold > 0.0 or drop_t < it.t0:
			continue
		# 쓸기 중에는 아무도 안 잔다 — 팔이 언제 닿을지 물체가 모른다.
		if it.sleep and not sweep_on:
			continue
		if it.air:
			it.vh -= DROP.g * dt
			it.h += it.vh * dt
		it.u += it.vu * dt
		it.w += it.vw * dt
		it.psi += it.om * dt

		if it.h <= 0.0:
			it.h = 0.0
			# 반발 "후" 속도로 가른다. 충돌 속도로 가르면 e=0.16 짜리 개조가
			# 0.02px 짜리 안 보이는 호를 한 번 더 그리고 호 개수 증명이 틀어진다.
			var rv: float = -it.vh * it.e
			if rv >= DROP.v_land:
				it.vh = rv
				# 수평이 주는 유일한 이산 지점. 그래서 수평 속력이 던진 값 위로
				# 스스로 오르는 경로가 물체 간 교환 말고는 없다.
				it.vu *= 1.0 - DROP.mu_b
				it.vw *= 1.0 - DROP.mu_b
				it.om *= 1.0 - DROP.mu_b
				_drop_wob(it, rv)
			else:
				# air 플래그로 가른다. |vh| 임계로 가르면 그 임계가 g*sub(8.75)와
				# 결합해 sub 을 바꾸는 순간 조용히 틀린다.
				if it.air:
					_drop_wob(it, 26.0)
				it.air = false
				it.vh = 0.0

		if it.h <= DROP.h_touch:
			# 쿨롱 등감속. 유한 시간에 정확히 0 이 된다 — 정착 증명의 열쇠다.
			var sp := sqrt(it.vu * it.vu + it.vw * it.vw)
			if sp > 0.0001:
				var k: float = maxf(sp - DROP.a_fric * dt, 0.0) / sp
				it.vu *= k
				it.vw *= k
			it.om = signf(it.om) * maxf(absf(it.om) - DROP.a_spin * dt, 0.0)

		_drop_walls(it)
		if sweep_on:
			_sweep_push(i)

	for k in int(DROP.relax):
		_drop_pairs()
	if sweep_on:
		# 분리 솔버는 위치를 순간이동시키므로 relax 뒤에 팔 오른쪽으로 되밀린
		# 물건이 남을 수 있다. 팔은 무한질량이라 마지막 말이 팔의 것이다.
		for i in mini(drop.size(), stock.size()):
			_sweep_push(i)

	var was := drop_awake
	drop_awake = false
	for it in drop:
		if it.gone or it.sold > 0.0 or it.held:
			continue
		if drop_t < it.t0:
			drop_awake = true
			continue
		if it.sleep:
			continue
		var still: bool = it.h <= 0.01 \
				and absf(it.vu) + absf(it.vw) + absf(it.vh) < DROP.v_sleep \
				and absf(it.om) < DROP.om_sleep
		it.rest = (it.rest + dt) if still else 0.0
		if it.rest >= DROP.t_sleep:
			it.sleep = true
			it.vu = 0.0
			it.vw = 0.0
			it.vh = 0.0
			it.om = 0.0
		else:
			drop_awake = true
	if was and not drop_awake and not sweep_live:
		drop_toss = false
		_drop_lock()


# 착지 흔들림 — 그리기 전용 스프링에 한 대 먹인다. 물리로 안 돌아온다.
func _drop_wob(it: Dictionary, v: float) -> void:
	it.wv = maxf(it.wv, clampf(absf(v) / 260.0, 0.0, 1.0))


# 스윕이 아니라 위치 클램프다 — 후조건이라 벽 터널링이 구조적으로 불가능하다.
# 쓸기 중에는 왼쪽 벽이 창구 빗변으로 물러난다. 그 밖은 물리가 아니라 구멍이다.
# 새 기하를 안 만든다 — _chute_dock_u 는 구매 비행의 무릎이 쓰는 바로 그 수다.
func _drop_lo(it: Dictionary) -> float:
	return _chute_dock_u(Z_SELL, it.w) if sweep_on else DROP.u_lo + it.hw


func _drop_walls(it: Dictionary) -> void:
	var lo: float = _drop_lo(it)
	var hi: float = DROP.u_hi - it.hw
	if it.u < lo:
		it.u = lo
		# 쓸기 중 왼쪽은 벽이 아니라 구멍이라 안 튕긴다. _sweep_push 가
		# 곧바로 이 물건을 waste 로 보낸다.
		if not sweep_on:
			it.vu = absf(it.vu) * DROP.e_wall
	elif it.u > hi:
		it.u = hi
		it.vu = -absf(it.vu) * DROP.e_wall
	# 먼 벽은 일방통행이다. w0 = -10 (레일 뒤) 에서 던지므로 진입 전에는 안 건다.
	if not it.into:
		if it.w >= DROP.w_lo:
			it.into = true
	elif it.w < DROP.w_lo:
		it.w = DROP.w_lo
		it.vw = absf(it.vw) * DROP.e_wall
	if it.w > DROP.w_hi:
		it.w = DROP.w_hi
		it.vw = -absf(it.vw) * DROP.e_wall


# 밀어낸 뒤 위치만 자른다. 속도를 안 건드리는 게 _drop_walls 와의 차이다.
# 먼 벽은 반드시 into 뒤에만 — 이 조건이 없으면 아직 레일 뒤에 있는 물건이
# 남과 한 번 닿는 것만으로 트레이 한가운데로 순간이동한다.
func _drop_clamp(it: Dictionary) -> void:
	it.u = clampf(it.u, _drop_lo(it), DROP.u_hi - it.hw)
	if it.into:
		it.w = maxf(it.w, DROP.w_lo)
	it.w = minf(it.w, DROP.w_hi)


# 면 위 충돌 원 k 번의 중심. 다트만 3개(0=꼬리 1=중심 2=촉).
func _drop_sub(it: Dictionary, k: int) -> Vector2:
	var c := Vector2(it.u, it.w)
	if it.nb == 1 or k == 1:
		return c
	var dir := Vector2(cos(it.psi), sin(it.psi)) * DROP.d_dart
	return c + (dir if k == 2 else -dir)


func _drop_live(it: Dictionary) -> bool:
	return not it.gone and it.sold <= 0.0 and drop_t >= it.t0 and not it.held


# 4물체 → 쌍 6개 → 원-원 검사 12회. 브로드페이즈를 붙이면 코드만 는다.
func _drop_pairs() -> void:
	for a in drop.size():
		if not _drop_live(drop[a]):
			continue
		for b in range(a + 1, drop.size()):
			if not _drop_live(drop[b]):
				continue
			for ia in int(drop[a].nb):
				for ib in int(drop[b].nb):
					_drop_pair(drop[a], ia, drop[b], ib)


func _drop_pair(A: Dictionary, ia: int, B: Dictionary, ib: int) -> void:
	var pa := _drop_sub(A, ia)
	var pb := _drop_sub(B, ib)
	var dv := pb - pa
	var dist := dv.length()
	var sep: float = A.r + B.r
	if dist >= sep:
		return
	var n := (dv / dist) if dist > 0.0001 else Vector2(1.0, 0.0)

	# ① 위치 — 면 안에서만 민다. h 를 안 건드리므로 위치에너지를 못 만든다.
	#    텔레포트인데도 발산이 불가능한 이유가 이 한 줄이다.
	var push := n * (sep - dist) * 0.5
	A.u -= push.x
	A.w -= push.y
	B.u += push.x
	B.w += push.y

	# ② 속도 — 다가오는 중일 때만. 이 조건이 없으면 접촉 상태에서 매 패스
	#    힘이 들어가 떤다. 등질량이라 이 형태가 곧 운동량 보존이고 e<1 이라
	#    운동에너지는 항상 준다.
	var rel := (Vector2(B.vu, B.vw) - Vector2(A.vu, A.vw)).dot(n)
	if rel < 0.0:
		var j: float = -(1.0 + DROP.e_pair) * rel * 0.5
		A.vu -= n.x * j
		A.vw -= n.y * j
		B.vu += n.x * j
		B.vw += n.y * j
		# ③ 회전은 곁가지다. om 은 그리기와 자기 감쇠 말고 아무 데도 안 먹인다 —
		#    inv_i 를 틀리게 잡아도 선형 수렴 증명이 안 깨진다. 상한만 못 박는다.
		var ra := pa - Vector2(A.u, A.w)
		var rb := pb - Vector2(B.u, B.w)
		A.om = clampf(A.om - (ra.x * n.y - ra.y * n.x) * j * DROP.inv_i,
				-DROP.om_cap, DROP.om_cap)
		B.om = clampf(B.om + (rb.x * n.y - rb.y * n.x) * j * DROP.inv_i,
				-DROP.om_cap, DROP.om_cap)
		# 자던 것을 깨운다. 이게 없으면 먼저 선 물건이 못 밀리는 말뚝이 되고
		# "서로 부딪힌다" 가 절반만 참이 된다. 수렴은 안 깨진다 — 총 운동에너지가
		# 단조 비증가라 깨움은 재분배일 뿐이다.
		if rel < -DROP.v_wake:
			if A.sleep:
				A.sleep = false
				A.rest = 0.0
			if B.sleep:
				B.sleep = false
				B.rest = 0.0

	_drop_clamp(A)
	_drop_clamp(B)


# 정착 확정. "겹침 없고 트레이 안" 이 정착의 정의다.
# 실현가능성: 원 지름 합 166 vs 트레이 폭 580 (3.5배). 데드락이 불가능하다.
# 실측 — 1500롤 전부 잔여 겹침 0.000px · 트레이 이탈 0.
func _drop_lock() -> void:
	for it in drop:
		it.into = true
	for k in int(DROP.relax_hard):
		_drop_pairs()
	for it in drop:
		if it.held or it.gone:
			continue
		_drop_clamp(it)


# 소비자가 둘이다 — 헤드리스(_drop_roll 말미)와 낙하 중 사람의 클릭.
# 근사가 아니라 같은 _drop_step 을 같은 고정 dt 로 감으므로 결과가 완전히 같다.
# 실측 최대 199 서브스텝 (예산 424).
func _drop_settle() -> void:
	_hand_abort()
	var guard := int(DROP.t_max / DROP.sub) + 8
	while drop_awake and guard > 0:
		guard -= 1
		drop_t += DROP.sub
		_drop_step(DROP.sub)
		if drop_t > DROP.t_max:
			break
	for it in drop:
		it.vu = 0.0
		it.vw = 0.0
		it.vh = 0.0
		it.om = 0.0
		it.h = 0.0
		it.air = false
		it.sleep = true
		it.rest = DROP.t_sleep
	_drop_lock()
	drop_awake = false
	drop_toss = false
	drop_acc = 0.0
	if _autoplay:
		_drop_verify()


# 물리와 무관한 것만. drop_awake 와 상관없이 매 프레임 돈다.
# tip_spot 은 지난 프레임 값이다(_tip_update 가 _process 끝) — 들어올림 1프레임 지연.
func _drop_extras(d: float) -> void:
	var hov: int = tip_spot if tip_a > 0.004 else -1
	for i in drop.size():
		var it: Dictionary = drop[i]
		if it.gone:
			continue
		# stock 을 읽는 곳 셋 중 하나. _buy 는 "건드리면 안 됨" 이라 폴링한다.
		if it.sold <= 0.0 and i < stock.size() and stock[i].sold:
			it.sold = 0.0001
			_drop_leave(i)
		if it.sold > 0.0:
			it.sold = minf(it.sold + d / DROP.sold_t, 1.0)
			if it.sold >= 1.0 and not it.gone:
				it.gone = true
				_drop_arrive(i)
			continue
		it.wv -= it.wob * DROP.wob_k * d
		it.wv *= exp(-DROP.wob_c * d)
		it.wob = clampf(it.wob + it.wv * d, -1.0, 1.0)
		if not it.held:
			it.mark = Vector2(it.u, it.w)
		# 든 물건은 눌린다 — 들리지 않는 노선이라 이것이 "잡았다" 의 전부다.
		var tgt: float = -HAND.dip if it.held else (DROP.lift_hov if i == hov else 0.0)
		it.lv += (tgt - it.lift) * DROP.lift_k * d
		it.lv *= exp(-DROP.lift_c * d)
		it.lift = clampf(it.lift + it.lv * d, -2.0, DROP.lift_hov + 3.0)


func _drop_leave(i: int) -> void:
	var it: Dictionary = drop[i]
	var p := _p2s(it.u, it.w, it.h)
	# 랙 칸은 이륙 시점에 굳힌다. 도착할 때 다시 계산하면 그 사이 판매·구매로
	# owned 가 바뀌어 엉뚱한 칸이 튄다. 튐 자체는 _drop_arrive 로 옮겼다 —
	# 물건이 아직 테이블에 있는데 랙이 먼저 반응하면 인과가 뒤집힌다.
	it.slot = -1
	match stock[i].type:
		"item":
			it.slot = clampi(owned.size() - 1, 0, GameData.max_items() - 1)
			it.to = _slot_rect(it.slot).get_center()
		"mod":
			it.to = p + Vector2(0.0, -30.0)
			pop(p + Vector2(0.0, -8.0), "보드 개조", C_CHIP.lightened(0.25), 13, 0.9)
		_:
			it.to = p + Vector2(0.0, -30.0)
			pop(p + Vector2(0.0, -8.0), "탄창 교체", C_GREEN.lightened(0.3), 13, 0.9)


# ══════════════════════════════════════════════════════════
#  히트 — 자리가 아니라 물건을 잡는다
# ══════════════════════════════════════════════════════════

# 그리기 순서와 히트 순서를 한 배열에서 뽑는다. 따로 만들면 언젠가 갈리고,
# 갈리는 순간 "보이는 건 앞엣건데 잡히는 건 뒤엣것" 이 되어 못 고치는 버그로 읽힌다.
func _z_order() -> Array:
	var z := []
	for i in mini(drop.size(), stock.size()):
		if drop[i].gone or drop[i].sold > 0.0:
			continue
		# ARMED 는 안 뺀다 — 아직 아무 일도 안 일어난 상태라, 빼면 누르고
		# 있는 동안 물건·가격·툴팁이 통째로 사라진다.
		if hand_st == H.CARRY and i == hand_i:
			continue
		z.append(i)
	z.sort_custom(func(a, b): return drop[a].w < drop[b].w)
	return z


# 히트 광역검사와 툴팁 앵커. 항상 lift 를 뺀 h 로 만든다 — 판정 사각이
# 들어올림을 따라가면 커서 끝에 걸린 물체가 60Hz 로 떤다.
func _obj_box(i: int) -> Rect2:
	var it: Dictionary = drop[i]
	var c := _p2s(it.u, it.w, it.h)
	match stock[i].type:
		"mod":
			var em := Vector2(TBL.mod_r + 3.0, TBL.mod_r * TBL.flat + 3.0)
			return Rect2(c - em, em * 2.0)
		"dart":
			var de := _dart_e(it)
			var dl: float = TBL.dart_l * de.length() + 8.5
			var dn := de.normalized()
			var ed := Vector2(absf(dn.x) * dl + 5.0, absf(dn.y) * dl + 5.0)
			return Rect2(c - ed, ed * 2.0)
	var ry: float = TBL.chip_r * TBL.flat + TBL.chip_t * TBL.tall
	return Rect2(c - Vector2(TBL.chip_r, ry), Vector2(TBL.chip_r * 2.0, ry * 2.0))


func _obj_shape(i: int, m: Vector2) -> bool:
	var it: Dictionary = drop[i]
	var c := _p2s(it.u, it.w, it.h)
	match stock[i].type:
		"mod":
			# 52° 정사영에서 면 위 축정렬 사각은 화면에서도 축정렬 사각이다.
			# 근사가 아니라 공짜로 정확하다.
			return absf(m.x - c.x) <= TBL.mod_r + 5.0 \
					and absf(m.y - c.y) <= TBL.mod_r * TBL.flat + 5.0
		"dart":
			var de := _dart_e(it)
			var dl: float = TBL.dart_l * de.length() + 4.0
			var dn := de.normalized()
			return _seg_d(m, c - dn * dl, c + dn * dl) <= 7.0
	var lz: float = TBL.chip_t * TBL.tall * 0.5          # 옆면 슬리버를 덮는다
	var q := (m - c - Vector2(0.0, lz)) / Vector2(TBL.chip_r + 2.0,
			TBL.chip_r * TBL.flat + lz + 2.0)
	return q.length_squared() <= 1.0


func _seg_d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / l2, 0.0, 1.0))


# 커서 아래 매물. _z_order 를 정확히 거꾸로 훑는다 — 위에 그려진 것이 잡힌다.
# 박스는 통과했는데 모양이 아니면 다음(아래) 물체로 흘려보낸다. 다트의 빈 박스가
# 뒤엣 칩을 가로채지 못하는 경로가 이것이다.
# 실측 — 정착 배치 300판을 1px 격자로 전수 조사해 못 잡는 물체 0/1200,
# 최소 표적 면적 667px²(다트) · 1158(칩) · 1719(개조).
func _shop_hit(m: Vector2) -> int:
	var lz: float = DROP.lift_hov * TBL.tall             # 3.70 — 들린 위치까지 덮는다
	var z := _z_order()
	for k in range(z.size() - 1, -1, -1):
		var i: int = z[k]
		if drop[i].sold > 0.0:
			continue
		if not _obj_box(i).grow_individual(2.0, 2.0 + lz, 2.0, 2.0).has_point(m):
			continue
		# 순수 수직 평행이동의 스윕이라 두 점 OR 이 정확한 덮개다 (근사가 아니다)
		if _obj_shape(i, m) or _obj_shape(i, m + Vector2(0.0, lz)):
			return i
	return -1


# ══════════════════════════════════════════════════════════
#  그리기
# ══════════════════════════════════════════════════════════

# _table_draw 의 "물건은 여기에" 자리 (덮개 앞 — 낙하 중 위로 삐져나온 건 잘린다)
func _goods_draw() -> void:
	# 팔려 나간 자리에 남는 코스터 자국. 개수를 보존하고 "여긴 이제 빈 자리" 를 말한다.
	for i in mini(drop.size(), stock.size()):
		var g: Dictionary = drop[i]
		if g.gone and not _sweep_wipe():
			_e_ring_w(Vector2(g.u, _p2g(g.w)), 13.0, 13.0 * TBL.flat, 1.0,
					C_TABLE.darkened(0.35))
	var z := _z_order()
	for i in z:                     # 그림자 먼저 전부 — 어떤 몸통보다도 밑이다
		_obj_shadow(i)
	var hov: int = tip_spot if tip_a > 0.004 else -1
	for i in z:
		_obj_draw(i, 0.0 if (hov < 0 or hov == i) else DROP.dim_off)


# 그림자가 없으면 높이 h 와 깊이 w 가 화면 y 하나로 뭉개져 구분이 안 된다.
# 장식이 아니라 이 투영의 유일한 깊이 단서다.
func _obj_shadow(i: int) -> void:
	var it: Dictionary = drop[i]
	if it.sold > 0.0:
		return
	var hh: float = it.h + it.lift
	var k: float = 1.0 + hh * DROP.sh_grow
	var col := Color(0.0, 0.0, 0.0, DROP.sh_a / k)
	for s in int(it.nb):
		var sp := _drop_sub(it, s)
		# 기존 그림자 벡터 (1.5,3.0) = light * 3.35. h=0 에서 정확히 일치한다.
		var g := Vector2(sp.x, _p2g(sp.y)) + TBL.light * (3.35 + hh * 0.10)
		draw_colored_polygon(_e_pts(g, it.r * k, it.r * k * TBL.flat, 14), col)


func _obj_draw(i: int, dim: float) -> void:
	_obj_paint(drop[i], stock[i], dim)


# drop/stock 인덱스에서 떼어 낸 몸통. 창구로 빠진 물건(waste)이 두 번째
# 소비자다 — 그쪽은 stock 을 안 들고 자기 사본을 들고 온다.
func _obj_paint(it: Dictionary, s: Dictionary, dim: float) -> void:
	var c := _p2s(it.u, it.w, it.h + it.lift)
	if it.sold > 0.0:
		# 팔린 물건은 면을 떠난다 — 화면 좌표로 넘어가는 유일한 지점이다.
		# 무릎 둘. 드래그로 산 것은 첫 다리 길이가 0 이고, 클릭으로 산 것은
		# 펠트에서 계산대까지 미끄러진 뒤 같은 자리에서 같은 곡선으로 떠난다.
		# 플래그가 0개다 — 물체 위치가 경로를 추론한다.
		var sv: float = float(it.sold)
		var via := Vector2(_chute_dock_u(Z_BUY, it.w), _p2g(it.w))
		if sv < HAND.knee:
			var ka: float = sv / HAND.knee
			c = c.lerp(via, ka * ka)
		else:
			var kb: float = (sv - HAND.knee) / (1.0 - HAND.knee)
			c = via.lerp(it.to, 1.0 - pow(1.0 - kb, 3.0))
		dim = sv * 0.55
	match s.type:
		"item":
			_chip_flat(c, s.d, it.psi, dim, it.wob)
		"cons":
			# 소비 아이템 — 작은 사각 꾸러미. 개조(캐비닛)보다 작고 칩(원반)과
			# 형태가 갈린다. 아트 방향이 미정이라 실루엣만 세워 둔다.
			var ce := Vector2(11.0, 11.0 * TBL.flat)
			var body: Color = C_PANEL.lightened(0.22 - dim * 0.2)
			draw_colored_polygon(PackedVector2Array([
					c + Vector2(-ce.x, -ce.y), c + Vector2(ce.x, -ce.y),
					c + Vector2(ce.x, ce.y), c + Vector2(-ce.x, ce.y)]), body)
			draw_rect(Rect2(c - ce, ce * 2.0), C_WIRE.darkened(0.2), false, 1.0)
			draw_string(font, Vector2(c.x - ce.x, c.y + 3.5),
					String(s.d.n).substr(0, 2), HORIZONTAL_ALIGNMENT_CENTER,
					ce.x * 2.0, 8, Color(C_TXT, 1.0 - dim))
		"mod":
			_icon_mod(c, TBL.mod_r, s.d.id, dim)
		_:
			# sh=false — 내장 그림자는 고정 오프셋이라 낙하 중 하늘을 같이 난다
			var de := _dart_e(it)
			_icon_dart(c, TBL.dart_l * de.length(), s.d.id, dim,
					de.angle() + 1.0304, 1.0 - dim * 0.5, false)


# 펠트에 누운 칩. 랙의 draw_chip(정원)은 안 고친다 — 같은 물건의 다른 자세다.
# _e_ring_w(화면 인셋)와 _e_ring_r(비율)을 섞어 쓰지 않는다.
func _chip_flat(c: Vector2, it: Dictionary, rot: float, dim: float, wob: float) -> void:
	var ti := _chip_ti(it.cost)
	var t: Dictionary = CHIP_TIERS[ti]
	var rx: float = TBL.chip_r * (1.0 + wob * 0.05)
	var ry: float = TBL.chip_r * TBL.flat * (1.0 - wob * 0.12)
	var body := Color(t.body).darkened(dim)
	var edge := Color(t.edge).darkened(dim)
	var sd: float = TBL.chip_t * TBL.tall              # 옆면 2.77px
	draw_colored_polygon(_e_pts(c + Vector2(0.0, sd), rx, ry), edge.darkened(0.35))
	draw_colored_polygon(_e_pts(c, rx, ry), edge)
	draw_colored_polygon(_e_pts(c, rx - 1.5, ry - 1.5), body)
	var step := TAU / float(CHIP_SPOTS[ti] * 2)
	for k in CHIP_SPOTS[ti]:
		var a := rot + float(k) * step * 2.0
		draw_colored_polygon(_e_band(c, rx, ry, rx * 0.66, ry * 0.66,
				a - step * 0.42, a + step * 0.42, 3), Color(t.spot).darkened(dim))
	_e_ring_r(c, rx, ry, 0.55, 0.61, edge.lightened(0.18))
	if it.get("g", "") != "":
		_e_ring_w(c, rx, ry, 1.0, C_GOLD.darkened(dim))
	var val := ("×" + str(it.v)) if it.k == "xmult" else str(it.v)
	var ink: Color = C_CHIP.lightened(0.5) if it.k == "chip" else C_MULT.lightened(0.45)
	draw_string(font, c + Vector2(-rx, 4.0), val,
			HORIZONTAL_ALIGNMENT_CENTER, rx * 2.0, 12, ink.darkened(dim))


# _table_draw 의 맨 끝 (덮개·레일 뒤) — 가격은 절대 안 잘려야 한다.
#
# 넷이 안 겹치는 근거는 라벨 회피 알고리즘이 아니라 분리 불변식이다.
#   · 가격판은 지면점 기준 균일 오프셋(bill_dy)이라 화면 y 가 w 의 단조함수다.
#     → 두 판이 겹치려면 |Δu| < 21.6 이고 |Δw| < 9/0.788 = 11.4,
#       즉 면 거리 < √(21.6² + 11.4²) = 24.4 여야 한다.
#   · 분리 솔버가 보장하는 최소 면 거리는 칩-다트 28 · 개조-다트 30 · 칩-칩 38.
#     24.4 < 28 이므로 겹침이 불가능하다. 실측 1500롤 겹침 0, 최소 y차 16.2px.
#   · 전제: 가격 문자열이 2자리 이내(bw ≤ 25). 지금 최대 가격은 14 다.
#     세 자리가 생기면 이 정리부터 다시 세워야 한다.
func _bill_draw() -> void:
	if _sweep_wipe():
		return              # 쓸려 나가는 물건에 가격을 안 붙인다
	for i in mini(drop.size(), stock.size()):
		var it: Dictionary = drop[i]
		if not it.into:
			continue        # 아직 레일 뒤다. 물건보다 가격이 먼저 뜨면 안 된다
		var s: Dictionary = stock[i]
		var txt := str(s.cost)
		var bw := gold_w(txt, 9)
		var col: Color = C_GOLD if (not s.sold and gold >= s.cost) \
				else C_DIM.darkened(0.25)
		draw_gold_at(it.u - bw * 0.5, _p2g(it.w) + DROP.bill_dy, txt, 9, col)


# 헤드리스 전용 자가검사. "정착 = 겹침 없고 · 트레이 안이고 · 넷 다 잡힌다" 를
# 기하 근사가 아니라 _shop_hit 자체로 잰다. 2px 격자라 상점 방문당 26,880 호출 —
# 오토플레이에서만 돈다. 실측 pen 0.000 · oob 0 · 최소표적 844~1156px².
func _drop_verify() -> void:
	var pen := 0.0
	var oob := 0
	for a in drop.size():
		var A: Dictionary = drop[a]
		if A.gone:
			continue
		var ok: bool = A.h <= 0.01
		ok = ok and A.u >= DROP.u_lo + A.hw - 0.01 and A.u <= DROP.u_hi - A.hw + 0.01
		ok = ok and A.w >= DROP.w_lo - 0.01 and A.w <= DROP.w_hi + 0.01
		if not ok:
			oob += 1
		for b in range(a + 1, drop.size()):
			var B: Dictionary = drop[b]
			for ia in int(A.nb):
				for ib in int(B.nb):
					pen = maxf(pen, A.r + B.r
							- _drop_sub(A, ia).distance_to(_drop_sub(B, ib)))
	var area := []
	area.resize(drop.size())
	area.fill(0)
	var y := 84.0
	while y < 252.0:
		var x := 1.0
		while x < 640.0:
			var hi := _shop_hit(Vector2(x, y))
			if hi >= 0:
				area[hi] += 4
			x += 2.0
		y += 2.0
	var mn := 1 << 30
	for i in area.size():
		if drop[i].gone:
			continue
		mn = mini(mn, area[i])
	if pen > 0.5 or oob > 0 or mn < 200:
		push_warning("drop: 정착 불변식 위반 pen=%.2f oob=%d 최소표적=%d" % [pen, oob, mn])
	if hand_st != H.NONE or buy_sel >= 0:
		push_warning("hand: 오토플레이에서 손 상태 %d / buy_sel %d" % [hand_st, buy_sel])
	for it in drop:
		if it.held:
			push_warning("hand: 오토플레이에서 held 물체")

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
const DART_DL := 10.0           # 보드에 꽂힌 다트 반길이
const MB_SEG := 10              # 20 칸이면 한 칸 호가 5px 라 뭉갠다


# 개조 아이콘은 id 가 아니라 효과 축(k)으로 갈린다.
# data.gd 가 "k 는 _mod_step 의 match 가 읽는 유일한 열쇠" 라고 못박았으므로
# 여기도 같은 열쇠를 쓴다. 같은 축의 개조가 새로 생기면 아이콘이 저절로 맞는다.
# (옛 판에서는 여기가 id 로 갈려 있어, 개조가 여덟 종으로 바뀐 뒤
#  match 가 하나도 안 걸려 여덟 개가 전부 민무늬로 그려지고 있었다.)
#
# 정확한 기하가 아니라 기호다. 실제 링 폭 0.10 은 17px 반지름에서 1.7px 라
# 사라지고, 속살(+0.06)과 겉살(-0.06)의 차이는 1px 여서 안 갈린다.
# 그래서 방향과 대소만 살리고 폭은 읽히도록 과장한다.
func _icon_mod(c: Vector2, r: float, id: String, dim: float) -> void:
	var m := GameData.mod_of(id)
	var k := String(m.get("k", ""))

	# 사각 캐비닛 — 이게 없으면 칩과 똑같은 원반이라 실루엣이 안 갈린다
	var pl := Rect2(c - Vector2(r + 3.0, r + 3.0), Vector2(r * 2.0 + 6.0, r * 2.0 + 6.0))
	draw_rect(pl, C_PANEL.darkened(0.35 + dim * 0.3))
	draw_rect(Rect2(pl.position, Vector2(pl.size.x, 1.0)), C_WIRE.darkened(0.35))

	# 판벌이는 판이 커지는 것 자체가 효과다. 바탕을 줄여 그려야 커질 자리가 난다.
	var br: float = r * (0.84 if k == "out" else 1.0)

	var d := 0.42 + dim * 0.35
	var acc := C_ACC.darkened(dim)
	var ghost := Color(C_TXT, 0.45 - dim * 0.3)
	var step := TAU / float(MB_SEG)

	# 바탕 보드 — 죽여 깔고, 바뀌는 곳만 원색으로 덮는다
	draw_circle(c, br, C_DARK.darkened(d * 0.5))
	for i in MB_SEG:
		var a := float(i) * step
		draw_colored_polygon(annulus_at(c, br * MB.bo, br * MB.di, a, a + step, 3),
				(C_LIGHT if i % 2 == 0 else C_DARK).darkened(d))
	# 링 강조는 draw_arc 로만 그린다. 전체 링을 폴리곤으로 넘기면 이음매가
	# 겹친 비볼록 도형이라 삼각분할이 튄다.
	var trp_lit := k == "band" or k == "slide" or k == "ring"
	if not trp_lit:
		draw_arc(c, br * (MB.ti + MB.to) * 0.5, 0.0, TAU, 20,
				C_GREEN.darkened(d), (MB.to - MB.ti) * br)
	if k != "band" and k != "out":
		draw_arc(c, br * (MB.di + 1.0) * 0.5, 0.0, TAU, 20,
				C_RED.darkened(d), (1.0 - MB.di) * br)
	if k != "bull":
		draw_circle(c, br * MB.bo, C_GREEN.darkened(d))
		draw_circle(c, br * MB.bi, C_RED.darkened(d))

	match k:
		"band":
			# 폭을 주고받는다. 한쪽이 굵어지면 반드시 다른 쪽이 가늘어진다.
			# 속살과 겉살이 서로의 거울이 되도록 부호만 보고 갈린다.
			var up: bool = float(m.v[0]) > 0.0
			var wt: float = 0.24 if up else 0.06
			var wd: float = 0.07 if up else 0.26
			draw_arc(c, br * 0.53, 0.0, TAU, 24, acc, wt * br)
			draw_arc(c, br * (1.0 - wd * 0.5), 0.0, TAU, 24,
					C_RED.lightened(0.25).darkened(dim), wd * br)
			# 원래 폭을 유령선으로 남겨 "무엇이 무엇으로 바뀌었는가" 를 읽힌다
			for q in [MB.ti, MB.to, MB.di]:
				draw_arc(c, br * q, 0.0, TAU, 20, ghost, 1.0)
		"slide":
			# 띠가 더블 바로 안쪽으로 옮겨간다. 원래 자리와 새 자리를 같이 보인다.
			var w: float = MB.to - MB.ti
			draw_arc(c, br * (MB.ti + MB.to) * 0.5, 0.0, TAU, 20, ghost, w * br)
			draw_arc(c, br * (MB.di - w * 0.5 - 0.02), 0.0, TAU, 24, acc, w * br)
			for i in 4:
				var a := float(i) * TAU * 0.25 + step * 0.5
				var u := Vector2(sin(a), -cos(a))
				draw_line(c + u * br * 0.62, c + u * br * 0.76, acc, 1.0)
		"ring":
			# 안쪽에 띠가 하나 더 생긴다. 기존 띠는 초록 그대로 두어 "추가" 로 읽힌다.
			draw_arc(c, br * (MB.ti + MB.to) * 0.5, 0.0, TAU, 20,
					C_GREEN.darkened(d), (MB.to - MB.ti) * br)
			# 두 띠 사이를 비워 두 개임이 세어지게 한다. 얇으면 무늬로 읽힌다.
			draw_arc(c, br * 0.33, 0.0, TAU, 22, acc, 0.15 * br)
		"bull":
			# 불은 넓어지고 한복판은 좁아진다. 원래 불 크기를 유령선으로.
			draw_circle(c, br * MB.bo * 1.55, acc)
			draw_circle(c, br * MB.bi * 0.65, C_RED.lightened(0.2).darkened(dim))
			draw_arc(c, br * MB.bo, 0.0, TAU, 16, ghost, 1.0)
		"out":
			# 판이 커진다. 바탕을 줄여 그렸으므로 그 바깥이 새로 생긴 땅이다.
			draw_arc(c, br * (MB.di + 1.0) * 0.5, 0.0, TAU, 20,
					C_RED.darkened(d), (1.0 - MB.di) * br)
			draw_arc(c, (br + r) * 0.5, 0.0, TAU, 26, acc, r - br)
			draw_arc(c, br, 0.0, TAU, 20, ghost, 1.0)
		"swap":
			# 가장 작은 칸 v 개가 최대값이 된다. 바뀌는 칸 수를 그대로 칠한다.
			# 칸 값이 최대로 "올라간다". 판 밖으로 삐져나오게 그려 승격을 보인다.
			# 짝패도 부채꼴을 쓰므로 이 삐침이 둘을 가르는 유일한 표식이다.
			var n: int = clampi(int(m.v), 1, MB_SEG)
			for i in n:
				var a := float(i * 2) * step
				draw_colored_polygon(annulus_at(c, br * MB.bo, br * 1.14,
						a + step * 0.12, a + step * 0.88, 3), acc)
		"odd":
			# 칸마다 짝이 생긴다. 붙어 있는 두 칸이 같은 값이 되는 것을 보인다.
			# 붙은 두 칸이 같은 값이 된다. 바깥에서 다리로 묶어 "짝" 을 명시한다.
			# 판갈이와 갈리는 지점은 이 다리와, 부채꼴이 판 안에 머문다는 것이다.
			for pair in [0, 4, 8]:
				for j in 2:
					var a := float(pair + j) * step
					draw_colored_polygon(annulus_at(c, br * MB.bo, br * MB.di,
							a, a + step, 3), acc if j == 0 else acc.darkened(0.3))
				var a0 := float(pair) * step
				draw_arc(c, br * (MB.di + 0.07), a0 - PI * 0.5,
						a0 + step * 2.0 - PI * 0.5, 8, acc, 1.6)


# rot 은 기본 각도에서 더 돌릴 양(레일 정렬 · 탁자 위 흩뿌림), a 는 알파(focus 감쇠).
# 회전 인자 이름은 draw_item_chip 이 이미 쓰는 rot 에 맞췄고,
# 알파 인자를 뒤에 덧붙인 것은 _icon_modifier 가 a 를 받아들인 선례와 같은 방식이다.
func _icon_dart(c: Vector2, dl: float, id: String, dim := 0.0,
		rot := 0.0, a := 1.0, sh := true) -> void:
	# 기본 각도. 촉이 오른쪽 위, 꼬리가 왼쪽 아래로 눕는다.
	# (옛 주석은 _draw_darts 와 같은 각이라고 했지만 그쪽은 꼬리가 오른쪽 위라
	#  실제로는 정반대였다. 지금은 _draw_darts 도 이 함수를 쓴다.)
	var dir := Vector2(6.0, -10.0).normalized().rotated(rot)
	var nrm := Vector2(-dir.y, dir.x)
	# 굵기는 길이를 따라간다. 절대값으로 두면 dl 을 키웠을 때 길기만 하고
	# 얇은 막대가 된다 — 손 부채(dl 30)에서 실제로 그렇게 나왔다.
	# 기준은 매대 크기 dl 19. 바닥을 둬 보드에 꽂힌 다트(dl 7)가
	# 실오라기가 되는 것을 막는다.
	var k: float = maxf(0.75, dl / 19.0)
	var bw := 2.6 * k
	var fin := 3.2 * k
	var col := C_TXT
	match id:
		"hvy":
			bw = 4.0 * k
			fin = 2.4 * k
			col = C_WIRE.lightened(0.30)
		"lgt":
			bw = 1.5 * k
			fin = 4.6 * k
			col = C_GREEN.lightened(0.35)
		"prc":
			bw = 2.2 * k
			fin = 2.8 * k
			col = C_CHIP.lightened(0.25)
		"mag":
			bw = 3.0 * k
			fin = 3.4 * k
			col = C_MULT.lightened(0.25)
	col = Color(col.darkened(dim), a)

	var tip := c + dir * dl
	var tail := c - dir * dl
	var brl := c + dir * dl * 0.1

	# 내장 그림자는 고정 오프셋이라 낙하 중 하늘을 같이 난다.
	# 테이블에서는 끄고 _goods_draw 가 높이에 맞는 그림자 하나만 그린다.
	if sh:
		draw_line(tip + Vector2(1.5, 3.0), tail + Vector2(1.5, 3.0),
				Color(0.0, 0.0, 0.0, 0.28 * a), bw)
	# 촉
	draw_colored_polygon(PackedVector2Array([tip,
			brl + nrm * bw * 0.5, brl - nrm * bw * 0.5]), Color(C_LIGHT.darkened(dim), a))
	# 배럴
	draw_line(brl, c - dir * dl * 0.35, col, bw)
	# 샤프트
	draw_line(c - dir * dl * 0.35, c - dir * dl * 0.6,
			Color(C_DARK.lightened(0.25).darkened(dim), a), 1.6)
	# 날개
	var w0 := c - dir * dl * 0.6
	draw_colored_polygon(PackedVector2Array([w0, w0 + nrm * fin - dir * dl * 0.2,
			tail, w0 - nrm * fin - dir * dl * 0.2]), col)

	match id:
		"hvy":
			for t in [0.55, 0.75]:
				var q := brl.lerp(c - dir * dl * 0.35, t)
				draw_line(q + nrm * bw * 0.6, q - nrm * bw * 0.6,
						Color(C_DARK.darkened(dim), a), 2.0)
		"lgt":
			for side in [-1.0, 1.0]:
				draw_line(tail + nrm * side * 2.5 * k - dir * 2.0 * k,
						tail + nrm * side * 2.5 * k - dir * 6.0 * k, col, 1.0)
		"prc":
			draw_line(tip, tip + dir * 5.0 * k, Color(C_CHIP.lightened(0.4).darkened(dim), a), 1.0)
		"mag":
			draw_arc(tip + dir * 4.0 * k, 4.5 * k, PI * 0.15, PI * 0.85,
					10, Color(C_MULT.lightened(0.4).darkened(dim), a), 1.0)


# ══════════════════════════════════════════════════════════
#  제약 아이콘
# ──────────────────────────────────────────────────────────
#  GameData.modifiers() 6종. 세 자리에서 크기만 달리 쓴다.
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

		# ── 높은 목표 ────────────────────────────────────
		# 목표선(가로획)이 있고 그 위를 뚫고 오르는 화살표. 손실색 하나다 —
		# 제약 세트에는 얻는 색이 한 점도 안 들어간다는 규칙 그대로다.
		"tgt":
			draw_rect(Rect2(c + Vector2(-r * 0.7, r * 0.5),
					Vector2(r * 1.4, w1)), grey)
			draw_rect(Rect2(c + Vector2(-w2 * 0.5, -r * 0.34),
					Vector2(w2, r * 0.9)), loss)
			var tipv := PackedVector2Array([
					c + Vector2(0.0, -r * 0.86),
					c + Vector2(-r * 0.42, -r * 0.22),
					c + Vector2(r * 0.42, -r * 0.22)])
			draw_colored_polygon(tipv, loss)

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
#  손 · 계산대   (끌어 옮기기 · 두 갈래 구매)
# ──────────────────────────────────────────────────────────
#  물체는 안 들린다. h ≡ 0 이다. 커서는 펠트 위의 물건을 민다.
#  이 한 줄이 두 가지를 동시에 산다.
#    ① 역변환.  _p2s 는 못 뒤집는다(화면 y 에 w 와 h 가 섞인다). 뒤집는 것은
#       _p2s 가 아니라 _p2g 다 — _p2g(w) = fy + w*0.788 은 flat != 0 인
#       일변수 아핀사상이라 전단사고, 그 역이 _g2w 다. h 를 0 으로 못 박은
#       절단면 하나만 뒤집는 것이라 근사가 0 이다.
#    ② 수렴 증명.  이 구획이 h · vh 에 쓰는 값은 0 뿐이고, 손에 든 물체는
#       적분기(_drop_step)에 한 번도 안 들어간다. 놓을 때 속도도 0 이라
#       적분기가 아예 안 돈다 — 겹침은 _drop_lock 의 위치 분리 12패스가
#       그 자리에서 정리한다(전부 v=0 이라 임펄스·깨우기가 안 걸린다).
#       낙하 구획의 "vh 를 양수로 만드는 경로가 없다" 가 문자 그대로 산다.
#       드래그가 drop_awake 를 켜지 않으므로 입력 잠금 창도 안 생긴다.
#
#  드는 것이 둘이다. 매대의 물건(hand_src 0)은 위 문단 그대로 면 위를 밀려
#  다니고, 랙의 칩(hand_src 1)은 물리 물체가 아니라 커서 밑의 그림뿐이다.
#  랙 칩 쪽은 적분기·펠트·겹침 어디에도 안 닿는다 — 그려지고, 놓이면 팔린다.
#
#  바깥과 닿는 곳은 열이다.
#    _hand_press/_motion/_release  입력          (_unhandled_input)
#    _hand_update(d)               매 프레임      (_drop_update 첫 줄)
#    _hand_abort()                 손을 비운다     (_drop_roll · _drop_settle
#                                                  · _reroll · _next_round 맨 앞)
#    _shop_tap(i) / _rack_tap(i)   고르기          (_hand_release 의 탭 갈래)
#    _chute_click(z) / _pay_click() 확정           (_click 의 S.SHOP)
#    _chute_draw()/_hold_draw()/_fly_draw()        (_table_draw · _draw_shop 말미)
#    buy_sel / sell_sel            고른 매물 · 고른 칩. 서로 배타
#    drop[i].held/.slot/.mark/.scuff               새 필드 넷
#
#  불변식 — held 인 물체의 u/w 를 쓰는 곳은 _hand_update 하나뿐이다.
#  grep 으로 검산된다. 나머지는 _drop_step 의 skip 한 토큰과 _drop_live 의
#  한 토큰으로 자동으로 빠진다.
# ══════════════════════════════════════════════════════════

enum H { NONE, ARMED, CARRY }

var hand_st: int = H.NONE
var hand_i := -1                 # 집은 매물. drop/stock 공용 인덱스
var hand_p0 := Vector2.ZERO      # 누른 화면 좌표. 탭은 이 점으로 판정한다
var hand_m := Vector2.ZERO       # 마지막 커서 화면 좌표
var hand_far := 0.0              # 누름 이후 |m - p0| 의 **누적 최대**. 단조 비감소
var hand_off := Vector2.ZERO     # 면 좌표 잡기 오프셋. ramp 로 0 에 녹는다
var hand_zone := -1              # 지금 켜진 창구 (-1 없음 · 0 판매 · 1 구매)
var hand_src := 0                # 무엇을 들었나 (0 = 매대 물건 · 1 = 랙 칩)
var hand_v := Vector2.ZERO       # 든 물체의 평활 속도(면px/s). 놓을 때 이걸 넘긴다

var buy_sel := -1                # 2클릭 구매의 1단계
var pay_flash := 0.0
var pay_msg := ""
var pay_msg_t := 0.0

const HAND := {
	# ── 판정 ─────────────────────────────────────────
	"slip": 5.0,
	#  클릭↔드래그 임계 (640x360 뷰 px). 창 기본이 1280x720 이라 실제 10 device px.
	#  최소 표적 면적 실측 667px²(다트 ≈26x26)의 19% — 5px 미끄러져도 같은 물체 위다.
	#  **안전장치가 아니라 감각 손잡이다.** 오분류가 골드를 쓰는 경로가 구조적으로
	#  없으므로(§4·§9) 3 으로 줄이든 8 로 늘리든 게임이 안 깨진다.

	# ── 손 ───────────────────────────────────────────
	"v_cap": 1800.0,
	#  물체가 커서를 따라가는 최대 속력(면px/s). 60fps 에서 프레임당 30 면px
	#  (화면 30 x 23.6). 손에 든 것은 적분기 밖이라 이건 터널링 상한이 아니라
	#  무게감 손잡이다 — 후려치면 아주 살짝 끌린다.
	"ramp": 260.0,
	#  잡기 오프셋을 0 으로 녹이는 속도(면px/s). 최대 오프셋은 다트 반폭 37.5 와
	#  깊이 42.6 → 0.164초. 녹고 나면 **커서 = 물체 지면점** 이라 계산대 판정이
	#  커서 기준과 물체 기준으로 갈릴 수 없다. 이 한 줄이 두 기준의 불일치를 없앤다.
	"dip": 1.5,
	#  잡힌 물체가 눌리는 깊이(면). 기존 lift clamp 하한 -2.0 안쪽이라 공짜.
	#  호버는 +6 으로 뜬다 — 뜸/눌림이 정반대라 두 상태가 안 헷갈린다.

	# ── 계산대 ───────────────────────────────────────
	"back_v": 900.0,
	#  창구 도크로 붙고 떨어지는 속도(면px/s). 도크가 손이 아니라 판의 동작이라
	#  손 속도(v_cap)와 갈라 뒀다. 계단 클램프였다면 경계에서 순간이동이 난다.
	"latch_gap": 6.0,
	#  창구 래치 히스테리시스(화면 px). 진입은 빗변 그대로, 이탈은 +6.
	#  경계에서 손이 떨려도 523Hz 가 연타되지 않고 창구 얼굴이 안 깜빡인다.
	"flash": 2.6,
	#  계산대 섬광 감쇠(1/s). deny_flash 와 같은 속도라 승낙과 거절이 같은 박자다 → 0.38초.
	"msg_t": 1.4,
	#  거절 사유를 하단에 띄우는 시간(초). _buy_block 의 문장을 그대로 쓴다.
	"knee": 0.26,
	#  구매 연출이 계산대를 지나는 진행도. sold_t 0.46 을 0.12s / 0.34s 로 가른다
	#  (뒤 0.34 는 기존 sold_t 를 그대로 물려받은 두 번째 다리다).

	# ── 연출 (전부 그리기 전용. 물리에 한 방울도 안 흘린다) ──
	"land_wob": 90.0,
	#  놓을 때 _drop_wob 에 먹이는 값. wv = 90/260 = 0.346 으로 착지 반발(rv≈84)과
	#  같은 크기다 — 놓기와 착지가 같은 어휘를 쓴다.
	"scuff_n": 10,      # 마찰 자국 링버퍼 길이. 0.42초 뒤 알파 0
	"scuff_dt": 0.02,   # 적립 최소 간격(초)
	"scuff_min": 0.6,   # 적립 최소 이동(면px). 제자리 떨림으로 자국이 안 쌓이게

	# ── 던지기 ───────────────────────────────────────
	#  놓는 순간의 손 속도를 물리에 넘긴다. 물체는 뜨지 않는다 — h·vh 는 0 에
	#  못 박은 채 면 위에서만 미끄러진다. 그래서 낙하 구획의 "vh 를 양수로
	#  만드는 경로가 없다" 가 이 기능이 붙어도 문자 그대로 산다.
	"toss_tau": 0.055,
	#  손 속도 평활 시간(초). 프레임 하나의 튐으로 던져지지 않게 3~4프레임을 섞는다.
	#  놓기 직전의 감속도 같이 섞이므로 "멈춰서 놓으면 안 미끄러진다" 가 성립한다.
	"toss_min": 45.0,
	#  이 아래는 아예 안 던진다(면px/s). 미끄럼 거리 v²/2a = 1.9면px 이라
	#  눈에 안 보이는 구간이다. 조심해서 놓는 배치의 정확도를 지키는 죽은 띠다.
	"toss": 0.34,
	#  손 속도 → 물체 속도 비율. 손은 v_cap 1800 까지 가지만 물건은 그만큼 안 난다.
	"toss_cap": 210.0,
	#  상한(면px/s). 마찰 a_fric 520 에서 미끄럼 거리 v²/2a = 42.4 면px
	#  (화면 가로 42 · 세로 33), 멈추기까지 0.40초. "후려쳐도 살짝" 의 상한이다.
	"toss_spin": 0.010,
	#  던진 속력 → 회전(rad/s). 상한에서 2.1, a_spin 30 으로 0.07초에 멎는다.
	#  미끄럼보다 훨씬 짧게 두는 것이 의도다 — 놓는 손짓의 잔상이지 팽이가 아니다.
}


# 창구 둘. 펠트 사다리꼴의 좌우 빗변이 그대로 창구다 —
# 왼쪽으로 밀면 팔고, 오른쪽으로 밀면 산다.
#
# 방향이 곧 뜻이라 라벨을 안 읽어도 성립한다. 대신 반대로 밀면 거절한다:
# 랙의 칩은 왼쪽만, 매대의 물건은 오른쪽만 받는다. 계산대 하나가 양방향이던
# 시절에는 "무엇을 밀었는가" 가 방향을 정했지만, 지금은 방향이 먼저다.
#
# 물리로 굴러 들어가는 것은 여전히 부등식 위반이다 — DROP.u_lo/u_hi 주석 참조.
const CHUTE := {
	"back": 80.0,     # 카운터 높이(TBL.fy)에서 펠트가 시작하는 x. 앞으로 갈수록 0
	"gap": 6.0,       # 래치 히스테리시스(화면 px). 진입 0 · 이탈 +gap
}
const Z_SELL := 0
const Z_BUY := 1


# 그 높이에서 펠트가 시작하는 x. 좌우 대칭이라 왼쪽 값 하나로 둘 다 낸다.
func _chute_edge(y: float) -> float:
	var t := clampf((y - TBL.fy) / (TBL.ny - TBL.fy), 0.0, 1.0)
	return CHUTE.back * (1.0 - t)


# 커서가 어느 창구 위인가. pad 로 히스테리시스를 만든다.
func _chute_at(m: Vector2, pad: float) -> int:
	if m.y < TBL.fy - pad or m.y > TBL.ny + pad:
		return -1
	var e := _chute_edge(m.y) + pad
	if m.x <= e:
		return Z_SELL
	if m.x >= VIEW.x - e:
		return Z_BUY
	return -1


# 도킹 목표 u. 물건 중심을 빗변 위에 얹어 반쯤 걸치게 한다 — "건네는 중" 이다.
# 계산대 때와 같이 붙는 속도는 손과 갈라 둔다. 도크는 손이 아니라 판의 동작이다.
func _chute_dock_u(zone: int, w: float) -> float:
	var e := _chute_edge(_p2g(w))
	return e if zone == Z_SELL else VIEW.x - e


# ══ 면 ↔ 화면 — h = 0 절단면 위에서만 ══
#  _p2s 의 역이 아니다(그건 존재하지 않는다). _p2g 의 역이다.
#  불변식: held 인 물체에만, 이 구획에서만 쓴다. h != 0 에 쓰면 틀린 답이 나온다.
func _g2w(y: float) -> float:
	return (y - TBL.fy) / TBL.flat


# ══ 입력 ══════════════════════════════════════════════
# true 를 돌려주면 _click 을 안 부른다(삼킨다).
func _hand_press(m: Vector2) -> bool:
	if _autoplay:
		return false                          # 좌표 입력은 오토플레이의 어휘가 아니다
	# 소비 아이템 슬롯 — 상점과 PICK 에서 산다. 사용 확정은 뗄 때다.
	if (state == S.SHOP and not sweep_live) or state == S.PICK:
		var ci := _cons_hit(m)
		if ci >= 0:
			hand_st = H.ARMED
			hand_src = 4
			hand_i = ci
			hand_p0 = m
			hand_m = m
			hand_far = 0.0
			return true
	if state != S.SHOP or sweep_live:
		return false
	# 창구 — 구매·판매 확정은 눌렀다 **뗄 때** 실행한다(확정 규칙:
	# 아이템 구매와 사용은 마우스 버튼을 눌렀다 뗄 때). 창구 자리는 고정이라
	# 낙하 중에도 잡는다. 끌고 나가면 취소다 — 버튼과 같은 문법이다.
	# 오토플레이·프로브는 _click 을 직접 부르므로 그쪽 경로는 그대로 산다.
	var cz := _chute_at(m, 0.0)
	if cz >= 0:
		hand_st = H.ARMED
		hand_src = 2
		hand_i = cz
		hand_p0 = m
		hand_m = m
		hand_far = 0.0
		return true
	if _drop_busy():
		return false
	if _reroll_rect().has_point(m) or _next_rect().has_point(m):
		return false
	# 랙의 칩도 집는다 — 왼쪽 창구로 밀면 판다. 매대보다 먼저 보는 이유는
	# y 로 갈려 있어(매물 최상단 99.3 > 랙 하단 58) 겹칠 수 없기 때문이 아니라,
	# 겹치게 되는 날 무엇이 이기는지를 여기 한 줄로 정해 두기 위해서다.
	if _can_sell():
		for k in mini(owned.size(), GameData.max_items()):
			if _slot_rect(k).has_point(m):
				hand_st = H.ARMED
				hand_src = 1
				hand_i = k
				hand_p0 = m
				hand_m = m
				hand_far = 0.0
				return true
	if _panel_rect().has_point(m):
		return false
	var i := _shop_hit(m)
	if i < 0:
		return false
	hand_st = H.ARMED
	hand_src = 0
	hand_i = i
	hand_p0 = m
	hand_m = m
	hand_far = 0.0
	return true


func _hand_motion(m: Vector2) -> void:
	if hand_st == H.NONE:
		return
	hand_m = m
	if hand_st == H.ARMED:
		# **누적 최대**다. 현재 거리가 아니다. 이 한 줄이 [끌고 갔다 돌아와서 뗌]
		# → 탭 판정이라는 경로를 원천 차단한다.
		hand_far = maxf(hand_far, m.distance_to(hand_p0))
		if hand_far > HAND.slip:
			if hand_src >= 2:
				_hand_abort()     # 창구·소비 슬롯은 버튼이다. 끌면 취소다
			else:
				_hand_take()


func _hand_take() -> void:
	hand_st = H.CARRY
	hand_v = Vector2.ZERO
	hand_zone = -1
	buy_sel = -1
	sell_sel = -1             # 드래그는 _click 을 안 거쳐 _sell_hit 의 낙수가 안 온다
	if hand_src == 1:
		# 랙 칩은 물리 물체가 아니다. 적분기에 넣을 것이 없어 커서만 따라간다.
		hand_off = Vector2.ZERO
		beep(196.0, 0.04, 0.08)
		return
	var it: Dictionary = drop[hand_i]
	# 집는 순간 물체가 안 튄다. 이 오프셋은 ramp 로 0 에 녹으므로 0.17초 뒤에는
	# 커서 = 물체 지면점이고, 그때부터 계산대 판정이 커서 기준과 물체 기준으로
	# 갈릴 수 없다. 그전에도 판정은 커서 하나만 본다.
	hand_off = Vector2(it.u, it.w) - Vector2(hand_p0.x, _g2w(hand_p0.y))
	it.held = true
	it.h = 0.0                # ← 이 노선 전체가 이 두 줄이다
	it.vh = 0.0
	it.vu = 0.0
	it.vw = 0.0
	it.om = 0.0
	it.air = false
	it.sleep = true           # 정착 인구조사에서 빠진다 → 드는 동안 _drop_busy() 가 false
	it.rest = DROP.t_sleep
	it.scuff = []
	beep(196.0, 0.04, 0.08)


func _hand_release(m: Vector2) -> void:
	if hand_st == H.NONE:
		return
	var i := hand_i
	var src := hand_src
	var z := hand_zone
	var was_carry: bool = hand_st == H.CARRY
	hand_st = H.NONE
	hand_i = -1
	hand_far = 0.0
	hand_zone = -1
	hand_src = 0
	if not was_carry:                         # 안 움직였다 = 탭
		if src == 2:
			# 창구 확정 — 뗄 때도 같은 창구 안이어야 한다. 눌러 놓고 밖에서
			# 떼면 취소다. 버튼의 문법 그대로다.
			if _chute_at(m, 0.0) == i:
				_chute_click(i)
		elif src == 4:
			if _cons_hit(m) == i:
				_cons_use(i)
		elif src == 1:
			_rack_tap(i)
		else:
			_shop_tap(i)
		return

	# 랙 칩 — 왼쪽 창구는 판매, 다른 랙 칸 위는 순서 바꾸기.
	if src == 1:
		if z == Z_SELL and _can_sell() and i >= 0 and i < owned.size():
			_sell(i)
		elif z == Z_BUY:
			pay_msg = "오른쪽은 사는 창구다"
			pay_msg_t = HAND.msg_t
			_deny()
		else:
			# 아이템 순서 변경 — 확정 규칙이다(아이템순서변경=True). 발동이
			# 랙 순서라 순서가 값을 바꾸는데, 지금까지 되팔고 다시 사는 것
			# 말고는 고칠 길이 없었다. 정산 중에는 손 시스템 자체가 안 살아
			# 있으므로 "득점 시작 시 순서 스냅샷" 계약과 안 부딪힌다.
			var j := _slot_at(m)
			if j >= 0 and i >= 0 and i < owned.size() and j != i:
				_rack_reorder(i, j)
			else:
				beep(147.0, 0.05, 0.07)       # 그냥 제자리로 돌아간다
		return

	if i < 0 or i >= drop.size():
		return
	hand_m = m
	var it: Dictionary = drop[i]
	it.held = false
	if z >= 0:
		var blk := "왼쪽은 파는 창구다" if z == Z_SELL else _buy_block(i)
		if blk == "":
			_pay_take(i)
			return                            # 이미 떠났다. 자리로 안 돌려보낸다
		# 판이 물건을 밀어냈다 — 창구가 좌우라 밀어내는 방향도 가로다.
		it.u = clampf(it.u, DROP.u_lo + it.hw, DROP.u_hi - it.hw)
		pay_msg = blk
		pay_msg_t = HAND.msg_t
		_deny()
		_hand_land(it)
		return
	beep(147.0, 0.05, 0.07)
	_hand_land(it, _toss_of(hand_v))


# 놓는 손짓을 물체 속도로 옮긴다. 죽은 띠(toss_min) 아래면 0 을 돌려주고,
# 그러면 _hand_land 가 예전 그대로 — 속도 없이 그 자리에 놓는 길로 간다.
func _toss_of(v: Vector2) -> Vector2:
	var t := v * HAND.toss
	var sp := t.length()
	if sp < HAND.toss_min:
		return Vector2.ZERO
	return t * (minf(sp, HAND.toss_cap) / sp)


# 물리에 반납한다.
#
# 속도 0 으로 반납하면(살며시 놓기 · 반송 · 취소) 적분기가 한 번도 안 돌고
# drop_awake 도 안 켜진다 — 곧바로 다음 물건을 집을 수 있다. 겹침은
# _drop_lock 의 위치 분리 12패스가 그 자리에서 정리하고, 전부 v=0 이라
# _drop_pair 의 ②임펄스·③깨우기가 안 걸린다(순수 위치 해소).
#
# 속도를 실어 반납하면(던지기) 면 위에서만 미끄러진다. h·vh 는 0 에 못 박혀
# 있어 낙하 구획의 "vh 를 양수로 만드는 경로가 없다" 가 그대로 산다. 멈추는
# 것은 쿨롱 마찰(a_fric 520)이 유한 시간에 정확히 0 을 만들어 주므로 정착
# 증명이 이미 덮고 있다 — 상한 210 에서 0.40초 · 42면px 다.
func _hand_land(it: Dictionary, v := Vector2.ZERO) -> void:
	it.h = 0.0
	it.air = false
	it.vh = 0.0
	it.vu = v.x
	it.vw = v.y
	it.u = clampf(it.u, DROP.u_lo + it.hw, DROP.u_hi - it.hw)
	it.w = clampf(it.w, DROP.w_lo, DROP.w_hi)
	it.scuff = []
	if v == Vector2.ZERO:
		it.om = 0.0
		it.sleep = true
		it.rest = DROP.t_sleep
		_drop_wob(it, HAND.land_wob)
		_drop_lock()
		return
	var sp := v.length()
	it.om = clampf(-v.x * HAND.toss_spin, -DROP.om_cap, DROP.om_cap)
	it.sleep = false
	it.rest = 0.0
	_drop_wob(it, maxf(HAND.land_wob, sp))
	_toss_wake()


# 던지기는 새 낙하로 센다. drop_t 를 물려받으면 t_max(2.6초) 예산이 이미
# 소진돼 있어 던지자마자 _drop_settle 이 물건을 순간이동시킨다. 입장 시차
# t0 도 같이 0 으로 내린다 — 첫 낙하에서만 뜻이 있는 값이라, 안 내리면
# 시차가 남은 물건이 _drop_live 에서 빠져 부딪히지 않는 유령이 된다.
func _toss_wake() -> void:
	drop_t = 0.0
	drop_acc = 0.0
	for e in drop:
		e.t0 = 0.0
	drop_awake = true
	drop_toss = true


# 손을 비우는 유일한 문.
func _hand_abort() -> void:
	if hand_src == 0 and hand_i >= 0 and hand_i < drop.size():
		var it: Dictionary = drop[hand_i]
		if it.held:
			it.held = false
			it.u = clampf(it.u, DROP.u_lo + it.hw, DROP.u_hi - it.hw)
			_hand_land(it)
	hand_st = H.NONE
	hand_i = -1
	hand_far = 0.0
	hand_zone = -1
	hand_src = 0
	buy_sel = -1


# ══ 프레임 ════════════════════════════════════════════
func _hand_update(d: float) -> void:
	pay_flash = maxf(pay_flash - d * HAND.flash, 0.0)
	pay_msg_t = maxf(pay_msg_t - d, 0.0)
	# 인덱스를 프레임 너머로 들고 가는 유일한 변수라 여기서 못 박는다 (sell_sel 과 같은 대접)
	if buy_sel >= 0 and (state != S.SHOP or buy_sel >= stock.size()
			or stock[buy_sel].sold):
		buy_sel = -1
	if hand_st == H.NONE:
		return
	var n_src: int = owned.size() if hand_src == 1 else drop.size()
	if state != S.SHOP or hand_i < 0 or hand_i >= n_src:
		_hand_abort()
		return
	# 창 밖에서 떼어 released 를 못 받은 경우의 안전망
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_hand_release(hand_m)
		return
	if hand_st != H.CARRY:
		return

	# 래치는 히스테리시스로 건다 — 경계에서 소리와 창구 얼굴이 연타되지 않는다.
	var z := _chute_at(hand_m, HAND.latch_gap if hand_zone >= 0 else 0.0)
	if z >= 0 and z != hand_zone:
		beep(523.0, 0.04, 0.10)
	hand_zone = z

	if hand_src == 1:
		return                                  # 랙 칩은 커서에 붙어 다닌다
	var it: Dictionary = drop[hand_i]
	hand_off = hand_off.move_toward(Vector2.ZERO, HAND.ramp * d)

	var ut: float = hand_m.x + hand_off.x
	var wt: float = clampf(_g2w(hand_m.y) + hand_off.y, DROP.w_lo, DROP.w_hi)
	if hand_zone >= 0:
		# 창구는 문이 아니라 도크다. 붙는 것은 판의 동작이라 손 속도와 무관하다.
		ut = _chute_dock_u(hand_zone, wt)
	else:
		ut = clampf(ut, DROP.u_lo + it.hw, DROP.u_hi - it.hw)
	var lim: float = HAND.back_v if hand_zone >= 0 else HAND.v_cap
	var was := Vector2(it.u, it.w)
	var p := was.move_toward(Vector2(ut, wt), lim * d)
	it.u = p.x
	it.w = p.y

	# 던질 속도는 커서가 아니라 물체가 실제로 간 거리로 잰다. 그래야 v_cap
	# 이 만드는 무게감이 던지기에도 그대로 실린다 — 후려쳐도 물건은 그만큼
	# 못 따라오고, 못 따라온 만큼 안 날아간다. 계산대에 붙어 있는 동안은
	# 판이 끄는 것이라 손짓이 아니다. 0 으로 둬서 거절 반송이 안 튀게 한다.
	if d > 0.0:
		if hand_zone >= 0:
			hand_v = Vector2.ZERO
		else:
			hand_v = hand_v.lerp((p - was) / d, clampf(d / HAND.toss_tau, 0.0, 1.0))
	_hand_scuff(it, d)


func _hand_scuff(it: Dictionary, d: float) -> void:
	for s in it.scuff:
		s.t += d
	var g := Vector2(it.u, _p2g(it.w))
	if it.scuff.is_empty() or (it.scuff[-1].t >= HAND.scuff_dt
			and it.scuff[-1].p.distance_to(g) >= HAND.scuff_min):
		it.scuff.append({"p": g, "t": 0.0})
		if it.scuff.size() > int(HAND.scuff_n):
			it.scuff.pop_front()


# ══ 구매 두 갈래 — 둘 다 계산대에서 끝난다 ═══════════
func _shop_tap(i: int) -> void:
	sell_sel = -1
	buy_sel = -1 if buy_sel == i else i
	beep(349.0 if buy_sel >= 0 else 262.0, 0.05, 0.10)   # 349 는 랙 선택과 같은 음


# 랙 칩을 끌지 않고 톡 눌렀을 때. 두 클릭 경로의 1단계다.
func _rack_tap(i: int) -> void:
	buy_sel = -1
	if i < 0 or i >= owned.size() or not _can_sell():
		sell_sel = -1
		return
	sell_sel = -1 if sell_sel == i else i
	sell_t = 0.0
	beep(349.0 if sell_sel >= 0 else 262.0, 0.05, 0.10)


# 커서가 랙의 몇째 칸 위인가. 빈 칸도 자리로 친다 — 맨 뒤로 보내는 드롭이다.
func _slot_at(m: Vector2) -> int:
	for k in GameData.max_items():
		if _slot_rect(k).has_point(m):
			return k
	return -1


# 랙 순서 바꾸기. i 를 뽑아 j 자리에 끼운다 — 자리를 서로 맞바꾸는 것이
# 아니라 끼워 넣기다. 발동 순서가 곧 랙 순서이므로 이 함수가 사실상
# "정산식 편집기"다. 봉인은 칩이 아니라 자리에 걸리는 게 아니라 칩에
# 걸리므로, 같은 칩을 따라가게 한다.
func _rack_reorder(i: int, j: int) -> void:
	j = mini(j, owned.size() - 1)
	var sealed_it: Dictionary = owned[sealed] if sealed >= 0 and sealed < owned.size() else {}
	var it: Dictionary = owned.pop_at(i)
	owned.insert(j, it)
	if not sealed_it.is_empty():
		sealed = owned.find(sealed_it)
	sell_sel = -1
	# slot_pop/vel/hot 은 인덱스를 공유한다. 하나만 지우면 크기가 어긋나
	# _panel_update 가 넘어진다 — _sell 과 같은 이유, 같은 처방이다.
	_panel_reset()
	beep(392.0, 0.05, 0.10)
	pop(_slot_rect(j).get_center() + Vector2(0.0, 22.0), "순서 변경", C_TXT, 9, 0.8)


# 창구를 눌렀을 때. 방향이 무엇을 뜻하는지는 여기서도 같다.
func _chute_click(z: int) -> void:
	if z == Z_SELL:
		if _can_sell() and sell_sel >= 0 and sell_sel < owned.size():
			_sell(sell_sel)
			return
		pay_msg = "먼저 랙에서 팔 칩을 고른다"
		pay_msg_t = HAND.msg_t
		_deny()
		return
	_pay_click()


func _pay_click() -> void:
	if buy_sel < 0:
		pay_msg = "먼저 매대에서 살 물건을 고른다"
		pay_msg_t = HAND.msg_t
		_deny()
		return
	var blk := _buy_block(buy_sel)
	if blk != "":
		pay_msg = blk                 # 선택은 유지한다 — 고쳐서 다시 누를 수 있어야 한다
		pay_msg_t = HAND.msg_t
		_deny()
		return
	var i := buy_sel
	buy_sel = -1
	_pay_take(i)


# 두 경로가 만나는 한 점. _buy 는 한 글자도 안 고친다 —
# stock[i].sold 를 _drop_extras 가 폴링해 _drop_leave 를 띄운다.
func _pay_take(i: int) -> void:
	var cost: int = stock[i].cost
	_buy(i)
	pay_flash = 1.0
	pay_msg = ""
	pay_msg_t = 0.0
	pop(_bank_rect().get_center() + Vector2(0.0, 30.0), "-%d" % cost, C_GOLD, 13, 0.7)


# ══ 그리기 ════════════════════════════════════════════
# 버튼(_btn)이 아니라 판의 어법이다 — 누르는 것이 아니라 놓는 자리다.
# 손에 든 것 하나만 따로, 앞치마·버튼 다음에 그린다. _goods_draw 는 창구보다
# 먼저 나가므로 창구까지 밀어 넣은 물건이 거기서는 덮인다.
func _hold_draw() -> void:
	if hand_st != H.CARRY:
		return
	if hand_src == 1:
		# 랙에서 뽑은 칩. 물리 물체가 아니라 커서 밑의 그림뿐이다.
		if hand_i < 0 or hand_i >= owned.size():
			return
		_e_ring_w(hand_m, PANEL.r + 4.0, (PANEL.r + 4.0) * TBL.flat, 1.0,
				Color(C_ACC if hand_zone == Z_SELL else C_TXT, 0.55))
		draw_item_chip(hand_m, PANEL.r, owned[hand_i], 0.0, 0.0, 0.0, 12)
		return
	if hand_i < 0 or hand_i >= drop.size():
		return
	var it: Dictionary = drop[hand_i]
	# 자리 링. h ≡ 0 이라 몸통 중심이 곧 지면점이고, 링과 몸통이 안 갈린다.
	# 팔려나간 자리의 코스터 자국과 같은 함수·같은 어법 — "링 = 자리".
	_e_ring_w(Vector2(it.u, _p2g(it.w)), it.r + 3.0, (it.r + 3.0) * TBL.flat, 1.0,
			Color(C_ACC if hand_zone >= 0 else C_TXT, 0.55))
	_obj_shadow(hand_i)
	_obj_draw(hand_i, 0.0)


func _scuff_draw(it: Dictionary) -> void:
	var col: Color = C_TABLE.darkened(0.22)
	for s in it.scuff:
		var a: float = clampf(1.0 - s.t / 0.42, 0.0, 1.0) * 0.5
		if a > 0.01:
			draw_colored_polygon(_e_pts(s.p, it.r * 0.5, it.r * 0.5 * TBL.flat, 10),
					Color(col, a))


# 팔린 물건의 비행. _goods_draw 안에 두면 먼 덮개(y[18,80])와 앞치마(y[250,360])가
# 덮어 두 다리 중 1.5개가 안 보인다 — 드래그 구매의 첫 다리는 통째로, 랙으로
# 가는 두 번째 다리는 0.19초가 가려진다. 그래서 판·버튼 다음에 따로 그린다.
func _fly_draw() -> void:
	for i in mini(drop.size(), stock.size()):
		if drop[i].gone or drop[i].sold <= 0.0:
			continue
		_obj_draw(i, 0.0)


func _drop_arrive(i: int) -> void:
	# 도착에서 튄다. 이륙에서 튀면 칩이 도착하기 0.46초 전에 랙이 먼저 튄다 —
	# 지금 있는 연출의 유일한 거짓말이었다.
	var it: Dictionary = drop[i]
	match stock[i].type:
		"item":
			_panel_fire(it.slot)
		"mod":
			pop(it.to, "보드 개조", C_CHIP.lightened(0.25), 13, 0.9)
		_:
			pop(it.to, "탄창 교체", C_GREEN.lightened(0.3), 13, 0.9)

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
var tip_spot := -1              # 호버 중인 매대 자리 (테이블 구획용)
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
	tip_spot = -1


# 지금 커서 아래에 무엇이 있는가. 없으면 빈 사전.
func _tip_hit(m: Vector2) -> Dictionary:
	match state:
		S.SHOP:
			if hand_st == H.CARRY:
				return {}                 # 드는 동안 툴팁은 끈다
			# 날아다니는 동안은 매물 툴팁을 안 띄운다 — 판이 미끄러져 못 읽는다.
			if not _drop_busy():
				var hi := _shop_hit(m)
				if hi >= 0:
					return {"k": "stock", "i": hi}
			for i in GameData.max_items():
				if _slot_rect(i).has_point(m):
					return {"k": "rack", "i": i}
		S.STAGE:
			for i in stage_pick.size():
				if _stage_rect(i).has_point(m):
					return {"k": "stage", "i": i}
			for i in GameData.max_items():
				if _slot_rect(i).has_point(m):
					return {"k": "rack", "i": i}
		S.COLLECT:
			var kk: String = ["citem", "cmod", "cdart", "ccons", "cmodf"][collect_tab]
			for i in _col_count():
				if _col_cell(i).has_point(m):
					return {"k": kk, "i": collect_page * COL_PAGE + i}
		S.PICK, S.AIM_V, S.AIM_H:
			# 조준 중에도 갈아탈 수 있으므로 그때도 벽을 짚어 준다
			for i in remaining.size():
				if _mag_rect(i).has_point(m):
					return {"k": "mag", "i": i}
			# 점수 카드가 떠 있으면 랙 툴팁이 카드를 정면으로 덮는다.
			# 위는 상단바라 앵커를 뒤집어서 못 피한다 — 그동안 대상에서 뺀다.
			if card_p <= 0.004:
				for i in GameData.max_items():
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
				_tip_add("최대 %d개" % GameData.max_items(), 9, C_DIM.darkened(0.2))
				return
			var it: Dictionary = owned[i]
			tip_title = it.n
			tip_chip = it
			_tip_add(GameData.cond_text(it.c), 10, C_DIM)
			_tip_add(GameData.eff_line(it), 11,
					C_CHIP.lightened(0.35) if it.k == "chip" else C_MULT.lightened(0.3))
			if it.get("g", "") != "":
				_tip_add(GameData.gold_text(it.g, it.gv), 9, C_GOLD)
			if i == sealed:
				_tip_add("이번 판 봉인 — 발동하지 않는다", 9, C_MULT.lightened(0.25))
			if _can_sell():
				_tip_add("판매가", 10, C_GOLD, "", "", str(GameData.sell_value(it)))
				_tip_add("왼쪽 창구를 눌러 판다" if i == sell_sel else "누르면 고른다",
						9, C_DIM.darkened(0.2))
		"stock":
			var s: Dictionary = stock[i]
			tip_mark = Rect2()      # 칩 랙과 같은 진영 — 사각 테두리 안 두른다
			tip_spot = i
			tip_title = s.d.n
			if s.type == "item":
				tip_chip = s.d
				_tip_add(GameData.cond_text(s.d.c), 10, C_DIM)
				_tip_add(GameData.eff_line(s.d), 11,
						C_CHIP.lightened(0.35) if s.d.k == "chip" else C_MULT.lightened(0.3))
				if s.d.get("g", "") != "":
					_tip_add(GameData.gold_text(s.d.g, s.d.gv), 9, C_GOLD)
			elif s.type == "cons":
				_tip_add(s.d.d, 10, C_DIM)
				_tip_add("한 번 쓰고 사라진다 — 사면 왼쪽 위 칸에 들어간다",
						9, C_DIM.darkened(0.2))
			else:
				_tip_add(s.d.d, 10, C_DIM)
				_tip_add("보드를 바꾼다 — 런이 끝날 때까지 남는다" if s.type == "mod"
						else "탄창의 표준 다트 1개와 바꾼다", 9, C_DIM.darkened(0.2))
			# 못 사는 이유를 누르기 전에 알려준다. _deny() 는 원인을 한 문장으로 뭉갠다.
			var blk := _buy_block(i)
			if blk != "":
				_tip_add(blk, 9,
						C_DIM.darkened(0.3) if s.sold else C_RED.lightened(0.2))
		"stage":
			var sp: Dictionary = stage_pick[i]
			tip_mark = _stage_rect(i)
			tip_title = sp.d.n
			_tip_add(sp.d.d, 11, C_MULT.lightened(0.25))
			_tip_add("목표 %d" % sp.target, 10, C_DIM)
		"citem":
			var it: Dictionary = GameData.items()[i]
			tip_mark = _col_cell(i % COL_PAGE)
			tip_title = it.n
			tip_chip = it
			_tip_add(GameData.cond_text(it.c), 10, C_DIM)
			_tip_add(GameData.eff_line(it), 11,
					C_CHIP.lightened(0.35) if it.k == "chip" else C_MULT.lightened(0.3))
			if it.get("g", "") != "":
				_tip_add(GameData.gold_text(it.g, it.gv), 9, C_GOLD)
			_tip_add("%s · %d골드" % [GameData.rarity_name(it.rarity), it.cost],
					9, C_DIM.darkened(0.2))
		"cmod":
			var md: Dictionary = GameData.mods()[i]
			tip_mark = _col_cell(i % COL_PAGE)
			tip_title = md.n
			_tip_add(md.d, 10, C_DIM)
			_tip_add("보드 개조 · %d골드" % md.cost, 9, C_DIM.darkened(0.2))
		"cdart":
			var dt: Dictionary = GameData.darts()[i]
			tip_mark = _col_cell(i % COL_PAGE)
			tip_title = dt.n
			_tip_add(dt.d, 10, C_DIM)
			_tip_add("게이지 ×%.2f" % dt.gauge, 9, C_DIM.darkened(0.2))
			if int(dt.get("mult", 0)) != 0:
				_tip_add("배수 %+d" % int(dt.mult), 9, C_MULT.lightened(0.25))
		"ccons":
			tip_mark = _col_cell(i % COL_PAGE)
			var cd: Dictionary = GameData.consumables()[i]
			tip_title = cd.n
			_tip_add(cd.d, 10, C_DIM)
			_tip_add("소비 아이템 · 한 번 쓰고 사라진다", 9, C_DIM.darkened(0.2))
		"cmodf":
			tip_mark = _col_cell(i % COL_PAGE)
			var mo: Dictionary = GameData.modifiers()[i]
			tip_title = mo.n
			_tip_add(mo.d, 10, C_DIM)
			_tip_add("라운드 제약 — 셋 중 하나를 반드시 고른다", 9,
					C_DIM.darkened(0.2))
		"mag":
			var dd: Dictionary = remaining[i]
			tip_mark = _mag_rect(i)
			tip_title = dd.n
			_tip_add(dd.d, 10, C_DIM)
			_tip_add("게이지 ×%.2f" % dd.gauge, 9, C_DIM.darkened(0.2))
			if int(dd.get("mult", 0)) != 0:
				_tip_add("배수 %+d" % int(dd.mult), 9, C_MULT.lightened(0.25))
			if dd.get("fix1", false):
				_tip_add("배수를 1로 고정", 9, C_MULT.lightened(0.25))


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
	elif tip_spot >= 0 and tip_spot < drop.size():
		t = _obj_box(tip_spot)
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


func _btn(r: Rect2, label: String, sub: String, on: bool,
		sub_col: Color = C_GOLD) -> void:
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
	# 상점과 같은 테이블이다. 매물이 있던 자리에 제약 카드가 놓이고,
	# 창구는 좌우 다 셔터가 내려가 있다 — 그 화면에서는 아무것도 안 판다.
	_felt_draw()
	# 런 바가 들고 있던 것과 카드에서 뺀 것이 여기서 만난다.
	# 딜러 라인(y119) 바로 밑 — 카지노가 펠트에 테이블 리밋을 인쇄하는 자리다.
	# target_of(round_no) 는 _open_stage 가 base 를 만든 그 식이다(출처 하나).
	# 카드보다 **먼저** 그린다. 미끄러져 오는 카드가 글자를 덮어야 순서가 맞다.
	draw_string(font, Vector2(0.0, 131.0),
			"R%d / %d   ·   목표 %d" % [round_no, GameData.rounds_n(),
					GameData.target_of(round_no)],
			HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 10,
			Color(C_TABLE.lightened(0.34), 0.75))
	for i in stage_pick.size():
		_stage_card(i)
	_cover_draw()
	_apron_mods()


# 앞치마 = 산 개조를 거는 선반. 상점에서 리롤·다음 버튼이 서는 띠와
# 같은 줄(중심 y 272 = 250+42/2 −(-1))을 쓴다 — 두 화면이 같은 틀이라는
# 말이 여기서도 지켜진다.
# 개조(mods.csv)는 _icon_mod, 제약(modifiers.csv)은 _icon_modifier 다.
# 캐비닛과 획으로 형태가 갈려 있어 아래(내가 산 것)와 위(내가 고를 것)가
# 안 섞인다. 이름 최장 실측 27px < 칸 52px.
func _apron_mods() -> void:
	var n: int = mods_own.size()
	if n == 0:
		# 빈 홈 하나. 랙이 빈 칸에 유령 홈을 그리는 어법 그대로이고 크기도
		# 실제 캐비닛(2r+6 = 32)과 같다. "개조 없음" 이라고 쓰는 것보다
		# R1 플레이어에게 더 많이 가르친다 — 비었다가 아니라 여기에 걸린다.
		var e := Rect2(VIEW.x * 0.5 - 16.0, 256.0, 32.0, 32.0)
		draw_rect(e, C_WOOD.darkened(0.55))
		draw_rect(e, C_WOOD.lightened(0.10), false, 1.0)
		return
	var step: float = minf(52.0, 560.0 / float(n))
	var x0: float = VIEW.x * 0.5 - (float(n) - 1.0) * step * 0.5
	for i in n:
		var mid: String = mods_own[i]
		var mx: float = x0 + float(i) * step
		_icon_mod(Vector2(mx, 272.0), 13.0, mid, 0.0)
		draw_string(font, Vector2(mx - step * 0.5, 300.0),
				GameData.mod_of(mid).get("n", ""),
				HORIZONTAL_ALIGNMENT_CENTER, step, 9, C_DIM.darkened(0.15))


func _stage_card(i: int) -> void:
	var md: Dictionary = stage_pick[i].d
	var r := _stage_rect(i)
	var sz: Vector2 = r.size
	var p := _stage_pose(i)
	var hot: bool = tip_a > 0.004 and tip_mark == r
	# 매대와 같은 숫자를 빌린다: DROP.lift_hov * tall = 3.70.
	# _stage_rect(히트·툴팁 앵커)는 들림을 안 따라간다 — 따라가면 커서 끝에
	# 걸린 것이 60Hz 로 떤다(_obj_box 의 불변식). 그리는 자리만 뜬다.
	var lz: float = (DROP.lift_hov * TBL.tall) if hot else 0.0
	p.y -= lz

	# 그림자는 매물과 같은 빛 벡터다. 들린 만큼 멀어진다.
	draw_rect(Rect2(p + TBL.light * 3.35 + Vector2(0.0, lz), sz),
			Color(0.0, 0.0, 0.0, 0.30))

	var body: Color = C_PANEL.lightened(0.18 if hot else 0.10)
	# 가까운 모서리의 두께 — 물건이지 인쇄가 아니라고 말하는 2px.
	draw_rect(Rect2(Vector2(p.x, p.y + sz.y), Vector2(sz.x, CARD.th)),
			body.darkened(0.45))
	draw_rect(Rect2(p, sz), body)
	draw_rect(Rect2(p, Vector2(sz.x, 2.0)), C_MULT.lightened(0.20 if hot else 0.0))
	draw_rect(Rect2(p + Vector2(0.0, sz.y - 1.0), Vector2(sz.x, 1.0)),
			Color(C_BG, 0.55))

	# 얼굴은 그림이 먼저다. 훑는 채널은 글자가 아니라 실루엣이다.
	# 아이콘이 축("링이 나빠진다")을 말하고 설명이 양("0.5배")을 말한다.
	# "목표" 는 안 쓴다 — _open_stage 가 base 하나를 n장에 복사하므로 셋이
	# 같은 값이고, 셋 중 하나를 고르는 면에서 판별 정보량이 0 비트다.
	# 등급 배수가 있던 시절의 잔재이고 00a4076 에서 죽었어야 했다.
	_icon_modifier(p + Vector2(sz.x * 0.5, CARD.icon), CARD.icon_r, md.id, 0.0)
	draw_string(font, p + Vector2(0.0, CARD.name), md.n,
			HORIZONTAL_ALIGNMENT_CENTER, sz.x, 13, C_MULT.lightened(0.32))
	draw_string(font, p + Vector2(6.0, CARD.desc), md.d,
			HORIZONTAL_ALIGNMENT_CENTER, sz.x - 12.0, 9, C_DIM)


func _draw_shop() -> void:
	_scrim()
	_table_draw()
	_btn(_reroll_rect(), "리롤", "무료" if reroll_cost == 0 else "", gold >= reroll_cost)
	if reroll_cost > 0:
		var rr := _reroll_rect()
		draw_gold(rr.position.x + rr.size.x * 0.5, rr.position.y + 35.0,
				str(reroll_cost), 10, C_GOLD if gold >= reroll_cost else C_DIM.darkened(0.3))
	_btn(_next_rect(), "다음 라운드 →", "", true)
	_hold_draw()
	_fly_draw()

	# 거절 사유. 창구가 좌우로 갔으므로 앞치마 가운데가 비었다 — 거기 쓴다.
	# 문구는 _buy_block 이 만든다.
	var msg := ""
	var ma := 0.0
	if pay_msg_t > 0.0:
		msg = pay_msg
		ma = minf(pay_msg_t * 3.0, 1.0)
	elif deny_flash > 0.0:
		msg = "골드가 부족하거나 슬롯이 꽉 찼다"
		ma = deny_flash
	elif hand_st == H.CARRY and hand_zone >= 0:
		if hand_src == 1:
			msg = "" if hand_zone == Z_SELL else "오른쪽은 사는 창구다"
		else:
			msg = "왼쪽은 파는 창구다" if hand_zone == Z_SELL else _buy_block(hand_i)
		ma = 0.85
	if msg != "":
		draw_string(font, Vector2(196.0, 306.0), msg, HORIZONTAL_ALIGNMENT_CENTER,
				248.0, 10, Color(C_MULT.lightened(0.3), ma))

	# 대기 중에는 아무 말도 안 한다. 조작을 시작한 뒤의 세 가지만 남긴다 —
	# 그것들은 설명이 아니라 지금 무슨 상태인가를 알리는 것이다.
	var tip := ""
	if _sweep_wipe():
		tip = "딜러가 판을 쓸어 담는다"
	elif _drop_busy():
		tip = "떨어지는 중  —  아무 데나 눌러 바로 세운다"
	elif hand_st == H.CARRY:
		tip = "왼쪽 끝에 밀면 판매  ·  오른쪽 끝에 밀면 구매  ·  펠트에 놓으면 그냥 옮긴다" \
				if hand_src == 0 else "왼쪽 끝에 밀면 판매"
	elif buy_sel >= 0:
		tip = "오른쪽 끝을 눌러 구매  ·  다시 누르면 취소"
	elif sell_sel >= 0:
		tip = "왼쪽 끝을 눌러 판매  ·  다시 누르면 취소"
	draw_string(font, Vector2(0, 316), tip,
			HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 10, C_DIM.darkened(0.2))

func _draw_over() -> void:
	_scrim()
	if won:
		draw_string(font, Vector2(0, 150), "완주!", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 34, C_ACC)
		draw_string(font, Vector2(0, 186), "%d개 라운드를 모두 넘겼다" % GameData.rounds_n(),
				HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 13, C_TXT)
	else:
		draw_string(font, Vector2(0, 150), "실패", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 34, C_MULT)
		draw_string(font, Vector2(0, 186), "라운드 %d — %d / %d" % [round_no, total, target],
				HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 13, C_TXT)
	draw_string(font, Vector2(0, 226), "클릭 → 제목으로", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 12, C_DIM)


# ══════════════════════════════════════════════════════════
#  제목 · 설정 · 컬렉션
# ──────────────────────────────────────────────────────────
#  셋 다 판을 배경으로 깔고 스크림을 덮는다 — OVER 와 같은 문법이다.
#  버튼은 _btn 하나로 통일한다. 전용 위젯이 없는 것이 이 게임의 어법이다.
# ══════════════════════════════════════════════════════════

var collect_tab := 0
var muted := false


func _menu_rect(i: int) -> Rect2:
	return Rect2(Vector2(226.0, 190.0 + float(i) * 40.0), Vector2(188.0, 32.0))


func _menu_back_rect() -> Rect2:
	return Rect2(Vector2(226.0, 322.0), Vector2(188.0, 30.0))


func _toggle_fullscreen() -> void:
	# 에디터에 내장된 실행에서는 창 모드를 못 바꾼다 — 내장 해제나
	# 내보낸 빌드에서만 실제로 커진다.
	var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if fs
			else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _draw_title() -> void:
	_scrim()
	draw_string(font, Vector2(0, 108), "하이톤", HORIZONTAL_ALIGNMENT_CENTER,
			VIEW.x, 40, C_TXT)
	draw_string(font, Vector2(0, 132), "HIGHTONE", HORIZONTAL_ALIGNMENT_CENTER,
			VIEW.x, 12, C_DIM)
	draw_string(font, Vector2(0, 158), "던지는 손과 읽는 머리가 곱해지는 다트 로그라이트",
			HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 10, C_DIM.darkened(0.15))
	var names := ["시작", "컬렉션", "설정", "종료"]
	var subs := ["스페이스", "", "", ""]
	for i in 4:
		_btn(_menu_rect(i), names[i], subs[i], true)
	if OS.is_debug_build():
		draw_string(font, Vector2(0, 352), "프로토타입 — 세이브 없음 · 한 판 완결",
				HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 9, C_DIM.darkened(0.35))


func _draw_settings() -> void:
	_scrim()
	draw_string(font, Vector2(0, 96), "설정", HORIZONTAL_ALIGNMENT_CENTER,
			VIEW.x, 24, C_TXT)
	var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_btn(_menu_rect(0), "전체화면  %s" % ("켬" if fs else "끔"), "F11", true)
	_btn(_menu_rect(1), "소리  %s" % ("끔" if muted else "켬"), "", true)
	_btn(_menu_rect(2), "뒤로", "ESC", true)
	draw_string(font, Vector2(0, 330), "설정은 저장되지 않는다 — 세이브가 없는 프로토타입이다",
			HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 9, C_DIM.darkened(0.3))


# ── 컬렉션 — 게임에 실린 전부를 편다. 해금이 없으므로 도감이 곧 전량이다 ──

const COL_PAGE := 28        # 7 × 4 — 한 쪽에 얹는 수
var collect_page := 0


func _col_total() -> int:
	match collect_tab:
		0: return GameData.items().size()
		1: return GameData.mods().size()
		2: return GameData.darts().size()
		3: return GameData.consumables().size()
	return GameData.modifiers().size()


# 이번 쪽에 실제로 놓인 수. 칸 인덱스는 쪽 안에서 0부터다.
func _col_count() -> int:
	return clampi(_col_total() - collect_page * COL_PAGE, 0, COL_PAGE)


func _col_pages() -> int:
	return maxi(1, int(ceil(float(_col_total()) / float(COL_PAGE))))


func _col_tab_rect(t: int) -> Rect2:
	return Rect2(Vector2(70.0 + float(t) * 102.0, 42.0), Vector2(96.0, 24.0))


func _col_arrow_rect(right: bool) -> Rect2:
	return Rect2(Vector2(560.0 if right else 44.0, 322.0), Vector2(36.0, 30.0))


func _col_cell(i: int) -> Rect2:
	var cols := 7
	var cw := 86.0
	var ch := 58.0
	var x0 := (VIEW.x - cw * float(cols)) * 0.5
	return Rect2(Vector2(x0 + float(i % cols) * cw, 72.0 + float(i / cols) * ch),
			Vector2(cw, ch))


func _draw_collect() -> void:
	_scrim()
	draw_string(font, Vector2(0, 30), "컬렉션", HORIZONTAL_ALIGNMENT_CENTER,
			VIEW.x, 18, C_TXT)
	var tabs := ["칩 %d" % GameData.items().size(),
			"개조 %d" % GameData.mods().size(),
			"다트 %d" % GameData.darts().size(),
			"소비 %d" % GameData.consumables().size(),
			"제약 %d" % GameData.modifiers().size()]
	for t in 5:
		_btn(_col_tab_rect(t), tabs[t], "", t == collect_tab)

	var base := collect_page * COL_PAGE
	for i in _col_count():
		var cell := _col_cell(i)
		var c := cell.get_center() + Vector2(0.0, -8.0)
		var gi := base + i
		var nm := ""
		match collect_tab:
			0:
				var it: Dictionary = GameData.items()[gi]
				draw_item_chip(c, 13.0, it, 0.0, 0.0, 0.0, 9)
				nm = it.n
			1:
				var md: Dictionary = GameData.mods()[gi]
				_icon_mod(c, 13.0, md.id, 0.0)
				nm = md.n
			2:
				var dt: Dictionary = GameData.darts()[gi]
				_icon_dart(c, 15.0, dt.id, 0.0, -0.62)
				nm = dt.n
			3:
				var cs: Array = GameData.consumables()
				var e := Vector2(11.0, 9.0)
				draw_rect(Rect2(c - e, e * 2.0), C_PANEL.lightened(0.22))
				draw_rect(Rect2(c - e, e * 2.0), C_WIRE.darkened(0.2), false, 1.0)
				draw_string(font, Vector2(c.x - e.x, c.y + 3.0),
						String(cs[gi].n).substr(0, 2),
						HORIZONTAL_ALIGNMENT_CENTER, e.x * 2.0, 8, C_TXT)
				nm = cs[gi].n
			4:
				var mo: Dictionary = GameData.modifiers()[gi]
				_icon_modifier(c, 11.0, mo.id, 0.0)
				nm = mo.n
		draw_string(font, Vector2(cell.position.x, cell.end.y - 8.0), nm,
				HORIZONTAL_ALIGNMENT_CENTER, cell.size.x, 8, C_DIM)

	if _col_pages() > 1:
		_btn(_col_arrow_rect(false), "◀", "", true)
		_btn(_col_arrow_rect(true), "▶", "", true)
		draw_string(font, Vector2(0, 318), "%d / %d" % [collect_page + 1, _col_pages()],
				HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 9, C_DIM)
	_btn(_menu_back_rect(), "뒤로", "ESC", true)


func _draw_hint() -> void:
	var hint := ""
	match state:
		S.PICK:
			hint = "던질 다트를 고르세요"
		S.AIM_V:
			hint = "다트판을 눌러 높이 결정"
		S.AIM_H:
			hint = "다트판을 눌러 좌우 결정"
		S.CONFIRM:
			hint = "조준 확인"
	if hint != "":
		draw_string(font, Vector2(0, 348), hint,
				HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 12, C_ACC)

	# 손 부채가 하단 좌측을 쓰므로 오른쪽으로 비킨다.
	# 조절 값 표시는 개발 빌드 전용이다 — 내보낸 exe 와 문서용 스크린샷에
	# 이 줄이 찍혀 나가는 것을 한 번 겪었다. 조절 키 자체는 릴리즈에도 산다.
	if OS.is_debug_build():
		draw_string(font, Vector2(VIEW.x - 262.0, 356), "[ ] 조준 %.2f    - = 정산 %.2f    ; ' 확인텀 %.2f"
				% [gauge_speed, beat, confirm_hold], HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
				C_DIM.darkened(0.25))
