shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform float motion = 0.75;
varying float phase;
void vertex() {
	phase = INSTANCE_CUSTOM.r * 6.28318;
	VERTEX.x += sin(TIME * 0.5 + phase) * 5.0 * motion;
	VERTEX.y += sin(TIME * 0.8 + phase) * 4.0 * motion;
}
void fragment() {
	ALBEDO = mix(vec3(0.35,0.75,0.69),vec3(1.0,0.82,0.48),0.5+0.5*sin(phase));
	ALBEDO *= 0.65+0.35*sin(TIME*motion+phase);
}
