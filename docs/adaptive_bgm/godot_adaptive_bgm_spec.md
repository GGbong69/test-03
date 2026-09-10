# Godot 4 적응형 BGM 구현 명세

명세 버전: 1.0.0 · 대상: Claude Code · 언어: GDScript · 검토 기준일: 2026-09-10

> 이 파일과 `godot_adaptive_bgm_spec.json`을 함께 Claude Code에 전달한다. 아래 요구사항대로 기존 프로젝트에 구현하고, 실제 수행한 검증과 미검증 항목을 구분해 보고하도록 한다.

## 1. 목표와 적용 범위

동일 곡의 Main/Shop/Aim/Final 편곡을 같은 타임라인에서 계속 재생하고 게임 상태에 따라 각 편곡의 게인만 크로스페이드한다.

Markdown과 JSON은 동일 명세의 두 표현이다. JSON은 구현 입력용 데이터이며 JSON Schema 또는 즉시 실행 가능한 Godot 설정 파일이 아니다.

권장 최소 버전은 **Godot 4.3**이다. `AudioStreamSynchronized` 안에 네 편곡을 넣고 단일 `AudioStreamPlayer`로 시작한다. 공식 문서가 보장하는 공통 시작을 사용하며, 각 하위 볼륨을 바꿔 전환한다. [S1](https://docs.godotengine.org/en/4.3/classes/class_audiostreamsynchronized.html)

기존 프로젝트의 정확한 4.x 버전을 먼저 확인하고 README와 테스트 결과에 기록한다.

4.0~4.2는 기본 구현 대상 밖이다. 프로젝트 버전을 임의 변경하지 말고 호환 대안과 한계를 보고한다.

**4.0~4.2 호환 대안:** MusicManager 아래 AudioStreamPlayer 4개를 배치하고 모두 로드한 뒤 같은 프레임에 한 번씩 play(0.0)한다. 같은 프레임 호출만으로 샘플 단위 동시 시작이 보장되지는 않는다. 별도 청취 및 녹음 검증 후에만 근사 동기화로 채택한다. AudioStreamSynchronized가 없는 버전에서 해당 타입을 참조하는 스크립트를 그대로 로드하지 않는다.

편곡마다 완성된 전체 믹스를 사용한다. 독립 악기를 더하는 stem 믹싱은 별도 확장이다.

**필수 범위:** MusicManager Autoload, 4개 편곡 동기화 재생, 즉시 시작하는 크로스페이드, 전환 도중 재전환, 엔진 스트림 루프, Music 버스 사용자 볼륨/음소거, 명시적 음악 일시정지/재개, 씬 변경 시 재생 유지, 입력/에셋 검증, 테스트용 장면과 결과 기록

**범위 밖:** 발라트로 내부 소스의 재현 또는 구현 방식 단정, 실제 게임 음악 제작/배포, 박자·마디 경계 예약 전환, FMOD/Wwise 통합, 서로 다른 곡 사이의 전환, 추가 악기 stem 레이어링, 게임 속도에 따른 음악 피치 변경, 브라우저 자동재생 정책 우회

## 2. MusicManager와 AudioStreamPlayer 구성

```text
MusicManager (Node, Autoload, process_mode=PROCESS_MODE_ALWAYS)
└── Player (AudioStreamPlayer, process_mode=PROCESS_MODE_INHERIT)
    └── stream: AudioStreamSynchronized (실행 시 생성, stream_count=4)
        ├── index 0: Main
        ├── index 1: Shop
        ├── index 2: Aim
        └── index 3: Final
```

Autoload: `MusicManager` → `res://audio/music/music_manager.tscn`

스크립트: `res://audio/music/music_manager.gd`

- **`name`:** Player
- **`type`:** AudioStreamPlayer
- **`autoplay`:** false
- **`bus`:** Music
- **`volume_db`:** -6.0
- **`pitch_scale`:** 1.0
- **`max_polyphony`:** 1
- **`stream_paused`:** false
- **`stream_assignment`:** 검증 및 하위 볼륨 초기화가 끝난 AudioStreamSynchronized를 시작 전에 한 번 할당한다.
- **`polyphony_note`:** max_polyphony=1은 전체 동기화 묶음 한 개를 의미하며, 하위 편곡 네 개를 제한하지 않는다.
- **`backend_note`:** 대상 버전/플랫폼에 playback_type 설정이 있으면 동기화 리소스를 지원하는 Stream 경로를 사용한다. 실험적 Sample 경로를 무조건 강제하지 말고 내보낸 빌드에서 확인한다.

- **`route`:** Player → Music → Master
- **`music_default_db`:** 0.0
- **`music_default_muted`:** false
- **`ownership`:** MusicManager 또는 기존 오디오 설정 서비스 중 한 곳만 Music 버스를 제어한다. SFX 버스는 건드리지 않는다.

AudioStreamSynchronized.new()로 관리자 전용 리소스를 만든다. 하위 에셋의 루프 설정을 런타임에 변경한다면 복제 후 변경하여 다른 사용처와 공유된 리소스를 오염시키지 않는다.

### 초기화 순서

1. 프로젝트 버전, 기존 Autoload, 오디오 설정 서비스와 Music 버스를 확인한다.
2. 구성 파일 및 네 스트림을 시작 전에 로드하고 전체 검증한다.
3. 동기화 리소스를 생성하고 stream_count=4를 지정한 다음 고정 인덱스에 스트림을 설정한다.
4. Main 또는 start(initial_state)의 대상에 0 dB, 나머지에 -80 dB를 적용한다.
5. Player의 버스/헤드룸/피치 설정을 적용하고 stream을 할당한다.
6. 준비 완료 후 부트스트랩에서 start()를 한 번 호출한다. Player.play(0.0)는 start 내부에서만 호출한다.

- 실행 중 묶음은 하나뿐이다.
- 상태 전환은 play/stop/seek/stream 교체를 호출하지 않는다.
- 들리지 않는 변형도 재생 및 디코딩을 계속한다.
- 상태 전환 중 타임라인을 새로 계산하거나 되감지 않는다.
- 씬마다 MusicManager를 새로 인스턴스화하지 않는다.

`AudioStreamPlayer`의 버스·피치·일시정지와 stream 교체 동작은 [공식 API](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html)를 따른다. 실행 중 하위 게인 반영은 [Godot 4.3 구현](https://github.com/godotengine/godot/blob/4.3-stable/modules/interactive_music/audio_stream_synchronized.cpp)에서도 확인할 수 있다.

## 3. 상태 매핑과 게임 연결

| 상태 | 인덱스 | 예시 상황 | 목표 게인 [Main, Shop, Aim, Final] |
|---|---:|---|---|
| Main | 0 | 메뉴, 라운드 선택, 일반 플레이, 발사 후 기본 상태 | `[1.0, 0.0, 0.0, 0.0]` |
| Shop | 1 | 상점 화면이 활성 상태 | `[0.0, 1.0, 0.0, 0.0]` |
| Aim | 2 | 일반 라운드에서 조준 중 | `[0.0, 0.0, 1.0, 0.0]` |
| Final | 3 | 마지막 라운드 플레이 중; 조준보다 우선 | `[0.0, 0.0, 0.0, 1.0]` |

- **`owner`:** 기존 GameState 또는 얇은 MusicStateAdapter가 게임 조건을 한 곳에서 해석해 MusicManager.set_state()에 최종 상태를 전달한다.
- **`order`:** ["shop_open → Shop", "final_round_active → Final", "aiming → Aim", "otherwise → Main"]
- **`exit_policy`:** 상점 종료/조준 종료 때 무조건 Main을 보내지 말고 현재 모든 조건을 다시 평가한다.
- **`example`:** ["일반 → Main", "일반 라운드 조준 시작 → Aim", "조준 취소/다트 발사 후 → Main", "마지막 라운드 진입 → Final", "마지막 라운드에서 조준 → Final 유지", "마지막 라운드에서 상점 열기 → Shop", "상점 닫기, 마지막 라운드 진행 중 → Final"]
- **`pause_menu`:** 일시정지 메뉴는 별도 음악 상태로 만들지 않는다. 기본값은 현재 곡과 페이드가 계속 진행된다.

```gdscript
func resolve_music_state(shop_open: bool, final_round_active: bool, aiming: bool) -> StringName:
    if shop_open:
        return &"Shop"
    if final_round_active:
        return &"Final"
    if aiming:
        return &"Aim"
    return &"Main"

# GameState 조건이 바뀔 때:
# MusicManager.set_state(resolve_music_state(shop_open, final_round_active, aiming))
```

## 4. 공개 API와 이벤트 계약

### `start(initial_state: StringName = &"Main") -> bool`

준비된 정지 상태에서 대상 one-hot 게인을 적용하고 네 편곡을 0초부터 한 번에 시작한다. 재생 중/음악 일시정지 중 재호출은 아무 변경 없이 true. 잘못된 상태/준비 실패는 false와 오류 신호.

### `set_state(state: StringName, fade_seconds: float = -1.0) -> bool`

재생 중에만 허용한다. -1은 기본 1초, 0은 즉시 적용, 그 외 유한한 양수만 허용한다. 같은 requested_state는 no-op true. 새 상태는 현재 실제 게인에서 최신 요청으로 전환한다. 잘못된 입력 또는 정지 상태는 현재 상태를 보존하고 false.

### `set_music_volume_linear(value: float) -> void`

유한한 입력을 0~1로 제한해 Music 버스 볼륨으로 저장/적용한다. 사용자 음소거 플래그와 별도로 관리한다. 비유한 입력은 거부한다.

### `set_music_muted(muted: bool) -> void`

사용자 음소거 플래그를 바꾸고 effective_mute = user_muted OR user_volume_linear == 0을 Music 버스에 적용한다. 재생은 유지한다.

### `set_music_paused(paused: bool) -> void`

묶음 전체의 Player.stream_paused와 페이드 시계를 함께 멈추거나 재개한다. 재생 위치를 보존하며 재개 때 play를 호출하지 않는다. 정지 상태에서는 no-op.

### `stop_music() -> void`

명시적 종료용: 페이드를 취소하고 Player.stop(), paused=false, running=false, requested/settled=Main, 게인=Main one-hot으로 초기화한다. 사용자 볼륨/음소거는 유지한다. 다음 start는 0초부터 시작한다.

### `get_debug_snapshot() -> Dictionary`

running, paused, requested_state, settled_state, gains, applied_stream_db, fade_active, fade_progress, playback_position_seconds, user_volume_linear, user_muted, effective_mute, start_count를 반환한다. 재생 위치는 진단값이며 정밀 동기화 증거로 쓰지 않는다.

### 신호

- `state_requested(state: StringName)`: 유효한 새 전환 요청을 수락할 때 1회. start와 동일 상태 no-op에서는 발생하지 않는다.
- `state_settled(state: StringName)`: start 성공 또는 페이드 완료/즉시 적용 후 1회. 취소된 페이드의 목표는 통지하지 않는다.
- `music_error(code: StringName, message: String)`: 준비 실패, 잘못된 API 입력, 예상치 못한 재생 종료. 오류를 삼키지 말고 식별 가능한 코드와 함께 기록한다.

신호 수신자에서 MusicManager의 변경 API를 즉시 재호출하지 않는다. 필요한 후속 전환은 call_deferred로 예약한다.

## 5. 크로스페이드와 빠른 재전환

기본 시간 **1초**, **선형 진폭 보간**을 사용한다. 대상 상태만 1이고 나머지는 0인 벡터를 목표로 한다.

```text
u = clamp(elapsed_seconds / duration_seconds, 0, 1)
gain[i] = lerp(from_gain[i], target_gain[i], u)
```

- 새 요청을 검증한 뒤 현재 gains 벡터를 from_gains로 복사한다.
- 이전 페이드를 취소하고 목표 상태의 one-hot 벡터를 to_gains로 설정한다.
- requested_state를 새 목표로 설정하고 elapsed=0으로 시작한다.
- u=clamp(elapsed/duration, 0, 1). 각 i에 gains[i]=lerp(from_gains[i], to_gains[i], u)를 적용한다.
- 매 갱신마다 gain_to_db를 통해 sync_stream.set_sync_stream_volume(i, db)를 호출한다.
- 완료 시 정확한 목표 벡터를 다시 적용하고 settled_state를 갱신한다.

- **`zero_duration`:** 같은 상태 no-op 검사를 통과한 새 요청이면 현재 페이드를 취소하고 목표를 같은 호출 안에서 적용한다. 음악 일시정지 중에도 0초 요청은 즉시 적용한다.
- **`interruption`:** Main→Shop 도중 Aim 요청 시 Main/Shop/Aim/Final 네 현재 값을 모두 출발점으로 삼는다. 중간에 셋 이상의 게인이 양수여도 정상이다.
- **`same_state`:** requested_state가 같으면 시간 변경 요청도 무시한다. 매 프레임 같은 이벤트가 와도 페이드가 계속 진행한다.
- **`timing`:** 기본 즉시 전환 시작; 프레임에서 볼륨을 갱신하므로 샘플 단위의 전환 시점 예약은 아니다.
- **`clock`:** Time.get_ticks_usec()의 프레임 간 차이로 초를 누적해 Engine.time_scale과 분리한다. _process의 delta를 그대로 사용하지 않는다. 음악 명시 정지 중 매 프레임 기준 tick만 갱신하고 누적하지 않는다. 재개 시 기준 tick을 재설정한다.
- **`invariants`:** ["모든 게인은 유한하고 0~1이다.", "정상 재생/전환 중 게인 합은 1±0.000001이다.", "살아 있는 페이드는 하나다.", "신규 요청 첫 적용 게인은 직전 프레임 값과 같다.", "settled_state는 전환 중 마지막 완료 상태를 유지한다."]
- **`curve_reason`:** 동일 곡의 공통 악기가 겹치는 편곡을 기본 가정하므로 선형 진폭을 사용한다. dB를 0→-80으로 직접 보간하면 중간에 음량이 크게 꺼질 수 있다.
- **`equal_power_extension`:** 선택 확장: 두 비상관 소스에서는 cos(u*PI/2), sin(u*PI/2)도 고려할 수 있다. 공통 악기가 있으면 중간 음량이 증가할 수 있고 임의 중단 시 다중 게인 처리도 달라지므로 기본 구현에 섞지 않는다.
- **`tween_alternative`:** Tween을 쓴다면 이전 Tween.kill(), 현재 게인 스냅샷, 하나의 tween_method, pause/time_scale 정책을 동일하게 구현한다. 여러 볼륨 Tween을 방치하지 않는다.

## 6. 볼륨 dB와 사용자 설정

- **`conversion`:** gain <= 0이면 -80.0; 그 외 max(-80.0, linear_to_db(gain)). linear_to_db(0)는 호출하지 않는다.
- **`examples`:** [{"linear": 1.0, "db": 0.0}, {"linear": 0.5, "db_approx": -6.0206}, {"linear": 0.001, "db": -60.0}, {"linear": 0.0001, "db": -80.0}]
- **`floor_note`:** -80 dB는 매우 작은 유한 신호이며 수학적 완전 무음은 아니다. 비활성 편곡은 이 바닥값을 사용한다. 사용자 완전 음소거는 Music 버스 mute로 구현한다.
- **`gain_stages`:** 편곡 크로스페이드 dB + Player 헤드룸(-6 dB 기본) + Music 사용자 볼륨 dB + Master 설정
- **`user_volume_zero`:** 0이면 Music 버스 mute=true; 버스 dB에는 -80을 넣을 수 있다. 0보다 크면 linear_to_db(value)를 적용하고 user_muted를 반영한다. 이전 양수 값과 명시적 음소거 여부를 혼동하지 않는다.
- **`headroom`:** Player -6 dB는 시작값이다. 실제 에셋과 SFX를 합친 출력에서 클리핑을 측정하고 필요하면 믹스를 조정한다. 개별 곡의 0 dB 게인은 원본 크기이지 무음이 아니다.
- **`persistence`:** 기존 설정 저장 시스템에 user_volume_linear와 user_muted를 연결한다. 기존 시스템이 없으면 README에 외부 연결 API를 문서화하며 임의의 별도 저장 체계를 추가하지 않는다.

게인 변환 API는 [AudioStreamPlayer 문서](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html)를 참고한다. dB 숫자와 정책값은 이 명세에서 정한 믹스 기준이다.

## 7. 음악 파일 요구사항

| 상태 | 기본 에셋 경로 |
|---|---|
| Main | `res://audio/music/tracks/main.ogg` |
| Shop | `res://audio/music/tracks/shop.ogg` |
| Aim | `res://audio/music/tracks/aim.ogg` |
| Final | `res://audio/music/tracks/final.ogg` |

- 동일 BPM 및 템포맵; 기본은 일정 BPM
- 동일 박자표, 마디 수, 프레이즈 및 코드 진행 타이밍
- 동일 샘플레이트, 채널 수, 디코딩 후 프레임 수
- 동일 시작점: 공통 첫 박을 같은 프레임에 배치
- 동일 전체 길이 및 루프 시작/종료 프레임
- 같은 DAW 세션과 동일 내보내기 구간으로 출력
- 편곡별 앞 무음 제거/뒤 무음 자동 자르기/다른 tail 길이 금지
- 공통 악기는 가능하면 동일 위상·지연 보상 기준으로 출력
- 루프 경계의 파형과 잔향을 연결하고 크로스페이드 중 청취 음량도 맞춤

- **`preferred_format`:** Ogg Vorbis (.ogg); 동일 인코더/설정으로 일괄 출력
- **`alternative_format`:** PCM WAV (.wav); 메모리/패키지 크기를 검토하고 동일 형식으로 네 파일을 통일
- **`exclude_default`:** MP3는 이 명세의 검증 대상에서 제외한다.
- **`metadata_note`:** BPM 메타데이터만 넣는다고 파일이 자동으로 타임스트레치되거나 박자가 맞춰지지 않는다. BPM·마디 구조는 제작자가 보증하고 실제 파형/재생으로 검증한다.
- **`example_only`:** true
- **`duration_formula`:** duration_seconds = bars * beats_per_bar * 60 / bpm; 여기서 BPM은 박자표 분모 단위(예시에서는 4분음표)이다.
- **`correction`:** 120 BPM, 4/4, 128마디는 256초(4분 16초)다. 192초(3분 12초)는 96마디다.
- **`validation`:** get_length()는 양수이며 기준 스트림과 차이가 0.001초 이하인지 런타임에서 검사한다. 이 허용치는 리소스 메타데이터 반올림 점검용이며 1ms 길이 차이를 에셋 규격으로 허용한다는 뜻이 아니다. 오프라인에서 디코딩한 프레임 수와 시작 박 정렬을 별도로 확인한다.
- **`missing_assets`:** 실제 음악이 없으면 에셋 대기 상태를 명시하고 라이선스가 확인된 대체 에셋 또는 직접 만든 동일 길이 테스트 신호만 사용한다. 발라트로 OST를 내려받거나 포함하지 않는다.

### 제작 규격 예시 — 실제 에셋에 맞춰 교체

```json
{
  "bpm": 120.0,
  "time_signature": [
    4,
    4
  ],
  "beats_per_bar": 4,
  "bars": 96,
  "total_beats": 384,
  "duration_seconds": 192.0,
  "sample_rate_hz": 48000,
  "channels": 2,
  "decoded_frame_count": 9216000,
  "loop_start_frame": 0,
  "loop_end_frame_exclusive": 9216000
}
```

## 8. 동기화, 루프와 타임라인

- **`mode`:** 각 하위 스트림의 내장 전체 파일 루프; 처음부터 끝까지 같은 길이
- **`ogg`:** {"loop": true, "loop_offset": 0.0, "bpm": 0.0, "beat_count": 0, "bar_beats": 4, "reason": "기본 구현에서는 EOF 루프를 사용하고 실제 BPM은 별도 music_config.json에 저장한다. beat_count 기반의 다른 종료 지점을 만들지 않는다."}
- **`wav`:** {"loop_mode": "AudioStreamWAV.LOOP_FORWARD", "loop_begin": 0, "loop_end": "decoded_frame_count", "note": "WAV API의 루프 위치는 시간(초)이나 스테레오 채널 전체 샘플 합계가 아닌 프레임에 대응하는 샘플 인덱스 단위다. import 후 값 및 실제 경계를 검증한다."}
- **`rules`:** ["네 하위 스트림 모두 loop를 켠다. 동기화 리소스는 서로 다른 곡 길이를 자동으로 같게 만들지 않는다.", "finished 신호나 Timer로 stop/play를 반복해 루프를 만들지 않는다.", "일반 전환이나 주기적 drift 보정 목적으로 seek를 호출하지 않는다.", "개별 비활성 편곡의 재생을 멈추거나 일시정지하지 않는다.", "에셋/오디오 장치 문제 발생 시 원인을 기록한다. 복구가 필요하면 전체 묶음을 한 번에 다시 시작하는 명시적 동작으로 처리한다. 자동 반복 재시작 루프는 만들지 않는다."]
- **`diagnostics`:** get_playback_position은 오디오 믹싱 청크 단위 진단값이다. UI 추정에는 get_time_since_last_mix를 더하고 출력 지연을 고려할 수 있으나, 래핑/일시정지/시작 지연을 별도로 처리한다. 이 추정값으로 하위 스트림의 샘플 동기화를 증명하거나 매 프레임 seek하지 않는다.
- **`proof`:** 동일 프레임에 마커를 가진 시험용 네 스트림을 사용해 각각의 버전이 같은 위치에 들리는지 검사한다. 정밀 검증은 출력 녹음의 마커 정렬로 수행한다. 구현 버전에서 가능한 진단 API만 사용하며 하위 playback 위치 getter가 있다고 가정하지 않는다.

OGG의 `loop_offset` 및 `beat_count` 동작은 [AudioStreamOggVorbis](https://docs.godotengine.org/en/stable/classes/class_audiostreamoggvorbis.html), WAV의 샘플 인덱스 루프는 [AudioStreamWAV](https://docs.godotengine.org/en/stable/classes/class_audiostreamwav.html), 위치 추정과 지연의 한계는 [오디오 동기화 가이드](https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html)를 따른다.

## 9. 오류 처리

| 조건 | 처리 |
|---|---|
| Music 버스 없음 | 프로젝트 통합 때 기존 버스를 보존하며 Music→Master 경로를 추가한다. 런타임에서는 검증 실패로 알리고 묵시적 Master fallback에 기대지 않는다. |
| 누락/로드 실패/지원 밖 형식/길이 불일치/루프 설정 불일치 | 전체 시작을 거부하고 파일 경로가 포함된 오류를 기록한다. 부분적으로 준비된 편곡만 재생하지 않는다. |
| 알 수 없는 상태 또는 NaN/Infinity/잘못된 음수 duration | false 또는 오류 신호로 거부하고 실행 중 음악/페이드는 그대로 보존한다. |
| 실행 중 예상치 못한 finished | 오류 기록, running=false, 페이드 취소, 필요하면 묶음 정리. finished로 자동 루프하지 않는다. |
| 준비 전 외부 호출 | ready/running 가드로 거부한다. 부트스트랩은 준비 완료 후 start를 호출한다. |

## 10. GDScript 구현 지침과 핵심 예시

- 먼저 기존 오디오 코드, 프로젝트 버전과 게임 상태 흐름을 읽고 중복 MusicManager 및 Autoload 이름 충돌을 피한다.
- MusicManager Autoload 이름과 동일한 class_name MusicManager 선언을 함께 사용하지 않는다. extends Node만으로 충분하다.
- 타입 지정 GDScript를 사용한다. 상태 외부 식별자는 정확한 StringName Main/Shop/Aim/Final, 내부 인덱스는 고정 매핑을 쓴다.
- 네 에셋/설정을 준비할 때만 ResourceLoader를 호출한다. 전환 중 파일 로드나 동기화 리소스 재구성은 금지한다.
- 설정 파일의 숫자 타입, 필수 키, 고정 인덱스 중복, 배열 길이와 유한값을 검증한다. BPM/마디 수 등 예시값을 실제 에셋 검사 없이 사실로 간주하지 않는다.
- 교차 전환 계산을 한 함수에 모으고, 실제 게인과 from/to를 별도 복사한다. mutable 배열을 공유해서 출발점이 변하지 않게 한다.
- 상태 요청 입력 검증을 먼저 수행한 후 현재 페이드를 취소한다. 실패한 요청은 정상 페이드를 중단시키지 않아야 한다.
- Node.PROCESS_MODE_ALWAYS로 씬 트리 일시정지 중 음악/페이드를 유지하고 명시적 음악 pause만 별도로 처리한다.
- 테스트용 UI 버튼을 게임 코드에 영구 하드코딩하지 말고 별도의 music_test.tscn에 둔다.
- 기존 프로젝트 버전에서 파싱 및 실행하고, 에디터 재생과 실제 내보내기 환경에서 검증한다. 실제 오디오 검증을 수행하지 않았다면 통과했다고 쓰지 않는다.

아래 코드는 **페이드 계산의 참고 발췌**다. 전체 구현 파일이 아니며 start/정지/일시정지/리소스 준비/버스 설정/진단을 앞의 계약대로 완성해야 한다. 이 명세 작성 단계에서 실제 음악 재생을 테스트한 코드는 아니다.

```gdscript
extends Node

# 핵심 페이드 로직 예시. 전체 MusicManager 구현이 아니다.
# 초기 준비/start/버스/오류 신호/pause/stop/진단 코드는 본문 계약대로 추가한다.
const STATE_INDEX = {&"Main": 0, &"Shop": 1, &"Aim": 2, &"Final": 3}
const DEFAULT_FADE_SECONDS: float = 1.0
const SILENT_DB: float = -80.0

var sync_stream: AudioStreamSynchronized
var running: bool = false
var music_paused: bool = false
var requested_state: StringName = &"Main"
var settled_state: StringName = &"Main"
var gains := PackedFloat64Array([1.0, 0.0, 0.0, 0.0])
var from_gains := PackedFloat64Array()
var to_gains := PackedFloat64Array()
var fade_active: bool = false
var fade_elapsed: float = 0.0
var fade_duration: float = 1.0
var last_tick_usec: int = 0

signal state_requested(state: StringName)
signal state_settled(state: StringName)
signal music_error(code: StringName, message: String)

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    last_tick_usec = Time.get_ticks_usec()
    # 별도 준비가 끝난 start()만 running=true로 만든다.

func _gain_to_db(gain: float) -> float:
    if gain <= 0.0:
        return SILENT_DB
    return maxf(SILENT_DB, linear_to_db(gain))

func _apply_gains() -> void:
    for i in range(4):
        sync_stream.set_sync_stream_volume(i, _gain_to_db(gains[i]))

func set_state(state: StringName, fade_seconds: float = -1.0) -> bool:
    if not STATE_INDEX.has(state) or not is_finite(fade_seconds):
        music_error.emit(&"invalid_request", "Invalid state or duration")
        return false
    if fade_seconds < 0.0 and fade_seconds != -1.0:
        music_error.emit(&"invalid_duration", "Only -1 or nonnegative durations are allowed")
        return false
    if not running or sync_stream == null:
        music_error.emit(&"not_running", "Call start after preparing all streams")
        return false
    if state == requested_state:
        return true

    # 이전 페이드의 현재 값을 보존한 뒤 최신 요청 하나로 교체한다.
    fade_active = false
    from_gains = gains.duplicate()
    to_gains = PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
    to_gains[int(STATE_INDEX[state])] = 1.0
    requested_state = state
    fade_duration = DEFAULT_FADE_SECONDS if fade_seconds == -1.0 else fade_seconds
    fade_elapsed = 0.0
    last_tick_usec = Time.get_ticks_usec()
    if fade_duration == 0.0:
        gains = to_gains.duplicate()
        _apply_gains()
        settled_state = state
        # 수신자는 콜백 안에서 재진입 호출하지 말고 필요하면 call_deferred를 쓴다.
        state_requested.emit(state)
        state_settled.emit(state)
        return true
    fade_active = true
    state_requested.emit(state)
    return true

func _process(_delta: float) -> void:
    var now_usec: int = Time.get_ticks_usec()
    var dt: float = maxf(0.0, float(now_usec - last_tick_usec) / 1000000.0)
    last_tick_usec = now_usec
    if not running or music_paused or not fade_active:
        return
    fade_elapsed += dt
    var u: float = clampf(fade_elapsed / fade_duration, 0.0, 1.0)
    for i in range(4):
        gains[i] = lerpf(from_gains[i], to_gains[i], u)
    if u >= 1.0:
        gains = to_gains.duplicate()
        fade_active = false
        settled_state = requested_state
    _apply_gains()
    if not fade_active:
        state_settled.emit(settled_state)
```

## 11. Claude Code가 만들어야 할 산출물

| 경로 | 내용 |
|---|---|
| `res://audio/music/music_manager.gd` | 공개 API, 단일 페이드, 검증/오류/진단 구현 |
| `res://audio/music/music_manager.tscn` | Autoload 루트 및 단일 Player |
| `res://audio/music/music_config.json` | 실제 네 에셋 경로, 고정 상태 매핑, fade/headroom/floor 값, 실제 공통 음악 메타데이터; 이 명세 JSON 전체를 런타임에 직접 읽지 않음 |
| `res://audio/music/tracks/` | 사용자가 제공한 네 편곡 및 import 루프 설정; 없다면 README에 미제공 명시 |
| `res://tests/audio/music_test.tscn` | 4개 상태 버튼, 반복 전환, 볼륨/음소거/정지/재개, 진단 표시 |
| `res://tests/audio/music_test.gd` | 핵심 게인/API 시나리오 자동 검증 및 테스트 장면 제어 |
| `res://audio/music/README.md` | 정확한 Godot 버전, 연결 방법, 에셋/import 요구사항, 실행 방법, 실제 수행한 테스트 결과와 미검증 항목 |
| `project.godot / 기존 버스 레이아웃 / 기존 GameState 연결부` | 최소한의 Autoload, Music 버스, 상태 전달 변경; 기존 설정 보존 |

작업 순서는 기존 프로젝트 파악 → 구성/에셋 검사 → 관리자와 버스 → 게임 상태 연결 → 테스트 장면 → 검증 결과 기록으로 한다. 이 문서의 JSON 전체를 게임 설정으로 로드하지 말고 필요한 런타임 필드만 별도 구성 파일에 넣는다.

## 12. 테스트 체크리스트와 완료 조건

- [ ] **T01 · 구성 검증** (`automatic`): 버스/에셋 누락, 중복 인덱스, 잘못된 메타데이터, 길이/루프 불일치 시 시작 거부 및 식별 가능한 오류. 게임 크래시 없음.
- [ ] **T02 · 최초 Main 시작 및 start 재호출** (`automatic_and_listen`): start_count=1, Main 게인=1, 나머지=0(적용 dB=-80). start 재호출 및 씬 이동 후 재생 위치 초기화 없음.
- [ ] **T03 · Main→Shop 1초 페이드** (`automatic`): 순수 보간 함수 u=0/0.5/1에서 [1,0,0,0]/[0.5,0.5,0,0]/[0,1,0,0]. 시작/끝 dB 정상, 완료 신호 1회. 런타임 완료는 다음 처리 프레임 이내.
- [ ] **T04 · Main→Shop 0.3초 후 Aim→0.2초 후 Final** (`automatic_and_listen`): 각 새 요청은 현재 4개 게인에서 연속 시작. 이전 완료 신호 없음. 모든 게인이 범위 내, 합=1±1e-6, 마지막 Final에 수렴, play/seek 추가 호출 없음.
- [ ] **T05 · 동일 목표를 매 프레임 100번 요청** (`automatic`): 페이드가 계속 진행하고 재시작/완료 신호 중복/타임라인 초기화 없음.
- [ ] **T06 · 0초, -1초, 잘못된 음수, NaN, Infinity, 알 수 없는 상태** (`automatic`): 0은 즉시 목표 적용, -1은 기본값, 나머지 유효하지 않은 입력은 기존 페이드/상태 보존하며 거부.
- [ ] **T07 · 볼륨 1→0.5→0→0.5 및 별도 음소거** (`automatic_and_listen`): 버스만 변경되고 게인/재생 위치 유지. 0에서 완전 mute, 명시적 음소거 중 볼륨을 올려도 mute 유지. SFX는 영향 없음.
- [ ] **T08 · 전환 중 SceneTree pause 및 Engine.time_scale=0.25/2.0** (`automatic_and_listen`): 기본 정책에서 음악/페이드 계속 진행. 시간 배율과 무관하게 실제 약 1초에 완료. 테스트 후 기존 time_scale 복원.
- [ ] **T09 · 전환 중 명시적 음악 pause 5초 후 resume** (`automatic_and_listen`): 모든 편곡과 페이드 진행률 유지 후 함께 재개. 재개 직후 5초를 누적하지 않음. pause 중 새 양수 duration 요청은 게인 유지 후 resume에서 진행; 0초 요청은 즉시 적용.
- [ ] **T10 · stop 후 start** (`automatic_and_listen`): 페이드/일시정지 초기화, 사용자 볼륨/음소거 유지, 다음 start만 전체를 0초부터 한 번 재시작.
- [ ] **T11 · 게임 조건 우선순위 및 씬 왕복 10회** (`integration`): Shop > Final > Aim > Main. 상점 종료 후 남은 조건 복원. MusicManager 인스턴스=1, 씬 이동에 따른 play 호출 없음.
- [ ] **T12 · 일반 전환 및 루프 전후 0.5초 구간에서 전환** (`listen_and_capture`): 가청 클릭, 공백, 첫 박 재시작, 템포 점프 없음. 동일 타임라인의 편곡 변화로 들림. 필요하면 파형 캡처를 결과에 첨부.
- [ ] **T13 · 동일 마커를 가진 시험 에셋으로 동기화 확인** (`capture`): 제어된 엔진 출력 캡처에서 편곡별 마커의 상대 오프셋이 0 또는 캡처 1프레임 이내. 스피커 루프백만 가능하면 측정 오차를 기록하고 샘플 단위 보장으로 판정하지 않음.
- [ ] **T14 · 30분 이상 및 최소 10회 루프, 0.1~0.3초 간격 무작위 상태 전환** (`long_run_and_capture`): 점진적 편곡 오프셋 증가/루프 공백 없음, 최신 목표에 수렴. 측정 환경·CPU·메모리 기록; 지속 증가나 오디오 underrun 없음.
- [ ] **T15 · 실제 에셋으로 대상 플랫폼 내보내기** (`export_and_listen`): 네 파일 import/포함 정상, 모든 상태 전환과 루프 재생, 최종 Music+SFX 출력 클리핑 없음. 웹 대상이면 사용자 입력 이후 시작도 검증.

- 필수 산출물과 게임 상태 연결이 완료되어야 한다.
- T01~T15 중 실제 수행 결과를 pass/fail/not_run 및 근거와 함께 기록한다.
- 실제 음악 또는 대상 플랫폼이 없으면 해당 오디오/내보내기 항목은 not_run으로 남기고 제한을 명시한다.
- JSON 문법 통과나 코드 파싱만으로 오디오 동기화/루프 청취 검증을 대체하지 않는다.

검증 결과에는 `테스트 ID / pass·fail·not_run / Godot 정확한 버전 / 플랫폼 / 사용 에셋 / 근거 또는 미수행 사유`를 남긴다. 장시간 재생은 시간과 루프 횟수, 실제 출력 캡처는 캡처 경로와 샘플레이트를 함께 기록한다.

## 13. 기본값 한눈에 보기

```json
{
  "initial_state": "Main",
  "state_order": [
    "Main",
    "Shop",
    "Aim",
    "Final"
  ],
  "fade_seconds": 1.0,
  "fade_curve": "linear_amplitude",
  "silent_floor_db": -80.0,
  "player_headroom_db": -6.0,
  "user_volume_linear": 1.0,
  "user_muted": false,
  "pitch_scale": 1.0,
  "continue_during_scene_tree_pause": true,
  "ignore_engine_time_scale_for_fade": true,
  "loop_start_seconds": 0.0,
  "loop_entire_file": true,
  "resource_length_tolerance_seconds": 0.001
}
```

## 14. 근거와 설계 선택

공식 API 동작과 이 문서의 설계 선택을 구분한다. 상태 우선순위, 1초 페이드, -80/-6 dB 및 테스트 기준은 본 프로젝트의 제안 기본값이다. 실제 발라트로 내부 구현을 검증했다는 의미는 아니다.

- S1: [Godot 4.3 AudioStreamSynchronized](https://docs.godotengine.org/en/4.3/classes/class_audiostreamsynchronized.html) — 4.3에서 사용할 수 있는 동기화 스트림과 하위 볼륨 API
- S2: [Godot AudioStreamPlayer](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html) — 비위치 재생, 버스, 피치, stream_paused, 재생 위치와 stream 교체 동작
- S3: [Godot AudioStreamOggVorbis](https://docs.godotengine.org/en/stable/classes/class_audiostreamoggvorbis.html) — loop, loop_offset, BPM 및 beat_count 종료점
- S4: [Godot AudioStreamWAV](https://docs.godotengine.org/en/stable/classes/class_audiostreamwav.html) — WAV 내장 루프 모드와 위치 단위
- S5: [Godot: Sync the gameplay with audio and music](https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html) — 오디오 믹스 청크, 출력 지연, 진단 위치 추정의 한계
- S6: [Godot 4.3 audio_stream_synchronized.cpp](https://github.com/godotengine/godot/blob/4.3-stable/modules/interactive_music/audio_stream_synchronized.cpp) — 하위 스트림의 공통 시작과 믹싱 중 하위 게인 반영
