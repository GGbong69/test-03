extends SceneTree

const GameData = preload("res://scripts/data.gd")

# ══════════════════════════════════════════════════════════
#  데이터 표 검사만 하는 진입점
#
#  실행:  godot --path . --headless --script scripts/tools/validate.gd
#  종료 코드 = 오류 개수 (경고는 안 센다)
#
#  게임을 켜도 같은 검사가 돌지만, 그건 push_error 라 종료 코드를 안 바꾸고
#  호출자가 셀 수도 없다. 표를 고친 뒤 게임을 켜기 전에 이걸 먼저 돌린다.
# ══════════════════════════════════════════════════════════

func _initialize() -> void:
	var errs := GameData.errors()
	var warns := GameData.warnings()

	for name in GameData.FILES:
		print("  %-12s %3d행" % [GameData.FILES[name], GameData.rows(name).size()])

	if warns.is_empty() and errs.is_empty():
		print("\n표 %d장 — 이상 없다" % GameData.FILES.size())
	if not warns.is_empty():
		print("\n경고 %d건" % warns.size())
		for w in warns:
			print("  · " + w)
	if not errs.is_empty():
		print("\n오류 %d건" % errs.size())
		for e in errs:
			print("  × " + e)

	quit(mini(errs.size(), 125))
