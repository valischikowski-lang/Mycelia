class_name InputConfig
extends RefCounted
## Data-driven input map. Actions are registered at startup so bindings can be
## rebound and persisted through Settings without editing project.godot.

const DEFAULT_KEYS: Dictionary = {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"walk": [KEY_CTRL],
	"interact": [KEY_E],
	"pause": [KEY_ESCAPE],
	"menu_inventory": [KEY_I, KEY_TAB],
	"menu_spellbook": [KEY_B],
	"menu_journal": [KEY_J],
	"menu_map": [KEY_M],
	"menu_skills": [KEY_K],
	"menu_character": [KEY_C],
	"debug_perf": [KEY_F3],
	"ui_card_1": [KEY_1],
	"ui_card_2": [KEY_2],
	"ui_card_3": [KEY_3],
	"ui_card_4": [KEY_4],
	"attack": [],
	"block": [],
	"aim_bow": [KEY_F],
	"dodge": [KEY_Q, KEY_ALT],
	"lock_on": [KEY_T],
	"switch_weapon": [KEY_X],
	"ability_1": [KEY_1],
	"ability_2": [KEY_2],
	"ability_3": [KEY_3],
	"ability_4": [KEY_4],
	"ability_5": [KEY_5],
}

## Mouse buttons per action (added on top of the keys).
const DEFAULT_MOUSE: Dictionary = {
	"attack": [MOUSE_BUTTON_LEFT],
	"block": [MOUSE_BUTTON_RIGHT],
	"lock_on": [MOUSE_BUTTON_MIDDLE],
}

const DEFAULT_JOY_BUTTONS: Dictionary = {
	"jump": [JOY_BUTTON_A],
	"interact": [JOY_BUTTON_X],
	"sprint": [JOY_BUTTON_LEFT_STICK],
	"pause": [JOY_BUTTON_START],
	"menu_inventory": [JOY_BUTTON_BACK],
	"attack": [JOY_BUTTON_RIGHT_SHOULDER],
	"block": [JOY_BUTTON_LEFT_SHOULDER],
	"dodge": [JOY_BUTTON_B],
	"lock_on": [JOY_BUTTON_RIGHT_STICK],
	"switch_weapon": [JOY_BUTTON_Y],
}

const DEFAULT_JOY_AXES: Dictionary = {
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"aim_bow": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}


## Registers all actions. `overrides` maps action -> Array of keycodes.
static func apply(overrides: Dictionary = {}) -> void:
	for action: String in DEFAULT_KEYS.keys():
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.2)
		var keys: Array = overrides.get(action, DEFAULT_KEYS[action])
		for key: Variant in keys:
			var ev := InputEventKey.new()
			ev.physical_keycode = int(key) as Key
			InputMap.action_add_event(action, ev)
		for button: Variant in DEFAULT_JOY_BUTTONS.get(action, []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = int(button) as JoyButton
			InputMap.action_add_event(action, jb)
		if DEFAULT_JOY_AXES.has(action):
			var data: Array = DEFAULT_JOY_AXES[action]
			var ja := InputEventJoypadMotion.new()
			ja.axis = int(data[0]) as JoyAxis
			ja.axis_value = float(data[1])
			InputMap.action_add_event(action, ja)
		for mb: Variant in DEFAULT_MOUSE.get(action, []):
			var me := InputEventMouseButton.new()
			me.button_index = int(mb) as MouseButton
			InputMap.action_add_event(action, me)


static func key_name(action: String) -> String:
	if not InputMap.has_action(action):
		return "?"
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	return "?"
