extends SceneTree

# 어두운 배경 위의 시작 화면이 폰에서 잘 안 읽힌다는 지적을 받았다.
# 눈으로 보는 건 사람 몫이지만, "묻힌다"는 건 결국 밝기 차이라서 숫자로
# 바닥선을 정해 둘 수 있다. 여기서 지키는 건 그 바닥선이다.
func _initialize() -> void:
	_test_font_is_bold()
	await _test_buttons_stand_out_from_the_background()
	await _test_text_is_big_enough_to_read()
	print("test_ui_readability: OK")
	quit()

func _menu() -> Control:
	var m: Control = load("res://scenes/start.tscn").instantiate()
	root.add_child(m)
	return m

func _test_font_is_bold() -> void:
	var theme: Theme = load(str(ProjectSettings.get_setting("gui/theme/custom", "")))
	var font: Font = theme.default_font
	assert(font is FontVariation,
		"굵기를 주려면 FontVariation 이어야 한다: %s" % font.get_class())
	assert((font as FontVariation).variation_embolden >= 0.2,
		"글씨가 충분히 굵지 않다: %f" % (font as FontVariation).variation_embolden)

func _test_buttons_stand_out_from_the_background() -> void:
	var menu := _menu()
	await process_frame
	var back: Color = (menu.get_node("Background") as ColorRect).color
	var button: Button = menu.get_node("Center/Menu/Sizes/S4")

	var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
	var pressed := button.get_theme_stylebox("pressed") as StyleBoxFlat
	assert(normal != null and pressed != null, "버튼 바탕이 StyleBoxFlat 이어야 한다")

	var gap := absf(normal.bg_color.get_luminance() - back.get_luminance())
	assert(gap >= 0.08, "버튼이 배경에 묻힌다 (밝기 차 %f)" % gap)

	# 통 크기와 난이도는 눌린 상태로만 구분된다. 안 고른 것과 확실히 달라야 한다.
	var picked := absf(pressed.bg_color.get_luminance() - normal.bg_color.get_luminance())
	assert(picked >= 0.15, "고른 버튼이 안 고른 것과 구분되지 않는다 (밝기 차 %f)" % picked)

	assert(normal.border_width_left >= 1 and normal.border_width_top >= 1,
		"테두리가 없으면 버튼 경계가 흐려진다")
	var edge := absf(normal.border_color.get_luminance() - normal.bg_color.get_luminance())
	assert(edge >= 0.03, "테두리가 바탕과 같은 밝기라 보이지 않는다 (밝기 차 %f)" % edge)

	var ink := absf(button.get_theme_color("font_color").get_luminance()
		- normal.bg_color.get_luminance())
	assert(ink >= 0.3, "글자가 버튼 바탕에 묻힌다 (밝기 차 %f)" % ink)
	menu.queue_free()

func _test_text_is_big_enough_to_read() -> void:
	var menu := _menu()
	await process_frame
	# 설정값이 아니라 실제로 라벨이 쓰는 크기를 본다. ProjectSettings 의
	# gui/theme/default_font_size 는 36 으로 적어 두어도 먹지 않아서, 설정값만
	# 보는 검사는 통과하는데 화면은 16pt 로 나왔다.
	var best: Label = menu.get_node("Center/Menu/Best")
	assert(best.get_theme_default_font_size() >= 30,
		"기본 글자 크기가 폰에서 읽기엔 작다: %d" % best.get_theme_default_font_size())
	# 크기를 준 것과 실제로 그만큼 그려지는 것은 다르다. 높이로 확인한다.
	assert(best.get_minimum_size().y >= 40,
		"글자가 실제로는 작게 그려지고 있다 (높이 %f)" % best.get_minimum_size().y)
	# 버전 표시만 예외다 - 일부러 흐리게 깔아 둔 빌드 표식이다.
	var hint: Label = menu.get_node("Center/Menu/Hint")
	var hint_size: int = hint.get_theme_font_size("font_size")
	assert(hint_size >= 30, "설명 글자가 폰에서 읽기엔 작다: %d" % hint_size)
	menu.queue_free()
