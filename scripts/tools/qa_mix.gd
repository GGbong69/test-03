extends SceneTree

#  소리 섞기 검사(2026-10-21) — 질감 소리만 높이를 흔들고 · ×배수 걸음에 5도 겹.
#  소리는 sfx_pool 자리에 박힌 stream · pitch_scale · volume_db 로 읽는다(qa_land 의 수법).
#
#   godot --path . --headless --script scripts/tools/qa_mix.gd

const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_mix_g.cfg"
	Save.path = "user://_qa_mix.cfg"
	Save.prof_fmt = "user://_qa_mix_%d.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-34s %s" % ["통과" if c else "실패", n, d])


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


#  자리를 넓혀 새로 깐다 — 이번에 난 것만 sfx_next 까지 읽는다.
func _pool() -> void:
	for sp in g.sfx_pool:
		sp.queue_free()
	g.sfx_pool.clear()
	for i in 64:
		var sp := AudioStreamPlayer.new()
		g.add_child(sp)
		g.sfx_pool.append(sp)
	g.sfx_next = 0


#  [이름, 피치, dB] 들.
func _heard() -> Array:
	var out := []
	for i in g.sfx_next:
		var pl: AudioStreamPlayer = g.sfx_pool[i]
		out.append([String(pl.stream.resource_path).get_file().get_basename(),
				pl.pitch_scale, pl.volume_db])
	return out


func _run() -> void:
	print("\n소리 섞기 검사\n")

	# ① 질감 소리만 흔든다 — f 를 받거나 목록 밖이면 고정
	_pool()
	for k in 12:
		g._sfx("dart_pick")
	g._sfx("hit_single")
	g._sfx("dart_fly", g.SFX_BASE * 0.72)
	var h := _heard()
	var lo := 9.0
	var hi := 0.0
	for k in 12:
		lo = minf(lo, float(h[k][1]))
		hi = maxf(hi, float(h[k][1]))
	_ok("① dart_pick 은 ±3% 안에서 흔들린다", lo >= 0.97 and hi <= 1.03 and hi - lo > 0.005,
			"%.3f ~ %.3f" % [lo, hi])
	_ok("① 등급음은 고정", is_equal_approx(float(h[12][1]), 1.0), "%.3f" % float(h[12][1]))
	_ok("① f 를 받으면 그 음 그대로", is_equal_approx(float(h[13][1]), 0.72), "%.3f" % float(h[13][1]))
	var rs: int = g.run_rng.state
	_pool()
	g._sfx("hand_drop")
	_ok("① 흔들기는 판 난수를 안 민다", g.run_rng.state == rs)

	# ② ×배수 걸음만 5도 위(×1.5)에 -9dB 한 겹 · 다른 걸음은 한 소리 · 꼭대기는 옥타브 밑(×0.75)
	g._new_run()
	g.queue_redraw()
	for kind in ["mult", "xmult"]:
		_pool()
		g.queue = [{"k": "item", "kind": kind, "v": 2.0, "i": -1, "lbl": "x"}]
		g.pitch_step = 0
		g._next_step()
		h = _heard().filter(func(e): return e[0] == "settle_item")
		if kind == "mult":
			_ok("② 배수 + 는 한 소리", h.size() == 1 and is_equal_approx(float(h[0][2]), 0.0), "%s" % [h])
		else:
			_ok("② ×배수는 5도 위 -9dB 한 겹", h.size() == 2
					and is_equal_approx(float(h[1][1]), float(h[0][1]) * 1.5)
					and is_equal_approx(float(h[1][2]), -9.0) and is_equal_approx(float(h[0][2]), 0.0),
					"%s" % [h])
	_pool()
	g.queue = [{"k": "item", "kind": "xmult", "v": 2.0, "i": -1, "lbl": "x"}]
	g.pitch_step = 20
	g._next_step()
	h = _heard().filter(func(e): return e[0] == "settle_item")
	_ok("② 위가 막히면 옥타브 밑의 같은 음", h.size() == 2
			and is_equal_approx(float(h[1][1]), float(h[0][1]) * 0.75), "%s" % [h])
	_pool()
	g._sfx("settle_item", g.SFX_BASE)
	_ok("② 돌려 쓴 자리는 0dB 로 돌아온다", is_equal_approx(float(_heard()[0][2]), 0.0))

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
