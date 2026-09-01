extends SceneTree

# 웹 빌드에는 시스템 폰트가 없다. Godot 내장 폰트에 한글 글리프가 없으므로
# 폰트를 직접 넣지 않으면 아이폰 사파리에서 한글이 전부 두부로 나온다.
# 맥에서는 OS 폰트로 대체되어 이 문제가 드러나지 않는다 — 그래서 테스트가 필요하다.
#
# 폰트는 실제로 쓰는 글자만 남긴 부분집합이라, 문구를 새로 쓰면 그 글자가
# 빠져 있을 수 있다. 화면에 나갈 만한 글자를 전부 훑어 확인한다.
# 다시 뜨는 방법은 assets/fonts/README.md 에 있다.
func _initialize() -> void:
	_test_setting_points_at_the_font()
	_test_font_covers_every_string_literal()
	print("test_font: OK")
	quit()

func _font_path() -> String:
	return str(ProjectSettings.get_setting("gui/theme/custom_font", ""))

func _test_setting_points_at_the_font() -> void:
	var path := _font_path()
	assert(path != "", "gui/theme/custom_font 이 비어 있으면 웹에서 한글이 깨진다")
	assert(ResourceLoader.exists(path), "폰트 파일이 없다: %s" % path)
	var size: int = ProjectSettings.get_setting("gui/theme/default_font_size", 16)
	# 720x1280 뷰포트가 폰 화면 폭으로 줄어든다. 기본 16 이면 손바닥에서 못 읽는다.
	assert(size >= 30, "기본 글자 크기가 폰에서 읽기엔 작다: %d" % size)

func _test_font_covers_every_string_literal() -> void:
	var font: Font = load(_font_path())
	assert(font != null, "폰트를 불러올 수 없다: %s" % _font_path())
	var missing := {}
	for dir in ["res://scenes", "res://scripts"]:
		for name in DirAccess.get_files_at(dir):
			if not (name.ends_with(".tscn") or name.ends_with(".gd")):
				continue
			var where := "%s/%s" % [dir, name]
			for c in _literal_chars(where):
				if not font.has_char(c.unicode_at(0)):
					missing[c] = where
	assert(missing.is_empty(),
		"부분집합 폰트에 없는 글자가 문자열에 들어 있다 (두부로 나온다): %s" % missing)

# 큰따옴표 안의 글자만 모은다. 주석 줄은 건너뛴다 — 화면에 나가지 않는다.
# 큰따옴표가 홀수 개인 줄은 없다고 본다(코드베이스에 이스케이프된 따옴표가 없다).
func _literal_chars(path: String) -> Dictionary:
	var out := {}
	var text := FileAccess.get_file_as_string(path)
	assert(text != "", "파일을 읽을 수 없다: %s" % path)
	for line in text.split("\n"):
		var s := line.strip_edges()
		if s.begins_with("#") or s.begins_with(";"):
			continue
		var parts := line.split("\"")
		for i in range(1, parts.size(), 2):
			for c in parts[i]:
				out[c] = true
	return out
