extends Control
class_name BatteryGauge

## ライトを「電池アイコンを1目盛りにつき1個ずつ並べる」ゲージとして表示する。
## HeartGauge(❤/♡を並べる)と同じ考え方で、total個の電池アイコンを横に並べ、
## 左からfilled個だけ満タン(緑)、残りは空(灰)の電池として描く。
## Draws Light as a row of individual battery icons, one per point of the gauge -- same idea
## as HeartGauge (a row of ❤/♡), but each icon is a small battery shape. `total` icons are
## drawn; the leftmost `filled` are shown full (green), the rest empty (gray).

@export var battery_size: Vector2 = Vector2(24, 16)
@export var gap: float = 3.0
@export var fill_color: Color = Color(0.3, 0.8, 0.4)
@export var empty_color: Color = Color(0.2, 0.2, 0.24)
@export var border_color: Color = Color(0, 0, 0, 0.7)
@export var border_width: float = 1.5
@export var nub_width: float = 3.0
@export var nub_height_ratio: float = 0.5

var total: int = 0
var filled: int = 0


func set_value(new_filled: int, new_total: int) -> void:
	filled = max(new_filled, 0)
	total = max(new_total, 0)
	var step := battery_size.x + nub_width + gap
	custom_minimum_size = Vector2(
		total * step - (gap if total > 0 else 0.0),
		battery_size.y
	)
	queue_redraw()


func _draw() -> void:
	var step := battery_size.x + nub_width + gap
	for i in range(total):
		var x := i * step
		_draw_one_battery(x, i < filled)


func _draw_one_battery(x: float, is_filled: bool) -> void:
	var body_rect := Rect2(Vector2(x, 0), battery_size)
	draw_rect(body_rect, fill_color if is_filled else empty_color)
	draw_rect(body_rect, border_color, false, border_width)

	var nub_height := battery_size.y * nub_height_ratio
	var nub_rect := Rect2(
		Vector2(x + battery_size.x + 1.0, (battery_size.y - nub_height) / 2.0),
		Vector2(nub_width, nub_height)
	)
	draw_rect(nub_rect, fill_color if is_filled else border_color)
