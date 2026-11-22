extends Node

const SAVE_PATH := "user://gilla_remake.cfg"
const FUR := [
    {"name": "Gilla Green", "color": Color(1.0, 1.0, 1.0), "cost": 0},
    {"name": "Charcoal", "color": Color(0.35, 0.35, 0.38), "cost": 150},
    {"name": "Crimson", "color": Color(1.6, 0.45, 0.45), "cost": 300},
    {"name": "Ocean", "color": Color(0.45, 0.8, 2.0), "cost": 500},
    {"name": "Gold", "color": Color(2.0, 1.6, 0.45), "cost": 800},
]

const ROOMS := ["GILLA-1", "GILLA-2", "GILLA-3", "GILLA-4", "GILLA-5", "GILLA-6"]

var room_idx := 0
var money := 0
var xp := 0
var owned: Array = [0]
var equipped := 0


func _ready() -> void:
    load_game()


func read_text(path: String) -> String:
    if FileAccess.file_exists(path):
        return FileAccess.get_file_as_string(path).strip_edges()
    return ""


func server_url() -> String:
    return read_text("res://server_url.txt")


func mod_token() -> String:
    return read_text("res://mod_token.txt")


func level() -> int:
    return 1 + int(sqrt(xp / 100.0))


func xp_next() -> int:
    var l := level()
    return l * l * 100


func add_money(n: int) -> void:
    money += n
    save_game()


func add_xp(n: int) -> void:
    xp += n
    save_game()


func save_game() -> void:
    var cf := ConfigFile.new()
    cf.set_value("g", "money", money)
    cf.set_value("g", "xp", xp)
    cf.set_value("g", "owned", owned)
    cf.set_value("g", "equipped", equipped)
    cf.set_value("g", "room_idx", room_idx)
    cf.save(SAVE_PATH)


func load_game() -> void:
    var cf := ConfigFile.new()
    if cf.load(SAVE_PATH) != OK:
        return
    money = int(cf.get_value("g", "money", 0))
    xp = int(cf.get_value("g", "xp", 0))
    owned = cf.get_value("g", "owned", [0])
    equipped = int(cf.get_value("g", "equipped", 0))
    room_idx = int(cf.get_value("g", "room_idx", 0)) % ROOMS.size()
