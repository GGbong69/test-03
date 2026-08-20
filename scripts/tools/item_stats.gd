extends SceneTree

const GameData = preload("res://scripts/data.gd")

# 아이템 표에 붙일 수치를 뽑는다. 임시 도구 — 뽑고 나면 지운다.
#
# 재는 것 둘
#   발동률   그 칩의 조건이 다트 한 발에서 걸릴 확률
#   기여     그 칩 한 장이 다트당 더해 주는 점수의 기대값
#
# 기여를 재는 이유는 가격과 나란히 놓기 위해서다. 조건이 넓고 값이 작은 칩과
# 조건이 좁고 값이 큰 칩을 같은 자로 재야 비싼 값을 하는지 알 수 있다.
# 보드 개조를 여덟으로 다시 짤 때 쓴 자와 같다 — "다트당 몇 점" 하나로 본다.
#
# 전제
#   개조 없는 기본 판. 칩은 한 장만 들었다고 본다(다른 칩과의 곱은 안 본다).
#   조준은 게이지가 훑는 사각형 위 균등분포다. 실제 사람은 가운데를 노리므로
#   중앙 조건(불·중물)은 여기 값보다 실제로 더 자주 걸리고, 가장자리 조건
#   (더블·띠쟁이)은 덜 걸린다. 그래서 이 표는 상한도 하한도 아닌 기준선이다.

const ROUNDS := 60000

func _initialize() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)

	var items: Array = GameData.items()
	var n := items.size()
	var fire := []          # 발동 횟수
	var gain := []          # 점수 기여 합
	fire.resize(n)
	gain.resize(n)
	fire.fill(0)
	gain.fill(0.0)

	var darts := 0
	var base_sum := 0.0
	var miss := 0

	for r in ROUNDS:
		var last_sec := -1
		var streak := 0
		var warm := false
		for d in 6:
			var p := Vector2(
					g.BC.x + randf_range(-g.SWING, g.SWING),
					g.BC.y + randf_range(-g.SWING, g.SWING))
			var info: Dictionary = g.hit_info(p)
			darts += 1
			var is_miss: bool = info.mult == 0
			if is_miss:
				miss += 1
			var same: bool = info.sector > 0 and info.sector == last_sec
			streak = streak + 1 if same else 0
			var ctx := {
				"sector": info.sector,
				"mult": info.mult,
				"miss": is_miss,
				"left": p.x < g.BC.x,
				"same": same,
				"first": d == 0,
				"last": d == 5,
				"streak": streak,
				"warm": warm,
			}
			var b: float = float(info.base)
			var m: float = float(info.mult)
			base_sum += b * m

			for i in n:
				var it: Dictionary = items[i]
				if not GameData.check(it.c, ctx):
					continue
				fire[i] += 1
				# 이 칩 한 장만 들었을 때 늘어나는 점수
				match String(it.k):
					"chip":
						gain[i] += float(it.v) * maxf(m, 1.0)
					"mult":
						gain[i] += b * float(it.v)
					"xmult":
						gain[i] += b * m * (float(it.v) - 1.0)
					"mult_streak":
						gain[i] += b * float(it.v) * float(streak)
			if info.mult == 3:
				warm = true
			last_sec = info.sector

	var f := FileAccess.open("D:/Workspace14/test-03/data/_stats.csv", FileAccess.WRITE)
	f.store_line("id,fire_pct,gain_per_dart,gain_per_gold")
	for i in n:
		var it: Dictionary = items[i]
		var fp: float = 100.0 * float(fire[i]) / float(darts)
		var gp: float = float(gain[i]) / float(darts)
		f.store_line("%s,%.2f,%.2f,%.2f" % [it.id, fp, gp, gp / float(it.cost)])
	f.close()

	print("다트 %d발 · 빗나감 %.1f%% · 무개조 판 다트당 기본 %.2f점"
			% [darts, 100.0 * float(miss) / float(darts), base_sum / float(darts)])
	quit()
