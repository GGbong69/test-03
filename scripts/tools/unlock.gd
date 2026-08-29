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
#  **게임은 이 파일을 안 부른다.** tools/ 안의 다른 것들처럼 --script 로만
#  돈다. 진짜 저장(user://hightone.cfg)을 건드리므로 프로브처럼 Save.path
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
	print("팩")
	var pr := GameData.packs()
	for i in pr.size():
		var id := String(pr[i].get("id", ""))
		var on: bool = i == 0 or Save.unlocked("pack:" + id)
		print("  %s %-8s %s" % ["●" if on else "○", id, pr[i].get("name", "")])
	print("리그")
	var sr := GameData.stakes()
	for i in sr.size():
		var id := String(sr[i].get("id", ""))
		var on: bool = i == 0 or Save.unlocked(GameData.stake_key(id))
		var won: bool = Save.unlocked(GameData.win_key(id))
		print("  %s %-8s %s%s" % ["●" if on else "○", id, sr[i].get("name", ""),
				"  (완주)" if won else ""])


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("list"):
		_list()
		quit(0)
		return

	var packs := GameData.packs()
	var stakes := GameData.stakes()
	var n := 0

	if args.has("lock"):
		# 자연 상태로 되돌린다 — 완주 기록(win:)은 남긴다. 그것은 심은 것이
		# 아니라 실제로 넘긴 흔적이다.
		for k in Save.unlock_keys():
			var key := String(k)
			if key.begins_with("stake:") or key.begins_with("pack:"):
				if Save.lock(key):
					n += 1
		_say(n, "지운 해금")
	else:
		# 첫 행은 늘 열려 있으므로 키를 안 심는다 — 심으면 저장에
		# 아무도 안 읽는 줄이 하나 는다.
		for i in range(1, packs.size()):
			if Save.unlock("pack:" + String(packs[i].get("id", ""))):
				n += 1
		# 리그은 팩마다 따로 뚫린다. 모든 팩 × 모든 단을 연다.
		for p in packs:
			var pid := String(p.get("id", ""))
			for i in range(1, stakes.size()):
				if Save.unlock(GameData.stake_key(String(stakes[i].get("id", "")), pid)):
					n += 1
		_say(n, "새로 연 것")

	print("")
	_list()
	quit(0)
