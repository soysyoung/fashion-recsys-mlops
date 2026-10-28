# 공식 cu129 이미지에 든 torchcodec 0.17.0 이 CUDA 13 용이라 `vllm serve` 가 import 단계에서 죽는다
# (libcudart.so.13 없음). https://github.com/vllm-project/vllm/issues/63121
# torchcodec 은 오디오 디코딩용이라 텍스트 LLM 에는 필요 없다. 공식 이미지가 고쳐지면 이 파일을 지운다.
ARG BASE
FROM ${BASE}
RUN pip uninstall -y torchcodec
