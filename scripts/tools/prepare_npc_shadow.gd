extends SceneTree

# Generated concept art is kept as source. This tool trims it, scales it with
# nearest-neighbour sampling, and snaps it to the game's deliberately small
# palette so the runtime files do not look like high-resolution illustrations.

const JOBS := [
	{
		"src": "res://assets/npc_shadow/source/idle_master_keyed.png",
		"dst": "res://assets/npc_shadow/idle_master.png",
		"axis": "width",
		"size": 288,
	},
	{
		"src": "res://assets/npc_shadow/source/rig_parts_keyed.png",
		"dst": "res://assets/npc_shadow/rig_parts.png",
		"axis": "width",
		"size": 512,
	},
	{
		"src": "res://assets/npc_shadow/source/sweep_forward_keyed.png",
		"dst": "res://assets/npc_shadow/sweep_forward.png",
		"axis": "height",
		"size": 160,
	},
]

const RIG_PARTS := [
	{"name": "torso", "region": Rect2(0.28, 0.00, 0.44, 0.53)},
	{"name": "upper_left", "region": Rect2(0.00, 0.31, 0.23, 0.43)},
	{"name": "upper_right", "region": Rect2(0.77, 0.31, 0.23, 0.43)},
	{"name": "fore_left", "region": Rect2(0.00, 0.75, 0.39, 0.25)},
	{"name": "fore_right", "region": Rect2(0.61, 0.75, 0.39, 0.25)},
]

const PALETTE := [
	Color8(8, 8, 11),
	Color8(14, 14, 18),
	Color8(21, 20, 25),
	Color8(29, 28, 34),
	Color8(39, 37, 44),
	Color8(52, 49, 57),
	Color8(66, 62, 70),
	Color8(84, 79, 87),
	Color8(105, 99, 106),
	Color8(132, 124, 130),
	Color8(161, 153, 158),
	Color8(190, 181, 184),
	Color8(74, 31, 29),
	Color8(112, 45, 39),
	Color8(160, 58, 49),
	Color8(210, 72, 61),
]


func _init() -> void:
	var failed := false
	for job in JOBS:
		if not _prepare(job):
			failed = true
	quit(1 if failed else 0)


func _prepare(job: Dictionary) -> bool:
	var src: String = job.src
	var image := Image.load_from_file(src)
	if image == null or image.is_empty():
		push_error("Could not load %s" % src)
		return false

	var bounds := _alpha_bounds(image)
	if bounds.size == Vector2i.ZERO:
		push_error("No opaque pixels in %s" % src)
		return false
	if bounds == Rect2i(Vector2i.ZERO, image.get_size()):
		push_error("%s has no transparent margin; background may be baked in" % src)
		return false

	bounds = bounds.grow(4).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var out := image.get_region(bounds)
	var target: int = job.size
	if job.axis == "width":
		var h := maxi(1, roundi(float(out.get_height()) * target / out.get_width()))
		out.resize(target, h, Image.INTERPOLATE_NEAREST)
	else:
		var w := maxi(1, roundi(float(out.get_width()) * target / out.get_height()))
		out.resize(w, target, Image.INTERPOLATE_NEAREST)

	# Generated chroma-key PNGs are RGB8. Convert before clearing the key;
	# otherwise transparent writes are silently flattened back to opaque white.
	out.convert(Image.FORMAT_RGBA8)
	_snap_palette(out)
	var err := out.save_png(job.dst)
	if err != OK:
		push_error("Could not save %s: %s" % [job.dst, error_string(err)])
		return false
	if job.dst.ends_with("rig_parts.png") and not _save_rig_parts(out):
		return false

	var colors := {}
	var transparent := 0
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			if c.a < 0.5:
				transparent += 1
			else:
				colors[c.to_rgba32()] = true
	print("NPC_ASSET %s size=%dx%d opaque_colors=%d transparent=%d" % [
		job.dst, out.get_width(), out.get_height(), colors.size(), transparent])
	return true


func _alpha_bounds(image: Image) -> Rect2i:
	var lo := image.get_size()
	var hi := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if not _is_background(image.get_pixel(x, y)):
				lo.x = mini(lo.x, x)
				lo.y = mini(lo.y, y)
				hi.x = maxi(hi.x, x)
				hi.y = maxi(hi.y, y)
	if hi.x < lo.x:
		return Rect2i()
	return Rect2i(lo, hi - lo + Vector2i.ONE)


func _snap_palette(image: Image) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var src := image.get_pixel(x, y)
			if _is_background(src):
				image.set_pixel(x, y, Color.TRANSPARENT)
				continue
			var best: Color = PALETTE[0]
			var best_d := INF
			for candidate in PALETTE:
				var dr: float = src.r - candidate.r
				var dg: float = src.g - candidate.g
				var db: float = src.b - candidate.b
				var d: float = dr * dr + dg * dg + db * db
				if d < best_d:
					best_d = d
					best = candidate
			image.set_pixel(x, y, best)


func _is_background(color: Color) -> bool:
	if color.a < 0.5:
		return true
	# Image generation may bake the transparency preview into the bitmap. The
	# technical source images therefore use a deliberately impossible costume
	# color as a chroma key. Keep the test broad enough for JPEG-like edge noise,
	# but require both red and blue dominance so the muted red shirt survives.
	return color.r > 0.72 and color.b > 0.62 \
		and color.r - color.g > 0.38 and color.b - color.g > 0.32


func _save_rig_parts(sheet: Image) -> bool:
	var ok := true
	for part in RIG_PARTS:
		var n: Rect2 = part.region
		var region := Rect2i(
			Vector2i(roundi(n.position.x * sheet.get_width()), roundi(n.position.y * sheet.get_height())),
			Vector2i(roundi(n.size.x * sheet.get_width()), roundi(n.size.y * sheet.get_height()))
		).intersection(Rect2i(Vector2i.ZERO, sheet.get_size()))
		var cut := sheet.get_region(region)
		var bounds := _alpha_bounds(cut)
		if bounds.size == Vector2i.ZERO:
			push_error("No opaque pixels in rig part %s" % part.name)
			ok = false
			continue
		bounds = bounds.grow(2).intersection(Rect2i(Vector2i.ZERO, cut.get_size()))
		cut = cut.get_region(bounds)
		var dst := "res://assets/npc_shadow/parts/%s.png" % part.name
		var err := cut.save_png(dst)
		if err != OK:
			push_error("Could not save %s: %s" % [dst, error_string(err)])
			ok = false
		else:
			print("NPC_PART %s size=%dx%d" % [dst, cut.get_width(), cut.get_height()])
	return ok
