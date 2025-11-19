extends Node

var tp

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	tp=	TestPlugin.new()
	tp.helloWorld()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
