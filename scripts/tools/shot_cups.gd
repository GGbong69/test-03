extends SceneTree
# 다트통마다의 통을 한 장에 모아 붙인다. 통은 다트통의 얼굴이라 **나란히 놓고**
# 봐야 "저건 아까 그 통" 이 서는지 알 수 있다 — 한 장씩 보면 다 달라 보인다.
#   godot --path . --quit-after 4000 --script scripts/tools/shot_cups.gd
#
# 세 장을 떨군다.
#   cups_all.png   무대째로 나란히. 눈으로 견주는 장
#   cups_zoom.png  통 셋의 4배 확대. 단이 몇 개인지 · 무늬가 도트인지를 본다
#   그리고 칸마다 **팔레트 감사**를 찍는다 — 통 픽셀이 100% PAL 안에
#   있는지. 세는 것은 **3D 뷰포트 텍스처**다(무대·윤·후광·깨짐이 안 든다).
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false

#  PAL 밖이지만 통에 있어도 되는 색. 동전 스티커와 사진·사탕은 원래
#  PAL 그림이고 StandardMaterial 그대로 두기로 한 것들이다.
const OK_OFF := ["f4f0e6", "efe9db", "fbf6ea", "e8dfc8"]

func _initialize() -> void:
	Save.path = "user://_shot_cups.cfg"
	Save.wipe()
	for r in GameData.packs():
		Save.unlock("pack:" + String(r.get("id", "")))
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)

func _process(_d: float) -> bool:
	if busy: return false
	busy = true
	_run()
	return false

func _wait(n: int) -> void:
	for i in n:
		await process_frame


#  이 게임 그림의 온 팔레트. game.gd 의 ART_PAL 을 그대로 읽는다 —
#  여기 옮겨 적으면 둘이 갈리고, 갈리면 감사가 거짓말을 한다.
func _pal() -> Dictionary:
	var out := {}
	for k in g.ART_PAL:
		var i := 0
		for c in g.ART_PAL[k]:
			out[Color(c).to_html(false)] = "%s%d" % [k, i]
			i += 1
	return out


#  통 픽셀의 팔레트 감사. 뷰포트는 배경이 투명이라 알파가 곧 「통이다」다.
#
#  **PAL 밖이 0 이 아니어도 되는 다트통이 셋 있다.** 동전 스티커(아가리 아래
#  한 장)와 선물의 사진·사탕은 StandardMaterial 을 그대로 두기로 한 것들이라
#  빛을 받아 팔레트 사이 값으로 떨어진다 — 원래 PAL 로 그린 그림이고,
#  램프에 얹으면 다이컷 테와 얼굴이 한 단으로 뭉친다. 그 다트통은 아래에서
#  까닭을 같이 찍는다.
func _audit(pal: Dictionary) -> String:
	if not g._cup3_live():
		return "뷰포트 없음"
	var img: Image = g.cup_vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var seen := {}
	var off := {}
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			n += 1
			var hx := c.to_html(false)
			seen[hx] = int(seen.get(hx, 0)) + 1
			if not pal.has(hx) and not OK_OFF.has(hx):
				off[hx] = int(off.get(hx, 0)) + 1
	var tot := 0
	var worst := PackedStringArray()
	for hx in off:
		tot += int(off[hx])
	var ks := off.keys()
	ks.sort_custom(func(a, b): return int(off[a]) > int(off[b]))
	for i in mini(ks.size(), 3):
		worst.append("%s x%d" % [ks[i], off[ks[i]]])
	return "색 %2d · 통 %4dpx · PAL밖 %3dpx%s" % [seen.size(), n, tot,
			("  (" + ", ".join(worst) + ")") if tot > 0 else ""]


func _run() -> void:
	await _wait(6)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 통은 화면이 있어야 선다")
		quit(0)
		return
	g._open_newrun()
	await _wait(60)
	var pal := _pal()
	var st: Rect2 = g._cup_stage()
	var sc: int = int(root.get_texture().get_image().get_width() / 640)
	var cw: int = int(st.size.x) * sc
	var ch: int = int(st.size.y) * sc
	var cols := 5
	var packs := GameData.packs()
	var rows: int = int(ceil(float(packs.size()) / float(cols)))
	var sheet := Image.create(cw * cols, ch * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("221d33"))
	var zoom := []
	var bad := 0
	#  **화살표로 민다.** 통을 다시 세워서(_cup3_close+_cup3_open) 찍으면
	#  자루가 처음 놓인 자리 그대로라 늘 얌전하다 — 플레이어는 그 그림을
	#  한 번도 못 본다. 미는 동안 벽이 자루를 밀어 나르고, 그때 기운
	#  자루가 그대로 선다. cup_probe 주석이 경고해 둔 그 함정에
	#  촬영 쪽이 빠져 있었다.
	for pi in packs.size():
		if pi > 0:
			g._pack_step(1)
		await _wait(150)
		var img: Image = root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var src := Rect2i(int(st.position.x) * sc, int(st.position.y) * sc, cw, ch)
		sheet.blit_rect(img, src, Vector2i((pi % cols) * cw, int(pi / cols) * ch))
		var au := _audit(pal)
		#  스티커·발치 소품을 쥔 다트통은 PAL 밖 픽셀이 있어도 된다.
		var sk: Dictionary = g._cup3_skin(pi)
		var why := PackedStringArray()
		if bool(sk.sticker):
			why.append("동전 스티커")
		if String(sk.foot) == "gift":
			why.append("사진·사탕")
		if not au.contains("PAL밖   0px") and why.is_empty():
			bad += 1
		print("  %2d %-10s %-14s %s%s" % [pi, packs[pi].get("id", ""),
				packs[pi].get("name", ""), au,
				("  ← " + ", ".join(why)) if not why.is_empty() else ""])
		#  4배 확대 크롭 셋. 단이 몇 개인지는 확대해야 센다.
		if pi == 0 or pi == 6 or pi == 7:
			zoom.append(img.get_region(src))
	sheet.save_png("res://shots/cups_all.png")
	#  확대 장. 통 셋을 4배(시트가 이미 2배라 두 번 더)로 나란히 둔다.
	if zoom.size() > 0:
		var zs := Image.create(cw * 2 * zoom.size(), ch * 2, false,
				Image.FORMAT_RGBA8)
		zs.fill(Color("221d33"))
		for i in zoom.size():
			var z: Image = zoom[i]
			z.resize(cw * 2, ch * 2, Image.INTERPOLATE_NEAREST)
			zs.blit_rect(z, Rect2i(0, 0, cw * 2, ch * 2),
					Vector2i(i * cw * 2, 0))
		zs.save_png("res://shots/cups_zoom.png")
	print("\nshots/cups_all.png · %dx%d · 칸 %dx%d"
			% [sheet.get_width(), sheet.get_height(), cw, ch])
	print("shots/cups_zoom.png · 기본 · 무쇠 · 깃털 4배")
	#  목표: 통 픽셀 100% PAL · 칸당 20색 이하. 무대 섞은 색과
	#  윤·후광·깨짐 FX 는 뷰포트를 세므로 애초에 안 든다.
	print("PAL 밖 색이 있는 다트통 %d개" % bad)
	quit(0)
