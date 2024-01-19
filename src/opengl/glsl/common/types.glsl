struct Camera {
    vec3 eye;
    vec3 dir;
    vec3 up;
};

struct Ray {
    vec3 o;
    vec3 d;
    vec3 rD;
    float t;
};

struct OpenPBRMaterial {
    float base_weight;
    vec3  base_color;
    float base_roughness;
    float base_metalness;
};

struct SurfaceInteraction {
    vec3 p;
    vec3 n;
    vec3 w_i;
    vec3 w_o;
    OpenPBRMaterial mat;
    bool valid;
};

struct BVHNode {
    vec4 aabb_min;
    vec4 aabb_max;
    uint left_child;
    uint first_tri_index_id;
    uint tri_count;
    uint filler; // TODO: Figure out a better way to deal with alignments
};

struct RNG {
    uint state;
};
