@tool
class_name AndroidCodeResource 
extends Resource

@export var source: String
@export var built: bool

func _init(in_source = "",in_built=false):
	source = in_source
	built = in_built
	#print("Init:",in_source)
