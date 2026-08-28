extends RefCounted

# ══════════════════════════════════════════════════════════
#  데이터 테이블 로더
#
#  수치는 res://data/ 의 표 여덟 장에 있다. 이 파일은 그 표를 읽고,
#  틀린 곳을 전부 모아 뱉고, game.gd 가 쓰는 모양으로 내준다.
#  숫자 리터럴을 여기에 다시 적지 마라 — 그 순간 출처가 둘이 된다.
#
#  표 여덟 장
#    items.csv      스티커 26   — 이 세트의 대표 표
#    rarity.csv     등급 3  — 등장 가중치의 유일한 출처
#    mods.csv       개조 8  — 판 기하를 바꾼다
#    darts.csv      다트 5  — 탄창에 드는 것
#    modifiers.csv  제약 6  — 스테이지 선택 그 자체다
#    antes.csv      라운드 8 — 목표 곡선 · 리그 배수 · 매대 폭
#    blinds.csv     블라인드 3 — 라운드 안의 배수·보상·건너뛰기
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
#    는다   — 새 cond(check + cond_text + _icon_cond 셋), 새 다트(_icon_dart),
#            새 축(mods 또는 modifiers 의 match 한 가지),
#            새 제약(_icon_modifier 한 가지 — 카드 얼굴에 그림이 있어야 한다)
# ══════════════════════════════════════════════════════════

#  익스포트 주의 — data/*.csv 는 .import 에서 importer="keep" 이어야 한다.
#  고닷 4 는 CSV 를 기본적으로 번역 파일(csv_translation)로 잡고, 그러면
#  원본 파일이 빌드에 안 실려 FileAccess.open 이 null 을 돌려준다. 즉
#  에디터에서는 멀쩡하고 익스포트한 빌드에서만 스티커가 한 장도 없다.
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
	"antes": "antes.csv",
	"blinds": "blinds.csv",
	"stakes": "stakes.csv",
	"packs": "packs.csv",
	"tuning": "tuning.csv",
	# ── HIGHTONE 스펙(2026-08-23 통합 컨텍스트)에서 온 표 ──
	# areas 는 전부 확정이라 게임이 직접 읽는다. 나머지는 상태 열이 문이다 —
	# 가안·제안·미정 행은 자리(스캐폴드)이고, 검증기가 집계만 한다.
	"areas": "areas.csv",
	"area_up": "area_upgrades.csv",
	"cons": "consumables.csv",
	"proc": "processing.csv",
	"spec_map": "spec_map.csv",
}

# tuning.csv 가 반드시 가져야 하는 열쇠. 목록이 곧 계약이다 —
# 코드가 읽는데 표에 없으면 부팅이 소리를 낸다.
const TUNE_KEYS := [
	"start_gold", "clear_gold", "gold_per_dart", "interest_per", "interest_max",
	"gold_broke", "gold_blitz", "sell_div", "sell_min",
	"free_rerolls", "reroll_base", "reroll_step", "max_items",
	"darts_base", "stage_picks",
	"board_r", "aim_swing", "sector_max", "val_max_mul",
	"gauge_speed", "resolve_beat", "confirm_hold", "fly_time", "aim_click_r",
	"cons_slots", "shop_cons", "cons_price_tmp",
]

const RARITIES := ["common", "uncommon", "rare"]
const MOD_AXES := ["band", "slide", "ring", "bull", "out", "swap", "odd"]
const MODIFIER_AXES := ["band_mul", "gauge_mul", "fog", "darts_add",
		"sector_kill", "seal_items", "target_mul"]

static var _raw := {}                # 표 이름 → Array[Dictionary] (전부 문자열)
static var _tune := {}               # key → int/float
static var _cache := {}              # 가공한 결과
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
# 되돌려 놓기 때문에, 문자열로 두면 저장 한 번에 스티커가 조용히 사라진다.
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
static func fill(tpl: String, vals: Dictionary) -> String:
	var out := tpl
	for k in vals:
		var v = vals[k]
		out = out.replace("{%s}" % k, _num(v))
		out = out.replace("{%s:+}" % k, ("+" if _pos(v) else "") + _num(v))
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


# ══════════════════════════════════════════════════════════
#  표 → 게임이 쓰는 모양
# ══════════════════════════════════════════════════════════

# ── 스티커 ────────────────────────────────────────────────────
#  열: id name rarity cond kind value cost gold gv weight min_round enabled
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
			"line": r.get("_line", 0),
		}
		if String(r.get("gold", "")) != "":
			it["g"] = r.get("gold")
			it["gv"] = _i(r, "gv", "items")
		out.append(it)
	_cache["items"] = out
	return out


# 등장 가중치와 해금 라운드. 등급이 기본을 정하고 스티커가 예외로 덮는다.
static func item_weight(it: Dictionary) -> float:
	boot()
	for r in _raw.get("items", []):
		if r.get("id") == it.id and String(r.get("weight", "")) != "":
			return _f(r, "weight", "items")
	for r in _raw.get("rarity", []):
		if r.get("id") == it.get("rarity", "common"):
			return _f(r, "weight", "rarity", 1.0)
	return 1.0


static func item_min_round(it: Dictionary) -> int:
	boot()
	for r in _raw.get("items", []):
		if r.get("id") == it.id and String(r.get("min_round", "")) != "":
			return _i(r, "min_round", "items")
	for r in _raw.get("rarity", []):
		if r.get("id") == it.get("rarity", "common"):
			return _i(r, "min_round", "rarity", 1)
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
			}
		_cache["areas"] = m
	var a: Dictionary = _cache["areas"]
	if not a.has(key):
		push_error("데이터 표: areas 에 '%s' 가 없다" % key)
		return {"base": 0, "mult": 1, "track": 0}
	return a[key]


# ── 영역 강화 (area_upgrades.csv · 수치 전부 미정) ────────
#  트랙의 1..lv 레벨 행을 합쳐 돌려준다. 지금은 모든 행의 수치 칸이 비어
#  있으므로(미정) 0 이 나온다 — 자리만 세워 둔 표다.
static func track_bonus(track: int, lv: int) -> Dictionary:
	boot()
	var out := {"s": 0, "m": 0}
	for r in _raw.get("area_up", []):
		if _i(r, "track", "area_up", 0) != track:
			continue
		if _i(r, "level", "area_up", 0) > lv:
			continue
		out.s += _i(r, "add_score", "area_up", 0)
		out.m += _i(r, "add_mult", "area_up", 0)
	return out


# ── 소비 아이템 (consumables.csv · 전부 가안) ─────────────
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
		out.append({
			"id": r.get("id", ""),
			"n": r.get("name", ""),
			"d": r.get("desc", ""),
			"cat": r.get("cat", ""),
			"track": _i(r, "track", "cons", 0),
			"cost": cost if cost > 0 else tune_i("cons_price_tmp"),
			"line": r.get("_line", 0),
		})
	_cache["cons"] = out
	return out


static func cons_slots() -> int:
	return int(pack_v("cons_slots", float(tune_i("cons_slots"))))



# ── 보드 개조 ─────────────────────────────────────────────
#  k = 효과 축. game.gd _mod_step 의 match 가 읽는 유일한 열쇠다.
#    band   링 폭 주고받기  v = [트리플 증분, 더블 증분]   합이 0 이다
#    slide  트리플 띠 이동   v = 더블 안쪽에서 띄울 간격
#    ring   트리플 띠 추가   v = [안, 밖]
#    bull   불 이중 구조     v = [한복판, 불]
#    out    판 바깥 경계     v = 새 dbl_out
#    swap   작은 칸 올리기   v = 올릴 칸 수
#    odd    짝수 칸 내리기   v = 안 씀
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
		var ps := _f(r, "pierce_side", "darts")
		var mg := _f(r, "magnet", "darts")
		out.append({
			"id": r.get("id", ""),
			"n": r.get("name", ""),
			"gauge": g,
			"mult": mu,
			"fix1": _b(r, "fix1", "darts"),
			"pierce": ps > 0.0,
			"side": ps,
			"magnet": mg,
			"cost": _i(r, "cost", "darts"),
			"d": fill(r.get("desc", ""),
					{"gauge": g, "mult": mu, "pierce_side": ps, "magnet": mg}),
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


# ── 라운드 ────────────────────────────────────────────────
# ══════════════════════════════════════════════════════════
#  라운드와 블라인드
# ──────────────────────────────────────────────────────────
#  발라트로 구조를 그대로 옮겼다. 8라운드 × 3블라인드 = 24판이다.
#  게임 쪽은 여전히 1..24 짜리 **한 개의 정수**(round_no)만 들고 다닌다 —
#  (라운드, 종류) 짝을 상태로 만들면 저장·HUD·정산이 전부 두 값을 맞춰야
#  하고, 언젠가 어긋난다. 여기서 나눗셈 한 번으로 파생시킨다.
#
#      라운드 = (n - 1) / 3 + 1        종류 = (n - 1) % 3
#
#  목표 = 라운드 기본 × 블라인드 배수 × 리그 배수.
#  세 표가 각자 한 축씩만 쥔다 — antes.csv 가 곡선을, blinds.csv 가
#  라운드 안의 비율을, 리그이 난이도를 쥔다.
static func blinds_per_ante() -> int:
	var n := rows("blinds").size()
	return n if n > 0 else 3


static func antes_n() -> int:
	return rows("antes").size()


# 전체 판 수. game.gd 의 round_no 는 1..이 값이다.
static func rounds_n() -> int:
	return antes_n() * blinds_per_ante()


static func ante_of(n: int) -> int:
	var per := blinds_per_ante()
	@warning_ignore("integer_division")
	var a := (clampi(n, 1, rounds_n()) - 1) / per + 1
	return a


static func blind_idx(n: int) -> int:
	return (clampi(n, 1, rounds_n()) - 1) % blinds_per_ante()


static func _ante_row(n: int) -> Dictionary:
	var rs := rows("antes")
	if rs.is_empty():
		return {}
	return rs[clampi(ante_of(n) - 1, 0, rs.size() - 1)]


static func blind_of(n: int) -> Dictionary:
	var rs := rows("blinds")
	if rs.is_empty():
		return {}
	return rs[clampi(blind_idx(n), 0, rs.size() - 1)]


# 지금 리그의 id. 빈 값이면 흰 리그이다 — 표의 첫 행이 그 자리를 맡는다.
static var stake := ""

# 지금 스타트팩의 id. 발라트로의 덱 자리다 — 런의 시작 조건을 쥔다.
static var pack := ""


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
	return rows[0]                       # 빈 값·모르는 id 는 첫 팩으로 떨어진다


static func pack_v(key: String, dflt: float) -> float:
	var r := pack_row()
	if r.is_empty() or String(r.get(key, "")) == "":
		return dflt
	return _f(r, key, "packs", dflt)


# 해금·완주 키는 팩별로 갈린다 — 발라트로도 리그을 덱마다 따로 뚫는다.
static func stake_key(stake_id: String, pack_id := "") -> String:
	var pk: String = pack_id if pack_id != "" else String(pack_row().get("id", ""))
	return "stake:%s:%s" % [pk, stake_id]


static func win_key(stake_id: String, pack_id := "") -> String:
	var pk: String = pack_id if pack_id != "" else String(pack_row().get("id", ""))
	return "win:%s:%s" % [pk, stake_id]


# 표에서 이 리그이 몇째 단인가. 사다리의 잠김·완주 표시가 이 번호를 읽는다.
static func stake_idx(id := "") -> int:
	var want: String = id if id != "" else stake
	var rows := stakes()
	for i in rows.size():
		if String(rows[i].get("id", "")) == want:
			return i
	return 0


# 표는 셋이 축을 하나씩 쥔다 — antes 가 곡선, blinds 가 라운드 안의 비율,
# stakes 가 난이도. 리그은 곡선을 **고르는** 것이지 곱하는 것이 아니다:
# curve 열이 antes.csv 의 어느 열을 볼지 가리킨다(base 면 곱 없음).
static func stakes() -> Array:
	boot()
	return _raw.get("stakes", [])


static func stake_row(id := "") -> Dictionary:
	var want: String = id if id != "" else stake
	var rows := stakes()
	if rows.is_empty():
		return {}
	for r in rows:
		if String(r.get("id", "")) == want:
			return r
	return rows[0]                       # 빈 값·모르는 id 는 첫 단으로 떨어진다


# 리그이 미는 값 하나. 표에 없는 열을 물으면 기본값이 돌아온다.
static func stake_v(key: String, dflt: float) -> float:
	var r := stake_row()
	if r.is_empty() or String(r.get(key, "")) == "":
		return dflt
	return _f(r, key, "stakes", dflt)


static func stake_mul(n: int) -> float:
	var col := String(stake_row().get("curve", "base"))
	if col == "base" or col == "":
		return 1.0
	var v := _f(_ante_row(n), col, "antes", 1.0)
	return v if v > 0.0 else 1.0


static func target_of(n: int) -> int:
	var base := _i(_ante_row(n), "base", "antes")
	var m := _f(blind_of(n), "mult", "blinds", 1.0)
	return int(round(float(base) * m * stake_mul(n)))


static func darts_of(n: int) -> int:
	var d := _i(_ante_row(n), "darts", "antes", 0)
	return d if d > 0 else tune_i("darts_base")


# 이 판을 넘기면 받는 골드. 작은 3 · 큰 4 · 보스 5 —
# tuning 의 clear_gold 를 대신한다(그 행은 이제 이 표의 폴백이다).
static func reward_of(n: int) -> int:
	var r := _i(blind_of(n), "reward", "blinds", 0)
	return r if r > 0 else tune_i("clear_gold")


static func is_boss(n: int) -> bool:
	return _b(blind_of(n), "boss", "blinds")


static func skippable(n: int) -> bool:
	return _b(blind_of(n), "skippable", "blinds")


static func blind_name(n: int) -> String:
	return String(blind_of(n).get("name", ""))


# 상점은 판 N 을 클리어한 뒤 N+1 을 위해 열린다. 라운드 표는 라운드당 한 줄뿐이라
# 옛 rounds.csv 처럼 "마지막 행을 비워 둔다" 는 규약이 필요 없다 — 마지막
# 판이면 호출부가 애초에 상점을 안 연다.
static func shop_of(n: int) -> Dictionary:
	var r := _ante_row(n)
	return {
		"items": _i(r, "shop_items", "antes", 0),
		"mods": _i(r, "shop_mods", "antes", 0),
		"darts": _i(r, "shop_darts", "antes", 0),
	}


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
	return int(pack_v("item_slots", float(tune_i("max_items"))))
static func stage_picks() -> int: return tune_i("stage_picks")
static func sector_max() -> int: return tune_i("sector_max")
static func val_max_mul() -> float: return tune("val_max_mul")


# ══════════════════════════════════════════════════════════
#  표로 안 뺀 것 — 술어와 기하
# ══════════════════════════════════════════════════════════

# 판의 기본 모양. 1행짜리라 CSV 로 얻는 것이 없고, "길이 20" 계약은
# 어차피 hit_info 에 남는다.
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
	"bo_min": 0.08,
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
		# "이후" 붙은 패턴 조건은 완성한 발이 아니라 그 다음 발부터 선다.
		"risk", "risk1", "few", "sixth",
		"pair", "trip", "quad", "pair2", "spread",
		"zone3", "zones2", "zones4", "rezone", "sec"]

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
	"diff": ["first"],                        # last_sector 는 라운드마다 -1 로 선다
	# 반복 횟수는 threshold 다. 넓은 쪽이 좁은 쪽을 담는다 (2 ⊇ 3 ⊇ 4).
	"pair": ["trip", "quad", "pair2"],
	"trip": ["quad"],
	"zones2": ["zones4"],
}

# 완전분할 — 같은 k 로 한 분할을 다 덮으면 합성 무조건 카드가 된다.
const COND_PART := [["left", "right"], ["odd", "even"], ["mid", "big", "small"]]
const KINDS := ["chip", "mult", "xmult", "mult_streak", "mult_rand", "save"]
const GOLDS := ["clear", "spare", "clean", "blitz", "broke", "round", "risk50"]


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
		"bull": return x.sector >= 25
		"odd": return x.sector < 25 and x.sector % 2 == 1
		"even": return x.sector < 25 and x.sector % 2 == 0
		"left": return x.left
		"right": return not x.left
		"big": return x.sector >= 15 and x.sector < 25
		"mid": return x.sector >= 6 and x.sector <= 14
		"small": return x.sector >= 1 and x.sector <= 5
		"same": return x.same
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
	return false


static func cond_text(c: String) -> String:
	match c:
		"always": return "모든 다트"
		"triple": return "트리플 명중 시"
		"double": return "더블 명중 시"
		"band": return "트리플·더블 어디든"
		"bull": return "불 명중 시"
		"odd": return "홀수 섹터 명중 시"
		"even": return "짝수 섹터 명중 시"
		"left": return "왼쪽 절반 명중 시"
		"right": return "오른쪽 절반 명중 시"
		"big": return "15 이상 섹터 명중 시"
		"mid": return "6~14 섹터 명중 시"
		"small": return "5 이하 섹터 명중 시"
		"same": return "직전과 같은 섹터면"
		"diff": return "직전과 다른 섹터면"
		"first": return "라운드 첫 다트에"
		"last": return "라운드 마지막 다트에"
		"streak": return "연속 명중 1회마다"
		"warm": return "이번 라운드에 트리플을 맞힌 뒤"
		"miss": return "빗나가면"
		"missp": return "직전 투척이 빗나갔다면"
		"risk": return "더블·트리플·불 명중 시"
		"risk1": return "라운드 첫 더블·트리플·불 명중 시"
		"few": return "이번 라운드 다트가 3개 이하면"
		"sixth": return "매 6번째 투척에"
		"pair": return "같은 숫자 2회를 맞힌 뒤"
		"trip": return "같은 숫자 3회를 맞힌 뒤"
		"quad": return "같은 숫자 4회를 맞힌 뒤"
		"pair2": return "다른 두 숫자를 각 2회 맞힌 뒤"
		"spread": return "다른 숫자 세 곳을 맞힌 뒤"
		"zone3": return "같은 영역 종류 3회를 맞힌 뒤"
		"zones2": return "다른 영역 2종을 맞힌 뒤"
		"zones4": return "네 영역을 모두 맞힌 뒤"
		"rezone": return "이미 명중한 영역을 다시 맞히면"
	if c.begins_with("sec:"):
		return c.substr(4).replace(",", "·") + "번 명중 시"
	return ""


# 아이템 하나가 이번 발에 내는 수. x 는 판정 문맥 + 배율 재료다.
#   streak/darts_left/items_n/gold/mag_hvy/round_darts/low/zonehist/
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
		"missing": v *= maxi(0, 6 - int(x.get("round_darts", 6)))
		"low": v *= int(x.get("low", 0))
		"zonehist": v *= int(x.get("zonehist", 0))
		"rackval": v *= int(x.get("rackval_others", 0))
	return v


# 화면용 효과 문장 — per·grow 가 있으면 수 하나로는 거짓말이 되므로
# 배율의 정체를 같이 적는다.
static func eff_line(it: Dictionary) -> String:
	# 점수도 배수도 없는 카드 — 골드·다트·승급이 본업이다
	if String(it.get("k", "")) == "":
		var da := int(it.get("dadd", 0))
		if da != 0:
			return "라운드 시작 다트 %+d" % da
		if String(it.get("side", "")) == "trackup25":
			return "발동 4회 중 1회, 맞은 영역 강화 +1"
		return ""     # 골드 카드 — 효과는 골드 줄이 이미 말한다
	var g: String = String(it.get("grow", ""))
	if g == "hitmiss":
		return "명중마다 배수 +%d · 빗나가면 −%d" % [it.gstep, it.gstep]
	if g == "fire":
		return "발동할 때마다 %s +%d 누적" % ["점수" if it.k == "chip" else "배수", it.gstep]
	if g == "tdec":
		return "%s +%d 에서 시작 · 던질 때마다 −%d" \
				% ["점수" if it.k == "chip" else "배수", it.v, it.gstep]
	if g == "rdec":
		return "배수 +%d 에서 시작 · 라운드마다 −%d · 0이면 파괴" % [it.v, it.gstep]
	var base := eff_text(it.k, it.v)
	match String(it.get("per", "")):
		"darts_left": return "남은 다트 1개당 " + base
		"items": return "보유 아이템 1개당 " + base
		"gold": return "보유 골드 1당 " + base
		"gold5": return "보유 골드 5당 " + base
		"mag_hvy": return "무거운 다트 1개당 " + base
		"missing": return "기본에서 줄어든 다트 1개당 " + base
		"low": return "라운드 최저 명중 숫자 1당 " + base
		"zonehist": return "이 영역의 런 누적 명중 1회당 " + base
		"rackval": return "다른 아이템 판매가 합계만큼 " + base.split(" ")[0] + " 추가"
		"empty": return "배수 × 빈 아이템 칸 수 (최소 ×1)"
	if String(it.get("k2", "")) != "":
		base += " · " + eff_text(it.k2, it.v2)
	# 부가 효과는 kind 가 있어도 붙는다. 빈 kind 갈래에서만 읽으면
	# 다트를 깎는 대가가 얼굴에서 사라진다.
	var da2 := int(it.get("dadd", 0))
	if da2 != 0:
		base += " · 라운드 시작 다트 %+d" % da2
	if String(it.get("side", "")) == "trackup25":
		base += " · 4회 중 1회 영역 강화 +1"
	if String(it.get("boom", "")) == "r6":
		base += " · 라운드마다 1/6 확률로 파괴"
	elif String(it.get("boom", "")) == "r1000":
		base += " · 라운드마다 0.1% 확률로 파괴"
	return base


static func eff_text(k: String, v: int) -> String:
	match k:
		"chip": return "점수 +%d" % v
		"mult": return "배수 +%d" % v
		"xmult": return "배수 ×%d" % v
		"mult_streak": return "배수 +%d" % v
		"mult_rand": return "배수 +0~%d 무작위" % v
		"save": return "실패 1회 방지 (총점이 목표의 %d%% 이상일 때)" % v
	return ""


static func item_desc(it: Dictionary) -> String:
	return "%s %s" % [cond_text(it.c), eff_text(it.k, it.v)]


# 골드 반쪽은 item_desc 에 안 섞는다 — 발동 시점이 다르므로 따로 보여준다.
# 이 발이 즉시 골드를 낳는가. risk50 은 정산이 아니라 착탄에 붙으므로
# _gold_from_items 밖에 사는 유일한 골드다 — 게임과 측정기가 같은 술어를
# 읽어야 표가 거짓말을 안 한다. 게이트가 없던 동안 게임은 표의 3배를 벌었다.
static func gold_dart_hit(it: Dictionary, x: Dictionary) -> bool:
	if String(it.get("g", "")) != "risk50":
		return false
	return int(x.get("mult", 0)) >= 2 or int(x.get("sector", 0)) >= 25


static func gold_text(g: String, gv: int) -> String:
	match g:
		"clear": return "클리어 시 골드 +%d" % gv
		"spare": return "남은 다트 1개당 골드 +%d" % gv
		"clean": return "한 발도 안 빗나가면 골드 +%d" % gv
		"blitz": return "남은 다트 %d개 이상이면 골드 +%d" % [gold_blitz(), gv]
		"broke": return "정산 때 보유 골드 %d 이하면 +%d" % [gold_broke(), gv]
		"round": return "라운드마다 골드 +%d" % gv
		"risk50": return "더블·트리플·불 명중 시 절반 확률로 골드 +%d" % gv
	return ""


# 스티커 위에 얹는 짧은 태그 (원 안에는 긴 글이 안 들어간다)
static func gold_tag(g: String) -> String:
	match g:
		"clear": return "클리어"
		"spare": return "잔탄"
		"clean": return "무실책"
		"blitz": return "속공"
		"broke": return "빈털터리"
		"round": return "정기"
		"risk50": return "위험수당"
	return ""


# ── 판매 ──────────────────────────────────────────────────
#  판매가 = 구매가의 절반(내림), 최소 2. 26종이 4/7/11/14 이므로 2/3/5/7 이다.
#  올림으로 두면 7→4, 11→6 이 되어 보통 등급의 회수율이 흔함보다 높아진다.
#  내림은 평균 회수율을 46% 로 눌러 "비싼 스티커는 팔면 더 손해"를 만든다.
#
#  스프레드(구매가 − 판매가) = 2 / 4 / 6 / 7.
#  이것이 "한 정산만 빌려 쓰고 되팔기" 의 손익선이다. 골드 스티커의 1회 지급(gv)이
#  이 선을 넘으면 대여가 성립한다 — 지금 넘는 것은 속사(9 vs 6) 하나뿐이고
#  그것도 계속 들고 있는 쪽이 낫다. 새 골드 스티커의 gv 는 반드시 이 선과 비교한다.
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
	_v_rounds()
	_v_cross()
	_v_spec()
	_v_stats()
	_v_stakes()
	_v_packs()


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
# antes.csv 에 실재하는 열이어야 한다 — 오타가 나면 조용히 배수 1 이 되어
# "어려운 리그인데 안 어려운" 상태가 생긴다.
static func _v_stakes() -> void:
	var raw: Array = _raw.get("stakes", [])
	if raw.is_empty():
		_errs.append("stakes — 표가 비었다")
		return
	var ante_cols := {}
	var ar: Array = _raw.get("antes", [])
	if not ar.is_empty():
		for k in ar[0].keys():
			ante_cols[String(k)] = true
	var seen := {}
	var prev := ""
	for i in raw.size():
		var r: Dictionary = raw[i]
		var who := "stakes:%d %s" % [r.get("_line", 0), r.get("name", "")]
		var id: String = r.get("id", "")
		if id == "" or seen.has(id):
			_errs.append("%s — id 가 비었거나 중복이다" % who)
		seen[id] = true
		var cv: String = r.get("curve", "")
		if cv != "base" and not ante_cols.has(cv):
			_errs.append("%s — 곡선 열 '%s' 가 antes.csv 에 없다" % [who, cv])
		var pq: String = r.get("prereq", "")
		if i == 0:
			if pq != "":
				_errs.append("%s — 첫 단은 선행이 없어야 한다" % who)
		elif pq != prev:
			_errs.append("%s — 선행이 바로 앞 단(%s)이 아니다: '%s'" % [who, prev, pq])
		prev = id
		if _f(r, "shop_cost_mul", "stakes", 1.0) <= 0.0:
			_errs.append("%s — 매대 가격 배수가 0 이하다" % who)
		if _i(r, "darts_add", "stakes", 0) <= -int(tune_i("darts_base")):
			_errs.append("%s — 다트 증감이 탄창을 다 없앤다" % who)
	# 계단은 한 방향이어야 한다 — 뒤 단이 앞 단보다 쉬우면 고를 이유가 없다.
	var hard := 0
	for r2 in raw:
		var h := (0 if String(r2.get("curve", "")) == "base" else 1) \
				+ _i(r2, "seal_items", "stakes", 0) \
				- _i(r2, "darts_add", "stakes", 0) \
				+ (1 if _f(r2, "shop_cost_mul", "stakes", 1.0) > 1.0 else 0) \
				+ (1 if _i(r2, "perish", "stakes", 0) > 0 else 0) \
				+ (1 if _i(r2, "rent", "stakes", 0) > 0 else 0)
		if h < hard:
			_warns.append("stakes:%d %s — 앞 단보다 무르다" % [r2.get("_line", 0), r2.get("name", "")])
		hard = maxi(hard, h)


# 스타트팩. 첫 행은 늘 열려 있어야 하고(런을 못 시작하면 게임이 안 돈다),
# 다트 id 는 실재해야 하며, 칸 수는 0 보다 커야 한다.
static func _v_packs() -> void:
	var raw: Array = _raw.get("packs", [])
	if raw.is_empty():
		_errs.append("packs — 표가 비었다. 시작할 팩이 없으면 런이 안 선다")
		return
	var dids := {}
	for d in _raw.get("darts", []):
		dids[String(d.get("id", ""))] = true
	var seen := {}
	for i in raw.size():
		var r: Dictionary = raw[i]
		var who := "packs:%d %s" % [r.get("_line", 0), r.get("name", "")]
		var id: String = r.get("id", "")
		if id == "" or seen.has(id):
			_errs.append("%s — id 가 비었거나 중복이다" % who)
		seen[id] = true
		if i == 0 and String(r.get("prereq", "")) != "":
			_errs.append("%s — 첫 팩은 늘 열려 있어야 한다" % who)
		var dd: String = r.get("dart_id", "")
		if dd != "" and not dids.has(dd):
			_errs.append("%s — 다트 '%s' 가 darts.csv 에 없다" % [who, dd])
		if _i(r, "item_slots", "packs", 1) <= 0:
			_errs.append("%s — 스티커 칸이 0 이하다" % who)
		if _i(r, "darts_add", "packs", 0) <= -int(tune_i("darts_base")):
			_errs.append("%s — 다트 증감이 탄창을 다 없앤다" % who)


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
	var tracks := {}
	for r in _raw.get("area_up", []):
		tracks[_i(r, "track", "area_up", 0)] = true
	for r in _raw.get("areas", []):
		var t := _i(r, "track", "areas", 0)
		if t > 0 and not tracks.has(t):
			_errs.append("areas:%d — 강화 트랙 %d 가 area_upgrades 에 없다" % [r.get("_line", 0), t])
	for r in _raw.get("cons", []):
		if String(r.get("cat", "")) == "area" and not tracks.has(_i(r, "track", "cons", 0)):
			_errs.append("cons:%d — 강화 트랙 %d 가 area_upgrades 에 없다" % [r.get("_line", 0), _i(r, "track", "cons", 0)])
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
	for r in _raw.get("proc", []):
		ids[String(r.get("id", ""))] = true
	for r in _raw.get("areas", []):
		ids[String(r.get("key", ""))] = true
	for r in _raw.get("spec_map", []):
		var g: String = r.get("game_id", "")
		if g != "" and not ids.has(g):
			_errs.append("spec_map:%d — game_id '%s' 가 어느 표에도 없다" % [r.get("_line", 0), g])


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
	if _tune.has("sector_max") and int(_tune["sector_max"]) >= 25:
		_errs.append("tuning — sector_max 가 25 이상이다. check(\"bull\") 이 sector >= 25 라 칸이 불로 판정된다")


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
		if not CONDS.has(r.get("cond", "")):
			_errs.append("%s — 모르는 조건 '%s'" % [who, r.get("cond", "")])
		# 효과 없는 카드도 있다 — 골드·다트·승급만 하는 조커들. 그때는
		# 빈 kind 를 허락하되 부가 효과가 하나는 있어야 한다.
		if String(r.get("kind", "")) == "":
			if String(r.get("gold", "")) == "" and String(r.get("dadd", "")) == "" \
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
		var want := _rarity_of_cost(_i(r, "cost", "items"))
		if want != "" and r.get("rarity", "") != want:
			if String(r.get("_note", "")).find("등급 예외") < 0:
				_warns.append("%s — 가격 %s 는 보통 %s 인데 %s 다. 이상치면 _note 에 '등급 예외' 를 적어라"
						% [who, r.get("cost"), want, r.get("rarity")])
	# 상위호환 — 같은 효과이고 조건이 상대를 담는데 값이 크고 가격이 싸면
	# 상대 카드는 영원히 안 팔린다.
	for a in raw:
		if not _b(a, "enabled", "items"):
			continue
		for b in raw:
			if not _b(b, "enabled", "items"):
				continue
			if a.get("id") == b.get("id") or a.get("kind") != b.get("kind"):
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
			if covers and _i(a, "value", "items") >= _i(b, "value", "items") \
					and _i(a, "cost", "items") <= _i(b, "cost", "items"):
				_errs.append("items — %s(%s) 가 %s(%s) 의 상위호환이다"
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
	# 아무 스티커도 안 쓰는 조건은 화면에 영영 안 나온다. 숫자를 손으로 적지 않고
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
		_warns.append("items — 어떤 스티커도 안 쓰는 조건 %d종: %s" % [idle.size(), idle])


static func _rarity_of_cost(cost: int) -> String:
	match cost:
		4: return "common"
		7: return "uncommon"
		11, 14: return "rare"
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
			_errs.append("%s — 개조 id 는 네 글자여야 한다" % who)
		if not MOD_AXES.has(r.get("axis", "")):
			_errs.append("%s — 모르는 축 '%s'" % [who, r.get("axis", "")])
		if _i(r, "cost", "mods") <= 0:
			_errs.append("%s — 가격이 0 이하다" % who)
		# 링 폭 주고받기는 합이 0 이어야 한다. 아니면 판값이 조용히 오른다.
		if r.get("axis", "") == "band":
			var sum := _f(r, "v0", "mods") + _f(r, "v1", "mods")
			if absf(sum) > 0.0005:
				_errs.append("%s — band 축은 v0+v1 이 0 이어야 한다 (지금 %.3f)" % [who, sum])
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
		_v_desc(who, r.get("desc", ""), ["gauge", "mult", "pierce_side", "magnet"])
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
		_v_desc(who, r.get("desc", ""), ["v"])
	# 한 판에 제약이 하나뿐이라 축 중복이 게임에 안 나타난다. 그래도 세어 둔다 —
	# 카드를 둘 이상 붙이는 날 이 경고가 먼저 울려야 한다.
	var reused := []
	for a in axes:
		if int(axes[a]) > 1:
			reused.append(a)
	if not reused.is_empty():
		_warns.append("modifiers — 축을 둘 이상이 나눠 쓴다: %s" % [reused])
	# 스테이지 화면이 까는 장수보다 후보가 적으면 같은 카드가 두 번 뜬다.
	var need := tune_i("stage_picks")
	if raw.size() < need:
		_errs.append("modifiers — 제약이 %d종인데 스테이지가 %d장을 깐다" % [raw.size(), need])


static func _v_rounds() -> void:
	var raw: Array = _raw.get("antes", [])
	if raw.is_empty():
		_errs.append("antes — 표가 비었다")
		return
	var prev := 0
	for i in raw.size():
		var r: Dictionary = raw[i]
		var who := "antes:%d" % r.get("_line", 0)
		if _i(r, "ante", "antes") != i + 1:
			_errs.append("%s — ante 는 1부터 빠짐없이 이어져야 한다" % who)
		var t := _i(r, "base", "antes")
		if t <= prev:
			_errs.append("%s — 기본 목표가 안 오른다 (%d → %d)" % [who, prev, t])
		prev = t
		if _i(r, "darts", "antes") <= 0:
			_errs.append("%s — 다트가 0 이하다" % who)
		# 매대 자리는 정확히 넷이다(game.gd _table_draw 의 ax/ay).
		# 라운드 표에는 "마지막 행을 비운다" 규약이 없다 — 마지막 판이면
		# 호출부가 애초에 상점을 안 연다.
		var w := _i(r, "shop_items", "antes") + _i(r, "shop_mods", "antes") \
				+ _i(r, "shop_darts", "antes")
		if w != 4:
			_errs.append("%s — 매대 폭 합이 %d 다. 자리는 정확히 4개여야 한다" % [who, w])
		# 리그 배수는 1 이상이고 라운드를 따라 안 내려간다 — 내려가면
		# "더 어려운 리그인데 목표가 더 낮다" 가 된다.
		for col in ["curve_a", "curve_b"]:
			var m := _f(r, col, "antes", 0.0)
			if m < 1.0:
				_errs.append("%s — %s 가 %.2f 다. 1.00 미만이면 리그이 쉬워진다" % [who, col, m])
			if i > 0 and m < _f(raw[i - 1], col, "antes", 0.0) - 0.001:
				_errs.append("%s — %s 가 앞 라운드보다 낮다" % [who, col])

	var bl: Array = _raw.get("blinds", [])
	if bl.is_empty():
		_errs.append("blinds — 표가 비었다")
		return
	var boss := 0
	var pm := 0.0
	for r in bl:
		var who2 := "blinds:%d" % r.get("_line", 0)
		var m2 := _f(r, "mult", "blinds", 0.0)
		if m2 <= 0.0:
			_errs.append("%s — 배수가 0 이하다" % who2)
		if m2 < pm:
			_errs.append("%s — 배수가 앞 블라인드보다 낮다. 순서가 곧 난이도다" % who2)
		pm = m2
		if _i(r, "reward", "blinds", 0) <= 0:
			_errs.append("%s — 보상이 0 이하다" % who2)
		if _b(r, "boss", "blinds"):
			boss += 1
			if _b(r, "skippable", "blinds"):
				_errs.append("%s — 보스는 못 건너뛴다" % who2)
	if boss != 1:
		_errs.append("blinds — 보스가 %d개다. 라운드마다 정확히 하나여야 한다" % boss)
	# 보스가 제약을 깔려면 제약이 stage_picks 만큼 있어야 한다 — 그 검사는
	# _v_modifiers 가 이미 한다. 여기서는 보스가 마지막인지만 본다.
	if boss == 1 and not _b(bl[bl.size() - 1], "boss", "blinds"):
		_errs.append("blinds — 보스는 라운드의 마지막 판이어야 한다")


static func _v_cross() -> void:
	# 해금 라운드가 상점보다 뒤면 그 스티커는 영영 안 뜬다. 상점은 라운드 N 을
	# 클리어한 뒤 N+1 을 위해 열리므로 볼 수 있는 최소 라운드는 2 다.
	var n := rounds_n()
	for r in _raw.get("items", []):
		if String(r.get("min_round", "")) == "":
			continue
		var mr := _i(r, "min_round", "items")
		if mr < 2 or mr > n:
			_errs.append("items:%d — min_round %d 는 2~%d 여야 한다 (R1 앞에는 상점이 없다)"
					% [r.get("_line", 0), mr, n])
	for r in _raw.get("rarity", []):
		var mr2 := _i(r, "min_round", "rarity", 1)
		if mr2 < 2 or mr2 > n:
			_errs.append("rarity:%d — min_round %d 는 2~%d 여야 한다" % [r.get("_line", 0), mr2, n])
	# 매대가 마르면 리롤이 같은 물건을 다시 뱉는다. 라운드마다 후보 수가
	# 매대 폭보다 넉넉한지 센다 — 소유 스티커가 후보에서 빠지므로 여유를 둔다.
	var need := 0
	for r in rows("antes"):
		need = maxi(need, _i(r, "shop_items", "antes"))
	need += tune_i("max_items")
	for rd in range(2, n + 1):
		var cnt := 0
		for it in items():
			if item_min_round(it) <= rd:
				cnt += 1
		if cnt < need:
			_warns.append("items — R%d 에 뜰 수 있는 스티커가 %d장뿐이다. 매대 %d칸 + 슬롯을 채우면 마른다"
					% [rd, cnt, need])
	# 얼굴에 효과가 한 줄도 안 나오는 스티커 — 무슨 물건인지 모르는 채로 값을
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
		if String(it2.get("side", "")) != "" and face.find("강화") < 0:
			_errs.append("items — %s(%s) 의 영역 승급이 얼굴에 없다" % [it2.n, it2.id])
		if String(it2.get("boom", "")) != "" and face.find("파괴") < 0:
			_errs.append("items — %s(%s) 의 파괴 확률이 얼굴에 없다" % [it2.n, it2.id])
		if String(it2.get("g", "")) != "" and gtx == "":
			_errs.append("items — %s(%s) 의 골드가 얼굴에 없다" % [it2.n, it2.id])

	# 가중치가 0 인 스티커는 표에 있으나 게임에 없다.
	for it in items():
		if item_weight(it) <= 0.0:
			_errs.append("items — %s(%s) 는 매대에 안 뜬다" % [it.n, it.id])


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
