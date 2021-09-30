#version 300 es

precision highp float;

uniform mat4 u_Model;
uniform vec4 u_Color; // The color with which to render this instance of geometry.
uniform float u_Hot;
uniform float u_Dry;
uniform float u_Octavity;
uniform vec3 u_Camera;
// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Pos;
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;

out vec4 out_Col; // This is the final output color that you will see on your
                                    // screen for the pixel that is currently being processed.

vec3 rgb(float r, float g, float b) {
    return vec3(r / 255.0, g / 255.0, b / 255.0);
}

float random(vec3 st) {
        float p1 = fract(sin(dot(st.xy,
                                                vec2(12.9898,78.233)))
                                 * 43758.5453123);
        float p2 = fract(sin(dot(st.yz,
                                                vec2(12.9898,78.233)))
                                 * 43758.5453123);;
        return fract(sin(dot(vec2(p1, p2),
                                                vec2(12.9898,78.233)))
                                 * 43758.5453123);
}
vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}

float snoise(vec3 v){ 
    const vec2  C = vec2(1.0/6.0, 1.0/3.0) ;
    const vec4  D = vec4(0.0, 0.5, 1.0, 2.0);

// First corner
    vec3 i  = floor(v + dot(v, C.yyy) );
    vec3 x0 =   v - i + dot(i, C.xxx) ;

// Other corners
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min( g.xyz, l.zxy );
    vec3 i2 = max( g.xyz, l.zxy );

    //  x0 = x0 - 0. + 0.0 * C 
    vec3 x1 = x0 - i1 + 1.0 * C.xxx;
    vec3 x2 = x0 - i2 + 2.0 * C.xxx;
    vec3 x3 = x0 - 1. + 3.0 * C.xxx;

// Permutations
    i = mod(i, 289.0 ); 
    vec4 p = permute( permute( permute( 
                        i.z + vec4(0.0, i1.z, i2.z, 1.0 ))
                        + i.y + vec4(0.0, i1.y, i2.y, 1.0 )) 
                        + i.x + vec4(0.0, i1.x, i2.x, 1.0 ));

// Gradients
// ( N*N points uniformly over a square, mapped onto an octahedron.)
    float n_ = 1.0/7.0; // N=7
    vec3  ns = n_ * D.wyz - D.xzx;

    vec4 j = p - 49.0 * floor(p * ns.z *ns.z);  //  mod(p,N*N)

    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_ );    // mod(j,N)

    vec4 x = x_ *ns.x + ns.yyyy;
    vec4 y = y_ *ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);

    vec4 b0 = vec4( x.xy, y.xy );
    vec4 b1 = vec4( x.zw, y.zw );

    vec4 s0 = floor(b0)*2.0 + 1.0;
    vec4 s1 = floor(b1)*2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));

    vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
    vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;

    vec3 p0 = vec3(a0.xy,h.x);
    vec3 p1 = vec3(a0.zw,h.y);
    vec3 p2 = vec3(a1.xy,h.z);
    vec3 p3 = vec3(a1.zw,h.w);

//Normalise gradients
    vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

// Mix final noise value
    vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
    m = m * m;
    return 42.0 * dot( m*m, vec4( dot(p0,x0), dot(p1,x1), 
                                                                dot(p2,x2), dot(p3,x3) ) );
    // return vec3(m.xyz);
}

//	Classic Perlin 3D Noise 
//	by Stefan Gustavson
//
vec3 fade(vec3 t) {return t*t*t*(t*(t*6.0-15.0)+10.0);}

float cnoise(vec3 P){
    vec3 Pi0 = floor(P); // Integer part for indexing
    vec3 Pi1 = Pi0 + vec3(1.0); // Integer part + 1
    Pi0 = mod(Pi0, 289.0);
    Pi1 = mod(Pi1, 289.0);
    vec3 Pf0 = fract(P); // Fractional part for interpolation
    vec3 Pf1 = Pf0 - vec3(1.0); // Fractional part - 1.0
    vec4 ix = vec4(Pi0.x, Pi1.x, Pi0.x, Pi1.x);
    vec4 iy = vec4(Pi0.yy, Pi1.yy);
    vec4 iz0 = Pi0.zzzz;
    vec4 iz1 = Pi1.zzzz;

    vec4 ixy = permute(permute(ix) + iy);
    vec4 ixy0 = permute(ixy + iz0);
    vec4 ixy1 = permute(ixy + iz1);

    vec4 gx0 = ixy0 / 7.0;
    vec4 gy0 = fract(floor(gx0) / 7.0) - 0.5;
    gx0 = fract(gx0);
    vec4 gz0 = vec4(0.5) - abs(gx0) - abs(gy0);
    vec4 sz0 = step(gz0, vec4(0.0));
    gx0 -= sz0 * (step(0.0, gx0) - 0.5);
    gy0 -= sz0 * (step(0.0, gy0) - 0.5);

    vec4 gx1 = ixy1 / 7.0;
    vec4 gy1 = fract(floor(gx1) / 7.0) - 0.5;
    gx1 = fract(gx1);
    vec4 gz1 = vec4(0.5) - abs(gx1) - abs(gy1);
    vec4 sz1 = step(gz1, vec4(0.0));
    gx1 -= sz1 * (step(0.0, gx1) - 0.5);
    gy1 -= sz1 * (step(0.0, gy1) - 0.5);

    vec3 g000 = vec3(gx0.x,gy0.x,gz0.x);
    vec3 g100 = vec3(gx0.y,gy0.y,gz0.y);
    vec3 g010 = vec3(gx0.z,gy0.z,gz0.z);
    vec3 g110 = vec3(gx0.w,gy0.w,gz0.w);
    vec3 g001 = vec3(gx1.x,gy1.x,gz1.x);
    vec3 g101 = vec3(gx1.y,gy1.y,gz1.y);
    vec3 g011 = vec3(gx1.z,gy1.z,gz1.z);
    vec3 g111 = vec3(gx1.w,gy1.w,gz1.w);

    vec4 norm0 = taylorInvSqrt(vec4(dot(g000, g000), dot(g010, g010), dot(g100, g100), dot(g110, g110)));
    g000 *= norm0.x;
    g010 *= norm0.y;
    g100 *= norm0.z;
    g110 *= norm0.w;
    vec4 norm1 = taylorInvSqrt(vec4(dot(g001, g001), dot(g011, g011), dot(g101, g101), dot(g111, g111)));
    g001 *= norm1.x;
    g011 *= norm1.y;
    g101 *= norm1.z;
    g111 *= norm1.w;

    float n000 = dot(g000, Pf0);
    float n100 = dot(g100, vec3(Pf1.x, Pf0.yz));
    float n010 = dot(g010, vec3(Pf0.x, Pf1.y, Pf0.z));
    float n110 = dot(g110, vec3(Pf1.xy, Pf0.z));
    float n001 = dot(g001, vec3(Pf0.xy, Pf1.z));
    float n101 = dot(g101, vec3(Pf1.x, Pf0.y, Pf1.z));
    float n011 = dot(g011, vec3(Pf0.x, Pf1.yz));
    float n111 = dot(g111, Pf1);

    vec3 fade_xyz = fade(Pf0);
    vec4 n_z = mix(vec4(n000, n100, n010, n110), vec4(n001, n101, n011, n111), fade_xyz.z);
    vec2 n_yz = mix(n_z.xy, n_z.zw, fade_xyz.y);
    float n_xyz = mix(n_yz.x, n_yz.y, fade_xyz.x); 
    return 2.2 * n_xyz;
}

float getBias(float time, float bias)
{
  return (time / ((((1.0 / bias) - 2.0) * (1.0 - time)) + 1.0));
}

float getGain(float time, float gain)
{
    if (time < 0.5)
        return getBias(time * 2.0, gain) / 2.0;
    else
        return getBias(time * 2.0 - 1.0,1.0 - gain) / 2.0 + 0.5;
}

float hash(float p) { p = fract(p * 0.011); p *= p + 7.5; p *= p + p; return fract(p); }
float hash(vec2 p) {vec3 p3 = fract(vec3(p.xyx) * 0.13); p3 += dot(p3, p3.yzx + 3.333); return fract((p3.x + p3.y) * p3.z); }

float noise1d(float x) {
    float i = floor(x);
    float f = fract(x);
    float u = f * f * (3.0 - 2.0 * f);
    return mix(hash(i), hash(i + 1.0), u);
}

float mod289(float x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
vec4 mod289(vec4 x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
vec4 perm(vec4 x){return mod289(((x * 34.0) + 1.0) * x);}

float noise3d(vec3 p){
    vec3 a = floor(p);
    vec3 d = p - a;
    d = d * d * (3.0 - 2.0 * d);

    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy);
    vec4 k2 = perm(k1.xyxy + b.zzww);

    vec4 c = k2 + a.zzzz;
    vec4 k3 = perm(c);
    vec4 k4 = perm(c + 1.0);

    vec4 o1 = fract(k3 * (1.0 / 41.0));
    vec4 o2 = fract(k4 * (1.0 / 41.0));

    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);

    return o4.y * d.y + o4.x * (1.0 - d.y);
}

const int NUM_NOISE_OCTAVES_S_BASE  = 0;
const int NUM_NOISE_OCTAVES_C_BASE  = 0;
const int NUM_NOISE_OCTAVES_N_BASE  = 0;
const int NUM_NOISE_OCTAVES_1D_BASE  = 0;

float sfbm(vec3 x) {
    int NUM_NOISE_OCTAVES_S = NUM_NOISE_OCTAVES_S_BASE + int(u_Octavity);
	float v = 0.0;
	float a = 0.5;
	vec3 shift = vec3(100);
	for (int i = 0; i < NUM_NOISE_OCTAVES_S; ++i) {
		v += a * snoise(x);
		x = x * 2.0 + shift;
		a *= 0.5;
	}
	return v;
}
// perlin fbm
float cfbm(vec3 x) {
    int NUM_NOISE_OCTAVES_C = NUM_NOISE_OCTAVES_C_BASE + int(u_Octavity);
	float v = 0.0;
	float a = 0.5;
	vec3 shift = vec3(100);
	for (int i = 0; i < NUM_NOISE_OCTAVES_C; ++i) {
		v += a * cnoise(x);
		x = x * 2.0 + shift;
		a *= 0.5;
	}
	return v;
}

float nfbm(vec3 x) {
    int NUM_NOISE_OCTAVES_N = NUM_NOISE_OCTAVES_N_BASE + int(u_Octavity);
	float v = 0.0;
	float a = 0.5;
	vec3 shift = vec3(100);
	for (int i = 0; i < NUM_NOISE_OCTAVES_N; ++i) {
		v += a * noise3d(x);
		x = x * 2.0 + shift;
		a *= 0.5;
	}
	return v;
}

float fbm1d(float x) {
    int NUM_NOISE_OCTAVES_1D = NUM_NOISE_OCTAVES_1D_BASE + int(u_Octavity);
	float v = 0.0;
	float a = 0.5;
	float shift = float(100);
	for (int i = 0; i < NUM_NOISE_OCTAVES_1D; ++i) {
		v += a * noise1d(x);
		x = x * 2.0 + shift;
		a *= 0.5;
	}
	return v;
}

vec3 palette( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d )
{
    return a + b*cos( 6.28318*(c*t+d) );
}

// bool inOcean(float height) {
//     return height < u_Ocean;
// }

void main()
{
    vec4 H = vec4(u_Camera.x, u_Camera.y, u_Camera.z, 1.0f) + fs_LightVec;
    H /= 2.f;

    float specInt = max(pow(dot(normalize(H), normalize(fs_Nor)), 100.f), 0.f);
    // float specInt = 0.f;
    // Material base color (before shading)
    vec4 diffuseColor = u_Color;
    
    // Calculate the diffuse term for Lambert shading
    float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
    // Avoid negative lighting values
    diffuseTerm = clamp(diffuseTerm, 0.0, 1.0);

    float ambientTerm = 0.1;

    float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                        //to simulate ambient lighting. This ensures that faces that are not
                                                        //lit by our point light are not completely black.

    // Compute final shaded color
    // out_Col = vec4(diffuseColor.rgb * lightIntensity, diffuseColor.a);

    vec3 bioNois1Input = fs_Pos.xyz * 0.5f;
    vec3 bioNois2Input = fs_Pos.xyz * 0.5f;

    // figure out biomes by thresholds
    float bioNois1 = snoise(bioNois1Input);
    float bioNois2 = cnoise(bioNois2Input);
    float bioNois1Thresh = u_Hot;
    float bioNois2Thresh = u_Dry;
    vec3 surfaceColor;
    if (bioNois1 > bioNois1Thresh) {
        if (bioNois2 > bioNois2Thresh) {
            float t = getGain(bioNois1, 0.6);
            vec3 a = vec3(0.500, 0.500, 0.000);
            vec3 b = vec3(0.500, 0.500, 0.000);
            vec3 c = vec3(0.500, 0.500, 0.000);
            vec3 d = vec3(0.500, 0.000, 0.000);
            
            surfaceColor = palette(t, a, b, c, d);
        } else {
            float t = getGain(bioNois2, 0.75);
            vec3 a = vec3(3.138, 0.500, 0.500);
            vec3 b = vec3(0.500, 0.500, 0.500);
            vec3 c = vec3(3.138, 0.448, 0.667);
            vec3 d = vec3(0.800, 1.000, 0.333);
            surfaceColor = palette(t, a, b, c, d);
        }
    } else {
        if (bioNois2 > bioNois2Thresh) {
            float t = getGain(bioNois1, 0.75);
            vec3 a = vec3(0.938, 0.328, 0.718);
            vec3 b = vec3(0.659, 0.438, 0.328);
            vec3 c = vec3(0.388, 0.388, 0.296);
            vec3 d = vec3(2.538, 2.478, 0.168);
            surfaceColor = palette(t, a, b, c, d);
        } else {
            float t = getGain(bioNois2, 0.25);
            vec3 a = vec3(0.660, 0.560, 0.680);
            vec3 b = vec3(0.718, 0.438, 0.720);
            vec3 c = vec3(0.520, 0.448, 0.520);
            vec3 d = vec3(-0.430, -0.397, -0.083);
            surfaceColor = palette(t, a, b, c, d);
        }
    }

    // vec4 modelposition = u_Model * fs_Pos;
    // if (inOcean(length(modelposition.xyz))) {
    //     modelposition = u_Model * fs_Pos;
    // }
    // diffuseColor = surfaceColor;
    out_Col = vec4(surfaceColor.rgb * surfaceColor.rgb * (lightIntensity + specInt), diffuseColor.a);

}
