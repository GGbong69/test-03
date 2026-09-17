extends SceneTree
# 판 도중에 동전 슬롯이 바뀌면 조준·계산 방식이 그 자리에서 따라가는가.
#   godot --headless --path . --script scripts/tools/qa_modes_live.gd
#
# 카우보이(십자 조준)를 든 채 판에 서서 팔았는데 그 판 끝까지 십자가
# 남았다(사용자 제보, 2026-09-17). 방식을 판 시작에만 읽었기 때문이다.
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_ml_g.cfg"
	Save.path = "user://_qa_ml.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	_run()
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-44s %s" % ["통과" if cond else "실패", nm, note])


func _item(id: String) -> Dictionary:
	for it in GameData.items():
		if String(it.id) == id:
			return it.duplicate()
	return {}


#  판에 선다 — 동전을 쥐여 주고 판을 열어 자루 하나를 집는다.
func _leg_with(ids: Array) -> void:
	g.owned.clear()
	for id in ids:
		g.owned.append(_item(String(id)))
	g.sealed = -1
	g._panel_reset()
	g._start_leg()
	g._swap_skip()
	g.state = g.S.PICK
	g._pick_dart(0)


func _run() -> void:
	g._new_run()
	g._tutor_close()
	var cow := _item("r04")
	var sun := _item("r01")
	var dec := _item("l01")
	if cow.is_empty() or sun.is_empty() or dec.is_empty():
		_ok("검사할 동전이 표에 있다(r04 · r01 · l01)", false)
		return
	var cow_aim := String(cow.get("aim", ""))
	var sun_aim := String(sun.get("aim", ""))

	# ── 조준 중에 판다 ──────────────────────────────────
	_leg_with(["r04"])
	_ok("카우보이를 들면 판이 그 조준으로 선다", g.aim_mode == cow_aim and g.state == g.S.AIM_V,
			"'%s' · state %d" % [g.aim_mode, g.state])
	g._sell(0)
	_ok("조준 중에 팔면 그 자리에서 기본 조준", g.aim_mode == "std", "'%s'" % g.aim_mode)
	_ok("자루는 쥔 채 조준 첫 칸이다", g.state == g.S.AIM_V and g.grip_pick == 0,
			"state %d · 자루 %d" % [g.state, g.grip_pick])

	# ── 잠근 뒤에 판다 — 잠금이 풀린다 ──────────────────
	_leg_with(["r04"])
	g._advance()                  # 한 번에 잠그는 방식이라 곧장 확인
	var locked: int = g.state
	g._sell(0)
	_ok("잠근 뒤 팔면 잠금이 풀리고 첫 칸부터", locked == g.S.CONFIRM
			and g.state == g.S.AIM_V and g.aim_mode == "std",
			"잠근 뒤 %d → %d · '%s'" % [locked, g.state, g.aim_mode])

	# ── 기본 조준에서 반쯤 잠근 채 순서를 바꾼다 ────────
	_leg_with(["c01", "r04", "r01"])
	_ok("앞자리 조준 동전이 쥔다", g.aim_mode == cow_aim, "'%s'" % g.aim_mode)
	g._rack_reorder(2, 0)         # 태양계를 맨 앞으로
	_ok("순서를 바꾸면 앞자리 동전의 조준으로", g.aim_mode == sun_aim, "'%s'" % g.aim_mode)
	_leg_with(["r01"])
	g._advance()                  # 원 조준은 두 칸 — 첫 칸만 잠근다
	var half: int = g.state
	g.owned.append(_item("r04"))
	g._panel_reset()
	g._rack_reorder(1, 0)
	_ok("반쯤 잠근 채 방식이 바뀌면 첫 칸부터", half == g.S.AIM_H
			and g.state == g.S.AIM_V and g.aim_mode == cow_aim,
			"%d → %d · '%s'" % [half, g.state, g.aim_mode])

	# ── 방식이 안 바뀌면 조준을 안 건드린다 ──────────────
	_leg_with(["c01", "r04"])
	g._advance()
	g._sell(0)                    # 조준과 상관없는 동전
	_ok("상관없는 동전을 팔면 잠금이 그대로", g.state == g.S.CONFIRM and g.aim_mode == cow_aim,
			"state %d · '%s'" % [g.state, g.aim_mode])

	# ── 날아가는 중 — 그 발은 그대로 ─────────────────────
	_leg_with(["r04"])
	g.state = g.S.FLY
	g._sell(0)
	_ok("날아가는 중에 팔면 그 발은 그대로 날고 방식만 바뀐다",
			g.state == g.S.FLY and g.aim_mode == "std",
			"state %d · '%s'" % [g.state, g.aim_mode])

	# ── 봉인된 조준 동전 ─────────────────────────────────
	_leg_with(["r04", "r01"])
	g.sealed = 0
	g._rack_reorder(1, 1)         # 제자리 — 다시 읽게만 한다
	_ok("봉인된 동전은 조준을 못 쥔다", g.aim_mode == sun_aim, "'%s'" % g.aim_mode)
	g.sealed = -1

	# ── 계산 방식 ─────────────────────────────────────────
	_leg_with(["l01"])
	var sm := String(dec.get("score", ""))
	_ok("데칼코마니를 들면 그 계산", g.score_mode == sm, "'%s'" % g.score_mode)
	g._sell(0)
	_ok("판 도중에 팔면 그 자리에서 다트통 계산으로", g.score_mode == GameData.score_mode(),
			"'%s'" % g.score_mode)

	# ── 상점에서 판다 — 상태는 안 건드린다 ───────────────
	_leg_with(["r04"])
	g.state = g.S.SHOP
	g._sell(0)
	_ok("상점에서 팔면 상태는 그대로 · 방식은 기본", g.state == g.S.SHOP and g.aim_mode == "std",
			"state %d · '%s'" % [g.state, g.aim_mode])

	# ── 판 시작은 조준을 다시 세우지 않는다 ──────────────
	#  (빗각의 축 뽑기가 전역 난수를 한 칸 밀면 같은 씨의 런이 갈라진다)
	g.owned = [_item("r15")]
	g.state = g.S.AIM_V
	g.aim_mode = "std"
	seed(4242)
	g._modes_refresh(false)
	var after := randi()
	seed(4242)
	var clean := randi()
	_ok("판 시작 읽기는 난수를 안 민다", after == clean and g.aim_mode == "tilt",
			"'%s'" % g.aim_mode)
	g.owned.clear()
