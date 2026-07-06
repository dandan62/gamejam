extends Control
class_name SegmentGauge

## 一定数のセグメント(四角)を横に並べて描画し、filledの数だけ塗りつぶす簡易ゲージ。
## HP/ライト/行動力など、正確な数値よりも残量の目安を見せたい表示に使う。
## Draws a row of segment boxes and fills the leftmost `filled` of them.
## Used for HP/light/action-points displays where an at-a-glance remaining
## amount matters more than the exact number.

@export var segment_size: Vector2 = Vector2(14, 16)
@export var segment_gap: float = 3.0
@export var filled_color: Color = Color(0.85, 0.25, 0.25)
@export var empty_color: Color = Color(0.25, 0.25, 0.28)

var total: int = 0
var filled: int = 0


func set_value(new_filled: int, new_total: int) -> void:
	filled = max(new_filled, 0)
	total = max(new_total, 0)
	custom_minimum_size = Vector2(
		total * segment_size.x + max(total - 1, 0) * segment_gap,
		segment_size.y
	)
	queue_redraw()


func _draw() -> void:
	for i in range(total):
		var x := i * (segment_size.x + segment_gap)
		var rect := Rect2(Vector2(x, 0), segment_size)
		var color := filled_color if i < filled else empty_color
		draw_rect(rect, color)
		draw_rect(rect, Color(0, 0, 0, 0.6), false, 1.5)
