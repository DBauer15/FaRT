#pragma once

#include <glm/glm.hpp>

namespace fart {

struct OpenPBRMaterial {

    /* Base */
    alignas(16) glm::vec3   base_color;
    float       base_weight; 
    float       base_roughness;
    float       base_metalness;

    /* Specular */
    alignas(16) glm::vec3   specular_color;
    float       specular_weight;
    float       specular_roughness;
    float       specular_anisotropy;
    float       specular_rotation;
    float       specular_ior;
    float       specular_ior_level;

    static OpenPBRMaterial defaultMaterial() {
        OpenPBRMaterial pbr_mat;

        pbr_mat.base_color         = glm::vec3(0.8f, 0.8f, 0.8f);
        pbr_mat.base_weight        = 1.f;
        pbr_mat.base_roughness     = 0.f;
        pbr_mat.base_metalness     = 0.f;

        pbr_mat.specular_color         = glm::vec3(1.f, 1.f, 1.f);
        pbr_mat.specular_weight        = 1.f;
        pbr_mat.specular_roughness     = 0.3f;
        pbr_mat.specular_anisotropy    = 0.f;
        pbr_mat.specular_rotation      = 0.f;
        pbr_mat.specular_ior           = 1.5f;
        pbr_mat.specular_ior_level     = 0.5f;
        
        return pbr_mat;
    }

};

}