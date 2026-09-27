extends RefCounted
## Presentation-side audio facade (blueprint §60). M4: real runtime playback.
##
## A small bounded pool of AudioStreamPlayer nodes (hosted by the presenter)
## plays generated interaction sounds on the correct bus. Playback is optional
## and never blocks gameplay or the simulation:
## - no host (headless tests) -> requests are counted, no hardware playback;
## - Sound OFF -> play() is a safe no-op;
## - unknown SFX or missing stream -> false;
## - a missing bus (isolated branch, tests) falls back to Master.
##
## Streams are generated in code (procedural_sfx.gd); no binary assets ship.

const Contract := preload("res://audio/audio_contract.gd")
const ProceduralSfx := preload("res://audio/procedural_sfx.gd")

## SFX overlap pool. Expected concurrency: at most a handful of simultaneous
## taps/matches/loads; 8 covers overlap comfortably without unbounded players.
const POOL_SIZE := 8

var enabled := true          ## Sound gate (SFX + UI interaction sound).
var music_enabled := true    ## Music gate (no music asset ships in M4).

var play_count := 0
var playback_count := 0      ## Actual player.play() invocations (needs a host).
var last_sfx: StringName = &""
var last_bus: StringName = &""

var _streams: Dictionary = {}
var _players: Array = []
var _music_player: AudioStreamPlayer = null
var _host: Node = null
var _next_player := 0


# --- hosting (pool lifecycle) ------------------------------------------------

## Binds the pool to a Node in the scene tree (the presenter's AudioHost).
func bind_host(host: Node) -> void:
	_host = host
	_build_pool()


func detach_host() -> void:
	_host = null
	_players.clear()
	_music_player = null


func has_host() -> bool:
	return _host != null and is_instance_valid(_host)


func pool_size() -> int:
	return _players.size()


# --- stream registry ---------------------------------------------------------

func register_stream(sfx: StringName, stream: Variant) -> void:
	if stream != null:
		_streams[sfx] = stream


func unregister_stream(sfx: StringName) -> void:
	_streams.erase(sfx)


func has_stream(sfx: StringName) -> bool:
	return _streams.has(sfx)


func stream_count() -> int:
	return _streams.size()


## Generates and registers the default procedural interaction sounds. Returns
## how many were added. Idempotent; generated streams are cached per process.
func ensure_default_streams() -> int:
	var added := 0
	for sfx: StringName in Contract.all_sfx():
		if _streams.has(sfx):
			continue
		var stream := ProceduralSfx.build(sfx)
		if stream != null:
			_streams[sfx] = stream
			added += 1
	return added


# --- playback ----------------------------------------------------------------

## Returns true when a play request was accepted and (if a host exists) started.
## Never throws and never blocks; gameplay never depends on audio.
func play(sfx: StringName, pitch: float = 1.0) -> bool:
	if not enabled:
		return false
	if not Contract.is_known(sfx):
		return false
	if not _streams.has(sfx):
		return false
	var stream: Variant = _streams[sfx]
	play_count += 1
	last_sfx = sfx
	last_bus = Contract.bus_for(sfx)
	if stream is AudioStream:
		_play_stream(stream, sfx, pitch)
	return true


# --- settings ----------------------------------------------------------------

## Master sound gate (kept for the existing scaffold API/tests).
func set_enabled(value: bool) -> void:
	enabled = value


func set_sound_enabled(value: bool) -> void:
	enabled = value


func is_sound_enabled() -> bool:
	return enabled


func set_music_enabled(value: bool) -> void:
	music_enabled = value
	if not value and _music_player != null and is_instance_valid(_music_player) and _music_player.is_inside_tree():
		_music_player.stop()


func is_music_enabled() -> bool:
	return music_enabled


## Resolves a bus name to a real bus, falling back to Master when absent
## (isolated branch / tests). Public for diagnostics and tests.
func resolved_bus(bus_name: StringName) -> StringName:
	return _resolve_bus(bus_name)


# --- internals ---------------------------------------------------------------

func _build_pool() -> void:
	if not _players.is_empty():
		return
	if _host == null or not is_instance_valid(_host):
		return
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % i
		player.bus = _resolve_bus(Contract.BUS_SFX)
		_host.add_child(player)
		_players.append(player)
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = _resolve_bus(Contract.BUS_MUSIC)
	_host.add_child(_music_player)


func _play_stream(stream: AudioStream, sfx: StringName, pitch: float) -> void:
	var player := _select_player()
	if player == null or not is_instance_valid(player):
		return
	player.bus = _resolve_bus(Contract.bus_for(sfx))
	player.stream = stream
	player.pitch_scale = clampf(pitch, 0.01, 4.0)
	# Headless hosts (tests) are not in the tree: count the request, skip output.
	if player.is_inside_tree():
		player.play()
		playback_count += 1


## Prefers a free player, else round-robins the bounded pool (oldest stolen).
func _select_player() -> AudioStreamPlayer:
	var count := _players.size()
	if count == 0:
		return null
	for i in count:
		var player: AudioStreamPlayer = _players[i]
		if is_instance_valid(player) and not player.playing:
			return player
	var fallback: AudioStreamPlayer = _players[_next_player % count]
	_next_player = (_next_player + 1) % count
	return fallback


## A missing bus (isolated branch/tests) silently falls back to Master.
func _resolve_bus(bus_name: StringName) -> StringName:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return bus_name
	return Contract.BUS_MASTER
