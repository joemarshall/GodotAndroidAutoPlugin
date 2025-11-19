extends Node



var _plugin_name = "test"
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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_plugin_singleton.helloWorld()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
