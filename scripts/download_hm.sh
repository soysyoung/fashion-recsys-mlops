#!/usr/bin/env bash
# H&M 데이터를 data/raw 에 받는다. 원본은 커밋하지 않는다 (.gitignore).
# 사전 조건: Kaggle 계정에서 대회 약관에 동의하고 인증한다. 약관의 사용 범위는 직접 읽는다.
#   인증 (kaggle CLI 안내 기준): .venv/bin/kaggle auth login (OAuth), 또는 API 토큰을
#   환경변수 KAGGLE_API_TOKEN 이나 파일 ~/.kaggle/access_token 에 둔다.
#   https://www.kaggle.com/competitions/h-and-m-personalized-fashion-recommendations/rules
set -euo pipefail

cd "$(dirname "$0")/.."
# Ubuntu 24.04 는 시스템 pip 설치를 막으므로(PEP 668) 저장소 안 .venv 에 공식 kaggle CLI 를 설치한다.
# 실패하면 `sudo apt install python3-venv` 가 필요하다.
[ -x .venv/bin/kaggle ] || { python3 -m venv .venv && .venv/bin/pip install -q kaggle; }
mkdir -p data/raw
# 전체가 약 35GB(이미지 포함)라 필요한 CSV 만 받는다.
for f in articles.csv customers.csv transactions_train.csv; do
  [ -f "data/raw/$f" ] && continue
  [ -f "data/raw/$f.zip" ] || .venv/bin/kaggle competitions download -c h-and-m-personalized-fashion-recommendations -f "$f" -p data/raw
  .venv/bin/python -m zipfile -e "data/raw/$f.zip" data/raw
done
ls -lh data/raw
