extends SceneTree

const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")

# ══════════════════════════════════════════════════════════
#  장시간 소크 — 런을 계속 돌려 드물게만 밟는 갈래를 밟아 본다
#
#  실행:  godot --path . --headless --quit-after 900000 \
#             -s scripts/tools/soak.gd -- autoplay [시드]
#  종료 코드 = 0. 판정은 로그의 SCRIPT ERROR 를 세서 한다.
#
#  프로브들은 저마다 한 가지를 겨눈다. 이것은 겨누지 않는다 — 오래 돌려서
#  엔진이 비명을 지르는지만 본다. 배열 밖 색인·0 나누기·없는 열처럼
#  "그 판에서만" 나는 것들은 표적 검사로는 안 걸리고 시간으로 걸린다.
# ══════════════════════════════════════════════════════════

const STEPS := 600

var g: Node = null
var frames := 0
var runs := 0
var last_state := -1
var lands := 0
var pack_want := ""


func _initialize() -> void:
	Save.path = "user://_probe_soak.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	var a := OS.get_cmdline_user_args()
	var sd := 20260902
	var pk := ""
	for t in a:
		if String(t).is_valid_int():
			sd = int(t)
		elif String(t).begins_with("p_") or String(t) == "base":
			pk = String(t)
	# 팩을 박아 두는 자리. 기본 팩만 돌면 다트 수·칸 수·이자를 미는
	# 갈래가 통째로 안 밟힌다 — 「기본에서 줄어든 다트」 버그가 그랬다.
	if pk != "":
		GameData.pack = pk
	pack_want = pk
	seed(sd)
	print("소크 시드 %d · 팩 %s" % [sd, pk if pk != "" else "(저장값)"])


func _process(_d: float) -> bool:
	frames += 1
	if frames == 2:
		g.beat = 0.015
		g.gauge_speed = 8.0
		g.confirm_hold = 0.0
	g.set_process(false)
	for _i in STEPS:
		g._process(1.0 / 60.0)
		if g.state == g.S.OVER and last_state != g.state:
			runs += 1
			if pack_want != "":
				GameData.pack = pack_want   # 새 런이 저장값으로 되돌리는 것을 막는다
		last_state = g.state
	lands = int(g.land_n)
	if frames % 40 == 0:
		print("  … 런 %d · 다트 %d · 라운드 %d" % [runs, lands, g.round_no])
	if runs >= 30:
		print("\n소크 끝 — 런 %d회 · 다트 %d발" % [runs, lands])
		quit(0)
	return false
