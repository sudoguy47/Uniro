#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// Stretch overscroll fragment shader
// Compiled once, cached globally, and executed on the GPU with zero raster stalls.

uniform vec2 u_size;
uniform float u_max_stretch_intensity;
uniform float u_overscroll_x;
uniform float u_overscroll_y;
uniform float u_interpolation_strength;
uniform sampler2D u_texture;

out vec4 fragColor;

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;

    // Safety guard against uninitialized or zero-size render objects
    if (u_size.x <= 0.0 || u_size.y <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 uv = fragCoord / u_size;
    bool isVertical = abs(u_overscroll_y) > 0.0001;
    float overscroll = isVertical ? u_overscroll_y : u_overscroll_x;

    // Fast-path bypass: zero stretch calculations during normal scrolling
    if (abs(overscroll) < 0.0001) {
        fragColor = texture(u_texture, uv);
        return;
    }

    // Branchless, uniform-optimized stretch calculation for mobile GPU execution
    float absOverscroll = min(abs(overscroll), u_max_stretch_intensity);
    float normDist = 1.0 / (1.0 + absOverscroll);
    float pos = isVertical ? uv.y : uv.x;

    float offsetPos = (overscroll > 0.0) ? (1.0 - pos) : pos;
    float posVariation = mix(1.0, offsetPos, u_interpolation_strength);
    float stretchIntensity = absOverscroll * posVariation;
    float deformed = normDist - (offsetPos / (1.0 + stretchIntensity));
    float finalCoord = (overscroll > 0.0) ? deformed : (1.0 - deformed);

    if (isVertical) {
        uv.y = clamp(finalCoord, 0.0, 1.0);
    } else {
        uv.x = clamp(finalCoord, 0.0, 1.0);
    }

    fragColor = texture(u_texture, uv);
}
