extends SubViewportContainer
class_name Dice3D

## 2D6を3D表示でトス演出するミニビューポート。
## 各ダイスは立方体+6面それぞれにLabel3D(1〜6、対面の和が7になる標準配置)を
## 子ノードとして持たせ、出目に応じた面が正面(+Z、カメラ側)を向く回転へ
## ランダムな余分回転を足してTweenで一気に回す。
## Mini viewport that shows a 3D toss animation for a 2D6 roll.
## Each die is a cube with a Label3D (1-6, standard layout where opposite faces sum to 7)
## as a child on each of its 6 faces. It's spun with a Tween toward the rotation that puts
## the rolled face forward (+Z, toward the camera), plus extra random spins for flourish.

signal roll_finished

const FACE_ROTATIONS := {
	1: Vector3(0, 0, 0),
	2: Vector3(0, -90, 0),
	3: Vector3(90, 0, 0),
	4: Vector3(-90, 0, 0),
	5: Vector3(0, 90, 0),
	6: Vector3(0, 180, 0),
}

var _die_a: Node3D
var _die_b: Node3D
var _tweens_running := 0


func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(220, 140)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(440, 280)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	add_child(viewport)

	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0, 0.8, 2.6)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	viewport.add_child(light)

	_die_a = _build_die()
	_die_a.position = Vector3(-0.8, 0, 0)
	viewport.add_child(_die_a)

	_die_b = _build_die()
	_die_b.position = Vector3(0.8, 0, 0)
	viewport.add_child(_die_b)


func _build_die() -> Node3D:
	var root := Node3D.new()

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	mesh_instance.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.95, 0.9)
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)

	var face_defs := [
		{"text": "1", "pos": Vector3(0, 0, 0.51), "rot": Vector3(0, 0, 0)},
		{"text": "6", "pos": Vector3(0, 0, -0.51), "rot": Vector3(0, 180, 0)},
		{"text": "2", "pos": Vector3(0.51, 0, 0), "rot": Vector3(0, 90, 0)},
		{"text": "5", "pos": Vector3(-0.51, 0, 0), "rot": Vector3(0, -90, 0)},
		{"text": "3", "pos": Vector3(0, 0.51, 0), "rot": Vector3(-90, 0, 0)},
		{"text": "4", "pos": Vector3(0, -0.51, 0), "rot": Vector3(90, 0, 0)},
	]
	for def in face_defs:
		var label := Label3D.new()
		label.text = def["text"]
		label.position = def["pos"]
		label.rotation_degrees = def["rot"]
		label.font_size = 140
		label.pixel_size = 0.003
		label.modulate = Color(0.1, 0.1, 0.15)
		label.no_depth_test = false
		root.add_child(label)

	return root


func roll(d1: int, d2: int) -> void:
	_tweens_running = 0
	_animate_die(_die_a, d1)
	_animate_die(_die_b, d2)


func _animate_die(die: Node3D, value: int) -> void:
	var base: Vector3 = FACE_ROTATIONS.get(value, Vector3.ZERO)
	var extra := Vector3(
		360.0 * randi_range(2, 3),
		360.0 * randi_range(2, 3),
		360.0 * randi_range(1, 2)
	)
	die.rotation_degrees = Vector3.ZERO
	_tweens_running += 1
	var tween := die.create_tween()
	tween.tween_property(die, "rotation_degrees", base + extra, 0.9) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_die_tween_finished)


func _on_die_tween_finished() -> void:
	_tweens_running -= 1
	if _tweens_running <= 0:
		roll_finished.emit()
