@tool
extends EditorImportPlugin

const AndroidCodeResource = preload("coderesource.gd")

var active_tasks = {}

func _get_importer_name():
	return "androidcode"

func _get_visible_name():
	return "Make android plugins"

func _get_recognized_extensions():
	return ["kt","java"]

func _get_save_extension():
	return "res"

func _get_resource_type():
	return "Resource"

func _get_preset_count():
	return 2

func _get_preset_name(preset_index):
	if preset_index==0:
		return "Don't build"
	else:
		return "Make Android plugin"

func _get_import_options(path, preset_index):
	var companion_script= path.get_basename()+".gd"
	var basename = path.get_file().get_basename()
	var generated_default_value="generated_"+basename
	if !FileAccess.file_exists(companion_script):
		companion_script=""
	else:
		companion_script = "./"+basename + ".gd"
	return [{"name": "make_plugin", "default_value": preset_index==1},	{"name":"extra_maven_deps","default_value":""},
	{"name":"plugin_description","default_value":"Generated plugin"},
	{"name":"plugin_version","default_value":"1.0"},
	{"name":"plugin_author","default_value":"Jo Bloggs"},
	{"name":"plugin_name","default_value":generated_default_value},
	{"name":"auto_enable_plugin","default_value":true},
	{"name":"godot_interface_script","default_value":companion_script,"property_hint":PROPERTY_HINT_RESOURCE_TYPE,"hint_string":"Script"}
	]

func do_build(params,coderesource,filename,auto_enable,plugin_name,currently_enabled):
	var executable = "pwsh.exe" if OS.get_name() == "Windows" else "bash"
	var pipes = OS.execute_with_pipe(executable,params,false)
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
	if auto_enable:
		EditorInterface.call_deferred("set_plugin_enabled",plugin_name,coderesource.built)
	elif currently_enabled:
		EditorInterface.call_deferred("set_plugin_enabled",plugin_name,true)
	if coderesource.built:
		print("********************* Built plugin successfully *********************")
	else:
		push_error("********************* Error building plugin *********************")
	ResourceSaver.save(coderesource, filename)
	call_deferred("_wait_for_thread_end",true,filename)

func _wait_for_thread_end(can_block,filename):
	if active_tasks==null:
		active_tasks={}
	var _thread = active_tasks.get(filename)
	if _thread == null:
		return true
	if WorkerThreadPool.is_task_completed(_thread):
		return true
	if can_block:
		WorkerThreadPool.wait_for_task_completion(_thread)
		return true	
	return false

func _quotify(str):
	if str.begins_with("-"):
		return str
	if str.begins_with('"'):
		return str
	if str.find(" ")==-1:
		return str
	else:
		return '\\"'+str+'\\"'

func _import(source_file, save_path, options, platform_variants, gen_files):
	if options["make_plugin"]==false:
		print("Not making android plugin")
		return OK
	var file = FileAccess.open(source_file, FileAccess.READ)
	if file == null:
		return FAILED
	# Initialize the resource
	var coderesource = AndroidCodeResource.new(file.get_as_text())
	var filename = save_path + "." + _get_save_extension()
	if not _wait_for_thread_end(false,filename):
		push_error("Already building plugin ",filename,", wait for it to finish")
		return FAILED
	
	var plugin_name = options["plugin_name"].replace(" ","_")

	var currently_enabled = EditorInterface.is_plugin_enabled(plugin_name)
	if currently_enabled:
		EditorInterface.set_plugin_enabled(plugin_name,false)

	var build_folder = ProjectSettings.globalize_path("res://.godot/generated/"+plugin_name)
	var install_folder = ProjectSettings.globalize_path("res://addons/"+plugin_name)
	var is_windows = OS.get_name() == "Windows"
	var script_name = "create_plugin_project.ps1" if is_windows else "create_plugin_project.sh"
	var create_plugin_script = ProjectSettings.globalize_path("res://addons/androidcodeimporter/" + script_name)
	 	# build an AAR
	var extra_args=[]
	if options["extra_maven_deps"]!="":
		extra_args = ["-MavenDependencies",options["extra_maven_deps"]]
	if options["godot_interface_script"]!="":
		var interface_path = options["godot_interface_script"]
		if interface_path.is_relative_path():
			interface_path=source_file.get_base_dir()+ "/" + interface_path
			interface_path = interface_path.simplify_path()
		interface_path = ProjectSettings.globalize_path(interface_path)
		extra_args = ["-InterfaceScript",interface_path]
	var params = ["-SourceFile",ProjectSettings.globalize_path(source_file),"-TargetFolder",build_folder,"-PluginName",plugin_name,"-Description",
	  options["plugin_description"],"-Author",options["plugin_author"],"-Version",options["plugin_version"],"-InstallFolder",install_folder]+extra_args
	if is_windows:
		params.push_front(create_plugin_script)
		params.push_front("-Command")
		params = params.map(_quotify)
	else:
		params.push_front(create_plugin_script)
	print("**************************** Building plugin ****************************")
	print(params)
	var output = []
	var call_bound = do_build.bind(params,coderesource,filename,options["auto_enable_plugin"],plugin_name,currently_enabled)
	active_tasks[filename] = WorkerThreadPool.add_task(call_bound)
	return OK
