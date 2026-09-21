shader_type spatial;
render_mode diffuse_burley;
uniform vec4 base_color : source_color = vec4(0.12,0.24,0.23,1.0);
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float n=noise(world_position.xz*0.65)*0.65+noise(world_position.xz*3.0)*0.35;
 ALBEDO=base_color.rgb*(0.75+n*0.65);
 ROUGHNESS=0.95;
}
