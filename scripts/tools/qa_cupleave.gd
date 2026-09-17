extends SceneTree
# 나가는 통이 자루를 흘리는가. qa_cupspill 은 **들어오는** 통이 멎은 뒤만
# 재는데, 흘리는 쪽은 나가는 통이고 그 리그는 슬라이드가 끝나면 지워진다 —
# 그래서 멎은 뒤에 재는 자로는 영영 안 잡힌다. 여기서는 미끄러지는 동안
# 매 프레임 나가는 리그를 들여다본다.
#
#   godot --path . --max-fps 60 --quit-after 9000 --script scripts/tools/qa_cupleave.gd
#
# 재는 것은 둘이다. 둘 다 넘으면 한 프레임씩 센다.
#   기울기   자루가 아가리에 걸쳐 눕기 시작하는 39도(qa_cupspill 의 그 선)
#   거리     촉이 통 축에서 벗어난 몫. 1.00×r 이 벽이니 그 밖은 뚫고 나온 것
#
# 넘기기는 두 갈래로 돌린다. 한 번씩 끊어 넘기는 길과, 미끄러지는 도중에
# 또 누르는 길(shot_cupstage 가 stage_6 → stage_7 사이에 하는 그것)이다.
# 흘린 그림이 찍힌 것은 뒤엣것이었다 — 실측 63도에 촉 2.11×r 이었고,
# 그 자루가 통이 나간 뒤에도 카운터에 누워 남았다.
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.path = "user://_qa_cupleave.cfg"
	Save.wipe()
	for r in GameData.packs():
		Save.unlock("pack:" + String(r.get("id", "")))
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if busy:
		return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


# 나가는 리그의 자루가 이 프레임에 얼마나 누웠는가. 통이 두 벌일 때만
# 재는 값이라 멎어 있는 동안은 빈손으로 돌아간다.
func _peek() -> Array:
	if g.cup_rigs.size() < 2:
		return [0.0, 0.0]
	var rig: Dictionary = g.cup_rigs[0]
	if not is_instance_valid(rig.cup):
		return [0.0, 0.0]
	var cx: float = rig.cup.position.x
	var rr: float = float(rig.r)
	var dl: float = float(g.CUP3.dl)
	var lean := 0.0
	var far := 0.0
	for b in rig.darts:
		if not is_instance_valid(b):
			continue
		var t: Transform3D = b.global_transform
		var tip: Vector3 = t.origin - t.basis.y * dl
		var tl: Vector3 = t.origin + t.basis.y * dl
		var flat: float = Vector2(tl.x - tip.x, tl.z - tip.z).length()
		lean = maxf(lean, rad_to_deg(asin(clampf(flat / (2.0 * dl), 0.0, 1.0))))
		far = maxf(far, Vector2(tip.x - cx, tip.z).length() / rr)
	return [lean, far]


# 한 갈래를 끝까지 돌리고 그동안 본 것 중 가장 나쁜 값을 돌려준다.
func _sweep(quick: bool) -> Array:
	var lean := 0.0
	var far := 0.0
	var laid := 0
	for pi in GameData.packs().size():
		g._pack_step(1)
		# 미끄러지는 동안만 잰다. 통이 두 벌인 프레임이 그 사이다.
		for k in 200:
			await process_frame
			var m := _peek()
			if m[0] > 0.0:
				lean = maxf(lean, float(m[0]))
				far = maxf(far, float(m[1]))
				if float(m[0]) > 39.0 or float(m[1]) > 1.0:
					laid += 1
			if quick and k == 14:
				break
			if not quick and g.cup_rigs.size() < 2 and k > 4:
				break
	return [lean, far, laid]


func _run() -> void:
	await _wait(6)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 3D 는 화면이 있어야 선다")
		quit(0)
		return
	g._open_newrun()
	await _wait(120)
	print("\n나가는 통이 자루를 흘리는가 — 가장 기운 자루(도) · 가장 먼 촉(r배)\n")
	var a := await _sweep(false)
	print("  끊어 넘기기        %4.0f도 · %.2f×r%s"
			% [a[0], a[1], "   ← %d프레임" % a[2] if a[2] > 0 else ""])
	await _wait(150)
	var b := await _sweep(true)
	print("  도중에 또 누르기     %4.0f도 · %.2f×r%s"
			% [b[0], b[1], "   ← %d프레임" % b[2] if b[2] > 0 else ""])
	# 통과선은 qa_cupspill 과 같은 39도다. 나가는 통이라고 눕혀도 되는 것이
	# 아니다 — 무대 왼쪽 끝에서는 나가는 통의 자루도 그대로 보인다.
	var laid: int = int(a[2]) + int(b[2])
	print("\n눕거나 벽을 넘은 프레임 %d" % laid)
	print("%s" % ("전부 통과" if laid == 0 else "실패"))
	quit(mini(laid, 125))
