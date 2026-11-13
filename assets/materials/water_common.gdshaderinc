// Shared by water.gdshader and water_bank.gdshader.
//
// Water meshes store local position in metres in UV (rivers: x = metres from
// the centre line, y = metres along the river). water_edge() returns the
// distance in metres to the water's edge: positive inside, negative outside.
//
// shape: 0 natural pond, 1 round, 2 rectangle, 3 river, 4 coast (y = metres
// out to sea from the shoreline).

float water_edge(vec2 p, int kind, vec2 dims, float variant) {
	if (kind == 2) {
		vec2 d = dims * 0.5 - abs(p);
		return min(d.x, d.y);
	}
	if (kind == 3) {
		float half_width = dims.x * 0.5;
		float along = min(p.y, dims.y - p.y);
		if (along < half_width) {
			// Rounded ends, so a river fades out instead of being cut off.
			return half_width - length(vec2(p.x, half_width - along));
		}
		return half_width - abs(p.x);
	}
	if (kind == 4) {
		float wobble = sin(p.x * 0.031 + variant) * 4.0
			+ sin(p.x * 0.077 + variant * 2.3) * 1.6
			+ sin(p.x * 0.19 + variant * 3.1) * 0.5;
		return p.y - wobble;
	}
	vec2 radii = max(dims * 0.5, vec2(0.05));
	float r = length(p / radii);
	float bound = 1.0;
	if (kind == 0) {
		float a = atan(p.y, p.x);
		bound = (1.0 + 0.10 * sin(3.0 * a + variant)
			+ 0.06 * sin(5.0 * a + variant * 2.1)
			+ 0.035 * sin(8.0 * a + variant * 4.3)) / 1.2;
	}
	return (bound - r) * min(radii.x, radii.y);
}
