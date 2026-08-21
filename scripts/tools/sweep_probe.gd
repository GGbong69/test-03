extends SceneTree

#  쓸기 프로브
#
#  주장 하나를 잰다: **훑기가 끝나는 순간 판 위에 물건이 하나도 안 남는다.**
#  _sweep_deal 에 남은 것을 마저 보내는 안전망이 있지만, 그 안전망이 실제로
#  일하고 있으면 화면에서는 물건이 팝 하고 사라진다. 그러니 안전망이 한 번도
#  안 쓰이는 것까지 재야 주장이 성립한다.
#
#  쓸기는 사람 손에만 붙어 있어서(_reroll 의 drop_fast 갈래) 오토플레이도
#  다른 도구도 이 경로를 안 밟는다. 여기서만 밟는다.
#
#  실행:  godot --path . --script scripts/tools/sweep_probe.gd -- <시드> <횟수>

const GameData = preload("res://scripts/data.gd")

var g = null
var step := 0
var fails := 0
var rolls := 200
var seed_v := 20260821


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		seed_v = int(a[0])
	if a.size() > 1:
		rolls = int(a[1])
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _ok(name: String, cond: bool, detail: String) -> void:
	print("  %s %-30s %s" % ["OK  " if cond else "실패", name, detail])
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	step += 1
	if step < 12:                      # _ready 가 돌아 font 가 서기를 기다린다
		return false
	seed(seed_v)
	g.set_process(false)               # 시계를 손으로만 감는다

	var sub: float = g.DROP.sub
	var t1: float = g.SWEEP.reach + g.SWEEP.rake
	var worst_left := 0                # 훑기가 못 치운 물건 수의 최대
	var worst_u := -1.0e9              # deal 직전 남은 물건의 최대 u
	var n_bad_stock := 0
	var n_bad_waste := 0
	var n_slow := 0
	var max_steps := 0

	for r in rolls:
		g.round_no = 1 + (r % 7)
		g.gold = 99
		g._open_shop()
		g._drop_settle()
		var n: int = g.stock.size()

		g._sweep_begin()
		var by_rake := -1
		var left_u := -1.0e9
		var k := 0
		while g.sweep_live and k < 4000:
			k += 1
			var was_dealt: bool = g.sweep_dealt
			var pre: int = g.waste.size()
			if not was_dealt:
				# deal 이 이 스텝에서 터질 수 있다. 터지기 전 상태를 붙잡는다.
				left_u = -1.0e9
				for it in g.drop:
					if not it.gone:
						left_u = maxf(left_u, float(it.u))
			g._sweep_update(sub)
			if g.sweep_dealt and not was_dealt:
				by_rake = pre
			g.drop_t += sub
			g._drop_step(sub)
			g._waste_update(sub)
		max_steps = maxi(max_steps, k)
		if k >= 4000:
			n_slow += 1

		worst_left = maxi(worst_left, n - by_rake)
		if n - by_rake > 0:
			worst_u = maxf(worst_u, left_u)
		if g.stock.size() != n or g.drop.size() != n:
			n_bad_stock += 1
		# 복귀가 끝나도 waste 는 fall_t 만큼 더 산다. 그만큼 더 감아 비운다.
		var q := 0
		while g.waste.size() > 0 and q < 400:
			q += 1
			g._waste_update(sub)
		if g.waste.size() > 0:
			n_bad_waste += 1

	_ok("훑기가 판을 비운다", worst_left == 0,
			"안전망이 치운 물건 최대 %d개%s" % [worst_left,
			"" if worst_left == 0 else " (최대 u %.1f)" % worst_u])
	_ok("새 판이 같은 수로 선다", n_bad_stock == 0, "어긋난 롤 %d" % n_bad_stock)
	_ok("waste 가 비워진다", n_bad_waste == 0, "안 빈 롤 %d" % n_bad_waste)
	_ok("타임라인이 끝난다", n_slow == 0, "최대 %d 서브스텝 (예산 4000)" % max_steps)

	print("%d롤 · 시드 %d — %s" % [rolls, seed_v,
			"네 검사 전부 통과" if fails == 0 else "실패 %d건" % fails])
	quit(fails)
	return true
