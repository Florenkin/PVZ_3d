shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled;
uniform vec4 fog_color : source_color = vec4(0.77, 0.86, 0.87, 0.42);
void fragment() {
    ALBEDO = fog_color.rgb;
    ALPHA = fog_color.a * pow(max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 1.5);
}
