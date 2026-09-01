class_name SaveData
extends RefCounted

# 테스트가 실제 사용자 기록을 지우지 않도록 경로를 바꿔 끼울 수 있게 둔다.
static var PATH := "user://blockbox_save.cfg"
const SECTION := "progress"
const KEY := "high_score"

static func load_high_score() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return 0
	var v: Variant = cfg.get_value(SECTION, KEY, 0)
	# 손으로 고친 파일에 배열이나 사전이 들어 있으면 int() 가 크래시한다.
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return 0
	return int(v)

static func save_high_score(value: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # 실패해도 빈 설정으로 이어간다
	cfg.set_value(SECTION, KEY, value)
	cfg.save(PATH)

static func submit(score: int) -> int:
	var best := load_high_score()
	if score > best:
		best = score
		save_high_score(best)
	return best
