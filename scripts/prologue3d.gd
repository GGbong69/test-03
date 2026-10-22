extends RefCounted
# ══════════════════════════════════════════════════════════
#  프롤로그 — 전파상 창고의 주인공 TV · 3D 를 도트로 (2026-10-18)
# ──────────────────────────────────────────────────────────
#  「게임 시작 할 때 프롤로그 … tv화면이 전체 화면이 되고 그 때 부터 우리가 만든 tv 켜짐 부터」 · 장소
#  「어두운 전파상 창고」 · 「그냥 제작자만 보여주자」(김건의) · 「그냥 3d로 하고 도트같이 필터를 씌우자」 ·
#  「카메라 무빙 넣지말고 … 불이 깜박깜박 됐다가 게임 tv로 클로즈업」 · 「다른 tv들 그냥 아무 장면이나 보여줘도
#  되 노이즈가 걸린 tv가 있어도 괜찮고」 · 「중요하지 않은 tv랑 중요한 tv는 나누고 중요한 tv는 좀 퀄리티
#  엄청엄청 높게 하고 안 중요한 tv는 좀 엑스트라? 명도나 밝기도 조금 어둡게」 · 「메인 tv가 가운데 크게 보이도록
#  사질 나머지는 거의 안보여도 괜찮잖아」(젠레스 존 제로 런처 그림)(사용자).
#  주인공 TV(TvHero · 비디오 데크 위) 하나가 화면 가운데를 크게 차지하고, 둘레의 TV 더미는 엑스트라 — 몸은
#  어둡고(EXTRA) 화면은 흐리고 덜 붉다. 주인공은 게임 TV 다 — 크레딧 뒤에 깜박이며 켜져 **게임의 인트로를
#  그대로 튼다**(「크로즈업 되기전에 TV가 깜박이고 좀 재생되는 중에 클로즈업 되야 좀 몰입하는 느낌이 나지
#  않을까?」 · 인트로 첫 그림을 보냈다). 무대 · 층은 도트 화판 **밖**(game.gd screen_host)에 서고, 주인공 유리는
#  화판 그림(게임이 그 밑에서 그리는 인트로)을 유리 높이에 꽉 채우고 양옆을 잘라 비춘다(처음엔 16:9 를 통째로
#  넣어 위아래 띠가 섰다 — 「해상도가 안 맞는데?」). 클로즈업은 TV 속으로 들어간다(「클로즈업이 아예 TV속으로
#  들어가는것 같이」) — 카메라가 유리를 지나 테가 화면 밖으로 빠질 때까지 밀고 들고, 그동안 유리 속 그림은 유리를
#  따라 커지던 것에서 화면에 박힌 게임 그림(SCREEN_UV — portal)으로 옮겨 간다. 끝에는 층 안에 화판 그림을 그대로
#  깔아(Feed) 층을 걷어도 같은 그림이다 — 그때(handoff) 게임 필터가 켜지고 층이 걷힌다.
#  「제작 김건의」는 왼쪽 빨간 휴대용 TV(maker — 엑스트라지만 흐리지 않다)에 뜬다
#  (「이름은 붉은색으로 표시한곳에 표시해도 되잖아」 → 「이름 표시 TV 위치도 왼쪽으로」 · 지지직 → 그림).
#  그 그림은 옛 방송 끝 자막이다 — 검은 바탕 · 크림빛 글 · 빛깔 번짐 · 낟알 · 가끔 튀는 줄 · 흐르는 밝은 띠
#  (「색이 무슨 유아용 게임도 아니고 좀 레트로한 감성 살린 화면으로」 — 주황 띠 바탕을 걷었다).
#  카메라는 처음부터 주인공 **화면** 한가운데를 곧게 본다(「tv화면을 진짜 중앙에 배치해 지금 클로즈업 될때
#  살짝 왼쪽으로 가는게 있잖아」 — 화면이 몸 왼쪽에 있어 몸 한가운데를 보던 카메라가 다가가며 옆으로 흘렀다).
#  빛 · 그늘 — 「방을 진짜 어둡게 하라고 tv 빛 이외에는 빛도 없도록」 · 「이름 표시 tv는 메인 TV보다 뒤에 있는거
#  아니야? 근데 왜 메인 TV 앞면까지 빛에 째이는거야」(사용자). 방에는 등 · 환경광이 없다 — 빛은 켜진 화면뿐이다.
#  화면 빛은 유리 바로 앞에서 앞쪽 반구로만 나가는 원뿔(SCR_LIT)이라 뒤에 선 TV 는 주인공 앞면을 못 비추고
#  옆면 · 바닥만 물들인다(처음엔 화면 앞 35cm 의 점 빛이라 뒤 TV 빛이 주인공 앞면에 닿았다). 「불이 깜박깜박」은
#  TV 들이 차례로 깜박이며 켜지는 것이다. 몸은 제목 문(Door3D)과 같은 결 그림 재질(TRI_SHADER — UV 없는
#  Blender 몸에 앞 · 옆 · 위로 결을 비춘다 · 나무 결은 결 대비 · 채도를 누른다) · 필름 톤 · 둘레 비네트.
#  TV 는 scripts/tools/blender/tvs.py 가 짓는다(assets/models/tvs.glb). 무대는 논리 화면 크기의 SubViewport
#  — 게임 도트와 같은 격자에 그려 가장 가까운 점으로 붙인다. 화면은 SCR_SHADER(화면 도트 칸 · 주사선).
#  화면은 tvs.py 에서 귀만 둥근 네모다(「tv의 테두리가 너무 둥글지 않아?」).
#  흐름 — 어둠(구석 지지직 한 대) → 둘레 TV 가 차례로 깜박이며 흐리게 켜진다 → 크레딧 TV 가 켜진다
#  (지지직 → 제작자) → 주인공이 깜박이며 켜져 인트로를 튼다 → 카메라가 곧게 다가간다 → 유리 속 그림이 화면을
#  채우면 층이 걷히고 인트로가 이어진다.
#  주인공 · 제작자 TV 만 또렷하다(「진짜 메인 TV 제작자 TV 만 제대로 나오고 남은거는 거의 안 보이게? 그냥 배경
#  느낌」 → 「그렇다고 진짜 배경으로 넣으라는 소린 아니었다고」 — 더미는 주인공 둘레 탑 그대로). 둘레 TV 는 화면 ·
#  빛을 낮춰(EXTRA · REEL) 어둠에 잠기고, 제작자 TV 는 주인공 앞면 쪽으로 당겨 섰다. 카메라 초점은 주인공 유리에
#  있어(DOF) 그 바로 뒤에 붙은 둘레 TV 가 살짝 흐리다 — 초점은 카메라가 다가가는 동안 주인공 거리를 따라간다
#  (_focus). 주인공 화면 앞에는 먼지가 떠다니며 그 빛을 받아 반짝인다(DUST — 카메라가 다가가는
#  동안 그 사이를 지나 깊이가 난다).
#  주인공이 켜질 때 조작판이 움직인다(「메인 화면 켜질때 메인tv의 오른쪽 버튼? 레버?들이 움직일수 있나?」) —
#  채널 다이얼이 딸깍 돌며 켜지고 · 슬라이더가 올라가며 그림이 밝아지고 · 볼륨 다이얼이 스르르 돌고 · 빨강 · 초록 ·
#  파랑 등이 차례로 든다(KNOB). 도는 몫은 tvs.py 가 따로 낸 HeroKnobA · HeroKnobB · HeroSlider(제 자리 · 처음 각은
#  glb 노드 변환).
#  둘레 TV 여섯은 영화 명장면 이스터에그다(REELS 열셋 — 「여러 영화의 명장면을 도트로 … 저작권은 안 걸리게」 ·
#  「여러 영화가 랜덤으로 나오면 좋겠고 이스터에그 tv는 밝기 낮춰」). 켤 때마다 장면을 섞어 나눠 주고, 저마다
#  한 번 채널이 넘어가며(지지직) 다른 장면이 된다 — 어느 때든 두 화면에 같은 장면이 안 뜬다. 밝기는 둘레
#  엑스트라 언저리 — 찾아야 보인다. 스틸을
#  따라 그리지 않고 구도 · 상황만 빌려 코드로 새로 그린 실루엣이다 — 얼굴 · 생김새 · 분장 · 제목 · 대사 · 로고는
#  없다. 복도에서 망치를 든 사람 · 철교 위에서 팔을 벌린 사람 · 경찰차 지붕에서 춤추는 빨간 정장 · 노을 진
#  뱃머리의 두 사람 · 하늘 그림 벽의 검은 문 앞에서 절하는 사람 · 빗속 긴 사선 계단을 내려가는 식구 · 누런 논의
#  배수로를 들여다보는 흰 셔츠 · 빗속 가로등에 매달린 우산 든 사람 · 옥상에서 뒤로 젖힌 긴 코트와 총알 물결 ·
#  보랏빛 언덕 가로등 옆에서 춤추는 노란 옷 · 흰 셔츠 · 새벽 계단 꼭대기에서 두 팔을 든 뒷모습 · 새벽 사막의
#  검은 석판과 웅크린 유인원 · 공원 벤치 끝의 흰 정장과 떠다니는 깃털(「다른 영화들도 레퍼런스 조사 하고」 —
#  장면마다 스틸 검색으로 구도를 쟀다).
#  API — make(game, outer) · tick(h, t) · length() · handoff() · feed_at() · ON(TV 가 켜지는 때) · cues()(소리 때
#  전부 — 앞 토막 것까지 · game.gd _plg_tick 이 한 번씩 낸다).
# ──────────────────────────────────────────────────────────
#  앞 토막 — 비디오테이프를 넣는 손 (2026-10-22)
#  「시작 하면 애니메이션? 좀 영화같이 씬을 보여줘서 약간 스토리도 챙기고 싶어」 · 「애니메이션은 뭐가 되었든 TV로
#  이어져야지」(사용자) — 고른 안 「비디오테이프를 넣는 손」. 게임은 TV 안에서 시작하므로 이 토막도 TV 로 든다.
#  글 · 말 없이 물건이 이야기한다:
#   · 어둠에 창밖 빗소리만 먹먹하게(game.gd plg_rain · Rain 버스 로패스) → 주인공 TV 밑 데크에 낮고 가깝게 선 눈.
#     빛은 구석 지지직 TV(차고 깜박인다 — 그 빛 한 줄기가 구멍 둘레만 짚는다 · 깃발로 끊은 촬영 빛)와 데크의
#     VFD(청록 대시가 1Hz 로 깜박) · 표시등(빨강)뿐이다. 나머지는 검다.
#   · 상인의 손(얼굴은 안 나온다 — 상점과 같은 Blender 손 · 걷은 소매 · 약지 금반지 · 반지 손 = 왼손)이 오른쪽
#     앞에서 뻗어 와 표시 없는 카세트의 오른 끝을 쥐고 들어온다. 엄지는 윗면에 눕고 · 검지는 펴서 밑을 받치고 ·
#     셋은 차례로 더 말린다(엄지두덩 · 물갈퀴째). 눈은 앞 왼쪽 낮게 선다 — 빛이 왼쪽 구석 TV 에서만 오므로 손등 ·
#     카세트 왼 끝이 빛을 받는 쪽이다(정면에서는 손등이 빛을 등져 검은 덩어리였다 · 첫 촬영). VFD · 표시등은
#     구멍 왼쪽(손에 안 가린다). 구멍 앞에서 한 박 맞추고(살짝 뺐다가) 민다 — 덮개가 안으로 젖혀지고 카세트가
#     미끄러져 든다. 절반쯤에서 기계가 받아 끌어들이고 손가락이 풀린다(엄지가 먼저 뜬다) · 손은 오른쪽 앞 밖으로
#     빠진다(더 밀면 굽힌 손가락이 구멍 밑 앞판에 닿는다 — qa_prologue ⑨ 가 손끝을 잰다). 덮개가 스프링으로
#     닫히고 철컥 — 표시등이 빨강 → 초록, 대시가 멎어 켜진 채 재생 세모가 든다(탭이 부러진 테이프는 넣기만 하면
#     저절로 돈다 — 버튼을 누르는 손이 없다). 모터가 돌고 위 TV 유리가 밑에서부터 희미하게 든다.
#   · 눈이 데크에서 위 · 뒤로 올라 TV 더미 첫 그림(cam_start)에 선다(끊지 않는다) — 그 뒤는 옛 흐름 그대로 때만
#     TAPE_LEN 뒤(ON · T · LEN · REEL · feed_at · handoff). 손 · 카세트 · 그 빛은 다 쓰면 걷는다(_tape_tick).
#  때 · 길은 TAPE 한 표 · 소리 때는 cues() 한 표. 손은 game.gd 의 상점 손(_hand3_build · _fore3_build — 같은 조각 ·
#  같은 빛 사다리)을 데크 좌표에 TAPE.s 배로 세운다(1 단위 = 3.3mm — 손 길이 58 이 190mm · 카세트 폭 187mm 와 같다).
#  레퍼런스 — VHS 실측 187 × 25 × 103mm · 등 라벨이 손 쪽 · 덮개 변이 먼저(Gough Lui) · 덮개는 안쪽으로만 젖혀지고
#  비틀림 스프링이 닫는다(US5917675) · 로딩은 감지 → 끌어들임 → 드럼 기동 2 초(EP0339646) · VFD 505nm 청록 · 옛 GaP
#  초록 표시등 · TV 빛은 약하니 깃발로 끊는다(촬영 관례) · 표시 없는 테이프(Ringu · V/H/S · Lost Highway) · 테이프를
#  넣는 순간이 문턱(사일런트 힐 2).

const Door3D = preload("res://scripts/door3d.gd")
const Room3D = preload("res://scripts/room3d.gd")
const TVS_GLB := "res://assets/models/tvs.glb"
#  앞 토막 길이 — TV 창고의 때(ON · T · LEN · REEL)는 다 이만큼 뒤로 선다
const TAPE_LEN := 6.0
const LEN := TAPE_LEN + 6.1
#  켜지는 때 — tvs 둘레 TV(차례로) · maker 크레딧 TV · hero 주인공(이때 인트로 시계가 출발한다)
const ON := {"tvs": TAPE_LEN + 1.0, "maker": TAPE_LEN + 1.75, "hero": TAPE_LEN + 2.55}
#  stag 둘레 TV 가 차례로 켜지는 사이 · snow 크레딧 TV 가 켜진 뒤 지지직 동안 · push0~push1 다가가는 동안
const T := {"stag": 0.07, "snow": 0.45, "push0": TAPE_LEN + 3.55, "push1": TAPE_LEN + 5.65}
#  끝에 층이 걷히는 시간(LEN 앞 out 초부터 — handoff). 어둠에서 떠오르는 것은 앞 토막(TAPE.black · fade)이 맡는다 —
#  TV 방은 눈이 데크에서 올라와 이미 보인다.
const FADE := {"out": 0.45}
#  앞 토막(초 · 자리는 데크 좌표 m — 원점은 바닥 한가운데 · 앞면 z 0 · 구멍 · 카세트 치수는 tvs.py 사본) —
#    black 빗소리만 · fade 떠오르는 동안 · cam 눈(앞 왼쪽 낮게 — 빛이 왼쪽 구석 TV 에서 오므로 손등 · 카세트 왼
#    끝이 그 빛을 받는 쪽에서 본다) · look 보는 데 · fov 화각 · focus 초점(구멍 앞)
#    crane 눈이 cam_start 로 오르는 동안(끊지 않는다 · 화각 · 초점도 옛 값으로)
#    slot 구멍 한가운데 · hole 구멍 [폭 · 높이] · tape 카세트 [폭 · 두께 · 깊이] · enter 손이 들어오는 동안 · from 들어
#    오기 전 카세트 한가운데(오른쪽 앞 — 그림 밖) · tilt 그때의 요 · 굴림(도) · near 구멍 앞에 맞춘 앞변 z ·
#    align 한 박(back 살짝 빼는 m) · push 미는 동안 · deep 손이 밀어 넣는 앞변 깊이(103mm 의 절반 — 나머지는 기계가
#    끌어들인다 · 더 밀면 굽힌 손가락이 구멍 밑 앞판에 닿는다) · pull 끌어들이는 동안(빨리 받아 천천히 앉힌다) ·
#    home 다 든 등 z · drop 내려앉는 m · clunk 철컥(홀더가 앉는다) · lead 철컥 소리 앞의 덮개 딱(deck_clunk 의 28ms)
#    flap 덮개 젖힘(도) · flap_d 그만큼 들어갈 때 다 젖혀진다(m) · hinge 경첩 z · snap 닫히는 동안 · over 넘쳤다 돈다
#    led 표시등 [대기 · 동작] · led_gap 바뀔 때 꺼진 동안(두 틀) · vfd 청록 · vfd_e 그 제 빛 · vfd_dim 꺼진 대시 ·
#    vfd_hz 깜박임 · play 철컥 뒤 재생 세모가 드는 때 · vfd_l 창 빛 [세기 · 닿는 거리 · 자리] · key 구석 TV 빛 한
#    줄기 [세기 · 원뿔(도) · 닿는 거리] · glow 위 TV 유리가 희미하게 드는 [시작 · 다 든 때 · 그 빛 몫]
#    s 손 배율(m / 손 단위) · let 손가락이 펴지는 동안(기계가 받는 때 놓는다) · leave 손이 빠지는 동안 · out 빠지는
#    길(m · 가속) · lift 놓으며 손등 쪽으로 비키는 m · fore 팔뚝 길이(손 단위)
#    grip 손 자리(카세트 좌표 — knuckle 검지 너클 · yaw · pitch · roll 도) — 상인의 왼손(반지 손)이 오른쪽 앞에서
#    뻗어 와 카세트 오른 끝을 쥔다: 엄지는 윗면 · 검지는 펴서 밑을 받치고 셋은 차례로 더 말린다(손등이 눈 · 빛 쪽)
const TAPE := {
	"black": 1.0, "fade": 0.6,
	"cam": Vector3(-0.40, 0.19, 0.34), "look": Vector3(-0.10, 0.09, 0.0), "fov": 32.0,
	"focus": Vector3(-0.08, 0.084, 0.05), "crane": [5.0, 6.0],
	"slot": Vector3(-0.08, 0.084, 0.0), "hole": Vector2(0.196, 0.032), "tape": Vector3(0.187, 0.025, 0.103),
	"enter": [1.0, 1.8], "from": Vector3(0.30, 0.15, 0.36), "tilt": [20.0, -8.0], "near": 0.006,
	"align": [1.8, 2.05], "back": 0.004, "push": [2.05, 2.45], "deep": 0.048,
	"pull": [2.45, 2.80], "home": -0.012, "drop": 0.012, "clunk": 2.90, "lead": 0.028,
	"flap": 86.0, "flap_d": 0.02, "hinge": -0.004, "snap": 0.12, "over": 6.0,
	"led": [Color("ff2a1a"), Color("8cff3a")], "led_gap": 0.035,
	"vfd": Color("33f2c2"), "vfd_e": 1.0, "vfd_dim": 0.12, "vfd_hz": 1.0, "play": 0.45,
	"vfd_l": [0.035, 0.12, Vector3(-0.27, 0.085, 0.02)], "key": [1.4, 13.0, 1.8], "glow": [3.9, 5.0, 0.1],
	"s": 0.00328, "let": [2.45, 2.58], "leave": [2.50, 3.25], "out": Vector3(0.42, 0.08, 0.40),
	"lift": Vector3(0.0, 0.006, 0.02), "fore": 80.0,
	"grip": {"knuckle": Vector3(0.045, -0.018, 0.066), "yaw": -30.0, "pitch": 0.0, "roll": 15.0},
}
#  손가락 자세 — game.gd FPOSE 차례 [첫 굽힘 ×4 · 끝 굽힘 ×4 · 부채 · 엄지 접기 · 엄지 굽힘 · 엄지 내림].
#  grip 쥔 손(엄지는 윗면에 눕고 · 검지는 펴서 밑 · 가운데 · 약지 · 새끼는 차례로 더 말린다 — 다섯이 다 일하지 않는다) ·
#  let 놓은 손(조금 풀린다 · 엄지가 먼저 뜨고 검지가 한 박 늦다)
const TAPE_POSE := {
	"grip": [10.0, 40.0, 60.0, 78.0, 15.0, 70.0, 85.0, 95.0, 12.0, 0.0, 30.0, 50.0],
	"let": [8.0, 30.0, 45.0, 60.0, 10.0, 45.0, 60.0, 75.0, 8.0, 0.0, 10.0, 20.0],
}
#  층 — 게임 필터(CRT 100 · VHS 98 · 도트 97 · 반전 96) 밑
const LAYER := 90
const FONT_BIG := "res://fonts/Paperlogy-7Bold.ttf"
const FONT_SM := "res://fonts/Galmuri9.ttf"
#  제작자 그림 — 크레딧 TV 유리가 첫 장면에서 차지하는 논리 px 언저리(1 칸 = 1 px)
const CARD := Vector2i(120, 108)
#  카메라 — 주인공 화면 한가운데에서 앞으로 dist(m) · 세로 화각(주인공 폭이 화면 폭의 여섯 몫 언저리)
const CAM := {"dist": 1.55, "fov": 34.0}
#  초점(_focus) — 주인공 유리까지의 거리 d 에서 d + dof_at 너머가 dof_tr 에 걸쳐 흐려진다(세기 dof_k)
const FOCUS := {"dof_at": 0.08, "dof_tr": 0.16, "dof_k": 0.12}
#  먼지 — n 알 · 크기(m) · 상자(주인공 유리 앞 — 가로 · 세로 반폭 · 앞으로 깊이) · 떠도는 빠르기 · 빛 받는 거리(유리
#  에서 이 안이면 밝다) · 가장 밝을 때 알파
const DUST := {"n": 70, "size": 0.004, "box": Vector3(0.7, 0.45, 1.1), "drift": 0.025, "lit_r": 0.8, "a": 0.55}
#  빛 — glow 화면 번짐 세기 · 문턱 · vig 둘레 비네트 짙기(가장자리 알파)
const LIT := {"glow": 0.45, "glow_thr": 0.9, "vig": 0.55}
#  화면 빛(SCR_LIT) — 유리 앞 at(m)에서 앞으로 원뿔 ang(도) · 닿는 거리 range · 세기는 MAKER · EXTRA 의 light
const SCR_LIT := {"at": 0.08, "ang": 85.0, "range": 1.3, "att": 1.0}
#  재질 — den 결 그림 1 텍셀이 첫 장면의 주인공 앞면에서 논리 1px(1m 당 텍셀) · walnut 주인공 몸(짙은 호두
#  나무) · wood 엑스트라 나무 장
const MAT := {"den": 450.0, "walnut": Color("3a2414"), "wood": Color("4a2e18")}
#  MAKER — 크레딧 TV 의 화면 빛 세기(주인공 왼쪽 옆면 · 바닥을 물들인다).
const MAKER := {"light": 1.3}
#  주인공 화면 빛 — light 앞으로 나가는 원뿔 세기 · rim 유리 둘레(테 · 검은 판 안쪽)를 비추는 작은 빛 세기 ·
#  rim_r 그 닿는 거리 · dive 끝 거리 — 유리 폭이 화면 폭을 꼭 채우는 거리의 몫(1 밑이면 유리를 지나 테가 화면
#  밖으로 빠진다) · portal 다가가는 몫(0~1)의 이 구간에서 유리 속 그림이 화면에 박힌 그림으로 옮겨 간다 ·
#  flat 이 구간에서 층 안에 화판 그림을 그대로 깐다(필름 톤 · 번짐이 낀 무대 그림과 게임 그림의 톤 차를 잇는다)
const HERO := {"light": 1.1, "rim": 0.4, "rim_r": 0.55, "dive": 0.78, "portal": [0.45, 0.95], "flat": [0.8, 1.0]}
#  엑스트라 — 점 빛 세기 · 몸 빛깔 배수 · 화면 밝기 · 채도 · 화면 도트(1m 당 칸) · 화면 색 단 수
const EXTRA := {"light": 0.3, "tone": 0.42, "dim": 0.13, "sat": 0.6, "cells": 110.0, "lv": 8.0}
#  화면 장면 — 번호(SCR_SHADER mode) · 앞에 둔 점 빛 빛깔. game 은 주인공(지지직 1 → 화판 그림 9) · maker 는
#  크레딧(지지직 1 → 제작자 그림 4).
const JOB := {
	"game": [9, Color(1.0, 0.80, 0.60)], "maker": [4, Color(1.0, 0.90, 0.74)],
	"snow": [1, Color(0.62, 0.68, 0.80)], "bars": [2, Color(0.72, 0.70, 0.60)],
	"blue": [3, Color(0.25, 0.40, 1.0)], "wave": [5, Color(0.35, 1.0, 0.50)],
	"ball": [6, Color(0.60, 0.62, 0.70)], "sunset": [7, Color(1.0, 0.50, 0.38)], "board": [8, Color(0.85, 0.72, 0.60)],
	"reel": [4, Color(0.7, 0.7, 0.7)],
	"hammer": [4, Color(0.55, 0.65, 0.52)], "rail": [4, Color(0.78, 0.80, 0.72)], "dance": [4, Color(0.85, 0.45, 0.40)],
	"bow": [4, Color(1.0, 0.62, 0.38)], "exit": [4, Color(0.50, 0.65, 0.95)],
	"stairs": [4, Color(0.45, 0.60, 0.58)], "field": [4, Color(0.90, 0.78, 0.45)], "lamp": [4, Color(0.55, 0.62, 0.85)],
	"bullet": [4, Color(0.60, 0.80, 0.62)], "hill": [4, Color(0.62, 0.50, 0.95)], "steps": [4, Color(0.95, 0.78, 0.70)],
	"monolith": [4, Color(0.95, 0.75, 0.50)], "bench": [4, Color(0.60, 0.85, 0.55)],
}
const PLASTIC := {"red": Color("a83c30"), "teal": Color("2f8a84"), "graph": Color("2b2f3c"), "slate": Color("3d4456"),
		"": Color("8c2924")}
#  더미 — [꼴, x, 앞뒤 z, 돌림(도), 기울기(도), 플라스틱 빛깔, 장면]. 밑에서 위로 — 같은 깊이 띠(z 가 DEPTH_BAND
#  안)에서 그 폭 밑의 가장 높은 윗면에 얹는다. 기울면 낮은 귀가 윗면에 닿게 든다. 주인공(TvHero · 장면 game)과
#  데크 · 제작자 TV(maker)는 앞으로 · 둘레 TV 는 뒤로 물린다. reel 은 영화 TV · reel0 은 처음부터 지지직으로 켜진
#  왼쪽 아래 영화 TV(어둠 속 첫 빛 — REEL.tune 에 채널이 잡혀 영화를 튼다 · 「왜 왼쪽 하단 화면은 안나와?」).
const PILE := [
	["TvConsole", -1.02, -0.10, 5.0, 0.0, "", "bars"],
	["TvConsole", 0.0, -0.10, 0.0, 0.0, "", "sunset"],
	["TvWood", 0.98, -0.10, -6.0, 0.0, "", "snow"],
	["Speaker", 1.50, -0.12, -8.0, 0.0, "", ""],
	["Speaker", -1.55, -0.12, 8.0, 0.0, "", ""],
	["Deck", 0.0, 0.04, 0.0, 0.0, "", ""],
	["TvHero", 0.0, 0.04, 0.0, 0.0, "", "game"],
	["TvMon", -0.84, -0.12, 8.0, -3.0, "graph", "reel0"],
	["TvMon", 0.66, -0.12, -8.0, 2.0, "graph", "reel"],
	["TvPort", -0.69, -0.02, 9.0, 3.0, "red", "maker"],
	["TvPort", 0.73, -0.14, -7.0, -4.0, "teal", "reel"],
	["TvBox", -0.28, -0.16, 6.0, -4.0, "", "reel"],
	["TvMon", 0.24, -0.18, -5.0, 3.0, "slate", "reel"],
	["TvPort", -1.28, -0.16, 9.0, 3.0, "teal", "snow"],
	["TvMon", 1.20, -0.16, -9.0, -4.0, "graph", "bars"],
	["TvBox", -0.79, -0.16, 12.0, -5.0, "", "reel"],
]
#  같은 깊이 띠 — z 차가 이보다 작은 것끼리만 서로 얹힌다
const DEPTH_BAND := 0.3
const HERO_KINDS := ["TvHero", "Deck"]
#  주인공 조작판(ON.hero 에서 잰 초) — power 채널 다이얼이 켜는 딸깍 · ch 그림이 선 뒤 채널 딸깍 · step 딸깍 한 번의
#  각(도) · click 딸깍이 도는 시간 · vol 볼륨 다이얼이 도는 동안 · 각 · slide 슬라이더가 오르는 동안 · 맨 밑까지의
#  거리(m) · led 등 셋(빨강 · 초록 · 파랑)이 드는 때
const KNOB := {"power": -0.12, "ch": 0.45, "step": 30.0, "click": 0.07, "vol": [0.3, 1.1], "vol_a": 70.0,
		"slide": [-0.15, 0.5], "slide_lo": -0.125, "led": [0.0, 0.1, 0.2]}
const HERO_PARTS := ["HeroKnobA", "HeroKnobB", "HeroSlider"]
#  영화 TV — 그림 크기(칸 = 텍셀) · 밝기 · 채도 · sw 채널이 넘어가는 때(초 · 이 사이에서 TV 마다 아무 때나) ·
#  snow 넘어갈 때 지지직 동안 · tune 처음부터 켜진 reel0 이 지지직에서 채널을 잡는 때
const REEL := {"size": Vector2i(64, 48), "dim": 0.15, "sat": 0.75, "sw": [TAPE_LEN + 2.9, TAPE_LEN + 4.6], "snow": 0.14,
		"tune": TAPE_LEN + 1.6}
const REELS := ["hammer", "rail", "dance", "bow", "exit", "stairs", "field", "lamp", "bullet", "hill", "steps",
		"monolith", "bench"]

#  화면 — UV(0,0 왼 위) 를 res 칸으로 끊는다. pw 켜짐(0~1 · 가운데 줄이 위아래로 벌어지고 처음엔 하얗다) ·
#  dim · sat 엑스트라의 밝기 · 채도. 꺼진 유리는 위가 옅은 짙은 회색 · 귀가 어둡고 · 왼 위에 비스듬한 반짝 띠
#  둘 · amb 켜진 TV 몫을 따라 옅어진다(다 꺼진 어둠에서는 유리도 거의 안 보인다). warm 은 켜지기 전에 데워지는
#  관 — 꺼진 유리가 밑에서부터 희미하게 든다(앞 토막 · 테이프가 먹힌 뒤의 주인공 TV).
#  lv 가 있으면(엑스트라) 색을 그 단으로 끊는다 — 바둑 점은 안 얹는다(제목에 없는 결).
#  mode 9(주인공) — tex(게임 화판)를 유리 높이에 꽉 채우고 양옆을 잘라(cw 보이는 폭 몫) 칸 없이 비춘다 ·
#  feed 화판 크기(주사선 줄). mode 4(크레딧) — 빛깔 번짐(빨강만 한 칸 옆에서 — r · b 둘 다 밀면 작은 글이
#  무지개가 됐다) · 옅은 낟알(밝은 쪽만 — 검은 바탕이 회색 모래로 떴다) · 가끔 튀는 줄 · 흐르는 밝은 띠(옛 테이프).
const SCR_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform int mode = 0;
uniform float pw = 0.0;
uniform float tm = 0.0;
uniform float seed = 0.0;
uniform float dim = 1.0;
uniform float sat = 1.0;
uniform float lv = 0.0;
uniform float amb = 1.0;
uniform float warm = 0.0;
uniform vec2 res = vec2(40.0, 30.0);
uniform float cw = 0.6;
uniform float portal = 0.0;
uniform vec2 feed = vec2(640.0, 360.0);
uniform sampler2D tex : source_color, filter_nearest, repeat_disable;

float hs(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed * 17.0) * 43758.5453);
}

vec3 scene(vec2 q) {
	float ar = res.x / res.y;
	if (mode == 1) {
		float n = hs(floor(q * res) + floor(tm * 15.0) * vec2(7.0, 13.0));
		float v = n < 0.45 ? 0.08 : (n < 0.8 ? 0.42 : 0.78);
		return vec3(v, v, v * 1.06) * (0.72 + 0.28 * step(0.18, fract(q.y - tm * 0.45)));
	}
	if (mode == 2) {
		vec3 C[7] = vec3[](vec3(0.75), vec3(0.75, 0.75, 0.0), vec3(0.0, 0.75, 0.75), vec3(0.0, 0.75, 0.0),
				vec3(0.75, 0.0, 0.75), vec3(0.75, 0.0, 0.0), vec3(0.0, 0.0, 0.75));
		if (q.y > 0.74) {
			return q.x < 0.3 ? vec3(0.02, 0.12, 0.35) : (q.x < 0.55 ? vec3(0.95) : vec3(0.03));
		}
		return C[int(clamp(q.x * 7.0, 0.0, 6.0))];
	}
	if (mode == 3) {
		vec3 c = vec3(0.08, 0.18, 0.72);
		if (abs(q.y - 0.5) < 0.09 && abs(q.x - 0.5) < 0.3 && fract(tm * 0.9) < 0.6) {
			c = vec3(0.92);
		}
		return c;
	}
	if (mode == 4) {
		float row = floor(q.y * res.y);
		float tk = floor(tm * 12.0);
		vec2 j = vec2(0.0);
		if (hs(vec2(row, tk)) > 0.965) {
			j.x = (hs(vec2(row + 3.0, tk)) - 0.5) * 0.05;
		}
		float ca = 1.0 / res.x;
		vec3 c = texture(tex, q + j).rgb;
		c.r = texture(tex, q + j + vec2(ca, 0.0)).r;
		c += vec3(max(hs(q * res + tk) - 0.6, 0.0) * 0.06);
		c += vec3(0.03, 0.027, 0.024) * (1.0 - smoothstep(0.0, 0.06, abs(fract(q.y - tm * 0.18) - 0.5)));
		return c;
	}
	if (mode == 5) {
		vec3 c = vec3(0.02, 0.09, 0.05);
		if (fract(q.x * 6.0) < 1.0 / res.x * 6.0 || fract(q.y * 4.0) < 1.0 / res.y * 4.0) {
			c = vec3(0.04, 0.22, 0.10);
		}
		float y = 0.5 + 0.3 * sin(q.x * 11.0 + tm * 5.0) * cos(q.x * 3.0 - tm * 1.3);
		if (abs(q.y - y) < 1.2 / res.y) {
			c = vec3(0.50, 1.0, 0.58);
		}
		return c;
	}
	if (mode == 6) {
		vec2 b = abs(fract(vec2(tm * 0.41, tm * 0.57) + seed) * 2.0 - 1.0);
		b = 0.14 + b * 0.72;
		vec3 c = vec3(0.04, 0.04, 0.07);
		if (abs(q.x - 0.5) < 0.6 / res.x && fract(q.y * 7.0) < 0.5) {
			c = vec3(0.45);
		}
		if (length((q - b) * vec2(ar, 1.0)) < 0.1) {
			c = vec3(0.95, 0.92, 0.75);
		}
		return c;
	}
	if (mode == 7) {
		float hz = 0.62;
		vec3 c = mix(vec3(0.30, 0.10, 0.40), vec3(0.98, 0.52, 0.26), clamp(q.y / hz, 0.0, 1.0));
		vec2 s = (q - vec2(0.5, 0.56)) * vec2(ar, 1.0);
		if (length(s) < 0.24 && q.y < hz && !(q.y > 0.46 && fract(q.y * 16.0) < 0.3)) {
			c = vec3(1.0, 0.86, 0.42);
		}
		if (q.y >= hz) {
			c = vec3(0.14, 0.08, 0.28);
			float w = 0.26 * (1.0 - (q.y - hz) * 1.6);
			if (abs(q.x - 0.5) < w && fract(q.y * 11.0 + tm * 0.6) < 0.35) {
				c = vec3(0.95, 0.58, 0.30);
			}
		}
		return c;
	}
	if (mode == 8) {
		vec2 d = (q - 0.5) * vec2(ar, 1.0);
		float r = length(d) / 0.42;
		float sec = floor((atan(d.y, d.x) + tm * 0.7) / 6.2831853 * 20.0);
		bool alt = mod(sec, 2.0) < 1.0;
		vec3 c = vec3(0.10, 0.06, 0.05);
		if (r < 1.0) {
			c = alt ? vec3(0.07) : vec3(0.92, 0.88, 0.78);
		}
		if ((r < 1.0 && r > 0.88) || (r < 0.6 && r > 0.5)) {
			c = alt ? vec3(0.78, 0.12, 0.12) : vec3(0.10, 0.50, 0.26);
		}
		if (r < 0.12) {
			c = vec3(0.10, 0.50, 0.26);
		}
		if (r < 0.05) {
			c = vec3(0.80, 0.10, 0.10);
		}
		return c;
	}
	return vec3(0.0);
}

void fragment() {
	vec2 cell = floor(UV * res);
	vec2 q = (cell + 0.5) / res;
	vec3 off = mix(vec3(0.05, 0.056, 0.07), vec3(0.016, 0.018, 0.024), smoothstep(0.0, 0.8, UV.y));
	off *= (1.0 - 1.6 * dot(UV - 0.5, UV - 0.5)) * amb;
	off += vec3(0.004, 0.005, 0.007) * warm * smoothstep(0.5, 1.0, UV.y);
	float gd = UV.x * 0.85 + UV.y;
	if ((abs(gd - 0.42) < 0.045 || abs(gd - 0.56) < 0.012) && UV.x < 0.5) {
		off += vec3(0.03, 0.034, 0.042) * amb * 2.5;
	}
	vec3 c = off;
	if (pw > 0.0 && mode > 0) {
		vec3 s;
		if (mode == 9) {
			q = UV;
			vec2 cu = mix(vec2((UV.x - 0.5) * cw + 0.5, UV.y), SCREEN_UV, portal);
			s = texture(tex, cu).rgb * mix(1.08, 1.0, portal);
			if (mod(floor(cu.y * feed.y), 2.0) > 0.5) {
				s *= mix(0.86, 1.0, portal);
			}
		} else {
			s = scene(q);
			if (mod(cell.y, 2.0) > 0.5) {
				s *= 0.78;
			}
		}
		s = mix(s, vec3(0.9, 0.95, 1.0), (1.0 - smoothstep(0.0, 0.35, pw)) * 0.85);
		s *= 1.0 - (mode == 9 ? 0.5 * (1.0 - portal) : 1.2) * dot(UV - 0.5, UV - 0.5);
		s = mix(vec3(dot(s, vec3(0.299, 0.587, 0.114))), s, sat) * dim;
		float open = max(smoothstep(0.0, 0.55, pw), 1.5 / res.y);
		if (abs(q.y - 0.5) * 2.0 < open) {
			c = s;
		}
	}
	if (lv > 0.0) {
		c = floor(c * lv + 0.5) / lv;
	}
	ALBEDO = c;
}
"""
static var _scr_sh: Shader = null

#  몸 — 결 그림을 앞 · 옆 · 위(몸 좌표에서 가장 큰 노멀 축)로 비춘다(Blender 몸은 UV 가 화면 유리에만 있다).
#  나무는 제목 문(Door3D.LIT_SHADER)과 같이 결 대비(grain) · 채도(sat)를 바탕(base) 쪽으로 누른다 —
#  안 누르면 결이 주황 줄로 서서 램프 밑에서 지글거렸다(「긁힌 라미네이트」). 빛은 엔진 빛 그대로(단 없음).
const TRI_SHADER := """
shader_type spatial;
uniform sampler2D alb : source_color, filter_nearest, repeat_enable;
uniform bool use_tex = false;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 base : source_color = vec3(0.5);
uniform float grain = 1.0;
uniform float sat = 1.0;
uniform float den = 450.0;
uniform vec2 tsz = vec2(256.0);
uniform float rough = 0.8;
uniform float spec = 0.3;
uniform float metal = 0.0;
varying vec3 op;
varying vec3 on;

void vertex() {
	op = VERTEX;
	on = NORMAL;
}

void fragment() {
	vec3 c = vec3(1.0);
	if (use_tex) {
		vec3 a = abs(on);
		vec2 uv = (a.z >= a.x && a.z >= a.y) ? op.xy : ((a.x >= a.y) ? op.zy : op.xz);
		c = texture(alb, vec2(uv.x, -uv.y) * den / tsz).rgb;
		vec3 lw = vec3(0.2126, 0.7152, 0.0722);
		float lb = max(dot(base, lw), 0.0001);
		float dd = dot(c, lw) / lb - 1.0;
		float k = mix(grain, 1.0, smoothstep(0.40, 0.60, -dd));
		c = base + (c - base) * k;
		c = mix(vec3(dot(c, lw)), c, sat);
	}
	ALBEDO = c * tint;
	ROUGHNESS = rough;
	SPECULAR = spec;
	METALLIC = metal;
}
"""
static var _tri_sh: Shader = null
static var _wood_im := {}       # 바탕 빛깔 → 결 그림(처음 부를 때 굽는다)


#  제작자 그림 — 옛 방송 끝 자막. 검은 남빛 바탕(위가 조금 옅다) · 「제작」 양옆에 가는 줄 · 크림빛 「김건의」에
#  호박빛 번짐(겹쳐 찍은 옅은 테) · 밑에 가는 줄 하나.
class Card extends Node2D:
	var big: Font
	var sm: Font

	func _draw() -> void:
		var s := Vector2(CARD)
		for y in int(s.y):
			var k: float = float(y) / s.y
			draw_rect(Rect2(0.0, float(y), s.x, 1.0), Color("10121a").lerp(Color("050508"), k))
		var cream := Color("f1e4c4")
		var dim := Color(cream, 0.55)
		draw_rect(Rect2(16.0, 34.0, 24.0, 1.0), dim)
		draw_rect(Rect2(s.x - 40.0, 34.0, 24.0, 1.0), dim)
		_txt(sm, 40.0, "제작", 18, Color(cream, 0.85), 0)
		_txt(big, 80.0, "김건의", 30, cream, 2)
		draw_rect(Rect2(34.0, 90.0, s.x - 68.0, 1.0), Color(cream, 0.35))

	func _txt(f: Font, y: float, s: String, sz: int, col: Color, k: int) -> void:
		if f == null:
			return
		var glow := Color(1.0, 0.62, 0.25, 0.16)
		for dx in range(-k, k + 1):
			for dy in range(-k, k + 1):
				if dx != 0 or dy != 0:
					draw_string(f, Vector2(dx, y + dy), s, HORIZONTAL_ALIGNMENT_CENTER, float(CARD.x), sz, glow)
		draw_string(f, Vector2(0.0, y), s, HORIZONTAL_ALIGNMENT_CENTER, float(CARD.x), sz, col)


#  영화 TV 그림 — 64 × 48 도트. kind 마다 구도 · 상황만 빌린 실루엣(머리말). t 로 조금씩 움직인다.
class Reel extends Node2D:
	var kind := ""
	var t := 0.0

	func _p(pts: Array, c: Color) -> void:
		var pv := PackedVector2Array()
		for q in pts:
			pv.append(Vector2(q[0], q[1]))
		draw_colored_polygon(pv, c)

	func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
		draw_rect(Rect2(x, y, w, h), c)

	func _draw() -> void:
		match kind:
			"hammer":
				_hammer()
			"rail":
				_rail()
			"dance":
				_dance()
			"bow":
				_bow()
			"exit":
				_exit()
			"stairs":
				_stairs()
			"field":
				_field()
			"lamp":
				_lamp()
			"bullet":
				_bullet()
			"hill":
				_hill()
			"steps":
				_steps()
			"monolith":
				_monolith()
			"bench":
				_bench()

	#  빗줄기 — n 가닥이 dx 만큼 비스듬히 떨어진다
	func _rain(n: int, dx: float, c: Color) -> void:
		for i in n:
			var x: float = fmod(float(i) * 13.7 + t * dx * 8.0, 70.0) - 3.0
			var y: float = fmod(float(i) * 7.3 + t * 60.0, 52.0) - 4.0
			draw_line(Vector2(x, y), Vector2(x + dx, y + 4.0), c)

	#  빗속 긴 사선 계단 — 짙은 청록 옹벽 · 흰 난간 · 계단을 내려가는 작은 사람 셋
	func _stairs() -> void:
		_r(0, 0, 64, 48, Color("1b2828"))
		for x in [6, 19, 33, 47, 58]:
			_r(x, 0, 3, 48, Color("172222"))
		_p([[64, 4], [64, 10], [0, 47], [0, 41]], Color("2e3a38"))
		for i in 22:
			var sx: float = 64.0 - float(i) * 3.0
			_r(sx - 2.0, 4.0 + float(i) * 1.73, 2, 1, Color("4a5654"))
		draw_line(Vector2(64, 0), Vector2(0, 37), Color("b4bcbc"))
		for i in 11:
			var px: float = 64.0 - float(i) * 6.0
			draw_line(Vector2(px, px * -0.578 + 37.0), Vector2(px, px * -0.578 + 40.0), Color("8a9494"))
		for k in 3:
			var u: float = fmod(t * 0.06 + float(k) * 0.08, 1.0)
			var x: float = 54.0 - u * 46.0
			var y: float = 47.0 - x * 0.578 - 2.0
			_r(x, y - 5.0, 2, 5, Color("0a0e0e"))
			_r(x, y - 7.0, 2, 2, Color("0a0e0e"))
		_rain(26, -1.5, Color(0.7, 0.8, 0.8, 0.35))

	#  흐린 하늘 · 누런 논 · 콘크리트 배수로 · 그 구멍을 허리 숙여 들여다보는 흰 셔츠
	func _field() -> void:
		_r(0, 0, 64, 13, Color("d8d4c0"))
		_r(0, 12, 64, 36, Color("b8932e"))
		for y in range(13, 48, 3):
			var sw: float = roundf(sin(t * 1.4 + float(y) * 0.4))
			for x in range(0, 64, 2):
				var hi: bool = (x + y) % 4 == 0
				_r(float(x) + sw, float(y), 1, 2, Color("e0c25a") if hi else Color("9c7a22"))
		_r(10, 27, 22, 10, Color("9a978d"))
		_r(10, 27, 22, 1, Color("bdbab0"))
		_r(15, 30, 10, 6, Color("0a0a0a"))
		var k := Color("2a2622")
		_r(38, 30, 2, 9, k)
		_r(41, 30, 2, 9, k)
		_p([[36, 31], [43, 31], [36, 24], [30, 25]], Color("e4e2d6"))
		draw_circle(Vector2(29, 25), 2.6, Color("1e1a16"))
		draw_line(Vector2(33, 26), Vector2(30, 31), Color("e4e2d6"), 2.0)

	#  비 오는 밤거리 · 벽돌 가게 창 · 가로등 · 한 손으로 기둥에 매달려 우산을 내뻗은 사람
	func _lamp() -> void:
		_r(0, 0, 64, 48, Color("0f1626"))
		_r(0, 8, 24, 36, Color("2a1c1c"))
		_r(4, 16, 14, 12, Color("6a5226"))
		_r(4, 16, 14, 1, Color("8a6e36"))
		_r(0, 44, 64, 4, Color("1a2232"))
		_r(37, 6, 2, 40, Color("2c2c34"))
		draw_circle(Vector2(38, 5), 6.0, Color(1.0, 0.9, 0.6, 0.18))
		draw_circle(Vector2(38, 5), 2.6, Color("f5e6b0"))
		_r(35, 44, 6, 2, Color("2c2c34"))
		var k := Color("48506a")
		var hl := Color("8a92b0")
		var lean: float = sin(t * 1.2) * 1.5
		_r(36, 13, 2, 4, k)
		_p([[37, 15], [37, 20], [29 + lean, 33], [26 + lean, 31]], k)
		draw_line(Vector2(36, 15), Vector2(28 + lean, 31), hl, 1.0)
		draw_line(Vector2(27 + lean, 32), Vector2(33, 44), k, 2.0)
		draw_line(Vector2(29 + lean, 32), Vector2(37, 44), k, 2.0)
		draw_circle(Vector2(26 + lean, 26), 2.6, Color("2a2018"))
		_r(22 + lean, 23, 9, 1, Color("2a2a34"))
		_r(24 + lean, 21, 5, 2, Color("2a2a34"))
		draw_line(Vector2(29 + lean, 25), Vector2(14 + lean, 19), Color("1a1a22"), 1.0)
		_r(13 + lean, 18, 2, 2, Color("1a1a22"))
		_rain(30, 0.0, Color(0.7, 0.8, 1.0, 0.35))
		for x in [6, 22, 46]:
			_r(x, 45, 8, 1, Color(1.0, 0.9, 0.6, 0.25))

	#  초록빛 낀 옥상 · 먼 빌딩 · 거의 눕듯 뒤로 젖힌 긴 코트 · 그 위를 지나는 총알과 물결
	func _bullet() -> void:
		for y in 30:
			_r(0, y, 64, 1, Color("9db29d").lerp(Color("c6d2c2"), float(y) / 30.0))
		for b in [[0, 16, 8, 14], [9, 12, 7, 18], [18, 18, 10, 12], [44, 14, 9, 16], [54, 10, 10, 20]]:
			_r(b[0], b[1], b[2], b[3], Color("7f907f"))
		_p([[0, 30], [64, 30], [64, 48], [0, 48]], Color("3a4a3e"))
		for x in [8, 24, 40, 56]:
			draw_line(Vector2(32, 30), Vector2(x * 2 - 32, 48), Color("334236"))
		var k := Color("0b0d0c")
		_r(33, 38, 2, 8, k)
		_r(37, 40, 2, 6, k)
		_p([[32, 39], [37, 40], [22, 30], [18, 28]], k)
		_p([[31, 38], [36, 40], [38, 45], [30, 44]], Color("121614"))
		draw_circle(Vector2(16, 27), 2.4, k)
		draw_line(Vector2(21, 29), Vector2(15, 22), k, 1.5)
		draw_line(Vector2(24, 31), Vector2(30, 24), k, 1.5)
		for i in 3:
			var bx: float = 70.0 - fmod(t * 22.0 + float(i) * 24.0, 80.0)
			var by: float = 20.0 + float(i) * 3.0
			_r(bx, by, 2, 1, Color("d8d0b0"))
			for r in 3:
				draw_arc(Vector2(bx + 4.0 + float(r) * 4.0, by), 1.0 + float(r), -1.2, 1.2, 6,
						Color(0.85, 0.95, 0.85, 0.5 - float(r) * 0.15))

	#  보랏빛 노을 · 반짝이는 도시 불빛 · 언덕 · 가로등 · 춤추는 노란 옷과 흰 셔츠
	func _hill() -> void:
		for y in 30:
			_r(0, y, 64, 1, Color("2a1f5a").lerp(Color("7a5aa8"), float(y) / 30.0))
		_r(0, 29, 64, 8, Color("18183a"))
		for i in 24:
			var lx: float = fmod(float(i) * 11.3, 64.0)
			var ly: float = 30.0 + fmod(float(i) * 3.7, 6.0)
			var a: float = 0.5 + 0.5 * sin(t * 3.0 + float(i))
			_r(roundf(lx), roundf(ly), 1, 1, Color(1.0, 0.95, 0.75, a))
		_p([[0, 36], [20, 34], [44, 35], [64, 33], [64, 48], [0, 48]], Color("17132a"))
		_r(54, 14, 1, 21, Color("2a2440"))
		draw_circle(Vector2(54.5, 13), 4.0, Color(1.0, 0.85, 0.55, 0.2))
		_r(53, 12, 3, 2, Color("f2dc9a"))
		var sw: float = sin(t * 2.0) * 2.0
		_p([[22, 36], [28, 36], [26, 27], [24, 27]], Color("e8c84a"))
		draw_line(Vector2(25, 28), Vector2(19, 21 + sw), Color("e8c84a"), 1.0)
		draw_circle(Vector2(25, 25), 1.8, Color("3a2418"))
		_r(34, 30, 2, 6, Color("202030"))
		_r(36, 30, 2, 6, Color("202030"))
		_p([[33, 31], [38, 31], [38, 25], [33, 25]], Color("eeeeee"))
		draw_line(Vector2(38, 26), Vector2(44, 22 - sw), Color("eeeeee"), 1.0)
		draw_circle(Vector2(35.5, 23), 1.8, Color("2a2018"))

	#  새벽 하늘 · 먼 도시 · 광장 · 돌계단 꼭대기에서 두 팔을 V 로 든 뒷모습(회색 운동복)
	func _steps() -> void:
		for y in 26:
			_r(0, y, 64, 1, Color("b8c4d8").lerp(Color("e8c0a8"), float(y) / 26.0))
		for b in [[2, 16, 6, 10], [9, 19, 8, 7], [40, 14, 5, 12], [46, 18, 8, 8], [56, 15, 6, 11]]:
			_r(b[0], b[1], b[2], b[3], Color("8d97a8"))
		_r(31, 15, 2, 11, Color("8d97a8"))
		_r(0, 26, 64, 8, Color("b9b4ae"))
		for i in 5:
			_r(0, 34 + i * 3, 64, 3, Color("a7a19c") if i % 2 == 0 else Color("8f8a86"))
		var k := Color("6e6e72")
		var hop: float = roundf(absf(sin(t * 3.0)) * -1.5)
		_r(29, 32 + hop, 2, 5, Color("55555a"))
		_r(33, 32 + hop, 2, 5, Color("55555a"))
		_p([[28, 33 + hop], [36, 33 + hop], [35, 25 + hop], [29, 25 + hop]], k)
		draw_line(Vector2(29, 26 + hop), Vector2(23, 17 + hop), k, 2.0)
		draw_line(Vector2(35, 26 + hop), Vector2(41, 17 + hop), k, 2.0)
		draw_circle(Vector2(32, 22 + hop), 2.3, Color("2a2420"))

	#  새벽 사막 하늘 · 바위 · 우뚝 선 검은 석판 · 웅크린 유인원 그림자들
	func _monolith() -> void:
		for y in 32:
			_r(0, y, 64, 1, Color("6f8fb0").lerp(Color("f0c890"), float(y) / 32.0))
		for c in [[10, 8, 14], [44, 11, 18]]:
			_r(c[0], c[1], c[2], 1, Color(1, 1, 1, 0.35))
		_p([[0, 30], [10, 26], [22, 31], [36, 27], [50, 32], [64, 28], [64, 48], [0, 48]], Color("5a4030"))
		_p([[0, 38], [16, 34], [30, 39], [48, 35], [64, 40], [64, 48], [0, 48]], Color("3d2b20"))
		_r(16, 6, 7, 30, Color("08080a"))
		_r(16, 6, 1, 30, Color("3a3a40"))
		var k := Color("1a120c")
		for a in [[34, 36, 3.5], [44, 38, 3.0], [9, 40, 3.0]]:
			var bob: float = roundf(sin(t * 2.0 + float(a[0])) * 0.8)
			draw_circle(Vector2(a[0], float(a[1]) + bob), a[2], k)
			draw_circle(Vector2(float(a[0]) + 2.0, float(a[1]) - 2.5 + bob), a[2] * 0.6, k)
		_p([[52, 48], [52, 34], [58, 30], [64, 32], [64, 48]], Color("0e0a08"))

	#  공원 — 짙은 나무 · 잔디 · 돌바닥 위 나무 벤치 · 오른쪽 끝에 앉은 흰 정장 · 떠다니는 깃털
	func _bench() -> void:
		_r(0, 0, 64, 20, Color("24452a"))
		for c in [[6, 6, 8], [22, 4, 9], [40, 7, 8], [58, 5, 9]]:
			draw_circle(Vector2(c[0], c[1]), c[2], Color("2f5a32"))
		_r(0, 20, 64, 16, Color("5a8a40"))
		_p([[8, 34], [56, 34], [62, 44], [2, 44]], Color("a8a49a"))
		_r(0, 44, 64, 4, Color("4c7a36"))
		var w := Color("8a6a40")
		_r(14, 26, 32, 2, w)
		_r(14, 29, 32, 2, w)
		_r(14, 33, 32, 2, w)
		for x in [15, 44]:
			_r(x, 35, 1, 4, Color("2a2a2a"))
		var suit := Color("e8e4d8")
		_r(38, 33, 5, 2, suit)
		_r(41, 35, 2, 4, suit)
		_p([[37, 33], [42, 33], [41, 26], [38, 26]], suit)
		draw_circle(Vector2(39.5, 24), 2.0, Color("3a2a1c"))
		_r(36, 31, 3, 2, Color("f2f2f2"))
		var fx: float = 20.0 + sin(t * 0.9) * 10.0
		var fy: float = 10.0 + fmod(t * 4.0, 30.0)
		draw_line(Vector2(fx, fy), Vector2(fx + 2.0, fy + 1.0), Color("ffffff"))

	#  초록 낡은 복도 · 끝의 문 · 천장 등 · 복도 한가운데 망치를 치켜든 검은 사람(머리가 헝클어졌다)
	func _hammer() -> void:
		_r(0, 0, 64, 48, Color("10140f"))
		_p([[0, 0], [64, 0], [40, 13], [24, 13]], Color("1b211b"))
		_p([[0, 0], [24, 13], [24, 33], [0, 48]], Color("2c3b2e"))
		_p([[64, 0], [40, 13], [40, 33], [64, 48]], Color("37483a"))
		_p([[0, 48], [24, 33], [40, 33], [64, 48]], Color("181d18"))
		_r(27, 15, 10, 18, Color("7d7a62"))
		_r(29, 17, 6, 16, Color("5b5946"))
		_r(29, 13, 6, 1, Color("d8e0c8"))
		_r(4, 14, 5, 10, Color("26332a"))
		_r(53, 18, 6, 9, Color("2f3f33"))
		var k := Color("0b0b0d")
		var by: float = roundf(sin(t * 2.2))
		_p([[30, 27], [47, 27], [50, 48], [27, 48]], k)
		draw_circle(Vector2(39, 22), 5.5, k)
		_p([[33, 21], [30, 16], [35, 18]], k)
		_p([[44, 20], [48, 15], [45, 21]], k)
		_p([[37, 17], [38, 12], [41, 17]], k)
		_p([[29, 30], [34, 27], [25, 13 + by], [21, 15 + by]], k)
		_r(20, 11 + by, 5, 4, k)
		_r(21, 4 + by, 2, 7, Color("d8b02a"))
		_r(15, 2 + by, 11, 3, Color("7c8086"))
		_r(15, 2 + by, 11, 1, Color("b8bcc2"))

	#  흐린 하늘 · 초록 산 · 강 · 소실점으로 모이는 철교 · 멀리서 오는 기차 불빛 · 팔을 크게 벌린 회색 양복
	func _rail() -> void:
		for y in 18:
			_r(0, y, 64, 1, Color("cdd5c3").lerp(Color("a7b8a5"), float(y) / 18.0))
		_p([[0, 16], [8, 11], [18, 14], [28, 9], [40, 13], [52, 8], [64, 12], [64, 26], [0, 26]], Color("4a6b45"))
		_p([[0, 21], [12, 16], [26, 19], [40, 15], [64, 18], [64, 31], [0, 31]], Color("35512f"))
		_r(0, 30, 64, 18, Color("6f8c86"))
		_p([[8, 48], [30, 18], [34, 18], [56, 48]], Color("5d5048"))
		for i in 10:
			var y: float = 19.0 + float(i * i) * 0.32
			var hw: float = 2.0 + (y - 18.0) * 0.8
			_r(32.0 - hw, roundf(y), hw * 2.0, 1, Color("3f352f"))
		draw_line(Vector2(19, 48), Vector2(31, 18), Color("b9b2a3"))
		draw_line(Vector2(45, 48), Vector2(33, 18), Color("b9b2a3"))
		_r(47, 21, 9, 1, Color("4f78b0"))
		_r(50, 25, 11, 1, Color("d2bc52"))
		_r(50, 22, 1, 4, Color("4f78b0"))
		var g: float = 0.5 + 0.5 * sin(t * 3.0)
		draw_circle(Vector2(32, 18), 1.2 + g * 1.3, Color(1.0, 0.95, 0.8, 0.85))
		var suit := Color("6e7280")
		var ay: float = roundf(sin(t * 1.6) * 0.8)
		_p([[28, 26], [36, 26], [37, 40], [27, 40]], suit)
		_r(28, 40, 3, 7, Color("3a3c44"))
		_r(33, 40, 3, 7, Color("3a3c44"))
		_p([[28, 26], [28, 29], [13, 24 + ay], [13, 22 + ay]], suit)
		_p([[36, 26], [36, 29], [51, 24 + ay], [51, 22 + ay]], suit)
		_r(11, 21 + ay, 3, 3, Color("cbb39b"))
		_r(51, 21 + ay, 3, 3, Color("cbb39b"))
		_r(31, 27, 2, 8, Color("e2d79c"))
		draw_circle(Vector2(32, 22), 3.5, Color("2a2420"))

	#  밤거리 연기 · 번진 불빛 · 사람들 머리 · 경찰차 지붕 위에서 팔을 든 빨간 정장
	func _dance() -> void:
		_r(0, 0, 64, 48, Color("0f1a18"))
		for c in [[10, 10, 9], [50, 14, 11], [30, 4, 8]]:
			draw_circle(Vector2(c[0], c[1]), c[2], Color(0.35, 0.48, 0.42, 0.18))
		_r(2, 4, 14, 7, Color("8a7530"))
		_r(48, 2, 12, 5, Color("2f6a46"))
		var lights := [[8, 18, Color("f2c14e")], [20, 9, Color("7ad08a")], [44, 20, Color("f2c14e")],
				[56, 10, Color("e05a4a")], [36, 6, Color("f2c14e")]]
		for i in lights.size():
			var L: Array = lights[i]
			var a: float = 0.55 + 0.45 * sin(t * 2.0 + float(i) * 1.7)
			draw_circle(Vector2(L[0], L[1]), 1.6, Color(L[2], a))
		for i in 12:
			draw_circle(Vector2(float(i) * 6.0 + 2.0, 44.0 + float(i % 2)), 3.2, Color("080a0a"))
		_r(8, 34, 32, 6, Color("cfd3d8"))
		var blink: bool = fmod(t * 3.0, 1.0) < 0.5
		_r(12, 31, 11, 3, Color("d03030") if blink else Color("40181a"))
		_r(23, 31, 11, 3, Color("2848c8") if not blink else Color("141a40"))
		var red := Color("a32a2a")
		var sw: float = sin(t * 2.4) * 2.0
		_p([[21, 34], [24, 34], [25, 23], [22, 23]], Color("7a1f20"))
		_p([[26, 34], [29, 34], [27, 23], [24, 23]], Color("7a1f20"))
		_p([[20, 23], [30, 23], [29, 13], [21, 13]], red)
		draw_line(Vector2(29, 15), Vector2(37 + sw, 5), red, 3.0)
		draw_line(Vector2(21, 15), Vector2(14, 24), red, 3.0)
		draw_circle(Vector2(25, 10), 3.0, Color("2b211a"))

	#  노을 하늘 · 해 · 반짝이는 바다 · 뱃머리 난간 · 서로 안은 두 사람
	func _bow() -> void:
		for y in 28:
			_r(0, y, 64, 1, Color("553a66").lerp(Color("f2a65a"), float(y) / 28.0))
		draw_circle(Vector2(48, 26), 5.0, Color("ffd38a"))
		_r(0, 28, 64, 20, Color("2a2340"))
		for i in 6:
			var gx: float = 44.0 + sin(t * 2.0 + float(i)) * 3.0
			_r(roundf(gx), 30.0 + float(i) * 2.0, 6.0 - float(i) * 0.6, 1, Color(1.0, 0.8, 0.5, 0.55))
		_p([[0, 48], [0, 37], [64, 31], [64, 48]], Color("120d14"))
		draw_line(Vector2(0, 34), Vector2(64, 27), Color("2c2230"))
		for i in 11:
			var x: float = float(i) * 6.0
			draw_line(Vector2(x, 34.0 - x * 0.11), Vector2(x, 37.0 - x * 0.09), Color("2c2230"))
		var k := Color("140c12")
		_p([[24, 35], [31, 35], [31, 19], [24, 19]], k)
		draw_circle(Vector2(27, 15), 3.2, k)
		_p([[28, 35], [35, 35], [34, 21], [29, 21]], Color("1d121a"))
		draw_circle(Vector2(32, 17), 2.8, Color("1d121a"))
		draw_circle(Vector2(34, 15), 1.6, Color("1d121a"))
		_p([[24, 22], [33, 26], [33, 28], [24, 24]], k)

	#  하늘 · 구름을 칠한 벽 · 벽에 난 검은 문 · 흰 계단 · 문 앞에서 허리 숙여 절하는 사람
	func _exit() -> void:
		for y in 48:
			_r(0, y, 64, 1, Color("4c7cc2").lerp(Color("8db6e8"), float(y) / 48.0))
		for c in [[9, 9, 4], [14, 8, 5], [20, 10, 3.5], [48, 16, 4], [53, 15, 5], [58, 17, 3]]:
			draw_circle(Vector2(c[0], c[1]), c[2], Color(1, 1, 1, 0.85))
		_r(39, 8, 9, 28, Color("050508"))
		_r(20, 36, 32, 3, Color("cdd1d8"))
		_r(16, 39, 40, 3, Color("b5b9c0"))
		_r(12, 42, 48, 6, Color("9ea3ab"))
		var k := Color("1c1c22")
		_r(32, 26, 2, 10, k)
		_r(35, 26, 2, 10, k)
		var a: float = 0.9 + 0.45 * (0.5 + 0.5 * sin(t * 1.3))
		var hip := Vector2(34.5, 26.0)
		var d := Vector2(-sin(a), -cos(a))
		var sd := Vector2(-d.y, d.x)
		var top: Vector2 = hip + d * 9.0
		var body := PackedVector2Array([hip - sd * 2.0, hip + sd * 2.0, top + sd * 2.0, top - sd * 2.0])
		draw_colored_polygon(body, k)
		draw_circle(top + d * 2.5, 2.4, k)


static func _hard(path: String) -> Font:
	var f := load(path) as FontFile
	if f == null:
		return null
	var h := f.duplicate() as FontFile
	h.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	h.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return h


static func length() -> float:
	return LEN


#  game — 인트로를 그리는 게임(그 화판 그림이 주인공 유리에 뜬다) · outer — 화판 밖(game.screen_host · box 를
#  가진 boot). 무대 · 층은 outer 밑에 선다 — 화판 안에 두면 화판 그림이 제 그림을 비춘다.
static func make(game: Node, outer: Node) -> Node:
	var hn := Node.new()
	hn.name = "Prologue"
	outer.add_child(hn)
	var sz: Vector2 = game.get_viewport().get_visible_rect().size
	var vp := SubViewport.new()
	vp.name = "Stage"
	vp.size = Vector2i(maxi(int(sz.x), 2), maxi(int(sz.y), 2))
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.gui_disable_input = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	hn.add_child(vp)
	var cv := SubViewport.new()
	cv.name = "Card"
	cv.size = CARD
	cv.disable_3d = true
	cv.gui_disable_input = true
	cv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cv.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var card := Card.new()
	card.big = _hard(FONT_BIG)
	card.sm = _hard(FONT_SM)
	cv.add_child(card)
	hn.add_child(cv)

	var w := Node3D.new()
	vp.add_child(w)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = float(LIT.glow)
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = float(LIT.glow_thr)
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for lvl in 7:
		env.set_glow_level(lvl, 1.0 if lvl < 3 else 0.0)
	we.environment = env
	w.add_child(we)
	var cam := Camera3D.new()
	cam.fov = float(CAM.fov)
	var ca := CameraAttributesPractical.new()
	ca.dof_blur_far_enabled = true
	ca.dof_blur_far_transition = float(FOCUS.dof_tr)
	ca.dof_blur_amount = float(FOCUS.dof_k)
	cam.attributes = ca
	w.add_child(cam)

	var hm := _mats(true)
	var xm := _mats(false)
	var dm := hm.duplicate()
	dm["gun"] = _lit(Color("2c3038"), null, 0.45, 0.45, 0.3)
	#  데크의 제 빛 — VFD 대시 · 재생 세모 · 표시등(앞 토막이 켜고 바꾼다 · _tape_deck) · 연기빛 덮개
	dm["vfd"] = Room3D._glow(TAPE.vfd, float(TAPE.vfd_e))
	dm["vfd_on"] = Room3D._glow(TAPE.vfd, float(TAPE.vfd_e))
	dm["led_deck"] = Room3D._glow(TAPE.led[0], 1.8)
	dm["flap"] = _lit(Color("1c1d22"), null, 0.3, 0.55)
	var deck_mi: MeshInstance3D = null
	var flap := {}
	var tvs := []
	var tops := []      # [x0, x1, 윗면, z] — 얹힌 것들
	var cam_end := {}
	var cam_start := {}
	var feed: Texture2D = game.get_viewport().get_texture()
	#  영화 TV 그림 화판 — 다 · 채널은 켤 때마다 섞은 한 벌에서 떼어 준다 — 첫 채널 n 장 다음 둘째 채널 n 장(영화
	#  TV 가 n 대). 장면이 2n 개 이상이면 어느 때든 두 화면에 같은 장면이 안 뜬다(「같은 화면에 곂친 장면이 있오야
	#  겠어? 안 겹쳐지면 좋겠는데」 — 처음엔 둘째 채널을 아무것으로 뽑아 남의 첫 채널과 겹쳤다).
	var reels := {}
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var deck: Array = REELS.duplicate()
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp
	var dealt := 0
	var n_reel := 0
	for e in PILE:
		if String(e[6]).begins_with("reel"):
			n_reel += 1
	for rk in REELS:
		if not reels.has(rk):
			var rv := SubViewport.new()
			rv.size = REEL.size
			rv.disable_3d = true
			rv.gui_disable_input = true
			rv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			rv.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
			var rn := Reel.new()
			rn.kind = rk
			rv.add_child(rn)
			hn.add_child(rv)
			reels[rk] = rn
	var parts := {}
	var chans := {}            # PILE 차례 → [첫 채널, 둘째 채널, 넘어가는 때]
	for i in PILE.size():
		var e: Array = PILE[i]
		var me: Mesh = _mesh(String(e[0]))
		if me == null:
			continue
		var hero: bool = String(e[0]) in HERO_KINDS
		var bb: AABB = me.get_aabb()
		var x: float = float(e[1])
		var x0: float = x + bb.position.x
		var x1: float = x + bb.end.x
		var y := 0.0
		for tp in tops:
			if absf(float(tp[3]) - float(e[2])) < DEPTH_BAND and minf(x1, float(tp[1])) - maxf(x0, float(tp[0])) > 0.06:
				y = maxf(y, float(tp[2]))
		var lift: float = bb.size.x * 0.5 * absf(sin(deg_to_rad(float(e[4]))))
		tops.append([x0, x1, y + bb.end.y + lift, float(e[2])])
		var mi := MeshInstance3D.new()
		mi.mesh = me
		mi.position = Vector3(x, y + lift, float(e[2]))
		mi.rotation_degrees = Vector3(0.0, float(e[3]), float(e[4]))
		w.add_child(mi)
		var job: String = e[6]
		var ms: Dictionary = (dm if String(e[0]) == "Deck" else hm) if hero else xm
		var gm: ShaderMaterial = null
		var gb := AABB()
		for k in me.get_surface_count():
			var sm: Material = me.surface_get_material(k)
			var key: String = sm.resource_name if sm != null else ""
			if key == "glass":
				gb = _surf_aabb(me, k)
				var rt: Texture2D = null
				if job.begins_with("reel"):
					var c0: String = deck[dealt % deck.size()]
					var c1: String = deck[(n_reel + dealt) % deck.size()]
					dealt += 1
					chans[i] = [c0, c1, rng.randf_range(float(REEL.sw[0]), float(REEL.sw[1]))]
					rt = (reels[c0].get_parent() as SubViewport).get_texture()
				gm = _scr_mat(job, gb, i, cv, hero, feed, sz, rt)
				mi.set_surface_override_material(k, gm)
			elif key == "plastic":
				var pc: Color = PLASTIC.get(String(e[5]), PLASTIC[""])
				mi.set_surface_override_material(k, _lit(pc * float(EXTRA.tone), null, 0.45, 0.5))
			elif ms.has(key):
				mi.set_surface_override_material(k, ms[key])
		if String(e[0]) == "TvHero":
			#  조작판의 도는 몫 — glb 노드 변환이 제 자리 · 처음 각이다
			for pn in HERO_PARTS:
				var pm: Mesh = _mesh(pn)
				if pm == null:
					continue
				var pi := MeshInstance3D.new()
				pi.name = pn
				pi.mesh = pm
				pi.transform = _tv_xf[pn]
				for k in pm.get_surface_count():
					var psm: Material = pm.surface_get_material(k)
					var pkey: String = psm.resource_name if psm != null else ""
					if hm.has(pkey):
						pi.set_surface_override_material(k, hm[pkey])
				mi.add_child(pi)
				parts[pn] = {"n": pi, "xf": pi.transform}
		elif String(e[0]) == "Deck":
			#  카세트 구멍의 덮개 — 윗변 경첩(glb 노드 변환이 제 자리 · 닫힌 각)
			deck_mi = mi
			var fm: Mesh = _mesh("DeckFlap")
			if fm != null:
				var fi := MeshInstance3D.new()
				fi.name = "DeckFlap"
				fi.mesh = fm
				fi.transform = _tv_xf["DeckFlap"]
				for k in fm.get_surface_count():
					var fsm: Material = fm.surface_get_material(k)
					var fkey: String = fsm.resource_name if fsm != null else ""
					if dm.has(fkey):
						fi.set_surface_override_material(k, dm[fkey])
				mi.add_child(fi)
				flap = {"n": fi, "xf": fi.transform}
		if gm == null:
			continue
		var g: Vector3 = mi.transform * gb.get_center()
		var n: Vector3 = mi.transform.basis * Vector3(0.0, 0.0, 1.0)
		if hero:
			#  끝 — 유리 꼭지(가장 나온 가운데)에서 유리 폭이 화면 폭을 꼭 채우는 거리의 dive 몫 — 유리를 지나
			#  테가 화면 밖으로 빠진다(TV 속으로 든다).
			var ar: float = sz.x / maxf(sz.y, 1.0)
			var apex: Vector3 = g + n * gb.size.z * 0.5
			var de: float = gb.size.x * 0.5 / (tan(deg_to_rad(float(CAM.fov)) * 0.5) * ar) * float(HERO.dive)
			cam_end = {"look": apex, "at": apex + n * de}
			cam_start = {"look": g, "at": g + n * float(CAM.dist)}
		else:
			#  빨간 대기등 — 화면 오른쪽 아래 테 밖
			var led := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.014, 0.014, 0.01)
			led.mesh = lm
			led.material_override = Room3D._glow(Color("ff3b2e"), 1.2)
			led.position = Vector3(gb.end.x - 0.02, gb.position.y - 0.012, 0.004)
			mi.add_child(led)
		var ton: float = 0.0 if job == "reel0" else (float(ON.maker) if job == "maker" else
				(float(ON.hero) if hero else float(ON.tvs) + float(T.stag) * float(tvs.size())))
		var rl: OmniLight3D = null
		if hero:
			#  유리 둘레 — 켜진 화면이 제 테 · 검은 판 안쪽을 비춘다(남의 앞면은 아니다)
			rl = OmniLight3D.new()
			rl.light_color = JOB.game[1]
			rl.omni_range = float(HERO.rim_r)
			rl.omni_attenuation = 1.6
			rl.light_energy = 0.0
			rl.position = g + n * (gb.size.z * 0.5 + 0.02)
			w.add_child(rl)
		#  화면 빛 — 유리 바로 앞에서 앞쪽으로만(뒤 · 옆 뒤로는 안 샌다)
		var lt := SpotLight3D.new()
		lt.light_color = JOB[job.trim_suffix("0")][1]
		lt.spot_angle = float(SCR_LIT.ang)
		lt.spot_range = float(SCR_LIT.range)
		lt.spot_attenuation = float(SCR_LIT.att)
		lt.light_energy = 0.0
		w.add_child(lt)
		var at: Vector3 = g + n * (gb.size.z * 0.5 + float(SCR_LIT.at))
		lt.look_at_from_position(at, at + n)
		if job.begins_with("reel"):
			lt.light_color = JOB[String(chans[i][0])][1]
		tvs.append({"m": gm, "l": lt, "r": rl, "on": ton, "job": job, "i": i, "hero": hero, "ch": chans.get(i, []),
				"e": float(HERO.light) if hero else (float(MAKER.light) if job == "maker" else float(EXTRA.light))})
	hn.set_meta("vp", vp)
	hn.set_meta("cam", cam)
	hn.set_meta("tvs", tvs)
	hn.set_meta("end", cam_end)
	hn.set_meta("reels", reels)
	hn.set_meta("parts", parts)
	var leds := []
	for nm in ["led_r", "led_g", "led_b"]:
		var lm := hm[nm] as StandardMaterial3D
		leds.append({"m": lm, "c": lm.albedo_color, "e": lm.emission_energy_multiplier})
	hn.set_meta("leds", leds)
	hn.set_meta("start", cam_start)
	hn.set_meta("focus", cam_start.look if not cam_start.is_empty() else Vector3.ZERO)
	_dust_make(w, hn)
	if not cam_start.is_empty():
		cam.look_at_from_position(cam_start.at, cam_start.look)
	hn.set_meta("flap", flap)
	hn.set_meta("deck_m", dm)
	if deck_mi != null:
		_tape_make(hn, game, deck_mi, hm, tvs)
	_room(w, xm)
	var vg := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	gr.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, float(LIT.vig))])
	vg.gradient = gr
	vg.fill = GradientTexture2D.FILL_RADIAL
	vg.fill_from = Vector2(0.5, 0.5)
	vg.fill_to = Vector2(1.0, 0.5)
	vg.width = 320
	vg.height = 180
	#  층 — 무대 · 비네트 · 어둠 막. 자리는 tick 이 화판(outer.box)에 맞춘다.
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
	for pr in [["Stage", vp.get_texture()], ["Vig", vg], ["Feed", feed]]:
		var tr := TextureRect.new()
		tr.name = String(pr[0])
		tr.texture = pr[1]
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(tr)
	var fade := ColorRect.new()
	fade.name = "Fade"
	fade.color = Color.BLACK
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(fade)
	(root.get_node("Feed") as CanvasItem).modulate.a = 0.0
	hn.set_meta("outer", outer)
	hn.set_meta("root", root)
	tick(hn, 0.0)
	return hn


static var _tv_mesh := {}
static var _tv_xf := {}         # 이름 → glb 노드 변환(움직이는 몫의 제 자리)


static func _mesh(nm: String) -> Mesh:
	if _tv_mesh.is_empty():
		_tv_mesh[""] = null
		var ps: PackedScene = load(TVS_GLB) as PackedScene if ResourceLoader.exists(TVS_GLB) else null
		var sc: Node = ps.instantiate() if ps != null else null
		if sc != null:
			for c in sc.find_children("*", "MeshInstance3D", true, false):
				_tv_mesh[String(c.name)] = (c as MeshInstance3D).mesh
				_tv_xf[String(c.name)] = (c as MeshInstance3D).transform
			sc.free()
	return _tv_mesh.get(nm)


static func _surf_aabb(me: Mesh, k: int) -> AABB:
	var vs: PackedVector3Array = me.surface_get_arrays(k)[Mesh.ARRAY_VERTEX]
	var b := AABB(vs[0], Vector3.ZERO)
	for v in vs:
		b = b.expand(v)
	return b


#  몸 재질 — TRI_SHADER. tex 가 있으면 결 그림(나무 — wood 가 바탕이면 결 · 채도를 누른다) · 없으면 맨 색.
static func _lit(col: Color, tex: Image = null, rough := 0.8, spec := 0.3, metal := 0.0,
		wood := Color(0, 0, 0, 0)) -> ShaderMaterial:
	if _tri_sh == null:
		_tri_sh = Shader.new()
		_tri_sh.code = TRI_SHADER
	var m := ShaderMaterial.new()
	m.shader = _tri_sh
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("spec", spec)
	m.set_shader_parameter("metal", metal)
	if tex != null:
		m.set_shader_parameter("alb", ImageTexture.create_from_image(tex))
		m.set_shader_parameter("use_tex", true)
		m.set_shader_parameter("tsz", Vector2(tex.get_size()))
		m.set_shader_parameter("den", float(MAT.den))
	if wood.a > 0.0:
		m.set_shader_parameter("base", wood)
		m.set_shader_parameter("grain", float(Door3D.LOOK.grain))
		m.set_shader_parameter("sat", float(Door3D.LOOK.sat))
	return m


#  나무 결 그림 — 제목 문 판자(Room3D._plank)를 판 한 장 높이로(이음이 드물다 · 못 없음). 바탕 빛깔마다 한 번.
static func _wood(base: Color) -> Image:
	var key := base.to_html()
	if not _wood_im.has(key):
		_wood_im[key] = Room3D._plank(256, 256, base, 2026101 + _wood_im.size(), 200, 256, false)[0]
	return _wood_im[key]


#  주인공(hero) · 엑스트라 재질 — 엑스트라는 빛깔을 tone 배로 어둡게. 나무는 결 · 니스(반짝은 조금),
#  쇠는 매끈하게.
static func _mats(hero: bool) -> Dictionary:
	var k: float = 1.0 if hero else float(EXTRA.tone)
	var wb: Color = MAT.walnut if hero else MAT.wood
	var wd := _lit(Color(k, k, k), _wood(wb), 0.55, 0.35, 0.0, wb)
	return {
		"wood": wd, "gun": wd,
		"metal": _lit(Color("82878f") * k, null, 0.35, 0.5, 0.5),
		"panel": _lit(Color("24252c") * k, null, 0.6, 0.3),
		"bezel": _lit(Color("060608") * k, null, 0.7, 0.15),
		"knob": _lit(Color("c8cacf") * k, null, 0.25, 0.6, 0.6),
		"grille": _lit(Color("16161b") * k, null, 0.9, 0.1),
		"trim": _lit(Color("9a968c") * k, null, 0.35, 0.5, 0.5),
		"cap": _lit(Color("d4d4cc") * k, null, 0.4, 0.4),
		"lcd": _lit(Color("0c1414"), null, 0.15, 0.6),
		"led_r": Room3D._glow(Color("ff3b2e"), 1.6), "led_g": Room3D._glow(Color("3cff6a"), 1.6),
		"led_b": Room3D._glow(Color("3c7bff"), 1.6),
		"floor": _lit(Color(0.5, 0.5, 0.5), _wood(Color("2a1a10")), 0.7, 0.2, 0.0, Color("2a1a10")),
	}


static func _scr_mat(job: String, gb: AABB, i: int, cv: SubViewport, hero: bool, feed: Texture2D,
		sz: Vector2, reel: Texture2D = null) -> ShaderMaterial:
	if _scr_sh == null:
		_scr_sh = Shader.new()
		_scr_sh.code = SCR_SHADER
	var m := ShaderMaterial.new()
	m.shader = _scr_sh
	m.set_shader_parameter("mode", int(JOB[job.trim_suffix("0")][0]))
	m.set_shader_parameter("seed", float(i) * 0.37)
	if hero:
		m.set_shader_parameter("res", sz)
		m.set_shader_parameter("tex", feed)
		m.set_shader_parameter("feed", sz)
		m.set_shader_parameter("cw", (gb.size.x / gb.size.y) / (sz.x / maxf(sz.y, 1.0)))
	elif job == "maker":
		m.set_shader_parameter("res", Vector2(CARD))
		m.set_shader_parameter("tex", cv.get_texture())
	elif reel != null:
		m.set_shader_parameter("res", Vector2(REEL.size))
		m.set_shader_parameter("tex", reel)
		m.set_shader_parameter("dim", float(REEL.dim))
		m.set_shader_parameter("sat", float(REEL.sat))
	else:
		var k: float = float(EXTRA.cells)
		m.set_shader_parameter("res", Vector2(maxf(roundf(gb.size.x * k), 10.0), maxf(roundf(gb.size.y * k), 8.0)))
		m.set_shader_parameter("dim", float(EXTRA.dim))
		m.set_shader_parameter("sat", float(EXTRA.sat))
		m.set_shader_parameter("lv", float(EXTRA.lv))
	return m


#  방 — 나무 바닥(화면 빛이 앞으로 나가 바닥에 고인다). 뒤 벽은 빛이 안 닿아 두지 않는다.
static func _room(w: Node3D, mats: Dictionary) -> void:
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12.0, 12.0)
	fl.mesh = pm
	fl.material_override = mats.floor
	w.add_child(fl)


#  TV 켜짐 — 깜박(0.08 켜짐 · 0.1 꺼짐) 뒤 0.45 초에 걸쳐 선다.
static func _pw(t: float, ton: float) -> float:
	var u: float = t - ton
	if u < 0.0:
		return 0.0
	if u < 0.08:
		return 0.5
	if u < 0.18:
		return 0.0
	return clampf((u - 0.18) / 0.45, 0.0, 1.0)


static func tick(hn: Node, t: float) -> void:
	hn.set_meta("t", t)
	var lit := 0.0
	var nx := 0
	for tv in hn.get_meta("tvs"):
		var m := tv.m as ShaderMaterial
		m.set_shader_parameter("tm", t)
		var p: float = 1.0 if String(tv.job) == "reel0" else _pw(t, float(tv.on))
		if String(tv.job) == "maker":
			m.set_shader_parameter("mode", 1 if t < float(tv.on) + float(T.snow) else 4)
		elif String(tv.job).begins_with("reel"):
			#  영화 TV — 넘어가는 때 앞뒤로 지지직 · 그 뒤 둘째 채널 · reel0 은 tune 까지 지지직
			var ch: Array = tv.ch
			var cur: String = ch[0] if t < float(ch[2]) else ch[1]
			var snowy: bool = absf(t - float(ch[2])) < float(REEL.snow) * 0.5
			if String(tv.job) == "reel0" and t < float(REEL.tune):
				snowy = true
			m.set_shader_parameter("mode", 1 if snowy else 4)
			var rv := (hn.get_meta("reels") as Dictionary)[cur].get_parent() as SubViewport
			m.set_shader_parameter("tex", rv.get_texture())
			(tv.l as SpotLight3D).light_color = JOB[cur][1]
		if tv.hero:
			_dust(hn, t, minf(p * 1.6, 1.0))
			#  주인공 — 깜박이며 켜지면 곧장 화판 그림(첫 그림이 어둠이라 지지직을 안 거친다)
			(tv.r as OmniLight3D).light_energy = float(HERO.rim) * minf(p * 1.6, 1.0)
		else:
			lit += minf(p * 1.6, 1.0)
			nx += 1
		m.set_shader_parameter("pw", p)
		var fl: float = 0.85 + 0.15 * sin(t * 29.0 + float(tv.i) * 1.7)
		var wk := 0.0
		if tv.hero:
			#  테이프가 먹힌 뒤 데워지는 관 — 켜지기 전부터 유리가 희미하게 들고 그 빛이 앞으로 희미하게 샌다
			var gw: Array = TAPE.glow
			wk = smoothstep(float(gw[0]), float(gw[1]), t)
			m.set_shader_parameter("warm", wk)
			wk *= float(gw[2])
		(tv.l as SpotLight3D).light_energy = float(tv.e) * (minf(p * 1.6, 1.0) + wk) * fl
	_layer(hn, t)
	var reels: Dictionary = hn.get_meta("reels")
	for rn in reels.values():
		(rn as Node2D).set("t", t)
		(rn as CanvasItem).queue_redraw()
	_panel(hn, t)
	_tape_tick(hn, t)
	#  꺼진 유리(주인공 · 아직 안 켜진 엑스트라)는 켜진 TV 몫만큼만 비친다
	for tv in hn.get_meta("tvs"):
		(tv.m as ShaderMaterial).set_shader_parameter("amb", 0.04 + 0.3 * lit / float(maxi(nx, 1)))
	var cam := hn.get_meta("cam") as Camera3D
	var ce: Dictionary = hn.get_meta("end")
	var cs: Dictionary = hn.get_meta("start")
	if not ce.is_empty():
		var u: float = clampf((t - float(T.push0)) / (float(T.push1) - float(T.push0)), 0.0, 1.0)
		var e: float = u * u * (3.0 - 2.0 * u)
		if t < TAPE_LEN and hn.has_meta("deck"):
			_tape_cam(hn, cam, t)
		else:
			cam.fov = float(CAM.fov)
			cam.look_at_from_position((cs.at as Vector3).lerp(ce.at, e), (cs.look as Vector3).lerp(ce.look, e))
			_focus(hn, cam)
		var pr: Array = HERO.portal
		var fr: Array = HERO.flat
		var po: float = smoothstep(float(pr[0]), float(pr[1]), u)
		for tv in hn.get_meta("tvs"):
			if tv.hero:
				(tv.m as ShaderMaterial).set_shader_parameter("portal", po)
		var root := hn.get_meta("root") as Control
		(root.get_node("Vig") as CanvasItem).modulate.a = 1.0 - po
		(root.get_node("Feed") as CanvasItem).modulate.a = smoothstep(float(fr[0]), float(fr[1]), u)


#  층 — 화판(outer.box) 자리에 맞추고 · 빗소리만 나는 어둠(TAPE.black) 뒤 TAPE.fade 에 떠오르고 · handoff 뒤
#  FADE.out 동안 걷힌다.
static func _layer(hn: Node, t: float) -> void:
	var root := hn.get_meta("root") as Control
	var outer: Node = hn.get_meta("outer")
	var box: Control = outer.get("box") as Control if outer != null else null
	if box != null:
		root.position = box.position
		root.size = box.size
	(root.get_node("Fade") as ColorRect).color.a = 1.0 - clampf((t - float(TAPE.black)) / float(TAPE.fade), 0.0, 1.0)
	root.modulate.a = 1.0 - clampf((t - handoff()) / float(FADE.out), 0.0, 1.0)


#  먼지 — 더하기로 얹는 작은 판(늘 카메라를 본다). 알마다 제 씨로 상자 안에 흩어 둔다.
static func _dust_make(w: Node3D, hn: Node) -> void:
	var qm := QuadMesh.new()
	qm.size = Vector2(float(DUST.size), float(DUST.size))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	qm.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = qm
	mm.instance_count = int(DUST.n)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(mi)
	var seeds := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 1018
	for i in int(DUST.n):
		seeds.append(Vector3(rng.randf(), rng.randf(), rng.randf()))
	hn.set_meta("dust", mm)
	hn.set_meta("dust_seed", seeds)


#  먼지 — 상자 안에서 천천히 떠돌고(위로 · 옆으로 흔들) 주인공 유리에 가까울수록 · 주인공이 켜진 만큼 밝다
static func _dust(hn: Node, t: float, hero_p: float) -> void:
	var mm := hn.get_meta("dust") as MultiMesh
	var g: Vector3 = hn.get_meta("focus")
	var bx: Vector3 = DUST.box
	var seeds: Array = hn.get_meta("dust_seed")
	for i in seeds.size():
		var sd: Vector3 = seeds[i]
		var y: float = fmod(sd.y + t * float(DUST.drift) * (0.5 + sd.x), 1.0)
		var pos := g + Vector3((sd.x * 2.0 - 1.0) * bx.x + sin(t * 0.4 + float(i)) * 0.03,
				(y * 2.0 - 1.0) * bx.y, 0.06 + sd.z * bx.z)
		mm.set_instance_transform(i, Transform3D(Basis(), pos))
		var k: float = clampf(1.0 - pos.distance_to(g) / float(DUST.lit_r), 0.0, 1.0)
		mm.set_instance_color(i, Color(1.0, 0.85, 0.65, float(DUST.a) * k * k * hero_p))


#  초점 — 주인공 유리까지의 거리를 따라 옮긴다(다가가는 동안에도 주인공이 또렷하다)
static func _focus(hn: Node, cam: Camera3D) -> void:
	var d: float = cam.global_position.distance_to(hn.get_meta("focus"))
	(cam.attributes as CameraAttributesPractical).dof_blur_far_distance = d + float(FOCUS.dof_at)


#  주인공 조작판 — 채널 다이얼(켜는 딸깍 · 채널 딸깍) · 볼륨 다이얼 · 슬라이더 · 등 셋(KNOB).
static func _panel(hn: Node, t: float) -> void:
	var ps: Dictionary = hn.get_meta("parts")
	var u: float = t - float(ON.hero)
	var ck: float = float(KNOB.click)
	if ps.has("HeroKnobA"):
		var a: float = 0.0
		for c in [KNOB.power, KNOB.ch]:
			a += float(KNOB.step) * clampf((u - float(c)) / ck, 0.0, 1.0)
		_spin(ps.HeroKnobA, a)
	if ps.has("HeroKnobB"):
		var vr: Array = KNOB.vol
		_spin(ps.HeroKnobB, float(KNOB.vol_a) * smoothstep(float(vr[0]), float(vr[1]), u))
	if ps.has("HeroSlider"):
		var sr: Array = KNOB.slide
		var dy: float = float(KNOB.slide_lo) * (1.0 - smoothstep(float(sr[0]), float(sr[1]), u))
		var sp: Dictionary = ps.HeroSlider
		(sp.n as Node3D).transform = (sp.xf as Transform3D).translated_local(Vector3(0.0, dy, 0.0))
	var leds: Array = hn.get_meta("leds")
	for i in leds.size():
		var L: Dictionary = leds[i]
		var on: float = 1.0 if u >= float(KNOB.led[i]) else 0.0
		if u >= float(KNOB.led[i]) and u < float(KNOB.led[i]) + 0.06:
			on = 0.5
		var lm := L.m as StandardMaterial3D
		lm.albedo_color = (L.c as Color).darkened(0.85).lerp(L.c, on)
		lm.emission_energy_multiplier = float(L.e) * on


#  도는 몫을 제 축(앞 — 로컬 z)으로 a 도(시계 방향)
static func _spin(part: Dictionary, a: float) -> void:
	(part.n as Node3D).transform = (part.xf as Transform3D) * Transform3D(Basis(Vector3(0, 0, 1), -deg_to_rad(a)),
			Vector3.ZERO)


# ══ 앞 토막 — 비디오테이프를 넣는 손 ═══════════════════════════════
#  데크(데크 좌표) 밑에 VFD 빛 · 카세트 · 상인의 손(손 단위 공간 Arm — TAPE.s 배) · 구석 TV 빛 한 줄기를 세운다.
#  손은 game.gd 의 상점 손 그대로다 — _hand3_build(같은 Blender 조각 · 빛 사다리 · 거울 손 = 상인의 왼손 · 약지
#  금반지) · _fore3_build(맨 팔뚝 · 걷은 단 · 셔츠 소매). 같은 손이어야 같은 사람으로 읽힌다(얼굴은 안 나온다).
static func _tape_make(hn: Node, game: Node, deck: MeshInstance3D, hm: Dictionary, tvs: Array) -> void:
	hn.set_meta("deck", deck)
	#  VFD 창 빛 — 데크가 내는 빛(청록). 구멍 앞의 손가락 · 카세트 등에 밑빛으로 맺힌다.
	var vl: Array = TAPE.vfd_l
	var vo := OmniLight3D.new()
	vo.light_color = TAPE.vfd
	vo.omni_range = float(vl[1])
	vo.omni_attenuation = 1.5
	vo.light_specular = 0.0          # 창 빛은 번지는 빛이다 — 앞판 니스에 둥근 반짝 점을 찍지 않게
	vo.light_energy = 0.0
	vo.position = vl[2]
	deck.add_child(vo)
	hn.set_meta("vfd_l", vo)
	#  구석 TV 빛 한 줄기 — 지지직 화면에서 구멍 둘레로만(좁은 원뿔 — 촬영의 깃발). 눈이 오르는 동안 걷힌다.
	var src := Vector3.ZERO
	for tv in tvs:
		if String(tv.job) == "reel0":
			src = (tv.l as SpotLight3D).position
	var kk: Array = TAPE.key
	var key := SpotLight3D.new()
	key.light_color = JOB.snow[1]
	key.spot_angle = float(kk[1])
	key.spot_range = float(kk[2])
	key.spot_attenuation = 0.5
	key.light_energy = 0.0
	(deck.get_parent() as Node3D).add_child(key)
	key.look_at_from_position(src, deck.transform * (TAPE.slot as Vector3))
	hn.set_meta("key", key)
	var tm: Mesh = _mesh("Tape")
	if tm == null or game == null or not game.has_method("_hand3_build"):
		return
	var tp := MeshInstance3D.new()
	tp.name = "Tape"
	tp.mesh = tm
	#  연기빛 창 — 너머의 흰 허브 · 감긴 갈색 테이프가 비친다
	var win := StandardMaterial3D.new()
	win.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	win.albedo_color = Color(Color("2a2a2e"), 0.35)
	win.roughness = 0.1
	win.metallic_specular = 0.8
	var cm := {"shell": _lit(Color("19191b"), null, 0.35, 0.5), "hub": _lit(Color("d8d4cc"), null, 0.5, 0.3),
			"pack": _lit(Color("3a2618"), null, 0.25, 0.6), "label": _lit(Color("e6dcc4"), null, 0.9, 0.15),
			"ink": _lit(Color("2b2f5a"), null, 0.6, 0.2), "bezel": hm.bezel, "win": win}
	for k in tm.get_surface_count():
		var sm: Material = tm.surface_get_material(k)
		var sk: String = sm.resource_name if sm != null else ""
		if cm.has(sk):
			tp.set_surface_override_material(k, cm[sk])
	deck.add_child(tp)
	var arm := Node3D.new()
	arm.name = "Arm"
	arm.scale = Vector3.ONE * float(TAPE.s)
	deck.add_child(arm)
	var mats: Dictionary = game._hand3_mats()
	var hj: Dictionary = game._hand3_build(mats, true, true)
	arm.add_child(hj.root)
	var fm := {"skin": mats.skin, "cloth": game._hand3_toon(game.FORE3.cloth),
			"brass": game._hand3_toon(game.FORE3.brass, Color(0.0, 0.0, 0.0, 0.0), 0.4, 0.09, 1.0, 0.5)}
	var fo: Dictionary = game._fore3_build(fm, float(game.FORE3.bare_r), -1.0)
	arm.add_child(fo.root)
	hn.set_meta("tape", {"n": tp, "arm": arm, "hj": hj, "fo": fo, "game": game})


#  카세트 자리(데크 좌표 · 한가운데) — 들어온다(호를 그리며 기울기가 풀린다) → 구멍 앞 한 박(살짝 뺐다가 댄다) →
#  민다 → 기계가 끌어들인다(빨리 받아 천천히 앉힌다) → 철컥 앞에 내려앉는다.
static func _tape_at(t: float) -> Transform3D:
	var sl: Vector3 = TAPE.slot
	var hd: float = (TAPE.tape as Vector3).z * 0.5
	var near := Vector3(sl.x, sl.y, hd + float(TAPE.near))
	var al: Array = TAPE.align
	var pu: Array = TAPE.push
	var pl: Array = TAPE.pull
	if t < float(al[0]):
		var en: Array = TAPE.enter
		var u: float = clampf((t - float(en[0])) / (float(en[1]) - float(en[0])), 0.0, 1.0)
		var e: float = 1.0 - pow(1.0 - u, 3.0)
		var tl: Array = TAPE.tilt
		var p: Vector3 = (TAPE.from as Vector3).lerp(near, e) + Vector3(0.0, 0.02 * sin(PI * e), 0.0)
		return Transform3D(Basis(Vector3.UP, deg_to_rad(float(tl[0]) * (1.0 - e)))
				* Basis(Vector3.BACK, deg_to_rad(float(tl[1]) * (1.0 - e))), p)
	var fe := 0.0      # 앞변 z
	if t < float(pu[0]):
		var u: float = clampf((t - float(al[0])) / (float(al[1]) - float(al[0])), 0.0, 1.0)
		fe = lerpf(float(TAPE.near), 0.0, smoothstep(0.45, 1.0, u)) + float(TAPE.back) * sin(PI * minf(u / 0.6, 1.0))
	elif t < float(pl[0]):
		fe = -float(TAPE.deep) * smoothstep(float(pu[0]), float(pu[1]), t)
	else:
		var u: float = clampf((t - float(pl[0])) / (float(pl[1]) - float(pl[0])), 0.0, 1.0)
		fe = lerpf(-float(TAPE.deep), float(TAPE.home) - hd * 2.0, 1.0 - pow(1.0 - u, 2.5))
	var y: float = sl.y
	var ck: float = TAPE.clunk
	if t > ck - 0.05:
		var d: float = clampf((t - (ck - 0.05)) / 0.05, 0.0, 1.0)
		y -= float(TAPE.drop) * d * d
	return Transform3D(Basis(), Vector3(sl.x, y, fe + hd))


#  손 자리 — 카세트 좌표의 손 원점(손목) 변환(m). 손 좌표(손끝 +x · 손등 +y · 엄지 쪽 +z — 거울 손)를 카세트의
#  왼쪽(−x — 오른쪽에서 들어온 손가락이 등을 따라 눕는다) · 카메라 쪽(+z — 손등) · 위(+y — 엄지가 윗면)로 세우고
#  grip 의 각으로 튼 뒤, 검지 너클이 knuckle 에 앉게 원점을 민다.
static func _tape_grip(game: Node) -> Transform3D:
	var gp: Dictionary = TAPE.grip
	var b := Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 1.0, 0.0))
	b = Basis(Vector3.UP, deg_to_rad(float(gp.yaw))) * Basis(Vector3.BACK, deg_to_rad(float(gp.roll))) \
			* Basis(Vector3.RIGHT, deg_to_rad(float(gp.pitch))) * b
	var F: Dictionary = game.FING3
	var kn := Vector3(float(F.fx[0]), float(F.fy), -float(F.fz[0]))     # 거울 손 — 너클 z 를 뒤집는다
	return Transform3D(b, (gp.knuckle as Vector3) - b * kn * float(TAPE.s))


#  손가락 — 집은 손(grip) → 놓은 손(let)을 k 로. 엄지가 먼저 뜨고(앞 6 할) 검지는 한 박 늦게 빠진다(vhs-18).
static func _tape_pose(game: Node, hj: Dictionary, k: float) -> void:
	var a: Array = TAPE_POSE.grip
	var b: Array = TAPE_POSE.let
	var p := PackedFloat32Array()
	p.resize(12)
	for i in 12:
		var ki: float = k
		if i >= 9:
			ki = minf(k / 0.6, 1.0)
		elif i == 0 or i == 4:
			ki = clampf((k - 0.25) / 0.75, 0.0, 1.0)
		p[i] = lerpf(float(a[i]), float(b[i]), ki)
	var sg: float = hj.sg
	var fan: Array = game.FING3.fan
	for f in 4:
		(hj.j1[f] as Node3D).basis = Basis(Vector3.UP, deg_to_rad(p[8] * float(fan[f])) * sg) \
				* Basis(Vector3.BACK, -deg_to_rad(p[f]))
		(hj.j2[f] as Node3D).basis = Basis(Vector3.BACK, -deg_to_rad(p[4 + f]))
	game._thumb3_pose(sg, p, 0)
	game._thumb3_set(hj, game.thumb_mr, Transform3D(game.thumb_pr, Vector3(float(game.THUMB3.lm), 0.0, 0.0)),
			Basis(Vector3.BACK, -deg_to_rad(float(game.thumb_cr))), sg, clampf(p[9], 0.0, 1.0))


#  덮개 각(도 · + 안쪽) — 앞변이 덮개 앞면을 지나면 flap_d 에 걸쳐 다 젖혀지고(윗면에 얹혀 미끄러진다), 등이 지나간
#  뒤 snap 에 비틀림 스프링으로 닫혀 철컥 소리 앞의 딱(clunk − lead)에 닿고, over 만큼 넘쳤다 돌아온다.
static func _flap_deg(t: float) -> float:
	var shut: float = float(TAPE.clunk) - float(TAPE.lead)
	var c0: float = shut - float(TAPE.snap)
	var hd: float = (TAPE.tape as Vector3).z * 0.5
	var fe: float = _tape_at(minf(t, c0)).origin.z - hd
	var open: float = float(TAPE.flap) * smoothstep(0.0, float(TAPE.flap_d), float(TAPE.hinge) - 0.0015 - fe)
	if t < c0:
		return open
	if t < shut:
		var q: float = (t - c0) / float(TAPE.snap)
		return open * (1.0 - q * q)
	return -float(TAPE.over) * sin(PI * clampf((t - shut) / 0.1, 0.0, 1.0))


#  데크의 제 빛 — 표시등(철컥 전 빨강 대기 · 두 틀 꺼졌다 초록) · VFD(철컥 전엔 대시가 1Hz 로 깜박 · 뒤엔 켜진 채 ·
#  재생 세모가 든다) · 창 빛 · 덮개. TV 방에서도 그 상태로 남는다.
static func _tape_deck(hn: Node, t: float) -> void:
	var dm: Dictionary = hn.get_meta("deck_m")
	var ck: float = TAPE.clunk
	var lc: Array = TAPE.led
	var c: Color = lc[0] if t < ck else lc[1]
	var on: float = 0.0 if (t >= ck and t < ck + float(TAPE.led_gap)) else 1.0
	var led := dm.led_deck as StandardMaterial3D
	led.albedo_color = c.darkened(0.85).lerp(c, on)
	led.emission = c
	led.emission_energy_multiplier = 1.8 * on
	var dk: float = float(TAPE.vfd_dim) if (t < ck and fmod(t * float(TAPE.vfd_hz), 1.0) >= 0.5) else 1.0
	_vfd(dm.vfd, dk)
	_vfd(dm.vfd_on, 1.0 if t >= ck + float(TAPE.play) else float(TAPE.vfd_dim))
	if hn.has_meta("vfd_l"):
		(hn.get_meta("vfd_l") as OmniLight3D).light_energy = float(TAPE.vfd_l[0]) * (0.55 + 0.45 * dk)
	var fl: Dictionary = hn.get_meta("flap")
	if not fl.is_empty():
		(fl.n as Node3D).transform = (fl.xf as Transform3D) * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(_flap_deg(t))),
				Vector3.ZERO)


static func _vfd(m: StandardMaterial3D, k: float) -> void:
	m.albedo_color = (TAPE.vfd as Color) * k
	m.emission_energy_multiplier = float(TAPE.vfd_e) * k


#  앞 토막 한 틀 — 데크 빛 · 덮개는 늘 · 카세트 · 손 · 빛 한 줄기는 있는 동안만. 다 쓰면 걷는다 — 손 · 카세트는 눈이
#  오르기 전에(넓어지는 그림에 빠진 손이 다시 들어온다) · 빛 한 줄기는 다 오른 뒤에.
static func _tape_tick(hn: Node, t: float) -> void:
	if not hn.has_meta("deck"):
		return
	_tape_deck(hn, t)
	var cr: Array = TAPE.crane
	if hn.has_meta("key"):
		var key := hn.get_meta("key") as SpotLight3D
		if t >= TAPE_LEN:
			key.queue_free()
			hn.remove_meta("key")
		else:
			key.light_energy = float(TAPE.key[0]) * (0.85 + 0.15 * sin(t * 29.0)) \
					* (1.0 - smoothstep(float(cr[0]), float(cr[1]), t))
	if not hn.has_meta("tape"):
		return
	var tp: Dictionary = hn.get_meta("tape")
	if t >= float(cr[0]):
		(tp.n as Node).queue_free()
		(tp.arm as Node).queue_free()
		hn.remove_meta("tape")
		return
	(tp.n as Node3D).transform = _tape_at(t)
	var g: Node = tp.game
	var hj: Dictionary = tp.hj
	var lt: Array = TAPE.let
	var lv: Array = TAPE.leave
	#  손은 놓을 때까지 카세트를 따른다(끌려드는 한 박 포함) · 그 뒤 손목부터 오른쪽 · 앞으로 빠진다(가속)
	var hx: Transform3D = _tape_at(minf(t, float(lt[0]))) * _tape_grip(g)
	var ku: float = clampf((t - float(lv[0])) / (float(lv[1]) - float(lv[0])), 0.0, 1.0)
	hx.origin += (TAPE.out as Vector3) * ku * ku + (TAPE.lift as Vector3) * smoothstep(float(lt[0]), float(lt[1]), t)
	hx.basis = Basis(Vector3.UP, deg_to_rad(-25.0) * ku * ku) * hx.basis
	var s: float = TAPE.s
	(hj.root as Node3D).transform = Transform3D(hx.basis, hx.origin / s)
	#  팔뚝 — 손목에서 손등 축 뒤로 fore 만큼(팔꿈치는 화면 밖). 너비 축은 손 폭(엄지 쪽)을 따른다.
	var wr: Vector3 = hx.origin / s + hx.basis.y * 0.5
	var el: Vector3 = wr - hx.basis.x * float(TAPE.fore)
	var ax: Vector3 = el - (wr - el).normalized() * float(g.HAND3.back)
	(tp.fo.root as Node3D).transform = g._aim3(ax, wr, 1.0, 0.0, hx.basis.y)
	g._fore3_fit(tp.fo, (wr - ax).length(), 1.0)
	_tape_pose(g, hj, smoothstep(float(lt[0]), float(lt[1]), t))


#  앞 토막의 눈 — 데크 앞 낮고 가까이(TAPE.cam · fov · focus) → crane 동안 TV 더미 첫 그림(cam_start)으로 오른다.
#  자리 · 보는 데 · 화각 · 초점을 같은 몫(smootherstep)으로 옮긴다 — 끊지 않는다.
static func _tape_cam(hn: Node, cam: Camera3D, t: float) -> void:
	var dk := hn.get_meta("deck") as Node3D
	var cs: Dictionary = hn.get_meta("start")
	var cr: Array = TAPE.crane
	var u: float = clampf((t - float(cr[0])) / (float(cr[1]) - float(cr[0])), 0.0, 1.0)
	var e: float = u * u * u * (u * (u * 6.0 - 15.0) + 10.0)
	cam.fov = lerpf(float(TAPE.fov), float(CAM.fov), e)
	cam.look_at_from_position((dk.transform * (TAPE.cam as Vector3)).lerp(cs.at, e),
			(dk.transform * (TAPE.look as Vector3)).lerp(cs.look, e))
	var fp: Vector3 = (dk.transform * (TAPE.focus as Vector3)).lerp(hn.get_meta("focus"), e)
	(cam.attributes as CameraAttributesPractical).dof_blur_far_distance = cam.global_position.distance_to(fp) \
			+ float(FOCUS.dof_at)


#  소리 때 전부(이름 → 초) — TV 가 켜지는 때(ON) · 창밖 비(rain — 제 자리에서 돈다) · 앞 토막의 넷(이름이 곧
#  sfx 이름 — 달그락은 들어올 때 · 톡과 미끄러짐은 덮개에 닿을 때 · 위잉은 기계가 받을 때 · 딱 · 철컥은 덮개가
#  닫히는 때 — 철컥은 그 28ms 뒤 TAPE.clunk 에 선다). game.gd _plg_tick 이 한 번씩 낸다.
static var _cues := {}


static func cues() -> Dictionary:
	if _cues.is_empty():
		_cues = ON.duplicate()
		_cues["rain"] = 0.0
		_cues["tape_rattle"] = float(TAPE.enter[0]) + 0.08
		_cues["tape_in"] = float(TAPE.push[0]) + 0.03
		_cues["deck_whir"] = float(TAPE.pull[0])
		_cues["deck_clunk"] = float(TAPE.clunk) - float(TAPE.lead)
	return _cues


#  층이 걷히기 시작하는 때 — 게임 필터가 이때 켜진다(game.gd _plg_cover).
static func handoff() -> float:
	return LEN - float(FADE.out)


#  주인공이 화판 그림을 틀기 시작하는 때 — 게임의 인트로 시계가 이때 출발한다.
static func feed_at() -> float:
	return float(ON.hero)
