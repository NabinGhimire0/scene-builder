class_name VoiceChanger
extends RefCounted
## Changes a recorded voice into another character: man, woman, child, old
## person, giant, chipmunk, robot, whisper, radio, cave, alien…
##
## Pitch and voice "size" (formants) are changed separately with pitch-synchronous
## overlap-add (PSOLA): the voice is cut into one-period grains at each glottal
## pulse, the grains are re-spaced for the new pitch and squeezed or stretched for
## the new formants. Whisper and robot use linear prediction (LPC): the voice's
## filter is driven by noise or by a steady buzz. The result is a new .wav file.

const RATE := 22050

## Presets. f0: target average pitch in Hz (0 = keep); formant: fixed factor, or
## formant_m / formant_f by the speaker's own voice (man / woman); plus effects.
const PRESETS := {
	"Woman": {"f0": 215.0, "formant_m": 1.17, "formant_f": 1.0, "about": "A woman's voice"},
	"Man": {"f0": 112.0, "formant_m": 1.0, "formant_f": 0.86, "about": "A man's voice"},
	"Girl": {"f0": 285.0, "formant_m": 1.32, "formant_f": 1.16, "about": "A young girl"},
	"Boy": {"f0": 255.0, "formant_m": 1.26, "formant_f": 1.1, "about": "A young boy"},
	"Old man": {"f0": 105.0, "formant_m": 0.97, "formant_f": 0.85, "shake": 0.035, "breath": 0.12, "about": "Older, shaky"},
	"Old woman": {"f0": 185.0, "formant_m": 1.13, "formant_f": 0.98, "shake": 0.04, "breath": 0.1, "about": "Older, shaky"},
	"Giant": {"pitch": 0.55, "formant": 0.72, "reverb": 0.25, "about": "Huge and deep"},
	"Monster": {"pitch": 0.5, "formant": 0.68, "growl": 0.5, "reverb": 0.3, "about": "Growling monster"},
	"Chipmunk": {"pitch": 1.9, "formant": 1.55, "about": "Tiny cartoon"},
	"Cartoon": {"pitch": 1.45, "formant": 1.3, "about": "Bright cartoon character"},
	"Robot": {"robot": 105.0, "metal": 0.4, "about": "Monotone machine"},
	"Alien": {"pitch": 1.15, "formant": 1.2, "ring": 55.0, "reverb": 0.15, "about": "Wobbly alien"},
	"Whisper": {"whisper": 1.0, "about": "Breathy whisper"},
	"Ghost": {"pitch": 0.92, "whisper": 0.55, "reverb": 0.55, "about": "Airy and echoing"},
	"Radio": {"radio": 1.0, "about": "Phone / old radio"},
	"Cave": {"reverb": 0.6, "about": "Big echoing space"},
}

## Analysis of a voice: {"f0": per 10 ms (0 = unvoiced), "median": Hz, "male": bool}.
static func analyse(x: PackedFloat32Array, rate: int = RATE) -> Dictionary:
	var hop := rate / 50
	var f0 := _pitch_track(x, rate, hop)
	var voiced := PackedFloat32Array()
	for v in f0:
		if v > 0.0:
			voiced.append(v)
	var median := 0.0
	if not voiced.is_empty():
		var arr := Array(voiced)
		arr.sort()
		median = float(arr[arr.size() / 2])
	return {"f0": f0, "hop": hop, "median": median, "male": median > 0.0 and median < 165.0}


## The settings a preset means for a voice whose median pitch is [param median].
static func settings_for(preset: String, median: float, custom: Dictionary = {}) -> Dictionary:
	var p: Dictionary = PRESETS.get(preset, {}).duplicate()
	for k in custom:
		p[k] = custom[k]
	var male := median > 0.0 and median < 165.0
	if p.has("f0"):
		p["pitch"] = clampf(float(p["f0"]) / maxf(median if median > 0.0 else (120.0 if male else 210.0), 60.0), 0.45, 2.6)
	if p.has("formant_m"):
		p["formant"] = float(p["formant_m"]) if male else float(p["formant_f"])
	if p.has("semitones"):
		p["pitch"] = float(p.get("pitch", 1.0)) * pow(2.0, float(p["semitones"]) / 12.0)
	return p


## Changes [param x] (mono samples at [param rate]); [param progress] is called with 0..1.
static func process(x: PackedFloat32Array, rate: int, s: Dictionary, progress: Callable = Callable()) -> PackedFloat32Array:
	var y := x
	var info := analyse(x, rate)
	_report(progress, 0.25)
	var pitch := float(s.get("pitch", 1.0))
	var formant := float(s.get("formant", 1.0))
	var robot := float(s.get("robot", 0.0))
	if robot > 0.0:
		y = _lpc_voice(x, rate, robot, 0.0, float(s.get("metal", 0.0)))
	elif absf(pitch - 1.0) > 0.01 or absf(formant - 1.0) > 0.01 or float(s.get("shake", 0.0)) > 0.0:
		y = _psola(x, rate, info, pitch, formant, float(s.get("shake", 0.0)))
	_report(progress, 0.6)
	var whisper := float(s.get("whisper", 0.0))
	var breath := float(s.get("breath", 0.0))
	if whisper > 0.0 or breath > 0.0:
		var w := _lpc_voice(y, rate, 0.0, 1.0, 0.0)
		var mix := maxf(whisper, breath)
		for i in y.size():
			y[i] = y[i] * (1.0 - mix) + w[i] * mix * 1.2
	if float(s.get("growl", 0.0)) > 0.0:
		y = _growl(y, rate, float(s["growl"]))
	if float(s.get("ring", 0.0)) > 0.0:
		var fr := float(s["ring"])
		for i in y.size():
			y[i] = y[i] * (0.55 + 0.45 * sin(TAU * fr * i / rate))
	if float(s.get("radio", 0.0)) > 0.0:
		y = _radio(y, rate)
	_report(progress, 0.8)
	if float(s.get("reverb", 0.0)) > 0.0:
		y = _reverb(y, rate, float(s["reverb"]))
	y = _match_loudness(x, y, rate)
	_report(progress, 1.0)
	return y


static func _report(progress: Callable, v: float) -> void:
	if progress.is_valid():
		progress.call(v)


# ------------------------------------------------------------------ pitch

## Pitch every hop (Hz, 0 = unvoiced), by normalised autocorrelation on an 8 kHz copy.
static func _pitch_track(x: PackedFloat32Array, rate: int, hop: int) -> PackedFloat32Array:
	var dec := maxi(1, rate / 8000)
	var r := float(rate) / dec
	var d := PackedFloat32Array()
	d.resize(x.size() / dec)
	for i in d.size():
		var s := 0.0
		for k in dec:
			s += x[i * dec + k]
		d[i] = s / dec
	var win := int(r * 0.032)
	var lo := int(r / 450.0)
	var hi := int(r / 60.0)
	var frames := x.size() / hop
	var out := PackedFloat32Array()
	out.resize(frames)
	var dhop := float(hop) / dec
	var energy_max := 0.0
	var energies := PackedFloat32Array()
	energies.resize(frames)
	for f in frames:
		var c := int(f * dhop)
		var e := 0.0
		for i in range(c, mini(c + win, d.size())):
			e += d[i] * d[i]
		energies[f] = e
		energy_max = maxf(energy_max, e)
	var prev := 0.0
	for f in frames:
		var c := int(f * dhop)
		if c + win + hi >= d.size() or energies[f] < energy_max * 0.004:
			out[f] = 0.0
			continue
		var best := 0.0
		var best_lag := 0
		var e0 := energies[f]
		for lag in range(lo, hi + 1):
			var s := 0.0
			var e1 := 0.0
			for i in range(c, c + win, 4):
				var a := d[i]
				var b := d[i + lag]
				s += a * b
				e1 += b * b
			var corr := s / sqrt(maxf(e0 * 0.25 * e1, 1e-12))
			# favour the lag near the previous frame (fewer octave jumps)
			if prev > 0.0:
				corr *= 1.0 - 0.15 * minf(absf(r / lag - prev) / prev, 1.0)
			if corr > best:
				best = corr
				best_lag = lag
		if best > 0.55 and best_lag > 0:
			out[f] = r / best_lag
			prev = out[f]
		else:
			out[f] = 0.0
	# smooth: median of 5
	var sm := out.duplicate()
	for f in range(2, frames - 2):
		var w := [out[f - 2], out[f - 1], out[f], out[f + 1], out[f + 2]]
		w.sort()
		sm[f] = w[2] if out[f] > 0.0 else 0.0
	return sm


# ------------------------------------------------------------------ PSOLA

static func _psola(x: PackedFloat32Array, rate: int, info: Dictionary, pitch: float, formant: float, shake: float) -> PackedFloat32Array:
	var f0: PackedFloat32Array = info["f0"]
	var hop: int = info["hop"]
	var n := x.size()
	# analysis marks: one per period at the strongest peak (voiced), every 10 ms (unvoiced)
	var marks := PackedInt32Array()
	var periods := PackedFloat32Array()
	var t := 0
	while t < n:
		var f := mini(t / hop, f0.size() - 1)
		var hz := f0[f] if f >= 0 and f < f0.size() else 0.0
		var period := int(rate / hz) if hz > 0.0 else int(rate * 0.01)
		var best := t
		if hz > 0.0:
			var bv := -1.0
			for i in range(t, mini(t + period, n)):
				if absf(x[i]) > bv:
					bv = absf(x[i])
					best = i
			if not marks.is_empty() and best - marks[marks.size() - 1] < period * 0.6:
				best = marks[marks.size() - 1] + period
		marks.append(mini(best, n - 1))
		periods.append(float(period))
		t = best + period if hz > 0.0 else t + period
	var y := PackedFloat32Array()
	y.resize(n + rate / 10)
	var to := float(marks[0]) if not marks.is_empty() else 0.0
	var mi := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	while to < n:
		while mi + 1 < marks.size() and absf(marks[mi + 1] - to) < absf(marks[mi] - to):
			mi += 1
		var m := marks[mi]
		var pa := periods[mi]
		var f := mini(m / hop, f0.size() - 1)
		var voiced := f0[f] > 0.0
		var step := pa / pitch if voiced else pa
		if voiced and shake > 0.0:
			step *= 1.0 + shake * sin(TAU * 5.5 * to / rate) + shake * 0.4 * rng.randf_range(-1.0, 1.0)
		# grain: two analysis periods around the mark, squeezed by the formant factor
		var half := int(pa)
		var out_half := int(half / formant)
		var centre := int(to)
		for k in range(-out_half, out_half):
			var src := m + k * formant
			var si := int(floor(src))
			if si < 0 or si + 1 >= n:
				continue
			var fr := src - si
			var v := x[si] * (1.0 - fr) + x[si + 1] * fr
			var w := 0.5 + 0.5 * cos(PI * float(k) / out_half)
			var o := centre + k
			if o >= 0 and o < y.size():
				y[o] += v * w
		to += maxf(step, 16.0)
	y.resize(n)
	return y


# ------------------------------------------------------------------ LPC (whisper, robot, breath)

## Re-voices with linear prediction: buzz at [param buzz_hz] (robot) or noise (whisper).
static func _lpc_voice(x: PackedFloat32Array, rate: int, buzz_hz: float, noise: float, metal: float) -> PackedFloat32Array:
	var order := 18
	var frame := int(rate * 0.025)
	var hop := frame / 2
	var n := x.size()
	var y := PackedFloat32Array()
	y.resize(n)
	var mem := PackedFloat32Array()
	mem.resize(order)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var phase := 0.0
	var start := 0
	while start < n:
		var end := mini(start + frame, n)
		# autocorrelation of the windowed frame
		var r := PackedFloat32Array()
		r.resize(order + 1)
		var len := end - start
		var fw := PackedFloat32Array()
		fw.resize(len)
		for i in len:
			fw[i] = x[start + i] * (0.5 - 0.5 * cos(TAU * i / maxf(len, 1)))
		for lag in order + 1:
			var s := 0.0
			for i in range(0, len - lag):
				s += fw[i] * fw[i + lag]
			r[lag] = s
		var a := _levinson(r, order)
		var gain := sqrt(maxf(_lpc_error(r, a), 0.0) / maxf(len, 1)) * 1.6
		for i in range(start, mini(start + hop, n)):
			var e := 0.0
			if buzz_hz > 0.0:
				phase += buzz_hz / rate
				if phase >= 1.0:
					phase -= 1.0
					e = sqrt(rate / buzz_hz) * 0.9
				e += rng.randf_range(-1.0, 1.0) * 0.05
			else:
				e = rng.randf_range(-1.0, 1.0) * noise * 1.7
			var v := e * gain
			for k in order:
				v -= a[k + 1] * mem[k]
			for k in range(order - 1, 0, -1):
				mem[k] = mem[k - 1]
			mem[0] = v
			if metal > 0.0:
				v = v * (1.0 - metal) + v * metal * sin(TAU * 900.0 * i / rate)
			y[i] = clampf(v, -1.5, 1.5)
		start += hop
	return y


static func _levinson(r: PackedFloat32Array, order: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(order + 1)
	a[0] = 1.0
	var e := r[0] * 1.0001 + 1e-9
	for i in range(1, order + 1):
		var acc := r[i]
		for j in range(1, i):
			acc += a[j] * r[i - j]
		var k := -acc / e
		var tmp := a.duplicate()
		for j in range(1, i):
			a[j] = tmp[j] + k * tmp[i - j]
		a[i] = k
		e *= (1.0 - k * k)
		if e <= 0.0:
			break
	return a


static func _lpc_error(r: PackedFloat32Array, a: PackedFloat32Array) -> float:
	var e := 0.0
	for i in a.size():
		e += a[i] * r[i]
	return e


# ------------------------------------------------------------------ effects

static func _growl(y: PackedFloat32Array, rate: int, amount: float) -> PackedFloat32Array:
	var out := y.duplicate()
	for i in y.size():
		var m := 1.0 - amount * 0.5 * (0.5 + 0.5 * sin(TAU * 32.0 * i / rate))
		out[i] = tanh(y[i] * (1.0 + amount * 2.0)) * m
	return out


static func _radio(y: PackedFloat32Array, rate: int) -> PackedFloat32Array:
	var out := _biquad(y, rate, 340.0, 0.7, true)
	out = _biquad(out, rate, 3200.0, 0.7, false)
	for i in out.size():
		out[i] = tanh(out[i] * 2.2) * 0.6
	return out


## One high-pass (or low-pass) biquad.
static func _biquad(x: PackedFloat32Array, rate: int, f: float, q: float, high: bool) -> PackedFloat32Array:
	var w0 := TAU * f / rate
	var alpha := sin(w0) / (2.0 * q)
	var c := cos(w0)
	var b0 := (1.0 + c) / 2.0 if high else (1.0 - c) / 2.0
	var b1 := -(1.0 + c) if high else (1.0 - c)
	var b2 := b0
	var a0 := 1.0 + alpha
	var a1 := -2.0 * c
	var a2 := 1.0 - alpha
	var y := PackedFloat32Array()
	y.resize(x.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in x.size():
		var v := (b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
		x2 = x1
		x1 = x[i]
		y2 = y1
		y1 = v
		y[i] = v
	return y


## A small room / hall (Schroeder: four combs and two all-passes), plus a tail.
static func _reverb(x: PackedFloat32Array, rate: int, amount: float) -> PackedFloat32Array:
	var tail := int(rate * (0.4 + amount * 1.6))
	var n := x.size() + tail
	var wet := PackedFloat32Array()
	wet.resize(n)
	var delays := [1557, 1617, 1491, 1422]
	var fb := 0.72 + amount * 0.22
	for d0 in delays:
		var d := int(d0 * rate / 25000.0 * (1.0 + amount))
		var buf := PackedFloat32Array()
		buf.resize(d)
		var p := 0
		var lp := 0.0
		for i in n:
			var inp := x[i] if i < x.size() else 0.0
			var out := buf[p]
			lp = out * 0.6 + lp * 0.4
			buf[p] = inp + lp * fb
			p = (p + 1) % d
			wet[i] += out * 0.25
	for d0 in [225, 556]:
		var d := int(d0 * rate / 25000.0)
		var buf := PackedFloat32Array()
		buf.resize(d)
		var p := 0
		for i in n:
			var b := buf[p]
			var v := wet[i]
			buf[p] = v + b * 0.5
			wet[i] = b - v * 0.5
			p = (p + 1) % d
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = (x[i] if i < x.size() else 0.0) * (1.0 - amount * 0.35) + wet[i] * amount * 0.9
	return out


## Keeps the loudness (in 50 ms steps) of the original voice.
static func _match_loudness(ref: PackedFloat32Array, y: PackedFloat32Array, rate: int) -> PackedFloat32Array:
	var block := rate / 20
	var out := y.duplicate()
	var blocks := int(ceil(float(y.size()) / block))
	var gains := PackedFloat32Array()
	gains.resize(blocks)
	var global_ref := 0.0
	var global_y := 0.0
	for b in blocks:
		var sr := 0.0
		var sy := 0.0
		for i in range(b * block, mini((b + 1) * block, y.size())):
			var rv := ref[i] if i < ref.size() else 0.0
			sr += rv * rv
			sy += y[i] * y[i]
		global_ref += sr
		global_y += sy
		gains[b] = sqrt(sr / maxf(sy, 1e-9)) if sy > 1e-7 and sr > 1e-6 * block else -1.0
	var overall := sqrt(global_ref / maxf(global_y, 1e-9))
	var prev := overall
	for i in y.size():
		var b := i / block
		var g := clampf(gains[b] if (i < ref.size() and gains[b] >= 0.0) else overall, overall * 0.25, overall * 4.0)
		prev = lerpf(prev, g, 0.002)
		out[i] = clampf(y[i] * prev, -1.0, 1.0)
	return out


# ------------------------------------------------------------------ files

## Mono samples of a sound file: {"samples", "rate"} ({} if it can't be read).
## .wav is read directly; .mp3 / .ogg need FFmpeg ([param ffmpeg]).
static func read(path: String, ffmpeg := "ffmpeg", rate := RATE) -> Dictionary:
	var wav_path := path
	if path.get_extension().to_lower() != "wav":
		DirAccess.make_dir_recursive_absolute("user://tools/")
		wav_path = "user://tools/decode_%d.wav" % (hash(path) & 0xffff)
		var output: Array = []
		var code := OS.execute(ffmpeg, PackedStringArray(["-y", "-loglevel", "error", "-i", ProjectSettings.globalize_path(path),
			"-ac", "1", "-ar", str(rate), "-c:a", "pcm_s16le", ProjectSettings.globalize_path(wav_path)]), output, true)
		if code != 0:
			return {}
	var wav := load_wav(wav_path)
	if wav == null:
		return {}
	var ch := 2 if wav.stereo else 1
	var data := wav.data
	var bytes_per := 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
	var frames := data.size() / (bytes_per * ch)
	var x := PackedFloat32Array()
	x.resize(frames)
	for i in frames:
		var s := 0.0
		for c in ch:
			var o := (i * ch + c) * bytes_per
			s += (data.decode_s16(o) / 32768.0) if bytes_per == 2 else (data.decode_s8(o) / 128.0)
		x[i] = s / ch
	if wav.mix_rate != rate:
		x = resample(x, wav.mix_rate, rate)
	return {"samples": x, "rate": rate}


static func resample(x: PackedFloat32Array, from: int, to: int) -> PackedFloat32Array:
	var ratio := float(from) / to
	var n := int(x.size() / ratio)
	var y := PackedFloat32Array()
	y.resize(n)
	# a little low-pass first when going down
	var src := x
	if from > to:
		src = x.duplicate()
		var k := int(ceil(ratio))
		for i in src.size():
			var s := 0.0
			var c := 0
			for j in range(maxi(0, i - k + 1), i + 1):
				s += x[j]
				c += 1
			src[i] = s / c
	for i in n:
		var p := i * ratio
		var j := int(p)
		var f := p - j
		y[i] = src[j] * (1.0 - f) + (src[mini(j + 1, src.size() - 1)]) * f
	return y


static func write(path: String, x: PackedFloat32Array, rate := RATE) -> Error:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(x.size() * 2)
	for i in x.size():
		data.encode_s16(i * 2, int(clampf(x[i], -1.0, 1.0) * 32767.0))
	wav.data = data
	return wav.save_to_wav(path)


## Minimal PCM .wav reader (8/16-bit).
static func load_wav(path: String) -> AudioStreamWAV:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	var pos := 12
	var channels := 1
	var rate := 44100
	var bits := 16
	while pos + 8 <= bytes.size():
		var id := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size := bytes.decode_u32(pos + 4)
		if id == "fmt ":
			if bytes.decode_u16(pos + 8) != 1:
				return null
			channels = bytes.decode_u16(pos + 10)
			rate = bytes.decode_u32(pos + 12)
			bits = bytes.decode_u16(pos + 22)
		elif id == "data":
			var wav := AudioStreamWAV.new()
			wav.mix_rate = rate
			wav.stereo = channels == 2
			wav.format = AudioStreamWAV.FORMAT_16_BITS if bits == 16 else AudioStreamWAV.FORMAT_8_BITS
			var data := bytes.slice(pos + 8, pos + 8 + mini(size, bytes.size() - pos - 8))
			if bits == 8:
				for i in data.size():
					data[i] = (data[i] + 128) % 256
			wav.data = data
			return wav
		pos += 8 + size + (size % 2)
	return null
