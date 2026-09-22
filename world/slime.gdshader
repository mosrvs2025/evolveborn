shader_type spatial;
render_mode specular_schlick_ggx;
uniform float motion = 0.75;
void vertex() {
	VERTEX += NORMAL * sin(VERTEX.y * 9.0 + VERTEX.x * 5.0 + TIME * 2.5) * 0.025 * motion;
}
void fragment() {
	float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 2.5);
	ALBEDO = mix(vec3(0.13,0.58,0.49),vec3(0.65,0.98,0.77),rim);
	ROUGHNESS = 0.19;
	SPECULAR = 0.8;
	METALLIC = 0.12;
	EMISSION = vec3(0.13,0.42,0.30)*rim*0.5;
}
