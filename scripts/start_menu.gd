extends Control

func _ready() -> void:
	$Center/Menu/Start.pressed.connect(_on_start)
	$Center/Menu/Best.text = "최고 기록 %d" % SaveData.load_high_score()

func _on_start() -> void:
	GameConfig.size = GameConfig.SIZES[_selected($Center/Menu/Sizes)]
	GameConfig.difficulty = _selected($Center/Menu/Difficulty)
	# 씬을 바꾸기 전에 적용해야 한다. main.tscn 의 자식 노드들은 자기 _ready 에서
	# Board 의 크기를 읽어 뷰를 만들고, 자식 _ready 는 부모보다 먼저 돈다.
	GameConfig.apply()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# 눌린 버튼이 줄 안에서 몇 번째인지가 곧 선택 값이다.
func _selected(row: Container) -> int:
	for i in row.get_child_count():
		var b := row.get_child(i) as Button
		if b != null and b.button_pressed:
			return i
	return 0
