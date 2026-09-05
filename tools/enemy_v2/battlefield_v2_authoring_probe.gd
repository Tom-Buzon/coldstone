extends SceneTree
const Composer = preload("res://scripts/enemy_v2/battlefield/battlefield_composer.gd")
const Document = preload("res://scripts/world_editor/world_document.gd")
const Commander = preload("res://scripts/enemy_v2/battlefield/army_commander.gd")
class Unit extends Node:
	var health := 100.0
	var dead := false
class Layout extends RefCounted:
	var records := {}
class Army extends Node:
	var groups := {}
	var battle_layout := Layout.new()
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var zone := Document.entity("battlefield","Test",Vector3.ZERO,Composer.defaults())
	zone.id = "test"
	var doc := Document.new()
	doc.data.entities = [zone]
	check(Composer.populate(doc.data,zone).population==169,"default population")
	var original := doc.to_json()
	zone.properties.size = [10,4,10]
	check(not Composer.populate(doc.data,zone).errors.is_empty(),"small zone rejection")
	zone.properties.size = [70,4,90]
	check(Composer.populate(doc.data,zone).errors.is_empty(),"restored zone")
	var member: Dictionary = doc.data.entities[1]
	member.properties.deployment_locked = true
	member.position[0] += 1.0
	check(Composer.populate(doc.data,zone).errors.is_empty(),"lock retained")
	check(doc.data.entities[1].position[0]==member.position[0],"locked placement changed")
	zone.properties.mode = "player"
	check(Composer.compose(zone).population==85,"player-only composition")
	zone.properties.enemy_doctrine = "champion"
	zone.properties.enemy_giant = 0
	check(Composer.compose(zone).errors.is_empty(),"legacy doctrine still constrains composition")
	zone.properties = Composer.defaults()
	var easy := preload("res://scripts/enemy_v2/battlefield/army_difficulty.gd").create(&"novice")
	var hard := preload("res://scripts/enemy_v2/battlefield/army_difficulty.gd").create(&"hard")
	check(easy.reaction_seconds>hard.reaction_seconds and easy.player_pressure<hard.player_pressure,"difficulty unchanged")
	var planner := preload("res://scripts/enemy_v2/battlefield/army_engagement_planner.gd").new()
	var sample: Dictionary = {}
	for i in range(8): sample[StringName(str(i))] = {"anchor":Vector3(i+5,0,0)}
	planner.choose_player_groups(sample,Vector3.ZERO,0.25,30.0,false)
	check(planner.pursuing.size()==2,"player allocation monopolizes army")
	planner.choose_player_groups(sample,Vector3.ZERO,0.25,30.0,true)
	check(planner.pursuing.size()==8,"player-only battle leaves unassigned troops")
	print("BATTLEFIELD_AUTHORING ","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)
