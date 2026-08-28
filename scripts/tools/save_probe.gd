extends SceneTree

const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")

# ══════════════════════════════════════════════════════════
#  저장 회귀 검사
#
#  실행:  godot --path . --headless -s scripts/tools/save_probe.gd
#         godot --path . --headless -s scripts/tools/save_probe.gd -- pass2
#         godot --path . --headless -s scripts/tools/save_probe.gd -- pass3
#  종료 코드 = 실패 개수. **세 차수를 이 순서로 돌려야 한다** (1차가 쓴 것을
#  2차가 읽는다). 3차는 앞 둘과 독립이고 저장을 지우고 시작한다.
#
#  **두 번 돌려야 진짜 검사다.** 한 프로세스 안에서 쓰고 읽는 것은
#  ConfigFile 이 메모리에 들고 있는 값을 다시 보는 것뿐이라, 디스크에
#  안 닿아도 통과한다. 그래서 1차가 쓰고 죽고, 2차가 새 프로세스에서
#  읽는다. 저장이 없던 시절의 증상(창을 닫으면 음량이 1.0 으로 돌아온다)이
#  정확히 이 경계에서만 보였다.
#
#  보는 것
#    1차 — 깨끗한 상태에서 쓰기 · 누적 · 최댓값 · 해금 · 모르는 키 거부
#    2차 — 프로세스가 바뀐 뒤에도 값이 그대로인가 · 깨진 파일로 안 죽는가
#    3차 — 게임을 세워 실제로 던져서, 통계 훅이 **모든 발**을 세는가
# ══════════════════════════════════════════════════════════

var fails := 0


func _say(ok: bool, name: String, detail := "") -> void:
	print("  %s %-34s %s" % ["OK  " if ok else "실패", name, detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	# 진짜 저장은 안 건드린다 — 이 검사는 지우고 깨뜨리는 것이 일이라,
	# 플레이어 파일을 쓰면 검사 한 번에 해금과 통계가 날아간다.
	Save.path = "user://_probe.cfg"
	var pass2 := false
	var pass3 := false
	for a in OS.get_cmdline_user_args():
		if String(a) == "pass2":
			pass2 = true
		elif String(a) == "pass3":
			pass3 = true

	if pass3:
		_pass3()
	elif pass2:
		_pass2()
	else:
		_pass1()
	print("\n%s" % ("실패 %d건" % fails if fails > 0 else "전부 통과"))
	quit(mini(fails, 125))


func _pass1() -> void:
	print("1차 — 쓴다  (%s)" % ProjectSettings.globalize_path(Save.path))
	Save.wipe()
	_say(Save.stat("darts") == 0 and not Save.unlocked("pack:mag"),
			"지운 뒤에는 전부 기본값", "darts %d" % Save.stat("darts"))

	# 설정
	Save.set_set("vol", 0.35)
	Save.set_set("fullscreen", true)

	# 누적
	for i in 7:
		Save.bump("darts")
	Save.bump("triples", 3)
	_say(Save.stat("darts") == 7 and Save.stat("triples") == 3,
			"누적이 더해진다", "darts %d · triples %d"
			% [Save.stat("darts"), Save.stat("triples")])

	# 최댓값 — 작은 값은 안 덮는다
	Save.peak("best_score", 120)
	Save.peak("best_score", 90)
	_say(Save.stat("best_score") == 120, "최댓값은 안 내려간다",
			"120 뒤 90 → %d" % Save.stat("best_score"))

	# 모르는 키는 조용히 사라지지 않고 소리를 낸다
	Save.bump("없는키")
	_say(Save.stat("없는키") == 0, "모르는 통계 키는 거부한다 (에러 한 줄이 위에 뜬다)")
	Save.peak("darts", 99)
	_say(Save.stat("darts") == 7, "누적 키에 peak 을 못 쓴다", "darts %d" % Save.stat("darts"))

	# 해금 — 처음 열 때만 true
	var a := Save.unlock("pack:mag")
	var b := Save.unlock("pack:mag")
	Save.unlock("stake:green")
	_say(a and not b, "해금은 처음 한 번만 새것이다", "1회 %s · 2회 %s" % [a, b])
	var packs := Save.unlocked_of("pack")
	_say(packs.size() == 1 and packs[0] == "mag", "갈래별로 훑는다",
			"pack: %s · stake: %s" % [packs, Save.unlocked_of("stake")])

	Save.flush()
	_say(Save.last_error() == "", "쓰기가 실패하지 않았다", Save.last_error())


func _pass2() -> void:
	print("2차 — 새 프로세스에서 읽는다")
	_say(is_equal_approx(float(Save.get_set("vol", 1.0)), 0.35),
			"음량이 살아남았다", "%.2f" % float(Save.get_set("vol", 1.0)))
	_say(bool(Save.get_set("fullscreen", false)) == true, "전체화면이 살아남았다")
	_say(Save.stat("darts") == 7 and Save.stat("triples") == 3,
			"통계가 살아남았다", "darts %d · triples %d"
			% [Save.stat("darts"), Save.stat("triples")])
	_say(Save.stat("best_score") == 120, "최댓값이 살아남았다",
			"%d" % Save.stat("best_score"))
	_say(Save.unlocked("pack:mag") and Save.unlocked("stake:green"),
			"해금이 살아남았다", "pack %s · stake %s"
			% [Save.unlocked_of("pack"), Save.unlocked_of("stake")])
	_say(not Save.unlocked("pack:없는것"), "안 연 것은 안 열려 있다")

	# 깨진 파일로 게임이 죽지 않는다 — 쓰레기를 써 놓고 새로 읽힌다.
	var f := FileAccess.open(Save.path, FileAccess.WRITE)
	if f != null:
		f.store_string("이건 설정 파일이 아니다 [[[ = = ] ] ]\n= 3 ㅋ")
		f.close()
	Save._loaded = false
	Save._cfg = null
	var v: Variant = Save.get_set("vol", 1.0)
	_say(is_equal_approx(float(v), 1.0),
			"깨진 파일이면 기본값으로 산다", "vol %.2f · 사유 '%s'"
			% [float(v), Save.last_error()])


# 3차 — 통계 훅이 **모든 발**을 세는가.
#  1·2차는 저장 계층만 본다. 여기서는 게임을 세워 실제로 던진다.
#  이 검사가 없으면 "훅이 어딘가 이른 return 뒤에 있어서 절반만 세더라" 를
#  못 잡는다. 해금 조건이 통계를 읽을 것이므로 이건 밸런스가 아니라 정확성이다.
func _pass3() -> void:
	print("3차 — 게임을 세워 실제로 던진다")
	Save.wipe()
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g._new_run()                        # runs +1
	g.state = g.S.AIM_V
	g.owned = []
	g._panel_reset()
	g.remaining = [GameData.darts()[0]]
	g.cur_dart = GameData.darts()[0]
	g.darts_left = 999
	g.round_darts = 999

	# 판 안 12시(싱글) 10발 · 판 밖 4발. 큐는 매번 비우고 던진다 —
	# _land 는 큐에 쌓기만 하고 정산은 _next_step 이 한다.
	var inside := 10
	var outside := 4
	for i in inside:
		g.aim = g.BC + Vector2(0.0, -1.0) * g.R * 0.35
		g.queue = []
		g._land()
	for i in outside:
		g.aim = g.BC + Vector2(0.0, -1.0) * g.R * 1.25
		g.queue = []
		g._land()
	Save.flush()

	_say(Save.stat("darts") == inside + outside, "던진 발을 하나도 안 빠뜨린다",
			"%d 발 던져 %d 셈" % [inside + outside, Save.stat("darts")])
	_say(Save.stat("misses") == outside, "빗나감을 정확히 센다",
			"%d 발 판 밖 → %d" % [outside, Save.stat("misses")])
	_say(Save.stat("runs") == 1, "런 시작이 세어진다", "runs %d" % Save.stat("runs"))
