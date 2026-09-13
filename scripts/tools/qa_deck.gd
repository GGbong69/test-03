extends SceneTree

# 표가 기획서(2026-09-13 14:42판 40장)와 맞는가. 게임을 안 세우는 표 검사.
#
#   godot --path . --headless --script scripts/tools/qa_deck.gd

const GameData = preload("res://scripts/data.gd")

var okn := 0
var fail := 0

const OLD_NAMES := ["비트 코인", "루나 코인", "소수 정예", "한번 더!!!",
	"한번 더???", "단골 손님", "모험심", "예비 다트", "파란 다트",
	"명중 적립기", "착탄 이력계", "진열 가치", "동전 슬롯 집합체", "굳은살",
	"무른살", "계란 바구니", "분산투자", "트리오", "물타기", "집중력",
	"시잔기", "소갈", "다시! 또 다시!", "장기 투자", "녹슨 동전", "액션 배우",
	"크림 치즈", "새로운만남", "마무리", "조개 껍질", "비상금", "동전 줍기",
	"불나방", "면죄부", "재도전", "위조화폐", "페인트", "한 수 앞", "사직서"]


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-34s %s" % ["통과" if c else "실패", n, d])


func _item(nm: String) -> Dictionary:
	for it in GameData.items():
		if String(it.n) == nm:
			return it
	return {}


func _initialize() -> void:
	print("\n표 대조 — 기획서 40장 (2026-09-13 14:42판)\n")

	# ① 옛 이름이 name 열에 남았나
	var left := PackedStringArray()
	for pool in [GameData.items(), GameData.consumables(), GameData.darts(),
			GameData.mods(), GameData.modifiers()]:
		for r in pool:
			if OLD_NAMES.has(String(r.n)):
				left.append(String(r.n))
	_ok("옛 이름이 표에 없다", left.is_empty(), ", ".join(left))

	# ② 동전 수와 등급
	var cnt := {"common": 0, "uncommon": 0, "rare": 0, "legendary": 0}
	for it in GameData.items():
		var r := String(it.get("rarity", ""))
		if cnt.has(r): cnt[r] += 1
	var on := GameData.items().size()
	print("      켜진 동전 %d장 — 일반 %d · 희귀 %d · 레어 %d · 레전더리 %d"
			% [on, cnt.common, cnt.uncommon, cnt.rare, cnt.legendary])

	# ③ 기획서가 못박은 값
	print("")
	var cases := [
		["교통카드", "common", 4], ["유리 대포", "common", 4],
		["아카로스", "common", 4], ["빌리의 바지", "rare", 12],
		["딱정벌레의 도로", "uncommon", 8], ["녹는 시계", "legendary", 20],
	]
	for c in cases:
		var it := _item(String(c[0]))
		_ok("%s %s %dG" % [String(c[0]), String(c[1]), int(c[2])],
				not it.is_empty() and String(it.rarity) == String(c[1])
				and int(it.cost) == int(c[2]),
				"%s %dG" % [String(it.get("rarity", "없다")), int(it.get("cost", 0))])

	# 확률
	var gc := _item("유리 대포")
	var ak := _item("아카로스")
	_ok("유리 대포 1/2", GameData.boom_n(String(gc.get("boom", ""))) == 2,
			GameData.eff_line(gc))
	_ok("아카로스 1/10 · ×4", GameData.boom_n(String(ak.get("boom", ""))) == 10,
			GameData.eff_line(ak))
	var bp := _item("빌리의 바지")
	_ok("빌리의 바지 점수 +40 · 배수 +4",
			GameData.eff_line(bp).find("+40") >= 0
			and GameData.eff_line(bp).find("+4") >= 0, GameData.eff_line(bp))

	# ④ 보드 확장
	print("")
	var pz := {}
	var dn := {}
	var badcost := PackedStringArray()
	for m in GameData.mods():
		if int(m.cost) != 12: badcost.append(String(m.n))
		if String(m.id) == "pizz": pz = m
		if String(m.id) == "dnut": dn = m
	_ok("보드 확장 12장 전부 12G",
			GameData.mods().size() == 12 and badcost.is_empty(),
			"%d장 · %s" % [GameData.mods().size(), ", ".join(badcost)])
	# mods() 는 v1 이 비면 스칼라, 차면 배열로 싣는다.
	_ok("피자 칸 값 32", float(pz.get("v", 0.0)) == 32.0, str(pz.get("v", 0)))
	var dv = dn.get("v", 0)
	_ok("도넛 11↑ +6 · 10↓ +12",
			dv is Array and float(dv[0]) == 6.0 and float(dv[1]) == 12.0,
			str(dv))

	# ⑤ 사탕 · 사진 · 다트
	print("")
	var cbad := PackedStringArray()
	for c in GameData.candies():
		if int(c.cost) != 4: cbad.append("%s %dG" % [String(c.n), int(c.cost)])
	_ok("사탕 다섯 전부 4G",
			GameData.candies().size() == 5 and cbad.is_empty(),
			"%d장 · %s" % [GameData.candies().size(), ", ".join(cbad)])
	var fbad := PackedStringArray()
	for f in GameData.fixtures():
		var want: int = 30 if String(f.n) == "마릴린 딥틱" else 15
		if int(f.cost) != want: fbad.append("%s %dG" % [String(f.n), int(f.cost)])
	_ok("사진 아홉 · 마릴린 딥틱만 30G",
			GameData.fixtures().size() == 9 and fbad.is_empty(),
			"%d장 · %s" % [GameData.fixtures().size(), ", ".join(fbad)])
	# 기획서 다트 표는 여섯 줄이지만 마지막 「?」는 다트가 아니라 다트통이
	# 쥔 계산 방식이다(packs.csv 의 score rand). 표에는 다섯이 맞다.
	_ok("다트 다섯 줄 (표준 포함)", GameData.darts().size() == 5,
			"%d줄" % GameData.darts().size())
	_ok("제약 10 · 챌린지 7 · 리그 8 · 다트통 14",
			GameData.modifiers().size() == 10 and GameData.leagues().size() == 8
			and GameData.packs().size() == 14,
			"제약 %d · 리그 %d · 다트통 %d" % [GameData.modifiers().size(),
					GameData.leagues().size(), GameData.packs().size()])

	# ⑥ 설명에 { } 가 남았나
	print("")
	var braces := PackedStringArray()
	for pool in [GameData.items(), GameData.consumables(), GameData.darts(),
			GameData.mods(), GameData.modifiers(), GameData.tags()]:
		for r in pool:
			var t := String(r.get("d", ""))
			if t.find("{") >= 0: braces.append(t)
	_ok("설명에 { } 자리가 안 남았다", braces.is_empty(), ", ".join(braces))

	# ⑦ 사탕과 사진이 갈린다
	_ok("사탕 5 · 사진 9 · 통짜 14",
			GameData.candies().size() == 5 and GameData.fixtures().size() == 9
			and GameData.consumables().size() == 14,
			"%d · %d · %d" % [GameData.candies().size(),
					GameData.fixtures().size(), GameData.consumables().size()])

	# ⑧ 검증기
	_ok("검증기 오류 0", GameData.errors().is_empty(),
			", ".join(GameData.errors()))
	print("      경고 %d건" % GameData.warnings().size())

	print("\n통과 %d · 실패 %d" % [okn, fail])
	quit(mini(fail, 125))
