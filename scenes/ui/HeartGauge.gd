extends Control
class_name HeartGauge

## HPを❤(満タン)/♡(空)のハート記号を横に並べて表示する専用ゲージ。
## SegmentGauge(四角のバー)とインターフェースは同じ(set_value(filled, total))だが、
## 見た目がハート記号になる。
## A dedicated gauge for HP: draws a row of filled (❤) / empty (♡) heart glyphs.
## Same interface as SegmentGauge (set_value(filled, total)), just a different look.

@export var heart_font_size: int = 20
@export var gap: float = 2.0
@export var filled_color: Color = Color(0.9, 0.15, 0.2)
@export var empty_color: Color = Color(0.45, 0.45, 0.5)

const FILLED_GLYPH := "❤"
const EMPTY_GLYPH := "♡"

var total: int = 0
var filled: int = 0


func set_value(new_filled: int, new_total: int) -> void:
	filled = max(new_filled, 0)
	total = max(new_total, 0)
	var step := heart_font_size + gap
	custom_minimum_size = Vector2(
		total * step - (gap if total > 0 else 0.0),
		heart_font_size + 4.0
	)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var step := heart_font_size + gap
	for i in range(total):
		var glyph := FILLED_GLYPH if i < filled else EMPTY_GLYPH
		var color := filled_color if i < filled else empty_color
		var x := i * step
		draw_string(font, Vector2(x, heart_font_size), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, heart_font_size, color)
