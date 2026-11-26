@tool
extends EditorNode3DGizmoPlugin

const HANDLE_X = 0
const HANDLE_Y = 1
const HANDLE_Z = 2

var drag_state: Dictionary = {}


func _init():
    create_material("axis_x", Color(1, 0.2, 0.2))
    create_material("axis_y", Color(0.2, 1, 0.2))
    create_material("axis_z", Color(0.2, 0.5, 1))

    create_material("rotate_x", Color(1, 0.2, 0.2))
    create_material("rotate_y", Color(0.2, 1, 0.2))
    create_material("rotate_z", Color(0.2, 0.5, 1))

    create_handle_material("handles")


func _get_gizmo_name() -> String:
    return "SATISFY Transform Gizmo"


func _has_gizmo(node: Node3D) -> bool:
    return node is MeshInstance3D


func _redraw(gizmo: EditorNode3DGizmo):
    gizmo.clear()

    var handles := PackedVector3Array([
        Vector3(1.5, 0, 0),
        Vector3(0, 1.5, 0),
        Vector3(0, 0, 1.5)
    ])

    var x_axis := PackedVector3Array([
        Vector3.ZERO, handles[HANDLE_X]
    ])

    var y_axis := PackedVector3Array([
        Vector3.ZERO, handles[HANDLE_Y]
    ])

    var z_axis := PackedVector3Array([
        Vector3.ZERO, handles[HANDLE_Z]
    ])

    gizmo.add_lines(x_axis, get_material("axis_x", gizmo))
    gizmo.add_lines(y_axis, get_material("axis_y", gizmo))
    gizmo.add_lines(z_axis, get_material("axis_z", gizmo))

    gizmo.add_lines(
        _make_ring(HANDLE_X),
        get_material("rotate_x", gizmo)
    )
    gizmo.add_lines(
        _make_ring(HANDLE_Y),
        get_material("rotate_y", gizmo)
    )
    gizmo.add_lines(
        _make_ring(HANDLE_Z),
        get_material("rotate_z", gizmo)
    )

    gizmo.add_handles(
        handles,
        get_material("handles", gizmo),
        PackedInt32Array([HANDLE_X, HANDLE_Y, HANDLE_Z])
    )


func _make_ring(axis: int, radius: float = 2.0, segments: int = 64) -> PackedVector3Array:
    var points := PackedVector3Array()

    for i in range(segments):
        var a0 := TAU * float(i) / segments
        var a1 := TAU * float(i + 1) / segments

        var p0: Vector3
        var p1: Vector3

        if axis == HANDLE_X:
            p0 = Vector3(0, cos(a0) * radius, sin(a0) * radius)
            p1 = Vector3(0, cos(a1) * radius, sin(a1) * radius)
        elif axis == HANDLE_Y:
            p0 = Vector3(cos(a0) * radius, 0, sin(a0) * radius)
            p1 = Vector3(cos(a1) * radius, 0, sin(a1) * radius)
        else:
            p0 = Vector3(cos(a0) * radius, sin(a0) * radius, 0)
            p1 = Vector3(cos(a1) * radius, sin(a1) * radius, 0)

        points.append(p0)
        points.append(p1)

    return points


func _get_handle_name(
    gizmo: EditorNode3DGizmo,
    handle_id: int,
    secondary: bool
) -> String:
    match handle_id:
        HANDLE_X:
            return "Move X"
        HANDLE_Y:
            return "Move Y"
        HANDLE_Z:
            return "Move Z"

    return "Move"


func _begin_handle_action(
    gizmo: EditorNode3DGizmo,
    handle_id: int,
    secondary: bool
):
    var node = gizmo.get_node_3d()
    var local_axis := _get_local_axis(handle_id)

    drag_state = {
        "node": node,
        "start_position": node.global_position,
        "axis_origin": node.global_position,
        "axis_world": (node.global_transform.basis * local_axis).normalized(),
        "start_axis_offset": null
    }


func _get_local_axis(handle_id: int) -> Vector3:
    match handle_id:
        HANDLE_X:
            return Vector3.RIGHT
        HANDLE_Y:
            return Vector3.UP
        HANDLE_Z:
            return Vector3(0, 0, 1)

    return Vector3.ZERO


func _get_handle_value(
    gizmo: EditorNode3DGizmo,
    handle_id: int,
    secondary: bool
) -> Variant:
    return gizmo.get_node_3d().global_position


func _get_axis_offset(
    camera: Camera3D,
    screen_pos: Vector2,
    axis_origin: Vector3,
    axis_world: Vector3
) -> Variant:
    var ray_origin = camera.project_ray_origin(screen_pos)
    var ray_direction = camera.project_ray_normal(screen_pos).normalized()

    var b = ray_direction.dot(axis_world)
    var denominator = 1.0 - b * b

    if abs(denominator) < 0.00001:
        return null

    var offset = ray_origin - axis_origin
    var d = ray_direction.dot(offset)
    var e = axis_world.dot(offset)

    return (e - b * d) / denominator


func _set_handle(
    gizmo: EditorNode3DGizmo,
    handle_id: int,
    secondary: bool,
    camera: Camera3D,
    screen_pos: Vector2
):
    if drag_state.is_empty():
        return

    var node = drag_state.get("node")

    if not is_instance_valid(node):
        return

    var axis_origin: Vector3 = drag_state["axis_origin"]
    var axis_world: Vector3 = drag_state["axis_world"]

    var current_offset = _get_axis_offset(
        camera, screen_pos, axis_origin, axis_world
    )

    if current_offset == null:
        return

    if drag_state["start_axis_offset"] == null:
        drag_state["start_axis_offset"] = current_offset
        return

    var delta = current_offset - drag_state["start_axis_offset"]
    node.global_position = drag_state["start_position"] + axis_world * delta


func _commit_handle(
    gizmo: EditorNode3DGizmo,
    handle_id: int,
    secondary: bool,
    restore: Variant,
    cancel: bool
):
    var node = gizmo.get_node_3d()

    if not is_instance_valid(node):
        drag_state.clear()
        return

    var current_position = node.global_position

    if cancel:
        node.global_position = restore
    elif not current_position.is_equal_approx(restore):
        var undo_redo = EditorInterface.get_editor_undo_redo()

        undo_redo.create_action("SATISFY: Move Object")
        undo_redo.add_do_property(node, "global_position", current_position)
        undo_redo.add_undo_property(node, "global_position", restore)
        undo_redo.commit_action()

    drag_state.clear()
