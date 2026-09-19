extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  해금 열쇠 — 개발용
#
#  열기:  godot --path . --headless --quit-after 60 --script scripts/tools/unlock.gd
#  잠그기: godot --path . --headless --quit-after 60 --script scripts/tools/unlock.gd -- lock
#  보기:  ... -- list
#
#  발견(컬렉션) — 절이 다르므로 갈래도 따로다. 2026-09-19
#    ... -- found     [발견] 절을 109개로 채운다
#    ... -- unfound   [발견] 절을 지운다(_v 는 남긴다 — 빗장이다)
#
#  ⚠ **기획서 그림은 이 도구로 열지 않는다.** 그림 도구들은 저마다 Save.path
#  를 제 자리로 박고 g._dev_unlock_all() 한 줄로 그리는 쪽만 덮으므로,
#  사람의 저장을 지날 일이 없다.
#
#  **게임은 이 파일을 안 부른다.** tools/ 안의 다른 것들처럼 --script 로만
#  돈다. 진짜 저장(user://highton.cfg)을 건드리므로 프로브처럼 Save.path
#  를 옮기지 않는다 — 옮기면 아무 일도 안 일어난다.
#
#  win: 키는 안 심는다. 그것은 "이 단을 완주했다" 는 기록이라, 열어 주는
#  것과 다르다. 사다리의 완주 표시는 실제로 넘긴 단만 켜져 있어야 한다.
#
#  제출본에는 영향이 없다 — 저장은 user:// 라 사람마다 따로다.
# ══════════════════════════════════════════════════════════


func _say(n: int, what: String) -> void:
	print("  %s %d개" % [what, n])


func _list() -> void:
	var keys := Save.unlock_keys()
	print("심어 둔 해금 %d개" % keys.size())
	for k in keys:
		print("  %s" % k)
	print("")
	print("다트통")
	var pr := GameData.packs()
	for i in pr.size():
		var id := String(pr[i].get("id", ""))
		var on: bool = i == 0 or Save.unlocked("pack:" + id)
		print("  %s %-8s %s" % ["●" if on else "○", id, pr[i].get("name", "")])
	print("리그")
	var sr := GameData.leagues()
	for i in sr.size():
		var id := String(sr[i].get("id", ""))
		var on: bool = i == 0 or Save.unlocked(GameData.league_key(id))
		var won: bool = Save.unlocked(GameData.win_key(id))
		print("  %s %-8s %s%s" % ["●" if on else "○", id, sr[i].get("name", ""),
				"  (완주)" if won else ""])
	#  발견은 [해금]과 **다른 절**이라 위 「심어 둔 해금 N개」에 안 섞인다 —
	#  프로필 화면의 「해금 N개」(slot_info)도 같은 이유로 안 변한다.
	print("")
	print("발견 %d개" % _found_n())


#  여섯 탭의 표를 훑어 센다. found_keys().size() 로 세면 표에서 빠진 id 가
#  저장에 남아 있을 때 109보다 큰 수가 나오고, "_v" 한 줄까지 같이 세어진다.
func _found_n() -> int:
	var n := 0
	for s in _six():
		for r in s[1]:
			if Save.found(String(s[0]) + ":" + String(r.get("id", ""))):
				n += 1
	return n


#  갈래 접두사 다섯. **game.gd 의 COL_TABS.f 와 같은 낱말이다** — 한 곳에서
#  못 내므로(도구는 게임을 안 올린다) 여기 적는 다섯 낱말이 그쪽과 짝이라는
#  것을 주석에 남긴다. 사탕과 사진은 consumables() 한 번이면 둘 다 든다 —
#  접두사가 하나(cons:)라 갈래를 안 가른다.
func _six() -> Array:
	return [["item", GameData.items()], ["mod", GameData.mods()],
			["dart", GameData.darts()], ["cons", GameData.consumables()],
			["modf", GameData.modifiers()]]


func _initialize() -> void:
	#  진짜 저장을 고치는 유일한 도구다 — 도구 실행을 도구 자리로 돌리는 막(Save._tool_run)을 연다.
	Save.allow_real = true
	var args := OS.get_cmdline_user_args()
	if args.has("list"):
		_list()
		quit(0)
		return

	var packs := GameData.packs()
	var leagues := GameData.leagues()
	var n := 0

	#  ── 발견(컬렉션) ─────────────────────────────────────
	#  [해금]을 한 글자도 안 건드린다 — 절이 다르다. 팩 풀이 읽는 itemgot:
	#  은 위 「열기/잠그기」가 쥐고, 이쪽은 컬렉션만 쥔다.
	if args.has("unfound"):
		Save.unfound_all()          # 절을 지우고 _v 를 다시 세운다(이주 빗장)
		_say(0, "발견을 지웠다 — 남은")
		print("")
		_list()
		quit(0)
		return
	if args.has("found"):
		for s in _six():
			for r in s[1]:
				if Save.discover(String(s[0]) + ":" + String(r.get("id", ""))):
					n += 1
		Save.found_ready_set()      # 이주가 다시 안 돌게 빗장을 세운다
		Save.flush()                # discover() 는 flush 를 안 한다 — 여기서 친다
		_say(n, "새로 발견")
		print("")
		_list()
		quit(0)
		return

	if args.has("lock"):
		# 자연 상태로 되돌린다 — 완주 기록(win:)은 남긴다. 그것은 심은 것이
		# 아니라 실제로 넘긴 흔적이다.
		for k in Save.unlock_keys():
			var key := String(k)
			if key.begins_with("league:") or key.begins_with("pack:"):
				if Save.lock(key):
					n += 1
		_say(n, "지운 해금")
	else:
		# 첫 행은 늘 열려 있으므로 키를 안 심는다 — 심으면 저장에
		# 아무도 안 읽는 줄이 하나 는다.
		for i in range(1, packs.size()):
			if Save.unlock("pack:" + String(packs[i].get("id", ""))):
				n += 1
		# 리그은 다트통마다 따로 뚫린다. 모든 다트통 × 모든 단을 연다.
		for p in packs:
			var pid := String(p.get("id", ""))
			for i in range(1, leagues.size()):
				if Save.unlock(GameData.league_key(String(leagues[i].get("id", "")), pid)):
					n += 1
		_say(n, "새로 연 것")

	print("")
	_list()
	quit(0)
