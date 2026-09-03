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
#    ② 해금 — 스타트팩·리그. 발라트로가 조건으로 여는 그것
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

# 통계 키 — 전부 int 누적이거나 최댓값이다.
#  누적(bump): 던진 다트·트리플·불·빗나감·구매·판매·리롤·소비·런·완주
#  최댓값(peak): 도달 판·한 판 점수·보유 골드·트랙 레벨
#
#  발라트로의 해금 조건이 전부 이 두 모양이라(“타로 25장 사용”, “한 손에
#  10만점”) 두 연산만 있으면 조건표를 데이터로 쓸 수 있다.
const STATS := [
	"runs", "wins", "darts", "triples", "doubles", "bulls", "misses",
	"items_bought", "mods_bought", "darts_bought", "cons_used",
	"rerolls", "sold", "gold_earned", "skips", "fixtures_bought",
	"best_leg", "best_score", "best_gold", "best_track",
]
# 최댓값으로 다루는 것들. 나머지는 누적이다.
const PEAKS := ["best_leg", "best_score", "best_gold", "best_track"]

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
