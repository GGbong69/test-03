extends Node2D

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
# DEV — 정식 출시에서 지운다. 지우는 자리는 이 줄과 아래 "# DEV" 셋뿐이다.
const Dev = preload("res://scripts/dev.gd")

# ── 다트 로그라이트 프로토타입 ──────────────────────────────
# 흐름: 판 플레이 → 클리어 정산(보너스 3택) → 상점 → 다음 판
# 조작: 마우스 클릭 / 스페이스 (상하 → 좌우 → 확인 → 발사)
#       [ ] 조준 속도   - = 정산 속도   ; ' 확인 텀
# 밸런스 수치는 전부 scripts/data.gd 에 있다.

const VIEW := Vector2(640, 360)

#  글꼴 — 프로젝트에 실어 둔다.
#  OS 글꼴(SystemFont)은 웹에서 빈손으로 돌아와 한글이 전부 네모가 되고,
#  데스크톱에서도 기기에 뭐가 깔렸느냐에 따라 다른 글꼴이 잡힌다. 실어 두면
#  브라우저와 윈도가 같은 화면을 그린다.
#  Paperlogy 는 Thin(1) 부터 Black(9) 까지 아홉 단계다. 두께를 바꾸려면
#  fonts/ 에 그 파일을 넣고 이 줄만 고치면 된다 — 부르는 곳은 _ready 한 곳뿐이다.
# 픽셀 한글 글꼴. 11px 로 설계돼 있어서 11 · 22 · 33 에서 획이 딱 떨어진다 —
# 매끈한 TTF 를 8~9px 로 래스터화하면 획이 통째로 사라지는 자리가 그 반대다.
# 갈무리(OFL) — fonts/Galmuri-LICENSE.txt
const FONT_PATH := "res://fonts/Galmuri11.ttf"

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
#    PANEL · _panel_rect · _slot_rect        (동전 슬롯)
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
# 상점·스테이지는 테이블이 화면 전부를 쓴다. 런 바를 내리고
# 그 자리(16px)를 상인에게 준다 — 상인이 사람으로 읽히려면 세로가 필요하고,
# 목표·점수 진행은 던지는 중에만 쓸모가 있다. 다음 판 목표는
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
	return leg_no if (state == S.CLEAR or state == S.SHOP) else leg_no - 1


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
	# 옛 판매판 자리(x[80,154])는 사탕 칸(_cons_rect)이 쓴다.
	"cap":        Rect2(490.0, 20.0, 40.0, 44.0),
	# 사탕 칸은 자금판 오른쪽. 이름을 안 달았더니 플레이 피드백에서
	# "어디 있는지 몰랐다" 가 나왔다 — 칸 밑에 이름과 수를 적는다.
	"cons":       Rect2(84.0, 20.0, 68.0, 44.0),
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
		TITLE, SETTINGS, COLLECT, NEWRUN, LEG, RUNINFO }

# 칸 색 — 길이 20, 값은 colors.csv 의 id. _board_bake 가 굽고
# 손질·개칠이 고친다. 굽기 전(첫 프레임)에는 비어 있을 수 있으므로
# 읽는 쪽은 반드시 _sec_col 을 지난다.
var sec_col := []


func _sec_col(i: int) -> int:
	if i < 0 or i >= sec_col.size():
		return i % 2 if i >= 0 else -1
	return int(sec_col[i])


# ── 보드 기하 (보드 확장로 변한다) ──────────────────────────────
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

# 판 동안 실제로 쓰이는 값 (영구 보드 확장 + 이번 판 제약)
var rt_dbl_out := 1.00
var rt_dbl_in := 0.90
var rt_trp_in := 0.56
var rt_trp_out := 0.66
var rt_trp2_in := 0.0
var rt_trp2_out := 0.0
var rt_bull_o := 0.14
var rt_bull_i := 0.06
var dead_idx := -1              # "금지 구역"이 죽이는 칸. -1 이면 안 걸렸다
# ── 사진 선반 ────────────────────────────────────────────
#  상점 왼쪽 벽에 걸린다. **테이블(stock)에 안 넣는다** — 테이블은 상인이
#  쓸어 다시 던지는 판이고 사진은 그 판에 안 오른다. 리롤해도 안 씻기는
#  것이 코드 0줄로 성립하는 이유가 그것이다(_roll_stock 은 stock 만 지운다).
#  한 라운드에 하나. 사면 사라지고 그 라운드에는 다시 안 뜬다.
var aim_mode := "std"           # 이 런의 조준 방식. 다트통이 정한다
var score_mode := "std"         # 이 런의 점수 계산 방식. 다트통이 정한다
var aim_r := 0.0                # 원·선 조준이 잠근 반지름
var aim_a := 0.0                # 빗각 조준이 잠근 첫 축의 값
var aim_ax := 0.0               # 빗각 조준의 축 각도. 다트마다 새로 뽑는다
var pull_at := Vector2(-1, -1)  # 당김이 다트를 쥔 자리. x < 0 이면 안 쥐었다
var pull_t := 0.0               # 쥔 뒤 흐른 시간
var pull_log := []              # 최근 손자리 [{p,t}] — 놓는 순간의 속도를 잰다
var drift_o := Vector2.ZERO     # 흔들림 — 커서에서 조준점까지
var drift_to := Vector2.ZERO    # 지금 달려가는 자리
var drift_t := 0.0              # 다음 자리를 뽑기까지 남은 시간
var kick_o := Vector2.ZERO      # 반동으로 밀린 양
var burst_left := 0             # 남은 작은 다트 수
var kick_pellet := false        # 지금 정산하는 것이 연발의 한 발인가
var burst_n := 0                # 이번 연발의 발 수. 다 팔 때까지 안 준다
var settle_n := 0               # 이번 정산의 걸음 수. 걸음마다 안 준다
var burst_t := 0.0              # 다음 발까지 남은 시간
var burst_hits := []            # 꽂힌 자리 — 정산이 하나씩 판다
var mouse_at := Vector2(320, 180)   # 마지막 마우스 자리(놓기·당김이 읽는다)
var mouse_down := false         # 왼쪽 단추를 쥐고 있는가. 당김이 뗌을 여기서 안다
# 조준의 무작위는 **제 난수통**을 쓴다. 전역 난수를 태우면 다트를 집을
# 때마다 줄이 밀려 상점·성장 뽑기가 통째로 달라진다.
var aim_rng := RandomNumberGenerator.new()
var shelf := {}                 # 이 상점에 걸린 사진. 비면 없다
var run_from := S.SHOP           # 런 정보를 열던 자리. 닫으면 그리로 돌아간다
var shelf_round := 0             # 그 사진을 굴린 라운드. 라운드가 바뀔 때만 다시 굴린다
var dead_col := -1              # 값을 죽이는 칸 색 번호. -1 이면 안 걸렸다
var dead_ring := 0              # 무효가 되는 배수(2 더블 · 3 트리플). 0 이면 없다
var odd_mul := 1.0              # 홀수 칸 값 배수
var spin_cur := 0               # 판이 지금 몇 칸 돌아가 있는가. 되돌릴 때 쓴다

# ── 스테이지 선택 ─────────────────────────────────────────
var stage_pick := []            # 이번에 깔린 제약 카드들
var active_mods := []           # 이번 판에 걸린 제약 (지금은 언제나 한 장)
var sealed := -1                # "둔화"로 봉인된 아이템 인덱스

# ── 탄창 ──────────────────────────────────────────────────
var magazine := []              # 영구 구성 (상점에서 바꾼다)
var remaining := []             # 이번 판에 남은 다트
var cur_dart := {}              # 지금 던지는 다트

# ── 진행 상태 ─────────────────────────────────────────────
var state: int = S.AIM_V
var leg_no := 1
var target := 0
var total := 0
var shown := 0.0
var darts_left := 0
var gold := 0
var owned := []
var won := false

var last_sector := -1
var last_miss := false          # 직전 투척이 빗나갔는가 — 조건 missp 가 읽는다
# ── 조커 이식이 들여온 판 추적 ──
# 패턴 조건("같은 숫자 2회 이후" 류)은 명중 이력에서 나온다. 판마다 비운다.
var sec_cnt := {}               # 숫자 → 이번 판 명중 수
var zone_cnt := {}              # 영역 종류(single/double/triple/bull) → 명중 수
var pat := {}                   # 완성된 패턴 깃발. "이후" 조건이 읽는다
# 마지막 발의 판정 문맥과 그 일련번호. 조건 프로브가 게임과 **같은** 문맥을
# 읽는 창구다 — 프로브가 제 문맥을 지으면 ctx 에 열이 하나 빠져도 못 잡는다.
# 실제로 색 조건 일곱 장이 그렇게 죽어 있었고 측정기도 같이 속았다.
var last_ctx := {}
var land_n := 0
var seen_risk := false          # risk1 용 — 이번 판에 risk 명중이 있었나
var low_hit := 0                # 이번 판 최저 명중 숫자 (0 = 아직 없음)
var leg_darts := 6            # 이번 판 시작 다트 수 (few·missing 이 읽는다)
# 제약·리그·뱃지·사진·동전이 손대기 **전**의 다트 수. 「기본에서 줄어든
# 다트 1개당」이 읽는 그 기본이다. 다트통이 이 수를 바꾸므로(여벌 +1 · 넓은 동전 슬롯 -1)
# 6 을 박아 두면 안 된다 — 넓은 동전 슬롯은 아무것도 안 잃고 한 발 줄어든 것으로
# 읽히고, 여벌은 한 발을 잃고도 안 줄어든 것으로 읽힌다.
var leg_base := 6
var throw6 := 0                 # sixth 용 던진 수 카운터 (런 단위 · 발동 시 리셋)
var zone_hist := {}             # 런 단위 영역 종류 누적 명중 (zonehist 배율)
var streak := 0
var dart_index := 0
var leg_miss := false
var leg_trp := false          # 이번 판에 트리플이 나왔는가 ("손맛")         # 이번 판에 한 번이라도 빗나갔는가 (골드 동전 "새 자리" 판정)

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
var fly_rot := 0.0            # 나는 동안 쓰는 흔들림. 꽂힌 뒤에도 같은 값이다
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
		# 소크는 사람의 저장에 손대지 않는다. 한 번 돌 때마다 런·다트·
		# 골드가 실제 통계에 쌓이고, 해금 조건이 바로 그 통계를 읽는다 —
		# 회귀를 돌릴수록 해금이 저절로 열리는 저장이 된다(runs 가 89 에서
		# 90 이 되는 것을 보고 알았다). 프로브가 Save.path 를 옮기는 것과
		# 같은 이유이고, 오토플레이는 그 규약이 빠져 있던 유일한 자리다.
		Save.path = "user://_autoplay.cfg"
		# 검증 실행에서만 전 구간을 빠르게 통과시킨다 (실제 기본값은 위 선언부)
		gauge_speed = 2.2
		beat = 0.10
		confirm_hold = 0.05

	font = load(FONT_PATH)

	_bus_setup()      # 소리 자리를 세우기 전에 버스가 있어야 한다

	var p := AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 44100.0
	gen.buffer_length = 0.08
	p.stream = gen
	#  웹의 기본 재생 방식은 Sample 이다 — 스트림을 미리 통째로 굽는 방식이라
	#  매 프레임 채워 넣는 AudioStreamGenerator 를 못 받는다. 브라우저 콘솔에
	#  "cannot be sampled" 한 줄만 뜨고 소리가 통째로 안 난다.
	#  프로젝트 설정의 default_playback_type.web 은 안 먹었다(4.7.2 에서 확인).
	#  노드에 직접 박아야 듣는다. 데스크톱에선 어차피 같은 값이라 무해하다.
	p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	p.bus = "SFX"
	add_child(p)
	p.play()
	pb = p.get_stream_playback()

	# 파일 소리를 낼 자리 넷. 합성음과 같은 버스에 서므로 음량 조절이
	# 한 곳에서 둘 다 듣는다(_apply_vol 은 버스를 만진다).
	for i in 4:
		var sp := AudioStreamPlayer.new()
		sp.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		sp.bus = "SFX"
		add_child(sp)
		sfx_pool.append(sp)

	# 음악 — 크로스페이드를 하려면 둘이 동시에 울려야 하므로 자리가 둘이다.
	# 같은 버스(0)에 서므로 _apply_vol 이 효과음과 함께 한 번에 줄인다.
	for i in 2:
		var mp := AudioStreamPlayer.new()
		mp.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		mp.volume_db = -80.0
		mp.bus = "Music"
		add_child(mp)
		mus_pl.append(mp)

	# 저장은 소리 장치를 세운 **뒤**에 읽는다 — _apply_vol 이 버스를 만진다.
	_load_settings()

	if _autoplay:
		_new_run()
	else:
		# 제목 화면. 판을 배경으로 깔아야 하므로 기본 판만 먼저 굽는다.
		_board_bake()
		state = S.TITLE


# ══════════════════════════════════════════════════════════
#  런 / 판 진행
# ══════════════════════════════════════════════════════════

func _new_run() -> void:
	Save.bump("runs")
	mods_own.clear()
	_board_bake()
	leg_no = 1
	# 시작 조건은 다트통이 쥔다 — 표가 비면 튜닝 값이 그대로 남는다.
	var pk := GameData.pack_row()
	gold = GameData.start_gold() + int(pk.get("gold_add", 0))
	magazine.clear()
	var dart_id := String(pk.get("dart_id", "std"))
	var d0: Dictionary = GameData.darts()[0]
	for dd in GameData.darts():
		if String(dd.id) == dart_id:
			d0 = dd
	var nd: int = maxi(1, GameData.tune_i("darts_base") + int(pk.get("darts_add", 0)))
	for i in nd:
		magazine.append(d0)
	owned.clear()
	cons.clear()
	track_lv.clear()
	track_hits.clear()          # 트랙 레벨과 같은 런 스코프다
	throw6 = 0
	zone_hist.clear()
	won = false
	leg_tags.clear()
	leg_tags_round = 0
	leg_skipped.clear()
	GameData.fixture_clear()     # 사진은 런 스코프다. 지우는 자리는 여기 하나
	# **지운 뒤에** 쥐여 준다. 반대였다 — 사진을 주는 다트통이 지금까지
	# 하나도 없어서 아무도 안 밟은 자리였고, 선물 다트통을 만들자마자
	# 드러났다. 다른 세 갈래(보드 확장·사탕·동전)는 각자의 clear 가
	# 이 줄보다 위에 있어 안 걸렸다.
	_pack_grants()
	spin_cur = 0
	dead_col = -1
	dead_ring = 0
	odd_mul = 1.0
	pending_tags.clear()
	_open_leg()


func _start_leg() -> void:
	# 테이블을 빼고 판을 세운다. **데이터보다 먼저** 부른다 — 이 아래가
	# 판의 링 폭(rt_*)을 다시 잡으므로, 연출을 나중에 열면 올라오는 동안은
	# 지난 판의 모양이었다가 다 선 순간 툭 바뀐다.
	_swap_begin(true)
	# 영구 보드 확장값에서 출발해 이번 판 제약을 얹는다
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
	# 이번 판의 기본 다트 수는 rounds.csv 의 darts 열이 정한다.
	# tuning.csv 비고가 오래전부터 그렇게 적혀 있었는데 코드가 안 읽고
	# 있었다 — 표가 거짓말을 하던 자리다. 탄창보다 많으면 순환해서 채운다.
	#
	# **다트통 몫을 같이 더한다.** 다트통의 darts_add 는 _new_run 이 탄창 크기에만
	# 넣어 두는데, rounds 의 수로 곧장 자르면 그 몫이 통째로 없어졌다 —
	# 여벌 다트통이 탄창 일곱 자루를 쥐고도 여섯 발만 던지고 있었고, 넓은 동전 슬롯은
	# 다섯 자루를 쥐고도 여섯 발을 던졌다(둘 다 다트통 설명과 반대다).
	# 아래 dadd 사슬(제약·리그·뱃지·사진·동전)과 달리 다트통만 탄창 쪽에
	# 살았던 것이 원인이라, 다트통도 같은 자리에서 센다.
	var want := (GameData.darts_of(leg_no)
			+ int(GameData.pack_v("darts_add", 0.0)))
	while remaining.size() > want and remaining.size() > 1:
		remaining.pop_back()
	while remaining.size() < want and not magazine.is_empty():
		remaining.append(magazine[remaining.size() % magazine.size()])
	# 여기까지가 "기본" 이다 — 판과 다트통이 정한 수. 아래 dadd 사슬이 그것을 깎는다.
	leg_base = remaining.size()
	var dadd := int(mod_v("darts_add", 0.0))
	dadd += int(GameData.league_v("darts_add", 0.0))
	dadd += _spend_tags("dart")          # 뱃지 — 다음 판 한 번만 산다
	dadd += GameData.fixture_i("darts_add", 0)   # 사진 — 런 내내 산다
	# 순서: 제약 → 리그 → 뱃지 → 사진 → 동전. 전부 더하기라 지금은 수가
	# 같지만, 이 줄들 중 하나라도 곱이 되면 순서가 값을 바꾼다. 그때 고칠
	# 자리가 여기 하나다.
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
	leg_darts = remaining.size()
	grip_t = 0.0
	# 칸은 시작 때 한 번 정하고 끝까지 안 바꾼다. 자루가 빠질 때마다 다시
	# 가운데 맞추면 남은 것들이 미끄러져 꽂혀 있는 것으로 안 보인다.
	grip_slot.clear()
	for gi in remaining.size():
		grip_slot.append(gi)
	grip_n = remaining.size()
	grip_pick = -1
	# 제약 둔화와 리그이 같은 축을 민다 — 보라 리그부터는 매 판 상시다.
	var seal := int(mod_v("seal_items", 0.0)) \
			+ int(GameData.league_v("seal_items", 0.0))
	sealed = randi() % owned.size() if seal > 0 and not owned.is_empty() else -1
	dead_idx = int(mod_v("sector_kill", -1.0))
	# 변형을 판 시작에 한 번 읽는다. 코드에 갈래가 없는 이름이면
	# 여기서 한 번 울린다 — 매 프레임 울리면 로그가 못 쓰게 된다.
	#
	# 조준은 **든 동전**가 쥔다. 다트통이 직접 들고 있으면 그 방식을 런
	# 도중에 얻거나 잃을 수 없다 — 동전로 오면 사고 팔고 봉인되는
	# 것들과 같은 규칙 아래 놓이고, 그 자체가 판단거리가 된다.
	# 계산 방식은 다트통이 그대로 쥔다. 그것은 이 런이 어떤 판인가에 대한
	# 약속이라 도중에 바뀌면 안 된다.
	aim_mode = _aim_from_items()
	score_mode = GameData.score_mode()
	if not GameData.AIM_MODES.has(aim_mode):
		push_error("조준: 모르는 방식 '%s' — AIM_MODES 에 없다" % aim_mode)
		aim_mode = "std"
	if not GameData.SCORE_MODES.has(score_mode):
		push_error("점수: 모르는 방식 '%s' — SCORE_MODES 에 없다" % score_mode)
		score_mode = "std"
	dead_col = int(mod_v("color_kill", -1.0))
	dead_ring = int(mod_v("ring_kill", 0.0))
	odd_mul = mod_v("odd_mul", 1.0)
	# 돌아간 각도를 지금 값으로 맞춘다. 차이만큼만 돌리므로 제약이 빠진
	# 판에서는 저절로 제자리로 돌아온다.
	_board_spin(int(mod_v("spin", 0.0)) - spin_cur)
	leg_miss = false
	leg_trp = false
	total = 0
	shown = 0.0
	dart_index = 0
	streak = 0
	last_sector = -1
	last_miss = false     # 직전 칸과 같은 규칙 — 판이 바뀌면 "직전" 이 없다
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
# 던지는 순간이다.
#
# **조준이 시작되면 다트를 못 바꾼다**(확정 규칙 조준중다트변경=False).
# 아래 state == S.PICK 가드가 그것이고, 갈아타는 클릭 자체는 _click 의
# AIM_V/AIM_H 갈래가 막는다. 여기 "조준 중에도 갈아탈 수 있다" 고 적혀
# 있었는데 규칙과 정반대였다 — 규칙이 바뀔 때 주석이 안 따라온 자리다.
func _pick_dart(i: int) -> void:
	if i < 0 or i >= remaining.size():
		return
	grip_pick = i
	cur_dart = remaining[i]
	darts_left = remaining.size() - 1     # 이번 자루를 뺀 나머지
	if state == S.PICK:
		state = S.AIM_V
	_aim_begin()
	_sfx("dart_pick")


# 던지는 순간 벽에서 실제로 빠진다.
func _grip_consume() -> void:
	if grip_pick < 0 or grip_pick >= remaining.size():
		return
	remaining.remove_at(grip_pick)
	grip_slot.remove_at(grip_pick)
	grip_pick = -1
	darts_left = remaining.size()


func _finish_leg() -> void:
	Save.peak("best_leg", leg_no)
	Save.peak("best_score", total)
	Save.peak("best_gold", gold)
	Save.flush()
	if total < target:
		# 목숨 아이템(조커 이식 110099) — 총점이 목표의 일정 비율 이상이면
		# 실패를 한 번 무르고 자신을 부순다. 판은 클리어로 친다.
		for i in owned.size():
			if i == sealed:
				continue          # 봉인은 발동을 막는다 — 목숨도 발동이다
			var sv: Dictionary = owned[i]
			if String(sv.get("k", "")) == "save" \
					and float(total) >= float(target) * float(sv.v) / 100.0:
				var at := _slot_rect(mini(i, GameData.max_items() - 1)).get_center()
				_seal_drop(i)
				owned.remove_at(i)
				_panel_reset()
				pop(at + Vector2(0.0, 24.0), "%s — 실패를 막았다" % sv.n,
						C_ACC, 11, 1.2)
				_sfx("save_life")
				# 마지막 판에서 목숨이 터져도 완주는 완주다. 여기서 곧장
				# 정산으로 가면 아래 완주 검사에 못 닿아, 상점이 0칸으로 열리고
				# 목표가 라운드 8 그대로인 유령 25판이 시작된다.
				if leg_no >= GameData.legs_n():
					state = S.OVER
					won = true
					_sfx("run_win")
					return
				_leg_end_wear()
				_settle_clear()
				return
		state = S.OVER
		won = false
		_pack_unlock_check()
		Save.flush()
		_sfx("run_lose")
		return

	if leg_no >= GameData.legs_n():
		_league_unlock_next()
		_pack_unlock_next()
		state = S.OVER
		won = true
		Save.bump("wins")
		_pack_unlock_check()
		Save.flush()
		_sfx("run_win")
		return

	_leg_end_wear()
	_settle_clear()


# 정산 — 실패 방지로 넘어온 판도 같은 길을 걷는다.
func _settle_clear() -> void:
	# 정산 내역
	# 잔탄 골드는 다트통이 덮을 수 있다. 이자를 끈 다트통이 그 자리를 여기서
	# 되돌려 받는다 — 저축이 값을 잃으면 버는 길이 하나 있어야 한다.
	var dart_gold: int = darts_left \
			* int(GameData.pack_v("dart_gold", float(GameData.gold_per_dart())))
	@warning_ignore("integer_division")  # 보유 5당 1, 내림이 규칙이다
	var interest: int = mini(gold / GameData.interest_per(), _interest_cap())
	# 이자를 끄는 다트통. 상한을 0 으로 만드는 대신 여기서 끊는다 —
	# 상한은 리그·사진도 미는 값이라, 거기 0 을 섞으면 "누가 껐나" 가
	# 안 읽힌다. 다트통이 끈 것은 다트통 자리에서 끈다.
	if GameData.pack_v("interest_off", 0.0) > 0.0:
		interest = 0
	# gold 를 더하기 전에 부른다 — "굳은살"과 이자가 같은 잔액을 보게 하려는 것이다.
	var item_rows := _gold_from_items()
	var item_gold := 0
	for r in item_rows:
		item_gold += r.v
	# 클리어 보상은 판마다 다르다 — 작은 3 · 큰 4 · 보스 5.
	# 발라트로와 같은 값이고, legs.csv 가 쥔다.
	var clear := GameData.reward_of(leg_no)
	# 초록 리그부터 작은 판이 골드를 안 준다. 곡선이 아니라 여유를 깎는 단이다.
	if GameData.leg_idx(leg_no) == 0:
		clear = int(GameData.league_v("reward_small", float(clear)))
	# 제약이 이 판의 보상을 깎는다. 리그 뒤에 온다 — 리그이 정한 값을
	# 제약이 다시 미는 순서라야 "이 판만" 이 성립한다.
	clear = int(floor(float(clear) * mod_v("reward_mul", 1.0)))
	clear_gold_detail = [
		{"n": GameData.leg_name(leg_no), "v": clear},
		{"n": "남은 다트 %d개" % darts_left, "v": dart_gold},
		{"n": "이자", "v": interest},
	]
	for r in item_rows:
		clear_gold_detail.append(r)
	gold += clear + dart_gold + interest + item_gold
	# 여태 판매분만 세고 있었다 — 클리어·잔탄·이자·아이템 골드가 통째로
	# 빠져서 통계의 번 돈이 실제의 일부였다. 해금 조건이 이 키를 읽기
	# 전에 고친다. 이미 쌓인 저장은 못 되살리므로 임계값을 그 위에서 잡는다.
	Save.bump("gold_earned", clear + dart_gold + interest + item_gold)

	state = S.CLEAR
	_sfx("leg_clear")


# 봉인은 자리가 아니라 동전에 걸린다. owned 에서 원소를 빼면 뒤 인덱스가
# 하나씩 당겨지므로 sealed 도 같이 민다 — 안 밀면 _gold_from_items 가
# 엉뚱한 동전의 골드를 지우고, 범위를 벗어나면 봉인이 통째로 증발한다.
# _rack_reorder 는 동전을 따라가는 같은 규약을 이미 지키고 있었다.
func _seal_drop(i: int) -> void:
	if sealed < 0:
		return
	if sealed == i:
		sealed = -1
	elif sealed > i:
		sealed -= 1


# 완주하면 다음 리그이 열린다. 표 순서가 곧 계단이라 지금 단의 다음 행이다.
# 기본 다트통은 완주로 열린다 — 표 순서대로 다음 하나. 리그 사다리와 같은 모양이다.
# 다트통이 쥐여 주는 것들. 네 갈래를 한자리에서 푼다 — 갈래마다 다른
# 자리에서 풀면 "이 다트통이 무엇을 주고 시작하나" 를 네 곳에서 읽어야 한다.
#
# 보드 확장은 판을 다시 굽는다(mods_own 이 판의 유일한 출처다). 사진은
# GameData 의 static 목록에 들어가고, 사탕와 동전은 칸에 담긴다.
# 칸이 모자라면 안 담는다 — 다트통이 제 칸보다 많이 주면 그건 표의 잘못이고
# 검증기가 잡을 자리다. 여기서 칸을 늘려 주면 그 잘못이 숨는다.
func _pack_grants() -> void:
	for id in GameData.pack_grants("grant_mod"):
		if not mods_own.has(String(id)):
			mods_own.append(String(id))
	if not mods_own.is_empty():
		_board_bake()
	for id in GameData.pack_grants("grant_fixture"):
		GameData.fixture_add(String(id))
	for id in GameData.pack_grants("grant_cons"):
		for c in GameData.consumables():
			if String(c.id) == String(id) and cons.size() < GameData.cons_slots():
				cons.append(c)
				break
	for id in GameData.pack_grants("grant_item"):
		for it in GameData.items():
			if String(it.id) != String(id) or owned.size() >= GameData.max_items():
				continue
			var gp: Dictionary = it.duplicate()
			gp.gs = 0
			gp.bought = 0
			owned.append(gp)
			break
	_panel_reset()


func _pack_unlock_next() -> void:
	var rows := GameData.packs_of("base")
	var cur := String(GameData.pack_row().get("id", ""))
	for i in rows.size():
		if String(rows[i].get("id", "")) != cur or i + 1 >= rows.size():
			continue
		var nxt: Dictionary = rows[i + 1]
		if Save.unlock("pack:" + String(nxt.get("id", ""))):
			pop(Vector2(VIEW.x * 0.5, 232.0),
					"%s 열렸다" % nxt.get("name", ""), C_GOLD, 13, 1.6)
		return


# 히든 다트통은 통계 하나가 문이다. 런이 끝날 때와 새 런 화면을 열 때 본다 —
# 조건이 채워진 순간이 아니라 런 경계에서 여는 것은 발라트로와 같다.
# 저장을 읽는 쪽이 여기라 data.gd 는 저장을 모른 채로 남는다(검증기가 순수해야 한다).
func _pack_unlock_check() -> void:
	for r in GameData.packs_of("hidden"):
		var id := String(r.get("id", ""))
		if Save.unlocked("pack:" + id):
			continue
		var st := String(r.get("unlock_stat", ""))
		if st == "":
			continue
		if Save.stat(st) < int(String(r.get("unlock_v", "0"))):
			continue
		if Save.unlock("pack:" + id):
			pop(Vector2(VIEW.x * 0.5, 232.0),
					"%s 열렸다" % r.get("name", ""), C_ACC, 13, 1.6)


func _league_unlock_next() -> void:
	var rows := GameData.leagues()
	var cur := String(GameData.league_row().get("id", ""))
	Save.unlock(GameData.win_key(cur))      # 이 다트통으로 이 단을 넘겼다
	for i in rows.size():
		if String(rows[i].get("id", "")) != cur or i + 1 >= rows.size():
			continue
		var nxt := String(rows[i + 1].get("id", ""))
		if Save.unlock(GameData.league_key(nxt)):
			pop(Vector2(VIEW.x * 0.5, 210.0),
					"%s 열렸다" % rows[i + 1].get("name", ""), C_GOLD, 13, 1.6)
		return


# 판 종료의 마모 — 감쇠(rdec)와 확률 파괴(boom). 조커 이식이 들여왔다.
# 정산보다 먼저 부른다: 이번 판 일한 값은 이미 점수로 냈고, 골드 정산은
# 남은 자만 받는 것이 "판 종료 시 파괴" 의 뜻에 맞다.
func _leg_end_wear() -> void:
	# 유지비 — 검정 리그. 골드가 없으면 0 에서 멈춘다(빚을 안 만든다).
	var rent := int(GameData.league_v("rent", 0.0))
	if rent > 0 and gold > 0:
		var pay: int = mini(rent, gold)
		gold -= pay
		pop(_slot_rect(0).get_center() + Vector2(0.0, -22.0),
				"유지비 −%d" % pay, C_MULT, 11, 1.0)
	var per := int(GameData.league_v("perish", 0.0))
	var i := owned.size() - 1
	while i >= 0:
		var it: Dictionary = owned[i]
		var dead := false
		# 삭음 — 주황 리그. 산 판을 기억해 두었다가 그만큼 지나면 부순다.
		if per > 0:
			var age := leg_no - int(it.get("bought", leg_no))
			if age >= per:
				dead = true
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
			_seal_drop(i)
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
			"clean": v = it.gv if not leg_miss else 0
			"blitz": v = it.gv if darts_left >= GameData.gold_blitz() else 0
			"broke": v = it.gv if gold <= GameData.gold_broke() else 0
			"leg": v = it.gv
		if v > 0:
			rows.append({"n": it.n, "v": v})
	return rows


# 무료 리롤 횟수 — 표 + 사진. 뱃지(무료 리롤)는 이 값이 아니라
# rerolls_used 를 음수로 밀어 좌변에 붙는다. 같은 축이 아니라 같은 비교의
# 반대편이라, 둘을 한 수로 합치면 안 된다.
func _free_rerolls() -> int:
	return GameData.free_rerolls() + GameData.fixture_i("free_rerolls", 0)


# 이자 상한 = 표 + 리그 + 사진. 정산(_settle_clear)과 자금판 미리보기가
# 같은 식을 읽어야 한다 — 갈려 있으면 화면에 적힌 수와 실제로 들어오는
# 골드가 다르고, 그건 플레이어가 못 고치는 종류의 거짓말이다.
func _interest_cap() -> int:
	return GameData.interest_max() + int(GameData.league_v("interest_add", 0.0)) 			+ GameData.fixture_i("interest_add", 0)


# 벽에 걸린 사진 한 장. 매물과 다른 어휘로 그린다 — 매물은 펠트 위에
# 놓인 둥근 물건이고 이것은 벽에 박힌 네모 판이다. 같은 어휘를 쓰면
# "이것도 쓸려 나가나" 를 플레이어가 물어야 한다.
func _reroll_price() -> int:
	if rerolls_used < _free_rerolls():
		return 0
	return GameData.reroll_base() + (rerolls_used - _free_rerolls()) * GameData.reroll_step()


func _open_shop() -> void:
	# 판이 끝났다. 상점에 동전 슬롯이 서므로 안 지우면 지난 판 "봉인" 뱃지가
	# 유령으로 남는다. _gold_from_items() 가 sealed 를 읽으므로
	# _finish_leg 안에서는 지우면 안 된다 — 여기가 유일하게 안전한 지점이다.
	sealed = -1
	sell_sel = -1
	buy_sel = -1
	_panel_reset()
	_sweep_reset()
	rerolls_used = -_spend_tags("reroll")   # 뱃지 — 무료 리롤을 앞당긴다
	reroll_cost = _reroll_price()
	# 사진은 라운드가 바뀔 때만 갈린다. 같은 라운드의 상점 셋이 같은 것을 본다 —
	# 발라트로가 바우처를 라운드마다 하나 거는 것과 같은 자리다. 안 사면
	# 다음 상점에도 그대로 걸려 있고, 라운드가 넘어가면 사라진다.
	var round := GameData.round_of(leg_no)
	if round != shelf_round:
		shelf_round = round
		shelf = GameData.fixture_roll(round)
	_roll_stock()
	state = S.SHOP
	_sfx("shop_open")


#  가중치 뽑기. 동전과 제약이 같은 저울을 쓴다 — 제약은 행에 w 를 들고 있고,
#  동전은 등급 표에서 가져온다. 균등 shuffle 이던 시절에는 14골드 희귀가
#  4골드 흔함과 같은 확률로 R2 테이블에 떴다.
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


#  테이블은 판 N 을 클리어한 뒤 N+1 을 위해 열린다. 그래서 폭도 해금도
#  다음 판 번호로 본다. 판 표는 판당 한 줄이라 옛 rounds.csv 처럼
#  "마지막 행을 비워 둔다" 는 규약이 없다 — 마지막 판이면 애초에 상점을 안 연다.
# 리그이 미는 값 — 주황부터 테이블이 비싸다. 올림이라 4골드가 5가 된다.
func _league_cost(c: int) -> int:
	var m := GameData.league_v("shop_cost_mul", 1.0)
	return c if m == 1.0 else maxi(1, int(ceil(float(c) * m)))


func _roll_stock() -> void:
	stock.clear()
	var nxt := leg_no + 1
	var tag_more := _spend_tags("shop")     # 뱃지 — 매물이 는다
	var tag_free := _spend_tags("free")     # 뱃지 — 몇 개가 공짜다
	# 상점 칸은 그 판 **뒤**의 상점 폭이다. 판 표를 읽으므로 같은 판
	# 안에서는 세 판이 같은 폭을 본다 — 판이 바뀌는 경계에서만 값이 갈린다.
	var w := GameData.shop_of(leg_no)

	# 후보를 먼저 거른다 — 이미 가진 동전만 뺀다. 등장 조건은 없앴고
	# 무엇이 뜨는지는 등급 가중치가 혼자 정한다(min_leg 는 전부 2 —
	# 첫 상점이 열리는 판이라 아무것도 안 막는다).
	var pool := []
	for it in GameData.items():
		if _has_item(it.id) or GameData.item_min_leg(it) > nxt:
			continue
		# 가중치 0 은 **테이블에 안 뜬다는 뜻**이다. 저울에만 맡기면 마지막
		# 원소로 떨어지는 폴백(_draw_weighted)에 걸려 아주 가끔 뜬다.
		# 전설이 그 자리라, 따로 얻는 길로만 오게 하려면 여기서 빼야 한다.
		if GameData.item_weight(it) <= 0.0:
			continue
		pool.append(it)

	var n := 0
	while n < int(w.items) + tag_more:
		var it := _draw_weighted(pool)
		if it.is_empty():
			break
		pool.erase(it)
		stock.append({"type": "item", "d": it, "cost": _league_cost(it.cost), "sold": false})
		n += 1

	# 판이 더는 못 받는 보드 확장과 이미 산 보드 확장을 여기서 뺀다.
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
		stock.append({"type": "mod", "d": m, "cost": _league_cost(m.cost), "sold": false})
		mn += 1
	# 보드 확장을 다 샀거나 판이 꽉 찼다. 예전 코드는 여기서 mods[i] 로 죽었다.
	# 자리는 정확히 4개여야 하므로(_table_draw 의 ax/ay 주석) 동전로 메운다.
	while mn < int(w.mods):
		var fill := _draw_weighted(pool)
		if fill.is_empty():
			break
		pool.erase(fill)
		stock.append({"type": "item", "d": fill, "cost": _league_cost(fill.cost), "sold": false})
		mn += 1

	var darts_pool := GameData.darts().slice(1)
	darts_pool.shuffle()
	for i in mini(int(w.darts), darts_pool.size()):
		var dd: Dictionary = darts_pool[i]
		stock.append({"type": "dart", "d": dd, "cost": _league_cost(dd.cost), "sold": false})

	# 사탕 — 상점 구성이 미정(기획 메모 990006)이라 임시 규칙로 낸다:
	# shop_cons 가 켜져 있으면 동전 자리 하나를 사탕으로 바꾼다.
	# 자리 수 4는 안 변한다 — _table_draw 의 ax/ay 전제가 사는 이유다.
	if GameData.tune_i("shop_cons") == 1:
		var cp := GameData.consumables()
		if not cp.is_empty():
			for k in stock.size():
				if stock[k].type == "item":
					var cd: Dictionary = cp[randi() % cp.size()]
					stock[k] = {"type": "cons", "d": cd, "cost": _league_cost(cd.cost),
							"sold": false}
					break

	# 사진 — 라운드마다 하나 걸린다(shelf_round 가 그것을 지킨다). 벽에
	# 걸린 패널이었는데 다른 매물과 같은 규약을 못 따랐다 — 툴팁도
	# 창구도 손도 안 닿았다. 테이블에 내려놓으면 그 넷이 공짜로 붙는다.
	# 리롤해도 같은 사진이 다시 온다. 사면 shelf 가 비어 안 온다.
	if not shelf.is_empty():
		stock.append({"type": "fix", "d": shelf, "cost": int(shelf.cost),
				"sold": false})

	# 뱃지 "외상" — 앞에서부터 몇 개를 0골드로 만든다. 안 팔린 것만 고른다.
	for k in stock.size():
		if tag_free <= 0:
			break
		if not stock[k].sold:
			stock[k].cost = 0
			tag_free -= 1

	# 상인이 판을 쓸고 다시 던진다. 리롤이 배치를 안 바꾸면 낙하가 배치를
	# 결정한다는 전제 자체가 거짓말이 된다.
	_drop_roll()


func _deny() -> void:
	deny_flash = 1.0
	shake = 4.0
	_sfx("deny")


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
		return "동전 판이 꽉 찼다 (%d/%d)" % [owned.size(), GameData.max_items()]
	if s.type == "dart" and _std_slot() < 0:
		return "바꿀 표준 다트가 없다"
	if s.type == "cons" and cons.size() >= GameData.cons_slots():
		return "사탕 칸이 꽉 찼다 (%d/%d)" % [cons.size(), GameData.cons_slots()]
	return ""


func _buy(i: int) -> void:
	if _buy_block(i) != "":
		_deny()
		return

	var s: Dictionary = stock[i]
	gold -= s.cost
	s.sold = true
	match String(s.type):
		"item": Save.bump("items_bought")
		"mod": Save.bump("mods_bought")
		"dart": Save.bump("darts_bought")
		"fix": Save.bump("fixtures_bought")
	match s.type:
		"item":
			# 사본이다. 성장 상태(gs)가 원본 카탈로그에 붙으면 다음 런까지
			# 살아남는다 — 컬렉션과 테이블이 같은 사전을 읽기 때문이다.
			var cp: Dictionary = s.d.duplicate()
			cp.gs = 0
			cp.bought = leg_no          # 삭음(주황 리그)이 읽는 나이다
			owned.append(cp)
		"mod":
			_apply_mod(s.d.id)
		"dart":
			magazine[_std_slot()] = s.d
		"cons":
			# 칸으로 들어간다. 상점 즉시 사용은 칸에서 바로 누르면 되므로
			# 별도 경로가 없다 — 확인 버튼을 만들지 않는 규칙과도 맞는다.
			cons.append(s.d)
		"fix":
			# 사면 사라지고 효과만 런 끝까지 남는다. 동전 슬롯에도 사탕
			# 칸에도 안 들어간다. shelf 를 비워 리롤에도 다시 안 온다.
			GameData.fixture_add(String(s.d.id))
			shelf = {}
			# 테이블 폭·무료 리롤이 이 순간 바뀔 수 있다. 이번 판은 이미
			# 굴린 뒤라 폭은 다음 리롤부터 넓어지고, 값은 지금 다시 매긴다.
			reroll_cost = _reroll_price()
			_panel_reset()
	_sfx("fixture_buy" if s.type == "fix" else "buy")


func _std_slot() -> int:
	for i in magazine.size():
		if magazine[i].id == "std":
			return i
	return -1


# ══════════════════════════════════════════════════════════
#  보드 확장
#
#  판은 상태가 아니라 mods_own 의 함수다. 살 때마다 GameData.BOARD_BASE 에서
#  MODS 표 순서대로 다시 굽는다 — 그래서 "먼저 산 보드 확장이 나중 보드 확장을 흔드는가"
#  라는 물음이 아예 성립하지 않는다. 순서 무관성은 증명이 아니라 구성이다.
#
#  바깥과 닿는 곳은 넷뿐이다.
#    _mod_room(id)   테이블에 낼 수 있는가   (_roll_stock · _buy_block · _tip_build)
#    _apply_mod(id)  산다                  (_buy)
#    _board_bake()   판을 다시 굽는다       (_new_run · _apply_mod)
#    sectors / bull_* / trp_* / trp2_* / dbl_*   (_start_leg 가 rt_* 로 복사)
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


# 이 보드 확장 목록이면 판이 어떻게 되는가. 사지 않고 물어볼 수 있어야
# 테이블 필터·거절 문구·실제 적용 셋이 같은 답을 쓴다.
func _board_of(ids: Array) -> Array:
	var b: Dictionary = GameData.BOARD_BASE.duplicate()
	var sec: Array = GameData.SECTORS_BASE.duplicate()
	for m in GameData.mods():      # 표 순서가 곧 적용 순서다
		if ids.has(m.id):
			_mod_step(b, sec, m)
	return [b, sec]


# 판이 성립하는가. 링 순서는 hit_info 의 if 사슬이 전제하는 그것이고,
# 판값 상한은 조합의 유일한 천장이다 — 보드 확장마다 따로 두지 않는다.
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


# 테이블에 낼 수 있는가. 산 기록 · 배타 짝 · 기하 · 판값 · "정말 바뀌는가" 를
# 여기 한 곳에서 묻는다. 무효 구매가 생길 자리 자체가 없어지는 것이
# 이 함수의 존재 이유다. 새 보드 확장을 만들면 여기만 통과시켜라.
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
	# 남겨 두는 것은 다음 사람이 보드 확장을 늘릴 때의 계약이다.
	return not _board_same(cur[0], cur[1], nx[0], nx[1])


func _apply_mod(id: String) -> void:
	if not _mod_room(id):
		return
	mods_own.append(id)
	_board_bake()


# 판을 n 칸 돌린다. 값과 색이 **같이** 돌아야 한다 — 색만 남으면 판이
# 뒤집힌 것이 아니라 색칠이 어긋난 것으로 읽힌다.
#
# 배열을 직접 돌리되 지금 각도(spin_cur)를 들고 있어서, 다음 판에서
# 차이만큼만 되돌린다. _board_bake 로 되굽는 방법은 못 쓴다 — 색은
# 일부러 되굽기에서 안 지워지기 때문이다(_board_bake 주석).
func _board_spin(n: int) -> void:
	var m: int = sectors.size()
	if m == 0:
		return
	var k: int = ((n % m) + m) % m
	spin_cur = ((spin_cur + k) % m + m) % m
	if k == 0:
		return
	sectors = sectors.slice(k) + sectors.slice(0, k)
	if sec_col.size() == m:
		sec_col = sec_col.slice(k) + sec_col.slice(0, k)


# 판을 굽는다. 보드 확장을 산 뒤와 런 초기화, 두 곳에서만 부른다.
func _board_bake() -> void:
	# 되굽기 전에 회전을 푼다. 굽기는 sectors 를 밑바닥에서 새로 만드는데
	# sec_col 은 일부러 안 지운다(아래 주석). 그대로 두면 보드 확장을 산 순간
	# 숫자만 제자리로 가고 색은 돌아간 채 남아 판이 어긋난다.
	_board_spin(-spin_cur)
	var r := _board_of(mods_own)
	var b: Dictionary = r[0]
	sectors = r[1]
	# 칸 색 — 굽는 자리가 여기 하나뿐이라 손질·개칠이 색을 바꿔도
	# 다시 구우면 그대로 산다. 길이가 어긋나면 통째로 다시 깐다.
	if sec_col.size() != sectors.size():
		sec_col = GameData.colors_base()
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
# 판을 갈아 끼우는 일만 상인에게 넘긴다.
func _reroll() -> void:
	if sweep_live:
		return                   # 쓸기는 중단도 재진입도 없다
	_hand_abort()
	if gold < reroll_cost:
		_deny()
		return
	gold -= reroll_cost
	Save.bump("rerolls")
	rerolls_used += 1
	reroll_cost = _reroll_price()
	if drop_fast:
		_roll_stock()            # 헤드리스는 팔을 안 기다린다. 새 판이 곧 결과다
	else:
		_sweep_begin()           # 끝에서 _sweep_deal 이 _roll_stock 을 부른다
	_sfx("reroll")


func _next_leg() -> void:
	_hand_abort()
	leg_no += 1
	_open_leg()


# ══════════════════════════════════════════════════════════
#  판 선택
# ══════════════════════════════════════════════════════════

func _open_leg() -> void:
	sealed = -1
	sell_sel = -1
	buy_sel = -1
	leg_t = 0.0
	# 라운드의 뱃지를 한꺼번에 굴린다. 미리 굴려 두어야 "무엇을 받고 무엇을
	# 버리는가" 를 보고 고를 수 있다 — 안 보이면 도박이지 선택이 아니다.
	# 라운드가 그대로면 다시 안 굴린다. 판을 넘길 때마다 뒤 판의 뱃지가
	# 바뀌면 아까 그것을 보고 세운 계획이 매번 무너진다.
	var bta := GameData.round_of(leg_no)
	if bta != leg_tags_round:
		leg_tags_round = bta
		leg_tags.clear()
		var bf := _round_first()
		for k in GameData.legs_per_round():
			var brn: int = bf + k
			if GameData.skippable(brn):
				leg_tags[brn] = GameData.tag_roll(bta)
	leg_tag = _leg_tag(leg_no)
	state = S.LEG
	_sfx("leg_open")


# 이 라운드의 첫 판 번호. 세 판을 늘어놓을 때 기준이 된다.
func _round_first() -> int:
	return leg_no - GameData.leg_idx(leg_no)


# 그 판을 건너뛰면 받을 뱃지. 없으면 빈 사전이다(보스 판).
func _leg_tag(rn: int) -> Dictionary:
	return leg_tags.get(rn, {})


func _leg_go() -> Rect2:
	return _next_rect()


# 건너뛰기는 **건너뛸 판 바로 아래**에 붙는다. 앞치마 왼쪽에 두었을 때는
# 그 버튼이 어느 판을 건너뛰는지가 화면에 안 적혀 있었다 — 판이 셋이고
# 버튼은 하나인데 둘이 멀리 떨어져 있으면 잇는 것은 플레이어의 추측이다.
# 건너뛰기 판 한 장. 지금 판이든 뒤 판이든 **같은 모양**이고 밝기만
# 다르다 — 다른 모양으로 그리면 "이건 뭐고 저건 뭔가" 를 한 번 더
# 배워야 한다. 셋을 나란히 놓고 비교하는 화면이라 특히 그렇다.
#
# _btn 을 안 쓴다. 그것은 46px 버튼용이라 부제를 y+35 에 놓는데
# 이 판은 32px 이고, 그 차이만큼 글자가 판 밖으로 나갔다.


# 자리와 글 간격은 여기 한 표에 모은다. 세 함수(_skip_rect · _skip_past ·
# _skip_plate)가 같은 표를 본다 — 갈라 두면 지나간 자리와 지금 자리의
# 글줄이 1px 씩 어긋난다.
#
# 예전에는 높이 28 에 베이스라인 12·23 이었다. 갈무리는 글자 칸이 곧 잉크
# 칸이라(오름 = 글자 크기, 한글은 내림을 안 쓴다) 그 배치의 실측은
#   머리띠 0..2 · 첫 줄 2..12 · 둘째 줄 14..23 · 아래 여백 5
# 였다. 머리띠가 첫 줄 윗획에 **닿고**, 두 줄 사이가 2px 뿐이라 셋이
# 한 덩어리로 뭉쳤다 — 줄 높이에 기대면 픽셀 글꼴은 언제나 이렇게 붙는다.
# 지금은 간격을 손으로 준다:
#   머리띠 0..2 · 3 · 10pt 5..15 · 4 · 9pt 19..28 · 4 = 32
#
# 세로 자리 — 판 카드 아래끝이 226 이고 그림자가 228 까지 온다. 232 에서
# 시작해 264 에서 끝나므로 펠트 near 모서리(268)에 4px 이 남는다. 레일을
# 밟으면 판이 테이블 밖으로 흘러내린 것으로 읽힌다.
const SKIP := {
	"h":   32.0,     # 판 높이
	"dy":   6.0,     # 판 카드 아래끝과의 사이
	"y1":  15.0,     # 첫 줄(10pt) 베이스라인
	"y2":  28.0,     # 둘째 줄(9pt) 베이스라인
	"y0":  21.0,     # 한 줄만 있을 때(9pt) — 머리띠 아래 칸의 가운데
	"ix":  14.0,     # 뱃지 그림 중심 x. 그림 반지름 6.5, 잉크 오른끝이 20.5
	# 글 왼쪽. 그림에서 7.5px 띄운다 — 그림은 글자가 아니라 그림이므로
	# 낱말 사이(4px)보다 넓게 벌려야 둘이 한 덩어리로 안 읽힌다.
	"tx":  28.0,
	"pad": 32.0,     # 글이 쓰는 폭 = 판 폭 - 이만큼 (왼쪽 tx + 오른쪽 4)
}


# 지나간 판의 자리. 고른 것이 무엇이었는지만 남긴다.
func _skip_past(r: Rect2, rn: int) -> void:
	var took: bool = bool(leg_skipped.get(rn, false))
	draw_rect(r, C_PANEL.darkened(0.52))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)),
			C_ACC.darkened(0.72) if took else C_WIRE.darkened(0.4))
	if not took:
		draw_string(font, r.position + Vector2(0.0, SKIP.y0), "던졌다",
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, C_DIM.darkened(0.42))
		return
	var t := _leg_tag(rn)
	_icon_tag(Vector2(r.position.x + SKIP.ix, r.get_center().y), 6.5,
			String(t.get("kind", "")), 0.34)
	var tx: float = r.position.x + SKIP.tx
	var tw: float = r.size.x - SKIP.pad
	draw_string(font, Vector2(tx, r.position.y + SKIP.y1), "건너뜀",
			HORIZONTAL_ALIGNMENT_LEFT, tw, 10, C_DIM.darkened(0.32))
	draw_string(font, Vector2(tx, r.position.y + SKIP.y2),
			_elide(_tag_text(t), tw, 9), HORIZONTAL_ALIGNMENT_LEFT, tw, 9,
			C_GOLD.darkened(0.58))


func _skip_plate(r: Rect2, t: Dictionary, on: bool) -> void:
	var a: float = 1.0 if on else 0.55
	draw_rect(r, C_PANEL.lightened(0.10) if on else C_PANEL.darkened(0.34))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0 if on else 1.0)),
			C_ACC if on else C_ACC.darkened(0.55))
	if t.is_empty():
		draw_string(font, r.position + Vector2(0.0, SKIP.y1), "못 건너뛴다",
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, C_DIM)
		draw_string(font, r.position + Vector2(0.0, SKIP.y2), "보스 판",
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, C_DIM.darkened(0.3))
		return
	_icon_tag(Vector2(r.position.x + SKIP.ix, r.get_center().y), 6.5,
			String(t.get("kind", "")), a)
	var tx: float = r.position.x + SKIP.tx
	var tw: float = r.size.x - SKIP.pad
	draw_string(font, Vector2(tx, r.position.y + SKIP.y1),
			"건너뛴다" if on else "건너뛰면",
			HORIZONTAL_ALIGNMENT_LEFT, tw, 10,
			C_TXT if on else C_DIM.darkened(0.1))
	draw_string(font, Vector2(tx, r.position.y + SKIP.y2),
			_elide(_tag_text(t), tw, 9), HORIZONTAL_ALIGNMENT_LEFT, tw, 9,
			C_GOLD if on else C_GOLD.darkened(0.34))


func _skip_rect(i: int) -> Rect2:
	var r := _row_rect(i, GameData.legs_per_round())
	return Rect2(Vector2(r.position.x + 6.0, r.end.y + SKIP.dy),
			Vector2(r.size.x - 12.0, SKIP.h))


func _leg_skip() -> Rect2:
	return _skip_rect(clampi(GameData.leg_idx(leg_no), 0,
			GameData.legs_per_round() - 1))


# 건너뛴다 — 점수도 골드도 없다. 뱃지를 받고 다음 판으로 넘어간다.
func _skip_leg() -> void:
	if not GameData.skippable(leg_no):
		_deny()
		return
	leg_skipped[leg_no] = true
	if not leg_tag.is_empty():
		_take_tag(leg_tag)
	Save.bump("skips")
	leg_no += 1
	_open_leg()


# 뱃지의 효과 한 줄. 표의 desc 는 {v} 를 안 채운 날것이라 여기서 채운다.
# 이름만으로는 무슨 값을 받는지 모른다 — "여벌 다트" 가 몇 개인지,
# "넓은 테이블" 가 몇 칸인지는 이 줄에만 있다.
# 언제 쓰이는가. 즉시 받는 것과 다음 상점까지 쥐고 있는 것이 화면에서
# 안 갈렸다 — "무료 리롤" 을 지금 받는지 다음 상점에서 받는지가
# 건너뛸지 말지를 바꾼다.
func _tag_when(t: Dictionary) -> String:
	match String(t.get("when", "now")):
		"leg":
			return "다음 판에"
		"shop":
			return "다음 상점에서"
		"stage":
			return "다음 보스 판에"
	return "바로"


# 쌓아 둔 뱃지 한 자리. 그리기와 판정이 같은 식을 쓴다.
#
# 폭 58 에 글 왼쪽 15 였을 때 "넓은 테이블" 의 테이블 그림(반지름 5, 잉크
# 오른끝 13)과 첫 글자가 2px 로 붙어, 그림이 글자의 일부로 읽혔다.
# 자리를 4px 늘리고 글을 20 으로 민다 — 이름 최장이 35px(8pt)이라
# 남는 38 로 안 잘리고, 아홉 장까지는 640 안에 선다.
func _pend_rect(i: int) -> Rect2:
	return Rect2(Vector2(8.0 + float(i) * 66.0, VIEW.y - 20.0), Vector2(62.0, 14.0))


func _tag_text(t: Dictionary) -> String:
	if t.is_empty():
		return ""
	return GameData.fill(String(t.get("desc", "")),
			{"v": float(String(t.get("v", "0")))})


# 뱃지 하나를 받는다. 지금 쓰는 것은 바로 쓰고, 나중 것은 쌓아 둔다.
func _take_tag(t: Dictionary) -> void:
	var kind := String(t.get("kind", ""))
	var v := int(t.get("v", 0))
	var when := String(t.get("when", "now"))
	var at := Vector2(VIEW.x * 0.5, TBL.fy + 40.0)
	if when != "now":
		# 효과 줄과 때를 같이 싣는다 — 쌓인 뱃지에 커서를 올렸을 때
		# 이름만 있으면 무엇이 기다리는지가 이름 그대로 수수께끼다.
		pending_tags.append({"kind": kind, "v": v, "n": String(t.get("name", "")),
				"d": _tag_text(t), "w": _tag_when(t)})
		pop(at, "%s" % t.get("name", ""), C_ACC, 13, 1.4)
		return
	match kind:
		"gold":
			gold += v
			Save.bump("gold_earned", v)
		"track":
			# 트랙을 고르는 것이지 강화 줄을 고르는 것이 아니다. 표는 트랙당
			# 여덟 줄이라 줄에서 뽑아도 지금은 고르게 나오지만, 트랙마다
			# 줄 수가 달라지는 순간 조용히 치우친다. 트랙에서 뽑는다.
			var tks := {}
			for r in GameData.rows("area_up"):
				tks[int(r.get("track", 0))] = true
			var tkl := tks.keys()
			if not tkl.is_empty():
				# v 만큼 올린다. 표에는 +1 뿐이지만 값을 무시하고 있었다.
				for _k in maxi(v, 1):
					var tk: int = tkl[randi() % tkl.size()]
					track_lv[tk] = int(track_lv.get(tk, 0)) + 1
					Save.peak("best_track", int(track_lv[tk]))
					# 무엇이 올랐는지 말한다. 이 뱃지만 아무 말이 없었다 —
					# 화면에 트랙 레벨을 쓰는 자리가 런 정보뿐이라, 말이
					# 없으면 "안 걸렸다" 와 구별이 안 된다.
					pop(at, "%s 강화 Lv.%d" % [_track_name(tk),
							int(track_lv[tk]) + 1], C_GREEN.lightened(0.2), 12, 1.3)
		"cons":
			var cp := GameData.consumables()
			for i in v:
				if cons.size() < GameData.cons_slots() and not cp.is_empty():
					cons.append(cp[randi() % cp.size()])
		"item":
			var pool := []
			for it in GameData.items():
				if not _has_item(it.id) and GameData.item_min_leg(it) <= leg_no:
					pool.append(it)
			for i in v:
				if owned.size() < GameData.max_items() and not pool.is_empty():
					var pick: Dictionary = pool[randi() % pool.size()].duplicate()
					pick.gs = 0
					pick.bought = leg_no
					owned.append(pick)
					_panel_reset()
	pop(at, "%s" % t.get("name", ""), C_ACC, 13, 1.4)


# 쌓아 둔 뱃지에서 한 갈래를 꺼내 값을 합친다. 꺼내면 사라진다.
func _spend_tags(kind: String) -> int:
	var sum := 0
	var i := pending_tags.size() - 1
	while i >= 0:
		if String(pending_tags[i].kind) == kind:
			sum += int(pending_tags[i].v)
			pending_tags.remove_at(i)
		i -= 1
	return sum


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
	# 봉인은 _start_leg 에서만 다시 뽑힌다. 지우지 않으면 스테이지 선택
	# 화면의 동전 슬롯이 지난 판 봉인을 그대로 보여준다.
	sealed = -1
	sell_sel = -1
	buy_sel = -1
	stage_slots = owned.size()
	# 등급(정공·도전·극한)이 없다. 제약 셋을 깔고 하나를 고른다 — 고르는
	# 질문이 "얼마나 무리할까" 에서 "어느 쪽이 내 빌드에 덜 아픈가" 로
	# 바뀌었다. 보상은 붙지 않는다. 제약은 대가를 치르는 것이 아니라 그냥 판이다.
	#
	# **보스 판에서만 깐다.** 발라트로가 보스 블라인드에만 효과를 붙이는 것과
	# 같은 자리다. 다른 점 하나: 발라트로는 무엇이 나올지 못 고르는데 우리는
	# 셋 중에 고른다 — 조준 게임이라 "이 제약이 내 손에 얼마나 아픈가" 를
	# 플레이어가 실제로 안다.
	var base := GameData.target_of(leg_no)
	stage_pick.clear()
	stage_stand.clear()
	stage_t = 0.0
	if not GameData.is_boss(leg_no):
		# 작은 판·큰 판은 제약이 없다. 화면을 띄우지 않고 바로 던지러 간다.
		active_mods = []
		target = base
		_start_leg()
		return
	var left := GameData.modifiers().duplicate()
	for i in GameData.stage_picks() + _spend_tags("picks"):
		var md := _draw_weighted(left)
		if md.is_empty():
			break
		left.erase(md)               # 같은 카드가 두 장 깔리지 않는다
		# "높은 목표"(스펙 700001 · 확정)는 목표 자체를 올린다. 카드에 오른
		# 목표가 곧 그 판의 목표다 — 화면과 판정이 같은 수를 읽는다.
		var tgt := base
		if String(md.k) == "target_mul":
			tgt = int(ceil(float(base) * float(md.v)))
		stage_pick.append({"d": md, "target": tgt})
		stage_stand.append(0.0)
	state = S.STAGE
	_sfx("stage_open")


func _pick_stage(i: int) -> void:
	var sp: Dictionary = stage_pick[i]
	active_mods = [sp.d]
	target = sp.target
	_sfx("stage_pick")
	_start_leg()


# ══════════════════════════════════════════════════════════
#  오디오
# ══════════════════════════════════════════════════════════

# ══════════════════════════════════════════════════════════
#  소리 — 이름 있는 사건
#
#  여태 소리는 부르는 자리마다 날 숫자였다. `beep(392.0, 0.06, 0.14)` 이
#  쉰여섯 곳이었고, 어느 것이 "판을 넘겼다" 이고 어느 것이 "못 산다" 인지는
#  둘레 코드를 읽어야 알 수 있었다. 소리 파일을 넣으려면 그 쉰여섯을
#  하나씩 되짚어야 했다.
#
#  이제 부르는 자리는 **이름만 댄다.** 그 이름으로 둘이 갈린다.
#      res://sfx/<이름>.wav 가 있으면   그 파일을 낸다
#      없으면                           아래 표의 합성음을 낸다
#  파일을 떨구는 것만으로 소리가 바뀐다 — 코드는 한 글자도 안 고친다.
#  일부만 넣어도 된다. 넣은 것만 파일이 되고 나머지는 합성음으로 남는다.
#
#  표의 수치는 옮기기 전 그 자리에 있던 값 **그대로**다. 지금 소리는
#  한 음도 안 달라졌다.
#
#  f 를 넘기는 자리가 넷 있다(정산 걸음). 거기는 음이 반음씩 오르는 것이
#  소리의 내용이므로, 파일이 있으면 같은 비로 pitch_scale 을 민다.
# ══════════════════════════════════════════════════════════
const SFX_DIR := "res://sfx/"

# 정산 걸음의 기준 음. 파일을 얼마나 밀어 올릴지가 이 값 대비로 정해진다.
const SFX_BASE := 392.0

const SFX := {
	# ── 던지기 ────────────────────────────────────
	"dart_pick":      {"f": 262.0, "d": 0.05, "a": 0.10},
	"aim_lock_first": {"f": 300.0, "d": 0.05, "a": 0.10},
	"aim_lock_last":  {"f": 400.0, "d": 0.06, "a": 0.12},
	"kick_shot":      {"f": 520.0, "d": 0.04, "a": 0.09},

	# ── 착탄 (등급이 곧 소리다) ──────────────────
	"hit_miss":       {"seq": [150.0], "gap": 0.0, "d": 0.22, "a": 0.11},
	"hit_single":     {"seq": [160.0], "gap": 0.0, "d": 0.13, "a": 0.19},
	"hit_double":     {"seq": [330.0, 330.0], "gap": 0.075, "d": 0.11, "a": 0.20},
	"hit_triple":     {"seq": [330.0, 415.0, 494.0], "gap": 0.07, "d": 0.12, "a": 0.22},
	"hit_bull_o":     {"seq": [262.0, 392.0, 523.0], "gap": 0.07, "d": 0.15, "a": 0.24},
	"hit_bull_i":     {"seq": [262.0, 392.0, 523.0, 659.0], "gap": 0.07, "d": 0.17, "a": 0.26},

	# ── 정산 (반음씩 오른다 — 게임 이름이 여기서 왔다) ──
	"settle_miss":    {"f": 180.0, "d": 0.20, "a": 0.14},
	"settle_step":    {"f": SFX_BASE, "d": 0.10, "a": 0.16},
	"settle_pierce":  {"f": SFX_BASE, "d": 0.11, "a": 0.18},
	"settle_item":    {"f": SFX_BASE, "d": 0.11, "a": 0.18},
	"settle_total":   {"f": 196.0, "d": 0.34, "a": 0.26},
	"target_hit":     {"seq": [392.0, 523.0, 659.0, 784.0], "gap": 0.08, "d": 0.26, "a": 0.26},

	# ── 판과 런 ───────────────────────────────────
	"leg_clear":    {"seq": [392.0, 494.0, 587.0], "gap": 0.09, "d": 0.18, "a": 0.22},
	"save_life":      {"seq": [392.0, 523.0], "gap": 0.09, "d": 0.16, "a": 0.22},
	"run_win":        {"seq": [262.0, 330.0, 392.0, 523.0, 659.0], "gap": 0.10, "d": 0.22, "a": 0.26},
	"run_lose":       {"seq": [300.0, 240.0, 180.0], "gap": 0.13, "d": 0.24, "a": 0.22},
	"leg_open":     {"seq": [392.0, 523.0], "gap": 0.07, "d": 0.12, "a": 0.18},
	"leg_go":       {"f": 523.0, "d": 0.06, "a": 0.14},
	"stage_open":     {"seq": [392.0, 494.0], "gap": 0.09, "d": 0.14, "a": 0.18},
	"stage_pick":     {"seq": [523.0, 659.0, 784.0], "gap": 0.07, "d": 0.12, "a": 0.20},

	# ── 상점 ──────────────────────────────────────
	"shop_open":      {"f": 440.0, "d": 0.10, "a": 0.18},
	"buy":            {"seq": [523.0, 659.0], "gap": 0.07, "d": 0.11, "a": 0.20},
	"sell":           {"seq": [659.0, 880.0], "gap": 0.06, "d": 0.09, "a": 0.18},
	"deny":           {"seq": [200.0, 150.0], "gap": 0.06, "d": 0.10, "a": 0.16},
	"reroll":         {"f": 392.0, "d": 0.09, "a": 0.18},
	"fixture_buy":    {"seq": [392.0, 523.0, 659.0], "gap": 0.07, "d": 0.14, "a": 0.18},
	"cons_use":       {"seq": [523.0, 659.0], "gap": 0.06, "d": 0.10, "a": 0.18},
	"sweep_sink":     {"f": 196.0, "d": 0.05, "a": 0.09},
	"drop_skip":      {"f": 330.0, "d": 0.05, "a": 0.10},
	"chute_enter":    {"f": 523.0, "d": 0.04, "a": 0.10},

	# ── 손 ────────────────────────────────────────
	"hand_take":      {"f": 196.0, "d": 0.04, "a": 0.08},
	"hand_drop":      {"f": 147.0, "d": 0.05, "a": 0.07},
	"shop_select":    {"f": 349.0, "d": 0.05, "a": 0.10},
	"shop_deselect":  {"f": 262.0, "d": 0.05, "a": 0.10},
	"rack_select":    {"f": 349.0, "d": 0.05, "a": 0.10},
	"rack_deselect":  {"f": 262.0, "d": 0.05, "a": 0.10},
	"rack_move":      {"f": 392.0, "d": 0.05, "a": 0.10},

	# ── 메뉴 ──────────────────────────────────────
	"newrun_open":    {"f": 440.0, "d": 0.05, "a": 0.12},
	"pack_flip":      {"f": 392.0, "d": 0.04, "a": 0.10},
	"league_pick":     {"f": 523.0, "d": 0.05, "a": 0.12},
	"run_start":      {"f": 523.0, "d": 0.06, "a": 0.14},
	"menu_pick":      {"f": 523.0, "d": 0.06, "a": 0.14},
	"menu_pick2":     {"f": 392.0, "d": 0.04, "a": 0.10},
	"menu_back":      {"f": 440.0, "d": 0.05, "a": 0.12},
	"back":           {"f": 330.0, "d": 0.05, "a": 0.10},
	"page":           {"f": 392.0, "d": 0.04, "a": 0.08},
}

# 파일을 낼 자리들. 겹쳐 나는 소리가 서로를 안 끊게 몇 개 돌려 쓴다.
var sfx_pool := []
var sfx_next := 0
# 이름 → AudioStream. **없다는 것도 기억한다** — 소리마다 파일 시스템을
# 두드리면 정산 한 걸음마다 디스크를 때린다.
var sfx_cache := {}


func _sfx(name: String, f := 0.0) -> void:
	var st := _sfx_file(name)
	if st != null and not sfx_pool.is_empty():
		var pl: AudioStreamPlayer = sfx_pool[sfx_next]
		sfx_next = (sfx_next + 1) % sfx_pool.size()
		pl.stream = st
		# 정산 걸음은 음이 오르는 것이 소리의 내용이다. 파일도 같은 비로 민다.
		pl.pitch_scale = 1.0 if f <= 0.0 else clampf(f / SFX_BASE, 0.25, 4.0)
		pl.play()
		return
	var e: Dictionary = SFX.get(name, {})
	if e.is_empty():
		# 표에 없는 이름은 조용히 무음이 된다 — 그게 제일 찾기 어렵다.
		push_error("소리: 모르는 이름 '%s' — SFX 표에 먼저 적어라" % name)
		return
	if e.has("seq"):
		beep_seq(e.seq, e.gap, e.d, e.a)
	else:
		beep(f if f > 0.0 else float(e.f), e.d, e.a)


func _sfx_file(name: String) -> AudioStream:
	if sfx_cache.has(name):
		return sfx_cache[name]
	var path := SFX_DIR + name + ".wav"
	var st: AudioStream = load(path) if ResourceLoader.exists(path) else null
	sfx_cache[name] = st
	return st


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
	# 이 게임 고유의 축. 제약이 미는 그 줄에 사진이 나란히 얹힌다 —
	# 둘 다 곱이라 순서가 값을 안 바꾼다.
	var g := gauge_speed * mod_v("gauge_mul", 1.0) 			* GameData.fixture_v("gauge_mul", 1.0)
	return g * (cur_dart.gauge if cur_dart.has("gauge") else 1.0)


func ch() -> float:
	# 제약이 못 건드린다 — 확인 구간은 입력을 안 받는 순수 연출이라 배수를
	# 걸어도 화면에서 아무 일이 안 일어난다. 안개가 그 축을 쓰다가 죽은
	# 효과가 됐고, 지금은 조준선을 지우는 fog 축으로 옮겼다.
	return confirm_hold


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
	_mus_update(d)

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
	_tick_score(d)

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
	# 3D 통은 새 런 화면에만 산다. 지우는 자리를 한 곳에 둔다 — 나가는
	# 길이 셋(ESC · 뒤로 · 시작)이라 각각에 달면 언젠가 하나를 빠뜨린다.
	if state != S.NEWRUN and cup_vp != null:
		_cup3_close()
	# 판에 꽂힌 다트의 3D 무대도 같은 규약이다. 판이 안 서는 화면에서는
	# 지운다 — 상점·제목·컬렉션에서 뒤에 남아 돌 이유가 없다.
	# 판 갈이가 도는 동안(swap_live)은 판이 아직 화면에 있으므로 살려 둔다.
	if bd_vp != null and not _is_play() and not swap_live:
		_bd3_close()
	Dev.tick(d)          # DEV
	_drop_update(d)

	match state:
		S.AIM_V, S.AIM_H:
			_aim_tick(d)
		S.CONFIRM:
			gt += d * gs()
			confirm_t += d
			if confirm_t >= ch():
				if cur_dart.get("magnet", 0.0) > 0.0:
					aim = aim.lerp(BC, cur_dart.magnet)
				_grip_consume()
				state = S.FLY
				fly_t = 0.0
				# 꽂힐 각을 지금 정한다. 나는 동안과 꽂힌 뒤가 같은 각이라야
				# 착탄 프레임에서 자루가 홱 돌지 않는다.
				fly_rot = randf_range(-0.26, 0.26)
		S.FLY:
			fly_t += d
			if fly_t >= GameData.tune("fly_time"):
				if burst_hits.is_empty():
					_land()
				else:
					aim = burst_hits.pop_front()
					_land(false)
		S.RESOLVE:
			qt -= d
			if qt <= 0.0:
				_next_step()
		S.NEWRUN:
			_cup_update(d)

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
		var gm := _cursor()
		for i in remaining.size():
			# 뒤에 그려진 것이 위에 있다. 마지막 명중을 택해 그리기 순서와 맞춘다.
			if _grip_pose(i).hit.has_point(gm):
				gi = i
	for i in grip_hov.size():
		grip_hov[i] = move_toward(grip_hov[i], 1.0 if i == gi else 0.0, d * 7.0)

	_tip_update(d)
	queue_redraw()


# 점수판이 따라 올라가는 수. lerp 는 목표에 닿지 않고 밑에서 수렴하므로
# 반 점 안에 들면 딱 붙인다 — 안 붙이면 45 를 44.9997 로 들고 있게 되고,
# 점수판이 그 값을 버려서 "44 / 45 인데 클리어" 로 읽힌다(플레이 보고).
# 3D 통은 여기서만 만진다. 강체를 그리기 틱에서 밀면 물리 서버가 그
# 프레임에 되돌려 놓아 아무 일도 안 일어난다.
func _physics_process(d: float) -> void:
	if state == S.NEWRUN:
		_cup3_phys(d)


func _tick_score(d: float) -> void:
	shown = lerpf(shown, float(total), 1.0 - pow(0.02, d))
	if absf(shown - float(total)) < 0.5:
		shown = float(total)


func _auto_step() -> void:
	match state:
		S.LEG:
			# 열에 하나꼴로 건너뛴다 — 두 길이 다 돌아야 소크가 뜻이 있다
			if GameData.skippable(leg_no) and randf() < 0.1:
				_skip_leg()
			else:
				_open_stage()
		S.PICK:
			_click(_mag_rect(randi() % maxi(remaining.size(), 1)).get_center())
		S.AIM_V, S.AIM_H:
			_advance()
		S.CLEAR:
			_click(Vector2(-1, -1))
		S.STAGE:
			_click(_stage_rect(randi() % stage_pick.size()).get_center())
		S.SHOP:
			# 사탕은 쟁여 둘 이유가 없다 — 들자마자 쓴다.
			#
			# 이 세 줄이 없으면 **트랙이 측정에서 통째로 빠진다.**
			# 오토플레이가 사탕를 사서 칸에 넣기만 하고 안 써서, 성장 축 둘
			# (트랙 강화 · 보드 확장) 중 하나가 없는 게임을 재게 된다. 그 수치로
			# 목표 곡선을 잡으면 실제보다 낮게 잡힌다 — curve_probe 를 처음
			# 돌렸을 때 실제로 그랬다.
			for ci in cons.size():
				if String(cons[ci].get("cat", "")) == "area":
					_cons_use(ci)
					return
			# 좌표가 아니라 함수를 직접 부른다. 4단계에서 _stock_rect 가 사라지므로
			# 여기서 미리 끊어 둬야 그 삭제가 순수 삭제가 된다.
			var buyable := []
			for i in stock.size():
				if _buy_block(i) == "":
					buyable.append(i)
			var roll := randf()
			# 사진도 이제 테이블 매물이라 buyable 에 같이 든다 — 따로
			# 굴리는 갈래가 없어졌다. 다만 소크가 사진을 한 번도 안 사면
			# 넓어진 테이블·늘어난 다트를 굴려 보지 못하므로, 사진이
			# 떠 있으면 그것을 먼저 집는다.
			var fixi := -1
			for i in buyable:
				if stock[i].type == "fix":
					fixi = i
					break
			if fixi >= 0 and roll < 0.35:
				_buy(fixi)
			elif not buyable.is_empty() and roll < 0.55:
				_buy(buyable[randi() % buyable.size()])
			elif gold >= reroll_cost and roll < 0.8:
				_reroll()
			else:
				_next_leg()
		S.OVER:
			_click(Vector2(320, 180))


# ══════════════════════════════════════════════════════════
#  히든 다트통이 갈라지는 두 자리
# ──────────────────────────────────────────────────────────
#  기본 다트통들은 값만 바꾼다 — 다트 수, 시작 골드, 칸 수. 히든 다트통은
#  **조준하는 법**과 **점수 내는 법**이 다르다. 그 둘이 갈라지는 자리가
#  이 게임에 정확히 두 곳이고, 여기다.
#
#  지금은 std 하나뿐이다. 변형의 내용은 아직 안 정했고 여기는 자리만
#  세워 둔 것이다. 새 방식을 만들려면
#    ① data.gd 의 AIM_MODES / SCORE_MODES 에 이름을 적고
#    ② 아래 match 에 그 이름의 갈래를 파고
#    ③ packs.csv 의 aim / score 열에 그 이름을 쓴다
#  ①을 빼먹으면 검증기가 막는다. ②를 빼먹으면 판 시작에 오류가 뜬다.
#  둘 다 조용히 std 로 도는 것을 막으려고 있다 — 안개가 그렇게 죽었었다.
#
#  방식은 **판 시작에 한 번** 읽어 둔다. 매 프레임 표를 뒤지지 않고,
#  판 도중에 다트통이 바뀔 일도 없다. 제약 축들과 같은 규약이다.
# ══════════════════════════════════════════════════════════

# 든 동전 중 조준 방식을 쥔 첫 장. 둘을 같이 들면 동전 슬롯 앞자리가
# 이긴다 — 동전 순서는 플레이어가 끌어서 바꿀 수 있으므로 "무엇이
# 이기나" 가 손에 있다.
func _aim_from_items() -> String:
	for i in owned.size():
		if i == sealed:
			continue          # 봉인된 동전은 이번 판에 일을 안 한다
		var am := String(owned[i].get("aim", ""))
		if am != "":
			return am
	return "std"


# 당김 조준. **끌고 온 거리가 아니라 놓는 순간의 속도**가 던지는 벡터다 —
# 뒤로 끌었다가 그 자리에서 가만히 놓으면 아무 데도 안 간다. 당긴 거리는
# 그 위에 얹히는 배수일 뿐이다. 다트는 판 아래 제자리에서 출발한다.
const PULL := {
	# 자루를 못 찾을 때만 쓰는 자리. 보통은 고른 자루가 꽂힌 데서 떠난다.
	"org": Vector2(40.0, 224.0),
	"win": 0.12,                   # 속도를 재는 창(초). 손이 마지막에 한 일만 본다
	# 속도 → 거리(초). 벽에서 판 한가운데까지 약 265px 이므로 1000px/s 쯤이
	# 정중앙이다 — 창 해상도로는 초당 2000px, 흔한 손놀림 하나다.
	# 640px/s 에서 1380px/s 사이가 판에 얹히므로 두 배가 조금 넘는 폭이
	# 있고, 그보다 세게 튕기면 오른쪽으로 지나간다.
	"vs": 0.26,
	"least": 120.0,                # 이보다 안 나가면 안 던진다. 다시 쥔다
	"spread": 4.0,                 # 산포. 같은 자리에 두 번은 못 꽂는다
}

# 반동 조준. 한 발이 작은 다트 여러 발이 된다. 쏠 때마다 조준이 위로
# 밀리므로 손으로 눌러 잡아야 한다 — FPS 의 스프레이다.
#
# 연발을 **다 쏜 뒤에** 정산한다. 이 게임의 정산은 발마다 카드가 뜨고
# 큐가 도는 애니메이션이라 한 발에 1초 넘게 걸리는데, 그 사이에 반동을
# 잡으라고 하면 잡을 것이 없다. 쏘는 동안은 손만 일하고, 다 쏜 뒤에
# 꽂힌 자리를 하나씩 판다.
# 발 수와 점수 몫은 표에 있다(kick_n · kick_share) — 그 둘은 균형이고,
# 아래 넷은 손맛이다.
# 정산 걸음의 빠르기. free 걸음까지는 그대로, 그 뒤로는 남은 걸음마다
# step 만큼 짧아지고 min 에서 멎는다.
const PACE := {"free": 5.0, "step": 0.055, "min": 0.30, "shot": 4.0}

const KICK := {
	"gap": 0.11,      # 발 사이 간격(초)
	"up": 10.0,       # 발마다 위로 밀리는 양(px)
	"side": 5.0,      # 좌우 흔들림 폭(px)
	# 회복은 연사보다 **느려야** 한다. 30px/s 로 두었더니 발 사이 0.11초에
	# 거의 다 돌아와서 발이 안 걸어 올라갔다 — 잡을 것이 없는 반동이었다.
	"settle": 14.0,   # 밀린 것이 제자리로 돌아오는 빠르기(px/s)
}

# 흔들 조준. 커서 둘레의 원 안에서 **새 자리를 계속 뽑고 그리로 달려간다.**
# 도착하기 전에 다음 자리를 뽑으므로 늘 움직이고, 다음 자리가 어디일지
# 모르므로 기다렸다 누르기가 안 통한다.
#
# 빠르기는 참고한 게임(Darts: skill issue)에 맞춘다 — 그 게임의 점은
# 눈으로 따라갈 수 있게 어슬렁거리지, 파르르 떨지 않는다. 10초에 원
# 지름의 대여섯 배쯤 지난다. 감쇠 랜덤워크(멎어 보임)와 초당 300px
# (떨림) 둘 다 지나쳤던 자리다 — 프로브가 위아래 양쪽을 다 막는다.
const DRIFT := {"span": 0.32, "hold": 0.45, "speed": 40.0}


# 다트마다 조준을 새로 세운다. 빗각의 축은 여기서 뽑으므로 한 발 안에서는
# 축이 안 흔들리고 다음 발에서는 반드시 바뀐다. gt 는 손대지 않는다 —
# 게이지가 자유롭게 돌아야 집는 순간의 위상이 매번 다르다.
func _aim_begin() -> void:
	aim_r = 0.0
	aim_a = 0.0
	# 빗각일 때만 뽑는다. 늘 뽑으면 다트를 집을 때마다 전역 난수 줄이
	# 한 칸씩 밀려, 조준과 아무 상관없는 상점·성장 뽑기가 통째로
	# 달라진다 — joker_probe 가 그렇게 다른 런을 걸어 실패했다.
	if aim_mode == "tilt":
		aim_ax = randf() * TAU
	drift_o = Vector2.ZERO
	drift_to = Vector2.ZERO
	drift_t = 0.0
	kick_o = Vector2.ZERO
	burst_left = 0
	burst_n = 0
	burst_t = 0.0
	burst_hits = []
	_pull_drop()


func _aim_stages() -> int:
	return int(GameData.AIM_STAGES.get(aim_mode, 2))


func _aim_hint(stage: int) -> String:
	var a: Array = GameData.AIM_HINT.get(aim_mode, [])
	return String(a[stage]) if stage < a.size() else ""


# 커서 자리. 뷰포트가 없으면 — 헤드리스 검사가 _process 를 직접 밀
# 때가 그렇다 — 마지막으로 받은 자리를 쓴다. 없는 커서를 엔진에
# 물으면 오류가 나고, 검사가 보려던 것과 상관없는 데서 프레임이 멎는다.
func _cursor() -> Vector2:
	return get_local_mouse_position() if get_viewport() != null else mouse_at


# 이 방식이 쓰는 축 한 쌍. 빗각만 기울고 나머지는 화면의 가로세로 그대로다.
func _aim_axes() -> Array:
	if aim_mode == "tilt":
		var u := Vector2(cos(aim_ax), sin(aim_ax))
		return [u, u.orthogonal()]
	return [Vector2(1.0, 0.0), Vector2(0.0, 1.0)]


# 조준점이 나갈 수 있는 끝. 클릭이 잠기는 반경과 같은 선이라 "누를 수
# 있는 자리"와 "꽂힐 수 있는 자리"가 어긋나지 않는다. 빗나감 띠가 이
# 안에 있으므로 놓기 조준도 빗나갈 수 있다.
func _aim_clamp(p: Vector2) -> Vector2:
	return BC + (p - BC).limit_length(R * GameData.tune("aim_click_r"))


# 던지는 자리 = **고른 자루가 꽂혀 있는 데**. 이 게임의 다트는 왼쪽 벽에
# 박혀 있으므로 거기서 떠난다. 자루마다 높이가 달라 던지는 각도가 매번
# 조금씩 다르다 — 벽의 어느 칸을 뽑았는가가 그대로 손맛이 된다.
func _pull_org() -> Vector2:
	if grip_pick >= 0 and grip_pick < remaining.size():
		return _grip_pose(grip_pick).c
	return PULL.org


# 다트를 쥔다. 판 위가 아니라 왼쪽 벽에서 쥐므로 조준 클릭 규칙 밖이다.
func _pull_grab(m: Vector2) -> void:
	pull_at = m
	pull_t = 0.0
	pull_log = [{"p": m, "t": 0.0}]


func _pull_drop() -> void:
	pull_at = Vector2(-1, -1)
	pull_t = 0.0
	pull_log = []


# 손자리를 창 하나만큼만 기억한다. 놓는 순간의 속도는 손이 **마지막에**
# 한 일이지, 쥔 자리에서 여기까지 온 거리가 아니다.
func _pull_sample(d: float) -> void:
	pull_t += d
	pull_log.append({"p": mouse_at, "t": pull_t})
	while pull_log.size() > 2 and pull_t - float(pull_log[0].t) > PULL.win:
		pull_log.pop_front()


# 던지는 벡터 = 창 안의 손 속도. **끌고 온 거리가 아니다.**
#
# 참고한 게임에는 뒤로 당긴 거리가 배수로 얹혔는데, 그 게임은 다트가
# 화면 아래에 있어 뒤로 당길 자리가 있었다. 우리 다트는 왼쪽 벽에 박혀
# 있어서 뒤로는 34px 밖에 없다 — 못 쓰는 손잡이를 두느니 뺀다.
func _pull_vec() -> Vector2:
	if pull_log.size() < 2:
		return Vector2.ZERO
	var a: Vector2 = pull_log[0].p
	var b: Vector2 = pull_log[pull_log.size() - 1].p
	var dt: float = maxf(float(pull_log[pull_log.size() - 1].t)
			- float(pull_log[0].t), 0.016)
	return (b - a) / dt * PULL.vs


# 지금 놓으면 어디에 꽂히는가. 출발 자리는 늘 자루가 꽂힌 데다 —
# 손을 어디로 끌고 갔든 겨냥이 안 옮겨지고, 튕기는 방향만 겨냥이 된다.
func _pull_point() -> Vector2:
	return _aim_clamp(_pull_org() + _pull_vec())


# 작은 다트 한 발. 꽂고, 반동을 얹고, 마지막이면 정산으로 넘긴다.
func _kick_fire() -> void:
	burst_hits.append(aim)
	# 여기서 화면에 꽂는다. 정산은 이미 꽂힌 자리를 읽으므로 그때는
	# 다시 안 꽂는다(_land 의 mark=false).
	darts.append({"p": aim, "id": String(cur_dart.get("id", "std")),
			"rot": fly_rot})
	_sfx("kick_shot")
	kick_o += Vector2(aim_rng.randf_range(-float(KICK.side), float(KICK.side)),
			-float(KICK.up))
	burst_left -= 1
	burst_t = float(KICK.gap)
	if burst_left <= 0:
		_advance()


func _aim_tick(d: float) -> void:
	gt += d * gs()
	match aim_mode:
		"ring":
			# 1단계는 중심에서 원이 커지고, 2단계는 그 원 위를 점이 돈다.
			if state == S.AIM_V:
				aim_r = lerpf(4.0, R, tri(gt))
				aim = BC + Vector2(0.0, -aim_r)
			else:
				var an := fposmod(gt, 1.0) * TAU - PI * 0.5
				aim = BC + Vector2(cos(an), sin(an)) * aim_r
		"tilt":
			# 기울어진 축 한 쌍을 쓸 뿐, 잠그는 순서는 기본과 같다.
			var ax := _aim_axes()
			if state == S.AIM_V:
				aim_a = lerpf(-SWING, SWING, tri(gt))
				aim = BC + ax[0] * aim_a
			else:
				aim = BC + ax[0] * aim_a + ax[1] * lerpf(-SWING, SWING, tri(gt))
		"cross":
			# 두 축이 서로 다른 박자로 동시에 간다. 1.37 은 1 과 안 맞아떨어져
			# 궤적이 대각선 한 줄로 굳지 않는다 — 굳으면 아무 때나 눌러도 된다.
			aim.y = lerpf(BC.y - SWING, BC.y + SWING, tri(gt))
			aim.x = lerpf(BC.x - SWING, BC.x + SWING, tri(gt * 1.37))
		"drift":
			# **커서 둘레**의 작은 원 안을 제멋대로 떠돈다. 커서를 옮기면 그
			# 원도 따라온다 — 판 한가운데를 도는 것이 아니라 손을 따라다니는
			# 것이 이 방식의 전부다.
			var w := R * float(DRIFT.span)
			drift_t -= d * gs()
			if drift_t <= 0.0:
				# 원 안에서 고르게 뽑는다. 반지름에 제곱근을 안 씌우면 가운데로
				# 쏠려 가장자리를 거의 안 쓴다.
				drift_to = Vector2.RIGHT.rotated(aim_rng.randf() * TAU) \
						* (sqrt(aim_rng.randf()) * w)
				drift_t = float(DRIFT.hold)
			drift_o = drift_o.move_toward(drift_to, float(DRIFT.speed) * d * gs())
			aim = _aim_clamp(mouse_at + drift_o)
		"place":
			aim = _aim_clamp(mouse_at)
		"kick":
			# 조준은 손을 따라간다. 반동이 그 위에 얹혀 밀고, 손이 눌러 잡는다.
			# 안 잡으면 발이 위로 걸어 올라가 판을 벗어난다.
			kick_o = kick_o.move_toward(Vector2.ZERO, float(KICK.settle) * d)
			aim = _aim_clamp(mouse_at + kick_o)
			if burst_left > 0:
				burst_t -= d
				if burst_t <= 0.0:
					_kick_fire()
		"pull":
			if pull_at.x < 0.0:
				aim = _pull_org()       # 아직 안 쥐었다. 다트는 벽에 박혀 있다
			else:
				_pull_sample(d)
				aim = _pull_point()
				if not mouse_down:
					# 쥐었다가 그냥 놓은 손이다 — 안 던지고 다시 쥐게 한다.
					# 힘이 없는데도 던지면 매번 벽 옆에 꽂혀 다트만 없어진다.
					#
					# **던지는 벡터**를 잰다. 착탄점으로 재면 벽에서 판까지의
					# 거리가 늘 끼어든다 — 손이 가만히 있어도 _aim_clamp 가
					# 판 언저리로 끌어다 놓아서, 안 던진 것이 던진 것이 된다.
					if _pull_vec().length() < float(PULL.least):
						_pull_drop()
					else:
						var sp: float = PULL.spread
						aim = _aim_clamp(aim + Vector2(
								aim_rng.randf_range(-sp, sp),
								aim_rng.randf_range(-sp, sp)))
						_advance()
		_:
			# 게이지가 왕복하고 누른 순간 그 축이 잠긴다. 세로 먼저 가로 다음.
			# 모르는 이름도 여기로 떨어진다 — 소리는 _start_leg 가 이미
			# 냈고, 여기서 멎으면 조준이 영영 안 잠겨 런이 통째로 막힌다.
			if state == S.AIM_V:
				aim.y = lerpf(BC.y - SWING, BC.y + SWING, tri(gt))
			else:
				aim.x = lerpf(BC.x - SWING, BC.x + SWING, tri(gt))


# 이 다트의 점수. 기본 점수와 배수를 어떻게 합치는가 — 그 한 줄이 이 게임의
# 점수 계산 방식 전부다.
func _score_combine(chip: int, mult: int) -> int:
	match score_mode:
		"std":
			return chip * mult
		"bal":
			# 점수와 배수를 평균으로 맞춘 뒤 곱한다. 한쪽에만 쌓는 빌드가
			# 통째로 죽고 양쪽을 고르게 올린 빌드가 가장 커진다 — 같은
			# 합에서 곱이 가장 큰 자리가 두 값이 같은 자리이기 때문이다.
			var x := int(round((float(chip) + float(mult)) * 0.5))
			return x * x
	return chip * mult


func _advance() -> void:
	match state:
		S.AIM_V:
			# 한 번에 잠그는 방식은 두 번째 칸을 건너뛴다. 안 건너뛰면
			# 이미 정해진 자리를 두고 아무 일도 안 하는 칸을 한 번 더
			# 눌러야 한다.
			if _aim_stages() < 2:
				state = S.CONFIRM
				confirm_t = 0.0
				_sfx("aim_lock_last")
				return
			state = S.AIM_H
			_sfx("aim_lock_first")
		S.AIM_H:
			state = S.CONFIRM
			confirm_t = 0.0
			_sfx("aim_lock_last")


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey:
		var k := e as InputEventKey
		if k.pressed and not k.echo:
			if Dev.key(self, k.keycode):          # DEV
				return
			if swap_live:
				# 연출은 아무 키로나 건너뛴다. 잠긴 채로 못 빠져나가는
				# 자리를 안 만드는 것이 ESC(일시정지)보다 앞선다.
				_swap_skip()
				return
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
				KEY_TAB:
					# 런 정보 — 런 안에서만 뜻이 있다. 타이틀·설정·컬렉션에서는
					# 볼 런이 없고, 연출 중(RESOLVE·전환)에는 입력을 안 받는다.
					if state == S.RUNINFO:
						state = run_from
						_sfx("menu_back")
					elif _runinfo_ok():
						run_from = state
						state = S.RUNINFO
						_sfx("menu_pick")
				KEY_F11:
					_toggle_fullscreen()
				KEY_ESCAPE:
					if state == S.RUNINFO:
						state = run_from
					elif state == S.SETTINGS:
						_settings_back()
					elif state == S.COLLECT or state == S.NEWRUN:
						state = S.TITLE
					elif hand_st != H.NONE:
						_hand_abort()
					elif buy_sel >= 0 or sell_sel >= 0:
						buy_sel = -1
						sell_sel = -1
					elif state != S.TITLE and state != S.OVER:
						# 판 중의 ESC 는 일시정지다 — 설정을 열고, 닫으면
						# 열던 자리로 돌아간다. 진행 상태는 전부 그대로다.
						pause_from = state
						state = S.SETTINGS
				KEY_SPACE:
					if hand_st != H.NONE:
						_hand_abort()
					elif state == S.TITLE:
						_open_newrun()
					elif state == S.NEWRUN:
						if _pack_open(newrun_pip):
							_new_run()
						else:
							_deny()
					elif state == S.SETTINGS:
						_settings_back()
					elif state == S.COLLECT:
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
		mouse_at = mb.position
		mouse_down = mb.pressed
		if mb.pressed:
			if _hand_press(mb.position):
				return                    # 삼킨다 — 탭인지 드래그인지 아직 모른다
			_click(mb.position)
		else:
			if set_drag >= 0:
				# 저장은 뗄 때 한 번. 끄는 동안 매 프레임 쓰면 파일을 두드린다.
				_set_slide_end()
				return
			_hand_release(mb.position)
	elif e is InputEventMouseMotion:
		# 손 상태와 무관하게 받아 둔다 — _hand_motion 은 쥐고 있을 때만
		# 갱신하는데, 놓기·당김 조준은 아무것도 안 쥔 채로 자리를 읽는다.
		mouse_at = (e as InputEventMouseMotion).position
		# 게이지를 끌고 있으면 손보다 먼저 본다 — 설정 화면에는 손이 없다.
		if set_drag >= 0:
			_set_slide(set_drag, mouse_at)
			return
		_hand_motion(mouse_at)


func _click(m: Vector2) -> void:
	if Dev.click(self, m):          # DEV
		return
	if swap_live:
		return          # 갈아 끼우는 동안은 아무것도 안 받는다
	match state:
		S.PICK:
			for i in remaining.size():
				if _mag_rect(i).has_point(m):
					_pick_dart(i)
					return
		S.AIM_V, S.AIM_H:
			# 다트를 갈아타는 것은 **첫 축을 잠그기 전까지**다.
			# 규칙이 뜻하는 것은 "던질 자루를 무를 수 없다" 가 아니라
			# "잠근 것을 무를 수 없다" 이므로, 결정의 순간을 잠금에 둔다.
			# 한 번 잠근 뒤(AIM_H)에는 못 바꾼다 — 세로를 맞춰 놓고 자루를
			# 갈면 그 세로가 어느 자루의 것인지가 없어진다.
			# 한 번에 잠그는 방식들은 잠그기 전이 곧 조준 내내이므로,
			# 그 방식에서는 던지기 직전까지 갈아탈 수 있다.
			#
			# 당김은 뺀다. 거기서는 **벽의 자루를 쥐는 것이 곧 던지기**라
			# (_pull_grab 은 조준 클릭 규칙 밖이다) 같은 클릭에 두 뜻을
			# 실을 수 없다. 반동도 연발이 도는 중에는 안 받는다.
			if (state == S.AIM_V and m.x >= 0.0 and aim_mode != "pull"
					and burst_left <= 0 and burst_hits.is_empty()):
				for i in remaining.size():
					if _mag_rect(i).has_point(m):
						if i != grip_pick:
							_pick_dart(i)
						return
			#
			# 다트판 위에서만 잠긴다. 아무 데나 눌러도 되면 빗나간 클릭이
			# 그대로 조준이 되어, 무르지 못하는 실수가 생긴다.
			# 숫자 고리까지 포함해 R*1.22 로 넉넉히 잡는다.
			# m.x < 0 은 키보드에서 온 것이다 — 좌표가 없으므로 통과시킨다.
			# 당김은 **판 아래에서 다트를 쥔다.** 판 위를 눌러야 한다는 규칙을
			# 여기 두면 다트를 아예 못 잡는다 — 출발 자리가 판 밖이다.
			if aim_mode == "pull" and m.x >= 0.0:
				_pull_grab(m)
				return
			if m.x >= 0.0 and (m - BC).length() > R * GameData.tune("aim_click_r"):
				return
			if m.x >= 0.0 and aim_mode == "place":
				mouse_at = m
				aim = _aim_clamp(m)          # 누른 자리가 곧 꽂히는 자리다
			# 반동은 누름이 **방아쇠**다. 잠그는 것은 마지막 발이 나간 뒤라
			# 여기서 _advance 를 안 한다 — 하면 첫 발만 나가고 끝난다.
			if aim_mode == "kick" and m.x >= 0.0:
				if burst_left <= 0 and burst_hits.is_empty():
					mouse_at = m
					burst_left = GameData.tune_i("kick_n")
					burst_n = burst_left
					burst_t = 0.0
				return
			_advance()
		S.CLEAR:
			# 좌표를 보지 않는다 — 아무 데나 누르든 스페이스든 상점으로 넘어간다
			_open_shop()
			_swap_begin(false)   # 상점이 선 뒤라야 들어오는 테이블에 그릴 것이 있다
			return
		S.LEG:
			if _leg_go().has_point(m):
				_open_stage()
				_sfx("leg_go")
				return
			if _leg_skip().has_point(m):
				_skip_leg()
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
			# 창구가 "먼저 판에서 팔 동전을 고른다" 로 거절해 2클릭 판매가 통째로
			# 죽는다. 동전 슬롯(y[4,36])과 창구(y[112,244])는 y 로 갈려 있어 순서를
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
				_next_leg()
				return
			if _drop_busy():
				# 커서 밑에서 물건이 움직이는 동안 구매가 성립하면 "누른 것" 과
				# "산 것" 이 갈린다. 첫 클릭은 "지금 세운다" 로만 쓴다.
				_drop_settle()
				_sfx("drop_skip")
				return
			var hi := _shop_hit(m)
			if hi >= 0:
				_shop_tap(hi)           # 1클릭 즉시 구매 → 고르기로 내린다
			else:
				buy_sel = -1            # 맨 펠트 = 취소
		S.OVER:
			# 검증 실행은 소크 테스트라 곧장 다음 런으로 돈다. 사람은 새 런으로 —
			# 다트통과 리그을 다시 고를 자리가 거기다.
			if _autoplay:
				_new_run()
			else:
				_open_newrun()
		S.NEWRUN:
			for i in GameData.leagues().size():
				if not _league_rect(i).has_point(m):
					continue
				if not _league_open(i):
					_deny()
					return
				GameData.league = String(GameData.leagues()[i].get("id", ""))
				Save.set_set("league", GameData.league)
				Save.flush()
				_sfx("league_pick")
				return
			if GameData.packs().size() > 1:
				for right in [false, true]:
					if _pack_arrow(right).has_point(m):
						_pack_step(1 if right else -1)
						_sfx("pack_flip")
						return
			if _newrun_go().has_point(m):
				if not _pack_open(newrun_pip):
					_deny()
					return
				_new_run()
				_sfx("run_start")
				return
			if _newrun_back().has_point(m):
				state = S.TITLE
				_sfx("back")
				return
		S.TITLE:
			for i in 4:
				if _menu_rect(i).has_point(m):
					match i:
						0:
							_open_newrun()
						1:
							collect_tab = 0
							state = S.COLLECT
						2:
							state = S.SETTINGS
						3:
							get_tree().quit()
					_sfx("menu_pick")
					return
		S.SETTINGS:
			var rows := _set_rows()
			for i in rows.size():
				if not _set_rect(i).has_point(m):
					continue
				match rows[i]:
					"fs":
						_toggle_fullscreen()
					"vol", "mus":
						# 누른 자리로 곧장 가고 뗄 때까지 따라온다. 예전에는 클릭 한 번만
						# 받고 0.05 로 끊어서 계단처럼 움직였다 — 그게 조작감의 정체다.
						set_drag = i
						_set_slide(i, m)
					"lobby":
						pause_from = -1
						state = S.TITLE
					"quit":
						get_tree().quit()
					"back":
						_settings_back()
				_sfx("menu_back")
				return
		S.RUNINFO:
			for t in RI_TABS.size():
				if _ri_tab_rect(t).has_point(m):
					runinfo_tab = t
					_sfx("menu_pick2")
					return
			if _runinfo_back_rect().has_point(m):
				state = run_from
				_sfx("menu_back")
			return
		S.COLLECT:
			for t in COL_TABS.size():
				if _col_tab_rect(t).has_point(m):
					collect_tab = t
					collect_page = 0
					_sfx("menu_pick2")
					return
			if _col_pages() > 1:
				if _col_arrow_rect(false).has_point(m):
					collect_page = (collect_page - 1 + _col_pages()) % _col_pages()
					_sfx("page")
					return
				if _col_arrow_rect(true).has_point(m):
					collect_page = (collect_page + 1) % _col_pages()
					_sfx("page")
					return
			if _menu_back_rect().has_point(m):
				state = S.TITLE
				_sfx("back")


# ══════════════════════════════════════════════════════════
#  판정 / 정산
# ══════════════════════════════════════════════════════════

func hit_info(p: Vector2) -> Dictionary:
	var v := p - BC
	var r := v.length()
	# 기본점수·기본배수는 areas.csv(착탄 영역 · 전부 확정)가 정한다.
	# 여기 있던 50/25/0 하드코딩이 그리로 갔다. 기하(반지름)는 판의 모양이라
	# 보드 확장이 주무르는 값이고, 영역의 값은 데이터다 — 소유가 다르다.
	if r > R * rt_dbl_out:                                    # ← ① 판벌이
		var ao := GameData.area("out")
		return {"base": ao.base, "mult": 0, "sector": -1, "idx": -1,
				"r0": 0.0, "r1": 0.0, "track": ao.track, "col": -1}
	if r <= R * rt_bull_i:
		var bi := GameData.area("bull_i")
		return {"base": bi.base, "mult": bi.mult, "sector": bi.base, "idx": -1,
				"r0": 0.0, "r1": R * rt_bull_i, "track": bi.track, "col": -1}
	if r <= R * rt_bull_o:
		var bo := GameData.area("bull_o")
		return {"base": bo.base, "mult": bo.mult, "sector": bo.base, "idx": -1,
				"r0": 0.0, "r1": R * rt_bull_o, "track": bo.track, "col": -1}

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
			"track": trk, "col": _sec_col(idx)}

# 반환값의 치역:  mult ∈ {0,1,2,3}   sector ∈ {-1} ∪ [1,20] ∪ {25,50}
#                col ∈ {-1} ∪ [0, colors.csv 행 수)   — 불·아웃은 -1 이다

# 착탄 연출. 등급은 **꽂힌 자리**가 정한다 — 점수에 쓰는 배수가 아니다.
#
# 둘을 같은 수로 읽고 있었고, 그래서 배수를 건드리는 것이 하나라도 끼면
# 연출이 통째로 어긋났다. 트리플에 꽂았을 때 실제로 이랬다:
#   무거운(-1)  "더블" 이 뜬다        — 맞은 자리를 두고 거짓말을 한다
#   자석(-1)    "더블" 이 뜬다
#   관통(고정 1) 아무것도 안 뜬다
#   가벼운(+3)  아무것도 안 뜬다      — 배수 6은 어느 갈래에도 안 걸린다
# 트랙도 배수를 더하므로 트리플을 올릴수록 트리플 연출이 죽었다.
# 표준 다트에 트랙 0일 때만 맞던 연출이다.
#
# 링을 죽이는 제약(민짜)은 그대로 반영한다 — 죽은 띠는 죽은 것으로 보여야
# 한다는 규칙이 이미 판 그리기에 있고(_draw_board 의 dead), 그 축은 "꽂힌
# 자리가 무엇인가" 를 실제로 바꾼다. 다트와 트랙은 점수를 바꿀 뿐이다.
func _impact(info: Dictionary, hit_mult: int) -> void:
	var lbl := Vector2(0.0, 26.0) if aim.y < BC.y else Vector2(0.0, -24.0)

	var grade := 1
	if hit_mult == 0:
		grade = 0
	elif info.sector == 50:
		grade = 5
	elif info.sector == 25:
		grade = 4
	elif hit_mult == 3:
		grade = 3
	elif hit_mult == 2:
		grade = 2

	match grade:
		0:
			shake = 1.5
			board_punch = 0.15
			hit_flash_amt = 0.25
			_sfx("hit_miss")
		1:
			shake = 3.0
			board_punch = 0.45
			hit_flash_amt = 0.4
			_sfx("hit_single")
			add_wave(aim, 3.0, 24.0, C_TXT, 0.35, 1.0, 0.28)
		2:
			shake = 6.5
			board_punch = 0.8
			hitstop = 0.05
			hit_flash_amt = 0.7
			_sfx("hit_double")
			add_wave(aim, 3.0, 42.0, C_ACC, 0.75, 1.5, 0.40)
			add_ring_fx(R * rt_dbl_in, R * rt_dbl_out, C_ACC, 0.50)
			pop(aim + lbl, "더블", C_ACC, 15, 0.8)
		3:
			shake = 9.5
			board_punch = 1.0
			hitstop = 0.09
			hit_flash_amt = 0.9
			_sfx("hit_triple")
			add_wave(aim, 3.0, 54.0, C_ACC, 0.85, 2.0, 0.45)
			add_wave(aim, 3.0, 32.0, C_TXT, 0.60, 1.0, 0.32)
			add_ring_fx(R * rt_trp_in, R * rt_trp_out, C_ACC, 0.55)
			pop(aim + lbl, "트리플", C_ACC, 17, 0.9)
		4:
			shake = 11.0
			board_punch = 1.0
			hitstop = 0.11
			hit_flash_amt = 0.9
			_sfx("hit_bull_o")
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
			_sfx("hit_bull_i")
			add_wave(BC, R * rt_bull_i, R * 1.35, C_RED.lightened(0.45), 0.90, 2.5, 0.60)
			add_wave(BC, R * rt_bull_i, R * 0.90, C_ACC, 0.80, 2.0, 0.45)
			add_wave(BC, 3.0, 52.0, C_TXT, 0.80, 1.5, 0.32)
			add_sparks(16, R * rt_bull_i, R * 1.10, 16.0, C_ACC, 0.55)
			pop(BC + Vector2(0.0, -38.0), "불스아이", C_ACC, 20, 1.1)


# mark 가 false 면 연발의 한 발이다 — 이미 꽂혀 있고, 점수도 한 발치가
# 아니라 작은 다트 몫만 받는다.
func _land(mark := true) -> void:
	kick_pellet = not mark
	if _autoplay:
		# 검증 실행은 보드 안에 고르게 꽂아서 판이 진행되게 한다
		var a := randf() * TAU
		aim = BC + Vector2(cos(a), sin(a)) * sqrt(randf()) * R * 0.95

	var info := hit_info(aim)
	# 칸을 죽이는 축 셋. 번호 · 색 · 홀짝 순으로 좁아진다.
	if dead_idx >= 0 and info.idx == dead_idx:
		info.base = 0
	if dead_col >= 0 and int(info.col) == dead_col:
		info.base = 0
	if not is_equal_approx(odd_mul, 1.0) and info.idx >= 0 			and int(info.base) % 2 == 1:
		info.base = int(round(float(info.base) * odd_mul))
	# 링을 죽이는 축. 배수만 1 로 내린다 — 값은 그대로다.
	if dead_ring > 0 and int(info.mult) == dead_ring:
		info.mult = 1
	if info.mult == 0:
		leg_miss = true
	# 꽂힌 자리의 배수. 여기까지가 "판이 무엇인가" 이고, 아래는 "내 다트가
	# 그것을 어떻게 셈하는가" 다. 연출은 앞의 것을 쓴다(_impact 주석 참조).
	# 이 런에서 어느 트랙을 몇 번 맞혔나. 런 정보 화면이 읽는다 —
	# 여기가 "판이 무엇인가" 가 끝나는 자리라 칸 죽이기·홀짝 보정을
	# 이미 다 지난 뒤다. 즉 화면에 뜨는 수는 실제로 셈에 들어간 착탄이다.
	var _tk: int = int(info.get("track", 0))
	if _tk != 0:
		track_hits[_tk] = int(track_hits.get(_tk, 0)) + 1

	var land_mult: int = int(info.mult)

	# 다트 특성
	var pierce_gain := 0
	if info.mult > 0:
		if cur_dart.get("fix1", false):
			info.mult = 1
		if cur_dart.get("mult", 0) != 0:
			info.mult = maxi(1, info.mult + cur_dart.mult)
		if cur_dart.get("pierce", false) and info.idx >= 0:
			# 양옆 칸의 몫은 darts.csv 의 pierce_side 가 정한다 — 카드 문장이
			# 그 수를 그대로 찍는다. 여기 0.5 를 박아 두면 표를 고쳐도 안 따라온다.
			# 칸 수도 sectors 에서 읽는다. 20 을 박으면 보드 확장이 칸을 늘리는 날
			# 배열 밖을 짚는다.
			var n: int = sectors.size()
			var l: int = sectors[(info.idx + n - 1) % n]
			var r: int = sectors[(info.idx + 1) % n]
			pierce_gain = int(float(l + r) * float(cur_dart.get("side", 0.5)))

	# 트랙 강화 — 사탕이 올린 트랙 레벨. 레벨별 수치 행이 전부
	# 트랙 강화 (= 발라트로의 행성 카드). 사탕이 트랙 레벨을 올리고
	# 그 레벨의 1..lv 행을 합친 것이 여기 얹힌다. 다트 보정 **뒤**에 오는
	# 순서는 의도한 것이다 — 다트의 배수 하한(maxi(1, ...))을 먼저 통과시킨
	# 뒤에 트랙 배수를 더해야, 무거운 다트가 트랙 투자를 통째로 먹지 않는다.
	#
	# info.mult > 0 가드 때문에 빗나감은 배수를 못 받는다. 점수만 받는다 —
	# 그게 보드 아웃 트랙의 전부이고, 빗나감 깃발이 살아 있는 이유다.
	var tlv := int(track_lv.get(int(info.get("track", 0)), 0))
	if tlv > 0:
		var tb := GameData.track_bonus(int(info.track), tlv)
		info.base += int(tb.s)
		if info.mult > 0:
			info.mult += int(tb.m)

	# 꽂힌 자루마다 살짝 다른 각. 한 번 정하고 저장하므로 프레임 간 안 흔들린다.
	# 연발은 쏘는 동안 이미 꽂아 두었으므로 여기서는 안 꽂는다.
	if mark:
		darts.append({"p": aim, "id": String(cur_dart.get("id", "std")),
				"rot": randf_range(-0.26, 0.26)})
	# 연출에는 **꽂힌 자리의 배수**를 넘긴다. info.mult 는 이 위에서
	# 다트와 트랙이 이미 주무른 값이라, 그걸 넘기면 연출이 점수를 따라간다.
	_impact(info, land_mult)

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

	# rackval 배율 — 이 발에서 파는 값이 아니라 지금 동전 슬롯의 값이다.
	var rv_all := 0
	for o in owned:
		rv_all += GameData.sell_value(o)

	var mag_hvy := 0
	for md in magazine:
		if String(md.get("id", "")) == "hvy":
			mag_hvy += 1

	# ── 이력 갱신 — ctx 를 만들기 **전**이다 ─────────────────────
	#  패턴 깃발은 완성한 그 발부터 선다. 전에는 이 블록이 ctx 뒤에 있어서
	#  「같은 숫자 3회」가 3번째 발이 아니라 4번째 발에야 섰다 — 6발 판에서
	#  세 발·네 발 계열이 사실상 안 뜨던 원인이다.
	#
	#  순서가 바뀌었으므로 갱신 **전** 값을 봐야 하는 넷은 먼저 떠 둔다.
	#  이 넷의 뜻은 하나도 안 바뀐다:
	#    rezone   이미 맞힌 영역을 **다시** 맞히면 — 이번 발 전의 이력을 본다
	#    risk1    판 **첫** 고난도 명중 — 갱신 뒤엔 영영 거짓이 된다
	#    low      이번 발 전까지의 최저 칸
	#    zonehist 이 영역을 몇 번째로 맞히는가 — 이번 발을 포함한다(종전과 같다)
	var rezone_pre: bool = zone != "" and zone_cnt.get(zone, 0) > 0
	var risk1_pre: bool = is_risk and not seen_risk
	var low_pre := low_hit
	var zonehist_pre: int = (zone_hist.get(zone, 0) + 1) if zone != "" else 0
	if zone != "":
		if info.sector >= 1 and info.sector <= 20:
			sec_cnt[info.sector] = int(sec_cnt.get(info.sector, 0)) + 1
		zone_cnt[zone] = int(zone_cnt.get(zone, 0)) + 1
		zone_hist[zone] = int(zone_hist.get(zone, 0)) + 1
		if is_risk:
			seen_risk = true
		if info.sector >= 1 and info.sector <= 20:
			low_hit = info.sector if low_hit == 0 else mini(low_hit, info.sector)
		# 깃발 — 한 번 서면 판 끝까지 산다
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

	var ctx := {
		"sector": info.sector,
		"mult": info.mult,
		"miss": info.mult == 0,
		"missp": last_miss,
		"left": aim.x < BC.x,
		# 꽂힌 칸의 색. hit_info 가 이미 실어 보내는데 여기서 안 옮겨
		# 담아서, col 조건 일곱 장이 통째로 죽어 있었다 — check() 는
		# 없는 열을 -1 로 읽고 "칸에 안 꽂혔다" 로 판정한다.
		"col": int(info.get("col", -1)),
		"same": same,
		"first": dart_index == 0,
		"last": darts_left == 0,
		"streak": streak,
		"warm": leg_trp,
		# ── 조커 이식 조건 재료. 패턴 깃발은 이번 발을 **포함한** 것이다 —
		#    「같은 숫자 3회」는 3번째 발부터 선다. 위 이력 갱신 블록 참조.
		"risk1": risk1_pre,
		"few": leg_darts <= 3,
		"sixth": throw6 >= 6,
		"pair": pat.get("pair", false),
		"trip": pat.get("trip", false),
		"quad": pat.get("quad", false),
		"pair2": pat.get("pair2", false),
		"spread": pat.get("spread", false),
		"zone3": pat.get("zone3", false),
		"zones2": pat.get("zones2", false),
		"zones4": pat.get("zones4", false),
		"rezone": rezone_pre,
		# ── 배율 재료 ──
		"darts_left": darts_left,
		"items_n": owned.size(),
		"gold": gold,
		"mag_hvy": mag_hvy,
		"leg_darts": leg_darts,
		"leg_base": leg_base,
		"low": low_pre,
		"zonehist": zonehist_pre,
		"empty_n": GameData.max_items() - owned.size(),
		"rackval_all": rv_all,
		"rand01": randf(),
	}
	last_ctx = ctx
	land_n += 1

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

	# 빗나감이라도 보드 아웃 트랙을 올렸으면 점수가 난다 — info.base 는
	# 위에서 track_bonus 를 이미 받았다. 트랙이 0 이면 base 도 0 이라
	# 조건식이 예전과 완전히 같은 자리로 떨어진다.
	#
	# 빗나감 **깃발**은 안 건드린다. info.mult 는 여전히 0 이고 배수 1 은
	# 큐가 넣는다 — 실패 조건 동전(빗나감·연속 빗나감)가 그대로 산다.
	# 점수가 나는 빗나감과 실패로 세는 빗나감은 다른 축이다.
	if info.mult == 0 and fired.is_empty() and info.base <= 0:
		queue.append({"k": "miss"})
	else:
		if info.mult == 0:
			queue.append({"k": "miss"})
			queue.append({"k": "chip", "v": info.base})
			queue.append({"k": "mult", "v": 1})
		else:
			queue.append({"k": "chip", "v": info.base})
			queue.append({"k": "mult", "v": info.mult})
		if pierce_gain > 0:
			queue.append({"k": "pierce", "v": pierce_gain})
		for i in fired:
			var it: Dictionary = owned[i]
			if it.k == "save":
				continue          # 목숨은 정산이 아니라 판 실패가 읽는다
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
			# 즉시 골드 — 판정은 data.gd 가 쥔다. risk50 만 절반 확률이고
			# hit 은 조건이 곧 문이라 걸리면 그대로 준다.
			if GameData.gold_dart_hit(it, ctx) \
					and (String(it.get("g", "")) != "risk50" or randf() < 0.5):
				gold += int(it.get("gv", 0))
				pop(_slot_rect(mini(i, GameData.max_items() - 1)).get_center()
						+ Vector2(0.0, 24.0), "+%d" % it.gv, C_GOLD, 11, 0.8)
			# 영역 승급 — 발동 4회 중 1회꼴로 맞은 영역의 강화 트랙이 오른다
			if String(it.get("side", "")) == "trackup25" and randf() < 0.25 \
					and int(info.get("track", 0)) > 0:
				track_lv[info.track] = int(track_lv.get(info.track, 0)) + 1
				pop(BC + Vector2(0.0, -52.0), "트랙 강화 +1", C_ACC, 10, 0.9)
		queue.append({"k": "total"})

	# 통계는 해금 조건보다 **먼저** 세기 시작한다. 조건을 나중에 달면
	# 그때부터 세어져서 이미 한 플레이가 증발한다.
	Save.bump("darts")
	if info.mult == 0:
		Save.bump("misses")
	elif info.idx == -1:
		Save.bump("bulls")
	elif info.mult >= 3:
		Save.bump("triples")
	elif info.mult == 2:
		Save.bump("doubles")

	# 이력 갱신은 ctx 를 만들기 **전**으로 옮겼다 — 이 위쪽 블록이다.
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
		leg_trp = true
	dart_index += 1
	# 큐를 다 세운 뒤라야 이 정산이 얼마나 긴지 알 수 있다.
	settle_n = queue.size()
	state = S.RESOLVE
	qt = beat * 1.1


# 작은 다트의 기본 점수. **들어올 때** 깎는다 — 정산 결과만 깎으면 카드는
# "50 x 1" 을 보여 주고 총점은 13 만 오른다. 화면이 거짓말을 하는 것이다.
#
# 판에서 온 기본 점수가든 동전이 얹은 기본 점수가든 다 여기를 지난다. 기본 점수만 깎고
# 동전을 안 깎으면 조건 없는 "점수 +16" 한 장이 발마다 온전히 얹혀
# 자루 하나가 다섯 자루가 된다.
#
# **배수는 안 깎는다.** 보통 한 발과 연발 한 발에 같은 배수가 곱해지므로
# 비는 그대로다(다섯 발 x 0.25 = 1.25배). 고리가 준 x3 을 x0.75 로
# 적으면 그것이 더 큰 거짓말이다.
func _chip_gain(v: int) -> int:
	if not kick_pellet or v <= 0:
		return v
	return maxi(1, int(round(float(v) * GameData.tune("kick_share"))))


# 정산이 길수록 걸음을 재게 한다. 스무 걸음이 줄줄이 서 있는데 한 걸음씩
# 같은 박자로 세면 손이 놀고 기다리게 된다 — 발라트로가 그렇게 한다.
#
# **남은 걸음이 아니라 정산 전체 크기로 잰다.** 남은 것으로 재면 뒤로
# 갈수록 배수가 1 로 돌아가서, 정작 제일 답답한 꼬리가 제일 느려진다.
# 그렇게 만들었더니 연발이 10.7초에서 8.7초로밖에 안 줄었다.
#
# 짧은 정산은 안 건드린다(free 걸음까지는 배수 1). 맨 다트 한 발은
# 걸음이 셋이라 지금과 똑같이 돈다. 연발 한 발은 걸음 넷쯤으로 쳐서
# 같이 센다 — 안 그러면 연발은 짧은 정산 다섯 번이라 하나도 안 빨라진다.
func _pace() -> float:
	var load := float(settle_n) + float(burst_n) * float(PACE.shot)
	return clampf(1.0 - maxf(load - float(PACE.free), 0.0) * float(PACE.step),
			float(PACE.min), 1.0)


func _next_step() -> void:
	if queue.is_empty():
		card_target = 0.0
		# 반동은 한 발이 여러 발이다. 남은 작은 다트가 있으면 다음 발을
		# 판다 — 자루는 이미 하나만 썼으므로 판 계산은 안 건드린다.
		if not burst_hits.is_empty():
			aim = burst_hits.pop_front()
			_land(false)
			return
		burst_n = 0               # 연발이 다 팔렸다. 이제 보통 걸음이다
		# 목표를 넘긴 순간 판 종료 — 남은 다트는 골드로 환산된다
		if total >= target or darts_left <= 0:
			_finish_leg()
		else:
			_to_pick()
		return

	var st = queue.pop_front()
	var pace := _pace()
	qt = beat * pace
	pitch_step += 1
	var f := 392.0 * pow(2.0, float(pitch_step) / 12.0)
	var cc := card_pos() + Vector2(CARD_W * 0.5, 12.0)

	match st.k:
		"miss":
			card_item = "빗나감"
			_sfx("settle_miss")
			qt = beat * 1.4 * pace
		"chip":
			cur_chip += _chip_gain(st.v)
			_sfx("settle_step", f)
		"pierce":
			var pg := _chip_gain(st.v)
			cur_chip += pg
			card_item = "관통  점수 +%d" % pg
			pop(cc, "+%d" % pg, C_CHIP, 17, 0.9)
			_sfx("settle_pierce", f)
		"mult":
			cur_mult = st.v
			_sfx("settle_step", f)
		"item":
			_panel_fire(st.i)
			card_item = st.lbl
			match st.kind:
				"chip":
					cur_chip += _chip_gain(st.v)
				"mult", "mult_streak", "mult_rand":
					cur_mult += st.v
				"xmult":
					cur_mult *= st.v
				_:
					# 갈래를 안 늘리면 새 효과가 소리 없이 사라진다. mult_rand 가
					# 그렇게 죽어 있었고, 표는 그 카드를 87장 중 4위로 적고 있었다.
					push_error("정산: 모르는 효과 '%s' — 점수에 안 실린다" % st.kind)
			var col: Color = C_CHIP if st.kind == "chip" else C_MULT
			# st.v 는 이미 굴린 값이다 — kind 를 날것으로 넘기면 "배수 +0~7
			# 무작위" 가 떠서 결과를 상한으로 뒤집어 읽힌다. 큐 라벨(1634)과
			# 같은 매핑을 여기도 쓴다.
			pop(cc, GameData.eff_text(
					"mult" if st.kind == "mult_rand" else String(st.kind), st.v),
					col, 17, 0.9)
			_sfx("settle_item", f)
			shake = 3.0
		"total":
			var was_short := total < target
			last_gain = _score_combine(cur_chip, cur_mult)
			total += last_gain
			card_mode = 1
			total_flash = 1.0
			shake = 9.0
			board_punch = 1.0
			qt = beat * 2.6 * pace
			if was_short and total >= target:
				# 목표 돌파 — 판이 여기서 끝난다
				_sfx("target_hit")
				screen_flash = 0.7
				shake = 13.0
				pop(BC + Vector2(0.0, -46.0), "목표 달성", C_ACC, 22, 1.2)
				qt = beat * 3.4
			else:
				_sfx("settle_total")


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
#    ③ 가까운 모서리에 두께 2px. 동전 옆면(4.5*tall=2.77)과 같은 어법이고,
#       두께가 없으면 카드가 펠트에 인쇄된 무늬로 읽힌다.
#    ④ 폭을 상수에서 n 역산으로 바꾼다. 지금 값은 n=4 에서
#       150*4+14*3 = 642 > 640 으로 실제로 터진다.
#  ①만으로도 상인 여유가 7px(현재 상인 아래끝 119 vs 카드 126)에서
#  28.5px 로 벌어진다. 새 상인(111.5)와 합쳐 "안 가린다" 가 성립한다.
#
#  ── 글자는 왜 안 눕히는가 ────────────────────────────
#  카드는 눌리고 카드 위의 인쇄는 안 눌린다. 새 예외가 아니라 네 번째 사례다.
#    _sticker_flat  0.788 로 눌린 원반 위에 정면 숫자 12px
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


# 카드가 **누워 있는** 자리다. 히트 칸과 툴팁 앵커가 이걸 읽으므로
# 반드시 쉬는 모습이어야 한다 — 선 모습을 주면 아직 안 선 카드의
# 허공을 눌러도 잡힌다. 서면서 커지는 쪽은 위로만 자라므로, 누운 칸에
# 커서가 있는 한 계속 서 있다(떨림이 없다).
func _stage_rect(i: int) -> Rect2:
	return _row_rect(i, maxi(stage_pick.size(), 1))


# 한 줄에 n 장을 늘어놓을 때 i 번째 자리. 제약 카드와 판 카드가 같은 줄을
# 쓰므로 자리 계산도 하나다 — 개수만 다르다. 제약은 stage_pick 를 세지만
# 판 선택 화면에서는 그 배열이 비어 있어, 세는 곳을 나눠야 한다.
func _row_rect(i: int, cnt: int) -> Rect2:
	var n: float = maxf(float(cnt), 1.0)
	var span: float = VIEW.x - CARD.x0 * 2.0
	var w: float = (span - CARD.gap * (n - 1.0)) / n
	var hh: float = CARD.h * TBL.flat
	return Rect2(Vector2(CARD.x0 + float(i) * (w + CARD.gap),
			CARD.y + CARD.h - hh), Vector2(w, hh))


#  상인이 한 장씩 밀어 내려 준다. 카운터 뒤에서 나와 자리에 서고 한 번 튄다.
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
# 자루 사이 간격. 자루가 늘면 좁힌다 — 간격이 31 로 고정이면 아홉 자루째의
# 판정 사각(±18)이 화면(360) 아래로 6px 나가고, 열 자루면 자루 자체가
# 화면 밖이라 눌러서 고를 수가 없다. 그런데 오토플레이는 _mag_rect 의
# 중심 좌표를 스스로 만들어 넘기므로 소크가 그걸 못 잡는다.
#   마지막 자루 아래끝 = cy 224 + (n-1)*dy/2 + hit 18 ≤ 360
#   → dy ≤ 236 / (n-1)
# 기본 여섯 + 동전 하나 + 뱃지 하나 + 사진 하나 = 아홉이 실제 상한이다.
func _grip_dy() -> float:
	return minf(float(GRIP.dy), 236.0 / maxf(float(grip_n) - 1.0, 1.0))


func _grip_pose(i: int) -> Dictionary:
	# 칸은 시작 때 배정된 그대로다. 남은 개수가 아니라 시작 개수로 가운데를
	# 맞추므로, 자루가 빠져도 나머지가 제자리에 그대로 꽂혀 있다.
	var slot: int = grip_slot[i] if i < grip_slot.size() else i
	# 깊이와 높이도 같이 흔든다. 각도만 흔들면 자로 잰 듯 줄 맞춘 티가 남는다.
	var dy := _grip_dy()
	var base := Vector2(
			GRIP.x + (_grip_rnd(slot, 12.77) - 0.5) * 2.0 * GRIP.deep,
			GRIP.cy - float(maxi(grip_n, 1) - 1) * dy * 0.5 + float(slot) * dy
					+ (_grip_rnd(slot, 41.31) - 0.5) * GRIP.sway * 2.0)
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


# 선반 자리. 왼쪽 벽 — 자금판(y 20~54) 아래, 판매 창구 이름표(y 128) 위다.
# 테이블 물건은 펠트 위에 물리로 떨어지므로 이 사각과 영영 안 겹친다.
# 상점 밖에서 고른 동전을 파는 버튼. 고른 것이 없거나 상점이면 빈 사각이다
# (상점에는 창구가 있고, 두 자리를 같이 두면 같은 일에 문이 둘이 된다).
#
# 자리는 고른 칸 바로 아래다. 동전 슬롯 아래 y[64,76] 은 창구·버튼(112~)과
# 매물 최상단(99.3)과 조준 잠금 반경(76.4) 어디에도 안 겹치는 띠다.
func _sell_btn_rect() -> Rect2:
	if state == S.SHOP or sell_sel < 0 or sell_sel >= owned.size():
		return Rect2()
	if not _can_sell():
		return Rect2()
	var cell := _slot_rect(sell_sel)
	var w := 46.0
	return Rect2(cell.get_center().x - w * 0.5, cell.position.y + cell.size.y + 1.0,
			w, 13.0)


func _reroll_rect() -> Rect2:
	return Rect2(Vector2(32.0, 288.0), Vector2(152.0, 46.0))


func _next_rect() -> Rect2:
	return Rect2(Vector2(432.0, 288.0), Vector2(176.0, 46.0))


# ══════════════════════════════════════════════════════════
#  그리기
# ══════════════════════════════════════════════════════════

# ══════════════════════════════════════════════════════════
#  판 갈이 — 테이블 화면 ↔ 다트판 화면
# ──────────────────────────────────────────────────────────
#  테이블이 오른쪽으로 빠지고, 그 **앞에서** 판이 누운 채 올라와 선다.
#  돌아올 때는 같은 타임라인을 거꾸로 감는다 — 시각을 뒤집는 함수가
#  하나뿐이라 두 방향이 영영 안 갈린다.
#
#  이 연출은 게임 상태를 한 비트도 안 만진다. 상태는 부르는 쪽이 그
#  프레임에 다 바꾸고 여기는 그림만 붙잡는다. 그래서 프로브가 전부
#  그대로 살고, 소크(drop_fast)가 연출을 통째로 건너뛰어도 두 쪽이
#  정확히 같은 게임을 한다.
#
#  바깥과 닿는 곳은 여섯이다.
#    _swap_begin(to_board)  전환을 연다   (_start_leg 맨 앞 · _click S.CLEAR)
#    _swap_update(d)        매 프레임      (_drop_update 맨 앞)
#    _swap_skip()           즉시 끝낸다    (프로브·도구)
#    _swap_rise()           판이 선 정도   (_swap_board · _draw_board · _grip_draw)
#    _swap_gone()           테이블이 빠진 정도 (_swap_screen · _cover_draw)
#    swap_live              입력 잠금 하나
# ══════════════════════════════════════════════════════════

# 두 층은 **안 겹친다**. 겹치면 올라오는 판이 아직 남은 펠트 위에 얹힌
# 것으로 읽힌다 — 판이 테이블 위에 놓인 물건이 되어 버린다. 테이블이
# 화면을 완전히 뜬 뒤에 판이 뜬다. lead 가 그 경계다.
const SWAP := {
	# 0.30 으로는 "옮겼는지도 모르겠다" 는 말을 들었고, 그래서 0.59 로
	# 늘렸었다. 그런데 늘린 쪽은 "휙휙 안 바뀐다" 는 말을 들었다 —
	# 두 불만이 같은 값의 양끝이 아니라 **다른 것을 가리키고 있었다.**
	# 안 읽히던 것은 총 길이가 아니라 테이블이 빠지는 속도다. 0.30 짜리
	# 옛 판은 총 길이도 짧았지만 테이블도 느긋하게 나가서, 화면에 오래
	# 남은 채로 판이 뒤따라 올라오니 한 동작으로 뭉쳤다.
	#
	# 그래서 총 길이는 0.36 으로 줄이되 테이블을 두 배로 빨리 뺐다(0.15).
	# 테이블은 아홉 프레임에 휙 빠지고, 그 뒤 빈 화면에서 판이 선다.
	# 두 동작이 겹치지 않고 순서대로 읽히므로, 총 길이가 옛 "안 읽히던"
	# 판보다 길지 않은데도 무엇이 일어났는지는 더 잘 보인다.
	#
	# 아래 넷은 서로 물려 있다: 판이 뜨는 시각(lead)은 테이블이 640 밖으로
	# 나가는 시각보다 뒤여야 하고, 돌아올 때 판이 눕는 시간(fall)은
	# 테이블이 발을 들이는 시각보다 앞이어야 한다.
	# swap_probe 가 그 둘을 구간으로 잰다 — 손으로 옮기지 말 것.
	"dur":   0.36,    # 총 길이 = lead + rise
	"out":   0.15,    # 테이블이 화면 밖으로 빠지는 시간
	# 판이 뜨기 시작하는 시각. 테이블은 t=0.084 에 화면(640) 밖으로 나간다 —
	# lead 까지 46ms(세 프레임) 여유다. 짧게 잡을수록 두 동작이 겹칠 위험이
	# 커지므로, 프레임 하나(16.7ms) 로는 안 붙인다.
	"lead":  0.13,
	"rise":  0.23,    # 판이 서기까지 (lead 부터)
	# 돌아올 때 판이 눕기까지 (0 부터). 서는 것보다 빨라야 한다 — 테이블이
	# t=0.137 에 화면에 발을 들이므로 그전에 판이 내려가 있어야 두 층이
	# 안 겹친다. 0.11 이라 27ms(두 프레임) 여유다.
	"fall":  0.11,
	"tin":   0.23,    # 돌아올 때 테이블이 드는 시간 (lead 부터)
	"dx":    700.0,   # 테이블 이동. 640 에 카드 그림자·앞치마 여유 60
	# 상인은 가로로만 빼면 안 된다. 실루엣은 동전 슬롯(x[159,481] y[4,48]) 뒤에
	# 잘리는 것을 전제로 그린 크롭이라(NPC.top 주석), 89px 만 밀려도 평평한
	# 절단면과 잘린 팔 뿌리가 드러난다. 그래서 위로도 같이 뺀다 — 동전 슬롯이
	# 곧 퇴장문이다. 184 면 절단면이 동전 슬롯을 벗어나기 전에 화면 위로 넘어간다.
	"npc":   184.0,
	# 누운 판이 아래로 잠기는 깊이. 판은 시작할 때 **화면 밖**에 있어야
	# 한다 — 28 로는 앞치마 높이라, 아직 안 빠진 테이블 위에 판이 누워
	# 얹힌 것으로 읽혔다(찍어 보고 알았다). 누운 판의 윗변은
	#   306.74*0.70 + 91.14*0.30 = 242.06
	# 이므로 118 을 넘겨야 360 밖이다. 126 은 여유 8px.
	"dy":    126.0,
	"lie":   0.30,    # 누운 판의 y 배율 = sin 17.5°. 이보다 납작하면 고리가
					  # 1px 밑으로 뭉개지고 가로 스포크가 통째로 사라진다
	"pivot": 1.13,    # 축 = 판 아래 모서리. _draw_board 의 숫자 고리 배율 그대로
	"grip":  108.0,   # 탄창 벽이 왼쪽에서 들어오는 거리. 뽑힌 자루 꼬리까지 뺀다
}

var swap_t := 0.0        # 전환 경과(초)
var swap_live := false   # 전환이 도는 중 — 입력을 통째로 삼킨다
var swap_in := true      # true 테이블→판 · false 판→테이블
var swap_scr := -1       # 그 동안 그릴 테이블 화면. state 는 이미 반대편이다


func _e_out(k: float) -> float:
	return 1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 3.0)


# 판이 선 정도. 0 = 아래에 누워 있다 · 1 = 제자리에 서 있다.
#
# 두 방향이 **각자의 시계로** 같은 ease-out 을 탄다. 한쪽 타임라인을
# 거꾸로 감는 쪽이 짧지만, 뒤집힌 ease-out 은 ease-in 이 되어 돌아오는
# 길이 굼뜨다 멈칫하고 끝에서 들이받는다 — 찍어 보고 알았다.
func _swap_rise() -> float:
	if not swap_live:
		return 1.0
	if swap_in:
		return _e_out((swap_t - float(SWAP.lead)) / float(SWAP.rise))
	return 1.0 - _e_out(swap_t / float(SWAP.fall))


# 테이블이 빠져나간 정도. 0 = 제자리 · 1 = 화면 밖.
func _swap_gone() -> float:
	if not swap_live:
		return 0.0
	if swap_in:
		return _e_out(swap_t / float(SWAP.out))
	return 1.0 - _e_out((swap_t - float(SWAP.lead)) / float(SWAP.tin))


# 판 아래 모서리 = 눕히기의 축. 그리기와 검사가 같은 식을 쓴다.
func _swap_py() -> float:
	return BC.y + R * float(SWAP.pivot)


func _swap_begin(to_board: bool) -> void:
	# 소크와 도구는 연출을 안 탄다. 이 함수가 게임 상태를 안 만지므로
	# 건너뛰어도 두 쪽이 정확히 같은 게임을 한다.
	if drop_fast:
		return
	if to_board:
		if state != S.LEG and state != S.STAGE:
			return          # 테이블에서 온 것이 아니면 갈아 끼울 것이 없다
	elif state != S.SHOP:
		return
	swap_t = 0.0
	swap_live = true
	swap_in = to_board
	swap_scr = state


func _swap_update(d: float) -> void:
	if not swap_live:
		return
	swap_t += d
	npc_clock += d          # 상인은 빠지는 동안에도 숨을 쉰다
	if swap_t >= float(SWAP.dur):
		_swap_skip()


# 연출을 즉시 끝낸다. 프로브·도구가 감을 손잡이다.
func _swap_skip() -> void:
	swap_t = 0.0
	swap_live = false
	swap_scr = -1


# 판 층의 한 점이 지금 화면 어디로 가는가. 그리기와 검사가 같은 식을 쓴다 —
# "누운 판이 실제로 화면 안에 있는가" 는 눈이 아니라 이 함수가 답해야 한다.
func _swap_map(y: float) -> float:
	var a := _swap_rise()
	var sy: float = lerpf(float(SWAP.lie), 1.0, a)
	return _swap_py() * (1.0 - sy) + y * sy + float(SWAP.dy) * (1.0 - a)


# 판 층을 눕히고 내린다. x 는 안 누른다 — 바닥에 누운 원반은 세로만 준다.
# 흔들림은 origin 에 더해 배율 **밖**에 둔다. 안 그러면 판이 누울수록
# 불스아이의 타격감이 각도에 따라 옅어진다.
# _swap_map(y) = _swap_map(0) + y*sy 라서 두 함수가 같은 두 수를 쓴다.
func _swap_board(sh: Vector2) -> void:
	if not swap_live:
		return
	var sy: float = lerpf(float(SWAP.lie), 1.0, _swap_rise())
	draw_set_transform_matrix(Transform2D(Vector2(1.0, 0.0), Vector2(0.0, sy),
			Vector2(0.0, _swap_map(0.0)) + sh))


# 방의 벽. **안 움직인다.** 옮겨야 하는 것은 카운터·상인·판 셋뿐이고,
# 벽까지 같이 밀면 화면이 통째로 옮겨져 무엇이 움직였는지 안 읽힌다.
# 대신 색만 건너간다 — 테이블 화면의 바탕은 벽(C_WOOD)이고 판 화면의
# 바탕은 C_BG 라, 안 바꾸면 두 색의 경계선이 화면을 쓸고 지나간다.
func _swap_wall(base: Color) -> Color:
	return base.lerp(C_BG, _swap_rise()) if swap_live else base


# 안 밀리는 것의 원점. shake_off 에서 테이블 이동분만 뺀다.
func _swap_pin() -> Vector2:
	return shake_off - Vector2(float(SWAP.dx) * _swap_gone(), 0.0)


# 나가는(들어오는) 테이블 한 벌. shake_off **자체**를 잠깐 밀었다 되돌린다 —
# 카드 얼굴(_stage_card · _leg_card)이 draw_set_transform(shake_off) 로
# 복귀하므로, 오프셋을 새 변수에 담으면 그 복귀가 오프셋을 조용히 떨군다.
func _swap_screen(sh: Vector2) -> void:
	shake_off = sh + Vector2(float(SWAP.dx) * _swap_gone(), 0.0)
	draw_set_transform(shake_off)
	_draw_screen(swap_scr)
	shake_off = sh
	draw_set_transform(sh)


# 화면 한 벌. state 가 아니라 scr 를 받는다 — 전환 중에는 그려야 할
# 테이블이 이미 바뀐 state 와 다르기 때문이다.
func _draw_screen(scr: int) -> void:
	if scr == S.CLEAR:
		_draw_clear()
	elif scr == S.LEG:
		_draw_leg()
	elif scr == S.STAGE:
		_draw_stage()
	elif scr == S.SHOP:
		_draw_shop()
	elif scr == S.OVER:
		_draw_over()
	elif scr == S.TITLE:
		_draw_title()
	elif scr == S.SETTINGS:
		_draw_settings()
	elif scr == S.COLLECT:
		_draw_collect()
	elif scr == S.RUNINFO:
		_draw_runinfo()
	elif scr == S.NEWRUN:
		_draw_newrun()
	else:
		_draw_hint()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), C_BG)
	# 툴팁이 대상 테두리만 같이 흔들고 판은 고정하려면 이 값을 알아야 한다
	var sh := Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	shake_off = sh
	draw_set_transform(sh)

	if swap_live:
		# 방이 맨 밑이다. 카운터만 옆으로 빠지고 방은 그대로 있는 것이
		# 실제로 일어나는 일이다. _felt_draw 의 전면 사각은 이때 쉰다.
		draw_rect(Rect2(Vector2.ZERO, VIEW), _swap_wall(C_WOOD))
		# 테이블이 다 빠진 **뒤에** 판이 뜬다. 그래서 두 층이 안 겹치고,
		# 나가는 쪽만 테이블을 먼저 그리면 된다.
		if swap_in:
			_swap_screen(sh)

	_swap_board(sh)
	_draw_board()
	_draw_fx()
	_draw_darts()
	draw_set_transform(sh)          # 눕힘을 반드시 되돌린다
	if swap_live:
		if not swap_in:
			# 정산 화면의 스크림(0.94)을 이어받아 푼다. 안 풀면 눌러 넘긴
			# 첫 프레임이 전환에서 가장 밝은 프레임이 된다 — 이음새가
			# 아니라 번쩍임이다. 나가는 쪽은 밝은 테이블에서 오므로 안 건다.
			draw_rect(Rect2(Vector2.ZERO, VIEW),
					Color(C_BG, 0.94 * _swap_rise()))
			# 들어오는 테이블이 나중이다 — 다 누운 판을 덮으며 자리를 잡는다.
			_swap_screen(sh)
	else:
		_draw_aim()
		_draw_card()
		# 런 정보는 화면을 갈아 끼우는 것이 아니라 **판 위에 뜨는 판**이다.
		# 열던 화면을 먼저 그리고 그 위에 얹어야 "잠깐 확인하고 닫는다" 로
		# 읽힌다 — 뒤가 검으면 다른 화면으로 넘어간 것처럼 보인다.
		if state == S.RUNINFO:
			_draw_screen(run_from)
		_draw_screen(state)

	# 화면이 바뀌어도 같은 자리에 남는 것만 판이다 — 그래서 스크림 뒤에 그린다.
	_hud_draw()
	if not swap_live:
		_tip_draw(sh)
	draw_set_transform(Vector2.ZERO)
	Dev.draw(self)          # DEV
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
			or state == S.COLLECT or state == S.NEWRUN or state == S.RUNINFO:
		return
	if not _bar_hidden():
		_draw_topbar()
	if state != S.CLEAR:            # 정산 화면은 그 자체가 명세다
		_bank_draw()
		_cons_draw()
		_panel_draw()
		_cap_draw()
		_rack_hold_draw()   # 판 위다 — 끌고 다니는 동전은 무엇에도 안 덮인다
		# 나가는 전환에서만 같이 들어온다. 돌아오는 쪽은 안 그린다 —
		# HUD 는 스크림 위라, 벽만 어두운 화면에 홀로 밝게 뜬다.
		# 스크림이 0.94 로 시작하므로 사라지는 것도 안 보인다.
		if _is_play() or (swap_live and swap_in):
			# 왼쪽에서 미끄러져 든다. 테이블이 오른쪽으로 빠지므로 두
			# 층이 서로를 안 스친다 — 드러난 자리를 벽이 곧바로 메운다.
			var gx: float = -float(SWAP.grip) * (1.0 - _swap_rise())
			if gx < -0.01:
				draw_set_transform(shake_off + Vector2(gx, 0.0))
			_grip_draw()
			if gx < -0.01:
				draw_set_transform(shake_off)
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


# 판 바깥선에서 gap(R 배수)만큼 바깥. 뒤판과 숫자 고리가 같은 식을 본다 —
# 갈라 두면 보드 확장로 판이 커질 때 하나만 안 따라간다.
func _board_rim(gap: float) -> float:
	return R * (rt_dbl_out + gap)


func _draw_board() -> void:
	var sw := 18.0 * PI / 180.0
	var push := 1.0 + board_punch * 0.028

	# 판 뒤판과 숫자 고리는 **판 바깥선을 따라간다.** 1.07 · 1.13 을
	# 박아 두었더니 보드 확장 "판벌이"(바깥선 1.10)를 사는 순간 뒤판이 판보다
	# 안쪽으로 들어가고 숫자가 띠 위에 겹쳐 앉았다 — 판 모양은 데이터인데
	# 그 둘레만 상수였던 자리다. 간격은 그대로라 기본 판에서는 한 픽셀도
	# 안 달라진다.
	draw_circle(BC, _board_rim(0.07) * push, C_DARK.darkened(0.4))

	for i in 20:
		var a0 := i * sw - sw * 0.5
		var a1 := a0 + sw
		# 칸 색은 표가 정한다. 띠 색은 지금 규칙(i%2 → 빨강/초록)을 유지한다 —
		# 띠까지 데이터로 보내면 칸 색과 띠 색이 겹쳐 읽힘이 무너진다.
		var base_c := Color(GameData.color_hex(_sec_col(i)))
		# 죽은 칸은 죽은 것으로 보여야 한다. 값이 0 인데 판이 멀쩡해 보이면
		# 제약이 아니라 버그로 읽힌다 — "금지 구역"이 여태 그랬다.
		# 색 축(그늘)은 색 자체가 표시지만, 죽었다는 것까지는 색이 안 말한다.
		var dead: bool = i == dead_idx or (dead_col >= 0 and _sec_col(i) == dead_col)
		var ring_c: Color = C_RED if i % 2 == 0 else C_GREEN
		if dead:
			# **배경 쪽으로** 뺀다. C_DARK 로 낮추면 먹색 칸(2b2438)이 그 색과
			# 같아서 "그늘"이 아무것도 안 바꾼 것처럼 보였다 — 죽은 표시는
			# 원래 색이 무엇이든 같은 곳으로 가야 한다. 구멍처럼 읽힌다.
			base_c = base_c.lerp(C_BG, 0.72)
			ring_c = ring_c.lerp(C_BG, 0.72)
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

	# 칸 숫자는 누우면 지운다. 비균일 배율이 글자를 세로로만 눌러
	# 12px 글자가 3.6px 얼룩이 된다 — 글자는 눌러서 눕힐 수 없다.
	var na: float = clampf((_swap_rise() - 0.45) / 0.35, 0.0, 1.0)
	if na > 0.01:
		for i in 20:
			var a := i * sw
			var p := BC + Vector2(sin(a), -cos(a)) * _board_rim(0.13)
			draw_string(font, p + Vector2(-14, 5), str(sectors[i]),
					HORIZONTAL_ALIGNMENT_CENTER, 28, 12, Color(C_DIM, na))


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


# 벽을 언제 그리는가는 부르는 쪽(_hud_draw)이 정한다. 여기 있던 조기
# 반환은 상류 게이트에 가려 한 번도 안 닿던 죽은 가드였고, 두 곳에 같은
# 규칙을 적어 두면 다음에 조건을 바꾸는 사람이 한 곳만 고친다.
func _grip_draw() -> void:
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


# 판에 들어서면 오른쪽에서 날아와 하나씩 꽂힌다.
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


# ══════════════════════════════════════════════════════════
#  꽂힌 다트의 시점
#
#  눈은 판 한가운데를 지나는 축 위에 있다. 판이 정원으로 그려지는 것이
#  이미 그 뜻이다 — 축 위의 원은 원근에서도 원이다.
#
#  판에 수직으로 꽂힌 자루는 **축에서 멀수록 옆구리가 보인다.**
#    불 한복판   자루가 눈을 정면으로 가리켜 점으로 뭉친다
#    싱글        비스듬해지기 시작한다
#    더블 띠     가장 비스듬해서 몸통이 다 보인다
#
#  화면에 비치는 길이는 착탄 반지름에 **정비례**한다. 근사가 아니라 축 위
#  원근 투영의 답 그대로다 — 눈이 z=D, 판이 z=0, 자루가 눈 쪽으로 L 만큼
#  나와 있으면 촉은 반지름 r 에, 꽁지는 r·D/(D−L) 에 찍히므로 화면 길이가
#  r·L/(D−L) 이다. 그 상수 하나가 PERSP 다.
#
#  몸통은 중심 **바깥**으로 뻗는다. 꽁지가 눈에 더 가까워 축에서 더 멀리
#  찍히기 때문이다. 그래서 위에 꽂히면 아랫면이, 아래에 꽂히면 윗면이
#  보인다 — 방향 하나로 위아래가 저절로 갈린다.
#
#  MIN 이 없으면 불에 꽂은 발이 길이 0 이 되어 사라진다. 정면으로 본
#  자루는 점이 아니라 날개가 맞은편에서 보이는 작은 덩어리다.
# ══════════════════════════════════════════════════════════
const DART_PERSP := 0.33    # 반지름 1px 당 화면 길이. 판 끝에서 DART_DL 이 된다
const DART_MIN := 4.0       # 정면으로 본 자루의 반길이
const DART_MAX := 22.0      # 판 밖 먼 빗나감이 작살이 되는 것을 막는다


# ══════════════════════════════════════════════════════════
#  판에 꽂힌 다트 — 3D 무대
#
#  통(새 런 화면)이 이미 3D 다. 자루 메시를 _dart3_meshes 로 같이 쓰므로
#  여기서 새로 만드는 것은 **무대뿐**이다 — 뷰포트 하나와 카메라 하나.
#
#  ── 카메라가 설 자리는 이미 정해져 있었다 ────────────────
#  2D 판이 정원으로 그려진다는 것이 곧 "눈은 판 한가운데를 지나는 축
#  위에 있다" 는 뜻이다. 3D 는 그 전제를 실제 카메라로 세운 것뿐이라
#  두 그림이 어긋날 자리가 없다.
#
#  ── 픽셀을 맞추는 규약 ───────────────────────────────
#  **판 평면(z=0)에서 월드 1 = 화면 1px.** 원근 카메라의 z=0 면 반높이가
#  D·tan(fov/2) 이므로 그것을 뷰포트 반높이와 같게 잡으면 된다. 그러면
#  착탄점을 2D 좌표 그대로 꽂을 수 있고, 판·섬광·물결과 한 픽셀도 안 어긋난다.
#
#  ── 원근의 세기는 2D 받침과 같은 수다 ───────────────────
#  꽁지(z=len)는 D/(D−len) 배로 벌어져 찍힌다. 그 벌어짐이 곧
#  DART_PERSP = len/(D−len) 이라, D 를 거기서 거꾸로 뽑는다.
#  같은 수를 두 곳에 적지 않으므로 3D 가 꺼진 자리(헤드리스)로 떨어져도
#  다트가 튀지 않는다.
#
#  ── 뷰포트가 640x392 인 이유 ──────────────────────────
#  카메라 축이 뷰포트 한가운데를 지난다. 그 한가운데가 BC(320,196)에
#  앉아야 하므로 세로가 196*2 다. 아래 32px 은 화면 밖으로 잘린다 —
#  거기 꽂히는 다트가 없다.
#
#  ── 렌더러가 없으면 2D 가 대신 선다 ────────────────────
#  헤드리스 프로브·도구에서는 뷰포트가 빈 그림을 돌려준다. 그때는
#  _draw_darts_2d 가 같은 투영을 손으로 계산해 그린다. 두 벌을 나란히
#  두려는 게 아니라, 검사가 다트 없는 판을 보지 않게 하는 받침이다.
# ══════════════════════════════════════════════════════════

const BD3 := {
	# 자루 온 길이(px). 판 지름 196px 이 실물 다트판(바깥 지름 451mm)이라
	# 치면 1px ≈ 2.3mm 이고, 실물 자루 140mm 가 61px 이다. 80 은 거기서
	# 한 뼘 키운 값 — 61 로는 꽁지가 판에 붙어 원근이 안 읽힌다.
	"len":  80.0,
	"r":     1.5,      # 배럴 반지름. 정면으로 본 자루의 굵기가 이것이다
	"fin":   3.4,      # 날개 반폭. 불에 꽂힌 발은 이 십자가 전부라 넉넉히 준다
	# 꽁지가 위로 드는 각(rad). 실물 다트는 호를 그려 꽂히므로 꽁지가 든다.
	# 0.14 로는 그 기울기가 원근보다 커서 불에 꽂은 발이 점으로 안 뭉치고
	# 위로 선 막대가 됐다 — 이 화면에서 읽히는 것은 기울기가 아니라 원근이다.
	"rise":  0.06,
	"jit":   0.13,     # 자루마다의 손떨림(rad)
}

var bd_vp: SubViewport = null
var bd_nodes := []          # darts 와 인덱스를 공유하는 Node3D 들


func _bd3_live() -> bool:
	return bd_vp != null and is_instance_valid(bd_vp)


# 이 실행에 진짜 렌더러가 있는가. 3D 무대를 여는 자리는 전부 이것을 지난다 —
# 헤드리스에서 3D 뷰포트를 세우면 언젠가 죽는다.
func _has_renderer() -> bool:
	return DisplayServer.get_name() != "headless"


# 눈 거리. 원근의 세기(DART_PERSP)가 이 값을 정한다 — 거꾸로가 아니다.
func _bd3_eye() -> float:
	return float(BD3.len) * (1.0 + 1.0 / float(DART_PERSP))


func _bd3_size() -> Vector2:
	return Vector2(VIEW.x, BC.y * 2.0)


func _bd3_open() -> void:
	if _bd3_live():
		return
	var sz := _bd3_size()
	bd_vp = SubViewport.new()
	bd_vp.size = Vector2i(int(sz.x), int(sz.y))
	bd_vp.own_world_3d = true
	bd_vp.transparent_bg = true
	# 처음 한 벌은 열면서 굽는다. 그 뒤로는 자루 수가 달라질 때만
	# _bd3_sync 가 다시 굽도록 다시 건다.
	bd_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	bd_vp.msaa_3d = Viewport.MSAA_DISABLED
	bd_vp.gui_disable_input = true
	add_child(bd_vp)

	var d := _bd3_eye()
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	# z=0 면의 반높이가 뷰포트 반높이와 같아진다 = 월드 1 이 1px 이다.
	cam.fov = rad_to_deg(2.0 * atan(sz.y * 0.5 / d))
	cam.near = 1.0
	cam.far = d * 2.0
	cam.position = Vector3(0.0, 0.0, d)
	bd_vp.add_child(cam)

	# 빛은 왼쪽 위에서. 화면의 다른 입체(동전 마감·플라크 광택)가 쓰는
	# 방향과 같다 — 한 화면에 광원이 둘이면 어느 쪽이 위인지가 안 읽힌다.
	var lt := DirectionalLight3D.new()
	lt.rotation_degrees = Vector3(-38.0, -30.0, 0.0)
	lt.light_energy = 1.15
	lt.shadow_enabled = false
	bd_vp.add_child(lt)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = C_PANEL.lightened(0.50)
	env.ambient_light_energy = 1.10
	we.environment = env
	bd_vp.add_child(we)


func _bd3_close() -> void:
	bd_nodes.clear()
	if _bd3_live():
		bd_vp.queue_free()
	bd_vp = null


# 착탄점 하나가 3D 어디에 어떤 자세로 서는가.
# 화면 y 는 아래로 크고 월드 y 는 위로 크므로 부호를 뒤집는다.
func _bd3_pose(e: Dictionary) -> Transform3D:
	var p: Vector2 = e.p
	var land := Vector3(p.x - BC.x, -(p.y - BC.y), 0.0)
	# 자루 축 — 눈 쪽(+Z)에서 출발해 꽁지를 들고, 자루마다 조금씩 흔든다.
	var j: float = float(e.get("rot", 0.0))
	var ax := Vector3(0.0, 0.0, 1.0)
	# +X 둘레의 회전은 +Z 를 −Y 로 보낸다. 꽁지를 **위로** 들려면 부호가
	# 음수다 — 양수로 두었더니 12시에 꽂은 발에서 기울기가 원근과 정면으로
	# 상쇄되어, 판 끝이 판 가운데보다 짧게 비쳤다(프로브가 잡았다).
	ax = ax.rotated(Vector3.RIGHT, -(float(BD3.rise) + j * float(BD3.jit)))
	ax = ax.rotated(Vector3.UP, j)
	var yv := ax.normalized()
	var xv := Vector3.UP.cross(yv)
	if xv.length() < 0.01:
		xv = Vector3.RIGHT
	xv = xv.normalized()
	# 촉 끝이 로컬 −dl 이라는 _dart3_meshes 의 약속을 여기서 읽는다.
	return Transform3D(Basis(xv, yv, xv.cross(yv)),
			land + yv * float(BD3.len) * 0.5)


# darts 배열과 3D 노드를 맞춘다. 수가 달라졌을 때만 다시 세운다 —
# 판마다 열두 발을 넘지 않으므로 통째로 다시 세워도 싸다.
# ── 눈 뒤에서 판까지 ─────────────────────────────────
# 던진 자루가 카메라 앞에서 출발해 착탄점에 꽂힌다. FLY 동안만 산다.
# 그동안은 무대를 매 프레임 다시 굽는다 — 0.2초뿐이라 값이 싸다.
var bd_fly: Node3D = null


func _bd3_flying() -> bool:
	return state == S.FLY and _bd3_live()


func _bd3_fly() -> void:
	if not _bd3_live():
		return
	if state != S.FLY:
		if is_instance_valid(bd_fly):
			bd_fly.queue_free()
			bd_fly = null
			bd_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		return
	if not is_instance_valid(bd_fly):
		bd_fly = Node3D.new()
		_dart3_meshes(bd_fly, float(BD3.len) * 0.5, float(BD3.r), float(BD3.fin),
				_dart3_col(String(cur_dart.get("id", "std"))))
		bd_vp.add_child(bd_fly)
	bd_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var end := _bd3_pose({"p": aim, "rot": fly_rot})
	# 출발점은 눈 바로 앞, 화면 아래쪽이다 — 손에서 떠난 것처럼 읽힌다.
	# 원근이 알아서 크게 잡아 주므로 자루를 따로 키우지 않는다.
	# 눈에 바짝 붙여 둔다. 0.62 로 두었더니 출발부터 판 앞이라 "날아왔다" 가
	# 아니라 "판 위에서 미끄러졌다" 로 보였다. 원근이 자루를 키우는 자리는
	# 카메라 코앞뿐이다.
	var beg := Vector3(end.origin.x * 0.15 - 18.0, end.origin.y * 0.15 - 46.0,
			_bd3_eye() * 0.86)
	var t := clampf(fly_t / maxf(GameData.tune("fly_time"), 0.001), 0.0, 1.0)
	# 끝에서 살짝 붙는다 — 등속이면 원근 때문에 뒤로 갈수록 느려 보인다.
	var e := t * t * (3.0 - 2.0 * t)
	bd_fly.transform = Transform3D(end.basis, beg.lerp(end.origin, e))


func _bd3_sync() -> void:
	if not _bd3_live():
		return
	if bd_nodes.size() != darts.size():
		# 꽂힌 자루는 한 번 서면 안 움직인다. 그래서 그릴 때마다 3D 를 다시
		# 굽지 않고, 수가 달라진 프레임에만 한 번 굽는다 — UPDATE_ALWAYS 로
		# 두면 640x392 짜리 3D 화면을 판 내내 매 프레임 다시 그린다.
		bd_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		for n in bd_nodes:
			if is_instance_valid(n):
				n.queue_free()
		bd_nodes.clear()
		for e in darts:
			var n := Node3D.new()
			_dart3_meshes(n, float(BD3.len) * 0.5, float(BD3.r), float(BD3.fin),
					_dart3_col(String(e.get("id", "std"))))
			bd_vp.add_child(n)
			bd_nodes.append(n)
	for i in mini(bd_nodes.size(), darts.size()):
		if is_instance_valid(bd_nodes[i]):
			bd_nodes[i].transform = _bd3_pose(darts[i])


func _draw_darts() -> void:
	# 렌더러가 있으면 3D 무대를 연다. 없는 자리(헤드리스)에서는 안 열리고
	# 아래 2D 받침이 그대로 선다 — 여는 쪽에서 한 번만 가른다.
	#
	# 가드를 get_viewport() != null 로 두었던 것이 틀렸다. **헤드리스에도
	# 뷰포트는 있다** — 없는 것은 렌더러다. 그래서 검사마다 3D 무대가 열렸고,
	# 프로브가 간헐적으로 세그폴트했다(settle · league · mod 가 번갈아 죽었다).
	# 매번 다른 프로브가 죽어서 원인이 안 보였다. 화면 서버 이름이 그것을
	# 정확히 말하는 유일한 값이다.
	if not _bd3_live() and _has_renderer() and (not darts.is_empty() or state == S.FLY):
		_bd3_open()
	# **비어도 맞춘다.** 판이 바뀌면 darts 만 비고 3D 자루는 뒤에 남아,
	# 새 판 위에 지난 판의 다트가 그대로 꽂혀 있었다(프로브가 잡았다).
	# 맞추는 자리가 하나뿐이라야 그 일이 안 생긴다.
	if _bd3_live():
		_bd3_sync()
		_bd3_fly()
	# 첫 발은 꽂힌 자루가 없다. 나는 자루만 있어도 무대를 그려야 한다.
	if darts.is_empty() and not _bd3_flying():
		return
	if _bd3_live():
		var tex: Texture2D = bd_vp.get_texture()
		if tex != null:
			var sz := _bd3_size()
			# 눕히기 변환이 걸린 채로 그린다 — 판과 같이 눌려야 판 갈이
			# 연출에서 다트만 서 있는 그림이 안 나온다.
			draw_texture_rect(tex, Rect2(Vector2.ZERO, sz), false)
			return
	_draw_darts_2d()


# 3D 가 없을 때의 받침. 같은 투영을 손으로 계산한다 — 자세한 근거는
# 위 구획 주석과 DART_PERSP 에 있다.
func _draw_darts_2d() -> void:
	for e in darts:
		var v: Vector2 = e.p - BC
		var r := v.length()
		var dl := clampf(r * float(DART_PERSP) * 0.5,
				float(DART_MIN), float(DART_MAX))
		# _icon_dart 의 dir 은 촉이 보는 쪽이다. 촉이 판에 박혀 있고 몸통이
		# 바깥으로 뻗으므로 dir 은 **안쪽**을 본다.
		var u := (-v).normalized() if r > 0.001 else Vector2(0.0, 1.0)
		# e.rot 은 자루마다의 손떨림. 이제 절대각이 아니라 방사 방향에 얹는다 —
		# 안 얹으면 가까이 꽂힌 발들이 자로 잰 듯 나란해진다.
		var rot: float = u.angle() - Vector2(6.0, -10.0).angle() + float(e.rot)
		# 촉이 착탄점에 오도록 중심을 뒤로 물린다 — _icon_dart 는 tip = c + dir*dl 이다.
		# 예전에는 선 하나와 점 하나로 그려서 다트가 아니라 압정으로 보였다.
		_icon_dart(e.p - u * dl, dl, e.id, 0.0, rot, 1.0)


func _draw_aim() -> void:
	if state == S.AIM_V or state == S.AIM_H:
		_draw_aim_live()
	elif state == S.CONFIRM:
		_aim_h_line(aim.y, C_ACC)
		_aim_v_line(aim.x, C_ACC)
		if mod_v("fog", 0.0) <= 0.0:
			var e := 1.0 - pow(1.0 - clampf(confirm_t / maxf(ch(), 0.001), 0.0, 1.0), 3.0)
			draw_arc(aim, lerpf(22.0, 7.0, e), 0.0, TAU, 24, C_TXT, 1.0)
			draw_arc(aim, lerpf(30.0, 11.0, e), 0.0, TAU, 24, Color(C_TXT, 0.3), 1.0)
	elif state == S.FLY:
		var k := 1.0 - fly_t / 0.2
		draw_circle(aim, 3.0 + k * 26.0, Color(C_TXT, 0.2 + k * 0.55))


# 조준 중의 그림. 방식마다 **무엇이 잠겼고 무엇이 움직이는지**가 다르다 —
# 잠긴 것은 어둡게, 움직이는 것은 밝게. 이 규칙 하나로 여덟이 다 읽힌다.
func _draw_aim_live() -> void:
	var dim := C_ACC.darkened(0.55)
	var two := state == S.AIM_H
	match aim_mode:
		"ring":
			_aim_circle(BC, aim_r, Color(C_ACC, 0.55) if two else C_ACC)
			if two:
				_aim_dot(aim, C_ACC)
		"tilt":
			var ax := _aim_axes()
			if two:
				_aim_ray(BC + ax[0] * aim_a, ax[1], dim)
				_aim_ray(aim, ax[0], C_ACC)
			else:
				_aim_ray(aim, ax[1], C_ACC)
		"cross":
			_aim_h_line(aim.y, C_ACC)
			_aim_v_line(aim.x, C_ACC)
		"place":
			_aim_dot(aim, C_ACC)
		"kick":
			_aim_dot(aim, C_ACC)
			# 손에서 조준점까지가 **밀린 양**이다. 이 선이 길어질수록 손을
			# 더 내려야 한다 — 얼마나 눌러야 하는지가 그대로 보인다.
			if kick_o.length() > 1.5:
				draw_line(mouse_at, aim, Color(C_ACC, 0.45), 1.0)
				draw_arc(mouse_at, 3.0, 0.0, TAU, 12, Color(C_ACC, 0.55), 1.0)
			# 남은 발. 다 쏘기 전에는 조준을 못 놓는다
			for pi in burst_left:
				draw_rect(Rect2(aim + Vector2(-9.0 + float(pi) * 5.0, 11.0),
						Vector2(3.0, 3.0)), C_ACC)
		"drift":
			# 떠도는 테두리를 같이 보여 준다 — 어디까지 튈 수 있는지가
			# 보여야 "그 안에서 언제 누를까" 가 판단이 된다.
			_aim_circle(mouse_at, R * float(DRIFT.span), Color(C_ACC, 0.45))
			_aim_dot(aim, C_ACC)
		"pull":
			_draw_pull()
		_:
			if two:
				_aim_h_line(aim.y, dim)
				_aim_v_line(aim.x, C_ACC)
			else:
				_aim_h_line(aim.y, C_ACC)


# 당김의 그림. 이 방식의 어려움은 **얼마나 세게 튕겨야 하는지 배울
# 길이 없다**는 것이었다 — 벽에서 판까지가 265px 인데 손에는 아무
# 눈금도 없다. 그래서 셋을 낸다.
#   ① 던지는 줄 위에서 **판에 얹히는 구간**만 밝게 — 점을 그 안에
#      넣으면 된다는 것이 한눈에 보인다. 세기를 가르치는 것은 이것이다
#   ② 착탄점에 **산포 고리** — 같은 자리에 두 번은 못 꽂으므로
#      점 하나로 그리면 없는 정확도를 약속하는 셈이다
#   ③ 힘이 모자라면 빈 점 — 아무것도 안 그리면 고장 난 것으로 읽힌다
func _draw_pull() -> void:
	var org := _pull_org()
	draw_arc(org, 9.0, 0.0, TAU, 20, Color(C_ACC, 0.3), 1.0)
	if pull_at.x < 0.0:
		return
	draw_arc(mouse_at, 5.0, 0.0, TAU, 16, Color(C_ACC, 0.45), 1.0)
	var v := _pull_vec()
	if v.length() < 0.5:
		return
	var u := v.normalized()
	var weak: bool = v.length() < float(PULL.least)
	draw_line(org, aim, Color(C_ACC, 0.16 if weak else 0.26), 1.0)
	# 판에 얹히는 구간 — 이 줄이 판 원을 지나는 두 자리 사이다. 밝기만
	# 달리해서는 판 무늬 위에서 안 갈린다. 양 끝에 눈금을 세워 "여기서
	# 여기까지" 를 눈이 먼저 잡게 한다.
	var f := org - BC
	var bq := f.dot(u)
	var dq := bq * bq - (f.length_squared() - R * R)
	if dq > 0.0:
		var rt := sqrt(dq)
		var t0 := maxf(-bq - rt, 0.0)
		var t1 := maxf(-bq + rt, 0.0)
		if t1 > t0:
			var n := u.orthogonal() * 5.0
			var a0 := org + u * t0
			var a1 := org + u * t1
			draw_line(a0, a1, Color(C_BG, 0.55), 3.0)
			draw_line(a0, a1, C_ACC, 1.0)
			for e in [a0, a1]:
				draw_line(e - n, e + n, Color(C_BG, 0.55), 3.0)
				draw_line(e - n, e + n, C_ACC, 1.0)
	if weak:
		draw_arc(aim, 4.0, 0.0, TAU, 16, Color(C_ACC, 0.4), 1.0)
		return
	_aim_dot(aim, C_ACC)
	draw_arc(aim, float(PULL.spread) + 2.0, 0.0, TAU, 18, Color(C_ACC, 0.4), 1.0)


# 조준용 원. 얇은 선 하나는 판 무늬에 묻힌다 — 판의 삼중 고리와 반지름이
# 겹치면 아예 안 보인다. 어두운 바닥을 깔아 어느 칸 위에서도 뜨게 한다.
# 잠근 원은 색을 어둡게 말고 **옅게** 죽인다. 어둡힌 강조색은 판의 붉은
# 칸과 같은 색이 되어 버린다.
func _aim_circle(c: Vector2, r: float, col: Color) -> void:
	var rr := maxf(r, 1.0)
	draw_arc(c, rr, 0.0, TAU, 48, Color(C_BG, 0.7), 3.0)
	draw_arc(c, rr, 0.0, TAU, 48, col, 1.0)


# 선이 없는 방식의 조준점. 원 하나로는 판의 고리와 헷갈려서 십자를 겹친다.
func _aim_dot(p: Vector2, col: Color) -> void:
	draw_arc(p, 4.0, 0.0, TAU, 16, col, 1.0)
	draw_line(p - Vector2(8.0, 0.0), p + Vector2(8.0, 0.0), col, 1.0)
	draw_line(p - Vector2(0.0, 8.0), p + Vector2(0.0, 8.0), col, 1.0)


# 기울어진 조준선. 가로세로 두 줄이 못 그리는 축을 그린다 — 안개 규칙은
# 같다(판 안쪽이 비고 바깥 꼬리만 남는다).
func _aim_ray(p: Vector2, dir: Vector2, col: Color) -> void:
	var foot := p + dir * (BC - p).dot(dir)
	var h := foot.distance_to(BC)
	var rr: float = R + 8.0
	var far := 151.0
	if mod_v("fog", 0.0) <= 0.0 or h >= rr:
		draw_line(foot - dir * far, foot + dir * far, col, 1.0)
		return
	var cut: float = sqrt(maxf(rr * rr - h * h, 0.0))
	draw_line(foot - dir * far, foot - dir * cut, col, 1.0)
	draw_line(foot + dir * cut, foot + dir * far, col, 1.0)


# 조준선 한 줄. 안개가 걸리면 판 원 안쪽이 비고 바깥 꼬리만 남는다 —
# 확인 텀을 0 으로 만들던 옛 안개는 아무것도 안 바꾸는 것과 같았다.
# 확인 구간은 입력을 안 받는 순수 연출이라 없어져도 티가 안 났던 것이다.
func _aim_h_line(y: float, col: Color) -> void:
	var fog: bool = mod_v("fog", 0.0) > 0.0
	var dy: float = y - BC.y
	var rr: float = R + 8.0
	if not fog or absf(dy) >= rr:
		draw_line(Vector2(BC.x - 151.0, y), Vector2(BC.x + 151.0, y), col, 1.0)
		return
	var cut: float = sqrt(maxf(rr * rr - dy * dy, 0.0))
	draw_line(Vector2(BC.x - 151.0, y), Vector2(BC.x - cut, y), col, 1.0)
	draw_line(Vector2(BC.x + cut, y), Vector2(BC.x + 151.0, y), col, 1.0)


func _aim_v_line(x: float, col: Color) -> void:
	var fog: bool = mod_v("fog", 0.0) > 0.0
	var dx: float = x - BC.x
	var rr: float = R + 8.0
	if not fog or absf(dx) >= rr:
		draw_line(Vector2(x, 68.0), Vector2(x, 334.0), col, 1.0)
		return
	var cut: float = sqrt(maxf(rr * rr - dx * dx, 0.0))
	draw_line(Vector2(x, 68.0), Vector2(x, BC.y - cut), col, 1.0)
	draw_line(Vector2(x, BC.y + cut), Vector2(x, 334.0), col, 1.0)


func _draw_topbar() -> void:
	var r: Rect2 = LAY.bar
	draw_rect(r, C_PANEL)
	draw_rect(Rect2(Vector2(0.0, r.size.y - 1.0), Vector2(r.size.x, 1.0)), C_BG)
	# 1px 두 줄이 "칸이 나뉘어 있다"를 만드는 전부다. 640x360 에서 테두리는 사치다.
	for cx in LAY.bar_cut:
		draw_line(Vector2(cx, 3.0), Vector2(cx, 15.0), C_BG, 1.0)

	# 1칸 x[0,100] — 런 진행
	draw_string(font, Vector2(8, 13), "R%d/%d"
			% [GameData.round_of(leg_no), GameData.rounds_n()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TXT)
	# 칸은 **판** 여덟이다. 판 스물넷을 다 찍으면 44 + 7x23 + 5 = 210px 라
	# 목표 게이지(x 146~506)를 밀고 들어간다. 대신 지금 판의 칸을 넘긴
	# 판 수만큼 아래에서 채운다 — 5px 를 셋으로 나누면 한 판이 1.67px 이고,
	# nearest 에서 0/2/3/5 로 떨어져 세 단이 실제로 갈린다.
	var round := GameData.round_of(leg_no)
	var per := GameData.legs_per_round()
	var done_b: int = GameData.leg_idx(leg_no) \
			+ (1 if (state == S.CLEAR or state == S.SHOP) else 0)
	var pip: Rect2 = LAY.bar_pip
	for i in GameData.rounds_n():
		var q := Rect2(pip.position + Vector2(float(i) * LAY.bar_pip_dx, 0.0), pip.size)
		if i < round - 1:
			draw_rect(q, C_ACC)
		elif i == round - 1:
			draw_rect(q, C_ACC.darkened(0.62))
			if done_b > 0:
				var h := q.size.y * float(mini(done_b, per)) / float(per)
				draw_rect(Rect2(q.position + Vector2(0.0, q.size.y - h),
						Vector2(q.size.x, h)), C_ACC)
			draw_rect(q, C_ACC, false, 1.0)
		else:
			draw_rect(q, C_BG)

	# 2칸 x[100,584] — 목표. 진행바 좌표는 기존 그대로다.
	var g: Rect2 = LAY.bar_gauge
	draw_string(font, Vector2(104, 13), GameData.leg_name(leg_no),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			C_ACC if GameData.is_boss(leg_no) else C_DIM.darkened(0.2))
	draw_rect(g, C_BG)
	if state == S.SHOP or state == S.STAGE:
		# STAGE 에서 목표 숫자를 쓰면 안 된다 — 등급 배수(극한 ×1.25)가
		# 아직 안 정해졌고 카드 셋이 서로 다른 숫자를 이미 크게 띄운다.
		var msg := "판을 고르는 중"
		if state == S.SHOP:
			msg = "다음 %s  ·  목표 %d" % [GameData.leg_name(leg_no + 1),
				GameData.target_of(leg_no + 1)]
		draw_string(font, Vector2(g.position.x, 13.0), msg,
				HORIZONTAL_ALIGNMENT_CENTER, g.size.x, 10, C_DIM)
	else:
		var k := clampf(shown / float(maxi(target, 1)), 0.0, 1.0)
		draw_rect(Rect2(g.position, Vector2(g.size.x * k, g.size.y)), C_ACC)
		draw_string(font, Vector2(LAY.bar_score, 13.0),
				"%d / %d" % [int(round(shown)), target],
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
		var k := clampf(float(_run_done()) / float(GameData.legs_n()), 0.0, 1.0)
		draw_rect(Rect2(r.position, Vector2(r.size.x * k, 2.0)), C_ACC)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), C_GOLD.darkened(0.35))
	# deny_flash 는 상점 중앙 골드 텍스트가 쓰던 값을 그대로 물려받는다
	var gc: Color = C_GOLD.lerp(C_MULT, deny_flash)
	var jx := randf_range(-deny_flash, deny_flash) * 2.0
	draw_gold(r.get_center().x + jx, r.position.y + 26.0, str(gold), 16, gc)

	# 이자 줄은 판이 늘어난 화면에서만 담긴다.
	if r.size.y < 46.0:
		return

	# 이자 미리보기. 계산식은 _finish_leg 와 같고 둘 다 지급 전 잔액을 본다.
	if state == S.SHOP and leg_no + 1 >= GameData.legs_n():
		# R8 은 정산이 없다 (_finish_leg 의 leg_no >= ROUNDS 조기 return 이
		# 골드 지급 블록보다 앞선다). 남긴 골드는 영원히 안 돌아온다.
		draw_string(font, r.position + Vector2(0.0, 42.0), "마지막 판",
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, C_MULT.lightened(0.2))
	else:
		@warning_ignore("integer_division")  # 위 _finish_leg 와 같은 식이어야 한다
		var itr: int = mini(gold / GameData.interest_per(), _interest_cap())
		draw_string(font, r.position + Vector2(0.0, 42.0), "이자 +%d" % itr,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9,
				C_GOLD.darkened(0.3) if itr > 0 else C_DIM.darkened(0.35))


# ── 동전 꼬리표 ─────────────────────────────────────────────
func _cap_draw() -> void:
	var r: Rect2 = LAY.cap
	r.position.y += _hud_dy()
	draw_rect(r, C_FELT)                                   # 동전 슬롯과 같은 재질
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), C_FELT.lightened(0.14))
	draw_string(font, r.position + Vector2(0.0, 18.0), "동전",
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, C_DIM.darkened(0.1))
	draw_string(font, r.position + Vector2(0.0, 36.0),
			"%d/%d" % [owned.size(), GameData.max_items()],
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13,
			C_ACC if owned.size() >= GameData.max_items() else C_TXT)


# ══════════════════════════════════════════════════════════
#  동전 슬롯  (아이템 패널)
# ──────────────────────────────────────────────────────────
#  바깥과 닿는 곳은 이 넷뿐이다.
#    _panel_fire(i)    아이템이 발동할 때        (_next_step)
#    _panel_update(d)  매 프레임 진행           (_process)
#    _panel_draw()     매 프레임 그리기          (_draw, _draw_stage)
#    _panel_reset()    판 시작 시 정지        (_start_leg)
#  owned / sealed 를 읽기만 하고 게임 상태는 건드리지 않는다.
#  그래서 이 구획만 지우고 다시 써도 나머지는 영향을 안 받는다.
#
#  아이템은 원형 동전다. 골드는 동전이 아니라 플라크로 그린다
#  (draw_gold). 원반과 직사각으로 형태를 갈라 둘을 안 헷갈리게 한다.
# ══════════════════════════════════════════════════════════

# 감각 조정은 이 표에서만 한다.
const PANEL := {
	# 배치
	"y": 20.0,           # 동전 슬롯 위쪽. 아래 y[56,112] 가 상인 자리다
	# 높이 46 을 38 로 줄인 것은 상인 때문이다. 동전 슬롯 아래끝(58)과 카운터(77)
	# 사이의 19px 이 머리가 들어갈 유일한 자리다 — 동전 슬롯을 그대로 두면 실루엣이
	# 통째로 동전 슬롯 뒤에 숨어 "누가 판다" 가 화면에서 안 읽힌다.
	# 높이 32 → 36, 칸 42 → 56. 플레이 피드백이 "아이템 칸이 너무 작다"
	# 였고, 실제로 칸 밑 이름이 서로 겹쳐 안 읽혔다(실측). 동전 슬롯은 넓히되
	# **가운데를 지킨다** — 상인 윗머리(y<36 반폭 111 = x[209,431])가
	# 동전 슬롯 뒤에 숨는 것이 실루엣의 전제라 옮기면 벽으로 샌다.
	"h": 44.0,           # 동전 슬롯 높이
	"cell": 62.0,        # 동전 한 칸 폭
	"pad": 6.0,          # 동전 슬롯 안쪽 여백
	"r": 19.0,           # 동전 반지름
	"chip_dy": -1.0,     # 칸 안에서 동전 중심을 얼마나 올릴지

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

# 등급(가격)별 동전 — 명도가 단조 하강해서 저해상도에서도 순서가 읽힌다.
#
#  원래는 노름기본 점수이었다. 대회 제출본에서 사행성 기호를 걷어내며 동전로
#  갈았는데 실루엣(원반)은 한 픽셀도 안 건드렸다 — 낙하 솔버·동전 슬롯·컬렉션이
#  전부 "원 하나" 를 전제로 서 있어서, 여기만 바꾸면 나머지가 안 흔들린다.
#  갈린 것은 테두리 어법 하나다: 가장자리 스팟(기본 점수를 기본 점수으로 만들던 유일한
#  표식)을 빼고 다이컷 흰 테두리를 둘렀다.
#
#  등급의 둘째 신호는 마감(fin)이다 — 0 매트 · 1 유광 · 2 홀로그램.
#  색만으로는 저해상도에서 두 단이 붙는데, 마감은 형태라 안 붙는다.
#  단은 **희귀도 열이 정한다.** 가격으로 재던 것을 옮겼다 — 가격은 등급을
#  따라가는 것이 기본이지만 예외가 있고(변덕쟁이·빈손은 희귀인데 7골드),
#  검증기는 4·7·11·14 만 대조하므로 5골드·8골드 짜리는 아예 안 본다.
#  그 틈으로 다섯 장이 얼굴에 틀린 단을 달고 있었다: 5골드 흔함이 유광,
#  8골드 흔함·보통이 홀로그램으로 찍혔다. 값이 아니라 등급을 그려야
#  "이 카드가 얼마나 귀한가" 가 얼굴과 데이터에서 같은 말을 한다.
const STK_TIERS := [
	{"rarity": "common", "body": "ded5c0", "fin": 0},
	{"rarity": "uncommon", "body": "7d5ad0", "fin": 1},
	{"rarity": "rare", "body": "241e33", "fin": 2},
	# 전설 — 홀로그램을 부채 셋이 아니라 온 바퀴로 두른다. 같은 어법의
	# 한 단 위라 새 표식을 배우지 않아도 "홀로보다 더" 로 읽힌다.
	{"rarity": "legendary", "body": "3a1030", "fin": 3},
]
const C_DIECUT := Color("f4f0e6")   # 다이컷 테두리. 이 흰 띠 하나가 "동전"를 말한다
const C_LINER := Color("efe9db")    # 이형지 뒷면 — 말릴 때만 보인다. 인쇄가 없다
const HOLO := [Color("74d6ea"), Color("ef86c6"), Color("ffd873")]
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
var grip_t := 0.0               # 판 시작 후 경과 — 날아와 꽂히는 연출용
var grip_slot := []             # remaining[i] 가 벽의 몇 번 칸에 꽂혀 있는가
var grip_n := 0                 # 이번 판 시작 자루 수 — 칸 배치의 기준
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


# 동전 하나가 빠졌다. 스프링 셋도 같이 밀어낸다 — owned 와 인덱스를
# 공유하므로, 안 밀면 뒤 동전이 앞 동전의 스프링을 물려받는다.
# 통째로 0 으로 돌리는 길(_panel_reset)은 상점에서만 안전했다: 판 위에서는
# 발동 스프링이 살아 있어 애니메이션이 그 자리에서 튄다. 이제 어디서든
# 파므로 밀어내는 쪽이 맞다.
func _panel_pull(i: int) -> void:
	_panel_ensure()
	if i < 0 or i >= slot_pop.size():
		return
	for arr in [slot_pop, slot_vel, slot_hot]:
		arr.remove_at(i)
		arr.append(0.0)


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
	peel_t += d


# 칸 폭. 다섯까지는 62 고정이고, 그 위로는 좁혀서 이웃을 안 밟는다.
#
# 62 는 원래 이름 때문에 잡은 값이었다 — "칸 42 → 56 은 칸 밑 이름이
# 서로 겹쳐 안 읽혔다(실측)" 가 위 주석이다. 그런데 그 이름은 지금
# 없다(봉인·호버일 때만 뜬다). 그래서 남은 하한은 그리는 것의 크기다:
# 동전 원반 지름 38 과 호버 링 지름 42. 46 이면 링 양옆에 2px 이
# 남는다 — 그 아래로는 링이 칸 밖으로 샌다.
#
# 위 한계는 이웃이다. 왼쪽 사탕 칸이 152 에서 끝나고 오른쪽 수용량
# 꼬리표가 490 에서 시작하므로 동전 슬롯이 쓸 수 있는 폭은 334 다.
const PANEL_CELL_MIN := 46.0
const PANEL_SPAN := 330.0     # 사탕(152)와 꼬리표(490) 사이, 여유 2px 씩
# 동전 슬롯 판의 최소 폭. 상인 윗머리가 x[209,431] 이라 그것을 덮으려면 222 가
# 필요하다. 칸이 셋 이하로 줄면 칸만으로는 그 폭이 안 나오고, 그때
# 머리가 동전 슬롯 밖으로 새어 실루엣이 통째로 무너진다 — 칸 수와 판 폭을
# 갈라 둔 이유가 그것이다. 판은 늘 이만큼이고 칸은 그 안에서 가운데다.
const PANEL_W_MIN := 228.0


func _panel_cell() -> float:
	var n: int = maxi(GameData.max_items(), 1)
	return clampf((PANEL_SPAN - PANEL.pad * 2.0) / float(n),
			PANEL_CELL_MIN, float(PANEL.cell))


func _panel_rect() -> Rect2:
	# _slot_rect 가 이걸 파생하므로 판매 판정·툴팁 앵커·구매 비행 목표가
	# 전부 따라온다. 좌표 소유자를 안 늘리는 자리다.
	#
	# **가운데를 지킨다.** 상인 윗머리(y<36 반폭 111 = x[209,431])가 동전 슬롯 뒤에
	# 숨는 것이 실루엣의 전제다. 한쪽으로 붙여 키우면 칸 수가 줄었을 때
	# 머리가 동전 슬롯 밖으로 새고, 그건 여섯 번 다시 그린 자리다.
	var n: int = GameData.max_items()
	var w: float = maxf(_panel_cell() * float(n) + PANEL.pad * 2.0, PANEL_W_MIN)
	return Rect2(Vector2((VIEW.x - w) * 0.5, PANEL.y + _hud_dy()), Vector2(w, PANEL.h))


func _slot_rect(i: int) -> Rect2:
	var pr := _panel_rect()
	# 칸은 판 안에서 **가운데** 정렬이다. 판이 최소 폭에 걸려 칸보다
	# 넓어질 수 있으므로 왼쪽에서 재면 오른쪽에 빈 띠가 남는다.
	var cw: float = _panel_cell()
	return Rect2(Vector2(pr.get_center().x
			- cw * float(GameData.max_items()) * 0.5 + float(i) * cw,
			pr.position.y),
			Vector2(cw, pr.size.y))


func _stk_ti(rarity: String) -> int:
	for i in STK_TIERS.size():
		if String(STK_TIERS[i].rarity) == rarity:
			return i
	return 0


# 조건 그림 — 동전이 "언제" 터지는가를 얼굴에 새긴다.
#
# 지금까지 동전은 값(얼마나)만 보였다. 그래서 등급·잉크·숫자가 같으면
# 조건이 정반대여도 똑같이 보였다 — 홀수 애호와 짝수 애호, 좌익수와 우익수가
# 화면에서 구분 불가였다. 재미의 절반은 조건 쪽인데 그게 안 그려지고 있었다.
#
# 열여섯 조건을 원시 도형만으로 가른다. 글자는 안 쓴다 — 동전 슬롯 반지름 15 에서
# 얼굴에 남는 자리가 지름 17px 라 한글은 물론 숫자도 둘은 안 들어간다.
# 갈리는 축을 도형 갈래로 나눠 뒀다: 선 / 점 / 반원 / 삼각 / 원 / 원쌍 / 막대 / X.
# 같은 갈래 안에서만 개수와 방향으로 갈리므로 실루엣이 먼저 읽힌다.
func _icon_cond(c: Vector2, r: float, cond: String, col: Color) -> void:
	var u := r * 0.62          # 도형 반경 — 얼굴 안에 머무는 상한
	# 숫자 지정 조건 — 숫자가 곧 아이콘이다. 셋 넘으면 첫 수에 점을 단다.
	if cond.begins_with("col:"):
		# 색 조건은 글자가 아니라 칠로 말한다. 쓰는 색을 나란히 눕힌다.
		var cs := cond.substr(4).split(",")
		var bw: float = r * 1.7 / float(maxi(cs.size(), 1))
		for k in cs.size():
			draw_rect(Rect2(c.x - r * 0.85 + float(k) * bw, c.y - u * 0.6,
					bw - 1.0, u * 1.2), Color(GameData.color_hex(int(cs[k]))))
		return
	if cond.begins_with("sec:"):
		var parts := cond.substr(4).split(",")
		var txt := "·".join(parts) if parts.size() <= 2 else parts[0] + "…"
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
			# 동전 슬롯 r=15 → r_icon 6.30 → u 3.906. 두 호의 중심 간격 2.227px,
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


# 아이템 하나를 동전로 그린다. 동전 슬롯과 상점이 같은 그림을 쓰도록 여기 하나로 모았다.
func draw_item_sticker(c: Vector2, r: float, it: Dictionary, rot: float, lift: float,
		dim: float, num_sz: int, peel := 0.0) -> void:
	var ti := _stk_ti(String(it.get("rarity", "common")))
	draw_sticker(c, r, STK_TIERS[ti], rot, lift, it.get("g", "") != "", dim, peel)
	var y := _peel_y(r, peel)
	# 등급 고리. 색은 rarity.csv 가 정한다 — 정의만 있고 아무도 안 부르던
	# rarity_color() 가 이 한 줄로 산다. 흔함은 안 그린다(고리가 곧 "귀하다").
	# 말린 상태에서는 접는 선 위쪽만 그린다 — 아래로 넘어가면 떨어져 나간
	# 자리에 인쇄가 떠서 종이가 아니라 유령이 된다.
	if String(it.get("rarity", "common")) != "common":
		var rr := r - 3.0
		var t2: float = asin(clampf(y / rr, -1.0, 1.0)) if y < rr else PI * 0.5
		draw_arc(c, rr, PI - t2, TAU + t2, 24,
				Color(GameData.rarity_color(String(it.rarity)), 1.0 - dim), 1.0)
	# 얼굴을 위아래로 가른다 — 위는 조건(언제 터지는가), 아래는 값(얼마나).
	# 값만 있으면 조건이 정반대인 짝이 똑같이 보인다.
	var ink: Color = C_CHIP.lightened(0.5) if it.k == "chip" else C_MULT.lightened(0.45)
	_icon_cond(c + Vector2(0.0, -r * 0.33), r * 0.42, String(it.c), ink.darkened(dim + 0.08))
	var val := ("×" + str(it.v)) if it.k == "xmult" else str(it.v)
	var vs: int = maxi(7, int(float(num_sz) * 0.84))
	var vy := r * 0.34 + float(vs) * 0.34
	if vy + 2.0 < y:
		draw_string(font, c + Vector2(-r, vy), val,
				HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, vs, ink.darkened(dim))
	# 말린 끝은 인쇄를 덮는다. 그래서 맨 마지막이다 — 순서가 곧 물리다.
	_peel_fold(c, r, peel, dim)


# 동전 몸통. 동전 슬롯·테이블·툴팁·컬렉션이 같은 그림을 쓰도록 여기 하나로 모았다.
#  gold_rim — 골드를 버는 동전은 다이컷을 금박으로 찍는다. 링을 하나 더
#  두르지 않는 이유는 반지름 13px 에 고리 셋(다이컷·등급·골드)이 들어가면
#  1.5px 간격으로 뭉개져 셋 다 안 읽히기 때문이다. 테두리 색은 공짜다.
func draw_sticker(c: Vector2, r: float, tier: Dictionary, rot: float,
		lift: float, gold_rim: bool, dim: float, peel := 0.0) -> void:
	var body := Color(tier.body).darkened(dim)
	var rim: Color = (C_GOLD if gold_rim else C_DIECUT).darkened(dim)
	var rw: float = clampf(r * 0.16, 1.0, 2.2)      # 다이컷 폭. r=8 툴팁에서도 안 뭉갠다
	var y := _peel_y(r, peel)

	# 종이라 옆면이 없다. 들리면 두께 대신 그림자만 자란다 — 기본 점수의 원기둥
	# 옆면(1.5px)을 그대로 두면 두꺼운 원반으로 되돌아간다.
	if lift > 0.05:
		draw_circle(c + Vector2(0.0, lift), r, Color(0.0, 0.0, 0.0, 0.22))

	_disc_seg(c, r, y, rim)                         # 다이컷 테두리
	# 인쇄 가장자리 1px. 흔함(크림 ded5c0)과 다이컷(f4f0e6)은 명도차가 9% 뿐이라
	# 이 줄이 없으면 둘이 한 덩어리 흰 원으로 뭉개진다. 나머지 두 등급은 대비가
	# 충분하지만 같은 그림을 쓰는 편이 어법이 안 갈린다.
	_disc_seg(c, r - rw, y, body.darkened(0.34))
	_disc_seg(c, r - rw - 1.0, y, body)             # 인쇄면

	# 마감. 각 규약은 annulus_at 그대로다(0 = 12시, 시계 방향) — 둘 다 왼쪽
	# 위를 향하므로 접는 선(아래) 아래로 새지 않는다. peel 을 안 봐도 된다.
	var fa := 1.0 - dim
	match int(tier.fin):
		1:
			# 유광 — 왼쪽 위 대각 초승달 하나
			draw_colored_polygon(annulus_at(c, r * 0.50, r - rw - 0.3,
					rot - 1.45, rot - 0.35, 6), Color(1.0, 1.0, 1.0, 0.32 * fa))
		2:
			# 홀로그램 — 가운데서 퍼지는 무지개 부채 셋
			for k in 3:
				var a := rot - 1.85 + float(k) * 0.72
				draw_colored_polygon(annulus_at(c, r * 0.20, r - rw - 0.3,
						a, a + 0.46, 4), Color(HOLO[k], 0.55 * fa))
		3:
			# 전설 — 같은 무지개를 온 바퀴로. 부채가 끊기지 않으므로
			# 홀로그램 옆에 두면 "다 덮였다" 가 곧 한 단 위로 읽힌다.
			for k in 6:
				var a2 := rot + float(k) * (TAU / 6.0)
				draw_colored_polygon(annulus_at(c, r * 0.20, r - rw - 0.3,
						a2, a2 + TAU / 6.0, 4),
						Color(HOLO[k % 3], 0.42 * fa))


# 접는 선의 높이(중심 기준 아래 방향). peel 1 이면 거의 다 말린다.
func _peel_y(r: float, peel: float) -> float:
	return r * (1.0 - clampf(peel, 0.0, 1.0) * 0.78)


# 원반에서 접는 선 위쪽만 채운다(활꼴). y >= r 이면 그냥 정원이라
# peel 0 인 흔한 경로에서 폴리곤을 안 만든다.
func _disc_seg(c: Vector2, r: float, y: float, col: Color) -> void:
	if y >= r - 0.4:
		draw_circle(c, r, col)
		return
	var t := asin(clampf(y / r, -1.0, 1.0))
	var pts := PackedVector2Array()
	for i in 21:
		var a: float = (PI - t) + (PI + 2.0 * t) * float(i) / 20.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, col)


# 동전을 떼면 아래 끝이 위로 말린다. 아래 활꼴을 접는 선에 대해 미러링하는
# 것이 전부다 — 종이접기 그대로라 곡률을 풀 일이 없다. 뒤집힌 쪽은 이형지라
# 인쇄가 없고, 그래서 얼굴 위에 겹쳐도 무엇이 가려졌는지가 안 헷갈린다.
func _peel_fold(c: Vector2, r: float, peel: float, dim: float) -> void:
	var y := _peel_y(r, peel)
	if y >= r - 0.6:
		return
	var t := asin(clampf(y / r, -1.0, 1.0))
	var pts := PackedVector2Array()
	for i in 17:
		var a: float = t + (PI - 2.0 * t) * float(i) / 16.0
		var q := Vector2(cos(a), sin(a)) * r
		pts.append(c + Vector2(q.x, y - (q.y - y)))
	draw_colored_polygon(pts, C_LINER.darkened(dim))
	# 접힌 가장자리 — 이형지와 얼굴을 가른다. 색 대비만으로는 흔함 등급에서
	# 둘이 붙는다(크림 vs 이형지 명도차 8%). 선이 대비를 대신한다.
	for i in pts.size() - 1:
		draw_line(pts[i], pts[i + 1], Color(0.0, 0.0, 0.0, 0.30), 1.0)
	# 접는 선 = 아직 붙어 있는 마지막 자리. 이 한 줄이 없으면 뒷면이 그냥
	# 얼굴 위에 뜬 밝은 반달로 보인다.
	var hx := sqrt(maxf(r * r - y * y, 0.0))
	draw_line(c + Vector2(-hx, y), c + Vector2(hx, y),
			Color(0.0, 0.0, 0.0, 0.45), 1.0)


# ── 플라크 (통화) ─────────────────────────────────────────
#  동전보다 위 등급인 직사각 화폐판. 아이템이 원반이므로 통화는
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


# 플라크와 수 사이. 크기에 비례해야 22pt 정산 총액과 9pt 값뱃지가 같은
# 밀도로 읽힌다 — 4px 로 못 박아 두면 큰 쪽만 붙어 보인다. 재는 쪽과
# 그리는 쪽이 같은 값을 봐야 가운데·오른쪽 정렬이 안 어긋난다.
func gold_gap(size: int) -> float:
	return maxf(4.0, float(size) * 0.30)


func gold_w(n: String, size: int) -> float:
	return float(size) * 0.85 + gold_gap(size) \
			+ font.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


# 왼쪽 정렬로 그리고 차지한 폭을 돌려준다 — 문장 중간에 끼워 넣을 때 쓴다.
func draw_gold_at(x: float, y: float, n: String, size: int, c: Color) -> float:
	var iw := float(size) * 0.85
	draw_plaque(Vector2(x, y - float(size) * 0.62), iw, iw * 0.64, c)
	draw_string(font, Vector2(x + iw + gold_gap(size), y), n,
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
			if hand_st == H.CARRY and hand_src == 1 and i == hand_i:
				_panel_gap(i)     # 지금 손에 들려 있다. 자리에는 자국만 남는다
			else:
				_panel_slot(i)
		else:
			# 빈 자리는 비워 둔다. 동그란 홈을 파 두었더니 "여기 뭔가 있다"
			# 로 읽혔다 — 발라트로도 빈 조커 칸에 아무것도 안 그린다.
			# 칸이 몇인지는 카운터가 이미 말한다.
			pass
	_sell_btn_draw()


# 상점 밖의 판매 버튼. 창구가 하는 말("판매 +N")을 그대로 한다.
func _sell_btn_draw() -> void:
	var r := _sell_btn_rect()
	if r.size.x <= 0.0:
		return
	var hot: bool = hand_st == H.ARMED and hand_src == 5
	var v := GameData.sell_value(owned[sell_sel])
	draw_rect(Rect2(r.position + Vector2(1.0, 2.0), r.size), Color(0.0, 0.0, 0.0, 0.35))
	draw_rect(r, C_PANEL.lightened(0.12 if hot else 0.02))
	# 위쪽 한 획 — 리롤·다음 판 버튼과 같은 어법이라 "버튼"으로 읽힌다.
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), C_ACC if hot else C_GOLD)
	draw_gold(r.position.x + r.size.x * 0.5, r.position.y + r.size.y - 3.0,
			"+%d" % v, 9, C_GOLD)


# 동전 i 의 고정 기울기 계수(-0.5~0.5). 인덱스로만 결정되므로 프레임 간 안 흔들린다.
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

	draw_item_sticker(c, r, it, bounce * PANEL.spin, up * PANEL.lift,
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

	# 상점에서는 동전 슬롯이 매물대가 된다 — 태그 자리에 회수액을 건다.
	# 상점 밖에서는 안 쓴다. 파는 값은 판매 버튼이 이미 말하고(_sell_btn_draw),
	# 둘 다 켜면 같은 수가 두 번 붙는다. "평소엔 아무 글자도 안 쓴다"
	# 규칙(아래 주석)이 사는 자리도 그래서 여기다.
	if _can_sell() and state == S.SHOP:
		draw_gold(cell.get_center().x, cell.position.y + cell.size.y - 3.0,
				str(GameData.sell_value(it)), 9,
				C_ACC if sel else C_GOLD.darkened(0.30))
		return

	# 평소엔 아무 글자도 안 쓴다. 조건은 동전 얼굴의 아이콘이 이미
	# 말하고, 칸 밑에 문장을 깔면 동전에 눌려 조각으로 읽힌다(실측).
	# 발라트로도 조커 밑에 글자를 안 둔다 — 카드가 곧 이름이다.
	# 글자가 뜨는 것은 상태 둘뿐이다: 봉인됐거나, 지금 보고 있거나.
	var label := ""
	var col: Color = C_DIM.darkened(0.15)
	if lock:
		label = "봉인"
		col = C_MULT.darkened(0.2)
	elif slot_hot[i] > 0.0:
		label = it.n
		col = C_TXT
	if label == "":
		return
	# 그래도 넘치면 뒤를 자른다 — draw_string 은 폭을 넘으면 가운데를
	# 잘라 조각을 남기므로, 자를 자리는 우리가 고른다.
	draw_string(font, cell.position + Vector2(0.0, cell.size.y - 3.0),
			_elide(label, cell.size.x - 2.0, 9),
			HORIZONTAL_ALIGNMENT_CENTER, cell.size.x, 9, col)


# 폭에 맞게 뒤를 자른다. 자른 티를 내야 "짧은 이름" 과 안 헷갈린다.
func _elide(t: String, w: float, sz: int) -> String:
	if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x <= w:
		return t
	var out := ""
	for i in t.length():
		var cand := out + t[i] + "…"
		if font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > w:
			break
		out += t[i]
	return out + "…"



# ══════════════════════════════════════════════════════════
#  판매 (동전 슬롯 → 골드)
# ──────────────────────────────────────────────────────────
#  바깥과 닿는 곳은 셋뿐이다.
#    _sell_hit(m)   동전 슬롯 클릭 판정          (_click 의 S.SHOP)
#    _can_sell()    지금 팔 수 있는가      (_panel_slot / _tip_build / _process)
#    sell_sel       고른 칸 (-1 = 없음)
#
#  두 번 눌러야 팔린다. 첫 클릭은 동전(동전 슬롯 안), 두 번째는 왼쪽 창구다.
#  두 표적이 물리적으로 갈려 있어 더블클릭이 판매로 흘러들 수 없다 —
#  같은 자리를 두 번 누르는 방식이었다면 필요했을 타이머가 여기선 필요 없다.
#  판매판이 자금 판 바로 옆인 것도 의도다. 파는 건 물건 옆이 아니라 지갑 옆이다.
#
#  S.CLEAR 에는 절대 붙이지 않는다 — 정산 지급(_finish_leg 의 gold +=)이
#  이미 끝난 시점이라 골드 동전의 "받고 즉시 되팔기" 창이 열린다.
# ══════════════════════════════════════════════════════════

var sell_sel := -1
var sell_t := 0.0               # 선택 링 맥동에만 쓴다
var stage_slots := 0
var stage_stand := []           # 카드마다 0(누움) ~ 1(섬)
# 이번 프레임의 흔들림 이동. 카드 얼굴이 제 변환을 걸 때 여기에 겹치고,
# 끝나면 이 값으로 되돌린다 — 안 되돌리면 남은 변환이 HUD 를 통째로 민다.
var shake_off := Vector2.ZERO

# ── 판 선택 ──────────────────────────────────────────────
#  라운드의 세 판을 늘어놓고 지금 판을 던지거나 건너뛴다. 건너뛰면 점수도
#  골드도 없고 대신 뱃지를 받는다 — 그 교환이 이 화면의 전부다.
#  보스 판은 못 건너뛴다(legs.csv 의 skippable 이 문이고, 검증기가
#  마지막 판만 0 인 것을 강제한다).
var leg_tag := {}             # 지금 건너뛰면 받을 뱃지. 화면에 미리 보인다
# 판 번호 → 그 판을 건너뛰면 받을 뱃지. **라운드에 들어올 때 한꺼번에 굴린다.**
# 지금 판만 굴리면 "뒤 판을 건너뛰면 뭘 받나" 를 화면에 못 적는다 — 그걸
# 모르면 지금 판을 건너뛸지 말지도 못 정한다. 셋을 같이 보고 고르는 것이
# 이 화면의 일이다. 라운드가 바뀔 때까지 값이 안 흔들려야 그 비교가 선다.
var leg_tags := {}
var leg_tags_round := 0
# 건너뛴 판. 지난 판의 자리를 비우면 "내가 무엇을 골랐더라" 가 화면에서
# 사라진다 — 셋을 비교해 고르는 화면인데 고른 흔적만 없어지는 셈이다.
var leg_skipped := {}
var pending_tags := []          # 나중에 쓸 뱃지들 [{kind, v, when, n}]
var leg_t := 0.0              # 화면이 열린 뒤 흐른 시간(카드 미끄러짐)            # 스테이지 화면에 들어설 때의 동전 개수
var stage_t := 0.0              # 카드가 깔리는 경과. _open_stage 에서 0 으로 선다


func _can_sell() -> bool:
	# 어디서든 판다. 파는 자리가 창구 하나뿐이라 상점 전용이었는데,
	# 그러면 판에 서고 나서는 자기 정산식을 줄일 수 없다 — 순서는
	# 아무 때나 바꾸는데(_can_rack_move) 빼는 것만 못하는 건 어긋난다.
	# 조커를 아무 때나 파는 그 문법으로 맞춘다.
	#
	# 창구는 상점에만 있으므로 상점 밖에서는 **고른 동전 아래의 판매
	# 버튼**이 그 일을 한다(_sell_btn_rect). 두 자리가 같은 _sell 을 부른다.
	return _can_rack_move()


# 동전 슬롯 순서를 지금 바꿀 수 있는가. **파는 것과 갈라 둔다.** 파는 자리는 창구
# 하나뿐이라 상점 전용이지만, 순서는 발동 규칙이라 판 위에서도 만진다 —
# 발동이 동전 슬롯 순서인데(16쪽) 순서를 상점에서만 만질 수 있으면 판에 서고
# 나서는 자기 정산식을 못 고친다. 조커를 아무 때나 끄는 그 문법이다.
#
# 막는 자리는 넷뿐이다.
#   · 동전 슬롯이 안 그려지는 화면 — _hud_draw 가 거르는 것들과 CLEAR
#   · 전환·쓸기 — 입력을 통째로 삼키는 두 연출
#   · RESOLVE — queue 가 owned 인덱스(k=item 의 i)를 들고 있다. 끼워 넣으면
#     엉뚱한 동전이 카드에 뜬다. 「득점 시작 시 순서 스냅샷」이 여기서
#     지켜진다. 큐는 다트가 꽂힐 때 세워지므로 FLY 까지는 열어 둬도 된다
#   · 연발이 도는 중 — 커서가 곧 조준이라(kick) 끄는 손이 남은 발을 끌고 간다
func _can_rack_move() -> bool:
	if swap_live or sweep_live or state == S.RESOLVE or burst_left > 0:
		return false
	return state == S.SHOP or state == S.STAGE or state == S.LEG or _is_play()


func _sell_hit(m: Vector2) -> bool:
	# 동전 슬롯 y[44,76] 은 테이블 y[104,236] · 스테이지 카드 y[112,264] 와 y 로 갈려
	# 있어 먼저 검사해도 그쪽 클릭을 훔칠 수 없다.
	# (판매판 분기가 여기 있었다 — _can_sell 이 SHOP 전용이 되면서 영원히
	#  못 닿는 가지가 됐고, 그리는 쪽 _sell_draw 도 호출이 0이었다. 걷어냈다.)
	if not _can_sell():
		return false
	for i in GameData.max_items():
		if _slot_rect(i).has_point(m):
			sell_sel = -1 if (sell_sel == i or i >= owned.size()) else i
			sell_t = 0.0
			_sfx("rack_select")
			return true
	sell_sel = -1                   # 딴 데를 누르면 선택만 풀고 그대로 흘려보낸다
	return false


func _sell(i: int) -> void:
	if i < 0 or i >= owned.size():
		return
	var v := GameData.sell_value(owned[i])
	var at := _slot_rect(i).get_center()
	gold += v
	Save.bump("sold")
	Save.bump("gold_earned", v)
	owned.remove_at(i)
	sell_sel = -1
	# sealed 는 owned 의 인덱스다. 이제 판 위에서도 파므로 살아 있는 값일
	# 수 있다 — 지우지 말고 **같이 밀어야** 봉인이 같은 동전에 남는다.
	# 판 것이 봉인이었으면 그때만 지운다.
	if sealed == i:
		sealed = -1
	elif sealed > i:
		sealed -= 1
	# slot_pop/slot_vel/slot_hot 도 owned 와 인덱스를 공유한다. 같이 밀어야
	# 뒤 동전이 앞 동전의 스프링을 물려받지 않는다.
	_panel_pull(i)
	pop(at + Vector2(0.0, -14.0), "+%d" % v, C_GOLD, 15, 0.8)
	_sfx("sell")


# ══════════════════════════════════════════════════════════
#  사탕 — 사서 쟁여 뒀다가 한 번 쓰고 사라지는 것
# ──────────────────────────────────────────────────────────
#  확정 규칙: 칸 2 · 상점 즉시 사용 가능 · 보관 가능 · 판 중 사용 가능 ·
#  사용 확정은 누르고 뗄 때 · 확인 버튼과 비교 팝업은 만들지 않는다.
#  칸 두 개는 옛 판매판이 쓰던 자리(자금판 오른쪽)에 선다.
#
#  트랙 강화형은 대상이 트랙 하나로 정해져 있어 "대상 클릭" 이 곧 사용이다.
#  스티커형(제안)은 대상을 골라야 하므로 흐름이 다르다 — 데이터만 실려 있고
#  사용은 아직 막혀 있다.
# ══════════════════════════════════════════════════════════

var cons := []                  # 보유 사탕 (최대 cons_slots)
var track_lv := {}              # 트랙 레벨 {트랙ID: int}
var track_hits := {}            # 이 런에서 그 트랙을 몇 번 맞혔나 {트랙ID: int}


func _cons_rect(i: int) -> Rect2:
	var c: Rect2 = LAY.cons
	var w: float = (c.size.x - 4.0) * 0.5
	return Rect2(c.position.x + float(i) * (w + 4.0), c.position.y + _hud_dy(),
			w, c.size.y)


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
		# 스티커형은 대상 선택 흐름이 아직 없다 — 데이터 스캐폴드 단계다
		pay_msg = "스티커는 아직 준비 중이다"
		pay_msg_t = HAND.msg_t
		_deny()
		return
	track_lv[c.track] = int(track_lv.get(c.track, 0)) + 1
	Save.bump("cons_used")
	Save.peak("best_track", int(track_lv[c.track]))
	var at := _cons_rect(i).get_center()
	cons.remove_at(i)
	pop(at + Vector2(0.0, 26.0), "%s  Lv%d" % [c.n, track_lv[c.track]],
			C_ACC, 10, 0.9)
	_sfx("cons_use")


func _cons_draw() -> void:
	# 동전 슬롯과 같은 재질로 깐다 — 같은 재질이 "여기도 물건 두는 자리다" 를 말한다.
	var box: Rect2 = LAY.cons
	box.position.y += _hud_dy()
	draw_rect(box, C_FELT)
	draw_rect(Rect2(box.position, Vector2(box.size.x, 1.0)), C_FELT.lightened(0.14))
	for i in GameData.cons_slots():
		var r := _cons_rect(i).grow(-3.0)
		var live: bool = i < cons.size()
		if live:
			draw_rect(r, C_PANEL.lightened(0.10))
			draw_rect(r, C_WIRE.darkened(0.15), false, 1.0)
			_icon_cons(r.get_center(), minf(r.size.x, r.size.y) * 0.30,
					String(cons[i].id))
	# 이름과 수 — 동전 슬롯 밑은 상인 자리라 못 쓰지만 이 자리는 벽이다.
	draw_string(font, Vector2(box.position.x, box.end.y + 9.0), "사탕",
			HORIZONTAL_ALIGNMENT_CENTER, box.size.x * 0.5, 9, C_DIM.darkened(0.1))
	draw_string(font, Vector2(box.get_center().x, box.end.y + 9.0),
			"%d/%d" % [cons.size(), GameData.cons_slots()],
			HORIZONTAL_ALIGNMENT_CENTER, box.size.x * 0.5, 9,
			C_ACC if cons.size() >= GameData.cons_slots() else C_TXT)


# ══════════════════════════════════════════════════════════
#  상점 테이블  (펠트 · 오버헤드 · 낙하)
# ──────────────────────────────────────────────────────────
#  정사영 기울임. 테이블 면에서 앙각 52°(수직에서 38°). 원근 배율은 없다 —
#  640x360 에서 깊이 164px 짜리 판의 참원근은 1.08배라 안 보이고, 안 쓰면
#  면 위의 축정렬 사각형이 화면에서도 축정렬 사각형이 되어 draw_rect 가
#  근사가 아니라 정확해진다.
#
#  계수가 둘인 것이 이 구획의 존재 이유다.
#    면에 누운 것의 y → sin 52° = 0.788   (TBL.flat)
#    면에서 선 것의 y → cos 52° = 0.616   (TBL.tall — 동전 옆면에만 쓴다)
#  하나였다면 draw_set_transform 의 scale 한 줄로 끝났다. 그리고 그 한 줄은
#  _tip_draw(2249행)가 draw_set_transform(sh) 로 복구할 때 조용히 사라지고,
#  _hud_draw 가 _draw_shop 다음이라 남은 scale 은 HUD 를 통째로 누른다.
#  → 이 구획은 draw_set_transform 을 한 번도 부르지 않는다. 불변식이다.
#
#  예외 하나 — _stage_card 의 얼굴. 카드가 면에 누우면 그 위의 아이콘과
#  글자도 같이 누워야 하는데, 글자는 좌표를 옮겨서는 못 눕힌다. 그래서
#  거기서만 draw_set_transform_matrix 를 걸고 **같은 함수 안에서**
#  draw_set_transform(shake_off) 로 되돌린다. 되돌리는 줄이 없으면
#  남은 변환이 _hud_draw 를 통째로 민다 — 위 문단이 말하는 그 사고다.
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
const C_TABLE := Color("1b3126")   # 펠트. 동전 슬롯(C_FELT "16281f")보다 한 단 밝다 —
								   # 동전 슬롯이 앞에 놓인 별개 물건으로 읽히게.
const C_WOOD := Color("3a2a24")


# ══════════════════════════════════════════════════════════
#  상인 — 크롭된 상반신
#
#  얼굴도 목도 어깨도 화면에 없다. 카메라가 그만큼 가깝다는 뜻이고, 그래서
#  몸통이 커진다. 얼굴을 안 그리는 이유는 예전과 같다 — 640x360 에서 사람
#  얼굴은 어떤 각도로도 뭉개진다. 달라진 것은 그 결론을 "작게 그려 실루엣만"
#  에서 "잘라내고 크게" 로 뒤집은 것이다.
#
#  ── 크롭이 성립하는 사각은 화면에 딱 하나다 ──────────────
#  상인보다 나중에 그려지는 불투명 판은 _hud_draw 의 셋뿐이다 — 자금판
#  x[4,76] · 동전 슬롯 x[209,431] · 동전 카운터 x[436,473], 전부 y 가 4 에서
#  시작한다. 그중 상인의 x 와 겹치는 것은 동전 슬롯 하나다. 그래서 제약이 둘이다.
#    ① 실루엣 최상단은 y ≥ 4 다. 위로 더 가면 상단바가 상점·스테이지에서
#       꺼져 있어(_bar_hidden) 덮개가 아예 없고, 화면 맨 위에 조끼색 띠가
#       폭 전체로 남는다. 6 을 쓴다 — 동전 슬롯과 상인이 같은 transform(shake) 안이라
#       상대 가림은 흔들려도 안 변하고, 2px 은 반올림 여유다.
#    ② y < 36 에서 반폭은 111 이하다. 넘으면 동전 슬롯 왼쪽 구멍(x[76,209])이나
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
#  하나와 단추 세 개면 같은 실루엣이 조끼 입은 상인이 된다. V 꼭짓점은
#  반드시 동전 슬롯 밑변(36)보다 아래여야 한다 — 위면 통째로 동전 슬롯 뒤라 아무 일도 안 한다.
#
#  ── 값 사다리 ────────────────────────────────────────────
#  조끼 9 < 소매 24 < 벽 41 < 셔츠 93 < 커프 111 < 림 141.
#  앞의 간격 15(소매−조끼) 와 17(벽−소매) 은 옛 주석이 실측으로 못 박은
#  값이라 그대로 지킨다 — 10 은 실패했고 15 는 됐다.
#
#  ── 움직이는 것은 둘이다 ────────────────────────────────
#  숨과 쓸기. 숨은 몸통 윗변이 아니라 **V 꼭짓점·단추·팔꿈치**를 움직인다 —
#  윗변은 y=4 라 동전 슬롯 뒤이고, 거기를 흔들면 아무 데서도 안 보인다.
# ══════════════════════════════════════════════════════════
const NPC := {
	"cx": 320.0,
	# 테이블이 내려가면 상인도 **통째로** 내려간다 — cut 만 내리면 몸통이
	# 늘어나 팔과 붙는다. top 과 cut 의 차(106)가 곧 몸의 길이이고,
	# 그 값이 팔·옷의 모든 비례를 쥔다.
	"top": 22.0,         # 실루엣 최상단. 상점 동전 슬롯(y[4,48]) 뒤라 안 보인다
	"cut": 128.0,        # 허리 = 카운터. TBL.fy 와 같은 값이어야 한다
	"hc": 72.0,          # 가슴 반폭 (y=top). 111 이 한계다
	"hw": 60.0,          # 허리 반폭 (y=cut)
	"vee_w": 27.0,       # 셔츠 V 반폭 (y=top)
	"vee_y": 84.0,       # V 꼭짓점. 상점 동전 슬롯 밑변(48)보다 36px 아래라 V 가 산다
	"btn_y": 94.0, "btn_dy": 11.0, "btn_r": 2.9,
	"belt": 5.0,
	# 팔은 **판 위에 누운 상자**다. 몸통은 서 있고 팔은 누워 있으므로 같은
	# 도형으로 그리면 안 된다 — 누운 것은 화면 좌표가 아니라 면 좌표(u,w)로
	# 그려야 52° 정사영이 공짜로 붙는다. 옆면(h=0)을 깔고 윗면(h=t)을 얹는
	# 어법은 동전(_sticker_flat)과 같다. 이 게임이 이미 쓰는 문법이다.
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
	# 팔꿈치를 몸통 **밖**·동전 슬롯 **뒤**로 뺀다. 뿌리가 동전 슬롯(x[209,431] y[4,36])에
	# 잘리므로 어깨를 안 그리고도 팔이 몸에서 나오고, 팔과 옆구리 사이에
	# 12px 짜리 배경 골이 세로로 75px 뚫린다.
	#
	# 설계할 때는 이걸 "닫힌 구멍" 으로 잡았는데 재 보니 아니었다 — 위는
	# 동전 슬롯에, 아래는 카운터(cut 112)에 열려 있어서 닫히지가 않는다. 대신
	# 더 센 것이 나왔다: 팔이 검사 칸 안에서 몸통과 **아예 다른 덩어리**가
	# 된다. 실루엣을 단색으로 칠하면 셋으로 갈린다(몸통 · 팔 · 팔).
	"el_l": Vector2(-94.0, -104.0), "wr_l": Vector2(-78.0, -2.0),
	# 오른쪽 손목 −6 은 왼쪽 −2 와 4w 차다 — 손이 거울짝이 된 뒤에도
	# 정확히 같은 높이에 두지는 않는다(완전대칭은 옷걸이의 냄새다).
	# u 88 에 두면 손끝이 몸통 위로 올라타 한 덩어리로 붙는다(실측).
	"el_r": Vector2(96.0, -103.0), "wr_r": Vector2(104.0, -6.0),
	# 쓸기 팔의 뿌리. 어깨 u +62 는 몸통 윗반폭(72) 안이라, 몸이 어디를
	# 걷든 소매가 조끼에서 나온다. w −115(화면 y 21)는 쉴 때 동전 슬롯 뒤다.
	"sh_r": Vector2(62.0, -115.0),
	# 팔꿈치 26 → 손목 13 → 너클 18. **손목이 전체 최소폭**이고 손이 거기서
	# 1.66배로 되벌어진다. 이 계단이 관절이 있다는 유일한 표시다 —
	# 옛 값은 팔꿈치도 9, 손목도 9, 손도 9 라 팔 하나가 통짜 막대였다.
	"el_w": 13.0, "wr_w": 6.5,
	"arm_t": 12.0, "hand_t": 9.0,
	# 왼손(화면 오른쪽)은 오른손의 거울짝이다 — 다각형도 뒤집고 각도도
	# 거울로 잡는다(거울각 20° + 비대칭용 4°). 각도만 두고 다각형만
	# 뒤집으면 엄지가 화면 안쪽으로 넘어가 정사영에 눌리고, 다각형만
	# 두고 각도만 세우면 손이 매달린 덩어리가 된다 — 둘 다 해 봤다.
	# 거울로 온전히 뒤집으면 엄지 투영이 오른손과 정확히 같아진다.
	# 지금은 각이 완전한 거울(112+68=180)이고, 남는 비대칭은 길이 5% 와
	# 손목 w 4 다 — 손각을 사람 관절 범위로 눕히면서 각의 4° 를 내줬다.
	# 손각은 팔 방향에서 얼마나 꺾이느냐로 정한다. 옛 값(160·24)은 팔이
	# 면에서 81°·85° 로 내려오는데 손을 160°·24° 로 뒀다 — 79°·61° 꺾인
	# 손목이라 사람 관절이 못 하는 각이고, 화면에서는 팔에 신발을 신긴
	# 것으로 읽혔다. 사람 손목의 좌우 꺾임 한계가 20~30° 다.
	# 손끝을 관객 쪽(+w)으로 돌리면 정사영이 길이를 0.788 로 누르지만,
	# 엄지 노치는 ey 축이라 가로로 남아 실루엣 정보가 안 준다.
	"ang_l": 112.0, "sc_l": 0.95,
	"ang_r": 68.0,       # 쓸 때의 손각은 상수가 아니라 팔 방향이 정한다
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
#  상인이 판을 쓸어 왼쪽(판매) 창구로 넣고 새로 뿌린다. 세 박자다 —
#  뻗기 · 훑기 · 복귀. 물리가 열리는 것은 훑기 동안뿐이다(sweep_on).
#
#  아래팔은 면 위의 직선이고, 52° 정사영에서 면 위 직선은 화면 직선이라
#  **그려지는 아래팔이 곧 미는 선이다.** 근사가 아니라 _sweep_line 하나를
#  그리기와 물리가 같이 읽는 것이다. 위팔이 동전 슬롯 뒤 어깨와 팔꿈치를 이어
#  팔을 몸에 묶는다 — 길이는 만화지만 뿌리는 실물이다.
#
#  아래팔은 트레이 w[24,126] 을 정확히 덮는다 — 팔꿈치가 w 24 (화면 y 130.9),
#  손이 w 126 (y 211.3). 물건 중심은 _drop_walls·_drop_clamp 가 그 구간에
#  못 박으므로 팔이 못 만나는 물건이 존재할 수 없다. 경우를 안 따져도 된다.
#
#  기울기를 창구 빗변과 **평행**으로 잡은 것이 이 표의 유일한 묘수다.
#  빗변 기울기는 back·flat/(ny−fy) 다 — **테이블 깊이가 바뀌면 이 값도
#  바뀌므로 tilt 를 같이 고쳐야 한다.** 지금은 80·0.788/140 = 0.450286 이고
#     line(w) − e(w) = u1 + tilt·w_hd − back      … w 와 무관한 상수
#  가 된다. 그래서 "어느 깊이에서 빠지는가" 를 따질 일이 없다. 물건이
#  놓이는 자리가 line(w) − r 이므로 조건이 그 상수 ≤ r 하나로 줄고,
#  지금 값은 18 + 56.74 − 80 = −5.26 이라 가장 빡빡한 동전(r 19)도
#  넉넉히 지난다.
#  시작점 u0 = 529 는 반대쪽이다. 물건이 물리적으로 닿을 수 있는 가장
#  오른쪽 실체가 u_hi − hw + r = 524 − 19 + 19 = 524 이므로(실측 최대는
#  486) 선이 거기보다 오른쪽에서 출발하면 팔 오른쪽에 남는 물건이 없다.
#
#  물건이 빗변을 넘으면 물리를 떠나 waste 로 간다. drop 은 stock 과 인덱스를
#  나누므로 거기 남겨 두면 "쓸려 가는 중인데 살 수 있는" 상태가 생긴다.
const SWEEP := {
	"reach": 0.26,       # 팔을 오른쪽 끝까지 뻗는다. 0.16 은 순간이동으로 읽혔다
	"rake": 0.52,        # 훑는다. 이 동안만 왼쪽 벽이 열린다
	"back": 0.30,        # 복귀. 새 매물은 이 동안 이미 떨어지고 있다
	"u0": 529.0, "u1": 18.0,
	"w_el": 24.0, "w_hd": 126.0,
	"tilt": 0.450286,    # 창구 빗변의 기울기 그대로. 아래 주석이 이유다
	"tilt_deg": 5.0,     # 몸 기울기 — 뻗을 때 +5°(95도), 훑어 끝나면 −5°(85도)
	"w_wr": 74.0,        # 훑을 때 손목 깊이. 손끝이 미는 선 아래끝(126) 근처를 덮는다
	"hand_up": 1.55,     # 훑을 때 손 배율 — 가까이 온 것은 커진다. 원근이다
	"push": 620.0,       # 밀린 물건이 받는 최소 좌향 속도 (면px/s)
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
	"fy": 128.0,         # 펠트 far 모서리
	"ny": 268.0,         # 펠트 near 모서리. 레일 6px 뒤가 버튼 줄이다

	# ── 물건 ─────────────────────────────────────────
	"chip_r": 19.0,      # 38 x 29.9 타원. 동전 슬롯 동전은 30 x 30 정원이다 (일부러 다르다)
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
	# 판 갈이 때는 _draw 가 이 사각을 **안 밀고** 맨 밑에 미리 깔았다.
	# 여기서 또 그리면 벽이 테이블을 따라 옮겨진다.
	if not swap_live:
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

	# 상인 라인 — 면 위에서 좌우로 뻗은 선은 이 정사영에서 정확히 화면
	# 수평선이 된다. 근사가 아니라 공짜로 맞다.
	var dly: float = TBL.fy + 7.0
	var de := _chute_edge(dly)
	draw_line(Vector2(de + 8.0, dly), Vector2(VIEW.x - de - 8.0, dly), Color(ink, 0.5), 1.0)


func _cover_draw() -> void:
	# 덮개 — 물건은 카운터 뒤에서 나온다. 그 위로 삐져나온 부분을
	# 먼 쪽 레일이 덮는다. 클리핑 대신 불투명 사각 하나다. 상시 HUD 는
	# _hud_draw 가 이 위에 판을 다시 얹으므로 멀쩡하고, 결과적으로 동전 슬롯이
	# 테이블 쿠션 위에 놓인 상인 트레이로 읽힌다.
	# 카운터 뒤 벽도 방이다 — 자리를 지킨 채 색만 건너간다. 자리는
	# 지키되 그리는 **차례**는 그대로여야 한다. 이 사각의 일이 카운터 뒤에서
	# 올라오는 물건을 덮는 것이라, 맨 밑으로 내리면 낙하 중인 매물이
	# 카운터 위로 삐져나온다.
	if swap_live:
		draw_set_transform(_swap_pin())
	# 이 띠는 카운터가 벽에 드리운 그늘이다 — 카운터가 나가면 같이 옅어져
	# 벽에 녹는다. 안 그러면 테이블이 다 빠진 뒤에도 y=128 에 가로 이음선
	# 하나가 화면을 가로질러 남는다.
	draw_rect(Rect2(0.0, 0.0, VIEW.x, TBL.fy),
			_swap_wall(C_WOOD.darkened(0.30).lerp(C_WOOD, _swap_gone())))
	if swap_live:
		draw_set_transform(shake_off)
	# 상인만 위로 더 뺀다. 실루엣은 동전 슬롯 뒤에 잘리는 것을 전제로 그린
	# 크롭이라(NPC.top), 가로로만 밀면 평평한 절단면이 드러난다. 동전 슬롯이
	# 퇴장문이다. 구획 규약(draw_set_transform 금지)의 두 번째 예외이고,
	# _stage_card 와 같은 규칙으로 **같은 함수 안에서** 되돌린다. 배율이
	# 아니라 이동뿐이라 규약이 막는 사고(남은 scale 이 HUD 를 누른다)는
	# 원리상 못 일어난다.
	var nd: float = float(SWAP.npc) * _swap_gone()
	if nd > 0.01:
		draw_set_transform(shake_off - Vector2(0.0, nd))
	_npc_body()
	if nd > 0.01:
		draw_set_transform(shake_off)
	draw_rect(Rect2(0.0, TBL.fy - 3.0, VIEW.x, 3.0), C_WOOD)
	draw_rect(Rect2(0.0, TBL.fy - 1.0, VIEW.x, 1.0), C_WOOD.lightened(0.18))
	if nd > 0.01:
		draw_set_transform(shake_off - Vector2(0.0, nd))
	_npc_arms()
	if nd > 0.01:
		draw_set_transform(shake_off)
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


# 상인 몸통 — 카운터 위로 올라온 부분만. 동전 슬롯이 이 위에 얹혀 트레이로 읽힌다.
# 상인 몸통 — 카운터 위로 올라온 부분만. 동전 슬롯이 이 위에 얹혀 트레이로 읽힌다.
func _npc_body() -> void:
	var br: float = sin(npc_clock * 1.5) * float(NPC.breathe)
	var cx: float = NPC.cx
	# 141 에서 내렸다. 손 윗면(133)보다 밝은 것이 화면에 있으면 안 된다 —
	# 눈은 가장 밝은 데로 먼저 가고, 그게 옆구리 획이면 상인이 안 읽힌다.
	var rim: Color = C_WOOD.lightened(0.26)
	# 몸통. 위는 동전 슬롯(y<36) 뒤로 사라지고 아래는 카운터에 박힌다. 사다리꼴
	# 하나면 충분하다 — 이 크롭에서 어깨 사면은 화면 밖이라 그릴 것이 없다.
	# 쓸 때는 윗점들이 _npc_tl 로 허리축 기울임을 탄다.
	draw_colored_polygon(PackedVector2Array([
			_npc_tl(Vector2(cx - NPC.hc, NPC.top)),
			_npc_tl(Vector2(cx + NPC.hc, NPC.top)),
			Vector2(cx + NPC.hw, NPC.cut), Vector2(cx - NPC.hw, NPC.cut)]),
			C_WOOD.darkened(0.84))
	# 셔츠 V — 조끼가 벌어진 자리. 이 한 조각이 사다리꼴을 옷으로 만든다.
	# 꼭짓점만 숨을 탄다. 윗변은 동전 슬롯 뒤라 움직여도 아무 데서도 안 보인다.
	draw_colored_polygon(PackedVector2Array([
			_npc_tl(Vector2(cx - NPC.vee_w, NPC.top)),
			_npc_tl(Vector2(cx + NPC.vee_w, NPC.top)),
			_npc_tl(Vector2(cx, NPC.vee_y + br))]), C_LIGHT.darkened(0.60))
	# 단추 셋. 세로 한 줄이 가운데를 잡아 좌우 대칭을 몸으로 읽게 한다.
	for k in 3:
		draw_colored_polygon(_e_pts(
				_npc_tl(Vector2(cx, NPC.btn_y + float(k) * NPC.btn_dy + br)),
				NPC.btn_r, NPC.btn_r, 12), C_WOOD.lightened(0.13))
	# 허리띠 — 몸통이 카운터에서 끊기는 자리에 가로 획. 축이 여기라 안 기운다.
	draw_rect(Rect2(cx - NPC.hw - 1.0, NPC.cut - NPC.belt,
			(NPC.hw + 1.0) * 2.0, NPC.belt), C_WOOD.darkened(0.90))
	# 옆선 빛. 벽과 100/255 갈리는 유일한 고대비 획이고, 이게 없으면
	# 조끼(9)와 벽(41)의 32 차이만 남아 실루엣이 벽에 잠긴다.
	for s in [-1.0, 1.0]:
		draw_line(_npc_tl(Vector2(cx + s * NPC.hc, NPC.top)),
				Vector2(cx + s * NPC.hw, NPC.cut), Color(rim, 0.55), 1.0)


# 팔 — 먼 레일 다음이라 "카운터에 얹혔다" 가 된다.
# 오른쪽(화면) 팔만 쓸기를 한다. 마주 본 사람이므로 그것이 상인의 **왼팔**
# 이다 — 쓸기는 u 529 에서 18 로 가는데 529 에 닿는 팔이 그쪽뿐이라
# 물리가 이미 팔을 골라 놨다.
func _npc_arms() -> void:
	var br: float = sin(npc_clock * 1.5) * float(NPC.breathe)
	var cx: float = NPC.cx
	var a := _sweep_amt()
	# 쉬는 팔. 숨은 팔꿈치를 손목보다 크게 흔든다 — 뿌리가 동전 슬롯 뒤라
	# 팔꿈치 쪽 진폭은 안 보이고 팔 전체의 기울기로만 나온다.
	# 몸이 기울면 뿌리도 그만큼 밀린다.
	_npc_limb(Vector2(cx + NPC.el_l.x + _npc_sway(NPC.el_l.y),
			NPC.el_l.y + br * 0.5),
			Vector2(cx + NPC.wr_l.x + _npc_sway(NPC.wr_l.y),
			NPC.wr_l.y + br * 0.2),
			deg_to_rad(NPC.ang_l), NPC.sc_l)
	# 쓸는 팔 — 어깨부터 **쭉 편 채** 휩쓴다. 몸이 +5° 기울며 뻗고,
	# −5° 로 넘어가는 동안 팔이 부채꼴로 판을 쓴다. 팔꿈치는 어깨-손목
	# 직선 위라 안 굽고, 손으로 갈수록 굵어지다 손이 1.55배가 된다 —
	# 관객 쪽으로 내려온 것은 크게 보이는 것이 원근이다.
	var el := Vector2(cx + NPC.el_r.x + _npc_sway(NPC.el_r.y),
			NPC.el_r.y + br * 0.5)
	var wr := Vector2(cx + NPC.wr_r.x + _npc_sway(NPC.wr_r.y),
			NPC.wr_r.y + br * 0.2)
	var ang: float = deg_to_rad(NPC.ang_r)
	var sh := Vector2(cx + NPC.sh_r.x + _npc_sway(NPC.sh_r.y), NPC.sh_r.y)
	if a > 0.004:
		var wt := Vector2(_sweep_line(SWEEP.w_wr), SWEEP.w_wr)
		wr = wr.lerp(wt, a)
		el = el.lerp(sh + (wr - sh) * 0.55, a)
		# 손도 팔의 연장이다 — 쭉 편 팔은 손까지 한 방향이다.
		ang = lerp_angle(ang, (wr - sh).angle(), a)
	var hs := lerpf(1.0, SWEEP.hand_up, a)
	# 위팔은 **쓸 때만** 그린다. 쉬는 자세에서는 어깨와 팔꿈치가 거의
	# 같은 높이라 토막이 몸통 옆구리에 붙어 팔–몸통 골을 4px 로 좁힌다
	# (프로브가 잡았다). 원래 설계도 "팔은 상자 하나" 였고 위팔은 쓸기가
	# 어깨까지 뻗을 때 몸에 매다는 줄로만 필요하다.
	# 어깨 쪽이 가늘어지는 것은 원근이다 — 먼 것이 가늘다.
	if a > 0.004:
		_npc_taper(sh, el, lerpf(11.5, 8.0, a), NPC.el_w, NPC.arm_t,
				C_WOOD.darkened(0.84), C_WOOD.lightened(0.04))
	# 관절 원판 — 쉬는 자세로 오갈 때 굽는 모서리의 틈을 밑에서 메운다.
	var jd := PackedVector2Array()
	for k in 8:
		var ka := TAU * (float(k) + 0.5) / 8.0
		jd.append(el + Vector2(cos(ka), sin(ka)) * (NPC.el_w - 1.0))
	_npc_flat(jd, NPC.arm_t, C_WOOD.darkened(0.84), C_WOOD.lightened(0.04))
	# 이 팔이 상인의 왼팔이다 — 손은 거울상으로 붙는다.
	_npc_limb(el, wr, ang, hs, true, lerpf(NPC.wr_w, 13.5, a))


# 팔 하나 + 손 하나. 면 좌표(u,w) 로 받는다.
# 값 사다리를 여기서 못 박는다 — 소매 윗면 66 은 벽 41 보다 **밝다**.
# 옛 소매 24 는 벽보다 어두워서 팔이 벽에 잠겨 있었다. 손 윗면 133 은
# 화면에서 가장 밝은 덩어리이고, 그래서 눈이 손부터 본다.
func _npc_limb(el: Vector2, wr: Vector2, ang: float, sc: float,
		mir: bool = false, wrr: float = -1.0) -> void:
	if wrr < 0.0:
		wrr = NPC.wr_w
	var ex := Vector2(cos(ang), sin(ang))
	# 손대칭이 문제였다. 같은 다각형을 두 팔에 평행이동만 해서 붙이면
	# 상인이 오른손을 두 개 단다 — 마주 본 사람의 두 손은 거울상이다.
	# 뒤집기는 다각형과 각도를 **함께** 거울로 잡아야 한다. 다각형만
	# 뒤집으면 엄지가 화면 안쪽(−w)으로 넘어가 정사영이 8px 노치를
	# 6px 로 누르고(실측 — 그 손만 빵이 된다), 각도까지 뒤집으면 엄지
	# 방향이 오른손과 거울로 정확히 같아서 투영 손실도 같다.
	var ey := Vector2(ex.y, -ex.x) if mir else Vector2(-ex.y, ex.x)
	var hand := PackedVector2Array()
	for q in PALM:
		hand.append(wr + ex * (q.x * sc) + ey * (q.y * sc))
	if mir:
		hand.reverse()          # 뒤집힌 감김을 되돌린다 — 삼각분할이 읽는 값이다
	# 접지 그림자 — 같은 손을 면에서 w+3 밀어 어둡게 깐다. 화면에서는
	# 2.4px 아래다. 이 한 조각이 "떠 있는 손"과 "판에 놓인 손"을 가른다.
	var sh := PackedVector2Array()
	for q in hand:
		sh.append(_p2s(q.x, q.y + 3.0, 0.0))
	draw_colored_polygon(sh, C_WOOD.darkened(0.84))
	_npc_taper(el, wr, NPC.el_w, wrr, NPC.arm_t,
			C_WOOD.darkened(0.84), C_WOOD.lightened(0.04))
	# 손목 덮개 — 팔 상자와 손 다각형의 이음새에서 래스터가 어긋나면
	# 펠트가 1px 새어 나온다(검토 실측). 작은 원판이 밑에서 메운다.
	var wc := PackedVector2Array()
	for k in 8:
		var ka := TAU * (float(k) + 0.5) / 8.0
		wc.append(wr + Vector2(cos(ka), sin(ka)) * (wrr + 2.0) * sc)
	_npc_flat(wc, NPC.hand_t, C_WOOD.darkened(0.84), C_WOOD.lightened(0.13))
	# 손목 이음선은 **어둡게**. 밝은 커프 띠로 갈라 봤다가 옷이 아니라
	# 띠 자체로 읽혀서 졌다 — 양옆보다 밝은 좁은 획은 형태를 자른다.
	# 어두운 획은 반대로 잇는다. 여기서는 손 옆면(84)이 그 역할을 한다.
	_npc_flat(hand, NPC.hand_t, C_WOOD.lightened(0.13),
			C_WOOD.lightened(0.38))


# 면 위에 누운 다각형 하나. 옆면(h=0)을 먼저 깔고 윗면(h=t)을 얹는다 —
# 윗면이 t*tall 만큼 위로 올라가므로 아래로 삐져나온 옆면이 그대로
# 두께가 된다. 동전과 같은 수법이다. 옆면 색을 **인자로 받는** 것이 중요하다:
# 옛 _npc_slab 은 col.darkened(0.58) 로 자동 파생했는데, 그 결과가
# 조끼색과 같은 값이라 몸통 위에 겹치는 구간에서 두께가 통째로 사라졌다.
func _npc_flat(pts: PackedVector2Array, t: float, side: Color,
		top: Color) -> void:
	var lo := PackedVector2Array()
	var md := PackedVector2Array()
	var hi := PackedVector2Array()
	for q in pts:
		lo.append(_p2s(q.x, q.y, 0.0))
		md.append(_p2s(q.x, q.y, t * 0.5))
		hi.append(_p2s(q.x, q.y, t))
	draw_colored_polygon(lo, side)
	# 중간층 — 노치 같은 오목 꼭짓점에서 아래층과 윗층의 래스터가 서로
	# 어긋나면 그 틈으로 펠트가 1px 뚫린다(쓸기 두 자세에서 실측).
	# 같은 도형을 반 높이에 한 번 더 깔면 어긋남이 절반이라 안 뚫린다.
	draw_colored_polygon(md, side)
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


# 몸은 제자리에서 **기울기만** 한다 — 뻗을 때 오른쪽으로 +5°, 훑으면서
# 왼쪽 −5° 까지. 허리(w 0 = 카운터 선)가 축이다. 걷기도 팔 늘리기도
# 시켜 봤지만 다 부자연스러웠다 — 기울고, 팔은 쭉 편 채 원근으로 큰다.
func _sweep_tilt() -> float:
	if not sweep_live:
		return 0.0
	var k: float = clampf((_sweep_u() - SWEEP.u1) / (SWEEP.u0 - SWEEP.u1), 0.0, 1.0)
	return deg_to_rad(lerpf(-SWEEP.tilt_deg, SWEEP.tilt_deg, k)) * _sweep_amt()


# 기울임을 화면 점에 얹는다 — 허리(NPC.cx, cut)를 축으로 돈다.
func _npc_tl(pt: Vector2) -> Vector2:
	var th := _sweep_tilt()
	if absf(th) < 0.0005:
		return pt
	var pv := Vector2(NPC.cx, NPC.cut)
	return pv + (pt - pv).rotated(th)


# 팔 뿌리(면 좌표 u,w)의 기울임 보정 — 허리축이 w 0 이라, 위로 갈수록
# (w 음수) 기울기만큼 u 가 밀린다. 작은 각이라 회전 대신 밀기로 충분하다.
func _npc_sway(w: float) -> float:
	return -w * TBL.flat * _sweep_tilt()


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
	_sfx("sweep_sink")


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
#   _e_ring_r  동전 좌표계 비율 — 12시에서 flat 배로 준다.  면의 구역
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
#  _dart_e · _obj_box · _obj_shape · _obj_shadow · _sticker_flat 뿐이다. grep 으로 검산된다.
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
	# 막대의 방향별 마찰비(a_fric 에 곱한다). 자기 축을 가로질러 밀리면
	# 구르고, 축을 따라 밀리면 촉이 긁힌다 — 같은 세기로 밀어도 옆으로
	# 굴린 것이 두 배 넘게 멀리 간다. a_fric 520 기준 굴림 286 · 미끄럼
	# 702 이고, 상한 속도 260 에서 미끄럼 거리가 118px 대 48px 이다.
	# 둘 다 양수라 "유한 시간에 정확히 0" 인 정착 증명은 그대로 산다.
	"mu_roll": 0.55, "mu_slide": 1.35,
	"tumble_rate": 0.145,
	#  미끄러진 거리(면px) 당 도는 각(rad). 3D 로 세워 그리는 물체(사탕·
	#  다트) 전용이다 — 다른 물체가 쓰는 psi/om 회전은 그대로 둔다. 새
	#  toss_cap 260 의 최대 미끄럼 65면px 에서 65*0.145 ≈ 9.4rad(1.5바퀴) —
	#  세게 던지면 눈에 보이게 굴러 넘어가고, 살짝 밀면 그만큼만 기운다.

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
	#  동전 원 1개(실루엣과 정확히 일치) · 보드 확장 원 1개 · 다트 원 3개(캡슐).
	#  다트에 가운데 원이 있어 동전-다트 최소 중심거리가 방위와 무관하게 28 이다.
	#  이 28 이 가격판 겹침 불가 정리의 전제다 (아래 _bill_draw 주석).
	"r_item": 19.0, "r_mod": 21.0, "r_dart": 9.0, "d_dart": 16.0,
	#  사진은 폴라로이드다 — 동전보다 조금 작은 네모라 반지름도 그만큼 작다.
	"r_fix": 16.0,

	# ── 화면 반폭 (좌우 벽 전용 — 충돌 반지름과 다르다) ──
	#  벽은 "그려지는 것" 을 가두고 충돌은 "형상" 이라 두 일에 각각 맞는 값이다.
	"hw_item": 19.0, "hw_mod": 22.0, "hw_dart": 37.5, "hw_fix": 17.0,

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
# 레인 안쪽 여백. 매물이 늘면 줄여서 폭을 벌린다 — 그리기와 검사가 같은
# 식을 써야 "여섯이 뭉친다" 를 눈이 아니라 수로 잡는다.
func _lane_pad(n: int) -> float:
	return maxf(90.0 - maxf(float(n) - 4.0, 0.0) * 22.0, 26.0)


# 매물 하나가 받는 레인 폭(면 px). 동전 지름이 38 이라 이보다 좁아지면
# 서로를 밀고 값뱃지가 겹친다.
func _lane_w(n: int) -> float:
	if n <= 0:
		return 0.0
	return (float(DROP.u_hi) - float(DROP.u_lo) - _lane_pad(n) * 2.0) / float(n)


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
			"fix":
				# 종이는 안 튄다 — 반발을 동전의 절반으로 둔다. 떨어져
				# 찰싹 붙는 것이 "사진" 의 무게다.
				r = DROP.r_fix
				e = DROP.e_item * 0.5
				hw = DROP.hw_fix
		# 완전 난수면 넷 중 둘이 같은 지점에 쏟아지는 판이 잦고, 그 둘이 같이
		# 벽으로 밀린다. 레인은 출발만 벌려 둘 뿐 정착 위치를 통제하지 않는다.
		#
		# 안쪽 여백이 90 으로 고정이라 레인이 몇 개든 폭이 228px 이었다.
		# 넷일 때는 57px 씩이라 넉넉한데, "넓은 테이블" 뱃지로 여섯이 되면
		# 38px 씩이 되어 동전(지름 38)가 서로를 밀고 값뱃지가 겹친다.
		# 레인 수가 늘면 여백을 줄여 폭을 벌린다 — 창구 빗변까지는 안 간다.
		var lane: float = lerpf(DROP.u_lo + _lane_pad(n), DROP.u_hi - _lane_pad(n),
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
			"roll": 0.0,      # 3D 로 세워 그리는 물체가 구른 각(사탕·다트)
			"handled": false, # 손이 실제로 던진 적이 있는가 — roll 을 그 뒤부터만 쌓는다
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
	_swap_update(d)          # 상태를 안 가린다 — 전환은 두 화면 사이에 있다
	_hand_update(d)
	if state == S.LEG:
		leg_t += d
		npc_clock += d
	if state == S.STAGE:
		stage_t += d
		npc_clock += d
		# 커서 아래 카드만 선다. tip_mark 를 읽으므로 툴팁과 같은 판정이고,
		# 그래서 "글자가 뜨는 카드" 와 "선 카드" 가 절대 안 갈린다.
		for i in mini(stage_stand.size(), stage_pick.size()):
			var on: bool = tip_a > 0.004 and tip_mark == _stage_rect(i)
			stage_stand[i] = move_toward(stage_stand[i], 1.0 if on else 0.0, d * 7.0)
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
			# 반발 "후" 속도로 가른다. 충돌 속도로 가르면 e=0.16 짜리 보드 확장이
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
				var af: float = DROP.a_fric
				if i < stock.size() and stock[i].type == "dart":
					# 막대는 방향에 따라 다르게 멎는다. psi 가 자루의 축이다.
					var ax := Vector2(cos(it.psi), sin(it.psi))
					var al: float = absf((Vector2(it.vu, it.vw) / sp).dot(ax))
					af = DROP.a_fric * lerpf(DROP.mu_roll, DROP.mu_slide, al)
					# 구른 만큼 자기 축이 돈다. 축을 가로지르는 성분만
					# 굴림을 만든다 — 축을 따라 미끄러질 때는 안 돈다.
					# 부호는 어느 쪽으로 밀렸는지가 정한다.
					var pp: float = sp * sqrt(maxf(1.0 - al * al, 0.0))
					var sg: float = signf(it.vu * ax.y - it.vw * ax.x)
					it.roll = it.get("roll", 0.0) + pp * sg * DROP.tumble_rate * dt
				var k: float = maxf(sp - af * dt, 0.0) / sp
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
		# 사탕·다트는 미끄러진 거리만큼 구른다 — "굴러서 뒤집힌다". psi/om 은
		# 다른 물체와 공유하는 회전(a_spin 30 이 0.09초 안에 죽인다)이라
		# 3D 로 세워 그리는 물체에 쓰면 표가 안 난다. 이 축은 그 둘 전용이고
		# 속도가 그대로 회전 속도다 — 세게 던져 멀리 밀릴수록 더 많이 구른다.
		# 딜러가 던져 테이블에 앉히는 것 자체도 꽤 멀리 미끄러진다(초반
		# 아크 + 몇 번의 바운스) — handled 없이 적분하면 손도 안 댔는데
		# 몇 바퀴씩 돌아 있었다("갑자기 꽂힌 것처럼" 제보의 절반은 이거다).
		# 손이 실제로 던진 뒤부터만(_hand_land 가 handled 를 켠다) 구른다.
		if i < stock.size() and bool(it.get("handled", false)) 				and stock[i].type == "cons":
			var tsp: float = Vector2(it.vu, it.vw).length()
			it.roll = it.get("roll", 0.0) + tsp * DROP.tumble_rate * d
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
	# 동전 슬롯 칸은 이륙 시점에 굳힌다. 도착할 때 다시 계산하면 그 사이 판매·구매로
	# owned 가 바뀌어 엉뚱한 칸이 튄다. 튐 자체는 _drop_arrive 로 옮겼다 —
	# 물건이 아직 테이블에 있는데 동전 슬롯이 먼저 반응하면 인과가 뒤집힌다.
	it.slot = -1
	match stock[i].type:
		"item":
			it.slot = clampi(owned.size() - 1, 0, GameData.max_items() - 1)
			it.to = _slot_rect(it.slot).get_center()
		"mod":
			it.to = p + Vector2(0.0, -30.0)
			pop(p + Vector2(0.0, -8.0), "보드 확장", C_CHIP.lightened(0.25), 13, 0.9)
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
		"fix":
			# 돌아간 네모의 축정렬 덮개. 반폭·반높이의 큰 쪽으로 잡는다.
			var fr: float = maxf(FIX_W, FIX_H) + 3.0
			var ef := Vector2(fr, fr * TBL.flat + 3.0)
			return Rect2(c - ef, ef * 2.0)
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
		"fix":
			# 그리는 것과 같은 네 귀퉁이를 쓴다 — 둘이 어긋날 수가 없다.
			return _in_poly(m, _fix_quad(c, it.psi, 1.14))
	var lz: float = TBL.chip_t * TBL.tall * 0.5          # 옆면 슬리버를 덮는다
	var q := (m - c - Vector2(0.0, lz)) / Vector2(TBL.chip_r + 2.0,
			TBL.chip_r * TBL.flat + lz + 2.0)
	return q.length_squared() <= 1.0


# 볼록 다각형 안인가. 사진의 네 귀퉁이가 유일한 소비자다 — 돌아간
# 네모라 축정렬 검사로는 귀퉁이가 어긋난다. 감기 방향과 무관하게 맞다:
# 모든 외적의 부호가 같으면 안이다.
func _in_poly(m: Vector2, pts: PackedVector2Array) -> bool:
	var sg := 0.0
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var cr := (b.x - a.x) * (m.y - a.y) - (b.y - a.y) * (m.x - a.x)
		if absf(cr) < 0.0001:
			continue
		if sg == 0.0:
			sg = signf(cr)
		elif signf(cr) != sg:
			return false
	return true


func _seg_d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / l2, 0.0, 1.0))


# 커서 아래 매물. _z_order 를 정확히 거꾸로 훑는다 — 위에 그려진 것이 잡힌다.
# 박스는 통과했는데 모양이 아니면 다음(아래) 물체로 흘려보낸다. 다트의 빈 박스가
# 뒤엣 동전을 가로채지 못하는 경로가 이것이다.
# 실측 — 정착 배치 300판을 1px 격자로 전수 조사해 못 잡는 물체 0/1200,
# 최소 표적 면적 667px²(다트) · 1158(동전) · 1719(보드 확장).
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
	# 상한을 안 두면 딜러가 던지는 초반 아크(h 100~120)에서 k 가 4.4 를
	# 넘는다 — 실제 그림(다트 26px)의 세 배가 넘는 그림자가 되어, 물건이
	# 하늘에 있는데 바닥엔 그보다 훨씬 큰 검은 자국만 진하게 남는다
	# ("바닥에 꽂힌 것처럼 보인다" 는 제보가 이거다). 2.0 에서 끊는다 —
	# 낮은 바운스의 "떠 있다" 느낌은 남기고 던지기 아크의 과장만 없앤다.
	var k: float = minf(1.0 + hh * DROP.sh_grow, 2.0)
	var col := Color(0.0, 0.0, 0.0, DROP.sh_a / k)
	# 기존 그림자 벡터 (1.5,3.0) = light * 3.35. h=0 에서 정확히 일치한다.
	var g := Vector2(it.u, _p2g(it.w)) + TBL.light * (3.35 + hh * 0.10)
	match stock[i].type:
		"dart":
			# 가는 막대의 그림자는 가는 막대다 — 충돌 부위 세 곳에 원을
			# 찍으면 애벌레가 된다(실측). 다트 방향으로 누운 가는 타원 하나.
			#
			# 방향은 psi 다 — 3D 자루의 머리 방향도 psi 를 쓰므로 둘이
			# 같은 값을 본다. roll 은 자기 축 구름이라 실루엣을 안 돌린다.
			var de := _dart_e(it)
			var dirv := de.normalized()
			var L: float = TBL.dart_l * de.length() * 0.92 * k
			var pts := PackedVector2Array()
			for q in 12:
				var a := TAU * float(q) / 12.0
				var e := Vector2(cos(a) * L, sin(a) * 2.4 * k)
				pts.append(g + Vector2(e.x * dirv.x - e.y * dirv.y,
						e.x * dirv.y + e.y * dirv.x))
			draw_colored_polygon(pts, col)
		"cons":
			# 꾸러미는 동전보다 작다 — 동전 반지름 그림자를 깔면 빛무리가 된다.
			draw_colored_polygon(_e_pts(g, 12.5 * k, 12.5 * k * TBL.flat, 12), col)
		"fix":
			# 사진은 네모라 그림자도 네모다. 타원을 깔면 원반으로 읽힌다.
			var fq := _fix_quad(g, it.psi, k)
			draw_colored_polygon(fq, col)
		_:
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
			_sticker_flat(c, s.d, it.psi, dim, it.wob)
		"cons":
			# 사탕 — 카드가 아니라 모델이 구르며 떨어진다. it.psi 는 물리가
			# 이미 매기는 회전이다(_drop_roll 의 om 이 프레임마다 더한다) —
			# 그 값을 그대로 3D 야로 옮기면 손으로 맞출 각이 없다.
			# sleep 만 보고 얼리면 안 된다 — 잠든 뒤에도 wob 스프링은 몇 프레임
			# 더 감쇠하고, 구르던 관성도 완전히 멎을 시간이 더 든다.
			# "털썩 떨어져 두어 번 흔들리다 멎는다" 가 화면에 남으려면
			# 세 값(흔들림·흔들림 속도·미끄럼 속도)이 다 죽어야 한다.
			var still: bool = bool(it.get("sleep", false)) 					and absf(float(it.get("wob", 0.0))) < 0.02 					and absf(float(it.get("wv", 0.0))) < 0.02 					and Vector2(it.get("vu", 0.0), it.get("vw", 0.0)).length() < 1.0
			var ctex := _candy_tex_live(String(s.d.id), float(it.get("roll", 0.0)),
					float(it.get("wob", 0.0)), not still)
			if ctex != null:
				var ch := 30.0
				var cw := ch * float(CANDY_VP.x) / float(CANDY_VP.y)
				draw_texture_rect(ctex, Rect2(c - Vector2(cw, ch) * 0.5, Vector2(cw, ch)),
						false, Color(1.0 - dim * 0.3, 1.0 - dim * 0.3, 1.0 - dim * 0.3,
								1.0 - dim))
			else:
				# 렌더러가 없는 자리(헤드리스 프로브)의 옛 실루엣.
				var ce := Vector2(11.0, 11.0 * TBL.flat)
				var body: Color = C_PANEL.lightened(0.22 - dim * 0.2)
				draw_colored_polygon(PackedVector2Array([
						c + Vector2(-ce.x, -ce.y), c + Vector2(ce.x, -ce.y),
						c + Vector2(ce.x, ce.y), c + Vector2(-ce.x, ce.y)]), body)
				draw_rect(Rect2(c - ce, ce * 2.0), C_WIRE.darkened(0.2), false, 1.0)
				_icon_cons(c, ce.y * 0.56, String(s.d.id), 1.0 - dim)
		"fix":
			_fix_flat(c, it, it.psi, dim)
		"mod":
			# 동전과 같은 어법으로 눕는다 — 옆면을 깔고 윗면을 얹는다.
			# 정면 원반은 컬렉션의 것이고, 테이블 위의 것은 누워야 한다.
			draw_colored_polygon(_e_pts(c, TBL.mod_r, TBL.mod_r * TBL.flat),
					C_DARK.darkened(0.72 + dim * 0.2))
			_icon_mod(c - Vector2(0.0, TBL.chip_t * TBL.tall),
					TBL.mod_r, s.d.id, dim, TBL.flat)
		_:
			# sh=false — 내장 그림자는 고정 오프셋이라 낙하 중 하늘을 같이 난다
			var de := _dart_e(it)
			_icon_dart(c, TBL.dart_l * de.length(), s.d.id, dim,
					de.angle() + 1.0304, 1.0 - dim * 0.5, false,
					float(it.get("roll", 0.0)))


# 펠트에 누운 사진의 네 귀퉁이. 그림자와 몸통이 같은 식을 써야 둘이 안 어긋난다.
# 세로는 TBL.flat 으로 누른다 — 면에 누운 것의 규약이다. psi 로 살짝 돌려
# 두면 넉 장이 쏟아져도 판박이로 겹쳐 보이지 않는다.
const FIX_W := 13.0      # 반폭
const FIX_H := 11.0      # 반높이(누르기 전)


func _fix_quad(c: Vector2, rot: float, k := 1.0) -> PackedVector2Array:
	var co := cos(rot) * k
	var si := sin(rot) * k
	var pts := PackedVector2Array()
	for q in [Vector2(-FIX_W, -FIX_H), Vector2(FIX_W, -FIX_H),
			Vector2(FIX_W, FIX_H), Vector2(-FIX_W, FIX_H)]:
		var e := Vector2(q.x * co - q.y * si, q.x * si + q.y * co)
		pts.append(c + Vector2(e.x, e.y * TBL.flat))
	return pts


# 펠트에 누운 사진 — 폴라로이드다. 테두리가 두껍고 아래가 더 두껍다.
# 그 한 가지로 동전(원반)·사탕(덩어리)·다트(막대)와 실루엣이 갈린다.
func _fix_flat(c: Vector2, it: Dictionary, rot: float, dim: float) -> void:
	var co := cos(rot)
	var si := sin(rot)
	# 종이 두께 — 아래로 한 획. 면에 놓인 것이 떠 보이지 않게 한다.
	var body := _fix_quad(c, rot)
	draw_colored_polygon(_fix_quad(c + Vector2(0.0, 1.2), rot),
			Color(0.0, 0.0, 0.0, 0.35))
	draw_colored_polygon(body, Color(C_LIGHT.lightened(0.30).darkened(dim), 1.0))

	# 인화면 — 테두리를 남기고 안쪽에. 아래 여백이 더 넓은 것이 폴라로이드다.
	var inner := PackedVector2Array()
	for q in [Vector2(-9.0, -8.0), Vector2(9.0, -8.0),
			Vector2(9.0, 3.0), Vector2(-9.0, 3.0)]:
		var e := Vector2(q.x * co - q.y * si, q.x * si + q.y * co)
		inner.append(c + Vector2(e.x, e.y * TBL.flat))
	draw_colored_polygon(inner, Color(C_DARK.lightened(0.10).darkened(dim), 1.0))

	# 찍힌 것 — 판이다. 이 게임의 사진이 무엇을 찍은 것인지 한 점으로 말한다.
	var ic := c + Vector2((-0.0 * co - -2.5 * si),
			(-0.0 * si + -2.5 * co) * TBL.flat)
	_ring(ic, 4.2, 0.62, 1.0, Color(C_WIRE.darkened(0.1 + dim), 0.75))
	draw_circle(ic, 1.6, Color(C_RED.darkened(dim), 0.9))

	# 테두리 한 획 — 종이의 끝을 못 박는다.
	draw_polyline(_fix_quad(c, rot) + PackedVector2Array([body[0]]),
			Color(C_WIRE.darkened(0.25 + dim), 0.5), 1.0)


# 펠트에 누운 동전. 동전 슬롯의 draw_sticker(정원)은 안 고친다 — 같은 물건의
# 다른 자세다. _e_ring_w(화면 인셋)와 _e_ring_r(비율)을 섞어 쓰지 않는다.
#
#  여기서도 갈린 것은 테두리뿐이다: 가장자리 스팟과 인레이 홈(둘 다 동전의
#  어휘)을 빼고, 다이컷과 마감을 동전 슬롯과 같은 각 규약으로 얹었다. 옆면은
#  종이 두께라 그림자로만 남는다 — 히트박스(TBL.chip_t)는 안 건드렸다.
func _sticker_flat(c: Vector2, it: Dictionary, rot: float, dim: float, wob: float) -> void:
	var ti := _stk_ti(String(it.get("rarity", "common")))
	var t: Dictionary = STK_TIERS[ti]
	var rx: float = TBL.chip_r * (1.0 + wob * 0.05)
	var ry: float = TBL.chip_r * TBL.flat * (1.0 - wob * 0.12)
	var body := Color(t.body).darkened(dim)
	var rim: Color = (C_GOLD if it.get("g", "") != "" else C_DIECUT).darkened(dim)
	var rw := 2.2
	var sd: float = TBL.chip_t * TBL.tall              # 그림자 낙차 2.77px
	draw_colored_polygon(_e_pts(c + Vector2(0.0, sd), rx, ry),
			Color(0.0, 0.0, 0.0, 0.26 * (1.0 - dim)))
	draw_colored_polygon(_e_pts(c, rx, ry), rim)
	draw_colored_polygon(_e_pts(c, rx - rw, ry - rw * TBL.flat), body)
	var fa := 1.0 - dim
	match int(t.fin):
		1:
			draw_colored_polygon(_e_band(c, rx - rw - 0.3, ry - rw * TBL.flat - 0.3,
					rx * 0.50, ry * 0.50, rot - 1.45, rot - 0.35, 6),
					Color(1.0, 1.0, 1.0, 0.22 * fa))
		2:
			for k in 3:
				var a := rot - 1.85 + float(k) * 0.72
				draw_colored_polygon(_e_band(c, rx - rw - 0.3, ry - rw * TBL.flat - 0.3,
						rx * 0.20, ry * 0.20, a, a + 0.46, 4),
						Color(HOLO[k], 0.34 * fa))
		3:
			for k in 6:
				var a2 := rot + float(k) * (TAU / 6.0)
				draw_colored_polygon(_e_band(c, rx - rw - 0.3, ry - rw * TBL.flat - 0.3,
						rx * 0.20, ry * 0.20, a2, a2 + TAU / 6.0, 4),
						Color(HOLO[k % 3], 0.26 * fa))
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
#   · 분리 솔버가 보장하는 최소 면 거리는 동전-다트 28 · 보드 확장-다트 30 · 동전-동전 38.
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
#  테이블 아이콘
# ──────────────────────────────────────────────────────────
#  상점에 세 종류가 나란히 선다. 실루엣이 서로 갈려야 글자를
#  안 읽고도 무엇인지 안다.
#    아이템 → 원반 (draw_item_sticker)
#    보드 확장   → 미니 보드 — 상점에선 눕고(fl=TBL.flat) 컬렉션에선 정면(fl 1)
#    다트   → 대각선
#  _icon_mod / _icon_dart 만 바깥에서 부른다.
# ══════════════════════════════════════════════════════════

# 미니 보드는 실제 링 비율(트리플 띠 0.10)을 쓰면 17px 반지름에서 1.7px 라
# 사라진다. 읽히는 도식 비율을 따로 둔다 — 계측도가 아니라 기호다.
const MB := {"bi": 0.13, "bo": 0.27, "ti": 0.46, "to": 0.60, "di": 0.84}
# 보드에 꽂힌 다트 반길이. 10 으로는 판 위에서 안 읽혔다 — 철선 스포크가
# 이미 1px 흰 선이라 그 옆에서 다트가 스포크 한 조각으로 보였고, 크림색
# 칸 위에서는 배럴(거의 흰색)이 통째로 사라졌다.
# 16 은 굵기 기준선(19)의 0.84 라 _icon_dart 의 굵기 하한(0.75)을 처음으로
# 넘긴다 — 길이만 는 것이 아니라 배럴과 날개가 같이 굵어져서 읽힌다.
# 19 까지 키워 봤지만 거기서는 불에 꽂힌 한 발이 불을 통째로 덮는다.
const DART_DL := 16.0
const MB_SEG := 10              # 20 칸이면 한 칸 호가 5px 라 뭉갠다


# 보드 확장 아이콘은 id 가 아니라 효과 축(k)으로 갈린다.
# data.gd 가 "k 는 _mod_step 의 match 가 읽는 유일한 열쇠" 라고 못박았으므로
# 여기도 같은 열쇠를 쓴다. 같은 축의 보드 확장이 새로 생기면 아이콘이 저절로 맞는다.
# (옛 판에서는 여기가 id 로 갈려 있어, 보드 확장이 여덟 종으로 바뀐 뒤
#  match 가 하나도 안 걸려 여덟 개가 전부 민무늬로 그려지고 있었다.)
#
# 정확한 기하가 아니라 기호다. 실제 링 폭 0.10 은 17px 반지름에서 1.7px 라
# 사라지고, 속살(+0.06)과 겉살(-0.06)의 차이는 1px 여서 안 갈린다.
# 그래서 방향과 대소만 살리고 폭은 읽히도록 과장한다.
func _icon_mod(c: Vector2, r: float, id: String, dim: float,
		fl: float = 1.0) -> void:
	var m := GameData.mod_of(id)
	var k := String(m.get("k", ""))

	# 판벌이는 판이 커지는 것 자체가 효과다. 바탕을 줄여 그려야 커질 자리가 난다.
	var br: float = r * (0.84 if k == "out" else 1.0)

	var d := 0.42 + dim * 0.35
	var acc := C_ACC.darkened(dim)
	var ghost := Color(C_TXT, 0.45 - dim * 0.3)
	var step := TAU / float(MB_SEG)

	# 모든 프리미티브가 타원 헬퍼를 지난다 — fl 1.0 이면 정면 원이고,
	# TBL.flat 이면 테이블에 누운 판이다. 원 전용 draw_circle·draw_arc 는
	# 여기서 못 쓴다: 눕힌 원반의 링은 12시에서 fl 배로 줄어야 한다.
	draw_colored_polygon(_e_pts(c, br, br * fl), C_DARK.darkened(d * 0.5))
	for i in MB_SEG:
		var a := float(i) * step
		draw_colored_polygon(_e_band(c, br * MB.di, br * MB.di * fl,
				br * MB.bo, br * MB.bo * fl, a, a + step, 3),
				(C_LIGHT if i % 2 == 0 else C_DARK).darkened(d))
	var trp_lit := k == "band" or k == "slide" or k == "ring"
	if not trp_lit:
		_e_ring_r(c, br, br * fl, MB.ti, MB.to, C_GREEN.darkened(d))
	if k != "band" and k != "out":
		_e_ring_r(c, br, br * fl, MB.di, 1.0, C_RED.darkened(d))
	if k != "bull":
		draw_colored_polygon(_e_pts(c, br * MB.bo, br * MB.bo * fl, 14),
				C_GREEN.darkened(d))
		draw_colored_polygon(_e_pts(c, br * MB.bi, br * MB.bi * fl, 10),
				C_RED.darkened(d))

	match k:
		"band":
			# 폭을 주고받는다. 한쪽이 굵어지면 반드시 다른 쪽이 가늘어진다.
			# 속살과 겉살이 서로의 거울이 되도록 부호만 보고 갈린다.
			var up: bool = float(m.v[0]) > 0.0
			var wt: float = 0.24 if up else 0.06
			var wd: float = 0.07 if up else 0.26
			_e_ring_r(c, br, br * fl, 0.53 - wt * 0.5, 0.53 + wt * 0.5, acc)
			_e_ring_r(c, br, br * fl, 1.0 - wd, 1.0,
					C_RED.lightened(0.25).darkened(dim))
			# 원래 폭을 유령선으로 남겨 "무엇이 무엇으로 바뀌었는가" 를 읽힌다
			for q in [MB.ti, MB.to, MB.di]:
				_e_ring_w(c, br * q, br * q * fl, 1.0, ghost)
		"slide":
			# 띠가 더블 바로 안쪽으로 옮겨간다. 원래 자리와 새 자리를 같이 보인다.
			var w: float = MB.to - MB.ti
			_e_ring_r(c, br, br * fl, MB.ti, MB.to, ghost)
			_e_ring_r(c, br, br * fl, MB.di - w - 0.02, MB.di - 0.02, acc)
			for i in 4:
				var a := float(i) * TAU * 0.25 + step * 0.5
				var u := Vector2(sin(a), -cos(a))
				draw_line(c + Vector2(u.x * br * 0.62, u.y * br * 0.62 * fl),
						c + Vector2(u.x * br * 0.76, u.y * br * 0.76 * fl),
						acc, 1.0)
		"ring":
			# 안쪽에 띠가 하나 더 생긴다. 기존 띠는 초록 그대로 두어 "추가" 로 읽힌다.
			_e_ring_r(c, br, br * fl, MB.ti, MB.to, C_GREEN.darkened(d))
			# 두 띠 사이를 비워 두 개임이 세어지게 한다. 얇으면 무늬로 읽힌다.
			_e_ring_r(c, br, br * fl, 0.33 - 0.075, 0.33 + 0.075, acc)
		"bull":
			# 불은 넓어지고 한복판은 좁아진다. 원래 불 크기를 유령선으로.
			draw_colored_polygon(_e_pts(c, br * MB.bo * 1.55,
					br * MB.bo * 1.55 * fl, 14), acc)
			draw_colored_polygon(_e_pts(c, br * MB.bi * 0.65,
					br * MB.bi * 0.65 * fl, 10),
					C_RED.lightened(0.2).darkened(dim))
			_e_ring_w(c, br * MB.bo, br * MB.bo * fl, 1.0, ghost)
		"out":
			# 판이 커진다. 바탕을 줄여 그렸으므로 그 바깥이 새로 생긴 땅이다.
			_e_ring_r(c, br, br * fl, MB.di, 1.0, C_RED.darkened(d))
			_e_ring_r(c, br, br * fl, 1.0, r / br, acc)
			_e_ring_w(c, br, br * fl, 1.0, ghost)
		"swap":
			# 가장 작은 칸 v 개가 최대값이 된다. 바뀌는 칸 수를 그대로 칠한다.
			# 칸 값이 최대로 "올라간다". 판 밖으로 삐져나오게 그려 승격을 보인다.
			# 짝패도 부채꼴을 쓰므로 이 삐침이 둘을 가르는 유일한 표식이다.
			var cnt: int = clampi(int(m.v), 1, MB_SEG)
			for i in cnt:
				var a := float(i * 2) * step
				draw_colored_polygon(_e_band(c, br * 1.14, br * 1.14 * fl,
						br * MB.bo, br * MB.bo * fl,
						a + step * 0.12, a + step * 0.88, 3), acc)
		"odd":
			# 붙은 두 칸이 같은 값이 된다. 바깥에서 다리로 묶어 "짝" 을 명시한다.
			# 판갈이와 갈리는 지점은 이 다리와, 부채꼴이 판 안에 머문다는 것이다.
			for pair in [0, 4, 8]:
				for j in 2:
					var a := float(pair + j) * step
					draw_colored_polygon(_e_band(c, br * MB.di, br * MB.di * fl,
							br * MB.bo, br * MB.bo * fl, a, a + step, 3),
							acc if j == 0 else acc.darkened(0.3))
				var a0 := float(pair) * step
				draw_colored_polygon(_e_band(c, br * (MB.di + 0.07) + 0.8,
						(br * (MB.di + 0.07) + 0.8) * fl,
						br * (MB.di + 0.07) - 0.8,
						(br * (MB.di + 0.07) - 0.8) * fl,
						a0, a0 + step * 2.0, 8), acc)


# rot 은 기본 각도에서 더 돌릴 양(레일 정렬 · 탁자 위 흩뿌림), a 는 알파(focus 감쇠).
# 회전 인자 이름은 draw_item_sticker 이 이미 쓰는 rot 에 맞췄고,
# 알파 인자를 뒤에 덧붙인 것은 _icon_modifier 가 a 를 받아들인 선례와 같은 방식이다.
func _icon_dart(c: Vector2, dl: float, id: String, dim := 0.0,
		rot := 0.0, a := 1.0, sh := true, spin := 0.0) -> void:
	# 기본 각도. 촉이 오른쪽 위, 꼬리가 왼쪽 아래로 눕는다.
	# (옛 주석은 _draw_darts 와 같은 각이라고 했지만 그쪽은 꼬리가 오른쪽 위라
	#  실제로는 정반대였다. 지금은 _draw_darts 도 이 함수를 쓴다.)
	var dir := Vector2(6.0, -10.0).normalized().rotated(rot)
	var nrm := Vector2(-dir.y, dir.x)
	# 굵기는 길이를 따라간다. 절대값으로 두면 dl 을 키웠을 때 길기만 하고
	# 얇은 막대가 된다 — 손 부채(dl 30)에서 실제로 그렇게 나왔다.
	# 기준은 테이블 크기 dl 19. 바닥을 둬 짧게 부르는 자리가 실오라기가
	# 되는 것을 막는다. 보드에 꽂힌 다트가 그 바닥에 걸려 있었는데
	# (dl 7 → 10 → 지금 16), 굵기가 안 늘어 길이만 긴 막대로 보였다.
	# 지금은 16/19 = 0.84 라 처음으로 바닥 위에 선다 — 바닥이 걸리는
	# 자리는 이제 다트 아이콘을 아주 작게 부르는 곳뿐이다.
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
	# 날개 — 실제 깃은 십자로 세운 두 장이다. 자루가 자기 축으로 구르면
	# 한 쌍은 정면(넓게), 나머지 한 쌍은 옆면(얇게)으로 돌아간다. 그
	# 폭 둘을 spin 의 cos·sin 으로 갈라 그리면 구름이 폭 변화로 읽히고,
	# **길이는 안 건드린다** — 막대는 굴러도 늘지 않는다.
	# 넓은 쪽은 |cos|·|sin| 중 큰 것이라 0.707~1.0 사이를 오간다. 십자
	# 깃이 실제로 그렇다 — 완전히 사라지는 순간이 없다.
	var w0 := c - dir * dl * 0.6
	var fa: float = fin * maxf(absf(cos(spin)), absf(sin(spin)))
	var fb: float = fin * minf(absf(cos(spin)), absf(sin(spin)))
	draw_colored_polygon(PackedVector2Array([w0, w0 + nrm * fa - dir * dl * 0.2,
			tail, w0 - nrm * fa - dir * dl * 0.2]), col)
	# 옆면으로 선 나머지 한 장. 이 얇은 선이 구르는 것을 읽히게 한다.
	if fb > 0.5:
		var fm := w0.lerp(tail, 0.45)
		draw_line(fm + nrm * fb, fm - nrm * fb,
				Color(col.darkened(0.4), a), maxf(1.0, k * 0.9))

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
#  이름을 _icon_mod 로 못 짓는다 — 코드에서 mod 는 이미 보드 확장다.
#
#  ── 실루엣 ──
#  이 게임은 이미 네 실루엣을 썼다.
#    아이템     꽉 찬 원반      draw_item_sticker
#    보드 확장       불투명 사각판    _icon_mod
#    다트       긴 대각 획      _icon_dart
#    빈 동전 슬롯 홈   속 빈 고리      _panel_draw
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


# ══════════════════════════════════════════════════════════
#  사탕 · 뱃지 아이콘
# ──────────────────────────────────────────────────────────
#  둘 다 여태 글자 두 자로 그려져 있었다(_obj_paint 주석: "아트 방향이
#  미정이라 실루엣만 세워 둔다"). 칸이 26px 이라 이름이 안 들어가고,
#  들어가도 "싱글"과 "삯"은 같은 크기의 검은 얼룩이다.
#
#  사탕는 **판 자체를 어휘로 쓴다.** 다섯 종이 전부 트랙 강화라 무엇을
#  올리는지가 곧 판의 어느 고리인지다 — 같은 원에 다른 고리를 밝히면
#  다섯이 한 가족으로 읽히고, 새 영역이 생겨도 고리 하나만 더하면 된다.
#  이름을 몰라도 어디가 세지는지는 보인다.
#
#  뱃지는 **받는 것의 모양**을 쓴다. 골드는 동전, 다트는 다트, 테이블은
#  늘어선 칸. 뱃지 열 종이 서로 다른 것을 주므로 한 가족일 이유가 없다.
# ══════════════════════════════════════════════════════════

# 판 고리의 안팎 비율. hit_info 의 rt_* 와 같은 뜻이되 아이콘용 고정값이다 —
# 보드 확장이 판을 주무르면 아이콘까지 흔들려서 "어느 고리인가" 가 안 읽힌다.
const ICO := {
	"bull": 0.20, "in_lo": 0.20, "in_hi": 0.46,
	"trp_lo": 0.46, "trp_hi": 0.60,
	"out_lo": 0.60, "out_hi": 0.84,
	"dbl_lo": 0.84, "dbl_hi": 1.00,
}


func _ring(c: Vector2, r: float, lo: float, hi: float, col: Color) -> void:
	draw_colored_polygon(annulus_at(c, r * lo, r * hi, 0.0, TAU, 24), col)


# 사탕 — 작은 판에 해당 고리 하나만 밝힌다.
#
# 처음엔 고리 다섯을 다 그렸다가 뭉갰다. 반지름이 9px 이라 한 고리가
# 2px 이고, 꺼진 고리끼리는 서로 안 갈린다. **밝히는 것은 늘 하나**이므로
# 판은 한 색으로 깔고 그 위에 켜진 고리만 얹는다 — 경계선은 켜진 고리의
# 가장자리가 대신한다. 그리는 것이 줄면 작은 칸에서 더 잘 읽힌다.
# ── 사탕 그림 ────────────────────────────────────────
#  모델을 작은 3D 무대에 세워 한 번 굽고, 그 그림을 아이콘으로 쓴다.
#  다트판(_bd3_)·컵(_cup3_)이 이미 쓰는 어법이다 — 화면은 2D 로 남고
#  물건만 3D 다. 한 사탕에 무대 하나, UPDATE_ONCE 라 굽는 것은 한 번뿐이다.
#
#  트랙과 사탕을 짝지었다. 색이 아니라 **모양**이 트랙을 말한다 —
#  26px 칸에서 색 다섯은 서로 안 갈리지만 곰·꼬임·지팡이·막대·판은 갈린다.
const CANDY3 := {
	"c_sg": "gummy",       # 싱글 — 곰젤리
	"c_db": "twist",       # 더블 — 꼬인 사탕
	"c_tr": "cane",        # 트리플 — 지팡이 사탕
	"c_bl": "pop",         # 불 — 막대사탕
	"c_bo": "bar",         # 보드 아웃 — 초콜릿 판
}
const CANDY_VP := Vector2i(34, 46)     # 굽는 크기. 칸(26x38)보다 한 뼘 크다

var candy_vp := {}                     # id → SubViewport


# 무대 하나를 짓는다 — 뷰포트 · 메시 · 빛 · 카메라. 회전은 안 건드린다,
# 정적 굽기(_candy_tex)와 라이브 스핀(_candy_tex_live)이 각자 정한다.
func _candy_build(nm: String) -> Dictionary:
	var mesh: Mesh = load("res://assets/candy/%s.obj" % nm)
	if mesh == null:
		return {}
	var vp := SubViewport.new()
	vp.size = CANDY_VP
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.gui_disable_input = true
	add_child(vp)

	var ab := mesh.get_aabb()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	# obj 의 mtl 은 pymeshlab 이 텍스처 없는 것으로 덮어 쓴다. 여기서 물린다.
	var mat := StandardMaterial3D.new()
	var tex: Texture2D = load("res://assets/candy/%s.jpg" % nm)
	if tex != null:
		mat.albedo_texture = tex
	mat.roughness = 0.55
	mat.specular = 0.30
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var k := 1.0 / maxf(maxf(ab.size.x, ab.size.y), 0.001)
	mi.scale = Vector3.ONE * k
	mi.position = -ab.get_center() * k
	vp.add_child(mi)

	var lt := DirectionalLight3D.new()
	lt.rotation_degrees = Vector3(-46.0, -28.0, 0.0)
	lt.light_energy = 1.5
	vp.add_child(lt)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.70, 0.80)
	env.ambient_light_energy = 0.9
	we.environment = env
	vp.add_child(we)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = 1.18                      # 1.0 짜리 물건에 여백 한 뼘
	cam.near = 0.01
	cam.far = 10.0
	vp.add_child(cam)
	cam.global_position = Vector3(0.0, 0.0, 3.0)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	return {"vp": vp, "mi": mi}


# 그 사탕의 그림(정지). 컬렉션·소비 칸처럼 늘 같은 자세로 보이는 자리다.
# 없으면 굽고, 못 구우면 null 이다(헤드리스).
func _candy_tex(id: String) -> Texture2D:
	if candy_vp.has(id):
		var v: SubViewport = candy_vp[id]
		return v.get_texture() if is_instance_valid(v) else null
	if not _has_renderer() or not CANDY3.has(id):
		return null
	var b := _candy_build(String(CANDY3[id]))
	if b.is_empty():
		return null
	candy_vp[id] = b.vp
	(b.mi as MeshInstance3D).rotation_degrees = Vector3(0.0, -24.0, 0.0)
	return b.vp.get_texture()


var candy_live := {}       # id → {"vp":SubViewport,"mi":MeshInstance3D} — 테이블에 구르는 사탕


# 테이블에 떨어진 사탕. 물리가 이미 계산해 둔 값을 그대로 3D 로 옮긴다 —
# 카드 뒤에 아이콘을 얹는 대신 모델 자체가 구르며 떨어진다.
#   roll — 미끄러진 거리를 그대로 도는 각으로 쓴다(DROP.candy_roll,
#          _drop_extras 가 매 프레임 적분). 다른 물체와 공유하는 psi/om
#          은 마찰(a_spin 30)이 0.09초 안에 죽여서 3D 로 옮겨도 표가 안
#          난다 — 그래서 사탕만 따로 "미끄러진 만큼 구른다" 축을 하나 둔다.
#   wob  — 충격의 크기로 매기는 감쇠 진동. 착지 잔진동만 담당한다.
# live 가 참인 동안(아직 다 안 멈춤) 매 프레임 다시 굽고, 멈추면 마지막
# 자세로 얼린다 — _bd3_fly 와 같은 어법이다. 상점엔 사탕이 한 번에
# 한 장뿐이라(매대 규칙) 인스턴스를 공유해도 겹칠 일이 없다.
func _candy_tex_live(id: String, roll: float, wob: float, live: bool) -> Texture2D:
	if not candy_live.has(id):
		if not _has_renderer() or not CANDY3.has(id):
			return null
		var b := _candy_build(String(CANDY3[id]))
		if b.is_empty():
			return null
		candy_live[id] = b
	var e: Dictionary = candy_live[id]
	if not is_instance_valid(e.vp):
		candy_live.erase(id)
		return null
	var mi: MeshInstance3D = e.mi
	# 다트와 같은 이유 · 같은 길이다 — Basis 를 통째로 assign 하는 길은
	# 이 뷰포트 조합에서 렌더가 깨졌다(듬성듬성한 점만 찍혔다. 원인은
	# 못 잡았다). rotation.x/y/z 개별 대입은 그려지는 것을 확인했으므로
	# 그 길을 쓴다. x·y 는 정지 아이콘과 같은 -24° 로 고정하고 roll 은
	# z 하나에만 싣는다 — 완전한 길이 불변은 아니지만(실측 26~37px 정도
	# 왕복) 두 축을 다 돌리던 것보다 훨씬 안정적이다.
	mi.rotation.x = 0.0
	mi.rotation.y = deg_to_rad(-24.0)
	mi.rotation.z = roll + clampf(wob * 2.2, -0.5, 0.5)
	var vp: SubViewport = e.vp
	vp.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_ONCE)
	return vp.get_texture()


# 사탕 몸통 색 — 판이 이미 쓰는 색에서 가져온다. 트랙과 색이 같아야
# 「어느 자리를 올리는 사탕인가」가 그림만으로 읽힌다.
const CANDY := {
	"c_sg": C_LIGHT,          # 싱글 — 판의 밝은 칸
	"c_db": C_GREEN,          # 더블 — 판의 초록 띠
	"c_tr": C_RED,            # 트리플 — 판의 붉은 띠
	"c_bl": C_ACC,            # 불 — 한복판
	"c_bo": C_WIRE,           # 보드 아웃 — 판 밖
}


# 사탕. 실루엣이 먼저다 — 26px 칸에서 고리 그림은 다른 물건과 안 갈리지만
# 포장 끝 둘이 달린 몸통은 한눈에 사탕이다. 고리는 그 얼굴에 얹는다.
#
# r 은 **몸통** 반지름이다. 포장까지 1.5r 이므로 칸 반폭보다 작게 준다.
func _icon_cons(c: Vector2, r: float, id: String, a := 1.0) -> void:
	# 모델이 있으면 그것을 쓴다. 없는 자리(헤드리스·프로브)는 아래 손그림이
	# 그대로 선다 — 프로브가 렌더러 없이 도는 자리가 있다.
	var t := _candy_tex(id)
	if t != null:
		var h := r * 3.1
		var w := h * float(CANDY_VP.x) / float(CANDY_VP.y)
		draw_texture_rect(t, Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h)),
				false, Color(1.0, 1.0, 1.0, a))
		return
	var body: Color = CANDY.get(id, C_DIM)
	body = Color(body, a)
	var ink := Color(C_DARK.darkened(0.25), a)
	# 포장 끝. 몸통에 물린 자리는 좁고 바깥은 벌어진다.
	for sgn in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
				Vector2(c.x + sgn * r * 0.72, c.y - r * 0.24),
				Vector2(c.x + sgn * r * 0.72, c.y + r * 0.24),
				Vector2(c.x + sgn * r * 1.52, c.y + r * 0.62),
				Vector2(c.x + sgn * r * 1.52, c.y - r * 0.62)]),
				Color(body.darkened(0.30), a))
	draw_circle(c, r, body)
	# 트랙 표식. 켜진 고리 하나만 얹는다 — 몸통 색이 이미 트랙을 말하므로
	# 여기서는 어느 고리인지만 못 박으면 된다.
	match id:
		"c_db":
			_ring(c, r * 0.80, ICO.dbl_lo, ICO.dbl_hi, ink)
		"c_tr":
			_ring(c, r * 0.80, ICO.trp_lo, ICO.trp_hi, ink)
		"c_sg":
			_ring(c, r * 0.80, ICO.out_lo, ICO.out_hi, ink)
		"c_bl":
			draw_circle(c, r * 0.34, ink)
		"c_bo":
			# 판 밖이다 — 몸통 안에 판을 작게 두고 밖으로 획 넷을 뻗는다.
			draw_circle(c, r * 0.34, ink)
			for i in 4:
				var d := Vector2(cos(TAU * float(i) * 0.25 + PI * 0.25),
						sin(TAU * float(i) * 0.25 + PI * 0.25))
				draw_line(c + d * r * 0.50, c + d * r * 0.92, ink,
						maxf(r * 0.16, 1.0))
	# 광택 한 점. 몸통이 공이라는 것을 이 점 하나가 말한다.
	draw_circle(c + Vector2(-r * 0.34, -r * 0.36), maxf(r * 0.17, 1.0),
			Color(C_LIGHT, a * 0.55))


func _icon_area(c: Vector2, r: float, id: String, a := 1.0) -> void:
	var off := Color(C_WIRE.lightened(0.10), a)
	var on := Color(C_ACC, a)
	draw_circle(c, r, off)
	match id:
		"c_db":
			_ring(c, r, ICO.dbl_lo, ICO.dbl_hi, on)
		"c_tr":
			_ring(c, r, ICO.trp_lo, ICO.trp_hi, on)
		"c_sg":
			# 싱글은 고리가 둘이다(트리플 안쪽과 바깥쪽). 넓은 쪽만 켜면
			# 트리플과 같은 그림이 되므로 둘 다 켠다.
			_ring(c, r, ICO.out_lo, ICO.out_hi, on)
			_ring(c, r, ICO.in_lo, ICO.in_hi, on)
		"c_bl":
			draw_circle(c, r * 0.34, on)
		"c_bo":
			# 판에 없는 영역이다 — 판을 어둡게 죽이고 밖으로 네 획을 뻗는다.
			draw_circle(c, r * 0.88, Color(C_DARK.darkened(0.30), a))
			for i in 4:
				var d := Vector2(cos(TAU * float(i) * 0.25 + PI * 0.25),
						sin(TAU * float(i) * 0.25 + PI * 0.25))
				draw_line(c + d * r * 1.10, c + d * r * 1.66, on,
						maxf(r * 0.22, 1.0))
		_:
			draw_circle(c, r * 0.34, Color(C_DARK.darkened(0.30), a))


# 뱃지 — 받는 것의 모양. 칸이 작아 획 셋을 안 넘긴다.
func _icon_tag(c: Vector2, r: float, kind: String, a := 1.0) -> void:
	var col := Color(C_GOLD, a)
	var w := maxf(r * 0.26, 1.0)
	match kind:
		"gold", "free":
			# 동전. 외상은 그 동전에 빗금을 그어 "안 낸다" 를 만든다.
			draw_colored_polygon(_e_pts(c, r * 0.86, r * 0.62, 12), col)
			if kind == "free":
				draw_line(c + Vector2(-r * 0.9, r * 0.7), c + Vector2(r * 0.9, -r * 0.7),
						Color(C_DARK.darkened(0.4), a), w * 1.4)
		"dart":
			# 촉이 왼쪽 아래, 꼬리가 오른쪽 위. 벽에 꽂힌 자루와 같은 기울기다.
			var dv := Vector2(0.80, -0.62).normalized()
			draw_line(c - dv * r * 0.9, c + dv * r * 0.9, Color(C_TXT, a), w)
			draw_colored_polygon(PackedVector2Array([
					c - dv * r * 1.15, c - dv * r * 0.35 + Vector2(-dv.y, dv.x) * r * 0.34,
					c - dv * r * 0.35 - Vector2(-dv.y, dv.x) * r * 0.34]), col)
		"track":
			# 판 하나와 위로 뻗은 화살 — 어느 고리인지는 굴려 봐야 안다.
			draw_circle(c + Vector2(0.0, r * 0.18), r * 0.66,
					Color(C_WIRE.darkened(0.18), a))
			draw_circle(c + Vector2(0.0, r * 0.18), r * 0.24, col)
			draw_colored_polygon(PackedVector2Array([
					c + Vector2(0.0, -r * 1.15), c + Vector2(-r * 0.46, -r * 0.52),
					c + Vector2(r * 0.46, -r * 0.52)]), col)
		"cons":
			# 꾸러미 — 상점 테이블 위의 사탕과 같은 네모다.
			draw_rect(Rect2(c - Vector2(r * 0.74, r * 0.74),
					Vector2(r * 1.48, r * 1.48)), Color(C_ACC, a))
			draw_rect(Rect2(c - Vector2(r * 0.74, r * 0.16),
					Vector2(r * 1.48, r * 0.32)), Color(C_DARK.darkened(0.3), a))
		"item":
			# 동전 원반. 동전 슬롯에 붙는 그것이다.
			draw_circle(c, r * 0.84, Color(C_CHIP.lightened(0.10), a))
			draw_circle(c, r * 0.40, Color(C_DARK.darkened(0.3), a))
		"reroll":
			# 한 바퀴 돌아오는 화살. 리롤 관례 그대로다.
			draw_arc(c, r * 0.72, PI * 0.35, PI * 1.85, 16, col, w)
			draw_colored_polygon(PackedVector2Array([
					c + Vector2(r * 0.72, -r * 0.30), c + Vector2(r * 0.28, -r * 0.30),
					c + Vector2(r * 0.62, -r * 0.90)]), col)
		"shop":
			# 늘어선 테이블 칸. 셋째 칸만 밝은 것이 "한 칸 더" 다.
			for i in 3:
				var bx := c + Vector2(-r * 0.94 + float(i) * r * 0.72, -r * 0.42)
				draw_rect(Rect2(bx, Vector2(r * 0.50, r * 0.84)),
						col if i == 2 else Color(C_WIRE.darkened(0.15), a))
		"picks":
			# 부챗살로 벌린 카드 셋 — 제약 선택지가 그 모양으로 깔린다.
			for i in 3:
				var rot := deg_to_rad(-22.0 + float(i) * 22.0)
				var up := Vector2(0.0, -1.0).rotated(rot)
				var sd := Vector2(1.0, 0.0).rotated(rot) * r * 0.30
				var bt := c + Vector2(0.0, r * 0.62)
				draw_colored_polygon(PackedVector2Array([
						bt - sd, bt + sd, bt + sd + up * r * 1.28,
						bt - sd + up * r * 1.28]),
						col if i == 1 else Color(C_WIRE.darkened(0.15), a))
		_:
			draw_circle(c, r * 0.7, col)


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
		# 여섯 중 유일하게 보드가 아니라 동전을 건드리는 제약이라 혼자만
		# 기하가 아니라 물건이다 — 그 어긋남이 곧 "대상이 다르다"는 표시다.
		# 동전 슬롯이 봉인 동전에 이미 "봉인"을 C_MULT 로 찍으므로 자물쇠는
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
#  드는 것이 둘이다. 테이블의 물건(hand_src 0)은 위 문단 그대로 면 위를 밀려
#  다니고, 동전 슬롯의 동전(hand_src 1)은 물리 물체가 아니라 커서 밑의 그림뿐이다.
#  동전 슬롯 동전 쪽은 적분기·펠트·겹침 어디에도 안 닿는다 — 그려지고, 놓이면 팔린다.
#
#  바깥과 닿는 곳은 열이다.
#    _hand_press/_motion/_release  입력          (_unhandled_input)
#    _hand_update(d)               매 프레임      (_drop_update 첫 줄)
#    _hand_abort()                 손을 비운다     (_drop_roll · _drop_settle
#                                                  · _reroll · _next_leg 맨 앞)
#    _shop_tap(i) / _rack_tap(i)   고르기          (_hand_release 의 탭 갈래)
#    _chute_click(z) / _pay_click() 확정           (_click 의 S.SHOP)
#    _chute_draw()/_hold_draw()/_fly_draw()        (_table_draw · _draw_shop 말미)
#    buy_sel / sell_sel            고른 매물 · 고른 동전. 서로 배타
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
var hand_src := 0                # 무엇을 들었나 (0 = 테이블 물건 · 1 = 동전 슬롯 동전)
var peel_t := 0.0                # 동전 슬롯에서 뗀 뒤 지난 시간(초). 말림 감쇠에만 쓴다
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
	"toss": 0.16,
	#  손 속도 → 물체 속도 비율. 손은 v_cap 1800 까지 가지만 물건은 그만큼 안 난다.
	#  옛 값 0.34 는 물체 속도 618 면px/s(v_cap 의 34%) 만 넘으면 곧장 아래
	#  toss_cap 에 눌렸다 — 보통 세기로 후려쳐도 다 같은 세기로 읽혔다.
	#  0.16 으로 낮춰 그 문턱을 1625(v_cap 의 90%) 까지 밀어낸다 — 살살
	#  밀 때부터 온 힘으로 후려칠 때까지 거의 전 구간이 다른 세기로 읽힌다.
	"toss_cap": 260.0,
	#  상한(면px/s). 마찰 a_fric 520 에서 미끄럼 거리 v²/2a = 65.0 면px
	#  (화면 가로 65 · 세로 51), 멈추기까지 0.50초. "후려치면 판을 가로지른다"
	#  의 상한이다. 옛 42.4 면px 는 손 속도가 조금만 세도 다 같은 거리로
	#  뭉개졌다 — 최대 거리를 늘려 세기 차이가 거리로도 드러나게 했다.
	"toss_spin": 0.010,
	#  던진 속력 → 회전(rad/s). 상한에서 2.6, a_spin 30 으로 0.087초에 멎는다.
	#  미끄럼보다 훨씬 짧게 두는 것이 의도다 — 놓는 손짓의 잔상이지 팽이가 아니다.
}


# 창구 둘. 펠트 사다리꼴의 좌우 빗변이 그대로 창구다 —
# 왼쪽으로 밀면 팔고, 오른쪽으로 밀면 산다.
#
# 방향이 곧 뜻이라 라벨을 안 읽어도 성립한다. 대신 반대로 밀면 거절한다:
# 동전 슬롯의 동전은 왼쪽만, 테이블의 물건은 오른쪽만 받는다. 계산대 하나가 양방향이던
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

# 손이 사는 화면. 상점과 **판 중**이다.
#
# 사탕과 동전 슬롯 순서 변경은 화면에 늘 보인다(_hud_draw 가 정산·제목류만
# 빼고 매 프레임 그린다). 그런데 눌리는 화면은 상점 하나뿐이었다 — 보이는데
# 안 먹는 것은 플레이어에게 규칙이 아니라 고장이다.
#
# 확정 규칙(docs/게임내용.md): 사탕는 "상점에서 즉시 쓸 수 있고, 보관할 수
# 있고, 판 중에도 쓸 수 있다". 동전 슬롯 순서는 발동 순서라 판을 보면서
# 고칠 수 있어야 뜻이 있다.
#
# 판 고르기(LEG)와 제약 고르기(STAGE)도 산다. 두 화면은 _hud_draw 가 동전 슬롯과
# 사탕 칸을 그대로 그리고, LEG 는 _tip_hit 이 툴팁까지 띄운다 — 이름과 효과를
# 읽어 주고 나서 누르면 아무 일도 안 나는 자리였다. 무엇을 들고 있는지가 곧
# "던질까 건너뛸까" 의 근거인데, 고르는 자리에서 그걸 못 고쳤다.
#
# 정산(RESOLVE)만 뺀다. 큐가 동전 슬롯 인덱스를 들고 있어서 순서를 바꾸면 엉뚱한
# 카드가 빛나고, 사탕 칸이 정산 넘기기 클릭을 훔친다.
func _hand_live() -> bool:
	if state == S.SHOP:
		return not sweep_live
	if state == S.LEG or state == S.STAGE:
		return true
	return _is_play() and state != S.RESOLVE


# 동전 슬롯 동전을 집는다. 집었으면 true. 파는 것은 뗄 때 _can_sell 이 다시 판다.
func _rack_grab(m: Vector2) -> bool:
	for k in mini(owned.size(), GameData.max_items()):
		if _slot_rect(k).has_point(m):
			hand_st = H.ARMED
			hand_src = 1
			hand_i = k
			hand_p0 = m
			hand_m = m
			hand_far = 0.0
			return true
	return false


# true 를 돌려주면 _click 을 안 부른다(삼킨다).
func _hand_press(m: Vector2) -> bool:
	if swap_live:
		return false
	if _autoplay:
		return false                          # 좌표 입력은 오토플레이의 어휘가 아니다
	# 사탕 슬롯 — 상점과 판 중. 사용 확정은 뗄 때다.
	if _hand_live():
		var ci := _cons_hit(m)
		if ci >= 0:
			hand_st = H.ARMED
			hand_src = 4
			hand_i = ci
			hand_p0 = m
			hand_m = m
			hand_far = 0.0
			return true
	# 판매 버튼 — 상점 밖에서 파는 유일한 자리다. 동전 슬롯 잡기보다 먼저
	# 본다. 확정은 **뗄 때**고 끌고 나가면 취소다 — 창구·사탕 칸과 같은
	# 문법이라 실수로 파는 경로가 없다.
	if _sell_btn_rect().has_point(m):
		hand_st = H.ARMED
		hand_src = 5
		hand_i = sell_sel
		hand_p0 = m
		hand_m = m
		hand_far = 0.0
		return true
	# 동전 슬롯의 동전 — **상점 잠금 위**다. 순서 바꾸기는 판 위에서도 돌아야
	# 하므로 화면을 안 가린다(_can_rack_move). 훔칠 걱정이 없는 것은 y 가
	# 갈려 있기 때문이다 — 동전 슬롯 y[20,64](상단바가 숨으면 [4,48]) 아래로
	# 창구·버튼 y[112,334], 매물 최상단 99.3, 그리고 조준이 잠기는 반경
	# BC.y - 98*1.22 = 76.4 가 전부 내려가 있다. 누른 자리가 동전 슬롯 안이면
	# 조준·구매·창구 어느 것도 그 클릭을 원한 적이 없다.
	if _can_rack_move() and _rack_grab(m):
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
	# 동전 슬롯은 위에서 이미 집었다. 여기 남은 것은 빈 칸과 판 여백이다 —
	# 삼켜서 테이블 클릭으로 안 새게 한다.
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
				_hand_abort()     # 창구·사탕 칸은 버튼이다. 끌면 취소다
			else:
				_hand_take()


func _hand_take() -> void:
	hand_st = H.CARRY
	hand_v = Vector2.ZERO
	hand_zone = -1
	buy_sel = -1
	sell_sel = -1             # 드래그는 _click 을 안 거쳐 _sell_hit 의 낙수가 안 온다
	if hand_src == 1:
		# 동전 슬롯 동전은 물리 물체가 아니다. 적분기에 넣을 것이 없어 커서만 따라간다.
		hand_off = Vector2.ZERO
		peel_t = 0.0              # 떼는 순간. 말림이 여기서부터 잦아든다
		_sfx("hand_take")
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
	_sfx("hand_take")


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
		if src == 5:
			# 뗄 때도 같은 버튼 안이어야 한다. 버튼의 문법 그대로다.
			if _sell_btn_rect().has_point(m) and i >= 0 and i < owned.size():
				_sell(i)
		elif src == 2:
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

	# 동전 슬롯 동전 — 왼쪽 창구는 판매, 다른 동전 슬롯 칸 위는 순서 바꾸기.
	if src == 1:
		if z == Z_SELL and _can_sell() and i >= 0 and i < owned.size():
			_sell(i)
		elif z == Z_BUY:
			pay_msg = "오른쪽은 사는 창구다"
			pay_msg_t = HAND.msg_t
			_deny()
		else:
			# 아이템 순서 변경 — 확정 규칙이다(아이템순서변경=True). 발동이
			# 동전 슬롯 순서라 순서가 값을 바꾸는데, 지금까지 되팔고 다시 사는 것
			# 말고는 고칠 길이 없었다. "득점 시작 시 순서 스냅샷" 계약은
			# _can_rack_move 가 RESOLVE 를 접어서 지킨다 — 큐가 서고 나면
			# 손이 아예 안 열린다.
			var j := _slot_at(m)
			if j >= 0 and i >= 0 and i < owned.size() and j != i:
				_rack_reorder(i, j)
			else:
				_sfx("hand_drop")       # 그냥 제자리로 돌아간다
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
	_sfx("hand_drop")
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
	it.handled = true    # 여기서부터 3D 구름(roll)이 붙는다 — 손이 던졌다
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
	# 쥔 것이 **어느 배열의** 몇째인가. 넷 다 drop 크기로 재고 있었다 —
	# 사탕 칸은 cons 의 색인이고 창구는 배열이 아니라 구역 번호다.
	# 테이블이 다 팔려 drop 이 비면 사탕도 창구도 손에서 놓쳐 버렸다.
	var n_src: int = drop.size()
	match hand_src:
		1: n_src = owned.size()
		2: n_src = 2                          # Z_SELL · Z_BUY
		4: n_src = cons.size()
		5: n_src = owned.size()               # 판매 버튼도 owned 의 색인이다
	# 사는 화면도 쥔 것에 따라 다르다. 매물(0)과 창구(2)는 상점의 물건이라
	# 상점을 벗어나면 손을 놓는다. 동전 슬롯(1)·사탕(4)·판매 버튼(5)은
	# 판 중에도 산다.
	var live := _hand_live()
	if hand_src == 0 or hand_src == 2:
		live = state == S.SHOP and not sweep_live
	if not live or hand_i < 0 or hand_i >= n_src:
		_hand_abort()
		return
	# 창 밖에서 떼어 released 를 못 받은 경우의 안전망
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_hand_release(hand_m)
		return
	if hand_st != H.CARRY:
		return

	# 래치는 히스테리시스로 건다 — 경계에서 소리와 창구 얼굴이 연타되지 않는다.
	# 창구는 상점에만 있다. 판 중에 동전 슬롯 동전을 끌 때 이것을 걸면 없는 창구의
	# 소리가 나고, 뗄 때 "오른쪽은 사는 창구다" 가 뜬다.
	var pad: float = HAND.latch_gap if hand_zone >= 0 else 0.0
	var z := -1
	if _can_sell():
		z = _chute_at(hand_m, pad)
	if z >= 0 and z != hand_zone:
		_sfx("chute_enter")
	hand_zone = z

	if hand_src == 1:
		return                                  # 동전 슬롯 동전은 커서에 붙어 다닌다
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
	_sfx("shop_select" if buy_sel >= 0 else "shop_deselect")


# 동전 슬롯 동전을 끌지 않고 톡 눌렀을 때. 두 클릭 경로의 1단계다.
func _rack_tap(i: int) -> void:
	buy_sel = -1
	if i < 0 or i >= owned.size() or not _can_sell():
		sell_sel = -1
		return
	sell_sel = -1 if sell_sel == i else i
	sell_t = 0.0
	_sfx("rack_select" if sell_sel >= 0 else "rack_deselect")


# 커서가 동전 슬롯의 몇째 칸 위인가. 빈 칸도 자리로 친다 — 맨 뒤로 보내는 드롭이다.
func _slot_at(m: Vector2) -> int:
	for k in GameData.max_items():
		if _slot_rect(k).has_point(m):
			return k
	return -1


# 동전 슬롯 순서 바꾸기. i 를 뽑아 j 자리에 끼운다 — 자리를 서로 맞바꾸는 것이
# 아니라 끼워 넣기다. 발동 순서가 곧 동전 슬롯 순서이므로 이 함수가 사실상
# "정산식 편집기"다. 봉인은 동전이 아니라 자리에 걸리는 게 아니라 동전에
# 걸리므로, 같은 동전을 따라가게 한다.
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
	_sfx("rack_move")
	pop(_slot_rect(j).get_center() + Vector2(0.0, 22.0), "순서 변경", C_TXT, 9, 0.8)


# 든 동전의 말림. 뗄 때 크게 젖혔다가 0.11초 만에 잦아들어 손 안에서
# 살짝 말린 채로 남는다. 정착값 0.28 은 "떼어져 있다" 를 말하는 최소치이면서,
# 접는 선을 값 숫자(반지름 13 에서 아래 9.8px)보다 낮게 두는 상한이기도 하다 —
# r*(1-0.78*0.28) = 10.16 > 9.8. 더 올리면 들고 있는 동안 값이 안 보인다.
# 0.32 는 떼는 순간의 튕김이라 값을 잠깐 먹는다. 0.1초짜리라 괜찮다.
func _peel_now() -> float:
	return 0.28 + 0.32 * exp(-peel_t / 0.10)


# 든 동전 슬롯 동전. 물리 물체가 아니라 커서 밑의 그림뿐이다.
#
# **동전 슬롯을 그린 다음**이라는 것이 이 함수가 따로 있는 이유다. 예전에는
# _draw_shop 말미의 _hold_draw 가 그렸는데, _hud_draw 는 그보다 뒤라
# 판(_panel_draw)이 든 동전을 덮었다 — 끌어다 다른 칸 위에 올리는 순간
# 손에 든 것이 판 밑으로 사라져서, 놓을 자리를 보면서 놓을 수가 없었다.
# 상점에서도 그랬다. 순서 바꾸기가 "안 된다" 로 읽히던 자리다.
func _rack_hold_draw() -> void:
	if hand_st != H.CARRY or hand_src != 1:
		return
	if hand_i < 0 or hand_i >= owned.size():
		return
	# 끼워 넣을 자리. 자국(_panel_gap)이 "여기서 뗐다" 를 말하는 동안
	# 이 고리가 "여기로 간다" 를 말한다 — 둘이 같이 서야 이동이 읽힌다.
	# 빈 칸에 떨구면 맨 뒤로 가므로 _rack_reorder 와 **같은 식**으로 접는다.
	var j := _slot_at(hand_m)
	if j >= 0:
		j = mini(j, owned.size() - 1)
		if j != hand_i:
			draw_arc(_slot_rect(j).get_center() + Vector2(0.0, PANEL.chip_dy),
					PANEL.r + 2.0, 0.0, TAU, 24, Color(C_ACC, 0.9), 1.0)
	_e_ring_w(hand_m, PANEL.r + 4.0, (PANEL.r + 4.0) * TBL.flat, 1.0,
			Color(C_ACC if hand_zone == Z_SELL else C_TXT, 0.55))
	draw_item_sticker(hand_m, PANEL.r, owned[hand_i], 0.0, 0.0, 0.0, 12,
			_peel_now())


# 떼어낸 자리. 빈 홈(반지름 0.72)이 아니라 동전과 같은 반지름의 자국이다 —
# "여기 붙어 있었다" 와 "여기는 원래 비어 있다" 가 같은 그림이면 안 된다.
func _panel_gap(i: int) -> void:
	var e := _slot_rect(i).get_center() + Vector2(0.0, PANEL.chip_dy)
	draw_circle(e, PANEL.r, C_FELT.darkened(0.30))
	draw_arc(e, PANEL.r, 0.0, TAU, 24, C_FELT.lightened(0.22), 1.0)


# 창구를 눌렀을 때. 방향이 무엇을 뜻하는지는 여기서도 같다.
func _chute_click(z: int) -> void:
	if z == Z_SELL:
		if _can_sell() and sell_sel >= 0 and sell_sel < owned.size():
			_sell(sell_sel)
			return
		pay_msg = "먼저 판에서 팔 동전을 고른다"
		pay_msg_t = HAND.msg_t
		_deny()
		return
	_pay_click()


func _pay_click() -> void:
	if buy_sel < 0:
		pay_msg = "먼저 테이블에서 살 물건을 고른다"
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
	# 동전 슬롯 동전은 여기서 안 그린다 — _rack_hold_draw 가 판 위에서 맡는다.
	if hand_st != H.CARRY or hand_src != 0:
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
# 덮어 두 다리 중 1.5개가 안 보인다 — 드래그 구매의 첫 다리는 통째로, 동전 슬롯으로
# 가는 두 번째 다리는 0.19초가 가려진다. 그래서 판·버튼 다음에 따로 그린다.
func _fly_draw() -> void:
	for i in mini(drop.size(), stock.size()):
		if drop[i].gone or drop[i].sold <= 0.0:
			continue
		_obj_draw(i, 0.0)


func _drop_arrive(i: int) -> void:
	# 도착에서 튄다. 이륙에서 튀면 동전이 도착하기 0.46초 전에 동전 슬롯이 먼저 튄다 —
	# 지금 있는 연출의 유일한 거짓말이었다.
	var it: Dictionary = drop[i]
	match stock[i].type:
		"item":
			_panel_fire(it.slot)
		"mod":
			pop(it.to, "보드 확장", C_CHIP.lightened(0.25), 13, 0.9)
		_:
			pop(it.to, "탄창 교체", C_GREEN.lightened(0.3), 13, 0.9)

# ══════════════════════════════════════════════════════════
#  툴팁 (마우스 오버)
# ──────────────────────────────────────────────────────────
#  바깥과 닿는 곳은 둘뿐이다.
#    _tip_update(d)  매 프레임 진행     (_process 끝)
#    _tip_draw(sh)   오버레이 다음에    (_draw)
#  동전 슬롯의 호버 링만 tip_slot / tip_a 를 읽는다.
#
#  대상은 매 프레임 새로 찾아 그 프레임에 사탕한다. 인덱스를
#  프레임 너머로 들고 가지 않으므로 상점이 갈리거나 아이템이
#  사라져도 범위를 넘을 수 없다.
# ══════════════════════════════════════════════════════════

const TIP := {
	"w": 178.0,          # 판 폭 (고정 — 대상마다 크기가 출렁이면 눈이 다시 초점을 잡는다)
	"pad": 7.0,
	"gap": 6.0,          # 대상과 판 사이
	"title": 15.0,       # 제목 줄 높이
	"line": 13.0,        # 본문 줄 높이
	"base": 10.0,        # 본문 블록 윗변에서 첫 줄 베이스라인까지 (10pt 의 오름)
	"chip_gap": 5.0,     # 본문 아래끝과 갈래 기본 점수 사이
	"chip_h": 12.0,      # 갈래 기본 점수 높이
	"fade": 14.0,        # 페이드 속도
	"quiet": 6.0,        # shake 가 이보다 크면 아예 안 그린다 (읽을 수 없다)
}

var tip_title := ""
var tip_lines := []             # [{"s": String, "sz": int, "c": Color}]
var tip_chip := {}              # 제목 옆 미니동전로 그릴 아이템 (없으면 빈 사전)
# 갈래 기본 점수 — 툴팁 맨 아래에 한 낱말. "이게 뭐냐" 가 이름만으로는 안 풀린다.
# 동전과 사탕이 둘 다 둥근 판이고 보드 확장과 사진이 둘 다 네모라,
# 그림만으로는 갈래가 안 갈린다. 발라트로가 툴팁 밑에 부스터/조커/타로를
# 기본 점수으로 붙이는 그 자리다.
var tip_tag := ""               # 기본 점수에 적을 낱말. 비면 안 그린다
var tip_tag_c := Color(1, 1, 1)
var tip_mark := Rect2()         # 대상 사각 (동전 슬롯은 링으로 대신하므로 빈 값)
# 그 사각에 테두리를 두르는가. tip_mark 를 비우는 것과 다르다 — 제약
# 카드는 "커서 아래 카드가 선다" 를 tip_mark 로 판정하므로(_drop_update)
# 사각 자체는 살아 있어야 하고, 그리기만 빠져야 한다.
var tip_box := true
var tip_slot := -1              # 호버 중인 동전 슬롯 칸
var tip_spot := -1              # 호버 중인 테이블 자리 (테이블 구획용)
var tip_a := 0.0                # 페이드


# ic  왼쪽에 붙일 제약 아이콘 id (없으면 빈 문자열 — 기존 호출은 3인자 그대로)
# tl  이름 뒤에 9pt 로 이어 붙일 설명 (제약 줄에서만 쓴다)
func _tip_add(t: String, sz: int, c: Color, ic := "", tl := "", gd := "") -> void:
	if t == "":
		return
	# 여기서 접어 둔다. 크기 재기(_tip_size)와 그리기(_tip_draw)가 같은
	# 배열을 읽어야 판 높이와 글이 어긋나지 않는다.
	var w: float = TIP.w - TIP.pad * 2.0
	if ic != "":
		w -= 18.0                       # 아이콘 자리
	if gd != "":
		w -= gold_w(gd, sz) + 6.0       # 오른쪽에 붙는 값 자리
	tip_lines.append({"s": t, "sz": sz, "c": c, "ic": ic, "tl": tl, "gd": gd,
			"wr": _tip_wrap(t, w, sz)})


# 한 줄을 판 폭에 맞게 접는다. 낱말 경계를 먼저 보고, 낱말 하나가 폭보다
# 길면 글자 단위로 자른다 — 한글은 띄어쓰기가 성겨서 그 갈래가 실제로 온다.
func _tip_wrap(t: String, w: float, sz: int) -> PackedStringArray:
	var out := PackedStringArray()
	# 글꼴이 없는 실행(헤드리스 도구)에서는 재는 것 자체가 안 된다. 감싸기는
	# 그리기용이라 그냥 통줄로 넘긴다 — 툴팁을 세우는 검사가 이 한 줄
	# 때문에 헤드리스에서 못 도는 것이 더 손해다.
	if font == null:
		out.append(t)
		return out
	if w <= 1.0 or font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x <= w:
		out.append(t)
		return out
	var line := ""
	for word in t.split(" "):
		var cand: String = word if line == "" else line + " " + word
		if font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x <= w:
			line = cand
			continue
		if line != "":
			out.append(line)
			line = ""
		if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x <= w:
			line = word
			continue
		for ci in word.length():
			var ch := word[ci]
			if font.get_string_size(line + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x <= w:
				line += ch
			else:
				if line != "":
					out.append(line)
				line = ch
	if line != "":
		out.append(line)
	return out


func _tip_clear() -> void:
	tip_title = ""
	tip_lines = []
	tip_chip = {}
	tip_tag = ""
	tip_mark = Rect2()
	tip_box = true
	tip_slot = -1
	tip_spot = -1


# 지금 커서 아래에 무엇이 있는가. 없으면 빈 사전.
func _tip_hit(m: Vector2) -> Dictionary:
	match state:
		S.SHOP:
			if hand_st == H.CARRY:
				return {}                 # 드는 동안 툴팁은 끈다
			# 든 사탕 — 칸에 이름 세 글자만 적혀 있어 무슨 효과인지
			# 알 길이 없었다. 살 때는 테이블 툴팁이 말해 주는데 산 뒤로는
			# 아무 데서도 안 말한다. 쓰는 자리가 곧 모르는 자리였다.
			var ch := _cons_hit(m)
			if ch >= 0:
				return {"k": "held", "i": ch}
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
		S.LEG:
			# 동전 슬롯과 사탕 칸은 판 선택 화면에도 그대로 떠 있는데(_hud_draw)
			# 여기만 대상에서 빠져 있었다. 무엇을 들고 있는지가 곧 "던질까
			# 건너뛸까" 의 근거인데, 정작 고르는 자리에서 그것을 못 읽었다.
			var ch3 := _cons_hit(m)
			if ch3 >= 0:
				return {"k": "held", "i": ch3}
			for i in GameData.max_items():
				if _slot_rect(i).has_point(m):
					return {"k": "rack", "i": i}
			# 버튼에는 효과 한 줄만 들어간다(폭이 141px 이다). 뱃지의 이름과
			# 언제 쓰이는지는 툴팁이 맡는다.
			for bi in GameData.legs_per_round():
				var brn2: int = _round_first() + bi
				if brn2 < leg_no or _leg_tag(brn2).is_empty():
					continue
				if _skip_rect(bi).has_point(m):
					return {"k": "tag", "i": brn2}
			for i in pending_tags.size():
				if _pend_rect(i).has_point(m):
					return {"k": "pend", "i": i}
		S.COLLECT:
			var kk := String(COL_TABS[collect_tab].k)
			for i in _col_count():
				if _col_cell(i).has_point(m):
					return {"k": kk, "i": collect_page * COL_PAGE + i}
		S.PICK, S.AIM_V, S.AIM_H:
			var ch2 := _cons_hit(m)
			if ch2 >= 0:
				return {"k": "held", "i": ch2}
			# 조준 중에도 갈아탈 수 있으므로 그때도 벽을 짚어 준다
			for i in remaining.size():
				if _mag_rect(i).has_point(m):
					return {"k": "mag", "i": i}
			# 점수 카드가 떠 있으면 동전 슬롯 툴팁이 카드를 정면으로 덮는다.
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
			_tip_set_tag("동전")
			tip_mark = Rect2()
			tip_slot = i
			if i >= owned.size():
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
				_tip_add("이번 판 봉인", 9, C_MULT.lightened(0.25))
			if _can_sell():
				_tip_add("판매가", 10, C_GOLD, "", "", str(GameData.sell_value(it)))
		"stock":
			var s: Dictionary = stock[i]
			# 테이블은 한 자리에 네 갈래가 섞여 뜬다 — 그림만으로는 동전과
			# 사탕가, 보드 확장과 사진이 안 갈린다. 기본 점수가 그것을 한 낱말로 푼다.
			match String(s.type):
				"item":
					_tip_set_tag("동전")
				"mod":
					_tip_set_tag("보드 확장")
				"dart":
					_tip_set_tag("다트")
				"cons":
					_tip_set_tag("사탕")
				"fix":
					_tip_set_tag("사진")
			tip_mark = Rect2()      # 동전 슬롯과 같은 진영 — 사각 테두리 안 두른다
			tip_spot = i
			tip_title = s.d.n
			if s.type == "item":
				tip_chip = s.d
				_tip_add(GameData.cond_text(s.d.c), 10, C_DIM)
				_tip_add(GameData.eff_line(s.d), 11,
						C_CHIP.lightened(0.35) if s.d.k == "chip" else C_MULT.lightened(0.3))
				if s.d.get("g", "") != "":
					_tip_add(GameData.gold_text(s.d.g, s.d.gv), 9, C_GOLD)
			else:
				# 사탕·보드 확장·다트·사진 — 효과 한 줄이면 된다. 분류 해설은 소음이다.
				_tip_add(s.d.d, 10, C_DIM)
			# 못 사는 이유를 누르기 전에 알려준다. _deny() 는 원인을 한 문장으로 뭉갠다.
			var blk := _buy_block(i)
			if blk != "":
				_tip_add(blk, 9,
						C_DIM.darkened(0.3) if s.sold else C_RED.lightened(0.2))
		"tag":
			# i 는 자리 번호가 아니라 **판 번호**다. 뒤 판의 뱃지도 짚으므로
			# 어느 판의 것인지가 열쇠여야 한다.
			var bt := _leg_tag(i)
			if bt.is_empty():
				return
			_tip_set_tag("뱃지")
			tip_mark = _skip_rect(GameData.leg_idx(i))
			tip_title = String(bt.get("name", ""))
			_tip_add(_tag_text(bt), 10, C_ACC)
			_tip_add(_tag_when(bt), 9, C_DIM)
		"pend":
			if i >= pending_tags.size():
				return
			_tip_set_tag("뱃지")
			tip_mark = _pend_rect(i)
			tip_title = String(pending_tags[i].n)
			_tip_add(String(pending_tags[i].get("d", "")), 10, C_ACC)
			_tip_add(String(pending_tags[i].get("w", "")), 9, C_DIM)
		"held":
			if i >= cons.size():
				return
			var hc: Dictionary = cons[i]
			_tip_set_tag("사탕")
			tip_mark = _cons_rect(i)
			tip_title = String(hc.n)
			_tip_add(String(hc.d), 10, C_ACC)
		"stage":
			_tip_set_tag("제약")
			var sp: Dictionary = stage_pick[i]
			# 사각은 남기고 테두리만 뺀다. 카드는 서면서 커지고 밝아지는데
			# 테두리는 **누웠을 때의 자리**에 그려져, 선 카드 위에 어긋난
			# 흰 상자가 뜬다. 선 것 자체가 이미 표시라 두를 것이 없다 —
			# 테이블(stock)와 동전 슬롯이 먼저 간 길이다.
			tip_mark = _stage_rect(i)
			tip_box = false
			tip_title = sp.d.n
			_tip_add(sp.d.d, 11, C_MULT.lightened(0.25))
			_tip_add("목표 %d" % sp.target, 10, C_DIM)
		"citem":
			_tip_set_tag("동전")
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
			_tip_set_tag("보드 확장")
			var md: Dictionary = GameData.mods()[i]
			tip_mark = _col_cell(i % COL_PAGE)
			tip_title = md.n
			_tip_add(md.d, 10, C_DIM)
			_tip_add("보드 확장 · %d골드" % md.cost, 9, C_DIM.darkened(0.2))
		"cdart":
			_tip_set_tag("다트")
			var dt: Dictionary = GameData.darts()[i]
			tip_mark = _col_cell(i % COL_PAGE)
			tip_title = dt.n
			_tip_add(dt.d, 10, C_DIM)
			_tip_add("게이지 ×%.2f" % dt.gauge, 9, C_DIM.darkened(0.2))
			if int(dt.get("mult", 0)) != 0:
				_tip_add("배수 %+d" % int(dt.mult), 9, C_MULT.lightened(0.25))
		"ccons":
			_tip_set_tag("사탕")
			tip_mark = _col_cell(i % COL_PAGE)
			var cd: Dictionary = GameData.consumables()[i]
			tip_title = cd.n
			_tip_add(cd.d, 10, C_DIM)
		"cfix":
			_tip_set_tag("사진")
			tip_mark = _col_cell(i % COL_PAGE)
			var fx: Dictionary = GameData.fixtures()[i]
			tip_title = fx.n
			_tip_add(fx.d, 10, C_DIM)
		"cmodf":
			_tip_set_tag("제약")
			tip_mark = _col_cell(i % COL_PAGE)
			var mo: Dictionary = GameData.modifiers()[i]
			tip_title = mo.n
			_tip_add(mo.d, 10, C_DIM)
		"mag":
			_tip_set_tag("다트")
			var dd: Dictionary = remaining[i]
			tip_mark = _mag_rect(i)
			tip_title = dd.n
			_tip_add(dd.d, 10, C_DIM)
			_tip_add("게이지 ×%.2f" % dd.gauge, 9, C_DIM.darkened(0.2))
			if int(dd.get("mult", 0)) != 0:
				_tip_add("배수 %+d" % int(dd.mult), 9, C_MULT.lightened(0.25))
			if dd.get("fix1", false):
				_tip_add("배수를 1로 고정", 9, C_MULT.lightened(0.25))


# 갈래 기본 점수 하나. 이름 · 색을 같이 정한다 — 색이 갈래를 절반쯤 말한다.
func _tip_set_tag(k: String) -> void:
	tip_tag = k
	match k:
		"동전":
			tip_tag_c = C_CHIP.lightened(0.15)
		"사탕":
			tip_tag_c = C_ACC
		"보드 확장":
			tip_tag_c = C_MULT.lightened(0.20)
		"다트":
			tip_tag_c = C_TXT.darkened(0.15)
		"사진":
			tip_tag_c = C_GOLD
		"제약":
			tip_tag_c = C_RED.lightened(0.20)
		_:
			tip_tag_c = C_DIM


# 제목 줄과 본문 사이. 픽셀 글꼴은 내림이 2px 뿐이라 줄 높이에만 맡기면
# 제목의 아랫획과 첫 줄의 윗획이 서로 닿는다 — 최소 3px 은 띄운다.
#
# 미니동전가 붙은 툴팁은 더 벌린다. 원반(반지름 8, 중심 pad+9)의 아래끝은
# pad+17 인데 제목 칸은 pad+15 에서 끝난다. 2px 이 남으므로 바로 아래
# 첫 줄이 원반 밑동을 물었다 — 글자끼리 닿는 것과 다르다. 원반은 그림이라
# 1px 만 겹쳐도 획이 아니라 얼룩으로 읽힌다.
func _tip_lead() -> float:
	return 8.0 if not tip_chip.is_empty() else 3.0


# 본문 블록의 높이. 크기 재기(_tip_size)와 그리기(_tip_draw)가 **같은 식**을
# 봐야 갈래 기본 점수가 판 밖으로 새지 않는다 — 예전에는 그리기가 마지막 줄의
# 베이스라인에서 기본 점수 자리를 재고 크기 재기는 블록 아래끝에서 재서, 그 차이
# (내림 + 다음 줄 오름 = 10px)만큼 기본 점수가 밀려 아래 여백을 통째로 먹었다.
func _tip_body_h() -> float:
	var h := 0.0
	for l in tip_lines:
		# 아이콘 줄만 14px 아이콘이 들어가게 2px 키운다.
		# 접힌 줄은 그만큼 아래로 쌓는다 — 폭은 안 늘린다.
		h += TIP.line * float(maxi(1, l.wr.size())) + (2.0 if l.ic != "" else 0.0)
	return h


func _tip_size() -> Vector2:
	var h: float = TIP.pad * 2.0 + TIP.title + _tip_lead() + _tip_body_h()
	if tip_tag != "":
		h += TIP.chip_gap + TIP.chip_h
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
	if swap_live:
		# 커서 아래 물건이 통째로 미끄러지는 중이다. 판정은 안 움직이므로
		# 툴팁만 그 자리에 붙어 남는다 — 뜯어 둔다.
		tip_a = 0.0
		_tip_clear()
		return
	var hit := _tip_hit(_cursor())
	_tip_build(hit)
	if hit.is_empty():
		tip_a = maxf(tip_a - d * TIP.fade, 0.0)
	else:
		tip_a = minf(tip_a + d * TIP.fade, 1.0)


func _tip_draw(sh: Vector2) -> void:
	if tip_a <= 0.004 or tip_title == "" or shake > TIP.quiet:
		return

	# 테두리는 대상과 같이 흔들려야 어긋나 보이지 않는다 — 현재 transform 그대로.
	if tip_box and tip_mark.size.x > 0.0:
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
		draw_item_sticker(p + Vector2(TIP.pad + 8.0, TIP.pad + 9.0), 8.0, tip_chip,
				0.42, 0.0, 0.0, 8)
		# 원반 지름이 16 이라 pad+16 에서 끝난다. 20 이면 글자와 4px 밖에
		# 안 떨어져 둘이 한 덩어리로 붙어 보였다 — 아이콘은 글자가 아니라
		# 그림이므로 낱말 사이보다 넓게 띄워야 따로 읽힌다.
		tx += 27.0
	draw_string(font, Vector2(tx, p.y + TIP.pad + 12.0), tip_title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(C_TXT, tip_a))

	# _tip_draw 의 본문 루프. 이 시점에 transform 은 이미 Vector2.ZERO 라
	# 아이콘도 안 흔들린다. 페이드는 tip_a 를 알파로 넘겨 글자와 같이 뜬다.
	# 아이콘 없는 줄은 ic == "" 로 예전 경로 그대로 간다.
	var top: float = p.y + TIP.pad + TIP.title + _tip_lead()   # 본문 블록 윗변
	var y: float = top + TIP.base                              # 첫 줄 베이스라인
	for l in tip_lines:
		var lx: float = p.x + TIP.pad
		if l.ic != "":
			_icon_modifier(Vector2(lx + 7.0, y - 4.0), 7.0, l.ic, 0.0, tip_a)
			lx += 18.0
		# 붙는 값(오른쪽 정렬)과 꼬리표는 첫 줄에 선다 — 접힌 아랫줄로
		# 내려가면 무엇에 붙은 값인지가 안 읽힌다.
		if l.gd != "":
			draw_gold_at(p.x + sz.x - TIP.pad - gold_w(l.gd, l.sz), y,
					l.gd, l.sz, Color(l.c, tip_a))
		if l.tl != "":
			var tw: float = font.get_string_size(l.wr[0], HORIZONTAL_ALIGNMENT_LEFT,
					-1, l.sz).x + 5.0
			draw_string(font, Vector2(lx + tw, y), l.tl, HORIZONTAL_ALIGNMENT_LEFT,
					p.x + sz.x - TIP.pad - lx - tw, 9, Color(C_DIM, tip_a))
		for wi in l.wr.size():
			draw_string(font, Vector2(lx, y), l.wr[wi], HORIZONTAL_ALIGNMENT_LEFT,
					-1, l.sz, Color(l.c, tip_a))
			y += TIP.line
		y += 2.0 if l.ic != "" else 0.0

	# 갈래 기본 점수 — 맨 아래 왼쪽에 한 낱말. 이름 위가 아니라 아래에 두는 것은
	# 읽는 순서가 "무엇이다 → 무슨 효과다 → 어느 갈래다" 이기 때문이다.
	# 갈래를 먼저 읽히면 이름을 안 읽고 넘긴다.
	if tip_tag != "":
		var tw2: float = font.get_string_size(tip_tag, HORIZONTAL_ALIGNMENT_LEFT,
				-1, 9).x + 10.0
		# 본문 **블록 아래끝**에서 잰다. y 는 다음 줄의 베이스라인이라
		# 그것으로 재면 기본 점수가 10px 아래로 밀려 판 밑변에 걸쳐 잘렸다.
		var tr := Rect2(Vector2(p.x + TIP.pad, top + _tip_body_h() + TIP.chip_gap),
				Vector2(tw2, TIP.chip_h))
		draw_rect(tr, Color(tip_tag_c, tip_a * 0.22))
		draw_rect(Rect2(tr.position, Vector2(tr.size.x, 1.0)),
				Color(tip_tag_c, tip_a * 0.85))
		draw_string(font, tr.position + Vector2(5.0, 9.0), tip_tag,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(tip_tag_c, tip_a))

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
	draw_string(font, Vector2(0, 46), "라운드 %d  %s 클리어"
			% [GameData.round_of(leg_no), GameData.leg_name(leg_no)],
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


# 라운드의 세 판을 테이블에 늘어놓는다. 지난 판은 엎어져 어둡고, 지금 판은
# 서 있고, 다음 판은 누워 있다 — 제약 카드와 같은 어법이라 새로 배울 것이 없다.
func _draw_leg() -> void:
	_felt_draw()
	var first := _round_first()
	var per: int = GameData.legs_per_round()
	draw_string(font, Vector2(0.0, TBL.fy + 3.0),
			"라운드 %d / %d" % [GameData.round_of(leg_no), GameData.rounds_n()],
			HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 10,
			Color(C_TABLE.lightened(0.34), 0.75))
	# 선 카드만 상인 앞이다 — 제약 카드와 같은 규칙
	var cur: int = clampi(GameData.leg_idx(leg_no), 0, per - 1)
	for i in per:
		if i != cur:
			_leg_card(i, first + i)
	_cover_draw()
	_leg_card(cur, first + cur)

	_btn(_leg_go(), "던진다", "목표 %d" % GameData.target_of(leg_no), true)
	# 판마다 건너뛰기 자리를 깐다. **뒤 판의 보상도 같이 보인다** —
	# 지금 판을 건너뛸지는 뒤에 무엇이 기다리는지를 봐야 정해진다.
	# 지난 판은 안 그린다(이미 지나갔다), 지금 판만 누를 수 있다.
	for i in per:
		var srn: int = first + i
		if srn < leg_no:
			# 지나간 판도 자리를 지킨다. 건너뛴 것은 그 값을, 던진 것은
			# 던졌다는 것을 남긴다 — 자리가 비면 무엇을 골랐는지가 화면에서
			# 없어지고, 그러면 남은 판을 고르는 근거 하나가 사라진다.
			_skip_past(_skip_rect(i), srn)
			continue
		if srn == leg_no:
			# 이름이 아니라 **효과**를 적는다. "여벌 다트" 는 이름이고,
			# 건너뛸지 말지를 정하는 데 필요한 것은 "다트 +1개" 다. 이름은
			# 툴팁에 있다 — 고르는 자리에 필요한 것과 알아 두면 좋은 것이 다르다.
			_skip_plate(_leg_skip(), leg_tag, true)
			continue
		var pt := _leg_tag(srn)
		if not pt.is_empty():
			_skip_plate(_skip_rect(i), pt, false)
	# 쌓아 둔 뱃지 — 언제 쓰이는지는 이름이 말한다
	for i in pending_tags.size():
		var r := _pend_rect(i)
		draw_rect(r, C_PANEL.lightened(0.10))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), C_ACC)
		_icon_tag(Vector2(r.position.x + 9.0, r.get_center().y + 0.5), 5.0,
				String(pending_tags[i].kind))
		var pw: float = r.size.x - 24.0
		draw_string(font, r.position + Vector2(20.0, 11.0),
				_elide(String(pending_tags[i].n), pw, 8),
				HORIZONTAL_ALIGNMENT_LEFT, pw, 8, C_TXT)


# 판 한 장. 지금 판이면 서고 나머지는 눕는다.
func _leg_card(i: int, rn: int) -> void:
	var r := _row_rect(i, GameData.legs_per_round())
	var sz: Vector2 = r.size
	var done: bool = rn < leg_no
	var up: float = 1.0 if rn == leg_no else 0.0
	# 미끄러져 들어온다 — 제약 카드와 같은 딜 어법
	var k: float = clampf((leg_t - float(i) * float(DEAL.stag))
			/ float(DEAL.dur), 0.0, 1.0)
	var e: float = 1.0 - pow(1.0 - k, 3.0)
	var px: float = lerpf(VIEW.x * 0.5 - sz.x * 0.5, r.position.x, e)
	var gs: float = 1.0 + 0.12 * up
	var w2: float = sz.x * gs
	var foot: float = r.end.y - 7.0 * up
	var q := _card_quad(px - (w2 - sz.x) * 0.5, w2, foot, up, gs)

	var sh := PackedVector2Array()
	for c in q:
		sh.append(c + TBL.light * (2.0 + 5.0 * up))
	draw_colored_polygon(sh, Color(0.0, 0.0, 0.0, 0.22 + 0.14 * up))
	var body: Color = C_PANEL.darkened(0.30) if done \
			else C_PANEL.lightened(0.10 + 0.08 * up)
	draw_colored_polygon(q, body)
	draw_colored_polygon(PackedVector2Array([q[0], q[1],
			q[1] + Vector2(0.0, 2.0), q[0] + Vector2(0.0, 2.0)]),
			C_ACC if rn == leg_no else C_MULT.darkened(0.4))

	var ax: Vector2 = ((q[1] - q[0]) + (q[2] - q[3])) * 0.5 / sz.x
	var ay: Vector2 = ((q[3] - q[0]) + (q[2] - q[1])) * 0.5 / CARD.h
	var mid: Vector2 = (q[0] + q[1] + q[2] + q[3]) * 0.25
	draw_set_transform_matrix(Transform2D(ax, ay,
			mid - ax * (sz.x * 0.5) - ay * (CARD.h * 0.5) + shake_off))
	var ink: Color = C_DIM.darkened(0.3) if done else C_TXT
	draw_string(font, Vector2(0.0, 30.0), GameData.leg_name(rn),
			HORIZONTAL_ALIGNMENT_CENTER, sz.x, 13,
			ink if rn != leg_no else C_ACC)
	if done:
		draw_string(font, Vector2(0.0, 56.0), "넘김",
				HORIZONTAL_ALIGNMENT_CENTER, sz.x, 11, C_DIM.darkened(0.3))
	else:
		draw_string(font, Vector2(0.0, 56.0), "목표 %d" % GameData.target_of(rn),
				HORIZONTAL_ALIGNMENT_CENTER, sz.x, 11, ink)
		# 보상은 수가 아니라 **금화 개수**로 낸다. 3 과 5 의 차이는 읽어야
		# 알지만 금화 셋과 다섯은 안 읽고도 보인다. 카드가 누워 있을 때
		# 특히 그렇다 — 눌린 글자는 못 읽어도 개수는 세인다.
		var rw: int = GameData.reward_of(rn)
		var cw: float = 7.0
		var cx0: float = sz.x * 0.5 - float(rw) * cw * 0.5
		for ci in mini(rw, 8):
			draw_plaque(Vector2(cx0 + float(ci) * cw, 70.0), 5.5, 3.6,
					C_GOLD if not done else C_DIM.darkened(0.3))
	draw_set_transform(shake_off)


func _draw_stage() -> void:
	# 상점과 같은 테이블이다. 매물이 있던 자리에 제약 카드가 놓이고,
	# 창구는 좌우 다 셔터가 내려가 있다 — 그 화면에서는 아무것도 안 판다.
	_felt_draw()
	# 런 바가 들고 있던 것과 카드에서 뺀 것이 여기서 만난다.
	# 진행자 라인(y119) 바로 밑 — 펠트에 규격을 인쇄하는 자리다.
	# target_of(leg_no) 는 _open_stage 가 base 를 만든 그 식이다(출처 하나).
	# 카드보다 **먼저** 그린다. 미끄러져 오는 카드가 글자를 덮어야 순서가 맞다.
	draw_string(font, Vector2(0.0, 131.0),
			"라운드 %d / %d   ·   %s   ·   목표 %d"
			% [GameData.round_of(leg_no), GameData.rounds_n(),
					GameData.leg_name(leg_no), GameData.target_of(leg_no)],
			HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 10,
			Color(C_TABLE.lightened(0.34), 0.75))
	# 선 카드가 맨 위에 온다. 커지면서 이웃을 밀고 들어가는데 그리는 순서가
	# 고정이면 오른쪽 카드가 그 위를 덮어 든 것이 아래로 보인다.
	var front := -1
	for i in stage_pick.size():
		if float(stage_stand[i] if i < stage_stand.size() else 0.0) > 0.004:
			front = i
		else:
			_stage_card(i)
	# 누운 카드는 상인 손 **아래**다 — 카운터에 놓인 것이니 그게 맞다. 선
	# 카드는 그 위다. 카운터보다 앞으로 나와 세운 것을 손이 덮으면 든 것으로
	# 안 읽힌다. 그래서 덮개를 사이에 끼운다.
	_cover_draw()
	if front >= 0:
		_stage_card(front)
	_apron_mods()


# 앞치마 = 산 보드 확장을 거는 선반. 상점에서 리롤·다음 버튼이 서는 띠와
# 같은 줄을 쓴다 — 두 화면이 같은 틀이라는 말이 여기서도 지켜진다.
# 값을 손으로 적지 않고 버튼 사각에서 뽑는다. 손으로 적었더니 버튼을
# 내렸을 때 선반만 옛 자리에 남아 펠트 위에 검은 네모가 떴다.
# 보드 확장(mods.csv)는 _icon_mod, 제약(modifiers.csv)은 _icon_modifier 다.
# 캐비닛과 획으로 형태가 갈려 있어 아래(내가 산 것)와 위(내가 고를 것)가
# 안 섞인다. 이름 최장 실측 27px < 칸 52px.
# 앞치마 줄의 중심. 버튼 띠와 같은 줄이다.
func _apron_y() -> float:
	return _reroll_rect().get_center().y


func _apron_mods() -> void:
	var n: int = mods_own.size()
	if n == 0:
		# 빈 홈 하나. 동전 슬롯이 빈 칸에 유령 홈을 그리는 어법 그대로이고 크기도
		# 실제 캐비닛(2r+6 = 32)과 같다. "보드 확장 없음" 이라고 쓰는 것보다
		# R1 플레이어에게 더 많이 가르친다 — 비었다가 아니라 여기에 걸린다.
		var e := Rect2(VIEW.x * 0.5 - 16.0, _apron_y() - 16.0, 32.0, 32.0)
		draw_rect(e, C_WOOD.darkened(0.55))
		draw_rect(e, C_WOOD.lightened(0.10), false, 1.0)
		return
	var step: float = minf(52.0, 560.0 / float(n))
	var x0: float = VIEW.x * 0.5 - (float(n) - 1.0) * step * 0.5
	for i in n:
		var mid: String = mods_own[i]
		var mx: float = x0 + float(i) * step
		_icon_mod(Vector2(mx, _apron_y()), 13.0, mid, 0.0)
		draw_string(font, Vector2(mx - step * 0.5, _apron_y() + 28.0),
				GameData.mod_of(mid).get("n", ""),
				HORIZONTAL_ALIGNMENT_CENTER, step, 9, C_DIM.darkened(0.15))


# 화면 x 를 펠트 폭에 맞춰 좁힌다. 펠트는 y 마다 폭이 다르고(창구 빗변),
# 그 비를 그대로 곱하면 면에 놓인 것이 판과 같이 모인다.
func _felt_x(x: float, y: float, up: float) -> float:
	var sc: float = (VIEW.x - _chute_edge(y) * 2.0) / VIEW.x
	return VIEW.x * 0.5 + (x - VIEW.x * 0.5) * lerpf(sc, 1.0, up)


# 카드 한 장의 네 귀퉁이. up 0 이면 면에 누워 사다리꼴이고, 1 이면 화면에
# 세워져 직사각형이다. 밑변(가까운 모서리)이 축이라 자리에서 안 미끄러진다.
func _card_quad(px: float, w: float, foot: float, up: float,
		hs := 1.0) -> PackedVector2Array:
	var hh: float = CARD.h * lerpf(TBL.flat, 1.0, up) * hs
	var top: float = foot - hh
	var q := PackedVector2Array()
	for c in [Vector2(px, top), Vector2(px + w, top),
			Vector2(px + w, foot), Vector2(px, foot)]:
		q.append(Vector2(_felt_x(c.x, c.y, up), c.y))
	return q


# 카드 안에서 세로 t(0 위 ~ 1 아래) 자리의 왼끝·오른끝·y.
# 얼굴(아이콘·글자)이 사다리꼴을 따라가려면 이 셋이 필요하다.
func _card_row(q: PackedVector2Array, t: float) -> Vector3:
	return Vector3(lerpf(q[0].x, q[3].x, t), lerpf(q[1].x, q[2].x, t),
			lerpf(q[0].y, q[3].y, t))


func _stage_card(i: int) -> void:
	var md: Dictionary = stage_pick[i].d
	var r := _stage_rect(i)
	var sz: Vector2 = r.size
	var p := _stage_pose(i)
	var up: float = stage_stand[i] if i < stage_stand.size() else 0.0

	# 서는 것은 **가까운 모서리를 축으로** 몸을 세우는 일이다. 누운 카드는
	# 세로가 flat(0.788)배로 눌리고 **폭이 펠트를 따라 좁아진다** — 뒤로 갈수록
	# 좁아지는 그 사다리꼴이 "판 위에 놓였다" 를 말하는 전부다. 서면 둘 다 풀린다.
	# 집어 든 카드는 커지고 떠오른다. 같은 자리에서 눌림만 풀면 "조금 길어진
	# 사각형" 이라 든 것으로 안 읽힌다 — 손에 온 것은 눈에 가까워진 것이다.
	var gs: float = 1.0 + 0.12 * up
	var w2: float = sz.x * gs
	var px2: float = p.x - (w2 - sz.x) * 0.5
	var foot: float = p.y + sz.y - 7.0 * up
	var q := _card_quad(px2, w2, foot, up, gs)

	# 그림자는 매물과 같은 빛 벡터다. 서면 카드가 멀어지므로 그림자도 진다.
	var sh := PackedVector2Array()
	for c in q:
		sh.append(c + TBL.light * (2.0 + 5.0 * up))
	draw_colored_polygon(sh, Color(0.0, 0.0, 0.0, 0.22 + 0.14 * up))

	var body: Color = C_PANEL.lightened(0.10 + 0.08 * up)
	# 가까운 모서리의 두께 — 물건이지 인쇄가 아니라고 말한다. 누웠을 때는
	# 카드 옆면이 거의 안 보이고, 서면 두꺼워진다.
	var th: float = CARD.th * (0.5 + up)
	draw_colored_polygon(PackedVector2Array([q[3], q[2],
			q[2] + Vector2(0.0, th), q[3] + Vector2(0.0, th)]), body.darkened(0.45))
	draw_colored_polygon(q, body)
	# 먼 모서리의 띠 — 카드가 서면 켜진다
	draw_colored_polygon(PackedVector2Array([q[0], q[1],
			q[1] + Vector2(0.0, 2.0), q[0] + Vector2(0.0, 2.0)]),
			C_MULT.lightened(0.20 * up))
	draw_colored_polygon(PackedVector2Array([q[3] - Vector2(0.0, 1.0),
			q[2] - Vector2(0.0, 1.0), q[2], q[3]]), Color(C_BG, 0.55))

	# 얼굴은 그림이 먼저다. 훑는 채널은 글자가 아니라 실루엣이다.
	# 아이콘이 축("링이 나빠진다")을 말하고 설명이 양("0.5배")을 말한다.
	# 글자 자리는 카드가 눌린 만큼 같이 눌린다 — 글자 크기는 못 눌러도
	# **자리**가 눌리면 얼굴이 카드를 따라간다.
	# "목표" 는 안 쓴다 — _open_stage 가 base 하나를 n장에 복사하므로 셋이
	# 같은 값이고, 셋 중 하나를 고르는 면에서 판별 정보량이 0 비트다.
	# 얼굴도 카드와 같이 눕는다. 몸통만 눕히고 글자를 화면에 붙여 두면
	# 카드 위에 동전을 얹은 것으로 읽힌다 — 판에 인쇄된 것이 아니다.
	# 사다리꼴을 아핀으로 근사한다(위·아래 변의 평균). 정확히는 못 맞지만
	# 카드 한 장 안에서 위아래 폭 차가 15px 라 눈에 안 걸린다.
	var ax: Vector2 = ((q[1] - q[0]) + (q[2] - q[3])) * 0.5 / sz.x
	var ay: Vector2 = ((q[3] - q[0]) + (q[2] - q[1])) * 0.5 / CARD.h
	var mid: Vector2 = (q[0] + q[1] + q[2] + q[3]) * 0.25
	var org: Vector2 = mid - ax * (sz.x * 0.5) - ay * (CARD.h * 0.5)
	draw_set_transform_matrix(Transform2D(ax, ay, org + shake_off))
	_icon_modifier(Vector2(sz.x * 0.5, CARD.icon), CARD.icon_r, md.id, 0.0)
	draw_string(font, Vector2(0.0, CARD.name), md.n,
			HORIZONTAL_ALIGNMENT_CENTER, sz.x, 13, C_MULT.lightened(0.32))
	# 효과는 일어서야 보인다. 누운 카드에 여덟 글자를 눕혀 두면 못 읽는다.
	if up > 0.02:
		draw_string(font, Vector2(6.0, CARD.desc), md.d,
				HORIZONTAL_ALIGNMENT_CENTER, sz.x - 12.0, 9, Color(C_DIM, up))
	# 반드시 되돌린다. 남기면 _hud_draw 가 통째로 눌린다.
	draw_set_transform(shake_off)


func _draw_shop() -> void:
	_scrim()
	_table_draw()
	_btn(_reroll_rect(), "리롤", "무료" if reroll_cost == 0 else "", gold >= reroll_cost)
	if reroll_cost > 0:
		var rr := _reroll_rect()
		draw_gold(rr.position.x + rr.size.x * 0.5, rr.position.y + 35.0,
				str(reroll_cost), 10, C_GOLD if gold >= reroll_cost else C_DIM.darkened(0.3))
	_btn(_next_rect(), "다음 판 →", "", true)
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
		draw_string(font, Vector2(196.0, 316.0), msg, HORIZONTAL_ALIGNMENT_CENTER,
				248.0, 10, Color(C_MULT.lightened(0.3), ma))


func _draw_over() -> void:
	_scrim()
	if won:
		draw_string(font, Vector2(0, 150), "완주!", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 34, C_ACC)
		draw_string(font, Vector2(0, 186), "%d개 판을 모두 넘겼다" % GameData.legs_n(),
				HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 13, C_TXT)
	else:
		draw_string(font, Vector2(0, 150), "실패", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 34, C_MULT)
		draw_string(font, Vector2(0, 186), "라운드 %d %s — %d / %d"
				% [GameData.round_of(leg_no), GameData.leg_name(leg_no), total, target],
				HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 13, C_TXT)


# ══════════════════════════════════════════════════════════
#  제목 · 설정 · 컬렉션
# ──────────────────────────────────────────────────────────
#  셋 다 판을 배경으로 깔고 스크림을 덮는다 — OVER 와 같은 문법이다.
#  버튼은 _btn 하나로 통일한다. 전용 위젯이 없는 것이 이 게임의 어법이다.
# ══════════════════════════════════════════════════════════

var collect_tab := 0
# 소리 크기 0~1. 효과음과 음악을 따로 잡는다 — 깔개는 계속 울리고 효과음은
# 순간이라, 한 손잡이로 묶으면 한쪽에 맞추면 다른 쪽이 어긋난다.
var vol := 1.0           # 효과음. 예전 저장 키("vol")를 그대로 물려받는다
var vol_mus := 0.8       # 음악. 깔개라 기본값이 효과음보다 한 뼘 낮다
var set_drag := -1       # 끌고 있는 게이지 행. -1 이면 안 끈다
						 # 실제 초기값은 _ready 가 저장에서 읽는다.
var pause_from := -1     # 게임 중 ESC 로 설정을 열면 돌아갈 상태. -1 = 제목


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
	Save.set_set("fullscreen", not fs)


# 저장에서 설정을 되돌린다. 창 모드는 실제로 바꿔 보고 결과를 다시 읽는다 —
# 에디터 내장 실행처럼 못 바꾸는 자리가 있어서, 원한 값이 아니라 **된 값**을
# 저장해야 다음 실행에서 안 어긋난다.
func _load_settings() -> void:
	# 리그도 저장에서 되살린다. 모르는 id 면 league_row 가 첫 단으로 떨군다.
	GameData.league = String(Save.get_set("league", ""))
	GameData.pack = String(Save.get_set("pack", ""))
	vol = clampf(float(Save.get_set("vol", 1.0)), 0.0, 1.0)
	vol_mus = clampf(float(Save.get_set("vol_mus", 0.8)), 0.0, 1.0)
	_apply_vol()
	if bool(Save.get_set("fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		var got := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		if not got:
			Save.set_set("fullscreen", false)


func _draw_title() -> void:
	_scrim()
	draw_string(font, Vector2(0, 108), "하이톤", HORIZONTAL_ALIGNMENT_CENTER,
			VIEW.x, 40, C_TXT)
	draw_string(font, Vector2(0, 132), "HIGHTONE", HORIZONTAL_ALIGNMENT_CENTER,
			VIEW.x, 12, C_DIM)
	var names := ["시작", "컬렉션", "설정", "종료"]
	var subs := ["스페이스", "", "", ""]
	for i in 4:
		_btn(_menu_rect(i), names[i], subs[i], true)


# ══════════════════════════════════════════════════════════
#  새 런 — 다트통과 리그을 같이 고른다
# ──────────────────────────────────────────────────────────
#  발라트로가 PLAY 뒤에 여는 run_setup 이 이 자리다. 타이틀에는 덱도
#  리그도 없다 — 거기 있던 것을 여기로 옮겼다.
#
#  발라트로와 다르게 잡은 둘.
#    ① 리그을 화살표 사이클이 아니라 여덟 칸을 눕혀 곧장 누른다. 클릭
#       하나로 도는 게임에서 검정 리그에 가려고 일곱 번 넘기는 것은
#       조작이 아니라 형벌이다. 640x360 에 세로 기둥을 놓을 자리도 없다.
#    ② 발라트로는 이 화면을 게임오버에서 열면 못 빠져나가는데, 여기서는
#       뒤로가 늘 산다. 나갈 길 없는 화면을 만들지 않는다.
#
#  "시작" 은 확인 버튼이 아니다 — 다트통과 리그은 누르는 순간 확정되어
#  저장까지 끝나 있고, 이 버튼은 던지러 가는 이동이다.
# ══════════════════════════════════════════════════════════

var newrun_pip := 0             # 지금 보고 있는 다트통 번호


# ══════════════════════════════════════════════════════════
#  다트통 통 — 다트통의 얼굴
# ──────────────────────────────────────────────────────────
#  다트 세 자루를 허공에 흩어 놓던 자리다. 그 셋은 어느 다트통에서나 셋이라
#  **다트통이 무엇을 미는지를 한 획도 안 말했다** — 여벌 다트통도 셋, 넓은 동전 슬롯도
#  셋이었다. 통 하나로 바꾸면 다트통이 미는 것이 그대로 그림이 된다.
#    통 안   탄창 그대로. 자루 수(darts_base + darts_add)와 종류(dart_id)
#    통 겉   나머지 전부. 다트통마다 다른 통이 곧 그 다트통이다(CUP_SKIN)
#  한때는 통 옆에 골드·동전·칸 아이콘을 늘어 놓았다. 그 줄은 효과 글줄을
#  아이콘으로 한 번 더 읽는 것이라 자리만 먹고 아무것도 안 보탰다 —
#  다트통의 성질은 통 하나가 통째로 말한다.
#
#  잠긴 다트통은 기준선 통을 어둡게 세우고 **안도 겉도 그 다트통의 것을 안 쓴다.**
#  쓰면 히든이 히든이 아니다 — 효과 줄을 안 적는 규칙과 같은 규칙이다.
#
#  넘기기는 필름이다. 나가는 통과 들어오는 통이 같은 오프셋으로 같이
#  움직이고, 무대 밖으로 나간 몫은 판 바탕으로 덮어 자른다 — 그리기
#  API 에 클립이 없으므로 마스크가 곧 클립이다(_cup_mask).
# ══════════════════════════════════════════════════════════

const CUP := {
	# ── 통 ───────────────────────────────────────────
	"rx":    30.0,     # 아가리 가로 반지름
	"ry":     9.5,     # 눕힌 타원의 세로 반지름. rx 의 0.317 = 판 위 물건과 같은 눈높이
	"h":     42.0,     # 몸통 높이 (아가리 → 바닥)
	"rim":  126.0,     # 아가리 중심 y. 바닥은 168 이라 무대 아래끝(178)에 0.5px 남는다

	# ── 다트 ─────────────────────────────────────────
	#  아가리를 자루의 45% 지점에 둔다. 60% 를 넘게 담갔더니 배럴이 통째로
	#  통 안으로 들어가 남는 것이 날개와 흰 토막뿐이었다 — 다트가 아니라
	#  성냥으로 읽혔다. 배럴이 아가리 위로 18px 나와야 다트가 된다.
	"dl":    38.0,     # 반길이. 3D 자루(월드 0.81)를 화면에 눕힌 길이와 같다
	"dip":   36.0,     # 아가리에서 촉까지. 촉(160)은 바닥(168) 위에 뜬다
	"fan":    0.155,   # 자루 사이 벌어짐(rad). 일곱 자루가 ±26.6° 로 퍼진다
	"up":     2.6012,  # 촉이 바로 아래를 보게 하는 회전 = PI/2 - atan2(-10, 6)
	"spread": 5.0,     # 촉이 통 바닥에서 흩어지는 폭. 한 점에 모으면 겹친 티가 안 난다

	# ── 넘기기 ───────────────────────────────────────
	# 미끄러짐은 **px 가 원본**이고 3D 는 그것을 월드로 환산해 쓴다(_cup3_span).
	# 반대로 두면 화면 거리가 카메라 배율에 딸려 다녀 마스크와 어긋난다.
	"span": 132.0,     # 한 번에 미끄러지는 거리 = 무대 반폭 69 + 통 반폭 30 + 여유
	# 미끄러지는 시간(초). 0.85 였다 — 물리가 따라올 참이 필요해 길게 잡은
	# 값이었는데, 그 이유가 없어졌다. 통이 제 자루를 끌고 가고(CUP3.drag)
	# 벽이 자리를 옮겨서 지켜지므로(_cup3_step_rig 의 벽 지키기), 빨리
	# 밀어도 자루가 안 샌다. 여섯 다트통을 훑을 때 한 번에 0.85초는 답답하다.
	#
	# 판 갈이(0.36)까지 당겨 봤지만 거기서는 자루가 벽에 눌린 채 가라앉는다
	# (촉이 내내 1.00×r — 벽 지키기가 매 프레임 붙잡고 있다는 뜻이다).
	# 담기기는 하되 한쪽으로 쏠린 그림이라 0.45 에서 멈춘다. 절반 가까이
	# 빨라지면서 자루는 여전히 가운데로 가라앉는다(촉 0.60×r).
	"dur":    0.45,

	# ── 관성 ─────────────────────────────────────────
	#  다트 뭉치를 통에 용수철로 매단다. 뒤처진 거리가 곧 기울기다 —
	#  가속도를 재서 넣으면 프레임 간격에 따라 튀는데, 자리 차이는 안 튄다.
	"stiff": 150.0,    # 통 쪽으로 당기는 힘 (클수록 빨리 따라붙는다)
	"damp":    9.0,    # 감쇠 (클수록 빨리 멎는다)
	"tilt":    0.011,  # 뒤처진 1px 당 기울기(rad)
	"lean":    0.34,   # 기울기 상한(rad, 19.5°). 이 위로는 통에서 쏟아진 그림이 된다
}

var cup_t := 1.0        # 넘기기 진행 0~1 (1 = 멈춰 있다)
var cup_dir := 1        # +1 다음 다트통(통은 왼쪽으로 나간다) · -1 이전 다트통
var cup_prev := 0       # 미끄러지는 동안 나가는 다트통 번호
# 통이 지금까지 간 거리. **끊기지 않는 값**이라야 관성이 안 튄다 —
# 화면 오프셋은 넘길 때마다 0 으로 되돌아가므로 그것으로는 못 잰다.
var cup_run := 0.0
var cup_m := 0.0        # 다트 뭉치가 실제로 있는 자리
var cup_mv := 0.0       # 그 속도


# 통이 서는 무대. 통은 이 칸 안에서만 미끄러진다.
func _cup_stage() -> Rect2:
	return Rect2(Vector2(86.0, 60.0), Vector2(138.0, 118.0))


# 통 바닥 중심의 y. 소품도 이 선에 선다.
func _cup_foot() -> float:
	return float(CUP.rim) + float(CUP.h)


func _cup_reset() -> void:
	cup_t = 1.0
	cup_run = 0.0
	cup_m = 0.0
	cup_mv = 0.0


# 다트통을 한 칸 넘긴다. 값을 바꾸는 것은 _pack_view 가 그대로 하고,
# 여기는 그림이 어느 쪽으로 미끄러질지만 정한다.
func _pack_step(dir: int) -> void:
	if GameData.packs().size() < 2:
		return
	# 미끄러지는 도중에 또 누르면 그 자리에서 새로 시작한다. 나가던 통을
	# 버리고 지금 통이 나가는 통이 된다 — 연달아 눌러도 줄이 안 밀린다.
	cup_prev = newrun_pip
	cup_dir = dir
	cup_t = 0.0
	_pack_view(newrun_pip + dir)
	_cup3_step(dir)


func _cup_ease(t: float) -> float:
	var k := clampf(t, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


func _cup_update(d: float) -> void:
	var e0 := _cup_ease(cup_t)
	cup_t = minf(cup_t + d / float(CUP.dur), 1.0)
	cup_run += -float(cup_dir) * float(CUP.span) * (_cup_ease(cup_t) - e0)
	cup_mv += (cup_run - cup_m) * float(CUP.stiff) * d
	cup_mv *= exp(-float(CUP.damp) * d)
	cup_m += cup_mv * d


# 다트 뭉치가 통보다 뒤처진 만큼을 기울기로 바꾼다.
func _cup_lean() -> float:
	return clampf((cup_m - cup_run) * float(CUP.tilt),
			-float(CUP.lean), float(CUP.lean))


# 통에 꽂힌 자루 수 = 그 다트통이 런을 시작하는 탄창 크기(_new_run 과 같은 식).
# 갈라 두면 화면이 여섯 자루를 보여 주고 게임이 일곱 발을 주는 일이 난다.
func _cup_dart_n(row: Dictionary) -> int:
	return maxi(1, GameData.tune_i("darts_base") + int(row.get("darts_add", 0)))


# 통 앞벽 한 조각. 아가리 앞호와 바닥 앞호 사이의 띠다. 온 띠를 한 폴리곤에
# 넣으면 삼각분할이 튀므로(annulus 주석이 이미 밟은 함정) 좌우로 갈라 넘긴다.
func _cup_wall(c: Vector2, g: Vector2, rx: float, ry: float,
		a0: float, a1: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := lerpf(a0, a1, float(i) / 8.0)
		pts.append(c + Vector2(sin(a) * rx, -cos(a) * ry))
	for i in 9:
		var a := lerpf(a1, a0, float(i) / 8.0)
		pts.append(g + Vector2(sin(a) * rx, -cos(a) * ry))
	draw_colored_polygon(pts, col)


# 통 몸통. 다트를 사이에 끼우려고 두 번에 나눠 그린다 — 뒤(그림자·실루엣·
# 아가리 안쪽·뒤 테)를 깔고, 다트를 얹고, 앞(앞벽·앞 테)으로 덮는다.
# "통 안에 들어 있다" 는 이 덮기 한 번으로 선다.
func _cup_body(cx: float, dim: float, front: bool) -> void:
	var rx: float = CUP.rx
	var ry: float = CUP.ry
	var c := Vector2(cx, CUP.rim)
	var g := Vector2(cx, _cup_foot())
	var body: Color = C_WIRE.darkened(0.44 + dim * 0.22)
	var lip: Color = C_WIRE.lightened(0.18).darkened(dim)
	if not front:
		draw_colored_polygon(_e_pts(g + Vector2(2.0, 2.0), rx * 1.05, ry * 1.05, 18),
				Color(0.0, 0.0, 0.0, 0.30))
		draw_colored_polygon(PackedVector2Array([
				c + Vector2(-rx, 0.0), c + Vector2(rx, 0.0),
				g + Vector2(rx, 0.0), g + Vector2(-rx, 0.0)]), body)
		draw_colored_polygon(_e_pts(g, rx, ry, 20), body)
		draw_colored_polygon(_e_pts(c, rx, ry, 20), body)
		# 아가리 안쪽. 앞벽이 나중에 앞 절반을 덮으므로 화면에는 뒤 절반만 남는다.
		draw_colored_polygon(_e_pts(c, rx - 2.0, ry - 1.2, 20),
				C_DARK.darkened(0.30 + dim * 0.3))
		# 뒤 테는 다트보다 **먼저** 그린다. 온 고리를 나중에 그리면 자루를
		# 가로지르는 1.5px 선이 생겨 다트가 테 뒤로 지나간 것으로 안 읽힌다.
		draw_colored_polygon(_e_band(c, rx, ry, rx - 1.6, ry - 1.0,
				-PI * 0.5, PI * 0.5, 10), lip)
		return
	# 원통 음영. 반쪽을 통째로 밝히면 한가운데에 곧은 세로 이음선이 생겨
	# 원통이 아니라 접힌 판으로 읽힌다 — 띠 셋으로 나눠 굴린다.
	# 빛은 왼쪽 위에서 온다(TBL.light 와 같은 방향).
	_cup_wall(c, g, rx, ry, PI * 0.5, PI * 1.5, body)
	_cup_wall(c, g, rx, ry, PI * 1.08, PI * 1.40, body.lightened(0.13))
	_cup_wall(c, g, rx, ry, PI * 0.5, PI * 0.70, body.darkened(0.22))
	draw_colored_polygon(_e_band(c, rx, ry, rx - 1.6, ry - 1.0,
			PI * 0.5, PI * 1.5, 10), lip)
	# 바닥 앞호 — 몸통과 바닥을 가르는 한 줄. 없으면 통이 바닥 없는 띠가 된다.
	var bot := PackedVector2Array()
	for i in 13:
		var a := lerpf(PI * 0.5, PI * 1.5, float(i) / 12.0)
		bot.append(g + Vector2(sin(a) * rx, -cos(a) * ry))
	draw_polyline(bot, C_DARK.darkened(0.2 + dim * 0.3), 1.0)


# 통에 꽂힌 자루들. 촉은 통 안 한 자리에 모이고 꽁지는 부채로 벌어진다.
# lean 은 관성 기울기 — 촉을 축으로 도므로 통에서 안 빠져나온다.
func _cup_darts(cx: float, id: String, n: int, dim: float, lean: float) -> void:
	var foot := Vector2(cx, float(CUP.rim) + float(CUP.dip))
	# 바깥 자루부터 그린다. 가운데가 맨 위로 와야 한 뭉치로 읽힌다 —
	# 왼쪽부터 차례로 그리면 계단처럼 밀린 카드 부채가 된다.
	var lo := 0
	var hi := n - 1
	while lo <= hi:
		for i in ([lo] if lo == hi else [lo, hi]):
			var k: float = float(i) - float(n - 1) * 0.5
			var rot: float = float(CUP.up) + k * float(CUP.fan) + lean
			var dir := Vector2(6.0, -10.0).normalized().rotated(rot)
			var tip := foot + Vector2(k * float(CUP.spread), 0.0)
			_icon_dart(tip - dir * float(CUP.dl), CUP.dl, id, dim, rot,
					1.0 - dim * 0.5)
		lo += 1
		hi -= 1


# 렌더러가 없을 때 서는 2D 받침 한 벌. dx 는 필름 오프셋이다.
# 소품은 여기서 안 그린다 — 3D 경로와 같은 것을 두 번 그리게 된다.
func _cup_one(pi: int, dx: float) -> void:
	var packs := GameData.packs()
	if pi < 0 or pi >= packs.size():
		return
	var row: Dictionary = packs[pi]
	var open: bool = _pack_open(pi)
	var dim: float = 0.0 if open else 0.55
	var cx: float = _cup_stage().get_center().x + dx
	var lean := _cup_lean()

	_cup_body(cx, dim, false)
	# 잠긴 다트통은 **기준선 탄창**을 세운다. 그 다트통의 수와 종류를 그리면 효과 줄을
	# 안 적어 둔 뜻이 없어진다 — 히든의 다트가 그림으로 새는 자리였다.
	if open:
		_cup_darts(cx, String(row.get("dart_id", "std")),
				_cup_dart_n(row), dim, lean)
	else:
		_cup_darts(cx, "std", GameData.tune_i("darts_base"), dim, lean)
	_cup_body(cx, dim, true)


# 무대 밖으로 나간 몫을 판 바탕으로 덮어 자른다. 그리기 API 에 클립이
# 없으므로 이 네 조각이 곧 클립이다 — 판의 나머지(이름·효과 칸)는 이
# 뒤에 그려지므로 덮여도 상관없다.
func _cup_mask(stage: Rect2, pr: Rect2) -> void:
	var col: Color = C_PANEL.lightened(0.10)
	var y0: float = pr.position.y + 2.0          # 머리띠는 남긴다
	draw_rect(Rect2(pr.position.x, y0, stage.position.x - pr.position.x,
			pr.end.y - y0), col)
	draw_rect(Rect2(stage.end.x, y0, pr.end.x - stage.end.x, pr.end.y - y0), col)
	draw_rect(Rect2(stage.position.x, y0, stage.size.x,
			stage.position.y - y0), col)
	draw_rect(Rect2(stage.position.x, stage.end.y, stage.size.x,
			pr.end.y - stage.end.y), col)


# ══════════════════════════════════════════════════════════
#  다트통 통 — 3D 강체
# ──────────────────────────────────────────────────────────
#  통과 자루를 진짜 3D 로 세운다. 넘길 때 자루가 벽에 밀리고 멎을 때
#  반대쪽 벽을 때리는 것이 손으로 그린 기울기가 아니라 물리다 — 자루
#  수가 달라지면 부딪히는 모양도 저절로 달라진다.
#
#  화면과 닿는 곳은 하나다. SubViewport 를 무대 크기(138x118) **그대로**
#  잡고 1:1 로 얹는다. 배율이 1 이라 3D 가 픽셀 격자를 안 흔든다.
#  물리는 그 뷰포트의 제 World3D 에서 돈다(own_world_3d) — 게임의 나머지는
#  2D 그대로고, 이 화면을 뜨면 통째로 지운다.
#
#  넘기기는 필름 그대로다. 나가는 통과 들어오는 통이 **둘 다 강체**로
#  같이 미끄러지므로 양쪽 자루가 같이 출렁인다. 나간 통은 다 미끄러진
#  뒤에 지운다 — 도중에 지우면 화면 안에서 사라진다.
#
#  렌더러가 없는 자리(헤드리스 프로브·도구)에서는 뷰포트가 빈 그림을
#  돌려준다. 그때는 2D 실루엣(_cup_body · _cup_darts)이 대신 선다 —
#  두 벌을 나란히 두려는 게 아니라, 무대가 빈 칸으로 남지 않게 하는
#  받침이다. 눈으로 보는 것은 언제나 3D 쪽이다.
# ══════════════════════════════════════════════════════════

const CUP3 := {
	# ── 화면 ─────────────────────────────────────────
	"size":   2.05,    # 직교 카메라 세로 범위(월드). 무대 세로 118 / 이 값 = 배율
	"pitch": -18.0,    # 내려다보는 각(도). sin 18° = 0.309 가 아가리 타원의 눌림비다
	"eye_z":  6.00,    # 직교라 거리는 그림에 안 나온다 — 잘림면만 피하면 된다

	# ── 통 ───────────────────────────────────────────
	#  실물 다트 통은 자루가 서로 닿을 만큼 좁다 — 그래서 흔들면 한 뭉치로
	#  기울고 달그락거린다. 처음에 반지름 0.61(자루 지름의 열한 배)로 잡았더니
	#  자루끼리 안 닿아서, 통을 밀면 통만 가고 자루는 제자리에 남았다.
	"r":      0.38,    # 안쪽 반지름 (19px). 자루 일곱이 서로 기대 선다
	"wall":   0.05,    # 벽 두께
	"h":      1.02,    # 높이 (50px). 자루 길이의 63% 를 담근다 — 얕으면 지렛대로 쏟긴다
	"seg":      14,    # 벽 충돌을 두르는 조각 수. 원통 충돌은 속이 안 비므로 나눠 두른다

	# ── 그물 ─────────────────────────────────────────
	#  벽은 철망이다. 알파 시저라 구멍이 깊이까지 뚫린다 — 반투명이 아니라
	#  없는 자리다.
	#  칸 크기는 화면 픽셀이 정한다. 통 둘레가 화면에서 154px 이므로 가로
	#  텍셀을 160 으로 두면 텍셀 하나가 화면 픽셀 하나다. 이보다 잘게 뜨면
	#  한 픽셀 안에 철사와 구멍이 같이 들어와 그물이 얼룩이 된다.
	"net_w":   160,    # 텍스처 가로 = 둘레 한 바퀴. 화면 둘레와 거의 1:1
	"net_h":    72,    # 텍스처 세로
	"net_x":    34,    # 한 바퀴 마름모 수 (칸 4.7텍셀 ≒ 화면 4.5px)
	"net_y":    16,    # 세로 마름모 수. 칸이 가로세로 같게 보이는 수다
	"net_t":     0.15, # 철사 반두께(칸의 몇 배). 0.15 = 가로로 1.4텍셀
	"net_hem":   2,    # 위아래로 막아 두는 텍셀 수. 구멍이 테를 물면 톱니가 난다

	# ── 자루 ─────────────────────────────────────────
	"dl":     0.81,    # 반길이 (40px). 온 길이가 통 높이의 1.8배라 절반이 밖에 선다
	"dr":     0.055,   # 배럴 반지름
	"fin":    0.105,   # 날개 반폭
	"mass":   0.05,

	# ── 물리 손잡이 ──────────────────────────────────
	#  통이 90cm 짜리 실물이면 자루가 한가하게 떠다닌다. 중력을 올려
	#  "작은 통 안의 작은 자루" 로 되돌린다. 감쇠는 통이 멎은 뒤 달그락이
	#  두세 번에 잦아들게 잡은 값이다.
	#  통이 미끄러질 때의 최대 가속은 6*span/dur^2 이다. 그것이 유효 중력보다
	#  크면 자루가 통 밖으로 넘어간다 — 실제로 그렇게 쏟아졌다. 중력을 올려
	#  둘의 비를 0.8 아래로 눌러 둔다: 6*2.69/0.70² = 32.9 vs 9.8*4.6 = 45.1.
	"grav":   6.0,
	"ldamp":  1.1,
	"adamp":  2.6,
	"fric":   0.70,
	"bounce": 0.03,
	#  무게 중심을 배럴 쪽으로 내린다. 실물 다트가 앞이 무거운 것이 그대로
	#  통 안에서 안 넘어지는 이유다 — 가운데에 두면 자루가 긴 막대라
	#  한 번 밀릴 때마다 지렛대로 넘어간다.
	"com":    0.34,    # 반길이의 몇 배만큼 촉 쪽으로
	#  세우는 토크. 실물 통은 자루가 서로 받칠 만큼 좁은데, 그만큼 좁히면
	#  화면에서 통이 안 보인다. 넓힌 몫을 이 힘으로 갚는다.
	#
	#  **담아 두는 힘이 아니다.** 담는 일은 아래 벽 지키기가 자리를 옮겨서
	#  하고, 이것은 자루가 어떤 자세로 서는가만 정한다. 그래서 18 까지
	#  올렸다가 6 으로 내렸다 — 세게 걸면 자루가 통에 꽂아 놓은 막대처럼
	#  곧추서고, 통에 던져 넣은 것으로 안 읽힌다. 약하게 걸면 서로와
	#  벽에 기대 눕는다. 실물 통이 그렇다.
	"stand":  6.0,
	#  줄 — 촉이 통 안쪽 이만큼을 넘어가려 하면 축 쪽으로 당긴다. 순간이동이
	#  아니라 힘이라 물리가 계속 주인이고, 출렁임은 그대로 두고 이탈만 막는다.
	"leash":  0.45,    # 안쪽 반지름의 몇 배부터 당길지
	"pull":  220.0,    # 당기는 세기 (넘어간 거리 1 단위당 가속도)
	#  꽁지 줄. 세기는 기대 눕는 각을 정하는 값이지 이탈을 막는 값이 아니다
	#  (막는 일은 벽 지키기가 한다). 260 은 꽁지를 세워 세운 토크와 같이
	#  자루를 곧추세웠다.
	#  촉만 묶어 두면 자루가 촉을 축으로 부채처럼 벌어진다 —
	#  통은 가만한데 날개만 아가리 밖으로 나가고, 그것이 "다트가 통 밖으로
	#  삐져나온다" 로 보이던 것이다(실측 꽁지 1.25×r — 아가리 바깥선이
	#  1.13×r 이니 8px 넘어섰다). 줄을 걸고 다시 재니 1.08~1.13×r 로,
	#  아가리 안에 들어오되 부챗살은 남는다. cup_probe 가 이 값을 지킨다.
	#  실물 통은 자루가 서로 닿아 이 벌어짐을 서로 막는다. 화면에서 보이려고
	#  통을 넓힌 만큼 그 받침이 없어졌으므로 여기서 갚는다.
	#  **중심력이 아니라 꽁지 자리에 거는 힘**이다 — 중심에 걸면 자루가
	#  통째로 밀려 이번엔 촉이 반대로 샌다. 꽁지에 걸어야 세우는 토크가 된다.
	"fold":   1.00,    # 아가리 반지름의 몇 배부터 당길지
	"tuck":   90.0,    # 당기는 세기
	#  끌기 — 통이 제 자루를 데려가는 몫.
	#  벽이 자루를 밀어 나르는 것은 물리로는 접촉이고, 미끄러지는 속도에서는
	#  솔버가 그 접촉을 놓친다. 놓치면 통만 가고 자루는 제자리에 남아
	#  **벽을 뚫고 나온다** — 실측 촉 1.6×r 이었다(벽은 1.0×r).
	#  가로 속도만 통에 맞춘다. **돌기는 안 건드린다** — 달그락은 꽁지가
	#  흔들려서 나는 소리지 자루가 뒤처져서 나는 소리가 아니다.
	#  뒤처짐 ≈ 통 속도 / 이 값이라, 30 이면 최고 속도에서 0.13 (0.35×r) 이다.
	"drag":   30.0,
	"lid":    26.0,    # 아가리 위로 통째로 떠오를 때 눌러 내리는 가속도
}

# 다트통마다 통이 다르다. 통은 다트통의 얼굴이라 여섯 다트통을 훑을 때 눈이 먼저
# 잡는 것이 이것이다 — 글줄을 읽기 전에 "아까 그 통" 으로 다트통이 갈린다.
# 표에 없는 다트통은 기본 통을 쓴다. 나머지 셋은 아직 안 정했다.
#
#   wall     벽을 어떻게 두르는가. CUP_WALLS 에 있는 이름만 쓴다
#   wide     통 반지름 배율. **물리도 같이 넓어진다** — 벽 충돌·자루가
#            앉는 고리·줄이 전부 이 값을 곱한 반지름을 본다. 그림만 늘리면
#            자루가 안 보이는 벽에 막혀 통 한가운데 몰린다
#   sticker  아가리 아래에 동전 한 장. 동전 슬롯이 넓다는 말을 통이 대신 한다
#
# **잠긴 다트통은 이 표를 안 본다**(_cup3_skin). 겉이 새면 히든이 히든이 아니다 —
# 자루 수와 종류를 기준선으로 세우는 것과 같은 규칙이다.
const CUP_SKIN := {
	"base":   {},                                  # 기준선. 민 원통
	"p_mag":  {"wall": "net"},                     # 여벌 다트통. 철망
	"p_rack": {"wide": 1.15, "sticker": true},     # 넓은 동전 슬롯. 넓은 통에 동전 한 장
	# 선금 다트통. 선금을 받았으니 통이 금빛이고 발치에 플라크가 흩어져 있다 —
	# 다트통이 미는 것(시작 골드)이 글줄이 아니라 물건으로 보인다.
	"p_adv":  {"tint": "gold", "gold": 5},
	# 일당 다트통. 이자를 끄고 **남은 다트 1개당** 골드를 두 배로 주는 다트통이라,
	# 자루 자체가 돈이다. 그래서 통이 아니라 자루가 금빛이다.
	"p_wage": {"dart": "gold"},
}

# 겉 하나가 안 적은 값. 표는 다른 것만 적는다.
#   dart  자루 색을 덮는다. 빈 값이면 다트 종류가 정하는 색 그대로다.
const CUP_SKIN0 := {"wall": "solid", "wide": 1.0, "sticker": false,
		"tint": "steel", "gold": 0, "dart": ""}

# 있는 색의 온 목록. 벽 갈래와 독립이라 금빛 철망도 설 수 있다.
const CUP_TINTS := ["steel", "gold"]

# 있는 벽의 온 목록. _cup3_cup 의 match 와 짝이다 — 표에 오타를 내면
# 잠자코 민 통이 서므로(match 의 기본 갈래) 눈으로는 못 잡는다.
# cup_probe 가 이 목록으로 표를 검사한다.
const CUP_WALLS := ["solid", "net"]

var cup_vp: SubViewport = null
var cup_rigs := []      # [{"cup": AnimatableBody3D, "darts": Array, "pi": int}]
var cup_net: ImageTexture = null    # 벽 그물. 한 번 떠서 계속 쓴다


# 1 월드 단위가 몇 px 인가. 무대와 카메라가 같은 식을 봐야 2D 소품이
# 3D 통 옆에 정확히 선다.
func _cup3_ppu() -> float:
	return _cup_stage().size.y / float(CUP3.size)


func _cup3_live() -> bool:
	return cup_vp != null and is_instance_valid(cup_vp)


# 미끄러지는 거리를 월드로 환산한 값.
func _cup3_span() -> float:
	return float(CUP.span) / _cup3_ppu()


# 통 바닥(월드 y 0)이 화면의 _cup_foot() 에 앉게 하는 눈높이.
# 직교 + 내림각 p 에서 화면 세로 오프셋 = cos(p) * 높이 * 배율 이므로
# 그것을 뒤집으면 된다. 손으로 적어 두면 카메라 배율을 만질 때마다
# 통이 무대에서 미끄러진다 — 2D 소품은 _cup_foot() 을 보고 서므로
# 둘이 갈리면 소품만 허공에 뜬다.
func _cup3_eye() -> float:
	return (_cup_foot() - _cup_stage().get_center().y) 			/ (cos(deg_to_rad(float(CUP3.pitch))) * _cup3_ppu())


# 벽에 두르는 그물 무늬. 알파 0 인 자리가 구멍이다. 마름모 두 갈래를
# 겹쳐 짠다 — 격자로 두면 벽이 창틀로 읽히고, 마름모라야 철망이 된다.
# 한 벌만 떠서 두 통이 나눠 쓴다(넘길 때 통이 둘이다).
func _cup3_net() -> ImageTexture:
	if cup_net != null:
		return cup_net
	var tw: int = CUP3.net_w
	var th: int = CUP3.net_h
	var hem: int = CUP3.net_hem
	var t: float = CUP3.net_t
	var img := Image.create(tw, th, false, Image.FORMAT_RGBA8)
	for y in th:
		for x in tw:
			var u := (float(x) + 0.5) / float(tw) * float(CUP3.net_x)
			var v := (float(y) + 0.5) / float(th) * float(CUP3.net_y)
			var a := fposmod(u + v, 1.0)
			var b := fposmod(u - v, 1.0)
			var on := minf(a, 1.0 - a) < t or minf(b, 1.0 - b) < t
			if y < hem or y >= th - hem:
				on = true
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0 if on else 0.0))
	cup_net = ImageTexture.create_from_image(img)
	return cup_net


# 납작하게 굳힌다 — 반사와 광택이 들어오면 이 화면만 다른 게임이 된다.
# net 은 벽 한 겹 몫이다. 알파 블렌드가 아니라 시저인 것이 핵심이다 —
# 블렌드는 깊이를 안 써서 구멍 너머가 그리는 차례대로 지워진다.
# 뒷면을 안 자르는 것은 아가리 너머로 뒷벽 그물의 안쪽이 보여야 해서다.
func _cup3_mat(col: Color, net := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	m.metallic = 0.0
	# 반사광을 끈다. 여기 `specular = 0.0` 이라고 적혀 있었는데 그것은
	# 고닷 3.x 의 이름이라 4 에서는 **아무 일도 안 하고 경고만 냈다** —
	# 메시 하나당 한 줄씩이라 편집기 출력이 그 한 줄로 뒤덮였다(자루·통·
	# 플라크가 늘수록 같이 늘었다). 4 의 이름은 이것이다.
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if net:
		m.albedo_texture = _cup3_net()
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _cup3_mesh(parent: Node3D, mesh: Mesh, col: Color, at: Vector3,
		rot := Vector3.ZERO, net := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _cup3_mat(col, net)
	mi.position = at
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# ── 벽: 민 통 ────────────────────────────────────────
# 기준선. 벽 두 겹에 굵은 테 하나다.
func _cup3_wall_solid(b: Node3D, r: float, w: float, h: float, tint: String) -> void:
	var face := _cup3_face("solid", r, w)
	var outer := CylinderMesh.new()
	outer.top_radius = face
	outer.bottom_radius = face
	outer.height = h
	outer.cap_top = false
	outer.cap_bottom = false
	outer.radial_segments = 26
	_cup3_mesh(b, outer, _cup3_wall_col("solid", tint), Vector3(0.0, h * 0.5, 0.0))
	# 안쪽 벽은 법선을 뒤집어야 안이 보인다. 양면 재질로 두면 안쪽이
	# 바깥 빛을 받아 통이 유리로 보인다.
	var inner := CylinderMesh.new()
	inner.top_radius = r
	inner.bottom_radius = r
	inner.height = h
	inner.cap_top = false
	inner.cap_bottom = false
	inner.radial_segments = 26
	inner.flip_faces = true
	_cup3_mesh(b, inner, C_DARK.darkened(0.28), Vector3(0.0, h * 0.5, 0.0))
	var lip := TorusMesh.new()
	lip.inner_radius = r
	lip.outer_radius = r + w
	lip.rings = 26
	lip.ring_segments = 6
	_cup3_mesh(b, lip, _cup3_tint(tint).lightened(0.18), Vector3(0.0, h, 0.0))


# ── 벽: 철망 ─────────────────────────────────────────
# 벽은 그물 한 겹과 그 뒤의 어두운 속통, 둘로 선다.
#   그물   진짜로 뚫려 있다(알파 시저). 철사가 가늘어 통이 묽어지는
#          만큼 색을 한 단 올렸다 — 0.44 로는 벽이 실루엣만 남는다.
#   속통   구멍 너머에 서는 어둠. **속을 다 비우면 못 쓴다** — 흰 배럴
#          여섯이 1px 짜리 구멍마다 조각조각 비쳐 그물이 얼룩이 되고,
#          자루가 출렁일 때마다 그 얼룩이 같이 끓는다. 실물 철망 통도
#          안이 어두우면 구멍은 그냥 검다.
# 속통은 양면이다. 아가리로 들여다본 뒷벽 안쪽이 그 뒷면이다.
func _cup3_wall_net(b: Node3D, r: float, w: float, h: float, tint: String) -> void:
	var face := _cup3_face("net", r, w)
	var wall := CylinderMesh.new()
	wall.top_radius = face
	wall.bottom_radius = face
	wall.height = h
	wall.cap_top = false
	wall.cap_bottom = false
	wall.radial_segments = 26
	_cup3_mesh(b, wall, _cup3_wall_col("net", tint), Vector3(0.0, h * 0.5, 0.0),
			Vector3.ZERO, true)
	var drum := CylinderMesh.new()
	drum.top_radius = face - 0.01
	drum.bottom_radius = face - 0.01
	drum.height = h
	drum.cap_top = false
	drum.cap_bottom = false
	drum.radial_segments = 26
	var dm := _cup3_mesh(b, drum, C_DARK.darkened(0.29), Vector3(0.0, h * 0.5, 0.0))
	dm.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	# 아가리 테. 실물 철망 통은 여기가 굵게 말려 있지만 그 굵기는 안 따라간다 —
	# 50px 짜리 통에서 굵은 테는 통을 뚜껑 덮은 깡통으로 만든다. 그물이 위에서
	# 톱니로 끊기지만 않으면 되므로 1.4px 짜리 실선 한 줄이면 족하다.
	var lip := TorusMesh.new()
	lip.inner_radius = face - 0.012
	lip.outer_radius = face + 0.012
	lip.rings = 26
	lip.ring_segments = 6
	_cup3_mesh(b, lip, _cup3_tint(tint).lightened(0.18), Vector3(0.0, h, 0.0))


# 그 다트통의 통 겉. 안 적은 값은 기본값으로 채워 낸다 — 부르는 쪽이
# get(키, 기본값) 을 흩어 두면 기본값이 파일 여러 곳에 눌러앉는다.
# 잠긴 다트통은 표를 안 보고 기준선 통을 세운다.
func _cup3_skin(pi: int) -> Dictionary:
	var out := CUP_SKIN0.duplicate()
	var packs := GameData.packs()
	if pi < 0 or pi >= packs.size() or not _pack_open(pi):
		return out
	var row: Dictionary = CUP_SKIN.get(String(packs[pi].get("id", "")), {})
	for k in row:
		out[k] = row[k]
	return out


# 벽 바깥면의 반지름. 벽마다 다르다 — 민 통은 r+w 에, 철망은 그 절반에
# 선다. 동전이 이것을 보고 앉는다. 손으로 적어 두면 벽을 한 번 만질
# 때마다 동전이 벽 속에 파묻혀 통째로 사라진다(한 번 당했다).
func _cup3_face(wall: String, r: float, w: float) -> float:
	return r + w * 0.5 if wall == "net" else r + w


# 벽 바깥면의 색. 동전 그늘이 이것을 보고 제 벽보다 한 단 어두워진다 —
# 고정색으로 적어 두면 벽이 어두운 겉에서는 그늘이 벽보다 밝아진다.
func _cup3_wall_col(wall: String, tint: String) -> Color:
	return _cup3_tint(tint).darkened(0.30 if wall == "net" else 0.44)


# 통 몸의 바탕색. 겉 표의 tint 가 고른다. 벽 갈래(민·철망)와 **독립**이라
# 둘을 곱해 쓸 수 있다 — 금빛 철망을 만들 때 표에 한 칸만 적으면 된다.
func _cup3_tint(tint: String) -> Color:
	match tint:
		"gold": return C_GOLD
	return C_WIRE


# 통에 붙는 동전 한 장. 값은 전부 통 크기에 대한 비라 넓은 통에 붙어도
# 같은 동전로 보인다.
const CUP_STK := {
	"at":   -0.70,   # 통 앞에서 왼쪽으로 돌린 각(rad). 왼쪽 실루엣에 걸칠 만큼
					 # 돌려야 종이가 벽을 감고 도는 것이 보인다 — 정면에 두면
					 # 통이 원통인지 판때기인지 이 그림만으로는 안 갈린다
	"r":     0.46,   # 아가리 반지름의 몇 배. 통 폭의 41%
	"y":     0.34,   # 통 높이의 몇 배. 이보다 낮추면 바닥 테를 문다
	"face":  0.78,   # 얼굴/다이컷 반지름 비. draw_sticker 의 다이컷 폭과 같은 뜻
	"peel":  0.50,   # 아래 끝이 말린 정도. 2D 와 같은 식(_peel_y)을 쓴다
	"curl":  1.10,   # 말린 자락이 도는 각(rad, 63°). 이만큼 젖혀야
					 # 이형지가 위를 보고 빛을 받는다(안 젖히면 늘 그늘이라
					 # 얼굴과 8% 차로 붙는다). 더 젖히면 자락이 옆으로 서서
					 # 내려다보는 카메라에는 실선 한 줄로만 남는다
}


# 벽 위의 한 점. u 는 붙은 자리(at)에서 벽을 따라 잰 가로 거리(호 길이),
# v 는 높이, lift 는 벽에서 뜬 거리다. 각은 **뜨기 전 반지름**으로 잰다 —
# 뜬 반지름으로 재면 자락이 위로 접히면서 옆으로도 미끄러진다.
func _cup3_on(rad: float, at: float, u: float, v: float, y0: float,
		lift := 0.0) -> Vector3:
	var a := at + u / rad
	var rr := rad + lift
	return Vector3(sin(a) * rr, y0 + v, cos(a) * rr)


# 원반을 접는 선(fy)으로 가른 한 조각. 평평한 판을 대면 8px 짜리 동전도
# 가장자리가 벽으로 파고들므로 원통을 그대로 따라간다.
#   part 0  접는 선 위. 벽에 눕는다 (fy 가 반지름보다 크면 온 원이다)
#   part 1  접는 선 아래를 위로 만다. 2D 는 미러링(각 없는 접기)이면 되지만
#           3D 는 각이 곧 빛이라 진짜로 곡률을 준다 — 종이는 일정한 곡률로
#           휘므로 접는 선에서 잰 길이 d 가 그대로 각 k*d 다
#   part 2  접는 선 아래. 벽에 눕는다. 자락이 들려 드러난 자리다
func _cup3_leaf(rad: float, at: float, sr: float, y0: float, fy: float,
		part: int, curl: float, off: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 접는 선은 한가운데 **아래**에 있다(fy < 0). 2D 는 화면 y 가 아래로
	# 자라 같은 선을 +로 적는다 — 부호 하나로 자락이 통 위로 날아간다.
	var full := fy <= -sr + 0.001
	if part != 0 and full:
		return st.commit()                 # 접힐 자락이 없다
	var t0 := asin(clampf(fy / sr, -1.0, 1.0))
	var a0 := t0
	var a1 := PI - t0
	if part == 0 and full:
		a0 = -PI * 0.5
		a1 = PI * 1.5
	elif part != 0:
		a0 = PI - t0
		a1 = TAU + t0
	var cen := Vector2(0.0, 0.0 if full else fy)
	var n := 20
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / float(n))
		pts.append(Vector2(cos(a), sin(a)) * sr)
	# 곡률. 자락 길이(접는 선에서 원반 끝까지)를 다 돌면 curl 이 된다.
	var kv: float = curl / maxf(sr + fy, 0.001)
	for i in n:
		# 고닷의 앞면은 **시계 방향**이다. 반시계로 감으면 판이 벽 안쪽만
		# 보게 되어 화면에서 통째로 사라진다(한 번 당했다). 마는 것은 감는
		# 방향을 뒤집으므로 자락만 차례가 반대다.
		var tri: Array = [cen, pts[i], pts[i + 1]] if part == 1 			else [cen, pts[i + 1], pts[i]]
		for j in 3:
			var q: Vector2 = tri[j]
			var v := q.y
			var lift := off
			var nrm := Vector3(0.0, 0.0, 0.0)
			var a := at + q.x / rad
			if part == 1:
				var th := kv * (fy - q.y)          # 접는 선에서 잰 각
				v = fy + sin(th) / kv
				lift = off + (1.0 - cos(th)) / kv
				nrm = Vector3(sin(a) * cos(th), sin(th), cos(a) * cos(th))
			else:
				nrm = Vector3(sin(a), 0.0, cos(a))
			st.set_normal(nrm.normalized())
			st.add_vertex(_cup3_on(rad, at, q.x, v, y0, lift))
	return st.commit()


# 통에 붙은 동전. 게임의 다른 자리에서 쓰는 어법 그대로다 — 흰 다이컷 테
# 한 겹에 크림색 얼굴, 아래 끝은 말려 이형지가 보인다(draw_sticker).
# 반지름 10px 에 인쇄까지 넣으면 조건 아이콘이 두 픽셀로 뭉개지므로
# 여기서는 테·얼굴·말린 자락까지만 낸다.
func _cup3_sticker(b: Node3D, rad: float, r: float, h: float, wall: String,
		tint: String) -> void:
	var sr: float = r * float(CUP_STK.r)
	var y0: float = h * float(CUP_STK.y)
	var at: float = CUP_STK.at
	var cl: float = CUP_STK.curl
	# 2D 와 같은 식을 쓰되 부호를 뒤집는다 — 여기 y 는 위로 자란다.
	var fy := -_peel_y(sr, float(CUP_STK.peel))
	# 붙어 있던 자리. 자락이 들리면 여기가 드러난다 — 3D 쪽 그림자맵은
	# 꺼 두었으므로(_cup3_open) 이 어두운 활꼴 하나가 그림자를 대신한다.
	# 없으면 자락이 벽에 뜬 게 아니라 벽에 그려진 무늬로 읽힌다.
	_cup3_mesh(b, _cup3_leaf(rad, at, sr, y0, fy, 2, 0.0, 0.002),
			_cup3_wall_col(wall, tint).darkened(0.16), Vector3.ZERO)
	_cup3_mesh(b, _cup3_leaf(rad, at, sr, y0, fy, 0, 0.0, 0.004),
			C_DIECUT, Vector3.ZERO)
	_cup3_mesh(b, _cup3_leaf(rad, at, sr * float(CUP_STK.face), y0, fy,
			0, 0.0, 0.008), Color(STK_TIERS[0].body), Vector3.ZERO)
	# 뒤집힌 쪽은 이형지라 인쇄가 없다. 그래서 얼굴 위에 겹쳐도 무엇이
	# 가려졌는지가 안 헷갈린다. 종이는 옆면이 없으니 양면으로 둔다.
	# 말리면서 위를 보게 되므로 뿌리는 얼굴과 같은 밝기고 끝으로 갈수록
	# 밝아진다 — 그 그러데이션 하나가 "접혔다" 를 말한다.
	var fl := _cup3_mesh(b, _cup3_leaf(rad, at, sr, y0, fy, 1, cl, 0.006),
			C_LINER, Vector3.ZERO)
	fl.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED


# 통 하나. 원점은 **바닥 한가운데**라 y 0 이 곧 놓인 자리다.
# 겉이 통의 크기까지 정하므로(wide) 충돌도 여기서 같은 r 을 본다.
func _cup3_cup(skin: Dictionary) -> AnimatableBody3D:
	var r: float = float(CUP3.r) * float(skin.wide)
	var w: float = CUP3.wall
	var h: float = CUP3.h
	var b := AnimatableBody3D.new()
	b.sync_to_physics = true

	var tint := String(skin.tint)
	match String(skin.wall):
		"net":
			_cup3_wall_net(b, r, w, h, tint)
		_:
			_cup3_wall_solid(b, r, w, h, tint)
	if bool(skin.sticker):
		_cup3_sticker(b, _cup3_face(String(skin.wall), r, w), r, h,
				String(skin.wall), tint)
	var base := CylinderMesh.new()
	base.top_radius = r + w
	base.bottom_radius = r + w
	base.height = w * 1.6
	base.radial_segments = 26
	_cup3_mesh(b, base, _cup3_tint(tint).darkened(0.52), Vector3(0.0, w * 0.8, 0.0))

	var fl := CollisionShape3D.new()
	var fs := CylinderShape3D.new()
	fs.radius = r
	fs.height = w * 2.0
	fl.shape = fs
	fl.position = Vector3(0.0, w, 0.0)
	b.add_child(fl)
	# 발치 바닥. **통 몸에 붙인다** — 통이 미끄러질 때 바닥도 같이 가야
	# 발치에 놓인 것이 통을 따라간다. 따로 세우면 통만 나가고 골드는
	# 무대 한가운데 남는다.
	# 골드가 없는 다트통에는 안 붙인다. 아무것도 안 놓이는 바닥은 물리에
	# 몸 하나를 더 얹을 뿐이다.
	if int(skin.gold) > 0:
		var gd := CollisionShape3D.new()
		var gb := BoxShape3D.new()
		gb.size = Vector3(r * 7.0, w * 2.0, r * 4.0)
		gd.shape = gb
		gd.position = Vector3(0.0, -w, 0.0)
		b.add_child(gd)
	# 원통 충돌은 속이 안 비므로 벽을 조각으로 두른다. 조각 폭에 1.25 를
	# 곱해 겹쳐야 이음매로 자루가 새 나가지 않는다.
	var n: int = CUP3.seg
	for i in n:
		var a := TAU * float(i) / float(n)
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(TAU * r / float(n) * 1.25, h, w * 2.0)
		cs.shape = bx
		cs.position = Vector3(sin(a) * (r + w), h * 0.5, cos(a) * (r + w))
		cs.rotation = Vector3(0.0, a, 0.0)
		b.add_child(cs)
	return b


# ══════════════════════════════════════════════════════════
#  골드 — 3D 플라크
#
#  이 게임의 통화는 **직사각**이다. 아이템이 원반이라 통화를 직사각으로
#  갈라 둔 것이고(draw_plaque 주석), 그 어법을 3D 에도 그대로 옮긴다 —
#  여기서만 동전을 쓰면 화면마다 돈이 다른 물건이 된다.
#
#  2D 플라크의 네 가지 표식 중 셋을 옮긴다. 몸 · 어두운 옆면 · 파인 판.
#  대각 광택만 뺐다 — 3D 는 빛이 그 일을 한다.
#  비율도 2D 를 따른다: 세로 = 가로의 0.64 (draw_gold_at 의 iw · iw*0.64).
# ══════════════════════════════════════════════════════════

const GOLD3 := {
	"w":     0.22,     # 가로. 무대에서 13px 이라 발치에서 셀 수 있다
	"t":     0.05,     # 두께
	"mass":  0.06,
	"grav":  6.0,      # 자루와 같은 중력. 한 무대에 중력이 둘이면 안 된다
	"ldamp": 0.9,
	"adamp": 3.2,
	"fric":  0.85,     # 잘 안 미끄러진다 — 던져 놓은 것이 굴러가면 안 된다
	"bounce": 0.05,
	# 통 중심에서 이만큼(안반지름 배) 떨어진 데 떨군다. 통 바깥선이 1.13
	# 이고 플라크 반대각이 0.34 이라, 1.45 로는 벽 안에서 생겨 솔버가
	# 밀어내며 어디로 튈지 모르게 됐다. 2.0 이면 벽에서 확실히 떨어진다.
	"spill": 2.0,
	"drop":  0.55,     # 떨구는 높이. 낮으면 겹쳐 나고 높으면 튀어 나간다
	# 이보다 멀어지면 발치로 도로 부른다(안반지름 배). **놓는 자리보다
	# 넉넉히 밖이어야 한다** — 2.6 은 가장 바깥에 놓이는 2.44 와 붙어 있어서,
	# 놓자마자 도로 불리기를 되풀이하다 통 한쪽에 다 쌓였다.
	"keep":  3.4,
}


func _cup3_gold() -> RigidBody3D:
	var gw: float = GOLD3.w
	var gt: float = GOLD3.t
	var gd: float = gw * 0.64          # 2D 플라크의 세로비 그대로

	var b := RigidBody3D.new()
	b.mass = GOLD3.mass
	b.gravity_scale = GOLD3.grav
	b.linear_damp = GOLD3.ldamp
	b.angular_damp = GOLD3.adamp
	b.continuous_cd = true
	var pm := PhysicsMaterial.new()
	pm.friction = GOLD3.fric
	pm.bounce = GOLD3.bounce
	b.physics_material_override = pm

	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(gw, gt, gd)
	cs.shape = bx
	b.add_child(cs)

	var body := BoxMesh.new()
	body.size = Vector3(gw, gt, gd)
	_cup3_mesh(b, body, C_GOLD, Vector3.ZERO)
	# 파인 판. 2D 가 가운데를 어둡게 찍는 그 자리다 — 윗면에서 살짝 들어간다.
	var inl := BoxMesh.new()
	inl.size = Vector3(gw * 0.44, gt * 0.5, gd * 0.30)
	_cup3_mesh(b, inl, C_GOLD.darkened(0.40), Vector3(0.0, gt * 0.42, 0.0))
	return b


# 자루 하나. 축은 +Y 가 꽁지다 — 캡슐 충돌과 같은 축이라 둘이 안 어긋난다.
# 자루 색. _icon_dart 의 그것과 같은 값이라야 2D 받침과 3D 가 같은
# 다트로 읽힌다 — 다섯 종을 색으로 가르는 규약이 화면마다 갈리면 안 된다.
func _dart3_col(id: String) -> Color:
	match id:
		"hvy": return C_WIRE.lightened(0.30)
		"lgt": return C_GREEN.lightened(0.35)
		"prc": return C_CHIP.lightened(0.25)
		"mag": return C_MULT.lightened(0.25)
	return C_TXT


# 자루 한 벌의 메시. **두 무대가 같이 쓴다** — 통(새 런 화면)과 판에
# 꽂힌 다트다. 한 곳에서 만들어야 두 화면의 다트가 같은 물건으로 보인다.
#
# 자루의 축은 로컬 +Y 이고 촉이 −Y 쪽이다. 촉 끝은 정확히 −dl 에 온다
# (촉 원뿔이 −dl*0.82 에 서고 높이가 dl*0.36 이므로 −dl*0.82−dl*0.18).
# 꽂는 쪽이 그 약속을 읽고 자리를 잡으므로 비율을 바꾸면 같이 고친다.
#
# 비율은 _icon_dart 와 같다 — 2D 받침과 3D 가 다른 다트로 보이면
# 받침이 받침 구실을 못한다.
# Meshy 로 뽑아 500 삼각형으로 줄인 자루. 파일이 아니라 이 상수가 형태 전부다.
# 촉이 -Y, 온 길이 1.0 으로 맞춰 구웠다 — 쓰는 쪽에서 dl*2 로 키운다.
const DART3_MESHY := true      # 끄면 아래 원기둥 조합으로 돌아간다

# DART3M — Dart_ready.obj 에서 구움. 정점 252 · 삼각형 500
# 파일은 저장소에 안 들어간다. 이 상수가 형태 전부다.
static var DART3M_V := PackedVector3Array([
	Vector3(-0.00007, -0.50000, 0.00170), Vector3(0.00248, -0.45685, 0.00626), Vector3(0.00014, -0.47442, -0.00045),
	Vector3(0.00902, -0.43548, -0.00051), Vector3(-0.00772, -0.44751, 0.00163), Vector3(-0.00386, -0.44243, -0.00710),
	Vector3(0.00531, -0.42806, -0.00865), Vector3(-0.00340, -0.43445, 0.01037), Vector3(0.00737, -0.42776, 0.00977),
	Vector3(-0.00851, -0.41758, 0.00184), Vector3(0.00650, -0.39521, 0.01145), Vector3(-0.00558, -0.39887, -0.00957),
	Vector3(0.01143, -0.39397, -0.00104), Vector3(-0.00278, -0.38648, 0.01295), Vector3(-0.01013, -0.38722, 0.00543),
	Vector3(0.00144, -0.37995, -0.01097), Vector3(0.01191, -0.36574, 0.00343), Vector3(-0.01078, -0.37009, -0.00139),
	Vector3(0.00575, -0.35827, -0.00978), Vector3(0.00636, -0.36028, 0.01171), Vector3(-0.00750, -0.34372, -0.00947),
	Vector3(-0.00459, -0.35028, 0.01229), Vector3(-0.01139, -0.34618, 0.00035), Vector3(0.00928, -0.33307, -0.00702),
	Vector3(-0.00183, -0.32384, -0.01148), Vector3(0.00446, -0.32532, 0.01271), Vector3(0.01058, -0.32534, 0.00721),
	Vector3(-0.00531, -0.31682, 0.01163), Vector3(-0.01034, -0.31846, -0.00373), Vector3(0.01174, -0.30879, -0.00165),
	Vector3(-0.00954, -0.29244, 0.00623), Vector3(0.00195, -0.28424, -0.01058), Vector3(0.00817, -0.28484, 0.00921),
	Vector3(-0.00907, -0.28565, -0.00670), Vector3(0.01017, -0.27131, -0.00539), Vector3(0.00090, -0.26689, 0.01231),
	Vector3(-0.01115, -0.26045, 0.00407), Vector3(0.01157, -0.24697, -0.00091), Vector3(-0.01015, -0.25046, -0.00596),
	Vector3(0.00264, -0.24821, -0.01033), Vector3(0.00912, -0.23631, 0.00877), Vector3(-0.00465, -0.24393, 0.01091),
	Vector3(-0.01027, -0.22679, -0.00374), Vector3(-0.00386, -0.22148, -0.01116), Vector3(0.00106, -0.20889, 0.01297),
	Vector3(0.00923, -0.20550, -0.00680), Vector3(-0.00963, -0.20041, 0.00763), Vector3(0.01146, -0.20078, 0.00556),
	Vector3(-0.00196, -0.18704, -0.01074), Vector3(-0.01143, -0.19799, -0.00273), Vector3(0.00867, -0.16790, -0.00460),
	Vector3(0.00204, -0.16303, 0.01172), Vector3(0.00933, -0.15437, 0.00581), Vector3(-0.00704, -0.15877, -0.00503),
	Vector3(-0.00681, -0.15816, 0.00864), Vector3(0.00789, -0.13356, -0.00552), Vector3(-0.00780, -0.12804, 0.00513),
	Vector3(-0.00413, -0.13079, -0.00617), Vector3(0.00679, -0.10630, 0.00629), Vector3(0.00729, -0.09816, -0.00265),
	Vector3(-0.00607, -0.09932, -0.00577), Vector3(-0.00833, -0.09010, 0.00437), Vector3(-0.00036, -0.08770, 0.00935),
	Vector3(-0.00342, -0.07414, -0.00684), Vector3(0.00662, -0.06116, 0.00578), Vector3(0.00519, -0.05722, -0.00661),
	Vector3(-0.00646, -0.03963, -0.00260), Vector3(-0.00227, -0.04593, 0.00775), Vector3(0.00768, -0.03988, 0.00030),
	Vector3(0.00288, -0.02494, -0.00585), Vector3(-0.00402, -0.02237, 0.00708), Vector3(0.00533, -0.00208, 0.00695),
	Vector3(0.00586, 0.00272, -0.00252), Vector3(-0.00615, 0.00616, -0.00439), Vector3(-0.00566, 0.00162, 0.00509),
	Vector3(-0.00649, 0.03978, 0.00392), Vector3(-0.00423, 0.03838, -0.00532), Vector3(0.00177, 0.03332, 0.00609),
	Vector3(0.00379, 0.05287, -0.00448), Vector3(0.00226, 0.07145, 0.00540), Vector3(-0.00579, 0.07737, -0.00048),
	Vector3(0.00310, 0.09140, -0.00501), Vector3(0.00428, 0.09831, 0.00321), Vector3(-0.00434, 0.11682, 0.00167),
	Vector3(0.00368, 0.12139, 0.00188), Vector3(-0.00370, 0.15491, -0.00295), Vector3(0.00472, 0.15057, -0.00370),
	Vector3(0.00324, 0.15918, 0.00296), Vector3(-0.00197, 0.18179, 0.00561), Vector3(0.00862, 0.18131, 0.00091),
	Vector3(-0.01628, 0.19440, 0.00117), Vector3(-0.00261, 0.18955, -0.00551), Vector3(0.00425, 0.21371, 0.00513),
	Vector3(-0.01097, 0.21371, 0.00287), Vector3(0.00003, 0.20332, 0.01341), Vector3(0.00336, 0.22371, -0.00579),
	Vector3(0.01324, 0.20534, 0.00181), Vector3(-0.00004, 0.21328, -0.01482), Vector3(-0.00802, 0.22970, -0.00204),
	Vector3(-0.01492, 0.21754, -0.00067), Vector3(-0.00099, 0.22451, 0.01381), Vector3(-0.02559, 0.22580, 0.00126),
	Vector3(0.01967, 0.21548, 0.00014), Vector3(0.01776, 0.23915, 0.00230), Vector3(0.00308, 0.24718, 0.00751),
	Vector3(-0.00254, 0.25403, 0.00725), Vector3(-0.00225, 0.24815, -0.00922), Vector3(-0.00012, 0.25270, -0.02710),
	Vector3(0.02807, 0.23271, 0.00063), Vector3(0.00979, 0.26292, -0.00166), Vector3(-0.01251, 0.24894, 0.00251),
	Vector3(0.00474, 0.25141, -0.00377), Vector3(-0.02432, 0.25280, -0.00052), Vector3(-0.00029, 0.24326, 0.01898),
	Vector3(-0.03122, 0.24043, 0.00136), Vector3(0.00104, 0.26893, -0.02003), Vector3(-0.00950, 0.26835, -0.00118),
	Vector3(0.02885, 0.27343, 0.00211), Vector3(-0.03574, 0.26163, 0.00022), Vector3(0.02315, 0.27685, -0.00056),
	Vector3(0.02075, 0.28389, 0.00229), Vector3(-0.00132, 0.27899, -0.01920), Vector3(-0.02979, 0.28308, 0.00207),
	Vector3(0.03566, 0.24924, 0.00050), Vector3(0.00490, 0.27974, 0.00558), Vector3(0.00108, 0.28765, 0.02082),
	Vector3(-0.00023, 0.25795, 0.02530), Vector3(0.00013, 0.28061, 0.03444), Vector3(-0.01211, 0.29095, 0.00279),
	Vector3(-0.04184, 0.28925, 0.00095), Vector3(-0.00478, 0.28261, 0.00490), Vector3(0.03913, 0.27396, 0.00073),
	Vector3(0.00134, 0.29894, -0.01216), Vector3(0.00882, 0.29985, -0.00142), Vector3(-0.00124, 0.29957, 0.02376),
	Vector3(-0.01491, 0.30651, -0.00064), Vector3(-0.02210, 0.29189, -0.00055), Vector3(-0.00032, 0.29258, -0.03412),
	Vector3(-0.00346, 0.29759, -0.00277), Vector3(0.04173, 0.29360, 0.00077), Vector3(-0.03864, 0.31490, 0.00049),
	Vector3(0.00098, 0.31475, -0.02345), Vector3(0.01489, 0.31317, 0.00240), Vector3(0.03740, 0.31381, 0.00093),
	Vector3(0.02936, 0.32010, -0.00044), Vector3(0.00001, 0.30471, 0.03970), Vector3(-0.00106, 0.31992, -0.02808),
	Vector3(0.01899, 0.32434, -0.00059), Vector3(0.00437, 0.31576, 0.00534), Vector3(-0.02756, 0.32850, -0.00042),
	Vector3(-0.00344, 0.31993, -0.00589), Vector3(-0.00145, 0.32942, 0.01603), Vector3(-0.02848, 0.32565, 0.00209),
	Vector3(0.00006, 0.31723, -0.03982), Vector3(-0.00550, 0.32262, 0.00421), Vector3(-0.01472, 0.33691, 0.00231),
	Vector3(0.02921, 0.33272, 0.00213), Vector3(0.00097, 0.33746, 0.02508), Vector3(0.00247, 0.34339, 0.00739),
	Vector3(-0.04022, 0.33948, 0.00066), Vector3(0.00122, 0.34524, -0.01156), Vector3(-0.00001, 0.33536, 0.04154),
	Vector3(-0.00143, 0.34174, -0.01428), Vector3(-0.00098, 0.33779, 0.03204), Vector3(0.00302, 0.34295, -0.00216),
	Vector3(0.00879, 0.35317, -0.00062), Vector3(-0.01676, 0.34826, -0.00057), Vector3(0.00081, 0.34948, -0.02849),
	Vector3(-0.00197, 0.34591, 0.00648), Vector3(0.04142, 0.33844, 0.00085), Vector3(0.01711, 0.36179, 0.00230),
	Vector3(-0.00089, 0.36194, -0.03283), Vector3(-0.00868, 0.36499, -0.00091), Vector3(0.02346, 0.36133, -0.00053),
	Vector3(0.03288, 0.36519, 0.00194), Vector3(0.00003, 0.38072, -0.04154), Vector3(-0.00118, 0.36535, 0.02546),
	Vector3(-0.02485, 0.37017, 0.00216), Vector3(-0.03976, 0.37273, 0.00081), Vector3(-0.02634, 0.36907, -0.00041),
	Vector3(-0.00133, 0.38741, -0.01849), Vector3(-0.00139, 0.38477, 0.01677), Vector3(0.00038, 0.36643, 0.03696),
	Vector3(-0.00094, 0.37970, 0.03275), Vector3(0.03466, 0.37884, -0.00022), Vector3(0.00112, 0.37960, 0.01825),
	Vector3(-0.00625, 0.38223, 0.00322), Vector3(-0.00192, 0.38605, -0.00731), Vector3(0.04184, 0.39155, 0.00096),
	Vector3(0.00103, 0.38477, -0.02093), Vector3(0.00462, 0.39238, 0.00301), Vector3(0.00121, 0.38419, -0.01047),
	Vector3(0.00065, 0.39094, -0.03371), Vector3(0.00007, 0.39051, 0.04041), Vector3(0.00485, 0.39516, -0.00182),
	Vector3(-0.01550, 0.40220, -0.00053), Vector3(0.02027, 0.39981, -0.00052), Vector3(0.01924, 0.41129, 0.00217),
	Vector3(-0.03798, 0.40523, 0.00084), Vector3(-0.00084, 0.40894, -0.03380), Vector3(-0.00012, 0.41661, 0.03900),
	Vector3(0.03282, 0.41388, 0.00191), Vector3(-0.00119, 0.41864, -0.02251), Vector3(-0.00139, 0.41268, 0.01549),
	Vector3(-0.00627, 0.41747, -0.00063), Vector3(0.00119, 0.41485, 0.01064), Vector3(-0.01114, 0.41688, 0.00223),
	Vector3(0.00105, 0.41542, -0.01792), Vector3(0.00097, 0.41551, 0.02418), Vector3(-0.02283, 0.42729, 0.00204),
	Vector3(-0.02950, 0.42415, -0.00024), Vector3(0.00074, 0.43214, -0.02989), Vector3(-0.00250, 0.43050, 0.00654),
	Vector3(0.03193, 0.42932, -0.00022), Vector3(0.00554, 0.42376, -0.00185), Vector3(-0.00109, 0.42037, 0.02754),
	Vector3(0.04168, 0.42955, 0.00079), Vector3(-0.00181, 0.43874, -0.00518), Vector3(0.03435, 0.45436, 0.00145),
	Vector3(-0.00017, 0.44164, -0.03952), Vector3(0.00174, 0.44313, -0.00600), Vector3(-0.02076, 0.43745, -0.00032),
	Vector3(0.02061, 0.43938, -0.00033), Vector3(0.01562, 0.44304, 0.00207), Vector3(-0.04164, 0.44328, 0.00058),
	Vector3(-0.00018, 0.44880, 0.03931), Vector3(0.00093, 0.44357, -0.01898), Vector3(0.00330, 0.44813, 0.00537),
	Vector3(-0.03415, 0.46060, 0.00097), Vector3(0.00083, 0.44316, 0.02657), Vector3(-0.00122, 0.44656, 0.01851),
	Vector3(-0.00100, 0.45671, -0.02585), Vector3(0.00504, 0.46876, -0.00226), Vector3(-0.01620, 0.45328, -0.00028),
	Vector3(-0.00092, 0.46645, 0.02673), Vector3(0.00086, 0.46725, 0.01446), Vector3(-0.00356, 0.46440, 0.00631),
	Vector3(-0.00117, 0.46761, -0.01102), Vector3(-0.00653, 0.47455, 0.00067), Vector3(-0.01461, 0.47584, 0.00103),
	Vector3(0.02838, 0.47238, 0.00055), Vector3(-0.02493, 0.47441, 0.00085), Vector3(0.00004, 0.47608, -0.03454),
	Vector3(0.01649, 0.48036, 0.00089), Vector3(0.00076, 0.47164, -0.01706), Vector3(0.00642, 0.47927, 0.00242),
	Vector3(0.00003, 0.48248, 0.03359), Vector3(-0.00012, 0.48640, -0.02617), Vector3(0.00015, 0.48620, 0.02087),
	Vector3(-0.00020, 0.49524, -0.01335), Vector3(0.00023, 0.50000, 0.00066), Vector3(-0.00022, 0.49619, 0.01106)
])
static var DART3M_N := PackedVector3Array([
	Vector3(0.00000, 0.00000, 0.00000), Vector3(0.32036, -0.31415, 0.89369), Vector3(0.39830, -0.53764, -0.74317),
	Vector3(0.98585, -0.14271, -0.08796), Vector3(-0.95636, -0.18283, 0.22791), Vector3(-0.61448, -0.12095, -0.77961),
	Vector3(0.47644, -0.08470, -0.87512), Vector3(-0.40241, -0.09241, 0.91078), Vector3(0.76975, -0.08833, 0.63220),
	Vector3(-0.99327, -0.04587, 0.10637), Vector3(0.58915, -0.03499, 0.80727), Vector3(-0.69833, -0.03490, -0.71493),
	Vector3(0.96884, -0.02423, -0.24650), Vector3(-0.39764, -0.03574, 0.91685), Vector3(-0.96707, -0.03749, 0.25174),
	Vector3(0.06433, -0.01764, -0.99777), Vector3(0.99838, -0.01002, 0.05597), Vector3(-0.95574, -0.02327, -0.29330),
	Vector3(0.55777, -0.01617, -0.82984), Vector3(0.46268, -0.00513, 0.88651), Vector3(-0.57626, -0.02993, -0.81672),
	Vector3(-0.58535, 0.00235, 0.81078), Vector3(-0.98083, 0.00517, 0.19480), Vector3(0.81303, 0.00207, -0.58221),
	Vector3(-0.14587, 0.00924, -0.98926), Vector3(0.23490, 0.02430, 0.97172), Vector3(0.94378, 0.00491, 0.33055),
	Vector3(-0.55904, 0.01799, 0.82895), Vector3(-0.98539, 0.01022, -0.17002), Vector3(0.96879, 0.01595, -0.24737),
	Vector3(-0.90001, -0.00059, 0.43587), Vector3(0.18758, 0.01262, -0.98217), Vector3(0.75434, 0.03783, 0.65539),
	Vector3(-0.82449, -0.00180, -0.56587), Vector3(0.91155, 0.00216, -0.41118), Vector3(0.04240, 0.00594, 0.99908),
	Vector3(-0.92844, 0.00499, 0.37144), Vector3(0.99997, -0.00178, 0.00780), Vector3(-0.64227, 0.01815, -0.76626),
	Vector3(0.20227, -0.00301, -0.97933), Vector3(0.77470, -0.03022, 0.63160), Vector3(-0.54821, -0.01251, 0.83625),
	Vector3(-0.98812, -0.01868, -0.15253), Vector3(-0.25747, -0.01328, -0.96620), Vector3(0.19151, 0.00737, 0.98146),
	Vector3(0.78939, 0.00845, -0.61383), Vector3(-0.76423, -0.00570, 0.64492), Vector3(0.95155, 0.01317, 0.30721),
	Vector3(-0.09238, 0.07934, -0.99256), Vector3(-0.94862, 0.04798, -0.31277), Vector3(0.64519, 0.05341, -0.76215),
	Vector3(0.01453, 0.04538, 0.99886), Vector3(0.92102, 0.03188, 0.38822), Vector3(-0.75559, 0.08231, -0.64985),
	Vector3(-0.76949, 0.08086, 0.63352), Vector3(0.59276, 0.03273, -0.80472), Vector3(-0.83118, 0.00444, 0.55599),
	Vector3(-0.55037, -0.01218, -0.83483), Vector3(0.58820, 0.04560, 0.80742), Vector3(0.79146, 0.02027, -0.61089),
	Vector3(-0.27272, 0.02142, -0.96186), Vector3(-0.98738, 0.01632, 0.15753), Vector3(-0.05972, -0.01400, 0.99812),
	Vector3(-0.41666, -0.00513, -0.90905), Vector3(0.83731, 0.03487, 0.54562), Vector3(0.70311, 0.01263, -0.71097),
	Vector3(-0.92297, 0.01447, -0.38459), Vector3(-0.20535, 0.03134, 0.97819), Vector3(0.98145, 0.00741, 0.19158),
	Vector3(0.17885, 0.02385, -0.98359), Vector3(-0.62689, -0.00121, 0.77911), Vector3(0.56898, 0.01980, 0.82212),
	Vector3(0.81857, 0.04135, -0.57292), Vector3(-0.67128, 0.01006, -0.74113), Vector3(-0.75337, 0.00937, 0.65753),
	Vector3(-0.86426, 0.03753, 0.50164), Vector3(-0.39116, 0.01629, -0.92018), Vector3(0.62284, 0.04605, 0.78099),
	Vector3(0.79587, 0.03350, -0.60454), Vector3(0.35331, 0.03130, 0.93498), Vector3(-0.92960, 0.06563, -0.36267),
	Vector3(0.41669, 0.06369, -0.90681), Vector3(0.72007, 0.02848, 0.69332), Vector3(-0.82402, 0.10982, 0.55582),
	Vector3(0.81137, -0.04590, -0.58272), Vector3(-0.85300, -0.24853, -0.45893), Vector3(0.65592, -0.02134, -0.75453),
	Vector3(0.45633, -0.03683, 0.88905), Vector3(-0.22380, -0.15061, 0.96293), Vector3(0.95229, -0.19343, -0.23609),
	Vector3(-0.97464, -0.21985, 0.04167), Vector3(-0.02791, -0.07776, -0.99658), Vector3(0.53601, -0.07453, 0.84091),
	Vector3(-0.45248, -0.01591, 0.89163), Vector3(0.80662, -0.07933, 0.58572), Vector3(0.74160, -0.07637, -0.66648),
	Vector3(0.87516, -0.26035, 0.40782), Vector3(-0.13125, -0.17345, -0.97606), Vector3(-0.53814, -0.00598, -0.84283),
	Vector3(-0.26667, -0.02728, -0.96340), Vector3(-0.63277, -0.04234, 0.77318), Vector3(-0.25384, -0.05538, 0.96566),
	Vector3(0.37705, -0.05314, -0.92466), Vector3(0.23169, -0.03937, 0.97199), Vector3(0.59010, -0.02111, 0.80705),
	Vector3(-0.89326, -0.00282, 0.44954), Vector3(-0.93410, 0.00321, -0.35701), Vector3(-0.93659, -0.07523, -0.34225),
	Vector3(0.33546, -0.10517, -0.93617), Vector3(0.31294, -0.00997, -0.94972), Vector3(-0.24483, 0.00362, 0.96956),
	Vector3(0.76898, 0.00497, -0.63926), Vector3(-0.10013, -0.01528, -0.99486), Vector3(0.91080, -0.08468, 0.40407),
	Vector3(-0.13579, -0.04207, 0.98984), Vector3(0.98636, -0.01186, -0.16420), Vector3(-0.27763, 0.01648, -0.96055),
	Vector3(0.08841, -0.01187, 0.99601), Vector3(-0.19014, -0.02538, -0.98143), Vector3(0.06728, -0.00509, -0.99772),
	Vector3(0.14578, 0.00700, 0.98929), Vector3(-0.99444, -0.01334, -0.10448), Vector3(-0.07963, -0.01068, 0.99677),
	Vector3(0.37387, -0.09785, -0.92230), Vector3(0.72424, 0.00493, 0.68953), Vector3(0.98792, -0.00641, 0.15483),
	Vector3(-0.96422, -0.07241, 0.25504), Vector3(0.98051, -0.04314, 0.19169), Vector3(-0.19185, -0.00494, 0.98141),
	Vector3(-0.19718, -0.00628, 0.98035), Vector3(-0.81106, -0.03499, 0.58392), Vector3(0.18079, -0.01191, -0.98345),
	Vector3(0.93254, 0.00282, -0.36106), Vector3(0.48833, 0.03038, -0.87213), Vector3(-0.99269, -0.01191, 0.12015),
	Vector3(-0.16747, -0.01933, -0.98569), Vector3(-0.05179, 0.00133, -0.99866), Vector3(0.21791, -0.15442, -0.96367),
	Vector3(-0.81049, -0.00856, -0.58569), Vector3(0.13282, 0.00081, 0.99114), Vector3(-0.16484, 0.00246, -0.98632),
	Vector3(0.99863, -0.00502, -0.05200), Vector3(0.14166, 0.00645, 0.98989), Vector3(0.23872, -0.00294, 0.97108),
	Vector3(0.07816, -0.00051, -0.99694), Vector3(0.83913, -0.06782, 0.53968), Vector3(-0.99653, -0.00014, -0.08323),
	Vector3(0.03220, 0.00485, -0.99947), Vector3(0.67230, 0.00447, 0.74026), Vector3(-0.05429, 0.00065, -0.99852),
	Vector3(-0.85821, -0.01191, -0.51316), Vector3(-0.98103, 0.01489, 0.19327), Vector3(-0.07033, 0.00492, 0.99751),
	Vector3(0.85094, -0.04699, -0.52316), Vector3(-0.69436, 0.07996, 0.71517), Vector3(-0.12673, 0.00218, 0.99194),
	Vector3(0.05699, -0.00445, 0.99836), Vector3(0.99781, -0.00081, 0.06622), Vector3(0.89709, 0.01184, 0.44168),
	Vector3(-0.31729, 0.00218, 0.94833), Vector3(0.98789, 0.01833, -0.15404), Vector3(-0.63216, -0.01580, 0.77468),
	Vector3(-0.98245, 0.00983, -0.18624), Vector3(-0.99717, 0.00097, 0.07515), Vector3(0.81820, 0.01224, -0.57480),
	Vector3(0.25183, -0.00758, -0.96774), Vector3(-0.15464, 0.01277, -0.98789), Vector3(0.99902, -0.00138, -0.04425),
	Vector3(-0.82829, 0.00001, 0.56030), Vector3(0.42284, -0.02380, -0.90589), Vector3(0.11772, 0.00646, 0.99303),
	Vector3(-0.99838, -0.00123, -0.05690), Vector3(-0.48566, 0.00333, -0.87414), Vector3(0.04435, -0.00386, -0.99901),
	Vector3(0.06706, -0.00045, 0.99775), Vector3(0.72994, -0.00572, -0.68349), Vector3(-0.99958, 0.00063, 0.02898),
	Vector3(-0.06476, 0.00316, 0.99790), Vector3(-0.44170, 0.01425, -0.89705), Vector3(-0.05339, 0.00571, -0.99856),
	Vector3(-0.99922, 0.00034, -0.03952), Vector3(-0.99202, -0.01083, 0.12564), Vector3(0.99196, 0.00128, 0.12651),
	Vector3(-0.99639, -0.00125, 0.08493), Vector3(0.07116, -0.00178, -0.99746), Vector3(0.99455, 0.00459, 0.10419),
	Vector3(-0.54741, 0.00323, 0.83686), Vector3(-0.84768, 0.02954, -0.52968), Vector3(0.95103, 0.00869, 0.30897),
	Vector3(0.99971, 0.00044, -0.02410), Vector3(0.53625, 0.01216, 0.84397), Vector3(0.94972, -0.01848, -0.31256),
	Vector3(0.99827, 0.00173, -0.05878), Vector3(0.97552, 0.00082, 0.21993), Vector3(0.51793, -0.00867, -0.85538),
	Vector3(-0.13295, 0.00762, -0.99109), Vector3(0.05459, 0.00285, -0.99850), Vector3(0.03401, 0.00515, 0.99941),
	Vector3(-0.70568, 0.01104, 0.70844), Vector3(-0.99771, 0.00224, -0.06758), Vector3(0.67409, 0.02530, 0.73822),
	Vector3(0.05305, 0.00384, 0.99858), Vector3(-0.99946, 0.00327, -0.03258), Vector3(-0.98729, 0.01814, 0.15788),
	Vector3(-0.29624, 0.04116, -0.95422), Vector3(0.98553, 0.00044, 0.16952), Vector3(-0.15451, -0.01694, 0.98785),
	Vector3(0.98811, 0.00321, -0.15368), Vector3(0.99789, 0.00093, 0.06495), Vector3(-0.10254, 0.00886, 0.99469),
	Vector3(-0.04926, 0.00196, -0.99878), Vector3(0.99893, 0.00536, -0.04584), Vector3(-0.86868, 0.00038, 0.49537),
	Vector3(0.07517, 0.01277, -0.99709), Vector3(0.47843, 0.01132, -0.87805), Vector3(-0.99882, 0.00265, 0.04853),
	Vector3(0.91567, 0.10609, 0.38768), Vector3(-0.96676, 0.00022, -0.25567), Vector3(0.09666, 0.03640, 0.99465),
	Vector3(-0.31051, 0.08160, -0.94706), Vector3(0.96535, 0.00853, -0.26080), Vector3(-0.03470, 0.01442, -0.99929),
	Vector3(0.08277, 0.01526, -0.99645), Vector3(0.11521, 0.00931, 0.99330), Vector3(-0.15416, 0.01309, -0.98796),
	Vector3(-0.92100, 0.02898, 0.38847), Vector3(0.99909, 0.01102, -0.04116), Vector3(0.75453, -0.00348, 0.65626),
	Vector3(-0.30496, 0.09938, 0.94717), Vector3(0.99876, 0.00861, 0.04897), Vector3(-0.99599, -0.01381, 0.08845),
	Vector3(-0.99897, 0.01539, -0.04276), Vector3(0.66801, 0.06677, -0.74115), Vector3(0.00089, 0.02926, -0.99957),
	Vector3(-0.99682, 0.01975, 0.07720), Vector3(0.98113, 0.02305, 0.19196), Vector3(-0.74709, 0.03249, 0.66393),
	Vector3(-0.98936, 0.03388, -0.14150), Vector3(-0.78009, 0.11253, -0.61547), Vector3(-0.29813, 0.16504, 0.94015),
	Vector3(0.31655, 0.24204, -0.91717), Vector3(-0.48015, 0.44116, 0.75818), Vector3(0.98888, 0.04752, -0.14090),
	Vector3(0.81267, 0.39787, 0.42576), Vector3(0.98725, 0.00954, -0.15891), Vector3(0.89791, 0.15940, 0.41031),
	Vector3(0.98364, 0.07266, 0.16486), Vector3(0.97979, 0.12189, -0.15857), Vector3(0.69204, 0.47898, 0.54005),
	Vector3(-0.59696, 0.55136, -0.58279), Vector3(-0.45607, 0.69514, -0.55568), Vector3(-0.18595, 0.46542, 0.86534)
])
static var DART3M_I := PackedInt32Array([
	0, 1, 2, 0, 2, 1, 1, 2, 3, 2, 4, 5,
	2, 1, 4, 2, 5, 6, 2, 6, 3, 4, 1, 7,
	1, 3, 8, 7, 1, 8, 5, 4, 9, 4, 7, 9,
	10, 7, 8, 6, 5, 11, 5, 9, 11, 3, 12, 8,
	7, 13, 9, 8, 12, 10, 9, 13, 14, 9, 14, 11,
	10, 13, 7, 12, 3, 6, 12, 6, 15, 6, 11, 15,
	10, 12, 16, 11, 14, 17, 11, 17, 15, 12, 15, 18,
	10, 16, 19, 16, 12, 18, 13, 10, 19, 15, 17, 20,
	13, 21, 14, 13, 19, 21, 20, 17, 22, 16, 18, 23,
	15, 20, 18, 17, 14, 21, 18, 20, 24, 19, 25, 21,
	17, 21, 22, 19, 16, 26, 25, 19, 26, 22, 21, 27,
	23, 18, 24, 16, 23, 26, 22, 28, 20, 21, 25, 27,
	26, 23, 29, 20, 28, 24, 22, 27, 28, 27, 30, 28,
	31, 23, 24, 29, 23, 31, 32, 27, 25, 24, 28, 33,
	33, 28, 30, 25, 26, 32, 29, 32, 26, 34, 29, 31,
	24, 33, 31, 32, 29, 34, 27, 35, 30, 27, 32, 35,
	33, 30, 36, 34, 37, 32, 30, 35, 36, 31, 33, 38,
	32, 37, 35, 33, 36, 38, 34, 31, 39, 35, 40, 41,
	36, 35, 41, 37, 40, 35, 31, 38, 39, 34, 39, 37,
	39, 38, 42, 36, 42, 38, 43, 39, 42, 36, 41, 42,
	41, 40, 44, 37, 39, 45, 42, 41, 46, 37, 45, 40,
	39, 43, 45, 40, 45, 47, 43, 48, 45, 41, 44, 46,
	40, 47, 44, 42, 46, 49, 42, 49, 43, 43, 49, 48,
	47, 45, 50, 46, 44, 51, 47, 52, 44, 47, 50, 52,
	48, 49, 53, 51, 54, 46, 44, 52, 51, 45, 48, 50,
	46, 54, 49, 49, 54, 53, 50, 48, 53, 52, 50, 55,
	53, 54, 56, 55, 50, 57, 50, 53, 57, 51, 52, 58,
	57, 53, 56, 54, 51, 58, 54, 58, 56, 58, 52, 59,
	57, 60, 55, 52, 55, 59, 57, 56, 61, 60, 57, 61,
	58, 62, 56, 56, 62, 61, 55, 60, 59, 60, 63, 59,
	58, 64, 62, 59, 65, 58, 60, 61, 63, 58, 65, 64,
	59, 63, 65, 61, 66, 63, 61, 62, 67, 61, 67, 66,
	62, 64, 67, 64, 65, 68, 65, 63, 66, 66, 69, 65,
	64, 68, 67, 67, 70, 66, 68, 65, 69, 68, 71, 67,
	69, 72, 68, 67, 71, 70, 68, 72, 71, 69, 66, 73,
	66, 70, 74, 73, 66, 74, 74, 70, 71, 69, 73, 72,
	73, 74, 75, 72, 73, 76, 71, 77, 74, 72, 77, 71,
	77, 75, 74, 72, 76, 78, 77, 72, 78, 76, 73, 75,
	77, 78, 79, 79, 75, 77, 75, 80, 76, 76, 80, 78,
	75, 79, 80, 78, 81, 79, 78, 80, 81, 82, 79, 81,
	81, 80, 83, 80, 79, 83, 82, 83, 79, 82, 81, 84,
	82, 84, 83, 81, 83, 84, 84, 83, 85, 86, 84, 85,
	84, 86, 87, 83, 87, 85, 84, 87, 83, 87, 88, 85,
	87, 89, 88, 85, 88, 90, 87, 86, 91, 86, 85, 91,
	85, 90, 91, 89, 92, 88, 90, 88, 93, 87, 91, 89,
	88, 92, 94, 89, 91, 95, 89, 96, 92, 91, 97, 95,
	98, 91, 99, 91, 90, 99, 88, 100, 93, 94, 100, 88,
	97, 91, 98, 89, 95, 96, 99, 90, 101, 90, 93, 101,
	102, 96, 95, 102, 103, 96, 100, 94, 104, 100, 105, 93,
	98, 106, 97, 94, 92, 104, 97, 106, 107, 102, 108, 103,
	108, 102, 109, 110, 101, 93, 102, 95, 111, 96, 103, 92,
	112, 99, 101, 98, 99, 112, 105, 110, 93, 100, 104, 113,
	109, 102, 111, 101, 114, 112, 95, 97, 115, 103, 104, 92,
	97, 107, 115, 106, 98, 116, 100, 113, 105, 103, 108, 117,
	112, 114, 118, 109, 119, 108, 103, 117, 120, 106, 121, 107,
	95, 115, 111, 104, 103, 120, 114, 122, 118, 108, 119, 123,
	104, 124, 113, 113, 125, 126, 127, 126, 125, 110, 128, 101,
	108, 123, 117, 122, 129, 118, 110, 105, 130, 120, 124, 104,
	101, 128, 114, 114, 128, 122, 123, 131, 117, 98, 112, 116,
	110, 130, 128, 123, 119, 131, 111, 115, 132, 109, 111, 132,
	113, 126, 105, 124, 125, 113, 109, 133, 119, 126, 134, 105,
	135, 116, 136, 112, 136, 116, 105, 134, 130, 115, 107, 137,
	112, 118, 136, 107, 121, 137, 106, 116, 138, 131, 139, 117,
	121, 106, 138, 118, 140, 136, 134, 126, 127, 115, 141, 132,
	133, 109, 132, 115, 137, 141, 138, 116, 135, 124, 120, 142,
	117, 143, 120, 131, 119, 144, 145, 134, 127, 121, 146, 137,
	118, 129, 140, 119, 133, 147, 142, 148, 124, 136, 140, 149,
	124, 148, 125, 121, 138, 150, 130, 151, 128, 131, 144, 143,
	119, 147, 144, 139, 131, 143, 134, 151, 130, 122, 152, 129,
	117, 139, 143, 137, 153, 141, 121, 150, 146, 151, 154, 128,
	128, 155, 152, 128, 152, 122, 143, 156, 120, 153, 137, 146,
	125, 157, 127, 154, 155, 128, 120, 156, 142, 136, 149, 135,
	148, 158, 125, 152, 140, 129, 127, 157, 145, 125, 158, 157,
	138, 135, 150, 149, 140, 159, 132, 160, 133, 145, 161, 134,
	146, 150, 162, 134, 163, 151, 133, 164, 165, 150, 135, 166,
	147, 133, 165, 134, 161, 163, 133, 160, 164, 141, 153, 167,
	145, 157, 161, 132, 141, 160, 151, 168, 154, 169, 156, 143,
	142, 170, 148, 153, 146, 171, 143, 144, 169, 148, 170, 158,
	140, 152, 159, 162, 150, 172, 144, 147, 173, 171, 146, 162,
	169, 144, 173, 166, 135, 149, 169, 174, 156, 167, 153, 175,
	163, 176, 151, 175, 153, 171, 156, 170, 142, 150, 166, 172,
	152, 155, 177, 149, 159, 178, 141, 167, 160, 149, 179, 166,
	162, 180, 171, 168, 151, 181, 152, 177, 159, 154, 168, 155,
	157, 182, 161, 173, 147, 165, 176, 163, 183, 173, 184, 169,
	149, 178, 179, 156, 174, 170, 161, 182, 163, 157, 158, 185,
	168, 186, 155, 172, 187, 162, 169, 188, 174, 168, 181, 186,
	166, 179, 172, 160, 167, 189, 163, 182, 183, 158, 190, 185,
	158, 170, 190, 162, 187, 180, 159, 177, 178, 151, 176, 181,
	160, 191, 164, 167, 175, 192, 155, 186, 177, 188, 169, 184,
	164, 191, 165, 157, 185, 182, 182, 193, 183, 160, 189, 191,
	173, 165, 194, 167, 192, 189, 179, 195, 172, 196, 184, 173,
	165, 191, 194, 190, 170, 197, 179, 178, 198, 173, 194, 196,
	175, 171, 199, 183, 193, 200, 187, 172, 195, 174, 201, 170,
	171, 180, 202, 199, 171, 202, 181, 203, 186, 201, 197, 170,
	174, 188, 201, 187, 195, 204, 183, 181, 176, 190, 205, 185,
	186, 206, 177, 179, 198, 195, 177, 198, 178, 191, 207, 194,
	185, 208, 182, 198, 177, 209, 191, 189, 207, 182, 208, 193,
	177, 206, 209, 195, 198, 210, 189, 211, 207, 203, 212, 186,
	193, 208, 200, 184, 196, 213, 194, 207, 214, 183, 215, 181,
	188, 184, 213, 181, 215, 203, 196, 194, 214, 185, 205, 208,
	189, 192, 211, 183, 200, 215, 188, 213, 216, 206, 186, 212,
	187, 217, 180, 201, 188, 216, 197, 201, 218, 175, 199, 219,
	207, 220, 214, 187, 204, 217, 192, 219, 211, 195, 210, 221,
	196, 222, 213, 190, 197, 223, 198, 224, 210, 192, 175, 219,
	200, 225, 215, 207, 226, 220, 190, 227, 205, 198, 228, 224,
	214, 222, 196, 195, 221, 204, 208, 229, 200, 223, 227, 190,
	215, 230, 203, 219, 199, 231, 180, 217, 202, 198, 209, 228,
	214, 232, 222, 199, 202, 231, 203, 230, 212, 205, 227, 208,
	207, 211, 226, 214, 220, 232, 229, 225, 200, 204, 221, 233,
	215, 234, 230, 208, 235, 229, 206, 236, 209, 208, 227, 235,
	210, 224, 228, 216, 218, 201, 202, 237, 231, 237, 202, 217,
	206, 212, 236, 217, 204, 238, 204, 233, 238, 236, 239, 209,
	216, 213, 218, 213, 222, 240, 209, 241, 228, 211, 219, 242,
	225, 234, 215, 218, 223, 197, 213, 240, 218, 221, 210, 228,
	221, 228, 241, 221, 241, 233, 238, 233, 239, 223, 243, 227,
	220, 226, 244, 230, 236, 212, 226, 211, 242, 227, 243, 245,
	220, 244, 232, 222, 232, 243, 229, 246, 225, 242, 219, 231,
	209, 239, 241, 226, 242, 247, 245, 235, 227, 236, 238, 239,
	223, 218, 240, 235, 248, 229, 226, 247, 244, 223, 240, 243,
	217, 238, 237, 248, 246, 229, 234, 236, 230, 240, 222, 243,
	233, 241, 239, 225, 246, 234, 231, 237, 249, 243, 232, 245,
	242, 231, 247, 238, 250, 237, 244, 249, 232, 235, 251, 248,
	247, 231, 249, 236, 234, 248, 236, 251, 238, 248, 251, 236,
	246, 248, 234, 245, 251, 235, 245, 232, 250, 250, 251, 245,
	232, 249, 250, 238, 251, 250, 247, 249, 244, 237, 250, 249
])

func _mesh_dart3m() -> ArrayMesh:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = DART3M_V
	a[Mesh.ARRAY_NORMAL] = DART3M_N
	a[Mesh.ARRAY_INDEX] = DART3M_I
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m

func _dart3_meshes(b: Node3D, dl: float, dr: float, fin: float, col: Color) -> void:
	if DART3_MESHY:
		var mi := _cup3_mesh(b, _mesh_dart3m(), col, Vector3.ZERO)
		mi.scale = Vector3.ONE * (dl * 2.0)
		return

	var tip := CylinderMesh.new()
	tip.top_radius = dr
	tip.bottom_radius = 0.0
	tip.height = dl * 0.36
	tip.radial_segments = 8
	_cup3_mesh(b, tip, C_LIGHT, Vector3(0.0, -dl * 0.82, 0.0))
	var bar := CylinderMesh.new()
	bar.top_radius = dr
	bar.bottom_radius = dr
	bar.height = dl * 0.84
	bar.radial_segments = 10
	_cup3_mesh(b, bar, col, Vector3(0.0, -dl * 0.22, 0.0))
	var sha := CylinderMesh.new()
	sha.top_radius = dr * 0.42
	sha.bottom_radius = dr * 0.42
	sha.height = dl * 0.30
	sha.radial_segments = 6
	_cup3_mesh(b, sha, C_DARK.lightened(0.25), Vector3(0.0, dl * 0.35, 0.0))
	# 날개는 배럴보다 한 단 어둡다 — 둘이 같은 흰색이면 표준 다트가
	# 머리 큰 흰 막대 하나로 뭉쳐 보인다(2D 아이콘은 굵기로 갈리지만
	# 3D 는 같은 빛을 받아 굵기 차이가 안 읽힌다).
	var fm := BoxMesh.new()
	fm.size = Vector3(fin * 2.0, dl * 0.42, 0.012 * dl / 0.81)
	for q in 2:
		_cup3_mesh(b, fm, col.darkened(0.18), Vector3(0.0, dl * 0.76, 0.0),
				Vector3(0.0, PI * 0.5 * float(q), 0.0))


# 자루 색은 **다트 종류가 정한다** — 무거운 회색 · 가벼운 초록 · 관통 파랑 ·
# 자석 빨강. 그 축을 다트통이 덮을 수 있게 하되, 덮어도 되는 자리는 하나뿐이다:
# 탄창이 전부 표준인 다트통. 표준은 색이 하나뿐이라 덮어도 가릴 정보가 없다.
# 특별한 다트를 쥔 다트통에서 덮으면 그 다트가 무엇인지가 그림에서 사라진다 —
# cup_probe 가 그 짝을 검사한다(주석으로 부탁하지 않는다).
func _cup3_dart(id: String, tint: String, cup_tint: String) -> RigidBody3D:
	var dl: float = CUP3.dl
	var dr: float = CUP3.dr
	var col := _dart3_col(id)
	if tint != "":
		col = _cup3_tint(tint)
		# 통과 **같은 색일 때만** 한 단 밝힌다. 통 벽이 그 색을 0.44 어둡게
		# 쓰는데 자루가 원색이면 금빛 통 안의 금빛 자루가 한 덩어리로
		# 뭉갠다(찍어 보고 알았다) — 색이 같아도 값이 갈리면 형태가 산다.
		# 통이 다른 색이면 원색 그대로가 낫다. 밝히면 금이 바래 보인다.
		if tint == cup_tint:
			col = col.lightened(0.34)

	var b := RigidBody3D.new()
	b.mass = CUP3.mass
	b.gravity_scale = CUP3.grav
	b.linear_damp = CUP3.ldamp
	b.angular_damp = CUP3.adamp
	b.continuous_cd = true          # 벽이 빠르게 밀고 들어온다 — 터널링을 막는다
	var pm := PhysicsMaterial.new()
	pm.friction = CUP3.fric
	pm.bounce = CUP3.bounce
	b.physics_material_override = pm

	b.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	b.center_of_mass = Vector3(0.0, -dl * float(CUP3.com), 0.0)

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = dr
	cap.height = dl * 1.9
	cs.shape = cap
	b.add_child(cs)

	# 촉 · 배럴 · 샤프트 · 날개는 _dart3_meshes 가 세운다 — 판에 꽂힌
	# 다트와 같은 벌이다.
	_dart3_meshes(b, dl, dr, float(CUP3.fin), col)
	return b


# 통 한 벌을 세운다. x 는 월드 가로 자리(0 = 무대 한가운데).
func _cup3_spawn(pi: int, x: float) -> void:
	var packs := GameData.packs()
	if not _cup3_live() or pi < 0 or pi >= packs.size():
		return
	var row: Dictionary = packs[pi]
	var open: bool = _pack_open(pi)
	# 잠긴 다트통은 기준선 탄창을 세운다 — 수와 종류가 그림으로 새면 효과 줄을
	# 안 적어 둔 뜻이 없어진다.
	var id: String = String(row.get("dart_id", "std")) if open else "std"
	var n: int = _cup_dart_n(row) if open else GameData.tune_i("darts_base")

	var skin := _cup3_skin(pi)
	# 이 통의 안쪽 반지름. 넓은 통은 자루가 앉는 고리도 줄도 같이 넓어진다 —
	# 통마다 다르므로 rig 에 적어 두고 물리가 그것을 본다(_cup3_step_rig).
	var r: float = float(CUP3.r) * float(skin.wide)
	var cup := _cup3_cup(skin)
	cup.position = Vector3(x, 0.0, 0.0)
	cup_vp.add_child(cup)

	# 촉을 작은 고리 위에 **겹치지 않게** 흩어 놓고 꽁지를 바깥으로 벌린다.
	# 한 점에 모아 놓았더니 솔버가 겹침을 푸느라 첫 프레임에 통 밖으로
	# 터뜨렸다 — 물리는 겹친 채로 시작하는 것을 제일 싫어한다.
	var rt: float = float(CUP3.dr) * 2.6            # 촉이 앉는 고리
	var rc: float = r * 0.62                        # 꽁지가 벌어지는 고리
	var darts := []
	for i in n:
		var b := _cup3_dart(id, String(skin.dart), String(skin.tint))
		var a := TAU * float(i) / float(n) + 0.4
		var out := Vector3(sin(a), 0.0, cos(a))
		var tip := Vector3(x, 0.0, 0.0) + out * rt + Vector3(0.0, float(CUP3.wall) * 2.2, 0.0)
		var up := (Vector3(0.0, float(CUP3.dl) * 1.9, 0.0) + out * (rc - rt)).normalized()
		var side := up.cross(Vector3(0.0, 0.0, 1.0))
		if side.length() < 0.01:
			side = up.cross(Vector3(1.0, 0.0, 0.0))
		b.transform = Transform3D(Basis(side.normalized().cross(up), up,
				side.normalized()), tip + up * float(CUP3.dl))
		cup_vp.add_child(b)
		darts.append(b)
	# 발치의 골드. 잠긴 다트통에는 안 놓는다 — 무엇을 주는 다트통인지가 그림으로
	# 새면 효과 줄을 안 적어 둔 뜻이 없어진다(자루 수와 같은 규칙이다).
	var gold3 := []
	if open:
		var gn: int = int(skin.gold)
		for i in gn:
			var gb := _cup3_gold()
			# 통 좌우로 갈라 흩는다. 한쪽에 몰면 통이 기운 것으로 보인다.
			var sd := 1.0 if i % 2 == 0 else -1.0
			var t := float(i) / maxf(float(gn) - 1.0, 1.0)
			gb.position = Vector3(
					x + sd * r * float(GOLD3.spill) * (0.72 + t * 0.5),
					float(GOLD3.drop) + t * 0.16,
					lerpf(-r * 0.9, r * 0.9, fposmod(t * 2.37, 1.0)))
			# 떨어지며 도는 각. 다 같은 각으로 떨구면 카드 다발로 쌓인다.
			gb.rotation = Vector3(0.0, t * TAU * 0.83, 0.0)
			cup_vp.add_child(gb)
			gold3.append(gb)
	cup_rigs.append({"cup": cup, "darts": darts, "pi": pi, "r": r,
			"gold": gold3})


func _cup3_kill(rig: Dictionary) -> void:
	for b in rig.get("darts", []):
		if is_instance_valid(b):
			b.queue_free()
	for gb in rig.get("gold", []):
		if is_instance_valid(gb):
			gb.queue_free()
	if is_instance_valid(rig.cup):
		rig.cup.queue_free()
	cup_rigs.erase(rig)


func _cup3_open() -> void:
	if _cup3_live():
		return
	# 헤드리스에서는 아예 안 세운다. 빈 그림을 돌려받아 2D 받침이 서는 것은
	# 맞지만, 그 사이 3D 뷰포트와 강체가 렌더러 없이 서 있다가 간헐적으로
	# 죽는다 — 프로브가 번갈아 세그폴트하던 원인이 여기였다.
	# 열지 않으면 _cup3_live() 가 false 라 아래 길이 전부 2D 로 떨어진다.
	if not _has_renderer():
		return
	var st := _cup_stage()
	cup_vp = SubViewport.new()
	cup_vp.size = Vector2i(int(st.size.x), int(st.size.y))
	cup_vp.own_world_3d = true
	cup_vp.transparent_bg = true
	cup_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cup_vp.msaa_3d = Viewport.MSAA_DISABLED
	cup_vp.gui_disable_input = true
	add_child(cup_vp)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CUP3.size
	cam.near = 0.05
	cam.far = 40.0
	var pit: float = deg_to_rad(float(CUP3.pitch))
	cam.position = Vector3(0.0, _cup3_eye() - sin(pit) * float(CUP3.eye_z),
			cos(pit) * float(CUP3.eye_z))
	cam.rotation = Vector3(pit, 0.0, 0.0)
	cup_vp.add_child(cam)

	var lt := DirectionalLight3D.new()
	lt.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	lt.light_energy = 1.05
	lt.shadow_enabled = false
	cup_vp.add_child(lt)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = C_PANEL.lightened(0.55)
	env.ambient_light_energy = 1.15
	we.environment = env
	cup_vp.add_child(we)

	_cup3_spawn(newrun_pip, 0.0)


func _cup3_close() -> void:
	cup_rigs.clear()
	if _cup3_live():
		cup_vp.queue_free()
	cup_vp = null


# 넘기기 시작. 지금 통은 나가는 통이 되고, 새 통이 반대쪽에서 들어온다.
func _cup3_step(dir: int) -> void:
	if not _cup3_live():
		return
	# 미끄러지는 도중에 또 눌렀다면 나가던 통은 그 자리에서 지운다 —
	# 셋이 겹쳐 서면 어느 것이 지금 다트통인지가 화면에서 안 갈린다.
	while cup_rigs.size() > 1:
		_cup3_kill(cup_rigs[0])
	if not cup_rigs.is_empty() and is_instance_valid(cup_rigs[0].cup):
		cup_rigs[0].cup.position.x = 0.0
	_cup3_spawn(newrun_pip, float(dir) * _cup3_span())


# 통 한 벌 몫의 물리. **통만 옮긴다** — 자루를 같이 옮기면 통에 붙은
# 그림이 되고, 벽이 밀어 나르게 두어야 그것이 곧 관성이다.
#
# 강체 자리를 _process 에서 건드리면 물리 서버가 그 프레임에 덮어써서
# 아무 일도 안 일어난다. 처음에 그렇게 짰다가 자루가 통을 안 따라가고
# 허공에 굳어 남았다 — 강체를 만지는 자리는 _physics_process 하나다.
func _cup3_step_rig(rig: Dictionary, x: float, moving: bool, dt: float) -> void:
	if not is_instance_valid(rig.cup):
		return
	# 통이 이 걸음에 간 속도. 자루와 골드를 끌 때 이것을 맞춘다.
	var vx: float = (x - float(rig.get("px", x))) / maxf(dt, 0.0001)
	rig["px"] = x
	rig.cup.position.x = x
	var r: float = float(rig.get("r", CUP3.r))
	var lea: float = r * float(CUP3.leash)
	for b in rig.darts:
		if not is_instance_valid(b):
			continue
		# 잠든 강체는 벽이 물러나도 안 깬다 — 통이 빠져나가고 자루만
		# 허공에 서 있던 그림이 이것이었다. 미끄러지는 동안은 안 재운다.
		if moving:
			b.sleeping = false
			# 끌기 — 벽이 놓친 접촉을 힘으로 메운다. 가로 속도만 맞추므로
			# 자루는 여전히 뒤처지고 흔들린다(CUP3.drag 주석 참조).
			b.apply_central_force(Vector3(vx - b.linear_velocity.x, 0.0, 0.0)
					* float(CUP3.drag) * b.mass)
		var t: Transform3D = b.global_transform
		var tip: Vector3 = t.origin - t.basis.y * float(CUP3.dl)
		var off := Vector2(tip.x - x, tip.z)
		if off.length() > lea:
			var pull := Vector3(-off.x, 0.0, -off.y).normalized()
			b.apply_central_force(pull * float(CUP3.pull) * b.mass
					* minf(off.length() - lea, r))
		if tip.y > float(CUP3.h) * 0.85:
			b.apply_central_force(Vector3(0.0, -float(CUP3.lid) * b.mass, 0.0))
		# 꽁지 줄 — 촉과 같은 규약을 자루 반대끝에 건다. 아가리 반지름을
		# 넘어간 몫에만 걸리므로, 통 안에서 출렁이는 동안은 아무 일도 안 한다.
		var tail: Vector3 = t.origin + t.basis.y * float(CUP3.dl)
		var tof := Vector2(tail.x - x, tail.z)
		var fld: float = r * float(CUP3.fold)
		if tof.length() > fld:
			var back := Vector3(-tof.x, 0.0, -tof.y).normalized()
			b.apply_force(back * float(CUP3.tuck) * b.mass
					* minf(tof.length() - fld, r), tail - t.origin)
		# 세우는 토크 — 통 안에서 자루끼리 받쳐 주는 몫이다. 기울기의
		# sin 에 비례하므로 곧추설수록 저절로 잦아든다.
		b.apply_torque(t.basis.y.cross(Vector3.UP) * float(CUP3.stand) * b.mass)
		# 벽은 뚫리지 않는다.
		#
		# 줄(leash)은 **힘**이라 언제나 늦을 수 있다. 미끄러지는 동안 실제로
		# 늦었다 — 촉이 1.4×r 까지 나가 벽 밖에 섰고, 마지막 그물의 문턱
		# (1.8×r)에는 안 닿아서 그대로 남았다. 힘으로 당기기엔 이미 멀고
		# 그물로 잡기엔 가까운 죽은 구간이었다. 열에 한 번쯤 걸려서
		# "자꾸 삐져나온다" 로 보였다.
		#
		# 그래서 여기서는 자리를 옮긴다. 넘어간 만큼만 안으로 밀고 바깥으로
		# 가던 속도를 지운다 — 한 프레임에 옮기는 양이 얼마 안 되므로
		# 눈에는 벽을 타고 미끄러지는 것으로 보인다. 줄은 여기까지 오지
		# 않게 미리 당기는 몫이고, 이것은 못 막았을 때의 바닥이다.
		var ov := Vector2(tip.x - x, tip.z)
		if ov.length() > r:
			var back2 := ov.normalized() * (ov.length() - r)
			b.global_position -= Vector3(back2.x, 0.0, back2.y)
			var rad := Vector3(ov.x, 0.0, ov.y).normalized()
			var outv: float = b.linear_velocity.dot(rad)
			if outv > 0.0:
				b.linear_velocity -= rad * outv
		# 마지막 그물. 힘으로도 못 돌아온 자루는 통 한가운데에 도로 세운다 —
		# 물리는 언젠가 새고, 새면 자루가 화면 밖 허공에 남아 눈에 띈다.
		if off.length() > r * 1.8 or tip.y < -0.25 or tip.y > float(CUP3.h) * 2.0:
			b.linear_velocity = Vector3.ZERO
			b.angular_velocity = Vector3.ZERO
			b.transform = Transform3D(Basis(), Vector3(x, float(CUP3.dl) * 0.8, 0.0))

	# 발치의 골드. 자루와 같은 규약이다 — 통이 끌고 가고, 너무 멀어지면
	# 발치로 도로 부른다. 다른 것은 바닥이 통 몸에 붙어 있다는 것뿐이라
	# 가만히 두면 마찰이 알아서 데려간다. 끌기는 그 마찰이 놓치는 몫이다.
	for gb in rig.get("gold", []):
		if not is_instance_valid(gb):
			continue
		if moving:
			gb.sleeping = false
			gb.apply_central_force(Vector3(vx - gb.linear_velocity.x, 0.0, 0.0)
					* float(CUP3.drag) * gb.mass)
		var go := Vector2(gb.global_position.x - x, gb.global_position.z)
		if go.length() > r * float(GOLD3.keep) or gb.global_position.y < -0.4:
			# **있던 쪽으로** 도로 부른다. 오른쪽으로만 부르면 미끄러질 때마다
			# 왼쪽 것이 하나씩 오른쪽으로 넘어가, 몇 번 넘기면 골드가 통
			# 한쪽에 다 쌓인다(찍어 보고 알았다).
			var sd2 := -1.0 if go.x < 0.0 else 1.0
			gb.linear_velocity = Vector3.ZERO
			gb.angular_velocity = Vector3.ZERO
			gb.global_position = Vector3(x + sd2 * r * float(GOLD3.spill),
					float(GOLD3.drop), 0.0)


func _cup3_phys(dt: float) -> void:
	if not _cup3_live():
		return
	if cup_t >= 1.0:
		# 다 미끄러졌다. 나간 통을 지우고 남은 하나를 한가운데에 못 박는다.
		while cup_rigs.size() > 1:
			_cup3_kill(cup_rigs[0])
		if not cup_rigs.is_empty():
			_cup3_step_rig(cup_rigs[0], 0.0, false, dt)
		return
	var sl := _cup_slides()
	var ppu := _cup3_ppu()
	for i in mini(cup_rigs.size(), sl.size()):
		_cup3_step_rig(cup_rigs[i], float(sl[i].dx) / ppu, true, dt)


# 지금 화면에 선 통들과 그 가로 오프셋(px). **자리를 아는 곳은 여기 하나**다 —
# 3D 통(월드로 환산) · 2D 받침 · 소품이 전부 이 값을 본다. 갈라 두면
# 소품만 딴 데 서 있는 화면이 나온다.
func _cup_slides() -> Array:
	if cup_t >= 1.0:
		return [{"pi": newrun_pip, "dx": 0.0}]
	var s: float = -float(cup_dir) * float(CUP.span) * _cup_ease(cup_t)
	return [{"pi": cup_prev, "dx": s},
			{"pi": newrun_pip, "dx": s + float(cup_dir) * float(CUP.span)}]


func _cup_draw(pr: Rect2) -> void:
	var stage := _cup_stage()
	draw_rect(stage, C_PANEL.darkened(0.20))
	# 통 밑 그림자. 3D 쪽 그림자맵은 껐다 — 138x118 에서 그림자맵은 계단만
	# 남기고, 통이 놓인 자리를 말하는 데는 눌린 타원 하나면 된다.
	for sl in _cup_slides():
		draw_colored_polygon(_e_pts(Vector2(stage.get_center().x + float(sl.dx) + 2.0,
				_cup_foot() + 4.0), 24.0, 6.0, 18), Color(0.0, 0.0, 0.0, 0.28))
	var tex: Texture2D = cup_vp.get_texture() if _cup3_live() else null
	if tex != null:
		draw_texture_rect(tex, stage, false)
	else:
		for sl in _cup_slides():
			_cup_one(int(sl.pi), float(sl.dx))
	_cup_mask(stage, pr)
	draw_rect(stage, C_PANEL.darkened(0.42), false, 1.0)




func _pack_rect() -> Rect2:
	return Rect2(Vector2(76.0, 52.0), Vector2(488.0, 132.0))


func _pack_arrow(right: bool) -> Rect2:
	return Rect2(Vector2(574.0 if right else 40.0, 96.0), Vector2(26.0, 44.0))


func _league_rect(i: int) -> Rect2:
	return Rect2(Vector2(167.0 + float(i) * 39.0, 198.0), Vector2(33.0, 22.0))


func _newrun_go() -> Rect2:
	return Rect2(Vector2(236.0, 306.0), Vector2(168.0, 34.0))


func _newrun_back() -> Rect2:
	return Rect2(Vector2(44.0, 312.0), Vector2(88.0, 28.0))


# 다트통은 첫 행이 늘 열려 있고, 나머지는 해금 키를 읽는다.
func _pack_open(i: int) -> bool:
	var rows := GameData.packs()
	if i <= 0 or i >= rows.size():
		return i == 0
	return Save.unlocked("pack:" + String(rows[i].get("id", "")))


# 리그은 다트통마다 따로 뚫린다 — 첫 단은 늘 열려 있고 나머지는 앞 단 완주다.
func _league_open(i: int) -> bool:
	var rows := GameData.leagues()
	if i <= 0 or i >= rows.size():
		return i == 0
	return Save.unlocked(GameData.league_key(String(rows[i].get("id", ""))))


func _league_won(i: int) -> bool:
	var rows := GameData.leagues()
	if i < 0 or i >= rows.size():
		return false
	return Save.unlocked(GameData.win_key(String(rows[i].get("id", ""))))


# 다트통을 넘기면 리그을 그 다트통이 뚫은 만큼으로 내린다. 발라트로가 덱을 바꿀 때
# 하는 그 한 줄이고, 이게 있어야 "리그은 다트통마다 따로 뚫는다" 가 읽힌다.
func _pack_view(i: int) -> void:
	var rows := GameData.packs()
	if rows.is_empty():
		return
	newrun_pip = posmod(i, rows.size())
	GameData.pack = String(rows[newrun_pip].get("id", ""))
	Save.set_set("pack", GameData.pack)
	var top := 0
	for k in GameData.leagues().size():
		if _league_open(k):
			top = k
	if GameData.league_idx() > top:
		GameData.league = String(GameData.leagues()[top].get("id", ""))
		Save.set_set("league", GameData.league)
	Save.flush()


# 저장에 남은 다트통을 화면의 지금 자리로 맞춘 뒤 연다.
func _open_newrun() -> void:
	_pack_unlock_check()          # 지난 런에서 채운 조건이 여기서 열린다
	var rows := GameData.packs()
	newrun_pip = 0
	for i in rows.size():
		if String(rows[i].get("id", "")) == GameData.pack:
			newrun_pip = i
	_pack_view(newrun_pip)
	_cup_reset()
	_cup3_open()
	state = S.NEWRUN
	_sfx("newrun_open")


func _draw_newrun() -> void:
	_scrim()
	draw_string(font, Vector2(0, 32), "새 런", HORIZONTAL_ALIGNMENT_CENTER,
			VIEW.x, 18, C_TXT)

	var packs := GameData.packs()
	var many: bool = packs.size() > 1
	for right in [false, true]:
		var ar := _pack_arrow(right)
		draw_rect(ar, C_PANEL.lightened(0.10) if many else C_PANEL.darkened(0.2))
		draw_rect(Rect2(ar.position, Vector2(ar.size.x, 2.0)),
				C_ACC if many else C_DIM.darkened(0.5))
		draw_string(font, ar.position + Vector2(0.0, 28.0), "▶" if right else "◀",
				HORIZONTAL_ALIGNMENT_CENTER, ar.size.x, 12, C_TXT if many else C_DIM)

	# 다트통 패널 — 왼쪽에 통(다트통의 얼굴), 오른쪽에 이름과 값
	var pr := _pack_rect()
	draw_rect(pr, C_PANEL.lightened(0.10))
	var open: bool = _pack_open(newrun_pip)
	var row: Dictionary = packs[newrun_pip] if newrun_pip < packs.size() else {}
	# 통이 먼저다. 마스크가 판 바탕을 다시 깔므로 머리띠와 글은 그 뒤에 온다.
	_cup_draw(pr)
	draw_rect(Rect2(pr.position, Vector2(pr.size.x, 2.0)), C_ACC)
	# 잠긴 히든은 이름도 안 보인다 — 그게 히든이다. 기본은 "잠김" 으로
	# 무엇이 남았는지는 보인다(다음에 무엇이 열리는지가 완주의 값이다).
	var hid: bool = not open and GameData.pack_kind(row) == "hidden"
	draw_string(font, Vector2(230, 84),
			String(row.get("name", "")) if open else ("???" if hid else "잠김"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_TXT if open else C_DIM)
	# 다섯 줄까지 든다. 넷일 때는 아래가 비지만, 다트통마다 칸 높이가
	# 출렁이면 넘길 때 눈이 자리를 다시 잡아야 한다.
	var eb := Rect2(Vector2(230.0, 94.0), Vector2(310.0, 86.0))
	draw_rect(eb, C_PANEL.darkened(0.2))
	var lines := _pack_lines(row) if open else [_pack_cond(row)]
	for li in mini(lines.size(), 5):
		draw_string(font, Vector2(242, 112 + li * 15), lines[li],
				HORIZONTAL_ALIGNMENT_LEFT, eb.size.x - 24.0, 11,
				C_TXT if open else C_DIM)
	# 이 다트통으로 넘긴 가장 높은 리그 — 한 번도 못 넘겼으면 안 그린다
	var best := -1
	for k in GameData.leagues().size():
		if _league_won(k):
			best = k
	# 옛 자리(196,60)는 통 무대 한가운데였다 — 통 위에 색 조각이 떠 있었다.
	if best >= 0:
		draw_rect(Rect2(536.0, 62.0, 16.0, 11.0),
				Color(String(GameData.leagues()[best].get("color", "cfc9bd"))))
	if many:
		var pw: float = float(packs.size()) * 4.0 + float(packs.size() - 1) * 6.0
		for k in packs.size():
			draw_rect(Rect2(VIEW.x * 0.5 - pw * 0.5 + float(k) * 10.0, 190.0, 4.0, 4.0),
					C_TXT if k == newrun_pip else C_PANEL.lightened(0.06))

	# 리그 사다리 — 왼쪽이 약한 단이다. 가로로 눕혔으니 읽는 방향을 따른다.
	var st := GameData.leagues()
	var cur := GameData.league_row()
	for i in st.size():
		var r := _league_rect(i)
		var col := Color(String(st[i].get("color", "cfc9bd")))
		if _league_open(i):
			draw_rect(r, col)
			if _league_won(i):
				draw_rect(Rect2(r.position.x, r.end.y, r.size.x, 2.0), C_GOLD)
		else:
			# 못 여는 단은 좁은 토막으로 — 자리는 지키되 값은 안 보인다
			draw_rect(Rect2(r.position.x + 10.0, r.position.y, 13.0, r.size.y),
					C_PANEL.lightened(0.06))
			draw_rect(Rect2(r.position.x + 10.0, r.position.y, 13.0, r.size.y),
					C_WIRE.darkened(0.3), false, 1.0)
		if String(st[i].get("id", "")) == String(cur.get("id", "")):
			draw_rect(r.grow(2.0), C_TXT, false, 1.0)
	draw_string(font, Vector2(0, 238), String(cur.get("name", "")),
			HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 13,
			Color(String(cur.get("color", "cfc9bd"))))
	draw_rect(Rect2(Vector2(160.0, 242.0), Vector2(320.0, 61.0)),
			C_PANEL.darkened(0.2))
	var sl := _league_lines()
	for li in sl.size():
		draw_string(font, _league_line_at(li),
				sl[li], HORIZONTAL_ALIGNMENT_LEFT, 150.0, 10, C_TXT)

	_btn(_newrun_go(), "시작", "스페이스", open)
	_btn(_newrun_back(), "뒤로", "ESC", true)


# 다트통이 미는 값만 줄로 낸다 — 해설은 안 쓴다.
# 다트통 설명. 표의 줄글이 있으면 그것을 폭에 맞게 접어서 낸다 —
# "시작 골드 +10 · 사탕 칸 1" 은 두 번 읽어야 하고 "골드 14개로
# 시작한다. 사탕 칸은 1개다" 는 한 번 읽는다.
#
# 줄글이 없으면 아래처럼 **기준선과 다른 것만** 낸다. 그것이 없는
# 다트통(기준선 그대로)은 "기준" 한 줄이고, 그게 그 다트통의 정직한 설명이다.
# 줄글 없이 기준선과 다르기만 한 다트통은 검증기가 막는다.
#
# 넷을 늘 적던 때는 일당 다트통이 기본 다트통과 글자 하나 안 다르게 보였다 —
# 그 다트통의 전부인 "이자 없음 · 잔탄당 2골드" 가 어느 줄에도 없었기
# 때문이다. 표에 열이 늘 때마다 이 함수를 같이 늘려야 하는 구조였고,
# 늘리는 것을 잊으면 그 열은 화면에서 없는 것이 된다.
#
# 다른 것만 적으면 기준선(기본 다트통)은 "기준" 한 줄이 되는데, 그게
# 그 다트통의 정직한 설명이다 — 아무것도 안 주고 아무것도 안 뺀다.
func _pack_lines(row: Dictionary) -> Array:
	var out := []
	var d := GameData.pack_desc(row)
	if d != "":
		for w in _tip_wrap(d, 286.0, 11):
			out.append(w)
		return out
	var da := int(row.get("darts_add", 0))
	if da != 0:
		out.append("다트 %+d" % da)
	var ga := int(row.get("gold_add", 0))
	if ga != 0:
		out.append("시작 골드 %+d" % ga)
	var isl := int(row.get("item_slots", GameData.tune_i("max_items")))
	if isl != GameData.tune_i("max_items"):
		out.append("동전 칸 %d" % isl)
	var csl := int(row.get("cons_slots", GameData.tune_i("cons_slots")))
	if csl != GameData.tune_i("cons_slots"):
		out.append("사탕 칸 %d" % csl)
	if String(row.get("interest_off", "")) != "" \
			and int(row.get("interest_off", 0)) > 0:
		out.append("이자 없음")
	if String(row.get("dart_gold", "")) != "":
		var dg := int(row.get("dart_gold", 0))
		if dg != GameData.gold_per_dart():
			out.append("잔탄 1개당 %d골드" % dg)
	var did := String(row.get("dart_id", ""))
	if did != "" and did != "std":
		out.append("%s 다트로 시작" % GameData.dart_name(did))
	# 쥐여 주는 것들 — 이름으로 낸다. id 는 표의 말이지 사람의 말이 아니다.
	for gk in [["grant_item", "items"], ["grant_mod", "mods"],
			["grant_fixture", "fixtures"], ["grant_cons", "cons"]]:
		for gid in String(row.get(gk[0], "")).split(";", false):
			out.append("%s 들고 시작" % GameData.row_name(gk[1], String(gid)))
	if out.is_empty():
		out.append("기준")
	return out


# 잠긴 다트통에 적는 한 줄. 히든은 조건을 안 알려 준다 — 알려 주면 히든이 아니다.
func _pack_cond(row: Dictionary) -> String:
	if GameData.pack_kind(row) == "hidden":
		return "조건 미달"
	var pq := String(row.get("prereq", ""))
	if pq == "":
		return "완주로 열린다"
	# 이름으로 낸다. id 를 그대로 내면 "p_mag 완주" 가 화면에 뜬다.
	return "%s 완주" % GameData.row_name("packs", pq)


# 리그이 미는 값 — 1단부터 지금 단까지 쌓인 결과만 적는다.
# 줄 수는 단마다 다르다 — 흰 리그은 한 줄이고 검정 리그은 일곱 줄이다.
# 칸당 세 줄로 못 박아 두었더니 일곱째 줄이 오른쪽 칸 첫 줄 **위에** 겹쳐
# 찍혔다(검정 리그의 "유지비 3" 이 "다트 -1" 을 덮었다). 가장 긴 단에 맞춰
# 네 줄로 고정한다 — 단을 훑을 때 칸이 들썩이지 않는 편이 낫다.
const STAKE_ROWS := 4


# 리그 설명 한 줄이 앉는 자리. 그리기와 검사가 같은 식을 쓴다 — 글자
# 겹침은 눈으로만 보이는 사고라, 자리를 함수로 내놔야 프로브가 잴 수 있다.
func _league_line_at(li: int) -> Vector2:
	return Vector2(172.0 + (0.0 if li < STAKE_ROWS else 158.0),
			258.0 + float(li % STAKE_ROWS) * 13.0)


func _league_lines() -> Array:
	var out := []
	var r := GameData.league_row()
	if String(r.get("curve", "base")) != "base":
		# 열 이름(curve_a)은 표의 말이지 사람의 말이 아니다. 곱이 판마다
		# 다르므로 첫 판과 마지막 판의 값을 범위로 적는다.
		var lo := GameData.league_mul(1)
		var hi := GameData.league_mul(GameData.legs_n())
		out.append("목표 ×%.2f~%.2f" % [lo, hi] if hi > lo else "목표 ×%.2f" % hi)
	if String(r.get("reward_small", "")) != "" \
			and int(GameData.league_v("reward_small", 3.0)) < 3:
		out.append("작은 판 보상 %d" % int(GameData.league_v("reward_small", 3.0)))
	if int(GameData.league_v("seal_items", 0.0)) > 0:
		out.append("봉인 %d" % int(GameData.league_v("seal_items", 0.0)))
	if int(GameData.league_v("darts_add", 0.0)) != 0:
		out.append("다트 %+d" % int(GameData.league_v("darts_add", 0.0)))
	if GameData.league_v("shop_cost_mul", 1.0) != 1.0:
		out.append("테이블 ×%.2f" % GameData.league_v("shop_cost_mul", 1.0))
	if int(GameData.league_v("perish", 0.0)) > 0:
		out.append("삭음 %d판" % int(GameData.league_v("perish", 0.0)))
	if int(GameData.league_v("rent", 0.0)) > 0:
		out.append("유지비 %d" % int(GameData.league_v("rent", 0.0)))
	if out.is_empty():
		out.append("기준")
	return out


# 설정의 행 — 판 중에 열었을 때만 "로비로 나가기" 가 낀다.
# 제목에서 연 설정에는 로비 행이 무의미하다 — 이미 로비다.
func _set_rows() -> Array:
	if pause_from >= 0:
		return ["back", "fs", "vol", "mus", "lobby", "quit"]
	return ["back", "fs", "vol", "mus", "quit"]


func _set_rect(i: int) -> Rect2:
	return Rect2(Vector2(226.0, 132.0 + float(i) * 40.0), Vector2(188.0, 32.0))


# 게이지의 홈 — 행 안에서 소리 글자 오른쪽부터 끝까지다.
# 게이지 한 칸을 커서 자리로 민다. 누를 때와 끌 때가 같은 문을 쓴다.
#
# 끊는 단위는 0.01 이다 — 예전 0.05 는 스무 칸이라 끄는 동안 계단이 손에
# 그대로 느껴졌다. 백 칸이면 게이지 폭(114px)보다 촘촘해 눈에는 이어져
# 보이고, 그래도 끊어 두는 것은 소수점이 저장에 그대로 들어가지 않게 하려는
# 것이다.
func _set_slide(i: int, m: Vector2) -> void:
	var rows := _set_rows()
	if i < 0 or i >= rows.size():
		return
	var key := String(rows[i])
	var tr := _vol_track(_set_rect(i))
	var x := snappedf(clampf((m.x - tr.position.x) / tr.size.x, 0.0, 1.0), 0.01)
	if key == "vol":
		vol = x
	elif key == "mus":
		vol_mus = x
	else:
		return
	_apply_vol()


func _set_slide_end() -> void:
	var rows := _set_rows()
	if set_drag >= 0 and set_drag < rows.size():
		var key := String(rows[set_drag])
		if key == "vol":
			Save.set_set("vol", vol)
		elif key == "mus":
			Save.set_set("vol_mus", vol_mus)
	set_drag = -1


# 게이지 한 줄. 효과음과 음악이 같은 그림을 쓴다 — 둘이 다르게 생기면
# 같은 종류의 손잡이로 안 읽힌다.
func _vol_row(r: Rect2, i: int, label: String, v: float) -> void:
	var hot: bool = set_drag == i
	draw_rect(r, C_PANEL.lightened(0.16 if hot else 0.10))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), C_ACC)
	draw_string(font, r.position + Vector2(10, 20), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TXT)
	var tr := _vol_track(r)
	draw_rect(tr, C_PANEL.darkened(0.45))
	if v > 0.0:
		draw_rect(Rect2(tr.position, Vector2(tr.size.x * v, tr.size.y)),
				C_GOLD.darkened(0.0 if hot else 0.15))
	# 손잡이 — 끄는 동안 굵어진다. 잡고 있다는 것을 눈으로도 안다.
	var kx: float = tr.position.x + tr.size.x * v
	var kw: float = 5.0 if hot else 3.0
	draw_rect(Rect2(kx - kw * 0.5, tr.position.y - 4.0, kw, 14.0), C_TXT)
	# 수를 같이 쓴다. 게이지만 있으면 지금 몇인지를 눈대중해야 한다.
	draw_string(font, Vector2(r.end.x - 32.0, r.position.y + 20.0),
			"%d" % int(round(v * 100.0)), HORIZONTAL_ALIGNMENT_RIGHT, 26.0, 10,
			C_TXT if hot else C_DIM)


func _vol_track(r: Rect2) -> Rect2:
	return Rect2(r.position + Vector2(58.0, 13.0), Vector2(r.size.x - 74.0, 6.0))


# ══════════════════════════════════════════════════════════
#  음악
#
#  네 곡이 화면을 따라 갈린다. 갈아 끼울 때 뚝 끊지 않고 겹쳐 넘긴다 —
#  플레이어가 둘인 이유가 그것 하나다. 한쪽이 잦아드는 동안 다른 쪽이
#  올라오고, 다 넘어가면 잦아든 쪽이 멈춘다.
#
#  화면과 곡의 대응은 _mus_want 한 곳에만 있다. 상태가 늘면 거기만 고친다.
const MUS := {
	"lobby":  "res://assets/music/lobby.mp3",   # 로비 — 타이틀·설정·컬렉션
	"select": "res://assets/music/select.mp3",  # 고르는 자리 — 판 선택·상점·정산
	"game":   "res://assets/music/game.mp3",    # 판 위 — 작은 판·큰 판
	"boss":   "res://assets/music/boss.mp3",    # 판 위 — 보스 판
}
#  음악의 기준 크기. 낮출 이유가 없어졌다 — 깔개를 효과음보다 낮게 두는
#  일은 이제 버스가 따로 맡고(사용자가 직접 정한다), 곡 자체가 조용해서
#  여기서 더 깎으면 안 들린다. 0 으로 두고 큰 조절은 컴프레서가 한다.
const MUS_DB := 0.0

const MUS_FADE := 1.4     # 겹쳐 넘기는 시간(초)

var mus_pl := []          # AudioStreamPlayer 둘
var mus_i := 0            # 지금 소리 내는 쪽
var mus_key := ""         # 그쪽이 물고 있는 곡
var mus_x := 1.0          # 넘김 진행도 0~1. 1 이면 넘김이 끝난 상태다
var mus_warned := {}      # 못 읽은 곡을 한 번만 말하려고 기억한다


# 지금 화면이 원하는 곡. 덮개 화면은 **뒤 화면을 따른다** — 잠깐 여는 판
# 때문에 곡이 바뀌면 그게 더 눈에 띈다(런 정보·일시정지가 그 자리다).
func _mus_want() -> String:
	var st := state
	if st == S.RUNINFO:
		st = run_from
	elif st == S.SETTINGS and pause_from >= 0:
		st = pause_from
	match st:
		S.TITLE, S.SETTINGS, S.COLLECT, S.NEWRUN, S.OVER:
			return "lobby"
		S.STAGE, S.SHOP, S.LEG, S.CLEAR:
			return "select"
	return "boss" if GameData.is_boss(leg_no) else "game"


func _mus_update(d: float) -> void:
	if mus_pl.size() < 2:
		return
	var want := _mus_want()
	if want != mus_key:
		_mus_to(want)
	# 넘기는 중이면 두 쪽을 반대로 민다. 다 넘어가면 뒤쪽을 멈춘다 —
	# 안 멈추면 곡 넷이 전부 돌면서 CPU 와 배를 같이 먹는다.
	if mus_x < 1.0:
		mus_x = minf(mus_x + d / MUS_FADE, 1.0)
		var cur: AudioStreamPlayer = mus_pl[mus_i]
		var old: AudioStreamPlayer = mus_pl[1 - mus_i]
		cur.volume_db = _mus_db(mus_x)
		old.volume_db = _mus_db(1.0 - mus_x)
		if mus_x >= 1.0 and old.playing:
			old.stop()


# 진행도를 데시벨로. 선형으로 섞으면 가운데가 파인다(두 소리의 에너지가
# 합이 아니라 제곱합이라서) — 제곱근을 취해 힘을 일정하게 잡는다.
func _mus_db(x: float) -> float:
	if x <= 0.001:
		return -80.0
	return MUS_DB + linear_to_db(sqrt(clampf(x, 0.0, 1.0)))


func _mus_to(key: String) -> void:
	# 자리가 아직 안 섰다(_ready 전). 프로브가 첫 프레임 앞에서 부르는
	# 경로가 있으므로 여기서 막는다 — 곡을 기억도 하지 않는다. 자리가
	# 서고 나면 _mus_update 가 want 와 다름을 보고 다시 부른다.
	if mus_pl.size() < 2 or not MUS.has(key):
		return
	var st: AudioStream = load(String(MUS[key]))
	if st == null:
		# 조용히 넘어가면 원인을 못 찾는다. 편집기가 새 파일을 아직 안
		# 읽었을 때 이 자리가 무음의 유일한 출구다 — 한 번은 말하게 한다.
		if not mus_warned.has(key):
			mus_warned[key] = true
			push_warning("음악을 못 읽었다: %s — 임포트가 안 됐을 수 있다" % MUS[key])
		return
	# mp3 는 임포트 설정이 아니라 자원의 값으로 순환한다. 코드에서 물려야
	# 어떤 임포트 상태에서도 끊기지 않는다.
	if st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true
	mus_key = key
	mus_i = 1 - mus_i
	mus_x = 0.0
	var cur: AudioStreamPlayer = mus_pl[mus_i]
	cur.stream = st
	cur.volume_db = -80.0
	cur.play()


# 버스 셋을 세운다 — Master 아래에 효과음·음악. 한 번만 만들고, 이름으로
# 찾으므로 두 번 불러도 안 늘어난다.
func _bus_setup() -> void:
	for nm in ["SFX", "Music"]:
		if AudioServer.get_bus_index(nm) >= 0:
			continue
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, nm)
		AudioServer.set_bus_send(i, "Master")



func _apply_vol() -> void:
	# Master 는 안 건드린다 — 예전에는 여기를 줄였는데, 그러면 둘을 가른
	# 뜻이 없다. 각자의 버스만 만진다.
	var si := AudioServer.get_bus_index("SFX")
	var mi := AudioServer.get_bus_index("Music")
	if si >= 0:
		AudioServer.set_bus_volume_db(si, linear_to_db(maxf(vol, 0.0001)))
		AudioServer.set_bus_mute(si, vol <= 0.001)
	if mi >= 0:
		AudioServer.set_bus_volume_db(mi, linear_to_db(maxf(vol_mus, 0.0001)))
		AudioServer.set_bus_mute(mi, vol_mus <= 0.001)


func _draw_settings() -> void:
	_scrim()
	draw_string(font, Vector2(0, 96), "설정", HORIZONTAL_ALIGNMENT_CENTER,
			VIEW.x, 24, C_TXT)
	var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	var rows := _set_rows()
	for i in rows.size():
		var r := _set_rect(i)
		match rows[i]:
			"fs":
				_btn(r, "전체화면  %s" % ("켬" if fs else "끔"), "F11", true)
			"vol", "mus":
				var sfx: bool = String(rows[i]) == "vol"
				_vol_row(r, i, "효과음" if sfx else "음악", vol if sfx else vol_mus)
			"lobby":
				_btn(r, "로비로 나가기", "", true)
			"quit":
				_btn(r, "게임 나가기", "", true)
			"back":
				# 판 중이면 "계속하기" 다 — 돌아가는 곳이 판이니까.
				_btn(r, "계속하기" if pause_from >= 0 else "뒤로", "ESC", true)


# 설정을 닫는다 — 판 중에 열었으면 그 자리로, 아니면 제목으로.
func _settings_back() -> void:
	state = pause_from if pause_from >= 0 else S.TITLE
	pause_from = -1


# ── 컬렉션 — 게임에 실린 전부를 편다. 해금이 없으므로 도감이 곧 전량이다 ──

const COL_PAGE := 28        # 7 × 4 — 한 쪽에 얹는 수
var collect_page := 0


func _col_total() -> int:
	match collect_tab:
		0: return GameData.items().size()
		1: return GameData.mods().size()
		2: return GameData.darts().size()
		3: return GameData.consumables().size()
		4: return GameData.fixtures().size()
	return GameData.modifiers().size()


# 이번 쪽에 실제로 놓인 수. 칸 인덱스는 쪽 안에서 0부터다.
func _col_count() -> int:
	return clampi(_col_total() - collect_page * COL_PAGE, 0, COL_PAGE)


func _col_pages() -> int:
	return maxi(1, int(ceil(float(_col_total()) / float(COL_PAGE))))


func _col_tab_rect(t: int) -> Rect2:
	# 여섯 칸을 화면 안에 고르게 편다. 다섯일 때 쓰던 102px 고정 간격은
	# 여섯째가 화면(640) 밖으로 나간다 — 폭에서 나눠 쓴다.
	var n := float(COL_TABS.size())
	var w: float = (VIEW.x - 44.0) / n
	return Rect2(Vector2(22.0 + w * float(t), 42.0), Vector2(w - 6.0, 24.0))


func _col_arrow_rect(right: bool) -> Rect2:
	return Rect2(Vector2(560.0 if right else 44.0, 322.0), Vector2(36.0, 30.0))


func _col_cell(i: int) -> Rect2:
	var cols := 7
	var cw := 86.0
	var ch := 58.0
	var x0 := (VIEW.x - cw * float(cols)) * 0.5
	return Rect2(Vector2(x0 + float(i % cols) * cw, 72.0 + float(i / cols) * ch),
			Vector2(cw, ch))


# ══════════════════════════════════════════════════════════
#  런 정보
#
#  런 안에서 지금 무엇을 들고 있는지 묻는 자리. 만든 이유는 **사진**이다 —
#  사면 사라지고 효과만 남는 물건이라 산 뒤에는 어디서도 안 보였다.
#
#  한 화면에 다 늘어놓았더니 여섯 구획이 한꺼번에 밀려들어 읽히지 않았다.
#  탭으로 가른다 — 컬렉션 화면이 이미 쓰는 어법이고, 한 번에 한 가지만
#  본다. 전체 화면이 아니라 판 위에 뜨는 판이다: 열어도 뒤의 게임이
#  남아 있어야 "잠깐 확인하고 닫는다" 로 읽힌다.
const RI_TABS := ["진행", "트랙", "사진", "보유"]

var runinfo_tab := 0


func _ri_panel() -> Rect2:
	# 트랙 탭이 가장 길다 — 머리 22 + 여섯 줄 x15 = 112. 거기에 탭줄(34)과
	# 뒤로 버튼(34)과 여백을 더한 값이 이 높이다. 더 키우면 아래가 비고,
	# 줄이면 트랙이 잘린다.
	var h := 214.0
	return Rect2(Vector2(74.0, (VIEW.y - h) * 0.5), Vector2(VIEW.x - 148.0, h))


func _ri_tab_rect(t: int) -> Rect2:
	var p := _ri_panel()
	var w: float = (p.size.x - 24.0) / float(RI_TABS.size())
	return Rect2(p.position.x + 12.0 + w * float(t), p.position.y + 8.0,
			w - 4.0, 18.0)


func _runinfo_back_rect() -> Rect2:
	# 힌트 글자가 버튼 아래에 붙으므로(_btn) 판 안에 들어오게 띄운다.
	var p := _ri_panel()
	return Rect2(p.position.x + 12.0, p.position.y + p.size.y - 38.0,
			p.size.x - 24.0, 17.0)


# 런 정보를 열 수 있는가. 런 밖(타이틀·컬렉션·설정·새 런)에는 볼 런이
# 없고, 연출 중에는 입력을 안 받는다 — _can_rack_move 가 그 둘을 이미
# 정확히 가르므로 같은 판정을 쓴다. 정산 화면(CLEAR)은 그 자체가 명세라
# 덮을 이유가 없다.
# 트랙 ID 를 사람이 읽는 이름으로. areas.csv 가 이미 이름을 들고 있다 —
# 불은 아우터·이너가 트랙을 나눠 쓰므로 먼저 만나는 이름으로 답한다.
func _track_name(tk: int) -> String:
	for a in GameData.areas_all():
		if int(a.get("track", 0)) == tk:
			return String(a.get("n", "?"))
	return "트랙"


func _runinfo_ok() -> bool:
	return _can_rack_move() or state == S.CLEAR


func _draw_runinfo() -> void:
	# 뒤를 통째로 가리지 않는다. 게임이 비쳐야 "잠깐 여는 판" 이다.
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.0, 0.0, 0.0, 0.55))
	var p := _ri_panel()
	draw_rect(Rect2(p.position + Vector2(2.0, 3.0), p.size), Color(0.0, 0.0, 0.0, 0.4))
	draw_rect(p, C_PANEL.darkened(0.10))
	draw_rect(p, C_WIRE.darkened(0.25), false, 1.0)

	for t in RI_TABS.size():
		_btn(_ri_tab_rect(t), RI_TABS[t], "", t == runinfo_tab)
	# 고른 탭을 가리키는 삼각형 — 발라트로가 쓰는 신호다. 버튼 강조만으로는
	# 넷이 같은 빨강이라 어느 것이 켜졌는지 한눈에 안 온다.
	var tr := _ri_tab_rect(runinfo_tab)
	var tx: float = tr.get_center().x
	draw_colored_polygon(PackedVector2Array([
			Vector2(tx - 4.0, tr.position.y - 6.0), Vector2(tx + 4.0, tr.position.y - 6.0),
			Vector2(tx, tr.position.y - 1.0)]), C_ACC)

	match runinfo_tab:
		0: _ri_progress(p)
		1: _ri_tracks(p)
		2: _ri_photos(p)
		3: _ri_carry(p)

	_btn(_runinfo_back_rect(), "뒤로", "탭", false)


# 한 구획을 세운다. 제목 한 줄 · 밑줄 · 그 아래 줄들. 넷이 같이 쓴다.
func _ri_block(x: float, y: float, w: float, head: String, rows: Array) -> float:
	draw_string(font, Vector2(x, y + 9.0), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_ACC)
	draw_rect(Rect2(x, y + 13.0, w, 1.0), Color(C_WIRE.darkened(0.3), 0.5))
	y += 26.0
	for ln in rows:
		draw_string(font, Vector2(x + 4.0, y), String(ln),
				HORIZONTAL_ALIGNMENT_LEFT, w - 8.0, 10, C_TXT)
		y += 14.0
	return y + 10.0


func _ri_progress(p: Rect2) -> void:
	var rd: int = GameData.round_of(leg_no)
	@warning_ignore("integer_division")  # 상단바와 같은 식이어야 한다
	var itr: int = mini(gold / GameData.interest_per(), _interest_cap())
	var cw: float = (p.size.x - 40.0) * 0.5
	var y0: float = p.position.y + 36.0
	_ri_block(p.position.x + 16.0, y0, cw, "진행", [
		"라운드  %d / %d" % [rd, GameData.rounds_n()],
		"판  %d / %d" % [leg_no, GameData.legs_n()],
		"목표  %d" % target,
		"지금  %d" % total,
	])
	_ri_block(p.position.x + 24.0 + cw, y0, cw, "경제", [
		"골드  %d" % gold,
		"이자  +%d" % itr,
		"리롤  %d" % reroll_cost,
	])


# 발라트로의 포커 핸드 표와 같은 자리다 — 레벨 · 이름 · 점수 x 배수 ·
# 이 런에서 맞힌 횟수. 트랙이 0 인 영역(보드 아웃)은 강화를 못 받으므로
# 레벨 칸을 비운다.
func _ri_tracks(p: Rect2) -> void:
	var x: float = p.position.x + 16.0
	var w: float = p.size.x - 32.0
	var y: float = p.position.y + 36.0
	draw_string(font, Vector2(x + 4.0, y + 9.0), "레벨", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 9, C_DIM)
	draw_string(font, Vector2(x + 46.0, y + 9.0), "트랙", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 9, C_DIM)
	draw_string(font, Vector2(x + w - 96.0, y + 9.0), "점수 x 배수",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, C_DIM)
	draw_string(font, Vector2(x + w - 24.0, y + 9.0), "맞힘", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 9, C_DIM)
	draw_rect(Rect2(x, y + 13.0, w, 1.0), Color(C_WIRE.darkened(0.3), 0.5))
	y += 22.0

	for a in GameData.areas_all():
		var tk: int = int(a.get("track", 0))
		# track_lv 는 **강화 횟수**다 — 0 이 "아직 안 올렸다" 이고 점수 쪽도
		# 그 규약으로 읽는다(tlv > 0 일 때만 보너스를 더한다). 기본값을 1 로
		# 읽었더니 두 가지가 한꺼번에 틀렸다: 안 올렸는데 1레벨 보너스가
		# 붙어 보였고, 한 번 올려도 화면의 수가 안 바뀌었다.
		var lv: int = int(track_lv.get(tk, 0))
		var n: int = int(track_hits.get(tk, 0))
		var b := GameData.track_bonus(tk, lv) if tk != 0 else {"s": 0, "m": 0}
		var sc: int = int(a.get("base", 0)) + int(b.s)
		var ml: int = int(a.get("mult", 1)) + int(b.m)

		# 화면에는 lv+1 로 쓴다 — 안 올린 트랙이 Lv.1 로 읽히는 편이 익숙하다.
		draw_string(font, Vector2(x + 4.0, y + 8.0),
				("Lv.%d" % (lv + 1)) if tk != 0 else "—", HORIZONTAL_ALIGNMENT_LEFT,
				-1, 10, C_GREEN.lightened(0.2) if lv > 0 else C_DIM)
		draw_string(font, Vector2(x + 46.0, y + 8.0), String(a.get("n", "?")),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_TXT)
		# 점수는 판 숫자를 곱하는 자리라 표에 값이 없는 트랙이 있다(싱글).
		# 그때는 수를 꾸며 내지 않고 "판 숫자" 라고 말한다.
		var sct := ("판 숫자" if sc == 0 else str(sc))
		draw_string(font, Vector2(x + w - 96.0, y + 8.0), sct,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_CHIP.lightened(0.3))
		draw_string(font, Vector2(x + w - 46.0, y + 8.0), "x%d" % ml,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_MULT.lightened(0.25))
		draw_string(font, Vector2(x + w - 24.0, y + 8.0), str(n),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				C_GOLD if n > 0 else C_DIM.darkened(0.2))
		y += 15.0


# 발라트로의 바우처 탭과 같은 자리. 효과 한 줄까지 같이 세운다 — 이름만
# 있으면 왜 산 것인지 다시 알 수 없다.
func _ri_photos(p: Rect2) -> void:
	var x: float = p.position.x + 16.0
	var w: float = p.size.x - 32.0
	var y: float = p.position.y + 36.0
	var own := []
	for f in GameData.fixtures():
		if GameData.fixtures_own.has(String(f.id)):
			own.append(f)
	draw_string(font, Vector2(x, y + 9.0), "이번 런에서 산 사진 %d" % own.size(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_ACC)
	draw_rect(Rect2(x, y + 13.0, w, 1.0), Color(C_WIRE.darkened(0.3), 0.5))
	y += 24.0
	if own.is_empty():
		draw_string(font, Vector2(x + 4.0, y + 8.0), "아직 없다",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_DIM)
		return
	for f in own:
		draw_string(font, Vector2(x + 4.0, y + 8.0), String(f.n),
				HORIZONTAL_ALIGNMENT_LEFT, 110.0, 10, C_TXT)
		draw_string(font, Vector2(x + 120.0, y + 8.0), String(f.d),
				HORIZONTAL_ALIGNMENT_LEFT, w - 124.0, 10, C_DIM)
		y += 15.0


func _ri_carry(p: Rect2) -> void:
	var mag := {}
	for d in magazine:
		var nm := String(d.get("n", d.get("id", "?")))
		mag[nm] = int(mag.get(nm, 0)) + 1
	var mag_rows := []
	for nm in mag:
		mag_rows.append("%s x%d" % [nm, mag[nm]])

	var mod_rows := []
	for m in GameData.mods():
		if mods_own.has(String(m.id)):
			mod_rows.append(String(m.n))

	var cw: float = (p.size.x - 40.0) * 0.5
	var y0: float = p.position.y + 36.0
	var xl: float = p.position.x + 16.0
	var xr: float = p.position.x + 24.0 + cw
	var y := _ri_block(xl, y0, cw, "칸", [
		"동전  %d / %d" % [owned.size(), GameData.max_items()],
		"사탕  %d / %d" % [cons.size(), GameData.cons_slots()],
	])
	_ri_block(xl, y, cw, "다트통", mag_rows if not mag_rows.is_empty() else ["없음"])
	_ri_block(xr, y0, cw, "판", mod_rows if not mod_rows.is_empty() else ["기본"])


# 컬렉션 탭. 사진이 빠져 있었다 — 산 뒤에 런 정보에서만 보이고 도감에는
# 아예 없었다. 표가 있으면 도감에도 있어야 한다.
#
# 이름과 툴팁 열쇠를 **한 줄에 같이** 둔다. 전에는 두 곳이 각자 순서를
# 적고 있었고, 사진 탭을 넷째에 끼워 넣자 툴팁 배열만 다섯 칸으로 남아
# 사진이 제약 설명을 집었다. 한 곳에서 나오면 그런 어긋남이 안 생긴다.
const COL_TABS := [
	{"n": "동전", "k": "citem"},
	{"n": "보드 확장", "k": "cmod"},
	{"n": "다트", "k": "cdart"},
	{"n": "사탕", "k": "ccons"},
	{"n": "사진", "k": "cfix"},
	{"n": "제약", "k": "cmodf"},
]


func _draw_collect() -> void:
	_scrim()
	draw_string(font, Vector2(0, 30), "컬렉션", HORIZONTAL_ALIGNMENT_CENTER,
			VIEW.x, 18, C_TXT)
	# 이름은 COL_TABS 가, 개수는 표가 낸다 — 이름을 여기서 또 적으면
	# 탭이 늘 때 순서가 또 어긋난다.
	var cnt := [GameData.items().size(), GameData.mods().size(),
			GameData.darts().size(), GameData.consumables().size(),
			GameData.fixtures().size(), GameData.modifiers().size()]
	for t in COL_TABS.size():
		_btn(_col_tab_rect(t), "%s %d" % [COL_TABS[t].n, cnt[t]], "",
			t == collect_tab)

	var base := collect_page * COL_PAGE
	for i in _col_count():
		var cell := _col_cell(i)
		var c := cell.get_center() + Vector2(0.0, -8.0)
		var gi := base + i
		var nm := ""
		match collect_tab:
			0:
				var it: Dictionary = GameData.items()[gi]
				draw_item_sticker(c, 13.0, it, 0.0, 0.0, 0.0, 9)
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
				# 테이블에 뜨는 그림 그대로 쓴다 — 두 글자 상자였을 때는
				# 컬렉션의 사탕과 판 위의 사탕이 다른 물건으로 보였다.
				var cs: Array = GameData.consumables()
				_icon_cons(c, 11.0, String(cs[gi].id))
				nm = cs[gi].n
			4:
				var fx: Dictionary = GameData.fixtures()[gi]
				_fix_flat(c, {}, 0.0, 0.0)
				nm = fx.n
			5:
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
			hint = _aim_hint(0)
		S.AIM_H:
			hint = _aim_hint(1)
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
