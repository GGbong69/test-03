extends SceneTree

#  부서짐 프로브 — 「턱에 처박힌다」가 수로도 성립하는가
#
#  sweep_probe 가 「판이 비는가」 하나를 재는 자리라면, 여기는 그 뒤에 남는
#  것들을 잰다: 조각이 몇 개까지 한꺼번에 서는가 · 새 매물이 내려오기 전에
#  다 죽는가 · 도착이 훑기 안에 드는가 · 순서가 안 뒤집히는가 · 날이 날린
#  것을 다시 안 따라잡는가 · 조각이 화면 밖에 산 채로 안 남는가 ·
#  흔들림 상한 · 한 쓸기의 소리 수.
#
#  시계를 손으로 감는다(g.set_process(false)) — 쓸기는 사람 손에만 붙어
#  있어서 오토플레이도 다른 도구도 이 경로를 안 밟는다.
#  sweep_probe 와 같이 sub 을 「한 프레임」으로 삼는다. 실제로는 한 프레임에
#  서브스텝이 여럿이지만, 물리가 프레임률과 무관한 것이 이미 증명돼 있으므로
#  (DROP.sub 주석) 160fps 로 돌린 것과 같다.
#
#  실행:  godot --headless --path . --script scripts/tools/qa_smash.gd -- <시드> <횟수>

const GameData = preload("res://scripts/data.gd")

var g = null
var step := 0
var fails := 0
var rolls := 200
var seed_v := 20260918


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		seed_v = int(a[0])
	if a.size() > 1:
		rolls = int(a[1])
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _ok(name: String, cond: bool, detail: String) -> void:
	print("  %s %-28s %s" % ["OK  " if cond else "실패", name, detail])
	if not cond:
		fails += 1


#  던져진 물건이 펠트에 처음 닿기까지. h·vh 에서 역산한다 — 실제로 감아
#  재면 매 롤 2천 스텝이 더 든다.
func _land_t(it: Dictionary, gv: float) -> float:
	var h: float = float(it.h)
	var vh: float = float(it.vh)
	return float(it.t0) + (vh + sqrt(vh * vh + 2.0 * gv * h)) / gv


func _process(_d: float) -> bool:
	step += 1
	if step < 12:
		return false
	seed(seed_v)
	g.set_process(false)

	var sub: float = g.DROP.sub
	var t1: float = g.SWEEP.reach + g.SWEEP.rake
	var max_shards := 0
	var max_grit := 0
	var max_shake := 0.0
	var max_hit_t := 0.0             # 가장 늦은 부딪힘(sweep_t)
	var n_drag := 0                  # 날린 적 없이 턱에 닿은 물건
	var min_hit_v := 1.0e9           # 닿는 순간의 최소 속력(면px/s)
	var n_out := 0                   # 화면 밖에 산 조각 점
	var max_snd := 0                 # 한 쓸기의 소리 수
	var min_gap := 1.0e9             # 마지막 조각 사망 → 첫 매물 착지 여유(초)
	var x_lo := 1.0e9
	var x_hi := -1.0e9
	var y_lo := 1.0e9
	var y_hi := -1.0e9
	var hit_ms := []                 # 매물 넷일 때의 부딪힘 시각(실측값 찍기용)
	var spread_ms := 0.0             # 첫 부딪힘 → 마지막 부딪힘(초)

	for r in rolls:
		g.leg_no = 1 + (r % 7)
		g.gold = 99
		g._open_shop()
		#  매물 2~9 를 고루 돈다. 조각 예산이 매물 수로 갈리므로(5/4/3)
		#  한 수만 보면 세 갈래 중 하나만 재는 셈이 된다.
		var want: int = 2 + (r % 8)
		var n0: int = g.stock.size()
		if n0 > 0:
			while g.stock.size() < want:
				g.stock.append(g.stock[g.stock.size() % n0].duplicate(true))
			while g.stock.size() > want:
				g.stock.remove_at(g.stock.size() - 1)
		g._drop_roll()
		g._drop_settle()
		var n: int = g.stock.size()

		g._sweep_begin()
		var gone := []
		var vu_pre := []
		var was_flung := []
		for i in n:
			gone.append(false)
			vu_pre.append(0.0)
			was_flung.append(false)
		var t_first := -1.0
		var t_last := 0.0
		var k := 0
		var deal_seen := false
		var first_land := 1.0e9
		var t_real := 0.0
		var last_alive := 0.0
		var snd0: int = g.smash_snd_n
		while k < 4000 and (g.sweep_live or not g.shards.is_empty()
				or not g.grit.is_empty()):
			k += 1
			t_real += sub
			g._sweep_update(sub)
			g.drop_t += sub
			g._drop_step(sub)
			g._waste_update(sub)
			g._smash_update(sub)
			for i in n:
				if gone[i]:
					continue
				if bool(g.drop[i].get("flung", false)):
					was_flung[i] = true
				if g.drop[i].gone:
					gone[i] = true
					max_hit_t = maxf(max_hit_t, float(g.sweep_t))
					min_hit_v = minf(min_hit_v, absf(vu_pre[i]))
					if not was_flung[i]:
						n_drag += 1
					if t_first < 0.0:
						t_first = t_real
					t_last = t_real
					if n == 4 and hit_ms.size() < 4:
						hit_ms.append(t_real)
				else:
					#  닿는 순간 vu 는 이미 0 으로 지워진 뒤다(_smash_at) —
					#  한 스텝 전 값을 들고 있다가 그것으로 잰다.
					vu_pre[i] = float(g.drop[i].vu)
			if not deal_seen and g.sweep_dealt:
				deal_seen = true
				var lg: float = g.DROP.g
				for it in g.drop:
					first_land = minf(first_land, t_real + _land_t(it, lg))
			max_shards = maxi(max_shards, g.shards.size())
			max_grit = maxi(max_grit, g.grit.size())
			max_shake = maxf(max_shake, float(g.shake))
			if not g.shards.is_empty():
				last_alive = t_real
			for s in g.shards:
				if float(s.t) < 0.0:
					continue
				#  **중심**을 잰다. 도형 자체는 면에서 ±22 를 뻗으므로 먼
				#  벽에 붙은 조각의 윗귀가 레일을 넘는데, 그것은 _smash_draw
				#  가 덮개 선에 대고 자른다. 여기서 재는 것은 「조각이
				#  트레이를 떠나지 않는가」다.
				var c: Vector2 = g._p2s(float(s.u), float(s.w), float(s.h))
				x_lo = minf(x_lo, c.x)
				x_hi = maxf(x_hi, c.x)
				y_lo = minf(y_lo, c.y)
				y_hi = maxf(y_hi, c.y)
				if (c.x < 0.0 or c.x > g.VIEW.x
						or c.y < g.TBL.fy or c.y > g.TBL.ny):
					n_out += 1
		max_snd = maxi(max_snd, g.smash_snd_n - snd0)
		if first_land < 1.0e8:
			min_gap = minf(min_gap, first_land - last_alive)
		spread_ms = maxf(spread_ms, t_last - maxf(t_first, 0.0))

	_ok("동시 조각 상한", max_shards <= 40 and max_grit <= 30,
			"조각 최대 %d (상한 40) · 부스러기 %d (상한 30)" % [max_shards, max_grit])
	_ok("조각이 딜링 전에 죽는다", min_gap > 0.10,
			"마지막 조각 → 첫 착지 여유 최소 %.3f초 (문턱 0.10)" % min_gap)
	_ok("도착이 훑기 안에 든다", max_hit_t < t1,
			"가장 늦은 부딪힘 sweep_t %.3f (rake 끝 %.3f)" % [max_hit_t, t1])
	_ok("끌려간 물건이 없다", n_drag == 0,
			"날린 적 없이 턱에 닿은 물건 %d개" % n_drag)
	#  문턱은 SMASH.chain 이다. 사슬이 열리는 최소가 곧 「날아간다」의 최소고,
	#  그 밑으로 닿았다면 날에 끌려 왔다는 뜻이다(실측 최소 802~981).
	_ok("날아와서 닿는다", min_hit_v >= float(g.SMASH.chain),
			"닿는 순간 최소 속력 %.0f 면px/s (문턱 %.0f)"
			% [min_hit_v, float(g.SMASH.chain)])
	_ok("조각이 트레이를 안 떠난다", n_out == 0,
			"밖에 선 조각 %d · 중심 x[%.0f,%.0f] y[%.0f,%.0f]" % [n_out, x_lo, x_hi, y_lo, y_hi])
	_ok("흔들림 상한", max_shake <= float(g.SMASH.shake0) + 0.001,
			"최대 %.1f (상한 %.1f)" % [max_shake, float(g.SMASH.shake0)])
	_ok("한 쓸기의 소리 수", max_snd <= int(g.SMASH.snd_max),
			"최대 %d개 (상한 %d)" % [max_snd, int(g.SMASH.snd_max)])

	#  ── 되돌리기 문 ────────────────────────────────
	#  움직임을 끈 손님은 **옛 길**로 간다 — 조각도 가루도 먼지도 흔들림도
	#  없이 구멍으로 미끄러진다(_egg_shatter 의 선례). 이 길이 살아 있는지를
	#  안 재면 motion_off 가 조용히 죽어도 아무도 모른다.
	var mo_debris := 0
	var mo_waste := 0
	var mo_shake := 0.0
	g.motion_off = true
	for r in 12:
		g.leg_no = 1 + (r % 7)
		g.gold = 99
		g._open_shop()
		g._drop_settle()
		g.shake = 0.0
		g._sweep_begin()
		var k := 0
		var seen := 0
		while k < 4000 and g.sweep_live:
			k += 1
			g._sweep_update(sub)
			g.drop_t += sub
			g._drop_step(sub)
			g._waste_update(sub)
			g._smash_update(sub)
			mo_debris += g.shards.size() + g.grit.size() + g.smash_dust.size()
			mo_shake = maxf(mo_shake, float(g.shake))
			seen = maxi(seen, g.waste.size())
		if seen > 0:
			mo_waste += 1
	g.motion_off = false
	_ok("모션 끄면 옛 길", mo_debris == 0 and mo_shake <= 0.001 and mo_waste == 12,
			"조각·가루·먼지 %d · 흔들림 %.1f · 구멍으로 간 롤 %d/12"
			% [mo_debris, mo_shake, mo_waste])

	if not hit_ms.is_empty():
		var line := ""
		for v in hit_ms:
			line += "%.3f " % float(v)
		print("  매물 넷 부딪힘(초) — %s" % line)
	print("  부딪힘이 퍼진 폭 최대 %.3f초" % spread_ms)

	print("%d롤 · 시드 %d — %s" % [rolls, seed_v,
			"아홉 검사 전부 통과" if fails == 0 else "실패 %d건" % fails])
	quit(fails)
	return true
