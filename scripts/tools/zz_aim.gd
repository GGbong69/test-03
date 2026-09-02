extends SceneTree
const GameData = preload("res://scripts/data.gd")

func tri(t: float) -> float:
	var f := fmod(t, 1.0)
	return f * 2.0 if f < 0.5 else (1.0 - f) * 2.0

func _initialize() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	g._new_run(); g._start_round()
	seed(77)
	var SW: float = g.SWING
	var SP := GameData.tune("gauge_speed")
	print("SWING=%.0f  board_r=%.0f  gauge_speed=%.2f" % [SW, g.R, SP])
	# 한 축이 -SW → +SW 를 지나는 데 걸리는 시간 = 0.5/SP 초. 그동안 2*SW px.
	var pxs := 2.0 * SW / (0.5 / SP)
	print("조준점 속도 = %.0f px/s → 타이밍 오차 1ms 당 %.2f px\n" % [pxs, pxs / 1000.0])

	# 사람: 두 축을 각각 "원하는 위치" 에서 잠근다. 실수는 **타이밍**이다.
	# 겨냥할 자리를 여러 개 놓고 잰다.
	var targets := {"불(중심)": Vector2(0,0), "트리플20": Vector2(-9,-64)}
	print("%-10s %-8s %8s %8s %8s %8s" % ["겨냥", "타이밍σ", "px σ", "한 발", "6발", "빗나감"])
	for tname in targets:
		var tgt: Vector2 = targets[tname]
		for ms in [15.0, 25.0, 40.0, 60.0, 90.0]:
			var M := 120000
			var s := 0.0
			var miss := 0
			var out := 0
			for i in M:
				# 사람이 노리는 gt. tri 가 그 값을 내는 지점 하나를 고른다.
				var fy := clampf((tgt.y + SW) / (2.0*SW), 0.0, 1.0)
				var fx := clampf((tgt.x + SW) / (2.0*SW), 0.0, 1.0)
				# tri 의 상승 구간에서 잠근다: gt = f/2
				var gy: float = fy * 0.5 + randfn(0.0, float(ms)/1000.0) * SP
				var gx: float = fx * 0.5 + randfn(0.0, float(ms)/1000.0) * SP
				var p: Vector2 = g.BC + Vector2(
						lerpf(-SW, SW, tri(gx)), lerpf(-SW, SW, tri(gy)))
				var h: Dictionary = g.hit_info(p)
				if int(h.mult) == 0:
					miss += 1
				s += float(h.base) * float(h.mult)
			var sig: float = pxs * float(ms) / 1000.0
			print("%-10s %5.0fms %8.1f %8.2f %8.0f %7.1f%%"
					% [tname, ms, sig, s/float(M), 6.0*s/float(M), 100.0*float(miss)/float(M)])
	# 기준선: 오토플레이
	var M2 := 300000
	var s2 := 0.0
	for i in M2:
		var a := randf() * TAU
		var p: Vector2 = g.BC + Vector2(cos(a), sin(a)) * sqrt(randf()) * g.R * 0.95
		var h: Dictionary = g.hit_info(p)
		s2 += float(h.base) * float(h.mult)
	print("\n%-10s %-8s %8s %8.2f %8.0f %7.1f%%" % ["오토플레이","(조준없음)","-", s2/float(M2), 6.0*s2/float(M2), 0.0])
	# 무작위 위상(조준을 아예 못 맞추는 사람)
	var s3 := 0.0
	var m3 := 0
	for i in M2:
		var p: Vector2 = g.BC + Vector2(lerpf(-SW,SW,tri(randf())), lerpf(-SW,SW,tri(randf())))
		var h: Dictionary = g.hit_info(p)
		if int(h.mult) == 0: m3 += 1
		s3 += float(h.base) * float(h.mult)
	print("%-10s %-8s %8s %8.2f %8.0f %7.1f%%" % ["무작위위상","(초보)","-", s3/float(M2), 6.0*s3/float(M2), 100.0*float(m3)/float(M2)])
	quit(0)
