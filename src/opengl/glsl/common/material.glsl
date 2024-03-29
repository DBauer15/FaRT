/*
 * Implementation of the OpenPBR material model
 * References:
 * https://academysoftwarefoundation.github.io/OpenPBR/#model/
 * https://cwyman.org/code/dxrTutors/tutors/Tutor14/tutorial14.md.html
 *
 */

/* 
 * General Functions
 *
 */
vec3 fresnelSchlick(vec3 f0, float cos_theta) {
    return f0 + (vec3(1.f) - f0) * pow(1.f - cos_theta, 5.f);
}

float ggxGeomtric(float roughness, float cos_theta_i, float cos_theta_o) {
    float k = roughness * roughness / 2.f;
    float g_i = cos_theta_i / max(FLT_MIN, (cos_theta_i*(1.f-k) + k));
    float g_o = cos_theta_o / max(FLT_MIN, (cos_theta_o*(1.f-k) + k));
    return g_o * g_i;
}

float ggxShadowing(float roughness, float cos_theta_h) {
    float cos_theta_h2 = cos_theta_h * cos_theta_h;
    float a2 = roughness * roughness;
    float d = (cos_theta_h2 * (a2 - 1.f)) + 1.f;
    return a2 / max(FLT_MIN, d * d) * ONE_OVER_PI;
}

float pdf_ggx(const SurfaceInteraction    si, 
              vec3                        w_i, 
              vec3                        w_o) 
{
    float theta_i = dot(si.n, w_i);
    if (theta_i < 0.f) return 0.f;

    vec3 h = normalize(w_i + w_o);
    float ndoth = dot(si.n, h);
    float D = ggxShadowing(si.mat.specular_roughness, ndoth);

    return D * ndoth / max(FLT_MIN, 4 * dot(w_o, h));
}

vec3 sample_ggx(const SurfaceInteraction    si, 
                inout RNG                   rng) {
    vec3 h = randomGGXMicrofacet(next_random2f(rng), si.n, si.mat.specular_roughness);
    vec3 w = reflect(-si.w_o, h);

    return w;
}

vec3 eval_ggx(const SurfaceInteraction   si,
              vec3                       w_i,
              vec3                       w_o,
              vec3                       f0)
{
    vec3 h = normalize(w_i + w_o);
    float hdotl = max(0.f, dot(w_i, h));
    float ndotv = max(FLT_MIN, dot(si.n, w_o));
    float ndotl = max(FLT_MIN, dot(si.n, w_i));
    float ndoth = max(0.f, dot(si.n, h));

    // fresnel
    vec3 F = si.mat.specular_weight * si.mat.specular_color * fresnelSchlick(f0, hdotl);
    
    // geometric
    float G = ggxGeomtric(si.mat.specular_roughness, ndotl, ndotv);

    // shadowing
    float D = ggxShadowing(si.mat.specular_roughness, ndoth);

    return (F * G * D) / (4.f * ndotv /* * ndotl */) /* * ndotl */; // ndotl (theta_i) left out for numerical robustness
}


float pdf_lambert(const SurfaceInteraction  si, 
                  vec3                      w_i, 
                  vec3                      w_o) 
{
    float theta_i = dot(si.n, w_i);
    if (theta_i < 0.f) return 0.f;
    return theta_i * ONE_OVER_PI;
}

vec3 sample_lambert(const SurfaceInteraction    si, 
                    inout RNG                   rng) 
{
    vec3 w = randomCosineHemispherePoint(next_random2f(rng), si.n);
    return w;
}

/* 
 * PBR Components
 *
 */
vec3 eval_metal(const SurfaceInteraction    si,
                vec3                        w_i,
                vec3                        w_o)
{

    // base reflectance
    vec3 f0 = si.mat.base_color;
    if (si.mat.base_color_texid >= 0)
        f0 = texture(textures[si.mat.base_color_texid], si.uv).rgb;
    f0 = f0 * si.mat.base_weight;
    return eval_ggx(si, w_i, w_o, f0);
}

vec3 eval_glossy(const SurfaceInteraction   si, 
                 vec3                       w_i, 
                 vec3                       w_o) 
{
    // base reflectance
    vec3 f0 = vec3(1.f) * pow((1.f - si.mat.specular_ior) / (1.f + si.mat.specular_ior), 2.f);
    return eval_ggx(si, w_i, w_o, f0);
}

vec3 eval_diffuse(const SurfaceInteraction  si, 
                  vec3                      w_i, 
                  vec3                      w_o) 
{

    vec3 f = si.mat.base_color;
    if (si.mat.base_color_texid >= 0)
        f = texture(textures[si.mat.base_color_texid], si.uv).rgb;
    f *= si.mat.base_weight * dot(w_i, si.n) * ONE_OVER_PI;
    return f;
}

/* Estimator for GGX Microfacet reflectanace */
vec3 ggx_reflectance(const SurfaceInteraction   si, 
                     vec3                       w_o, 
                     inout RNG                  rng) {
    vec3 reflectance = vec3(0.f);
    vec3 w_i;
    const uint samples = 8;
    for (uint i = 0; i < samples; i++) {
        w_i = randomHemispherePoint(next_random2f(rng), si.n);
        reflectance += eval_glossy(si, w_i, w_o);
    }
    return reflectance / samples;
}

/*
 * Top-Level BxDF functions called by the renderer
 *
 */
float bsdf_pdf(const  SurfaceInteraction    si, 
               vec3                         w_i, 
               vec3                         w_o) 
{
    float diffuse = pdf_lambert(si, w_i, w_o);
    float glossy = pdf_ggx(si, w_i, w_o);

    return (diffuse + glossy) / 2.f;
}

vec3 bsdf_sample(const SurfaceInteraction   si, 
                 inout float                pdf, 
                 inout RNG                  rng)
{
    vec3 w;

    // TODO: Find better heuristic to choose the sampler
    int bsdf_component = int(next_randomf(rng) * 2.f);
    if (bsdf_component == 0) {
        w = sample_lambert(si, rng);
    } else {
        w = sample_ggx(si, rng);
    } 

    pdf = bsdf_pdf(si, w, si.w_o);
    return w;
}

vec3 bsdf_eval(const SurfaceInteraction     si, 
               vec3                         w_i, 
               vec3                         w_o, 
               inout RNG                    rng)
{
    vec3 E_specular = ggx_reflectance(si, w_o, rng);
    vec3 diffuse = eval_diffuse(si, w_i, w_o);
    vec3 glossy = eval_glossy(si, w_i, w_o);
    vec3 metal = eval_metal(si, w_i, w_o);

    vec3 dielectric = glossy + (vec3(1.f) - E_specular) * diffuse;

    return mix(dielectric, metal, si.mat.base_metalness);
}
