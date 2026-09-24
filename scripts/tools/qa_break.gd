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
func _board(id: String) -> void:
	g.mods_own = [] if id == "" else [id]
	g._board_bake()
	g._start_leg()
	g._swap_skip()


#  한 발을 던져 목표를 넘기고, **돌파 프레임부터 정산까지**를 프레임으로
#  적는다. kill 이 참이면 매 프레임 _brk_skip() 을 불러 연출을 아예 못 살게
#  한다 — 「연출이 더한 프레임 0」의 A/B 짝이다.
func _throw(kill := false, cap := 900) -> Dictionary:
	var o := {"arm": -1, "fire": -1, "gone": -1, "clear": -1,
			"snd": 0, "shards": 0, "bits": 0, "pops": 0,
			"shake": -1.0, "qt": -1.0, "hitstop": -1.0,
			"stage": 0, "dart_gone": -1, "swap": false, "turn": false}
	g.target = 1
	g.total = 0
	g.state = g.S.CONFIRM
	g.confirm_t = 99.0
	g.aim = g.BC
	var prev: int = g.sfx_next
	var pool: int = maxi((g.sfx_pool as Array).size(), 1)
	for f in cap:
		g._process(DT)
		var now: int = g.sfx_next
		var dn: int = posmod(now - prev, pool)
		prev = now
		#  ⚠ **정산 프레임은 안 센다.** 그 프레임에 _settle_clear 가
		#  leg_clear 를 울리는데 그것은 깨짐의 소리가 아니다 — 세면 층마다
		#  꼭 하나씩 더 잡혀 표와 영영 안 맞는다.
		#  도안이 선 프레임도 안 센다(target_hit 이 거기서 운다).
		if o.arm >= 0 and o.clear < 0 and g.state != g.S.CLEAR:
			o.snd += dn
		if g.brk_live and o.arm < 0:
			o.arm = f
			o.shake = g.shake
			o.qt = g.qt
			o.hitstop = g.hitstop
			o.pops = (g.pops as Array).size()
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

	# ── ⑧ 테마 — 박아 둔 20 이 한 곳도 없다 ─────────────────
	var th_ok := true
	var th_txt := ""
	for id in ["", "pizz", "clok", "dnut", "aimb", "arst"]:
		_open()
		_board(id)
		var n: int = g._sec_n()
		var want_bands := _bands().size()
		var line := ""
		for t in 3:
			g._brk_arm(t)
			var wedge: int = g.brk_w
			var rings: int = (g.brk_rings as Array).size()
			g._brk_fire()
			var sh: int = (g.brk_shards as Array).size()
			var bull: int = 1 if g.rt_bull_o > 0.0 else 0
			if n % wedge != 0:
				th_ok = false
				line += "[부채 %d 가 칸 %d 의 약수가 아니다]" % [wedge, n]
			if rings > want_bands:
				th_ok = false
				line += "[겹 %d > 살아 있는 띠 %d]" % [rings, want_bands]
			if sh != wedge * rings + bull:
				th_ok = false
				line += "[조각 %d != %d]" % [sh, wedge * rings + bull]
			if sh > int(g.BRK.cap):
				th_ok = false
				line += "[조각 %d > 상한 %d]" % [sh, int(g.BRK.cap)]
			if (g.brk_bits as Array).size() > int(g.BRK.grit_cap):
				th_ok = false
				line += "[톱밥 초과]"
			#  가장 작은 조각의 안쪽 호. 「1px 외톨이는 물건이 아니라 먼지」
			#  바닥(약 2px)의 위여야 한다.
			var arc: float = g.R * maxf(float(g.brk_rings[0][0]), 0.0) \
					* (TAU / float(n)) * float(n / wedge)
			if g.rt_bull_o > 0.0 and arc < 2.0:
				th_ok = false
				line += "[안쪽 호 %.1fpx]" % arc
			line += "%d/%d·%d " % [wedge, rings, sh]
			g._brk_skip()
		th_txt += "%s(칸%d) %s " % [id if id != "" else "기본", n, line]
	_ok("테마 여섯에서 부채가 칸의 약수 · 겹이 산 띠 안", th_ok, th_txt)

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
	var plain_pair: Array = g._brk_cols_at("", g._board_cols(), 0)
	for th in ["pizza", "clock", "donut", "target"]:
		var p: Array = g._brk_cols_at(th, g._board_cols(), 0)
		if (p[1] as Color).is_equal_approx(plain_pair[1] as Color):
			col_ok = false
		col_txt += "%s %s  " % [th, (p[1] as Color).to_html(false)]
	_ok("테마 넷이 제 물감으로 깨진다", col_ok,
			"기본 %s / %s" % [(plain_pair[1] as Color).to_html(false), col_txt])

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
	for t in 3:
		g._brk_arm(t)
		g._brk_fire()
		var row: Array = g.BRK[["small", "big", "boss"][t]]
		tier_len.append([(g.brk_rings as Array).size(), g.brk_stage,
				(g.brk_bits as Array).size(), int(row[3])])
		tier_txt += "%s 겹%d·단%d·톱밥%d·소리%d  " % [
				["작은", "큰", "보스"][t], (g.brk_rings as Array).size(),
				g.brk_stage, (g.brk_bits as Array).size(), int(row[3])]
		g._brk_skip()
	var ladder_ok: bool = int(tier_len[0][0]) <= int(tier_len[2][0]) \
			and int(tier_len[0][1]) <= int(tier_len[2][1]) \
			and int(tier_len[0][2]) < int(tier_len[2][2]) \
			and int(tier_len[0][3]) < int(tier_len[2][3])
	_ok("층이 겹·단·톱밥·소리로 오른다", ladder_ok, tier_txt)
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
			absf(float(g.BRK.small[4]) / float(g.BRK.big[4]) - 1.2) > 0.05
			and absf(float(g.BRK.big[4]) / float(g.BRK.boss[4]) - 1.2) > 0.05,
			"%.3f · %.3f" % [float(g.BRK.small[4]) / float(g.BRK.big[4]),
					float(g.BRK.big[4]) / float(g.BRK.boss[4])])
	_ok("음이 내려간다 — 등장은 올리고 퇴장은 내린다",
			float(g.BRK.small[4]) > float(g.BRK.big[4])
			and float(g.BRK.big[4]) > float(g.BRK.boss[4]),
			"%.2f → %.2f → %.2f" % [float(g.BRK.small[4]),
					float(g.BRK.big[4]), float(g.BRK.boss[4])])
	var snd_txt := ""
	var snd_ok := true
	for t in 3:
		_open()
		g.leg_no = t + 1          # 작은 1 · 큰 2 · 보스 3
		var r := _throw()
		var row: Array = g.BRK[["small", "big", "boss"][t]]
		snd_txt += "%s %d회(표 %d)  " % [["작은", "큰", "보스"][t],
				int(r.snd), int(row[3])]
		if int(r.snd) != int(row[3]):
			snd_ok = false
	_ok("한 깨짐의 소리가 층대로 1·2·3", snd_ok, snd_txt)
	_ok("한 사건의 소리가 pool 4 밑", int(g.BRK.boss[3]) <= 3,
			"보스 %d개 / sfx_pool %d" % [int(g.BRK.boss[3]),
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
	_ok("빨리 보기에서 꼬리 톡이 0회 — 소리는 board_break 하나",
			int(fr.snd) == 1,
			"%d회 — 안 막으면 정산 프레임에 소리 다섯이라 target_hit 이 끊긴다"
			% int(fr.snd))
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
	_ok("모션 끄기 — 소리는 층대로 그대로 난다", int(mo.snd) == 3,
			"보스 %d회 / 표 3회" % int(mo.snd))
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

	print("\n통과 %d · 실패 %d" % [okn, fail])
	quit(1 if fail > 0 else 0)
