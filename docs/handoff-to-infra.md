# infra 세션 인계 메모

이 저장소(fashion-recsys-mlops)가 infra 에 요청하는 플랫폼 작업. infra 세션은 [infra/docs/todo.md](../../infra/docs/todo.md) 의 '새 세션에서 이어 하려면' 을 먼저 읽는다. 근거와 측정 출처는 [ADR 0001](decisions/0001-scope-public-models-only.md).

## 측정값 (2026-10-27, vLLM v0.32.0-cu129 + Qwen3-4B-AWQ, `docker run` 으로 시험)

| 항목 | 값 | 조건 |
|---|---|---|
| VRAM | 9270 MiB | `--gpu-memory-utilization 0.6`, `--max-model-len 4096` |
| VRAM | 13348 MiB | 같은 조건에서 0.85 |
| 컨테이너 메모리 | 4.648 GiB | 요청 1회 직후 |

미측정: 부하 중 자원, 지연, 다른 프로세스와 GPU 를 나눌 때의 동작.

## 요청 1: GPU 공유 (ADR 0013 후보)

- 현재: GPU 워커 한 노드에 `nvidia.com/gpu: 1` 로 광고된다. device plugin v0.20.1 에 args, env, ConfigMap 이 없다 (2026-10-27 확인, time-slicing 없음). vLLM 파드가 GPU 를 요청하면 GPU Notebook 은 `Pending` 이 된다.
- 필요: time-slicing 으로 GPU 를 2개 이상으로 광고한다 (vLLM 1 + Notebook 1 이상). 개수는 공식 문서를 읽고 정한다.
- 알려진 한계: time-slicing 은 VRAM 을 격리하지 않는다. vLLM 이 약 9.3GB 를 쥐므로 나머지 약 7GB 를 Notebook 이 넘기면 한쪽이 OOM 이다. 문서에 한계로 적는다.
- 미확인: 다른 프로세스가 VRAM 을 쥔 채로 vLLM 이 시작되는지.
- 선행: todo 4번(GPU Notebook 안 `nvidia-smi`)을 먼저 확인해 기준선으로 삼는다.

## 요청 2: OpenSearch (ADR 0014 후보)

- 단일 노드, replica 0, PVC, k-NN 사용.
- 규모: 벡터 약 10.5만 × 384차원. 공식 HNSW 공식 `1.1 × (4×dim + 8×m)` 바이트/벡터로 약 0.19GB (m=16).
- 제안 자원 (추정): 파드 4Gi, 힙 1~2GB, PVC 수 GB. 버전은 안정성 기준으로 고정하고 근거를 `docs/versions.md` 에.
- 미확인: 최신 안정 버전, 보안 플러그인의 초기 관리자 비밀번호 요구와 접속 방식. 공식 문서로 확인한다.
- 이 저장소가 받을 것: 클러스터 내부 Service 주소와 접속 방법(인증 포함).
- `vm.max_map_count` 는 WSL 에서 1048576 으로 이미 충분하다 (2026-10-27 확인).

## 요청 3: 자원 예산

- WSL 은 24GB (현재 사용 약 7GB, 가용 약 17GB).
- 이 저장소의 예상: vLLM 파드 request 5Gi / limit 8Gi (실측 4.6GiB 에 부하 여유), OpenSearch 4Gi. 합쳐 약 12Gi 가 추가된다.
- 판단 요청: `.wslconfig` 의 `memory` 조정 여부, 프로젝트용 네임스페이스와 ResourceQuota (todo 5번과 같은 주제).
- 클러스터에 metrics-server 가 없어 `kubectl top` 이 안 된다. 실측은 `docker stats` 로 한다.

## 이 저장소가 가져가는 것 (infra 가 하지 않는 일)

vLLM Deployment 와 Service (공식 이미지 + [serving/vllm/Dockerfile](../serving/vllm/Dockerfile) 의 torchcodec 제거 패치), HF 모델 캐시 PVC, OpenSearch 인덱스 매핑, 임베딩과 적재 잡, 검색 API. GPU 워커의 taint 때문에 Deployment 에는 toleration 이 필요하다 ([infra/k8s/gpu-poddefault.yaml](../../infra/k8s/gpu-poddefault.yaml) 참고, 이 메모 작성자는 파일을 읽지 않았다).

## infra 문서 갱신

- todo 21번은 "워크로드 저장소 하나에 프로젝트별 폴더"라고 적혀 있으나 프로젝트당 단독 저장소로 정했다. 고친다.
- README '범위' 에 이 저장소 링크를 넣는다.

## 규칙 요약 (todo.md 에 있는 것)

시스템을 바꾸는 명령은 사용자가 직접 실행하고, 변경은 스크립트로 흡수한다. 새 사실은 공식 문서나 실측으로 확인하고 못 한 것은 '미검증'으로 쓴다. 커밋은 `dev`, 한 커밋 한 목적. 공개 저장소이므로 tailnet 이름, 기기 모델, 사설 IP 는 쓰지 않는다.
