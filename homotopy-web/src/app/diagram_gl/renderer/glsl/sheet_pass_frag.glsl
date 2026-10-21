#version 300 es

// Forward pass for translucent sheets, drawn after the deferred lighting pass.
// Lighting matches lighting_pass_frag.glsl; occlusion by opaque geometry is
// tested against the view-space positions already stored in the G-buffer.

precision highp float;

uniform vec3 albedo;
uniform float opacity;

uniform sampler2D g_position;
uniform sampler2D g_albedo;

uniform float alpha;
uniform float spec;
uniform float gamma;

uniform vec3 camera_pos;

in float hidden;
in vec3 frag_pos;
in vec3 frag_normal;

out vec4 frag_color;

const float a = 0.5;
const int LIGHTS = 5;
const vec3 light_offsets[LIGHTS] = vec3[LIGHTS](
  vec3(0., 0., .25 * sqrt(3.)),
  vec3(-.5, 0., -.25 * sqrt(3.)),
  vec3(.5, 0., -.25 * sqrt(3.)),
  vec3(0., 1., 0.),
  vec3(0., -1., 0.)
);

void main() {
    if (hidden != 0.) {
        discard;
    }

    // Hide the sheet where opaque geometry lies in front of it. View space
    // looks down -z, so nearer points have larger z.
    ivec2 texel = ivec2(gl_FragCoord.xy);
    vec4 opaque = texelFetch(g_albedo, texel, 0);
    vec3 opaque_pos = texelFetch(g_position, texel, 0).xyz;
    if (opaque.a > 0.5 && opaque_pos.z > frag_pos.z + 1e-3) {
        discard;
    }

    vec3 normal = normalize(frag_normal);
    if (!gl_FrontFacing) {
        normal = -normal;
    }

    float camera_distance = length(camera_pos);
    vec3 color = a * albedo;
    for (int i = 0; i < LIGHTS; i++) {
        vec3 s = vec3(spec);
        vec3 d = 300. * light_offsets[i] + vec3(0., 0., -camera_distance) - frag_pos;
        vec3 l = normalize(d);

        float lambertian = max(dot(l, normal), 0.);
        float specular = 0.;

        if (lambertian > 0.) {
            vec3 view = normalize(-frag_pos);
            vec3 halfway = normalize(l + view);
            float theta = max(dot(halfway, normal), 0.);
            specular = pow(theta, alpha);
        }

        color += 0.4 * ((albedo + 0.01) * lambertian + s * specular);
    }

    frag_color = vec4(pow(color, vec3(1. / gamma)), opacity);
}
