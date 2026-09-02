extends SceneTree

const GameData = preload("res://scripts/data.gd")

# ══════════════════════════════════════════════════════════
#  성장 축 측정 — 목표 곡선 말고 무엇이 점수를 미는가
#
#  실행:  godot --path . --headless --quit-after 900000 \
#             -s scripts/tools/axis_probe.gd -- autoplay runs=24
#
#  curve_probe 는 "어디서 죽는가" 를 잰다. 이것은 "무엇을 쥐고 죽는가" 를
#  잰다. 라운드가 넘어갈 때마다 랙·트랙·개조·자루·설비를 통째로 찍어 두고,
#  판마다 실제로 난 점수와 같이 낸다.
#
#  내는 것
#    · 판별 평균: 목표 · 실제 낸 점수 · 쓴 다트 · 여유배율
#    · 판별 평균 보유: 스티커 수 · 트랙 레벨 합 · 개조 수 · 설비 수 · 비표준 자루
#    · 각 축이 상한(스티커 5칸 · 트랙 40레벨 · 개조 8 · 설비 7)에 닿는 판
#    · 라운드 점수를 축별로 쪼갠 몫 — 판 · 트랙 · 스티커
# ══════════════════════════════════════════════════════════

var g: Node = null
var frames := 0
var runs := 0
var RUNS := 16
const FRAME_CAP := 3000000

var last_round := 1
# 판 번호 → 누적 통계
var st := {}
# 이번 라운드에 축별로 얼마씩 실렸는가 (정산 큐를 뜯어 센다)
var acc := {}


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20260826)
	for a in OS.get_cmdline_user_args():
		var t := String(a)
		if String(GameData.stake_row(t).get("id", "")) == t:
			GameData.stake = t
		elif t.begins_with("runs="):
			RUNS = maxi(1, int(t.substr(5)))
	print("리그: %s · 런 %d회" % [GameData.stake if GameData.stake != "" else "흰색(기본)", RUNS])


func _row(n: int) -> Dictionary:
	if not st.has(n):
		st[n] = {"seen": 0, "pass": 0, "used": 0.0, "score": 0.0,
				"items": 0.0, "trk": 0.0, "mods": 0.0, "vou": 0.0, "dart": 0.0,
				"xm": 0.0, "cons": 0.0, "gold": 0.0,
				"c_board": 0.0, "c_trk": 0.0, "c_item": 0.0}
	return st[n]


# 라운드에 들어설 때 지금 쥔 것을 찍는다.
func _snap(n: int) -> void:
	var r := _row(n)
	r.seen += 1
	r.items += float(g.owned.size())
	var tl := 0
	for k in g.track_lv:
		tl += int(g.track_lv[k])
	r.trk += float(tl)
	r.mods += float(g.mods_own.size())
	r.vou += float(GameData.vouchers_own.size())
	var nonstd := 0
	for d in g.magazine:
		if String(d.get("id", "std")) != "std":
			nonstd += 1
	r.dart += float(nonstd)
	# 랙의 곱연산 총량 — xmult 만 곱해 둔다. 빌드가 얼마나 폭발했는지의 척도다.
	var xm := 1.0
	for o in g.owned:
		if String(o.get("k", "")) == "xmult":
			xm *= float(o.get("v", 1))
	r.xm += xm
	r.cons += float(g.cons.size())
	r.gold += float(g.gold)


func _finish() -> void:
	print("\n판  A  종류      목표    통과율  평균다트  여유   낸점수   스티커 트랙 개조 설비 자루  x곱")
	for n in range(1, GameData.rounds_n() + 1):
		if not st.has(n):
			continue
		var r: Dictionary = st[n]
		var sn := float(r.seen)
		var pn := float(r["pass"])
		var du: float = float(r.used) / maxf(pn, 1.0)
		print("%2d %2d  %-7s %7d  %5.0f%%  %5.1f  x%.2f  %8.0f   %4.1f  %4.1f %4.1f %4.1f %4.1f  x%.1f"
				% [n, GameData.ante_of(n), GameData.blind_name(n),
				GameData.target_of(n), 100.0 * pn / maxf(sn, 1.0), du,
				float(GameData.darts_of(n)) / maxf(du, 0.5),
				float(r.score) / maxf(pn, 1.0),
				float(r.items) / sn, float(r.trk) / sn, float(r.mods) / sn,
				float(r.vou) / sn, float(r.dart) / sn, float(r.xm) / sn])

	print("\n축별 점수 몫 (판이 준 칩 · 트랙이 얹은 칩/배수 · 스티커가 얹은 것)")
	print("판   판몫%   트랙몫%   스티커몫%")
	for n in range(1, GameData.rounds_n() + 1):
		if not st.has(n):
			continue
		var r: Dictionary = st[n]
		var tot: float = float(r.c_board) + float(r.c_trk) + float(r.c_item)
		if tot <= 0.0:
			continue
		print("%2d  %5.1f%%  %6.1f%%  %8.1f%%"
				% [n, 100.0 * float(r.c_board) / tot, 100.0 * float(r.c_trk) / tot,
				100.0 * float(r.c_item) / tot])
	quit(0)


func _process(_d: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		print("!! 프레임 상한")
		_finish()
		return true
	if frames == 1:
		_snap(1)
	if frames == 2:
		# 점수에 안 닿는 값만 민다 — 박자 · 게이지 · 확인 텀.
		g.beat = 0.015
		g.gauge_speed = 8.0
		g.confirm_hold = 0.0

	var pre_state: int = g.state
	g.set_process(false)
	g._process(1.0 / 60.0)

	# 정산 큐를 뜯어 축을 나눈다 — 큐가 만들어진 그 프레임에 읽는다.
	if pre_state != g.S.RESOLVE and g.state == g.S.RESOLVE:
		_split_queue()

	if g.round_no != last_round:
		if g.round_no > last_round:
			var r := _row(last_round)
			r["pass"] = int(r["pass"]) + 1
			r.used = float(r.used) + float(_used)
			r.score = float(r.score) + float(_rscore)
		_snap(g.round_no)
		last_round = g.round_no
		_rscore = 0.0
	if g.round_darts > 0 and g.darts_left <= g.round_darts:
		_used = g.round_darts - g.darts_left
	_rscore = float(g.total)

	if g.state == g.S.OVER:
		if g.won:
			var r2 := _row(g.round_no)
			r2["pass"] = int(r2["pass"]) + 1
		runs += 1
		print("  … 런 %d 끝 (판 %d)" % [runs, g.round_no])
		if runs >= RUNS:
			_finish()
			return true
		last_round = 1
		_rscore = 0.0
		g._new_run()
		_snap(1)
	return false


var _used := 0
var _rscore := 0.0


# 한 발의 정산 큐를 축별로 쪼갠다.
#   판몫    = 칸 값(트랙 보정 전) x 판 배수
#   트랙몫  = 트랙이 얹은 칩/배수가 더한 만큼
#   스티커몫 = 나머지 전부
# 큐는 이미 트랙이 얹힌 값을 들고 있으므로, 트랙 보너스를 다시 계산해서 뺀다.
func _split_queue() -> void:
	var chip := 0
	var mult := 0
	for q in g.queue:
		match String(q.get("k", "")):
			"chip", "pierce":
				chip += int(q.get("v", 0))
			"mult":
				mult = int(q.get("v", 0))
	var base_chip := chip
	var base_mult := maxi(mult, 1)
	# 트랙을 걷어낸 판몫
	var info: Dictionary = g.hit_info(g.aim)
	var tlv := int(g.track_lv.get(int(info.get("track", 0)), 0))
	var tb := {"s": 0, "m": 0}
	if tlv > 0:
		tb = GameData.track_bonus(int(info.get("track", 0)), tlv)
	var raw_chip: int = maxi(base_chip - int(tb.s), 0)
	var raw_mult: int = maxi(base_mult - int(tb.m), 1)
	var board := raw_chip * raw_mult
	var withtrk := base_chip * base_mult
	# 스티커까지 얹은 최종
	var c := base_chip
	var m := base_mult
	for q in g.queue:
		if String(q.get("k", "")) != "item":
			continue
		match String(q.get("kind", "")):
			"chip":
				c += int(q.get("v", 0))
			"mult", "mult_streak", "mult_rand":
				m += int(q.get("v", 0))
			"xmult":
				m *= int(q.get("v", 0))
	var full := c * m
	var r := _row(g.round_no)
	r.c_board = float(r.c_board) + float(board)
	r.c_trk = float(r.c_trk) + float(maxi(withtrk - board, 0))
	r.c_item = float(r.c_item) + float(maxi(full - withtrk, 0))
