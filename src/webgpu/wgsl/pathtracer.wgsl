/* Constants */
const MIN_RR_DEPTH: u32 = 3;
const MAX_BOUNCES: u32 = 5;
const EPS: f32 = 1e-5;
const ONE_OVER_PI: f32 = 0.3183098862;
const PI_OVER_TWO: f32 = 1.5707963268;
const PI_OVER_FOUR: f32 = 0.7853981634;
/* Constants */

/* Types */
struct Uniforms {
    frame_number: u32,
    scene_scale: f32,
    aspect_ratio: f32,
    eye: vec3f,
    dir: vec3f,
    up:  vec3f,
    viewport_size: vec3u,
};

struct Vertex {
    position: vec3f,
    normal: vec3f, 
    uv: vec2f,
    material_id: u32,
};

struct Ray {
    o: vec3f,
    d: vec3f,
    rD: vec3f,
    t: f32,
};

struct OpenPBRMaterial {
    base_color: vec3f,
    specular_color: vec3f,
    base_color_texid: i32,
    base_weight: f32,
    base_roughness: f32,
    base_metalness: f32,

    specular_weight: f32,
    specular_roughness: f32,
    specular_anisotropy: f32,
    specular_rotation: f32,
    specular_ior: f32,
    specular_ior_level: f32,

    transmission_weight: f32,

    geometry_opacity: f32,
    geometry_opacity_texid: i32,

    pad0: i32,
    pad1: i32,
    pad2: i32,
};

struct SurfaceInteraction {
    p: vec3f,
    n: vec3f,
    w_i: vec3f,
    w_o: vec3f,
    uv: vec2f,
    material: OpenPBRMaterial,
    valid: bool,
};

struct BVHNode {
    left_child: u32,
    first_tri_index_id: u32,
    tri_count: u32,
    aabb_min: vec3f,
    aabb_max: vec3f,
};

struct RNG {
    state: u32,
};
/* Types */

/* Data */
@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var<storage,read> vertices: array<Vertex>;
@group(0) @binding(2) var<storage,read> indices: array<u32>;
@group(0) @binding(3) var<storage,read> materials: array<OpenPBRMaterial>;
@group(0) @binding(4) var<storage,read> bvh: array<BVHNode>;
@group(0) @binding(5) var dst_texture: texture_storage_2d<rgba16float,write>;
@group(0) @binding(6) var src_texture: texture_2d<f32>;

/* Data */

/* Random */
fn murmurhash3_mix(hash: u32, k: u32) -> u32 {
    let c1: u32 = 0xcc9e2d51u;
    let c2: u32 = 0x1b873593u;
    let r1: u32 = 15u;
    let r2: u32 = 13u;
    let m: u32 = 5u;
    let n: u32 = 0xe6546b64u;

    var _k = k * c1;
    _k = (_k << r1) | (_k >> (32 - r1));
    _k *= c2;

    var _hash = hash ^ _k;
    _hash = ((_hash << r2) | (_hash >> (32 - r2))) * m + n;
    
    return _hash;
}

fn murmurhash3_finalize(hash: u32) -> u32 {
    var _hash = hash;
    _hash ^= _hash >> 16;
    _hash *= 0x85ebca6bu;
    _hash ^= _hash >> 13;
    _hash *= 0xc2b2ae35u;
    _hash ^= _hash >> 16;

    return _hash;
}

fn make_random(pixel_id: u32, frame_no: u32) -> RNG {
    var rng: RNG;
    rng.state = murmurhash3_mix(0u, pixel_id);
    rng.state = murmurhash3_mix(rng.state, frame_no);
    rng.state = murmurhash3_finalize(rng.state);

    return rng;
}

fn next_random(rng: ptr<function,RNG>) -> u32 {
    (*rng).state = 1664525u * (*rng).state + 1013904223u;
    return (*rng).state;
}

fn next_randomf(rng: ptr<function,RNG>) -> f32 {
    let r = next_random(rng);
    return bitcast<f32>((r & 0x007FFFFFu) | 0x3F800000u) - 1.0;
}

fn next_random2f(rng: ptr<function,RNG>) -> vec2f {
    return vec2f(next_randomf(rng), next_randomf(rng));
}

fn next_random3f(rng: ptr<function,RNG>) -> vec3f {
    return vec3f(next_randomf(rng), next_randomf(rng), next_randomf(rng));
}
/* Random */

/* Sampling */ 
fn reorient(dir: vec3f, normal: vec3f) -> vec3f {
    var sgn: f32 = 1.f;
    if (normal.z < 0.f) {
        sgn = -1.f;
    }
    let a: f32 = -1.f / (sgn + normal.z);
    let b: f32 = normal.x * normal.y * a;

    let tangent: vec3f = vec3f(
        1.f + sgn * normal.x * normal.x * a,
        sgn * b,
        -sgn * normal.x
    );
    let bitangent: vec3f = vec3f(
        b,
        sgn + normal.y * normal.y *  a,
        -normal.y
    );

    return dir.x * tangent + dir.y * bitangent + dir.z * normal;
}

fn randomDiskPoint(rand: vec2f) -> vec2f {
    let u_offset: vec2f = 2.f * rand.xy - vec2f(1.f);
    if (u_offset.x == 0.f && u_offset.y == 0.f) {
        return vec2f(0.f);
    }

    var theta: f32;
    var r: f32;

    if (abs(u_offset.x) > abs(u_offset.y)) {
        r = u_offset.x;
        theta = PI_OVER_FOUR * (u_offset.y / u_offset.x);
    } else {
        r = u_offset.y;
        theta = PI_OVER_TWO - PI_OVER_FOUR * (u_offset.x / u_offset.y);
    }

    return r * vec2f(cos(theta), sin(theta));
}

fn randomCosineHemispherePoint(rand: vec2f, n: vec3f) -> vec3f {
    let p: vec2f = randomDiskPoint(rand);
    let z: f32 = sqrt(max(0.f, 1.f - p.x*p.x - p.y*p.y));
    let dir: vec3f = vec3f(p, z);

    return reorient(dir, n);
}
/* Sampling */ 

/* Intersect */
fn getNormal(first_index: u32, bary: vec3f) -> vec3f {
    let n0: vec3f = vertices[indices[first_index+0]].normal.xyz;
    let n1: vec3f = vertices[indices[first_index+1]].normal.xyz;
    let n2: vec3f = vertices[indices[first_index+2]].normal.xyz;

    return normalize(n0 * bary.x + n1 * bary.y + n2 * bary.z);
}

fn getUV(first_index: u32, bary: vec3f) -> vec2f {
    let uv0: vec2f = vertices[indices[first_index+0]].uv.xy;
    let uv1: vec2f = vertices[indices[first_index+1]].uv.xy;
    let uv2: vec2f = vertices[indices[first_index+2]].uv.xy;

    return uv0 * bary.x + uv1 * bary.y + uv2 * bary.z;
}


fn intersectTriangle(ray: ptr<function,Ray>, 
                     si: ptr<function,SurfaceInteraction>,
                     first_index: u32) -> bool
{
    let material_id = vertices[indices[first_index+0]].material_id;
    let v0 = vertices[indices[first_index+0]].position.xyz;
    let v1 = vertices[indices[first_index+1]].position.xyz;
    let v2 = vertices[indices[first_index+2]].position.xyz;

    let edge1 = v1 - v0;
    let edge2 = v2 - v0;
    let h = cross( (*ray).d, edge2 );
    let a = dot( edge1, h );
    if (a > -EPS && a < EPS) {
        return false; // ray parallel to triangle
    }
    let f = 1 / a;
    let s = (*ray).o - v0;
    let u = f * dot( s, h );
    if (u < 0 || u > 1) {
        return false;
    }
    let q = cross( s, edge1 );
    let v = f * dot( (*ray).d, q );
    if (v < 0 || u + v > 1) {
        return false;
    }
    let t = f * dot( edge2, q );
    if (t > EPS) {
        // update ray and SurfaceInteraction
        // TODO: This could be moved to somewhere nicer with less divergence
        if (t < (*ray).t) {
            let bary = vec3f(1.0 - u - v, u, v);
            let uv = getUV(first_index, bary);
            let material: OpenPBRMaterial = materials[material_id];
            var face_normal = normalize(cross(edge1, edge2));
            var vertex_normal = getNormal(first_index, bary);
            if (dot(face_normal, -(*ray).d) < 0.0) {
                vertex_normal = vertex_normal * -1.0;
            }
            if (dot(face_normal, -(*ray).d) < 0.0) {
                face_normal = face_normal * -1.0;
            }

            // if (mat.base_color_texid >= 0 && texture(textures[mat.base_color_texid], uv).a < 0.001f) return false;
            (*si).uv = uv;
            (*si).n = vertex_normal;
            (*si).material = material;
            (*ray).t = min( (*ray).t, t );


            (*si).valid = true;
            return true;
        }
    }
    return false;
}

fn intersectAABB(ray: ptr<function,Ray>, bmin: vec3f, bmax: vec3f) -> f32 {
    let tx1: f32 = (bmin.x - (*ray).o.x) * (*ray).rD.x; 
    let tx2: f32 = (bmax.x - (*ray).o.x) * (*ray).rD.x;
    var tmin: f32 = min( tx1, tx2 ); 
    var tmax: f32 = max( tx1, tx2 );
    let ty1: f32 = (bmin.y - (*ray).o.y) * (*ray).rD.y; 
    let ty2: f32 = (bmax.y - (*ray).o.y) * (*ray).rD.y;

    tmin = max( tmin, min( ty1, ty2 ) ); 
    tmax = min( tmax, max( ty1, ty2 ) );

    let tz1: f32 = (bmin.z - (*ray).o.z) * (*ray).rD.z;
    let tz2: f32 = (bmax.z - (*ray).o.z) * (*ray).rD.z;
    tmin = max( tmin, min( tz1, tz2 ) );
    tmax = min( tmax, max( tz1, tz2 ) );

    if (tmax >= tmin && tmin < (*ray).t && tmax > 0.0) { 
        return tmin;
    }

    return 1e30; 
}

fn intersectBLAS(ray: ptr<function,Ray>, si: ptr<function,SurfaceInteraction>, bvh_offset: u32) {
    /* TODO: Increasing this results in no image */
    var stack = array<u32, 32>();
    var current: i32 = 0;
    stack[current] = bvh_offset;

    loop {
        var node: BVHNode = bvh[stack[current]];
        current = current - 1;

        if (node.left_child <= 0) {
            // intersect triangles in the node
            for (var i: u32 = 0; i < node.tri_count; i = i+1) {
                intersectTriangle(ray, si, node.first_tri_index_id + (3*i));
            }
        } else {
            let left_dist: f32 = intersectAABB(ray, bvh[bvh_offset + node.left_child].aabb_min.xyz, bvh[bvh_offset + node.left_child].aabb_max.xyz);
            let right_dist: f32 = intersectAABB(ray, bvh[bvh_offset + node.left_child+1].aabb_min.xyz, bvh[bvh_offset + node.left_child+1].aabb_max.xyz);


            if (left_dist > right_dist) {
                if (left_dist < 1e30) { 
                    current += 1;
                    stack[current] = bvh_offset + node.left_child;
                }
                if (right_dist < 1e30) {
                    current += 1;
                    stack[current] = bvh_offset + node.left_child+1;
                }
            } else {
                if (right_dist < 1e30) {
                    current += 1;
                    stack[current] = bvh_offset + node.left_child+1;
                }
                if (left_dist < 1e30) {
                    current += 1;
                    stack[current] = bvh_offset + node.left_child;
                }
            }
        }

        if (current < 0 || current >= 31) {
            return;
        }
    }
}

fn intersect(ray: ptr<function,Ray>) -> SurfaceInteraction {
    var si: SurfaceInteraction;
    si.valid = false;

    intersectBLAS(ray, &si, 0u);

    si.p = (*ray).o + (*ray).d * (*ray).t;
    si.w_o = -(*ray).d;
    return si;
}
/* Intersect */

/* Material */ 
fn pdf_lambert(si: ptr<function,SurfaceInteraction>,
                  w_i: vec3f,
                  w_o: vec3f) -> f32
{
    let theta_i: f32 = dot((*si).n, w_i);
    if (theta_i < 0.f) {
        return 0.f;
    }
    return theta_i * ONE_OVER_PI;
}

fn sample_lambert(si: ptr<function,SurfaceInteraction>,
                  rng: ptr<function,RNG>) -> vec3f
{
    let w: vec3f = randomCosineHemispherePoint(next_random2f(rng), (*si).n);
    return w;
}

fn bsdf_pdf(si: ptr<function,SurfaceInteraction>,
            w_i: vec3f,
            w_o: vec3f) -> f32
{
    /* TODO: Implement glossy pdf */
    let diffuse: f32 = pdf_lambert(si, w_i, w_o);

    return diffuse;
}

fn bsdf_sample(si: ptr<function,SurfaceInteraction>,
               pdf: ptr<function,f32>,
               rng: ptr<function,RNG>) -> vec3f
{
    var w: vec3f;

    /* TODO: Implement other BRDF components */
    w = sample_lambert(si, rng);

    *pdf = bsdf_pdf(si, w, (*si).w_o);
    return w;
}

fn eval_diffuse(si: ptr<function,SurfaceInteraction>,
                w_i: vec3f,
                w_o: vec3f) -> vec3f
{
    var f: vec3f = (*si).material.base_color;
    /* TODO: sample texture if available */

    //f *= si.material.base_weight * dot(w_i, si.n) * ONE_OVER_PI;
    f *= dot(w_i, (*si).n) * ONE_OVER_PI;
    return f;
}

fn bsdf_eval(si: ptr<function,SurfaceInteraction>,
             w_i: vec3f,
             w_o: vec3f,
             rng: ptr<function,RNG>) -> vec3f
{
    let diffuse = eval_diffuse(si, w_i, w_o);

    return diffuse;
}

/* Material */

/* Pathtracer */
fn miss(ray: Ray) -> vec4f {
    let sky = vec4f(70./255., 169./255., 235./255., 1.0);
    let haze = vec4f(127./255., 108./255., 94./255., 1.0);
    let background = mix(haze, sky, (ray.d.y + 1.0) /2.0);
    return background;
}

fn closestHit(uniforms: Uniforms, hit: SurfaceInteraction, rng: ptr<function,RNG>) -> vec4f {
    var si = hit;
    var L = vec3f(0.f);
    var throughput = vec3f(1.f);

    var f: vec3f;
    var f_pdf: f32;
    /* TODO: Pass MAX_BOUNCES const */
    for (var i: u32 = 0; i < MAX_BOUNCES; i = i + 1) {
        si.w_i = bsdf_sample(&si, &f_pdf, rng);
        if (f_pdf <= 0.f) {
            break;
        }
        f = bsdf_eval(&si, si.w_i, si.w_o, rng);
        throughput = f * throughput / f_pdf;

        var ray: Ray;
        ray.o = si.p + 0.00001f * uniforms.scene_scale * si.n;
        ray.d = si.w_i;
        ray.rD = 1.f / si.w_i;
        ray.t = 1e30f;

        si = intersect(&ray);

        // Ray left the scene, apply miss shader
        if (!si.valid) {
            L = throughput * miss(ray).xyz;
            break;
        }

        // Russian roulette termination
        if (i > MIN_RR_DEPTH) {
            let q: f32 = max(throughput.x, max(throughput.y, throughput.z));
            if (next_randomf(rng) > q) {
                break;
            } else {
                throughput = throughput / (1 - q);
            }
        }
    }

    return vec4f(L, 1.f);
}

fn spawnRay(uniforms: Uniforms, d: vec2f) -> Ray {
    let right: vec3f = normalize(cross(uniforms.dir, uniforms.up));
    var ray: Ray;
    ray.o = uniforms.eye;
    ray.d = normalize(uniforms.dir +
                      uniforms.aspect_ratio * (d.x - 0.5) * right +
                      (d.y - 0.5) * uniforms.up);
    ray.rD = 1.0 / ray.d;
    ray.t = 1e30;
    return ray;
}

@compute @workgroup_size(16, 16)
fn pathtracer(@builtin(global_invocation_id) id: vec3<u32>) {
    // Compute parameters
    let pixel_id = u32(id.y * uniforms.viewport_size.x + id.x);
    var rng = make_random(pixel_id, uniforms.frame_number);

    var L = vec4f(0.0);
    let uv = vec2f(f32(id.x) / f32(uniforms.viewport_size.x),
                   1.0 - (f32(id.y) / f32(uniforms.viewport_size.y)));
    let d = uv + (next_random2f(&rng) / vec2f(uniforms.viewport_size.xy));

    // Spawn and trace camera ray
    var ray = spawnRay(uniforms, d);

    let si = intersect(&ray);
    if (si.valid) {
        L = closestHit(uniforms, si, &rng);
    } else {
        L = miss(ray);
    }

    // Accumulate
    L = clamp(L, vec4f(vec3f(0), 1), vec4f(vec3f(10), 1));
    L = (f32(uniforms.frame_number) * textureLoad(src_texture, id.xy, 0) + L) / (f32(uniforms.frame_number) + 1.f);
    textureStore(dst_texture, id.xy, L);
}
/* Pathtracer */
