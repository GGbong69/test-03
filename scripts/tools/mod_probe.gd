extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  제약 축 회귀 검사
#
#  실행:  godot --path . --headless --quit-after 4000 --script scripts/tools/mod_probe.gd
#  종료 코드 = 실패 개수
#
#  제약은 축 하나가 정확히 한 자리에 걸린다. 그 자리가 둘이 되면
#  "이 제약이 무엇을 하는가" 가 코드에서 안 읽히고, 걸리는 자리가
#  0 이 되면 조용히 아무 일도 안 하는 카드가 된다 — 안개(fog)가 실제로
#  그랬다. 축마다 "값이 실제로 바뀌는가" 를 수로 못 박는다.
#
#  재는 것
#    ① 표의 모든 축이 코드가 아는 축이다 (그 역도 — 안 쓰이는 축이 없다)
#    ② 칸 축 — 번호 · 색 · 홀짝이 실제로 값을 죽인다
#    ③ 링 축 — 트리플 배수가 1 이 된다. 값은 안 죽는다
#    ④ 판 축 — 돌리면 자리가 바뀌고, 값의 총합은 그대로다
#    ⑤ 판 축은 되돌아온다 — 다음 판에 제약이 빠지면 제자리다
#    ⑥ 판밖 축 — 보상 배수가 정산에 실제로 든다
# ══════════════════════════════════════════════════════════

var fails := 0


func _say(ok: bool, name: String, detail := "") -> void:
	print("  %s %-30s %s" % ["OK  " if ok else "실패", name, detail])
	if not ok:
		fails += 1


func _row(id: String) -> Dictionary:
	for m in GameData.modifiers():
		if String(m.get("id", "")) == id:
			return m
	return {}


# 그 제약 하나만 걸고 라운드를 연다.
func _arm(g: Node, id: String) -> void:
	var r := _row(id)
	# 표의 행을 통째로 싣는다 — 게임이 그렇게 한다(_pick_stage 의 sp.d).
	# 손으로 골라 담으면 id 가 빠져 그리기가 터진다.
	g.active_mods = [] if r.is_empty() else [r]
	g._start_round()
	g._swap_skip()


# 판 어느 칸의 한가운데 점. idx 는 sectors 배열의 자리다.
func _pt(g: Node, idx: int, rr: float) -> Vector2:
	var a: float = float(idx) * TAU / 20.0
	return g.BC + Vector2(sin(a), -cos(a)) * g.R * rr


# 그 자리에 실제로 던졌을 때 정산 큐에 오르는 값·배수.
# hit_info 가 아니라 _land 를 지나야 한다 — 제약이 걸리는 자리가 거기다.
# 안개가 죽은 효과였던 것도 "판정은 맞는데 아무 데도 안 걸린" 경우였다.
func _throw(g: Node, idx: int, rr: float) -> Vector2:
	g.aim = _pt(g, idx, rr)
	g.queue.clear()
	g._land()
	var chip := 0.0
	var mult := 0.0
	for q in g.queue:
		if String(q.get("k", "")) == "chip":
			chip += float(q.get("v", 0))
		elif String(q.get("k", "")) == "mult":
			mult += float(q.get("v", 0))
	return Vector2(chip, mult)


func _initialize() -> void:
	Save.path = "user://_probe_mod.cfg"
	Save.wipe()
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g._new_run()
	g._swap_skip()

	# ① 표와 코드가 같은 축을 안다
	var unused: Array = GameData.MODIFIER_AXES.duplicate()
	var unknown := ""
	for m in GameData.modifiers():
		var ax := String(m.get("k", ""))
		if not GameData.MODIFIER_AXES.has(ax):
			unknown = ax
		unused.erase(ax)
	_say(unknown == "" and unused.is_empty(), "표와 코드가 같은 축을 안다",
			"모르는 축 '%s' · 안 쓰는 축 %s" % [unknown, unused])

	# ② 칸 축 — 번호
	_arm(g, "dead")
	var kill: int = g.dead_idx
	var live: int = (kill + 5) % 20
	var raw: int = int(g.hit_info(_pt(g, kill, 0.55)).base)
	var d_kill := _throw(g, kill, 0.55)
	var d_live := _throw(g, live, 0.55)
	_say(raw > 0 and is_zero_approx(d_kill.x) and d_live.x > 0.0,
			"번호 축이 그 칸만 죽인다",
			"판정 %d점 → 던지면 %.0f점 · 옆칸 %.0f점" % [raw, d_kill.x, d_live.x])

	# 색
	_arm(g, "shade")
	var hit_dead := 0
	var hit_live := 0
	for i in 20:
		var inf: Dictionary = g.hit_info(_pt(g, i, 0.55))
		if int(inf.col) == g.dead_col:
			hit_dead += 1
		else:
			hit_live += 1
	var dead_pts := 0.0
	var live_pts := 0.0
	for i in 20:
		var pt := _throw(g, i, 0.55)
		if int(g.hit_info(_pt(g, i, 0.55)).col) == g.dead_col:
			dead_pts += pt.x
		else:
			live_pts += pt.x
	_say(g.dead_col >= 0 and hit_dead == 10 and hit_live == 10
			and is_zero_approx(dead_pts) and live_pts > 0.0,
			"색 축이 그 색만 죽인다",
			"죽는 %d칸 합 %.0f점 · 사는 %d칸 합 %.0f점"
			% [hit_dead, dead_pts, hit_live, live_pts])

	# 홀짝
	_arm(g, "odd")
	var odd_seen := 0
	var even_seen := 0
	for i in 20:
		var inf: Dictionary = g.hit_info(_pt(g, i, 0.55))
		if int(inf.base) % 2 == 1:
			odd_seen += 1
		else:
			even_seen += 1
	var cut := 0
	var kept := 0
	for i in 20:
		var raw_v := int(g.hit_info(_pt(g, i, 0.55)).base)
		var got := _throw(g, i, 0.55).x
		if raw_v % 2 == 1:
			if int(got) == int(round(float(raw_v) * 0.5)):
				cut += 1
		elif int(got) == raw_v:
			kept += 1
	_say(is_equal_approx(g.odd_mul, 0.5) and odd_seen == 10 and even_seen == 10
			and cut == 10 and kept == 10,
			"홀수 칸만 반값이 된다",
			"반값 %d칸 · 그대로 %d칸" % [cut, kept])

	# ③ 링 축
	_arm(g, "flat")
	var trp := 0.0
	for i in 20:
		var inf: Dictionary = g.hit_info(_pt(g, i, (g.rt_trp_in + g.rt_trp_out) * 0.5))
		trp = maxf(trp, float(inf.mult))
	var mid: float = (g.rt_trp_in + g.rt_trp_out) * 0.5
	var t_hit := _throw(g, 0, mid)
	var raw_t := int(g.hit_info(_pt(g, 0, mid)).base)
	_say(g.dead_ring == 3 and is_equal_approx(trp, 3.0)
			and is_equal_approx(t_hit.y, 1.0) and int(t_hit.x) == raw_t,
			"링 축이 배수만 1 로 내린다",
			"판정 배수 %.0f → 던지면 %.0f · 값 %.0f(그대로 %d)"
			% [trp, t_hit.y, t_hit.x, raw_t])

	# ④ 판 축 — 자리는 바뀌고 값의 총합은 그대로다
	var base_sum := 0
	for v in GameData.SECTORS_BASE:
		base_sum += int(v)
	_arm(g, "turn")
	var spun: Array = g.sectors.duplicate()
	var spun_sum := 0
	for v in spun:
		spun_sum += int(v)
	var moved := 0
	for i in spun.size():
		if int(spun[i]) != int(GameData.SECTORS_BASE[i]):
			moved += 1
	_say(g.spin_cur == int(_row("turn").v) and spun_sum == base_sum and moved > 0,
			"판 축은 값을 안 죽이고 자리만 바꾼다",
			"%d칸 회전 · %d자리 이동 · 합 %d" % [g.spin_cur, moved, spun_sum])
	_say(g.sec_col.size() == spun.size(),
			"색도 같이 돈다", "%d칸" % g.sec_col.size())

	# ⑤ 되돌아온다
	_arm(g, "")
	var back := true
	for i in g.sectors.size():
		if int(g.sectors[i]) != int(GameData.SECTORS_BASE[i]):
			back = false
	_say(g.spin_cur == 0 and back, "제약이 빠지면 판이 제자리로")

	# ⑤' 굽는 사이에도 안 어긋난다. 개조를 사면 _board_bake 가 sectors 를
	#     밑바닥에서 새로 만드는데 sec_col 은 일부러 안 지운다 — 그대로 두면
	#     숫자만 제자리로 가고 색만 돌아간 채 남는다.
	_arm(g, "turn")
	g._board_bake()
	var mixed := false
	for i in g.sectors.size():
		if int(g.sectors[i]) != int(GameData.SECTORS_BASE[i]):
			mixed = true
	var col_ok := true
	for i in g.sec_col.size():
		if int(g.sec_col[i]) != i % 2:
			col_ok = false
	_say(g.spin_cur == 0 and not mixed and col_ok,
			"되굽기가 판을 안 어긋나게 한다",
			"회전 %d · 숫자 제자리 %s · 색 제자리 %s" % [g.spin_cur, not mixed, col_ok])

	# ⑥ 판밖 축 — 보상
	g.round_no = 2
	_arm(g, "dry")
	g.gold = 0
	g.total = GameData.target_of(2)
	g.darts_left = 0
	g._settle_clear()
	var dry_gold: int = g.gold
	g.round_no = 2
	_arm(g, "")
	g.gold = 0
	g.total = GameData.target_of(2)
	g.darts_left = 0
	g._settle_clear()
	_say(dry_gold < g.gold, "보상 축이 정산에 든다",
			"제약 %d골드 · 없을 때 %d골드" % [dry_gold, g.gold])

	print("
%s" % ("실패 %d건" % fails if fails > 0 else "열 검사 전부 통과"))
	quit(mini(fails, 125))
