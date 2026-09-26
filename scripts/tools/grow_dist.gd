extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  걸음 값 분포 실측 — 「큰 값」의 문턱을 수로 정하기 위한 자 (2026-09-26)
#
#  실행:  godot --headless --path . --quit-after 900000 \
#             --script scripts/tools/grow_dist.gd -- autoplay
#
#  왜 있는가
#    GROW 표(r_lo 0.05 · r_hi 2.00)와 CARDFX.big 0.50 이 **비율 자** 하나에
#    매여 있는데, 그 자를 세운 근거가 주석에 「실측 p25(r 0.110)」 「중앙값
#    (r 0.216)」 「상위 약 6%」로만 남아 있고 **재는 도구가 저장소에 없다.**
#    문턱을 한 단 더 올리려면(사용자: 「점수 올라갈 때 이펙트」) 그 분포를
#    다시 재야 하고, 무엇보다 **한 런에 몇 번 터지는가**를 알아야 한다.
#
#  무엇을 재는가
#    ① 합계 걸음마다 last_gain · target · r=gain/target 을 담는다.
#       라운드별 · 판별로 분위수를 낸다.
#    ② 같은 걸음을 **그 판 최대 대비**(gain / 그 판의 최대 gain)로도 담는다.
#       두 자 중 어느 쪽이 사람 눈과 맞는지 수로 논하려면 둘이 다 있어야 한다.
#    ③ 한 판 · 한 런에 걸음이 몇 번인가 (정산 걸음 전체 · 합계 걸음만).
#    ④ 문턱을 상위 10% · 5% · 1% 로 잡으면 각각 런에 몇 번 터지는가.
#    ⑤ 지금 자(_grow_n)가 그 표본에서 내는 gn 과 흔들림 px 의 분포.
#
#  ⚠ 점수·배수·목표·보상·확률을 한 글자도 안 건드린다 — 읽기만 한다.
#    게임을 오토플레이로 돌려 **게임이 낸 수**를 그대로 긁는다.
#
#  ⚠ 오토플레이는 beat 를 0.10 으로 누르므로 **프레임 수는 인용하지 마라.**
#    여기서 쓸 수 있는 것은 값의 분포와 개수뿐이다. 걸음 프레임은 qa_total 이 잰다.
# ══════════════════════════════════════════════════════════

var g: Node = null
var frames := 0

#  걸음 하나 = 사전 하나
var rows := []

#  판 단위로 모으는 것
var leg_key := ""            # "런#/판#"
var leg_gains := []          # 이 판의 gain 들
var leg_steps := 0           # 이 판의 정산 걸음 전체
var legs := []               # 판마다 {key, round, target, gains, steps}

#  런 단위
var run_no := 0
var run_legs := 0
var run_steps := 0
var run_totals := 0
var runs := []

var prev_total := 0
var prev_leg := -1
var prev_pitch := 0
var prev_state := -1

#  런을 몇 개까지 볼 것인가 — 인자로 바꾼다 (runs=40)
var want_runs := 24
var frame_cap := 400000


func _initialize() -> void:
	Save.path = "user://_grow_dist.cfg"
	Save.gpath = "user://_grow_dist_g.cfg"
	Save.wipe()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("runs="):
			want_runs = maxi(2, int(arg.substr(5)))
		if arg.begins_with("cap="):
			frame_cap = maxi(20000, int(arg.substr(4)))
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20260926)


func _process(d: float) -> bool:
	frames += 1
	if frames < 3:
		return false

	#  ── 판이 바뀌었나 ──────────────────────────────────
	var ln: int = int(g.leg_no)
	if ln != prev_leg:
		_close_leg()
		if ln < prev_leg or prev_leg < 0:
			_close_run()
		prev_leg = ln
		leg_key = "%d/%d" % [run_no, ln]
		leg_gains = []
		leg_steps = 0
		prev_total = int(g.total)

	#  ── 정산 걸음 세기 (pitch_step 은 발마다 0 으로 돈다) ──
	var ps: int = int(g.pitch_step)
	if ps > prev_pitch:
		leg_steps += ps - prev_pitch
		run_steps += ps - prev_pitch
	prev_pitch = ps

	#  ── 합계 걸음 — total 이 오른 프레임 하나로만 잡는다 ──
	#  game.gd 에 `total +=` 는 7234 한 줄뿐이라 이 검출이 샐 자리가 없다.
	var tt: int = int(g.total)
	if tt != prev_total:
		var gain: int = int(g.last_gain)
		var tgt: int = int(g.target)
		var r := float(absi(gain)) / maxf(float(tgt), 1.0)
		rows.append({
			"run": run_no, "leg": ln,
			"round": int(GameData.round_of(ln)),
			"gain": gain, "target": tgt, "r": r,
			"gn": float(g._grow_n()),
			#  ⚠ g.shake 를 그대로 읽으면 **목표 돌파가 13.0 으로 덮은 값**이
			#  섞인다(7291). GROW 가 실제로 세운 값을 따로 셈해 둔다 — 두 수를
			#  갈라 놓지 않으면 「지금 흔들림 분포」가 돌파 20%에 끌려 올라간다.
			"shake": float(g.shake),
			"shk_grow": lerpf(float(g.GROW.shk_lo), float(g.GROW.shk_hi),
					float(g._grow_n()) * float(g._grow_n())),
			"burst": int(g.burst_n),
			"settle_n": int(g.settle_n),
			"endless": bool(GameData.endless),
			"broke": tt >= tgt,
		})
		leg_gains.append(gain)
		run_totals += 1
		prev_total = tt

	if runs.size() >= want_runs:
		_close_leg()
		_close_run()
		_report()
		quit(0)
		return true
	#  ⚠ **프레임 예산을 반드시 둔다.** 오토플레이는 상점에서 멎는 갈래가
	#  알려져 있고(game.gd _auto_step 주석: 「판 14 상점에서 14562프레임」),
	#  무한에 든 런은 스스로 안 끝난다. 예산이 없으면 도구가 통째로 안 찍고
	#  **통과와 구별이 안 된다** — qa_grow 머리말이 적어 둔 그 사고다.
	#  예산에 걸려도 그때까지 모은 것을 찍는다.
	if frames > frame_cap:
		_close_leg()
		_close_run()
		print("!! 프레임 상한에 걸렸다 — 런 %d개만 봤다" % runs.size())
		_report()
		quit(0)
		return true
	return false


func _close_leg() -> void:
	if leg_key == "" or leg_gains.is_empty():
		return
	legs.append({"key": leg_key, "round": int(GameData.round_of(prev_leg)),
			"gains": leg_gains.duplicate(), "steps": leg_steps})
	run_legs += 1
	leg_key = ""
	leg_gains = []


func _close_run() -> void:
	if run_legs > 0:
		runs.append({"legs": run_legs, "steps": run_steps, "totals": run_totals})
	run_no += 1
	run_legs = 0
	run_steps = 0
	run_totals = 0


# ── 통계 ──────────────────────────────────────────────
func _pct(a: Array, p: float) -> float:
	if a.is_empty():
		return NAN
	var x: float = p * 0.01 * float(a.size() - 1)
	var i := int(floor(x))
	var j := mini(i + 1, a.size() - 1)
	return lerpf(a[i], a[j], x - float(i))


func _sorted(key: String, filt := -1) -> Array:
	var a := []
	for w in rows:
		if filt >= 0 and int(w.round) != filt:
			continue
		a.append(float(w[key]))
	a.sort()
	return a


func _five(a: Array) -> String:
	if a.is_empty():
		return "        (표본 0)"
	return "%9.3f %9.3f %9.3f %9.3f %9.3f" % [_pct(a, 25.0), _pct(a, 50.0),
			_pct(a, 90.0), _pct(a, 99.0), a[a.size() - 1]]


#  값 v 가 분포 a 에서 상위 몇 %인가
func _rank_of(a: Array, v: float) -> float:
	var n := 0
	for x in a:
		if x >= v:
			n += 1
	return 100.0 * float(n) / float(a.size())


func _report() -> void:
	print("\n═══ grow_dist · 런 %d개 · 합계 걸음 %d개 · 판 %d개 ═══"
			% [runs.size(), rows.size(), legs.size()])
	if rows.is_empty():
		print("  표본이 0 이다 — 오토플레이가 안 돌았다")
		return

	print("\n── ① r = last_gain / target 의 분포 ─────────────")
	print("                       p25       p50       p90       p99       max")
	var ra := _sorted("r")
	print("  전체 (n=%5d)  %s" % [ra.size(), _five(ra)])
	for rd in range(1, 9):
		var a := _sorted("r", rd)
		if a.is_empty():
			continue
		print("  R%-2d  (n=%5d)  %s" % [rd, a.size(), _five(a)])

	print("\n── ①-b 지금 표가 박은 자리가 실제로 상위 몇 %인가 ──")
	print("  GROW.r_lo 0.05  → 상위 %.1f%% (이 밑은 gn 0)" % _rank_of(ra, 0.05))
	print("  CARDFX.big 0.50 → 상위 %.1f%% (한 방 · 멈춤 · 금테)" % _rank_of(ra, 0.50))
	print("  GROW.r_hi 2.00  → 상위 %.1f%% (gn 천장)" % _rank_of(ra, 2.00))

	print("\n── ①-c 「그 판 최대 대비」로 재면 ───────────────")
	var lm := []
	for lg in legs:
		var mx := 0
		for v in lg.gains:
			mx = maxi(mx, int(v))
		for v in lg.gains:
			lm.append(float(absi(int(v))) / maxf(float(mx), 1.0))
	lm.sort()
	print("  gain / 그 판 최대      %s" % _five(lm))
	print("  → 판마다 정의상 1.0 이 **꼭 하나** 난다. 판 %d개 · 걸음 %d개라"
			% [legs.size(), lm.size()])
	print("     1.0 이 나는 비율이 %.1f%% 로 **판 길이에 매인다** — 목표 대비와 달리"
			% (100.0 * float(legs.size()) / float(maxi(lm.size(), 1))))
	print("     「이 판에서 제일 컸다」는 **그 판이 끝나야 알 수 있다**(사후 정보).")

	print("\n── ② 걸음 수 — 한 판에 · 한 런에 ────────────────")
	var ls := []
	var lt := []
	for lg in legs:
		ls.append(float(lg.steps))
		lt.append(float(lg.gains.size()))
	ls.sort()
	lt.sort()
	print("                       p25       p50       p90       p99       max")
	print("  판당 정산 걸음 전체  %s" % _five(ls))
	print("  판당 합계 걸음      %s" % _five(lt))
	var rs := []
	var rt := []
	var rl := []
	for r in runs:
		rs.append(float(r.steps))
		rt.append(float(r.totals))
		rl.append(float(r.legs))
	rs.sort()
	rt.sort()
	rl.sort()
	print("  런당 정산 걸음 전체  %s" % _five(rs))
	print("  런당 합계 걸음      %s" % _five(rt))
	print("  런당 판            %s" % _five(rl))

	print("\n── ③ 문턱을 잡으면 런에 몇 번 터지는가 ──────────")
	var per_run := _pct(rt, 50.0)     # 런당 합계 걸음 중앙값
	print("  런당 합계 걸음 중앙값 %.0f 개를 기준으로 센다" % per_run)
	print("  상위    r 문턱      런에 몇 번      판에 몇 번")
	for p in [50.0, 25.0, 10.0, 5.0, 2.0, 1.0, 0.5]:
		var thr := _pct(ra, 100.0 - p)
		var per_leg := _pct(lt, 50.0)
		print("  %5.1f%%   r ≥ %7.3f    %6.1f 번      %5.2f 번"
				% [p, thr, per_run * p * 0.01, per_leg * p * 0.01])

	print("\n── ④ 지금 자(_grow_n)가 내는 gn · 흔들림 px ─────")
	var ga := _sorted("gn")
	var sg := _sorted("shk_grow")
	var sa := _sorted("shake")
	print("                       p25       p50       p90       p99       max")
	print("  gn                %s" % _five(ga))
	print("  GROW 흔들림 px     %s" % _five(sg))
	print("  실제 shake px      %s   ← 돌파 13.0 덮기가 섞인 값" % _five(sa))
	var z := 0
	var sat := 0
	for x in ga:
		if x <= 0.0:
			z += 1
		if x >= 1.0:
			sat += 1
	print("  gn == 0 인 걸음 %d / %d (%.1f%%) ← **0단**이 실제로 이만큼이다"
			% [z, ga.size(), 100.0 * float(z) / float(ga.size())])
	print("  gn == 1 인 걸음 %d / %d (%.1f%%) ← **천장에 붙어 구별이 죽은 몫**"
			% [sat, ga.size(), 100.0 * float(sat) / float(ga.size())])
	var over := 0
	for x in sg:
		if x > 6.0:
			over += 1
	print("  GROW 흔들림 > 6.0 (TIP.quiet — 툴팁을 아예 안 그리는 선) %d / %d (%.1f%%)"
			% [over, sg.size(), 100.0 * float(over) / float(sg.size())])

	print("\n── ④-b 라운드마다 자가 천장에 얼마나 붙는가 ─────")
	print("  라운드   걸음      gn p50    gn 천장붙음   r p90     목표 중앙값")
	for rd in range(1, 9):
		var ar := _sorted("r", rd)
		if ar.is_empty():
			continue
		var ag := _sorted("gn", rd)
		var s2 := 0
		for x in ag:
			if x >= 1.0:
				s2 += 1
		var tg := _sorted("target", rd)
		print("  R%-2d   %5d    %7.3f   %6.1f%%     %8.3f  %10.0f"
				% [rd, ar.size(), _pct(ag, 50.0),
				100.0 * float(s2) / float(ag.size()), _pct(ar, 90.0),
				_pct(tg, 50.0)])
	print("  → 천장붙음이 라운드마다 크게 갈리면 자가 **라운드마다 다른 뜻**이다.")

	print("\n── ⑤ 목표 돌파 · 연발 · 무한 ───────────────────")
	var brk := 0
	var bst := 0
	var inf := 0
	var big := 0
	var mxg := 0
	for w in rows:
		if bool(w.broke):
			brk += 1
		if int(w.burst) > 0:
			bst += 1
		if bool(w.endless):
			inf += 1
		if float(w.r) >= 0.50:
			big += 1
		mxg = maxi(mxg, int(w.gain))
	print("  목표를 돌파한 걸음 %d (%.1f%%) — 판마다 정의상 한 번꼴"
			% [brk, 100.0 * float(brk) / float(rows.size())])
	print("  연발(burst_n>0) 걸음 %d (%.1f%%)" % [bst, 100.0 * float(bst) / float(rows.size())])
	print("  무한 구간 걸음 %d (%.1f%%)" % [inf, 100.0 * float(inf) / float(rows.size())])
	print("  CARDFX.big 0.50 이 걸린 걸음 %d (%.1f%%)"
			% [big, 100.0 * float(big) / float(rows.size())])
	print("  본 가장 큰 last_gain %d" % mxg)

	#  ── ⑥ 「큰 값」과 「목표 돌파」가 **같은 걸음인가** ─────────────
	#  이것이 문턱 설계의 갈림길이다. 겹치면 새 층이 **이미 열 겹이 켜진
	#  프레임**(grow_load ①-가)에 얹히는 것이고, 안 겹치면 조용한 자리에
	#  새 사건을 내는 것이다. 목표의 두 배를 한 발로 내면 대개 그 발이
	#  목표를 넘기므로 겹칠 것이 예상되지만, 무한 런처럼 이미 넘긴 뒤
	#  계속 쌓는 자리는 안 겹친다.
	print("\n── ⑥ 「큰 값」과 「목표 돌파」의 겹침 ──────────────")
	print("  문턱      큰 값 걸음   그중 돌파      그중 돌파 아님(조용한 자리)")
	for thr in [0.50, 1.00, 2.00, 4.00]:
		var n_big := 0
		var n_both := 0
		for w in rows:
			if float(w.r) >= thr:
				n_big += 1
				if bool(w.broke):
					n_both += 1
		if n_big == 0:
			continue
		print("  r ≥ %4.2f   %5d (%4.1f%%)  %5d (%4.0f%%)   %5d (%4.0f%%)"
				% [thr, n_big, 100.0 * float(n_big) / float(rows.size()),
				n_both, 100.0 * float(n_both) / float(n_big),
				n_big - n_both, 100.0 * float(n_big - n_both) / float(n_big)])
	var brk_big := 0
	var brk_small := 0
	for w in rows:
		if bool(w.broke):
			if float(w.r) >= 2.0:
				brk_big += 1
			else:
				brk_small += 1
	print("  거꾸로: 돌파 걸음 %d 중 r ≥ 2.00 인 것 %d (%.0f%%) · 그 밑 %d (%.0f%%)"
			% [brk + 0, brk_big, 100.0 * float(brk_big) / float(maxi(brk, 1)),
			brk_small, 100.0 * float(brk_small) / float(maxi(brk, 1))])
	print("  → 돌파 걸음의 흔들림은 7291 이 **13.0 으로 덮으므로** 크기를 안 읽는다.")
	print("     즉 판의 절정에서만 「흔들림이 값을 탄다」가 참이 아니다.")

	#  ── ⑦ 「달아오르는 가장자리」의 단이 실제로 몇 번 나는가 ──────────
	#  (2026-09-26 · 이 자리가 새로 붙은 곳이다. 위 ①~⑥ 은 손대지 않았다)
	#
	#  왜 필요한가: 설계가 단 넷을 gn 축의 세 점(t1·t2·t3)으로 끊고, 가장 센
	#  4단에 **판에 한 번**이라는 깃발을 얹었다. 문턱 셋의 몫은 위 ① 이 이미
	#  주지만 4단은 「이 판에서 여태 가장 큰 합계 걸음」이라는 **달리는 값**을
	#  둘째 문으로 쓰므로, 몫을 손으로 못 셈한다 — 걸음 순서에 매여 있다.
	#  그래서 실제 표본을 **판 단위로 순서대로 되돌려** 세어 본다.
	#
	#  ⚠ 여기서 쓰는 식은 game.gd 의 _fire_tier 와 **같아야 한다.** 한쪽을
	#  고치면 다른 쪽도 고쳐라. 사본이 둘인 것을 받아들인 까닭: 도구가 게임을
	#  부르면 fire_used 깃발이 이미 판마다 타 버려 「몇 번 걸렸나」를 셀 수가
	#  없다(깃발이 답을 먹는다).
	print("
── ⑦ 달아오르는 가장자리 — 단마다 몇 번 나는가 ───")
	var T1 := 0.50
	var T2 := 0.624
	var T3 := 0.876
	print("  단 경계 gn  t1 %.3f (r %.3f) · t2 %.3f (r %.3f) · t3 %.3f (r %.3f)"
			% [T1, 0.05 * pow(10.0, 1.60206 * T1),
			T2, 0.05 * pow(10.0, 1.60206 * T2),
			T3, 0.05 * pow(10.0, 1.60206 * T3)])
	#  판마다 순서대로 되돌린다. rows 는 난 순서로 쌓였고 run·leg 가 붙어 있다.
	var tier_n := [0, 0, 0, 0, 0]
	var rec_n := 0           # 문 ②(판 최고 기록)가 걸린 걸음
	var rec_at := []         # 그 걸음이 판의 몇 번째 합계 걸음이었나
	var t4_leg := {}         # 판마다 4단이 몇 번
	var t4_run := {}         # 런마다 4단이 몇 번
	var leg_seen := {}
	var cur := ""
	var peak := 0
	var used := false
	var idx := 0
	for w in rows:
		var key := "%d/%d" % [int(w.run), int(w.leg)]
		if key != cur:
			cur = key
			peak = 0
			used = false
			idx = 0
			leg_seen[key] = true
			if not t4_leg.has(key):
				t4_leg[key] = 0
		idx += 1
		var gn := float(w.gn)
		var gain: int = absi(int(w.gain))
		var wbrk := bool(w.broke)
		#  _fire_tier 와 같은 순서 — 기록 장부를 **먼저** 갱신한다
		var rec: bool = peak > 0 and gain > peak
		peak = maxi(peak, gain)
		var tier := 0
		if gn >= T1:
			if gn < T2:
				tier = 1
			else:
				var big3 := gn >= T3
				if not big3 and not rec:
					tier = 2
				elif wbrk or used:
					tier = 3 if big3 else 2
				else:
					used = true
					tier = 4
		tier_n[tier] += 1
		if rec and gn >= T2:
			rec_n += 1
			rec_at.append(float(idx))
		if tier == 4:
			t4_leg[key] = int(t4_leg[key]) + 1
			var rk := int(w.run)
			t4_run[rk] = int(t4_run.get(rk, 0)) + 1
	var n := rows.size()
	var n_leg: int = maxi(leg_seen.size(), 1)
	var n_run: int = maxi(runs.size(), 1)
	var per_leg_tot := float(n) / float(n_leg)
	print("  단   걸음 수    몫       판당       런당")
	for t in range(5):
		print("  %d단  %6d   %5.1f%%   %6.2f     %6.1f"
				% [t, tier_n[t], 100.0 * float(tier_n[t]) / float(n),
				float(tier_n[t]) / float(n_leg), float(tier_n[t]) / float(n_run)])
	print("  ── 0단(아무 일도 안 나는 단)이 %.1f%% ← 절반 가까이면 계약대로다"
			% (100.0 * float(tier_n[0]) / float(n)))
	print("  판당 합계 걸음 평균 %.2f · 판 %d개 · 런 %d개" % [per_leg_tot, n_leg, n_run])
	#  문 ② — 설계가 「추정」으로 남긴 칸 둘이 여기서 수가 된다
	rec_at.sort()
	print("
  문 ②(판 최고 기록 · gn ≥ t2) 걸린 걸음 %d (%.1f%%) · 판당 %.2f"
			% [rec_n, 100.0 * float(rec_n) / float(n), float(rec_n) / float(n_leg)])
	if not rec_at.is_empty():
		print("  그 걸음이 판의 몇 번째였나  p25 %.1f · p50 %.1f · p90 %.1f · max %.0f"
				% [_pct(rec_at, 25.0), _pct(rec_at, 50.0), _pct(rec_at, 90.0),
				rec_at[rec_at.size() - 1]])
	#  4단이 판에 한 번을 넘는가 — 깃발이 제 일을 하면 **최대가 1 이어야 한다**
	var mx_leg := 0
	var legs_with := 0
	for k in t4_leg:
		var v := int(t4_leg[k])
		mx_leg = maxi(mx_leg, v)
		if v > 0:
			legs_with += 1
	print("  4단 · 판당 최대 %d (깃발이 제 일을 하면 **1 을 절대 못 넘는다**)" % mx_leg)
	print("  4단이 난 판 %d / %d (%.1f%%) · 판당 %.2f · 런당 %.1f"
			% [legs_with, n_leg, 100.0 * float(legs_with) / float(n_leg),
			float(tier_n[4]) / float(n_leg), float(tier_n[4]) / float(n_run)])
	print("  → 판당 1.0 을 넘으면 설계대로 문 ②의 밑문을 t2 → t3 으로 올려야 한다.")
	#  심사 시간(2~3판) 어림 — 대회 심사가 짧다는 것이 이 층의 설계 조건이다
	print("  심사 3판 어림: 3단 %.1f번 · 4단 %.1f번"
			% [3.0 * float(tier_n[3]) / float(n_leg), 3.0 * float(tier_n[4]) / float(n_leg)])
	print("")
