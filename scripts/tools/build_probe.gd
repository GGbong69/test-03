extends SceneTree

const GameData = preload("res://scripts/data.gd")

# ══════════════════════════════════════════════════════════
#  빌드 상한 — 사람이 고른 랙은 곡선을 얼마나 넘어서는가
#
#  실행:  godot --path . --headless --quit-after 900000 \
#             -s scripts/tools/build_probe.gd -- autoplay runs=8 rack=j024,j046,j006
#
#  소크의 매수자는 **무작위**다. 매대 넷 중 하나를 눈 감고 집는다. 그래서
#  소크가 재는 것은 "사람이 짜는 빌드" 가 아니라 "잡동사니 빌드" 다.
#  사람은 골라 산다 — 그 차이가 얼마인지를 여기서 잰다.
#
#  랙을 미리 채워 두고 같은 오토플레이를 돌린다. 상점에서 더 사지 않게
#  랙을 꽉 채운 채로 시작하는 것과 같은 효과다(칸이 차면 _buy_block 이 막는다).
# ══════════════════════════════════════════════════════════

var g: Node = null
var frames := 0
var runs := 0
var RUNS := 8
var RACK: PackedStringArray = PackedStringArray(["j024", "j046", "j006"])
const FRAME_CAP := 400000

var last_round := 1
var st := {}
var _used := 0
# 라운드에서 실제로 낸 총점이 아니라 **첫 발이 낸 점수**를 따로 본다 —
# 라운드는 목표를 넘기는 순간 끝나므로 총점은 언제나 목표에 붙어 있다.
var first_gain := 0
var got_first := false


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20260826)
	for a in OS.get_cmdline_user_args():
		var t := String(a)
		if t.begins_with("runs="):
			RUNS = maxi(1, int(t.substr(5)))
		elif t.begins_with("rack="):
			RACK = t.substr(5).split(",")
	print("랙: %s · 런 %d회" % [", ".join(RACK), RUNS])


func _fill_rack() -> void:
	g.owned.clear()
	for id in RACK:
		for it in GameData.items():
			if String(it.id) != String(id):
				continue
			var c: Dictionary = it.duplicate()
			c.gs = 0
			c.bought = 0
			g.owned.append(c)
			break
	g._panel_reset()


func _row(n: int) -> Dictionary:
	if not st.has(n):
		st[n] = {"seen": 0, "pass": 0, "used": 0.0, "one": 0.0, "gs": 0.0}
	return st[n]


func _finish() -> void:
	print("\n판  목표      통과율  평균다트  여유    첫발점수    목표대비   성장치합")
	for n in range(1, GameData.rounds_n() + 1):
		if not st.has(n):
			continue
		var r: Dictionary = st[n]
		var sn := float(r.seen)
		var pn := maxf(float(r["pass"]), 1.0)
		var du: float = float(r.used) / pn
		var one: float = float(r.one) / sn
		var tg := float(GameData.target_of(n))
		print("%2d %8d   %4.0f%%  %5.1f  x%5.2f  %11.0f  x%9.1f  %7.1f"
				% [n, GameData.target_of(n), 100.0 * float(r["pass"]) / maxf(sn, 1.0),
				du, float(GameData.darts_of(n)) / maxf(du, 0.5), one, one / tg,
				float(r.gs) / sn])
	quit(0)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 2:
		g.beat = 0.015
		g.gauge_speed = 8.0
		g.confirm_hold = 0.0
		_fill_rack()
	if frames > FRAME_CAP:
		print("!! 프레임 상한")
		_finish()
		return true
	if frames == 3:
		_row(1).seen += 1

	var pre: int = g.state
	g.set_process(false)
	g._process(1.0 / 60.0)

	# 그 라운드의 첫 발이 낸 점수 — 여유의 진짜 척도다.
	if pre == g.S.RESOLVE and g.state != g.S.RESOLVE and not got_first:
		if g.last_gain > 0:
			first_gain = g.last_gain
			got_first = true

	if g.round_no != last_round:
		if g.round_no > last_round:
			var r := _row(last_round)
			r["pass"] = int(r["pass"]) + 1
			r.used = float(r.used) + float(_used)
			r.one = float(r.one) + float(first_gain)
			var gs := 0
			for o in g.owned:
				gs += int(o.get("gs", 0))
			r.gs = float(r.gs) + float(gs)
		_row(g.round_no).seen += 1
		last_round = g.round_no
		first_gain = 0
		got_first = false
	if g.round_darts > 0 and g.darts_left <= g.round_darts:
		_used = g.round_darts - g.darts_left

	if g.state == g.S.OVER:
		runs += 1
		print("  … 런 %d 끝 (판 %d · 완주 %s)" % [runs, g.round_no, str(g.won)])
		if runs >= RUNS:
			_finish()
			return true
		last_round = 1
		first_gain = 0
		got_first = false
		g._new_run()
		_fill_rack()
		_row(1).seen += 1
	return false
