class_name PerfLogger
extends Node
## Development performance log. While the FPS overlay is enabled (F3 or
## Settings), appends a CSV row every few seconds to user://perf_log.csv:
## time, fps, frame ms, draw calls, primitives, objects, static memory MB.

const PATH := "user://perf_log.csv"
const INTERVAL := 5.0

var _acc: float = 0.0
var _frames: int = 0
var _time: float = 0.0


func _process(delta: float) -> void:
	if not Settings.show_fps:
		return
	_acc += delta
	_time += delta
	_frames += 1
	if _acc < INTERVAL:
		return
	var avg_ms := _acc / maxf(1.0, _frames) * 1000.0
	var new_file := not FileAccess.file_exists(PATH)
	var f := FileAccess.open(PATH, FileAccess.READ_WRITE if not new_file else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	if new_file:
		f.store_line("time_s,fps,frame_ms,draw_calls,primitives,objects,static_mb,quality")
	f.store_line("%.1f,%d,%.2f,%d,%d,%d,%.1f,%d" % [
		_time, Engine.get_frames_per_second(), avg_ms,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, int(Settings.quality)])
	f.close()
	_acc = 0.0
	_frames = 0
