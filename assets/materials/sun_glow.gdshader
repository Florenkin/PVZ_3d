shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.18, 0.25);

void fragment() {
	float radius = length((UV - vec2(0.5)) * 2.0);
	ALBEDO = tint.rgb;
	ALPHA = tint.a * pow(1.0 - smoothstep(0.05, 1.0, radius), 2.0);
}
