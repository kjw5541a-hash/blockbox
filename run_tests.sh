#!/usr/bin/env bash
set -uo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -x "$GODOT" ]; then
	echo "godot 실행 파일을 찾을 수 없음: $GODOT"
	echo "GODOT 환경변수로 경로를 지정하세요."
	exit 1
fi

failed=0
for test_file in "$PROJECT_DIR"/tests/test_*.gd; do
	name="$(basename "$test_file")"
	echo "--- $name"
	if ! "$GODOT" --headless --path "$PROJECT_DIR" --script "res://tests/$name"; then
		echo "FAIL: $name"
		failed=1
	fi
done

if [ "$failed" -ne 0 ]; then
	echo "테스트 실패"
	exit 1
fi
echo "전체 통과"
