@tool
extends EditorImportPlugin

const AndroidCodeResource = preload("coderesource.gd")


func _get_importer_name():
	return "androidcode"

func _get_visible_name():
	return "Import Android code and make plugins"

func _get_recognized_extensions():
	return ["kt","java"]

func _get_save_extension():
	return "res"

func _get_resource_type():
	return "Resource"

func _get_preset_count():
	return 0

func _get_preset_name(preset_index):
	return "Default"

func _get_import_options(path, preset_index):
	return [{"name": "make_plugin", "default_value": true},	{"name":"extra_maven_deps","default_value":""},
	{"name":"plugin_description","default_value":"Generated plugin"},
	{"name":"plugin_version","default_value":"1.0"},
	{"name":"plugin_author","default_value":"Jo Bloggs"}
	]

func do_build(params,coderesource,filename):
	var pipes = OS.execute_with_pipe("pwsh.exe",params,false)
	print(pipes)
	var stdio = pipes["stdio"]
	var stderr = pipes["stderr"]
	var pid = pipes["pid"]
	while(OS.is_process_running(pid)):
		var io_line = stdio.get_line()
		if stdio.get_error()==OK:
			print(io_line)
		var err_line = stderr.get_line()
		if stderr.get_error()==OK:
			print(err_line)
		OS.delay_msec(5)
	var rcode = OS.get_process_exit_code(pid)
	var io_line = stdio.get_line()
	if stdio.get_error()==OK:
		print(io_line)
	var err_line = stderr.get_line()
	if stderr.get_error()==OK:
		print(err_line)
	
	if rcode==0:
		coderesource.built=true
	else:
		coderesource.built=false
	print(coderesource,coderesource.built)
	print("Saving: rcode = ",rcode)
	ResourceSaver.save(coderesource, filename)

func _import(source_file, save_path, options, platform_variants, gen_files):
	if options["make_plugin"]==false:
		print("Not making android plugin")
		return OK
	print(options)
	var file = FileAccess.open(source_file, FileAccess.READ)
	if file == null:
		return FAILED
	# Initialize the resource
	var coderesource = AndroidCodeResource.new(file.get_as_text())
	var filename = save_path + "." + _get_save_extension()
	
	var plugin_name = source_file.get_file().get_basename()
	var build_folder = ProjectSettings.globalize_path("res://.godot/generated/"+plugin_name)
	var install_folder = ProjectSettings.globalize_path("res://addons/generated_"+plugin_name)
	var create_plugin_script = ProjectSettings.globalize_path("res://addons/androidcodeimporter/create_plugin_project.ps1")
	 	# build an AAR
	var params = ["-Command",create_plugin_script,"-SourceFile",ProjectSettings.globalize_path(source_file),"-TargetFolder",build_folder,"-PluginName",plugin_name,"-Description",
	  options["plugin_description"],"-Author",options["plugin_author"],"-Version",options["plugin_version"],"-InstallFolder",install_folder,"-MavenDependencies",options["extra_maven_deps"]]
	print(params)
	var output = []
	var call_bound = do_build.bind(params,coderesource,filename)
	var thread = Thread.new()
	thread.start(call_bound)
	var last_output = []
	return ResourceSaver.save(coderesource, filename)
