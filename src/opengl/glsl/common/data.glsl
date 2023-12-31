uniform uint u_frame_no;
uniform uvec2 u_viewport_size;
uniform float u_aspect_ratio;
uniform Camera u_camera;

layout(std430, binding = 0) buffer geometry0 {
    vec4 vertices [];
};

layout(std430, binding = 1) buffer geometry1 {
    uint indices [];
};

layout(std430, binding = 2) buffer accel0 {
    BVHNode bvh [];
};
