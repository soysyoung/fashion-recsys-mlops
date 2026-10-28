# 0001. 공개 모델만 쓰고, 서빙과 운영에 집중한다

날짜: 2026-10-27 / 상태: 채택

## 결정

- 모델은 직접 학습하지 않고 공개 모델을 쓴다. 임베딩은 텍스트 임베딩 모델, 생성은 양자화된 소형 LLM.
- 구매·이탈 예측은 범위에서 뺀다. 정형 거래 이력은 LLM 의 일이 아니고, 학습을 하지 않기로 했기 때문이다.
- 유사 추천과 LLM 질의 추천 각각을 배치와 실시간으로 모두 구현한다.

## 근거

- 이전 경력(정오답 예측 실시간, 유사문항 추천 배치)에서 비어 있는 쪽을 채운다: 서빙 구조를 도메인만 바꿔 다시 만든다.
- GPU 는 RTX 5080 Laptop 16GB 한 장이고 kind 워커 한 노드에만 할당된다. 7~8B 를 FP16 으로는 못 올리므로 4비트 양자화 또는 4B 이하를 쓴다.

## 확인한 것 (2026-10-27)

| 항목 | 수준 | 내용 |
|---|---|---|
| 클러스터 KServe | 실측 | controller v0.18.0, ClusterServingRuntime `kserve-huggingfaceserver` 존재, Knative·Istio 가동 |
| KServe + vLLM | 문서 | HF 런타임의 vLLM 백엔드와 OpenAI 호환 API 는 문서에 있음. 문서는 v0.20 기준이고 클러스터는 v0.18.0 |
| vLLM + Blackwell(sm_120) | 이슈·포럼 | 유지보수자가 wheel/docker 에 SM120 지원이 들어갔다고 답함(2025-06). 5080 + WSL2 사용 보고 있음. 직접 실행은 아직 |
| bge-small-en-v1.5 | 모델 카드 | MIT, 33.4M 파라미터, 384차원 |
| Qwen3-4B-AWQ | 모델 카드 | 4B, AWQ 4비트, vLLM 서빙 안내 있음. 라이선스는 카드 조회에서 확인하지 못함 |

## 스모크 테스트 1차 결과 (2026-10-27)

`vllm/vllm-openai:v0.32.0-cu129` 가 시작 직후 종료됐다. 원인은 Blackwell 이 아니라 이미지에 든 `torchcodec 0.17.0` 이 CUDA 13 용이라 `libcudart.so.13`, `libnvrtc.so.13` 이 없는 것이다 (컨테이너 안 `ldd` 로 확인, [vllm#63121](https://github.com/vllm-project/vllm/issues/63121), 수정 릴리스는 확인하지 못함). 컨테이너 안에서 `torchcodec` 제거(B)와 `torchcodec==0.16.0` cu129 설치(A) 모두 `import vllm` 단계는 통과했다. 실제 서빙은 아직 시험하지 못했다. 텍스트 LLM 에는 오디오 디코더가 필요 없어 B 를 택해 [serving/vllm/Dockerfile](../../serving/vllm/Dockerfile) 로 만들었다.

## 스모크 테스트 2차 결과 (2026-10-27, 통과)

Dockerfile 적용 후 `v0.32.0-cu129` + `Qwen/Qwen3-4B-AWQ` 가 RTX 5080 Laptop 에서 서버를 띄우고 `/v1/chat/completions` 에 응답했다 (`vllm-0.32.0`, 프롬프트 17 + 생성 64 토큰, `finish_reason: length`). 이로써 이 이미지와 모델 조합이 sm_120 에서 동작한다는 것은 **관찰됐다**.

| 항목 | 값 | 조건 |
|---|---|---|
| VRAM 사용 | 13348 MiB | `--gpu-memory-utilization 0.85`, `--max-model-len 4096`, 응답 직후 `nvidia-smi` |
| 호스트 메모리, CPU, 지연 | **미측정** | `docker stats` 출력을 받지 못함 |

관찰: Qwen3 는 기본이 사고 모드라 응답이 `<think>` 로 시작한다. 서비스 용도에서는 요청에 `chat_template_kwargs: {"enable_thinking": false}` 를 준다 (스크립트에 넣었지만 아직 실행하지 않음).

## 스모크 테스트 3차 결과 (2026-10-27, 통과)

`GPU_UTIL=0.6`, `--max-model-len 4096`, 같은 이미지와 모델. 요청 1회(생성 27 토큰, `finish_reason: stop`).

| 항목 | 값 |
|---|---|
| VRAM 사용 | 9270 MiB (GPU 16303 MiB 중, 시작 전 0 MiB) |
| 컨테이너 메모리 | 4.648 GiB (`docker stats`, 요청 직후) |
| 컨테이너 CPU | 0.70% (요청 직후 유휴 시점) |
| 사고 모드 끄기 | `enable_thinking: false` 로 `<think>` 없이 응답함 |

미측정: 부하 중 메모리와 CPU, 응답 지연과 처리량, 다른 프로세스가 VRAM 을 쥔 상태에서의 시작 (vLLM 이 요청 비율만큼의 여유 VRAM 을 확인하는지 모른다).

## 열린 항목

- KServe 0.18.0 의 HF 런타임 이미지에 들어 있는 vLLM 이 sm_120 커널을 갖는지 모른다. 커스텀 ServingRuntime 은 가장 나중 단계로 미룬다. 그 전에는 공식 `vllm/vllm-openai` 이미지(버전 고정)를 일반 Deployment 로 띄운다.
- H&M 대회 약관에 동의는 했다(2026-10-27). 약관의 사용 범위 본문은 이 기록 작성자가 읽지 못했다. 공개 저장소에 둘 수 있는 것은 코드와 다운로드 스크립트뿐이다.
- 모델 라이선스는 사용 전에 모델 카드에서 직접 확인한다.
- GPU 는 노트북 한 장이라 vLLM 과 Kubeflow Notebook 이 동시에 쓰기 어렵다.
