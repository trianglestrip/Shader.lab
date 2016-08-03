
// author : https://www.shadertoy.com/view/ltfXDM

#define RAY_LENGTH_MAX 20.0
#define RAY_BOUNCE_MAX 10
#define RAY_STEP_MAX 40
#define COLOR vec3 (0.8, 0.8, 0.9)
#define ALPHA 0.9
#define REFRACT_INDEX vec3 (2.407, 2.426, 2.451)
#define LIGHT vec3 (1.0, 1.0, -1.0)
#define AMBIENT 0.2
#define SPECULAR_POWER 3.0
#define SPECULAR_INTENSITY 0.5
#define DELTA 0.001
#define PI 3.14159265359

uniform samplerCube envMap;
uniform vec3 resolution;
uniform vec4 mouse;
uniform float time;

varying vec2 vUv;
varying vec3 vEye;


mat3 mRotate(in vec3 angle) 
{
    float c = cos(angle.x);
    float s = sin(angle.x);
    mat3 rx = mat3(1.0, 0.0, 0.0, 0.0, c, s, 0.0, -s, c);
    c = cos(angle.y);
    s = sin(angle.y);
    mat3 ry = mat3(c, 0.0, -s, 0.0, 1.0, 0.0, s, 0.0, c);
    c = cos(angle.z);
    s = sin(angle.z);
    mat3 rz = mat3(c, s, 0.0, -s, c, 0.0, 0.0, 0.0, 1.0);
    return rz * ry * rx;
}
vec3 vRotateY(in vec3 p, in float angle) 
{
    float c = cos(angle);
    float s = sin(angle);
    return vec3(c * p.x - s * p.z, p.y, c * p.z + s * p.x);
}
vec3 normalTopA = normalize(vec3(0.0, 1.0, 1.4));
vec3 normalTopB = normalize(vec3(0.0, 1.0, 1.0));
vec3 normalTopC = normalize(vec3(0.0, 1.0, 0.5));
vec3 normalBottomA = normalize(vec3(0.0, -1.0, 1.0));
vec3 normalBottomB = normalize(vec3(0.0, -1.0, 1.6));
float getDistance(in vec3 p) 
{
    //p = p;// mRotate(vec3(time)) * p;
    float topCut = p.y - 1.0;
    float angleStep = PI / (mouse.y < 0.5 ? 8.0 : 2.0 + floor(18.0 * mouse.x / resolution.x));
    float angle = angleStep * (0.5 + floor(atan(p.x, p.z) / angleStep));
    vec3 q = vRotateY(p, angle);
    float topA = dot(q, normalTopA) - 2.0;
    float topC = dot(q, normalTopC) - 1.5;
    float bottomA = dot(q, normalBottomA) - 1.7;
    q = vRotateY(p, -angleStep * 0.5);
    angle = angleStep * floor(atan(q.x, q.z) / angleStep);
    q = vRotateY(p, angle);
    float topB = dot(q, normalTopB) - 1.85;
    float bottomB = dot(q, normalBottomB) - 1.9;
    return max(topCut, max(topA, max(topB, max(topC, max(bottomA, bottomB)))));
}

vec3 getNormal(in vec3 p) 
{
    const vec2 h = vec2(DELTA, -DELTA);
    return normalize(h.xxx * getDistance(p + h.xxx) + h.xyy * getDistance(p + h.xyy) + h.yxy * getDistance(p + h.yxy) + h.yyx * getDistance(p + h.yyx));
}

vec3 lightDirection = normalize(LIGHT);

float raycast(in vec3 origin, in vec3 direction, in vec4 normal, in float color, in vec3 channel) 
{
    color *= 1.0 - ALPHA;
    float intensity = ALPHA;
    float distanceFactor = 1.0;
    float refractIndex = dot(REFRACT_INDEX, channel);
    for (int rayBounce = 1; rayBounce < RAY_BOUNCE_MAX; ++rayBounce) 
    {
        vec3 refraction = refract(direction, normal.xyz, distanceFactor > 0.0 ? 1.0 / refractIndex : refractIndex);
        if (dot(refraction, refraction) < DELTA) 
        {
            direction = reflect(direction, normal.xyz);
            origin += direction * DELTA * 2.0;
        }
 else 
        {
            direction = refraction;
            distanceFactor = -distanceFactor;
        }
        float dist = RAY_LENGTH_MAX;
        for (int rayStep = 0; rayStep < RAY_STEP_MAX; ++rayStep) 
        {
            dist = distanceFactor * getDistance(origin);
            float distMin = max(dist, DELTA);
            normal.w += distMin;
            if (dist < 0.0 || normal.w > RAY_LENGTH_MAX) 
            {
                break;
            }
             origin += direction * distMin;
        }
        if (dist >= 0.0) 
        {
            break;
        }
         normal.xyz = distanceFactor * getNormal(origin);
        if (distanceFactor > 0.0) 
        {
            float relfectionDiffuse = max(0.0, dot(normal.xyz, lightDirection));
            float relfectionSpecular = pow(max(0.0, dot(reflect(direction, normal.xyz), lightDirection)), SPECULAR_POWER) * SPECULAR_INTENSITY;
            float localColor = (AMBIENT + relfectionDiffuse) * dot(COLOR, channel) + relfectionSpecular;
            color += localColor * (1.0 - ALPHA) * intensity;
            intensity *= ALPHA;
        }
     }
    float backColor = dot(textureCube(envMap, direction).rgb, channel);
    return color + backColor * intensity;
}

void main() {

    vec2 uv = ((vUv - 0.5) * 2.0) * vec2(resolution.z, 1.0);

    vec2 frag = uv;
    vec3 direction = normalize(vec3(frag, 2.0));
    vec3 origin = vEye; //7.0 * vec3(cos(time * 0.1), sin(time * 0.2), sin(time * 0.1));
    vec3 forward = -origin;
    vec3 up = vec3(0.0, 1.0, 0.0);//vec3(sin(time * 0.3), 2.0, 0.0);
    
    mat3 rotation;
    rotation[2] = normalize(forward);
    rotation[0] = normalize(cross(up, forward));
    rotation[1] = cross(rotation[2], rotation[0]);
    direction = rotation * direction;

    vec4 normal = vec4(0.0);
    float dist = RAY_LENGTH_MAX;
    for (int rayStep = 0; rayStep < RAY_STEP_MAX; ++rayStep) 
    {
        dist = getDistance(origin);
        float distMin = max(dist, DELTA);
        normal.w += distMin;
        if (dist < 0.0 || normal.w > RAY_LENGTH_MAX) 
        {
            break;
        }
         origin += direction * distMin;
    }
    if (dist >= 0.0) 
    {
        gl_FragColor.rgb = textureCube(envMap, direction).rgb;
    }
 else 
    {
        normal.xyz = getNormal(origin);
        float relfectionDiffuse = max(0.0, dot(normal.xyz, lightDirection));
        float relfectionSpecular = pow(max(0.0, dot(reflect(direction, normal.xyz), lightDirection)), SPECULAR_POWER) * SPECULAR_INTENSITY;
        gl_FragColor.rgb = (AMBIENT + relfectionDiffuse) * COLOR + relfectionSpecular;
        gl_FragColor.r = raycast(origin, direction, normal, gl_FragColor.r, vec3(1.0, 0.0, 0.0));
        gl_FragColor.g = raycast(origin, direction, normal, gl_FragColor.g, vec3(0.0, 1.0, 0.0));
        gl_FragColor.b = raycast(origin, direction, normal, gl_FragColor.b, vec3(0.0, 0.0, 1.0));
    }
    gl_FragColor.a = 1.0;
}