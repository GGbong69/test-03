extends SceneTree

# 프로필. 2026-09-15 사용자 지시 —
#   "발라트로나 슬더슬같이 프로필이 있고 프로필마다 진도가 다른거야"
#
# 재는 것은 하나다: **가른 것이 정말 갈렸는가.** 해금·통계는 프로필마다
# 따로 쌓이고, 음량은 프로필을 갈아도 그대로다.
#
#   godot --path . --headless --script scripts/tools/qa_profile.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var okn := 0
var fail := 0
var busy := false


func erase_file(fp: String) -> void:
	if FileAccess.file_exists(fp):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fp))


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-38s %s" % ["통과" if c else "실패", n, d])


func _process(_d: float) -> bool:
	if busy: return false
	busy = true
	_run()
	return false


func _run() -> void:
	print("\n프로필 검사 — 진도가 프로필마다 따로인가\n")
	#  검사용 전역 파일. 슬롯 파일은 Save.PROF 가 정하므로 검사가 끝나면
	#  지운다(아래 ⑦).
	Save.gpath = "user://_qa_prof_g.cfg"
	Save.prof_fmt = "user://_qa_prof_%d.cfg"
	Save._gloaded = false
	Save._gcfg = null
	Save.path = ""
	for i in range(1, Save.SLOTS + 1):
		Save.erase_slot(i)
	Save._slot = 0

	# ① 처음에는 1번이다
	_ok("처음 고른 자리는 1번", Save.slot() == 1, "슬롯 %d" % Save.slot())
	_ok("세 자리 다 비어 있다",
			not Save.slot_used(1) and not Save.slot_used(2) and not Save.slot_used(3),
			"1 %s · 2 %s · 3 %s" % [Save.slot_used(1), Save.slot_used(2),
					Save.slot_used(3)])

	# ② 1번에 진도를 쌓는다
	print("")
	Save.use_slot(1)
	Save.unlock("pack:p_mag")
	Save.bump("wins", 3)
	Save.peak("best_leg", 12)
	Save.set_pick("pack", "p_mag")
	Save.flush()
	_ok("1번에 쌓였다",
			Save.unlocked("pack:p_mag") and Save.stat("wins") == 3,
			"해금 %s · 완주 %d" % [Save.unlocked("pack:p_mag"), Save.stat("wins")])

	# ③ 2번으로 갈아타면 **빈손**이어야 한다
	print("")
	Save.use_slot(2)
	_ok("2번은 해금이 안 따라온다", not Save.unlocked("pack:p_mag"),
			"pack:p_mag %s" % Save.unlocked("pack:p_mag"))
	_ok("2번은 통계가 안 따라온다", Save.stat("wins") == 0,
			"완주 %d" % Save.stat("wins"))
	_ok("2번은 고른 다트통도 안 따라온다",
			String(Save.get_pick("pack", "")) == "",
			"'%s'" % Save.get_pick("pack", ""))

	# ④ 2번에 딴 것을 쌓고 1번으로 돌아가면 1번 것이 그대로
	Save.unlock("league:green")
	Save.bump("wins", 7)
	Save.flush()
	Save.use_slot(1)
	print("")
	_ok("1번으로 돌아오면 1번 것이 그대로",
			Save.unlocked("pack:p_mag") and Save.stat("wins") == 3,
			"해금 %s · 완주 %d" % [Save.unlocked("pack:p_mag"), Save.stat("wins")])
	_ok("2번 것이 1번에 안 샌다", not Save.unlocked("league:green"),
			"league:green %s" % Save.unlocked("league:green"))
	Save.use_slot(2)
	_ok("2번 것도 제자리에 있다",
			Save.unlocked("league:green") and Save.stat("wins") == 7,
			"해금 %s · 완주 %d" % [Save.unlocked("league:green"), Save.stat("wins")])

	# ⑤ 음량은 **전역**이다 — 프로필을 갈아도 그대로
	print("")
	Save.use_slot(1)
	Save.set_set("vol", 0.42)
	Save.use_slot(3)
	_ok("음량은 프로필을 갈아도 그대로",
			absf(float(Save.get_set("vol", 1.0)) - 0.42) < 0.001,
			"vol %s" % Save.get_set("vol", 1.0))
	Save.use_slot(2)
	_ok("돌아와도 그대로",
			absf(float(Save.get_set("vol", 1.0)) - 0.42) < 0.001,
			"vol %s" % Save.get_set("vol", 1.0))

	# ⑥ 고른 자리가 다음 실행까지 남는다
	print("")
	Save.use_slot(3)
	Save._gloaded = false          # 창을 껐다 켠 셈
	Save._gcfg = null
	Save._slot = 0
	_ok("고른 자리가 다음 실행까지 남는다", Save.slot() == 3,
			"슬롯 %d" % Save.slot())

	# ⑦ 훑는 것은 갈아타지 않는다 — 고르는 화면이 셋을 같이 보여 준다
	print("")
	Save.use_slot(1)
	var i2 := Save.slot_info(2)
	_ok("남의 자리를 훑어도 안 갈아탄다", Save.slot() == 1,
			"훑은 뒤 슬롯 %d" % Save.slot())
	_ok("훑은 값이 그 자리의 것", int(i2.get("wins", 0)) == 7,
			"2번 완주 %d · 지금 자리(1번) 완주 %d"
					% [int(i2.get("wins", 0)), Save.stat("wins")])
	#  2번은 쌓은 것이 있고, 3번은 고르기만 하고 아무것도 안 썼다 —
	#  고른다고 파일이 생기지는 않는다. 생기면 「빈 자리」가 없어진다.
	_ok("쌓은 자리는 찼다고, 안 쌓은 자리는 비었다고",
			bool(Save.slot_info(2).get("used", false))
			and not bool(Save.slot_info(3).get("used", false)),
			"2번 %s · 3번 %s" % [Save.slot_info(2).get("used", false),
					Save.slot_info(3).get("used", false)])

	# ⑧ 지우면 비고, 다른 자리는 안 다친다
	print("")
	Save.erase_slot(2)
	_ok("지운 자리는 빈다", not Save.slot_used(2), "2번 %s" % Save.slot_used(2))
	_ok("옆자리는 안 다친다", Save.slot_used(1) and Save.stat("wins") == 3,
			"1번 완주 %d" % Save.stat("wins"))

	# (9) 프로필이 생기기 전의 저장이 1번으로 옮겨 온다.
	#     가르기만 하고 두면 그 사람의 해금이 하루아침에 다 잠긴다 —
	#     파일은 멀쩡히 있는데 아무도 안 읽는 자리에 있는 것이라 더 나쁘다.
	print("")
	for im in range(1, Save.SLOTS + 1):
		erase_file(Save.slot_path(im))
	erase_file(Save.gpath)
	var old := ConfigFile.new()
	old.set_value("해금", "pack:p_wage", true)
	old.set_value("통계", "wins", 5)
	old.set_value("세기", "runs:base", 9)
	old.set_value("설정", "vol", 0.31)
	old.set_value("설정", "pack", "p_wage")
	old.save(Save.gpath)
	Save._gloaded = false
	Save._gcfg = null
	Save._slot = 0
	Save.path = ""
	Save._cfg = null
	Save._at = ""
	_ok("옛 저장의 해금이 1번으로 온다", Save.unlocked("pack:p_wage"),
			"pack:p_wage %s" % Save.unlocked("pack:p_wage"))
	_ok("옛 저장의 통계도 온다", Save.stat("wins") == 5, "완주 %d" % Save.stat("wins"))
	_ok("옛 저장의 세기도 온다", Save.tally("runs:base") == 9,
			"runs:base %d" % Save.tally("runs:base"))
	_ok("고른 다트통은 진도 쪽으로 온다",
			String(Save.get_pick("pack", "")) == "p_wage",
			"'%s'" % Save.get_pick("pack", ""))
	_ok("음량은 전역에 남는다",
			absf(float(Save.get_set("vol", 1.0)) - 0.31) < 0.001,
			"vol %s" % Save.get_set("vol", 1.0))
	#  두 번 안 옮긴다 — 2번으로 옮겨 놓고 다시 켜도 1번이 안 되살아난다
	Save.use_slot(2)
	Save.bump("wins", 1)
	Save.flush()
	Save._gloaded = false
	Save._gcfg = null
	Save._slot = 0
	_ok("옮기는 것은 한 번뿐", Save.slot() == 2 and Save.stat("wins") == 1,
			"슬롯 %d · 완주 %d" % [Save.slot(), Save.stat("wins")])

	# 뒷정리
	for i in range(1, Save.SLOTS + 1):
		Save.erase_slot(i)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.gpath))

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
