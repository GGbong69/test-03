extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  리그 8단 회귀 검사
#
#  실행:  godot --path . --headless --quit-after 600 --script scripts/tools/league_probe.gd
#  종료 코드 = 실패 개수
#
#  리그은 표도 배관도 오래 전부터 있었는데 스위치를 켜는 손이 없었다 —
#  game.gd 에 `GameData.league =` 대입이 0건이라 rounds.csv 의 곡선 두 열이
#  통째로 죽어 있었다. 그런 자리는 한 번 살려 두면 조용히 다시 죽으므로
#  여기서 못 박는다.
#
#  재는 것
#    ① 곡선 — 리그을 올리면 목표가 오른다. base 는 안 움직인다
#    ② 계단 — 여덟 단이 순서대로 서고 선행이 바로 앞 단이다
#    ③ 미는 값 — 봉인·다트·보상·가격이 표대로 나온다
#    ④ 모르는 id 는 첫 단으로 떨어진다 (옛 저장이 게임을 안 깬다)
#    ⑤ 리그은 타이틀이 아니라 새 런 화면에서 고른다 — 발라트로의 run_setup
#       자리다. 타이틀에 두었다가 되돌린 적이 있으므로 흐름을 못 박는다
# ══════════════════════════════════════════════════════════

var fails := 0


func _say(ok: bool, name: String, detail := "") -> void:
	print("  %s %-28s %s" % ["OK  " if ok else "실패", name, detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	var rows := GameData.leagues()
	_say(rows.size() == 8, "리그 여덟 단", "%d단" % rows.size())

	# ① 곡선 — 마지막 판의 보스 판(24판)으로 잰다
	var last: int = GameData.legs_n()
	GameData.league = ""
	var t_white := GameData.target_of(last)
	GameData.league = "blue"
	var t_blue := GameData.target_of(last)
	GameData.league = "yellow"
	var t_yellow := GameData.target_of(last)
	_say(t_blue > t_white and t_yellow > t_blue, "곡선이 단마다 가팔라진다",
			"흰 %d < 파랑 %d < 노랑 %d" % [t_white, t_blue, t_yellow])

	# 초록 리그은 곡선이 base 다 — 여유만 깎고 목표는 그대로여야 한다
	GameData.league = "green"
	_say(GameData.target_of(last) == t_white, "초록 단은 곡선을 안 건드린다",
			"목표 %d" % GameData.target_of(last))

	# ② 계단 — 선행이 바로 앞 단이다
	var chain := true
	for i in rows.size():
		var pq := String(rows[i].get("prereq", ""))
		var want := "" if i == 0 else String(rows[i - 1].get("id", ""))
		if pq != want:
			chain = false
	_say(chain, "선행이 바로 앞 단이다",
			"%s → … → %s" % [rows[0].get("name", ""), rows[rows.size() - 1].get("name", "")])

	# ③ 미는 값 — 표에 적힌 대로 나온다
	GameData.league = "green"
	_say(int(GameData.league_v("reward_small", 9)) == 0,
			"초록 단은 작은 판 보상이 0", "%d" % int(GameData.league_v("reward_small", 9)))
	GameData.league = "purple"
	_say(int(GameData.league_v("seal_items", 0)) == 1,
			"보라 단은 스티커를 봉인한다", "%d장" % int(GameData.league_v("seal_items", 0)))
	GameData.league = "red"
	_say(int(GameData.league_v("darts_add", 0)) == -1,
			"붉은 단은 다트를 깎는다", "%+d발" % int(GameData.league_v("darts_add", 0)))
	GameData.league = "black"
	var costly: bool = GameData.league_v("shop_cost_mul", 1.0) > 1.0 \
			and int(GameData.league_v("rent", 0)) > 0 \
			and int(GameData.league_v("perish", 0)) > 0
	_say(costly, "검정 단은 값·유지비·삭음을 다 얹는다",
			"×%.2f · 유지비 %d · 삭음 %d판" % [GameData.league_v("shop_cost_mul", 1.0),
			int(GameData.league_v("rent", 0)), int(GameData.league_v("perish", 0))])

	# ④ 모르는 id — 옛 저장이 게임을 안 깨야 한다
	GameData.league = "nosuch"
	var fb := GameData.league_row()
	_say(String(fb.get("id", "")) == String(rows[0].get("id", ""))
			and GameData.target_of(last) == t_white,
			"모르는 리그은 첫 단으로 떨어진다", String(fb.get("name", "")))

	# ⑤ 흐름 — 타이틀의 시작은 런을 안 열고 새 런 화면을 연다
	GameData.league = ""
	Save.path = "user://_probe_stake.cfg"
	Save.wipe()
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.state = g.S.TITLE
	g._click(g._menu_rect(0).get_center())
	_say(g.state == g.S.NEWRUN, "타이틀의 시작은 새 런 화면을 연다",
			"state %d" % g.state)

	# 잠긴 단은 못 고른다 — 첫 판에는 흰 단만 열려 있다
	var before := GameData.league
	g._click(g._league_rect(3).get_center())
	_say(GameData.league == before, "잠긴 리그은 안 골라진다", "리그 '%s'" % GameData.league)

	# 열린 단은 눌리고 저장에 남는다
	Save.unlock(GameData.league_key("green"))
	g._click(g._league_rect(1).get_center())
	_say(GameData.league == "green" and String(Save.get_set("league", "")) == "green",
			"열린 리그은 눌리고 저장된다", "리그 '%s'" % GameData.league)

	# 시작이 런을 연다
	g._click(g._newrun_go().get_center())
	_say(g.state != g.S.NEWRUN and g.leg_no == 1, "시작이 런을 연다",
			"state %d · 판 %d" % [g.state, g.leg_no])

	# 리그은 팩마다 따로 뚫린다 — 키에 팩 id 가 들어 있다
	_say(GameData.league_key("green", "base") == "league:base:green"
			and GameData.league_key("green", "other") == "league:other:green",
			"리그 해금은 팩마다 갈린다", GameData.league_key("green", "base"))

	# 설명 줄이 서로 안 겹친다. 여덟 단을 전부 깔아 자리를 실제로 세어
	# 본다 — 검정 리그의 일곱째 줄이 오른쪽 칸 첫 줄 위에 찍히던 사고가
	# 여기 없으면 눈으로만 보이고, 그 단을 열어 보기 전에는 눈에도 안 띈다.
	var worst := ""
	var most := 0
	for row in GameData.leagues():
		GameData.league = String(row.get("id", ""))
		var lines: Array = g._league_lines()
		most = maxi(most, lines.size())
		var seen := {}
		for li in lines.size():
			var at: Vector2 = g._league_line_at(li)
			if seen.has(at):
				worst = "%s — %d번 줄이 %d번과 같은 자리" % [GameData.league, li, seen[at]]
			seen[at] = li
	_say(worst == "", "설명 줄이 안 겹친다",
			worst if worst != "" else "최대 %d줄 · 칸당 %d줄 × 2" % [most, g.STAKE_ROWS])
	_say(most <= g.STAKE_ROWS * 2,
			"가장 긴 단이 칸 안에 든다", "%d줄 / %d칸" % [most, g.STAKE_ROWS * 2])

	GameData.league = ""
	print("\n%s" % ("실패 %d건" % fails if fails > 0 else "열여섯 검사 전부 통과"))
	quit(mini(fails, 125))
