@tool
extends EditorPlugin

var satisfy_dock: VBoxContainer
var object_tree: Tree
var transform_fields: Dictionary = {}
var selected_object: Node3D


func _enter_tree():
    print("SATISFY EDITOR V0.3 LOADED")

    satisfy_dock = VBoxContainer.new()
    satisfy_dock.name = "SATISFY"
    satisfy_dock.custom_minimum_size = Vector2(260, 0)

    var title = Label.new()
    title.text = "SATISFY ENGINE"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    satisfy_dock.add_child(title)

    var subtitle = Label.new()
    subtitle.text = "SCENE BUILDER v0.3"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    satisfy_dock.add_child(subtitle)

    add_section("SCENE TOOLS")
    add_button("CREATE SCENE", _on_create_scene)

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

    add_section("TRANSFORM TOOLS")

    create_transform_row("Position", "position")
    create_transform_row("Rotation", "rotation")
    create_transform_row("Scale", "scale")

    add_button("APPLY TRANSFORM", _on_apply_transform)

    add_control_to_dock(DOCK_SLOT_LEFT_UL, satisfy_dock)


func _exit_tree():
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
    satisfy_dock.add_child(row)


func refresh_objects():
    if object_tree == null:
        return

    object_tree.clear()
    selected_object = null

    var root = get_editor_interface().get_edited_scene_root()

    if root == null:
        return

    var tree_root = object_tree.create_item()
    _add_object_items(root, tree_root)


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

    if node is Node3D:
        selected_object = node
        _load_transform(node)

        var editor_selection = get_editor_interface().get_selection()
        editor_selection.clear()
        editor_selection.add_node(node)
    else:
        selected_object = null


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
