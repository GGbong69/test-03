extends RefCounted

# ══════════════════════════════════════════════════════════
#  데이터 테이블 로더
#
#  수치는 res://data/ 의 표 여덟 장에 있다. 이 파일은 그 표를 읽고,
#  틀린 곳을 전부 모아 뱉고, game.gd 가 쓰는 모양으로 내준다.
#  숫자 리터럴을 여기에 다시 적지 마라 — 그 순간 출처가 둘이 된다.
#
#  표 여덟 장
#    items.csv      동전 26   — 이 세트의 대표 표
#    rarity.csv     등급 3  — 등장 가중치의 유일한 출처
#    mods.csv       보드 확장 8  — 판 기하를 바꾼다
#    darts.csv      다트 5  — 탄창에 드는 것
#    modifiers.csv  제약 10 — 보스 판마다 하나(겹치기면 둘)가 미리 걸린다
#    rounds.csv      판 8 — 목표 곡선 · 리그 배수 · 테이블 폭
#    legs.csv     블라인드 3 — 판 안의 배수·보상·건너뛰기
#    tuning.csv     스칼라 24 — 행이 안 느는 값만 모은다
#
#  아홉 번째 장 _stats.csv 는 게임이 안 읽는다. 밑줄이 그 뜻이다.
#  scripts/tools/item_stats.gd 가 덮어쓰는 측정 산출물이고, 밸런스 근거로만
#  본다. 로더가 그 파일을 여는 곳은 이 파일 어디에도 없다.
#
#  표에 없는 것 — 왜 여기 안 오는가
#    check() 의 조건 19가지        술어다. 임계값만 빼면 술어가 두 쪽 난다
#    hit_info() 의 링 순서         반환 치역이 check() 와 맺은 계약이다
#    _mod_step 의 축 match         축이 늘 때만 코드가 느는 것이 옳은 접점이다
#    GEO · BOARD_BASE · VAL_W      1행짜리라 CSV 로 얻는 것이 없고,
#                                  검사 순서와 적분식이 값과 떨어지면 뜻이 죽는다
#    판매가                        cost 로 파생한다. 개별 조정 불가가 설계다
#
#  표를 늘려도 코드가 안 느는 것과 느는 것
#    안 는다 — items 한 줄, rounds 한 줄, tuning 한 줄, 기존 축을 쓰는 mods 한 줄
#    는다   — 새 cond(check + cond_text + _icon_cond 셋), 새 다트(DK_PARTS 한 줄 · _icon_dart 의 match · _dart3_parts),
#            새 축(mods 또는 modifiers 의 match 한 가지),
#            새 제약(_icon_modifier 한 가지 — 카드 얼굴에 그림이 있어야 한다)
# ══════════════════════════════════════════════════════════

#  익스포트 주의 — data/*.csv 는 .import 에서 importer="keep" 이어야 한다.
#  고닷 4 는 CSV 를 기본적으로 번역 파일(csv_translation)로 잡고, 그러면
#  원본 파일이 빌드에 안 실려 FileAccess.open 이 null 을 돌려준다. 즉
#  에디터에서는 멀쩡하고 익스포트한 빌드에서만 동전이 한 장도 없다.
#  (이 프로젝트에서 두 번 그 상태였다 — 처음 items.csv, 다음 새 표 다섯.)
#  프리셋의 비-리소스 필터에 data/*.csv 를 적어 두었고, 실제 빌드한 pck 를
#  열어 표 열셋이 내용까지 실렸고 .translation 은 0개임을 확인했다.
#  고칠 때는 고닷을 끄고 고쳐야 한다 — 켠 채로 고치면 리임포트가 옛 .import
#  를 되써 버린다(한 번 당했다).
const DIR := "res://data/"
const FILES := {
	"items": "items.csv",
	"rarity": "rarity.csv",
	"mods": "mods.csv",
	"darts": "darts.csv",
	"modifiers": "modifiers.csv",
	"rounds": "rounds.csv",
	"shop": "shop.csv",
	"legs": "legs.csv",
	"leagues": "leagues.csv",
	"packs": "packs.csv",
	"chal": "challenges.csv",
	"colors": "colors.csv",
	"tags": "tags.csv",
	"tutor": "tutor.csv",
	"boosters": "boosters.csv",
	"tuning": "tuning.csv",
	# ── HIGHTON 스펙(2026-08-23 통합 컨텍스트)에서 온 표 ──
	# areas 는 전부 확정이라 게임이 직접 읽는다. 나머지는 상태 열이 문이다 —
	# 가안·제안·미정 행은 자리(스캐폴드)이고, 검증기가 집계만 한다.
	"areas": "areas.csv",
	"area_up": "area_upgrades.csv",
	"cons": "consumables.csv",
}

# tuning.csv 가 반드시 가져야 하는 열쇠. 목록이 곧 계약이다 —
# 코드가 읽는데 표에 없으면 부팅이 소리를 낸다.
const TUNE_KEYS := [
	"start_gold", "clear_gold", "gold_per_dart", "interest_per", "interest_max",
	"gold_broke", "gold_blitz", "sell_div", "sell_min",
	"free_rerolls", "reroll_base", "reroll_step", "max_items",
	"darts_base",
	"board_r", "aim_swing", "sector_max", "val_max_mul",
	"gauge_speed", "resolve_beat", "bal_beats", "confirm_hold", "fly_time",
	"aim_click_r", "legend_pack_w",
	"cons_slots", "cons_price_tmp",
	"kick_n", "kick_share",
	"track_score", "track_mult",
	"curve_first", "curve_last", "curve_bow",
	# ── 2026-09-20 · 무한모드(기획서 P.17 「함수로 설정」) ──────
	#  round_base_endless 가 앞의 둘을, legs_top/rounds_top 이 셋째를,
	#  _roll_boss_mods 가 넷째를, big() 이 다섯째를 읽는다.
	"endless_step", "endless_accel", "endless_rounds", "endless_stack_per",
	"big_at",
]

# 등급 네 단. 발라트로의 이름을 따른다 — 일반 · 희귀 · 레어 · 레전더리.
# 속이름(id)은 안 바꿨다. 코드가 그것으로 갈리고 표·저장·CSV 가 전부
# 같은 낱말을 쓰므로, 한글 이름만 rarity.csv 에서 옮긴다.
const RARITIES := ["common", "uncommon", "rare", "legendary"]
const MOD_AXES := ["band", "slide", "ring", "bull", "out", "swap",
		"odd", "even", "flat", "target", "pizza", "donut"]
# 제약의 축. 발라트로의 보스 블라인드가 손패·플레잉 카드를 때리는 자리에
# 우리는 **판과 조준**이 있다. 그래서 축을 네 갈래로 벌린다 —
#   칸   sector_kill · color_kill · odd_mul · spin
#   링   band_mul · ring_kill
#   조준 gauge_mul · fog
#   판밖 darts_add · seal_items · target_mul · reward_mul
# 축 하나에 걸리는 자리가 정확히 한 곳이어야 한다. 두 곳이 되는 순간
# "이 제약이 무엇을 하는가" 가 코드에서 안 읽힌다.
# 사진이 밀 수 있는 축과 그 바닥·천장. 목록이 곧 계약이다 — 코드가 안 읽는
# 키를 표에 적으면 조용히 아무 일도 안 하는 사진이 되고(안개가 그랬다),
# 바닥이 없으면 음수 한 줄이 런을 잠근다 — 그래서 키마다 범위를 쥔다.
const VOUCHER_KEYS := {
	"shop_slots":    [0.0, 6.0],    # 표 4 + 여기 + 뱃지 2 ≤ 12칸
	"free_rerolls":  [0.0, 4.0],
	"interest_add":  [0.0, 10.0],   # 상한 15 = 보유 75. 런 최적 잔고의 세 배다
	"darts_add":     [0.0, 2.0],    # 동전·뱃지까지 아홉이면 벽 밖으로 나간다
	"gauge_mul":     [0.25, 4.0],
}
const VOUCHER_OPS := ["add", "mul"]

# ── 다트통의 갈래와 변형 ──────────────────────────────────────
#  base    런을 완주하면 표 순서대로 다음 것이 열린다
#  hidden  조건을 채워야 열린다. 그리고 **조준과 점수 계산이 달라진다** —
#          기본 다트통들이 값만 바꾸는 것과 갈리는 자리다.
#
#  아래 둘은 **아직 std 하나뿐이다.** 변형의 내용은 안 정했고, 여기는
#  갈라지는 자리만 세워 둔 것이다. 새 변형을 만들려면 이름을 여기 적고
#  game.gd 의 _aim_tick / _score_combine 에 그 이름의 갈래를 판다.
#  등록 안 된 이름을 표에 적으면 검증기가 막는다 — 조용히 std 로 도는
#  것이 이 시스템에서 가장 나쁜 결말이다(안개가 그랬다).
# 저장의 통계 열쇠 이름. save.gd 를 preload 하면 표 검증기가 저장 파일을
# 읽기 시작한다 — 검증기는 순수 함수여야 하므로 이름만 여기 둔다.
# save.gd 의 STATS 와 어긋나면 save_probe 가 잡는다.
const Save_STATS := [
	"runs", "wins", "darts", "triples", "doubles", "bulls", "misses",
	"items_bought", "mods_bought", "darts_bought", "cons_used",
	"rerolls", "sold", "gold_earned", "skips", "fixtures_bought",
	"boosters_bought",
	"best_leg", "best_score", "best_gold", "best_track",
	"best_dart_hvy", "best_dart_lgt", "best_dart_mag",
	"best_gain", "best_spare", "best_leg_bare",
	"win_gold", "win_items", "boss_spare", "win_null",
	"clok_out_streak", "revo_bull_leg",
]
# 「N 이하」로 읽는 열쇠. 크거나 같다 하나로는 「동전 4개 이하로 완주」를
# 못 적는다 — 적게 든 쪽이 이기는 조건이기 때문이다.
const UNLOCK_CMPS := ["", "ge", "le"]
const PACK_KINDS := ["base", "hidden"]
const AIM_MODES := ["std", "ring", "tilt", "cross", "drift", "place",
		"pull", "kick"]

# 조준을 **몇 번 잠그는가**. 둘이면 축을 하나씩(세로 먼저 가로 다음),
# 하나면 누르는 그 한 번에 자리가 통째로 정해진다. 상태 기계가 이 수를
# 읽고 갈리므로, 새 방식을 AIM_MODES 에만 적고 여기 빠뜨리면 두 번
# 잠그는 방식으로 돌아 화면과 조작이 어긋난다 — 검증기가 막는다.
const AIM_STAGES := {
	"std": 2, "ring": 2, "tilt": 2,
	"cross": 1, "drift": 1, "place": 1, "pull": 1, "kick": 1,
}

# 잠그는 칸마다 화면 아래에 뜰 말. 방식마다 무엇을 정하는지가 달라서
# 한 문장을 돌려 쓰면 "눌러 좌우 결정" 을 읽고 원 크기를 정하게 된다.
# 칸 수와 문장 수가 어긋나면 안내가 빈 채로 뜬다 — 검증기가 막는다.
const AIM_HINT := {
	"std": ["다트판을 눌러 높이 결정", "다트판을 눌러 좌우 결정"],
	"ring": ["다트판을 눌러 원 크기 결정", "다트판을 눌러 각도 결정"],
	"tilt": ["다트판을 눌러 첫 축 결정", "다트판을 눌러 둘째 축 결정"],
	"cross": ["다트판을 눌러 교차점 결정"],
	"drift": ["떠도는 조준점을 눌러 결정"],
	"place": ["꽂을 자리를 누르세요"],
	"pull": ["벽의 다트를 잡고 판 쪽으로 튕기세요"],
	"kick": ["눌러 쏘고 밀리는 조준을 따라 잡으세요"],
}
const SCORE_MODES := ["std", "bal", "rand"]

const MODIFIER_AXES := ["band_mul", "gauge_mul", "fog", "darts_add",
		"sector_kill", "seal_items", "target_mul",
		"color_kill", "ring_kill", "odd_mul", "shuffle", "reward_mul"]

static var _raw := {}                # 표 이름 → Array[Dictionary] (전부 문자열)
static var _tune := {}               # key → int/float
static var _cache := {}              # 스티커한 결과
static var _errs: PackedStringArray = []
static var _warns: PackedStringArray = []
static var _booted := false


# ── 부팅 ──────────────────────────────────────────────────
#  표를 전부 읽고 한 번에 검사한다. 첫 에러에서 멈추지 않는다 —
#  한 줄 고치고 다시 켜는 것보다 한 번에 다 보는 편이 빠르다.
static func boot() -> void:
	if _booted:
		return
	_booted = true
	for name in FILES:
		_raw[name] = _read(DIR + FILES[name], name)
	_load_tune()
	_validate()
	for e in _errs:
		push_error("데이터 표: " + e)
	for w in _warns:
		push_warning("데이터 표: " + w)


static func errors() -> PackedStringArray:
	boot()
	return _errs


static func warnings() -> PackedStringArray:
	boot()
	return _warns


# ── CSV 읽기 ──────────────────────────────────────────────
#  헤더 이름으로만 접근한다. 열을 옮기거나 사이에 끼워도 안 깨진다.
#  밑줄로 시작하는 열은 사람이 읽는 주석이라 그대로 담되 이름을 남긴다.
static func _read(path: String, who: String) -> Array:
	var out := []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_errs.append("%s — 파일을 못 연다: %s" % [who, path])
		return out
	var head := f.get_csv_line()
	if head.is_empty():
		_errs.append("%s — 빈 파일이다" % who)
		f.close()
		return out
	# BOM 은 첫 칸 앞에 붙는다. 안 지우면 "id" 가 "﻿id" 가 된다.
	head[0] = head[0].lstrip("﻿")
	for i in head.size():
		head[i] = head[i].strip_edges()
	var ln := 1
	while not f.eof_reached():
		var r := f.get_csv_line()
		ln += 1
		# 빈 행 판정이 먼저다. 파일이 CRLF 로 끝나면 마지막에 빈 행이 하나 온다.
		if r.is_empty() or r[0].strip_edges() == "":
			continue
		if r.size() > head.size():
			_errs.append("%s:%d — 칸이 헤더보다 많다(%d > %d). 따옴표 없는 쉼표가 열을 밀었다"
					% [who, ln, r.size(), head.size()])
			continue
		if r.size() < head.size():
			_warns.append("%s:%d — 칸이 모자란다(%d < %d). 빈 값으로 채운다"
					% [who, ln, r.size(), head.size()])
		var row := {"_line": ln}
		for i in head.size():
			row[head[i]] = r[i].strip_edges() if i < r.size() else ""
		out.append(row)
	f.close()
	return out


static func rows(name: String) -> Array:
	boot()
	return _raw.get(name, [])


# ── 값 꺼내기 ─────────────────────────────────────────────
#  조용한 캐스팅을 안 한다. "3.5" 를 int 로 읽어 3 이 되는 일이
#  아무 소리 없이 지나가면 밸런스가 어긋난 채로 굴러간다.
static func _i(row: Dictionary, col: String, who: String, dflt := 0) -> int:
	var s: String = str(row.get(col, "")).strip_edges()
	if s == "":
		return dflt
	if not s.is_valid_int():
		_errs.append("%s:%d — %s 가 정수가 아니다: '%s'" % [who, row.get("_line", 0), col, s])
		return dflt
	return int(s)


static func _f(row: Dictionary, col: String, who: String, dflt := 0.0) -> float:
	var s: String = str(row.get(col, "")).strip_edges()
	if s == "":
		return dflt
	if not s.is_valid_float():
		_errs.append("%s:%d — %s 가 실수가 아니다: '%s'" % [who, row.get("_line", 0), col, s])
		return dflt
	return float(s)


# 참/거짓은 1/0 정수로만 쓴다. 엑셀이 TRUE 를 로케일 따라 참/TRUE 로
# 되돌려 놓기 때문에, 문자열로 두면 저장 한 번에 동전이 조용히 사라진다.
static func _b(row: Dictionary, col: String, who: String) -> bool:
	var s: String = str(row.get(col, "")).strip_edges()
	if s == "":
		return false
	if s != "0" and s != "1":
		_errs.append("%s:%d — %s 는 1 또는 0 이어야 한다: '%s'" % [who, row.get("_line", 0), col, s])
		return false
	return s == "1"


# ── 표시 문장 ─────────────────────────────────────────────
#  desc 열은 수치를 문장에 안 박는다. {v0} 는 값을, {v0:+} 는 부호를
#  붙여 넣는다. 값을 고치면 문장이 따라 바뀌므로 표가 거짓말을 못 한다.
#  음수는 빼기표(U+2212)로 찍는다 — ASCII '-' 가 「테두리 -0.06」「단벌 -1」로
#  새어 나와 다른 감소(−)와 따로 놀았다. 수에만 건다: 이름(1-UP)의 하이픈은 문자열이라 안 닿는다.
static func fill(tpl: String, vals: Dictionary) -> String:
	var out := tpl
	for k in vals:
		var v = vals[k]
		var s := _num(v)
		if (v is int or v is float) and s.begins_with("-"):
			s = "−" + s.substr(1)
		out = out.replace("{%s}" % k, s)
		out = out.replace("{%s:+}" % k, ("+" if _pos(v) else "") + s)
	return out


static func _pos(v) -> bool:
	return (v is float and v >= 0.0) or (v is int and v >= 0)


static func _num(v) -> String:
	if v is float:
		var s := "%.2f" % v
		# 1.00 은 1 로, 0.50 은 0.5 로. 표에 적힌 자릿수를 그대로 보이면
		# 화면이 지저분해진다.
		s = s.rstrip("0").rstrip(".")
		return "0" if s == "" or s == "-" else s
	return str(v)


# 부호 붙인 정수 — 감소는 빼기표(U+2212). "%+d" 는 ASCII '-' 를 찍어
# BULLET TIME 에 「판 시작 다트 -2」가 섰다.
static func _sgn(n: int) -> String:
	return ("+%d" % n) if n >= 0 else ("−%d" % -n)


# ══════════════════════════════════════════════════════════
#  표 → 게임이 쓰는 모양
# ══════════════════════════════════════════════════════════

# ── 동전 ────────────────────────────────────────────────────
#  열: id name rarity cond kind value cost gold gv weight min_leg enabled
static func items() -> Array:
	boot()
	if _cache.has("items"):
		return _cache["items"]
	var out := []
	for r in _raw.get("items", []):
		if not _b(r, "enabled", "items"):
			continue
		var rar: String = r.get("rarity", "common")
		# sec 조건은 숫자 집합을 조건 문자열에 싣는다 — check() 가 아이템을
		# 몰라도 판정할 수 있게 "sec:4,10" 꼴로 굳힌다.
		var cnd: String = r.get("cond", "")
		if cnd == "sec":
			cnd = "sec:" + String(r.get("secs", "")).replace(";", ",")
		elif cnd == "col":
			cnd = "col:" + String(r.get("secs", "")).replace(";", ",")
		var it := {
			"id": r.get("id", ""),
			"n": r.get("name", ""),
			"c": cnd,
			"k": r.get("kind", ""),
			"v": _i(r, "value", "items"),
			"cost": _i(r, "cost", "items"),
			"rarity": rar,
			"tags": String(r.get("_tags", "")).split(";", false),
			"per": r.get("per", ""),
			"k2": r.get("k2", ""),
			"v2": _i(r, "v2", "items", 0),
			"grow": r.get("grow", ""),
			"gstep": _i(r, "gstep", "items", 0),
			"boom": r.get("boom", ""),
			"dadd": _i(r, "dadd", "items", 0),
			"side": r.get("side", ""),
			# 조준 방식. 비면 std 다 — 178장 중 이것을 쥔 장이 몇 없다.
			"aim": r.get("aim", ""),
			# 점수 계산 방식. 조준과 **같은 갈래다** — 터지는 효과가 아니라
			# 한 판 내내 켜져 있는 방법이고, 동전이 쥐므로 사고 팔고 봉인되는
			# 규칙 아래 놓인다. 비면 다트통 표로 떨어진다.
			"score": r.get("score", ""),
			# 이 동전을 여는 조건. 다트통의 unlock_stat 과 같은 규약이다 —
			# 통계 하나가 문이고, 비면 다른 길로만 온다(다트통이 쥐여 주기).
			"ustat": r.get("unlock_stat", ""),
			"uv": _i(r, "unlock_v", "items", 0),
			"line": r.get("_line", 0),
		}
		if String(r.get("gold", "")) != "":
			it["g"] = r.get("gold")
			it["gv"] = _i(r, "gv", "items")
		out.append(it)
	_cache["items"] = out
	return out


# 등장 가중치와 해금 판. 등급이 기본을 정하고 동전이 예외로 덮는다.
static func item_weight(it: Dictionary) -> float:
	boot()
	for r in _raw.get("items", []):
		if r.get("id") == it.id and String(r.get("weight", "")) != "":
			return _f(r, "weight", "items")
	for r in _raw.get("rarity", []):
		if r.get("id") == it.get("rarity", "common"):
			return _f(r, "weight", "rarity", 1.0)
	return 1.0


static func item_min_leg(it: Dictionary) -> int:
	boot()
	for r in _raw.get("items", []):
		if r.get("id") == it.id and String(r.get("min_leg", "")) != "":
			return _i(r, "min_leg", "items")
	for r in _raw.get("rarity", []):
		if r.get("id") == it.get("rarity", "common"):
			return _i(r, "min_leg", "rarity", 1)
	return 1


static func rarity_color(rar: String) -> Color:
	boot()
	for r in _raw.get("rarity", []):
		if r.get("id") == rar:
			return Color(String(r.get("color", "8f86a8")))
	return Color("8f86a8")


static func rarity_name(rar: String) -> String:
	boot()
	for r in _raw.get("rarity", []):
		if r.get("id") == rar:
			return r.get("name", rar)
	return rar


# ── 착탄 영역 (areas.csv · 전부 확정) ─────────────────────
#  key 는 코드가 부르는 이름(single/double/triple/bull_o/bull_i/out)이고
#  wb 는 스펙 워크북의 영역ID다. hit_info 가 매 판정마다 부르므로 캐시한다.
static func area(key: String) -> Dictionary:
	boot()
	if not _cache.has("areas"):
		var m := {}
		for r in _raw.get("areas", []):
			m[String(r.get("key", ""))] = {
				"base": _i(r, "base", "areas", 0),
				"mult": _i(r, "mult", "areas", 1),
				"track": _i(r, "track", "areas", 0),
				# 이름은 런 정보 화면이 쓴다. hit_info 는 안 읽지만 표에
				# 이미 있는 칸이라 여기서 같이 실어 두는 것이 표를 두 번
				# 읽는 것보다 싸다.
				"n": String(r.get("name", "")),
			}
		_cache["areas"] = m
	var a: Dictionary = _cache["areas"]
	if not a.has(key):
		push_error("데이터 표: areas 에 '%s' 가 없다" % key)
		return {"base": 0, "mult": 1, "track": 0}
	return a[key]


# 표에 적힌 순서대로 영역 전부. 런 정보 화면이 트랙 표를 세울 때 쓴다 —
# area(key) 는 한 칸씩 묻는 문이고 이쪽은 표 전체를 한 번에 본다.
# out(보드 아웃)도 포함한다: 트랙이 0 이라 강화는 못 받지만 판에 있는
# 영역이고, 빼면 "다섯 중 넷만 보인다" 가 된다.
static func areas_all() -> Array:
	boot()
	var out := []
	for r in _raw.get("areas", []):
		out.append(area(String(r.get("key", ""))))
	return out


# ── 팩 (boosters.csv) ────────────────────────────────────
#  상점에 물건으로 뜨고, 사면 안에 든 것 몇 개를 펼쳐 그중 하나를 고른다.
#  발라트로의 부스터 팩 자리다.
#
#  size 는 펼치는 수, pick 은 그중 고르는 수다. 둘을 나눠 두는 것은
#  "넷을 펼쳐 둘을 고른다" 같은 팩을 표만 고쳐 만들 수 있게 하려는 것이다.
#  pool 은 무엇이 나올 수 있는가 — 세미콜론으로 여럿, 다트통의 grant 와
#  같은 규약이다.
static func boosters() -> Array:
	boot()
	if _cache.has("boosters"):
		return _cache["boosters"]
	var out := []
	for r in _raw.get("boosters", []):
		if float(_f(r, "weight", "boosters", 0.0)) <= 0.0:
			continue
		out.append({
			"id": String(r.get("id", "")),
			"n": String(r.get("name", "")),
			"size": _i(r, "size", "boosters", 2),
			"pick": _i(r, "pick", "boosters", 1),
			"cost": _i(r, "cost", "boosters", 4),
			"pool": String(r.get("pool", "")).split(";", false),
			"w": _f(r, "weight", "boosters", 1.0),
			# 펼치는 수·고르는 수는 size·pick 에서 꽂는다 — 손으로 적은 「2개 중 하나」가
			# 표와 따로 놀았다.
			"d": fill(String(r.get("desc", "")), {"size": _i(r, "size", "boosters", 2),
					"pick": _i(r, "pick", "boosters", 1)}),
		})
	_cache["boosters"] = out
	return out


# ── 트랙 강화 (area_upgrades.csv · 수치 전부 미정) ────────
#  트랙의 1..lv 레벨 행을 합쳐 돌려준다. 지금은 모든 행의 수치 칸이 비어
#  있으므로(미정) 0 이 나온다 — 자리만 세워 둔 표다.
#  2026-09-11 기획서 P.10 — 「홀수레벨당 점수 짝수레벨당 배수가 오른다」.
#  표가 아니라 **식**이다. 표로 두면 적어 둔 레벨(8)에서 보너스가 멎는데,
#  사탕은 몇 번이든 살 수 있으므로 9레벨부터는 올려도 아무 일이 안 일어난다 —
#  그 벽이 화면 어디에도 안 보여서 "왜 안 오르지" 가 된다. 식이면 상한이 없다.
#
#  레벨 n 까지의 누적:  점수 = 올림(n/2) × track_score  ·  배수 = 내림(n/2) × track_mult
#  (레벨 1 점수 · 2 배수 · 3 점수 · 4 배수 … 순서다)
#
#  트랙마다 다른 값을 주고 싶으면 area_upgrades.csv 에 그 트랙 줄을 적는다 —
#  한 줄이라도 있으면 그 표가 이긴다. 지금은 다섯 트랙이 같은 값을 쓴다.
static func track_bonus(track: int, lv: int) -> Dictionary:
	boot()
	if lv <= 0:
		return {"s": 0, "m": 0}
	var out := {"s": 0, "m": 0}
	var by_table := false
	for r in _raw.get("area_up", []):
		if _i(r, "track", "area_up", 0) != track:
			continue
		by_table = true
		if _i(r, "level", "area_up", 0) > lv:
			continue
		out.s += _i(r, "add_score", "area_up", 0)
		out.m += _i(r, "add_mult", "area_up", 0)
	if by_table:
		return out
	@warning_ignore("integer_division")
	var odd: int = (lv + 1) / 2        # 홀수 레벨이 몇 번 지났나
	@warning_ignore("integer_division")
	var even: int = lv / 2             # 짝수 레벨이 몇 번 지났나
	return {"s": odd * tune_i("track_score"), "m": even * tune_i("track_mult")}


# ── 사탕 (consumables.csv · 전부 가안) ─────────────
#  enabled 행만 산다. 가격 칸이 비면(미정) 임시가 cons_price_tmp 를 쓴다 —
#  임시값은 tuning.csv 에 TODO 와 같이 있다. 스펙의 미정 가격을 데이터에서
#  확정해 버리지 않기 위한 우회다.
static func consumables() -> Array:
	boot()
	if _cache.has("cons"):
		return _cache["cons"]
	var out := []
	for r in _raw.get("cons", []):
		if not _b(r, "enabled", "cons"):
			continue
		var cost := _i(r, "cost", "cons", 0)
		var cv := _i(r, "v", "cons", 0)
		out.append({
			"id": r.get("id", ""),
			"n": r.get("name", ""),
			# 다른 표처럼 fill 을 지난다. 안 지나서 설명창에 「상한 {v}」가
			# 글자 그대로 찍히고 있었다(2026-09-13).
			"d": fill(r.get("desc", ""), {"v": cv}),
			"cat": r.get("cat", ""),
			# 사용조건 — 기획서 s33 이 표로 낸 열(2026-09-13). 전에는
			# _cons_use 안에 갈래마다 박혀 있었다.
			#   any   아무 때나
			#   rest  상점 · 판 선택중
			#   play  판 플레이 중
			"use_at": r.get("use_at", "any"),
			"track": _i(r, "track", "cons", 0),
			"v": cv,
			"cost": cost if cost > 0 else tune_i("cons_price_tmp"),
			"line": r.get("_line", 0),
		})
	_cache["cons"] = out
	return out


# 사용조건의 한국어 이름. 태그에 그대로 적힌다. any 는 붙일 것이 없다.
static func use_at_name(w: String) -> String:
	match w:
		"rest": return "상점·판 선택"
		"play": return "판 플레이 중"
	return ""


static func cons_slots() -> int:
	return int(pack_v("cons_slots", float(tune_i("cons_slots"))))



# ── 보드 확장 ─────────────────────────────────────────────
#  k = 효과 축. game.gd _mod_step 의 match 가 읽는 유일한 열쇠다.
#    band   링 폭 주고받기  v = [트리플 증분, 더블 증분]   합이 0 이다
#    slide  트리플 띠 이동   v = 더블 안쪽에서 띄울 간격
#    ring   트리플 띠 추가   v = [안, 밖]
#    bull   불 이중 구조     v = [한복판, 불]
#    out    판 바깥 경계     v = 새 dbl_out
#    swap   작은 칸 올리기   v = 올릴 칸 수
#    odd    짝수 칸 내리기   v = 안 씀
#    donut  불 지우기        v = [큰 칸 증분, 작은 칸 증분]
#
#  v1 이 비면 v 는 배열이 아니라 **스칼라**다(아래 has1). 2026-09-13
#  기획서에서 donut 이 비대칭으로 갈려 v1 이 찼고, 그래서 그 축만
#  스칼라에서 배열로 옮겼다 — v1 을 채우거나 비우면 game.gd _mod_step
#  쪽 읽는 법도 같이 바뀐다. 큰 칸과 작은 칸을 가르는 문턱은 표에 값
#  열이 v0·v1 둘뿐이라 자리가 없어 그 가지가 쥔다.
static func mods() -> Array:
	boot()
	if _cache.has("mods"):
		return _cache["mods"]
	var out := []
	for r in _raw.get("mods", []):
		var axis: String = r.get("axis", "")
		var v0 := _f(r, "v0", "mods")
		var has1 := String(r.get("v1", "")) != ""
		var v1 := _f(r, "v1", "mods")
		out.append({
			"id": r.get("id", ""),
			"n": r.get("name", ""),
			"k": axis,
			"v": [v0, v1] if has1 else v0,
			"excl": r.get("excl", ""),
			"cost": _i(r, "cost", "mods"),
			"d": fill(r.get("desc", ""), {"v0": v0, "v1": v1}),
			"line": r.get("_line", 0),
		})
	_cache["mods"] = out
	return out


static func mod_of(id: String) -> Dictionary:
	for m in mods():
		if m.id == id:
			return m
	return {}


# ── 다트 ──────────────────────────────────────────────────
static func darts() -> Array:
	boot()
	if _cache.has("darts"):
		return _cache["darts"]
	var out := []
	for r in _raw.get("darts", []):
		var g := _f(r, "gauge", "darts", 1.0)
		var mu := _i(r, "mult", "darts")
		var mg := _f(r, "magnet", "darts")
		out.append({
			"id": r.get("id", ""),
			"n": r.get("name", ""),
			"gauge": g,
			"mult": mu,
			"magnet": mg,
			"cost": _i(r, "cost", "darts"),
			"d": fill(r.get("desc", ""),
					{"gauge": g, "mult": mu, "magnet": mg}),
			"line": r.get("_line", 0),
		})
	_cache["darts"] = out
	return out


static func dart_of(id: String) -> Dictionary:
	var d := darts()
	for x in d:
		if x.id == id:
			return x
	return d[0] if not d.is_empty() else {}


# ── 스테이지 제약 ─────────────────────────────────────────
static func modifiers() -> Array:
	boot()
	if _cache.has("modifiers"):
		return _cache["modifiers"]
	var out := []
	for r in _raw.get("modifiers", []):
		var v := _f(r, "v", "modifiers")
		out.append({
			"id": r.get("id", ""),
			"n": r.get("name", ""),
			"k": r.get("axis", ""),
			"v": v,
			"w": _f(r, "weight", "modifiers", 1.0),
			"d": fill(r.get("desc", ""), {"v": v}),
			"line": r.get("_line", 0),
		})
	_cache["modifiers"] = out
	return out


# ── 판 ────────────────────────────────────────────────
# ══════════════════════════════════════════════════════════
#  판과 블라인드
# ──────────────────────────────────────────────────────────
#  발라트로 구조를 그대로 옮겼다. 8판 × 3블라인드 = 24판이다.
#  게임 쪽은 여전히 1..24 짜리 **한 개의 정수**(leg_no)만 들고 다닌다 —
#  (판, 종류) 짝을 상태로 만들면 저장·HUD·정산이 전부 두 값을 맞춰야
#  하고, 언젠가 어긋난다. 여기서 나눗셈 한 번으로 파생시킨다.
#
#      판 = (n - 1) / 3 + 1        종류 = (n - 1) % 3
#
#  목표 = 판 기본 × 블라인드 배수 × 리그 배수.
#  세 표가 각자 한 축씩만 쥔다 — rounds.csv 가 곡선을, legs.csv 가
#  판 안의 비율을, 리그이 난이도를 쥔다.
static func legs_per_round() -> int:
	var n := rows("legs").size()
	return n if n > 0 else 3


static func rounds_n() -> int:
	return rows("rounds").size()


# 전체 판 수. game.gd 의 leg_no 는 1..이 값이다.
static func legs_n() -> int:
	return rounds_n() * legs_per_round()


#  ⚠ 위 상한(legs_n)을 **일부러 걷었다.** 무한모드의 판 번호는 25 이상이라
#  clamp 가 남아 있으면 판 25 가 조용히 「라운드 8 · 보스 판」이 된다 —
#  오류가 아니라 clamp 라 아무 말이 없고, 목표는 20000 에 굳고 전부 보스라
#  못 건너뛰며 _round_boss 가 이미 끝난 24 를 가리켜 **보스 제약이 하나도
#  안 걸린다.** 「무한을 만들었는데 실은 8라운드가 무한 반복」이 그 꼴이다.
#  두 식 모두 clamp 없이 임의의 n 에서 옳고 **n <= legs_n() 에서 한 값도
#  안 다르다**(qa_endless 의 첫 단언이 그것을 기계로 잰다). 2026-09-20
static func round_of(n: int) -> int:
	var per := legs_per_round()
	@warning_ignore("integer_division")
	var a := (maxi(n, 1) - 1) / per + 1
	return a


static func leg_idx(n: int) -> int:
	return (maxi(n, 1) - 1) % legs_per_round()


#  ⚠ 아래 둘의 clampi 는 **일부러 남긴다** — 위 둘과 달리 이것은 사고가
#  아니라 **명시한 규약**이다. 무한은 rounds.csv 의 마지막 줄(라운드 8 —
#  darts 6 · aim_w 0.35 · aim_own_w 0.15 · shop_slots 4)을 계속 읽고
#  legs.csv 셋(작은·큰·보스)을 돌려 쓴다. 무한의 기울기는 endless_step ·
#  endless_accel 둘만 쥔다. 2026-09-20
static func _round_row(n: int) -> Dictionary:
	var rs := rows("rounds")
	if rs.is_empty():
		return {}
	return rs[clampi(round_of(n) - 1, 0, rs.size() - 1)]


static func leg_of(n: int) -> Dictionary:
	var rs := rows("legs")
	if rs.is_empty():
		return {}
	return rs[clampi(leg_idx(n), 0, rs.size() - 1)]


# 지금 리그의 id. 빈 값이면 흰 리그이다 — 표의 첫 행이 그 자리를 맡는다.
static var league := ""

# 지금 다트통의 id. 발라트로의 덱 자리다 — 런의 시작 조건을 쥔다.
static var pack := ""

# 이 런의 챌린지. "" 나 "none" 이면 안 건 것이다.
#
# 챌린지는 규칙 자체를 바꾸는 자리다 — 다트통이 "무엇을 들고 시작하는가"
# 라면 챌린지는 "이 런이 어떤 게임인가" 다. 그래서 표 한 장이 튜닝을
# 통째로 덮는 꼴로 만들었다. 새 계층을 파지 않고 이미 있는 손잡이를
# 민다는 것이 요점이다.
static var challenge := ""

#  이 런이 무한 구간에 들어섰는가. 기획서 P.17 의 「8라운드 클리어 이후」다.
#  **챌린지 바로 옆에 둔다** — 저장에 적는 자리도 둘이 나란하다(game.gd
#  1279 · 1439). RUN_PLAIN 에는 못 앉는다: 그 배열은 game.gd **노드의
#  속성**을 get() 으로 긁는데 이것은 여기 static var 다. 2026-09-20
static var endless := false


#  무한의 끝 라운드. 표에서 온다 — 천장(int64)부터 역산한 값이라
#  「넘치는 일이 구조에 없다」가 이 한 수의 뜻이다.
static func endless_rounds() -> int:
	return maxi(tune_i("endless_rounds"), rounds_n())


static func endless_legs_n() -> int:
	return endless_rounds() * legs_per_round()


#  지금 런의 마지막 판 번호. 무한이면 102, 아니면 24.
#  **legs_n() 을 그대로 쓰던 자리 열하나가 이것으로 바뀐다** — 안 바꾸면
#  그 자리들이 무한 구간에서 「마지막 판」·「보스 예고 없음」으로 굳는다.
static func legs_top() -> int:
	return endless_legs_n() if endless else legs_n()


static func rounds_top() -> int:
	return endless_rounds() if endless else rounds_n()


static func packs() -> Array:
	boot()
	return _raw.get("packs", [])


static func pack_row(id := "") -> Dictionary:
	var want: String = id if id != "" else pack
	var rows := packs()
	if rows.is_empty():
		return {}
	for r in rows:
		if String(r.get("id", "")) == want:
			return r
	return rows[0]                       # 빈 값·모르는 id 는 첫 다트통으로 떨어진다


static func pack_kind(row := {}) -> String:
	var r: Dictionary = row if not row.is_empty() else pack_row()
	var k: String = r.get("kind", "")
	return k if k != "" else "base"


# 다트통이 런 시작에 쥐여 주는 것들. 네 갈래를 같은 규약으로 읽는다 —
# 세미콜론으로 여럿, 빈 값이면 없다.
#   grant_item     동전  (히든 다트통이 조준 방식을 넘기는 통로)
#   grant_mod      보드 확장    (판 모양을 바꾼 채 시작한다)
#   grant_fixture  사진
#   grant_cons     사탕
#
# 다트통이 효과를 직접 들고 있지 않고 **물건으로** 준다. 그래야 그 물건이
# 사고 팔고 봉인되는 규칙 아래 놓인다 — 다트통이 직접 쥐면 런 도중에
# 얻거나 잃을 수 없고, 그러면 그 다트통은 처음부터 끝까지 같은 판이다.
static func pack_grants(key: String) -> PackedStringArray:
	var raw := String(pack_row().get(key, ""))
	if raw == "":
		return PackedStringArray()
	return raw.split(";", false)


static func score_mode() -> String:
	var m: String = pack_row().get("score", "")
	return m if m != "" else "std"


# 다트통 설명 한 줄. **문장은 사람이 쓰고 숫자는 표에서 꽂는다.**
#
# 줄글이 목록보다 읽힌다 — 처음 보는 사람은 "시작 골드 +10 · 사탕 칸 1"
# 을 두 번 읽어야 하고 "골드 14개로 시작한다. 사탕 칸은 1개다" 는 한 번
# 읽는다. 대신 손으로 쓴 문장은 표와 어긋날 수 있으므로 숫자를 직접
# 안 적는다 — items.csv·tags.csv·fixtures.csv 가 이미 쓰는 규약이고,
# 검증기가 모르는 열쇠를 막는다.
# 총량과 증감을 둘 다 낸다. 줄글이 "추가 다트 1개" 처럼 **늘고 준 것**을
# 말하므로 증감이 주로 쓰이고, 방향은 낱말이 쥔다 — 그래서 _d 는
# 절댓값이다. "다트 -1개 감소" 처럼 부호가 두 번 붙지 않게 한다.
#  score_mul 과 주는 물건·다트의 이름도 표에서 꽂는다 — 외줄의 1.6 과
#  「데칼코마니」「무거운」이 손으로 적혀 있어 표를 고치면 줄글만 옛말로 남았다.
#  이름은 grant_* 의 첫 id 다(세미콜론으로 여럿이면 줄글이 둘째를 따로 말해야 한다).
const PACK_DESC_KEYS := ["darts", "gold", "items", "cons", "dartgold",
		"darts_d", "gold_d", "items_d", "cons_d",
		"score_mul", "item_n", "fixture_n", "cons_n", "dart_n"]


static func pack_desc(row := {}) -> String:
	var r: Dictionary = row if not row.is_empty() else pack_row()
	var tpl := String(r.get("desc", ""))
	if tpl == "":
		return ""
	var isl := _i(r, "item_slots", "packs", tune_i("max_items"))
	var csl := _i(r, "cons_slots", "packs", tune_i("cons_slots"))
	return fill(tpl, {
		"darts": tune_i("darts_base") + _i(r, "darts_add", "packs", 0),
		"gold": start_gold() + _i(r, "gold_add", "packs", 0),
		"items": isl,
		"cons": csl,
		"dartgold": _i(r, "dart_gold", "packs", gold_per_dart()),
		"darts_d": absi(_i(r, "darts_add", "packs", 0)),
		"gold_d": absi(_i(r, "gold_add", "packs", 0)),
		"items_d": absi(isl - tune_i("max_items")),
		"cons_d": absi(csl - tune_i("cons_slots")),
		"score_mul": _f(r, "score_mul", "packs", 1.0),
		"item_n": row_name("items", String(r.get("grant_item", "")).get_slice(";", 0)),
		# 사진도 consumables.csv 에 산다 — 표 열쇠가 cons 다(검증기의 grant_fixture 와 같다)
		"fixture_n": row_name("cons", String(r.get("grant_fixture", "")).get_slice(";", 0)),
		"cons_n": row_name("cons", String(r.get("grant_cons", "")).get_slice(";", 0)),
		"dart_n": dart_name(String(r.get("dart_id", "std"))),
	})


static func packs_of(kind: String) -> Array:
	var out := []
	for r in packs():
		if pack_kind(r) == kind:
			out.append(r)
	return out


static func pack_v(key: String, dflt: float) -> float:
	var r := pack_row()
	if r.is_empty() or String(r.get(key, "")) == "":
		return dflt
	return _f(r, key, "packs", dflt)


# 해금·완주 키는 다트통별로 갈린다 — 발라트로도 리그을 덱마다 따로 뚫는다.
static func league_key(league_id: String, pack_id := "") -> String:
	var pk: String = pack_id if pack_id != "" else String(pack_row().get("id", ""))
	return "league:%s:%s" % [pk, league_id]


static func win_key(league_id: String, pack_id := "") -> String:
	var pk: String = pack_id if pack_id != "" else String(pack_row().get("id", ""))
	return "win:%s:%s" % [pk, league_id]


# 표에서 이 리그이 몇째 단인가. 사다리의 잠김·완주 표시가 이 번호를 읽는다.
static func league_idx(id := "") -> int:
	var want: String = id if id != "" else league
	var rows := leagues()
	for i in rows.size():
		if String(rows[i].get("id", "")) == want:
			return i
	return 0


# 표는 셋이 축을 하나씩 쥔다 — rounds 가 곡선, legs 가 판 안의 비율,
# leagues 가 난이도. 리그은 곡선을 **고르는** 것이지 곱하는 것이 아니다:
# curve 열이 rounds.csv 의 어느 열을 볼지 가리킨다(base 면 곱 없음).
static func leagues() -> Array:
	boot()
	return _raw.get("leagues", [])


static func league_row(id := "") -> Dictionary:
	var want: String = id if id != "" else league
	var rows := leagues()
	if rows.is_empty():
		return {}
	for r in rows:
		if String(r.get("id", "")) == want:
			return r
	return rows[0]                       # 빈 값·모르는 id 는 첫 단으로 떨어진다


# 리그이 미는 값 하나. 표에 없는 열을 물으면 기본값이 돌아온다.
static func challenges() -> Array:
	boot()
	var out := []
	for r in _raw.get("chal", []):
		if _b(r, "enabled", "chal"):
			out.append({"id": r.get("id", ""), "n": r.get("name", ""),
					"d": r.get("desc", ""), "row": r})
	return out


#  id 하나의 행. **모르는 id 는 빈 사전이다** — league_row/pack_row 와 달리
#  첫 행 폴백이 없다. 부르는 쪽(_run_ok)이 「표에서 사라졌는가」를 물을 수
#  있어야 하기 때문이다. 2026-09-20
static func chal_row_of(id: String) -> Dictionary:
	boot()
	var want: String = id if id != "" else "none"
	for r in _raw.get("chal", []):
		if String(r.get("id", "")) == want:
			return r
	return {}


static func chal_row() -> Dictionary:
	return chal_row_of(challenge)


#  챌린지가 걸려 있는가. "" 와 "none" 이 같은 뜻이다.
static func chal_any() -> bool:
	return challenge != "" and challenge != "none"


# 챌린지가 이 열을 밀고 있는가. 빈칸이면 기본값 그대로다 —
# 표에서 "안 건드림" 과 "0 으로 만듦" 이 갈려야 해서 빈칸을 봐야 한다.
static func chal_f(key: String, dflt: float) -> float:
	var r := chal_row()
	if r.is_empty() or String(r.get(key, "")).strip_edges() == "":
		return dflt
	return _f(r, key, "chal", dflt)


static func chal_i(key: String, dflt: int) -> int:
	return int(round(chal_f(key, float(dflt))))


static func chal_on(key: String) -> bool:
	var r := chal_row()
	return not r.is_empty() and String(r.get(key, "")).strip_edges() != ""


static func league_v(key: String, dflt: float) -> float:
	var r := league_row()
	if r.is_empty() or String(r.get(key, "")) == "":
		return dflt
	return _f(r, key, "leagues", dflt)


static func league_mul(n: int) -> float:
	var col := String(league_row().get("curve", "base"))
	if col == "base" or col == "":
		return 1.0
	var v := _f(_round_row(n), col, "rounds", 1.0)
	return v if v > 0.0 else 1.0


# 다트통이 목표를 통째로 늘리거나 줄인다. **계산 방식을 바꾸는 다트통은 이것
# 없이는 못 산다** — rounds 의 목표(40 → 105 → 220 …)가 "기본 점수 × 배수" 를
# 기준으로 잡혀 있어서, 합치는 법이 바뀌면 그 곡선이 통째로 어긋난다.
# 저울은 기본 점수가 배수보다 훨씬 큰 보통 판에서 점수를 몇 배로 올린다.
static func target_mul() -> float:
	return _f(pack_row(), "target_mul", "packs", 1.0)


# 다트통이 한 발의 **최종 점수**를 민다. 목표가 아니라 값 쪽을 미는 첫
# 손잡이다 — 목표를 낮추면 판이 쉬워지기만 하는데, 값을 키우면 한 발의
# 무게가 달라진다. 외줄 다트통이 그 자리다: 발수를 반으로 줄이고 한 발을
# 1.6배로 만든다.
#
# **합친 뒤에 곱한다.** 칸 값에 곱하면 계산 방식마다 비가 달라진다 —
# 저울은 두 값을 평균 내 제곱하므로 칸 값 1.6배가 최종 2.56배가 되고,
# 물음표는 칸 값을 버리므로 아예 아무 일도 안 일어난다. 곱하는 자리는
# game.gd 의 total 걸음 한 곳이다.
static func score_mul() -> float:
	var v := _f(pack_row(), "score_mul", "packs", 1.0)
	return v if v > 0.0 else 1.0


# ══════════════════════════════════════════════════════════
#  목표 곡선 — 표 여덟 줄이 아니라 함수 하나다
# ──────────────────────────────────────────────────────────
#  라운드 기본을 손으로 여덟 개 쳐 넣고 있었다. 그러면 곡선을 고칠 때마다
#  여덟 값의 **비**를 사람이 암산해야 하고, 실제로 그래서 모양이 뒤집혀
#  있었다 — 3차 측정이 「판 3·4 에서 62% 가 죽고 판 7~24 는 대부분 100%」
#  라고 말했다. 초반이 벽이고 후반이 공짜였다.
#
#  이제 세 손잡이가 곡선 전체를 쥔다. **모양과 크기가 갈라져 있다.**
#
#      log10 T(n) = 직선(첫값 → 끝값) + bow · 배부름(n)
#      배부름(n)  = (n-1)(N-n) / ((N-1)²/4)      양 끝 0, 한가운데 1
#
#    · curve_first  첫 판의 목표. 튜토리얼 구간을 여기 하나로 잡는다
#    · curve_last   라운드 8 기본. 첫값과의 비가 곧 런의 총 배율이다
#    · curve_bow    배부름. 0 이면 등비(직선), + 면 앞이 가파르고 뒤가 완만하다
#
#  bow 0.28 은 감이 아니라 **발라트로 라운드 1~8(300…50000)을 역산한 값**이다.
#  같은 식에 그 두 끝값을 넣으면 0.22~0.33 이 나오고, 평균이 0.28 이다.
#  그래서 이 게임의 곡선은 "발라트로와 같은 모양, 다른 크기" 가 된다 —
#  크기만 curve_last 로 따로 민다.
#
#  라운드가 여덟이 아니게 되어도 식이 안 깨진다. N 은 rounds 표의 줄 수다.
static func round_base(a: int) -> float:
	var n := rounds_n()
	var first := tune("curve_first")
	var last := tune("curve_last")
	if n <= 1 or first <= 0.0 or last <= 0.0:
		return maxf(first, 1.0)
	# 양 끝은 식을 안 태운다. 배부름이 거기서 0 이라 결과는 같아야 하는데,
	# 10^log10(x) 가 x 를 정확히 안 돌려준다 — 25 가 24.999999 로 나오면
	# 큰 판(x1.5)이 37.5 에서 37 로 떨어져 표와 화면이 1점 갈린다.
	var ai := clampi(a, 1, n)
	if ai == 1:
		return first
	if ai == n:
		return last
	var t := clampf(float(ai - 1) / float(n - 1), 0.0, 1.0)
	var lg := log(first) / log(10.0)
	var lg_end := log(last) / log(10.0)
	# 배부름은 양 끝에서 정확히 0 이다 — 두 끝값은 손잡이가 적은 그대로 선다.
	var k := float(ai - 1) * float(n - ai)
	var bow := tune("curve_bow") * k / (float((n - 1) * (n - 1)) / 4.0)
	return pow(10.0, lg + t * (lg_end - lg) + bow)


#  ── 무한 구간의 목표 곡선 ───────────────────────────────
#  기획서 P.17 이 「무한모드의 목표점수는 **함수로 설정**」이라 적은 자리다.
#
#      m = a − rounds_n()                     (무한 라운드 차수, m >= 1)
#      log10 T(a) = log10(curve_last) + m·log10(step) + log10(accel)·m(m−1)/2
#
#  로그에서 **2차식**이다 — 발라트로가 d = 1 + 0.2(ante−8) 로 만든 모양과
#  같은 갈래인데, 이중지수가 아니라 int64 안에 드는 쪽으로 눌렀다.
#
#  ⚠ **지수가 m(m−1)/2 다.** m(m+1)/2 로 쓰면 m=1 에서 가속항이 이미 붙어
#  첫 걸음이 step(1.630)이 아니라 1.724 가 된다 — 「계속」을 누른 그 라운드가
#  런에서 가장 가파른 벽이 되는 자리라 이 부호 하나가 설계의 요점이다.
#  m(m−1)/2 면 첫 걸음이 정확히 step 이고 가속은 **둘째 걸음부터** 붙는다.
#
#  ⚠ **round_base 의 N 을 늘려 무한을 내지 마라.** 그 식은 양 끝
#  (curve_first · curve_last)을 고정한 보간이라 N 을 9 로 늘리는 순간
#  **이미 지나온 라운드 1~8 의 목표가 통째로 바뀐다.** 그래서 본편 곡선을
#  한 값도 안 건드리고 그 **뒤에 이어 붙이는** 함수를 따로 낸다. 2026-09-20
static func round_base_endless(a: int) -> float:
	var n := rounds_n()
	if a <= n:
		return round_base(a)
	var m := float(mini(a, endless_rounds()) - n)
	var last := tune("curve_last")
	if last <= 0.0:
		return round_base(n)
	var lg := log(last) / log(10.0)
	var ls := log(tune("endless_step")) / log(10.0)
	var la := log(tune("endless_accel")) / log(10.0)
	return pow(10.0, lg + m * ls + la * m * (m - 1.0) * 0.5)


#  ── 큰 수를 사람이 읽게 깎는다. **깎는 자리는 여기 하나다** ──────
#  둘이 되면 표 값과 화면 값이 1 차이로 갈린다 — round_base 머리말이 이미
#  같은 사고를 적어 두었다(25 가 24.999999 로 나온 일).
#  ⚠ 돌려주는 것이 **String** 이라 구조적으로 계산에 못 들어간다 — 깎은
#  수가 다시 값이 되는 길이 없다. 표 값도 판정도 안 깎는다.
#  ⚠ 「유효숫자 둘 값 내림」으로는 글자가 **안 줄어든다** — 2.0e7 을 int 로
#  적으면 "20000000" 여덟 자다. 줄이는 것은 단위 쪽이다.
#  최대 폭 검산(12pt): 「6210조」 44px · 「256경」 36px · 「1.4억」 36px —
#  전부 상단바 목표 칸 60px 안. 2026-09-20
static func big(v: int) -> String:
	var at := tune_i("big_at")
	if absi(v) < at:
		return str(v)
	var neg: bool = v < 0
	var a := absi(v)
	#  만 1e4 · 억 1e8 · 조 1e12 · 경 1e16 — **가장 큰 단위 하나만** 쓴다.
	var units := [[10000000000000000, "경"], [1000000000000, "조"],
			[100000000, "억"], [10000, "만"]]
	for u in units:
		var d: int = int(u[0])
		if a < d:
			continue
		var m := float(a) / float(d)
		var s: String = ("%d%s" % [int(m), String(u[1])]) if m >= 10.0 			else ("%.1f%s" % [m, String(u[1])])
		return ("−" + s) if neg else s
	return str(v)


static func target_of(n: int) -> int:
	var base := round_base_endless(round_of(n))
	var m := _f(leg_of(n), "mult", "legs", 1.0)
	# 챌린지가 목표를 통째로 민다(깜깜이 0.7배). 여기 한 자리에 둔다 —
	# 보스 제약의 「문턱」은 이 위에 game.gd 의 _target_at 가 따로 올린다.
	return int(round(base * m * league_mul(n) * target_mul()
			* chal_f("target_mul", 1.0)))


static func darts_of(n: int) -> int:
	var d := _i(_round_row(n), "darts", "rounds", 0)
	return d if d > 0 else tune_i("darts_base")


# 이 판을 넘기면 받는 골드. 작은 3 · 큰 4 · 보스 5 —
# tuning 의 clear_gold 를 대신한다(그 행은 이제 이 표의 폴백이다).
static func reward_of(n: int) -> int:
	var r := _i(leg_of(n), "reward", "legs", 0)
	return r if r > 0 else tune_i("clear_gold")


static func is_boss(n: int) -> bool:
	return _b(leg_of(n), "boss", "legs")


# 뱃지 — 판을 건너뛴 값이다. 건너뛰면 점수도 골드도 없으므로 이것이
# 없으면 건너뛰기는 순손실이고 아무도 안 누른다.
#   when  now(즉시) · round(다음 판) · shop(다음 상점) · stage(다음 보스 판)
#  뱃지가 언제 값을 내는가.
#    now    건너뛰는 그 자리에서
#    leg    다음에 **던지는** 판에서 (지금 표에는 쓰는 줄이 없다)
#    shop   다음 상점에서
#    boss   이번 라운드 보스를 **넘겼을 때**. 못 넘기면 런이 끝나므로 0 이다
#
#  stage 는 걷었다 — 「다음 보스 판의 제약 고르는 자리」가 없어져
#  boss 와 글자까지 같은 뜻이 됐다(2026-09-18). 쓰는 줄은 0개였다.
const TAG_WHEN := ["now", "leg", "shop", "boss"]

#  갈래. 새 갈래를 만들면 game.gd 의 _take_tag 나 그 갈래를 꺼내 쓰는
#  자리(_spend_tags)를 같이 내야 한다 — 표에만 적으면 잠자코 아무 일도 안 난다.
#
#  dart 는 **지금 표에 쓰는 줄이 없다.** 2026-09-15 기획에서 「여벌 다트」가
#  빠졌다. 갈래와 꺼내는 자리는 남겨 둔다 — 되살리는 것이 표에 한 줄이어야
#  하고, 이것이 판을 건드리는 유일한 통로다.
#
#  picks(「여유로운 선택」 — 까는 장수를 늘린다)는 **뜻 자체가 없어져서**
#  걷었다. 고르는 화면이 사라지고 보스 판에 걸리는 장수는 「겹치기」의
#  mods_n 이 쥔다(2026-09-18). 쓰는 줄은 0개였다.
const TAG_KINDS := ["gold", "dart", "track", "candy", "photo", "item",
		"reroll", "shop", "free",
		"boss_gold", "skip_gold", "track_top", "copy"]


static func tags() -> Array:
	boot()
	return _raw.get("tags", [])


# ── 배움 ────────────────────────────────────────────────
#  처음 만난 것을 **걸음으로 나눠** 가르친다. 한 줄이 한 걸음이고
#  id 가 갈래, step 이 그 안의 차례다. id 를 게임이 부른다(_tutor).
#
#  ── 레퍼런스에서 가져온 규칙 넷 ──────────────────────
#  ① 한 걸음에 **하나만** 밝힌다(mark). 둘을 밝히면 어느 쪽을 보라는
#     말인지가 사라지고, 많이 밝히면 통제당하는 느낌이 난다.
#  ② 말하는 동안 시간을 **늦춘다**(slow). 느린 시간이 인지부하를 낮추고
#     조작 학습을 돕는다는 실험이 있다(I3D 2024). 득점처럼 한 번에
#     여러 수가 움직이는 자리일수록 더 늦춘다.
#  ③ 손님이 눌러서 넘긴다(wait tap). 시간으로 넘기면 읽는 속도가
#     사람마다 다른 것을 무시하게 된다.
#  ④ 몰아 넣지 않는다. 걸음은 **처음 만나는 그 자리**에서만 난다.
#
#  ── 문구 ────────────────────────────────────────────
#  동작이나 규칙 한 마디다. 왜 그런지는 안 적는다.
#  던지기·조준은 여기 없다 — 하단 안내(AIM_HINT)가 이미 잠금마다
#  가르치므로 같은 말을 두 곳에서 하면 둘 다 안 읽힌다.
static func tutor() -> Array:
	boot()
	return _raw.get("tutor", [])


#  한 갈래의 걸음 전부. step 차례로 준다. 없거나 다 꺼져 있으면 빈 배열이다.
static func tutor_steps(id: String) -> Array:
	var pool := []
	for r in tutor():
		if String(r.get("id", "")) == id and _b(r, "enabled", "tutor"):
			pool.append(r)
	#  step 차례로 세운다 — 표에서 줄 순서가 뒤바뀌어도 화면 차례는 안 바뀐다.
	var out := []
	for k in range(1, pool.size() + 1):
		for r in pool:
			if _i(r, "step", "tutor", 0) == k:
				out.append(r)
				break
	#  번호가 비면(검증기가 막지만) 표 순서 그대로 내준다. 데이터가
	#  틀어져도 걸음이 통째로 사라지지는 않게.
	if out.size() != pool.size():
		return pool
	return out


#  밝힐 수 있는 과녁. 게임이 이 이름을 화면 사각으로 옮긴다(_mark_rect).
#  빈 이름은 "아무 데도 안 밝힌다" 다 — 화면 전체가 주제일 때 쓴다.
const TUTOR_MARKS := ["", "leg_go", "leg_skip", "leg_boss", "board", "rack",
		"score", "chute_buy", "chute_sell", "goods", "dealer", "reroll",
		"cons"]
const TUTOR_WAITS := ["tap", "time"]


# 이 판에 걸 수 있는 뱃지 하나. 라운드가 문이고 가중치가 저울이다.
static func tag_roll(round: int) -> Dictionary:
	var pool := []
	var sum := 0.0
	for r in tags():
		if _i(r, "min_round", "tags", 1) > round:
			continue
		var w := _f(r, "weight", "tags", 1.0)
		if w <= 0.0:
			continue
		pool.append(r)
		sum += w
	if pool.is_empty():
		return {}
	var t := randf() * sum
	for r in pool:
		t -= _f(r, "weight", "tags", 1.0)
		if t <= 0.0:
			return r
	return pool[pool.size() - 1]


# ── 사진 ──────────────────────────────────────────────────
#  2026-09-10 기획서에서 사진이 1회성이 됐다. 상시 강화(바우처)이던 시절의
#  배관 — 산 목록(fixtures_own) · 축별 누적(_vou) · fixture_v/fixture_i —
#  을 통째로 걷었다. 이제 사진은 사탕과 같은 길로 손에 들어와 쓸 때 한 번
#  터지고 사라지므로, 런 내내 남는 값이 없다.

# 사진 목록. 표는 consumables.csv 로 옮겨 갔고 이 함수만 남겼다 —
# 읽는 자리가 서른 곳쯤 되는데(선반 · 컬렉션 · 개발자 판) 전부 "사진
# 목록을 달라" 는 뜻이라 여기 한 곳만 갈아 끼우면 그대로 산다.
static func fixtures() -> Array:
	var out := []
	for c in consumables():
		if String(c.get("cat", "")) != "area":
			out.append(c)
	return out


# 사탕만. consumables() 는 사탕과 사진이 한 표에 살아 둘 다 낸다 — 사탕을
# 뜻하는 자리에서 그것을 그대로 쓰면 사진이 사탕 행세를 한다. 컬렉션의
# 「사탕」 탭에 사진 여덟이 사탕 포장지를 쓰고 서 있던 것이 그 자리였다.
static func candies() -> Array:
	var out := []
	for c in consumables():
		if String(c.get("cat", "")) == "area":
			out.append(c)
	return out


#  이 id 가 사진인가. 사탕과 사진이 한 표(consumables)에 살고 **같은 칸**을
#  쓰므로, 그리는 쪽은 id 만 들고 둘을 갈라야 한다. 이름으로는 못 가른다 —
#  「구성 VIII」의 id 가 c_again 이라 v_ 로 시작하지도 않는다.
static func is_fixture(id: String) -> bool:
	boot()
	if not _cache.has("isfix"):
		var m := {}
		for c in consumables():
			m[String(c.get("id", ""))] = String(c.get("cat", "")) != "area"
		_cache["isfix"] = m
	return bool((_cache["isfix"] as Dictionary).get(id, false))


static func fixture_of(id: String) -> Dictionary:
	for f in fixtures():
		if String(f.id) == id:
			return f
	return {}


# 상점 선반에 걸 사진 하나. 2026-09-10 기획서에서 사진이 상시 강화(바우처)
# 에서 1회성으로 바뀌면서, 표가 fixtures 에서 consumables 로 옮겨 갔다.
# 선반이라는 자리 자체는 기획서에 그대로 있다 — 「사진은 상점에 0.5% 로
# 등장한다」 — 그래서 자리는 두고 무엇을 거는지만 바꾼다.
#
# 옛 바우처처럼 "이미 산 것" 을 걸러 낼 필요가 없다. 1회성이라 같은 것을
# 또 사도 뜻이 있다.
static func fixture_roll(round: int) -> Dictionary:
	var pool := []
	var sum := 0.0
	for f in consumables():
		if String(f.get("cat", "")) == "area":
			continue                       # 사탕은 제 자리로 따로 온다
		pool.append(f)
		sum += 1.0
	if pool.is_empty():
		return {}
	# 사진 표에는 가중치 열이 없다. 고르게 뽑는다 — 등장률은 선반이
	# 라운드마다 하나만 걸리는 것으로 이미 좁혀져 있다.
	return pool[randi() % pool.size()]


static func skippable(n: int) -> bool:
	return _b(leg_of(n), "skippable", "legs")


static func leg_name(n: int) -> String:
	return String(leg_of(n).get("name", ""))


# 상점은 판 N 을 클리어한 뒤 N+1 을 위해 열린다. 판 표는 판당 한 줄뿐이라
# 옛 rounds.csv 처럼 "마지막 행을 비워 둔다" 는 규약이 필요 없다 — 마지막
# 판이면 호출부가 애초에 상점을 안 연다.
static func shop_slots(n: int) -> int:
	# 테이블에 까는 자리 수다. 무엇이 그 자리에 오는지는 이 표가 안 쥔다 —
	# shop.csv 의 갈래 저울이 자리마다 따로 굴린다(기획서 P.17 「랜덤 등장」).
	# 전에는 여기서 동전 2 · 보드 확장 1 · 다트 1 로 갈래마다 칸을 못 박았다.
	# 뱃지 「매물」은 _roll_stock 이 이 값 뒤에 더한다.
	return _i(_round_row(n), "shop_slots", "rounds", 0)


#  조준 동전의 **최소** 가중치. 등급 가중치가 이보다 높으면 그대로 둔다(max).
#  그래서 교통카드(common 0.60)는 사다리 꼭대기 0.35 에도 안 걸린다 —
#  배수였다면 이 4골드짜리가 레어 다섯과 **같은 비율로 같이** 밀려 올라가,
#  조준 칸 셋 중 둘이 이미 든 교통카드가 된다. 바닥은 그 장을 만나지도 않는다.
#  열이 없거나 칸이 비면 0.0 이라 max 가 등급 값을 고른다 = 오늘과 같은 게임.
#
#  인자는 shop_slots 와 **같은 판 번호(leg_no)** 다. 라운드 번호가 아니다 —
#  _round_row 가 안에서 round_of 를 한 번 돈다. 여기에 라운드 번호를 넣으면
#  round_of 가 두 번 돌아 R8 이 R3 으로 읽히는데, 그 어긋남은 확률이라
#  화면으로도 검사로도 안 보인다. 2026-09-18
static func aim_floor(n: int) -> float:
	return _f(_round_row(n), "aim_w", "rounds", 0.0)


#  이미 조준 동전을 든 플레이어에게 쓰는 바닥. _aim_from_items(game.gd)가
#  든 동전 **첫 장만** 읽어 둘째 장은 슬롯만 먹는다 — 여기를 낮게 둬야
#  후반 상점이 죽은 픽으로 안 덮인다. **올릴수록 나빠지는 구간**이라
#  사다리와 같은 열을 쓰면 안 된다.
#
#  0 이 아닌 것은 둘 때문이다. (a) 보스 제약 「봉인」이 앞장을 재우면
#  _aim_from_items 가 뒷장으로 넘어가므로 둘째 장이 완전한 죽은 칸이 아니다.
#  (b) 첫 상점에서 4골드 교통카드를 집은 것이 런 전체를 잠그는 함정이 되면
#  안 된다 — 갈아타는 문은 끝까지 열어 둔다. 2026-09-18
static func aim_floor_own(n: int) -> float:
	return _f(_round_row(n), "aim_own_w", "rounds", 0.0)


# 상점 자리 하나에 무엇이 오는지의 저울. rarity.csv 와 같은 어법이다 —
# 값은 서로의 비일 뿐이라 합이 1 일 필요가 없다.
static func shop_kinds() -> Array:
	boot()
	if _cache.has("shopk"):
		return _cache["shopk"]
	var out := []
	for r in _raw.get("shop", []):
		var w := _f(r, "weight", "shop", 0.0)
		if w <= 0.0:
			continue              # 0 은 "이 갈래는 상점에 안 온다" 는 뜻이다
		out.append({
			"id": String(r.get("id", "")),
			"n": String(r.get("name", "")),
			"w": w,
		})
	_cache["shopk"] = out
	return out


# ── 전역 스칼라 ───────────────────────────────────────────
static func _load_tune() -> void:
	for r in _raw.get("tuning", []):
		var k: String = r.get("key", "")
		if k == "":
			continue
		var t: String = r.get("type", "float")
		_tune[k] = _i(r, "value", "tuning") if t == "int" else _f(r, "value", "tuning")


static func tune(key: String) -> float:
	boot()
	if not _tune.has(key):
		push_error("데이터 표: tuning 에 '%s' 가 없다" % key)
		return 0.0
	return float(_tune[key])


static func tune_i(key: String) -> int:
	return int(round(tune(key)))


# game.gd 가 이름으로 부르는 것들. 표를 한 겹 가려 호출부를 짧게 둔다.
static func start_gold() -> int: return tune_i("start_gold")
static func clear_gold() -> int: return tune_i("clear_gold")
static func gold_per_dart() -> int: return tune_i("gold_per_dart")
static func interest_per() -> int: return tune_i("interest_per")
static func interest_max() -> int: return tune_i("interest_max")
static func gold_broke() -> int: return tune_i("gold_broke")
static func gold_blitz() -> int: return tune_i("gold_blitz")
static func free_rerolls() -> int: return tune_i("free_rerolls")
static func reroll_base() -> int: return tune_i("reroll_base")
static func reroll_step() -> int: return tune_i("reroll_step")
static func max_items() -> int:
	# 챌린지가 상한을 덮으면 다트통보다 그것이 이긴다 — 「홑장」은 다트통이
	# 무엇이든 한 칸이라야 그 챌린지가 성립한다.
	if chal_on("item_cap"):
		return maxi(1, chal_i("item_cap", 5))
	return int(pack_v("item_slots", float(tune_i("max_items"))))
static func sector_max() -> int: return tune_i("sector_max")
static func val_max_mul() -> float: return tune("val_max_mul")


# ══════════════════════════════════════════════════════════
#  표로 안 뺀 것 — 술어와 기하
# ══════════════════════════════════════════════════════════

# 판의 기본 모양. 1행짜리라 CSV 로 얻는 것이 없고, "길이 20" 계약은
# 어차피 hit_info 에 남는다.
# 칸 색 — 발라트로의 문양 자리다. 판의 좌/우·홀/짝·대/소는 전부 위치와
# 칸 값에서 파생되므로 독립축이 아니다(값을 바꾸면 홀짝과 대소가 같이
# 바뀐다). 기하와 무관하고 다시 칠할 수 있는 넷째 속성이 필요했다.
# 기본 배치는 실물 다트판대로 밝은 칸·어두운 칸 교대다 — 지금 화면과
# 한 픽셀도 안 달라진다.
static func colors() -> Array:
	boot()
	return _raw.get("colors", [])


static func color_n() -> int:
	return maxi(1, colors().size())


static func color_hex(i: int) -> String:
	var c := colors()
	if i < 0 or i >= c.size():
		return "e8dfc8"
	return String(c[i].get("hex", "e8dfc8"))


static func color_name(i: int) -> String:
	var c := colors()
	if i < 0 or i >= c.size():
		return ""
	return String(c[i].get("name", ""))


#  기본 칸 색 — 크림 · 먹이 번갈아 선다. 칸 수를 받는다(피자는 여덟 조각).
static func colors_base(n: int = SECTORS_BASE.size()) -> Array:
	var out := []
	for i in n:
		out.append(i % 2)
	return out


const SECTORS_BASE := [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]
const BOARD_BASE := {
	"bi": 0.06, "bo": 0.14,      # 한복판(50) · 불(25)
	"ti": 0.56, "to": 0.66,      # 트리플 띠
	"t2i": 0.0, "t2o": 0.0,      # 둘째 트리플 띠. 0 이면 없다
	"din": 0.90, "dout": 1.00,   # 더블 띠 안쪽 · 판의 끝(= 빗나감 경계)
}

# 판이 성립하기 위한 순서 규칙. 밸런스 상한이 아니라 hit_info 의 if 사슬이
# 전제하는 순서 그 자체다 — bi <= bo < t2i < t2o < ti < to < din < dout
const GEO := {
	"bi_min": 0.02,     # 한복판 최소 반경
	"bull_gap": 0.02,   # 25 띠의 최소 폭. 0 이면 25 칸이 사라진다
	# 「도넛」이 불을 지우려면 여기가 내려와야 한다. 순서 규칙이 아니라
	# 넓이 바닥이라 내려도 hit_info 의 if 사슬은 그대로 선다.
	"bo_min": 0.04,
	"ti_min": 0.30,     # 띠가 판 한복판까지 기어들어오지 않게
	"band_min": 0.02,   # 링의 최소 폭
	"gap": 0.03,        # 띠와 띠 사이 단색의 최소 폭
	"eps": 0.0005,      # 0.56 - 0.03 != 0.53 인 부동소수 오차를 흡수한다
}

# 판값 — 균등 조준 다트당 기대 점수. 기하와 섹터를 한 저울에 올리는 유일한
# 숫자다. 가중치는 값이지만 적분식과 떨어지면 뜻이 죽어 여기 같이 둔다.
const VAL_W := {"bull_i": 50.0, "bull_o": 25.0, "trp": 3.0, "dbl": 2.0, "plain": 1.0}

const CONDS := ["always", "triple", "double", "band", "bull", "odd", "even", "left",
		"right", "big", "mid", "small", "same", "diff", "first", "last",
		"streak", "warm", "miss", "missp",
		# 조커 이식(2026-08-23 · 사용자 지시로 후보 시트 구현)이 들여온 조건들.
		# 패턴 조건은 완성한 **그 발부터** 선다(2026-09-02 규칙 변경).
		# 예외는 warm 하나다 — 「삼중고」(트리플 위에)와 「손맛」(트리플 뒤에)을
		# 가르는 것이 그 조건의 정체성이라 다음 발부터를 지킨다.
		"risk", "risk1", "few", "sixth",
		"pair", "trip", "quad", "pair2", "spread", "sum11",
		"zone3", "zones2", "zones4", "rezone", "sec", "col"]

# 조건 포함관계. A 가 B 를 담으면 A 로 뜨는 다트는 B 로도 뜬다.
# check() 를 고치면 여기도 같이 고친다 — 하위호환 검사의 유일한 근거다.
# 검증기는 이 표를 전이폐포로 닫은 뒤 쓴다.
const COND_SUB := {
	# always 는 빗나감 둘(miss·missp)만 빼고 전부 담는다 — check() 가 빗나간
	# 발에서 먼저 돌아서기 때문이다.
	"always": ["triple", "double", "band", "bull", "odd", "even", "left", "right",
			"big", "mid", "small", "same", "diff", "first", "last", "streak", "warm",
			"risk", "risk1", "few", "sixth", "pair", "trip", "quad", "pair2",
			"spread", "zone3", "zones2", "zones4", "rezone", "sec"],
	# risk = 배수 2 이상 또는 불. 링 둘과 불을 통째로 담는다.
	"risk": ["triple", "double", "band", "bull", "risk1"],
	"band": ["triple", "double"],
	"same": ["streak"], "streak": ["same"],   # streak>0 ⟺ same. 같은 술어다
	"diff": ["first"],                        # last_sector 는 판마다 -1 로 선다
	# 반복 횟수는 threshold 다. 넓은 쪽이 좁은 쪽을 담는다 (2 ⊇ 3 ⊇ 4).
	"pair": ["trip", "quad", "pair2"],
	"trip": ["quad"],
	"zones2": ["zones4"],
}

# 완전분할 — 같은 k 로 한 분할을 다 덮으면 합성 무조건 카드가 된다.
const COND_PART := [["left", "right"], ["odd", "even"], ["mid", "big", "small"]]
const KINDS := ["chip", "mult", "xmult", "mult_streak", "mult_rand", "save"]
const GOLDS := ["clear", "spare", "clean", "blitz", "broke", "leg", "risk50",
		"hit"]


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
	# 띠 배수는 보드 확장이 밀 수 있다(과녁 · 피자). 판이 그 값을 실어
	# 보내면 그것을 쓰고 아니면 VAL_W 의 기본을 쓴다 — 상수만 보면
	# 「피자」가 띠 배수를 1 로 내려도 판값이 안 움직여 거짓말이 된다.
	var w_trp: float = float(b.get("m_trp", VAL_W.trp))
	var w_dbl: float = float(b.get("m_dbl", VAL_W.dbl))
	var w_pln: float = float(b.get("m_sgl", VAL_W.plain))
	var w_bull: float = float(b.get("m_bull", 1.0))
	return VAL_W.bull_i * w_bull * b.bi * b.bi \
			+ VAL_W.bull_o * w_bull * (b.bo * b.bo - b.bi * b.bi) \
			+ s * (w_trp * a_trp + w_dbl * a_dbl + w_pln * a_pln)


static func board_val_max() -> float:
	return board_val(BOARD_BASE, SECTORS_BASE) * val_max_mul()


# ── 조건 판정 ─────────────────────────────────────────────
static func check(c: String, x: Dictionary) -> bool:
	# 빗나가면 명중 조건은 전부 죽는다. 예외는 빗나감을 읽는 두 술어뿐이다 —
	# miss(이번이 빗나감)와 missp(직전이 빗나감). 스펙 확정 아이템 100003이
	# "직전도 빗나갔다면 x2" 라서, 빗나간 발 위에서도 missp 는 살아야 한다.
	if x.miss:
		return c == "miss" or (c == "missp" and x.missp)
	match c:
		"always": return true
		"triple": return x.mult == 3
		"double": return x.mult == 2
		# 링이면 어디든. 불은 mult 1 이라 정의상 빠진다.
		"band": return x.mult == 2 or x.mult == 3
		# 깃발이 있으면 그것이 답이다. 없으면 옛 규칙으로 떨어진다 —
		# 프로브가 손으로 지은 문맥에는 깃발이 없다.
		"bull": return bool(x.get("bull", x.sector >= 25))
		"odd": return x.sector < 25 and x.sector % 2 == 1
		"even": return x.sector < 25 and x.sector % 2 == 0
		"left": return x.left
		"right": return not x.left
		"big": return x.sector >= 15 and x.sector < 25
		"mid": return x.sector >= 6 and x.sector <= 14
		"small": return x.sector >= 1 and x.sector <= 5
		"same": return x.same
		# 연속으로 맞춘 두 숫자의 합이 11 — 「딱정벌레의 도로」(기획서 s25)
		"sum11": return int(x.get("pair_sum", 0)) == 11
		"diff": return not x.same
		"first": return x.first
		"last": return x.last
		"streak": return x.streak > 0
		"warm": return x.warm
		"missp": return x.missp
		"risk": return x.mult >= 2 or x.sector >= 25
		"risk1": return x.get("risk1", false)
		"few": return x.get("few", false)
		"sixth": return x.get("sixth", false)
		"pair": return x.get("pair", false)
		"trip": return x.get("trip", false)
		"quad": return x.get("quad", false)
		"pair2": return x.get("pair2", false)
		"spread": return x.get("spread", false)
		"zone3": return x.get("zone3", false)
		"zones2": return x.get("zones2", false)
		"zones4": return x.get("zones4", false)
		"rezone": return x.get("rezone", false)
	if c.begins_with("sec:"):
		for t in c.substr(4).split(","):
			if x.sector == int(t):
				return true
		return false
	if c.begins_with("col:"):
		# 불·아웃은 색이 없다(-1). 칸에 꽂혀야 색 조건이 선다.
		var cv := int(x.get("col", -1))
		if cv < 0:
			return false
		for t in c.substr(4).split(","):
			if cv == int(t):
				return true
		return false
	return false


# 동전 칸 밑에 붙는 짧은 말. cond_text 는 툴팁용 문장이라 56px 칸에서
# 가운데가 잘려 글자 조각으로 읽혔다 — 자리마다 필요한 길이가 다르므로
# 말을 둘로 나눈다. 긴 쪽이 뜻을 말하고 짧은 쪽이 자리를 지킨다.
static func cond_tag(c: String) -> String:
	match c:
		"always": return "언제나"
		"triple": return "트리플"
		"double": return "더블"
		"band": return "띠"
		"bull": return "불"
		"odd": return "홀수"
		"even": return "짝수"
		"left": return "왼쪽"
		"right": return "오른쪽"
		"big": return "15 이상"
		"mid": return "6~14"
		"small": return "5 이하"
		"same": return "같은 칸"
		"sum11": return "두 수 합 11"
		"diff": return "다른 칸"
		"first": return "첫 발"
		"last": return "막 발"
		"streak": return "연속"
		"warm": return "트리플 뒤"
		"miss": return "빗나감"
		"missp": return "직전 빗나감"
		"risk": return "더블·트리플·불"
		"risk1": return "첫 고난도"
		"few": return "다트 3 이하"
		"sixth": return "여섯째"
		"pair": return "같은 수 2"
		"trip": return "같은 수 3"
		"quad": return "같은 수 4"
		"pair2": return "두 쌍"
		"spread": return "숫자 셋"
		"zone3": return "한 영역 3"
		"zones2": return "두 영역"
		"zones4": return "네 영역"
		"rezone": return "다시 그 영역"
	if c.begins_with("sec:"):
		return c.substr(4).replace(",", "·") + "번"
	if c.begins_with("col:"):
		var nm := PackedStringArray()
		for t in c.substr(4).split(","):
			nm.append(color_name(int(t)))
		return "·".join(nm)
	return ""


static func cond_text(c: String) -> String:
	match c:
		"always": return "모든 다트"
		"triple": return "트리플 명중 시"
		"double": return "더블 명중 시"
		"band": return "더블·트리플 명중 시"
		"bull": return "불 명중 시"
		"odd": return "홀수 칸 명중 시"
		"even": return "짝수 칸 명중 시"
		"left": return "왼쪽 절반 명중 시"
		"right": return "오른쪽 절반 명중 시"
		"big": return "15 이상 칸 명중 시"
		"mid": return "6~14 칸 명중 시"
		"small": return "5 이하 칸 명중 시"
		"same": return "직전과 같은 숫자면"
		"sum11": return "직전과 합이 11이면"
		"diff": return "직전과 다른 숫자면"
		"first": return "판 첫 다트에"
		"last": return "판 마지막 다트에"
		"streak": return "연속 명중 1회마다"
		"warm": return "이번 판에 트리플을 맞힌 뒤"
		"miss": return "빗나가면"
		"missp": return "직전 발이 빗나갔으면"
		"risk": return "더블·트리플·불 명중 시"
		"risk1": return "판 첫 더블·트리플·불 명중 시"
		"few": return "판 시작 다트가 3개 이하면"
		"sixth": return "6번째 발마다"
		"pair": return "이번 판에 같은 숫자를 2회 맞힌 발부터"
		"trip": return "이번 판에 같은 숫자를 3회 맞힌 발부터"
		"quad": return "이번 판에 같은 숫자를 4회 맞힌 발부터"
		"pair2": return "이번 판에 두 숫자를 각각 2회 맞힌 발부터"
		"spread": return "이번 판에 다른 숫자 3개를 맞힌 발부터"
		"zone3": return "이번 판에 같은 영역을 3회 맞힌 발부터"
		"zones2": return "이번 판에 다른 영역 2개를 맞힌 발부터"
		"zones4": return "이번 판에 네 영역을 모두 맞힌 발부터"
		"rezone": return "이번 판에 이미 맞힌 영역을 다시 맞히면"
	if c.begins_with("sec:"):
		return c.substr(4).replace(",", "·") + "번 명중 시"
	if c.begins_with("col:"):
		var nm := PackedStringArray()
		for t in c.substr(4).split(","):
			nm.append(color_name(int(t)))
		return "·".join(nm) + " 칸 명중 시"
	return ""


# 아이템 하나가 이번 발에 내는 수. x 는 판정 문맥 + 배율 재료다.
#   streak/darts_left/items_n/gold/mag_hvy/leg_darts/low/zonehist/
#   rackval_others/empty_n/rand01
# grow 아이템의 상태는 아이템 사전의 gs 에 있다(산 순간 0). fire 성장은
# 호출 전에 gs 를 올려 두는 것이 규약이다 — 첫 발동이 gstep 을 낸다.
static func item_amt(it: Dictionary, x: Dictionary) -> int:
	var g: String = String(it.get("grow", ""))
	if g == "fire" or g == "hitmiss":
		return int(it.get("gs", 0))
	if g == "tdec" or g == "rdec":
		return maxi(0, int(it.v) - int(it.get("gstep", 0)) * int(it.get("gs", 0)))
	var v: int = it.v
	match String(it.get("k", "")):
		"mult_streak":
			return v * int(x.get("streak", 0))
		"mult_rand":
			return int(round(float(x.get("rand01", 0.0)) * float(v)))
		"xmult":
			if String(it.get("per", "")) == "empty":
				return maxi(1, int(x.get("empty_n", 0)))
			return v
	match String(it.get("per", "")):
		"darts_left": v *= int(x.get("darts_left", 0))
		"items": v *= int(x.get("items_n", 0))
		"gold": v *= int(x.get("gold", 0))
		"gold5": v *= int(x.get("gold", 0)) / 5
		"mag_hvy": v *= int(x.get("mag_hvy", 0))
		# 기본은 표가 정한다(다트통이 여벌 +1 · 넓은 동전 슬롯 -1 로 민다). 여기 6 을
		# 박아 두면 넓은 동전 슬롯이 공짜로 한 단을 받고, 여벌은 한 발을 잃고도
		# 아무것도 못 받는다.
		"missing": v *= maxi(0, int(x.get("leg_base", 6))
				- int(x.get("leg_darts", 6)))
		"low": v *= int(x.get("low", 0))
		"zonehist": v *= int(x.get("zonehist", 0))
		"rackval": v *= int(x.get("rackval_others", 0))
	return v


# 화면용 효과 문장 — per·grow 가 있으면 수 하나로는 거짓말이 되므로
# 배율의 정체를 같이 적는다.
static func eff_line(it: Dictionary) -> String:
	# 조준을 쥔 장은 점수 열이 통째로 비어 있다 — 조준이 곧 효과다.
	var am := aim_text(String(it.get("aim", "")))
	if am != "":
		# 조준 동전은 정확도를 탄창으로 산다. 그 값이 얼굴에 없으면
		# 무엇을 주고 무엇을 받는지가 카드에서 안 읽힌다.
		var ad := int(it.get("dadd", 0))
		if ad != 0:
			return "%s · 판 시작 다트 %s" % [am, _sgn(ad)]
		return am
	# 계산 방식을 쥔 장도 같다 — 조준과 한 갈래라 같은 자리에서 갈린다.
	# 이 줄이 없으면 「효과가 한 줄도 안 나온다」 검사에 걸린다. 실제로
	# 데칼코마니를 넣은 첫 부팅이 거기서 멎었다.
	var sc := score_text(String(it.get("score", "")))
	if sc != "":
		return sc
	# 점수도 배수도 없는 카드 — 골드·다트·승급이 본업이다
	if String(it.get("k", "")) == "":
		var da := int(it.get("dadd", 0))
		if da != 0:
			return "판 시작 다트 " + _sgn(da)
		if String(it.get("side", "")) == "trackup25":
			return "1/4 확률로 맞힌 트랙 강화 +1"
		if String(it.get("side", "")) == "boardkill":
			# 런 승리는 화면이 「완주」라 부른다 — 「런 클리어」는 그 말 밖이다
			return "판을 넘기면 바로 완주"
		if String(it.get("side", "")) == "bigdart":
			# 발동한 발에서만 커지고(빗나가면 안 큰다) 얻는 것은 양옆 칸 값이다(pierce_gain → 점수)
			return "명중마다 다트가 커진다 · 커진 만큼 양옆 칸 값을 점수에 더한다"
		if String(it.get("side", "")) == "carry":
			# dadd += carry_darts — 다음 판의 판 시작 다트로 얹힌다. 잔탄 골드는 그대로 받는다
			return "남은 다트 1개당 다음 판 시작 다트 +1"
		return ""     # 골드 카드 — 효과는 골드 줄이 이미 말한다
	var g: String = String(it.get("grow", ""))
	# 성장형 넷은 한 틀이다 — 「[점수|배수] +X에서 시작 · [주기] ±Y (· 0이면 파괴)」.
	# hitmiss 는 gs 가 0 에서 쌓이고, fire 는 발동 전에 gs 를 올려 첫 발동이 gstep 이다.
	# tdec 은 _wear_spent 가, rdec 은 판 끝이 0 에서 지운다.
	var stat: String = "점수" if it.k == "chip" else "배수"
	if g == "hitmiss":
		return "%s +0에서 시작 · 명중마다 +%d · 빗나가면 −%d" % [stat, it.gstep, it.gstep]
	if g == "fire":
		return "%s +%d에서 시작 · 발동마다 +%d" % [stat, it.gstep, it.gstep]
	if g == "tdec":
		return "%s +%d에서 시작 · 던질 때마다 −%d · 0이면 파괴" % [stat, it.v, it.gstep]
	if g == "rdec":
		return "%s +%d에서 시작 · 판마다 −%d · 0이면 파괴" % [stat, it.v, it.gstep]
	var base := eff_text(it.k, it.v)
	match String(it.get("per", "")):
		"darts_left": return "남은 다트 1개당 " + base
		"items": return "보유 동전 1장당 " + base
		"gold": return "보유 골드 1당 " + base
		"gold5": return "보유 골드 5당 " + base
		"mag_hvy": return "무거운 다트 1개당 " + base
		"missing": return "기본에서 줄어든 다트 1개당 " + base
		"low": return "판 최저 명중 숫자 1당 " + base
		# zone_hist 는 런 단위이고 맞힌 영역을 따른다
		"zonehist": return "맞힌 영역의 이번 런 명중 1회당 " + base
		# 값이 v × 다른 동전 판매가 합이다 — 「배수 추가」로만 찍으면 v 가 얼굴에서 사라진다
		#  「판매가 합 1당」 은 말이 걸렸다 — 판매가는 골드라 「1골드당」 이면 합까지 읽힌다
		"rackval": return "다른 동전 판매가 1골드당 " + base
		"empty": return "배수 × 빈 동전 슬롯 수 (최소 ×1)"
	if String(it.get("k2", "")) != "":
		base += " · " + eff_text(it.k2, it.v2)
	# 부가 효과는 kind 가 있어도 붙는다. 빈 kind 갈래에서만 읽으면
	# 다트를 깎는 대가가 얼굴에서 사라진다.
	var da2 := int(it.get("dadd", 0))
	if da2 != 0:
		base += " · 판 시작 다트 " + _sgn(da2)
	if String(it.get("side", "")) == "trackup25":
		base += " · 1/4 확률로 맞힌 트랙 강화 +1"
	if String(it.get("side", "")) == "boardkill":
		base += " · 판을 넘기면 완주"
	if String(it.get("side", "")) == "bigdart":
		base += " · 명중마다 다트가 커진다"
	var bn := boom_n(String(it.get("boom", "")))
	if bn > 0:
		base += " · 판마다 1/%d 확률로 파괴" % bn
	return base


# boom 열은 「rN」 = 판마다 1/N 로 부서진다. 전에는 r6 과 r1000 둘만
# 받아서 기획서의 1/2(유리 대포) · 1/10(이카로스) 을 낼 자리가 없었다 —
# 꼴이 이미 1/N 이었으므로 N 을 읽기만 하면 옛 값도 그대로 산다.
# 0 은 「안 부서진다」다.
static func boom_n(b: String) -> int:
	if not b.begins_with("r"):
		return 0
	var n := b.substr(1)
	if not n.is_valid_int():
		return 0
	return maxi(int(n), 0)


static func eff_text(k: String, v: int) -> String:
	match k:
		"chip": return "점수 +%d" % v
		"mult": return "배수 +%d" % v
		"xmult": return "배수 ×%d" % v
		"mult_streak": return "배수 +%d" % v
		"mult_rand": return "배수 +0~%d 무작위" % v
		# 발동하면 _finish_leg 가 owned 에서 지운다 — 쓰고 사라지는 것까지 적는다
		"save": return "총점이 목표의 %d%% 이상이면 실패를 막고 파괴" % v
	return ""


# 계산 방식의 짧은 이름과 하는 일.
static func score_name(m: String) -> String:
	match m:
		"std": return "기본"
		"bal": return "저울"
		"rand": return "물음표"
	return m


static func score_text(m: String) -> String:
	match m:
		"bal": return "점수와 배수를 둘의 평균으로 맞춘 뒤 곱한다"
		# rnd 걸음은 그 발의 점수·배수만 바꾼다 — 「쌓은」은 총점으로 읽혔다
		"rand": return "점수와 배수를 버리고 둘 다 1~99 무작위로 다시 뽑는다"
	return ""


# 조준 방식의 짧은 이름. 목록·화면에서 std 같은 속이름을 안 보이게 한다.
static func aim_name(m: String) -> String:
	match m:
		"std": return "기본"
		"ring": return "원"
		"tilt": return "멀미"
		"cross": return "겹"
		"drift": return "수전증"
		"place": return "명사수"
		"pull": return "단검"
		"kick": return "리볼버"
	return m


# 조준 방식이 하는 일. 조건도 배수도 아니므로 이 한 줄이 설명 전부다.
#  ── 한 문장에 한 가지만 ────────────────────────────
#  2026-09-15 제보: "설명이 좀 이상한데".
#  「튕기는 속도와 방향으로 다트를 던집니다」가 그 자리였다 — 무엇을
#  튕기는지가 없어서, 읽고 나도 손을 어디에 둘지를 모른다.
#
#  세 가지를 맞춘다.
#    ① **주어가 손님이다.** 「조준선이 기웁니다」처럼 기계를 주어로 쓰면
#       구경하는 말이 되고, 조준은 구경이 아니라 손으로 하는 일이다.
#    ② **한 문장에 한 가지.** 겹치기·되튐처럼 곁가지가 있으면 줄을
#       바꿔 뒤에 붙인다. 접속사로 이으면 앞도 뒤도 안 읽힌다.
#    ③ 끝맺음은 툴팁 전체와 같은 평서 「-다」로 통일하고, 곁가지는 「 · 」로
#       잇는다. 표 안에서 어미가 섞이면 한 장만 다른 사람이 쓴 것으로 읽힌다
#       (2026-09-17 — 「-니다」 넷이 명사구·「-다」 툴팁 사이에서 혼자 존댓말이었다).
static func aim_text(m: String) -> String:
	match m:
		# 원과 점은 저절로 돈다 — 손님은 두 번 잠글 뿐이다
		"ring": return "원의 크기를 잠그고 원 위를 도는 점을 잠근다"
		"tilt": return "다트마다 다른 각도로 기운 조준선을 잠근다"
		"cross": return "가로세로 조준선을 함께 잠근다"
		"drift": return "커서 둘레를 떠도는 조준점을 눌러 던진다"
		"place": return "원하는 자리를 눌러 바로 던진다"
		# _pull_vec 은 놓기 직전 0.12초의 손 속도로 날린다 — 당긴 쪽이 아니라 튕긴 쪽이다
		"pull": return "벽의 다트를 튕긴 방향과 빠르기대로 던진다"
		"kick":
			# 손으로 적은 수는 표와 어긋난다 — 표에서 꽂는다
			return "한 발이 작은 다트 %d발이 된다 · 발마다 점수의 %d%%를 받는다 · 쏠 때마다 조준이 밀린다" % [tune_i("kick_n"), int(round(tune("kick_share") * 100.0))]
	return ""


static func item_desc(it: Dictionary) -> String:
	# 조준이나 계산 방식을 쥔 장은 조건·효과 칸이 비어 있다.
	# 그 장은 **방식이 곧 효과**다.
	var am := aim_text(String(it.get("aim", "")))
	if am != "":
		return am
	var sc := score_text(String(it.get("score", "")))
	if sc != "":
		return sc
	return "%s %s" % [cond_text(it.c), eff_text(it.k, it.v)]


# 골드 반쪽은 item_desc 에 안 섞는다 — 발동 시점이 다르므로 따로 보여준다.
# 이 발이 즉시 골드를 낳는가. risk50 은 정산이 아니라 착탄에 붙으므로
# _gold_from_items 밖에 사는 유일한 골드다 — 게임과 측정기가 같은 술어를
# 읽어야 표가 거짓말을 안 한다. 게이트가 없던 동안 게임은 표의 3배를 벌었다.
static func gold_dart_hit(it: Dictionary, x: Dictionary) -> bool:
	match String(it.get("g", "")):
		"risk50":
			return int(x.get("mult", 0)) >= 2 or int(x.get("sector", 0)) >= 25
		"hit":
			# 그 기본 점수의 조건이 걸린 발마다. 조건이 이미 골드의 문이므로
			# 여기서 술어를 또 만들지 않는다 — check 하나가 둘을 다 판다.
			return check(String(it.get("c", "")), x)
	return false


static func gold_text(g: String, gv: int) -> String:
	match g:
		"clear": return "판을 넘기면 골드 +%d" % gv
		"spare": return "판을 넘기면 남은 다트 1개당 골드 +%d" % gv
		"clean": return "한 발도 안 빗나가고 판을 넘기면 골드 +%d" % gv
		"blitz": return "남은 다트 %d개 이상으로 판을 넘기면 골드 +%d" % [gold_blitz(), gv]
		"broke": return "판을 넘길 때 보유 골드 %d 이하면 골드 +%d" % [gold_broke(), gv]
		"leg": return "판마다 골드 +%d" % gv
		"risk50": return "더블·트리플·불 명중 시 1/2 확률로 골드 +%d" % gv
		# 조건은 _tip_eff 가 앞에 잇는다 — 「크림 칸 명중 시 골드 +1」
		"hit": return "골드 +%d" % gv
	return ""


# 동전 위에 얹는 짧은 태그 (원 안에는 긴 글이 안 들어간다)
static func gold_tag(g: String) -> String:
	match g:
		"clear": return "클리어"
		"spare": return "잔탄"
		"clean": return "무실책"
		"blitz": return "속공"
		"broke": return "빈털터리"
		"leg": return "정기"
		"risk50": return "위험수당"
	return ""


# ── 판매 ──────────────────────────────────────────────────
#  판매가 = 구매가의 절반(내림), 최소 2. 26종이 4/7/11/14 이므로 2/3/5/7 이다.
#  올림으로 두면 7→4, 11→6 이 되어 보통 등급의 회수율이 흔함보다 높아진다.
#  내림은 평균 회수율을 46% 로 눌러 "비싼 동전은 팔면 더 손해"를 만든다.
#
#  스프레드(구매가 − 판매가) = 2 / 4 / 6 / 7.
#  이것이 "한 정산만 빌려 쓰고 되팔기" 의 손익선이다. 골드 동전의 1회 지급(gv)이
#  이 선을 넘으면 대여가 성립한다 — 지금 넘는 것은 속사(9 vs 6) 하나뿐이고
#  그것도 계속 들고 있는 쪽이 낫다. 새 골드 동전의 gv 는 반드시 이 선과 비교한다.
static func sell_value(it: Dictionary) -> int:
	var div := maxi(1, tune_i("sell_div"))
	@warning_ignore("integer_division")  # 내림이 의도다 — 위 주석 참조
	return maxi(tune_i("sell_min"), int(it.cost) / div)


# ══════════════════════════════════════════════════════════
#  검증
#
#  CSV 에는 컴파일이 없다. 이 함수가 그 자리를 대신한다.
#  게임을 멈추지는 않는다 — 무엇이 틀렸는지 전부 모아 두고 계속 간다.
# ══════════════════════════════════════════════════════════
static func _validate() -> void:
	_v_tuning()
	_v_items()
	_v_mods()
	_v_darts()
	_v_modifiers()
	_v_legs()
	_v_shop()
	_v_cross()
	_v_spec()
	_v_stats()
	_v_stakes()
	_v_packs()
	_v_colors()
	_v_tags()
	_v_tutor()
	_v_item_aim()


# 스펙 표 다섯 장의 무결성. 상태 열이 문이다 — 확정만 런타임이고,
# 나머지는 자리다. 여기서는 참조가 실재하는지와 필수 칸만 본다.
# item_stats 가 표 머리에 밸런스 열의 해시를 적어 둔다. 여태 쓰기만 하고
# 아무도 안 읽어서, 값을 고치고 다시 안 재면 조용히 옛 수를 보고 있었다 —
# 실제로 학교/집 병합에서 옛 사본이 올라왔고 아무 소리도 안 났다.
# 여기서 대조한다. 경고다: 표가 낡았다고 게임이 안 도는 것은 아니다.
static func _v_stats() -> void:
	var f := FileAccess.open(DIR + "_stats.csv", FileAccess.READ)
	if f == null:
		_warns.append("_stats.csv — 표가 없다. item_stats 를 한 번 돌려라")
		return
	f.get_line()                              # 머리글
	var first := f.get_line()
	f.close()
	var cols := first.split(",")
	if cols.size() < 17:
		_warns.append("_stats.csv — 열이 모자라다. 서식이 바뀌었으면 여기도 고쳐라")
		return
	var got: String = cols[16].strip_edges()
	var want := balance_hash()
	if got != want:
		_warns.append("_stats.csv — 낡았다 (표 %s · 지금 %s). item_stats 를 다시 돌려라"
				% [got, want])


# items.csv 에서 밸런스에 영향을 주는 열만 이어 붙여 해시한다. 이름이나
# _note 만 고친 커밋은 통계를 안 낡게 만든다. item_stats 가 이 함수를 써서
# 표에 적고, _v_stats 가 같은 함수로 대조한다 — 두 곳이 각자 셈하면
# 갈라지고, 갈라지면 늑대 소년이 된다.
static func balance_hash() -> String:
	var parts := PackedStringArray()
	for r in rows("items"):
		parts.append("%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
			r.get("id", ""), r.get("cond", ""), r.get("kind", ""),
			r.get("value", ""), r.get("cost", ""), r.get("gold", ""),
			r.get("gv", ""), r.get("enabled", ""),
			r.get("per", ""), r.get("k2", ""), r.get("v2", ""),
			r.get("grow", ""), r.get("gstep", ""), r.get("boom", ""),
			r.get("dadd", ""), r.get("side", ""), r.get("secs", "")])
	return "|".join(parts).md5_text().substr(0, 12)


# 리그 여덟. 순서가 곧 계단이라 prereq 가 앞 행을 가리켜야 하고, 곡선은
# rounds.csv 에 실재하는 열이어야 한다 — 오타가 나면 조용히 배수 1 이 되어
# "어려운 리그인데 안 어려운" 상태가 생긴다.
static func _v_stakes() -> void:
	var raw: Array = _raw.get("leagues", [])
	if raw.is_empty():
		_errs.append("leagues — 표가 비었다")
		return
	var round_cols := {}
	var ar: Array = _raw.get("rounds", [])
	if not ar.is_empty():
		for k in ar[0].keys():
			round_cols[String(k)] = true
	var seen := {}
	var prev := ""
	var prev_wins := 0
	for i in raw.size():
		var r: Dictionary = raw[i]
		var who := "leagues:%d %s" % [r.get("_line", 0), r.get("name", "")]
		var id: String = r.get("id", "")
		if id == "" or seen.has(id):
			_errs.append("%s — id 가 비었거나 중복이다" % who)
		seen[id] = true
		var cv: String = r.get("curve", "")
		if cv != "base" and not round_cols.has(cv):
			_errs.append("%s — 곡선 열 '%s' 가 rounds.csv 에 없다" % [who, cv])
		var pq: String = r.get("prereq", "")
		if i == 0:
			if pq != "":
				_errs.append("%s — 첫 단은 선행이 없어야 한다" % who)
		elif pq != prev:
			_errs.append("%s — 선행이 바로 앞 단(%s)이 아니다: '%s'" % [who, prev, pq])
		prev = id
		# 완주 횟수로 연다(2026-09-11 기획서 P.7). 첫 단은 늘 열려 있어야
		# 하므로 횟수가 없고, 나머지는 앞 단보다 적게 요구하면 안 된다 —
		# 적으면 그 단이 앞 단보다 먼저 열려 계단이 뒤집힌다.
		var uw := _i(r, "unlock_wins", "leagues", 0)
		if i == 0:
			if uw != 0:
				_errs.append("%s — 첫 단은 완주 횟수가 없어야 한다" % who)
		elif uw <= 0:
			_errs.append("%s — 완주 횟수가 비었다. 여는 길이 없다" % who)
		elif uw < prev_wins:
			_errs.append("%s — 앞 단(%d회)보다 적은 %d회에 열린다" % [who, prev_wins, uw])
		elif uw == prev_wins:
			_warns.append("%s — 앞 단과 같은 %d회에 열린다. 둘이 같이 열린다" % [who, uw])
		prev_wins = uw
		if _f(r, "shop_cost_mul", "leagues", 1.0) <= 0.0:
			_errs.append("%s — 테이블 가격 배수가 0 이하다" % who)
		if _i(r, "darts_add", "leagues", 0) <= -int(tune_i("darts_base")):
			_errs.append("%s — 다트 증감이 탄창을 다 없앤다" % who)
	# 계단은 한 방향이어야 한다 — 뒤 단이 앞 단보다 쉬우면 고를 이유가 없다.
	var hard := 0
	for r2 in raw:
		var h := (0 if String(r2.get("curve", "")) == "base" else 1) \
				+ _i(r2, "seal_items", "leagues", 0) \
				- _i(r2, "darts_add", "leagues", 0) \
				+ (1 if _f(r2, "shop_cost_mul", "leagues", 1.0) > 1.0 else 0) \
				+ (1 if _i(r2, "perish", "leagues", 0) > 0 else 0) \
				+ (1 if _i(r2, "rent", "leagues", 0) > 0 else 0)
		if h < hard:
			_warns.append("leagues:%d %s — 앞 단보다 무르다" % [r2.get("_line", 0), r2.get("name", "")])
		hard = maxi(hard, h)


# 다트통. 첫 행은 늘 열려 있어야 하고(런을 못 시작하면 게임이 안 돈다),
# 다트 id 는 실재해야 하며, 칸 수는 0 보다 커야 한다.
# 표의 행 이름. id 는 표의 말이지 사람의 말이 아니라, 화면에는 이름이 간다.
static func row_name(table: String, id: String) -> String:
	boot()
	for r in _raw.get(table, []):
		if String(r.get("id", "")) == id:
			return String(r.get("name", id))
	return id


static func dart_name(id: String) -> String:
	return row_name("darts", id)


static func _has_row(table: String, id: String) -> bool:
	for r in _raw.get(table, []):
		if String(r.get("id", "")) == id:
			return true
	return false


# 동전이 쥔 조준 방식. 등록 안 된 이름이면 조용히 std 로 도는 동전이
# 된다 — 히든 다트통이 통째로 아무 일도 안 하는 다트통이 되는 길이다.
#  배움 표. 빈 문구 하나가 화면에 빈 말상자로 뜨고, 모르는 과녁 하나가
#  아무 데도 안 밝히는 걸음이 된다 — 둘 다 화면에서는 "고장" 으로 읽힌다.
static func _v_tutor() -> void:
	var seen := {}          # id → 본 step 들
	for r in _raw.get("tutor", []):
		var ln: int = r.get("_line", 0)
		var id: String = String(r.get("id", "")).strip_edges()
		if id == "":
			_errs.append("tutor:%d — id 가 비었다. 게임이 부를 이름이 없다" % ln)
			continue
		var st: int = _i(r, "step", "tutor", 0)
		if st < 1:
			_errs.append("tutor:%d %s — step 이 %d 다. 1 부터 센다" % [ln, id, st])
		if not seen.has(id):
			seen[id] = {}
		if (seen[id] as Dictionary).has(st):
			_errs.append("tutor:%d %s — step %d 이 겹친다. 차례가 갈린다"
					% [ln, id, st])
		(seen[id] as Dictionary)[st] = true
		var tx: String = String(r.get("text", "")).strip_edges()
		if tx == "":
			_errs.append("tutor:%d %s — 문구가 비었다. 빈 말상자가 뜬다" % [ln, id])
		#  말상자는 두 줄까지 접는다. 40 자를 넘으면 세 줄이 되어 상자가
		#  버튼 줄을 먹는다(실측).
		elif tx.length() > 40:
			_errs.append("tutor:%d %s — 문구가 %d자다. 말상자에 40자까지 든다"
					% [ln, id, tx.length()])
		var mk: String = String(r.get("mark", ""))
		if not TUTOR_MARKS.has(mk):
			_errs.append("tutor:%d %s — 모르는 과녁 '%s'. 아무 데도 안 밝힌다"
					% [ln, id, mk])
		var wt: String = String(r.get("wait", "tap"))
		if not TUTOR_WAITS.has(wt):
			_errs.append("tutor:%d %s — 모르는 넘김 '%s'" % [ln, id, wt])
		var sl := _f(r, "slow", "tutor", 1.0)
		#  0 은 완전 정지다. 멈추면 배경 연출(상인·숨)까지 얼어 화면이
		#  죽은 것으로 보인다 — 늦추되 세우지는 않는다.
		if sl < 0.05 or sl > 1.0:
			_errs.append("tutor:%d %s — slow %.2f. 0.05~1.00 안이어야 한다"
					% [ln, id, sl])
	#  걸음이 1 부터 빈틈없이 이어지는가. 2 가 빠지면 3 이 영영 안 뜬다.
	for id2 in seen:
		var ss: Dictionary = seen[id2]
		for k in range(1, ss.size() + 1):
			if not ss.has(k):
				_errs.append("tutor %s — step %d 이 없다. 거기서 끊긴다"
						% [id2, k])


static func _v_item_aim() -> void:
	for m in AIM_MODES:
		var st: int = AIM_STAGES.get(m, 0)
		if st < 1 or st > 2:
			_errs.append("조준 %s — AIM_STAGES 에 잠그는 횟수(1 또는 2)가 없다" % m)
		if aim_text(m) == "" and m != "std":
			_errs.append("조준 %s — aim_text 에 문구가 없다. 동전이 빈 칸이 된다" % m)
		if aim_name(m) == m:
			_errs.append("조준 %s — aim_name 에 짧은 이름이 없다. 속이름이 화면에 뜬다" % m)
		var hs: Array = AIM_HINT.get(m, [])
		if hs.size() != st:
			_errs.append("조준 %s — 잠금 %d회인데 안내가 %d줄이다"
					% [m, st, hs.size()])
		for h in hs:
			if String(h).strip_edges() == "":
				_errs.append("조준 %s — 안내 한 줄이 비었다" % m)
	for r in _raw.get("items", []):
		var am: String = r.get("aim", "")
		if am != "" and not AIM_MODES.has(am):
			_errs.append("items:%d %s — 모르는 조준 방식 '%s'. AIM_MODES 에 먼저 적어라"
					% [r.get("_line", 0), r.get("name", ""), am])
		# 조준과 같은 규약이다. 등록 안 된 이름을 표에 적으면 조용히 std 로
		# 도는데, 그것이 이 시스템에서 가장 나쁜 결말이다(안개가 그랬다).
		var sm: String = r.get("score", "")
		if sm != "" and not SCORE_MODES.has(sm):
			_errs.append("items:%d %s — 모르는 계산 방식 '%s'. SCORE_MODES 에 먼저 적어라"
					% [r.get("_line", 0), r.get("name", ""), sm])
		# 해금 조건. 다트통과 같은 통계 목록을 읽는다.
		var ust: String = r.get("unlock_stat", "")
		if ust != "" and not Save_STATS.has(ust):
			_errs.append("items:%d %s — 모르는 통계 열쇠 '%s'"
					% [r.get("_line", 0), r.get("name", ""), ust])
		if ust != "" and _i(r, "unlock_v", "items", 0) <= 0:
			_errs.append("items:%d %s — 조건은 있는데 문턱(unlock_v)이 0 이다"
					% [r.get("_line", 0), r.get("name", "")])


static func _v_packs() -> void:
	var raw: Array = _raw.get("packs", [])
	if raw.is_empty():
		_errs.append("packs — 표가 비었다. 시작할 다트통이 없으면 런이 안 선다")
		return
	var dids := {}
	for d in _raw.get("darts", []):
		dids[String(d.get("id", ""))] = true
	var seen := {}
	# 앞줄(prereq)은 표 어디든 가리킬 수 있으므로 id 를 먼저 다 모은다.
	# 한 줄씩 내려가며 보면 아래를 가리킨 줄이 거짓 오류를 낸다.
	var seen_pack := {}
	for r0 in raw:
		seen_pack[String(r0.get("id", ""))] = true
	for i in raw.size():
		var r: Dictionary = raw[i]
		var who := "packs:%d %s" % [r.get("_line", 0), r.get("name", "")]
		var id: String = r.get("id", "")
		if id == "" or seen.has(id):
			_errs.append("%s — id 가 비었거나 중복이다" % who)
		seen[id] = true
		# 갈래와 변형. 등록 안 된 이름은 여기서 막는다 — 안 막으면 표에
		# 오타 하나가 조용히 기본 다트통으로 도는 히든 다트통을 만든다.
		var kind: String = r.get("kind", "")
		if kind != "" and not PACK_KINDS.has(kind):
			_errs.append("%s — 모르는 갈래 '%s'" % [who, kind])
		# 주는 것들이 실제로 표에 있는가. 없는 id 를 주면 그 다트통은 조용히
		# 아무것도 안 주고 시작한다 — 히든 다트통이 통째로 죽는 길이다.
		for gk in [["grant_item", "items"], ["grant_mod", "mods"],
				# 사진이 1회성이 되면서 표가 cons 로 옮겨 갔다 — 주는 것을
				# 찾을 자리도 같이 옮긴다.
				["grant_fixture", "cons"], ["grant_cons", "cons"]]:
			for gid in String(r.get(gk[0], "")).split(";", false):
				if not _has_row(gk[1], gid):
					_errs.append("%s — %s 에 없는 '%s' 를 준다" % [who, gk[1], gid])
		if _i(r, "dart_gold", "packs", 0) < 0:
			_errs.append("%s — 잔탄 골드가 음수다" % who)
		_v_desc(who, r.get("desc", ""), PACK_DESC_KEYS)
		# 기준선과 다른 데가 있는데 줄글이 없으면 그 다트통은 화면에서 기본
		# 다트통과 구분이 안 된다. 일당 다트통이 실제로 그랬다.
		var off := _i(r, "darts_add", "packs", 0) != 0 \
				or _i(r, "gold_add", "packs", 0) != 0 \
				or String(r.get("interest_off", "")) != "" \
				or String(r.get("dart_gold", "")) != "" \
				or (String(r.get("item_slots", "")) != ""
						and _i(r, "item_slots", "packs", 0) != tune_i("max_items")) \
				or (String(r.get("cons_slots", "")) != ""
						and _i(r, "cons_slots", "packs", 0) != tune_i("cons_slots"))
		if off and String(r.get("desc", "")) == "":
			_errs.append("%s — 기준선과 다른데 줄글이 없다" % who)
		var sm: String = r.get("score", "")
		var tm := String(r.get("target_mul", ""))
		if tm != "" and _f(r, "target_mul", "packs", 1.0) <= 0.0:
			_errs.append("%s — 목표 배수가 0 이하다" % who)
		# 합치는 법이 바뀌면 rounds 의 곡선이 어긋난다. 예전에는 오류로
		# 막았는데, 2026-09-11 기획서가 그 다트통들에 목표 배수를 안 적었다 —
		# 기획서를 따르기로 했으므로 경고로 내린다. 막는 것이 아니라
		# 「곡선이 어긋난 채로 간다」를 눈에 보이게 두는 자리다.
		if sm != "" and sm != "std" and tm == "":
			_warns.append("%s — 계산 방식이 %s 인데 목표 배수가 없다 — 곡선이 어긋난 채로 간다"
					% [who, sm])
		if sm != "" and not SCORE_MODES.has(sm):
			_errs.append("%s — 모르는 계산 방식 '%s'. SCORE_MODES 에 먼저 적어라"
					% [who, sm])
		# 히든은 조건이 있어야 히든이다. 없으면 영영 안 열린다.
		if pack_kind(r) == "hidden" and String(r.get("unlock_stat", "")) == "" 				and String(r.get("prereq", "")) == "":
			_errs.append("%s — 히든인데 여는 조건이 없다. 영영 안 열린다" % who)
		# 기본 다트통도 조건으로 열 수 있다(2026-09-09). 앞의 다섯은 체인
		# (prereq)으로 열어 처음 켠 사람이 막히지 않게 하고, 뒤는 조건으로
		# 열어 목표를 만든다 — 기획서 P.21 이 다트통마다 고유 조건을 적어
		# 둔 그 꼴이다. 둘 다 없는 기본 다트통만 막는다(표 첫 줄은 빼고).
		if pack_kind(r) == "base" and i > 0 \
				and String(r.get("unlock_stat", "")) == "" \
				and String(r.get("prereq", "")) == "":
			_errs.append("%s — 여는 길이 없다. 체인(prereq)이나 조건(unlock_stat) 하나는 있어야 한다" % who)
		var us: String = r.get("unlock_stat", "")
		if us != "" and not Save_STATS.has(us):
			_errs.append("%s — 모르는 통계 열쇠 '%s'" % [who, us])
		var uc: String = r.get("unlock_cmp", "")
		if not UNLOCK_CMPS.has(uc):
			_errs.append("%s — 모르는 비교자 '%s' (빈칸 · ge · le)" % [who, uc])
		if uc != "" and us == "":
			_errs.append("%s — 비교자만 있고 볼 통계가 없다" % who)
		# 앞줄(prereq)을 가리켰으면 그 줄이 실재해야 한다. 사슬이 곧 규칙이라
		# 없는 줄을 가리키면 그 다트통은 영영 안 열린다.
		var ppq: String = r.get("prereq", "")
		if ppq != "" and not seen_pack.has(ppq):
			_errs.append("%s — prereq 가 없는 다트통을 가리킨다: '%s'" % [who, ppq])
		if i == 0 and String(r.get("prereq", "")) != "":
			_errs.append("%s — 첫 다트통은 늘 열려 있어야 한다" % who)
		var dd: String = r.get("dart_id", "")
		if dd != "" and not dids.has(dd):
			_errs.append("%s — 다트 '%s' 가 darts.csv 에 없다" % [who, dd])
		if _i(r, "item_slots", "packs", 1) <= 0:
			_errs.append("%s — 동전 칸이 0 이하다" % who)
		# 값 배율. 0 이하면 점수가 통째로 죽는다 — 빈 칸(=1.0)과 다르다.
		if String(r.get("score_mul", "")) != "" \
				and _f(r, "score_mul", "packs", 1.0) <= 0.0:
			_errs.append("%s — score_mul 이 0 이하다" % who)
		if _i(r, "darts_add", "packs", 0) <= -int(tune_i("darts_base")):
			_errs.append("%s — 다트 증감이 탄창을 다 없앤다" % who)


# 칸 색. 표가 비면 판이 통째로 한 색이 되고 색 조건 카드가 다 죽는다.
# 그리고 col: 은 완전분할이 될 수 있다 — 색 전부를 한 카드가 쓰면
# 조건이 사라진 것과 같은데, COND_PART 는 조건 **이름** 배열이라
# 접두 패턴을 못 본다. 여기서 따로 센다.
# 뱃지. 모르는 갈래·때를 쓰면 조용히 아무 일도 안 하는 뱃지가 된다 —
# 건너뛰기를 눌렀는데 아무것도 안 오는 것이 이 표의 유일한 사고다.
static func _v_tags() -> void:
	var raw: Array = _raw.get("tags", [])
	if raw.is_empty():
		_errs.append("tags — 표가 비었다. 뱃지가 없으면 건너뛰기가 순손실이다")
		return
	var seen := {}
	var first := false
	for r in raw:
		var who := "tags:%d %s" % [r.get("_line", 0), r.get("name", "")]
		var id: String = r.get("id", "")
		if id == "" or seen.has(id):
			_errs.append("%s — id 가 비었거나 중복이다" % who)
		seen[id] = true
		if not TAG_KINDS.has(String(r.get("kind", ""))):
			_errs.append("%s — 모르는 갈래 '%s'" % [who, r.get("kind", "")])
		if not TAG_WHEN.has(String(r.get("when", ""))):
			_errs.append("%s — 모르는 때 '%s'" % [who, r.get("when", "")])
		if _i(r, "v", "tags", 0) <= 0:
			_errs.append("%s — 값이 0 이하다" % who)
		#  등급 칸. 비어 있으면 안 거른다. 오타를 내면 그 등급 동전이 하나도
		#  없는 것이 되어 **뱃지가 잠자코 빈손이 된다** — 눈으로는 못 잡는다.
		var rr := String(r.get("rarity", ""))
		if rr != "":
			if String(r.get("kind", "")) != "item":
				_errs.append("%s — 등급은 item 갈래만 쓴다 (지금 '%s')"
						% [who, r.get("kind", "")])
			var known := false
			for rw in _raw.get("rarity", []):
				if String(rw.get("id", "")) == rr:
					known = true
			if not known:
				_errs.append("%s — 모르는 등급 '%s'" % [who, rr])
		if _f(r, "weight", "tags", 0.0) <= 0.0:
			_errs.append("%s — 가중치가 0 이하라 영영 안 뜬다" % who)
		if _i(r, "min_round", "tags", 1) <= 1:
			first = true
		_v_desc(who, r.get("desc", ""), ["v"])
	if not first:
		_errs.append("tags — 라운드 1 에 뜰 수 있는 뱃지가 없다. 첫 건너뛰기가 빈손이 된다")


# 사진. 모르는 축·모르는 연산·범위 밖 값이 셋 다 같은 얼굴을 한다 —
# 표는 멀쩡한데 게임에서 아무 일도 안 일어나거나, 반대로 런이 잠긴다.


static func _v_colors() -> void:
	var raw: Array = _raw.get("colors", [])
	if raw.is_empty():
		_errs.append("colors — 표가 비었다. 칸에 색이 없으면 색 조건이 다 죽는다")
		return
	var seen := {}
	for i in raw.size():
		var r: Dictionary = raw[i]
		var who := "colors:%d %s" % [r.get("_line", 0), r.get("name", "")]
		if _i(r, "id", "colors", -1) != i:
			_errs.append("%s — id 는 0 부터 빠짐없이 이어져야 한다" % who)
		var hx: String = r.get("hex", "")
		if hx.length() != 6:
			_errs.append("%s — hex 가 여섯 자가 아니다: '%s'" % [who, hx])
		if seen.has(hx):
			_errs.append("%s — 같은 색이 둘이다: '%s'" % [who, hx])
		seen[hx] = true
	var full := raw.size()
	for it in items():
		var c: String = it.c
		if not c.begins_with("col:"):
			continue
		var toks := {}
		for t in c.substr(4).split(","):
			var v := int(t)
			if v < 0 or v >= full:
				_errs.append("items — %s(%s) 의 색 %d 가 표에 없다" % [it.n, it.id, v])
			toks[v] = true
		if toks.size() >= full:
			_errs.append("items — %s(%s) 가 색 전부를 쓴다. 조건이 없는 것과 같다"
					% [it.n, it.id])


static func _v_spec() -> void:
	var keys := {}
	for r in _raw.get("areas", []):
		var k: String = r.get("key", "")
		if keys.has(k):
			_errs.append("areas:%d — key 중복 '%s'" % [r.get("_line", 0), k])
		keys[k] = true
		if String(r.get("status", "")) != "확정":
			_warns.append("areas:%d — 확정이 아닌 행이 런타임에 실린다" % r.get("_line", 0))
	for need in ["single", "double", "triple", "bull_o", "bull_i", "out"]:
		if not keys.has(need):
			_errs.append("areas — 코드가 읽는 key '%s' 가 없다" % need)
	# 강화 트랙은 표에 줄이 **없어도 된다** — track_bonus 가 식으로 낸다.
	# 예전에는 줄이 없으면 오류였는데, 그때는 표가 유일한 길이어서 빠진
	# 트랙이 곧 "사탕을 써도 아무 일이 안 난다" 였다. 지금은 표가 **덮어쓰는**
	# 자리라, 없는 것이 기본이고 있는 것이 예외다.
	var tracks := {}
	for r in _raw.get("area_up", []):
		tracks[_i(r, "track", "area_up", 0)] = true
	# 한 트랙만 표로 덮으면 다른 트랙과 규칙이 갈린다. 막지는 않되 말은 한다.
	if not tracks.is_empty():
		var all_t := {}
		for r in _raw.get("areas", []):
			var t2 := _i(r, "track", "areas", 0)
			if t2 > 0:
				all_t[t2] = true
		for t3 in all_t:
			if not tracks.has(t3):
				_warns.append("area_upgrades — 트랙 %d 만 표가 없어 식으로 간다. 트랙마다 규칙이 갈린다" % t3)
	# spec_map 의 game_id 는 실재해야 한다. 빈칸은 "자리만" 이라 넘어간다.
	var ids := {}
	for r in _raw.get("items", []):
		ids[String(r.get("id", ""))] = true
	for r in _raw.get("cons", []):
		ids[String(r.get("id", ""))] = true
	for r in _raw.get("darts", []):
		ids[String(r.get("id", ""))] = true
	for r in _raw.get("modifiers", []):
		ids[String(r.get("id", ""))] = true
	# 2026-09-10 — 스티커(proc)와 스펙 매핑(spec_map) 표를 걷었다. 옛
	# 통합 컨텍스트에서 온 자리인데 기획서에 없는 것들이라, 게임은 안 읽고
	# 이 검사만 붙들고 있었다.


static func _v_tuning() -> void:
	var seen := {}
	for r in _raw.get("tuning", []):
		var k: String = r.get("key", "")
		if seen.has(k):
			_errs.append("tuning:%d — key 중복 '%s'" % [r.get("_line", 0), k])
		seen[k] = true
		var t: String = r.get("type", "")
		if t != "int" and t != "float":
			_errs.append("tuning:%d — type 은 int 또는 float 여야 한다: '%s'" % [r.get("_line", 0), t])
		var v := _f(r, "value", "tuning")
		var lo := _f(r, "min", "tuning", -INF)
		var hi := _f(r, "max", "tuning", INF)
		if v < lo or v > hi:
			_errs.append("tuning:%d — %s = %s 가 범위 [%s, %s] 밖이다" % [r.get("_line", 0), k, v, lo, hi])
	for k in TUNE_KEYS:
		if not seen.has(k):
			_errs.append("tuning — 코드가 읽는 '%s' 가 표에 없다" % k)
	for k in seen:
		if not TUNE_KEYS.has(k):
			_warns.append("tuning — 표에만 있고 코드가 안 읽는 key '%s' (오타인가)" % k)
	# 이 프로젝트에서 유일하게 문서화된 불변식이다. 보드만 줄이면 빗나갈
	# 확률이 조용히 오른다 — 두 값을 같은 표에 두고 비를 검사한다.
	if _tune.has("board_r") and _tune.has("aim_swing") and float(_tune["board_r"]) > 0.0:
		var ratio := float(_tune["aim_swing"]) / float(_tune["board_r"])
		if absf(ratio - 1.1226) > 0.056:
			_warns.append("tuning — aim_swing/board_r = %.4f 다. 기준 1.1226 에서 5%% 넘게 벗어나면 빗나감 확률이 바뀐다" % ratio)
	# 2026-09-10 — 이 규칙을 걷었다. check("bull") 이 이제 값이 아니라
	# hit_info 가 싣는 깃발을 본다(칸 값과 불이 같은 숫자 공간을 쓰던 자리다).
	# 「피자」가 칸 값을 32 로 눕히므로 상한이 25 를 넘어야 한다.
	# 깃발 없는 문맥(손으로 지은 프로브)은 옛 규칙으로 떨어지므로,
	# 그 자리에서는 여전히 25 이상이 불로 읽힌다 — 그건 의도한 폴백이다.


static func _v_items() -> void:
	var raw: Array = _raw.get("items", [])
	var seen := {}
	var sub := _sub_closure()
	for r in raw:
		var who := "items:%d %s(%s)" % [r.get("_line", 0), r.get("name", ""), r.get("id", "")]
		var id: String = r.get("id", "")
		if seen.has(id):
			_errs.append("%s — id 중복" % who)
		seen[id] = r
		if id.length() < 3 or id.length() > 4:
			_errs.append("%s — id 는 3~4 글자여야 한다" % who)
		# 꺼진 행은 자리다 — 조커 후보 90행이 엔진 미지원으로 대기 중이라
		# 효과 칸이 비어 있다. 켜는 순간부터 아래 전부를 묻는다.
		if not _b(r, "enabled", "items"):
			continue
		# **방식**을 쥔 장은 발동 조건이 없다 — 터지는 물건이 아니라 던지고
		# 세는 방법이라 한 판 내내 켜져 있다. always 를 적으면 "모든
		# 다트마다" 라는 없는 발동이 얼굴에 뜬다.
		#
		# 조준(aim)과 계산(score)이 같은 갈래다. 둘 중 하나만 봐서는
		# 계산 방식만 쥔 장이 「효과도 부가도 없는 빈 카드」로 걸린다.
		var aimed := String(r.get("aim", "")) != "" \
				or String(r.get("score", "")) != ""
		if aimed and String(r.get("cond", "")) != "":
			_errs.append("%s — 방식을 쥔 동전에 발동 조건이 붙었다" % who)
		if not aimed and not CONDS.has(r.get("cond", "")):
			_errs.append("%s — 모르는 조건 '%s'" % [who, r.get("cond", "")])
		# 효과 없는 카드도 있다 — 골드·다트·승급만 하는 조커들. 그때는
		# 빈 kind 를 허락하되 부가 효과가 하나는 있어야 한다.
		if String(r.get("kind", "")) == "":
			if not aimed and String(r.get("gold", "")) == "" \
					and String(r.get("dadd", "")) == "" \
					and String(r.get("side", "")) == "":
				_errs.append("%s — 효과도 부가도 없는 빈 카드다" % who)
		elif not KINDS.has(r.get("kind", "")):
			_errs.append("%s — 모르는 효과 '%s'" % [who, r.get("kind", "")])
		if not RARITIES.has(r.get("rarity", "")):
			_errs.append("%s — 모르는 등급 '%s'" % [who, r.get("rarity", "")])
		# fire·hitmiss 성장은 0에서 시작하는 것이 설계다. 빈 kind 도 값이 없다.
		if String(r.get("kind", "")) != "" \
				and String(r.get("grow", "")) != "fire" 				and String(r.get("grow", "")) != "hitmiss" 				and _i(r, "value", "items") <= 0:
			_errs.append("%s — 값이 0 이하다" % who)
		if String(r.get("grow", "")) != "" \
				and not ["fire", "hitmiss", "tdec", "rdec"].has(String(r.get("grow", ""))):
			_errs.append("%s — 모르는 성장 '%s'" % [who, r.get("grow")])
		if String(r.get("cond", "")) == "sec" and String(r.get("secs", "")) == "":
			_errs.append("%s — sec 조건인데 secs 칸이 비었다" % who)
		if _i(r, "cost", "items") <= 0:
			_errs.append("%s — 가격이 0 이하다" % who)
		if String(r.get("weight", "")) != "" and _f(r, "weight", "items") <= 0.0:
			_errs.append("%s — weight 가 0 이하다" % who)
		if String(r.get("gold", "")) != "":
			if not GOLDS.has(r.get("gold")):
				_errs.append("%s — 모르는 골드 조건 '%s'" % [who, r.get("gold")])
			if _i(r, "gv", "items") <= 0:
				_errs.append("%s — 골드 값이 0 이하다" % who)
		# 등급은 가격 4단을 따르는 것이 기본이다. 어긋나면 의도적 이상치이므로
		# 근거를 요구한다 — _note 가 비어 있으면 그냥 실수다.
		#
		# 표에 없는 가격은 **그 자체가 물음**이다. 여기서 조용히 넘기고 있었고
		# 그 틈으로 5골드·8골드 짜리 다섯 장이 대조를 한 번도 안 받았다.
		# 얼굴의 단이 가격에서 나오던 시절에는 그 다섯이 틀린 단을 달고 찍혔다.
		var cst := _i(r, "cost", "items")
		var want := _rarity_of_cost(cst)
		if want == "":
			_warns.append("%s — 가격 %d 는 등급 4단(4·7·11·14) 밖이라 등급과 대조할 수 없다"
					% [who, cst])
		elif r.get("rarity", "") != want:
			if String(r.get("_note", "")).find("등급 예외") < 0:
				_warns.append("%s — 가격 %s 는 보통 %s 인데 %s 다. 이상치면 _note 에 '등급 예외' 를 적어라"
						% [who, r.get("cost"), want, r.get("rarity")])
	# 상위호환 — 같은 효과이고 조건이 상대를 담는데 값이 크고 가격이 싸면
	# 상대 카드는 영원히 안 팔린다.
	#
	# **경고지 오류가 아니다.** 값은 기획서가 쥔다(P.20~P.25). 이 검사를
	# 오류로 두었더니 기획서 값을 넣을 때마다 부팅이 막혀, 다섯 장을 내
	# 판단으로 덮어 두었었다 — 그 자리마다 _note 에 「기획서 값은 …」이
	# 적혀 있었다. 값을 맞추는 것은 저자의 일이고 이 줄은 그 자리를
	# 가리키는 일만 한다.
	for a in raw:
		if not _b(a, "enabled", "items"):
			continue
		for b in raw:
			if not _b(b, "enabled", "items"):
				continue
			if a.get("id") == b.get("id") or a.get("kind") != b.get("kind"):
				continue
			# 조준을 쥔 장끼리는 우열이 없다 — 던지는 방법이 다를 뿐이다.
			# 점수 열이 다 비어 있어서 값 비교가 전부 동점으로 읽히는데,
			# 동점은 이 검사에서 "싸고 안 밀린다" 와 같은 말이 된다.
			if String(a.get("aim", "")) != "" or String(b.get("aim", "")) != "":
				continue
			# 골드는 발동 조건이 다르면 다른 카드다 — 있냐 없냐만으로 못 가른다
			if String(a.get("gold", "")) != String(b.get("gold", "")):
				continue
			# 배율·성장·보조 효과가 다르면 값의 크고 작음이 우열이 아니다
			if String(a.get("per", "")) != String(b.get("per", "")) \
					or String(a.get("grow", "")) != String(b.get("grow", "")) 					or String(a.get("k2", "")) != String(b.get("k2", "")) 					or String(a.get("dadd", "")) != String(b.get("dadd", "")):
				continue
			if String(a.get("grow", "")) != "":
				continue
			if String(a.get("boom", "")) != String(b.get("boom", "")) \
					or String(a.get("side", "")) != String(b.get("side", "")) 					or String(a.get("secs", "")) != String(b.get("secs", "")):
				continue
			var ca: String = a.get("cond", "")
			var cb: String = b.get("cond", "")
			var covers: bool = ca == cb or (sub.has(ca) and sub[ca].has(cb))
			# 값이 클수록 센 것이 보통인데 save 는 반대다 — 그 값은 「목표의
			# 몇 %」 라 낮을수록 일찍 선다. 부등호를 그대로 두면 조건 없는
			# 목숨(값 1)이 조건 붙은 목숨(값 50)에 밀리는 것으로 읽힌다.
			var av := _i(a, "value", "items")
			var bv := _i(b, "value", "items")
			var beats: bool = av <= bv if String(a.get("kind", "")) == "save" else av >= bv
			if covers and beats \
					and _i(a, "cost", "items") <= _i(b, "cost", "items"):
				_warns.append("items — %s(%s) 가 %s(%s) 의 상위호환이다 (기획서 값)"
						% [a.get("name"), a.get("id"), b.get("name"), b.get("id")])
	# 완전분할 — 같은 효과로 한 분할을 다 덮으면 조건이 사라진 것과 같다.
	for part in COND_PART:
		for kk in KINDS:
			var cov := 0
			for cc in part:
				for r2 in raw:
					if r2.get("cond") == cc and r2.get("kind") == kk \
							and _b(r2, "enabled", "items"):
						cov += 1
						break
			if cov == part.size():
				_warns.append("items — %s 를 %s 로 다 덮는다. 두 장을 같이 사면 조건 없는 카드가 된다"
						% [part, kk])
	# 아무 동전도 안 쓰는 조건은 화면에 영영 안 나온다. 숫자를 손으로 적지 않고
	# 여기서 센다 — 손으로 적은 현황은 커밋 한 번에 낡는다.
	var used := {}
	for r3 in raw:
		if _b(r3, "enabled", "items"):
			used[r3.get("cond", "")] = true
	var idle := []
	for c in CONDS:
		if not used.has(c):
			idle.append(c)
	if not idle.is_empty():
		_warns.append("items — 어떤 동전도 안 쓰는 조건 %d종: %s" % [idle.size(), idle])


static func _rarity_of_cost(cost: int) -> String:
	# 2026-09-06 기획서가 가격을 4·8·12 로 다시 잡았다. 옛 사다리는
	# 4·7·11·14 였는데 그 시절 표가 통째로 갈렸다. 쓰는 곳은 아래 등급 대조
	# 하나뿐이라 여기만 고치면 된다.
	match cost:
		4: return "common"
		8: return "uncommon"
		12: return "rare"
		20: return "legendary"
	return ""


# COND_SUB 를 전이폐포로 닫는다. always ⊃ band ⊃ triple 이 성립하는 것이
# always 목록에 triple 이 직접 적혀 있어서일 뿐이면, 새 조건을 사이에
# 끼웠을 때 조용히 놓친다.
static func _sub_closure() -> Dictionary:
	var out := {}
	for k in COND_SUB:
		out[k] = COND_SUB[k].duplicate()
	var moved := true
	while moved:
		moved = false
		for k in out.keys():
			for c in out[k].duplicate():
				if not out.has(c):
					continue
				for g in out[c]:
					if g != k and not out[k].has(g):
						out[k].append(g)
						moved = true
	return out


static func _v_mods() -> void:
	var raw: Array = _raw.get("mods", [])
	var seen := {}
	for r in raw:
		var who := "mods:%d %s(%s)" % [r.get("_line", 0), r.get("name", ""), r.get("id", "")]
		var id: String = r.get("id", "")
		if seen.has(id):
			_errs.append("%s — id 중복" % who)
		seen[id] = r
		if id.length() != 4:
			_errs.append("%s — 보드 확장 id 는 네 글자여야 한다" % who)
		if not MOD_AXES.has(r.get("axis", "")):
			_errs.append("%s — 모르는 축 '%s'" % [who, r.get("axis", "")])
		if _i(r, "cost", "mods") <= 0:
			_errs.append("%s — 가격이 0 이하다" % who)
		# 링 폭은 예전에 합이 0 이어야 했다 — 판값이 조용히 오르는 것을
		# 막으려던 규칙인데, 2026-09-11 기획서의 「핵심」은 트리플만 넓힌다고
		# 적었다. 기획서를 따르기로 했으므로 푼다. 판값이 오르는 것은
		# board_val_max() 상한이 이미 막고 있어서 문지기가 둘일 필요가 없다.
		if r.get("axis", "") == "band":
			var sum := _f(r, "v0", "mods") + _f(r, "v1", "mods")
			if absf(sum) > 0.0005:
				_warns.append("%s — band 축의 합이 0 이 아니다 (%.3f) — 링 총 폭이 그만큼 바뀐다"
						% [who, sum])
		_v_desc(who, r.get("desc", ""), ["v0", "v1"])
	# 배타는 대칭이어야 한다. 한쪽만 적으면 사는 순서에 따라 결과가 달라진다.
	for r in raw:
		var e: String = r.get("excl", "")
		if e == "":
			continue
		if not seen.has(e):
			_errs.append("mods:%d — excl 이 없는 id 를 가리킨다: '%s'" % [r.get("_line", 0), e])
		elif seen[e].get("excl", "") != r.get("id"):
			_errs.append("mods:%d — 배타가 한쪽만 있다: %s→%s 인데 반대가 없다"
					% [r.get("_line", 0), r.get("id"), e])


static func _v_darts() -> void:
	var seen := {}
	for r in _raw.get("darts", []):
		var who := "darts:%d %s(%s)" % [r.get("_line", 0), r.get("name", ""), r.get("id", "")]
		var id: String = r.get("id", "")
		if seen.has(id):
			_errs.append("%s — id 중복" % who)
		seen[id] = true
		if _f(r, "gauge", "darts") <= 0.0:
			_errs.append("%s — 게이지 배율이 0 이하다" % who)
		var mg := _f(r, "magnet", "darts")
		if mg < 0.0 or mg >= 1.0:
			_errs.append("%s — magnet 은 0 이상 1 미만이어야 한다 (지금 %s)" % [who, mg])
		if _i(r, "cost", "darts") < 0:
			_errs.append("%s — 가격이 음수다" % who)
		_v_desc(who, r.get("desc", ""), ["gauge", "mult", "magnet"])
	# 첫 행은 기본 다트다. dart_of() 의 폴백이 여기에 걸려 있다.
	var d: Array = _raw.get("darts", [])
	if d.is_empty():
		_errs.append("darts — 표가 비었다. 기본 다트가 없으면 탄창이 안 선다")
	elif _i(d[0], "cost", "darts") != 0:
		_warns.append("darts — 첫 행은 기본 다트라 가격이 0 이어야 한다")


static func _v_modifiers() -> void:
	var raw: Array = _raw.get("modifiers", [])
	var axes := {}
	var seen_id := {}
	for r in raw:
		var who := "modifiers:%d %s(%s)" % [r.get("_line", 0), r.get("name", ""), r.get("id", "")]
		var ax: String = r.get("axis", "")
		if not MODIFIER_AXES.has(ax):
			_errs.append("%s — 모르는 축 '%s'" % [who, ax])
		axes[ax] = int(axes.get(ax, 0)) + 1
		if _f(r, "weight", "modifiers") <= 0.0:
			_errs.append("%s — weight 가 0 이하다" % who)
		if seen_id.has(r.get("id", "")):
			_errs.append("%s — id 중복" % who)
		seen_id[r.get("id", "")] = true
		if ax == "sector_kill":
			var v := _i(r, "v", "modifiers")
			if v < 0 or v >= SECTORS_BASE.size():
				_errs.append("%s — sector_kill 의 v 는 0~%d 인덱스여야 한다" % [who, SECTORS_BASE.size() - 1])
		# 아래 넷은 값의 치역이 곧 뜻이다. 범위를 벗어나면 제약이 조용히
		# 아무 일도 안 하는 카드가 된다 — 고른 사람만 손해다.
		if ax == "color_kill":
			var cv := _i(r, "v", "modifiers")
			if cv < 0 or cv >= color_n():
				_errs.append("%s — color_kill 의 v 는 0~%d 색 번호여야 한다" % [who, color_n() - 1])
		if ax == "ring_kill":
			var rv := _i(r, "v", "modifiers")
			if rv != 2 and rv != 3:
				_errs.append("%s — ring_kill 의 v 는 2(더블) 또는 3(트리플)이다" % who)
		if ax == "spin":
			var sv := _i(r, "v", "modifiers")
			if sv <= 0 or sv >= SECTORS_BASE.size():
				_errs.append("%s — spin 의 v 는 1~%d 칸이다. 0 은 안 도는 것이다"
						% [who, SECTORS_BASE.size() - 1])
		if ax == "odd_mul" or ax == "reward_mul":
			if _f(r, "v", "modifiers") < 0.0:
				_errs.append("%s — %s 의 v 가 음수다" % [who, ax])
		_v_desc(who, r.get("desc", ""), ["v"])
	# **그날이 왔다** — 「겹치기」가 한 보스에 둘을 확정으로 건다(2026-09-18).
	# 축이 겹친 둘이 같이 걸리면 뒤엣것이 mod_v 에서 안 읽힌다.
	var reused := []
	for a in axes:
		if int(axes[a]) > 1:
			reused.append(a)
	if not reused.is_empty():
		_warns.append("modifiers — 축을 둘 이상이 나눠 쓴다: %s" % [reused])
	# 한 보스에 거는 장수보다 후보가 적으면 같은 제약이 두 장 걸린다.
	# 장수는 「겹치기」의 mods_n 이 쥔다 — 표 전체의 최댓값으로 잰다.
	#  ⚠ 날 표의 열쇠는 "chal" 이다 — challenges() 가 붙인 이름이 아니다.
	var need := 1
	for c in _raw.get("chal", []):
		need = maxi(need, int(_f(c, "mods_n", "chal")))
	if raw.size() < need:
		_errs.append("modifiers — 제약이 %d종인데 한 보스에 %d장을 건다"
				% [raw.size(), need])


static func _v_legs() -> void:
	var raw: Array = _raw.get("rounds", [])
	if raw.is_empty():
		_errs.append("rounds — 표가 비었다")
		return
	# 목표 곡선은 이제 표가 아니라 함수다(round_base). 그래서 검사도 줄이
	# 아니라 **식이 뱉는 수열**에 건다 — 손잡이 셋을 아무 값으로 돌려도
	# 목표가 안 내려가고, 첫 값이 무장 없는 한 판 기댓값(6발 x 14.4 = 86)을
	# 안 넘는지를 본다. 튜토리얼 라운드가 상한의 93% 를 요구하던 것이
	# 3차 측정에서 나온 진짜 벽이었고, 그 벽을 표에서는 못 봤었다.
	var prevb := 0.0
	for a in range(1, raw.size() + 1):
		var b := round_base(a)
		if b <= prevb:
			_errs.append("rounds — 라운드 %d 목표가 안 오른다 (%.0f → %.0f). curve_bow 가 너무 크다"
					% [a, prevb, b])
		prevb = b
	var unarmed := float(tune_i("darts_base")) * 14.4
	if round_base(1) > unarmed * 0.6:
		_errs.append("tuning — curve_first %.0f 가 무장 없는 한 판 기댓값 %.0f 의 60%% 를 넘는다. 첫 라운드가 튜토리얼이 아니게 된다"
				% [round_base(1), unarmed])

	#  조준 바닥이 견줄 두 수. **숫자로 안 박는다** — 등급 저울이 바뀌면
	#  바닥의 뜻도 같이 따라가야 한다(0.35 는 「uncommon 과 동률」이라는
	#  뜻이지 0.35 라는 숫자가 아니다). item_weight 의 어법 그대로 훑는다.
	var rare_w := 0.05
	var com_w := 0.60
	for rr in _raw.get("rarity", []):
		if rr.get("id") == "rare":
			rare_w = _f(rr, "weight", "rarity", 0.05)
		elif rr.get("id") == "common":
			com_w = _f(rr, "weight", "rarity", 0.60)

	for i in raw.size():
		var r: Dictionary = raw[i]
		var who := "rounds:%d" % r.get("_line", 0)
		if _i(r, "round", "rounds") != i + 1:
			_errs.append("%s — round 는 1부터 빠짐없이 이어져야 한다" % who)
		if _i(r, "darts", "rounds") <= 0:
			_errs.append("%s — 다트가 0 이하다" % who)
		# 테이블 폭. 물건은 낙하 레인으로 자리를 잡으므로(_drop_one 이 n 을 받아
		# 레인을 벌린다) 넷이 아니어도 그림은 선다. 0 이면 상점이 통째로 비어
		# 리롤도 뱃지도 아무것도 못 한다 — 거기만 막는다. 판 표에는 "마지막
		# 행을 비운다" 규약이 없다 — 마지막 판이면 호출부가 애초에 상점을 안 연다.
		var w := _i(r, "shop_slots", "rounds")
		if w < 1:
			_errs.append("%s — 테이블 폭이 %d 다. 상점이 통째로 빈다" % [who, w])
		# 리그 배수는 1 이상이고 판을 따라 안 내려간다 — 내려가면
		# "더 어려운 리그인데 목표가 더 낮다" 가 된다.
		for col in ["curve_a", "curve_b"]:
			var m := _f(r, col, "rounds", 0.0)
			if m < 1.0:
				_errs.append("%s — %s 가 %.2f 다. 1.00 미만이면 리그이 쉬워진다" % [who, col, m])
			if i > 0 and m < _f(raw[i - 1], col, "rounds", 0.0) - 0.001:
				_errs.append("%s — %s 가 앞 판보다 낮다" % [who, col])
		#  조준 바닥. max 라 등급 값 아래로는 구조적으로 못 내려가지만, 표에
		#  그보다 낮은 수가 적히면 「표에 적힌 값이 곧 그 라운드의 저울」이라는
		#  읽기가 거짓말이 된다. 상한이 common 인 것은 조준 동전이 여섯 장뿐이라
		#  common 0.60 에 닿으면 후반 상점이 같은 얼굴만 내기 때문이다 —
		#  Luck be a Landlord 에서 레어 버프가 쌓여 커먼이 통째로 증발한 자리다.
		#  게임이 뜨기 전에 운다. 2026-09-18
		var aw := _f(r, "aim_w", "rounds", 0.0)
		var ow := _f(r, "aim_own_w", "rounds", 0.0)
		if aw < rare_w - 0.0001:
			_errs.append("%s — aim_w 가 %.2f 다. 레어 저울(%.2f) 아래면 표가 거짓말을 한다"
					% [who, aw, rare_w])
		if aw >= com_w:
			_errs.append("%s — aim_w 가 %.2f 다. 일반 저울(%.2f) 이상이면 후반 상점에서 일반이 증발한다"
					% [who, aw, com_w])
		if i > 0 and aw < _f(raw[i - 1], "aim_w", "rounds", 0.0) - 0.0001:
			_errs.append("%s — aim_w 가 앞 판보다 낮다. 사용자가 시킨 것은 「올라갈수록」이다" % who)
		if ow > aw + 0.0001:
			_errs.append("%s — aim_own_w(%.2f) 가 aim_w(%.2f) 보다 높다. 이미 든 쪽이 더 흔하면 겹침 방지가 거꾸로 선다"
					% [who, ow, aw])
		if ow < rare_w - 0.0001:
			_errs.append("%s — aim_own_w 가 %.2f 다. 레어 저울(%.2f) 아래면 오늘보다 드물어진다"
					% [who, ow, rare_w])

	var bl: Array = _raw.get("legs", [])
	if bl.is_empty():
		_errs.append("legs — 표가 비었다")
		return
	var boss := 0
	var pm := 0.0
	for r in bl:
		var who2 := "legs:%d" % r.get("_line", 0)
		var m2 := _f(r, "mult", "legs", 0.0)
		if m2 <= 0.0:
			_errs.append("%s — 배수가 0 이하다" % who2)
		if m2 < pm:
			_errs.append("%s — 배수가 앞 블라인드보다 낮다. 순서가 곧 난이도다" % who2)
		pm = m2
		if _i(r, "reward", "legs", 0) <= 0:
			_errs.append("%s — 보상이 0 이하다" % who2)
		if _b(r, "boss", "legs"):
			boss += 1
			if _b(r, "skippable", "legs"):
				_errs.append("%s — 보스는 못 건너뛴다" % who2)
	if boss != 1:
		_errs.append("legs — 보스가 %d개다. 판마다 정확히 하나여야 한다" % boss)
	# 보스에 걸 제약이 넉넉한지는 _v_modifiers 가 이미 본다.
	# 여기서는 보스가 마지막인지만 본다.
	if boss == 1 and not _b(bl[bl.size() - 1], "boss", "legs"):
		_errs.append("legs — 보스는 판의 마지막 판이어야 한다")


# 상점 갈래 저울. 여기 없는 갈래는 상점에 영영 안 뜨고, 여기 있는데
# _roll_stock 이 모르는 이름이면 자리를 뽑아 놓고 아무것도 못 담아 테이블이
# 그만큼 빈다. 그래서 이름을 게임과 같은 목록으로 못 박는다.
const SHOP_KINDS := ["item", "mod", "dart", "cons", "fix", "boost"]


static func _v_shop() -> void:
	var raw: Array = _raw.get("shop", [])
	if raw.is_empty():
		_errs.append("shop — 표가 비었다. 상점이 아무것도 못 뽑는다")
		return
	var seen := {}
	var sum := 0.0
	for r in raw:
		var who := "shop:%d" % r.get("_line", 0)
		var id := String(r.get("id", ""))
		if not SHOP_KINDS.has(id):
			_errs.append("%s — 갈래 「%s」를 게임이 모른다. %s 중 하나여야 한다"
					% [who, id, ", ".join(SHOP_KINDS)])
		if seen.has(id):
			_errs.append("%s — 갈래 「%s」가 두 줄이다" % [who, id])
		seen[id] = true
		var w := _f(r, "weight", "shop", -1.0)
		if w < 0.0:
			_errs.append("%s — 저울이 음수다" % who)
		sum += maxf(w, 0.0)
	if sum <= 0.0:
		_errs.append("shop — 저울 합이 0 이다. 상점이 아무것도 못 뽑는다")
	for k in SHOP_KINDS:
		if not seen.has(k):
			_warns.append("shop — 갈래 「%s」 줄이 없다. 그 물건은 상점에 안 뜬다" % k)
	# 사진은 기획서 P.30 이 0.5% 라고 못 박은 유일한 갈래다. 자리마다 굴리므로
	# 상점당 확률은 1-(1-p)^폭 이다. 표를 건드리면 여기서 소리가 난다.
	if seen.has("fix") and sum > 0.0:
		var fw := 0.0
		for r in raw:
			if String(r.get("id", "")) == "fix":
				fw = _f(r, "weight", "shop", 0.0)
		var slots := 0
		for rr in rows("rounds"):
			slots = maxi(slots, _i(rr, "shop_slots", "rounds"))
		var per := 1.0 - pow(1.0 - fw / sum, float(maxi(slots, 1)))
		if per > 0.02:
			_warns.append("shop — 사진이 상점당 %.2f%% 다. 기획서 P.30 은 0.5%% 다"
					% (per * 100.0))


static func _v_cross() -> void:
	# 해금 판이 상점보다 뒤면 그 동전은 영영 안 뜬다. 상점은 판 N 을
	# 클리어한 뒤 N+1 을 위해 열리므로 볼 수 있는 최소 판은 2 다.
	var n := legs_n()
	for r in _raw.get("items", []):
		if String(r.get("min_leg", "")) == "":
			continue
		var mr := _i(r, "min_leg", "items")
		if mr < 2 or mr > n:
			_errs.append("items:%d — min_leg %d 는 2~%d 여야 한다 (R1 앞에는 상점이 없다)"
					% [r.get("_line", 0), mr, n])
	for r in _raw.get("rarity", []):
		var mr2 := _i(r, "min_leg", "rarity", 1)
		if mr2 < 2 or mr2 > n:
			_errs.append("rarity:%d — min_leg %d 는 2~%d 여야 한다" % [r.get("_line", 0), mr2, n])
	# 테이블이 마르면 리롤이 같은 물건을 다시 뱉는다. 판마다 후보 수가
	# 테이블 폭보다 넉넉한지 센다 — 소유 동전이 후보에서 빠지므로 여유를 둔다.
	var need := 0
	for r in rows("rounds"):
		need = maxi(need, _i(r, "shop_slots", "rounds"))
	need += tune_i("max_items")
	for rd in range(2, n + 1):
		var cnt := 0
		for it in items():
			if item_min_leg(it) <= rd:
				cnt += 1
		if cnt < need:
			_warns.append("items — R%d 에 뜰 수 있는 동전이 %d장뿐이다. 테이블 %d칸 + 슬롯을 채우면 마른다"
					% [rd, cnt, need])
	# 얼굴에 효과가 한 줄도 안 나오는 동전 — 무슨 물건인지 모르는 채로 값을
	# 치러야 한다. gold_text 가 GOLDS 를 다 안 덮어서 실제로 두 장이 그랬다.
	# 한 줄도 없는 경우만 보면 부족하다: j138 은 dadd 가 얼굴에서 사라졌는데도
	# "점수 +250" 이 있어서 그 검사를 통과했다. 효과 열마다 대응하는 말이 있는지 센다.
	for it2 in items():
		var face := eff_line(it2)
		var gtx := gold_text(String(it2.get("g", "")), int(it2.get("gv", 0)))
		if face == "" and gtx == "":
			_errs.append("items — %s(%s) 는 화면에 효과가 한 줄도 안 나온다"
					% [it2.n, it2.id])
			continue
		# 값이 든 열은 반드시 얼굴에 흔적이 있어야 한다
		if String(it2.get("k", "")) != "" and face == "":
			_errs.append("items — %s(%s) 의 효과가 얼굴에 없다" % [it2.n, it2.id])
		if int(it2.get("dadd", 0)) != 0 and face.find("다트") < 0:
			_errs.append("items — %s(%s) 의 다트 증감이 얼굴에 없다" % [it2.n, it2.id])
		# side 는 이제 갈래가 셋이다(승급 · 보드 처치 · 커지는 다트). 각자
		# 얼굴에 남기는 말이 달라서 "강화" 하나로는 못 잡는다 — 갈래마다
		# 무엇이 보여야 하는지를 적어 둔다.
		var sd := String(it2.get("side", ""))
		if sd != "":
			var mark: String = {"trackup25": "강화", "boardkill": "완주",
					"bigdart": "커진다", "carry": "다음 판"}.get(sd, "")
			if mark == "":
				_errs.append("items — %s(%s) 의 모르는 부가 효과 '%s'"
						% [it2.n, it2.id, sd])
			elif face.find(mark) < 0:
				_errs.append("items — %s(%s) 의 부가 효과가 얼굴에 없다"
						% [it2.n, it2.id])
		if String(it2.get("boom", "")) != "" and face.find("파괴") < 0:
			_errs.append("items — %s(%s) 의 파괴 확률이 얼굴에 없다" % [it2.n, it2.id])
		if String(it2.get("g", "")) != "" and gtx == "":
			_errs.append("items — %s(%s) 의 골드가 얼굴에 없다" % [it2.n, it2.id])

	# 가중치가 0 인 동전은 테이블에 안 뜬다. 그것 자체는 잘못이 아니다 —
	# rarity 표가 레전더리를 0.00 으로 두고 「따로 얻는 길로만 온다」고
	# 적어 뒀다. 잘못은 **그 다른 길이 하나도 없을 때**다. 그때 그 장은
	# 표에 있으나 게임에 없다.
	#
	# 길은 둘이다 — 다트통이 쥐여 주거나(grant_item), 통계 조건을 채우면
	# 다음 상점에 공짜로 오거나(unlock_stat). 이 목록이 곧 「레전더리를
	# 어떻게 얻는가」의 계약이다.
	var granted := {}
	for p in _raw.get("packs", []):
		for gid in String(p.get("grant_item", "")).split(";", false):
			granted[String(gid).strip_edges()] = true
	for it in items():
		if item_weight(it) > 0.0 or granted.has(String(it.id)):
			continue
		if String(it.get("ustat", "")) != "":
			continue
		_errs.append("items — %s(%s) 는 얻는 길이 없다. 쥐여 주는 다트통도 해금 조건도 없다"
				% [it.n, it.id])


# desc 의 중괄호가 실제 열 이름과 안 맞으면 화면에 중괄호가 그대로 나간다.
static func _v_desc(who: String, tpl: String, allowed: Array) -> void:
	var i := 0
	while true:
		var a := tpl.find("{", i)
		if a < 0:
			break
		var b := tpl.find("}", a)
		if b < 0:
			_errs.append("%s — desc 의 중괄호가 안 닫혔다" % who)
			break
		var key := tpl.substr(a + 1, b - a - 1)
		if key.ends_with(":+"):
			key = key.substr(0, key.length() - 2)
		if not allowed.has(key):
			_errs.append("%s — desc 에 없는 열을 쓴다: {%s}. 쓸 수 있는 것은 %s" % [who, key, allowed])
		i = b + 1
