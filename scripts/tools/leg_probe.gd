extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  판 선택 · 건너뛰기 · 뱃지 회귀 검사
#
#  실행:  godot --path . --headless --quit-after 2000 --script scripts/tools/blind_probe.gd
#  종료 코드 = 실패 개수
#
#  legs.csv 의 skippable 열도 GameData.skippable() 도 검증기도 오래
#  전부터 있었는데 게임에서 부르는 데가 0곳이었다 — 표만 있고 손이 없던
#  자리다. 한 번 살려 두면 조용히 다시 죽으므로 여기서 못 박는다.
#
#  재는 것
#    ① 흐름 — 런은 판 선택으로 시작하고, 던지면 판이 선다
#    ② 보스는 못 건너뛴다 (발라트로와 같은 규칙)
#    ③ 건너뛰면 점수도 골드도 없이 다음 판으로 간다
#    ④ 뱃지가 실제로 값을 낸다 — 즉시 것과 쌓아 두는 것 둘 다
#    ⑤ 쌓아 둔 뱃지는 한 번 쓰이고 사라진다
# ══════════════════════════════════════════════════════════

var fails := 0


func _say(ok: bool, name: String, detail := "") -> void:
	print("  %s %-30s %s" % ["OK  " if ok else "실패", name, detail])
	if not ok:
		fails += 1


func _tag(id: String) -> Dictionary:
	for t in GameData.tags():
		if String(t.get("id", "")) == id:
			return t
	return {}


func _initialize() -> void:
	Save.path = "user://_probe_blind.cfg"
	Save.wipe()
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)

	# ① 런은 판 선택으로 시작한다
	g._new_run()
	_say(g.state == g.S.LEG and g.leg_no == 1,
			"런은 판 선택으로 시작한다", "state %d · 판 %d" % [g.state, g.leg_no])
	_say(not g.leg_tag.is_empty(),
			"건너뛰면 받을 뱃지를 미리 보인다", String(g.leg_tag.get("name", "")))

	# 던지면 판이 선다
	g._click(g._leg_go().get_center())
	# 판 갈이 연출이 낀다. 그림만 붙잡고 상태·데이터는 그 프레임에 서므로
	# 아래 단언은 그대로다 — 그 약속이 깨지면 여기서 먼저 터진다.
	_say(g.state != g.S.LEG and g.target == GameData.target_of(1),
			"던지면 판이 선다", "state %d · 목표 %d" % [g.state, g.target])
	g._swap_skip()

	# ② 보스는 못 건너뛴다
	g.leg_no = GameData.legs_per_round()          # 라운드 1 의 마지막 판
	g._open_leg()
	_say(GameData.is_boss(g.leg_no) and not GameData.skippable(g.leg_no)
			and g.leg_tag.is_empty(),
			"보스 판은 뱃지도 안 굴린다", "판 %d" % g.leg_no)
	var before: int = g.leg_no
	g._click(g._leg_skip().get_center())
	_say(g.leg_no == before and g.state == g.S.LEG,
			"보스 판은 건너뛰기가 안 먹는다", "판 %d" % g.leg_no)

	# ③ 건너뛰면 점수도 골드도 없이 다음 판으로
	g.leg_no = 1
	g.gold = 10
	g.total = 0
	g._open_leg()
	g.leg_tag = {}                                  # 뱃지 값을 빼고 이동만 본다
	g._skip_leg()
	_say(g.leg_no == 2 and g.gold == 10 and g.state == g.S.LEG,
			"건너뛰면 값 없이 다음 판으로", "판 %d · 골드 %d" % [g.leg_no, g.gold])

	# ④ 즉시 뱃지 — 골드가 실제로 는다
	g.gold = 10
	g._take_tag(_tag("t_gold"))
	_say(g.gold == 10 + int(_tag("t_gold").get("v", 0)),
			"즉시 뱃지가 값을 낸다", "골드 10 → %d" % g.gold)

	# 쌓는 뱃지 — 지금은 아무 일도 안 하고 목록에 남는다
	g.pending_tags.clear()
	g._take_tag(_tag("t_dart"))
	_say(g.pending_tags.size() == 1 and String(g.pending_tags[0].kind) == "dart",
			"나중 뱃지는 쌓인다", "%d장" % g.pending_tags.size())

	# ⑤ 쌓인 뱃지는 한 번 쓰이고 사라진다
	var got: int = g._spend_tags("dart")
	_say(got == int(_tag("t_dart").get("v", 0)) and g.pending_tags.is_empty(),
			"쌓인 뱃지는 한 번 쓰고 사라진다",
			"값 %d · 남은 %d장" % [got, g.pending_tags.size()])
	_say(g._spend_tags("dart") == 0, "두 번째로는 아무것도 안 나온다")

	# 다트 뱃지가 실제로 탄창을 늘린다
	g.leg_no = 1
	g.pending_tags.clear()
	g._take_tag(_tag("t_dart"))
	g._start_leg()
	_say(g.remaining.size() == GameData.darts_of(1) + int(_tag("t_dart").get("v", 0)),
			"다트 뱃지가 탄창을 늘린다", "%d발" % g.remaining.size())

	print("\n%s" % ("실패 %d건" % fails if fails > 0 else "열한 검사 전부 통과"))
	quit(mini(fails, 125))
