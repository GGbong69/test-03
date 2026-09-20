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
#  ── 프로필 ────────────────────────────────────────────
#  발라트로·슬더스처럼 진도가 프로필마다 따로다. 파일을 둘로 가른다.
#
#    user://highton.cfg      **전역** — 음량·전체화면, 그리고 어느
#                            프로필을 쓰는가. 프로필을 갈아도 안 바뀐다.
#    user://profile_N.cfg    **프로필** — 해금 · 통계 · 세기 · 마지막에
#                            고른 다트통과 리그.
#
#  가르는 선은 「기계의 설정인가, 이 사람의 진도인가」다. 음량은 모니터
#  앞에 앉은 사람의 것이라 프로필을 갈아도 그대로여야 하고, 해금은
#  그 프로필이 쌓은 것이라 같이 가면 안 된다.
#
#  마지막에 고른 다트통·리그(league · pack)도 **진도 쪽**이다. 전에는
#  설정에 섞여 있었는데, 프로필 A 가 열어 둔 다트통을 프로필 B 가
#  물려받으면 새 프로필이 잠긴 다트통으로 시작한다.
const PATH := "user://highton.cfg"


#  ── 이름을 옮긴 저장 ─────────────────────────────────────
#  게임 이름은 HIGHTON 이다(2026-09-17 사용자). 예전 프로젝트 이름이 HIGHTONE 이라
#  user:// 가 app_userdata/HIGHTONE 이었고 전역 파일도 hightone.cfg 였다. 이름을
#  고치면 user:// 가 app_userdata/HIGHTON 으로 옮겨 가 프로필 · 해금 · 통계가 빈
#  새 폴더에서 시작한다 — 그래서 **새 전역 파일이 없고 옛 폴더가 있으면 한 번**
#  옛 .cfg 를 옮겨 담는다. 옛 폴더는 안 지운다(되돌아갈 길). 검사 · 도구의 자리
#  (밑줄로 시작하는 파일)는 안 옮긴다.
const OLD_DIR := "HIGHTONE"
const OLD_GLOBAL := "hightone.cfg"


static func migrate_name() -> void:
	if FileAccess.file_exists(PATH):
		return
	var here := OS.get_user_data_dir()
	var old := here.get_base_dir().path_join(OLD_DIR)
	if old == here or not DirAccess.dir_exists_absolute(old):
		return
	var d := DirAccess.open(old)
	if d == null:
		return
	DirAccess.make_dir_recursive_absolute(here)
	for f in d.get_files():
		if not f.ends_with(".cfg") or f.begins_with("_"):
			continue
		var to: String = PATH.get_file() if f == OLD_GLOBAL else f
		if not FileAccess.file_exists(here.path_join(to)):
			DirAccess.copy_absolute(old.path_join(f), here.path_join(to))
const PROF := "user://profile_%d.cfg"
const SLOTS := 3

static var gpath := PATH
#  ── 도구가 사람의 저장을 못 건드리게 ─────────────────────────
#  프로필 검사(qa_profile)가 슬롯 파일(user://profile_N.cfg)을 **진짜 자리에서**
#  지우고 새로 쓰고 있었다 — 슬롯 경로가 상수라 검사가 제 자리를 박을 수 없었다
#  (2026-09-17 발견). 이제 틀을 변수로 두고, --script 로 도는 도구가 틀(prof_fmt)이나
#  전역 파일(gpath)을 안 박았으면 **저절로** 도구 자리로 돌린다. 진짜 저장을 일부러
#  고치는 도구(unlock.gd)만 allow_real 을 켠다.
const TOOL_GPATH := "user://_tool_global.cfg"
const TOOL_PROF := "user://_tool_profile_%d.cfg"
static var prof_fmt := PROF
static var allow_real := false


static func _tool_run() -> bool:
	if allow_real:
		return false
	var ml := Engine.get_main_loop()
	return ml != null and ml.get_script() != null
#  비어 있으면 슬롯에서 낸다. 검사·프로브가 여기에 제 자리를 박으면
#  그것이 이긴다 — 슬롯이 생겨도 그 규약은 안 바뀐다.
static var path := ""
static var _slot := 0            # 1..SLOTS. 0 이면 아직 전역에서 안 읽었다

const S_SET := "설정"
const S_PIK := "고름"    # 프로필 — 마지막에 고른 다트통·리그
const S_UNL := "해금"
const S_STA := "통계"
# 자유 열쇠 세기. STATS 는 목록이 곧 계약이라 열쇠를 미리 다 적어야 하는데,
# 「이 다트통으로 몇 번 완주했나」는 다트통 수만큼 열쇠가 생겨서 그 목록에
# 못 들어간다. 해금(S_UNL)이 자유 열쇠를 쓰는 그 규약을 수로 옮긴 자리다.
const S_TAL := "세기"
#  배움 — 처음 만난 것을 한 번만 가르치려고 세는 자리.
#  해금(S_UNL)과 모양이 같지만 **칸을 가른다.** unlock_keys() 는 컬렉션
#  화면의 계약이라, 거기에 가르친 기록이 섞이면 컬렉션이 배움을 센다.
const S_TUT := "배움"
#  발견 — 컬렉션이 읽는 유일한 칸. 해금(S_UNL)과 모양이 같지만 **절을 가른다.**
#  slot_info(아래 295)가 [해금] 키를 **갈래를 안 가리고** 세어(301-304) 프로필
#  화면에 「해금 N개」로 찍으므로(game.gd:25374), 발견 109개를 같은 절에 넣으면
#  그 수가 그대로 두 배가 된다. 배움(S_TUT)을 왜 뺐는지가 바로 위 112-114 에
#  적혀 있고, 이것이 같은 판단이다. 2026-09-19
const S_FND := "발견"
#  이어하기 — 진행 중인 런 하나를 통째로 담는 절.
#  **절을 가르는 이유는 지우는 방식에 있다.** 런이 끝나면 이 절만
#  erase_section 으로 통째로 지우는데, 해금(S_UNL)·통계(S_STA)와 한 절이면
#  그 한 줄이 사람의 진도를 지운다.
#  slot_info(290 둘레)는 [해금] 키만 세므로 이 절은 그 셈에 안 걸린다 —
#  직접 읽어 확인했다. 프로필 화면의 「해금 N개」가 이것 때문에 늘 일은 없다.
#
#  ⚠ **새 파일을 안 판다.** 절이면 run_set → boot() → _pp() → slot_path()
#  → _tool_run() → TOOL_PROF 가 **저절로** 도구 자리로 돌린다.
#  오늘 이 가지에서 직접 센 것: scripts/tools 의 도구 204개 중 _new_run() 을
#  부르는 것이 116개고, 그중 **22개**는 Save.path 조차 안 박는다
#  (axis_probe · build_probe · curve_probe · econ_probe · lever_probe ·
#  probe_league · probe_music · probe_packs · probe_runinfo · probe_sell_any ·
#  probe_track · settle_probe · shot_clear · shot_drag · shot_quad ·
#  shot_worst · swap_shot · thumb · track_probe · zz_adv · zz_aim · zz_over).
#  새 파일이면 그 스물둘이 사람의 진행 중인 런을 곧장 쓰고 지운다 —
#  검사 한 번에 런이 날아간다. 세는 법:
#      comm -23 <(grep -l "_new_run()" scripts/tools/*.gd | sort) \
#               <(grep -l "Save.path"  scripts/tools/*.gd | sort)
#  2026-09-20
const S_RUN := "이어하기"
#  저장 판. 다르면(낮든 높든) 조용히 버린다. 표의 뼈대(판 수·갈래·매듭
#  이름)가 바뀌는 날 2 로 올린다.
const RUN_VER := 1

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
	"best_dart_hvy", "best_dart_lgt", "best_dart_mag",
	"best_gain", "best_spare", "best_leg_bare",
	# ── 2026-09-11 · 기획서 다트통 표의 해금 조건을 그대로 재는 것들 ──
	#  앞 넷과 달리 이쪽은 **완주한 그 순간**의 한 장면이다. 판마다 재면
	#  런 도중에 스쳐 간 값이 걸려서 "완주한 채로" 가 안 된다.
	#    win_gold    완주 때 들고 있던 골드          (선금: 100 이상)
	#    win_items   완주 때 들고 있던 동전 수        (넓은 슬롯: 4 이하 · 최솟값)
	#    boss_spare  보스 판을 넘긴 때 남은 다트      (외줄: 5 이상 = 한 발로)
	#    win_null    NULL 을 든 채 완주한 횟수        ([?? ???]: 1 이상)
	"win_gold", "win_items", "boss_spare", "win_null",
	# ── 2026-09-13 · 기획서 s27 「녹는 시계」의 해금 조건 ──
	#  보드 확장 「시계」를 낀 채 보드 아웃이 몇 번 이어졌나. 같은 판
	#  안에서만 이어지고 판이 새로 서면 0 이다.
	"clok_out_streak",
	# ── 2026-09-13 · 기획서 s27 「정조준」의 해금 조건 ──
	#  「[리볼버] 조준 상태에서 모든 다트를 볼스아이에 명중」. 조준 방식과
	#  한 판의 명중 패턴을 **같이** 봐야 해서 기존 열쇠로는 못 적었고,
	#  그래서 여태 bulls(누적 볼스아이) 150 이 임시로 서 있었다 — 오래
	#  하기만 하면 열리는 조건이라 기획서와 다른 물건이었다.
	#  판이 끝날 때 1 을 적는다. 0/1 이라 최댓값으로 다룬다.
	"revo_bull_leg",
]
# 최댓값으로 다루는 것들. 나머지는 누적이다.
const PEAKS := ["best_leg", "best_score", "best_gold", "best_track",
		"best_dart_hvy", "best_dart_lgt", "best_dart_mag",
		"best_gain", "best_spare", "best_leg_bare",
		"win_gold", "boss_spare", "clok_out_streak", "revo_bull_leg"]
# 최솟값으로 다루는 것들. 「N 이하로 완주」 조건이 읽는다 —
# 최댓값으로는 그 말을 못 적는다(적게 든 쪽이 이기는 조건이라 그렇다).
const DIPS := ["win_items"]

static var _cfg: ConfigFile = null
static var _at := ""             # 지금 _cfg 에 올라와 있는 파일
static var _gcfg: ConfigFile = null
static var _gloaded := false
static var _err := ""            # 마지막 실패 사유. 비어 있으면 정상이다


static func _read(fp: String) -> ConfigFile:
	var c := ConfigFile.new()
	if not FileAccess.file_exists(fp):
		return c
	var e := c.load(fp)
	if e != OK:
		_err = "저장 파일을 못 읽었다 (%d) — 기본값으로 시작한다" % e
		push_warning(_err)
		return ConfigFile.new()
	return c


# 전역(음량·전체화면·어느 프로필인가). 프로필을 갈아도 안 다시 읽는다.
static func gboot() -> void:
	if _gloaded:
		return
	_gloaded = true
	if gpath == PATH and _tool_run():
		gpath = TOOL_GPATH
	_gcfg = _read(gpath)
	_migrate()


#  프로필이 생기기 전의 저장을 1번으로 옮긴다.
#
#  2026-09-15 전에는 해금·통계가 전역 파일 안에 같이 살았다. 가르기만
#  하고 두면 그 사람의 해금이 **하루아침에 다 잠긴다** — 파일은 멀쩡히
#  있는데 아무도 안 읽는 자리에 있는 것이라 더 나쁘다.
#
#  옮기는 것은 **한 번뿐**이다. 1번 프로필 파일이 이미 있으면 손대지
#  않는다 — 그쪽이 이미 쌓고 있는 자리다. 옮긴 뒤 전역 파일의 옛 칸은
#  지운다. 안 지우면 1번을 지운 다음 실행에서 되살아난다.
static func _migrate() -> void:
	var old: bool = _gcfg.has_section(S_UNL) or _gcfg.has_section(S_STA)
	if _gcfg.has_section(S_TAL):
		old = true
	if not old or FileAccess.file_exists(slot_path(1)):
		return
	var c := ConfigFile.new()
	for sec in [S_UNL, S_STA, S_TAL]:
		if not _gcfg.has_section(sec):
			continue
		for k in _gcfg.get_section_keys(sec):
			c.set_value(sec, k, _gcfg.get_value(sec, k))
		_gcfg.erase_section(sec)
	#  마지막에 고른 다트통·리그도 설정에서 진도로 옮긴다.
	for k2 in ["pack", "league"]:
		if _gcfg.has_section_key(S_SET, k2):
			c.set_value(S_PIK, k2, _gcfg.get_value(S_SET, k2))
			_gcfg.erase_section_key(S_SET, k2)
	c.save(slot_path(1))
	_gcfg.set_value(S_SET, "slot", 1)
	_gcfg.save(gpath)
	print("저장: 옛 저장을 프로필 1 로 옮겼다")


static func slot() -> int:
	gboot()
	if _slot <= 0:
		_slot = clampi(int(_gcfg.get_value(S_SET, "slot", 1)), 1, SLOTS)
	return _slot


static func slot_path(i: int) -> String:
	var fmt := prof_fmt
	if fmt == PROF and _tool_run():
		fmt = TOOL_PROF
	return fmt % clampi(i, 1, SLOTS)


# 지금 읽고 쓸 프로필 파일. path 가 박혀 있으면 그것이 이긴다.
static func _pp() -> String:
	return path if path != "" else slot_path(slot())


# 처음 쓰는 순간 읽는다. 실패해도 빈 설정으로 계속 간다.
#
# **올라와 있는 파일이 바뀌면 다시 읽는다.** 전에는 한 번 읽었나(_loaded)
# 만 봤는데, 프로필을 갈면 경로가 바뀌므로 그것으로는 옛 프로필이 그대로
# 남는다 — 갈아탄 줄 알고 남의 해금을 쓰게 된다.
static func boot() -> void:
	var want := _pp()
	if _cfg != null and _at == want:
		return
	_at = want
	_cfg = _read(want)


#  ⚠ **원자적이지 않다 — 언젠가 고쳐야 하는 자리다.**
#  _cfg.save(_at) 는 제자리에 덮어쓴다. 쓰다가 전원이 나가면 반쪽 파일이
#  남는데, 잘린 ConfigFile 은 **대개 오류 없이 파싱된다** — 앞쪽 열쇠만
#  올라오고 뒤쪽은 없는 채로. 그러면 [해금]과 [통계]가 **아무 말 없이**
#  사라지고, 다음 flush() 가 그 망가진 설정을 되써서 영구화한다.
#  잘라서 재 봤다: 90%에서 자르면 오류 없이 해금 하나와 통계 전부가,
#  30%에서는 전부 사라진다(2026-09-20 검토).
#
#  이어하기가 이 위험을 **늘렸다.** 매듭이 판당 서넛이라 프로필 파일을
#  고쳐 쓰는 횟수가 판당 한둘에서 열 남짓으로 는다. 창이 여전히 밀리초
#  단위라 확률은 작지만, 잃는 것이 「런 하나」가 아니라 **사람의 진도
#  통째**라는 것은 적어 둔다 — 그렇게 적어 둔 자리가 없었다.
#
#  고치는 길은 .tmp 에 쓰고 갈아 끼우는 것인데, 고도의 DirAccess.rename 은
#  윈도우에서 **대상을 먼저 지우고** 옮기므로(godot#98360 · PR #98361)
#  .bak 과 _read 의 되읽기까지 같이 세워야 안전해진다. 반쪽만 하면 더
#  나쁘다 — 지우고 옮기는 사이에 죽으면 프로필이 통째로 없어진다.
#  그리고 .bak 이 서면 erase_slot()·wipe() 가 그것까지 지워야 한다(안
#  그러면 지운 프로필이 되살아난다). **별개 일감**이고, 그 둘은 지금 다른
#  워크플로우가 만지는 자리라 이번 턴에 안 건드린다.
static func flush() -> void:
	boot()
	var e := _cfg.save(_at)
	if e != OK:
		_err = "저장 실패 (%d)" % e
		push_warning(_err)


static func gflush() -> void:
	gboot()
	var e := _gcfg.save(gpath)
	if e != OK:
		_err = "저장 실패 (%d)" % e
		push_warning(_err)


# ── 프로필 ──────────────────────────────────────────────
# 슬롯을 갈아탄다. 다음에 읽을 때 저절로 새 파일이 올라온다(boot 의 _at).
static func use_slot(i: int) -> void:
	gboot()
	_slot = clampi(i, 1, SLOTS)
	_gcfg.set_value(S_SET, "slot", _slot)
	gflush()
	path = ""          # 슬롯을 골랐으면 박아 둔 자리는 놓는다


static func slot_used(i: int) -> bool:
	return FileAccess.file_exists(slot_path(i))


# 그 슬롯을 **올리지 않고** 훑는다. 고르는 화면이 셋을 같이 보여 줘야
# 하는데, 보여 주려고 올렸다가 안 고르고 나가면 남의 프로필이 올라온 채로
# 남는다 — 읽는 것과 갈아타는 것을 가른다.
static func slot_info(i: int) -> Dictionary:
	var fp := slot_path(i)
	if not FileAccess.file_exists(fp):
		return {"used": false}
	var c := _read(fp)
	var unl := 0
	if c.has_section(S_UNL):
		for k in c.get_section_keys(S_UNL):
			if bool(c.get_value(S_UNL, k, false)):
				unl += 1
	return {
		"used": true,
		"runs": int(c.get_value(S_STA, "runs", 0)),
		"wins": int(c.get_value(S_STA, "wins", 0)),
		"best_leg": int(c.get_value(S_STA, "best_leg", 0)),
		"best_score": int(c.get_value(S_STA, "best_score", 0)),
		"unlocks": unl,
	}


# 되돌릴 수 없다. 부르는 쪽이 확인을 받는다.
static func erase_slot(i: int) -> void:
	var fp := slot_path(i)
	if FileAccess.file_exists(fp):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fp))
	if _at == fp:
		_cfg = ConfigFile.new()
		_at = ""


static func last_error() -> String:
	return _err


# ── 설정 ────────────────────────────────────────────────
#  **전역이다.** 음량과 전체화면은 모니터 앞에 앉은 사람의 것이라
#  프로필을 갈아도 그대로여야 한다.
static func get_set(key: String, dflt: Variant) -> Variant:
	gboot()
	return _gcfg.get_value(S_SET, key, dflt)


static func set_set(key: String, v: Variant) -> void:
	gboot()
	_gcfg.set_value(S_SET, key, v)
	gflush()         # 설정은 드물게 바뀐다. 바뀔 때마다 바로 쓴다


#  마지막에 고른 다트통·리그. **프로필 쪽이다** — 전역에 두면 프로필 A 가
#  열어 둔 다트통을 B 가 물려받아 잠긴 다트통으로 시작한다.
static func get_pick(key: String, dflt: Variant) -> Variant:
	boot()
	return _cfg.get_value(S_PIK, key, dflt)


static func set_pick(key: String, v: Variant) -> void:
	boot()
	_cfg.set_value(S_PIK, key, v)
	flush()


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


#  최댓값 쪽. peak() 와 같은 일을 **자유 열쇠 절**에서 한다.
#  ⚠ PEAKS 배열을 안 늘리는 것이 요점이다 — 무한 구간의 수를 best_leg ·
#  best_gain 같은 자에 섞으면 해금 조건의 뜻이 조용히 바뀌고, **최댓값은
#  안 내려가므로 되돌릴 방법이 없다**(game.gd 의 _rec_off 머리말).
#  열쇠 둘: endless:leg · endless:score. 2026-09-20
static func tally_max(key: String, v: int) -> int:
	boot()
	var cur := tally(key)
	if v <= cur:
		return cur
	_cfg.set_value(S_TAL, key, v)
	return v


#  심어 둔 세기 열쇠 전부. 개발 도구가 갈래별로 지울 때 쓴다 —
#  unlock_keys() 와 같은 어법이다.
static func tally_keys() -> PackedStringArray:
	boot()
	if not _cfg.has_section(S_TAL):
		return PackedStringArray()
	return _cfg.get_section_keys(S_TAL)


#  세기 한 줄을 지운다. lock() 과 같이 **개발 도구만** 부른다.
static func tally_drop(key: String) -> bool:
	boot()
	if not _cfg.has_section_key(S_TAL, key):
		return false
	_cfg.erase_section_key(S_TAL, key)
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
# ── 배움 ────────────────────────────────────────────────
#  프로필마다 따로다 — 새 프로필은 처음부터 다시 배운다. 프로필을 지우면
#  파일째 없어지므로 따로 지울 것이 없다.
static func taught(id: String) -> bool:
	boot()
	return bool(_cfg.get_value(S_TUT, id, false))


#  처음이면 true 를 돌려주고 적어 둔다. 부르는 쪽은 이 한 줄로
#  "가르칠까" 를 정한다 — unlock() 과 같은 규약이다.
static func teach(id: String) -> bool:
	boot()
	if taught(id):
		return false
	_cfg.set_value(S_TUT, id, true)
	flush()
	return true


#  다시 배우게 한다. 설정에서 끄고 켜는 자리가 이것을 부른다.
static func forget_all() -> void:
	boot()
	if _cfg.has_section(S_TUT):
		_cfg.erase_section(S_TUT)
		flush()


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


# ── 발견 ────────────────────────────────────────────────
#  열쇠는 "<갈래>:<id>" — item:c01 · cons:v_cash · modf:gust. 갈래를 앞에 두는
#  해금(위 357)의 어법 그대로고, 절 이름이 셋째 토막 노릇을 한다.
#  "_v" 는 콜론이 없어 열쇠와 절대 안 부딪힌다 — 이 프로필이 발견을 세기
#  시작했다는 표시이자, game.gd 의 _found_migrate 가 한 번만 돌게 하는 빗장이다.
#
#  ⚠ 해금(itemgot:)과 **다른 계통이다.** itemgot 은 「팩에 드는가」를 답하고
#  이것은 「컬렉션에 보이는가」를 답한다. 한 열쇠로 묶으면 컬렉션 때문에 팩
#  확률이 흔들린다. 2026-09-19
static func found(id: String) -> bool:
	boot()
	return bool(_cfg.get_value(S_FND, id, false))


#  처음이면 true — unlock() · teach() 와 같은 규약이다.
#  ⚠ **flush 를 안 한다.** unlock() 은 부를 때마다 디스크를 치는데(위 365-371)
#  발견은 상점에서 연달아 선다. 같은 저장소가 2026-09-19 에 이 자리에서 한 번
#  뎄다 — game.gd 「휠 한 번 굴리면 프로필 파일을 열 번 넘게 쓴다」. 판 끝·런
#  끝의 flush 에 묻어간다. bump() 와 같은 길이다.
static func discover(id: String) -> bool:
	boot()
	if bool(_cfg.get_value(S_FND, id, false)):
		return false
	_cfg.set_value(S_FND, id, true)
	return true


static func found_keys() -> PackedStringArray:
	boot()
	if not _cfg.has_section(S_FND):
		return PackedStringArray()
	return _cfg.get_section_keys(S_FND)


static func found_of(kind: String) -> PackedStringArray:
	boot()
	var out := PackedStringArray()
	if not _cfg.has_section(S_FND):
		return out
	for k in _cfg.get_section_keys(S_FND):
		if String(k).begins_with(kind + ":") and bool(_cfg.get_value(S_FND, k, false)):
			out.append(String(k).substr(kind.length() + 1))
	return out


#  이 프로필이 발견을 세기 시작했는가. 한 번 걷는 이주의 빗장이다.
static func found_ready() -> bool:
	boot()
	return int(_cfg.get_value(S_FND, "_v", 0)) >= 1


static func found_ready_set() -> void:
	boot()
	_cfg.set_value(S_FND, "_v", 1)


#  개발자 판과 tools/unlock.gd 만 부른다. lock() 이 [해금]에 대해 그렇듯
#  게임은 안 부른다.
#  ⚠ **_v 를 다시 세운다.** 안 세우면 다음에 컬렉션을 열 때 _found_migrate 가
#  또 돌아 방금 잠근 것이 되살아난다 — 「발견 전부 잠그기」가 한 프레임짜리가
#  된다. 지운 프로필은 **발견을 세는 프로필**이다.
static func unfound_all() -> void:
	boot()
	if _cfg.has_section(S_FND):
		_cfg.erase_section(S_FND)
	_cfg.set_value(S_FND, "_v", 1)
	flush()


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
# **프로필만 지운다** — 음량까지 날아가면 검사 한 번에 사람 설정이 사라진다.
static func wipe() -> void:
	boot()
	_cfg = ConfigFile.new()
	flush()


# ── 이어하기 ────────────────────────────────────────────
#  진행 중인 런 하나. 게임이 「안전한 자리」(판 선택 · 판 첫머리 · 상점)에서
#  값을 통째로 받아 적고, 제목 화면의 「계속하기」가 그것을 되살린다.
#
#  여기는 **담는 자리일 뿐**이다. 무엇을 담는지는 game.gd 의 _run_save 가
#  정한다 — 저장 계층이 런의 모양을 알면 런 상태가 하나 늘 때 고칠 자리가
#  둘이 된다.
#
#  프로필 파일 안의 한 절이라 **슬롯마다 저절로 따로**고, erase_slot() ·
#  wipe() 가 파일·설정째 갈아 치우므로 따로 지울 자리를 안 만든다.

static func run_get(key: String, dflt: Variant) -> Variant:
	boot()
	return _cfg.get_value(S_RUN, key, dflt)


#  ⚠ **flush 를 안 한다.** 한 매듭에 서른 남짓이 줄줄이 들어오므로 열쇠마다
#  디스크를 치면 매듭 하나에 서른 번 쓴다. bump() 가 「한 발 던질 때마다
#  디스크를 때리면 안 된다」로 같은 판단을 내린 자리가 위에 있다.
#  부르는 쪽(_run_save)이 **끝에 한 번** flush() 한다.
static func run_set(key: String, v: Variant) -> void:
	boot()
	_cfg.set_value(S_RUN, key, v)


#  절이 서 있는가. **슬롯을 올리지 않고 묻는다** — slot_info 가 「보여
#  주려고 올렸다가 안 고르고 나가면 남의 프로필이 올라온 채로 남는다」를
#  피한 그 규약이다. 매 프레임 불려도 boot() 이 _at == want 면 즉시
#  return 이라 디스크에 안 닿는다.
#
#  ⚠ **이것만으로 「계속하기」를 켜지 마라.** 여기는 ver 하나만 본다 —
#  절은 성한데 판 번호가 표 밖이거나 다트통 id 가 표에서 사라진 저장에서도
#  참이다. 탈 수 있는가는 game.gd 의 _run_ok() 가 뼈대 여섯까지 보고
#  답하고, 제목 글줄의 흐림도 되살리기도 **그쪽 하나**를 본다. 갈라 두었던
#  동안 그 줄이 밝은 채로 죽어 있었다. 2026-09-20
static func run_live() -> bool:
	boot()
	return int(_cfg.get_value(S_RUN, "ver", 0)) == RUN_VER


#  ⚠ **제 안에서 flush 한다.** 완주 갈래 넷 중 하나(목숨이 마지막 판에서
#  터진 완주 — game.gd 의 `state = S.OVER; won = true; _sfx("run_win")`
#  넉 줄짜리 좁은 갈래)에만 Save.flush() 가 **없다**. 부르는 쪽에 맡기면
#  거기 하나가 빠져 **이긴 런이 「계속하기」로 되살아난다.** 손으로는 거의
#  못 밟는 갈래라 눈으로는 영영 안 걸린다. 2026-09-20
static func run_drop() -> void:
	boot()
	if _cfg.has_section(S_RUN):
		_cfg.erase_section(S_RUN)
		flush()
