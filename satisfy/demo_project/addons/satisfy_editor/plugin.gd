@tool
extends EditorPlugin

var satisfy_dock: VBoxContainer

func _enter_tree():
    print("SATISFY EDITOR PLUGIN LOADED")
    satisfy_dock = VBoxContainer.new()
    satisfy_dock.name = "SATISFY"

    var title = Label.new()
    title.text = "SATISFY ENGINE"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    satisfy_dock.add_child(title)

    var subtitle = Label.new()
    subtitle.text = "Game Development Tools v0.1"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    satisfy_dock.add_child(subtitle)

    satisfy_dock.add_child(HSeparator.new())

    var scene_button = Button.new()
    scene_button.text = "CREATE SCENE"
    scene_button.pressed.connect(_on_create_scene)
    satisfy_dock.add_child(scene_button)

    add_control_to_dock(DOCK_SLOT_LEFT_UL, satisfy_dock)


func _exit_tree():
    if satisfy_dock:
        remove_control_from_docks(satisfy_dock)
        satisfy_dock.queue_free()


func _on_create_scene():
    var scene = Node3D.new()
    scene.name = "MainScene"

    var packed = PackedScene.new()
    var result = packed.pack(scene)

    if result == OK:
        var error = ResourceSaver.save(
            packed,
            "res://MainScene.tscn"
        )
        if error == OK:
            print("SATISFY: MainScene created!")
        else:
            push_error("Failed to save scene.")
    else:
        push_error("Failed to create scene.")

    scene.free()
