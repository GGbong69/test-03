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
#  아이템이 "어디를 노릴지"를 바꾼다면, 개조는 "얼마나 잘 맞출지"를 바꾼다.
const MODS := [
	{"id": "trpw", "n": "트리플 확장", "d": "트리플 링 폭 +60%", "cost": 8},
	{"id": "dblw", "n": "더블 확장", "d": "더블 링 폭 +60%", "cost": 8},
	{"id": "bulw", "n": "불 확장", "d": "불스아이 반경 +70%", "cost": 10},
	{"id": "sw20", "n": "20 복제", "d": "가장 작은 섹터를 20으로", "cost": 9},
]

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

# 개조 누적 한계 (링이 서로 잡아먹지 않도록)
const TRP_BAND_MAX := 0.24
const DBL_BAND_MAX := 0.22
const BULL_O_MAX := 0.30


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
