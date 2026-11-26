@tool
extends EditorPlugin

var satisfy_dock: VBoxContainer
var object_tree: Tree
var transform_fields: Dictionary = {}
var transform_rows: Dictionary = {}
var transform_mode_status: Label
var active_transform_mode: String = "MOVE"
var selected_object: Node3D
var rename_input: LineEdit
var inspector_info: Label
var selection_locked: bool = false
var visibility_button: Button
var visibility_status: Label
var lock_status: Label
var satisfy_gizmo: EditorNode3DGizmoPlugin


func _enter_tree():
    print("SATISFY EDITOR V1.3 LOADED")

    satisfy_gizmo = load(
        "res://addons/satisfy_editor/satisfy_transform_gizmo.gd"
    ).new()

    add_node_3d_gizmo_plugin(satisfy_gizmo)

    satisfy_dock = VBoxContainer.new()
    satisfy_dock.name = "SATISFY"
    satisfy_dock.custom_minimum_size = Vector2(260, 0)

    var title = Label.new()
    title.text = "SATISFY ENGINE"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    satisfy_dock.add_child(title)

    var subtitle = Label.new()
    subtitle.text = "SCENE BUILDER v1.1"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    satisfy_dock.add_child(subtitle)

    add_section("SCENE TOOLS")
    add_button("CREATE SCENE", _on_create_scene)
    add_button("OPEN 3D VIEWPORT", _on_open_3d_viewport)
    add_button("SELECT OBJECT", _on_select_in_viewport)
    add_button("FOCUS SELECTED", _on_focus_selected)

    add_section("3D OBJECTS")
    add_button("CREATE CUBE", _on_create_cube)
    add_button("CREATE SPHERE", _on_create_sphere)
    add_button("CREATE CYLINDER", _on_create_cylinder)

    add_section("LIGHTING")
    add_button("CREATE CAMERA", _on_create_camera)
    add_button("CREATE LIGHT", _on_create_light)

    add_section("OBJECT EXPLORER")

    object_tree = Tree.new()
    object_tree.custom_minimum_size = Vector2(240, 180)
    object_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    object_tree.hide_root = true
    object_tree.item_selected.connect(_on_object_selected)
    satisfy_dock.add_child(object_tree)

    add_button("REFRESH OBJECTS", refresh_objects)

    add_section("OBJECT INSPECTOR")

    inspector_info = Label.new()
    inspector_info.text = "Select an object to inspect."
    inspector_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    satisfy_dock.add_child(inspector_info)

    add_section("OBJECT ACTIONS")

    rename_input = LineEdit.new()
    rename_input.placeholder_text = "New object name"
    satisfy_dock.add_child(rename_input)

    add_button("RENAME OBJECT", _on_rename_object)
    add_button("DUPLICATE OBJECT", _on_duplicate_object)
    add_button("DELETE OBJECT", _on_delete_object)

    add_section("VISIBILITY & LOCK")

    visibility_button = Button.new()
    visibility_button.text = "HIDE OBJECT"
    visibility_button.pressed.connect(_on_toggle_visibility)
    visibility_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    satisfy_dock.add_child(visibility_button)

    visibility_status = Label.new()
    visibility_status.text = "Visibility: NO OBJECT"
    satisfy_dock.add_child(visibility_status)

    add_button("LOCK SELECTION", _on_lock_selection)
    add_button("UNLOCK SELECTION", _on_unlock_selection)

    lock_status = Label.new()
    lock_status.text = "Selection: UNLOCKED"
    satisfy_dock.add_child(lock_status)

    add_section("TRANSFORM TOOLS")

    add_button("MOVE", _on_move_mode)
    add_button("ROTATE", _on_rotate_mode)
    add_button("SCALE", _on_scale_mode)

    transform_mode_status = Label.new()
    transform_mode_status.text = "Mode: MOVE"
    satisfy_dock.add_child(transform_mode_status)

    create_transform_row("Position", "position")
    create_transform_row("Rotation", "rotation")
    create_transform_row("Scale", "scale")

    _set_transform_mode("MOVE")

    add_button("APPLY TRANSFORM", _on_apply_transform)

    add_control_to_dock(DOCK_SLOT_LEFT_UL, satisfy_dock)


func _exit_tree():
    if satisfy_gizmo:
        remove_node_3d_gizmo_plugin(satisfy_gizmo)
        satisfy_gizmo = null

    if satisfy_dock:
        remove_control_from_docks(satisfy_dock)
        satisfy_dock.queue_free()


func add_section(section_name: String):
    satisfy_dock.add_child(HSeparator.new())

    var label = Label.new()
    label.text = section_name
    satisfy_dock.add_child(label)


func add_button(button_name: String, callback: Callable):
    var button = Button.new()
    button.text = button_name
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.pressed.connect(callback)
    satisfy_dock.add_child(button)


func create_transform_row(label_text: String, key: String):
    var row = HBoxContainer.new()

    var label = Label.new()
    label.text = label_text
    label.custom_minimum_size = Vector2(65, 0)
    row.add_child(label)

    var fields: Array[SpinBox] = []

    for axis in ["X", "Y", "Z"]:
        var field = SpinBox.new()
        field.min_value = -10000
        field.max_value = 10000
        field.step = 0.1
        field.custom_minimum_size = Vector2(55, 0)
        field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        field.tooltip_text = axis
        row.add_child(field)
        fields.append(field)

    transform_fields[key] = fields
    transform_rows[key] = row
    satisfy_dock.add_child(row)


func _set_transform_mode(mode: String):
    active_transform_mode = mode
    transform_mode_status.text = "Mode: " + mode

    for key in transform_rows:
        transform_rows[key].visible = (
            (mode == "MOVE" and key == "position") or
            (mode == "ROTATE" and key == "rotation") or
            (mode == "SCALE" and key == "scale")
        )


func _on_move_mode():
    _set_transform_mode("MOVE")


func _on_rotate_mode():
    _set_transform_mode("ROTATE")


func _on_scale_mode():
    _set_transform_mode("SCALE")


func refresh_objects():
    if object_tree == null:
        return

    object_tree.clear()
    selected_object = null
    _update_visibility_controls()

    var root = get_editor_interface().get_edited_scene_root()

    if root == null:
        return

    var tree_root = object_tree.create_item()
    tree_root.set_text(0, str(root.name))
    tree_root.set_metadata(0, root)
    _add_object_items(root, tree_root)
    tree_root.collapsed = false


func _add_object_items(node: Node, parent_item: TreeItem):
    for child in node.get_children():
        var item = object_tree.create_item(parent_item)
        item.set_text(0, child.name)
        item.set_metadata(0, child)

        if child is Node3D:
            item.set_text(0, "3D: " + child.name)

        _add_object_items(child, item)


func _on_object_selected():
    var item = object_tree.get_selected()

    if item == null:
        return

    var node = item.get_metadata(0)

    if not is_instance_valid(node):
        return

    if selection_locked:
        return

    if node is Node3D:
        selected_object = node
        _load_transform(node)

        var editor_selection = get_editor_interface().get_selection()
        editor_selection.clear()
        editor_selection.add_node(node)
    else:
        selected_object = null

    if rename_input != null:
        if node is Node3D:
            rename_input.text = str(node.name)
        else:
            rename_input.clear()

    _update_inspector(node)
    _update_visibility_controls()


func _load_transform(node: Node3D):
    _set_fields("position", node.position)
    _set_fields("rotation", node.rotation_degrees)
    _set_fields("scale", node.scale)


func _set_fields(key: String, value: Vector3):
    var fields = transform_fields[key]
    fields[0].value = value.x
    fields[1].value = value.y
    fields[2].value = value.z


func _read_fields(key: String) -> Vector3:
    var fields = transform_fields[key]

    return Vector3(
        fields[0].value,
        fields[1].value,
        fields[2].value
    )


func _on_apply_transform():
    if not is_instance_valid(selected_object):
        push_warning("Select a 3D object first.")
        return

    var node = selected_object

    var undo = get_undo_redo()
    undo.create_action("SATISFY: Apply Transform")

    undo.add_do_property(node, "position", _read_fields("position"))
    undo.add_do_property(node, "rotation_degrees", _read_fields("rotation"))
    undo.add_do_property(node, "scale", _read_fields("scale"))

    undo.add_undo_property(node, "position", node.position)
    undo.add_undo_property(node, "rotation_degrees", node.rotation_degrees)
    undo.add_undo_property(node, "scale", node.scale)

    undo.commit_action()


func add_node_to_scene(node: Node):
    var root = get_editor_interface().get_edited_scene_root()

    if root == null:
        push_warning("Open or create a scene first.")
        node.free()
        return

    var undo = get_undo_redo()
    undo.create_action("SATISFY: Add " + node.name)
    undo.add_do_method(root, "add_child", node)
    undo.add_do_method(node, "set_owner", root)
    undo.add_undo_method(root, "remove_child", node)
    undo.commit_action()

    refresh_objects()



func _on_rename_object():
    if not is_instance_valid(selected_object):
        push_warning("Select an object first.")
        return

    var new_name = rename_input.text.strip_edges()

    if new_name.is_empty():
        push_warning("Enter a new object name.")
        return

    var node = selected_object
    var old_name = node.name

    if new_name == str(old_name):
        return

    var undo = get_undo_redo()
    undo.create_action("SATISFY: Rename Object")
    undo.add_do_property(node, "name", new_name)
    undo.add_undo_property(node, "name", old_name)
    undo.commit_action()

    rename_input.clear()
    refresh_objects()
    print("SATISFY: Object renamed to ", new_name)


func _on_duplicate_object():
    if not is_instance_valid(selected_object):
        push_warning("Select an object first.")
        return

    var original = selected_object
    var parent = original.get_parent()
    var root = get_editor_interface().get_edited_scene_root()

    if parent == null or root == null:
        return

    var copy = original.duplicate()
    if copy == null:
        push_error("Could not duplicate object.")
        return

    var base_name = str(original.name) + "_Copy"
    var copy_name = base_name
    var number = 2

    while parent.has_node(NodePath(copy_name)):
        copy_name = base_name + str(number)
        number += 1

    copy.name = copy_name

    var undo = get_undo_redo()
    undo.create_action("SATISFY: Duplicate Object")
    undo.add_do_method(parent, "add_child", copy)
    undo.add_do_method(self, "_set_owner_recursive", copy, root)
    undo.add_undo_method(parent, "remove_child", copy)
    undo.commit_action()

    selected_object = copy
    refresh_objects()
    print("SATISFY: Duplicated ", original.name)


func _on_delete_object():
    if not is_instance_valid(selected_object):
        push_warning("Select an object first.")
        return

    var node = selected_object
    var parent = node.get_parent()
    var root = get_editor_interface().get_edited_scene_root()

    if parent == null or node == root:
        push_warning("Cannot delete the scene root.")
        return

    var old_index = node.get_index()

    var undo = get_undo_redo()
    undo.create_action("SATISFY: Delete Object")
    undo.add_do_method(parent, "remove_child", node)
    undo.add_undo_method(
        self,
        "_restore_deleted_node",
        parent,
        node,
        old_index,
        root
    )
    undo.commit_action()

    selected_object = null
    refresh_objects()
    print("SATISFY: Object deleted")


func _restore_deleted_node(
    parent: Node,
    node: Node,
    old_index: int,
    root: Node
):
    parent.add_child(node)
    parent.move_child(node, old_index)
    _set_owner_recursive(node, root)


func _set_owner_recursive(node: Node, root: Node):
    node.owner = root

    for child in node.get_children():
        _set_owner_recursive(child, root)


func _on_create_scene():
    var scene = Node3D.new()
    scene.name = "MainScene"

    var packed = PackedScene.new()
    var result = packed.pack(scene)

    if result == OK:
        var error = ResourceSaver.save(packed, "res://MainScene.tscn")

        if error == OK:
            print("SATISFY: MainScene created!")
        else:
            push_error("Failed to save scene.")
    else:
        push_error("Failed to create scene.")

    scene.free()


func _on_create_cube():
    var node = MeshInstance3D.new()
    node.name = "Cube"
    node.mesh = BoxMesh.new()
    add_node_to_scene(node)


func _on_create_sphere():
    var node = MeshInstance3D.new()
    node.name = "Sphere"
    node.mesh = SphereMesh.new()
    add_node_to_scene(node)


func _on_create_cylinder():
    var node = MeshInstance3D.new()
    node.name = "Cylinder"
    node.mesh = CylinderMesh.new()
    add_node_to_scene(node)


func _on_create_camera():
    var node = Camera3D.new()
    node.name = "Camera3D"
    node.position = Vector3(0, 3, 6)
    node.look_at_from_position(node.position, Vector3.ZERO)
    add_node_to_scene(node)


func _on_create_light():
    var node = DirectionalLight3D.new()
    node.name = "DirectionalLight3D"
    add_node_to_scene(node)


func _on_open_3d_viewport():
    get_editor_interface().set_main_screen_editor("3D")
    print("SATISFY: 3D VIEWPORT OPENED")


func _on_select_in_viewport():
    if not is_instance_valid(selected_object):
        push_warning("Select a 3D object first.")
        return

    var editor_selection = get_editor_interface().get_selection()
    editor_selection.clear()
    editor_selection.add_node(selected_object)

    get_editor_interface().set_main_screen_editor("3D")
    print("SATISFY: Object selected in native viewport")


func _on_focus_selected():
    if not is_instance_valid(selected_object):
        push_warning("Select a 3D object first.")
        return

    get_editor_interface().set_main_screen_editor("3D")
    _focus_selected_deferred.call_deferred()


func _focus_selected_deferred():
    if not is_instance_valid(selected_object):
        return

    var viewport = get_editor_interface().get_editor_viewport_3d(0)

    if viewport == null:
        push_warning("3D editor viewport is not available.")
        return

    var camera = viewport.get_camera_3d()

    if camera == null:
        push_warning("3D editor camera is not available.")
        return

    var target = selected_object.global_position
    camera.global_position = target + Vector3(4, 3, 4)
    camera.look_at(target, Vector3.UP)

    print("SATISFY: Viewport focused on ", selected_object.name)


func _update_inspector(node: Node):
    if inspector_info == null:
        return

    if not is_instance_valid(node):
        inspector_info.text = "Select an object to inspect."
        return

    var parent_name = "None"
    if node.get_parent() != null:
        parent_name = str(node.get_parent().name)

    var info = (
        "Name: " + str(node.name) + "\n" +
        "Type: " + node.get_class() + "\n" +
        "Parent: " + parent_name
    )

    if node is Node3D:
        info += (
            "\nVisibility: " + ("VISIBLE" if node.visible else "HIDDEN") +
            "\nPosition: " + str(node.position) +
            "\nRotation: " + str(node.rotation_degrees) +
            "\nScale: " + str(node.scale)
        )

    inspector_info.text = info

func _update_visibility_controls():
    if visibility_button == null or visibility_status == null:
        return

    if not is_instance_valid(selected_object):
        visibility_button.text = "HIDE OBJECT"
        visibility_button.disabled = true
        visibility_status.text = "Visibility: NO OBJECT"
        return

    visibility_button.disabled = false

    if selected_object.visible:
        visibility_button.text = "HIDE OBJECT"
        visibility_status.text = "Visibility: VISIBLE"
    else:
        visibility_button.text = "SHOW OBJECT"
        visibility_status.text = "Visibility: HIDDEN"


func _on_toggle_visibility():
    if not is_instance_valid(selected_object):
        _update_visibility_controls()
        return

    selected_object.visible = not selected_object.visible
    _update_visibility_controls()
    _update_inspector(selected_object)


func _on_lock_selection():
    selection_locked = true
    lock_status.text = "Selection: LOCKED"
    print("SATISFY: Selection locked")


func _on_unlock_selection():
    selection_locked = false
    lock_status.text = "Selection: UNLOCKED"
    print("SATISFY: Selection unlocked")
