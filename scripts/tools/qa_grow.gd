extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  성장형 동전 QA — "자란 값이 그 정산에 실리는가"
#
#  실행:  godot --path . --headless --quit-after 540000 \
#             --script scripts/tools/qa_grow.gd -- autoplay
#  종료 코드 = 실패 개수
#
#  **창을 넉넉히 줘야 한다.** 한 장을 phase_len(8000)프레임씩 붙잡고 보므로
#  성장형 여섯이면 48000프레임이다. 3분짜리 창에서는 중간에 잘리는데, 판정을
#  끝에 몰아 찍는 구조라 잘리면 **아무것도 안 나온다** — 통과와 구별이 안 된다.
#  짧게 보려면 frames=2000 처럼 걸음을 줄여서 부른다.
#
#  qa_items 는 "값이 0 에서 움직였다" 까지만 본다. 그것만으로는 방향도 폭도
#  모르고, 무엇보다 **자란 값이 점수에 실리는지**를 못 본다. 여기서는 정산
#  큐에 실제로 들어간 수를 그때의 성장값과 맞대 본다.
#
#  발라트로 어법과 맞춰 보는 것 셋
#    ① 발동하면 자라고 **자란 값이 그 발에 실린다** (게임: 먼저 올리고 낸다)
#    ② 성장은 판을 넘어 이어진다 (gs 는 살 때만 0 이 된다)
#    ③ 닳는 것은 0 에 닿으면 부서진다 (rdec) — tdec 은 어떤가를 같이 본다
#
#  item_amt 의 식
#    fire·hitmiss   수량 = gs        (게임이 gs 에 gstep 을 더한다)
#    tdec·rdec      수량 = max(0, v − gstep × gs)
# ══════════════════════════════════════════════════════════

var g = null
var fails := 0
var lines := []

var targets := []          # 검사할 성장형 동전
var ti := -1               # 지금 보는 것
var phase_end := 0
var frames := 0

# 한 장에 주는 프레임. 조건이 희소한 장(88날어 = 8번 칸 · 판의 3%)에 짧게
# 주면 한 번도 안 걸려 "안 돈다" 와 구별이 안 된다. frames= 로 바꾼다.
var phase_len := 8000

# 지금 장에서 모은 것
# 자취는 **목숨 단위**로 끊어 담는다. 오토플레이가 런을 새로 열면 손이
# 비고 우리는 다시 쥐는데, 그 0 을 같은 줄에 이어 붙이면 [0 4 8 12 0 4] 가
# 되어 "값이 내려갔다" 로 읽힌다. 목숨이 갈리는 것은 걸음이 아니다.
var lives := [[0]]
var queued := []           # (그때의 gs, 큐에 실린 수)
var leg_at := {}           # 판 번호마다 그 판에서 처음 본 gs
var died := false
var last_gs := -999
var last_n := 0


func _initialize() -> void:
	Save.path = "user://_qa_grow.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("frames="):
			phase_len = maxi(600, int(arg.substr(7)))
	for it in GameData.items():
		if String(it.get("grow", "")) != "":
			targets.append(it)
	lines.append("성장형 %d장" % targets.size())


func _bad(nm: String, why: String) -> void:
	fails += 1
	lines.append("  실패  %-12s %s" % [nm, why])


func _arm() -> void:
	var it: Dictionary = targets[ti]
	var cp: Dictionary = it.duplicate()
	cp.gs = 0
	cp.bought = 1
	cp.qa_tag = ti          # 이 판본이 내 것이라는 표식 — id 로는 못 가린다
	g.owned = [cp]
	g.sealed = -1
	lives = [[0]]
	queued = []
	leg_at = {}
	died = false
	last_gs = 0
	last_n = 1


# 한 장이 끝나면 모은 것을 판정한다.
func _judge() -> void:
	var it: Dictionary = targets[ti]
	var nm := String(it.get("n", ""))
	var gw := String(it.get("grow", ""))
	var step := int(it.get("gstep", 0))
	var v0 := int(it.get("v", 0))

	var steps := 0
	for lf in lives:
		steps += lf.size() - 1
	# 조건이 희소하면(88날어 = 8번 칸) 소크 창에서 한 번도 안 걸릴 수 있다.
	# 그것과 "안 돈다" 는 여기서 못 가른다 — 가르는 것은 qa_grow_step 이다.
	if steps == 0 and not died:
		lines.append("  알림  %-12s 이 창에서 한 번도 안 걸렸다 (조건 %s) — qa_grow_step 이 걸음을 따로 본다"
				% [nm, String(it.get("c", ""))])
		return

	# ① 자란 값이 큐에 실렸는가 — 그때의 gs 로 식을 다시 세워 맞대 본다
	#
	# 한 프레임 안에 성장값이 둘이다. game.gd 는 fire 를 큐에 넣기 **전에**
	# 올리고(3049), tdec·hitmiss 는 큐를 다 쌓은 **뒤에** 올린다(3094).
	# 그래서 정산 전후 두 값 중 하나로 식이 서면 제대로 실린 것이다.
	var bad_amt := 0
	for q in queued:
		var ok := false
		for gs_at in [int(q[0]), int(q[1])]:
			var want: int = gs_at if (gw == "fire" or gw == "hitmiss") \
					else maxi(0, v0 - step * gs_at)
			if int(q[2]) == want:
				ok = true
		if not ok:
			bad_amt += 1
	if queued.is_empty():
		if gw != "rdec":       # rdec 은 판 끝에만 자라 큐를 못 볼 수 있다
			_bad(nm, "정산 큐에 한 번도 안 실렸다")
	elif bad_amt > 0:
		_bad(nm, "큐에 실린 수가 성장값과 %d번 어긋났다 (표본 %d)"
				% [bad_amt, queued.size()])

	# ② 걸음 폭이 gstep 인가 · 방향이 맞는가
	var ups := 0
	var downs := 0
	var odd_step := 0
	var lo := 1 << 30
	var hi := -(1 << 30)
	for lf in lives:
		for vv in lf:
			lo = mini(lo, int(vv))
			hi = maxi(hi, int(vv))
		for i in range(1, lf.size()):
			var d: int = int(lf[i]) - int(lf[i - 1])
			if d > 0:
				ups += 1
			elif d < 0:
				downs += 1
			var unit: int = 1 if (gw == "tdec" or gw == "rdec") else step
			if unit > 0 and absi(d) % unit != 0:
				odd_step += 1
	if odd_step > 0:
		_bad(nm, "걸음 폭이 gstep 의 배수가 아닌 자리 %d곳" % odd_step)
	match gw:
		"fire":
			if downs > 0:
				_bad(nm, "fire 인데 값이 %d번 내려갔다" % downs)
		"hitmiss":
			if ups == 0:
				_bad(nm, "hitmiss 인데 한 번도 안 올랐다")
			# 하향은 빗나가야 나온다. 오토플레이는 판 안에 고르게 꽂아서
			# 빗나감이 안 날 수 있다 — 하향은 qa_grow_step 이 손으로 확인한다.
			if downs == 0:
				lines.append("  알림  %-12s 이 창에서는 빗나감이 없어 하향을 못 봤다" % nm)
			if lo < 0:
				_bad(nm, "hitmiss 가 0 아래로 내려갔다 (최저 %d)" % lo)
		"tdec", "rdec":
			if downs > 0:
				_bad(nm, "%s 의 걸음 수가 %d번 줄었다" % [gw, downs])

	# ③ 판을 넘어 이어지는가
	var legs: Array = leg_at.keys()
	legs.sort()
	var reset := 0
	for i in range(1, legs.size()):
		if int(leg_at[legs[i]]) < int(leg_at[legs[i - 1]]):
			reset += 1
	var carry := "판 %d개 넘김" % legs.size() if reset == 0 else "판이 바뀌며 %d번 되돌아감" % reset
	if reset > 0 and not died:
		_bad(nm, "성장이 판마다 초기화된다 — 발라트로는 런 내내 이어진다")

	var amt_lo: int = (lo if (gw == "fire" or gw == "hitmiss")
			else maxi(0, v0 - step * hi))
	var amt_hi: int = (hi if (gw == "fire" or gw == "hitmiss")
			else maxi(0, v0 - step * lo))
	lines.append("  %-12s %-8s 수량 %d → %d · 걸음 %d회(오름 %d 내림 %d) · 큐 표본 %d · %s%s"
			% [nm, gw, amt_hi if gw in ["tdec", "rdec"] else amt_lo,
			amt_lo if gw in ["tdec", "rdec"] else amt_hi,
			steps, ups, downs, queued.size(), carry,
			" · 부서짐" if died else ""])


func _process(_d: float) -> bool:
	frames += 1
	g.set_process(false)
	if ti < 0 or frames >= phase_end:
		if ti >= 0:
			_judge()
		ti += 1
		if ti >= targets.size():
			for l in lines:
				print(l)
			print("\n%s" % ("전부 통과" if fails == 0 else "실패 %d건" % fails))
			quit(mini(fails, 125))
			return true
		_arm()
		phase_end = frames + phase_len
	var gs_pre := int(g.owned[0].get("gs", 0)) if not g.owned.is_empty() else 0
	var leg_pre := int(g.leg_no)
	g._process(1.0 / 60.0)

	# 손을 이 한 장으로 고정한다. 오토플레이는 상점에서 제 동전을 산다.
	#
	# id 로 가리면 안 된다 — **같은 동전을 또 사면** 새 판본(gs 0)이 0번
	# 자리에 앉아 내 것으로 읽히고, 그 0 이 "값이 내려갔다" 가 된다.
	# 그래서 쥘 때 박아 둔 표식으로 가린다.
	var mine: bool = not g.owned.is_empty() \
			and int(g.owned[0].get("qa_tag", -1)) == ti
	if not mine:
		# 손이 빈 것과 부서진 것은 다르다. 판이 뒤로 안 갔는데 사라졌으면
		# 판 마모로 부서진 것이다.
		if g.owned.is_empty() and last_n > 0 and int(g.leg_no) >= leg_pre:
			died = true
		_arm_keep()
		return false

	var o: Dictionary = g.owned[0]
	var gs := int(o.get("gs", 0))
	# gs_pre 는 _process 를 부르기 전 값이다 — 위에서 받아 둔다
	if gs != last_gs:
		lives[-1].append(gs)
		last_gs = gs
	if not leg_at.has(g.leg_no):
		leg_at[g.leg_no] = gs
	# 큐에 실린 수 — 이 동전의 자리(0번)에서 나온 것만 본다
	for q in g.queue:
		if String(q.get("k", "")) == "item" and int(q.get("i", -1)) == 0:
			queued.append([gs_pre, gs, int(q.get("v", 0))])
	g.queue = g.queue.filter(func(z): return String(z.get("k", "")) != "item")
	last_n = g.owned.size()
	return false


# 런이 갈려 손이 빈 자리 — 자취는 남기고 다시 쥔다
func _arm_keep() -> void:
	var it: Dictionary = targets[ti]
	var cp: Dictionary = it.duplicate()
	cp.gs = 0
	cp.bought = 1
	cp.qa_tag = ti          # 이 판본이 내 것이라는 표식 — id 로는 못 가린다
	g.owned = [cp]
	g.sealed = -1
	# 다시 쥔 것은 걸음이 아니다. last_gs 를 0 으로 맞춰 두어야 다음 프레임에
	# "0 으로 내려갔다" 가 자취에 안 들어간다 — 그걸 세면 fire 가 내려간 것으로
	# 읽히고 판마다 초기화된 것으로도 읽힌다.
	last_gs = 0
	lives.append([0])       # 목숨이 갈렸다 — 새 줄에서 다시 센다
	leg_at.clear()
