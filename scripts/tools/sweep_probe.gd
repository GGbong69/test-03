extends SceneTree

#  쓸기 프로브
#
#  주장 하나를 잰다: **훑기가 끝나는 순간 판 위에 물건이 하나도 안 남는다.**
#  _sweep_deal 에 남은 것을 마저 보내는 안전망이 있지만, 그 안전망이 실제로
#  일하고 있으면 화면에서는 물건이 제자리에서 깨진다 — 날에 닿지도 않은
#  자리에서. 그러니 안전망이 한 번도 안 쓰이는 것까지 재야 주장이 성립한다.
#
#  **재는 방식을 2026-09-18 에 다시 적었다.** 전에는 deal 직전의
#  waste.size() 를 세어 「몇이 구멍으로 빠졌나」로 잰다. 이제 물건은 구멍이
#  아니라 창구 턱에 처박혀 부서지므로 waste 에 안 들어간다 — 같은 자를 그대로
#  두면 무조건 실패한다. 주장은 그대로 두고 자만 바꾼다: **drop 에 gone 이
#  아닌 것이 0 인가**(판이 비었다) + **smash_deal_n 이 0 인가**(안전망이
#  안 일했다). 연출을 바꾸면 단언도 같이 다시 적는다.
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
	var net := 0                       # 안전망이 깬 물건 수 (전 롤 합)
	var max_shards := 0
	var max_grit := 0
	var max_shake := 0.0

	for r in rolls:
		g.leg_no = 1 + (r % 7)
		g.gold = 99
		g._open_shop()
		g._drop_settle()
		var n: int = g.stock.size()

		g._sweep_begin()
		var left := -1
		var left_u := -1.0e9
		var k := 0
		while g.sweep_live and k < 4000:
			k += 1
			var was_dealt: bool = g.sweep_dealt
			if not was_dealt:
				# deal 이 이 스텝에서 터질 수 있다. 터지기 전 상태를 붙잡는다.
				var cnt := 0
				var mu := -1.0e9
				for it in g.drop:
					if not it.gone:
						cnt += 1
						mu = maxf(mu, float(it.u))
				left = cnt
				left_u = mu
			g._sweep_update(sub)
			g.drop_t += sub
			g._drop_step(sub)
			g._waste_update(sub)
			g._smash_update(sub)
			max_shards = maxi(max_shards, g.shards.size())
			max_grit = maxi(max_grit, g.grit.size())
			max_shake = maxf(max_shake, float(g.shake))
		max_steps = maxi(max_steps, k)
		if k >= 4000:
			n_slow += 1

		worst_left = maxi(worst_left, left)
		if left > 0:
			worst_u = maxf(worst_u, left_u)
		net += int(g.smash_deal_n)
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
			"rake 끝에 남은 물건 최대 %d개%s" % [worst_left,
			"" if worst_left <= 0 else " (최대 u %.1f)" % worst_u])
	_ok("안전망이 안 쓰인다", net == 0, "_sweep_deal 이 깬 수 %d" % net)
	_ok("새 판이 같은 수로 선다", n_bad_stock == 0, "어긋난 롤 %d" % n_bad_stock)
	_ok("waste 가 비워진다", n_bad_waste == 0,
			"안 빈 롤 %d (이제 motion_off 전용 길이다)" % n_bad_waste)
	_ok("타임라인이 끝난다", n_slow == 0, "최대 %d 서브스텝 (예산 4000)" % max_steps)
	print("  동시 최대 — 조각 %d · 부스러기 %d · 흔들림 %.1f"
			% [max_shards, max_grit, max_shake])

	print("%d롤 · 시드 %d — %s" % [rolls, seed_v,
			"다섯 검사 전부 통과" if fails == 0 else "실패 %d건" % fails])
	quit(fails)
	return true
