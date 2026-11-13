// Shared by the weather shaders. Each particle is one quad of a MultiMesh;
// its position comes from its instance id and scene_time, wrapped into a box
// around whichever camera is rendering, so it works in the editor, the camera
// preview and the exported video, and always matches the timeline.

global uniform float scene_time;
global uniform float wind_strength;
global uniform vec2 wind_direction;

float whash(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

// Returns the particle centre in world space.
vec3 weather_position(int id, vec3 cam, float box, float height, float fall, float drift) {
	float f = float(id);
	vec2 wind = wind_direction * wind_strength * drift * scene_time;
	float bx = whash(f) * box + wind.x;
	float bz = whash(f + 17.0) * box + wind.y;
	float by = whash(f + 31.0) * height - fall * scene_time * (0.8 + 0.4 * whash(f + 5.0));
	vec3 p;
	p.x = cam.x + mod(bx - cam.x, box) - box * 0.5;
	p.z = cam.z + mod(bz - cam.z, box) - box * 0.5;
	p.y = cam.y + mod(by - cam.y, height) - height * 0.45;
	return p;
}
