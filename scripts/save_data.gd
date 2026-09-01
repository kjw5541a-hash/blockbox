class_name SaveData
extends RefCounted

const PATH := "user://blockbox_save.cfg"
const SECTION := "progress"
const KEY := "high_score"

static func load_high_score() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return 0
	return int(cfg.get_value(SECTION, KEY, 0))

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
