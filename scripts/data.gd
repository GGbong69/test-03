extends RefCounted

# ══════════════════════════════════════════════════════════
#  밸런스 데이터 — 수치 조정은 전부 이 파일에서만 한다.
#  game.gd 는 이 표를 읽어 동작만 수행한다.
# ══════════════════════════════════════════════════════════

# ── 런 구조 ────────────────────────────────────────────────
const ROUNDS := 8
const DARTS_BASE := 6

# 조준 범위가 보드보다 넓어 약 37%는 빗나간다.
# 무개조 기준 실제 기대값은 다트당 약 10점 → 6다트에 약 60점.
# R1은 아이템 없이도 여유 있게 넘도록 45로 두고, 이후 약 1.75배씩 상승.
const TARGETS := [45, 85, 150, 270, 470, 820, 1450, 2500]

# ── 보드 기하 기본값 ──────────────────────────────────────
#  판의 출처는 여기 하나다. game.gd 의 _new_run 은 리터럴을 쓰지 않는다.
const SECTORS_BASE := [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]
const BOARD_BASE := {
	"bi": 0.06, "bo": 0.14,      # 한복판(50) · 불(25)
	"ti": 0.56, "to": 0.66,      # 트리플 띠
	"t2i": 0.0, "t2o": 0.0,      # 둘째 트리플 띠. 0 이면 없다 — hit_info 의 가지가 통째로 안 돈다
	"din": 0.90, "dout": 1.00,   # 더블 띠 안쪽 · 판의 끝(= 빗나감 경계)
}

# ── 경제 ──────────────────────────────────────────────────
const CLEAR_GOLD := 4          # 클리어 기본 보상
const GOLD_PER_DART := 1       # 남은 다트 1개당 (적은 다트로 끝낼 유인)
const INTEREST_PER := 5        # 보유 골드 N당 이자 1 (저축 유인)
const INTEREST_MAX := 5
const FREE_REROLLS := 1        # 상점 방문마다 무료 리롤 (없으면 초반에 못 씀)
const REROLL_BASE := 2
const REROLL_STEP := 1         # 리롤할 때마다 누적 상승
const MAX_ITEMS := 5
const SHOP_ITEMS := 2
const SHOP_MODS := 1

# ── 아이템 ────────────────────────────────────────────────
#  c = 발동 조건, k = 효과 종류, v = 수치
#  k: chip 점수 가산 / mult 배수 가산 / xmult 배수 곱 / mult_streak 연속수 비례
const ITEMS := [
	# 흔함 4골드 — 조건이 넓고 효과가 작다
	{"id": "trp", "n": "삼중고", "c": "triple", "k": "mult", "v": 4, "cost": 4},
	{"id": "dbl", "n": "가장자리", "c": "double", "k": "mult", "v": 3, "cost": 4},
	{"id": "odd", "n": "홀수 애호", "c": "odd", "k": "chip", "v": 14, "cost": 4},
	{"id": "evn", "n": "짝수 애호", "c": "even", "k": "chip", "v": 14, "cost": 4},
	{"id": "lft", "n": "좌익수", "c": "left", "k": "mult", "v": 2, "cost": 4},
	{"id": "rgt", "n": "우익수", "c": "right", "k": "mult", "v": 2, "cost": 4},
	{"id": "big", "n": "대물", "c": "big", "k": "chip", "v": 16, "cost": 4},
	{"id": "sml", "n": "소물", "c": "small", "k": "mult", "v": 5, "cost": 4},

	# 보통 7골드 — 조건이 좁은 대신 효과가 크다
	{"id": "sam", "n": "외골수", "c": "same", "k": "mult", "v": 4, "cost": 7},
	{"id": "dif", "n": "변덕쟁이", "c": "diff", "k": "chip", "v": 22, "cost": 7},
	{"id": "bul", "n": "명중왕", "c": "bull", "k": "mult", "v": 8, "cost": 7},
	{"id": "fst", "n": "첫 발", "c": "first", "k": "chip", "v": 45, "cost": 7},
	{"id": "lst", "n": "막판", "c": "last", "k": "xmult", "v": 2, "cost": 7},
	{"id": "mis", "n": "빈손", "c": "miss", "k": "chip", "v": 30, "cost": 7},

	# 희귀 — 빌드의 축이 되는 물건
	{"id": "str", "n": "정밀", "c": "streak", "k": "mult_streak", "v": 3, "cost": 11},
	{"id": "alc", "n": "기본기", "c": "always", "k": "chip", "v": 25, "cost": 11},
	{"id": "alm", "n": "증폭기", "c": "always", "k": "xmult", "v": 2, "cost": 14},

	# ── 골드 칩 ──────────────────────────────────────────
	#  두 시계로 움직인다.
	#    득점 반쪽 c/k/v — 다트마다. 기존 아이템과 완전히 같은 배관을 쓴다.
	#    골드 반쪽 g/gv  — 라운드 정산 때만. game.gd 의 _gold_from_items().
	#  골드를 다트 단위로 주면 "일부러 목표를 안 넘기고 다트를 다 던져
	#  골드만 벌기" 가 성립한다. 정산 단위로 묶어 그 길을 막았다.
	#  득점 반쪽은 같은 조건의 기존 아이템보다 낮다. 골드가 그 차액이다.
	{"id": "mtc", "n": "밑천", "c": "small", "k": "mult", "v": 2,
		"g": "broke", "gv": 4, "cost": 4},
	{"id": "pdn", "n": "판돈", "c": "first", "k": "chip", "v": 26,
		"g": "spare", "gv": 1, "cost": 7},
	{"id": "bjn", "n": "본전", "c": "diff", "k": "chip", "v": 12,
		"g": "clean", "gv": 3, "cost": 7},
	{"id": "kns", "n": "큰손", "c": "triple", "k": "mult", "v": 3,
		"g": "blitz", "gv": 9, "cost": 11},
	{"id": "mlj", "n": "물주", "c": "always", "k": "chip", "v": 16,
		"g": "clear", "gv": 4, "cost": 11},
]

const GOLD_BROKE := 6          # "밑천" 기준 — 정산 시점 보유 골드
const GOLD_BLITZ := 3          # "큰손" 기준 — 남은 다트

# ── 다트 종류 (탄창) ──────────────────────────────────────
#  gauge  조준 게이지 속도 배율 (낮을수록 맞히기 쉽다)
#  mult   링 배수에 가산 (최소 1로 고정)
#  fix1   링 배수를 1로 못박음
#  pierce 양옆 섹터의 기본 점수를 절반씩 추가
#  magnet 착탄을 보드 중심 쪽으로 당기는 비율
const DARTS := [
	{"id": "std", "n": "표준", "d": "특성 없음",
		"gauge": 1.00, "mult": 0, "fix1": false, "pierce": false, "magnet": 0.0, "cost": 0},
	{"id": "hvy", "n": "무거운", "d": "게이지 느림 · 배수 -1",
		"gauge": 0.55, "mult": -1, "fix1": false, "pierce": false, "magnet": 0.0, "cost": 5},
	{"id": "lgt", "n": "가벼운", "d": "게이지 빠름 · 배수 +3",
		"gauge": 1.90, "mult": 3, "fix1": false, "pierce": false, "magnet": 0.0, "cost": 6},
	{"id": "prc", "n": "관통", "d": "양옆 섹터 절반 · 배수 1",
		"gauge": 1.00, "mult": 0, "fix1": true, "pierce": true, "magnet": 0.0, "cost": 7},
	{"id": "mag", "n": "자석", "d": "중심으로 당김 · 배수 -1",
		"gauge": 1.00, "mult": -1, "fix1": false, "pierce": false, "magnet": 0.25, "cost": 7},
]
const SHOP_DARTS := 1


static func dart_of(id: String) -> Dictionary:
	for d in DARTS:
		if d.id == id:
			return d
	return DARTS[0]


# ── 보드 개조 ─────────────────────────────────────────────
#  아이템이 hit_info 가 뱉은 결과를 읽는다면, 개조는 hit_info 가 읽는 값을 바꾼다.
#
#  이 표가 서 있는 전제 셋. 하나라도 무너지면 무효 구매가 되돌아온다.
#   ① 한 종류는 런에 한 번만 산다. 누적이 없으니 누적 상한도 없다.
#      TRP_BAND_MAX 따위를 다시 만들지 마라 — 잡을 것이 없다.
#   ② 판은 저장하지 않는다. 살 때마다 BOARD_BASE 에서 이 표 순서대로 다시
#      굽는다(game.gd _board_of). 그래서 "사는 순서가 판을 바꾸는가" 라는
#      물음이 성립하지 않는다. 증명이 아니라 구성이다.
#   ③ 조합의 천장은 개조마다가 아니라 board_val() 한 곳에 있다. 판값이 기본
#      판의 VAL_MAX_MUL 배를 넘기는 개조는 매대에 아예 안 뜬다.
#
#  k = 효과 축. game.gd _mod_step 의 match 가 읽는 유일한 열쇠다.
#  새 축을 만들려면 여기 한 줄과 저기 한 가지를 같이 늘린다. 그 둘이 접점 전부다.
#    band   링 폭 주고받기  v = [트리플 폭 증분, 더블 폭 증분]   합이 0 이다
#    slide  트리플 띠 이동   v = 더블 안쪽에서 띄울 간격 (절대 좌표가 아니다)
#    ring   트리플 띠 추가   v = [안, 밖]
#    bull   불 이중 구조     v = [한복판, 불]
#    out    판 바깥 경계     v = 새 dbl_out
#    swap   작은 칸 올리기   v = 올릴 칸 수 (SECTOR_MAX 로 올린다)
#    odd    짝수 칸 내리기   v = 안 씀
#  excl = 같이 못 사는 짝. 서로를 정확히 되돌리는 한 쌍에만 쓴다.
#
#  ※ 칸 값은 절대 SECTOR_MAX(20) 를 넘기지 마라. check("bull") 이
#     sector >= 25 라, 25 짜리 칸이 생기면 그냥 칸이 불로 판정되고
#     명중왕이 오발한다. odd/even(sector < 25) 도 같이 죽는다.
const MODS := [
	{"id": "soks", "n": "속살", "d": "트리플 띠 +0.06 · 더블 띠 −0.06",
		"k": "band", "v": [0.06, -0.06], "excl": "guts", "cost": 9},
	{"id": "guts", "n": "겉살", "d": "더블 띠 +0.06 · 트리플 띠 −0.06",
		"k": "band", "v": [-0.06, 0.06], "excl": "soks", "cost": 6},
	{"id": "byer", "n": "벼랑", "d": "트리플 띠가 더블 바로 안쪽으로",
		"k": "slide", "v": 0.03, "excl": "", "cost": 7},
	{"id": "arst", "n": "아랫목", "d": "안쪽에 트리플 띠 하나 더",
		"k": "ring", "v": [0.38, 0.46], "excl": "", "cost": 9},
	{"id": "mung", "n": "멍석", "d": "불 +0.06 · 한복판 −0.02",
		"k": "bull", "v": [0.04, 0.20], "excl": "", "cost": 8},
	{"id": "panb", "n": "판벌이", "d": "판이 커진다 — 빗나감이 준다",
		"k": "out", "v": 1.10, "excl": "", "cost": 12},
	{"id": "pang", "n": "판갈이", "d": "가장 작은 세 칸이 20이 된다",
		"k": "swap", "v": 3, "excl": "", "cost": 9},
	{"id": "jjkp", "n": "짝패", "d": "칸마다 짝이 생긴다 · 짝수 칸 −1",
		"k": "odd", "v": 0, "excl": "", "cost": 6},
]

#  판이 성립하기 위한 순서 규칙. 밸런스 상한이 아니라 hit_info 의 if 사슬이
#  전제하는 순서 그 자체다 — 이걸 통과하면 50/25/배수3/배수2 판정이 안 깨진다.
#    bi <= bo < t2i < t2o < ti < to < din < dout
const GEO := {
	"bi_min": 0.02,     # 한복판 최소 반경
	"bull_gap": 0.02,   # 25 띠의 최소 폭. 0 이면 25 칸이 사라져 외골수·정밀이 흔들린다
	"bo_min": 0.08,
	"ti_min": 0.30,     # 띠가 판 한복판까지 기어들어오지 않게
	"band_min": 0.02,   # 링의 최소 폭
	"gap": 0.03,        # 띠와 띠 사이 단색의 최소 폭
	"eps": 0.0005,      # 0.56 - 0.03 != 0.53 인 부동소수 오차를 흡수한다
}

const SECTOR_MAX := 20      # 위 ※ 주석 참조. 25 를 넘기면 안 되는 것이 아니라 20 을 넘기면 안 된다

#  판값 — 균등 조준 다트당 기대 점수(섹터 실제 평균 기준). 기하와 섹터를
#  한 저울에 올리는 유일한 숫자다. 개조가 슬롯을 안 먹는 대신 이것이 슬롯이다.
#  기본 판 15.431 → 상한 23.147. 지금 여덟 종에서 이 상한이 눈에 보이는 곳은
#  딱 하나 — 판벌이와 판갈이(둘 다 빌드를 안 가리는 카드)를 함께 못 산다.
const VAL_W := {"bull_i": 50.0, "bull_o": 25.0, "trp": 3.0, "dbl": 2.0, "plain": 1.0}
const VAL_MAX_MUL := 1.50


static func mod_of(id: String) -> Dictionary:
	for m in MODS:
		if m.id == id:
			return m
	return {}


static func board_val(b: Dictionary, sec: Array) -> float:
	var a_trp: float = b.to * b.to - b.ti * b.ti
	if b.t2o > 0.0:
		a_trp += b.t2o * b.t2o - b.t2i * b.t2i
	var a_dbl: float = b.dout * b.dout - b.din * b.din
	var a_pln: float = (b.dout * b.dout - b.bo * b.bo) - a_trp - a_dbl
	var s := 0.0
	for v in sec:
		s += float(v)
	s /= float(sec.size())
	return VAL_W.bull_i * b.bi * b.bi \
			+ VAL_W.bull_o * (b.bo * b.bo - b.bi * b.bi) \
			+ s * (VAL_W.trp * a_trp + VAL_W.dbl * a_dbl + VAL_W.plain * a_pln)


static func board_val_max() -> float:
	return board_val(BOARD_BASE, SECTORS_BASE) * VAL_MAX_MUL


# ── 삭제 ──────────────────────────────────────────────────
#  const TRP_BAND_MAX := 0.24
#  const DBL_BAND_MAX := 0.22
#  const BULL_O_MAX   := 0.30
#  누적 구매가 없어져 상한이 잡을 것이 없다. 남겨 두면 다음 사람이
#  "개조가 쌓인다" 는 거짓 전제를 읽는다.

# ── 스테이지 제약 ─────────────────────────────────────────
#  높은 등급의 판을 고르면 이 중에서 무작위로 붙는다.
const MODIFIERS := [
	{"id": "narrow", "n": "좁은 판", "d": "트리플·더블 링 폭 절반"},
	{"id": "gust", "n": "역풍", "d": "조준 게이지 2배 속도"},
	{"id": "fog", "n": "안개", "d": "조준 확인 구간 없음"},
	{"id": "short", "n": "단벌", "d": "다트 1개 감소"},
	{"id": "dead", "n": "금지 구역", "d": "20번 섹터 점수 0"},
	{"id": "dull", "n": "둔화", "d": "아이템 하나 무작위 봉인"},
]

# ── 스테이지 등급 ─────────────────────────────────────────
#  제약을 받아들일수록 목표는 오르지만 상점 자금이 커진다.
const STAGES := [
	{"id": "plain", "n": "정공", "sub": "제약 없음",
		"mods": 0, "mul": 1.00, "gold": 0, "item": false},
	{"id": "hard", "n": "도전", "sub": "제약 1개",
		"mods": 1, "mul": 1.00, "gold": 5, "item": false},
	{"id": "brutal", "n": "극한", "sub": "제약 2개 · 목표 +25%",
		"mods": 2, "mul": 1.25, "gold": 10, "item": true},
]

# ── 조건 판정 ─────────────────────────────────────────────
static func check(c: String, x: Dictionary) -> bool:
	if x.miss:
		return c == "miss"
	match c:
		"always": return true
		"triple": return x.mult == 3
		"double": return x.mult == 2
		"bull": return x.sector >= 25
		"odd": return x.sector < 25 and x.sector % 2 == 1
		"even": return x.sector < 25 and x.sector % 2 == 0
		"left": return x.left
		"right": return not x.left
		"big": return x.sector >= 15 and x.sector < 25
		"small": return x.sector >= 1 and x.sector <= 5
		"same": return x.same
		"diff": return not x.same
		"first": return x.first
		"last": return x.last
		"streak": return x.streak > 0
	return false


static func cond_text(c: String) -> String:
	match c:
		"always": return "모든 다트"
		"triple": return "트리플 명중 시"
		"double": return "더블 명중 시"
		"bull": return "불 명중 시"
		"odd": return "홀수 섹터 명중 시"
		"even": return "짝수 섹터 명중 시"
		"left": return "왼쪽 절반 명중 시"
		"right": return "오른쪽 절반 명중 시"
		"big": return "15 이상 섹터 명중 시"
		"small": return "5 이하 섹터 명중 시"
		"same": return "직전과 같은 섹터면"
		"diff": return "직전과 다른 섹터면"
		"first": return "라운드 첫 다트에"
		"last": return "라운드 마지막 다트에"
		"streak": return "연속 명중 1회마다"
		"miss": return "빗나가면"
	return ""


static func eff_text(k: String, v: int) -> String:
	match k:
		"chip": return "점수 +%d" % v
		"mult": return "배수 +%d" % v
		"xmult": return "배수 ×%d" % v
		"mult_streak": return "배수 +%d" % v
	return ""


static func item_desc(it: Dictionary) -> String:
	return "%s %s" % [cond_text(it.c), eff_text(it.k, it.v)]


# 골드 반쪽은 item_desc 에 섞지 않는다 — 발동 시점이 다르므로 따로 보여준다.
static func gold_text(g: String, gv: int) -> String:
	match g:
		"clear": return "클리어 시 골드 +%d" % gv
		"spare": return "남은 다트 1개당 골드 +%d" % gv
		"clean": return "한 발도 안 빗나가면 골드 +%d" % gv
		"blitz": return "남은 다트 %d개 이상이면 골드 +%d" % [GOLD_BLITZ, gv]
		"broke": return "정산 때 보유 골드 %d 이하면 +%d" % [GOLD_BROKE, gv]
	return ""


# 칩 위에 얹는 3글자 태그 (원 안에는 긴 글이 안 들어간다)
static func gold_tag(g: String) -> String:
	match g:
		"clear": return "클리어"
		"spare": return "잔탄"
		"clean": return "무실책"
		"blitz": return "속공"
		"broke": return "빈털터리"
	return ""


# ── 판매 ──────────────────────────────────────────────────
#  판매가 = 구매가의 절반(내림), 최소 2. 22종이 4/7/11/14 이므로 2/3/5/7 이다.
#  올림으로 두면 7→4, 11→6 이 되어 보통 등급의 회수율이 흔함보다 높아진다.
#  내림은 평균 회수율을 46% 로 눌러 "비싼 칩은 팔면 더 손해"를 만든다.
#
#  스프레드(구매가 − 판매가) = 2 / 4 / 6 / 7.
#  이것이 "한 정산만 빌려 쓰고 되팔기" 의 손익선이다. 골드 칩의 1회 지급(gv)이
#  이 선을 넘으면 대여가 성립한다 — 지금 넘는 것은 큰손(9 vs 6) 하나뿐이고
#  그것도 계속 들고 있는 쪽이 낫다. 새 골드 칩의 gv 는 반드시 이 선과 비교한다.
const SELL_DIV := 2
const SELL_MIN := 2            # 최저 구매가가 4 라 지금은 안 걸린다. 0골드 판매를 막는 바닥.


static func sell_value(it: Dictionary) -> int:
	@warning_ignore("integer_division")  # 내림이 의도다 — 위 주석 참조
	return maxi(SELL_MIN, int(it.cost) / SELL_DIV)


static func target_of(round_no: int) -> int:
	var i := clampi(round_no - 1, 0, TARGETS.size() - 1)
	return TARGETS[i]
