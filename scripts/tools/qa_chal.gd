extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  챌린지 QA — 일곱이 실제로 규칙을 바꾸는가
#
#  실행:  godot --path . --headless --script scripts/tools/qa_chal.gd
#  종료 코드 = 실패 개수
#
#  챌린지는 표 한 장이 튜닝을 덮는 꼴이다. 새 계층을 안 팠으므로 "표에
#  적었는데 아무 데도 안 닿는" 실패가 가장 나기 쉽다 — 열마다 그것이
#  실제로 게임 값에 실리는지를 하나씩 본다.
#
#  대가와 보상이 한 줄에 같이 있는 것이 이 표의 규약이라, 둘 다 본다.
# ══════════════════════════════════════════════════════════

var g = null
var fails := 0
var done := false


func _initialize() -> void:
	Save.path = "user://_qa_chal.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(nm: String, cond: bool, detail: String) -> void:
	print("  %s %-28s %s" % ["OK  " if cond else "실패", nm, detail])
	if not cond:
		fails += 1


func _arm(id: String) -> void:
	GameData.challenge = id
	GameData.league = "white"
	GameData.pack = "base"
	g._new_run()
	g.leg_no = 1
	g._start_leg()


func _process(_d: float) -> bool:
	if done:
		return false
	done = true
	g.set_process(false)
	for i in 8:
		g._process(1.0 / 60.0)
	g._autoplay = false

	print("챌린지 검사 — 표가 실제로 게임을 미는가\n")

	# 표에 적힌 일곱이 다 있는가 (없음 한 줄 포함 여덟)
	var ids := []
	for c in GameData.challenges():
		ids.append(String(c.id))
	_ok("표가 선다", ids.size() == 8, "%d줄 %s" % [ids.size(), str(ids)])

	# ── 없음 — 기준선 ─────────────────────────────────────
	_arm("none")
	var base_slots: int = GameData.max_items()
	var base_tgt: int = GameData.target_of(3)
	var base_gold: int = int(g.gold)
	print("  기준선 — 슬롯 %d · 목표(판3) %d · 시작 골드 %d"
			% [base_slots, base_tgt, base_gold])

	# ── 홑장 — 슬롯 하나 · 효과 세 배 ────────────────────
	_arm("solo")
	_ok("홑장 — 슬롯이 하나다", GameData.max_items() == 1,
			"%d → %d" % [base_slots, GameData.max_items()])
	# 효과 배수는 정산 큐에 실린 수로 본다
	g.owned.clear()
	var coin: Dictionary = GameData.items()[0].duplicate()   # 무조건 배수 +4
	coin.gs = 0
	g.owned.append(coin)
	g.target = 1 << 30
	g.total = 0
	g.darts_left = 9
	g.aim = g.BC + Vector2(0.0, -g.R * 0.75)
	g._land()
	var got := 0
	for q in g.queue:
		if String(q.get("k", "")) == "item":
			got = int(q.get("v", 0))
	var want: int = int(coin.v) * 3
	_ok("홑장 — 효과가 세 배", got == want,
			"큐에 %d (기본 %d · 바라는 값 %d)" % [got, int(coin.v), want])

	# ── 깜깜이 — 안개 상시 · 목표 0.7배 ───────────────────
	_arm("blind")
	_ok("깜깜이 — 안개가 상시로 켜진다", g.mod_v("fog", 0.0) > 0.0,
			"fog %.1f · 걸린 제약 %d개" % [g.mod_v("fog", 0.0), g.active_mods.size()])
	var bt: int = GameData.target_of(3)
	_ok("깜깜이 — 목표가 0.7배", bt < base_tgt,
			"%d → %d" % [base_tgt, bt])

	# ── 외상 — 빚으로 시작 · 이자 두 배 ───────────────────
	_arm("debt")
	_ok("외상 — 빚으로 시작한다", g.gold == -20, "골드 %d" % g.gold)

	# ── 빈손 — 버는 길이 끊기고 뱃지가 두 배 ──────────────
	_arm("empty")
	g.gold = 0
	g.total = g.target
	g.darts_left = 3
	g._settle_clear()
	_ok("빈손 — 클리어해도 골드가 안 는다", g.gold == 0, "골드 %d" % g.gold)
	_arm("empty")
	g.gold = 0
	var tag := {}
	for t in GameData.tags():
		if String(t.get("kind", "")) == "gold":
			tag = t
			break
	if tag.is_empty():
		_ok("빈손 — 골드 뱃지가 표에 있다", false, "못 찾음")
	else:
		g._take_tag(tag)
		_ok("빈손 — 뱃지 골드가 두 배", g.gold == int(tag.get("v", 0)) * 2,
				"골드 %d (뱃지 %d)" % [g.gold, int(tag.get("v", 0))])

	# ── 큰손 — 물건이 공짜 ────────────────────────────────
	_arm("rich")
	_ok("큰손 — 값이 0 이다", g._league_cost(12) == 0,
			"12골드 → %d" % g._league_cost(12))

	# ── 목표물 — 한 칸만 산다 ─────────────────────────────
	_arm("mark")
	_ok("목표물 — 판마다 칸을 뽑는다", g.mark_sec >= 0, "칸 %d" % g.mark_sec)
	# 뽑힌 칸에 꽂으면 곱해지고, 다른 칸은 0 이다
	var sw := 18.0 * PI / 180.0
	var hit: Vector2 = g.BC + Vector2(sin(float(g.mark_sec) * sw),
			-cos(float(g.mark_sec) * sw)) * g.R * 0.75
	var other: int = (g.mark_sec + 5) % 20
	var miss: Vector2 = g.BC + Vector2(sin(float(other) * sw),
			-cos(float(other) * sw)) * g.R * 0.75
	_ok("목표물 — 뽑힌 칸은 곱해진다", int(g.hit_info(hit).base) > 0,
			"칸 %d · 값 %d" % [g.mark_sec, int(g.hit_info(hit).base)])
	g.target = 1 << 30
	g.total = 0
	g.darts_left = 9
	g.aim = miss
	g._land()
	while not g.queue.is_empty():
		g._next_step()
	_ok("목표물 — 다른 칸은 0 이다", g.total == 0,
			"다른 칸(%d)에 꽂고 점수 %d" % [other, g.total])

	# ── 겹치기 — 제약이 둘 ────────────────────────────────
	_arm("stack")
	var boss := -1
	for n in range(1, GameData.legs_n() + 1):
		if GameData.is_boss(n):
			boss = n
			break
	g.leg_no = boss
	g._open_stage()
	if g.stage_pick.size() < 2:
		_ok("겹치기 — 보스 판이 열린다", false, "카드 %d장" % g.stage_pick.size())
	else:
		g._pick_stage(0)
		_ok("겹치기 — 제약이 둘 걸린다", g.active_mods.size() == 2,
				"걸린 제약 %d개" % g.active_mods.size())
		var seen := {}
		for m in g.active_mods:
			seen[String(m.get("id", ""))] = true
		_ok("겹치기 — 서로 다른 둘이다", seen.size() == 2, "%s" % str(seen.keys()))

	GameData.challenge = ""
	print("\n%s" % ("전부 통과" if fails == 0 else "실패 %d건" % fails))
	quit(mini(fails, 125))
	return true
