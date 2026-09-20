extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  기록 규약 — 챌린지 런과 무한 구간은 STATS·PEAKS 에 한 줄도 안 쓴다
#
#  실행:  godot --headless --path . --script scripts/tools/qa_recoff.gd
#  종료 코드 = 실패 개수
#
#  ⚠ **이 갈림길은 되돌릴 수 없다.** 최댓값은 안 내려가므로 무한·챌린지
#  수를 PEAKS 에 한 번 섞으면 고칠 방법이 없다 — 밸런스가 아니라 기록
#  규약의 문제라 기계가 지켜야 한다.
#
#  수로 적은 것 둘(설계가 근거로 든 자리):
#    · best_leg_bare(문턱 24) — 24판을 동전을 잔뜩 들고 넘긴 뒤 무한 25판에서
#      전부 팔고 **한 판만** 맨손으로 넘기면 25 >= 24 로 조건이 선다.
#      맨손 런을 한 번도 안 하고 열린다.
#    · best_gain(문턱 100000) — R14 보스 목표가 이미 867,480 이다.
#      넘긴 판은 자동으로 10만을 넘는다.
#
#  ⚠ 그리고 **완주 갈래 넷이 다 기록을 남기는가**를 같이 잰다. 그중 하나
#  (마지막 판에서 목숨이 터진 완주)는 여태 넉 줄뿐이라 화면에만 있고
#  기록에 없었다 — 손으로는 거의 못 밟는 갈래라 검사가 유일한 눈이다.
# ══════════════════════════════════════════════════════════

var g = null
var fails := 0
var done := false


func _initialize() -> void:
	Save.gpath = "user://_qa_recoff_g.cfg"
	Save.path = "user://_qa_recoff.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(nm: String, cond: bool, detail := "") -> void:
	print("  %s %-48s %s" % ["OK  " if cond else "실패", nm, detail])
	if not cond:
		fails += 1


func _snap() -> Dictionary:
	var out := {}
	for k in ["wins", "runs", "best_leg", "best_score", "best_gold",
			"best_gain", "best_leg_bare", "gold_earned", "boss_spare",
			"best_spare", "win_gold", "win_null", "revo_bull_leg"]:
		out[k] = Save.stat(String(k))
	out["해금"] = Save.unlock_keys().size()
	return out


func _diff(a: Dictionary, b: Dictionary) -> Array:
	var out := []
	for k in a:
		if a[k] != b[k]:
			out.append("%s %s→%s" % [k, str(a[k]), str(b[k])])
	return out


#  판 하나를 넘긴다. total 을 목표에 얹고 _finish_leg 을 지난다.
func _clear_leg(leg: int) -> void:
	g.leg_no = leg
	g.target = GameData.target_of(leg)
	g.total = g.target
	g.darts_left = 3
	g._finish_leg()


func _arm(chal: String, endless: bool) -> void:
	GameData.challenge = chal
	GameData.endless = endless
	GameData.league = "white"
	GameData.pack = "base"
	g._new_run()
	GameData.endless = endless          # _new_run 이 끈다 — 검사에서 다시 켠다
	g.owned.clear()


func _process(_d: float) -> bool:
	if done:
		return false
	done = true
	for i in 8:
		g._process(1.0 / 60.0)
	g._autoplay = false

	print("기록 규약 — 무엇이 저장에 남는가\n")

	# ── ① 본편은 그대로 남는다(기준선) ───────────────────
	print("① 본편 — 여태 그대로 남는다")
	_arm("", false)
	var a0 := _snap()
	_clear_leg(5)
	var a1 := _snap()
	_ok("판을 넘기면 최댓값이 오른다", a1.best_leg >= 5 and a1.best_score > 0,
			"판 %d · 점수 %d" % [a1.best_leg, a1.best_score])
	_ok("동전이 없으면 맨손 기록이 선다", a1.best_leg_bare >= 5,
			"맨손 %d" % a1.best_leg_bare)
	#  best_gain 은 **한 발**의 값이라 정산 걸음(_next_step)이 적는다 —
	#  판을 넘기는 것만으로는 안 선다. 그래서 여기서는 「문이 막는가」만 본다.
	_ok("한 발 점수의 문이 본편에서는 열려 있다",
			not g._rec_off(), "한 방 %d" % a1.best_gain)
	_ok("_rec_off() 가 거짓이다", not g._rec_off())

	# ── ② 챌린지 런은 한 톨도 안 민다 ────────────────────
	print("\n② 챌린지 런")
	_arm("blind", false)
	_ok("_rec_off() 가 참이다", g._rec_off())
	var b0 := _snap()
	_clear_leg(9)
	_clear_leg(12)
	g.gold = 300
	g._settle_clear()
	var b1 := _snap()
	var d1 := _diff(b0, b1)
	_ok("STATS·PEAKS 가 한 칸도 안 늘었다", d1.is_empty(), str(d1))
	#  해금 셋이 한 개도 안 연다
	g._pack_unlock_next()
	g._pack_unlock_check()
	g._league_unlock_next()
	_ok("해금 셋이 한 개도 안 연다",
			Save.unlock_keys().size() == int(b0["해금"]),
			"해금 %d → %d" % [b0["해금"], Save.unlock_keys().size()])
	#  완주하면 chal:<id> 한 줄만 선다
	_clear_leg(GameData.legs_n())
	_ok("완주가 화면에 선다", g.won and g.state == g.S.OVER)
	_ok("완주 표시 한 줄이 섰다", Save.unlocked("chal:blind"))
	_ok("그것 말고는 저장이 안 늘었다",
			Save.unlock_keys().size() == int(b0["해금"]) + 1,
			"해금 %d → %d" % [b0["해금"], Save.unlock_keys().size()])
	var b2 := _snap()
	_ok("완주해도 wins 가 안 는다", b2.wins == b0.wins,
			"wins %d → %d" % [b0.wins, b2.wins])
	#  무한 갈래가 선다 — 챌린지여도 완주는 완주다
	_ok("완주 화면에 무한 갈래가 선다", g.endless_ok)

	# ── ③ 무한 구간 ──────────────────────────────────────
	print("\n③ 무한 구간")
	_arm("", false)
	#  본편을 먼저 넘겨 기준을 만든다
	_clear_leg(GameData.legs_n())
	var c0 := _snap()
	_ok("본편 완주로 wins 가 하나 는다", c0.wins == a1.wins + 1,
			"wins %d → %d" % [a1.wins, c0.wins])
	#  이제 무한으로 잇는다 — 「무한 런」이 하는 그대로
	GameData.endless = true
	g.leg_no = GameData.legs_n() + 1
	g.endless_ok = false
	g.won = false
	_ok("_rec_off() 가 참이다", g._rec_off())
	#  ⚠ 동전을 다 팔고 무한 한 판만 맨손으로 넘겨 본다
	g.owned.clear()
	_clear_leg(25)
	#  ⚠ R14 보스를 넘겨 본다 — 목표가 이미 867,480 이다
	_clear_leg(42)
	var c1 := _snap()
	var d2 := _diff(c0, c1)
	_ok("STATS·PEAKS 가 한 칸도 안 늘었다", d2.is_empty(), str(d2))
	_ok("무한 25판을 맨손으로 넘겨도 best_leg_bare 가 안 오른다",
			c1.best_leg_bare == c0.best_leg_bare,
			"맨손 %d" % c1.best_leg_bare)
	#  ⚠ 한 발 점수도 같은 문을 지나는가 — **정산 걸음 안에 숨어 있어
	#  처음에 빠졌던 자리다.** 직접 밀어 본다.
	g._peak("best_gain", 999999)
	g._bump("bulls", 50)
	g._peak("clok_out_streak", 9)
	var c1b := _snap()
	_ok("무한에서는 한 발 점수도 안 선다",
			c1b.best_gain == c0.best_gain and Save.stat("bulls") == 0,
			"한 방 %d · 불 %d · R14 목표 %d"
					% [c1b.best_gain, Save.stat("bulls"), GameData.target_of(42)])
	#  세기 절에는 쌓인다
	_ok("무한 최고 판이 세기 절에 쌓인다", Save.tally("endless:leg") >= 42,
			"무한 판 %d" % Save.tally("endless:leg"))
	_ok("무한 최고 점수도 쌓인다", Save.tally("endless:score") > 0,
			"점수 %d" % Save.tally("endless:score"))
	#  무한 상단 — 승리를 다시 안 박는다
	var w0: int = Save.stat("wins")
	_clear_leg(GameData.endless_legs_n())
	_ok("무한 상단에서 런이 끝난다", g.state == g.S.OVER,
			"state %d" % g.state)
	_ok("wins 를 다시 안 박는다", Save.stat("wins") == w0,
			"wins %d → %d" % [w0, Save.stat("wins")])
	_ok("무한 상단에서는 갈래를 다시 안 세운다", not g.endless_ok)
	GameData.endless = false

	# ── ④ 마지막 판에서 목숨이 터진 완주 ─────────────────
	#  ⚠ 손으로는 거의 못 밟는 갈래다. 여태 넉 줄뿐이라 화면에만 있고
	#  기록에 없었다 — 챌린지 해금(wins>=1)도 무한 진입 제안도 이 순간에
	#  달려 있으므로 안 고치면 「완주했는데 챌린지가 안 열리고 무한도 안
	#  묻는다」가 된다.
	print("\n④ 마지막 판에서 목숨이 터진 완주")
	_arm("", false)
	var sv := {}
	for it in GameData.items():
		if String(it.get("k", "")) == "save":
			sv = it.duplicate()
			break
	if sv.is_empty():
		_ok("목숨 동전이 표에 있다", false, "못 찾음")
	else:
		sv.gs = 0
		g.owned = [sv]
		var e0 := _snap()
		g.leg_no = GameData.legs_n()
		g.target = GameData.target_of(g.leg_no)
		#  목표에 **못 미친다.** 목숨이 터져 완주로 친다.
		g.total = int(float(g.target) * float(sv.v) / 100.0)
		g.darts_left = 0
		g._finish_leg()
		var e1 := _snap()
		_ok("완주 화면이 선다", g.won and g.state == g.S.OVER)
		_ok("wins 가 하나 는다", e1.wins == e0.wins + 1,
				"wins %d → %d" % [e0.wins, e1.wins])
		_ok("완주 최댓값이 선다", e1.win_gold >= 0 and Save.has_stat("win_items"))
		_ok("무한 갈래가 선다", g.endless_ok)
		_ok("이긴 런이 「계속하기」로 안 되살아난다", not Save.run_live())

	GameData.challenge = ""
	GameData.endless = false
	print("\n%s" % ("전부 통과" if fails == 0 else "실패 %d건" % fails))
	quit(mini(fails, 125))
	return true
