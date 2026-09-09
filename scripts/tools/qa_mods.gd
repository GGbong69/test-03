extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  제약 무게 측정 — 열두 장이 서로 비슷하게 아픈가
#
#  실행:  godot --path . --headless --script scripts/tools/qa_mods.gd
#
#  제약은 셋 중 하나를 고르는 자리다. 하나가 유독 무르면 늘 그것만 고르게
#  되고, 그러면 고르는 화면이 없는 것과 같다. 그래서 "무엇을 때리는가" 가
#  아니라 "얼마나 때리는가" 를 잰다 — mod_probe 는 앞의 것만 본다.
#
#  공통 자는 **여유** 다.
#      여유 = (다트당 기대 점수 × 판의 다트 수) / 목표 점수
#  무장 없이(동전 0장) 균등 조준으로 던져서 잰다. 제약이 점수를 깎든
#  다트를 뺏든 목표를 올리든, 전부 이 한 수에 모인다.
#
#  못 재는 것 셋 — 균등 조준에는 손도 빌드도 없다
#      역풍 · 안개   조준을 때린다. 사람이 얼마나 느려지는가는 여기 안 잡힌다
#      둔화          가진 동전을 잠근다. 동전 0장이면 공짜다
#      헛품          점수가 아니라 골드를 깎는다
#  이 셋은 수를 못 내므로 갈래만 적고 넘어간다.
# ══════════════════════════════════════════════════════════

const N := 4000            # 제약 하나당 던지는 수
const SEED := 20260910

var g = null
var done := false
var rows := []


func _initialize() -> void:
	Save.path = "user://_qa_mods.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


# 균등 조준 — 조준 사각형 위에 고르게 뿌린다. 판보다 사각형이 넓어서
# 37.68% 가 빗나가는 그 모형이다(기획서 15쪽).
func _throw(rng: RandomNumberGenerator) -> Vector2:
	var s: float = GameData.tune("aim_swing")
	return g.BC + Vector2(rng.randf_range(-s, s), rng.randf_range(-s, s))


# 제약 하나를 걸고 한 판을 통째로 재 본다.
func _measure(mod) -> Dictionary:
	# 리그와 다트통이 다트 수와 곡선을 민다. 둘 다 고정해야 제약끼리 비교가 된다 —
	# 안 고정하면 다트통이 무작위로 골라져 기준선이 판마다 흔들린다.
	g._new_run()
	# _new_run 뒤에 고정한다 — 앞에 두면 그 안에서 다시 골라져 덮인다.
	GameData.league = "white"
	GameData.pack = "base"
	g.leg_no = 3                       # 제약은 보스 판에만 걸린다
	g.owned.clear()                    # 무장 없이 — 판 자체의 값만 본다
	g.sealed = -1
	g.active_mods = [] if mod == null else [mod]
	# 목표는 _open_leg 이 세운다. 그 자리를 안 지나므로 같은 식을 여기서 쓴다 —
	# "높은 목표" 만 목표 자체를 올리고 나머지는 기본값 그대로다.
	var base: int = GameData.target_of(g.leg_no)
	var target: int = base
	if mod != null and String(mod.get("k", "")) == "target_mul":
		target = int(ceil(float(base) * float(mod.v)))
	g.target = target
	g._start_leg()
	var darts: int = int(g.darts_left)
	var reward: int = int(GameData.reward_of(g.leg_no))

	# 목표를 멀리 밀어 판이 안 끝나게 한다. 끝나면 남은 발이 안 던져져
	# 표본이 제약마다 달라지고, 그러면 잰 것이 서로 비교가 안 된다.
	g.target = 1 << 40
	g.total = 0
	g.darts_left = N + 10

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED                    # 제약마다 같은 자리에 꽂는다
	for i in N:
		g.aim = _throw(rng)
		g._land()
		while not g.queue.is_empty():
			g._next_step()
	var per: float = float(g.total) / float(N)
	return {
		"per": per, "darts": darts, "target": target, "reward": reward,
		"slack": per * float(darts) / float(maxi(target, 1)),
	}


func _process(_d: float) -> bool:
	if done:
		return false
	done = true
	g.set_process(false)
	for i in 8:
		g._process(1.0 / 60.0)
	g._autoplay = false                # _land 가 조준을 덮어쓰지 않게 한다

	var base := _measure(null)
	print("무장 없는 기준선 — 다트당 %.2f점 · 다트 %d개 · 목표 %d · 여유 %.3f\n"
			% [base.per, base.darts, base.target, base.slack])

	var skip := {"gauge_mul": "조준", "fog": "조준", "seal_items": "빌드",
			"reward_mul": "골드"}
	print("%-10s %-12s %8s %6s %8s %8s  %s"
			% ["제약", "축", "다트당", "다트", "목표", "여유", "기준선 대비"])
	for m in GameData.modifiers():
		var ax := String(m.get("k", ""))
		var r := _measure(m)
		var drop: float = 1.0 - r.slack / base.slack
		var note := ""
		if skip.has(ax):
			note = "  ← %s 을 때린다. 이 자로는 못 잼" % skip[ax]
		rows.append({"n": String(m.get("n", "")), "ax": ax, "drop": drop,
				"blind": skip.has(ax)})
		print("%-10s %-12s %8.2f %6d %8d %8.3f  %+6.1f%%%s"
				% [m.get("n", ""), ax, r.per, r.darts, r.target, r.slack,
				-drop * 100.0, note])

	var real := []
	for r in rows:
		if not r.blind:
			real.append(r)
	real.sort_custom(func(a, b): return a.drop > b.drop)
	print("\n잰 것 %d장 — 아픈 순서" % real.size())
	for r in real:
		print("  %-10s %+6.1f%%" % [r.n, -r.drop * 100.0])
	if real.size() >= 2:
		var hi: float = real[0].drop
		var lo: float = real[real.size() - 1].drop
		print("\n가장 아픈 것과 가장 무른 것의 차 %.1f%%p (%s %.1f%% ↔ %s %.1f%%)"
				% [(hi - lo) * 100.0, real[0].n, hi * 100.0,
				real[real.size() - 1].n, lo * 100.0])
	quit()
	return true
