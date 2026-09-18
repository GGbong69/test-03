extends SceneTree
# 제약이 돌아가는가 — 지난 보스가 정한 것이 이번 보스에 또 나오면 안 된다.
#  라운드마다 다른 보스를 만나는 것이 예고형 판 선택의 전부라(2026-09-18)
#  이 규칙은 고르는 화면이 있던 시절보다 오히려 더 중요하다.
#   godot --headless --path . --script scripts/tools/qa_bossrot.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_rot_g.cfg"
	Save.path = "user://_qa_rot.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	_run()
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-40s %s" % ["통과" if cond else "실패", nm, note])


func _ids(bn: int) -> Array:
	var out := []
	for mid in g.boss_mods.get(bn, PackedStringArray()):
		out.append(String(mid))
	out.sort()
	return out


#  보스 판 번호들. 제약은 보스에만 깔린다.
func _bosses(n: int) -> Array:
	var out := []
	for lv in range(1, 60):
		if GameData.is_boss(lv):
			out.append(lv)
		if out.size() >= n:
			break
	return out


func _run() -> void:
	g._new_run()
	g.drop_fast = true
	var mods: int = GameData.modifiers().size()
	var picks: int = maxi(GameData.chal_i("mods_n", 1), 1)
	_ok("표 종수 ≥ 거는 장수 × 2", mods >= picks * 2,
			"제약 %d종 · 한 보스에 %d장" % [mods, picks])

	var bs := _bosses(6)
	var prev := []
	var runs := 0
	for lv in bs:
		g.leg_no = lv
		g._roll_boss_mods(lv, true)
		var now := _ids(lv)
		if now.is_empty():
			continue
		_ok("보스 %d — 걸린 장수가 맞다" % lv, now.size() == picks,
				"%d장" % now.size())
		if not prev.is_empty():
			var same := []
			for k in now:
				if prev.has(k):
					same.append(k)
			_ok("보스 %d — 지난 셋과 안 겹친다" % lv, same.is_empty(),
					"겹친 것: %s" % ", ".join(same))
			runs += 1
		prev = now
	_ok("겹침 검사를 실제로 돌렸다", runs >= 4, "%d번" % runs)

	#  창이 넘치면 안 된다. 옛 화면이 셋을 깔았으니 지난 보스가 막던 폭이
	#  3 이었고, 거는 장수가 1~2 로 줄어도 **막는 폭은 옛날과 같아야** 한다.
	#  되풀이 방지의 폭이지 밸런스 손잡이가 아니다.
	_ok("기억 창이 상한을 안 넘는다", g.boss_seen.size() <= g.BOSS_SEEN_N,
			"%d개 (상한 %d)" % [g.boss_seen.size(), g.BOSS_SEEN_N])
	_ok("기억이 실제로 쌓인다", g.boss_seen.size() >= mini(picks, g.BOSS_SEEN_N),
			"%d개" % g.boss_seen.size())

	#  새 런은 넓은 표에서 뽑는다 — 지난 런의 것을 끌고 가면 첫 보스가
	#  까닭 없이 좁아진다. _new_run 은 끝에 판 선택을 열어 **이 라운드
	#  보스를 바로 굴리므로**, 「빈다」가 아니라 「지난 런 것이 안 남는다」다.
	g._new_run()
	_ok("새 런은 지난 런의 기억을 안 끌고 온다",
			g.boss_seen.size() <= picks and g.boss_mods.size() <= 1,
			"기억 %d개 · 사전 %d칸" % [g.boss_seen.size(), g.boss_mods.size()])
