@tool
extends EditorPlugin

var _importer: EditorImportPlugin

const AndroidCodeResource = preload("coderesource.gd")

func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	_importer = preload("create_plugin.gd").new()
	add_import_plugin(_importer)

func _exit_tree() -> void:
	remove_import_plugin(_importer)
	_importer = null
