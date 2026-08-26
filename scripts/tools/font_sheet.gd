extends SceneTree

#  Paperlogy 아홉 두께를 게임이 실제로 쓰는 크기로 나란히 그린다.
#  두께는 눈으로만 고른다 — 9px 잔글씨에서 Thin 은 사라지고 Black 은 뭉갠다.
#
#  실행:  godot --path . -s scripts/tools/font_sheet.gd
#  결과:  shots/font_sheet.png
#
#  글꼴은 프로젝트 밖(내려받은 폴더)에서 직접 읽는다. 아홉 개를 fonts/ 에
#  들이면 안 쓰는 여덟 개까지 빌드에 실린다. 고른 뒤 그 하나만 넣으면 된다.
#
#  뷰포트를 따로 판다 — 프로젝트가 640x360 스트레치라 root 를 그대로 쓰면
#  아홉 줄이 안 들어간다.

const SRC_DIR := "C:/Users/USER/Downloads/Paperlogy-1.001/"
const WEIGHTS := [
	"1Thin", "2ExtraLight", "3Light", "4Regular", "5Medium",
	"6SemiBold", "7Bold", "8ExtraBold", "9Black",
]

const C_BG := Color("14111f")
const C_TXT := Color("f4efe2")
const C_DIM := Color("8f86a8")
const C_ACC := Color("f2b134")
const C_GOLD := Color("f2c94c")

const W := 1140
const ROW := 96
const TOP := 44

var vp: SubViewport
var fonts := []
var frames := 0


func _initialize() -> void:
	for w in WEIGHTS:
		var f := FontFile.new()
		var err := f.load_dynamic_font(SRC_DIR + "Paperlogy-" + w + ".ttf")
		if err != OK:
			push_error("못 읽는다: " + w)
		fonts.append(f)

	vp = SubViewport.new()
	vp.size = Vector2i(W, TOP + ROW * WEIGHTS.size() + 12)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var cv := Node2D.new()
	vp.add_child(cv)
	cv.draw.connect(_paint.bind(cv))
	cv.queue_redraw()


func _paint(cv: Node2D) -> void:
	cv.draw_rect(Rect2(Vector2.ZERO, Vector2(vp.size)), C_BG)
	cv.draw_string(fonts[3], Vector2(16, 28),
			"Paperlogy 두께별 — 게임이 실제로 쓰는 크기 (제목 40 · 본문 12/11/10 · 잔글씨 9)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, C_DIM)

	for i in WEIGHTS.size():
		var f: FontFile = fonts[i]
		var y: float = TOP + ROW * i
		cv.draw_line(Vector2(0, y), Vector2(W, y), C_DIM.darkened(0.72))

		# 왼쪽 — 두께 이름
		cv.draw_string(fonts[5], Vector2(16, y + 26), WEIGHTS[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_ACC)
		cv.draw_string(fonts[3], Vector2(16, y + 44), "Paperlogy-%s.ttf" % WEIGHTS[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_DIM.darkened(0.25))

		# 제목 크기 40
		cv.draw_string(f, Vector2(180, y + 52), "하이톤",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 40, C_TXT)
		cv.draw_string(f, Vector2(320, y + 52), "HIGHTONE",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 20, C_DIM)

		# 본문 — 게임에서 실제로 나오는 문자열 그대로
		cv.draw_string(f, Vector2(490, y + 22), "시작   컬렉션   설정   종료",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_TXT)
		cv.draw_string(f, Vector2(490, y + 42), "R1/8    목표  0 / 45    이자 +4",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TXT)
		cv.draw_string(f, Vector2(490, y + 60), "다음 라운드 →    리롤   판매   구매",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_GOLD)
		cv.draw_string(f, Vector2(490, y + 78), "연속 빗나감 · 증폭기 · 빗나감 배수 · 12×3 · 20…",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, C_DIM)

		# 오른쪽 — 큰 숫자(정산 팝업)
		cv.draw_string(f, Vector2(910, y + 52), "+12",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 34, C_GOLD)
		cv.draw_string(f, Vector2(1010, y + 40), "칩 87",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_TXT)
		cv.draw_string(f, Vector2(1010, y + 60), "무료",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, C_ACC)


func _process(_d: float) -> bool:
	frames += 1
	if frames < 4:
		return false
	var img := vp.get_texture().get_image()
	img.save_png("res://shots/font_sheet.png")
	print("저장: font_sheet.png  %dx%d" % [img.get_width(), img.get_height()])
	return true
