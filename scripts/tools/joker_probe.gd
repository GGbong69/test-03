extends SceneTree

const GameData = preload("res://scripts/data.gd")

# ══════════════════════════════════════════════════════════
#  조커 이식 표적 검사 — 무작위 소크가 못 보장하는 길을 직접 걷는다
#
#  실행:  godot --path . --headless --quit-after 60000 -s scripts/tools/joker_probe.gd -- autoplay
#
#  -s 실행은 _ready 가 첫 프레임에야 돌므로, 오토플레이 설정은 인자로 넘기고
#  조커 장착은 둘째 프레임에 한다 — 여기서 미리 만지면 _ready 가 덮어쓴다.
#
#  성장(gs)·이중 효과(k2)·숫자 지정(sec)·목숨(save)·파괴(boom/rdec)·
#  다트 증감(dadd)·즉시 골드(risk50)·영역 승급(side) 을 쥔 채로
#  오토플레이를 여러 라운드 돌리고, 스크립트 오류 없이 상태가 앞으로
#  가는지와 성장값이 실제로 움직였는지를 본다.
# ══════════════════════════════════════════════════════════

var g: Node = null
var frames := 0
var fails := 0
var gs_seen := false          # 성장값이 한 번이라도 0을 벗어났는가
var boom_start := 0           # 파괴 후보를 쥔 개수 — 줄면 파괴가 산 것이다
var runs := 0

const PICKS := ["j024", "j029", "j040", "j058", "j099", "j138",
		"j089", "j036", "j115", "j005", "j046"]


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20260823)


func _arm() -> void:
	g.owned.clear()
	for id in PICKS:
		for it in GameData.items():
			if String(it.id) == id:
				var cp: Dictionary = it.duplicate()
				cp.gs = 0
				g.owned.append(cp)
	boom_start = g.owned.size()
	runs += 1


func _ok(name: String, cond: bool, detail: String) -> void:
	print("  %s %-24s %s" % ["OK  " if cond else "실패", name, detail])
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	frames += 1
	if frames == 2:
		_arm()
	g.set_process(false)
	g._process(1.0 / 60.0)
	for o in g.owned:
		if int(o.get("gs", 0)) != 0:
			gs_seen = true
	# 런이 끝나 타이틀로 돌아오면 오토플레이가 새 런을 연다 — 그때 다시 쥔다
	if g.state == g.S.SHOP and g.owned.size() < 4:
		_arm()
	if frames == 3000:
		_ok("성장값이 움직인다", gs_seen, "gs_seen %s" % gs_seen)
		_ok("상태가 앞으로 간다", g.round_no >= 1 and runs >= 1,
				"라운드 %d · 런 %d" % [g.round_no, runs])
		_ok("골드가 셈에 남아 있다", g.gold >= 0, "골드 %d" % g.gold)
		var amt_ok := true
		# item_amt 가 새 모양 전부에서 답을 내는지 — 대표 문맥 하나로 훑는다
		var ctx := {"streak": 1, "darts_left": 3, "items_n": 4, "gold": 20,
				"mag_hvy": 2, "round_darts": 4, "low": 5, "zonehist": 2,
				"empty_n": 2, "rackval_others": 6, "rand01": 0.5,
				"sector": 4, "mult": 2, "miss": false}
		for it in GameData.items():
			var v := GameData.item_amt(it, ctx)
			if v < 0:
				amt_ok = false
				print("       음수 수량: %s %d" % [it.id, v])
		_ok("수량이 음수로 안 떨어진다", amt_ok, "%d종 훑음" % GameData.items().size())
		print("%d프레임 · 런 %d회 — %s" % [frames, runs,
				"네 검사 전부 통과" if fails == 0 else "실패 %d" % fails])
		quit(1 if fails > 0 else 0)
	return false
