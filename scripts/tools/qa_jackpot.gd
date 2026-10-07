extends SceneTree
# 리롤 잭팟(2026-10-07 · game.gd JP) — 못 박는 것:
#   ① 표에 확률이 있고 아주 낮다(0 < p <= 1%).
#   ② 상점을 처음 열 때는 안 선다 — 확률이 1 이어도.
#   ③ 리롤에서 선다 — 한 칸 · 아직 안 가진 레전더리 · 표 값(리그 배수) · 공짜 칸을 안 건드린다.
#   ④ 확률 0 이면 리롤 삼백 번에 레전더리가 한 장도 안 선다(저울 0 은 그대로다).
#   ⑤ 튜토리얼 런에는 안 선다 · 레전더리를 다 들고 있으면 안 선다(깨지지도 않는다).
#   ⑥ 앉은 프레임에 연출이 선다 — 종 · 상인 · 흔들림 · 금화 · 반짝이. 길이가 표 그대로다.
#   ⑦ 어둠은 들고 · 머물고 · 나가는 한 번이다(껐다 켜는 프레임이 없다).
#   ⑧ 움직임을 끄면 흔들림 · 금화가 빠지고 어둠 · 반짝이는 남는다.
#   ⑨ 같은 칸이 다시 깔려도(사진이 테이블을 치웠다 다시 깔 때) 두 번 안 터진다.
#      매듭에서 되살린 상점도 다시 안 터진다.
#   ⑩ 개발자 줄 「레전더리 잭팟」이 있고 그 쪽이 열아홉 줄 안이며, 누르면 골드를 안 건드리고
#      잭팟 딜링이 선다.
#   godot --headless --path . --script scripts/tools/qa_jackpot.gd
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
const Dev = preload("res://scripts/dev.gd")
var g = null
var ok := 0
var bad := 0
var busy := false
var p0 := 0.0


func _initialize() -> void:
	Save.gpath = "user://_qa_jackpot_g.cfg"
	Save.path = "user://_qa_jackpot.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	GameData._tune["jackpot_p"] = p0
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)
	return false


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-44s %s" % ["통과" if cond else "실패", nm, note])


#  관찰용 소리 자리 — 게임은 넷이라 한 딜링의 소리가 돌아 덮인다(qa_land 와 같은 까닭).
func _snd_wide() -> void:
	for sp in g.sfx_pool:
		sp.queue_free()
	g.sfx_pool.clear()
	for i in 16:
		var sp := AudioStreamPlayer.new()
		sp.bus = "SFX"
		g.add_child(sp)
		g.sfx_pool.append(sp)
	g.sfx_next = 0


func _snd_has(nm: String) -> bool:
	for sp in g.sfx_pool:
		var st: AudioStream = (sp as AudioStreamPlayer).stream
		if st != null and st.resource_path.get_file().get_basename() == nm:
			return true
	return false


func _jp_rows() -> Array:
	var out := []
	for k in g.stock.size():
		if bool(g.stock[k].get("jackpot", false)):
			out.append(k)
	return out


func _legs_on_table(skip_free: bool) -> int:
	var n := 0
	for s in g.stock:
		if String(s.get("type", "")) != "item":
			continue
		if skip_free and bool(s.get("free", false)):
			continue
		if String((s.d as Dictionary).get("rarity", "")) == "legendary":
			n += 1
	return n


func _shop() -> void:
	g._new_run()
	g.tut_run = false
	g.motion_off = false
	g.drop_fast = true        # 낙하를 안 기다린다 — 리롤이 곧장 새 테이블을 깐다(오토플레이와 같다)
	g.gold = 9999
	g._open_shop()


func _reroll() -> void:
	g.gold = 9999
	g._reroll()


func _tick_out(cap := 6.0) -> float:
	var t := 0.0
	while g.jp_i >= 0 and t < cap:
		g._drop_extras(1.0 / 60.0)
		t += 1.0 / 60.0
	return t


func _legendaries() -> Array:
	var out := []
	for it in GameData.items():
		if String(it.get("rarity", "")) == "legendary":
			out.append(it)
	return out


func _run() -> void:
	p0 = GameData.tune("jackpot_p")
	# ① 표
	_ok("① 표에 확률이 있다(0 < p <= 1%)", p0 > 0.0 and p0 <= 0.01, "p %.6f" % p0)
	_ok("① tuning 계약 열쇠에 들었다", GameData.TUNE_KEYS.has("jackpot_p"))

	# ② 상점을 처음 열 때는 안 선다
	GameData._tune["jackpot_p"] = 1.0
	var open_hits := 0
	for _k in 30:
		_shop()
		open_hits += _jp_rows().size()
	_ok("② 상점을 열 때는 확률 1 이어도 안 선다", open_hits == 0, "%d칸" % open_hits)

	# ③ 리롤에서 선다
	_shop()
	_snd_wide()
	var leg0 := _legs_on_table(true)
	_reroll()
	var rows := _jp_rows()
	_ok("③ 리롤에 한 칸이 선다", rows.size() == 1, "%d칸" % rows.size())
	if rows.size() == 1:
		var s: Dictionary = g.stock[rows[0]]
		var d: Dictionary = s.d
		_ok("③ 그 칸이 레전더리다", String(d.get("rarity", "")) == "legendary", String(d.get("id", "")))
		_ok("③ 안 가진 장이다", not g._has_item(String(d.id)))
		_ok("③ 값은 표 값(리그 배수)이다", int(s.cost) == g._league_cost(int(d.get("cost", 0))),
				"%d" % int(s.cost))
		_ok("③ 공짜 칸이 아니다", not bool(s.get("free", false)))
		_ok("③ 앉은 프레임에 연출이 섰다", g.jp_i == rows[0] and g.jp_t >= 0.0,
				"jp_i %d · jp_t %.3f" % [g.jp_i, g.jp_t])
		_ok("③ 잭팟 종이 났다", _snd_has("jackpot"))
		_ok("③ 흔들림이 리롤(6.0)을 넘는다", g.shake >= float(g.JP.shake) - 0.001
				and float(g.JP.shake) > 6.0, "%.1f" % g.shake)
		_ok("③ 상인이 움찔한다", g._idle_name() == "움찔" or not g._npc_on(), g._idle_name())
		_ok("③ 금화 · 반짝이가 표의 수만큼", g.jp_coins.size() == int(g.JP.coins)
				and g.jp_sparks.size() == int(g.JP.sparks),
				"금화 %d · 반짝이 %d" % [g.jp_coins.size(), g.jp_sparks.size()])
		_ok("③ 레전더리 한 장만 더 섰다", _legs_on_table(true) == 1, "앞 %d" % leg0)
	_ok("③ 확률을 다 쓰면 자격이 꺼진다", not g.jp_due)

	# ⑥ ⑦ 길이와 어둠의 모양
	var dims := []
	var t := 0.0
	while g.jp_i >= 0 and t < 6.0:
		dims.append(g._jp_dim())
		g._drop_extras(1.0 / 60.0)
		t += 1.0 / 60.0
	var want: float = g._jp_len()
	_ok("⑥ 연출이 표 길이에 끝난다", absf(t - want) < 2.5 / 60.0, "%.3f초 · 표 %.2f" % [t, want])
	var peak := 0.0
	for v in dims:
		peak = maxf(peak, float(v))
	_ok("⑦ 어둠이 표 깊이까지 간다", absf(peak - float(g.JP.dim_a)) < 0.01, "%.3f" % peak)
	#  방향이 바뀐 횟수 — 오름 · (머묾) · 내림이면 한 번이다.
	var turns := 0
	var dir := 0
	for k in range(1, dims.size()):
		var dv: float = float(dims[k]) - float(dims[k - 1])
		var nd := 0 if absf(dv) < 0.0005 else (1 if dv > 0.0 else -1)
		if nd != 0 and dir != 0 and nd != dir:
			turns += 1
		if nd != 0:
			dir = nd
	_ok("⑦ 어둠은 들고 나는 한 번이다(껐다 켜지 않는다)", turns == 1, "방향 바뀜 %d" % turns)
	var jump := 0.0
	for k in range(1, dims.size()):
		jump = maxf(jump, absf(float(dims[k]) - float(dims[k - 1])))
	_ok("⑦ 한 틀에 어둠이 0.2 넘게 안 뛴다", jump < 0.2, "%.3f" % jump)
	_ok("⑥ 끝나면 비었다", g.jp_i < 0 and g.jp_coins.is_empty() and g._jp_dim() == 0.0)

	# ④ 확률 0
	GameData._tune["jackpot_p"] = 0.0
	_shop()
	var leg_hits := 0
	for _k in 300:
		_reroll()
		leg_hits += _legs_on_table(true)
	_ok("④ 확률 0 이면 리롤 삼백 번에 레전더리 0", leg_hits == 0, "%d장" % leg_hits)

	# ⑤ 튜토리얼 런 · 다 들고 있을 때
	GameData._tune["jackpot_p"] = 1.0
	_shop()
	g.tut_run = true
	_reroll()
	_ok("⑤ 튜토리얼 런에는 안 선다", _jp_rows().is_empty())
	g.tut_run = false
	_shop()
	g.owned.clear()
	for it in _legendaries():
		if g.owned.size() >= GameData.max_items():
			break
		var c: Dictionary = (it as Dictionary).duplicate()
		c.gs = 0
		c.bought = 0
		g.owned.append(c)
	var all_held: bool = g.owned.size() == _legendaries().size()
	_reroll()
	_ok("⑤ 레전더리를 다 들면 안 선다", not all_held or _jp_rows().is_empty(),
			"든 %d / %d" % [g.owned.size(), _legendaries().size()])
	g.owned.clear()

	# ⑧ 움직임 끄기
	_shop()
	g.motion_off = true
	g.shake = 0.0
	_reroll()
	_ok("⑧ 움직임을 끄면 흔들림이 없다", g.shake == 0.0, "%.2f" % g.shake)
	_ok("⑧ 금화가 빠진다", g.jp_coins.is_empty())
	_ok("⑧ 반짝이(알파)는 남는다", g.jp_sparks.size() == int(g.JP.sparks))
	g._drop_extras(0.2)
	_ok("⑧ 어둠(알파)은 남는다", g._jp_dim() > 0.3, "%.3f" % g._jp_dim())
	g.motion_off = false

	# ⑨ 다시 깔려도 한 번 · 되살린 상점도 다시 안 터진다
	_shop()
	_reroll()
	var k0: int = g.jp_i
	_tick_out()
	g._drop_roll()
	_ok("⑨ 같은 칸이 다시 깔려도 안 터진다", k0 >= 0 and g.jp_i < 0 and g.jp_t < 0.0,
			"앞 %d · 지금 %d" % [k0, g.jp_i])
	g._knot("shop")
	g._stock_restore()
	g._drop_roll()
	var legs_after := _legs_on_table(true)
	_ok("⑨ 되살린 상점에 그 장이 남는다", legs_after == 1, "%d장" % legs_after)
	_ok("⑨ 되살린 상점은 안 터진다", g.jp_i < 0 and _jp_rows().is_empty())

	# ⑩ 개발자 줄
	GameData._tune["jackpot_p"] = 0.0
	_shop()
	var was_on: bool = Dev.on
	var was_pg: int = Dev.page
	Dev.on = true
	Dev.page = 3
	var rws: Array = Dev._rows(g)
	var at := -1
	for i in rws.size():
		if String(rws[i].get("n1", "")) == "레전더리 잭팟":
			at = i
	_ok("⑩ 개발자 3쪽에 줄이 있다", at >= 0)
	_ok("⑩ 그 쪽이 열아홉 줄 안이다", rws.size() <= 19, "%d줄" % rws.size())
	if at >= 0:
		var gd0: int = g.gold
		Dev._run(g, rws[at])
		var f := 0
		while (g.sweep_live or g.drop_awake) and f < 600:
			g._drop_update(1.0 / 60.0)
			f += 1
		_ok("⑩ 누르면 잭팟 딜링이 선다", _jp_rows().size() == 1, "%d칸 · %d틀" % [_jp_rows().size(), f])
		_ok("⑩ 골드를 안 건드린다", g.gold == gd0, "%d → %d" % [gd0, g.gold])
	Dev.on = was_on
	Dev.page = was_pg
