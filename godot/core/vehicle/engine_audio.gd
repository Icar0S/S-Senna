class_name EngineAudio
extends AudioStreamPlayer3D
## PLACEHOLDER engine sound (Etapa 04): a synthesized tone whose pitch follows the
## RPM, so driving has feedback without third-party audio. The real system
## (loops with crossfade by RPM, doc 01 §2.11) replaces this in Etapa 12.

const MIX_RATE: float = 22050.0
const BUFFER_SECONDS: float = 0.1
## Firing frequency of a 4-cylinder, 4-stroke engine: 2 pulses per revolution.
const PULSES_PER_REV: float = 2.0
const VOLUME_DB: float = -14.0

var _vehicle: Vehicle = null
var _playback: AudioStreamGeneratorPlayback = null
var _phase: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(vehicle: Vehicle = null) -> void:
	_vehicle = vehicle
	name = "EngineAudio"
	var generator: AudioStreamGenerator = AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = BUFFER_SECONDS
	stream = generator
	volume_db = VOLUME_DB
	unit_size = 8.0


func _ready() -> void:
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	if _playback == null or _vehicle == null or _vehicle.drivetrain == null:
		return
	var rpm: float = _vehicle.drivetrain.rpm
	var load: float = clampf(maxf(_vehicle.input.throttle, _vehicle.input.brake * 0.3), 0.15, 1.0)
	var frequency: float = rpm / 60.0 * PULSES_PER_REV
	var step: float = frequency / MIX_RATE
	for i: int in _playback.get_frames_available():
		_phase = fposmod(_phase + step, 1.0)
		# Saw + a little square + noise: a rough, buzzy engine.
		var saw: float = _phase * 2.0 - 1.0
		var square: float = 1.0 if _phase < 0.5 else -1.0
		var noise: float = _rng.randf_range(-1.0, 1.0)
		var sample: float = (saw * 0.6 + square * 0.25 + noise * 0.15 * load) * (0.25 + load * 0.35)
		_playback.push_frame(Vector2(sample, sample))
