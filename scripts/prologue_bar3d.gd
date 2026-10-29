extends RefCounted
# ══════════════════════════════════════════════════════════
#  다른 여는 장면 — 바에 앉아 눈을 뜬다 (2026-10-25)
# ──────────────────────────────────────────────────────────
#  「시작하면 눈을 뜨고 주변을 살펴보는데 바에 앉아있는거지 … 외국 바에 CCTV같이 달린 TV 작은거 … 그걸 보다가
#  빨려 들어가는거지」 · 판지(outputs/prologue/bar_board)를 보고 「이대로 만들기는 하는데 좀 퀄리티 업을 많이 해야
#  될거 같은데? 지금은 그냥 뭐 3류 3D게임 같거든? 모델링은 최대한 하고 좀 이팩트같은걸로 가려야 될거 같은데?」(사용자).
#  테이프 프롤로그(prologue3d.gd · Plg)는 그대로 두고 같은 API(make · tick · cues · handoff · feed_at · length)로 선다 —
#  game.gd 의 시계 · 누름(첫 누름 빨리 감기 · 둘째 끝) · 필터 덮개 · 넘김이 그대로 돈다(PLGP.kind · plg_mod).
#  흐름(약 18 초 · 글 · 말 없음) — 눈은 사람 눈이다: 고개는 천천히 붙었다 천천히 서고(≤ 약 38°/s) · 멈춤에도 숨이 있다:
#   1 0~1.1 검다 — 먹먹한 방 소리(냉장고 · 먼 잔 한 번). 0.8 초에 감은 눈꺼풀 너머 빛이 한 단 든다(검붉은 판).
#   2-1 1.1~1.8 눈꺼풀이 반쯤 — 흐린 도트(덩어리 2 · 4px) · 뺨을 카운터에 댄 낮은 눈 · 코앞에 맥주잔.
#   2-2 1.8~3.2 한 번 더 깜박 → 또렷 · 받침 위 반 남은 잔. TV 는 아직 안 보인다 — 찬 빛이 단으로 깜박이며 잔 테 · 카운터
#       끝을 짚는다(화면 밖 TV 를 먼저 알린다).
#   3 3.2~7.9 고개를 천천히 들며 왼쪽 — 가운데 펜던트 밑에서 상인의 손이 잔을 닦는다(가슴에서 잘린다 · 얼굴은 늘 밖 ·
#     어둠 · 팔꿈치는 갈비 옆 · 손은 팔뚝을 잇는다 — 엄지는 천째 입 안 · 검지는 바깥 벽).
#   4 7.9~11.3 오른쪽 — 빈 홀 · 벽의 다트 장 · 테이블에 남은 빈 잔 둘 · 다트(방금 누가 있었다).
#   5 11.3~14.4 위 — 바 뒤 천장에 매단 작은 브라운관(관 · 멍에 · 쟁반)이 그림 한가운데 선다. 지지직이 단으로 걷히고 게임
#     인트로의 램프가 딸깍 켜진다 · 한 번 깜박인다.
#   6 14.4~16.95 TV 를 한가운데 둔 채 화각이 좁아지며 조금 다가가 매끈하게 선다(눈은 화면 한가운데로 가는 선 위로만). 방 빛이 한 등씩
#     꺼진다(가운데 펜던트가 마지막) · 방 소리가 먹먹해지고 TV 소리만 남는다. TV 그림 속 문 위 HIGHTON 간판이 한 글자씩
#     켜진다(SIGN · 문 한가운데가 유리 세로축).
#   7 15.9~17.4 TV 유리 속으로 든다 — 인광 점 속으로(DIVE.mode "phosphor" · Plg PHOS · 2026-10-28 「그 티비로 들어가는
#     그 연출이 문제인거 같아 좀 브라운관 들어가는 연출을 생각해서 다시 만들어 보자」 · 2026-10-29 「지금 들어가는 속도가 좀
#     빠르네」 — 빠르기는 Plg PHOS_RATE 한 줄 · 느림 1.5 초 — 테이프도 같은 줄): 밀기 꼬리 위에서 그 빠르기 그대로 이어 뛰어든다(서지 않는다)
#     — TV 몸 · 테가 화면 밖으로 빠지고 유리가 화면을 다 덮는 틀부터 배율이 단으로 뛰며 그림이 브라운관 제
#     결로 갈라진다(주사선 틈 → 끝이 둥근 R · G · B 인광 줄 → 줄 사이 검은 틈으로 날아든다). 넘김(handoff)에 무대를
#     끊고 게임 필터를 켜면 게임 그림이 R · G · B 세 장으로 비켜 있다가 단으로 겹쳐 제 빛깔이 된다 → 게임 속(인트로 — 네온이
#     붙는 쾅) → 제목 문. 소리는 들어가는 동안 차오르는 웅 · 이잉에 줄을 지날 때 지직(bar_phos) — 넘김에 끊기고 웅 꼬리(넘김엔
#     때리는 소리가 없다 — 0.34 초 뒤 네온 쾅이 한 박). 들어가는 동안 TV 그림 소리(램프 꺼짐 딸깍 · 다트)는 안 난다(game _sfx).
#     옛 반짝 · 번쩍(테이프와 같은 Plg glint · flash · cross)은 DIVE.mode "glint" 로 남는다.
#  빛 · 효과로 가린다(조사 T01~T14): 채움빛을 걷고 찬 바탕 한 단만(밤 · 주인공만 빛) · 펜던트 · TV 의 단단한 그림자 ·
#  니스 반짝 · 빛무리 · 전구 · 도트 잔 그림 · 거울 비침 걷기 · 선반 병은 뒤에서 · 채도를 누른다 · 깊이 덩어리 흐림(초점은
#  깜박임 · 눈길에 뛴다 — 흐르지 않는다) · TV 빛줄기에만 옅은 안개 · 눈길은 보는 점이 조금 앞서고 고개가 매끈하게 따라
#  살짝 넘쳤다 서고 멈춤엔 숨 · 빛은 이어 붙이지 않고 단으로 바뀐다 · 눈꺼풀은 렌즈 꼴(가운데가 넓다 · 위 눈꺼풀이 거의 다
#  움직인다 · 단단한 테).
#  세트는 제목 문 안의 술집(Door3D._inside)을 그대로 짓고 이 장면에서만 고친다(재질 · 빛 · 그림 카드). 주인공 소품 ·
#  상인 몸통 · TV · 잔 걸이 · 양철 천장은 scripts/tools/blender/bar_intro.py(assets/models/bar_intro.glb), 상인의
#  팔뚝 · 손은 상점 손 그대로(game.gd _hand3_build · _fore3_build). TV 는 이 장면의 세계(제 SubViewport)에만 있다 —
#  제목 문 카메라는 다른 세계라 못 본다.
#  소리는 제 자리에서 낸다 — 방 소리 · 잔 · 닦기 · 잔 놓기는 이 장면의 BarAmb 버스(로패스 — 눈과 같이 열리고 다이브에
#  닫힌다 · 넘김에 걷는다)로, TV 지지직 · 웅 · 들어가는 소리(bar_phos — entry_at)는 SFX 로(먹먹해지지 않는다). cues 는 비었다.
const Door3D = preload("res://scripts/door3d.gd")
const Room3D = preload("res://scripts/room3d.gd")
const Plg = preload("res://scripts/prologue3d.gd")
const GLB := "res://assets/models/bar_intro.glb"

#  때 — feed 화면 그림(게임 인트로 시계)이 출발 · dive0 ~ dive1 유리 속으로 · 넘김(handoff) = dive1 = 번쩍의 맨 밝은 틀 —
#  그 틀에 층이 끊기고(Plg.cross) LEN 까지 비어 있다가 걷힌다(옛 0.45 초 층 흐림은 번쩍이 맡는다 · 그동안 방 소리 꼬리만 남는다)
#  feed 13.78 — 넘김까지 3.62 초. 인트로의 램프 딸깍(0.45 → 14.23)은 TV 앞 깜박임(LID 13.8~14.15)이 끝난 뒤 · 램프 밑 문
#  그림이 밀기 내내 · 꺼짐(2.85 → 16.63)은 반짝 바로 앞 — 앞당겨 켠 간판의 네온 밝기로 한 번에 내려앉아(game.gd 어둠도
#  간판 시계를 따른다) 문 · 다트판이 네온 빛에 남은 유리를 빗금이 쓴다 · 네온이 붙는 쾅(3.96 → 17.74 = 넘김 + 20 틀)은
#  흰빛이 다 걷히고 잔상이 돌아온 뒤 게임 속에서 따로 — 테이프의 퍽 뒤 다트처럼 「들어왔고 살아 있다」 한 박 · 금빛 번쩍 없이
#  −6dB(game.gd intro_soft — 0.34 초 앞 흰 번쩍 · 퍽이 절정이다 · 유리 반짝 검토 2)(검토 1 — 다이브 한가운데 한 틀 만에
#  밝기가 튀었다 · 검토 2 — 밀기 첫 1 초가 인트로의 꺼진 박자라 TV 가 방보다 어두웠다 · 유리 반짝 검토 — 13.6 은 쾅이 퍽 0.16 초 뒤라 두 번 쳤고 · 13.44 는 쾅이 퍽에 겹쳐 유리 퍽이 settle_total
#  의 둥에 묻히고 흰 번쩍 뒤에 금빛 막이 매끈하게 꺼지며 · 건넌 뒤 게임 속이 1.3 초 정지 그림이었고 · 램프 딸깍이 감은 눈에
#  났다). 간판 소리는 이 장면이 간판을 켜는 때(SIGN.t0)에 난다(game.gd — 인트로 시계로는 반짝 쉬익에 겹친다).
const T := {"feed": 13.78, "dive0": 16.2, "dive1": 17.4}
#  끝 — 넘김 + 방 소리 꼬리(SND.tail) 뒤 · 인트로 끝(feed + INTRO.end 19.13)보다 앞이어야 한다(그 뒤엔 인트로가 이 장면을 안 민다)
const LEN := 18.45
#  층 — 게임 필터 밑(Plg.LAYER 와 같다)
const LAYER := 90
#  렌더 층 — 안(Door3D.LAYER_IN) · 상인(TV 빛이 안 닿는다) · 펜던트 · TV 그림자를 드리우는 주인공 것
const L_IN := 2
const L_MERCH := 1 << 4
const L_HERO := 1 << 5
#  자세 [눈, 보는 데, 굴림(도 — 뺨을 카운터에 댄 머리), 화각] — 바 좌표(Door3D BAR · 카운터 윗면 y −0.14 · 앞판 z −3.50 ·
#  오른쪽 바 의자 x −0.10 · z −3.12). 보는 데가 null 이면 TV 유리 한가운데(짓고 나서 셈한다 — 손으로 적은 점이 실제
#  화면보다 0.14m 높아 TV 가 그림 아래 3 분의 1 에 앉았다 · 검토 2). push 는 눈이 (화면 한가운데 − 눈) 선 위로만
#  다가간다(dolly m) — 화각이 좁아져도 한가운데가 안 움직인다.
const POSE := {
	"cheek": [Vector3(-0.13, -0.075, -3.57), Vector3(-0.14, -0.085, -3.88), -66.0, 44.0],
	"merch": [Vector3(-0.10, 0.30, -3.20), Vector3(-0.40, -0.07, -3.98), 0.0, 44.0],
	"dart": [Vector3(-0.10, 0.30, -3.20), Vector3(1.20, 0.02, -4.92), 0.0, 34.0],
	"tv": [Vector3(-0.10, 0.30, -3.20), null, 0.0, 22.0],
	"push": [Vector3(-0.10, 0.30, -3.20), null, 0.0, 14.0, 0.14],
}
#  눈길 [시작, 돌기 길이, 자세에서, 자세로, 꼴] — 사람 눈이다(「카메라 무빙이 너무 빠르지 않아? 좀 사람의 시야인거잖아?
#  자연스럽게 해봐」). 고개는 매끈하게 붙었다 매끈하게 선다(smoothstep — 시작 · 끝 속도 0 · 3 틀 눈 튐 걷기) · 가장 빠른
#  때가 사람 고개만큼(≤ 약 38°/s · 깬 직후 들기는 더 느리게) · 끝에 HEAD.over 만큼 넘쳤다가 HEAD.settle 초에 매끈하게
#  돌아와 선다 · 보는 점이 눈 자리보다 HEAD.lead 초 먼저 간다(눈이 앞선다). lift 고개를 든다(굴림이 늦게 끝난다 · 드는 동안
#  눈길이 카운터 쪽으로 처진다) · look 고개를 돌린다(낮은 호) · push 화각이 좁아지며 조금 다가간다 — 다가감이 곧 유리
#  뚫기의 다가감이다: 16.7 에 매끈하게 선다(옛 밀기는 16.2 에 섰고 다이브가 다시 붙었다 서서 두 번 멈칫했다). 인광 점 속으로는
#  뛰어듦(lunge_at — handoff − Plg.phos_lunge)이 밀기 꼬리 위에서 그 빠르기를 이어받는다(밀기가 서기 전에 붙는다 — 옛 0.7 초
#  판은 16.5~16.7 에 거의 섰다가 다시 붙었다) · 옛 반짝은 서는 때(dive0 + DIVE.creep uh 몫)에 뛰어든다.
const MOVE := [
	[3.2, 3.6, "cheek", "merch", "lift"],
	[7.9, 2.3, "merch", "dart", "look"],
	[11.3, 2.1, "dart", "tv", "look"],
	[14.4, 2.3, "tv", "push", "push"],
]
#  고개 — 끝 넘침 몫 · 돌아와 서는 초 · 눈이 앞서는 초 · 숨(Hz · 숙임 도 · 눈 높이 m · 켜지는 초 — 눈을 뜬 뒤 늘 · 다이브에
#  걷는다). 멈춤이 딱 서는 게임 카메라로 읽혔다(검토 2 — 숨 0).
const HEAD := {"over": 0.015, "settle": 0.4, "lead": 0.13, "br_hz": 0.22, "br_pitch": 0.2, "br_y": 0.003, "br_in": 0.4}
#  눈꺼풀 [때, 뜬 몫] — 감기 0.1 · 뜨기 0.2(둘째는 0.3) · 첫 뜸은 반(0.45). TV 앞에 눈이 선 동안 한 번 깜박인다(끊지 않는다).
const LID := [[0.0, 0.0], [1.1, 0.0], [1.55, 0.45], [1.8, 0.45], [1.9, 0.0], [1.95, 0.0], [2.25, 1.0],
		[13.8, 1.0], [13.9, 0.0], [13.95, 0.0], [14.15, 1.0]]
#  깨기 때 — 감은 눈 너머 빛이 한 단 드는 때 · 둘째 깜박임(초점이 잔에 서고 노출이 한 단 내린다)
const WAKE := {"skin": 0.8, "blink": 1.9}
#  감은 눈 너머 빛 — 검붉은 판(검정 위 두 단 안) · WAKE.skin 에 한 단 든다
const SKIN := [Color8(8, 2, 2), Color8(20, 6, 4)]
#  초점 [때부터, 띠 앞 m, 띠 뒤 m, 가장 작은 덩어리 px, 가장 큰 덩어리 px, 띠 앞 또렷(1)] — 흐름 없이 뛴다(깜박임 · 눈길 한가운데).
#  반 뜬 눈은 4px 까지만(8px 는 흐림이 아니라 저해상도로 읽혔다 · 나머지는 눈꺼풀이 맡는다) · 손 띠로는 고개를 들기
#  시작할 때 뛴다(드는 동안 손이 덩어리째 반짝였다). 손 띠는 선반 전체를 한 띠에 넣는다(왼 위 병만 4px 덩어리 ·
#  오른쪽은 1px — 한 그림에 텍셀 크기가 섞였다 · 검토 3) · 손 · 다트 띠 앞 가까운 손님 잔은 덩어리 없이(거품이 4~8px
#  블록으로 깨져 JPEG 덩어리였다 — 어둠이 맡는다)
const FOCUS := [
	[0.0, 0.0, 0.25, 2.0, 4.0],
	[1.9, 0.12, 0.42, 1.0, 4.0],
	[3.2, 0.62, 2.4, 1.0, 4.0, 1.0],
	[9.05, 1.9, 3.5, 1.0, 4.0, 1.0],
	[12.35, 1.05, 1.95, 1.0, 4.0],
	[16.2, 0.0, 999.0, 1.0, 1.0],
]
#  빛 밑값(세기) · 표 [때부터, 이름 → 밑값의 몫] — 그 때에 그 자리에서 바뀐다(이어 붙이지 않는다). 밀기 동안 한 등씩
#  꺼진다: 다트 장 그림등 → 촛불 · 네온 → 왼 펜던트 → 선반 밑불 · 채움 반 → 오른 펜던트 → 가운데 펜던트 · 채움 0.
#  손 컷은 선반 밑불을 한 단 내린다 · 올려다볼 때 한 단 더(앞에서 비춘 주황 병 줄이 TV 등장을 가로챘다) · 다트 장면은 찬
#  채움을 되살려 벽 · 장 문짝 · 그림등 · 의자가 1~2 단 실루엣으로 선다(검은 허공에 다트판과 원판만 떴다 · 검토 3).
#  tvb TV 몸 빛(TvRim · 전원 등) — 가운데 펜던트와 같이 꺼진다: 깜깜한 방에 TV 테 윗면의 무른 타원 하이라이트 · 화면 밑
#  끝의 쨍한 주황 전원 등만 유리 밖에 남아 별과 시선을 다퉜다(유리 반짝 검토 — 빛은 유리 하나만 · 등은 몸과 같은 단으로 ·
#  몸은 꺼지지 않고 TVL.body 무광 한 단).
#  가운데 펜던트는 손 + 15cm 만 덮는 좁은 원뿔(카운터 웅덩이가 화면 절반을 채우고 손이 크림으로 날았다 · 검토 1) ·
#  오른쪽은 손님 잔 받침만 — 초점이 손으로 뛰면 한 단 내린다(손님 잔이 손보다 밝아 이 컷 주인공과 다퉜다 · 검토 2).
#  촛불은 다트 장면에서 0.4(채도 높은 주황 웅덩이가 다트판과 다퉜다 · 검토 2)
const LBASE := {"pl": 0.9, "pm": 1.8, "pr": 0.7, "shelf": 0.15, "pict": 2.7, "candle": 1.1, "neon": 0.7}
#  펜던트 원뿔(반각 도) · 올려다보는 때부터 갓 속 젖빛 판 · 갓 안쪽은 가장 어두운 단(올려다본 그림 귀에 큰 원판이 섰다)
const PEND := {"ang": [24.0, 17.0, 12.0], "up": 11.3}
const LIGHT := [
	[0.0, {"pl": 1.0, "pm": 1.0, "pr": 1.0, "shelf": 1.0, "pict": 0.0, "candle": 0.4, "neon": 0.0, "fill": 1.0, "tvb": 1.0}],
	[3.2, {"pr": 0.45, "shelf": 0.35}],
	[7.9, {"pict": 1.0, "candle": 0.3, "neon": 0.0, "fill": 5.0}],
	[11.3, {"shelf": 0.3, "fill": 1.0}],
	[14.6, {"pict": 0.0}],
	[14.9, {"candle": 0.0, "neon": 0.0}],
	[15.2, {"pl": 0.0}],
	[15.45, {"shelf": 0.0, "fill": 0.5}],
	[15.7, {"pr": 0.0}],
	[16.0, {"pm": 0.0, "fill": 0.0, "tvb": 0.0}],
]
const CLICK := [14.6, 14.9, 15.2, 15.45, 15.7, 16.0]
#  채움 — 웅덩이 밖 바탕(안 재질 fill · 문 장면 BAR.fill 의 0.12 배 언저리 · 찬 쪽)
const FILL := Color(0.035, 0.04, 0.06)
#  상인 바탕빛 — 웅덩이 밖 소매 · 손이 가장 낮은 단 실루엣으로만 선다(셔츠가 푸른 흰빛이라 방 채움을 그대로 주니 파란
#  셔츠로 읽혔다 · 고른 회색으로 더 낮게)
const MFILL := Color(0.014, 0.014, 0.017)
#  살 바탕빛 — 살만 따뜻한 한 단 위로(손가락 틈 · 손목 밑이 MFILL 거의 검정이라 금 · 구멍으로 읽혔다 · 검토 3). 웅덩이 밖
#  팔뚝도 이 단으로 실루엣이 선다
const SKIN_FILL := Color(0.05, 0.03, 0.025)
#  주인공 소품 자리 — 손님 잔(받침째) · 상인(바닥 · 요(도) · 닦는 잔 밑동 · 기울기(도 — 일하는 손 쪽) · 숙임(도 — 입이 앉은
#  눈 쪽으로 열린다: 축이 시선과 거의 같아 테 타원이 모서리로 서서 직선이었다 · 검토 3) · 내려놓은 자리 · 가운데 펜던트가
#  겨누는 데(잔 밑동에서 — 손 · 잔 앞 · 일하는 팔뚝 쪽 · 가슴은 웅덩이 밖)) · TV(천장 걸이 · 요 · 숙임 · 기울기 축) · 잔 걸이 ·
#  양철 천장. 잔은 가슴 가까이(z 0.24) · 받치는 손 쪽(+x)으로 — 일하는 팔이 몸 옆에서 안으로 들어와 팔뚝이 그림 면을
#  가로지른다(잔이 몸 앞 33cm 면 팔뚝이 앉은 눈을 곧게 겨눠 손이 위팔 소매에서 돋은 주걱이었다 · 검토 3)
const PINT := Vector3(-0.18, -0.14, -3.86)
const MERCH := {"at": Vector3(-0.62, -1.22, -4.32), "yaw": 15.0, "glass": Vector3(0.08, 1.15, 0.24), "tilt": 35.0,
		"down": Vector3(-0.02, 1.081, 0.40), "lean": 15.0, "aim": Vector3(-0.09, 0.0, 0.08)}
const TV := {"at": Vector3(-0.10, 1.30, -4.60), "yaw": 4.0, "tilt": 15.0, "pivot": -0.4224, "aim": Vector3(-0.15, -0.14, -4.02)}
const RACK := Vector3(-0.15, 1.30, -3.86)
#  다트 테이블 — 앉은 눈에서 윗면 앞 절반이 카운터 끝에 가려 빈 잔 · 다트 · 촛불이 안 보였다. 이 장면만 테이블 무리
#  (테이블 · 촛불 · 의자 하나)를 벽 쪽으로 물리고 촛불을 테이블 먼 쪽으로 옮긴다(검토 1).
#  촛불 빛깔은 덜 진하게(채도 높은 주황 웅덩이가 다트판과 다퉜다 · 검토 2)
const TABLE := {"dz": -0.25, "candle_dz": -0.14, "pick": 0.6, "chair0": Vector3(0.56, 0.0, -4.95),
		"candle_c": Color(1.0, 0.80, 0.62)}
#  받침 채도
const HERO_K := {"coaster_sat": 0.6}
#  유리 값(GLASS_SHADER uniform) — rim_y 입술(잔 좌표 높이 — 이 위가 끊기지 않는 테 한 줄) · sy0 · sy1 빛줄 높이 띠 ·
#  body_k 몸 단 · body_y 몸 단이 서는 높이 · ef 가장자리 문턱 · base_y 두꺼운 밑 · lip 입술 바탕 · bend 너머 굴림(px).
#  손님 잔(논익 15cm · 밑 12.5mm) — 빛줄은 벽 밑끝부터 논익 굴곡 밑까지 1~2px(거품 높이에 짧게 떠 잔 밖으로 튀어나온 빨대
#  둘로 읽혔다 · 굴곡을 넘기면 테두리 그린 만화 잔의 지그재그) · 빈 윗부분만 찬 몸 한 단(뒤 병이 「유리 너머」로) · 너머
#  굴림 1px(굴린 병 모자이크가 얼룩무늬였다 · 검토 3). 닦는 빈 잔(14.8cm · 밑 9mm) — 몸 단은 거의 걷고(0.32 는 남색 카드로
#  읽혔다) 끊기지 않는 밝은 입술 · 위아래로 이은 빛줄 한 줄. 테이블 빈 잔(촛불 빛줄 · 몸 단)
const GLASS_K := {
	"pint": {"rim_y": 0.1482, "sy0": 0.012, "sy1": 0.104, "body_k": 0.22, "body_y": 0.086, "base_y": 0.0125, "hi": 0.3,
			"cut": 0.999, "bend": 1.0},
	"polish": {"rim_y": 0.143, "sy0": 0.012, "sy1": 0.14, "body_k": 0.08, "ef": 0.6, "base_y": 0.009, "hi": 0.55,
			"cut": 0.985, "lip": Color(0.30, 0.32, 0.34), "rim_k": 1.0},
	"table": {"rim_y": 0.1482, "sy0": 0.012, "sy1": 0.14, "body_k": 0.08, "ef": 0.6, "base_y": 0.0125, "hi": 0.6,
			"cut": 0.97, "rim_k": 0.8, "lip": Color(0.06, 0.05, 0.04)},
}
#  선반 병 렌더 층 — 병 뒤 밑불은 이 층만 비춘다(판 · 기둥 · 갓까지 비춰 올려다보면 판 밑면이 평평한 주황 띠였다)
const L_SHB := 1 << 6
#  테이블 렌더 층 — 촛불은 이 층만 비춘다(테이블 윗판 · 빈 잔 · 다트) — 의자 등 · 징두리 · 액자 테까지 비춰 채도 높은
#  주황 띠 셋이 다트판과 다퉜다(검토 2)
const L_TBL := 1 << 7
#  TV 빛 — 세기 · 빛깔(지지직 찬 빛 → 그림이 비친 뒤) · 원뿔 반각(손님 잔 · 그 너머 카운터만 — 넓게 비추니 주황 나무에
#  묻혀 찬 빛으로 안 읽혔다) · 단(밑값의 몫 — 0.5~2 초씩 버틴다 · 이어 붙이지 않는다) · body TV 몸 바탕(fill 빛깔 — 방 채움과
#  따로 · 마지막 펜던트에 몸이 한 틀 만에 꺼져 유리만 허공에 떴다 · 유리 반짝 검토 2) · led 전원 등 [TvRim 이 켜진 동안 · 꺼진 뒤 —
#  몸과 같은 단(홀로 뜬 불씨 점이었다)]
const TVL := {"e": 2.6, "c": Color(0.56, 0.65, 0.86), "c2": Color(0.74, 0.72, 0.74), "ang": 12.0, "lv": [0.6, 0.68, 0.76, 0.84, 0.92, 1.0],
		"hold": [0.5, 2.0], "rim": 0.2, "fog": 2.2, "body": Color(0.38, 0.42, 0.5), "led": [Color("ff3b2e"), Color8(14, 13, 16)]}
#  화면 — 지지직이 그림을 덮는 몫 [때부터, 몫](단으로 걷힌다) · 지지직 칸
const SNOW := [[0.0, 1.0], [13.4, 0.72], [13.7, 0.42], [14.0, 0.16], [14.4, 0.05], [14.9, 0.0]]
#  칸 40 × 90 — 칸이 가로 3 : 세로 1(가로 번진 인광 · Plg snow_crt) · 멈춘 TV 에서 세로 1.5px 언저리. 46 × 34(칸 8px 네모)는
#  브라운관 눈이 아니라 위장무늬 · QR 로 읽혔다(검토 3)
const SNOW_RES := Vector2(40.0, 90.0)
#  간판 — 밀기 동안 TV 그림의 HIGHTON 네온을 인트로보다 앞당겨 한 글자씩 켠다(game.plg_sign_t — 그림 속 인트로는 아직 램프
#  박자라 간판이 꺼진 검은 띠였고 제목이 다이브에서야 처음 보였다 · 검토 3). t0 부터 rate 배로 인트로 간판 시계(INTRO.sign
#  3.0 → 다 켜짐 · 붙기 전 hold)를 민다 · 넘김에 놓는다(그때 인트로는 이미 그 자리 — 다 켜지고 붙기 직전)
const SIGN := {"t0": 15.0, "rate": 0.5, "from": 3.0, "hold": 3.6}
#  상인 — 비틀기(도 · 1.5 초에 한 번 — bar_polish 의 박자 · t 0 이 정방향 가장 빠른 때) · 받치는 손이 반대로 돌리는 몫 ·
#  고쳐 쥐기 [시작, 끝, 잔을 돌리는 각] · 내려놓기 [시작, 닿음] · gone 안쪽으로 빠진 때(눈이 다트 장을 보는 동안)
const POLISH := {"a": 28.0, "per": 1.5, "back": 0.45, "regrip": [6.9, 7.25, 60.0], "down": [8.5, 8.85], "gone": 9.6}
#  일하는 손 — 집는 테 자리: 잔 축 둘레 각(0 = 일하는 손 쪽 · + 가 손님 쪽) · 높이(잔 좌표) · 반지름. 90° — 테 앞(손님 쪽)을
#  집는다: 집는 선(엄지 안 · 검지 밖)이 손님 쪽이라 손끝 축이 팔뚝을 그대로 잇고 손등이 눈을 본다(사진 — 일하는 손은 엎어
#  손등이 보는 쪽)
const WORK := {"phi": 90.0, "h": 0.147, "r": 0.044}
#  손 닿는 자리(손 단위) — 받치는 손바닥 한가운데(잔 밑동이 앉는다)
const HAND_AT := {"palm": Vector3(18.0, -8.0, 0.0)}
#  내려놓을 때 받치는 손이 옮겨 쥐는 잔 옆 — 높이(잔 좌표 · 밑에서) · 잔 축에서 손바닥까지(논익 몸 아래 1/3 의 반지름 + 살)
const SIDE := {"h": 0.07, "r": 0.041}
#  손목 한계(도) — 굽힘(손바닥 쪽) · 젖힘 · 옆 꺾임(사진: 닦는 손 굽힘 20~30° · 새끼 쪽 약 10° · 받치는 손 젖힘 10~20°)
const WRIST := {"flex": 28.0, "ext": 20.0, "dev": 14.0}
#  팔 — 위팔 길이(bar_intro.py L_UA) · 팔뚝(팔꿈치 → 손목) · 손 단위(m — prologue3d TAPE.s 0.00328 보다 5% 작게: 손 18 × 9.6cm ·
#  1배에서 손이 잔보다 커 보였다) · 팔꿈치가 굽는 쪽(어깨에서 — 바깥 x · 아래 · 뒤 — 받치는 팔꿈치는 갈비 옆에 붙는다) ·
#  pole_R 일하는 팔만 — 팔꿈치를 옆 · 조금 앞으로 들어(비틀 때 일하는 팔꿈치가 든다) 팔뚝이 몸 옆에서 안으로 · fs 맨 팔뚝
#  단면 몫(game _fore3_fit — 맨 팔뚝이 잔보다 가늘어 막대에 붙은 큰 손이었다 · 손 : 팔뚝 ≈ 0.9 : 1)
const ARM := {"ua": 0.2956, "fa": 0.27, "s": 0.0031, "pole": Vector3(0.10, -0.60, -0.15),
		"pole_R": Vector3(0.45, -0.45, 0.10), "fs": 1.3}
#  손가락 [첫 굽힘 ×4 · 끝 굽힘 ×4 · 부채 · 엄지 접기 · 엄지 굽힘 · 엄지 내림](game.gd FPOSE 차례)
const HPOSE := {
	"pinch": [42.0, 70.0, 85.0, 95.0, 46.0, 82.0, 92.0, 100.0, 7.0, 0.45, 26.0, 16.0],
	"cup": [48.0, 56.0, 62.0, 68.0, 34.0, 40.0, 46.0, 52.0, 3.0, 0.15, 24.0, 12.0],
}

#  바 안 재질 — 문 장면의 IN_SHADER 를 이 장면만 고친 사본. 빛의 감쇠(거리 · 원뿔)는 매끈하게 두고 면의 빛 각도만
#  둥근 것에서 nb 단으로 끊는다(평평한 판 · 벽 · 바닥은 0 — 웅덩이에 고리가 안 선다) · 바탕빛은 방향 없이 고르게
#  (눈이 돌아도 결 그늘이 안 뒤집힌다) · sat 채도.
static var _in_sh: Shader = null
const IN_LIGHT_OLD := """	float v = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	DIFFUSE_LIGHT += steps(v, FRAGCOORD.xy) * LIGHT_COLOR / PI;"""
const IN_LIGHT_NEW := """	float g = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	g = nb > 0.0 ? floor(g * nb + 0.5) / nb : g;
	DIFFUSE_LIGHT += g * ATTENUATION * LIGHT_COLOR / PI;"""
const IN_FK_OLD := "float fk = floor(clamp(0.6 + 0.55 * dot(fn, FD), 0.3, 1.2) * 5.0 + 0.5) / 5.0;"
const IN_ALB_OLD := """	ALBEDO = c.rgb;
	EMISSION = c.rgb * (fill * fk + vec3(glow_k));"""
const IN_ALB_NEW := """	vec3 cc = mix(mid, c.rgb, con);
	ALBEDO = mix(vec3(dot(cc, vec3(0.2126, 0.7152, 0.0722))), cc, sat);
	EMISSION = ALBEDO * (fill * fk + vec3(glow_k));"""

#  유리 — 너머를 굴려 비춘다(화면 그림 · 온 px 만큼만 밀고 덩어리로 — 유리 너머는 늘 초점 밖이다) · 스치는 면은 세
#  단으로 어둡다(테가 검은 선으로 선다) · 빛을 비추는 자리만 단단한 반짝 줄(빛 자리에서 — 붙인 도형이 아니다).
const GLASS_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, fog_disabled;
uniform sampler2D scr : hint_screen_texture, filter_nearest;
uniform sampler2D dep : hint_depth_texture, filter_nearest;
uniform vec3 tint : source_color = vec3(0.86, 0.92, 0.90);
uniform float f0 = 0.0;
uniform float f1 = 999.0;
uniform float bmin = 1.0;
uniform float bmax = 4.0;
uniform vec4 lp0 = vec4(0.0);
uniform vec4 lp1 = vec4(0.0);
uniform vec4 lp2 = vec4(0.0);
uniform vec3 lc0 : source_color = vec3(1.0, 0.81, 0.54);
uniform vec3 lc1 : source_color = vec3(1.0, 0.81, 0.54);
uniform vec3 lc2 : source_color = vec3(0.62, 0.68, 0.80);
uniform float bend = 5.0;
uniform float cut = 0.993;
uniform float cut2 = 0.995;
uniform float hi = 0.55;
uniform vec3 edge : source_color = vec3(0.035, 0.03, 0.026);
//  몸 단 — 실루엣 안을 찬 회색 한 단으로 덮는다(너머만 비치면 빛줄만 남아 두 손 사이에 걸린 실로 읽혔다 · 검토 2) ·
//  가장자리 단 문턱(fresnel — 낮을수록 두껍다) · 두꺼운 밑(잔 좌표 높이 이 밑은 한 단 밝은 렌즈) · 빛줄이 서는 높이 띠
//  (밖은 없다 — 처음부터 끝까지 이은 줄 · 논익 굴곡의 지그재그가 테두리 그린 만화 잔으로 읽혔다) · 입술 바탕(밝은 입술 한 단)
uniform vec3 body : source_color = vec3(0.20, 0.22, 0.25);
uniform float body_k = 0.0;
uniform float ef = 0.86;
uniform float base_y = -1.0;
uniform float sy0 = -1.0;
uniform float sy1 = 999.0;
uniform vec3 lip : source_color = vec3(0.0);
//  몸 단이 서는 높이(잔 좌표 — 이 위만 · 맥주가 든 아래는 맥주가 맡는다) · nsh 1 이면 초점 띠 앞(가까운 전경)은 덩어리 없이
uniform float body_y = -1.0;
uniform float nsh = 0.0;
//  입술 — 잔 좌표 높이 이 위는 끊기지 않는 어두운 한 줄(점선 고리 · 떠 있는 밝은 타원으로 읽혔다) · 빛 자리만 짧게 밝다 · 999 면 없다
uniform float rim_y = 999.0;
uniform float rim_k = 0.45;
varying float my;
varying float mo;
varying vec3 wp;
varying vec3 wn;

void vertex() {
	my = VERTEX.y;
	mo = dot(NORMAL.xz, VERTEX.xz);     // 바깥 벽(+) · 안 벽(−) — 빛줄은 앞 바깥 벽에만(안 벽까지 그으면 철사 그림이 됐다)
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

//  세로 빛줄 — 바닥 평면에 눕혀 본 반사가 빛 쪽을 볼 때만(둥근 벽을 따라 위아래로 곧게 선다 · 빛 자리에서 난다)
float strip(vec4 lp, vec3 r, float c) {
	vec2 l = normalize(lp.xz - wp.xz);
	return lp.w * step(c, dot(normalize(r.xz + vec2(1e-5)), l));
}

float want(float z) {
	float o = max(f0 - z, z - f1);
	if (o <= 0.0 || (nsh > 0.5 && z < f0)) {
		return 1.0;
	}
	float r = o / max(f1, 0.2);
	return r < 0.35 ? 2.0 : (r < 1.0 ? 4.0 : 8.0);
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float f = 1.0 - abs(dot(n, v));
	vec2 vs = VIEWPORT_SIZE;
	//  너머 그림 — 온 px 만큼 굴려 밀고, 화면 덩어리 흐림(POST_SHADER)과 같은 셈으로 그 깊이의 덩어리를 고른다
	vec2 fc = floor(FRAGCOORD.xy + round(n.xy * bend));
	vec2 uv = (fc + 0.5) / vs;
	for (int k = 3; k >= 1; k--) {
		float s = exp2(float(k));
		if (s > bmax) {
			continue;
		}
		vec2 bc = (floor(fc / s) * s + s * 0.5) / vs;
		vec4 vw = INV_PROJECTION_MATRIX * vec4(bc * 2.0 - 1.0, texture(dep, bc).r, 1.0);
		if (max(want(-vw.z / vw.w), bmin) >= s) {
			uv = bc;
			break;
		}
	}
	vec3 c = texture(scr, clamp(uv, vec2(0.0), vec2(1.0))).rgb * tint;
	c = mix(c, body, my > body_y ? body_k : 0.0);
	if (my < base_y) {
		c = c * 1.3 + body * 0.35;
	}
	c = f > ef ? max(c * 0.3, edge) : c * (f > 0.6 ? 0.7 : 1.0);
	vec3 r = reflect(-normalize(CAMERA_POSITION_WORLD - wp), normalize(wn));
	if (my > rim_y) {
		//  입술 — 끊기지 않는 어두운 한 줄 · 빛을 비추는 자리만 짧게 밝다(빛깔은 그 빛 — TV 의 찬 단도 여기 든다)
		c = c * 0.35 + lip + rim_k * (lc0 * strip(lp0, r, 0.9) + lc1 * strip(lp1, r, 0.9) + 2.0 * lc2 * strip(lp2, r, 0.7));
	} else if (mo > 0.0 && my > sy0 && my < sy1 && f < 0.55) {
		c += hi * (lc0 * strip(lp0, r, cut) + lc1 * strip(lp1, r, cut) + lc2 * strip(lp2, r, cut2));
	}
	ALBEDO = c;
}
"""
static var _glass_sh: Shader = null

#  맥주 — 두 띠(밑 짙고 · 몸) + 면 바로 밑 1px 밝은 줄 · 뒤에서 TV 가 받치면 제 빛이 단으로 든다(glow). 빛은 액체 속에서
#  흩어져 면 각도를 안 탄다 — 각도 단을 끊었더니 곧은 면 3~4 띠의 다각 기둥 · 층진 칵테일로 읽혔다(검토 1).
const BEER_SHADER := """
shader_type spatial;
uniform vec3 col : source_color = vec3(0.78, 0.47, 0.13);
uniform vec3 lo : source_color = vec3(0.42, 0.19, 0.05);
uniform vec3 top : source_color = vec3(0.98, 0.80, 0.42);
uniform float y0 = 0.0127;
uniform float y1 = 0.0762;
uniform float glow = 0.1;
varying float my;
void vertex() {
	my = VERTEX.y;
}
void fragment() {
	float h = (my - y0) / (y1 - y0);
	vec3 c = h < 0.4 ? lo : col;
	c = h > 0.94 ? top : c;
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = c * glow;
}
void light() {
	DIFFUSE_LIGHT += 0.6 * ATTENUATION * LIGHT_COLOR / PI;
}
"""
static var _beer_sh: Shader = null

#  깊이 덩어리 흐림 — 화면 한 장(층 맨 앞 · 투명 차례 맨 처음)이 깊이 그림을 읽어 초점 띠 밖을 2 · 4 · 8px 덩어리로
#  뭉갠다(덩어리 한가운데의 깊이로 고른다 — 고운 흐림이 아니라 도트 단). 주인공 유리는 이 뒤에 그려 또렷하다.
const POST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;
uniform sampler2D scr : hint_screen_texture, filter_nearest;
uniform sampler2D dep : hint_depth_texture, filter_nearest;
uniform float f0 = 0.0;
uniform float f1 = 999.0;
uniform float bmin = 1.0;
uniform float bmax = 4.0;
uniform float nsh = 0.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float lin(vec2 uv, mat4 ip) {
	float d = texture(dep, uv).r;
	vec4 v = ip * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

float want(float z) {
	float o = max(f0 - z, z - f1);
	if (o <= 0.0 || (nsh > 0.5 && z < f0)) {
		return 1.0;
	}
	float r = o / max(f1, 0.2);
	return r < 0.35 ? 2.0 : (r < 1.0 ? 4.0 : 8.0);
}

void fragment() {
	vec2 vs = VIEWPORT_SIZE;
	vec2 fc = floor(FRAGCOORD.xy);
	vec2 uv = (fc + 0.5) / vs;
	for (int k = 3; k >= 1; k--) {
		float s = exp2(float(k));
		if (s > bmax) {
			continue;
		}
		vec2 c = (floor(fc / s) * s + s * 0.5) / vs;
		if (max(want(lin(c, INV_PROJECTION_MATRIX)), bmin) >= s) {
			uv = c;
			break;
		}
	}
	ALBEDO = texture(scr, uv).rgb;
}
"""


#  묶음 — 무대 · 층 · 소리 자리가 다 이 밑이다. 걷힐 때 제 버스(로패스)를 같이 걷는다(넘김 · 일찍 끊음).
class Hold extends Node:
	var bus := ""
	var spk := []         # SFX 버스에 건 TV 스피커 효과(고역 · 저역 · 줄임)

	func _exit_tree() -> void:
		spk_off()
		var bi := AudioServer.get_bus_index(bus) if bus != "" else -1
		if bi >= 0:
			AudioServer.remove_bus(bi)
		bus = ""

	func spk_on() -> void:
		var bi := AudioServer.get_bus_index("SFX")
		if bi < 0 or not spk.is_empty():
			return
		var tv: Array = SND.tv
		var hp := AudioEffectHighPassFilter.new()
		hp.cutoff_hz = float(tv[0])
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = float(tv[1])
		var am := AudioEffectAmplify.new()
		am.volume_db = float(tv[2])
		spk = [hp, lp, am]
		for e in spk:
			AudioServer.add_bus_effect(bi, e)

	func spk_off() -> void:
		var bi := AudioServer.get_bus_index("SFX")
		if bi >= 0:
			for i in range(AudioServer.get_bus_effect_count(bi) - 1, -1, -1):
				if spk.has(AudioServer.get_bus_effect(bi, i)):
					AudioServer.remove_bus_effect(bi, i)
		spk = []


#  유리 뚫기 — 끝 거리 · portal · 반짝 · 번쩍 단은 테이프 Plg 값 그대로(HERO.dive · HERO.portal · GLINT). 다가감 몫만 제 것:
#  creep [ua · ub · uh · vp · vh] — 다가감은 제 밀기(MOVE push)가 맡아 vp · vh 0(다이브는 uh 까지 서 있다가 세제곱으로만
#  뛰어든다) · uh 는 테이프와 같아 빗금 · 별이 뛰어듦에 같은 자리로 걸린다. star 별 자리(유리 UV — 테이프 자리 0.86 · 0.26 은
#  이 그림에서 HIGHTON 간판 끝이라 네온과 다퉜다 · 간판을 비켜 오른 위 귀의 어두운 벽돌 위 — 숙여 단 유리의 위 어깨가 TV 빛 ·
#  펜던트를 받는 자리 · 굵은 띠가 GLINT.at 앞 틀에 지난다) · land portal 끝 그림 밝기 몫(테이프 0.75 — 이 무대 톤 매핑으로는
#  H−6 유리가 게임 속 H+6 보다 16% 밝고 붉었다 · 필터를 켠 게임 그림에 맞춘다) · sat portal 끝 그림 채도 몫(SCR sat — 필터를
#  안 지난 유리 그림이 자홍으로 짙어 문 채도 0.54 · 간판 띠 0.65 가 게임 속 0.43 · 0.56 이었고 번쩍이 빠지는 1/3 틀에 분홍
#  자리에 갈색이 붙어 보였다 · 유리 반짝 검토) · gcol 빗금 · 별 빛깔(SCR gcol · 선형) — 찬 TV 빛 쪽으로 한 단(테이프의 중성
#  흰빛은 불 꺼진 방에서 무엇을 비추는지 모를 그래픽이었다 · 유리 반짝 검토 2)
#  mode 들어가는 꼴 — "phosphor" 인광 점 속으로(Plg PHOS · 머리말 7) · "glint" 옛 반짝 · 번쩍(테이프와 같다 — creep uh
#  = 16.7 · MOVE push 끝에서 뛰어든다). phosphor 는 handoff − Plg.phos_lunge() 에 뛰어들어 다가감을 제 곡선으로 민다(_phos_d —
#  유리 배가 PHOS.take 에 닿는 틀이 Phos 첫 단 · 그 뒤 3D 는 Phos 밑에서 고른 빠르기로 handoff 까지 — 끝 배는 end 를 안 넘는다:
#  그 거리가 카메라 near 0.02m 보다 멀어야 유리 한가운데가 카메라 앞에 남는다). 들어가는 소리(bar_phos)는 파일
#  phos_lunge() 초가 handoff 다(sfx_bar.py 가 같은 표로 굽는다).
const DIVE := {"mode": "phosphor", "creep": [0.0, 0.0, 0.416667, 0.0, 0.0], "star": Vector2(0.92, 0.14), "land": 0.59,
		"sat": 0.75, "gcol": Vector3(0.55, 0.70, 0.95), "end": 30.0}


static func length() -> float:
	return LEN


#  유리를 뚫는 때(번쩍이 다 덮는 첫 틀) — 무대가 끊긴다.
static func handoff() -> float:
	return float(T.dive1)


#  게임 필터가 켜지는 때 · CRT 잔상을 되살리는 때(game.gd _plg_cover · _crt_apply — 테이프 Plg 와 같은 이름 · 같은 틀).
static func lit_at() -> float:
	return handoff() + (float((Plg.PHOS if _phos() else Plg.GLINT).lit) - 0.5) / 60.0


static func calm_at() -> float:
	return handoff() + (float((Plg.PHOS if _phos() else Plg.GLINT).calm) - 0.5) / 60.0


static func _phos() -> bool:
	return String(DIVE.mode) == "phosphor"


#  TV 가 게임 그림을 틀기 시작하는 때 — 게임의 인트로 시계가 이때 출발한다(지지직 사이로 비친다).
static func feed_at() -> float:
	return float(T.feed)


#  소리는 이 장면이 제 자리에서 낸다(로패스 버스 · 박자) — game.gd 가 낼 것이 없다. 유리 반짝의 삐싱(tv_glint)은 테이프에만
#  난다(2026-10-28 「바텐더 오프닝에서 삐씽 효과음은 쫌 뺄까?」).
static func cues() -> Dictionary:
	return {}


#  들어가는 때 — TV 소리를 걷는 기준 · 인광 점 속으로는 뛰어듦 첫 틀에 들어가는 소리(bar_phos)를 낸다(믹서가 한 틀 늦게
#  내므로 한 틀 앞당긴다). 옛 반짝은 테이프의 삐싱 큐와 같은 자리(handoff − GLINT.cue).
static func entry_at() -> float:
	return lunge_at() - 1.0 / 60.0 if _phos() else handoff() - float(Plg.GLINT.cue)


#  뛰어듦이 시작하는 때 — 인광 점 속으로는 handoff − Plg.phos_lunge()(밀기 꼬리 위) · 옛 반짝은 creep uh 몫(밀기가 서는 때)
static func lunge_at() -> float:
	if _phos():
		return handoff() - Plg.phos_lunge()
	return float(T.dive0) + float(DIVE.creep[2]) * (handoff() - float(T.dive0))


# ══ 짓기 ═══════════════════════════════════════════════════
#  game — 인트로를 그리는 게임(그 화판 그림이 TV 에 뜬다) · outer — 화판 밖(game.screen_host).
static func make(game: Node, outer: Node) -> Node:
	var hn := Hold.new()
	hn.name = "PrologueBar"
	outer.add_child(hn)
	var sz: Vector2 = game.get_viewport().get_visible_rect().size
	var vp := SubViewport.new()
	vp.name = "Stage"
	vp.size = Vector2i(maxi(int(sz.x), 2), maxi(int(sz.y), 2))
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.gui_disable_input = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	#  그림자 지도 — 가운데 펜던트가 한 사분면을 혼자 · 오른 펜던트 · TV 는 둘째 사분면(단단한 테 · 1px 가 안 기게)
	vp.positional_shadow_atlas_size = 4096
	vp.positional_shadow_atlas_quad_0 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1
	vp.positional_shadow_atlas_quad_1 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4
	hn.add_child(vp)
	var w := Node3D.new()
	w.name = "World"
	vp.add_child(w)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = false
	#  옅은 안개 — 제 빛 · 바탕빛이 없어 빛을 받은 데만 선다. TV 빛만 안개에 줄기를 세운다(펜던트는 0 · 둥근 안개 공 금지).
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.82, 0.80, 0.78)
	env.volumetric_fog_emission = Color.BLACK
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_length = 3.0
	env.volumetric_fog_ambient_inject = 0.0
	env.volumetric_fog_gi_inject = 0.0
	env.volumetric_fog_sky_affect = 0.0
	env.volumetric_fog_temporal_reprojection_amount = 0.6
	we.environment = env
	w.add_child(we)
	hn.set_meta("env", env)
	var cam := Camera3D.new()
	cam.near = 0.02
	cam.far = 30.0
	w.add_child(cam)
	hn.set_meta("cam", cam)
	hn.set_meta("vp", vp)
	hn.set_meta("game", game)
	#  세트 — 제목 문 안의 술집 그대로 짓고 이 장면만 고친다
	Door3D._inside(w)
	var bar := w.get_node("Bar") as Node3D
	_patch(hn, w, bar)
	_props(hn, w)
	_merchant(hn, w, game)
	var feed: Texture2D = game.get_viewport().get_texture()
	_tv(hn, w, feed, sz)
	_lights_make(hn, w, bar)
	_post_make(hn, w)
	_lids_make(hn, vp)
	_layer_make(hn, vp, outer)
	_audio_make(hn, game)
	tick(hn, 0.0)
	return hn


#  안 재질 하나(이 장면 사본) — col 맨 색 · nb 둥근 것의 빛 단
static func _inm(hn: Node, col: Color, nb := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _in_shader()
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("nb", nb)
	m.set_shader_parameter("fill", FILL)
	(hn.get_meta("ins") as Array).append(m)
	return m


static func _in_shader() -> Shader:
	if _in_sh == null:
		var code: String = Door3D.IN_SHADER
		var ok: bool = code.contains(IN_LIGHT_OLD) and code.contains(IN_FK_OLD) and code.contains(IN_ALB_OLD)
		if not ok:
			push_warning("prologue_bar3d — Door3D.IN_SHADER 가 바뀌어 빛 고침이 안 먹는다")
		code = code.replace(IN_LIGHT_OLD, IN_LIGHT_NEW).replace(IN_FK_OLD, "float fk = 0.8;") \
				.replace(IN_ALB_OLD, IN_ALB_NEW).replace("uniform float seam = 0.15;",
				"uniform float seam = 0.15;\nuniform float nb = 0.0;\nuniform float sat = 1.0;\nuniform float con = 1.0;\n"
				+ "uniform vec3 mid : source_color = vec3(0.0);")
		_in_sh = Shader.new()
		_in_sh.code = code
	return _in_sh


#  세트 고치기 — 안 재질을 사본으로(반짝 0 · 찬 바탕 · 평평한 판은 빛 단 없음 · 둥근 것은 4 단), 빛무리 · 바닥 그늘 막 ·
#  전구 · 거울 비침 · 도트 잔 그림을 걷고, 술병 그림은 눈을 보게 돌려 채도를 누르고 어둡게, 카운터 코는 팔걸이로.
static func _patch(hn: Node, w: Node3D, bar: Node3D) -> void:
	hn.set_meta("ins", [])
	var conv := {}
	var glows := []
	var eye: Vector3 = POSE.merch[0]
	var hide_bulb := ShaderMaterial.new()
	hide_bulb.shader = Shader.new()
	hide_bulb.shader.code = "shader_type spatial;\nrender_mode unshaded;\nvoid fragment() {\n\tdiscard;\n}\n"
	for n in bar.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var mo := mi.material_override
		#  빛무리 · 바닥 그늘 막(고운 그러데이션) — 이 장면은 진짜 그림자 · 어둠이 맡는다
		if mo is StandardMaterial3D and (mo as StandardMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			mi.visible = false
			continue
		if mi.mesh == Door3D._bar_mesh.get("CntNose"):
			mi.visible = false
			continue
		#  그림 카드(Door3D._sprite — 이름은 겹쳐 붙으며 바뀌므로 재질로 가린다: 잘라 내기 0.5 · 위로 든 노멀 · 제 빛 몫)
		var spr := false
		if mi.mesh is QuadMesh and mo is ShaderMaterial and (mo as ShaderMaterial).shader == Door3D._in_sh:
			var sm := mo as ShaderMaterial
			var gk: float = _num(sm.get_shader_parameter("glow_k"))
			var cut: float = _num(sm.get_shader_parameter("cut"))
			var tint: Color = sm.get_shader_parameter("tint")
			if cut > 0.4 and (is_equal_approx(gk, 0.3) or is_equal_approx(gk, 0.4) or not tint.is_equal_approx(Color.WHITE)):
				mi.visible = false            # 도트 잔(0.3 · 0.4) · 거울 비침(어두운 색) — 잔은 3D 로 바꿔 놓는다
				continue
			if cut > 0.4 and is_equal_approx(gk, 0.12):
				spr = true
				mi.rotation.y = atan2(eye.x - mi.position.x, eye.z - mi.position.z)
				mi.layers = L_IN | L_SHB          # 선반 병 — 뒤 밑불은 이 층만 비춘다
		#  다트 장 칠판(분필 점수) — 글로 읽히지 않게 한 단 어둡게
		var chalk: bool = mi.mesh is QuadMesh and absf((mi.mesh as QuadMesh).size.y - (float(Door3D.BAR.cab) * 2.0 - 0.05)) < 0.001
		var pr := mi.mesh is BoxMesh or mi.mesh is QuadMesh or mi.mesh is PlaneMesh
		var nb: float = 0.0 if pr else 4.0
		#  카운터 윗판 — 이 장면만 나무를 한 단 누르고 결 대비를 반으로(웅덩이가 밝은 주황 줄결 판이었다 · 검토 1)
		var B: Dictionary = Door3D.BAR
		var top: bool = mi.mesh is BoxMesh and absf((mi.mesh as BoxMesh).size.y - 0.05) < 0.001 \
				and absf(mi.position.y - (float(B.cnt_y) - 0.025)) < 0.001
		var slots := [mo]
		if mo == null:
			slots = []
			for k in mi.mesh.get_surface_count():
				slots.append(mi.get_surface_override_material(k))
		for k in slots.size():
			var om: Material = slots[k]
			if om is StandardMaterial3D:
				var gm := om as StandardMaterial3D
				if gm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
					if gm.emission_energy_multiplier >= 3.9 and gm.albedo_color.is_equal_approx(Color("fbf6ea")):
						#  전구 — 갓 밑으로 2cm 삐져나와 올려다보면 큰 크림 공이다(젖빛 판이 막는다)
						if mo == null:
							mi.set_surface_override_material(k, hide_bulb)
						else:
							mi.visible = false
					elif not glows.has(gm):
						glows.append(gm)
				continue
			if not (om is ShaderMaterial) or (om as ShaderMaterial).shader != Door3D._in_sh:
				continue
			var key := "%d_%d_%d_%d" % [om.get_instance_id(), int(nb), int(chalk), int(top)]
			if not conv.has(key):
				var nmat := (om as ShaderMaterial).duplicate() as ShaderMaterial
				nmat.shader = _in_shader()
				nmat.set_shader_parameter("gloss", 0.0)
				nmat.set_shader_parameter("fill", FILL)
				nmat.set_shader_parameter("nb", nb)
				if chalk:
					nmat.set_shader_parameter("tint", Color(0.12, 0.12, 0.12))
				if top:
					#  선형 0.6 배(색 값 0.79) · 결은 나무 맨색 둘레로 반만
					nmat.set_shader_parameter("tint", Color(0.79, 0.79, 0.79))
					nmat.set_shader_parameter("con", 0.5)
					nmat.set_shader_parameter("sat", 0.75)
					nmat.set_shader_parameter("mid", (B.wood as Color) * 0.79)
				if spr:
					#  선반 병 — 채도 · 밝기를 누르고 제 빛을 거의 걷는다(사탕 빛깔 금지 · 주인공만 제 빛깔)
					nmat.set_shader_parameter("sat", 0.5)
					nmat.set_shader_parameter("tint", Color(0.62, 0.6, 0.6))
					nmat.set_shader_parameter("glow_k", 0.02)
				conv[key] = nmat
				(hn.get_meta("ins") as Array).append(nmat)
			if mo != null:
				mi.material_override = conv[key]
			else:
				mi.set_surface_override_material(k, conv[key])
		if mi.mesh == Door3D._bar_mesh.get("Lamp"):
			#  펜던트 갓 밑 젖빛 판(bar_intro PendDiffuser) — 등마다 제 재질(한 등씩 꺼진다)
			var pd := _glb_mesh("PendDiffuser")
			if pd != null:
				var di := MeshInstance3D.new()
				di.name = "Diffuser"
				di.mesh = pd
				var fm := Room3D._glow(Color("b89a6a"), 0.45)
				di.material_override = fm
				di.layers = L_IN
				#  갓 속 깊이 올려 줄인다 — 올려다보면 치마가 대부분을 가려 반달만 비친다(큰 크림 원판 금지)
				di.position = Vector3(0.0, 0.08, 0.0)
				di.scale = Vector3(0.52, 1.0, 0.52)
				mi.add_child(di)
				var ds: Array = hn.get_meta("diff", [])
				ds.append({"m": fm, "x": mi.position.x})
				hn.set_meta("diff", ds)
		if mi.mesh == Door3D._bar_mesh.get("Tap"):
			#  탭은 카운터 뒤끝으로 물린다 — 뺨 눈 코앞에 물받이 상자가 섰다 · 오른쪽으로 빼면 다트 장 쪽 테이블을 가렸다(이 장면만)
			mi.position.z -= 0.18
			mi.layers = L_IN | L_HERO
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			#  탭은 앞 켜 실루엣 — 놋쇠가 밝은 노랑 점으로 튀지 않게 한 단 누른다
			for k in mi.mesh.get_surface_count():
				var tm := mi.get_surface_override_material(k) as ShaderMaterial
				if tm != null:
					var dm := tm.duplicate() as ShaderMaterial
					dm.set_shader_parameter("tint", (tm.get_shader_parameter("tint") as Color) * 0.3)
					mi.set_surface_override_material(k, dm)
					(hn.get_meta("ins") as Array).append(dm)
	#  제 빛 재질 — 바탕색이 곧 밝기(빛 없음 재질). 무리로 나눠 빛과 같이 끈다.
	var gl := {"shelf": [], "cab": [], "neon": [], "candle": [], "shade": []}
	for gm in glows:
		var c: Color = gm.albedo_color
		var e: float = gm.emission_energy_multiplier
		var grp := ""
		if c.is_equal_approx(Door3D.BAR.lamp):
			grp = "shelf" if is_equal_approx(e, 1.6) else "cab"
		elif c.is_equal_approx(Color("f2b134")) or (c.is_equal_approx(Color("fbf6ea")) and is_equal_approx(e, 2.0)):
			grp = "neon"
		elif c.is_equal_approx(Color("b03a32")) or (c.is_equal_approx(Color("fdeaa0")) and is_equal_approx(e, 3.0)):
			grp = "candle"
		elif c.is_equal_approx(Color("fdeaa0")):
			grp = "shade"
		if grp != "":
			(gl[grp] as Array).append({"m": gm, "c": c})
	hn.set_meta("glows", gl)
	#  테이블 무리 — 벽 쪽으로 물린다(앉은 눈에서 윗면 앞 절반이 카운터 끝에 가렸다) · 촛불은 테이블 먼 쪽으로 한 번 더.
	#  테이블 앞 의자는 밀려난 채(방금 누가 일어났다) — 앉은 눈과 테이블 사이에 서서 윗면을 가렸다 — 테이블 너머 벽 쪽으로
	#  빼고 비스듬히 돌린다. 의자는 채도 · 밝기를 누른다(다트 장면에서 가장 채도 높은 빨강이었다).
	var tc: Vector2 = Door3D.BAR.table
	var cp := Vector2(tc.x + 0.02, tc.y + 0.10)
	var chs: Array = Door3D.BAR.chairs
	var cmat := {}
	for c in bar.get_children():
		if not (c is Node3D):
			continue
		var n3 := c as Node3D
		var xz := Vector2(n3.position.x, n3.position.z)
		if xz.distance_to(tc) > float(TABLE.pick):
			continue
		n3.position.z += float(TABLE.dz)
		if xz.distance_to(cp) < 0.05:
			n3.position.z += float(TABLE.candle_dz)
		var chair := -1
		for i in chs.size():
			if xz.distance_to(Vector2(float(chs[i][0]), float(chs[i][1]))) < 0.01:
				chair = i
		if chair < 0:
			for gi in [n3] + n3.find_children("*", "GeometryInstance3D", true, false):
				if gi is GeometryInstance3D:
					(gi as GeometryInstance3D).layers |= L_TBL
			continue
		if chair == 0:
			n3.position = (TABLE.chair0 as Vector3) + Vector3(0.0, float(Door3D.BAR.floor), 0.0)
			n3.rotation.y = 2.3
		for cm in n3.find_children("*", "MeshInstance3D", true, false):
			var ci := cm as MeshInstance3D
			for k in (ci.mesh.get_surface_count() if ci.mesh != null else 0):
				var sm := ci.get_surface_override_material(k) if ci.material_override == null else ci.material_override
				if not (sm is ShaderMaterial) or (sm as ShaderMaterial).shader != _in_shader():
					continue
				if not cmat.has(sm):
					var dm := (sm as ShaderMaterial).duplicate() as ShaderMaterial
					dm.set_shader_parameter("sat", 0.55)
					dm.set_shader_parameter("tint", (sm.get_shader_parameter("tint") as Color) * 0.8)
					(hn.get_meta("ins") as Array).append(dm)
					cmat[sm] = dm
				if ci.material_override != null:
					ci.material_override = cmat[sm]
				else:
					ci.set_surface_override_material(k, cmat[sm])


#  셰이더 값(안 준 값은 null — 기본값 0)
static func _num(v: Variant) -> float:
	return 0.0 if v == null else float(v)


#  glb 메시 · 빈 노드 변환(이름 → 처음 부를 때 한 번 읽는다)
static var _mesh := {}
static var _xf := {}


static func _glb_mesh(nm: String) -> Mesh:
	if _mesh.is_empty():
		_mesh[""] = null
		var ps: PackedScene = load(GLB) as PackedScene if ResourceLoader.exists(GLB) else null
		var sc: Node = ps.instantiate() if ps != null else null
		if sc != null:
			for c in sc.find_children("*", "Node3D", true, false):
				_xf[String(c.name)] = (c as Node3D).transform
				if c is MeshInstance3D:
					_mesh[String(c.name)] = (c as MeshInstance3D).mesh
			sc.free()
	return _mesh.get(nm)


#  glb 메시 하나를 재질 이름으로 입혀 세운다
static func _glb_mi(nm: String, mats: Dictionary, at := Vector3.ZERO, layers := L_IN) -> MeshInstance3D:
	var me := _glb_mesh(nm)
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.position = at
	mi.layers = layers
	if me == null:
		return mi
	mi.mesh = me
	for k in me.get_surface_count():
		var sm: Material = me.surface_get_material(k)
		var key: String = sm.resource_name if sm != null else ""
		if mats.has(key):
			mi.set_surface_override_material(k, mats[key])
	return mi


static func _glass_set(m: ShaderMaterial, d: Dictionary) -> void:
	for k in d:
		m.set_shader_parameter(k, d[k])


static func _glass_mat(hn: Node) -> ShaderMaterial:
	if _glass_sh == null:
		_glass_sh = Shader.new()
		_glass_sh.code = GLASS_SHADER
	var m := ShaderMaterial.new()
	m.shader = _glass_sh
	if not hn.has_meta("glass"):
		hn.set_meta("glass", [])
	(hn.get_meta("glass") as Array).append(m)
	return m


#  주인공 소품 — 손님 잔 · 받침 · 팔걸이 · 고무 매트 · 테이블에 남은 빈 잔 둘 · 다트 둘 · 카운터 왼끝 잔 ·
#  천장 잔 걸이 · 양철 천장.
static func _props(hn: Node, w: Node3D) -> void:
	var B: Dictionary = Door3D.BAR
	if _beer_sh == null:
		_beer_sh = Shader.new()
		_beer_sh.code = BEER_SHADER
	var beer := ShaderMaterial.new()
	beer.shader = _beer_sh
	hn.set_meta("beer", beer)
	var pm := {
		"glass": _glass_mat(hn), "beer": beer, "foam": _inm(hn, Color("efe2c2"), 3.0),
		"coaster": _inm(hn, Color("7a2a20")), "coaster_ink": _inm(hn, Color("d8c9a8")),
		"coaster_wet": _inm(hn, Color("4a1812")), "card": _inm(hn, Color("b8ab90")),
		"rail": _inm(hn, B.wood, 4.0), "wood_dk": _inm(hn, B.wood_dk), "rubber": _inm(hn, Color("161214")),
		"wood": _inm(hn, B.wood, 4.0), "nut": _inm(hn, Color("9a6a32"), 3.0), "iron": _inm(hn, Color("1c1a1c"), 4.0),
		"tin": _inm(hn, Color("4a4038"), 4.0),
	}
	hn.set_meta("pm", pm)
	_glass_set(pm.glass, GLASS_K.pint)
	#  받침 잉크 채도를 누른다(빨강 · 크림 과녁이 화면에서 가장 채도 높았다) · 거품 옆면은 흩어진 빛으로 한 단 밝다
	#  (그늘진 옆이 거품 밑 검은 띠로 읽혔다)
	for k in ["coaster", "coaster_ink", "coaster_wet"]:
		(pm[k] as ShaderMaterial).set_shader_parameter("sat", float(HERO_K.coaster_sat))
	(pm.foam as ShaderMaterial).set_shader_parameter("glow_k", 0.22)
	var hero := L_IN | L_HERO
	var co := _glb_mi("Coaster", pm, PINT, hero)
	w.add_child(co)
	var pt := _glb_mi("Pint", pm, PINT + Vector3(0.0, 0.0022, 0.0), hero)
	pt.rotation_degrees.y = 20.0
	w.add_child(pt)
	hn.set_meta("pint", pt)
	var pb := _glb_mi("PintBeer", pm, PINT + Vector3(0.0, 0.0022, 0.0), hero)
	pb.rotation_degrees.y = 20.0
	w.add_child(pb)
	#  팔걸이 — 카운터 코(CntNose) 자리 그대로(앉은 눈에서 니스 반짝이 큰 크림 원판이던 것 · 재질 rail)
	var x0: float = B.x0
	var x1: float = B.cnt_x1
	var rl := _glb_mi("CntRail", pm, Vector3((x0 + x1) * 0.5, float(B.cnt_y), float(B.cnt_z) + 0.08))
	rl.scale = Vector3(x1 - x0 + 0.06, 1.0, 1.0)
	w.add_child(rl)
	w.add_child(_glb_mi("BarMat", pm, Vector3(-0.32, float(B.cnt_y), -3.98)))
	#  카운터 왼끝 — 누가 두고 간 반 잔(어둠 속 엑스트라)
	var lx := Vector3(-1.95, float(B.cnt_y), -3.70)
	w.add_child(_glb_mi("Coaster", pm, lx))
	w.add_child(_glb_mi("Pint", pm, lx + Vector3(0.0, 0.0022, 0.0)))
	w.add_child(_glb_mi("PintBeer", pm, lx + Vector3(0.0, 0.0022, 0.0)))
	#  테이블 — 빈 잔 둘 · 내려놓은 다트 둘(아무도 없지만 방금 누가 있었다). 테이블은 이 장면에서 벽 쪽으로 물렸고(_patch)
	#  잔 · 다트는 앉은 눈에서 보이는 먼 반쪽 · 촛불 웅덩이 안에 둔다.
	var tc: Vector2 = (B.table as Vector2) + Vector2(0.0, float(TABLE.dz))
	var ty: float = float(B.floor) + float(B.table_h)
	#  테이블 윗판 — Blender 테이블(bar_props Table) 윗면 법선이 밑을 봐서 촛불을 못 받고 검은 판이었다(문 장면은 바탕빛으로만
	#  봤다). 윗면 바로 위에 나무 원판 한 장(평평한 면 — 빛 단 없음)을 얹는다
	var tw := _inm(hn, B.wood)
	tw.set_shader_parameter("sat", 0.55)
	var top := Room3D._cyl(0.285, 0.285, 0.004, Vector3(tc.x, ty + 0.004, tc.y), tw, 32)
	top.layers = L_IN | L_TBL
	w.add_child(top)
	var tm := pm.duplicate()
	var tg := ShaderMaterial.new()
	tg.shader = (pm.glass as ShaderMaterial).shader
	var cz: float = tc.y + 0.10 + float(TABLE.candle_dz)
	tg.set_shader_parameter("lp0", Vector4(tc.x + 0.02, ty + 0.12, cz, 0.8))
	tg.set_shader_parameter("lc0", Color("ff9a50"))
	_glass_set(tg, GLASS_K.table)
	tm["glass"] = tg
	hn.set_meta("table_glass", tg)
	for g in [Vector2(-0.15, -0.06), Vector2(0.15, -0.12)]:
		w.add_child(_glb_mi("Pint", tm, Vector3(tc.x + g.x, ty, tc.y + g.y), L_IN | L_TBL))
	#  한 잔엔 김 빠진 맥주가 한 뼘 남았다(면을 반 높이로 · 벽 안으로 조금 줄인다)
	var lb := _glb_mi("PintBeer", pm, Vector3(tc.x - 0.15, ty, tc.y - 0.06), L_IN | L_TBL)
	lb.scale = Vector3(0.93, 0.5, 0.93)
	w.add_child(lb)
	var steel := _inm(hn, B.steel, 4.0)
	var fl := _inm(hn, Color("8c2a52"))
	(fl as ShaderMaterial).set_shader_parameter("sat", 0.7)
	#  카운터 오른끝 빈 잔 · 다트는 걷었다 — 눈에서 0.75m 라 다트 장면 한가운데 유령 철사 기둥으로 섰다(검토 1)
	var darts := [[Vector3(tc.x - 0.04, ty + 0.006, tc.y - 0.16), 70.0], [Vector3(tc.x + 0.06, ty + 0.006, tc.y - 0.20), 115.0]]
	for d in darts:
		var dn := Node3D.new()
		dn.position = d[0]
		dn.rotation_degrees = Vector3(0.0, float(d[1]), 90.0)
		w.add_child(dn)
		dn.add_child(Room3D._cyl(0.004, 0.004, 0.05, Vector3(0.0, 0.0, 0.0), steel, 6))
		dn.add_child(Room3D._cyl(0.0022, 0.0022, 0.045, Vector3(0.0, 0.047, 0.0), _inm(hn, Color("0d0b16")), 4))
		for fr in [0.0, 90.0]:
			var f := Room3D._box(Vector3(0.026, 0.03, 0.001), Vector3(0.0, 0.075, 0.0), fl)
			f.rotation_degrees.y = fr
			dn.add_child(f)
		for c in dn.get_children():
			(c as VisualInstance3D).layers = L_IN | L_TBL
	#  천장 — 양철 판(TV 둘레 · 펜던트 너머) · 잔 걸이(눈과 TV 사이 — 거꾸로 걸린 잔이 TV 빛에 테만 선다)
	var cy: float = float(B.ceil) - 0.001
	for i in 5:
		for j in 4:
			w.add_child(_glb_mi("TinTile", pm, Vector3(float(TV.at.x) + (float(i) - 2.0) * 0.61, cy,
					float(TV.at.z) + (float(j) - 1.0) * 0.61)))
	#  걸이 잔 — 펜던트 반짝은 빼고 TV 찬 빛만 테에 얹는다(어둠 속 실루엣 · 흰 점이 안 튀게)
	var rm := pm.duplicate()
	var rg := ShaderMaterial.new()
	rg.shader = (pm.glass as ShaderMaterial).shader
	rg.set_shader_parameter("hi", 0.4)
	rg.set_shader_parameter("tint", Color(0.5, 0.55, 0.6))
	rm["glass"] = rg
	hn.set_meta("rack_glass", rg)
	w.add_child(_glb_mi("GlassRack", rm, RACK))


# ══ 상인 ══════════════════════════════════════════════════
#  허리 ~ 깃 몸통(Blender · 머리 없음 · 깃 안은 먹 목) · 위팔 둘(어깨 축) · 상점 손 · 팔뚝(game.gd) · 닦는 빈 잔 · 바 천.
#  얼굴은 늘 그림 밖이거나 가장 어두운 단이다(가운데 펜던트는 손을 겨눈 좁은 원뿔 · TV 빛은 이 층을 안 비춘다).
#  상점 손 재질(shaders/hand3) 이 장면 사본 — 제 그림자를 안 받는다(펜던트 단단한 그림자가 손가락 · 팔뚝에 제 그늘
#  얼룩을 바둑판으로 앉혔다 · 검토 1) · 빛의 감쇠는 매끈하게(면 각도 단만 남는다) · fillc 방 바탕빛(찬 한 단 —
#  웅덩이 밖 소매 · 손이 방과 같은 바탕에 선다). lv 빛 단 세기 [l1 l2 l3].
static var _hand_sh: Shader = null


static func _toon(src: ShaderMaterial, fill := Color.BLACK, lv: Array = []) -> ShaderMaterial:
	if _hand_sh == null:
		var code: String = (src.shader as Shader).code
		if not (code.contains("render_mode cull_back;") and code.contains("EMISSION = ALBEDO * glow;")):
			push_warning("prologue_bar3d — hand3.gdshader 가 바뀌어 손 재질 고침이 안 먹는다")
		_hand_sh = Shader.new()
		_hand_sh.code = code.replace("render_mode cull_back;", "render_mode cull_back, shadows_disabled;") \
				.replace("EMISSION = ALBEDO * glow;", "EMISSION = ALBEDO * (glow + fillc);") \
				.replace("varying float v_ny;", "uniform vec3 fillc = vec3(0.0);\nvarying float v_ny;")
	var m := src.duplicate() as ShaderMaterial
	m.shader = _hand_sh
	m.set_shader_parameter("att_steps", 24.0)
	m.set_shader_parameter("fillc", Vector3(fill.r, fill.g, fill.b))
	if lv.size() == 3:
		for i in 3:
			m.set_shader_parameter("l%d" % (i + 1), float(lv[i]))
	return m


static func _merchant(hn: Node, w: Node3D, g: Node) -> void:
	if g == null or not g.has_method("_hand3_build") or _glb_mesh("BarTorso") == null:
		return
	var m := Node3D.new()
	m.name = "Merchant"
	m.position = MERCH.at
	m.rotation_degrees = Vector3(0.0, float(MERCH.yaw), 0.0)
	w.add_child(m)
	var V: Dictionary = g.VEST3
	var lay := L_MERCH | L_HERO
	#  셔츠(위팔 · 팔뚝 소매가 같은 재질 — 이음매 색이 갈리지 않게)는 빛 단을 둘로 묶는다(걷은 단이 점선 고리였다)
	var shirt := _toon(g._hand3_toon(g.FORE3.cloth), MFILL, [0.36, 0.36, 0.46])
	var tm := {
		"shirt": shirt, "shirt_btn": _toon(g._hand3_toon(Color("d8d2c4"))),
		"vest": _toon(g._hand3_toon(V.vest)), "lapel": _toon(g._hand3_toon(V.lap, Color(0, 0, 0, 0), 0.5)),
		"vest_back": _toon(g._hand3_toon(Color8(30, 22, 30))), "trousers": _toon(g._hand3_toon(Color8(24, 24, 30))),
		"belt": _toon(g._hand3_toon(Color8(48, 28, 18))),
		#  놋쇠 소매 띠 — 제 빛을 거의 걷는다(소매가 먹인데 띠만 허공에 뜬 올리브 막대였다 · 검토 1)
		"brass": _toon(g._hand3_toon(g.FORE3.brass, Color(0, 0, 0, 0), 0.4, 0.015, 1.0, 0.5)),
		"chain": _toon(g._hand3_toon(V.chain, Color(0, 0, 0, 0), 0.6, 0.03, 1.0, 0.5)),
		"void": Room3D._glow(Color.BLACK, 0.0),
		"cloth": _toon(g._hand3_toon(Color("cfc6ae"))), "cloth_stripe": _toon(g._hand3_toon(Color("6a3a22"))),
		"glass": _glass_mat(hn),
	}
	_glass_set(tm.glass, GLASS_K.polish)
	m.add_child(_glb_mi("BarTorso", tm, Vector3.ZERO, lay))
	var ua := {}
	for sd in ["R", "L"]:
		var u := _glb_mi("UpperArm" + sd, tm, Vector3.ZERO, lay)
		m.add_child(u)
		ua[sd] = u
	var arm := Node3D.new()
	arm.name = "Arm"
	arm.scale = Vector3.ONE * float(ARM.s)
	m.add_child(arm)
	var m0: Dictionary = g._hand3_mats()
	var mats := {"skin": _toon(m0.skin, SKIN_FILL), "nail": _toon(m0.nail), "ring": _toon(m0.ring)}
	#  살 — 위 두 문턱을 올려 손등 · 손가락 둥근 면에 단이 선다(펜던트가 거의 바로 위라 손등이 통째로 맨 위 단 —
	#  크림 벙어리장갑이었다 · 검토 1)
	(mats.skin as ShaderMaterial).set_shader_parameter("t2", 0.62)
	(mats.skin as ShaderMaterial).set_shader_parameter("t3", 0.9)
	var fm := {"skin": mats.skin, "cloth": tm.shirt, "brass": tm.brass}
	var hj := {"R": g._hand3_build(mats, false, false), "L": g._hand3_build(mats, true, true)}
	var fo := {"R": g._fore3_build(fm, float(g.FORE3.bare), 1.0), "L": g._fore3_build(fm, float(g.FORE3.bare_r), -1.0)}
	for sd in ["R", "L"]:
		arm.add_child(hj[sd].root)
		(fo[sd].sty as Node3D).visible = false
		arm.add_child(fo[sd].root)
	var gl := Node3D.new()
	gl.name = "Glass"
	m.add_child(gl)
	gl.add_child(_glb_mi("PolishGlass", tm, Vector3.ZERO, lay))
	#  감싼 천 — 잔 밑 30% · 말린 테로 닫힌 감쌈 + 잔 허리 뭉치(빈 잔 속이 천으로 찬다) · 테를 넘는 띠는 엄지가 집는 자리로
	#  돈다(_merch_tick). 잘라 낸 열린 껍데기는 검은 삼각 구멍 · 종이 상자로 읽혔다(검토 2).
	gl.add_child(_glb_mi("TowelWrap", tm, Vector3.ZERO, lay))
	var band := _glb_mi("TowelBand", tm, Vector3.ZERO, lay)
	gl.add_child(band)
	#  꼬리는 하나 — 받치는 손 새끼 쪽에서 늘 늘어진다(셋을 갈아 끼우는 흔들림은 1배에서 안 보였다)
	var tail := _glb_mi("TowelTail_A", tm, Vector3.ZERO, lay)
	m.add_child(tail)
	for c in m.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).layers = lay
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	hn.set_meta("merch", {"n": m, "ua": ua, "hj": hj, "fo": fo, "glass": gl, "band": band, "tail": tail, "g": g})


#  두 마디 IK — 어깨 s 에서 손목 w 로(위팔 l1 · 팔뚝 l2) · 팔꿈치는 pole 쪽으로 굽는다
static func _ik(s: Vector3, w: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var d: float = clampf(s.distance_to(w), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var dir: Vector3 = (w - s).normalized()
	var a: float = (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h: float = sqrt(maxf(l1 * l1 - a * a, 0.0))
	var pp: Vector3 = (pole - s) - dir * dir.dot(pole - s)
	return s + dir * a + pp.normalized() * h


#  손 좌표(손 단위)로 본 마디 자리 — 손 뿌리까지 변환을 곱해 올라간다
static func _hloc(hj: Dictionary, n: Node3D) -> Vector3:
	var x := Transform3D()
	var c: Node = n
	while c != null and c != hj.root:
		x = (c as Node3D).transform * x
		c = c.get_parent()
	return x.origin


#  손목 한계 — 손끝 축(x)을 팔뚝 축 f 에서 굽힘 · 젖힘 · 옆 꺾임 안으로 자른다(굴림 — 엎침 · 뒤침은 팔뚝이 같이 돈다).
#  손 방향을 잔에서만 정하니 팔뚝과 거의 90° 로 꺾여 팔 옆에 붙은 주걱이 됐다(「손목이 이상하지 않아?」).
static func _wrist_clamp(hb: Basis, f: Vector3) -> Basis:
	var fz: Vector3 = hb.z - f * f.dot(hb.z)
	if fz.length_squared() < 0.000001:
		return hb
	fz = fz.normalized()
	var fy: Vector3 = fz.cross(f)
	var x0: Vector3 = hb.x
	var ph: float = clampf(atan2(x0.dot(fy), x0.dot(f)), -deg_to_rad(float(WRIST.flex)), deg_to_rad(float(WRIST.ext)))
	var ps: float = clampf(atan2(x0.dot(fz), x0.dot(f)), -deg_to_rad(float(WRIST.dev)), deg_to_rad(float(WRIST.dev)))
	var x: Vector3 = (f + fy * tan(ph) + fz * tan(ps)).normalized()
	var y: Vector3 = (hb.y - x * x.dot(hb.y)).normalized()
	return Basis(x, y, x.cross(y))


#  k 축 둘레로 굴려 손끝 축(x)을 f 에 가장 가깝게(닿는 선 k 는 그대로)
static func _roll_to(hb: Basis, k: Vector3, f: Vector3) -> Basis:
	var p: Vector3 = hb.x - k * k.dot(hb.x)
	var q: Vector3 = f - k * k.dot(f)
	if p.length_squared() < 0.000001 or q.length_squared() < 0.000001:
		return hb
	return Basis(k, p.signed_angle_to(q, k)) * hb


#  손 · 팔 하나를 세운다 — 손의 닿는 자리 pl(손 좌표 m)을 P(상인 좌표 m)에, 손 축 kl 을 k 에 맞추고, 그 둘레 굴림은
#  손끝이 팔뚝을 잇도록(팔뚝 방향은 IK 가 정하므로 몇 번 오간다) · 손목은 한계 안. [손목, 손 basis, 팔꿈치]를 돌려준다.
static func _arm_set(g: Node, sd: String, M: Dictionary, P: Vector3, k: Vector3, kl: Vector3, pl: Vector3) -> Array:
	var s: float = ARM.s
	var hj: Dictionary = M.hj[sd]
	var fo: Dictionary = M.fo[sd]
	var out: float = -1.0 if sd == "R" else 1.0
	var sh: Vector3 = (_xf.get("Shoulder" + sd, Transform3D()) as Transform3D).origin
	var pv: Vector3 = ARM.get("pole_" + sd, ARM.pole)
	var pole: Vector3 = sh + Vector3(out * pv.x, pv.y, pv.z)
	var h0 := Basis(Quaternion(kl.normalized(), k.normalized()))
	var f: Vector3 = (P - sh).normalized()
	var hb := h0
	var wr := P
	var el := sh
	for i in 5:
		hb = _wrist_clamp(_roll_to(h0, k, f), f)
		wr = P - hb * pl
		el = _ik(sh, wr, float(ARM.ua), float(ARM.fa), pole)
		f = (wr - el).normalized()
	(hj.root as Node3D).transform = Transform3D(hb, wr / s)
	var y: Vector3 = (sh - el).normalized()
	var z: Vector3 = (Vector3.BACK - y * y.dot(Vector3.BACK)).normalized()
	(M.ua[sd] as Node3D).transform = Transform3D(Basis(y.cross(z), y, z), sh)
	#  팔뚝 끝은 손목 축 위 · 손뿌리 속으로 조금 묻는다(손목 이음매 틈 · 쐐기 금지)
	var ws: Vector3 = wr / s + hb.y * 0.5 + hb.x * 1.5
	var es: Vector3 = el / s
	var ax: Vector3 = es - (ws - es).normalized() * float(g.HAND3.back)
	(fo.root as Node3D).transform = g._aim3(ax, ws, 1.0, 0.0, hb.y)
	g._fore3_fit(fo, (ws - ax).length(), float(ARM.fs))
	return [wr, hb, el]


#  손가락 — game.gd FPOSE 차례(prologue3d _tape_pose 와 같은 길)
static func _fingers(g: Node, hj: Dictionary, p: Array) -> void:
	var sg: float = hj.sg
	var fan: Array = g.FING3.fan
	for f in 4:
		(hj.j1[f] as Node3D).basis = Basis(Vector3.UP, deg_to_rad(float(p[8]) * float(fan[f])) * sg) \
				* Basis(Vector3.BACK, -deg_to_rad(float(p[f])))
		(hj.j2[f] as Node3D).basis = Basis(Vector3.BACK, -deg_to_rad(float(p[4 + f])))
	g._thumb3_pose(sg, PackedFloat32Array(p), 0)
	g._thumb3_set(hj, g.thumb_mr, Transform3D(g.thumb_pr, Vector3(float(g.THUMB3.lm), 0.0, 0.0)),
			Basis(Vector3.BACK, -deg_to_rad(float(g.thumb_cr))), sg, clampf(float(p[9]), 0.0, 1.0))


#  비틀기(도) — 일하는 손이 잔 축 둘레로 테를 훑는다(사인 · 1.5 초 · t 0 이 정방향 가장 빠른 때 = bar_polish 박자). 고쳐
#  쥘 때 · 내려놓은 뒤에는 멎는다.
static func _twist(t: float) -> float:
	var P: Dictionary = POLISH
	var rg: Array = P.regrip
	var dn: Array = P.down
	var env: float = 1.0 - smoothstep(float(rg[0]) - 0.1, float(rg[0]) + 0.05, t) * (1.0 - smoothstep(float(rg[1]) - 0.05,
			float(rg[1]) + 0.1, t))
	env *= 1.0 - smoothstep(float(dn[0]) - 0.15, float(dn[0]), t)
	return float(P.a) * sin(TAU * t / float(P.per)) * env


static func _merch_tick(hn: Node, t: float) -> void:
	if not hn.has_meta("merch"):
		return
	var M: Dictionary = hn.get_meta("merch")
	#  잔을 내려놓고 안쪽으로 든다 — 눈이 다트 장을 보는 동안(그림 밖) 빠진다 · 올려다볼 때 깃이 그림 귀에 안 걸린다
	(M.n as Node3D).visible = t < float(POLISH.gone)
	if t >= float(POLISH.gone):
		return
	var g: Node = M.g
	var P: Dictionary = POLISH
	var th: float = _twist(t)
	var rg: Array = P.regrip
	var dn: Array = P.down
	var sp: float = -float(P.back) * th + float(rg[2]) * smoothstep(float(rg[0]), float(rg[1]), t)
	#  내려놓기 — 잔이 곧게 서며 카운터(상인 좌표 y 1.08)로 내려와 닿는다(잔 놓는 소리)
	var dk: float = smoothstep(float(dn[0]), float(dn[1]), t)
	var gp: Vector3 = (MERCH.glass as Vector3).lerp(MERCH.down, dk)
	var gb := Basis(Vector3.BACK, deg_to_rad(float(MERCH.tilt) * (1.0 - dk))) \
			* Basis(Vector3.RIGHT, deg_to_rad(float(MERCH.lean) * (1.0 - dk))) * Basis(Vector3.UP, deg_to_rad(sp))
	(M.glass as Node3D).transform = Transform3D(gb, gp)
	var a: Vector3 = gb.y
	var s: float = ARM.s
	#  받치는 손(왼손 · 반지) — 오므린 손바닥이 위로 밑동을 받친다(손바닥 법선 = 잔 축) · 손끝은 팔뚝을 잇는다.
	#  내려놓기 전에 밑동에서 잔 옆(받치는 손 쪽 · 몸 아래)으로 미끄러져 옆에서 쥔 채 내려놓는다 — 밑을 받친 채 내려 손이
	#  카운터를 뚫었다(2026-10-28 「컵을 잡고 있는손 테이블 뚫는거 알지?」)
	_fingers(g, M.hj.L, HPOSE.cup)
	var sk: float = smoothstep(float(dn[0]) - 0.3, float(dn[0]) + 0.1, t)
	var sd: Vector3 = (Vector3.RIGHT - a * a.dot(Vector3.RIGHT)).normalized()
	var lp: Vector3 = (gp - a * 0.003).lerp(gp + a * float(SIDE.h) + sd * float(SIDE.r), sk)
	var lr: Array = _arm_set(g, "L", M, lp, a.slerp(-sd, sk), Vector3.DOWN, (HAND_AT.palm as Vector3) * s)
	#  일하는 손(오른손) — 엄지는 천째 입 안 · 검지는 바깥 벽으로 테 한 점을 집는다(집는 선이 테의 지름 방향) · 손은 그 선
	#  둘레로 굴러 팔뚝을 잇는다 · 비틀면 집는 자리가 잔 축 둘레로 테를 훑는다
	_fingers(g, M.hj.R, HPOSE.pinch)
	var hr: Dictionary = M.hj.R
	var it: Vector3 = _hloc(hr, hr.tips[0])
	var tt: Vector3 = _hloc(hr, hr.ttip)
	var u0: Vector3 = (Vector3.LEFT - a * a.dot(Vector3.LEFT)).normalized()
	var u: Vector3 = Basis(a, deg_to_rad(float(WORK.phi) + th)) * u0
	var rim: Vector3 = gp + a * float(WORK.h) + u * float(WORK.r)
	_arm_set(g, "R", M, rim, u, it - tt, (it + tt) * 0.5 * s)
	#  테를 넘는 천 띠 — 엄지가 집는 자리(잔 좌표에서 u 쪽)로 돈다
	var ul: Vector3 = gb.transposed() * u
	(M.band as Node3D).rotation = Vector3(0.0, atan2(-ul.z, ul.x), 0.0)
	#  천 꼬리 — 받치는 손 새끼 쪽 모서리에서 늘 곧게 늘어진다
	var wl: Vector3 = lr[0]
	var hl: Basis = lr[1]
	var tn := M.tail as Node3D
	tn.visible = dk < 0.5
	tn.position = wl + hl.x * 0.07 - hl.z * 0.03 - Vector3(0.0, 0.015, 0.0)
	#  손이 잔 옆으로 내려가면 꼬리는 손 안으로 걷힌다(원점이 윗끝 — 늘어진 채면 카운터 앞끝을 뚫었다)
	tn.scale = Vector3(1.0, 1.0 - 0.8 * sk, 1.0)


# ══ TV ═══════════════════════════════════════════════════
#  천장 걸이(관 · 멍에 · 축 손잡이 · 줄) · 14″ 브라운관(두 단 테 · 볼록 유리 · 받침 띠 · 쟁반 — 숙여 단다). 유리는 테이프
#  프롤로그의 화면(Plg SCR_SHADER mode 9 — 게임 화판 그림) + 브라운관 결(crt · snowk · refl). 찬 빛 한 줄기가 카운터
#  끝 · 손님 잔으로(상인 층은 안 비춘다 · 원뿔이 머리에 안 닿는다) · 작은 빛 하나가 제 테 · 걸이 · 천장을 짚는다.
static func _tv(hn: Node, w: Node3D, feed: Texture2D, sz: Vector2) -> void:
	var pm: Dictionary = hn.get_meta("pm")
	var tm := {
		"crt_body": _inm(hn, Color("2a292d"), 4.0), "crt_bezel": _inm(hn, Color("121114"), 4.0),
		"crt_btn": _inm(hn, Color("3a3a40"), 4.0), "crt_grille": _inm(hn, Color("0c0c0f")),
		"crt_led": Room3D._glow(TVL.led[0], 1.0), "iron": pm.iron, "knob": _inm(hn, Color("26232a"), 4.0),
		"cable": _inm(hn, Color("0c0a0e"), 4.0), "rubber": pm.rubber,
	}
	hn.set_meta("led", tm.crt_led)
	var mnt := _glb_mi("TvMount", tm, TV.at)
	mnt.rotation_degrees = Vector3(0.0, float(TV.yaw), 0.0)
	w.add_child(mnt)
	var crt := _glb_mi("BarCrt", tm, Vector3(0.0, float(TV.pivot), 0.0))
	crt.rotation_degrees = Vector3(float(TV.tilt), 0.0, 0.0)
	mnt.add_child(crt)
	var me := crt.mesh
	if me == null:
		return
	var gb := AABB()
	var scr: ShaderMaterial = null
	for k in me.get_surface_count():
		var sm: Material = me.surface_get_material(k)
		if sm != null and sm.resource_name == "crt_glass":
			gb = Plg._surf_aabb(me, k)
			scr = Plg._scr_mat("game", gb, 0, null, true, feed, sz)
			scr.set_shader_parameter("res", SNOW_RES)
			scr.set_shader_parameter("crt", 1.0)
			scr.set_shader_parameter("snowk", 1.0)
			scr.set_shader_parameter("pw", 1.0)
			scr.set_shader_parameter("amb", 0.0)
			scr.set_shader_parameter("star", DIVE.star)
			scr.set_shader_parameter("land", DIVE.land)
			scr.set_shader_parameter("gcol", DIVE.gcol)
			crt.set_surface_override_material(k, scr)
			hn.set_meta("rim", {"n": crt, "p": Plg.glass_rim(me, k)})
	hn.set_meta("scr", scr)
	#  TV 몸은 방 채움을 안 따른다 — 제 화면 빛이 앞 테에 떨어지는 무광 한 단(TVL.body · 펜던트가 다 꺼져도 TV 가 선다)
	hn.set_meta("tvm", [tm.crt_body, tm.crt_bezel, tm.crt_btn, tm.crt_grille, tm.knob, tm.cable])
	#  유리 앞 한가운데 · 법선(세계) — 다이브 끝 거리(유리 폭이 화면 폭을 꼭 채우는 거리의 Plg HERO.dive 몫 — 끝에 유리 폭이
	#  화면의 143%). 눈은 보던 선(눈 → 한가운데) 그대로 들어간다 — 법선으로 돌아 들면 뛰어듦 끝에 그림이 기울며 돌았다
	var G := _tv_glass()
	var n: Vector3 = G.n
	var apex: Vector3 = G.c
	var fov: float = float(POSE.push[3])
	var ar: float = sz.x / maxf(sz.y, 1.0)
	var de: float = gb.size.x * 0.5 / (tan(deg_to_rad(fov) * 0.5) * ar) * float(Plg.HERO.dive)
	hn.set_meta("end", {"look": apex, "d": de})
	var tl := SpotLight3D.new()
	tl.name = "TvLight"
	tl.light_color = TVL.c
	tl.spot_angle = float(TVL.ang)
	tl.spot_range = 2.4
	tl.spot_attenuation = 1.0
	tl.spot_angle_attenuation = 1.0
	tl.light_cull_mask = L_IN
	tl.light_volumetric_fog_energy = float(TVL.fog)
	tl.shadow_enabled = true
	tl.shadow_blur = 0.0
	tl.light_size = 0.0
	tl.shadow_opacity = 0.8
	tl.shadow_caster_mask = L_HERO
	w.add_child(tl)
	var at: Vector3 = apex + n * 0.03
	tl.look_at_from_position(at, TV.aim)
	var rl := OmniLight3D.new()
	rl.name = "TvRim"
	rl.light_color = TVL.c
	rl.omni_range = 0.6
	rl.omni_attenuation = 1.4
	rl.light_cull_mask = L_IN
	rl.light_volumetric_fog_energy = 0.0
	rl.light_specular = 0.0
	rl.position = apex + n * 0.12 + Vector3(0.0, 0.12, 0.0)
	w.add_child(rl)
	hn.set_meta("tvl", [tl, rl])
	#  찬 빛 단 — 0.5~2 초씩 버티고 그 자리에서 바뀐다(이어 붙이지 않는다 · 씨 고정)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20251025
	var st := []
	var tt := 0.0
	var lv: Array = TVL.lv
	var last := -1
	while tt < LEN + 1.0:
		var i := rng.randi_range(0, lv.size() - 1)
		if i == last:
			i = (i + 2) % lv.size()
		last = i
		st.append([tt, float(lv[i])])
		var h: Array = TVL.hold
		tt += rng.randf_range(float(h[0]), float(h[1])) if rng.randf() > 0.2 else rng.randf_range(0.18, 0.35)
	hn.set_meta("tv_steps", st)


#  TV 유리 — 세계 자리(걸이 · 기울기는 상수 — _tv 가 같은 변환으로 단다) · c 앞 한가운데 · n 법선 · gb 유리 AABB(TV 좌표).
#  카메라 · 다이브가 이 점을 본다(짓기 전에도 셈한다 — 검사 도구).
static var _tvg := {}


static func _tv_glass() -> Dictionary:
	if not _tvg.is_empty():
		return _tvg
	var me := _glb_mesh("BarCrt")
	var gb := AABB(Vector3(-0.144, 0.08, 0.10), Vector3(0.288, 0.216, 0.03))
	if me != null:
		for k in me.get_surface_count():
			var sm := me.surface_get_material(k)
			if sm != null and sm.resource_name == "crt_glass":
				gb = Plg._surf_aabb(me, k)
	var gx := Transform3D(Basis(Vector3.UP, deg_to_rad(float(TV.yaw))), TV.at) \
			* Transform3D(Basis(Vector3.RIGHT, deg_to_rad(float(TV.tilt))), Vector3(0.0, float(TV.pivot), 0.0))
	var n: Vector3 = (gx.basis * Vector3.BACK).normalized()
	_tvg = {"c": gx * gb.get_center() + n * gb.size.z * 0.5, "n": n, "gb": gb, "xf": gx}
	return _tvg


static func _tv_level(hn: Node, t: float) -> float:
	var v := 1.0
	for s in hn.get_meta("tv_steps"):
		if t >= float(s[0]):
			v = float(s[1])
	return v


# ══ 빛 ═══════════════════════════════════════════════════
#  세트의 빛을 찾아 이 장면 차림으로 — 채움 끄기 · 펜던트는 좁혀 겨눈다(가운데는 상인의 손 · 오른쪽은 손님 잔 —
#  단단한 그림자 · 주인공 것만 드리운다) · 선반 밑불은 병 뒤 밑으로(어깨만 빛나고 몸은 어둡다) · 안개는 TV 만.
static func _lights_make(hn: Node, w: Node3D, bar: Node3D) -> void:
	var L := {"pend": [], "shelf": []}
	var hands: Vector3 = (MERCH.at as Vector3) + Basis(Vector3.UP, deg_to_rad(float(MERCH.yaw))) \
			* ((MERCH.glass as Vector3) + (MERCH.aim as Vector3))
	for n in bar.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		#  빛 이름도 겹쳐 붙으며 바뀐다 — 꼴 · 닿는 거리 · 빛깔로 가린다(Door3D _bar_lamps · _bar_back · _bar_darts · _bar_table ·
		#  _bar_deco · _inside)
		l.light_volumetric_fog_energy = 0.0
		l.light_specular = 0.0
		if l is SpotLight3D:
			if is_equal_approx((l as SpotLight3D).spot_range, 2.6):
				(L.pend as Array).append(l)
			else:
				#  그림등 — 판 · 장 문짝까지(판만 비추니 검은 허공에 뜬 원판이었다 · 검토 2) · 칠판 분필 점수는 어둡게 둔다(글로 읽히지 않게)
				(l as SpotLight3D).spot_angle = 25.0
				L["pict"] = l
			continue
		var o := l as OmniLight3D
		if is_equal_approx(o.omni_range, 0.85):
			(L.shelf as Array).append(l)
			o.position = Vector3(o.position.x, o.position.y - 0.11, float(Door3D.BAR.back) + 0.10)
			o.omni_range = 0.6
			o.light_cull_mask = L_SHB
		elif is_equal_approx(o.omni_range, 5.2):
			o.light_energy = 0.0
			o.visible = false
		elif o.light_color.is_equal_approx(Color("ff9a50")):
			L["candle"] = l
			l.light_color = TABLE.candle_c
			(l as OmniLight3D).omni_range = 0.65         # 테이블 윗판만 — 벽으로 물린 테이블이라 벽 · 액자까지 주황으로 비췄다
			l.light_cull_mask = L_TBL
		elif o.light_color.is_equal_approx(Color("f2a13a")):
			L["neon"] = l
	(L.pend as Array).sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.position.x < b.position.x)
	var pd: Array = L.pend
	if pd.size() == 3:
		var aims := [Vector3(float(pd[0].position.x), float(Door3D.BAR.cnt_y), float(Door3D.BAR.pend_z) - 0.08),
				hands, PINT + Vector3(0.0, 0.0, 0.01)]
		var ang: Array = PEND.ang
		for i in 3:
			var s := pd[i] as SpotLight3D
			s.spot_angle = float(ang[i])
			s.spot_angle_attenuation = 1.0
			s.spot_range = 2.2
			s.light_cull_mask = L_IN | L_MERCH
			s.look_at_from_position(s.position, aims[i])
			if i > 0:
				s.shadow_enabled = true
				s.shadow_blur = 0.0
				s.light_size = 0.0
				s.shadow_opacity = 0.82
				s.shadow_bias = 0.03
				s.shadow_normal_bias = 1.0
				s.shadow_caster_mask = L_HERO
			if i == 1:
				s.light_volumetric_fog_energy = 0.12
	hn.set_meta("L", L)
	hn.set_meta("lt_last", {})


#  빛 표를 그 때까지 쌓은 몫
static func _light_at(t: float) -> Dictionary:
	var d := {}
	for row in LIGHT:
		if t >= float(row[0]):
			for k in row[1]:
				d[k] = row[1][k]
	return d


static func _lights(hn: Node, t: float) -> void:
	var L: Dictionary = hn.get_meta("L")
	var d := _light_at(t)
	var pd: Array = L.pend
	var pk := ["pl", "pm", "pr"]
	for i in mini(pd.size(), 3):
		(pd[i] as Light3D).light_energy = float(LBASE[pk[i]]) * float(d[pk[i]])
	for l in L.shelf:
		(l as Light3D).light_energy = float(LBASE.shelf) * float(d.shelf)
	for k in ["pict", "candle", "neon"]:
		if L.has(k):
			(L[k] as Light3D).light_energy = float(LBASE[k]) * float(d[k])
	#  제 빛 재질 — 그 빛과 같이(무리마다 밑 몫 × 지금 몫)
	var gl: Dictionary = hn.get_meta("glows")
	#  올려다본 뒤 — 갓 속(젖빛 판 · 안쪽)은 가장 어두운 단 · 갓은 그림 귀에 어두운 테로만 든다
	var up: float = 0.0 if t >= float(PEND.up) else 1.0
	#  선반 앞 띠 등(제 빛)도 올려다본 뒤엔 꺼 둔다 — TV 를 한가운데 두면 그림 밑끝에 크림 가로줄로 걸렸다
	var gk := {"shelf": 0.15 * float(d.shelf) * up, "cab": 0.3 * float(d.pict), "neon": 0.5 * float(d.neon),
			"candle": float(d.candle) / 0.7 * 0.8, "shade": 0.12 * maxf(float(d.pm), float(d.pr)) * up}
	for grp in gl:
		for e in gl[grp]:
			(e.m as StandardMaterial3D).albedo_color = (e.c as Color) * clampf(float(gk[grp]), 0.0, 1.0)
	for df in hn.get_meta("diff", []):
		var x: float = df.x
		var k: float = float(d.pl) if x < -1.0 else (float(d.pm) if x < 0.0 else float(d.pr))
		(df.m as StandardMaterial3D).albedo_color = Color("b89a6a") * (0.05 + 0.5 * k * up) * (0.6 if x < -1.0 else 1.0)
	#  채움 — 바뀐 때만 재질을 다 고친다
	var fk: float = float(d.fill)
	if not is_equal_approx(float((hn.get_meta("lt_last") as Dictionary).get("fill", -1.0)), fk):
		(hn.get_meta("lt_last") as Dictionary)["fill"] = fk
		for m in hn.get_meta("ins"):
			(m as ShaderMaterial).set_shader_parameter("fill", FILL * fk)
		for m in hn.get_meta("tvm", []):
			(m as ShaderMaterial).set_shader_parameter("fill", TVL.body)
	#  TV — 찬 빛 단 · 그림이 비친 뒤 덜 차다 · 유리 반짝 줄 · 맥주 뒤 빛
	var tvk: float = _tv_level(hn, t)
	var tc: Color = TVL.c if t < float(T.feed) else TVL.c2
	var tl: Array = hn.get_meta("tvl", [])
	if tl.size() == 2:
		(tl[0] as SpotLight3D).light_energy = float(TVL.e) * tvk
		(tl[0] as SpotLight3D).light_color = tc
		(tl[1] as OmniLight3D).light_energy = float(TVL.rim) * tvk * float(d.tvb)
		(tl[1] as OmniLight3D).light_color = tc
	if hn.has_meta("led"):
		var lm := hn.get_meta("led") as StandardMaterial3D
		lm.albedo_color = TVL.led[0] if float(d.tvb) > 0.0 else TVL.led[1]
		lm.emission = lm.albedo_color
	var ps: Array = []
	for i in mini(pd.size(), 3):
		ps.append((pd[i] as Node3D).global_position)
	if ps.size() == 3:
		for gm in hn.get_meta("glass", []):
			var m := gm as ShaderMaterial
			m.set_shader_parameter("lp0", Vector4(ps[1].x, ps[1].y, ps[1].z, 0.9 * float(d.pm)))
			m.set_shader_parameter("lp1", Vector4(ps[2].x, ps[2].y, ps[2].z, 0.9 * float(d.pr)))
			if tl.size() == 2:
				var tp: Vector3 = (tl[0] as Node3D).global_position
				m.set_shader_parameter("lp2", Vector4(tp.x, tp.y, tp.z, 0.7 * tvk))
				m.set_shader_parameter("lc2", tc)
	if hn.has_meta("rack_glass") and tl.size() == 2:
		var rp: Vector3 = (tl[1] as Node3D).global_position
		var rg := hn.get_meta("rack_glass") as ShaderMaterial
		rg.set_shader_parameter("lp2", Vector4(rp.x, rp.y, rp.z, tvk))
		rg.set_shader_parameter("lc2", tc)
	if hn.has_meta("beer"):
		var bk: float = 1.0 if t < float(MOVE[0][0]) else 0.35
		(hn.get_meta("beer") as ShaderMaterial).set_shader_parameter("glow", (0.03 + 0.16 * tvk) * bk)
	#  TV 유리 위 펜던트 비침은 걷었다(refl 0) — 홀로 뜬 주황 짧은 줄이 화면 흠집으로 읽혔다(검토 2)
	#  깨는 노출 — 둘째 깜박임까지 한 단 밝다가 그 자리에서 내린다(빛이 먼저 · 모양이 뒤)
	(hn.get_meta("env") as Environment).tonemap_exposure = 1.35 if t < float(WAKE.blink) + 0.02 else 1.0


# ══ 효과 ═════════════════════════════════════════════════
static func _post_make(hn: Node, w: Node3D) -> void:
	var q := MeshInstance3D.new()
	q.name = "Post"
	var qm := QuadMesh.new()
	qm.size = Vector2(2.0, 2.0)
	q.mesh = qm
	var sh := Shader.new()
	sh.code = POST_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.render_priority = -100
	q.material_override = m
	q.extra_cull_margin = 16384.0
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(q)
	hn.set_meta("post", m)


static func _post_tick(hn: Node, t: float) -> void:
	#  반 뜬 눈 — 유리는 덩어리 판 뒤에 그려 1px 실루엣만 머리카락처럼 떴다. 화면 그림은 투명 차례 전에 한 번 떠지므로
	#  판 밑으로 넣으면 곧 안 보이는 것과 같다 — 초점이 서는 깜박임까지 유리를 감춘다(맥주 · 받침은 덩어리째 남는다)
	if hn.has_meta("pint"):
		(hn.get_meta("pint") as Node3D).visible = t >= float(WAKE.blink)
	var row: Array = FOCUS[0]
	for r in FOCUS:
		if t >= float(r[0]):
			row = r
	var ms: Array = [hn.get_meta("post")] + (hn.get_meta("glass", []) as Array)
	if hn.has_meta("rack_glass"):
		ms.append(hn.get_meta("rack_glass"))
	if hn.has_meta("table_glass"):
		ms.append(hn.get_meta("table_glass"))
	for m in ms:
		(m as ShaderMaterial).set_shader_parameter("f0", float(row[1]))
		(m as ShaderMaterial).set_shader_parameter("f1", float(row[2]))
		(m as ShaderMaterial).set_shader_parameter("bmin", float(row[3]))
		(m as ShaderMaterial).set_shader_parameter("bmax", float(row[4]))
		(m as ShaderMaterial).set_shader_parameter("nsh", float(row[5]) if row.size() > 5 else 0.0)


#  눈꺼풀 — 무대 화판 위 2D 두 장(논리 px 에 그려 테가 도트 계단이다). 틈은 렌즈 꼴 — 가운데가 넓고 귀가 좁다.
#  감긴 선은 높이 85% · 위 눈꺼풀이 그만큼 · 밑 눈꺼풀은 15% 만 움직인다.
static func _lids_make(hn: Node, vp: SubViewport) -> void:
	var up := Polygon2D.new()
	var lo := Polygon2D.new()
	vp.add_child(up)
	vp.add_child(lo)
	hn.set_meta("lids", [up, lo])


static func _lid(t: float) -> float:
	for i in range(1, LID.size()):
		var b: Array = LID[i]
		if t <= float(b[0]):
			var a: Array = LID[i - 1]
			var u: float = (t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001)
			return lerpf(float(a[1]), float(b[1]), clampf(u, 0.0, 1.0))
	return float(LID[LID.size() - 1][1])


static func _lids_tick(hn: Node, t: float) -> void:
	var lids: Array = hn.get_meta("lids")
	var vs: Vector2 = Vector2((hn.get_meta("vp") as SubViewport).size)
	var o: float = _lid(t)
	var col: Color = SKIN[0] if t < float(WAKE.skin) else (SKIN[1] if t < float(LID[1][0]) else Color.BLACK)
	for l in lids:
		(l as Polygon2D).visible = o < 0.999
		(l as Polygon2D).color = col
	if o >= 0.999:
		return
	var W: float = vs.x
	var H: float = vs.y
	var pu := PackedVector2Array([Vector2(W + 2.0, -2.0), Vector2(-2.0, -2.0)])
	var pl := PackedVector2Array([Vector2(W + 2.0, H + 2.0), Vector2(-2.0, H + 2.0)])
	var n := 40
	for i in n + 1:
		var x: float = W * float(i) / float(n)
		var u: float = float(i) / float(n) * 2.0 - 1.0
		var lens: float = 1.0 - 0.38 * u * u
		pu.append(Vector2(x, 0.85 * H - o * 1.5 * H * lens + 0.5))
		pl.append(Vector2(x, 0.85 * H + o * 0.32 * H * lens - 0.5))
	(lids[0] as Polygon2D).polygon = pu
	(lids[1] as Polygon2D).polygon = pl


#  층 — 무대 · 번쩍(Plg.flash_make — 맨 위). 무대 그림에만 필름 말(Plg GRADE_SHADER · 낟알 0 — 그늘은 차게 ·
#  밝은 데는 따뜻하게). 자리는 tick 이 화판(outer.box)에 맞춘다.
static func _layer_make(hn: Node, vp: SubViewport, outer: Node) -> void:
	var ly := CanvasLayer.new()
	ly.name = "PrologueLayer"
	ly.layer = LAYER
	hn.add_child(ly)
	var root := Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ly.add_child(root)
	var under := ColorRect.new()
	under.color = Color.BLACK
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	under.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(under)
	var tr := TextureRect.new()
	tr.name = "Stage"
	tr.texture = vp.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(tr)
	var gs := Shader.new()
	gs.code = Plg.GRADE_SHADER
	var gm := ShaderMaterial.new()
	gm.shader = gs
	var gd: Array = Plg.LOOK.grade
	for pk in [["lift", gd[0]], ["cool", gd[1]], ["warm", gd[2]]]:
		var pc: Color = pk[1]
		gm.set_shader_parameter(String(pk[0]), Vector3(pc.r, pc.g, pc.b))
	gm.set_shader_parameter("grain", Vector2.ZERO)
	gm.set_shader_parameter("px", Vector2(vp.size))
	tr.material = gm
	hn.set_meta("grade", gm)
	Plg.flash_make(root, Vector2(vp.size))
	var g: Node = hn.get_meta("game")
	Plg.phos_make(root, g.get_viewport().get_texture() if g != null else null, Vector2(vp.size))
	hn.set_meta("outer", outer)
	hn.set_meta("root", root)


#  층 — 화판(outer.box) 자리에 맞추고 · handoff 에 끊는다(인광 Plg.phos · 옛 번쩍 Plg.cross — LEN 까지 비어 있다가 걷힌다).
static func _layer(hn: Node, t: float) -> void:
	var root := hn.get_meta("root") as Control
	var outer: Node = hn.get_meta("outer")
	var box: Control = outer.get("box") as Control if outer != null else null
	if box != null:
		root.position = box.position
		root.size = box.size
	if _phos():
		#  유리 한가운데의 게임 px — TV 그림 자르기 한가운데(cx) · 세로 한가운데 · 날아들 낟알은 다트판 한가운데(_title_c)
		var scr: ShaderMaterial = hn.get_meta("scr")
		var fs: Vector2 = scr.get_shader_parameter("feed") if scr != null else Vector2(640.0, 360.0)
		var cx: float = float(scr.get_shader_parameter("cx")) if scr != null else 0.5
		var g: Node = hn.get_meta("game")
		var ce := Vector2(cx * fs.x, fs.y * 0.5)
		Plg.phos(root, t - handoff(), ce, g._title_c() if g != null and g.has_method("_title_c") else ce)
	else:
		Plg.cross(root, t - handoff(), Plg.rim_poly(hn, t - handoff()))
	#  건넌 뒤 무대는 안 보인다 — 방 소리 꼬리(LEN)까지 그리지 않는다
	(hn.get_meta("vp") as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED \
			if t >= handoff() + 0.5 / 60.0 else SubViewport.UPDATE_ALWAYS


# ══ 카메라 ═══════════════════════════════════════════════
#  고개가 도는 몫 — 길이 d 동안 매끈하게(smoothstep) HEAD.over 만큼 넘쳐 가서 HEAD.settle 초에 매끈하게 돌아와 선다.
#  시작 · 넘침 · 끝 모두 속도 0 이다.
static func _turn(t: float, t0: float, d: float) -> float:
	if t <= t0:
		return 0.0
	var o: float = HEAD.over
	if t < t0 + d:
		return (1.0 + o) * smoothstep(0.0, 1.0, (t - t0) / d)
	return 1.0 + o * (1.0 - smoothstep(0.0, 1.0, (t - t0 - d) / float(HEAD.settle)))


#  자세 하나 — TV 를 보는 자세는 화면 한가운데(c)를 본다 · push 는 눈이 그 선 위로 다가간다
static func _pose(nm: String, c: Vector3) -> Array:
	var p: Array = POSE[nm]
	var look: Vector3 = c if p[1] == null else p[1]
	var eye: Vector3 = p[0]
	if p.size() > 4:
		eye += (c - eye).normalized() * float(p[4])
	return [eye, look, float(p[2]), float(p[3])]


#  때 t 의 [눈, 보는 데, 굴림, 화각] — c 는 TV 유리 한가운데(세계). 길이 겹치지 않으니 마지막으로 시작한 길이 정한다.
static func _pose_at(t: float, c: Vector3) -> Array:
	var cur: Array = _pose("cheek", c)
	for mv in MOVE:
		var t0: float = mv[0]
		var d: float = mv[1]
		if t < t0 - float(HEAD.lead):
			break
		var a: Array = _pose(String(mv[2]), c)
		var b: Array = _pose(String(mv[3]), c)
		var fe: float = _turn(t, t0, d)
		var fl: float = _turn(t + float(HEAD.lead), t0, d)
		var fr: float = fe
		var dip := 0.0
		var u: float = clampf((t - t0) / d, 0.0, 1.0)
		match String(mv[4]):
			"lift":
				#  굴림은 늦게 붙어 마지막에 선다(넘치지 않는다) · 드는 동안 눈길이 카운터 쪽으로 처진다(굴린 그림 위끝이
				#  상인 깃을 안 지나게 — sin² 이라 시작 · 끝 기울기 0)
				fr = smoothstep(0.0, 1.0, clampf((t - t0 - d * 0.1) / (d * 0.9), 0.0, 1.0))
				dip = 0.3 * pow(sin(PI * u), 2.0)
			"look":
				dip = 0.08 * pow(sin(PI * u), 2.0)
			"push":
				fe = smoothstep(0.0, 1.0, u)
				fl = fe
				fr = fe
		#  눈길은 방향을 구면으로 잇는다 — 보는 점을 곧게 이으면 가까운 점 쪽에서 각속도가 몰렸다(첫 4 분의 1 에 49°/s)
		var eye: Vector3 = (a[0] as Vector3).lerp(b[0], fe)
		var da: Vector3 = ((a[1] as Vector3) - (a[0] as Vector3)).normalized()
		var db: Vector3 = ((b[1] as Vector3) - (b[0] as Vector3)).normalized()
		var dir: Vector3 = (da.slerp(db, fl) - Vector3(0.0, dip, 0.0)).normalized()
		cur = [eye, eye + dir, lerpf(float(a[2]), float(b[2]), fr), lerpf(float(a[3]), float(b[3]), fe)]
	return cur


#  숨 — 눈을 뜬 뒤 늘(HEAD.br_in 초에 걸쳐 켠다) · 다이브에 걷는다(뛰어듦 앞에 다 걷힌다 — 유리에 다가갈수록 몇 mm 숨이
#  한가운데를 흔든다). [숙임 도, 눈 높이 m]
static func _breath(t: float) -> Array:
	var b0: float = minf(float(T.dive0), lunge_at() - 0.3)
	var k: float = smoothstep(float(LID[6][0]), float(LID[6][0]) + float(HEAD.br_in), t) \
			* (1.0 - smoothstep(b0, b0 + 0.3, t))
	var s: float = sin(TAU * float(HEAD.br_hz) * (t - float(LID[6][0])))
	return [float(HEAD.br_pitch) * s * k, float(HEAD.br_y) * s * k]


#  카메라 변환 · 화각 — 다이브는 눈이 보던 선(눈 → 화면 한가운데) 위로 끝 거리까지 들고 보는 데는 한가운데 그대로(그림이
#  아래에서 미끄러져 들지 않는다 · 돌지 않는다). 거리는 로그로 줄인다(Plg 와 같다 — dive_w 가 고르게 늘면 그림이 고른 비로
#  커진다 · 끝에 가장 빠르게 뚫는다). c 화면 한가운데 · ce 다이브 끝 {look, d 거리}.
static func _cam_xf(t: float, c: Vector3, ce: Dictionary) -> Array:
	var p := _pose_at(t, c)
	var eye: Vector3 = p[0]
	var look: Vector3 = p[1]
	var br := _breath(t)
	#  숨은 눈 · 보는 점을 같이 올린다(눈만 올리면 보는 점이 가까운 자세에서 숙임이 몇 배로 커져 길 첫 틀에 덜컥 뛰었다)
	eye.y += float(br[1])
	look.y += float(br[1])
	var u: float = clampf((t - float(T.dive0)) / (float(T.dive1) - float(T.dive0)), 0.0, 1.0)
	if (t > lunge_at() if _phos() else u > 0.0) and not ce.is_empty():
		var o: Vector3 = eye - (ce.look as Vector3)
		if _phos():
			eye = (ce.look as Vector3) + o.normalized() * _phos_d(t, float(p[3]))
		else:
			eye = (ce.look as Vector3) + o * pow(float(ce.d) / o.length(), Plg.dive_w(u, DIVE.creep))
		#  보는 점에도 숨을 싣는다(눈에만 남으면 dive0 첫 틀에 방향이 0.06° 꺾여 화면이 1 도트 튀었다 · 검토)
		look = (ce.look as Vector3) + Vector3(0.0, float(br[1]), 0.0)
	var xf := Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)
	if absf(float(p[2])) > 0.01:
		xf.basis = xf.basis * Basis(Vector3.BACK, deg_to_rad(float(p[2])))
	xf.basis = xf.basis * Basis(Vector3.RIGHT, deg_to_rad(float(br[0])))
	return [xf, float(p[3])]


#  인광 점 속으로의 다가감 거리 — 유리 배 M(= 유리 높이 ÷ 화면 높이 · Plg.glass_pg = k ÷ 거리)을 뛰어듦 시작(l0) 뒤 틀 f 의
#  로그 줌 Z(f) 로 민다. 밀기 꼬리 위에서 붙으니 그 틀의 밀기 빠르기 r0 를 그대로 잇는다(서지 않는다): Z = r0·f + q·(f/n)^p ·
#  n 틀(PHOS_RATE solid)에 PHOS.take(유리가 화면을 다 덮는다 = Phos 첫 단) · 그 틀 빠르기가 첫 단 빠르기 re(ln(mag 1 ÷ mag 0) ÷
#  hold 0) — 둘에서 p 를 푼다(p > 1 — 늘 빨라진다 · 유리가 화면을 덮는 틀에 빠르기가 안 튄다). 그 뒤 Phos 밑에서는 re 로
#  고르게 handoff 까지(안 보인다 · 줄지 않는다 · DIVE.end 를 안 넘게 re 를 누른다). 밀기는 그동안에도 화각을 좁히지만 거리가
#  배를 맞춘다(눈은 한가운데로 가는 선 위). fov 이 틀 화각
static func _phos_d(t: float, fov: float) -> float:
	var G := _tv_glass()
	var c: Vector3 = G.c
	var gh: float = (G.gb as AABB).size.y
	var l0 := lunge_at()
	var m0 := _push_m(l0, c, gh)
	var r0: float = log(m0 / _push_m(l0 - 1.0 / 60.0, c, gh))
	var R := Plg.phos_rate()
	var n: float = float(R.solid)
	var hd: Array = R.hold
	var mg: Array = Plg.PHOS.mag
	var tk: float = float(Plg.PHOS.take)
	var re: float = minf(log(float(mg[1]) / float(mg[0])) / float(hd[0]),
			log(float(DIVE.end) / tk) / (Plg.phos_lunge() * 60.0 - n))
	var zt: float = log(tk / m0)
	var q: float = zt - r0 * n
	var p: float = (re - r0) * n / q
	var f: float = clampf((t - l0) * 60.0, 0.0, Plg.phos_lunge() * 60.0)
	var z: float = r0 * f + q * pow(f / n, p) if f < n else zt + re * (f - n)
	return gh / (2.0 * tan(deg_to_rad(fov) * 0.5) * m0 * exp(z))


#  밀기(뛰어듦 없이)의 유리 배 — 그 때 자세 · 숨의 눈에서
static func _push_m(t: float, c: Vector3, gh: float) -> float:
	var p := _pose_at(t, c)
	var e: Vector3 = (p[0] as Vector3) + Vector3(0.0, float(_breath(t)[1]), 0.0)
	return gh / (2.0 * tan(deg_to_rad(float(p[3])) * 0.5) * e.distance_to(c))


static func _cam(hn: Node, t: float) -> void:
	var cam := hn.get_meta("cam") as Camera3D
	var r := _cam_xf(t, _tv_glass().c, hn.get_meta("end", {}))
	cam.fov = r[1]
	cam.global_transform = r[0]
	var u: float = clampf((t - float(T.dive0)) / (float(T.dive1) - float(T.dive0)), 0.0, 1.0)
	#  유리 속 — 그림이 화면에 박힌 게임 그림으로 옮겨 가고(Plg.portal) · 유리 반짝(Plg.glint — 틀마다 · 창 밖이면 끈다) ·
	#  필름 말 · 안개가 걷힌다
	#  인광 점 속으로는 그림이 끝까지 유리에 붙어 커진다(portal 0 · 반짝 없음 — Phos 가 이어받는다)
	var scr: ShaderMaterial = hn.get_meta("scr")
	if scr != null and not _phos():
		var G := _tv_glass()
		var po: float = Plg.portal(scr, u, Plg.glass_pg(cam, G.c, (G.gb as AABB).size.y))
		scr.set_shader_parameter("sat", lerpf(1.0, float(DIVE.sat), po))
		Plg.glint(scr, t - handoff())
	var gk: float = 1.0 - smoothstep(float(Plg.LOOK.gone[0]), float(Plg.LOOK.gone[1]), u)
	(hn.get_meta("grade") as ShaderMaterial).set_shader_parameter("k", gk)
	(hn.get_meta("env") as Environment).volumetric_fog_density = 0.006 * gk


#  TV 화면 — 시계 · 지지직 몫(단)
static func _tv_tick(hn: Node, t: float) -> void:
	var scr: ShaderMaterial = hn.get_meta("scr")
	if scr == null:
		return
	scr.set_shader_parameter("tm", t)
	scr.set_shader_parameter("snowk", _snow(t))
	#  자르기 한가운데 — 문 한가운데(다트판 · 간판)가 유리 세로축에(그림 속 판이 오른쪽에 서서 TV 는 가운데인데 눈이 오른쪽으로
	#  끌렸다 · 검토 3)
	var g: Node = hn.get_meta("game")
	if g != null and g.has_method("_title_c"):
		var cw: float = float(scr.get_shader_parameter("cw"))
		scr.set_shader_parameter("cx", clampf(float(g._title_c().x) / float(g.VIEW.x), cw * 0.5, 1.0 - cw * 0.5))
		var on: bool = t >= float(SIGN.t0) and t < handoff()
		g.plg_sign_t = minf(float(SIGN.from) + (t - float(SIGN.t0)) * float(SIGN.rate), float(SIGN.hold)) if on else -1.0


static func _snow(t: float) -> float:
	var v := 1.0
	for s in SNOW:
		if t >= float(s[0]):
			v = float(s[1])
	return v


# ══ 소리 ═════════════════════════════════════════════════
#  방 소리 · 닦기(순환) · 먼 잔 · 잔 놓기 · 딸깍(한 번)은 제 버스(BarAmb_… — 로패스가 눈과 같이 열리고 빛이 꺼지는 단마다
#  닫히고 다이브에 다 닫힌다) · TV 지지직 · 웅(순환)은 SFX(먹먹해지지 않는다). 넘김(퍽) 뒤 꼬리(SND.tail)가 잦아들면 버스를 걷는다.
#  clink 먼 잔 · lp 로패스 [닫힘 · 열림](Hz) · static TV 지지직 [감은 눈 · 화면 밖(눈 뜬 뒤) · 올려다본 뒤](dB) · hum 웅(같은 차례) ·
#  click 빛 딸깍 · tv 그림이 비치는 동안 SFX 에 거는 작은 스피커 [고역 통과 · 저역 통과(Hz) · 줄임(dB)] — 게임 인트로 소리가
#  TV 소리로 들리다가 · tv_out 들어가는 때(entry_at) 앞 이 초에 걸쳐 TV 소리(스피커 · 지지직 · 웅)를 걷는다 — 반짝 ·
#  삐싱 · 퍽은 TV 소리가 아니다(스피커를 지나니 싱 −22 · 퍽 −11dBFS 로 먹먹하고 퍽이 인트로의 네온 쾅(−10)보다 작았다).
#  그 사이 인트로는 소리가 없다(뛰어듦 안에 드는 램프 꺼짐 딸깍은 game _sfx 가 걷는다 · 간판 소리는 SIGN.t0 · 쾅은 건넌 뒤) · 방은 로패스로 닫히는
#  중이라 쉬익이 홀로 차오른다 · tail 넘김 뒤 방 소리(로패스가 다 닫힌 채 −50dBFS 언저리)가 다 잦아드는 초 — 넘김에 끊으니 퍽 뒤
#  게임 속이 디지털 무음이라 멈춘 것처럼 읽혔다(유리 반짝 검토 2 · LEN 이 이 꼬리까지)
const SND := {"clink": 0.6, "lp": [600.0, 16000.0], "static": [-24.0, -15.0, 0.0], "hum": [-20.0, -12.0, 0.0],
		"click_db": -8.0, "tv": [350.0, 4800.0, -4.0], "tv_out": 0.07, "tail": 1.0}


static func _loop(g: Node, nm: String) -> AudioStreamWAV:
	var st := g._sfx_file(nm) as AudioStreamWAV if g.has_method("_sfx_file") else null
	if st == null:
		return null
	st = st.duplicate() as AudioStreamWAV
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = int(st.get_length() * float(st.mix_rate))
	return st


static func _audio_make(hn: Node, g: Node) -> void:
	if AudioServer.get_bus_index("SFX") < 0 or g == null:
		return
	var bus := "BarAmb_%d" % hn.get_instance_id()
	var bi := AudioServer.bus_count
	AudioServer.add_bus(bi)
	AudioServer.set_bus_name(bi, bus)
	AudioServer.set_bus_send(bi, "SFX")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = float(SND.lp[0])
	lp.db = AudioEffectFilter.FILTER_12DB
	AudioServer.add_bus_effect(bi, lp)
	(hn as Hold).bus = bus
	hn.set_meta("lp", lp)
	var pl := {}
	for k in [["room", "bar_room", bus], ["polish", "bar_polish", bus], ["static", "bar_tv_static", "SFX"],
			["hum", "bar_tv_hum", "SFX"]]:
		var st := _loop(g, String(k[1]))
		if st == null:
			continue
		var p := AudioStreamPlayer.new()
		p.stream = st
		p.bus = String(k[2])
		hn.add_child(p)
		pl[k[0]] = p
	hn.set_meta("snd", pl)
	hn.set_meta("rang", {})


static func _shot(hn: Node, nm: String, bus: String, db := 0.0, pitch := 1.0) -> void:
	var g: Node = hn.get_meta("game")
	var st: AudioStream = g._sfx_file(nm) if g != null and g.has_method("_sfx_file") else null
	if st == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = bus
	p.volume_db = db
	p.pitch_scale = pitch
	hn.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


static func _audio_tick(hn: Node, t: float) -> void:
	if not hn.has_meta("snd"):
		return
	var pl: Dictionary = hn.get_meta("snd")
	var rang: Dictionary = hn.get_meta("rang")
	var bus: String = (hn as Hold).bus
	var bi := AudioServer.get_bus_index(bus) if bus != "" else -1
	if not rang.has("start"):
		rang["start"] = true
		for k in pl:
			(pl[k] as AudioStreamPlayer).play()
	#  눈과 같이 열리는 로패스(로그 눈금) — 감으면 0 · 반쯤 0.45 · 첫 뜸 뒤 깜박임은 0.3 까지만 · 빛이 꺼지는 단마다 닫힌다 ·
	#  다이브에 다 닫힌다
	var k: float = _lid(t)
	if t > float(LID[3][0]) - 0.2:
		k = maxf(k, 0.3)
	var steps := [1.0, 0.85, 0.7, 0.58, 0.45, 0.35, 0.25]
	var n := 0
	for c in CLICK:
		if t >= float(c):
			n += 1
	k = minf(k, float(steps[n]))
	var du: float = clampf((t - float(T.dive0)) / (float(T.dive1) - float(T.dive0)), 0.0, 1.0)
	k *= 1.0 - du
	if hn.has_meta("lp"):
		var lf: Array = SND.lp
		(hn.get_meta("lp") as AudioEffectLowPassFilter).cutoff_hz = float(lf[0]) * pow(float(lf[1]) / float(lf[0]), k)
	if bi >= 0:
		AudioServer.set_bus_volume_db(bi, linear_to_db(maxf(1.0 - 0.12 * float(n), 0.05)))
	#  방 소리 꼬리 — 다이브엔 로패스만 닫히고 넘김 뒤 SND.tail 초에 소리 자리에서 걷는다(버스를 걷을 때 남은 소리가 Master 로
	#  새어 딸깍이지 않게 버스가 아니라 자리 크기로)
	if pl.has("room"):
		(pl.room as AudioStreamPlayer).volume_db = linear_to_db(maxf(1.0 - clampf((t - handoff()) / float(SND.tail), 0.0, 1.0),
				0.00001))
	#  닦기 — 고쳐 쥘 때 잦아들고 내려놓으면 멎는다(박자는 시작부터 비틀기와 같다)
	if pl.has("polish"):
		var pp := pl.polish as AudioStreamPlayer
		var rg: Array = POLISH.regrip
		var q: float = 1.0 if (t < float(rg[0]) or t > float(rg[1])) else 0.2
		pp.volume_db = linear_to_db(q) - 3.0
		if t >= float(POLISH.down[0]) and pp.playing:
			pp.stop()
	#  TV — 지지직은 그림이 비칠수록 단으로 잦아들고 · 웅은 올려다볼 때부터 크다. 반짝 앞 SND.tv_out 에 걸쳐 걷고 반짝 틀에
	#  멎는다 — 스피커도 그 틀에 걷혀 쉬익은 처음부터 날것이다(반짝 뒤에 걷으니 차오르는 쉬익 4 틀째에 고역이 한 틀에 열려
	#  「틱」 이음매가 났다 · 검토)
	var tg: float = entry_at()
	var tvk: float = 1.0 - clampf((t - (tg - float(SND.tv_out))) / float(SND.tv_out), 0.0, 1.0)
	#  인광 점 속으로 — TV 웅이 걷히는 틀에 들어가는 소리가 이어받는다(차오르는 웅 · 이잉 · 줄을 지날 때 지직 · 넘김에 끊긴다)
	if _phos() and t >= tg and not rang.has("phos"):
		rang["phos"] = true
		_shot(hn, "bar_phos", "SFX")
	if pl.has("static"):
		var sk: float = _snow(t)
		var sp := pl.static as AudioStreamPlayer
		var sd: Array = SND.static
		var near: float = float(sd[2]) if t >= float(MOVE[2][0]) else (float(sd[1]) if t >= float(WAKE.blink) else float(sd[0]))
		sp.volume_db = near + linear_to_db(0.3 + 0.7 * sk) + linear_to_db(maxf(tvk, 0.001))
	if pl.has("hum"):
		var hp := pl.hum as AudioStreamPlayer
		var hd: Array = SND.hum
		hp.volume_db = float(hd[2]) if t >= float(MOVE[2][0]) else (float(hd[1]) if t >= float(WAKE.blink) else float(hd[0]))
		hp.volume_db += linear_to_db(maxf(tvk, 0.001))
	for kk in ["static", "hum"]:
		if tvk <= 0.0 and pl.has(kk) and (pl[kk] as AudioStreamPlayer).playing:
			(pl[kk] as AudioStreamPlayer).stop()
	#  한 번씩 — 먼 잔 · 잔 놓기 · 빛이 꺼질 때마다 딸깍
	if t >= float(SND.clink) and not rang.has("clink"):
		rang["clink"] = true
		_shot(hn, "bar_clink", bus)
	if t >= float(POLISH.down[1]) and not rang.has("down"):
		rang["down"] = true
		_shot(hn, "bar_glass_down", bus, -2.0)
	for i in CLICK.size():
		var ck := "click%d" % i
		if t >= float(CLICK[i]) and not rang.has(ck):
			rang[ck] = true
			_shot(hn, "deck_grab", bus, float(SND.click_db), 0.72)
	#  TV 스피커 — 그림이 비치는 동안 게임 인트로 소리(SFX)를 작은 통 소리로 · 반짝이 서고 TV 소리가 걷히면 걷는다
	var tv_on: bool = t >= float(T.feed) and tvk > 0.0
	if tv_on != (not (hn as Hold).spk.is_empty()):
		if tv_on:
			(hn as Hold).spk_on()
		else:
			(hn as Hold).spk_off()
	#  넘김 뒤 꼬리(SND.tail)가 다 잦아들면 방 소리 자리 · 버스를 걷는다
	if t >= handoff() + float(SND.tail) and bi >= 0:
		for kk in ["room", "polish"]:
			if pl.has(kk):
				(pl[kk] as AudioStreamPlayer).stop()
		AudioServer.remove_bus(bi)
		(hn as Hold).bus = ""


# ══ 한 틀 ═════════════════════════════════════════════════
static func tick(hn: Node, t: float) -> void:
	hn.set_meta("t", t)
	_lights(hn, t)
	_merch_tick(hn, t)
	_tv_tick(hn, t)
	_cam(hn, t)
	#  층은 카메라가 선 뒤에(번쩍 오름 단이 이 틀의 유리 둘레로 잘린다)
	_layer(hn, t)
	_post_tick(hn, t)
	_lids_tick(hn, t)
	_audio_tick(hn, t)
