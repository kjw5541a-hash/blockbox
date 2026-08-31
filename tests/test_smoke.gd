extends SceneTree

func _initialize() -> void:
	assert(1 + 1 == 2, "산술이 깨졌다")
	print("test_smoke: OK")
	quit()
