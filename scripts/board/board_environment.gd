class_name BoardEnvironment
extends RefCounted


func spawn_port_markers(parent: Node3D) -> void:
	const RES_COLORS: Array = [
		Color(0.12, 0.42, 0.08),
		Color(0.65, 0.20, 0.06),
		Color(0.28, 0.68, 0.12),
		Color(0.85, 0.70, 0.04),
		Color(0.38, 0.40, 0.50),
	]
	const RES_SHORT: Array = ["LU", "BR", "WO", "GR", "OR"]
	const HARBORS: Array = [
		{"type": -1, "px": -5.51, "pz": 3.18},
		{"type": -1, "px": -2.21, "pz": 5.73},
		{"type": 3, "px": 3.31, "pz": 4.46},
		{"type": 4, "px": 5.51, "pz": 3.18},
		{"type": -1, "px": 5.51, "pz": -3.18},
		{"type": 0, "px": 2.21, "pz": -5.73},
		{"type": -1, "px": -3.31, "pz": -4.46},
		{"type": 1, "px": -5.51, "pz": -3.18},
		{"type": 2, "px": -5.51, "pz": 0.64},
	]

	for h: Dictionary in HARBORS:
		var h_type: int = h["type"]
		var pos := Vector3(h["px"], 0.10, h["pz"])

		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.06
		pm.bottom_radius = 0.08
		pm.height = 0.28
		pm.radial_segments = 8
		post.mesh = pm
		post.position = pos + Vector3(0, 0.14, 0)
		var pier_col: Color = Color(0.80, 0.65, 0.30) if h_type == -1 else RES_COLORS[h_type]
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = pier_col
		pmat.emission_enabled = true
		pmat.emission = pier_col * 0.6
		pmat.emission_energy_multiplier = 0.8
		post.material_override = pmat
		parent.add_child(post)

		var lbl := Label3D.new()
		if h_type == -1:
			lbl.text = "3:1"
			lbl.modulate = Color(1.0, 0.90, 0.55)
		else:
			lbl.text = "2:1\n%s" % RES_SHORT[h_type]
			lbl.modulate = RES_COLORS[h_type] * 1.8
		lbl.position = pos + Vector3(0, 0.55, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.pixel_size = 0.004
		lbl.font_size = 52
		lbl.outline_size = 7
		lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
		lbl.no_depth_test = true
		lbl.render_priority = 1
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		parent.add_child(lbl)


func spawn_ocean_plane(parent: Node3D) -> void:
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(72.0, 72.0)
	mesh.subdivide_width = 160
	mesh.subdivide_depth = 160
	plane.mesh = mesh
	plane.position = Vector3(0.0, -0.10, 0.0)
	plane.name = "TerrainPlane"

	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

uniform vec4  u_sand_dry  : source_color = vec4(0.84, 0.72, 0.48, 1.0);
uniform vec4  u_sand_wet  : source_color = vec4(0.60, 0.50, 0.33, 1.0);
uniform vec4  u_shallow   : source_color = vec4(0.10, 0.46, 0.72, 1.0);
uniform vec4  u_deep      : source_color = vec4(0.01, 0.10, 0.30, 1.0);
uniform vec4  u_foam      : source_color = vec4(0.88, 0.95, 1.00, 1.0);
uniform float u_dry_end    = 6.0;
uniform float u_shore_end  = 7.6;
uniform float u_ocean_full = 9.5;
uniform float u_wave_h     = 0.14;
uniform float u_wave_scale = 1.6;

varying vec2  v_xz;
varying float v_ocean;

float h21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p.yx + 19.19);
	return fract(p.x * p.y);
}
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i+vec2(1,0)), f.x),
	           mix(h21(i+vec2(0,1)), h21(i+vec2(1,1)), f.x), f.y);
}

void vertex() {
	v_xz   = VERTEX.xz;
	float r = length(v_xz);
	v_ocean = smoothstep(u_shore_end - 0.5, u_ocean_full, r);

	float h = 0.0, nx = 0.0, nz = 0.0;

	vec2 d1 = normalize(vec2( 1.0,  0.5)); float q1 = 0.9*u_wave_scale, a1 = u_wave_h;
	float p1 = dot(d1,v_xz)*q1 + TIME*1.1;
	h += a1*sin(p1); nx += a1*cos(p1)*q1*d1.x; nz += a1*cos(p1)*q1*d1.y;

	vec2 d2 = normalize(vec2(-0.6,  1.0)); float q2 = 1.3*u_wave_scale, a2 = u_wave_h*0.55;
	float p2 = dot(d2,v_xz)*q2 + TIME*0.9;
	h += a2*sin(p2); nx += a2*cos(p2)*q2*d2.x; nz += a2*cos(p2)*q2*d2.y;

	vec2 d3 = normalize(vec2( 0.4, -0.9)); float q3 = 2.1*u_wave_scale, a3 = u_wave_h*0.28;
	float p3 = dot(d3,v_xz)*q3 + TIME*1.4;
	h += a3*sin(p3); nx += a3*cos(p3)*q3*d3.x; nz += a3*cos(p3)*q3*d3.y;

	vec2 d4 = normalize(vec2(-1.0,  0.2)); float q4 = 3.2*u_wave_scale, a4 = u_wave_h*0.12;
	float p4 = dot(d4,v_xz)*q4 + TIME*1.7;
	h += a4*sin(p4); nx += a4*cos(p4)*q4*d4.x; nz += a4*cos(p4)*q4*d4.y;

	VERTEX.y += h * v_ocean;
	NORMAL = normalize(vec3(-nx*v_ocean, 1.0, -nz*v_ocean));
}

void fragment() {
	float r = length(v_xz);

	float wet_t  = smoothstep(u_dry_end, u_shore_end, r);
	vec3 sand = mix(u_sand_dry.rgb, u_sand_wet.rgb, wet_t);

	float deep_t = smoothstep(u_shore_end, u_ocean_full + 2.0, r);
	vec3 water = mix(u_shallow.rgb, u_deep.rgb, deep_t);

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.5);
	water = mix(water, u_shallow.rgb * 1.3, fresnel * 0.30 * v_ocean);

	vec2 fc = v_xz * 0.55 + vec2(TIME * 0.045, TIME * 0.028);
	float fn = vn(fc) * 0.55 + vn(fc * 1.8 + 4.1) * 0.30 + vn(fc * 3.1 + 8.3) * 0.15;
	float foam_t = smoothstep(0.72, 0.92, fn) * v_ocean;
	water = mix(water, u_foam.rgb, foam_t * 0.22);

	float shore_r = (u_shore_end + u_ocean_full) * 0.5;
	float shore_f = smoothstep(1.0, 0.0, abs(r - shore_r) / 0.9) * v_ocean;
	water = mix(water, u_foam.rgb, shore_f * 0.22);

	float water_t = smoothstep(u_shore_end - 0.4, u_shore_end + 0.6, r);
	vec3 col = mix(sand, water, water_t);

	float edge_fade = smoothstep(34.0, 48.0, r);
	col = mix(col, u_deep.rgb * 0.6, edge_fade);

	ALBEDO = col;
	EMISSION = sand * (1.0 - water_t) * 0.10;
	ROUGHNESS = mix(0.97, mix(0.03, 0.15, 1.0 - fresnel), water_t);
	METALLIC = mix(0.0, 0.60, water_t);
	SPECULAR = mix(0.05, 0.95, water_t);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	plane.material_override = mat
	parent.add_child(plane)
