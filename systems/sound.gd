extends Node

var volume: float = 0.45
var clock: float = 0
var intensity: int = 0
var tones: Dictionary = {}

func _ready():
	for key in ["step","hit","attack","devour","trait","evolve","hurt","ui","boss","ambient"]:
		var hz = {"step":90,"hit":130,"attack":240,"devour":440,"trait":660,"evolve":330,"hurt":70,"ui":550,"boss":55,"ambient":110}[key]
		var duration = 0.14 if key in ["step","hit","attack","hurt","ui"] else 0.85
		var bytes = PackedByteArray()
		bytes.resize(int(22050 * duration) * 2)
		for i in range(bytes.size()/2):
			var t = float(i)/22050.0
			var envelope = minf(t*30,1) * pow(1-t/duration,2)
			var phase = TAU*hz*t + (sin(t*12)*2 if key in ["devour","evolve"] else 0)
			var value = (sin(phase) + 0.25*sin(phase*1.5) + 0.15*sin(phase*2))*envelope*0.25
			bytes.encode_s16(i*2,int(value*32767))
		var wav = AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		wav.data = bytes
		tones[key] = wav

func play(key: String, pitch: float = 1.0):
	if volume <= 0.001 or not tones.has(key): return
	var voice = AudioStreamPlayer.new()
	voice.stream = tones[key]
	voice.volume_db = linear_to_db(volume * (0.24 if key == "ambient" else 0.65))
	voice.pitch_scale = pitch
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()

func _process(delta):
	clock += delta
	if clock > (1.1 if intensity > 0 else 2.7):
		clock = 0
		play("ambient", [1.0,1.25,1.5,2.0][randi()%4]*(0.5 if intensity == 2 else 1.0))
