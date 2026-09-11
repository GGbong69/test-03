extends RefCounted

# ══════════════════════════════════════════════════════════
#  저장 — 설정 · 해금 · 통계
# ──────────────────────────────────────────────────────────
#  이 게임에는 저장이 **한 줄도 없었다.** 프로젝트 전체에서 파일을 쓰는
#  코드가 0줄이었고(data.gd 의 FileAccess 는 CSV 를 읽기만 한다), 음량은
#  `var vol := 1.0` 이라는 그냥 변수라 창을 닫으면 같이 사라졌다.
#  잃어버린 것이 아니라 만든 적이 없었다.
#
#  세 가지가 여기 걸린다.
#    ① 설정 — 음량·전체화면. 제출본에서 이것부터 구멍이었다
#    ② 해금 — 다트통·리그. 발라트로가 조건으로 여는 그것
#    ③ 통계 — 해금 조건이 읽을 누적 카운터. 조건을 나중에 달면 그때부터
#       세기 시작해서 이미 한 플레이가 증발한다. 그래서 **조건보다 먼저**
#       세기 시작한다 — 지금 쓰는 곳이 없어도 값은 쌓인다.
#
#  ConfigFile 을 쓴다. JSON 이 아닌 이유 셋:
#    · get_value(sec, key, dflt) 가 없는 키를 기본값으로 조용히 받는다.
#      표가 자라도 옛 저장이 안 깨진다 — 이 프로젝트의 CSV 규약과 같은 태도다.
#    · 사람이 읽고 고칠 수 있는 INI 라 검증과 버그 재현이 쉽다.
#    · Variant 를 그대로 싣는다. 직렬화 코드를 안 쓴다.
#
#  **깨진 파일로 게임이 안 죽는다.** 파싱이 실패하면 빈 설정으로 시작하고
#  다음 저장에서 덮어쓴다. 저장이 게임을 막는 일은 없어야 한다 —
#  세이브 하나 때문에 실행이 안 되는 것이 제출본에서 가장 나쁜 결말이다.
# ══════════════════════════════════════════════════════════

# 검사가 진짜 저장을 지우고 해금까지 심고 있었다 — 리그이 해금을 읽기
# 시작하면서 드러났다. 경로를 상수가 아니라 변수로 두어 프로브가 제 자리를
# 쓰게 한다. 게임은 이 값을 절대 안 바꾼다.
const PATH := "user://hightone.cfg"
static var path := PATH

const S_SET := "설정"
const S_UNL := "해금"
const S_STA := "통계"
# 자유 열쇠 세기. STATS 는 목록이 곧 계약이라 열쇠를 미리 다 적어야 하는데,
# 「이 다트통으로 몇 번 완주했나」는 다트통 수만큼 열쇠가 생겨서 그 목록에
# 못 들어간다. 해금(S_UNL)이 자유 열쇠를 쓰는 그 규약을 수로 옮긴 자리다.
const S_TAL := "세기"

# 통계 키 — 전부 int 누적이거나 최댓값이다.
#  누적(bump): 던진 다트·트리플·불·빗나감·구매·판매·리롤·사탕·런·완주
#  최댓값(peak): 도달 판·한 판 점수·보유 골드·트랙 레벨
#
#  발라트로의 해금 조건이 전부 이 두 모양이라(“타로 25장 사용”, “한 손에
#  10만점”) 두 연산만 있으면 조건표를 데이터로 쓸 수 있다.
const STATS := [
	"runs", "wins", "darts", "triples", "doubles", "bulls", "misses",
	"items_bought", "mods_bought", "darts_bought", "cons_used",
	"rerolls", "sold", "gold_earned", "skips", "fixtures_bought",
	"boosters_bought",
	"best_leg", "best_score", "best_gold", "best_track",
	# ── 2026-09-09 · 다트통 해금 조건이 읽을 것들 ──────
	#  기획서 P.21 이 다트통을 「무엇을 들고 완주했나」로 열려고 하는데
	#  그것을 잴 자가 하나도 없었다. 넷은 다트 구성, 셋은 한 판의 기록이다.
	#
	#  **쓰는 다트통이 없어도 넷 다 센다.** 이 파일 머리말이 적어 둔 규약
	#  그대로다 — 조건을 나중에 달면 그때부터 세기 시작해서 이미 한
	#  플레이가 증발한다.
	"best_dart_hvy", "best_dart_lgt", "best_dart_prc", "best_dart_mag",
	"best_gain", "best_spare", "best_leg_bare",
	# ── 2026-09-11 · 기획서 다트통 표의 해금 조건을 그대로 재는 것들 ──
	#  앞 넷과 달리 이쪽은 **완주한 그 순간**의 한 장면이다. 판마다 재면
	#  런 도중에 스쳐 간 값이 걸려서 "완주한 채로" 가 안 된다.
	#    win_gold    완주 때 들고 있던 골드          (선금: 100 이상)
	#    win_items   완주 때 들고 있던 동전 수        (넓은 슬롯: 4 이하 · 최솟값)
	#    boss_spare  보스 판을 넘긴 때 남은 다트      (외줄: 5 이상 = 한 발로)
	#    win_null    NULL 을 든 채 완주한 횟수        ([?? ???]: 1 이상)
	"win_gold", "win_items", "boss_spare", "win_null",
]
# 최댓값으로 다루는 것들. 나머지는 누적이다.
const PEAKS := ["best_leg", "best_score", "best_gold", "best_track",
		"best_dart_hvy", "best_dart_lgt", "best_dart_prc", "best_dart_mag",
		"best_gain", "best_spare", "best_leg_bare",
		"win_gold", "boss_spare"]
# 최솟값으로 다루는 것들. 「N 이하로 완주」 조건이 읽는다 —
# 최댓값으로는 그 말을 못 적는다(적게 든 쪽이 이기는 조건이라 그렇다).
const DIPS := ["win_items"]

static var _cfg: ConfigFile = null
static var _loaded := false
static var _err := ""            # 마지막 실패 사유. 비어 있으면 정상이다


# 처음 쓰는 순간 읽는다. 실패해도 빈 설정으로 계속 간다.
static func boot() -> void:
	if _loaded:
		return
	_loaded = true
	_cfg = ConfigFile.new()
	if not FileAccess.file_exists(path):
		return
	var e := _cfg.load(path)
	if e != OK:
		_err = "저장 파일을 못 읽었다 (%d) — 기본값으로 시작한다" % e
		push_warning(_err)
		_cfg = ConfigFile.new()


static func flush() -> void:
	boot()
	var e := _cfg.save(path)
	if e != OK:
		_err = "저장 실패 (%d)" % e
		push_warning(_err)


static func last_error() -> String:
	return _err


# ── 설정 ────────────────────────────────────────────────
static func get_set(key: String, dflt: Variant) -> Variant:
	boot()
	return _cfg.get_value(S_SET, key, dflt)


static func set_set(key: String, v: Variant) -> void:
	boot()
	_cfg.set_value(S_SET, key, v)
	flush()          # 설정은 드물게 바뀐다. 바뀔 때마다 바로 쓴다


# ── 해금 ────────────────────────────────────────────────
#  id 는 "pack:mag" · "league:green" 처럼 갈래를 앞에 둔다. 표가 자라도
#  키가 안 부딪히고, 갈래별로 훑을 수 있다.
static func unlocked(id: String) -> bool:
	boot()
	return bool(_cfg.get_value(S_UNL, id, false))


# 새로 열렸으면 true 를 돌려준다 — 화면에 "열렸다" 를 띄울지가 여기서 갈린다.
static func unlock(id: String) -> bool:
	boot()
	if unlocked(id):
		return false
	_cfg.set_value(S_UNL, id, true)
	flush()
	return true


# ── 자유 열쇠 세기 ──────────────────────────────────────
#  "runs:p_mag" 처럼 갈래를 앞에 둔다. 해금 열쇠와 같은 어법이다.

static func tally(key: String) -> int:
	boot()
	return int(_cfg.get_value(S_TAL, key, 0))


static func tally_up(key: String, n := 1) -> int:
	boot()
	var v := tally(key) + n
	_cfg.set_value(S_TAL, key, v)
	return v


# 해금을 되돌린다. 개발 도구(tools/unlock.gd)만 부른다 — 심는 것만큼
# 지우는 것이 있어야 해금 흐름을 다시 시험할 수 있다. 게임은 안 부른다.
static func lock(id: String) -> bool:
	boot()
	if not _cfg.has_section_key(S_UNL, id):
		return false
	_cfg.erase_section_key(S_UNL, id)
	flush()
	return true


# 심어 둔 해금 키 전부. unlocked_of 와 달리 갈래 접두사를 안 떼고 준다.
static func unlock_keys() -> PackedStringArray:
	boot()
	if not _cfg.has_section(S_UNL):
		return PackedStringArray()
	return _cfg.get_section_keys(S_UNL)


static func unlocked_of(kind: String) -> PackedStringArray:
	boot()
	var out := PackedStringArray()
	if not _cfg.has_section(S_UNL):
		return out
	for k in _cfg.get_section_keys(S_UNL):
		if String(k).begins_with(kind + ":") and bool(_cfg.get_value(S_UNL, k, false)):
			out.append(String(k).substr(kind.length() + 1))
	return out


# ── 통계 ────────────────────────────────────────────────
static func stat(key: String) -> int:
	boot()
	return int(_cfg.get_value(S_STA, key, 0))


# 누적. 저장은 안 한다 — 한 발 던질 때마다 디스크를 때리면 안 된다.
# 판 끝과 런 끝에서 flush() 를 부른다.
static func bump(key: String, n := 1) -> void:
	boot()
	if not STATS.has(key):
		push_error("저장: 모르는 통계 키 '%s' — STATS 에 먼저 적어라" % key)
		return
	_cfg.set_value(S_STA, key, stat(key) + n)


static func peak(key: String, v: int) -> void:
	boot()
	if not PEAKS.has(key):
		push_error("저장: '%s' 는 최댓값 키가 아니다" % key)
		return
	if v > stat(key):
		_cfg.set_value(S_STA, key, v)


# 최솟값. 「N 이하로 완주」를 재는 자리다.
# **처음 한 번은 무조건 적는다** — 0 으로 시작하면 "아직 한 번도 안 했다" 와
# "0개로 했다" 가 구별이 안 되고, 뒤엣것이 늘 이겨서 조건이 처음부터 서 있다.
static func dip(key: String, v: int) -> void:
	boot()
	if not DIPS.has(key):
		push_error("저장: '%s' 는 최솟값 키가 아니다" % key)
		return
	if not _cfg.has_section_key(S_STA, key) or v < stat(key):
		_cfg.set_value(S_STA, key, v)


static func has_stat(key: String) -> bool:
	boot()
	return _cfg.has_section_key(S_STA, key)


static func all_stats() -> Dictionary:
	boot()
	var out := {}
	for k in STATS:
		out[k] = stat(k)
	return out


# 검사와 "처음부터 다시" 용. 되돌릴 수 없으므로 부르는 쪽이 확인을 받는다.
static func wipe() -> void:
	boot()
	_cfg = ConfigFile.new()
	flush()
