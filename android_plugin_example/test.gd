extends Object

# BEGIN_ANDROID_PLUGIN_INCLUDE
# # because we don't want to have class_name defined in our source project 
# # we have these comment markers to show content that should be uncommented and copied into the built plugin
#
# class_name TestPlugin
# END_ANDROID_PLUGIN_INCLUDE

var _plugin_name = "generated_test"
var _plugin_singleton

func _init():
	if Engine.has_singleton(_plugin_name):
		_plugin_singleton = Engine.get_singleton(_plugin_name)
	else:
		printerr("Initialization error: unable to access kotlin plugin")

## Print a 'Hello World' message to the logcat.
func helloWorld():
	if _plugin_singleton:
		_plugin_singleton.helloWorld()
	else:
		printerr("Initialization error")
