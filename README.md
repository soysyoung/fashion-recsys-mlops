# fashion-recsys-mlops

H&M 패션 이커머스 데이터로 **공개 모델을 직접 학습하지 않고 서빙·평가·운영하는** LLMOps 프로젝트. 플랫폼은 [infra](../infra) (kind + Kubeflow + GPU 1장) 위에서 돈다.

> **상태: 계획.** 아래 표의 항목은 아직 구현·검증되지 않았다. 구현한 것만 "완료"로 바꾼다.

## 범위

모델은 공개 모델을 그대로 쓴다. 이 저장소의 일은 모델을 만드는 것이 아니라 **서빙, 평가, 캐싱, 모니터링, 버전 관리**다. 구매·이탈 예측은 정형 데이터 학습이 필요해 뺐다 ([ADR 0001](docs/decisions/0001-scope-public-models-only.md)).

| | 배치 | 실시간 |
|---|---|---|
| **유사 상품 추천** | 상품 설명 임베딩과 이웃 목록 사전 계산 → 적재 | 쿼리 임베딩 + 벡터 검색 API |
| **LLM 질의 추천** | 상품 속성 추출·설명 일괄 생성 (vLLM 오프라인 추론) | 자연어 질의 → 추천 API (vLLM 서버) |

| 단계 | 내용 | 상태 |
|---|---|---|
| 0 | vLLM 스모크 테스트 ([scripts/vllm-smoke.sh](scripts/vllm-smoke.sh)) | 통과 (docker run, 요청 1회. 결과는 [ADR 0001](docs/decisions/0001-scope-public-models-only.md)) |
| 1 | 유사 추천 배치 경로 (임베딩 → 이웃 적재) | 계획 |
| 2 | 유사 추천 실시간 경로 + 배치/실시간 결과 일치 테스트 | 계획 |
| 3 | LLM 질의 추천 (배치, 실시간) | 계획 |
| 4 | CI/CD, 모니터링, 롤백 | 계획 |

## 데이터

H&M Personalized Fashion Recommendations (Kaggle). 대회 약관에 따라 **원본, 샘플, 파생물(임베딩 등)을 모두 저장소에 넣지 않는다**. 받는 방법은 [scripts/download_hm.sh](scripts/download_hm.sh).
