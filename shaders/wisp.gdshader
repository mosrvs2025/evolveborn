shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// The player's body. Semi-liquid: the surface is always moving slightly, the
// silhouette is a fresnel rim so it reads against dark caves, and the Core
// shows through from inside.

uniform vec4 tint : source_color = vec4(0.45, 0.85, 0.95, 1.0);
uniform vec4 rim : source_color = vec4(0.6, 1.0, 1.0, 1.0);
uniform float wobble = 0.045;
uniform float wobble_speed = 2.2;
uniform float alpha = 0.78;
uniform float charge = 0.0;      // rises while an ability is charging / on hit
uniform float smoke = 0.0;       // Shadow Membrane makes the edges give up

varying float v_rim_boost;

void vertex() {
	float t = TIME * wobble_speed;
	float d =
		sin(VERTEX.y * 6.1 + t) *
		cos(VERTEX.x * 5.3 - t * 0.83) *
		sin(VERTEX.z * 5.7 + t * 1.31);
	float pulse = 1.0 + charge * 0.45;
	VERTEX += NORMAL * d * wobble * pulse;
	v_rim_boost = d * 0.5 + 0.5;
}

void fragment() {
	float f = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fres = pow(f, 2.1);
	ALBEDO = tint.rgb;
	ALPHA = clamp(alpha + fres * 0.5 - smoke * 0.35 * (1.0 - fres), 0.05, 1.0);
	EMISSION = rim.rgb * (fres * 1.5 + v_rim_boost * 0.12 + charge * 0.6);
	ROUGHNESS = 0.22;
	SPECULAR = 0.65;
}
