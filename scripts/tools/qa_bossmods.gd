extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  보스 제약 굴림의 계약 (2026-09-18)
#
#  실행:  godot --path . --headless --script scripts/tools/qa_bossmods.gd
#  종료 코드 = 실패 개수
#
#  제약이 「고르는 것」에서 「그 보스 판에 이미 붙어 있는 것」으로 바뀌었다.
#  그 구조가 지는 약속은 하나다 — **미리 보여 준 것이 나중에 안 달라진다.**
#  문지기가 라운드 번호가 아니라 boss_mods 사전의 **열쇠**인 이유가 그것이고,
#  ②가 그 약속을 그대로 잰다.
#
#  재는 것
#    ① 라운드가 열리면 그 라운드 보스에 제약이 서 있다
#    ② 같은 라운드에서 판 선택을 셋 다 열어도 한 글자도 안 바뀐다
#    ③ 보스 판이 서면 active_mods 의 id 가 boss_mods 와 같다
#    ④ **보통 판이 서면 active_mods 가 빈다** — 보스 → 보통 순서로 돌려야
#       잡히는 회귀다. active_mods 를 비우는 게임 코드가 _begin_leg 하나뿐이라,
#       그 함수를 안 지나는 길이 생기면 지난 보스 제약이 런 끝까지 살아붙는다
#    ⑤ 상점이 다음 라운드 보스를 미리 굴린다 (마지막 상점에서 명판이 안 빈다)
#    ⑥ 「겹치기」에서 둘이 서고 서로 다른 축이다
#    ⑦ 새 런이 사전 · 무효 · 기억을 전부 비운다
#    ⑧ 판을 오갔다 돌아와도 안 바뀐다
# ══════════════════════════════════════════════════════════

var g = null
var fails := 0


func _ok(nm: String, cond: bool, note := "") -> void:
	print("  %s %-44s %s" % ["통과" if cond else "실패", nm, note])
	if not cond:
		fails += 1


func _ids(bn: int) -> Array:
	var out := []
	for mid in g.boss_mods.get(bn, PackedStringArray()):
		out.append(String(mid))
	return out


func _first_boss() -> int:
	for n in range(1, GameData.legs_n() + 1):
		if GameData.is_boss(n):
			return n
	return 0


func _initialize() -> void:
	Save.gpath = "user://_qa_bm_g.cfg"
	Save.path = "user://_qa_bm.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.drop_fast = true
	_run()
	print("\n%s" % ("실패 %d건" % fails if fails > 0 else "전부 통과"))
	quit(mini(fails, 125))


func _run() -> void:
	var per: int = GameData.legs_per_round()
	var boss: int = _first_boss()

	# ① 라운드가 열리면 제약이 서 있다
	g._new_run()
	_ok("라운드가 열리면 보스에 제약이 선다", not _ids(boss).is_empty(),
			"%d번 판 %s" % [boss, _ids(boss)])
	var first := _ids(boss)

	# ② 라운드 안에서 몇 번을 열어도 안 바뀐다.
	#    _open_leg 는 라운드당 세 번 불린다(판 1·2·3 앞에서 한 번씩) —
	#    라운드 카운터를 문지기로 쓰면 여기서 조용히 다시 굴린다.
	var same := true
	for k in per:
		g.leg_no = boss - GameData.leg_idx(boss) + k
		g._open_leg()
		if _ids(boss) != first:
			same = false
	_ok("라운드 안에서 세 번 열어도 안 바뀐다", same,
			"%s → %s" % [first, _ids(boss)])

	# ③ 보스 판이 서면 그 제약이 걸린다
	g.leg_no = boss
	g._begin_leg()
	var live := []
	for m in g.active_mods:
		live.append(String(m.get("id", "")))
	_ok("보스 판이 서면 정한 것이 걸린다", live == first,
			"정한 것 %s · 걸린 것 %s" % [first, live])
	_ok("목표도 _target_at 과 같다", g.target == g._target_at(boss),
			"%d / %d" % [g.target, g._target_at(boss)])

	# ④ **보스 다음에 보통 판** — 가장 큰 함정의 회귀 검사다
	g.leg_no = 1
	g._begin_leg()
	_ok("보통 판이 서면 제약이 빈다", g.active_mods.is_empty(),
			"걸린 제약 %d개" % g.active_mods.size())
	_ok("보통 판 목표는 맨 목표다", g.target == GameData.target_of(1),
			"%d / %d" % [g.target, GameData.target_of(1)])

	# ⑤ 라운드의 **마지막 상점** — 보스를 막 넘긴 자리다. 여기서 다음
	#    라운드 보스가 안 서면 정작 빌드를 짜는 순간에 명판이 빈다.
	g._new_run()
	g.leg_no = boss
	g._open_shop()
	var nboss: int = g._round_boss(g.leg_no + 1)
	_ok("마지막 상점이 다음 보스를 미리 굴린다",
			nboss > 0 and not _ids(nboss).is_empty(),
			"%d번 판 %s" % [nboss, _ids(nboss)])
	#  같은 상점에서 명판 · 런 정보 · 사탕 둘이 **같은 판**을 집는가.
	#  서로 다른 판을 집으면 예고한 것과 무효가 걸린 것이 갈린다.
	_ok("상점의 「대비할 보스」가 다음 라운드다", g._boss_ahead() == nboss,
			"%d / %d" % [g._boss_ahead(), nboss])
	#  판 선택은 **이번 판부터** 센다 — 아직 안 친 보스를 대비해야 한다.
	g.leg_no = boss
	g._open_leg()
	_ok("판 선택의 「대비할 보스」는 이번 라운드다", g._boss_ahead() == boss,
			"%d / %d" % [g._boss_ahead(), boss])

	# ⑥ 겹치기 — 둘이 서고 축이 서로 다르다
	#  겹치기는 열 하나다 — challenges() 가 실은 행은 row 안에 있다.
	var stack := ""
	for c in GameData.challenges():
		var cr: Dictionary = c.get("row", {})
		if int(str(cr.get("mods_n", "0")).to_int()) >= 2:
			stack = String(c.get("id", ""))
			break
	if stack == "":
		_ok("겹치기 챌린지가 표에 있다", false, "mods_n 2 인 줄이 없다")
	else:
		GameData.challenge = stack
		g._new_run()
		var two := _ids(boss)
		_ok("겹치기 — 둘이 정해진다", two.size() == 2, str(two))
		var ax := {}
		for mid in two:
			ax[String(g._mod_row(mid).get("k", ""))] = true
		_ok("겹치기 — 축이 서로 다르다", ax.size() == two.size(),
				"%s" % str(ax.keys()))
		GameData.challenge = ""

	# ⑦ 새 런이 셋을 전부 비운다.
	#    _new_run 은 끝에 판 선택을 열어 **이 라운드 보스를 바로 굴린다** —
	#    그래서 「빈다」가 아니라 「지난 런 것이 안 남는다」를 잰다.
	g._new_run()
	g.boss_void[boss] = true
	g.boss_void[boss + 99] = true
	for k2 in 9:
		g.boss_seen.append("narrow")
		g.boss_mods[boss + 90 + k2] = PackedStringArray(["narrow"])
	g._new_run()
	_ok("새 런이 지난 런의 무효를 안 끌고 온다", g.boss_void.is_empty(),
			"무효 %d칸" % g.boss_void.size())
	_ok("새 런이 지난 런의 사전을 안 끌고 온다", g.boss_mods.size() <= 1,
			"사전 %d칸 %s" % [g.boss_mods.size(), str(g.boss_mods.keys())])
	_ok("새 런의 기억은 이번 굴림 것뿐",
			g.boss_seen.size() <= maxi(GameData.chal_i("mods_n", 1), 1),
			"기억 %d개 %s" % [g.boss_seen.size(), str(g.boss_seen)])

	# ⑧ dev 가 판을 건너뛰어도 안 바뀐다 — 판 번호를 손으로 밀고 돌아온다
	var back := _ids(boss)
	g.leg_no = boss + per * 2
	g._open_leg()
	g.leg_no = 1
	g._open_leg()
	_ok("판을 오갔다 돌아와도 안 바뀐다", _ids(boss) == back,
			"%s → %s" % [back, _ids(boss)])
