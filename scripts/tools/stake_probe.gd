extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  판돈 8단 회귀 검사
#
#  실행:  godot --path . --headless --quit-after 600 --script scripts/tools/stake_probe.gd
#  종료 코드 = 실패 개수
#
#  판돈은 표도 배관도 오래 전부터 있었는데 스위치를 켜는 손이 없었다 —
#  game.gd 에 `GameData.stake =` 대입이 0건이라 antes.csv 의 곡선 두 열이
#  통째로 죽어 있었다. 그런 자리는 한 번 살려 두면 조용히 다시 죽으므로
#  여기서 못 박는다.
#
#  재는 것
#    ① 곡선 — 판돈을 올리면 목표가 오른다. base 는 안 움직인다
#    ② 계단 — 여덟 단이 순서대로 서고 선행이 바로 앞 단이다
#    ③ 미는 값 — 봉인·다트·보상·가격이 표대로 나온다
#    ④ 모르는 id 는 첫 단으로 떨어진다 (옛 저장이 게임을 안 깬다)
# ══════════════════════════════════════════════════════════

var fails := 0


func _say(ok: bool, name: String, detail := "") -> void:
	print("  %s %-28s %s" % ["OK  " if ok else "실패", name, detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	var rows := GameData.stakes()
	_say(rows.size() == 8, "판돈 여덟 단", "%d단" % rows.size())

	# ① 곡선 — 마지막 앤티의 보스 판(24판)으로 잰다
	var last: int = GameData.rounds_n()
	GameData.stake = ""
	var t_white := GameData.target_of(last)
	GameData.stake = "green"
	var t_green := GameData.target_of(last)
	GameData.stake = "purple"
	var t_purple := GameData.target_of(last)
	_say(t_green > t_white and t_purple > t_green, "곡선이 단마다 가팔라진다",
			"흰 %d < 초록 %d < 보라 %d" % [t_white, t_green, t_purple])

	# 붉은 판돈은 곡선이 base 다 — 여유만 깎고 목표는 그대로여야 한다
	GameData.stake = "red"
	_say(GameData.target_of(last) == t_white, "붉은 단은 곡선을 안 건드린다",
			"목표 %d" % GameData.target_of(last))

	# ② 계단 — 선행이 바로 앞 단이다
	var chain := true
	for i in rows.size():
		var pq := String(rows[i].get("prereq", ""))
		var want := "" if i == 0 else String(rows[i - 1].get("id", ""))
		if pq != want:
			chain = false
	_say(chain, "선행이 바로 앞 단이다",
			"%s → … → %s" % [rows[0].get("name", ""), rows[rows.size() - 1].get("name", "")])

	# ③ 미는 값 — 표에 적힌 대로 나온다
	GameData.stake = "red"
	_say(int(GameData.stake_v("reward_small", 9)) == 0,
			"붉은 단은 작은 판 보상이 0", "%d" % int(GameData.stake_v("reward_small", 9)))
	GameData.stake = "black"
	_say(int(GameData.stake_v("seal_items", 0)) == 1,
			"검정 단은 스티커를 봉인한다", "%d장" % int(GameData.stake_v("seal_items", 0)))
	GameData.stake = "blue"
	_say(int(GameData.stake_v("darts_add", 0)) == -1,
			"파랑 단은 다트를 깎는다", "%+d발" % int(GameData.stake_v("darts_add", 0)))
	GameData.stake = "gold"
	var costly: bool = GameData.stake_v("shop_cost_mul", 1.0) > 1.0 \
			and int(GameData.stake_v("rent", 0)) > 0 \
			and int(GameData.stake_v("perish", 0)) > 0
	_say(costly, "금 단은 값·자릿세·삭음을 다 얹는다",
			"×%.2f · 자릿세 %d · 삭음 %d판" % [GameData.stake_v("shop_cost_mul", 1.0),
			int(GameData.stake_v("rent", 0)), int(GameData.stake_v("perish", 0))])

	# ④ 모르는 id — 옛 저장이 게임을 안 깨야 한다
	GameData.stake = "nosuch"
	var fb := GameData.stake_row()
	_say(String(fb.get("id", "")) == String(rows[0].get("id", ""))
			and GameData.target_of(last) == t_white,
			"모르는 판돈은 첫 단으로 떨어진다", String(fb.get("name", "")))

	GameData.stake = ""
	print("\n%s" % ("실패 %d건" % fails if fails > 0 else "아홉 검사 전부 통과"))
	quit(mini(fails, 125))
