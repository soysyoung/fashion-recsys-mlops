#!/usr/bin/env bash
# vLLM 스모크 테스트: 공식 이미지로 작은 양자화 모델을 서빙하고 응답 한 번 확인한다.
# WSL 에서 실행한다. VLLM_IMAGE 는 Docker Hub 에서 확인한 버전으로 직접 고정한다 (latest 금지).
#   VLLM_IMAGE=vllm/vllm-openai:v0.32.0-cu129 ./scripts/vllm-smoke.sh
# 태그의 CUDA 는 드라이버가 지원하는 버전(nvidia-smi 의 CUDA Version, 2026-10-27 기준 13.1) 이하여야 한다. cu134-nightly 는 맞지 않을 가능성이 높다.
set -euo pipefail

: "${VLLM_IMAGE:?VLLM_IMAGE 를 설정한다 (예: vllm/vllm-openai:<태그>)}"
MODEL="${MODEL:-Qwen/Qwen3-4B-AWQ}"
NAME=vllm-smoke
PORT=8000

cd "$(dirname "$0")/.."
nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv,noheader
trap 'docker rm -f "$NAME" >/dev/null 2>&1 || true' EXIT

# 공식 이미지의 torchcodec 문제를 피하는 로컬 이미지 (serving/vllm/Dockerfile)
IMAGE="fashion-vllm:${VLLM_IMAGE##*:}"
docker build -q -t "$IMAGE" --build-arg BASE="$VLLM_IMAGE" serving/vllm

docker run -d --name "$NAME" --gpus all --ipc=host -p "$PORT:8000" \
  -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
  "$IMAGE" --model "$MODEL" --max-model-len 4096 --gpu-memory-utilization "${GPU_UTIL:-0.85}"

echo "서버가 뜰 때까지 기다린다 (첫 실행은 모델 내려받기 때문에 오래 걸린다)"
for _ in $(seq 1 120); do
  curl -sf "localhost:$PORT/health" >/dev/null && break
  docker ps -q -f "name=$NAME" | grep -q . || { docker logs --tail 40 "$NAME"; echo "컨테이너가 종료됨"; exit 1; }
  sleep 5
done
curl -sf "localhost:$PORT/health" >/dev/null || { docker logs --tail 40 "$NAME"; echo "10분 안에 뜨지 않음"; exit 1; }

curl -s "localhost:$PORT/v1/chat/completions" -H 'Content-Type: application/json' \
  -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Describe a navy wool coat in one sentence.\"}],\"max_tokens\":64,\"chat_template_kwargs\":{\"enable_thinking\":false}}"
echo
docker stats --no-stream "$NAME"
nvidia-smi --query-gpu=memory.used --format=csv,noheader
