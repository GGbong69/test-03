extends SceneTree

#  판 깨짐 프로브 — 「판이 깨졌는데 게임은 한 톨도 안 움직였다」를 잰다.
#
#  이 연출의 약속은 넷이고 전부 여기서 수로 확인한다.
#    ① 런 벽시계가 한 프레임도 안 는다     — 돌파~정산 프레임 수가 전후로 같다
#    ② 게임 값을 한 톨도 안 만진다         — 보상 · 목표 · 골드 · shake · qt
#    ③ 글자 0자                            — 팝업이 「목표 달성」 하나뿐이다
#    ④ 지금 그려지는 판에서 뜬다           — 박아 둔 20 이 한 곳도 없다
#
#  ⚠ **소리는 sfx_next 의 걸음으로 센다.** _sfx 가 파일을 틀 때마다
#  sfx_pool(넷)을 한 칸 돈다 — 한 프레임에 넷 이상 나면 셈이 접히지만
#  이 연출의 한 프레임 상한이 셋(break + 톡 둘)이라 접힐 길이 없다.
#  게임에 프로브용 셈 변수를 새로 안 만들려고 고른 길이다.
#
#  실행:  godot --headless --path . --script scripts/tools/qa_break.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")

var g = null
var busy := false
var okn := 0
var fail := 0
const DT := 1.0 / 60.0

#  ── ⑧ 이 쓸어 보는 맞은 자리 표 [판 반지름 비, 씨] ──
#  한복판 · 0.30 · 0.45 · 0.62 · 0.75 · 더블(0.806) · 테 코앞(0.90 · 0.95).
#  **설계서가 못 박은 여섯**에 씨 둘씩을 물렸다. 한복판은 L 이 방향마다
#  같아 무게가 평평해지는 자리라 반드시 끼고, 0.806~0.95 는 먼 쪽 살이
#  rim+|H| 까지 늘어 쐐기 하나가 판을 통째로 먹으려 드는 자리다.
const HITS := [
	[0.0, 0], [0.0, 1],
	[0.30, 2], [0.45, 3],
	[0.62, 0], [0.75, 1],
	[0.806, 2], [0.806, 3],
	[0.90, 0], [0.95, 1],
]


func _initialize() -> void:
	#  사람의 저장을 안 건드린다 — 도구는 제 자리를 박는다.
	Save.path = "user://_qa_break.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-38s %s" % ["통과" if c else "실패", n, d])


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


#  새 런을 열고 판 하나를 세운다. 화면은 S.PICK 이다.
func _open() -> void:
	g.state = g.S.TITLE
	g._new_run()
	g._click(g._leg_go().get_center())
	for _k in 60:
		g._process(DT)
	g._swap_skip()


#  보드 확장 하나를 끼우고 판을 다시 세운다. mods_own 이 판의 유일한 출처다.
#  ── 면이 판을 빈틈없이 덮는가 ── **정확한 자다. 래스터가 아니다.**
#  `_brk_make_facets` 는 판 다각형을 **쪼개기만** 해서 면을 낸다. 그런
#  분할이면 속 모서리는 반드시 **정순 하나 · 역순 하나**로 짝이 맞고,
#  짝이 없는 모서리는 전부 판 테 위에 있다. 그래서 ⓐ 짝이 없는데 테
#  위가 아닌 모서리 = **구멍의 씨앗** ⓑ 같은 방향으로 두 번 나온 모서리
#  = **겹침의 씨앗**이다. 0.5px 래스터는 판 하나에 236,000 칸이라 자가
#  못 돌고, 무엇보다 **부동소수 엡실론이 끼어든다** — 이 자에는 안 낀다.
#  되돌리는 것: [구멍의 씨앗, 겹침의 씨앗, 면의 최대 반지름]
func _tile(rim: float) -> Array:
	var dir := {}
	var maxr := 0.0
	for f in g.brk_facets:
		var poly: PackedVector2Array = f.pts
		var n: int = poly.size()
		for i in n:
			var p: Vector2 = poly[i]
			var q: Vector2 = poly[(i + 1) % n]
			maxr = maxf(maxr, p.length())
			var k := "%.3f,%.3f|%.3f,%.3f" % [p.x, p.y, q.x, q.y]
			dir[k] = int(dir.get(k, 0)) + 1
	var loose := 0
	var dup := 0
	for k in dir:
		if int(dir[k]) > 1:
			dup += int(dir[k]) - 1
		var parts: PackedStringArray = (k as String).split("|")
		if not dir.has(parts[1] + "|" + parts[0]):
			var xy: PackedStringArray = parts[0].split(",")
			if absf(Vector2(float(xy[0]), float(xy[1])).length() - rim) > 0.02:
				loose += 1
	return [loose, dup, maxr]


func _board(id: String) -> void:
	g.mods_own = [] if id == "" else [id]
	g._board_bake()
	g._start_leg()
	g._swap_skip()


#  ── 맞은 자리를 박는다 ──
#  ⚠ **이 줄이 없으면 덮임 자가 한 자리만 잰다.** `_board()` 가
#  `_start_leg()` 로 darts 를 비우므로 `_brk_hit_at()` 이 언제나 **씨
#  갈래**로 떨어지고, leg_no 도 테마 여섯 × 층 셋에서 전부 같아 **열여덟
#  판이 글자 그대로 같은 자리**에서 깨졌다(실측 0.302R 한 곳, 가짓수 1).
#  그런데 이 모형이 통째로 기대고 선 두 축 — 살을 **L² 무게**로 나누는
#  것(BRKWEB.wpow)과 **천장**(BRKWEB.amax_k) — 은 L 이 방향마다 크게
#  다른 **가장자리 타격에서만** 일을 한다. 한복판 근처 한 자리만 재는
#  자는 둘 다 못 지킨다.
#  **직접 재서 확인했다**: wpow 를 2.0 → 0.0(설계서가 「두 설계가 똑같이
#  틀렸다」고 적은 바로 그 수)으로 되돌려도 ⑧ 이 **그대로 초록**인데,
#  같은 빌드의 최대면은 10.2% → **16.8%** 로 ⑧ 자신의 천장(12%)을
#  넘었다. 자가 제 천장이 무너지는 것을 못 본 것이다. 2026-09-25
func _hit(hf: float, s: int) -> void:
	g.leg_no = 7 + s * 5
	var a: float = 0.37 + float(s) * 1.9 + hf * 2.7
	g.darts = [{"p": g.BC + Vector2(sin(a), -cos(a)) * g.R * hf,
			"id": "std", "rot": 0.0}]


#  한 발을 던져 목표를 넘기고, **돌파 프레임부터 정산까지**를 프레임으로
#  적는다. kill 이 참이면 매 프레임 _brk_skip() 을 불러 연출을 아예 못 살게
#  한다 — 「연출이 더한 프레임 0」의 A/B 짝이다.
#  deep 이 0 이상이면 도안이 선 뒤 **매 프레임** 그 단으로 못 박는다.
#  brk_deep 은 그리기와 음 높이만 읽는 값이라 매 프레임 같은 값을 다시
#  적는 것이 실제 판과 똑같다. 이 도구의 던지기는 target 1 · total 0 이라
#  자가 통째로 3단으로 뜨므로, 네 단을 재려면 이 문이 있어야 한다.
#  2026-09-25
func _throw(kill := false, cap := 900, deep := -1) -> Dictionary:
	var o := {"arm": -1, "fire": -1, "gone": -1, "clear": -1,
			"snd": 0, "crack": 0, "brk": 0,
			"shards": 0, "bits": 0, "pops": 0,
			"shake": -1.0, "qt": -1.0, "hitstop": -1.0,
			"stage": 0, "dart_gone": -1, "deep": -1,
			"swap": false, "turn": false}
	g.target = 1
	g.total = 0
	g.state = g.S.CONFIRM
	g.confirm_t = 99.0
	g.aim = g.BC
	var prev: int = g.sfx_next
	var pool: int = maxi((g.sfx_pool as Array).size(), 1)
	for f in cap:
		#  ⚠ **_process 보다 앞이다.** 삐걱은 그 프레임 안에서 울므로,
		#  뒤에 적으면 첫 단이 자가 뜬 3단 음으로 난다.
		if deep >= 0 and g.brk_live:
			g.brk_deep = deep
		g._process(DT)
		var now: int = g.sfx_next
		var dn: int = posmod(now - prev, pool)
		prev = now
		#  ⚠ **이름으로 센다.** 앞서는 sfx_next 가 몇 칸 돌았는지만 셌는데,
		#  그러면 깨짐이 소리를 한 종류 더 내는 순간 이 수가 통째로 어긋나
		#  「층대로 1·2·3」이 딴 것을 가리킨다 — 그 줄이 재려는 것은 **꼬리
		#  톡**이다. _sfx 가 자리마다 stream 을 갈아 끼우므로 그 자리의
		#  resource_path 가 곧 이름이다. 2026-09-24
		#  ⚠ **정산 프레임은 안 센다.** 그 프레임에 _settle_clear 가
		#  leg_clear 를 울리는데 그것은 깨짐의 소리가 아니다.
		#  도안이 선 프레임도 안 센다(target_hit 이 거기서 운다).
		if o.arm >= 0 and o.clear < 0 and g.state != g.S.CLEAR:
			for k in dn:
				var pi: int = posmod(prev - dn + k, pool)
				var st = (g.sfx_pool[pi] as AudioStreamPlayer).stream
				var snm := "" if st == null \
						else String(st.resource_path).get_file().get_basename()
				match snm:
					"board_thud":
						o.snd += 1
					"board_crack":
						o.crack += 1
					"board_break":
						o.brk += 1
		if g.brk_live and o.arm < 0:
			o.arm = f
			o.shake = g.shake
			o.qt = g.qt
			o.hitstop = g.hitstop
			o.pops = (g.pops as Array).size()
			o.deep = g.brk_deep
		if g.brk_fired and o.fire < 0:
			o.fire = f
		if o.arm >= 0:
			o.shards = maxi(o.shards, (g.brk_shards as Array).size())
			o.bits = maxi(o.bits, (g.brk_bits as Array).size())
			o.stage = maxi(o.stage, g.brk_stage)
			if g.swap_live: o.swap = true
			if g.turn_live: o.turn = true
		if o.fire >= 0 and o.gone < 0 \
				and (g.brk_shards as Array).is_empty() \
				and (g.brk_bits as Array).is_empty():
			o.gone = f
		if o.fire >= 0 and o.dart_gone < 0 and g._brk_dart_a() <= 0.0:
			o.dart_gone = f
		#  ⚠ **재고 나서 내린다.** 먼저 내리면 도안이 선 프레임을 못 보고
		#  arm 이 −1 로 남아 A/B 의 두 수가 딴 것을 가리킨다.
		if kill:
			g._brk_skip()
		if g.state == g.S.CLEAR:
			o.clear = f
			break
	return o


#  띠 표 — _board_dim_sector 가 쓰는 그 표. 겹이 그것과 같은 칸을 가리키는지
#  대려고 여기서 손으로 한 번 더 적는다(사본이 셋째가 되는 것은 설계서에
#  적어 올린 리팩터 일감이다).
func _bands() -> Array:
	var b := [[g.rt_bull_o, g.rt_trp_in], [g.rt_trp_in, g.rt_trp_out],
			[g.rt_trp_out, g.rt_dbl_in], [g.rt_dbl_in, g.rt_dbl_out]]
	if g.rt_trp2_out > 0.0:
		b[0] = [g.rt_bull_o, g.rt_trp2_in]
		b.append([g.rt_trp2_in, g.rt_trp2_out])
		b.append([g.rt_trp2_out, g.rt_trp_in])
	var out := []
	for e in b:
		if float(e[1]) > float(e[0]) + 0.001:
			out.append(e)
	return out


func _run() -> void:
	for _i in 20:
		g._process(DT)
	print("\n판 깨짐 검사 (BRK)\n")

	var stop: float = float(g.CARDFX.stop)
	var beat: float = g.beat

	# ── ① 돌파 프레임의 값이 하나도 안 바뀌었다 ──────────────
	_open()
	var a := _throw()
	_ok("돌파 프레임에 도안이 섰다", a.arm >= 0, "%d프레임째" % a.arm)
	_ok("흔들림은 돌파가 낸 13.0 그대로", is_equal_approx(float(a.shake), 13.0),
			"shake %.2f — 연출이 한 톨도 안 더했다" % a.shake)
	_ok("멈춤은 CARDFX.stop 밑", float(a.hitstop) <= stop + 0.0001,
			"hitstop %.3f / 상한 %.3f" % [a.hitstop, stop])
	_ok("걸음 길이를 안 건드렸다",
			absf(float(a.qt) - (beat * 3.4 - float(a.hitstop))) < 0.002,
			"qt %.3f / 기대 %.3f" % [a.qt, beat * 3.4 - float(a.hitstop)])

	# ── ② 글자 0자 ──────────────────────────────────────────
	#  연출을 통째로 손으로 돌려 놓고 팝업 수를 본다. 던져서 재면 그 발이
	#  낸 팝업(목표 달성 · 동전 발동)이 섞여서 무엇이 깨짐의 것인지 안
	#  갈린다 — 여기서는 게임을 한 걸음도 안 돌린다.
	_open()
	(g.pops as Array).clear()
	g._brk_arm(2)
	g.brk_free = true
	for _k in 60:
		g._brk_tick(DT)
	_ok("깨짐이 팝업을 한 개도 안 더한다", (g.pops as Array).is_empty(),
			"%d개 — 깨짐은 pop() 을 한 번도 안 부른다" % (g.pops as Array).size())
	g._brk_skip()
	_open()
	a = _throw()
	_ok("정산에 팝업을 안 끌고 온다", (g.pops as Array).is_empty(),
			"%d개" % (g.pops as Array).size())

	# ── ③ 런 벽시계가 한 프레임도 안 는다 ───────────────────
	#  같은 판을 연출 있이 · 연출 없이 한 번씩 던져 **돌파→정산 프레임 수**를
	#  댄다. 한 프레임이라도 달라지면 「새 시간 0초」가 거짓이 된 것이다.
	_open()
	var live := _throw()
	_open()
	var dead := _throw(true)
	_ok("연출이 더한 프레임 0",
			int(live.clear) - int(live.arm) == int(dead.clear) - int(dead.arm),
			"있이 %d프레임 · 없이 %d프레임"
			% [int(live.clear) - int(live.arm), int(dead.clear) - int(dead.arm)])
	_ok("정산 앞의 숨이 한두 프레임",
			int(live.gone) >= 0 and int(live.clear) - int(live.gone) <= 4
			and int(live.clear) > int(live.gone),
			"발화 +%d · 마지막 조각 +%d · 정산 +%d"
			% [int(live.fire) - int(live.arm), int(live.gone) - int(live.arm),
					int(live.clear) - int(live.arm)])
	_ok("다트가 조각보다 먼저 진다",
			int(live.dart_gone) >= 0 and int(live.dart_gone) < int(live.gone),
			"다트 +%d · 조각 +%d"
			% [int(live.dart_gone) - int(live.arm), int(live.gone) - int(live.arm)])

	# ── ④ 정산 · 상점 · 판 갈이 어디에도 안 남는다 ──────────
	_ok("정산에서 도안이 내려가 있다", not g.brk_live,
			"brk_live %s · 조각 %d" % [g.brk_live, (g.brk_shards as Array).size()])
	_ok("정산에서 판이 다시 그려진다", not is_inf(g._brk_board_dy()),
			"_brk_board_dy %.1f" % g._brk_board_dy())
	_ok("연출이 판 갈이·라운드 넘김을 안 빌렸다",
			not bool(live.swap) and not bool(live.turn),
			"swap_live %s · turn_live %s" % [live.swap, live.turn])

	# ── ⑤ 보상이 한 톨도 안 바뀐다 ──────────────────────────
	#  같은 판을 연출 있이 · 없이 넘겨 정산 내역과 지갑을 글자로 댄다.
	_open()
	g.leg_no = 2
	_throw()
	var gold_live: int = g.gold
	var det_live := JSON.stringify(g.clear_gold_detail)
	_open()
	g.leg_no = 2
	_throw(true)
	_ok("정산 내역이 글자 그대로 같다", det_live == JSON.stringify(g.clear_gold_detail),
			"있이 %s" % det_live)
	_ok("지갑이 같다", gold_live == g.gold, "%d / %d" % [gold_live, g.gold])

	# ── ⑥ 연발 — 판이 정말 끝나는 걸음에서만 선다 ───────────
	#  _next_step 은 큐가 빈 뒤에도 burst_hits 가 남았으면 _finish_leg 대신
	#  다음 다트를 판다. was_short 로 물었으면 판이 통째로 깨진 뒤에 남은
	#  다트가 **없는 판에** 날아가고, 그 다음 걸음은 그 판을 영영 안 깨뜨린다.
	_open()
	g.target = 1
	g.total = 0
	g.burst_hits = [g.BC, g.BC]
	g.state = g.S.CONFIRM
	g.confirm_t = 99.0
	g.aim = g.BC
	var armed_with_burst := false
	var armed_at_end := false
	for _f in 900:
		g._process(DT)
		if g.brk_live and not (g.burst_hits as Array).is_empty():
			armed_with_burst = true
		if g.brk_live:
			armed_at_end = true
		if g.state == g.S.CLEAR:
			break
	_ok("연발이 남았으면 안 깨진다", not armed_with_burst,
			"남은 다트가 있는 걸음에서 도안이 선 적 %s"
			% ("있다" if armed_with_burst else "없다"))
	_ok("연발이 다 팔린 걸음에서 깨진다", armed_at_end, "")

	# ── ⑦ 꼬리 — 걸음 길이가 달라도 정산 앞의 숨이 같다 ─────
	var breaths := []
	for bt in [0.34, 0.26, 0.015]:
		_open()
		g.beat = bt
		var r := _throw()
		breaths.append([bt, int(r.clear) - int(r.gone) if int(r.gone) >= 0 else -1])
	g.beat = beat
	var tail_ok := true
	var tail_txt := ""
	for e in breaths:
		tail_txt += "beat %.3f → %d프레임  " % [float(e[0]), int(e[1])]
		#  −1 은 「걸음이 너무 짧아 조각이 뜨기 전에 정산이 잘랐다」다.
		#  눌린 박자(0.015)에서만 나고, 그때도 게임 값에 한 톨도 안 닿는다.
		if float(e[0]) > 0.1 and (int(e[1]) < 0 or int(e[1]) > 4):
			tail_ok = false
	_ok("걸음 길이 셋에서 숨이 같다", tail_ok, tail_txt)

	# ── ⑧ 테마 — 면이 판을 빈틈없이 덮고 수가 자 안에 든다 ───
	#  ⚠ **앞 자는 「부채가 칸 수의 약수 · 겹이 산 띠 안」이었다.**
	#  그 약수 규약이 곧 「레고블럭」의 뿌리라 규약째로 죽었다(game.gd 의
	#  _brk_wedges 비석). 하지만 그 자가 **지키려던 것**은 약수가 아니라
	#  ⓐ 조각 하나가 한 색으로 읽히고 ⓑ 조각이 읽히는 크기이고
	#  ⓒ 조각이 예산 안이라는 셋이다. 새 모형에서 그 셋을 **부채 없이
	#  직접** 잰다 — 줄어든 자가 없고 오히려 덮임 자가 는다.
	#  ⓐ 는 이제 `_brk_shards_draw` 가 조각을 col 한 색으로 칠하는 것이
	#  지키므로 ⑧-d 가 색 가짓수로 잰다.
	#  ⚠ **테마 여섯 × 층 셋 × 맞은 자리 열**을 쓴다(HITS · _hit 머리말).
	#  맞은 자리 축이 빠져 있던 동안 이 자는 제 천장이 무너지는 것을 못
	#  봤다 — 덮임은 쪼개기가 정리로 지키지만 **크기**는 L 이 방향마다
	#  얼마나 다른가에 통째로 달려 있고, 그것이 곧 맞은 자리다. 2026-09-25
	var th_ok := true
	var th_txt := ""
	for id in ["", "pizz", "clok", "dnut", "aimb", "arst"]:
		_open()
		_board(id)
		var n: int = g._sec_n()
		var want_bands := _bands().size()
		var line := ""
		for t in 3:
			#  ⚠ **맞은 자리를 쓸면서 잰다**(_hit 머리말). 앞서는 여기서
			#  곧장 `_brk_arm(t)` 을 불렀는데, 그러면 darts 가 비어 있어
			#  맞은 자리가 **열여덟 판 전부 한 곳**이었다 — 이 모형이 기대고
			#  선 두 축(L² 무게 · 천장)이 일하는 가장자리 타격을 한 번도
			#  안 본 채 초록이었다.
			var fac_lo := 999
			var fac_hi := 0
			var amx_k := 0.0
			var amn_p := INF
			for hp in HITS:
				var hf := float(hp[0])
				var hs := int(hp[1])
				_hit(hf, hs)
				g._brk_arm(t)
				var rings: int = (g.brk_rings as Array).size()
				var fac: int = (g.brk_facets as Array).size()
				var rim: float = g._brk_rim()
				var disc: float = PI * rim * rim
				var at := "%.2fR·씨%d " % [hf, hs]
				fac_lo = mini(fac_lo, fac)
				fac_hi = maxi(fac_hi, fac)
				#  ⓐ 면이 판을 빈틈없이 덮는가 — **방향 모서리 짝짓기**로
				#  잰다. 쪼개기만으로 지은 분할이면 속 모서리는 정순 하나 ·
				#  역순 하나로 짝이 맞고, 짝 없는 모서리는 전부 판 테 위다.
				var tile := _tile(rim)
				if int(tile[0]) > 0:
					th_ok = false
					line += "[%s구멍의 씨앗 %d]" % [at, int(tile[0])]
				if int(tile[1]) > 0:
					th_ok = false
					line += "[%s겹침의 씨앗 %d]" % [at, int(tile[1])]
				#  ⓑ 실루엣이 원 — 면의 최대 반지름이 판 테와 소수점까지 같다
				if absf(float(tile[2]) - g._board_rim(
						g._theme_ring_w(g._board_theme()))) > 0.01:
					th_ok = false
					line += "[%s최대r %.3f]" % [at, float(tile[2])]
				#  ⓒ 크기 — 가장 큰 면이 판의 12% 밑, 가장 작은 면이 25px² 위
				var amx := 0.0
				var amn := INF
				for f in g.brk_facets:
					var ar: float = g._brk_area(f.pts)
					amx = maxf(amx, ar)
					amn = minf(amn, ar)
				amx_k = maxf(amx_k, amx / disc)
				amn_p = minf(amn_p, amn)
				if amx > disc * 0.12:
					th_ok = false
					line += "[%s최대면 %.1f%%]" % [at, amx / disc * 100.0]
				if amn < 25.0:
					th_ok = false
					line += "[%s최소면 %.0fpx²]" % [at, amn]
				if rings > want_bands:
					th_ok = false
					line += "[색 띠 %d > 살아 있는 띠 %d]" % [rings, want_bands]
				g._brk_fire()
				var sh: int = (g.brk_shards as Array).size()
				var bull: int = 1 if g.rt_bull_o > 0.0 else 0
				#  면 한 장이 조각 한 장. 불만 맨 뒤에 따로 얹는다.
				if sh != fac + bull:
					th_ok = false
					line += "[%s조각 %d != 면 %d + 불 %d]" % [at, sh, fac, bull]
				if sh > int(g.BRK.cap):
					th_ok = false
					line += "[%s조각 %d > 상한 %d]" % [at, sh, int(g.BRK.cap)]
				if (g.brk_bits as Array).size() > int(g.BRK.grit_cap):
					th_ok = false
					line += "[%s톱밥 초과]" % at
				g._brk_skip()
			line += "%d~%d·최대%.1f%%·최소%.0f " % [
					fac_lo, fac_hi, amx_k * 100.0, amn_p]
		th_txt += "%s(칸%d) %s " % [id if id != "" else "기본", n, line]
	_ok("테마 여섯에서 면이 판을 빈틈없이 덮는다", th_ok, th_txt)

	# ── ⑧-b 테 — 조각이 판의 **테까지** 먹는다 ──────────────
	#  띠 표는 노는 면(1.0)까지만 적는데 실제로 그려지는 판은 그 밖에 테가
	#  한 겹 더 있고 칸 숫자가 거기 앉는다. 안 먹으면 뜨는 프레임에 테와
	#  숫자만 먼저 사라져 판이 한 번 작아졌다 터진다 — 찍어 보고 잡았다.
	var rim_ok := true
	var rim_txt := ""
	for id in ["", "pizz", "clok", "dnut", "aimb"]:
		_open()
		_board(id)
		g._brk_arm(2)
		var want: float = g.rt_dbl_out + g._theme_ring_w(g._board_theme())
		var got: float = float(g.brk_rings[(g.brk_rings as Array).size() - 1][1])
		if got < want - 0.001:
			rim_ok = false
		rim_txt += "%s %.2f/%.2f  " % [id if id != "" else "기본", got, want]
		g._brk_skip()
	_ok("바깥 겹이 판의 테까지 간다", rim_ok, rim_txt)

	# ── ⑧-c 물감 — 테마마다 **제 판이 칠하는 색**으로 깨진다 ─
	#  _board_cols() 는 토너먼트 판의 진실일 뿐이다. 테마 넷은 그 배열을
	#  받아도 제 물감으로 덮으므로, 안 갈라 주면 시계 판이 빨강·초록으로
	#  깨지고 피자가 먹색으로 깨진다.
	var col_ok := true
	var col_txt := ""
	_open()
	_board("")
	#  ⚠ **바깥 겹의 반지름으로 묻는다.** 과녁·도넛은 색이 칸이 아니라
	#  반지름으로 서는 판이라 _brk_cols_at 이 겹 [r0, r1] 을 같이 받는다.
	g._brk_arm(2)
	var lastb: int = (g.brk_rings as Array).size() - 1
	var or0: float = float(g.brk_rings[lastb][0])
	var or1: float = float(g.brk_rings[lastb][1])
	var in0: float = float(g.brk_rings[0][0])
	var in1: float = float(g.brk_rings[0][1])
	var plain_pair: Array = g._brk_cols_at("", g._board_cols(), 0, or0, or1)
	for th in ["pizza", "clock", "donut", "target"]:
		var p: Array = g._brk_cols_at(th, g._board_cols(), 0, or0, or1)
		if (p[1] as Color).is_equal_approx(plain_pair[1] as Color):
			col_ok = false
		col_txt += "%s %s  " % [th, (p[1] as Color).to_html(false)]
	_ok("테마 넷이 제 물감으로 깨진다", col_ok,
			"기본 %s / %s" % [(plain_pair[1] as Color).to_html(false), col_txt])
	#  ⚠ 과녁·도넛은 **반지름을 안 보면** 안쪽 겹과 바깥 겹이 같은 한 쌍으로
	#  나온다 — 과녁이 판 밖 색(paper)으로, 도넛이 분홍 없이 깨진 그 병이다.
	var rad_ok := true
	var rad_txt := ""
	for th in ["donut", "target"]:
		var pi: Array = g._brk_cols_at(th, g._board_cols(), 0, in0, in1)
		var po: Array = g._brk_cols_at(th, g._board_cols(), 0, or0, or1)
		if (pi[0] as Color).is_equal_approx(po[0] as Color) \
				and (pi[1] as Color).is_equal_approx(po[1] as Color):
			rad_ok = false
		rad_txt += "%s 안 %s/%s · 바깥 %s/%s  " % [th,
				(pi[0] as Color).to_html(false), (pi[1] as Color).to_html(false),
				(po[0] as Color).to_html(false), (po[1] as Color).to_html(false)]
	_ok("과녁·도넛은 색을 반지름으로 고른다", rad_ok, rad_txt)
	#  과녁지 가장자리(paper)는 **판 밖 = 빗나감** 색이다. 조각에 뜨면 안 된다.
	var pap_ok := true
	var pap_txt := ""
	for bi2 in (g.brk_rings as Array).size():
		var pt: Array = g._brk_cols_at("target", g._board_cols(), 0,
				float(g.brk_rings[bi2][0]), float(g.brk_rings[bi2][1]))
		for c in pt:
			if (c as Color).is_equal_approx(g.TARGETART.paper as Color):
				pap_ok = false
		pap_txt += "겹%d %s/%s  " % [bi2, (pt[0] as Color).to_html(false),
				(pt[1] as Color).to_html(false)]
	_ok("과녁 조각에 판 밖 색(paper)이 없다", pap_ok, pap_txt)
	#  불 — 판 어디에도 없는 초록이 과녁 한가운데에 박혀 있었다.
	var bull_ok: bool = (g._brk_bull_col("target") as Color).is_equal_approx(
					g.TARGETART.gold as Color) \
			and (g._brk_bull_col("clock") as Color).is_equal_approx(
					g.CLOCKART.enamel as Color) \
			and (g._brk_bull_col("") as Color).is_equal_approx(g.C_GREEN as Color)
	_ok("불이 테마마다 그 판에 있는 색이다", bull_ok,
			"과녁 %s · 시계 %s · 기본 %s" % [
					(g._brk_bull_col("target") as Color).to_html(false),
					(g._brk_bull_col("clock") as Color).to_html(false),
					(g._brk_bull_col("") as Color).to_html(false)])
	g._brk_skip()

	# ── ⑧-d 리듬 — **한 색으로 깨지지 않는다** ──────────────
	#  판은 밝고 어두운 칸이 번갈아 도는 물건이라 그 리듬이 조각에 안
	#  남으면 「판이 깨졌다」가 아니라 「무언가 흩어졌다」가 된다. 두 번
	#  깨졌다: 한 번은 조각이 먹는 칸 수가 짝수라 언제나 같은 홀짝 칸을
	#  짚어 판이 통째로 빨강이었고, 한 번은 피자가 [cheese, crust] 한 쌍을
	#  박아 두어 ci 를 안 봐서 **열일곱 조각이 전부 창백한 치즈**였다.
	#  바깥 물감도 같이 잰다 — 피자는 띠 폭이 0 이라 섞는 비가 구조적으로
	#  0 이 나와 크러스트가 한 조각도 안 떴다(_brk_band_mix 의 접힌 판 갈래).
	var rhy_ok := true
	var rhy_txt := ""
	for m in [["", "기본"], ["pizz", "피자"], ["clok", "시계"],
			["dnut", "도넛"], ["aimb", "과녁"]]:
		_open()
		_board(String(m[0]))
		g._brk_arm(2)
		g._brk_fire()
		var seen := {}
		var outer := {}
		var last: int = (g.brk_rings as Array).size() - 1
		for s in g.brk_shards:
			seen[(s.col as Color).to_html(false)] = true
		#  바깥 물감이 실제로 섞여 드는지 — **면이 무는 구간**으로 묻는다.
		#  ⚠ 앞서는 「그 겹의 띠」를 넣었는데, 조각이 실제로 무는 폭과 달라
		#  `_brk_band_mix` 가 제 뜻대로 못 섰다. 판 테를 무는 면만 골라
		#  그 면의 r0n~r1n 을 그대로 넣는다.
		for f in g.brk_facets:
			var r0n := INF
			var r1n := 0.0
			for q in f.pts:
				var rr: float = (q as Vector2).length() / maxf(g.R, 1.0)
				r0n = minf(r0n, rr)
				r1n = maxf(r1n, rr)
			if r1n < float(g.brk_rings[last][1]) - 0.02:
				continue
			var mx: float = g._brk_band_mix(r0n, r1n)
			outer[snappedf(mx, 0.01)] = true
			if mx <= 0.0:
				rhy_ok = false
		if seen.size() < 3:
			rhy_ok = false
		rhy_txt += "%s 색%d·바깥섞임%s  " % [String(m[1]), seen.size(),
				"·".join((outer.keys() as Array).map(
						func(v): return "%.2f" % float(v)))]
		g._brk_skip()
	_ok("한 색으로 안 깨진다 — 판의 리듬이 조각에 남는다", rhy_ok, rhy_txt)

	# ── ⑨ 보드 확장 — 천체 고리에서 겹이 는다 ───────────────
	_open()
	_board("arst")
	_ok("천체 고리가 띠를 넷에서 여섯으로 벌린다", _bands().size() == 6,
			"살아 있는 띠 %d" % _bands().size())
	g._brk_arm(2)
	var arst_ok := true
	for e in g.brk_rings:
		var hit := false
		for b in _bands():
			if absf(float(e[0]) - float(b[0])) < 0.001:
				hit = true
		if not hit:
			arst_ok = false
	_ok("겹 경계가 조준 어둠과 같은 칸을 가리킨다", arst_ok,
			"겹 %d개 — 전부 _board_dim_sector 의 띠 경계 위" % (g.brk_rings as Array).size())
	g._brk_skip()

	# ── ⑩ 층 — 길이는 셋이 같고 겹·톱밥·소리만 갈린다 ───────
	_open()
	_board("")
	var tier_len := []
	var tier_txt := ""
	#  ⚠ **칸이 하나 늘었다 — 살과 면.** 앞서는 겹·단·톱밥·소리 넷이었는데,
	#  겹이 조각 기하에서 빠졌으므로 겹만으로는 층이 안 갈린다. 그리고
	#  앞 모형에서는 `_brk_wedges` 가 10/8/8 을 **전부 10 으로 스냅해**
	#  작은 판과 큰 판이 기하에서 글자 그대로 같았다(둘 다 21조각·단 4) —
	#  그 사실을 자가 한 번도 못 잡았다. 살 9/12/15 는 약수 제약이 없어
	#  **실제로 갈리고**, 그것을 여기서 못 박는다.
	#  ⚠ **맞은 자리를 셋에서 똑같이 둔다.** 면 수는 맞은 자리에 따라
	#  달라지므로(치우치면 천장이 더 쪼갠다) 같은 자리에서 견줘야 사다리가
	#  층의 것이 된다.
	for t in 3:
		g.darts = [{"p": g.BC + Vector2(0.0, -g.R * 0.30), "id": "std",
				"rot": 0.0}]
		g._brk_arm(t)
		var spk: int = (g.brk_spokes as Array).size()
		var fac: int = (g.brk_facets as Array).size()
		g._brk_fire()
		var row: Dictionary = g.BRK[["small", "big", "boss"][t]]
		tier_len.append([spk, g.brk_stage, (g.brk_bits as Array).size(),
				int(row.snd), fac])
		tier_txt += "%s 살%d·단%d·톱밥%d·소리%d·면%d  " % [
				["작은", "큰", "보스"][t], spk, g.brk_stage,
				(g.brk_bits as Array).size(), int(row.snd), fac]
		g._brk_skip()
	var ladder_ok: bool = int(tier_len[0][0]) < int(tier_len[1][0]) \
			and int(tier_len[1][0]) < int(tier_len[2][0]) \
			and int(tier_len[0][1]) <= int(tier_len[2][1]) \
			and int(tier_len[0][2]) < int(tier_len[2][2]) \
			and int(tier_len[0][3]) < int(tier_len[2][3]) \
			and int(tier_len[0][4]) < int(tier_len[2][4])
	_ok("층이 살·단·톱밥·소리·면으로 오른다", ladder_ok, tier_txt)
	#  ⚠ **작은 판과 큰 판이 기하에서 실제로 갈린다.** 앞 모형이 조용히
	#  깨뜨리고 있던 바로 그 자리라 따로 못 박는다.
	_ok("작은 판과 큰 판이 기하에서 갈린다",
			int(tier_len[0][0]) != int(tier_len[1][0])
			and int(tier_len[0][4]) != int(tier_len[1][4]),
			"살 %d/%d · 면 %d/%d" % [int(tier_len[0][0]), int(tier_len[1][0]),
					int(tier_len[0][4]), int(tier_len[1][4])])
	var same_len := absf(float(g.BRK.hold) + float(g.BRK.life_hi)) > 0.0
	_ok("길이는 셋이 같다 — 표에 층별 시간이 없다",
			same_len and not g.BRK.has("small_t"),
			"hold %.3f + life_hi %.2f = %.3f (층과 무관)"
			% [float(g.BRK.hold), float(g.BRK.life_hi),
					float(g.BRK.hold) + float(g.BRK.life_hi)])

	# ── ⑪ 소리 — 표에 있고 파일이 있고 겹이 층대로다 ────────
	_ok("board_break 가 SFX 표에 있다", (g.SFX as Dictionary).has("board_break"),
			"표에 없는 이름은 push_error 로 무음이 된다")
	_ok("board_break.wav 가 구워져 있다",
			ResourceLoader.exists("res://sfx/board_break.wav"), "")
	_ok("종의 비(tierce 1.2)를 안 쓴다",
			absf(float(g.BRK.small.pitch) / float(g.BRK.big.pitch) - 1.2) > 0.05
			and absf(float(g.BRK.big.pitch) / float(g.BRK.boss.pitch) - 1.2) > 0.05,
			"%.3f · %.3f" % [float(g.BRK.small.pitch) / float(g.BRK.big.pitch),
					float(g.BRK.big.pitch) / float(g.BRK.boss.pitch)])
	_ok("음이 내려간다 — 등장은 올리고 퇴장은 내린다",
			float(g.BRK.small.pitch) > float(g.BRK.big.pitch)
			and float(g.BRK.big.pitch) > float(g.BRK.boss.pitch),
			"%.2f → %.2f → %.2f" % [float(g.BRK.small.pitch),
					float(g.BRK.big.pitch), float(g.BRK.boss.pitch)])
	var snd_txt := ""
	var snd_ok := true
	var crk_txt := ""
	var crk_ok := true
	for t in 3:
		_open()
		g.leg_no = t + 1          # 작은 1 · 큰 2 · 보스 3
		var r := _throw()
		var row: Dictionary = g.BRK[["small", "big", "boss"][t]]
		#  **판이 뜨는 소리** = 발화 한 방 + 꼬리 톡(row[3] − 1).
		#  금이 번지는 앞 0.68초의 삐걱(board_crack)은 여기서 안 센다 —
		#  그것은 사건이 아니라 사건이 오는 소리이고, 아래 줄이 따로 센다.
		snd_txt += "%s 한방%d+톡%d(표 %d)  " % [["작은", "큰", "보스"][t],
				int(r.brk), int(r.snd), int(row.snd)]
		if int(r.brk) + int(r.snd) != int(row.snd):
			snd_ok = false
		#  ⚠ **단마다 한 알.** 작은 판은 꼬리 톡이 0회라, 이 줄이 없으면
		#  런에서 맨 처음 듣는 깨짐이 0.30초짜리 한 방뿐이다(2026-09-24).
		crk_txt += "%s 단%d·삐걱%d  " % [["작은", "큰", "보스"][t],
				int(r.stage), int(r.crack)]
		if int(r.crack) != int(r.stage) or int(r.stage) <= 0:
			crk_ok = false
	_ok("판이 뜨는 소리가 층대로 1·2·3 — 한 방 + 꼬리 톡", snd_ok, snd_txt)
	_ok("금이 번지는 동안 단마다 삐걱이 한 알", crk_ok, crk_txt)
	_ok("board_crack 이 SFX 표에 있고 파일이 있다",
			(g.SFX as Dictionary).has("board_crack")
			and ResourceLoader.exists("res://sfx/board_crack.wav"),
			"표에 없는 이름은 push_error 로 무음이 된다")
	#  삐걱은 **한 방보다 여려야 한다** — 사건이 오는 소리가 사건보다 크면
	#  발화가 안 들린다. 표의 a 로 잰다.
	_ok("삐걱이 한 방보다 여리다",
			float(g.SFX.board_crack.a) < float(g.SFX.board_thud.a)
			and float(g.SFX.board_thud.a) < float(g.SFX.board_break.a),
			"삐걱 %.2f < 톡 %.2f < 한방 %.2f" % [float(g.SFX.board_crack.a),
					float(g.SFX.board_thud.a), float(g.SFX.board_break.a)])
	#  단 간격이 SMASH.snd_gap 위여야 한 알씩 갈린다. 보스가 제일 촘촘하다 —
	#  brk_span(걸음 꼬리에서 난다) × 0.90 을 단 수로 나눈 것이 그 간격이다.
	g._brk_arm(2)
	var gap: float = (g.brk_span * 0.90) / float(int(g._brk_row().stages))
	_ok("단 간격이 SMASH.snd_gap 위", gap >= float(g.SMASH.snd_gap),
			"보스 %.3f / 문턱 %.3f" % [gap, float(g.SMASH.snd_gap)])
	g._brk_skip()
	_ok("한 사건의 소리가 pool 4 밑", int(g.BRK.boss["snd"]) <= 3,
			"보스 %d개 / sfx_pool %d" % [int(g.BRK.boss["snd"]),
					(g.sfx_pool as Array).size()])
	_ok("톡 사이가 SMASH.snd_gap 위",
			float(g.BRK.thud[1]) - float(g.BRK.thud[0]) >= float(g.SMASH.snd_gap),
			"%.3f / 문턱 %.3f" % [float(g.BRK.thud[1]) - float(g.BRK.thud[0]),
					float(g.SMASH.snd_gap)])

	# ── ⑫ 빨리 보기 — 순서가 그대로고 꼬리 톡이 0회 ─────────
	_open()
	g.leg_no = 3
	g.fast_lock = true
	g.fast_mul = 2.5
	var fr := _throw()
	g.fast_lock = false
	g.fast_mul = 1.0
	_ok("빨리 보기에서도 순서가 그대로",
			int(fr.arm) >= 0 and int(fr.fire) > int(fr.arm)
			and int(fr.clear) > int(fr.fire),
			"도안 %d · 발화 %d · 정산 %d" % [fr.arm, fr.fire, fr.clear])
	_ok("빨리 보기에서 꼬리 톡도 삐걱도 0회 — 소리는 board_break 하나",
			int(fr.snd) == 0 and int(fr.crack) == 0 and int(fr.brk) == 1,
			"한방 %d · 톡 %d · 삐걱 %d — 안 막으면 정산 프레임에 소리가 다섯이라 target_hit 이 끊긴다"
			% [int(fr.brk), int(fr.snd), int(fr.crack)])
	_ok("빨리 보기가 창을 줄인다",
			int(fr.clear) - int(fr.arm) < int(live.clear) - int(live.arm),
			"%d프레임 < %d프레임" % [int(fr.clear) - int(fr.arm),
					int(live.clear) - int(live.arm)])

	# ── ⑬ 소크 — 그림 0 · 소리 0 · 시간 0 ───────────────────
	_open()
	g.drop_fast = true
	var dr := _throw()
	g.drop_fast = false
	_ok("소크는 도안을 아예 안 세운다", int(dr.arm) < 0 and not g.brk_live,
			"arm %d · brk_live %s" % [dr.arm, g.brk_live])

	# ── ⑭ 모션 끄기 — 움직임만 끄고 빛·소리는 남는다 ────────
	_open()
	_board("")
	g.motion_off = true
	g.leg_no = 3
	var mo := _throw()
	_ok("모션 끄기 — 조각을 아예 안 만든다", int(mo.shards) == 0 and int(mo.bits) == 0,
			"조각 %d · 톱밥 %d" % [mo.shards, mo.bits])
	_ok("모션 끄기 — 판이 안 사라진다", not is_inf(g._brk_board_dy()),
			"_brk_board_dy %.1f — 순간 소멸은 깜빡임이지 그림이 아니다"
			% g._brk_board_dy())
	_ok("모션 끄기 — 금은 끝까지 그어진다", int(mo.stage) >= 6,
			"단 %d" % mo.stage)
	_ok("모션 끄기 — 소리는 층대로 그대로 난다",
			int(mo.brk) + int(mo.snd) == 3 and int(mo.crack) == int(mo.stage),
			"한방 %d + 톡 %d = 3 · 삐걱 %d(단 %d)"
			% [int(mo.brk), int(mo.snd), int(mo.crack), int(mo.stage)])
	_ok("모션 끄기 — 프레임 수가 그대로",
			int(mo.clear) - int(mo.arm) <= int(live.clear) - int(live.arm) + 4,
			"%d프레임 (켬 %d프레임 — 돌파 멈춤 60ms 가 원래 없다)"
			% [int(mo.clear) - int(mo.arm), int(live.clear) - int(live.arm)])
	g.motion_off = false

	# ── ⑮ 손잡이 — 도구 51개가 지나는 문 ────────────────────
	_open()
	g._brk_arm(2)
	g._brk_fire()
	var was_live: bool = g.brk_live
	g._swap_skip()
	_ok("_swap_skip 이 깨짐도 같이 내린다",
			was_live and not g.brk_live and not is_inf(g._brk_board_dy()),
			"정지 프레임을 찍는 도구가 게임과 같은 판을 찍는다")
	g._brk_arm(2)
	g._brk_fire()
	g._start_leg()
	_ok("_start_leg 이 지난 판의 깨짐을 안 물려받는다", not g.brk_live, "")
	g._swap_skip()

	# ── ⑮-b 판을 떠나면 내린다 — 제목 판을 안 지운다 ────────
	#  판 중의 ESC → 「로비로 나가기」는 state 를 곧장 S.TITLE 로 옮기고
	#  내리는 자리 셋(_finish_leg · _start_leg · _swap_skip)을 하나도 안
	#  밟는다. 안 막으면 brk_live 가 참인 채 남아 _brk_board_dy() 가 INF 를
	#  계속 내고, 판 층을 그리는 문에 state 갈래가 없으므로 **제목 화면의
	#  다트판이 영영 안 그려진다.** 문이 두 겹이라 둘 다 잰다.
	_open()
	g._brk_arm(2)
	g._brk_fire()
	g.state = g.S.TITLE
	g.pause_from = -1
	_ok("판을 떠난 프레임에 이미 판이 돌아온다",
			not is_inf(g._brk_board_dy()),
			"그리는 쪽 문 — _brk_tick 이 hitstop 에 건너뛴 프레임도 덮는다")
	for _k in 5:
		g._brk_tick(DT)
	_ok("제목으로 나가면 깨짐이 내려간다",
			not g.brk_live and (g.brk_shards as Array).is_empty()
			and not is_inf(g._brk_board_dy()),
			"brk_live %s · 조각 %d · _brk_board_dy %.1f"
			% [g.brk_live, (g.brk_shards as Array).size(), g._brk_board_dy()])
	#  금만 난 중(발화 전)에 나가도 제목 판에 금이 안 박힌다.
	_open()
	g.state = g.S.RESOLVE       # 금이 나려면 걸음 안이어야 한다
	g._brk_arm(2)
	for _k in 10:
		g._brk_tick(DT)
	var mid_stage: int = g.brk_stage
	g.state = g.S.TITLE
	g._brk_tick(DT)
	_ok("금만 난 중에 나가도 금이 안 남는다",
			mid_stage > 0 and not g.brk_live and g.brk_stage == 0,
			"나가기 전 단 %d → 단 %d" % [mid_stage, g.brk_stage])
	#  ⚠ **판 중에 연 설정은 얼기 그대로다.** _is_play_deep() 이 밑에 깔린
	#  화면을 보므로 여기서 갈리면 안 된다 — 닫고 돌아온 손님이 깨지던
	#  판을 이어서 본다.
	_open()
	g._brk_arm(2)
	g._brk_fire()
	g.pause_from = g.S.RESOLVE
	g.state = g.S.SETTINGS
	var froze: Vector2 = g.brk_shards[0].c
	for _k in 10:
		g._brk_tick(DT)
	_ok("판 중에 연 설정은 내리지 않고 언다",
			g.brk_live and g.brk_shards.size() > 0
			and (g.brk_shards[0].c as Vector2).is_equal_approx(froze),
			"brk_live %s · 조각이 제자리 %s"
			% [g.brk_live, (g.brk_shards[0].c as Vector2).is_equal_approx(froze)])
	g.state = g.S.RESOLVE
	g.pause_from = -1
	g._brk_skip()

	# ── ⑯ 씨 — 판마다 다르고 같은 판은 늘 같다 ──────────────
	_open()
	_board("")
	var seeds := {}
	var shapes := []
	for ln in [1, 2, 3, 12, 24, 25, 60, 102]:
		g.leg_no = ln
		g._brk_arm(2)
		seeds[ln] = g.brk_seed
		g._brk_fire()
		var sig := ""
		for s in g.brk_shards:
			sig += "%.1f,%.1f;" % [float((s.v as Vector2).x), float((s.v as Vector2).y)]
		shapes.append(sig)
		g._brk_skip()
	var uniq := {}
	for s in shapes:
		uniq[s] = true
	_ok("판마다 파단선이 다르다", uniq.size() == shapes.size(),
			"표본 %d개 중 서로 다른 무늬 %d개" % [shapes.size(), uniq.size()])
	g.leg_no = 24
	g._brk_arm(2)
	var s24: int = g.brk_seed
	g._brk_skip()
	_ok("같은 판은 늘 같은 무늬", s24 == int(seeds[24]),
			"씨 %d — 날 때마다 바뀌면 깨지는 게 아니라 깜빡이는 것이다" % s24)

	# ── ⑯-b 조각이 나는 꼴 — 한 겹이 한 속도로 안 난다 ──────
	#  ⚠ **흔들림을 빼고 잰다.** v 는 (바깥 속도 × 발사 방향) + (옆 흔들림,
	#  −위로)라, 그냥 |v| 를 재면 위로 성분이 다 덮어 버린다. 흔들림 두
	#  줄은 씨와 (j · bi) 만으로 나므로 여기서 **그대로 다시 떠서** 뺀다 —
	#  그러면 남는 것이 조각별 바깥 속도와 발사각 그 자체다. 조각은
	#  j(부채) 바깥 · bi(겹) 안쪽 차례로 쌓이고 불이 맨 뒤다.
	#  옛 코드는 sp 가 bi 만 읽어 **한 겹의 조각이 전부 같은 속도로 같은
	#  각도**였다 — 멈춘 그림이 바람개비였다(사용자 제보, 2026-09-24).
	_open()
	_board("")
	g.leg_no = 7
	g._brk_arm(2)
	g._brk_fire()
	var nb: int = (g.brk_rings as Array).size()
	var sd: int = g.brk_seed
	var ulo: float = float(g.BRK.up_lo)
	var uhi: float = float(g.BRK.up_hi)
	var lay := {}                      # 거리 띠 → [바깥 속도]
	var dmax := 0.0                    # 발사각이 제 방향에서 벗어난 최대
	var dover := 0.0                   # 그 벗어남이 제 면의 각폭 1/4 을 넘은 몫
	var far_lo := INF                  # 맞은 자리에 가장 가까운 면의 속도
	var far_hi := 0.0                  # 가장 먼 면의 속도
	var far_dlo := INF
	var far_dhi := 0.0
	#  ⚠ **겹도 j 도 없다.** 앞 자는 `brk_shards[j*nb+bi]` 로 부채×겹 격자
	#  인덱스를 직접 찍었는데 그물에는 그런 격자가 없다. 지키려던 것(한
	#  겹이 통째로 같은 속도로 나면 깨진 판이 아니라 **바람개비가 열리는
	#  그림**이다)은 겹 없이 그대로 선다 — **무게중심이 맞은 자리에서
	#  얼마나 먼가**로 0.25R 띠를 묶어 같은 띠 안을 견준다.
	for i in (g.brk_facets as Array).size():
		var sh: Dictionary = g.brk_shards[i]
		var sdi: int = i * 37 + 1
		var jit := Vector2((g._gl_rand(sdi * 7 + 2, sd) - 0.5) * 52.0,
				-lerpf(ulo, uhi, g._gl_rand(sdi * 11 + 3, sd)))
		var core: Vector2 = (sh.v as Vector2) - jit
		#  ⚠ **판 한복판이 아니라 맞은 자리에서 잰다.**
		var dv: Vector2 = (sh.c as Vector2) - g.brk_hit
		var u0: Vector2 = dv.normalized()
		var band: int = int(dv.length() / (g.R * 0.25))
		if not lay.has(band):
			lay[band] = []
		(lay[band] as Array).append(core.length())
		var dev: float = absf(u0.angle_to(core))
		dmax = maxf(dmax, dev)
		#  그 면이 **맞은 자리에서 보이는 각폭**의 1/4 안이어야 한다.
		#  ⚠ 절대 라디안으로 박으면 안 된다 — 면 크기가 안팎으로 열 배 다르다.
		var lo2 := INF
		var hi2 := -INF
		for q in (g.brk_facets[i] as Dictionary).pts:
			var rel: float = wrapf((q as Vector2 - g.brk_hit).angle()
					- u0.angle(), -PI, PI)
			lo2 = minf(lo2, rel)
			hi2 = maxf(hi2, rel)
		dover = maxf(dover, dev - clampf(hi2 - lo2, 0.0, PI) * 0.25 - 0.0001)
		if dv.length() < far_dlo:
			far_dlo = dv.length()
			far_lo = core.length()
		if dv.length() > far_dhi:
			far_dhi = dv.length()
			far_hi = core.length()
	var sp_ok := true
	var sp_txt := ""
	for bi in lay.keys():
		var la: Array = lay[bi]
		if la.size() < 2:
			continue
		var seen := {}
		for v in la:
			seen["%.2f" % float(v)] = true
		var lo := INF
		var hi := 0.0
		for v in la:
			lo = minf(lo, float(v))
			hi = maxf(hi, float(v))
		#  조각마다 다른 속도여야 하고(같은 값이 둘이면 겹 번호만 읽은 것이다)
		#  가장 빠른 조각이 가장 느린 조각의 1.3배는 넘어야 한다(표 0.70~1.35).
		if seen.size() != la.size() or hi < lo * 1.3:
			sp_ok = false
		sp_txt += "띠%d %d개 %.0f~%.0f(×%.2f)  " % [bi, la.size(), lo, hi,
				hi / maxf(lo, 0.001)]
	_ok("같은 거리 띠 안에서 조각마다 바깥 속도가 다르다", sp_ok, sp_txt)
	#  ⚠ **속도가 맞은 자리에서의 거리로 오른다.** 표(sp_lo~sp_hi)를 한 톨도
	#  안 건드리고 기준값을 거리로 매는 그 줄을 여기서 못 박는다 — 앞
	#  모형은 겹 번호로 맸다.
	_ok("바깥 속도가 맞은 자리에서 멀수록 빠르다", far_hi > far_lo,
			"가까운 %.0fpx → %.0fpx/s · 먼 %.0fpx → %.0fpx/s"
					% [far_dlo, far_lo, far_dhi, far_hi])
	#  발사각 — 제 방향 고정이 아니라 **제 면의 각폭**의 1/4 안에서 흔들린다.
	_ok("발사각이 제 면의 각폭 안에서 흔들린다",
			dmax > 0.001 and dover <= 0.0,
			"최대 %.3f rad · 각폭 1/4 을 넘은 몫 %.4f" % [dmax, maxf(dover, 0.0)])
	#  불 — 바깥 성분이 0 이면 둘레가 다 식은 뒤 한가운데에 혼자 남는다.
	var bull: Dictionary = g.brk_shards[(g.brk_shards as Array).size() - 1]
	var bjit := Vector2((g._gl_rand(991, sd) - 0.5) * 70.0,
			-lerpf(ulo, uhi, g._gl_rand(992, sd)))
	var bout: float = ((bull.v as Vector2) - bjit).length()
	_ok("불도 바깥으로 난다 — 제자리에서 위아래로만 안 논다",
			bout >= float(g.BRK.sp_lo) * 0.70 - 0.5,
			"바깥 %.0fpx/s / 바닥 %.0f" % [bout, float(g.BRK.sp_lo) * 0.70])
	_ok("불이 마지막에 진다 — 수명이 life_hi 로 박혀 있다",
			is_equal_approx(float(bull.life), float(g.BRK.life_hi)),
			"불 %.3f / life_hi %.3f" % [float(bull.life), float(g.BRK.life_hi)])
	g._brk_skip()

	# ── ⑰ 입력 — 새 잠금 깃발을 안 만든다 ───────────────────
	_open()
	g._brk_arm(2)
	g._brk_fire()
	_ok("깨짐이 입력을 안 삼킨다",
			not g.swap_live and not g.turn_live and not g.sweep_live,
			"swap %s · turn %s · sweep %s"
			% [g.swap_live, g.turn_live, g.sweep_live])
	g._brk_skip()

	# ── ⑱ 개발자 모드 — 같은 턴에 길을 낸다 ─────────────────
	#  「게임에 만든 것은 같은 턴에 개발자 모드에도 길을 낸다」가 이 저장소의
	#  규약이다. 줄이 있는가 · 한 쪽 한계(19줄)를 안 넘는가 · 고르개가 안
	#  비는가 · 눌렀을 때 값(골드 · 목표 · leg_no)이 한 톨도 안 움직이는가.
	_open()
	Dev.page = 2
	var rows: Array = Dev._rows(g)
	var row := {}
	for r in rows:
		if String(r.get("k", "")) == "brk":
			row = r
	_ok("2쪽에 「판 깨짐 다시 보기」 줄이 있다", not row.is_empty(),
			"2쪽 %d줄" % rows.size())
	_ok("한 쪽 한계(19줄)를 안 넘는다", rows.size() <= 19,
			"%d줄 — _panel y[22,352] · _row y 62+15i · 높이 13" % rows.size())
	_ok("고르개가 안 빈다 — _names 와 _cur_name 이 짝이다",
			Dev._names("brk").size() == 3 and Dev._cur_name(g, row) != "",
			"%s / '%s'" % [", ".join(Dev._names("brk")), Dev._cur_name(g, row)])
	if not row.is_empty():
		var gold0: int = g.gold
		var leg0: int = g.leg_no
		var tgt0: int = g.target
		Dev.pick["brk"] = 2
		Dev._run(g, row)
		var dev_live: bool = g.brk_live and g.brk_tier == 2
		#  다시 보기가 제 시계로 돌아 실제로 뜨는지 — dev 는 걸음 밖이다.
		var fired := false
		for _k in 90:
			g._brk_tick(DT)
			if g.brk_fired:
				fired = true
		_ok("누르면 그 층으로 깨진다", dev_live and fired,
				"brk_live %s · 층 %d · 발화 %s" % [g.brk_live, g.brk_tier, fired])
		_ok("개발자 모드가 런 진도를 안 만진다",
				g.gold == gold0 and g.leg_no == leg0 and g.target == tgt0,
				"골드 %d→%d · 판 %d→%d · 목표 %d→%d"
				% [gold0, g.gold, leg0, g.leg_no, tgt0, g.target])
		#  다시 보기의 끝맺음은 dev 가 쥔다 — 게임 쪽은 일부러 스스로 안 끝낸다.
		for _k in 90:
			Dev.tick(g, DT)
			g._brk_tick(DT)
		_ok("다시 보기가 끝나면 판이 돌아온다",
				not g.brk_live and not is_inf(g._brk_board_dy()),
				"brk_live %s · _brk_board_dy %.1f" % [g.brk_live, g._brk_board_dy()])
	_ok("소리 쪽은 저절로 는다 — SFX.keys() 를 읽는다",
			Dev._list("sfx").any(func(e): return String(e.n) == "board_break"),
			"4쪽에 줄을 안 더한다")
	#  깊이 줄 둘도 같은 자를 댄다 — 고르개가 안 비는가.
	_open()
	Dev.page = 2
	var rows2: Array = Dev._rows(g)
	var drow := {}
	var srow := {}
	for r in rows2:
		if String(r.get("k", "")) == "brkdeep":
			drow = r
		if String(r.get("k", "")) == "src":
			srow = r
	_ok("2쪽에 「오버 금 다시 보기」 줄이 있다", not drow.is_empty(),
			"2쪽 %d줄" % rows2.size())
	_ok("오버 금 고르개가 안 빈다",
			Dev._names("brkdeep").size() == 4 and Dev._cur_name(g, drow) != "",
			"%s / '%s'" % [", ".join(Dev._names("brkdeep")),
					Dev._cur_name(g, drow)])
	_ok("2쪽에 「출처 짚기 다시 보기」 줄이 있다", not srow.is_empty(), "")
	_ok("출처 짚기 고르개가 안 빈다",
			Dev._names("src").size() == 4 and Dev._cur_name(g, srow) != "",
			"%s / '%s'" % [", ".join(Dev._names("src")), Dev._cur_name(g, srow)])
	if not srow.is_empty():
		var sg0: int = g.gold
		var sl0: int = g.leg_no
		Dev.pick["src"] = 3
		Dev._run(g, srow)
		_ok("「출처 짚기」가 고리 · 얹힘으로 선다",
				g.src_t > 0.0 and g.src_ring and g.src_mix
				and g.hit_flash_amt > 0.0,
				"빛 %.2f · 고리 %s · 얹힘 %s · 세기 %.2f"
				% [g.src_t, g.src_ring, g.src_mix, g.hit_flash_amt])
		_ok("「출처 짚기」가 런 진도를 안 만진다",
				g.gold == sg0 and g.leg_no == sl0,
				"골드 %d→%d · 판 %d→%d" % [sg0, g.gold, sl0, g.leg_no])
		g.src_t = 0.0
	if not drow.is_empty():
		var dg0: int = g.gold
		var dl0: int = g.leg_no
		var dt0: int = g.target
		Dev.pick["brkdeep"] = 3
		Dev._run(g, drow)
		_ok("「오버 금」이 3단으로 깨진다", g.brk_live and g.brk_deep == 3,
				"brk_live %s · 단 %d" % [g.brk_live, g.brk_deep])
		_ok("「오버 금」이 런 진도를 안 만진다",
				g.gold == dg0 and g.leg_no == dl0 and g.target == dt0,
				"골드 %d→%d · 판 %d→%d · 목표 %d→%d"
				% [dg0, g.gold, dl0, g.leg_no, dt0, g.target])
		for _k in 180:
			Dev.tick(g, DT)
			g._brk_tick(DT)
		g._brk_skip()
	#  ⚠ **위 「판 깨짐」 줄은 0단을 못 박아야 한다.** 그 줄이 재는 것은
	#  층이다 — 깊이가 판을 따라가면 같은 층을 두 번 눌러도 금 굵기가
	#  달라져 무엇이 무엇을 바꿨는지 못 가른다.
	if not row.is_empty():
		_open()
		g.total = 999999          # 자가 3단으로 뜨는 자리
		Dev.pick["brk"] = 1
		Dev._run(g, row)
		_ok("「판 깨짐」 줄은 깊이를 0 으로 못 박는다", g.brk_deep == 0,
				"단 %d — 한 줄이 한 축만 말한다" % g.brk_deep)
		g._brk_skip()

	# ══ 오버 금 (BRKDEEP) — 깊이 축 ═══════════════════════════
	#  사용자: 「판에서 플레이한 점수가 목표점수보다 높아지고 오버할수록
	#  효과로 금가는 거」(2026-09-25). 깊이는 **있는 금 하나를 갈아 끼운다** —
	#  같은 함수 · 같은 기하 · 같은 씨 · 같은 단 수 · 같은 길이.
	#  아래 다섯이 그 「같다」를 전부 수로 붙든다.

	# ── ⑲ 깊이가 층의 것을 한 톨도 안 만진다 ────────────────
	#  두 축이 안 겹친다는 것의 유일한 그물이다. 없으면 ⑧ ⑩ 이 깊이 0단
	#  에서만 재는 것이 **우연**으로 남는다.
	var ax_ok := true
	var ax_txt := ""
	for id in ["", "pizz", "dnut"]:
		_open()
		_board(id)
		var base := []
		for t in 4:
			g._brk_arm(2, t)
			var w0: int = (g.brk_spokes as Array).size()
			var rg: int = (g.brk_rings as Array).size()
			var dborn: int = (g.brk_born as PackedFloat32Array).size()
			var sd2: int = g.brk_seed
			var drow3: int = int(g._brk_row().snd)
			#  ⚠ **면의 꼭짓점까지 글자 그대로 같아야 한다.** 깊이가 더하는
			#  둘(멈춘 곁가지 · 구덩이 고리)은 **면을 한 장도 안 가르므로**
			#  이것이 검사로가 아니라 **구조적으로** 참이다 — 그 둘이 제
			#  난수 흐름을 따로 쓰는 것이 그 까닭이다(_brk_deep_cracks).
			var vsum := 0.0
			var vn := 0
			for f in g.brk_facets:
				for q in f.pts:
					vsum += (q as Vector2).x * 1.7 + (q as Vector2).y * 3.1
					vn += 1
			g._brk_fire()
			var cur := [w0, rg, g.brk_stage, (g.brk_bits as Array).size(),
					(g.brk_shards as Array).size(), drow3, dborn, sd2,
					vn, snappedf(vsum, 0.001)]
			if t == 0:
				base = cur
			elif cur != base:
				ax_ok = false
				ax_txt += "[%s 단%d %s != %s]" % [id, t, str(cur), str(base)]
			g._brk_skip()
		ax_txt += "%s 부채%d·겹%d·단%d·톱밥%d·조각%d·소리겹%d  " % [
				id if id != "" else "기본", int(base[0]), int(base[1]),
				int(base[2]), int(base[3]), int(base[4]), int(base[5])]
	_ok("깊이가 층의 것(기하·개수·씨)을 한 톨도 안 만진다", ax_ok, ax_txt)

	# ── ⑳ 길이 0 — 이번 일의 유일한 치명상 ──────────────────
	#  돌파 걸음 70프레임 중 0~69 를 BRK 가 이미 쓴다. **빈 프레임이 1** 이라
	#  깊이가 한 프레임이라도 늘리면 정산(S.CLEAR)으로 샌다.
	#  ⚠ **1.0배로만 보면 절대 안 드러난다** — 2.5배에서는 마지막 조각이
	#  지는 프레임과 걸음 끝이 0프레임 차다. 박자 셋 × 빨리 보기까지 댄다.
	var len_ok := true
	var len_txt := ""
	for bt2 in [0.34, 0.26, 0.015]:
		var lwant := -1
		for t in 4:
			_open()
			g.beat = bt2
			var rr2 := _throw(false, 900, t)
			var lgot: int = int(rr2.clear) - int(rr2.arm)
			if lwant < 0:
				lwant = lgot
			elif lgot != lwant:
				len_ok = false
				len_txt += "[beat %.3f 단%d %d != %d]" % [bt2, t, lgot, lwant]
		len_txt += "beat %.3f → %d프레임  " % [bt2, lwant]
	g.beat = beat
	#  빨리 보기 2.5배에서도 네 단이 같은 프레임 수다. 2.5배에서는 마지막
	#  조각이 지는 프레임과 걸음 끝이 0프레임 차라 여기가 진짜 자다.
	var fwant := -1
	for t in 4:
		_open()
		g.fast_lock = true
		g.fast_mul = 2.5
		var rf2 := _throw(false, 900, t)
		var gotf: int = int(rf2.clear) - int(rf2.arm)
		if fwant < 0:
			fwant = gotf
		elif gotf != fwant:
			len_ok = false
			len_txt += "[2.5배 단%d %d != %d]" % [t, gotf, fwant]
	g.fast_lock = false
	g.fast_mul = 1.0
	len_txt += "2.5배 → %d프레임" % fwant
	_ok("깊이가 걸음을 한 프레임도 안 늘린다", len_ok, len_txt)

	# ── ㉑ 자가 안 터진다 ───────────────────────────────────
	#  clampi 가 가장 값싼 안전장치다. 이 도구의 던지기가 target 1 · total 0
	#  이라 자가 60배로 뜨고, 실측 최대도 x10.89 다(deep_probe). 클램프가
	#  없으면 배열 넷이 범위를 넘어 그 자리에서 터진다.
	_open()
	var dp_ok := true
	var dp_txt := ""
	for c in [[0, 0], [1, 0], [0, 100], [1, 60], [42, 41], [42, 53],
			[42, 84], [42, 126], [42, 9223372036854775807], [1, -5]]:
		g.target = int(c[0])
		g.total = int(c[1])
		var dv: int = g._brk_deep_tier()
		if dv < 0 or dv > 3:
			dp_ok = false
		dp_txt += "목표%d·총점%d→%d  " % [int(c[0]), int(c[1]), dv]
	_ok("깊이 자가 언제나 0~3 안", dp_ok, dp_txt)
	#  문턱이 실측 버킷 경계 그대로인가 — 표를 고치면 여기서 걸린다.
	g.target = 100
	var step_ok := true
	var step_txt := ""
	for c2 in [[99, 0], [124, 0], [125, 1], [199, 1], [200, 2], [299, 2],
			[300, 3], [1089, 3]]:
		g.total = int(c2[0])
		var dv2: int = g._brk_deep_tier()
		if dv2 != int(c2[1]):
			step_ok = false
		step_txt += "x%.2f→%d " % [float(c2[0]) / 100.0, dv2]
	_ok("문턱 셋이 x1.25 · x2.00 · x3.00", step_ok, step_txt)
	#  던지기가 실제로 3단에서 도는 것을 적는다 — ①③⑤⑥⑦⑪⑫⑭⑯ 이
	#  전부 3단에서 초록인 것이 우연이 아님을 여기서 못 박는다.
	_open()
	var d3 := _throw()
	_ok("이 도구의 던지기는 3단에서 돈다", int(d3.deep) == 3,
			"단 %d — 목표 1 에 총점이 얹히니 자가 상한에 붙는다" % int(d3.deep))

	# ── ㉒ 깊이가 소리 **알 수**를 안 바꾼다 ─────────────────
	#  pit 는 음만 민다. 알 수는 층의 것이다(삐걱 = 단 수 · 한방+톡 = row[3]).
	var dsnd_ok := true
	var dsnd_txt := ""
	for t in 4:
		for tier in 3:
			_open()
			g.leg_no = [1, 2, 3][tier]
			g.motion_off = true          # 조각 없이 금과 소리만 끝까지 본다
			var sr := _throw(false, 900, t)
			var want_c: int = int(sr.stage)
			var want_s: int = int(g._brk_row().snd)
			if int(sr.crack) != want_c or int(sr.brk) + int(sr.snd) != want_s:
				dsnd_ok = false
				dsnd_txt += "[단%d 층%d 삐걱%d/%d · 한방+톡%d/%d]" % [t, tier,
						int(sr.crack), want_c, int(sr.brk) + int(sr.snd), want_s]
			g.motion_off = false
		dsnd_txt += "단%d ✓ " % t
	_ok("깊이가 소리 알 수를 안 바꾼다 — 음만 민다", dsnd_ok, dsnd_txt)
	#  사다리가 안 뒤집힌다 — 작은 3단이 큰 0단보다, 큰 3단이 보스 0단보다 높다.
	var pit: Array = g.BRKDEEP.pit
	var lad_ok := true
	var lad_txt := ""
	for ti in 2:
		var phi: float = float(g.BRK[["small", "big", "boss"][ti]].pitch) \
				* float(pit[3])
		var lo2: float = float(g.BRK[["small", "big", "boss"][ti + 1]].pitch) \
				* float(pit[0])
		if phi <= lo2:
			lad_ok = false
		lad_txt += "%.3f > %.3f  " % [phi, lo2]
	#  종의 비(tierce 1.2)를 깊이가 어디에도 안 놓는다.
	for i2 in 4:
		for j2 in 4:
			if i2 != j2 and absf(float(pit[i2]) / float(pit[j2]) - 1.2) < 0.05:
				lad_ok = false
				lad_txt += "[종의 비]"
	_ok("층 사다리가 깊이 넷 어디에서도 안 뒤집힌다", lad_ok, lad_txt)

	# ── ㉓ 깊이가 금을 험하게 하되 테 밖으로 못 민다 ─────────
	#  ⚠ **앞 자는 「톱니가 안쪽으로만 벌어진다」였고, 그 톱니(BRKDEEP.jag)가
	#  죽었다.** 그물에서는 테 호가 곧 **면의 모서리**라 그것을 밀면 조각이
	#  같이 밀려 ⑲ 가 그 자리에서 빨개진다. 자를 지우지 않고 **뜻을 옮긴다**:
	#  그 자가 지키려던 것은 「깊이가 실루엣을 만지면 안 된다 · 그러면서도
	#  실제로 험해져야 한다」 둘이고, 새 모형에서 그 둘을 더 곧게 잰다.
	#    ⓐ 어느 단에서도 금이 판 테 **밖으로 한 픽셀도** 안 나간다
	#       — 멈춘 곁가지 끝점까지 전부 훑는다
	#    ⓑ 깊이가 오를수록 실제로 험해진다 — 마디 수가 **단조로** 는다
	#    ⓒ 면의 꼭짓점이 네 단에서 글자 그대로 같다(깊이가 기하를 안 만진다)
	#  ⚠ **수식을 손으로 베끼지 않는다.** 이 자가 바로 「없어진 수식을 재며
	#  초록이 된」 전례다(2026-09-25, 옛 주석). 게임이 실제로 세운
	#  `brk_web` 을 통째로 훑는다 — 굽는 자가 바뀌면 재는 자가 반드시 같이
	#  바뀐다.
	var jag_ok := true
	var jag_txt := ""
	for id2 in ["", "pizz", "clok", "dnut", "aimb", "arst"]:
		_open()
		_board(id2)
		for tier2 in 3:
			var rim: float = g._board_rim(g._theme_ring_w(g._board_theme()))
			var segs := []
			var vkey := []
			var far := 0.0
			for t in 4:
				g._brk_arm(tier2, t)
				#  금 마디의 **양 끝점을 전부** 훑는다 — 멈춘 곁가지 포함.
				for sg in g.brk_web:
					far = maxf(far, (sg.a as Vector2).length())
					far = maxf(far, (sg.b as Vector2).length())
				segs.append((g.brk_web as Array).size())
				#  면의 꼭짓점 지문
				var vs := ""
				for f in g.brk_facets:
					for q in f.pts:
						vs += "%.3f,%.3f;" % [(q as Vector2).x, (q as Vector2).y]
				vkey.append(vs.md5_text())
				g._brk_skip()
			if far > rim + 0.01:
				jag_ok = false
				jag_txt += "[%s 층%d 금 %.2f > 테 %.2f]" % [id2, tier2, far, rim]
			#  ⓑ 마디 수가 단조로 는다(멈춘 곁가지 0→2→4→6)
			for t2 in 3:
				if int(segs[t2 + 1]) < int(segs[t2]):
					jag_ok = false
					jag_txt += "[%s 층%d 마디 %d → %d]" % [id2, tier2,
							int(segs[t2]), int(segs[t2 + 1])]
			if int(segs[3]) <= int(segs[0]):
				jag_ok = false
				jag_txt += "[%s 층%d 3단이 안 험해진다 %d/%d]" % [id2, tier2,
						int(segs[0]), int(segs[3])]
			#  ⓒ 면이 네 단에서 한 점도 안 바뀐다
			for t3 in 3:
				if String(vkey[t3 + 1]) != String(vkey[0]):
					jag_ok = false
					jag_txt += "[%s 층%d 단%d 에서 면이 바뀌었다]" % [id2,
							tier2, t3 + 1]
			jag_txt += "%s%d 금%.0f/테%.0f·마디%d→%d " % [
					id2 if id2 != "" else "기본", tier2, far, rim,
					int(segs[0]), int(segs[3])]
	_ok("깊이가 금을 험하게 하되 테 밖으로 못 민다", jag_ok, jag_txt)

	# ── ㉙ 금이 **맞은 자리**에서 뻗는다 (2026-09-25) ────────
	#  사용자: 「시작화면 같이 유리같이 깨져야지」. 유리가 유리인 것은
	#  **한 점에서 갈라지기** 때문이고, 그 점은 마지막 다트가 꽂힌 자리다.
	#  이 자가 사용자의 말을 글자 그대로 잰다.
	#    ⓐ 모든 살의 뿌리가 구덩이 둘레(PIT)에 붙어 있다
	#    ⓑ 자루가 있으면 맞은 자리가 **마지막** 자루다
	#    ⓒ 자루가 없고 꽂힌 칸이 있으면 그 칸·띠의 한가운데다
	#    ⓓ 둘 다 없으면(개발자 다시 보기) 씨에서 뜨고, 같은 판이면 언제나
	#       같은 자리다 — 판마다는 다르다
	#    ⓔ 한 번 굳은 뒤 연출이 끝날 때까지 **한 비트도** 안 바뀐다.
	#       프레임마다 다시 읽으면 무늬가 깜빡인다(EGG 가 세운 씨 계약의
	#       본디 뜻이 이것이다)
	#    ⓕ 도넛에서 구멍 입술 밖이다 — 안이면 살이 한 점에 모여 **흰
	#       별표**가 박힌다(_brk_crack_draw 가 밟았던 함정)
	var hit_ok := true
	var hit_txt := ""
	var pitr: float = float(g.BRKWEB.pit)
	for id3 in ["", "dnut", "pizz"]:
		_open()
		_board(id3)
		#  ⓑ 마지막 자루
		g.darts = [
			{"p": g.BC + Vector2(-g.R * 0.30, g.R * 0.20), "id": "std", "rot": 0.0},
			{"p": g.BC + Vector2(g.R * 0.55, -g.R * 0.44), "id": "std", "rot": 0.0},
		]
		g._brk_arm(2)
		var want: Vector2 = (g.darts[1].p as Vector2) - g.BC
		if g.brk_hit.distance_to(want) > 0.01:
			hit_ok = false
			hit_txt += "[%s 마지막 자루가 아니다]" % id3
		#  ⓐ 살의 뿌리가 전부 구덩이 둘레
		for sp2 in g.brk_spokes:
			var root: Vector2 = (sp2.pts as Array)[0]
			if absf(root.distance_to(g.brk_hit) - pitr) > 0.01:
				hit_ok = false
				hit_txt += "[%s 뿌리 %.2f != %.2f]" % [id3,
						root.distance_to(g.brk_hit), pitr]
				break
		#  ⓕ 도넛 구멍 입술 밖
		if g._board_theme() == "donut" \
				and g.brk_hit.length() < g.R * float(g.DONUTART.hole):
			hit_ok = false
			hit_txt += "[도넛 구멍 안 %.1f]" % g.brk_hit.length()
		#  ⓔ 연출이 끝날 때까지 한 비트도 안 바뀐다
		var frozen: Vector2 = g.brk_hit
		g._brk_fire()
		for _f in 40:
			g._brk_tick(DT)
			if g.brk_hit != frozen:
				hit_ok = false
				hit_txt += "[%s 무늬가 깜빡인다]" % id3
				break
		g._brk_skip()
		#  ⓒ 자루가 없고 꽂힌 칸이 있으면 그 칸·띠의 한가운데
		g.darts = []
		g.hit_idx = 3
		g.hit_r0 = 0.20
		g.hit_r1 = 0.40
		g._brk_arm(2)
		var wa: float = 3.0 * g._sec_w()
		var wp: Vector2 = Vector2(sin(wa), -cos(wa)) * g.R * 0.30
		if g.brk_hit.distance_to(wp) > 0.01:
			hit_ok = false
			hit_txt += "[%s 꽂힌 칸이 아니다]" % id3
		g._brk_skip()
		#  ⓓ 둘 다 없으면 씨에서 — 같은 판은 같고, 판마다 다르다
		g.hit_idx = -1
		g.leg_no = 4
		g._brk_arm(2)
		var h4: Vector2 = g.brk_hit
		g._brk_skip()
		g._brk_arm(2)
		var h4b: Vector2 = g.brk_hit
		g._brk_skip()
		g.leg_no = 5
		g._brk_arm(2)
		var h5: Vector2 = g.brk_hit
		g._brk_skip()
		if h4 != h4b or h4 == h5:
			hit_ok = false
			hit_txt += "[%s 씨 자리 %s/%s/%s]" % [id3, h4, h4b, h5]
		hit_txt += "%s ✓ " % (id3 if id3 != "" else "기본")
	_ok("금이 맞은 자리에서 뻗는다", hit_ok, hit_txt)

	# ── ㉚ 도안 한 프레임의 셈이 자 안이다 (2026-09-25) ──────
	#  ⚠ **자가 없는 축이었다.** ③(70프레임)과 ⑳(70/54/4/29)은 프레임
	#  **수**를 재지 한 프레임의 벽시계를 안 잰다. `_brk_arm` 은 프레임 0 에
	#  그물을 통째로 짓는다 — 실측 3.6~7.1ms(60fps 예산 16.67ms)다. 그
	#  자리는 hitstop 을 qt 에서 뺀 바로 뒤라 여유가 있지만, **재는 자가
	#  없으면 나중에 눈치 못 챈 채 는다.**
	#  벽시계로 걸면 느린 기계에서 제 손으로 빨개지므로 **셈의 크기**를
	#  못 박는다 — 결정적이고, 실제로 시간을 미는 것이 이 넷이다.
	var bud_ok := true
	var bud_txt := ""
	for id4 in ["", "pizz", "dnut", "aimb", "clok", "arst"]:
		_open()
		_board(id4)
		var wf := 0
		var wv := 0
		var ws := 0
		for t4 in 3:
			for sd4 in range(1, 13):
				g._brk_skip()
				g.leg_no = sd4 * 3 + t4
				g.darts = [{"p": g.BC + Vector2(
						sin(float(sd4)) * g.R * 0.86,
						-cos(float(sd4)) * g.R * 0.86), "id": "std", "rot": 0.0}]
				g._brk_arm(t4, 3)
				wf = maxi(wf, (g.brk_facets as Array).size())
				ws = maxi(ws, (g.brk_web as Array).size())
				var vn := 0
				for f in g.brk_facets:
					vn += f.pts.size()
				wv = maxi(wv, vn)
				g._brk_skip()
		if wf > int(g.BRK.cap):
			bud_ok = false
			bud_txt += "[%s 면 %d > 상한 %d]" % [id4, wf, int(g.BRK.cap)]
		if wv > 3000:
			bud_ok = false
			bud_txt += "[%s 정점 %d > 3000]" % [id4, wv]
		if ws > 320:
			bud_ok = false
			bud_txt += "[%s 마디 %d > 320]" % [id4, ws]
		bud_txt += "%s 면%d·정점%d·마디%d  " % [
				id4 if id4 != "" else "기본", wf, wv, ws]
	_ok("도안 한 프레임의 셈이 자 안이다", bud_ok, bud_txt)

	# ══ 정산 출처 짚기 — 걸음에 매인 빛 ═══════════════════════
	#  사용자: 「점수 정산할 때 효과가 어디서 일어난 건지 좀 더 잘 알려줄 수
	#  있으면 좋겠어」(2026-09-25). 한 판에 4~8번 · 24판 런에 100~190번 나는
	#  신호라 **안 물리는 것**이 전부다. 창이 언제나 걸음의 78%(card_jrate)인
	#  것을 수로 못 박는다. 무엇을 짚는가는 settle_probe 가 잰다.

	# ── ㉔ 출처 빛이 걸음 안에서 죽는다 ─────────────────────
	#  창이 걸음의 78%(card_jrate)라 **구조적으로** 다음 걸음을 못 덮는다.
	#  첫 걸음만 chip(빛이 선다)으로 세우고 뒤를 miss 로 채워, 걸음이 갈리는
	#  프레임에 빛이 이미 0 인지 본다. 큐를 길게 세워 _pace() 가 걸음을
	#  누르는 자리도 같이 잰다.
	#  ⚠ **눌린 박자(beat 0.015)에서는 한 프레임 남는다.** card_jrate 의
	#  바닥 maxf(qt × 0.78, 0.02)가 걸음(0.015초)보다 길어지기 때문인데,
	#  **카드 시계 여섯이 이미 같은 바닥을 같은 이유로 쓴다** — 그래서
	#  자를 「chip_j 보다 늦게 안 죽는다」로 적는다. 새 상수가 0개라는 것이
	#  곧 이 자다. 사람이 보는 박자(0.34)에서는 둘 다 걸음 안에서 죽는다.
	#  2026-09-25
	var win_ok := true
	var win_txt := ""
	for c3 in [[0.34, 1, 1.0], [0.34, 20, 1.0], [0.015, 1, 1.0],
			[0.34, 1, 2.5]]:
		_open()
		g.state = g.S.RESOLVE
		g.beat = float(c3[0])
		g.fast_lock = float(c3[2]) > 1.0
		g.fast_mul = float(c3[2])
		#  ⚠ **_pace() 는 큐 길이가 아니라 settle_n 을 읽는다**(_land 가
		#  세운다). 큐만 길게 세우면 걸음이 하나도 안 눌려 「눌린 박자」
		#  자리가 자를 못 댄다 — 여기서 직접 세운다.
		g.settle_n = int(c3[1])
		g.queue = [{"k": "chip", "v": 7, "mx": 0}]
		#  꼬리는 **적어도 하나** — 걸음이 갈리는 프레임이 있어야 잰다.
		for _q in maxi(int(c3[1]) - 1, 1):
			g.queue.append({"k": "miss"})       # 빛을 안 세우는 걸음으로 채운다
		g.cur_chip = 0
		var rest: int = (g.queue as Array).size() - 1
		g._next_step()                          # 첫 걸음 — _pace() 가 큐 전체를 본다
		var lit_f := 0
		var jf := 0
		var bnd := -1
		for f2 in 600:
			g._process(DT)
			if (g.queue as Array).size() < rest:
				bnd = f2 + 1
				break
			if g.src_t > 0.0:
				lit_f = f2 + 1
			if g.chip_j > 0.0:
				jf = f2 + 1
		if bnd < 0 or lit_f > jf:
			win_ok = false
			win_txt += "[beat %.3f 빛 %d > 카드 %d]" % [float(c3[0]), lit_f, jf]
		if float(c3[0]) > 0.1 and lit_f >= bnd:
			win_ok = false
			win_txt += "[beat %.3f 빛 %d >= 걸음 %d]" % [float(c3[0]), lit_f, bnd]
		win_txt += "beat %.3f·큐%d·%.1f배 → 걸음 %d · 빛 %d · 카드 %d  " % [
				float(c3[0]), int(c3[1]), float(c3[2]), bnd, lit_f, jf]
	g.beat = beat
	g.fast_lock = false
	g.fast_mul = 1.0
	_ok("출처 빛이 카드 시계와 같은 창을 쓴다 — 다음 걸음을 못 덮는다",
			win_ok, win_txt)

	# ── ㉕ 출처 짚기가 글자를 한 자도 안 더한다 ─────────────
	_open()
	g.state = g.S.RESOLVE
	(g.pops as Array).clear()
	g.cur_chip = 0
	g.cur_mult = 0
	g.queue = [{"k": "chip", "v": 40, "mx": 1}, {"k": "mult", "v": 3, "mx": 0}]
	g._next_step()
	g._next_step()
	_ok("출처 짚기가 팝업을 한 개도 안 더한다", (g.pops as Array).is_empty(),
			"%d개 — pop() 을 한 번도 안 부른다" % (g.pops as Array).size())

	# ── ㉖ 모션 끄기에서 출처가 **하나도 안 죽는다** ─────────
	#  발라트로의 모션 감소가 조커 발동 애니를 꺼 「이 값이 어디서 왔는가」를
	#  통째로 잃는 그 자리를 여기서 막는다. 넷 다 알파와 색이라 산다.
	_open()
	g.motion_off = true
	g.state = g.S.RESOLVE
	var mo_ok := true
	var mo_txt := ""
	for c4 in [["chip", false], ["mult", true]]:
		g.src_t = 0.0
		g.cur_chip = 0
		g.cur_mult = 0
		g.queue = [{"k": String(c4[0]), "v": 9, "mx": 1}]
		g._next_step()
		if not (g.src_t > 0.0 and g.src_ring == bool(c4[1]) and g.src_mix):
			mo_ok = false
		mo_txt += "%s 빛%.2f·고리%s·얹힘%s  " % [String(c4[0]), g.src_t,
				g.src_ring, g.src_mix]
	g.motion_off = false
	_ok("모션 끄기에서 출처가 하나도 안 죽는다", mo_ok, mo_txt)

	print("\n통과 %d · 실패 %d" % [okn, fail])
	quit(1 if fail > 0 else 0)
