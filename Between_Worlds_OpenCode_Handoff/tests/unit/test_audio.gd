class_name TestAudio
extends RefCounted
## Punto 4: SFX procedurales válidos y deterministas.


func run(ctx: Object) -> void:
	for sfx_name in SfxSynth.NAMES:
		var stream := SfxSynth.make(sfx_name)
		ctx.check(stream != null, "SFX %s genera stream" % sfx_name)
		ctx.equals(stream.mix_rate, SfxSynth.SAMPLE_RATE, "SFX %s sample rate" % sfx_name)
		ctx.check(stream.data.size() > 100, "SFX %s con datos (%d bytes)" % [sfx_name, stream.data.size()])
		ctx.equals(stream.format, AudioStreamWAV.FORMAT_16_BITS, "SFX %s 16-bit" % sfx_name)

	# Determinismo: mismo nombre → mismos bytes.
	var a := SfxSynth.make("destroy")
	var b := SfxSynth.make("destroy")
	ctx.equals(a.data, b.data, "Ruido determinista (misma seed)")

	# Nombres inválidos caen al click sin romper.
	ctx.check(SfxSynth.make("nuke").data.size() > 0, "Nombre inválido => click")
	ctx.check(SfxSynth.is_valid("win"), "win válido")
	ctx.check(not SfxSynth.is_valid("nuke"), "nuke inválido")

	# Duraciones sanas: el disparo más corto < muerte < arpegio.
	var rifle := SfxSynth.make("shoot_rifle")
	var death := SfxSynth.make("death")
	var win := SfxSynth.make("win")
	ctx.check(rifle.data.size() < death.data.size(), "Rifle más corto que muerte")
	ctx.check(death.data.size() < win.data.size(), "Muerte más corta que fanfarria")
