extends SceneTree

func _initialize() -> void:
	# 이전 실행이 남긴 파일을 지우고 시작한다 — 이전 상태에 기대지 않는다.
	var abs_path := ProjectSettings.globalize_path(SaveData.PATH)
	DirAccess.remove_absolute(abs_path)
	_test_default_is_zero()
	_test_submit_keeps_max()
	_test_persists_across_reload()
	_test_garbage_content()
	# 이 테스트가 남긴 파일이 다음 실행에 영향을 주지 않도록 지운다.
	DirAccess.remove_absolute(abs_path)
	print("test_save_data: OK")
	quit()

func _test_default_is_zero() -> void:
	assert(SaveData.load_high_score() == 0, "기록이 없으면 0")

func _test_submit_keeps_max() -> void:
	assert(SaveData.submit(500) == 500, "첫 기록은 그대로 저장")
	assert(SaveData.submit(200) == 500, "낮은 점수는 기록을 덮으면 안 된다")
	assert(SaveData.submit(900) == 900, "높은 점수는 기록을 갱신한다")

func _test_persists_across_reload() -> void:
	SaveData.save_high_score(1234)
	assert(SaveData.load_high_score() == 1234, "저장한 값을 다시 읽을 수 있어야 한다")

func _test_garbage_content() -> void:
	var f := FileAccess.open(SaveData.PATH, FileAccess.WRITE)
	f.store_string("이건 ConfigFile 형식이 아니다 {{{ ???")
	f.close()
	assert(SaveData.load_high_score() == 0, "손상된 파일이면 0을 반환해야 한다")
