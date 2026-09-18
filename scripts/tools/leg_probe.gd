extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  판 선택 · 건너뛰기 · 뱃지 회귀 검사
#
#  실행:  godot --path . --headless --quit-after 2000 -s scripts/tools/leg_probe.gd
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
#    ⑥ 보스 카드가 제약을 들고, 보통 판은 제약이 없다 (2026-09-18)
#
#  뱃지는 id 가 아니라 **갈래로** 고른다
#    2026-09-15 에 tags.csv 를 갈아엎으면서 t_dart 가 빠졌고, 그 id 를 박아
#    둔 이 검사가 「나중 뱃지는 쌓인다 0장」으로 멎었다. 뒤의 두 검사는 빈
#    뱃지의 값 0 끼리 대 보며 **헛통과**하고 있었다 — 값이 0 인 뱃지는
#    고르지 않는다.
# ══════════════════════════════════════════════════════════

var fails := 0


func _say(ok: bool, name: String, detail := "") -> void:
	print("  %s %-30s %s" % ["OK  " if ok else "실패", name, detail])
	if not ok:
		fails += 1


# 이 갈래의 첫 뱃지. 값이 0 이면 뒤의 검사가 0 끼리 맞아떨어지므로 뺀다.
func _tag_kind(kind: String) -> Dictionary:
	for t in GameData.tags():
		if String(t.get("kind", "")) == kind and int(t.get("v", 0)) > 0:
			return t
	return {}


# 나중에 쓰는 첫 뱃지 — 받는 자리가 now 가 아닌 줄. 쌍둥이(copy)는 when 이
# now 라 여기 안 걸린다(쌓이긴 해도 pending_tags 가 아니라 tag_copy 에 쌓인다).
func _tag_later() -> Dictionary:
	for t in GameData.tags():
		if String(t.get("when", "now")) != "now" and int(t.get("v", 0)) > 0:
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
	#  ⑥ 판 선택이 열리는 그 자리에서 이 라운드 보스의 제약이 이미 서 있다.
	#     상점에서 빌드를 짜려면 그때 이미 정해져 있어야 한다(2026-09-18).
	var bn0: int = g._round_boss()
	_say(bn0 > 0 and not g.boss_mods.get(bn0, PackedStringArray()).is_empty(),
			"보스 카드가 제약을 든다",
			"%d번 판 %s" % [bn0, g.boss_mods.get(bn0, PackedStringArray())])

	# 던지면 판이 선다
	g._click(g._leg_go().get_center())
	# 판 갈이 연출이 낀다. 그림만 붙잡고 상태·데이터는 그 프레임에 서므로
	# 아래 단언은 그대로다 — 그 약속이 깨지면 여기서 먼저 터진다.
	_say(g.state != g.S.LEG and g.target == GameData.target_of(1),
			"던지면 판이 선다", "state %d · 목표 %d" % [g.state, g.target])
	_say(g.active_mods.is_empty(), "보통 판은 제약이 없다",
			"걸린 제약 %d개" % g.active_mods.size())
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
	var gold_t := _tag_kind("gold")
	g.gold = 10
	g._take_tag(gold_t)
	_say(not gold_t.is_empty() and g.gold == 10 + int(gold_t.get("v", 0)),
			"즉시 뱃지가 값을 낸다",
			"%s · 골드 10 → %d" % [gold_t.get("id", "표에 없음"), g.gold])

	# 쌓는 뱃지 — 지금은 아무 일도 안 하고 목록에 남는다
	var later := _tag_later()
	var lk := String(later.get("kind", ""))
	g.pending_tags.clear()
	g._take_tag(later)
	_say(not later.is_empty() and g.pending_tags.size() == 1
			and String(g.pending_tags[0].kind) == lk,
			"나중 뱃지는 쌓인다",
			"%s · %d장" % [later.get("id", "표에 없음"), g.pending_tags.size()])

	# ⑤ 쌓인 뱃지는 한 번 쓰이고 사라진다
	var got: int = g._spend_tags(lk)
	_say(not later.is_empty() and got == int(later.get("v", 0))
			and g.pending_tags.is_empty(),
			"쌓인 뱃지는 한 번 쓰고 사라진다",
			"값 %d · 남은 %d장" % [got, g.pending_tags.size()])
	_say(g._spend_tags(lk) == 0, "두 번째로는 아무것도 안 나온다")

	# 다트 뱃지가 실제로 탄창을 늘린다
	#  2026-09-15 표에서 「여벌 다트」가 빠졌다. 갈래와 꺼내는 자리
	#  (_start_leg 의 _spend_tags("dart"))는 남겨 뒀다 — 되살리는 것이 표에
	#  한 줄이라는 약속이다. 표에 없으면 빠진 그 줄을 그대로 세워 약속을 잰다.
	var dart_t := _tag_kind("dart")
	if dart_t.is_empty():
		dart_t = {"id": "t_dart(표에 없음 · 옛 줄)", "name": "여벌 다트",
				"kind": "dart", "v": "1", "when": "leg"}
	g.leg_no = 1
	g.pending_tags.clear()
	g._take_tag(dart_t)
	g._start_leg()
	_say(g.remaining.size() == GameData.darts_of(1) + int(dart_t.get("v", 0)),
			"다트 뱃지가 탄창을 늘린다",
			"%s · %d발" % [dart_t.id, g.remaining.size()])

	print("\n%s" % ("실패 %d건" % fails if fails > 0 else "열세 검사 전부 통과"))
	quit(mini(fails, 125))
