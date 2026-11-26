@tool
extends EditorPlugin

var satisfy_dock: VBoxContainer


func _enter_tree():
    print("SATISFY EDITOR V0.2 LOADED")

    satisfy_dock = VBoxContainer.new()
    satisfy_dock.name = "SATISFY"
    satisfy_dock.custom_minimum_size = Vector2(220, 0)

    var title = Label.new()
    title.text = "SATISFY ENGINE"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    satisfy_dock.add_child(title)

    var subtitle = Label.new()
    subtitle.text = "GAME DEVELOPMENT TOOLS v0.2"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    satisfy_dock.add_child(subtitle)

    satisfy_dock.add_child(HSeparator.new())

    add_section("SCENE TOOLS")
    add_button("CREATE SCENE", _on_create_scene)

    add_section("3D OBJECTS")
    add_button("CREATE CUBE", _on_create_cube)
    add_button("CREATE SPHERE", _on_create_sphere)
    add_button("CREATE CYLINDER", _on_create_cylinder)

    add_section("LIGHTING")
    add_button("CREATE CAMERA", _on_create_camera)
    add_button("CREATE LIGHT", _on_create_light)

    add_control_to_dock(DOCK_SLOT_LEFT_UL, satisfy_dock)


func _exit_tree():
    if satisfy_dock:
        remove_control_from_docks(satisfy_dock)
        satisfy_dock.queue_free()


func add_section(section_name: String):
    var label = Label.new()
    label.text = section_name
    satisfy_dock.add_child(HSeparator.new())
    satisfy_dock.add_child(label)


func add_button(button_name: String, callback: Callable):
    var button = Button.new()
    button.text = button_name
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.pressed.connect(callback)
    satisfy_dock.add_child(button)


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
