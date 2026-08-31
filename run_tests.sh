#!/usr/bin/env bash
set -uo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
# 실패한 assert는 Godot 4.7.2 헤드리스를 무한 정지시킨다. 타임아웃으로 실패 처리한다.
TEST_TIMEOUT="${TEST_TIMEOUT:-20}"

if [ ! -x "$GODOT" ]; then
	echo "godot 실행 파일을 찾을 수 없음: $GODOT"
	echo "GODOT 환경변수로 경로를 지정하세요."
	exit 1
fi

failed=0
for test_file in "$PROJECT_DIR"/tests/test_*.gd; do
	name="$(basename "$test_file")"
	echo "--- $name"
	perl -e 'alarm shift; exec @ARGV' "$TEST_TIMEOUT" "$GODOT" --headless --path "$PROJECT_DIR" --script "res://tests/$name"
	code=$?
	if [ "$code" -eq 142 ]; then
		echo "TIMEOUT(${TEST_TIMEOUT}초): $name — 실패한 assert가 CLI 디버거에서 멈춘 것일 수 있다. 위 SCRIPT ERROR 참고"
	fi
	if [ "$code" -ne 0 ]; then
		echo "FAIL: $name"
		failed=1
	fi
done

if [ "$failed" -ne 0 ]; then
	echo "테스트 실패"
	exit 1
fi
echo "전체 통과"
