class_name BoardMaterials
extends RefCounted

enum TerrainType {
	FOREST,
	HILLS,
	PASTURE,
	FIELDS,
	MOUNTAINS,
	DESERT
}


func make_tile_material(terrain: int) -> Material:
	match terrain:
		TerrainType.MOUNTAINS: return _mountains_shader()
		TerrainType.FIELDS: return _fields_shader()
		TerrainType.FOREST: return _forest_shader()
		TerrainType.HILLS: return _hills_shader()
		TerrainType.PASTURE: return _pasture_shader()
		TerrainType.DESERT: return _desert_shader()
		_:
			return solid_mat(Color(0.5, 0.5, 0.5), 0.9, 0.0)


func solid_mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat


func _mountains_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, specular_schlick_ggx;
varying vec2 v_pos;
float h21(vec2 p) { p = fract(p * vec2(127.1, 311.7)); p += dot(p, p.yx + 19.19); return fract(p.x * p.y); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h21(i), h21(i+vec2(1,0)), f.x), mix(h21(i+vec2(0,1)), h21(i+vec2(1,1)), f.x), f.y); }
void vertex() { v_pos = VERTEX.xz; }
void fragment() {
	float n = vn(v_pos * 4.5) * 0.55 + vn(v_pos * 9.0 + 2.3) * 0.30 + vn(v_pos * 18.0 + 5.1) * 0.15;
	vec3 rock = mix(vec3(0.24, 0.24, 0.28), vec3(0.56, 0.56, 0.61), n);
	float vein_n = vn(v_pos * 6.5 + vec2(TIME * 0.08, TIME * 0.05)) * 0.6 + vn(v_pos * 13.0 + 3.7) * 0.4;
	float vein = smoothstep(0.73, 0.77, vein_n);
	float pulse = 0.5 + 0.5 * sin(TIME * 2.0 + vein_n * 9.0);
	vec3 ore = vec3(0.12, 0.25, 0.92);
	vec3 col = mix(rock, ore * 0.7, vein * 0.7);
	ALBEDO = col; ROUGHNESS = mix(0.82, 0.28, vein); METALLIC = mix(0.08, 0.55, vein); EMISSION = ore * vein * pulse * 1.4; SPECULAR = mix(0.30, 0.90, vein);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _fields_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_mix, depth_draw_opaque;
varying vec2 v_pos;
float h21(vec2 p) { p = fract(p * vec2(127.1, 311.7)); p += dot(p, p.yx + 19.19); return fract(p.x * p.y); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h21(i), h21(i+vec2(1,0)), f.x), mix(h21(i+vec2(0,1)), h21(i+vec2(1,1)), f.x), f.y); }
void vertex() { v_pos = VERTEX.xz; }
void fragment() {
	float wave = sin(v_pos.x * 5.5 - v_pos.y * 2.0 + TIME * 1.4) * 0.5 + 0.5;
	wave = wave * 0.7 + vn(v_pos * 5.0 + TIME * 0.15) * 0.3;
	vec3 shadow = vec3(0.58, 0.44, 0.04);
	vec3 light = vec3(0.95, 0.83, 0.12);
	vec3 col = mix(shadow, light, wave);
	ALBEDO = col; ROUGHNESS = 0.90; METALLIC = 0.0; EMISSION = light * wave * 0.07;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _forest_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_mix, depth_draw_opaque;
varying vec2 v_pos;
float h21(vec2 p) { p = fract(p * vec2(127.1, 311.7)); p += dot(p, p.yx + 19.19); return fract(p.x * p.y); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h21(i), h21(i+vec2(1,0)), f.x), mix(h21(i+vec2(0,1)), h21(i+vec2(1,1)), f.x), f.y); }
void vertex() { v_pos = VERTEX.xz; }
void fragment() {
	vec2 drift = vec2(TIME * 0.09, TIME * 0.06);
	float beam = vn(v_pos * 2.8 + drift) * 0.55 + vn(v_pos * 5.5 + drift * 1.4 + 1.7) * 0.30 + vn(v_pos * 11.0 + 3.3) * 0.15;
	float ground = vn(v_pos * 7.0 + 0.9) * 0.6 + vn(v_pos * 14.0 + 4.1) * 0.4;
	vec3 deep = vec3(0.03, 0.16, 0.03);
	vec3 mid = vec3(0.07, 0.28, 0.05);
	vec3 bright = vec3(0.22, 0.58, 0.08);
	vec3 col = mix(deep, mid, ground);
	col = mix(col, bright, smoothstep(0.48, 0.78, beam));
	ALBEDO = col; ROUGHNESS = 0.94; EMISSION = bright * smoothstep(0.62, 0.85, beam) * 0.08;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _hills_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_mix, depth_draw_opaque;
varying vec2 v_pos;
float h21(vec2 p) { p = fract(p * vec2(127.1, 311.7)); p += dot(p, p.yx + 19.19); return fract(p.x * p.y); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h21(i), h21(i+vec2(1,0)), f.x), mix(h21(i+vec2(0,1)), h21(i+vec2(1,1)), f.x), f.y); }
void vertex() { v_pos = VERTEX.xz; }
void fragment() {
	float clay_n = vn(v_pos * 3.5) * 0.55 + vn(v_pos * 7.0 + 1.8) * 0.45;
	vec3 dark_clay = vec3(0.48, 0.14, 0.04);
	vec3 light_clay = vec3(0.78, 0.30, 0.10);
	vec3 col = mix(dark_clay, light_clay, clay_n);
	float crack_n = vn(v_pos * 4.8 + 2.2) * 0.6 + vn(v_pos * 9.5 + 5.0) * 0.4;
	float crack = 1.0 - smoothstep(0.0, 0.06, abs(crack_n - 0.5));
	col = mix(col, vec3(0.20, 0.06, 0.01), crack * 0.65);
	float glow = smoothstep(0.55, 0.85, clay_n);
	ALBEDO = col; ROUGHNESS = 0.91; METALLIC = 0.02; EMISSION = vec3(0.55, 0.12, 0.01) * glow * 0.06;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _pasture_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_mix, depth_draw_opaque;
varying vec2 v_pos;
float h21(vec2 p) { p = fract(p * vec2(127.1, 311.7)); p += dot(p, p.yx + 19.19); return fract(p.x * p.y); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h21(i), h21(i+vec2(1,0)), f.x), mix(h21(i+vec2(0,1)), h21(i+vec2(1,1)), f.x), f.y); }
void vertex() { v_pos = VERTEX.xz; }
void fragment() {
	float w1 = sin(v_pos.x * 5.5 + v_pos.y * 2.0 + TIME * 1.9) * 0.5 + 0.5;
	float w2 = sin(v_pos.x * 2.5 - v_pos.y * 5.0 - TIME * 1.3) * 0.5 + 0.5;
	float w3 = vn(v_pos * 4.0 + vec2(TIME * 0.12, TIME * 0.08)) * 0.4 + 0.3;
	float wave = w1 * 0.40 + w2 * 0.35 + w3 * 0.25;
	vec3 shadow = vec3(0.10, 0.34, 0.05);
	vec3 bright = vec3(0.42, 0.82, 0.14);
	vec3 col = mix(shadow, bright, wave);
	ALBEDO = col; ROUGHNESS = 0.93; EMISSION = bright * smoothstep(0.65, 0.90, wave) * 0.06;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _desert_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_mix, depth_draw_opaque;
varying vec2 v_pos;
float h21(vec2 p) { p = fract(p * vec2(127.1, 311.7)); p += dot(p, p.yx + 19.19); return fract(p.x * p.y); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h21(i), h21(i+vec2(1,0)), f.x), mix(h21(i+vec2(0,1)), h21(i+vec2(1,1)), f.x), f.y); }
void vertex() { v_pos = VERTEX.xz; }
void fragment() {
	float r = length(v_pos);
	float ripple = sin(r * 9.0 - TIME * 0.7) * 0.5 + 0.5;
	float noise = vn(v_pos * 3.2 + vec2(TIME * 0.05, 0.0)) * 0.5 + vn(v_pos * 6.5 + 1.9) * 0.3;
	float dune = ripple * 0.65 + noise * 0.35;
	vec3 trough = vec3(0.68, 0.52, 0.24);
	vec3 crest = vec3(0.97, 0.84, 0.52);
	vec3 col = mix(trough, crest, dune);
	float heat = smoothstep(0.62, 0.90, dune);
	ALBEDO = col; ROUGHNESS = 0.96; EMISSION = vec3(0.80, 0.45, 0.08) * heat * 0.10;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat
