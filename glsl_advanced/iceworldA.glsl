
// ------------------ channel define
// 0_# buffer64_iceworldB #_0
// 2_# noise #_2
// ------------------

// created by florian berger (flockaroo) - 2016
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// very much inspired by iq's "Volcanic", WAHa_06x36's "Truchet Tentacles" and Shanes "Entangled Vines"

#define readSampler iChannel0
#define randSampler iChannel2
#define time iDate.w

//----- common ------

#define MaxParticleNum 1
#define InRes iChannelResolution[0].xy

struct Particle {
    vec4 pos;
    vec4 vel;
    vec4 angVel;
    vec4 quat;
};

float hash(float seed)
{
    return fract(sin(seed)*158.5453 );
}

vec4 getRand4(float seed)
{
    return vec4(hash(seed),hash(seed+123.21),hash(seed+234.32),hash(seed+453.54));
}

bool isPixel(int x, int y, vec2 fragCoord) { return (int(fragCoord.x)==x && int(fragCoord.y)==y); }
vec4 getPixel(int x, int y, sampler2D s) { vec2 res=InRes; return texture2D(s,(vec2(x,y)+vec2(0.5))/res); }
vec4 getPixel(int x, int y) { return getPixel(x,y,readSampler); }

#define PixPerParticle 5
#define ParticlesPerLine 16
int XC(int idx) { return int(mod(float(idx),float(ParticlesPerLine)))*PixPerParticle; }
int YC(int idx) { return (idx/16)+50; } // first line (y=0) reserved for other than particle-data
int PIdx(int xc, int yc) {
    if(xc/PixPerParticle>=ParticlesPerLine) return -1;
    int pidx = (yc-50)*16 + xc/PixPerParticle;
    if(pidx>=MaxParticleNum) return -1;
    return pidx;
}

void writeParticle( int idx, Particle p, inout vec4 fragColor, vec2 fragCoord)
{
    int xc = XC(idx);
    int yc = YC(idx);
    if (isPixel(xc+0,yc,fragCoord)) fragColor.xyzw=p.pos;
    if (isPixel(xc+1,yc,fragCoord)) fragColor.xyzw=p.vel;
    if (isPixel(xc+2,yc,fragCoord)) fragColor.xyzw=p.angVel;
    if (isPixel(xc+3,yc,fragCoord)) fragColor.xyzw=p.quat;
    // not sure if framebuffer has .w, so store quat.w also in next pixel
    if (isPixel(xc+4,yc,fragCoord)) fragColor.xyzw=vec4(p.quat.w,0,0,1);
}

Particle readParticle( int idx )
{
    Particle p;
    int xc = XC(idx);
    int yc = YC(idx);
    // first line (y=0) reserved (e.g. for growNum, growIdx)
    p.pos    = getPixel(xc+0,yc);
    p.vel    = getPixel(xc+1,yc);
    p.angVel = getPixel(xc+2,yc);
    p.quat   = getPixel(xc+3,yc);
    // not sure if framebuffer has .w, so store quat.w also in next pixel
    vec4 p2  = getPixel(xc+4,yc);
    p.quat.w = p2.x;
    return p;
}

vec3 readParticlePos( int idx )
{
    return getPixel(XC(idx),YC(idx)).xyz;
}

vec3 readCamPos()
{
    return getPixel(0,0).xyz;
}

vec4 readCamQuat()
{
    vec4 q;
    q   = getPixel(1,0);
    q.w = getPixel(2,0).x;
    return q;
}

vec3 readCamNav()
{
    return getPixel(3,0).xyz;
}

void writeCamPos(vec3 pos, inout vec4 fragColor, vec2 fragCoord)
{
    if (isPixel(0,0,fragCoord)) fragColor.xyz=pos;
}

void writeCamQuat(vec4 quat, inout vec4 fragColor, vec2 fragCoord)
{
    if (isPixel(1,0,fragCoord)) fragColor.xyzw=quat;
    if (isPixel(2,0,fragCoord)) fragColor.x=quat.w;
}

void writeCamNav(vec3 nav, inout vec4 fragColor, vec2 fragCoord)
{
    if (isPixel(3,0,fragCoord)) fragColor.xyz=nav;
}

float readSteeringAngle()
{
    return getPixel(4,0).x;
}

void writeSteeringAngle(float st, inout vec4 fragColor, vec2 fragCoord)
{
    if (isPixel(4,0,fragCoord)) fragColor.x=st;
}

float readGas()
{
    return getPixel(4,0).y;
}

void writeGas(float gas, inout vec4 fragColor, vec2 fragCoord)
{
    if (isPixel(4,0,fragCoord)) fragColor.y=gas;
}

vec4 inverseQuat(vec4 q)
{
    //return vec4(-q.xyz,q.w)/length(q);
    // if already normalized this is enough
    return vec4(-q.xyz,q.w);
}

vec4 multQuat(vec4 a, vec4 b)
{
    return vec4(cross(a.xyz,b.xyz) + a.xyz*b.w + b.xyz*a.w, a.w*b.w - dot(a.xyz,b.xyz));
}

vec4 rotateQuatbyAngle(vec4 quat, vec3 angle)
{
    float angleScalar=length(angle);
    if (angleScalar<0.00001) return quat;
    return multQuat(quat,vec4(angle*(sin(angleScalar*0.5)/angleScalar),cos(angleScalar*0.5)));
}

vec3 transformVecByQuat( vec3 v, vec4 q )
{
    return v + 2.0 * cross( q.xyz, cross( q.xyz, v ) + q.w*v );
}

vec4 transformVecByQuat( vec4 v, vec4 q )
{
    return vec4( transformVecByQuat( v.xyz, q ), v.w );
}

void getEyeCoords(out vec3 right, out vec3 fwd, out vec3 up, out vec3 eye, out vec3 dir, float aspect, vec2 spos)
{
    float speed=0.0;
    float elev = float(iMouse.y/iResolution.y)*0.5*1.0+0.7*sin(time*0.3*speed);
    float azim = float(iMouse.x/iResolution.x)*0.5*1.0+0.5*time*speed;
    right = vec3(sin(azim),cos(azim),0);
    fwd   = vec3(vec2(-1,1)*right.yx*cos(elev),sin(elev));
    up    = cross(right,fwd);
    eye = -(60.0+4.0*sin(1.0*time*speed)+4.0*sin(0.65264*time*speed))*fwd+vec3(0,0,10);
    eye = readCamPos();
    vec4 cq = readCamQuat();
    right = transformVecByQuat(vec3(1,0,0),cq);
    up    = transformVecByQuat(vec3(0,0,1),cq);
    fwd   = transformVecByQuat(vec3(0,1,0),cq);
    dir = normalize(spos.x*right+spos.y*aspect*up+1.5*fwd);
}

vec2 calcScreenPos(vec3 eye, vec3 right, vec3 fwd, vec3 up, vec3 pos, float aspect)
{
    return vec2(dot(pos-eye,right)/dot(pos-eye,fwd)*1.5,dot(pos-eye,up)/dot(pos-eye,fwd)*1.5/aspect);
}

// some distance primitives - from iq's site (http://iquilezles.org/www/articles/smin/smin.htm)
float maxcomp(in vec3 p ) { return max(p.x,max(p.y,p.z));}

float getDistanceBoxS(vec3 rpos, vec3 size)
{
    vec3 di = abs(rpos) - size;
    return min( maxcomp(di), length(max(di,0.0)) );
}

float getDistanceBoxRounded( vec3 p, vec3 b, float r )
{
  return length(max(abs(p)-b,0.0))-r;
}

float getDistanceTorusS(vec3 rpos,float r1,float r2)
{
    vec3 ptor = normalize(vec3(rpos.xy,0))*r1;
    return length(rpos-ptor)-r2;
}

#define torusWorldRadius1 90.0
#define torusWorldRadius2 30.0



// ---- truchet cell funcs -----
// derived from WAHa_06x36 - shadertoy (https://www.shadertoy.com/view/ldfGWn)

float truchetRand(vec3 r) { return fract(sin(dot(r.xy,vec2(1.38984*sin(r.z),1.13233*cos(r.z))))*653758.5453); }

float truchetArc(vec3 pos, float radius)
{
    pos=fract(pos);
    float r=length(pos.xy);
    return length(vec2(r-0.5,pos.z-0.5))-radius;
}

float truchetCell(vec3 pos, float r)
{
    return min(min(
        truchetArc(pos.xyz               ,r),
        truchetArc(pos.zxy*vec3( 1,-1, 1),r)),
        truchetArc(pos.yzx*vec3(-1,-1, 1),r));
}

float sphere(vec3 pos, float r) { return length(pos)-r; }

float truchetCell2(vec3 pos, float r)
{
    return min(min(
        min(sphere(fract(pos)-vec3(0,0.5,0.5),r),sphere(fract(pos)-vec3(0.5,0,0.5),r)),
        truchetArc(pos.zxy*vec3( 1,-1, 1),r)),
        truchetArc(pos.yzx*vec3(-1,-1, 1),r));
}

float truchetCell3(vec3 pos, float r)
{
    return min(min(
        truchetArc(pos.xyz    ,r),
        truchetArc(pos.xyz*vec3(-1,-1,1) ,r)),
        length(fract(pos.xy)-vec2(0.5))-r
              );
}

// i tried to put all if's from WAHa_06x36's version into
// one modulo operation, and left away the swizzling.
// i think all roatational/mirrored cases are covered this way.
// yet im not completely sure...
float truchetDist(vec3 pos, float r)
{
    vec3 cellpos=fract(pos);
    vec3 gridpos=floor(pos);
    float rnd=truchetRand(gridpos);
    vec3 fact=floor(mod(rnd*vec3(2.0,4.0,8.0),vec3(2.0)))*2.0-vec3(1.0);
    return truchetCell(cellpos*fact,r);
}

float truchetDist2(vec3 pos, float r)
{
    vec3 cellpos=fract(pos);
    vec3 gridpos=floor(pos);
    float rnd=truchetRand(gridpos);
    float rnd2=truchetRand(gridpos+vec3(3.2,4.432,6.32))*3.0;
    float rnd3=truchetRand(gridpos-vec3(3.2,4.432,6.32))*3.0;
    vec3 fact=floor(mod(rnd*vec3(2.0,4.0,8.0),vec3(2.0)))*2.0-vec3(1.0);
    if     (rnd3>2.0) cellpos = cellpos.yzx;
    else if(rnd3>1.0) cellpos = cellpos.zxy;

    if     (rnd2<1.0)
        return truchetCell(cellpos*fact,r);
    else if(rnd2<2.0)
        return truchetCell2(cellpos*fact,r);
    else if(rnd2<3.0)
        return truchetCell3(cellpos.zxy,r);

    return truchetCell(cellpos*fact,r);
}

//#define randSampler iChannel2

vec4 snoise(vec2 texc) { return  2.0*texture2D(randSampler,texc, -16.0)-vec4(1.0); }

vec4 snoise3Dv4S(vec3 texc)
{
    vec3 x=texc*256.0;
    vec3 p = floor(x);
    vec3 f = fract(x);
    // using iq's improved texture filtering (https://www.shadertoy.com/view/XsfGDn)
    f = f*f*(3.0-2.0*f);
    vec2 uv = ((p.xy+vec2(17.0,7.0)*p.z) + 0.5 + f.xy)/256.0;
    vec4 v1 = texture2D( randSampler, uv, -16.0);
    vec4 v2 = texture2D( randSampler, uv+vec2(17.0,7.0)/256.0, -16.0);
    return mix( v1, v2, f.z )-vec4(0.50);
}

// this is a somewhat modified version of iq's noise in "volcanic"
vec4 snoise3Dv4(vec3 texc)
{
    vec3 x=texc*256.0;
    vec3 p = floor(x);
    vec3 f = fract(x);
    //f = f*f*(3.0-2.0*f);
    vec2 uv;
    uv = (p.xy+vec2(17,7)*p.z) + 0.5 + f.xy;
    vec4 v1 = texture2D( randSampler, uv/256.0, -16.0);
    vec4 v2 = texture2D( randSampler, (uv+vec2(17,7))/256.0, -16.0);
    return mix( v1, v2, f.z )-vec4(0.50);
}

float snoise3D(vec3 texc)
{
    return snoise3Dv4(texc).x;
}

float snoise3DS(vec3 texc)
{
    return snoise3Dv4S(texc).x;
}

float mScaleNoise(vec3 texc)
{
    float d=0.0;
    d+=snoise3DS(texc);
    d+=snoise3DS(texc*2.553)*0.5;
    d+=snoise3DS(texc*5.154)*0.25;
    //d+=snoise3DS(texc*400.45)*0.009;
    d+=snoise3DS(texc*400.45*vec3(0.1,0.1,1.0))*0.009;
    //d+=snoise3DS(texc*900.45*vec3(0.1,1.0,0.1))*0.005;
    //d+=snoise3DS(texc*900.45*vec3(1.0,0.1,0.1))*0.005;
    d*=0.5;
    return d;
}

float getDistanceWorldS(vec3 pos)
{
    vec3 pos0=pos;

    float dist = 100000.0;
    dist=truchetDist(pos*0.006,0.13+0.05*cos(0.02*(pos.x+pos.y+pos.z)))/0.006;
    float f=sin(0.01*(pos.x+pos.y+pos.z));
    dist+=clamp(15.5*mScaleNoise(0.035*pos/256.0),-100.0,1000.0)*(0.2+0.8*f*f);

    return dist;
}

vec3 getDistanceWorldSGradientSlow(vec3 pos, float delta)
{
    return vec3 (
                 getDistanceWorldS( pos+delta*vec3(1,0,0) )-getDistanceWorldS( pos-delta*vec3(1,0,0) ),
                 getDistanceWorldS( pos+delta*vec3(0,1,0) )-getDistanceWorldS( pos-delta*vec3(0,1,0) ),
                 getDistanceWorldS( pos+delta*vec3(0,0,1) )-getDistanceWorldS( pos-delta*vec3(0,0,1) )
                )/2.0/delta;
}

vec3 getDistanceWorldSGradient(vec3 pos, float delta)
{
    delta*=2.0;
    vec3 eps=vec3(delta,0,0);
    float d=getDistanceWorldS(pos);
    return vec3(getDistanceWorldS(pos+eps.xyy)-d,
                getDistanceWorldS(pos+eps.yxy)-d,
                getDistanceWorldS(pos+eps.yyx)-d)/delta;
}

float getDistanceSphereS(vec3 pos, float r)
{
    return length(pos)-r;
}

#define WheelFR vec3( 0.8, 1.2,-0.1)
#define WheelFL vec3(-0.8, 1.2,-0.1)
#define WheelBR vec3( 0.8,-1.2,-0.1)
#define WheelBL vec3(-0.8,-1.2,-0.1)

#define Mass 2.0
#define Iinv (mat3( 1.6,0,0, 0,3.0,0, 0,0,1.4 )/Mass)
#define WheelRadius 0.45

// smoothed minimum - copied from iq's site (http://iquilezles.org/www/articles/smin/smin.htm)
float smin( float a, float b, float k )
{
    float res = exp( -k*a ) + exp( -k*b );
    return -log( res )/k;
}

vec4 getDistanceObjS(vec3 pos)
{
    float obj=0.0;
    float dist = 100000.0;
    float steeringAngle=readSteeringAngle();
    vec4 q = vec4(0,sin(steeringAngle*0.5),0,cos(steeringAngle*0.5));
    dist = min(dist, getDistanceBoxRounded(pos-vec3(0.0, 0.0,0.3),vec3(0.8-0.1, 1.8-0.1,0.35-0.1),0.1));
    dist = smin(dist, getDistanceBoxRounded(pos-vec3(0.0,-0.5,0.7),vec3(0.75-0.15,1.1-0.15,0.5-0.15),0.15),10.0);
    float dist2 = dist;
    dist = max(dist, -getDistanceSphereS((pos-WheelFL).yzx,WheelRadius*1.2));
    dist = max(dist, -getDistanceSphereS((pos-WheelFR).yzx,WheelRadius*1.2));
    dist = max(dist, -getDistanceSphereS((pos-WheelBL).yzx,WheelRadius*1.2));
    dist = max(dist, -getDistanceSphereS((pos-WheelBR).yzx,WheelRadius*1.2));
    dist = min(dist, getDistanceTorusS(transformVecByQuat((pos-WheelFR).yzx,q),WheelRadius-0.15,0.15));
    dist = min(dist, getDistanceTorusS(transformVecByQuat((pos-WheelFL).yzx,q),WheelRadius-0.15,0.15));
    dist = min(dist, getDistanceTorusS((pos-WheelBR).yzx,WheelRadius-0.15,0.15));
    dist = min(dist, getDistanceTorusS((pos-WheelBL).yzx,WheelRadius-0.15,0.15));
    if(dist!=dist2) obj=1.0;
    return vec4(dist,obj,0,0);
}
//----- update ------

void initAll( out vec4 fragColor, in vec2 fragCoord )
{
    fragColor=vec4(0.0);
    int pidx=PIdx(int(fragCoord.x),int(fragCoord.y));
    if(pidx>=0)
    {
        Particle p;
        p.pos.xyz = vec3(float(pidx*5)+torusWorldRadius1,0.0,torusWorldRadius2*1.1);
        p.vel.xyz = vec3(0,0,0);
        p.quat = vec4(0,0,0,1);
        p.quat = normalize(vec4(0.46,0.68,0.26,0.5));
        p.pos.xyz = vec3(101.7,2.41,84.72)+vec3(5,5,0)*float(pidx);
        writeParticle(pidx,p,fragColor,fragCoord);
    }
    writeCamPos(vec3(0),fragColor,fragCoord);
    writeCamPos(vec3(99.5,4.5,54.8),fragColor,fragCoord);
    writeCamQuat(vec4(0,0,0,1),fragColor,fragCoord);
    writeCamQuat(normalize(vec4(0.592,0.428,0.471,0.494)),fragColor,fragCoord);
    writeSteeringAngle(0.2,fragColor,fragCoord);
    writeGas(0.0,fragColor,fragCoord);
    writeCamNav(vec3(30.0,-0.54,0.3), fragColor, fragCoord);
}

#define SpringConst 10.1
#define SpringConstStab 5.1
#define DT min(0.5*iTimeDelta,0.05)

void calcWheelForceAndTorque(inout Particle p, vec3 wheelPos, float wheelRadius, float steeringAngle, float frictionCoeff, float wheelAngSpeed, float springConst, float clutch, inout vec3 force, inout vec3 torque)
{
    vec3 wheelPosW = p.pos.xyz+transformVecByQuat(wheelPos.xyz,p.quat);
    float dist = getDistanceWorldS(wheelPosW);
    if(dist<wheelRadius)
    {
        // forces by wheels
        vec3 dforce = vec3(0,0,0);
        vec3 distGrad = getDistanceWorldSGradient(wheelPosW,0.1);
        vec3 distDir = normalize(distGrad);
        dforce=distDir*(wheelRadius-dist)*springConst;
        //p.vel.xyz -= distDir*dot(p.vel.xyz,distDir)*0.1;
        force  += dforce;
        torque += cross(dforce,wheelPosW-p.pos.xyz);

        float fl = length(dforce);

        // wheel-drive-forces
        vec3 chassisRotVel = transformVecByQuat(cross(-p.angVel.xyz,wheelPos.xyz+vec3(0,0,-WheelRadius)),p.quat);
        vec3 wheelAxe = transformVecByQuat(vec3(cos(steeringAngle),sin(-steeringAngle),0),p.quat);
        vec3 f=normalize(cross(distDir,wheelAxe));
        //vec3 c=wheelAngSpeed*wheelRadius*f-p.vel.xyz-chassisRotVel+dot(p.vel.xyz+chassisRotVel,distDir)*0.9*distDir;
        ///*if(length(c)>1.0)*/ c=normalize(c);
        //dforce = fl*frictionCoeff*c;

        vec3 c=wheelAngSpeed*wheelRadius*f-p.vel.xyz-chassisRotVel;
        // in f dir
        dforce += fl*frictionCoeff*clutch*sign(dot(c,f))*f;
        // in wheelaxe dir
        dforce += fl*frictionCoeff*sign(dot(c,wheelAxe))*wheelAxe;
        // in up dir
        dforce += fl*sign(dot(c,distDir))*distDir*0.7;

        force  += dforce;
        torque += cross(dforce,wheelPosW+transformVecByQuat(vec3(0,0,-WheelRadius),p.quat)-p.pos.xyz);
    }

}

void calcObjForceAndMom(Particle p, Particle p2, inout vec3 force, inout vec3 torque)
{
    vec3 collpos1;
    vec3 collpos2;
    vec3 dforce=vec3(0);
    vec3 d;
    vec3 dn;

    for(int k=0;k<4;k++)
    {
        //collpos1 = p.pos.xyz  + transformVecByQuat(vec3(0,0.6,0)-vec3(0,1.2,0)*float(k&1),p.quat);
        //collpos2 = p2.pos.xyz + transformVecByQuat(vec3(0,0.6,0)-vec3(0,1.2,0)*float(k&2)*0.5,p2.quat);
        collpos1 = p.pos.xyz  + transformVecByQuat(vec3(0,0.6,0)-vec3(0,1.2,0)*mod(float(k),2.0),    p.quat);
        collpos2 = p2.pos.xyz + transformVecByQuat(vec3(0,0.6,0)-vec3(0,1.2,0)*mod(float(k),4.0)*0.5,p2.quat);

        d = collpos1 - collpos2;
        dn = p2.pos.xyz-p.pos.xyz;
        if( length(d)<2.0 ) dforce=100.1*d/(length(d)+0.1);
        force+=dforce;
        torque+=1.0*cross(dforce,0.5*(collpos1+collpos2)-p.pos.xyz);
    }
    //TODO: friction force+torque
    //torque+=0.3*cross(cross(dforce,normalize(dn)),0.5*(collpos1+collpos2)-pos);
}

#define GRAVITY -4.0
vec3 getGravityWorld(vec3 pos)
{
    return GRAVITY*normalize(getDistanceWorldSGradientSlow(pos, 5.0)+getDistanceWorldSGradientSlow(pos, 10.0));
}



void calcCamera( inout vec4 fragColor, in vec2 fragCoord )
{
    vec3 camPos  = readCamPos();
    vec4 camQuat = readCamQuat();
    vec3 camDistRzRx = readCamNav();
    float camDistScalar = camDistRzRx.x;
    float camRotZ = camDistRzRx.y;
    float camRotX = camDistRzRx.z;

    float sDist=getDistanceWorldS(camPos);
    if(sDist<0.2) camDistScalar-=0.2;
    //if(KEY_R>0.5) camDistScalar-=0.3;
    //if(KEY_F>0.5) camDistScalar+=0.3;
    if(camDistScalar<3.5) camDistScalar=3.5;

    //if(KEY_E>0.5) camRotZ-=0.01;
    //if(KEY_Q>0.5) camRotZ+=0.01;

    Particle p = readParticle(0);
    vec3 camDist = vec3(-sin(camRotZ)*cos(camRotX),-cos(camRotZ)*cos(camRotX),sin(camRotX))*camDistScalar;

    vec3 newCamPos  = p.pos.xyz+transformVecByQuat(camDist,p.quat);
    float ang;
    vec4 newCamQuat = p.quat;
    newCamQuat = multQuat(newCamQuat,vec4(normalize(vec2(camDist.yx*vec2(1,-1)))*sin(camRotX*0.5),0,cos(camRotX*0.5)));
    newCamQuat = multQuat(newCamQuat,vec4(0,0,sin(-camRotZ*0.5),cos(-camRotZ*0.5)));

    camPos  = mix( camPos,  newCamPos,  0.02 );

    camQuat = normalize(mix( camQuat, newCamQuat, 0.08 ));

    camDistRzRx.x=camDistScalar;
    camDistRzRx.y=camRotZ;
    camDistRzRx.z=camRotX;
    writeCamNav(camDistRzRx, fragColor, fragCoord);
    writeCamQuat(camQuat, fragColor, fragCoord);
    writeCamPos(camPos,   fragColor, fragCoord);
}


void calcSteering( inout vec4 fragColor, in vec2 fragCoord )
{
    float steeringAngle = readSteeringAngle();
    float gas = readGas();

    if     (key[0] < -0.2) steeringAngle-=0.02;
    else if(key[0] > 0.2) steeringAngle+=0.02;
    else steeringAngle*=0.9;

    if     (key[1] < -0.2) gas+=0.01;
    else if(key[1] > 0.2) gas-=0.01;
    else gas*=0.9;

    gas=clamp(gas,-1.0,1.0);
    steeringAngle=clamp(steeringAngle,-0.5,0.5);

    writeSteeringAngle(steeringAngle,   fragColor, fragCoord);
    writeGas(gas, fragColor, fragCoord);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // copy old content
    fragColor = getPixel(int(fragCoord.x),int(fragCoord.y));

    int pidx=PIdx(int(fragCoord.x),int(fragCoord.y));
    if(pidx>=0 && pidx<MaxParticleNum)
    {
        vec3 force = vec3(0,0,0);
        vec3 torque = vec3(0,0,0);

        Particle p = readParticle(pidx);

        // gravity
        force+=getGravityWorld(p.pos.xyz)*Mass;

        // velocity damping
        force+=-0.2*p.vel.xyz;
        torque+=-0.2*transformVecByQuat(p.angVel.xyz,p.quat);

        float steeringAngle = readSteeringAngle();
        float gas = readGas();
        float clutch = clamp(abs(gas),0.0,1.0);
        float rotSpeed = gas*50.0;
        if(key[4]>0.5) { clutch=1.0; gas=0.0; }
        // wheel forces
        calcWheelForceAndTorque(p,WheelFL,WheelRadius,steeringAngle,1.7,rotSpeed,SpringConst,clutch,force,torque);
        calcWheelForceAndTorque(p,WheelFR,WheelRadius,steeringAngle,1.7,rotSpeed,SpringConst,clutch,force,torque);
        calcWheelForceAndTorque(p,WheelBL,WheelRadius,     0.0,     1.7,rotSpeed,SpringConst,clutch,force,torque);
        calcWheelForceAndTorque(p,WheelBR,WheelRadius,     0.0,     1.7,rotSpeed,SpringConst,clutch,force,torque);
        // stabilizers
        calcWheelForceAndTorque(p,vec3(0,0,1.6),1.8,     0.0,     0.0,0.0,SpringConstStab,1.0,force,torque);

        vec3 fwd=transformVecByQuat(vec3(0,1,0),p.quat);
        vec3 up=transformVecByQuat(vec3(0,0,1),p.quat);

        // obj-obj collision forces
        for(int i=0;i<MaxParticleNum;i++)
        {
            if (i!=pidx)
            {
                Particle p2 = readParticle(i);
                calcObjForceAndMom(p,p2,force,torque);
            }
        }

        // clamp velocity
        float velLen = length(p.vel.xyz);
        if(velLen>120.1) p.vel.xyz*=120.1/velLen;
        /*float angVelLen = length(p.angVel.xyz);
        if(angVelLen>3.1) p.angVel.xyz*=3.1/velLen;*/

        // time integration
        // ...positional
        vec3 acc = force/Mass;
        p.vel.xyz += acc*0.5*DT;
        p.pos.xyz += p.vel.xyz*DT;
        p.vel.xyz += acc*0.5*DT;
        // ...angular
        vec3 angAcc = Iinv*transformVecByQuat(torque,inverseQuat(p.quat));
        p.angVel.xyz += angAcc*0.5*DT;
        p.quat = rotateQuatbyAngle(p.quat,-p.angVel.xyz*DT);
        p.angVel.xyz += angAcc*0.5*DT;

        writeParticle(pidx,p,fragColor,fragCoord);
    }

    calcCamera(fragColor,fragCoord);

    calcSteering(fragColor,fragCoord);

    if(iFrame<10 || key[5]>0.5) initAll(fragColor,fragCoord);
}
