extends Object

# BEGIN_ANDROID_PLUGIN_INCLUDE
# # because we don't want to have class_name defined in our source project 
# # we have these comment markers to show content that should be uncommented and copied into the built plugin
#
# class_name AndroidCameraPlugin
# END_ANDROID_PLUGIN_INCLUDE

var _plugin_name = "generated_camera2"
var _plugin_singleton

func _init():
	if Engine.has_singleton(_plugin_name):
		_plugin_singleton = Engine.get_singleton(_plugin_name)
	else:
		printerr("Initialization error: unable to access kotlin plugin",_plugin_name)

func start():
	if _plugin_singleton:		
		_plugin_singleton.startCamera()
	else:
		printerr("Initialization error")

func register_for_frames(callback:Callable):
	if _plugin_singleton:		
		_plugin_singleton.connect("OnImage",callback)
		
func has_permission() -> bool:
	print("Trying has permission")
	if _plugin_singleton:
		print("WOO")
		return _plugin_singleton.hasCameraPermission()
	return false
	
func request_permission():
	print("Trying request permission")
	if _plugin_singleton:
		print("yay")
		_plugin_singleton.requestCameraPermission()
	
