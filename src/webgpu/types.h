#pragma once

#include <glm/glm.hpp>

namespace fart {

struct WebGPURendererUniforms {
    alignas(4) uint32_t frame_number;
    alignas(4) float scene_scale;
    alignas(4) float aspect_ratio;
    alignas(16) glm::vec4 eye;
    alignas(16) glm::vec4 dir;
    alignas(16) glm::vec4 up;
    alignas(16) glm::u32vec4 viewport_size;
};

struct Vertex {
    alignas(16) glm::vec4 position;
    alignas(16) glm::vec4 normal;
    alignas(16) glm::vec4 uv;
};

struct Material {
    alignas(16) glm::vec4 base_color;
    alignas(16) glm::vec4 specular_color;

    alignas(4) int32_t base_color_texid;
    alignas(4) float base_weight;
    alignas(4) float base_roughness;
    alignas(4) float base_metalness;

    alignas(4) float specular_weight;
    alignas(4) float specular_roughness;
    alignas(4) float specular_anisotropy;
    alignas(4) float specular_rotation;

    alignas(4) float specular_ior;
    alignas(4) float specular_ior_level;
    alignas(4) float transmission_weight;
    alignas(4) float geometry_opacity;

    alignas(4) int32_t geometry_opacity_texid;
    alignas(4) float pad0;
    alignas(4) float pad1;
    alignas(4) float pad2;
};

}
