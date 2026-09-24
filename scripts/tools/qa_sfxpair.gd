extends SceneTree

#  **같은 일은 키로 해도 손가락으로 해도 같은 소리가 난다.**
#    godot --path . --headless --script scripts/tools/qa_sfxpair.gd
#
#  모바일이 예정돼 있다. 손가락으로 배운 사람과 키로 배운 사람이 같은 일을
#  다른 소리로 배우면 그 화면은 두 벌이 된다 — 그래서 이것은 취향이 아니라
#  규칙이다. 그런데 여태 그 규칙을 **재는 자가 없었고**, 그 사이에 넷이
#  갈라졌다(2026-09-25 에 잡았다):
#    · 설정 나가기 — 「뒤로」는 menu_back, ESC·스페이스는 무음
#    · 새 런 나가기 — 단추는 back, ESC 는 무음
#    · 런 정보 닫기 — 「정보」 단추는 menu_back, ESC 는 무음
#    · 지목 풀기 — 톡은 shop/rack_deselect, ESC 는 무음
#  거기에 설정 여섯 줄 중 「전체화면」만 제 소리가 없어 **나가는 소리**
#  (menu_back)로 울었고, 키(F11)로는 소리가 아예 0이었다.
#
#  고친 꼴은 전부 같다 — 소리를 갈래마다 흩지 않고 **도착점 함수 한 곳**에
#  둔다. 그러면 새 길(화면 단추 · 손가락 · 키)이 나도 그 문을 지나는 한
#  소리가 따라온다. 이 자는 그 문이 실제로 하나인지를 **두 길로 눌러 보고**
#  같은 소리가 나는지로 잰다.
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0
const DT := 1.0 / 60.0


func _initialize() -> void:
	Save.gpath = "user://_qa_sfxpair_g.cfg"
	Save.path = "user://_qa_sfxpair.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c:
		okn += 1
	else:
		fail += 1
	print("  %s %-38s %s" % ["통과" if c else "실패", n, d])


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	return false


#  한 동작이 **실제로 운 소리들**. sfx_pool 이 한 칸씩 도는 것을 세고,
#  그 자리에 걸린 stream 의 파일 이름을 읽는다 — _sfx 가 자리마다 stream 을
#  갈아 끼우므로 그 경로가 곧 이름이다(칸을 세기만 하면 무엇이 울었는지는
#  모른다).
func _snd(cb: Callable) -> Array:
	var pool: int = maxi((g.sfx_pool as Array).size(), 1)
	var prev: int = g.sfx_next
	cb.call()
	var dn: int = posmod(int(g.sfx_next) - prev, pool)
	var out := []
	for k in dn:
		var pi: int = posmod(prev + k, pool)
		var st = (g.sfx_pool[pi] as AudioStreamPlayer).stream
		out.append("" if st == null
				else String(st.resource_path).get_file().get_basename())
	return out


func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	e.echo = false
	g._unhandled_input(e)


func _mid(r: Rect2) -> Vector2:
	return r.position + r.size * 0.5


#  두 길을 나란히 눌러 보고 같은 소리인지 본다.
func _pair(name: String, setup: Callable, by_key: Callable,
		by_tap: Callable) -> void:
	setup.call()
	var a := _snd(by_key)
	setup.call()
	var b := _snd(by_tap)
	_ok(name, a == b and not a.is_empty(),
			"키 %s · 손가락 %s" % [str(a), str(b)])


func _run() -> void:
	for i in 8:
		g._process(DT)
	print("\n같은 일 · 같은 소리\n")
	if (g.sfx_pool as Array).is_empty():
		print("  sfx_pool 이 비었다 — 잴 수 없다")
		quit(1)
		return

	var rows: Array = g._set_rows()
	var i_back: int = rows.find("back")
	var i_fs: int = rows.find("fs")
	_ok("설정 줄에 「뒤로」와 「전체화면」이 있다", i_back >= 0 and i_fs >= 0,
			str(rows))

	# ── ① 설정 나가기 ───────────────────────────────────
	_pair("설정 나가기 — 키와 단추가 같다",
			func():
				g.state = g.S.SETTINGS
				g.pause_from = -1,
			func(): _key(KEY_ESCAPE),
			func(): g._click(_mid(g._set_rect(i_back))))

	# ── ② 설정 나가기 — 스페이스도 같은 문이다 ──────────
	_pair("설정 나가기 — 스페이스도 같다",
			func():
				g.state = g.S.SETTINGS
				g.pause_from = -1,
			func(): _key(KEY_SPACE),
			func(): g._click(_mid(g._set_rect(i_back))))

	# ── ③ 전체화면 ─────────────────────────────────────
	#  ⚠ 여기만 **나가는 소리**(menu_back)로 울고 키로는 소리가 0이었다.
	#  둘이 같은지만 묻지 않고 「나가는 소리가 아닌지」를 같이 묻는다 —
	#  둘 다 menu_back 이어도 짝은 맞기 때문이다.
	g.state = g.S.SETTINGS
	g.pause_from = -1
	var fs_key := _snd(func(): _key(KEY_F11))
	g.state = g.S.SETTINGS
	g.pause_from = -1
	var fs_tap := _snd(func(): g._click(_mid(g._set_rect(i_fs))))
	_ok("전체화면 — 키와 줄이 같다", fs_key == fs_tap and not fs_key.is_empty(),
			"키 %s · 줄 %s" % [str(fs_key), str(fs_tap)])
	_ok("전체화면이 나가는 소리로 안 운다",
			not fs_key.has("menu_back") and not fs_tap.has("menu_back"),
			str(fs_tap))

	# ── ④ 새 런 나가기 ──────────────────────────────────
	_pair("새 런 나가기 — 키와 단추가 같다",
			func():
				g.state = g.S.NEWRUN
				g.pause_from = -1,
			func(): _key(KEY_ESCAPE),
			func(): g._click(_mid(g._newrun_back())))

	# ── ⑤ 런 정보 닫기 ──────────────────────────────────
	_pair("런 정보 닫기 — 키와 단추가 같다",
			func():
				g.run_from = g.S.SHOP
				g.state = g.S.RUNINFO,
			func(): _key(KEY_ESCAPE),
			func(): g._click(_mid(g._runinfo_back_rect())))

	# ── ⑥ 음량 — 미는 동안 귀가 있다 ────────────────────
	#  홈을 잡는 순간 한 번 나고 그 뒤 미는 내내 무음이라, 새 크기를 귀로
	#  못 듣고 맞춰야 했다. 연타 방지(60ms)가 걸려 있으므로 **시계를
	#  넘겨** 두 번째 톡이 나는지를 본다.
	g.state = g.S.SETTINGS
	g.vol_snd_ms = 0
	var v1 := _snd(func(): g._vol_set("vol", 0.40))
	g.vol_snd_ms = 0
	var v2 := _snd(func(): g._vol_set("vol", 0.60))
	_ok("음량을 밀면 톡이 난다", v1 == ["menu_pick2"] and v2 == ["menu_pick2"],
			"%s · %s" % [str(v1), str(v2)])
	#  같은 프레임에 연달아 밀면 한 알만 난다 — 끌기는 프레임마다 부른다.
	g.vol_snd_ms = 0
	var vr := _snd(func():
			for k in 6:
				g._vol_set("vol", 0.50 + 0.01 * float(k)))
	_ok("연달아 밀어도 톡이 겹치지 않는다", vr.size() == 1, str(vr))
	#  음악 쪽은 효과음 톡으로 말할 수 없다 — 안 낸다.
	g.vol_snd_ms = 0
	var vm := _snd(func(): g._vol_set("mus", 0.30))
	_ok("음악 쪽은 톡이 없다", vm.is_empty(), str(vm))

	# ── ⑦ 들고 있는 것 놓기 ─────────────────────────────
	#  _hand_abort 는 손이 빈 채로도 청소용으로 불리는 자리가 열 곳 넘는다.
	#  쥔 것이 있을 때만 울어야 한다.
	g.state = g.S.SHOP
	g.hand_st = g.H.NONE
	var h0 := _snd(func(): g._hand_abort())
	_ok("빈 손을 놓으면 소리가 없다", h0.is_empty(), str(h0))
	g.hand_st = g.H.CARRY
	g.hand_i = -1
	g.hand_src = 1
	var h1 := _snd(func(): g._hand_abort())
	_ok("쥔 것을 놓으면 소리가 난다", h1 == ["hand_drop"], str(h1))
	#  길게 누르기(읽기)는 아무것도 확정 안 한다 — 그 자리 주석이 「소리도
	#  없다」를 WCAG 2.5.2 와 함께 못 박아 두었다.
	g.hand_st = g.H.CARRY
	g.hand_i = -1
	g.hand_src = 1
	var h2 := _snd(func(): g._hand_abort(true))
	_ok("읽기가 된 손짓은 소리가 없다", h2.is_empty(), str(h2))

	print("\n%s" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
