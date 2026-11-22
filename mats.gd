extends RefCounted

var cache := {}


func tex(kind: String) -> ImageTexture:
    if cache.has("t_" + kind):
        return cache["t_" + kind]
    var S := 128
    var n := FastNoiseLite.new()
    n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    n.frequency = 0.03
    n.fractal_octaves = 3
    var noise: Image = n.get_seamless_image(S, S)
    var img := Image.create(S, S, false, Image.FORMAT_RGB8)
    for y in S:
        for x in S:
            var v: float = noise.get_pixel(x, y).r - 0.5
            var c := Color(0.7, 0.7, 0.7)
            match kind:
                "wall":
                    c = Color(0.7, 0.69, 0.66) + Color(1, 1, 1) * v * 0.22
                "floor":
                    c = Color(0.6, 0.61, 0.63) + Color(1, 1, 1) * v * 0.1
                    if x % 64 < 2 or y % 64 < 2:
                        c = Color(0.45, 0.46, 0.48)
                "dirt":
                    c = Color(0.36, 0.25, 0.15) + Color(1, 1, 1) * v * 0.22
                "rock":
                    c = Color(0.3, 0.27, 0.25) + Color(1, 1, 1) * v * 0.2
                "wood":
                    c = Color(0.55, 0.38, 0.2) + Color(1, 1, 1) * v * 0.1
                    if y % 32 < 2:
                        c = Color(0.25, 0.16, 0.08)
                "tealtile":
                    c = Color(0.55, 0.72, 0.68) + Color(1, 1, 1) * v * 0.05
                    if x % 32 < 2 or y % 32 < 2:
                        c = Color(0.14, 0.2, 0.2)
                "yellowtile":
                    c = Color(0.86, 0.79, 0.46) + Color(1, 1, 1) * v * 0.05
                    if x % 32 < 2 or y % 32 < 2:
                        c = Color(0.25, 0.2, 0.1)
                "metal":
                    c = Color(0.5, 0.52, 0.55) + Color(1, 1, 1) * v * 0.06
                "hazard":
                    if ((x + y) / 16) % 2 == 0:
                        c = Color(0.95, 0.75, 0.05)
                    else:
                        c = Color(0.08, 0.08, 0.08)
            img.set_pixel(x, y, c.clamp())
    img.generate_mipmaps()
    var t := ImageTexture.create_from_image(img)
    cache["t_" + kind] = t
    return t


func get_mat(kind: String, tint: Color = Color.WHITE) -> StandardMaterial3D:
    var key := kind + tint.to_html()
    if cache.has(key):
        return cache[key]
    var m := StandardMaterial3D.new()
    m.albedo_texture = tex(kind)
    m.albedo_color = tint
    m.uv1_triplanar = true
    m.uv1_world_triplanar = true
    m.uv1_scale = Vector3(0.5, 0.5, 0.5)
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    m.roughness = 0.9
    cache[key] = m
    return m


func glow(col: Color, energy: float = 1.5) -> StandardMaterial3D:
    var key := "g" + col.to_html() + str(energy)
    if cache.has(key):
        return cache[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = col
    m.emission_enabled = true
    m.emission = col
    m.emission_energy_multiplier = energy
    cache[key] = m
    return m


func paint(col: Color, metal: float = 0.0, rough: float = 0.6) -> StandardMaterial3D:
    var key := "p" + col.to_html() + str(metal) + str(rough)
    if cache.has(key):
        return cache[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = col
    m.metallic = metal
    m.roughness = rough
    cache[key] = m
    return m


const ARM_SHADER := "
shader_type spatial;
uniform sampler2D fur_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float blood = 0.5;
varying vec3 lp;
float hh(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
void vertex() { lp = VERTEX; }
void fragment() {
    vec3 t = texture(fur_tex, UV * 2.0).rgb * tint.rgb;
    float n = hh(floor(lp * vec3(26.0, 10.0, 26.0))) * 0.65 + hh(floor(lp * 9.0)) * 0.35;
    float b = smoothstep(1.0 - blood * 0.55, 1.0, n);
    ALBEDO = mix(t, vec3(0.5, 0.02, 0.02), b * 0.92);
    ROUGHNESS = mix(0.9, 0.2, b);
}
"


func arm_material(tex: Texture2D) -> ShaderMaterial:
    var sh := Shader.new()
    sh.code = ARM_SHADER
    var m := ShaderMaterial.new()
    m.shader = sh
    if tex:
        m.set_shader_parameter("fur_tex", tex)
    else:
        var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
        img.fill(Color(0.1, 0.7, 0.1))
        m.set_shader_parameter("fur_tex", ImageTexture.create_from_image(img))
    return m
