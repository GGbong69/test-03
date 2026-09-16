extends SceneTree
# 제약이 돌아가는가 — 지난 보스가 깐 셋이 이번 보스에 또 나오면 안 된다.
#   godot --headless --path . --script scripts/tools/qa_stagerot.gd
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


func _ids() -> Array:
	var out := []
	for e in g.stage_pick:
		out.append(String((e.d as Dictionary).id))
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
	var picks: int = GameData.stage_picks()
	_ok("표가 까는 장수의 두 배는 된다", mods >= picks * 2,
			"제약 %d종 · 까는 장수 %d" % [mods, picks])

	var bs := _bosses(6)
	var prev := []
	var runs := 0
	for lv in bs:
		g.leg_no = lv
		g._open_stage()
		var now := _ids()
		if now.is_empty():
			continue
		_ok("보스 %d — 깔린 장수가 맞다" % lv, now.size() == picks,
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

	#  **고른 것만이 아니라 깐 것 전부**를 기억해야 한다. 안 고른 둘도
	#  이미 본 카드라, 다음 판에 또 나오면 새 판이 아니다.
	_ok("기억한 수 = 깐 수", g.stage_seen.size() == picks,
			"%d개" % g.stage_seen.size())

	#  새 런은 넓은 표에서 뽑는다 — 지난 런의 것을 끌고 가면 첫 보스가
	#  까닭 없이 좁아진다.
	g._new_run()
	_ok("새 런은 기억을 비운다", g.stage_seen.is_empty(),
			"%d개" % g.stage_seen.size())
