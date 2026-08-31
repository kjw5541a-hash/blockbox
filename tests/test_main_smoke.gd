extends SceneTree

# 씬을 실제로 띄우고 몇 초 분량을 돌려, 렌더 코드가 게임 로직을 깨거나
# 예외를 던지지 않는지 확인한다. 그림이 예쁜지는 사람이 본다.
func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	assert(scene != null, "main.tscn 을 불러올 수 없다")
	var main: Node = scene.instantiate()
	root.add_child(main)
	await process_frame

	var game: Game = main.game
	assert(game != null, "main 이 Game 을 갖고 있어야 한다")
	assert(game.current != null, "시작하면 조각이 있어야 한다")

	for _i in 300:
		game.step(0.05)
		await process_frame
		if game.is_over:
			break

	assert(game.board.cells.size() == 224, "보드 크기가 유지되어야 한다")
	print("test_main_smoke: OK")
	quit()
