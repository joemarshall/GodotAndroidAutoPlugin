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

#func _handles(object):
	#for x in object.get_property_list():
		#if x["name"]=="coderesource.gd":
			#return true
		##print(x,object.get(x["name"]))
#
#func _edit(object):
	#print(object.get("resource_path"))
	#var res_path = ProjectSettings.globalize_path(object.get("resource_path"))
	#print(res_path)	
	#OS.shell_open(res_path)
