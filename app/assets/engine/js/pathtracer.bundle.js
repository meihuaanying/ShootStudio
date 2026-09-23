/**
 * three-gpu-pathtracer@0.0.24 + three-mesh-bvh@0.9.15（均 MIT）
 * 打包产物：仅含路径追踪器，three 复用 window.__ssThree（引擎 vendor 版）。
 */
var SSPathTracer=(()=>{var Zr=Object.defineProperty;var vs=Object.getOwnPropertyDescriptor;var ys=Object.getOwnPropertyNames;var Ts=Object.prototype.hasOwnProperty;var Zo=(i,e)=>{for(var t in e)Zr(i,t,{get:e[t],enumerable:!0})},bs=(i,e,t,r)=>{if(e&&typeof e=="object"||typeof e=="function")for(let n of ys(e))!Ts.call(i,n)&&n!==t&&Zr(i,n,{get:()=>e[n],enumerable:!(r=vs(e,n))||r.enumerable});return i};var Ss=i=>bs(Zr({},"__esModule",{value:!0}),i);var Ra={};Zo(Ra,{BlurredEnvMapGenerator:()=>$o,DenoiseMaterial:()=>jo,DynamicPathTracingSceneGenerator:()=>Bo,EquirectCamera:()=>Wo,FogVolumeMaterial:()=>Qo,GradientEquirectTexture:()=>Ot,PathTracingRenderer:()=>ht,PathTracingSceneGenerator:()=>Ve,PathTracingSceneWorker:()=>Do,PhysicalCamera:()=>Bt,PhysicalPathTracingMaterial:()=>Lt,PhysicalSpotLight:()=>qo,ProceduralEquirectTexture:()=>Nt,ShapedAreaLight:()=>Yo,WebGLPathTracer:()=>Vo});var c=globalThis.__ssThree;if(!c)throw new Error("three_global_shim\uFF1Awindow.__ssThree \u672A\u8BBE\u7F6E\uFF08\u5F15\u64CE\u672A\u5C31\u7EEA\uFF1F\uFF09");var Ca=c.ACESFilmicToneMapping,Ma=c.AddEquation,Pa=c.AddOperation,Ba=c.AdditiveAnimationBlendMode,Jo=c.AdditiveBlending,Da=c.AgXToneMapping,Ea=c.AlphaFormat,La=c.AlwaysCompare,Na=c.AlwaysDepth,Oa=c.AlwaysStencilFunc,Ga=c.AmbientLight,ka=c.AnimationAction,za=c.AnimationClip,Ua=c.AnimationLoader,Ha=c.AnimationMixer,Va=c.AnimationObjectGroup,Wa=c.AnimationUtils,qa=c.ArcCurve,Ya=c.ArrayCamera,Xa=c.ArrowHelper,$a=c.AttachedBindMode,ja=c.Audio,Qa=c.AudioAnalyser,Ka=c.AudioContext,Za=c.AudioListener,Ja=c.AudioLoader,ec=c.AxesHelper,kt=c.BackSide,tc=c.BasicDepthPacking,rc=c.BasicShadowMap,oc=c.BatchedMesh,ic=c.BezierInterpolant,nc=c.Bone,sc=c.BooleanKeyframeTrack,ac=c.Box2,ee=c.Box3,cc=c.Box3Helper,lc=c.BoxGeometry,uc=c.BoxHelper,K=c.BufferAttribute,ae=c.BufferGeometry,fc=c.BufferGeometryLoader,Jr=c.ByteType,pc=c.Cache,ei=c.Camera,mc=c.CameraHelper,dc=c.CanvasTexture,hc=c.CapsuleGeometry,xc=c.CatmullRomCurve3,gc=c.CineonToneMapping,vc=c.CircleGeometry,ce=c.ClampToEdgeWrapping,ti=c.Clock,he=c.Color,yc=c.ColorKeyframeTrack,Tc=c.ColorManagement,bc=c.Compatibility,Sc=c.CompressedArrayTexture,_c=c.CompressedCubeTexture,wc=c.CompressedTexture,Ac=c.CompressedTextureLoader,Rc=c.ConeGeometry,Ic=c.ConstantAlphaFactor,Fc=c.ConstantColorFactor,Cc=c.Controls,Mc=c.CubeCamera,Pc=c.CubeDepthTexture,Bc=c.CubeReflectionMapping,Dc=c.CubeRefractionMapping,Ec=c.CubeTexture,Lc=c.CubeTextureLoader,Nc=c.CubeUVReflectionMapping,Oc=c.CubicBezierCurve,Gc=c.CubicBezierCurve3,kc=c.CubicInterpolant,zc=c.CullFaceBack,Uc=c.CullFaceFront,Hc=c.CullFaceFrontBack,Vc=c.CullFaceNone,Wc=c.Curve,qc=c.CurvePath,Yc=c.CustomBlending,Xc=c.CustomToneMapping,$c=c.CylinderGeometry,jc=c.Cylindrical,Qc=c.Data3DTexture,ri=c.DataArrayTexture,$=c.DataTexture,Kc=c.DataTextureLoader,ne=c.DataUtils,Zc=c.DecrementStencilOp,Jc=c.DecrementWrapStencilOp,el=c.DefaultLoadingManager,tl=c.DepthFormat,rl=c.DepthStencilFormat,ol=c.DepthTexture,il=c.DetachedBindMode,nl=c.DirectionalLight,sl=c.DirectionalLightHelper,al=c.DiscreteInterpolant,cl=c.DodecahedronGeometry,zt=c.DoubleSide,ll=c.DstAlphaFactor,ul=c.DstColorFactor,fl=c.DynamicCopyUsage,pl=c.DynamicDrawUsage,ml=c.DynamicReadUsage,dl=c.EdgesGeometry,hl=c.EllipseCurve,xl=c.EqualCompare,gl=c.EqualDepth,vl=c.EqualStencilFunc,je=c.EquirectangularReflectionMapping,yl=c.EquirectangularRefractionMapping,Tl=c.Euler,bl=c.EventDispatcher,Sl=c.ExternalTexture,_l=c.ExtrudeGeometry,wl=c.FileLoader,Al=c.Float16BufferAttribute,eo=c.Float32BufferAttribute,G=c.FloatType,Rl=c.Fog,Il=c.FogExp2,Fl=c.FramebufferTexture,vt=c.FrontSide,Cl=c.Frustum,Ml=c.FrustumArray,Pl=c.GLBufferAttribute,Bl=c.GLSL1,Dl=c.GLSL3,El=c.GreaterCompare,Ll=c.GreaterDepth,Nl=c.GreaterEqualCompare,Ol=c.GreaterEqualDepth,Gl=c.GreaterEqualStencilFunc,kl=c.GreaterStencilFunc,zl=c.GridHelper,Ul=c.Group,Hl=c.HTMLTexture,te=c.HalfFloatType,Vl=c.HemisphereLight,Wl=c.HemisphereLightHelper,ql=c.IcosahedronGeometry,Yl=c.ImageBitmapLoader,Xl=c.ImageLoader,$l=c.ImageUtils,jl=c.IncrementStencilOp,Ql=c.IncrementWrapStencilOp,Kl=c.InstancedBufferAttribute,Zl=c.InstancedBufferGeometry,Jl=c.InstancedInterleavedBuffer,eu=c.InstancedMesh,tu=c.Int16BufferAttribute,ru=c.Int32BufferAttribute,ou=c.Int8BufferAttribute,Ut=c.IntType,iu=c.InterleavedBuffer,nu=c.InterleavedBufferAttribute,su=c.Interpolant,au=c.InterpolateBezier,cu=c.InterpolateDiscrete,lu=c.InterpolateLinear,uu=c.InterpolateSmooth,fu=c.InterpolationSamplingMode,pu=c.InterpolationSamplingType,mu=c.InvertStencilOp,du=c.KeepStencilOp,hu=c.KeyframeTrack,xu=c.LOD,gu=c.LatheGeometry,vu=c.Layers,yu=c.LessCompare,Tu=c.LessDepth,bu=c.LessEqualCompare,Su=c.LessEqualDepth,_u=c.LessEqualStencilFunc,wu=c.LessStencilFunc,Au=c.Light,Ru=c.LightProbe,Iu=c.LightShadow,Fu=c.Line,ue=c.Line3,Cu=c.LineBasicMaterial,Mu=c.LineCurve,Pu=c.LineCurve3,Bu=c.LineDashedMaterial,Du=c.LineLoop,Eu=c.LineSegments,re=c.LinearFilter,Lu=c.LinearInterpolant,oi=c.LinearMipMapLinearFilter,Nu=c.LinearMipMapNearestFilter,Ou=c.LinearMipmapLinearFilter,Gu=c.LinearMipmapNearestFilter,ku=c.LinearSRGBColorSpace,zu=c.LinearToneMapping,Uu=c.LinearTransfer,Hu=c.Loader,Vu=c.LoaderUtils,Wu=c.LoadingManager,qu=c.LoopOnce,Yu=c.LoopPingPong,Xu=c.LoopRepeat,$u=c.MOUSE,ju=c.Material,Qu=c.MaterialBlending,Ku=c.MaterialLoader,Zu=c.MathUtils,Ju=c.Matrix2,ii=c.Matrix3,V=c.Matrix4,ef=c.MaxEquation,Ht=c.Mesh,ni=c.MeshBasicMaterial,tf=c.MeshDepthMaterial,rf=c.MeshDistanceMaterial,of=c.MeshLambertMaterial,nf=c.MeshMatcapMaterial,sf=c.MeshNormalMaterial,af=c.MeshPhongMaterial,cf=c.MeshPhysicalMaterial,si=c.MeshStandardMaterial,lf=c.MeshToonMaterial,uf=c.MinEquation,ff=c.MirroredRepeatWrapping,pf=c.MixOperation,mf=c.MultiplyBlending,df=c.MultiplyOperation,U=c.NearestFilter,hf=c.NearestMipMapLinearFilter,xf=c.NearestMipMapNearestFilter,gf=c.NearestMipmapLinearFilter,vf=c.NearestMipmapNearestFilter,yf=c.NeutralToneMapping,Tf=c.NeverCompare,bf=c.NeverDepth,Sf=c.NeverStencilFunc,xe=c.NoBlending,_f=c.NoColorSpace,wf=c.NoNormalPacking,ai=c.NoToneMapping,Af=c.NormalAnimationBlendMode,Vt=c.NormalBlending,Rf=c.NormalGAPacking,If=c.NormalRGPacking,Ff=c.NotEqualCompare,Cf=c.NotEqualDepth,Mf=c.NotEqualStencilFunc,Pf=c.NumberKeyframeTrack,Bf=c.Object3D,Df=c.ObjectLoader,Ef=c.ObjectSpaceNormalMap,Lf=c.OctahedronGeometry,Nf=c.OneFactor,Of=c.OneMinusConstantAlphaFactor,Gf=c.OneMinusConstantColorFactor,kf=c.OneMinusDstAlphaFactor,zf=c.OneMinusDstColorFactor,Uf=c.OneMinusSrcAlphaFactor,Hf=c.OneMinusSrcColorFactor,ci=c.OrthographicCamera,Vf=c.PCFShadowMap,Wf=c.PCFSoftShadowMap,li=c.PMREMGenerator,qf=c.Path,Wt=c.PerspectiveCamera,qt=c.Plane,Yf=c.PlaneGeometry,Xf=c.PlaneHelper,$f=c.PointLight,jf=c.PointLightHelper,Qf=c.Points,Kf=c.PointsMaterial,Zf=c.PolarGridHelper,Jf=c.PolyhedronGeometry,ep=c.PositionalAudio,tp=c.PropertyBinding,rp=c.PropertyMixer,op=c.QuadraticBezierCurve,ip=c.QuadraticBezierCurve3,ui=c.Quaternion,np=c.QuaternionKeyframeTrack,sp=c.QuaternionLinearInterpolant,ap=c.R11_EAC_Format,cp=c.RED_GREEN_RGTC2_Format,lp=c.RED_RGTC1_Format,to=c.REVISION,up=c.RG11_EAC_Format,fp=c.RGBADepthPacking,L=c.RGBAFormat,Yt=c.RGBAIntegerFormat,pp=c.RGBA_ASTC_10x10_Format,mp=c.RGBA_ASTC_10x5_Format,dp=c.RGBA_ASTC_10x6_Format,hp=c.RGBA_ASTC_10x8_Format,xp=c.RGBA_ASTC_12x10_Format,gp=c.RGBA_ASTC_12x12_Format,vp=c.RGBA_ASTC_4x4_Format,yp=c.RGBA_ASTC_5x4_Format,Tp=c.RGBA_ASTC_5x5_Format,bp=c.RGBA_ASTC_6x5_Format,Sp=c.RGBA_ASTC_6x6_Format,_p=c.RGBA_ASTC_8x5_Format,wp=c.RGBA_ASTC_8x6_Format,Ap=c.RGBA_ASTC_8x8_Format,Rp=c.RGBA_BPTC_Format,Ip=c.RGBA_ETC2_EAC_Format,Fp=c.RGBA_PVRTC_2BPPV1_Format,Cp=c.RGBA_PVRTC_4BPPV1_Format,Mp=c.RGBA_S3TC_DXT1_Format,Pp=c.RGBA_S3TC_DXT3_Format,Bp=c.RGBA_S3TC_DXT5_Format,Dp=c.RGBDepthPacking,Ep=c.RGBFormat,Lp=c.RGBIntegerFormat,Np=c.RGB_BPTC_SIGNED_Format,Op=c.RGB_BPTC_UNSIGNED_Format,Gp=c.RGB_ETC1_Format,kp=c.RGB_ETC2_Format,zp=c.RGB_PVRTC_2BPPV1_Format,Up=c.RGB_PVRTC_4BPPV1_Format,Hp=c.RGB_S3TC_DXT1_Format,Vp=c.RGDepthPacking,Xt=c.RGFormat,$t=c.RGIntegerFormat,Wp=c.RawShaderMaterial,fi=c.Ray,qp=c.Raycaster,pi=c.RectAreaLight,De=c.RedFormat,mi=c.RedIntegerFormat,Yp=c.ReinhardToneMapping,Xp=c.RenderObjectRefreshType,$p=c.RenderTarget,jp=c.RenderTarget3D,fe=c.RepeatWrapping,Qp=c.ReplaceStencilOp,Kp=c.ReverseSubtractEquation,Zp=c.RingGeometry,Jp=c.SIGNED_R11_EAC_Format,em=c.SIGNED_RED_GREEN_RGTC2_Format,tm=c.SIGNED_RED_RGTC1_Format,rm=c.SIGNED_RG11_EAC_Format,om=c.SRGBColorSpace,im=c.SRGBTransfer,di=c.Scene,nm=c.ShaderChunk,sm=c.ShaderLib,_e=c.ShaderMaterial,am=c.ShadowMaterial,cm=c.Shape,lm=c.ShapeGeometry,um=c.ShapePath,fm=c.ShapeUtils,hi=c.ShortType,pm=c.Skeleton,mm=c.SkeletonHelper,dm=c.SkinnedMesh,xi=c.Source,hm=c.Sphere,xm=c.SphereGeometry,gi=c.Spherical,gm=c.SphericalHarmonics3,vm=c.SplineCurve,vi=c.SpotLight,ym=c.SpotLightHelper,Tm=c.Sprite,bm=c.SpriteMaterial,Sm=c.SrcAlphaFactor,_m=c.SrcAlphaSaturateFactor,wm=c.SrcColorFactor,Am=c.StaticCopyUsage,Rm=c.StaticDrawUsage,Im=c.StaticReadUsage,Fm=c.StereoCamera,Cm=c.StreamCopyUsage,Mm=c.StreamDrawUsage,Pm=c.StreamReadUsage,Bm=c.StringKeyframeTrack,Dm=c.SubtractEquation,Em=c.SubtractiveBlending,Lm=c.TOUCH,Nm=c.TangentSpaceNormalMap,Om=c.TetrahedronGeometry,Gm=c.Texture,km=c.TextureLoader,zm=c.TextureSource,Um=c.TextureUtils,Hm=c.Timer,Vm=c.TimestampQuery,Wm=c.TorusGeometry,qm=c.TorusKnotGeometry,Te=c.Triangle,Ym=c.TriangleFanDrawMode,Xm=c.TriangleStripDrawMode,$m=c.TrianglesDrawMode,jm=c.TubeGeometry,Qm=c.UVMapping,Km=c.Uint16BufferAttribute,Zm=c.Uint32BufferAttribute,Jm=c.Uint8BufferAttribute,ed=c.Uint8ClampedBufferAttribute,td=c.Uniform,rd=c.UniformsGroup,od=c.UniformsLib,id=c.UniformsUtils,yt=c.UnsignedByteType,nd=c.UnsignedInt101111Type,sd=c.UnsignedInt248Type,ad=c.UnsignedInt5999Type,Ee=c.UnsignedIntType,cd=c.UnsignedShort4444Type,ld=c.UnsignedShort5551Type,yi=c.UnsignedShortType,ud=c.VSMShadowMap,X=c.Vector2,P=c.Vector3,we=c.Vector4,fd=c.VectorKeyframeTrack,pd=c.VideoFrameTexture,md=c.VideoTexture,dd=c.WebGL3DRenderTarget,Ti=c.WebGLArrayRenderTarget,hd=c.WebGLCoordinateSystem,xd=c.WebGLCubeRenderTarget,ye=c.WebGLRenderTarget,gd=c.WebGLRenderer,vd=c.WebGLUtils,yd=c.WebGPUCoordinateSystem,Td=c.WebXRController,bd=c.WireframeGeometry,Sd=c.WrapAroundEnding,_d=c.ZeroCurvatureEnding,wd=c.ZeroFactor,Ad=c.ZeroSlopeEnding,Rd=c.ZeroStencilOp,Id=c.createCanvasElement,Fd=c.error,Cd=c.getConsoleFunction,Md=c.log,Pd=c.setConsoleFunction,Bd=c.warn,Dd=c.warnOnce;var Qe=Math.pow(2,-24),Tt=Symbol("SKIP_GENERATION"),jt={strategy:0,maxDepth:40,targetLeafSize:10,useSharedArrayBuffer:!1,setBoundingBox:!0,onProgress:null,indirect:!1,verbose:!0,range:null,[Tt]:!1};function W(i,e,t){return t.min.x=e[i],t.min.y=e[i+1],t.min.z=e[i+2],t.max.x=e[i+3],t.max.y=e[i+4],t.max.z=e[i+5],t}function bt(i){let e=-1,t=-1/0;for(let r=0;r<3;r++){let n=i[r+3]-i[r];n>t&&(t=n,e=r)}return e}function ro(i,e){e.set(i)}function oo(i,e,t){let r,n;for(let s=0;s<3;s++){let o=s+3;r=i[s],n=e[s],t[s]=r<n?r:n,r=i[o],n=e[o],t[o]=r>n?r:n}}function St(i,e,t){for(let r=0;r<3;r++){let n=e[i+2*r],s=e[i+2*r+1],o=n-s,l=n+s;o<t[r]&&(t[r]=o),l>t[r+3]&&(t[r+3]=l)}}function Ke(i){let e=i[3]-i[0],t=i[4]-i[1],r=i[5]-i[2];return 2*(e*t+t*r+r*e)}function E(i,e){return e[i+15]===65535}function O(i,e){return e[i+6]}function H(i,e){return e[i+14]}function k(i){return i+8}function z(i,e){let t=e[i+6];return i+t*8}function Ae(i,e){return e[i+7]}function Qt(i,e,t,r,n){let s=1/0,o=1/0,l=1/0,u=-1/0,m=-1/0,p=-1/0,f=1/0,a=1/0,h=1/0,g=-1/0,T=-1/0,d=-1/0,b=i.offset||0;for(let x=(e-b)*6,v=(e+t-b)*6;x<v;x+=6){let y=i[x+0],S=i[x+1],w=y-S,_=y+S;w<s&&(s=w),_>u&&(u=_),y<f&&(f=y),y>g&&(g=y);let I=i[x+2],F=i[x+3],A=I-F,C=I+F;A<o&&(o=A),C>m&&(m=C),I<a&&(a=I),I>T&&(T=I);let R=i[x+4],M=i[x+5],B=R-M,D=R+M;B<l&&(l=B),D>p&&(p=D),R<h&&(h=R),R>d&&(d=R)}r[0]=s,r[1]=o,r[2]=l,r[3]=u,r[4]=m,r[5]=p,n[0]=f,n[1]=a,n[2]=h,n[3]=g,n[4]=T,n[5]=d}var be=32,As=(i,e)=>i.candidate-e.candidate,Re=new Array(be).fill().map(()=>({count:0,bounds:new Float32Array(6),rightCacheBounds:new Float32Array(6),leftCacheBounds:new Float32Array(6),candidate:0})),Kt=new Float32Array(6);function _i(i,e,t,r,n,s){let o=-1,l=0;if(s===0)o=bt(e),o!==-1&&(l=(e[o]+e[o+3])/2);else if(s===1)o=bt(i),o!==-1&&(l=Rs(t,r,n,o));else if(s===2){let u=Ke(i),m=1.25*n,p=t.offset||0,f=(r-p)*6,a=(r+n-p)*6;for(let h=0;h<3;h++){let g=e[h],b=(e[h+3]-g)/be;if(n<be/4){let x=[...Re];x.length=n;let v=0;for(let S=f;S<a;S+=6,v++){let w=x[v];w.candidate=t[S+2*h],w.count=0;let{bounds:_,leftCacheBounds:I,rightCacheBounds:F}=w;for(let A=0;A<3;A++)F[A]=1/0,F[A+3]=-1/0,I[A]=1/0,I[A+3]=-1/0,_[A]=1/0,_[A+3]=-1/0;St(S,t,_)}x.sort(As);let y=n;for(let S=0;S<y;S++){let w=x[S];for(;S+1<y&&x[S+1].candidate===w.candidate;)x.splice(S+1,1),y--}for(let S=f;S<a;S+=6){let w=t[S+2*h];for(let _=0;_<y;_++){let I=x[_];w>=I.candidate?St(S,t,I.rightCacheBounds):(St(S,t,I.leftCacheBounds),I.count++)}}for(let S=0;S<y;S++){let w=x[S],_=w.count,I=n-w.count,F=w.leftCacheBounds,A=w.rightCacheBounds,C=0;_!==0&&(C=Ke(F)/u);let R=0;I!==0&&(R=Ke(A)/u);let M=1+1.25*(C*_+R*I);M<m&&(o=h,m=M,l=w.candidate)}}else{for(let y=0;y<be;y++){let S=Re[y];S.count=0,S.candidate=g+b+y*b;let w=S.bounds;for(let _=0;_<3;_++)w[_]=1/0,w[_+3]=-1/0}for(let y=f;y<a;y+=6){let _=~~((t[y+2*h]-g)/b);_>=be&&(_=be-1);let I=Re[_];I.count++,St(y,t,I.bounds)}let x=Re[be-1];ro(x.bounds,x.rightCacheBounds);for(let y=be-2;y>=0;y--){let S=Re[y],w=Re[y+1];oo(S.bounds,w.rightCacheBounds,S.rightCacheBounds)}let v=0;for(let y=0;y<be-1;y++){let S=Re[y],w=S.count,_=S.bounds,F=Re[y+1].rightCacheBounds;w!==0&&(v===0?ro(_,Kt):oo(_,Kt,Kt)),v+=w;let A=0,C=0;v!==0&&(A=Ke(Kt)/u);let R=n-v;R!==0&&(C=Ke(F)/u);let M=1+1.25*(A*v+C*R);M<m&&(o=h,m=M,l=S.candidate)}}}}else console.warn(`BVH: Invalid build strategy value ${s} used.`);return{axis:o,pos:l}}function Rs(i,e,t,r){let n=0,s=i.offset;for(let o=e,l=e+t;o<l;o++)n+=i[(o-s)*6+r*2];return n/t}var Ze=class{constructor(){this.boundingData=new Float32Array(6)}};function wi(i,e,t,r,n,s){let o=r,l=r+n-1,u=s.pos,m=s.axis*2,p=t.offset||0;for(;;){for(;o<=l&&t[(o-p)*6+m]<u;)o++;for(;o<=l&&t[(l-p)*6+m]>=u;)l--;if(o<l){for(let f=0;f<e;f++){let a=i[o*e+f];i[o*e+f]=i[l*e+f],i[l*e+f]=a}for(let f=0;f<6;f++){let a=o-p,h=l-p,g=t[a*6+f];t[a*6+f]=t[h*6+f],t[h*6+f]=g}o++,l--}else return o}}var Ai,Zt,io,Ri,Is=Math.pow(2,32);function Jt(i){return"count"in i?1:1+Jt(i.left)+Jt(i.right)}function Ii(i,e,t){return Ai=new Float32Array(t),Zt=new Uint32Array(t),io=new Uint16Array(t),Ri=new Uint8Array(t),no(i,e)}function no(i,e){let t=i/4,r=i/2,n="count"in e,s=e.boundingData;for(let o=0;o<6;o++)Ai[t+o]=s[o];if(n)return e.buffer?(Ri.set(new Uint8Array(e.buffer),i),i+e.buffer.byteLength):(Zt[t+6]=e.offset,io[r+14]=e.count,io[r+15]=65535,i+32);{let{left:o,right:l,splitAxis:u}=e,m=i+32,p=no(m,o),f=i/32,h=p/32-f;if(h>Is)throw new Error("MeshBVH: Cannot store relative child node offset greater than 32 bits.");return Zt[t+6]=h,Zt[t+7]=u,no(p,l)}}function Fs(i,e,t,r,n,s){let{maxDepth:o,verbose:l,targetLeafSize:u,_strictLeafSize:m=1/0,strategy:p,onProgress:f}=n,a=i.primitiveBuffer,h=i.primitiveBufferStride,g=new Float32Array(6),T=!1,d=new Ze;return Qt(e,t,r,d.boundingData,g),x(d,t,r,g),d;function b(v){f&&f((v-s.offset)/s.count)}function x(v,y,S,w=null,_=0){!T&&_>=o&&(T=!0,l&&console.warn(`BVH: Max depth of ${o} reached when generating BVH. Consider increasing maxDepth.`));let I=S>m;if(S<=u&&!I||_>=o)return b(y+S),v.offset=y,v.count=S,v;let F=_i(v.boundingData,w,e,y,S,p),A=F.axis===-1?-1:wi(a,h,e,y,S,F);if(F.axis===-1||A===y||A===y+S){if(!I)return b(y+S),v.offset=y,v.count=S,v;F.axis=Math.max(0,bt(v.boundingData)),A=y+Math.max(1,Math.floor(S/2))}v.splitAxis=F.axis;let C=new Ze,R=y,M=A-y;v.left=C,Qt(e,R,M,C.boundingData,g),x(C,R,M,g,_+1);let B=new Ze,D=A,Y=S-M;return v.right=B,Qt(e,D,Y,B.boundingData,g),x(B,D,Y,g,_+1),v}}function Fi(i,e){let t=e.useSharedArrayBuffer?SharedArrayBuffer:ArrayBuffer,r=i.getRootRanges(e.range),n=r[0],s=r[r.length-1],o={offset:n.offset,count:s.offset+s.count-n.offset},l=new Float32Array(6*o.count);l.offset=o.offset,i.computePrimitiveBounds(o.offset,o.count,l),i._roots=r.map(u=>{let m=Fs(i,l,u.offset,u.count,e,o),p=Jt(m),f=new t(32*p);return Ii(0,m,f),f})}var Ie=class{constructor(e){this._getNewPrimitive=e,this._primitives=[]}getPrimitive(){let e=this._primitives;return e.length===0?this._getNewPrimitive():e.pop()}releasePrimitive(e){this._primitives.push(e)}};var so=class{constructor(){this.float32Array=null,this.uint16Array=null,this.uint32Array=null;let e=[],t=null;this.setBuffer=r=>{t&&e.push(t),t=r,this.float32Array=new Float32Array(r),this.uint16Array=new Uint16Array(r),this.uint32Array=new Uint32Array(r)},this.clearBuffer=()=>{t=null,this.float32Array=null,this.uint16Array=null,this.uint32Array=null,e.length!==0&&this.setBuffer(e.pop())}}},N=new so;var Fe,et,Je=[],er=new Ie(()=>new ee);function Ci(i,e,t,r,n,s){Fe=er.getPrimitive(),et=er.getPrimitive(),Je.push(Fe,et),N.setBuffer(i._roots[e]);let o=ao(0,i.geometry,t,r,n,s);N.clearBuffer(),er.releasePrimitive(Fe),er.releasePrimitive(et),Je.pop(),Je.pop();let l=Je.length;return l>0&&(et=Je[l-1],Fe=Je[l-2]),o}function ao(i,e,t,r,n=null,s=0,o=0){let{float32Array:l,uint16Array:u,uint32Array:m}=N,p=i*2;if(E(p,u)){let a=O(i,m),h=H(p,u);return W(i,l,Fe),r(a,h,!1,o,s+i/8,Fe)}else{let A=function(R){let{uint16Array:M,uint32Array:B}=N,D=R*2;for(;!E(D,M);)R=k(R),D=R*2;return O(R,B)},C=function(R){let{uint16Array:M,uint32Array:B}=N,D=R*2;for(;!E(D,M);)R=z(R,B),D=R*2;return O(R,B)+H(D,M)},a=k(i),h=z(i,m),g=a,T=h,d,b,x,v;if(n&&(x=Fe,v=et,W(g,l,x),W(T,l,v),d=n(x),b=n(v),b<d)){g=h,T=a;let R=d;d=b,b=R,x=v}x||(x=Fe,W(g,l,x));let y=E(g*2,u),S=t(x,y,d,o+1,s+g/8),w;if(S===2){let R=A(g),B=C(g)-R;w=r(R,B,!0,o+1,s+g/8,x)}else w=S&&ao(g,e,t,r,n,s,o+1);if(w)return!0;v=et,W(T,l,v);let _=E(T*2,u),I=t(v,_,b,o+1,s+T/8),F;if(I===2){let R=A(T),B=C(T)-R;F=r(R,B,!0,o+1,s+T/8,v)}else F=I&&ao(T,e,t,r,n,s,o+1);return!!F}}var _t=new N.constructor,rr=new N.constructor,Ce=new Ie(()=>new ee),tt=new ee,rt=new ee,co=new ee,lo=new ee,uo=!1;function Mi(i,e,t,r){if(uo)throw new Error("MeshBVH: Recursive calls to bvhcast not supported.");uo=!0;let n=i._roots,s=e._roots,o,l=0,u=0,m=new V().copy(t).invert();for(let p=0,f=n.length;p<f;p++){_t.setBuffer(n[p]),u=0;let a=Ce.getPrimitive();W(0,_t.float32Array,a),a.applyMatrix4(m);for(let h=0,g=s.length;h<g&&(rr.setBuffer(s[h]),o=ge(0,0,t,m,r,l,u,0,0,a),rr.clearBuffer(),u+=s[h].byteLength/32,!o);h++);if(Ce.releasePrimitive(a),_t.clearBuffer(),l+=n[p].byteLength/32,o)break}return uo=!1,o}function ge(i,e,t,r,n,s=0,o=0,l=0,u=0,m=null,p=!1){let f,a;p?(f=rr,a=_t):(f=_t,a=rr);let h=f.float32Array,g=f.uint32Array,T=f.uint16Array,d=a.float32Array,b=a.uint32Array,x=a.uint16Array,v=i*2,y=e*2,S=E(v,T),w=E(y,x),_=!1;if(w&&S)p?_=n(O(e,b),H(e*2,x),O(i,g),H(i*2,T),u,o+e/8,l,s+i/8):_=n(O(i,g),H(i*2,T),O(e,b),H(e*2,x),l,s+i/8,u,o+e/8);else if(w){let I=Ce.getPrimitive();W(e,d,I),I.applyMatrix4(t);let F=k(i),A=z(i,g);W(F,h,tt),W(A,h,rt);let C=I.intersectsBox(tt),R=I.intersectsBox(rt);_=C&&ge(e,F,r,t,n,o,s,u,l+1,I,!p)||R&&ge(e,A,r,t,n,o,s,u,l+1,I,!p),Ce.releasePrimitive(I)}else{let I=k(e),F=z(e,b);W(I,d,co),W(F,d,lo);let A=m.intersectsBox(co),C=m.intersectsBox(lo);if(A&&C)_=ge(i,I,t,r,n,s,o,l,u+1,m,p)||ge(i,F,t,r,n,s,o,l,u+1,m,p);else if(A)if(S)_=ge(i,I,t,r,n,s,o,l,u+1,m,p);else{let R=Ce.getPrimitive();R.copy(co).applyMatrix4(t);let M=k(i),B=z(i,g);W(M,h,tt),W(B,h,rt);let D=R.intersectsBox(tt),Y=R.intersectsBox(rt);_=D&&ge(I,M,r,t,n,o,s,u,l+1,R,!p)||Y&&ge(I,B,r,t,n,o,s,u,l+1,R,!p),Ce.releasePrimitive(R)}else if(C)if(S)_=ge(i,F,t,r,n,s,o,l,u+1,m,p);else{let R=Ce.getPrimitive();R.copy(lo).applyMatrix4(t);let M=k(i),B=z(i,g);W(M,h,tt),W(B,h,rt);let D=R.intersectsBox(tt),Y=R.intersectsBox(rt);_=D&&ge(F,M,r,t,n,o,s,u,l+1,R,!p)||Y&&ge(F,B,r,t,n,o,s,u,l+1,R,!p),Ce.releasePrimitive(R)}}return _}var or=new class{constructor(){let i=null,e=null,t=null,r=!1;this.root=null,this.buffer=null,this.uint32Array=null,this.uint16Array=null,this.setBVH=(s,o)=>{if(r)throw new Error("BVHTraversalHelper: cannot call setBVH during an active traversal.");this.root=o,this.buffer=i=s._roots[o],this.uint16Array=t=new Uint16Array(i),this.uint32Array=e=new Uint32Array(i)},this.reset=()=>{this.root=null,this.buffer=i=null,this.uint16Array=t=null,this.uint32Array=e=null},this.getRangeStart=s=>{let o=s*2;for(;!E(o,t);)s=k(s),o=s*2;return O(s,e)},this.getRangeEnd=s=>{let o=s*2;for(;!E(o,t);)s=z(s,e),o=s*2;return O(s,e)+H(o,t)};let n=(s,o,l)=>{let u=o*2,m=E(u,t);if(!s(l,m,o)&&!m){let f=k(o),a=z(o,e);n(s,f,l+1),n(s,a,l+1)}};this.traverseBuffer=s=>{if(r)throw new Error("BVHTraversalHelper: cannot start a traversal during an active traversal.");r=!0;try{n(s,0,0)}finally{r=!1}},this.traverse=s=>{this.traverseBuffer((o,l,u)=>{if(l){let m=u*2,p=e[u+6],f=t[m+14];return s(o,l,new Float32Array(i,u*4,6),p,f)}else{let m=Ae(u,e);return s(o,l,new Float32Array(i,u*4,6),m)}})}}};var Pi=new ee,ot=new Float32Array(6),ir=class{constructor(){this._roots=null,this.primitiveBuffer=null,this.primitiveBufferStride=null}init(e){e={...jt,...e},"maxLeafSize"in e&&(console.warn('BVH: "maxLeafSize" option has been deprecated. Use "targetLeafSize", instead.'),e={...e,targetLeafSize:e.maxLeafSize}),Fi(this,e)}getRootRanges(){throw new Error("BVH: getRootRanges() not implemented")}writePrimitiveBounds(){throw new Error("BVH: writePrimitiveBounds() not implemented")}writePrimitiveRangeBounds(e,t,r,n){let s=1/0,o=1/0,l=1/0,u=-1/0,m=-1/0,p=-1/0;for(let f=e,a=e+t;f<a;f++){this.writePrimitiveBounds(f,ot,0);let[h,g,T,d,b,x]=ot;h<s&&(s=h),d>u&&(u=d),g<o&&(o=g),b>m&&(m=b),T<l&&(l=T),x>p&&(p=x)}return r[n+0]=s,r[n+1]=o,r[n+2]=l,r[n+3]=u,r[n+4]=m,r[n+5]=p,r}computePrimitiveBounds(e,t,r){let n=r.offset||0;for(let s=e,o=e+t;s<o;s++){this.writePrimitiveBounds(s,ot,0);let[l,u,m,p,f,a]=ot,h=(l+p)/2,g=(u+f)/2,T=(m+a)/2,d=(p-l)/2,b=(f-u)/2,x=(a-m)/2,v=(s-n)*6;r[v+0]=h,r[v+1]=d+(Math.abs(h)+d)*Qe,r[v+2]=g,r[v+3]=b+(Math.abs(g)+b)*Qe,r[v+4]=T,r[v+5]=x+(Math.abs(T)+x)*Qe}return r}shiftPrimitiveOffsets(e){let t=this._indirectBuffer;if(t)for(let r=0,n=t.length;r<n;r++)t[r]+=e;else{let r=this._roots;for(let n=0;n<r.length;n++){let s=r[n],o=new Uint32Array(s),l=new Uint16Array(s),u=s.byteLength/32;for(let m=0;m<u;m++){let p=8*m,f=2*p;E(f,l)&&(o[p+6]+=e)}}}}traverse(e,t=0){or.setBVH(this,t),or.traverse(e),or.reset()}refit(){let e=this._roots;for(let t=0,r=e.length;t<r;t++){let n=e[t],s=new Uint32Array(n),o=new Uint16Array(n),l=new Float32Array(n),u=n.byteLength/32;for(let m=u-1;m>=0;m--){let p=m*8,f=p*2;if(E(f,o)){let h=O(p,s),g=H(f,o);this.writePrimitiveRangeBounds(h,g,ot,0),l.set(ot,p)}else{let h=k(p),g=z(p,s);for(let T=0;T<3;T++){let d=l[h+T],b=l[h+T+3],x=l[g+T],v=l[g+T+3];l[p+T]=d<x?d:x,l[p+T+3]=b>v?b:v}}}}}getBoundingBox(e){return e.makeEmpty(),this._roots.forEach(r=>{W(0,new Float32Array(r),Pi),e.union(Pi)}),e}shapecast(e){let{boundsTraverseOrder:t,intersectsBounds:r,intersectsRange:n,intersectsPrimitive:s,scratchPrimitive:o,iterate:l}=e;if(n&&s){let f=n;n=(a,h,g,T,d)=>f(a,h,g,T,d)?!0:l(a,h,this,s,g,T,o)}else n||(s?n=(f,a,h,g)=>l(f,a,this,s,h,g,o):n=(f,a,h)=>h);let u=!1,m=0,p=this._roots;for(let f=0,a=p.length;f<a;f++){let h=p[f];if(u=Ci(this,f,r,n,t,m),u)break;m+=h.byteLength/32}return u}bvhcast(e,t,r){let{intersectsRanges:n}=r;return Mi(this,e,t,n)}};function Bi(){return typeof SharedArrayBuffer<"u"}function wt(i){return i.index?i.index.count:i.attributes.position.count}function Me(i){return wt(i)/3}function fo(i,e=ArrayBuffer){return i>65535?new Uint32Array(new e(4*i)):new Uint16Array(new e(2*i))}function Di(i,e){if(!i.index){let t=i.attributes.position.count,r=e.useSharedArrayBuffer?SharedArrayBuffer:ArrayBuffer,n=fo(t,r);i.setIndex(new K(n,1));for(let s=0;s<t;s++)n[s]=s}}function Ms(i,e,t){let r=wt(i)/t,n=e||i.drawRange,s=n.start/t,o=(n.start+n.count)/t,l=Math.max(0,s),u=Math.min(r,o)-l;return{offset:Math.floor(l),count:Math.floor(u)}}function Ps(i,e){return i.groups.map(t=>({offset:t.start/e,count:t.count/e}))}function po(i,e,t){let r=Ms(i,e,t),n=Ps(i,t);if(!n.length)return[r];let s=[],o=r.offset,l=r.offset+r.count,u=wt(i)/t,m=[];for(let a of n){let{offset:h,count:g}=a,T=h,d=isFinite(g)?g:u-h,b=h+d;T<l&&b>o&&(m.push({pos:Math.max(o,T),isStart:!0}),m.push({pos:Math.min(l,b),isStart:!1}))}m.sort((a,h)=>a.pos!==h.pos?a.pos-h.pos:a.type==="end"?-1:1);let p=0,f=null;for(let a of m){let h=a.pos;p!==0&&h!==f&&s.push({offset:f,count:h-f}),p+=a.isStart?1:-1,f=h}return s}function Bs(i,e){let t=i[i.length-1],r=t.offset+t.count>2**16,n=i.reduce((m,p)=>m+p.count,0),s=r?4:2,o=e?new SharedArrayBuffer(n*s):new ArrayBuffer(n*s),l=r?new Uint32Array(o):new Uint16Array(o),u=0;for(let m=0;m<i.length;m++){let{offset:p,count:f}=i[m];for(let a=0;a<f;a++)l[u+a]=p+a;u+=f}return l}var nr=class extends ir{get indirect(){return!!this._indirectBuffer}get primitiveStride(){return null}get primitiveBufferStride(){return this.indirect?1:this.primitiveStride}set primitiveBufferStride(e){}get primitiveBuffer(){return this.indirect?this._indirectBuffer:this.geometry.index.array}set primitiveBuffer(e){}constructor(e,t={}){if(e.isBufferGeometry){if(e.index&&e.index.isInterleavedBufferAttribute)throw new Error("BVH: InterleavedBufferAttribute is not supported for the index attribute.")}else throw new Error("BVH: Only BufferGeometries are supported.");if(t.useSharedArrayBuffer&&!Bi())throw new Error("BVH: SharedArrayBuffer is not available.");super(),this.geometry=e,this.resolvePrimitiveIndex=t.indirect?r=>this._indirectBuffer[r]:r=>r,this.primitiveBuffer=null,this.primitiveBufferStride=null,this._indirectBuffer=null,t={...jt,...t},t[Tt]||this.init(t)}init(e){let{geometry:t,primitiveStride:r}=this;if(e.indirect){let n=po(t,e.range,r),s=Bs(n,e.useSharedArrayBuffer);this._indirectBuffer=s}else Di(t,e);super.init(e),!t.boundingBox&&e.setBoundingBox&&(t.boundingBox=this.getBoundingBox(new ee))}getRootRanges(e){return this.indirect?[{offset:0,count:this._indirectBuffer.length}]:po(this.geometry,e,this.primitiveStride)}raycastObject3D(){throw new Error("BVH: raycastObject3D() not implemented")}};var le=class{constructor(){this.min=1/0,this.max=-1/0}setFromPointsField(e,t){let r=1/0,n=-1/0;for(let s=0,o=e.length;s<o;s++){let u=e[s][t];r=u<r?u:r,n=u>n?u:n}this.min=r,this.max=n}setFromPoints(e,t){let r=1/0,n=-1/0;for(let s=0,o=t.length;s<o;s++){let l=t[s],u=e.dot(l);r=u<r?u:r,n=u>n?u:n}this.min=r,this.max=n}isSeparated(e){return this.min>e.max||e.min>this.max}};le.prototype.setFromBox=function(){let i=new P;return function(t,r){let n=r.min,s=r.max,o=1/0,l=-1/0;for(let u=0;u<=1;u++)for(let m=0;m<=1;m++)for(let p=0;p<=1;p++){i.x=n.x*u+s.x*(1-u),i.y=n.y*m+s.y*(1-m),i.z=n.z*p+s.z*(1-p);let f=t.dot(i);o=Math.min(f,o),l=Math.max(f,l)}this.min=o,this.max=l}}();var Ds=function(){let i=new P,e=new P,t=new P;return function(n,s,o){let l=n.start,u=i,m=s.start,p=e;t.subVectors(l,m),i.subVectors(n.end,n.start),e.subVectors(s.end,s.start);let f=t.dot(p),a=p.dot(u),h=p.dot(p),g=t.dot(u),d=u.dot(u)*h-a*a,b,x;d!==0?b=(f*a-g*h)/d:b=0,x=(f+b*a)/h,o.x=b,o.y=x}}(),At=function(){let i=new X,e=new P,t=new P;return function(n,s,o,l){Ds(n,s,i);let u=i.x,m=i.y;if(u>=0&&u<=1&&m>=0&&m<=1){n.at(u,o),s.at(m,l);return}else if(u>=0&&u<=1){m<0?s.at(0,l):s.at(1,l),n.closestPointToPoint(l,!0,o);return}else if(m>=0&&m<=1){u<0?n.at(0,o):n.at(1,o),s.closestPointToPoint(o,!0,l);return}else{let p;u<0?p=n.start:p=n.end;let f;m<0?f=s.start:f=s.end;let a=e,h=t;if(n.closestPointToPoint(f,!0,e),s.closestPointToPoint(p,!0,t),a.distanceToSquared(f)<=h.distanceToSquared(p)){o.copy(a),l.copy(f);return}else{o.copy(p),l.copy(h);return}}}}(),Ei=function(){let i=new P,e=new P,t=new qt,r=new ue;return function(s,o){let{radius:l,center:u}=s,{a:m,b:p,c:f}=o;if(r.start=m,r.end=p,r.closestPointToPoint(u,!0,i).distanceTo(u)<=l||(r.start=m,r.end=f,r.closestPointToPoint(u,!0,i).distanceTo(u)<=l)||(r.start=p,r.end=f,r.closestPointToPoint(u,!0,i).distanceTo(u)<=l))return!0;let T=o.getPlane(t);if(Math.abs(T.distanceToPoint(u))<=l){let b=T.projectPoint(u,e);if(o.containsPoint(b))return!0}return!1}}();var Es=["x","y","z"],Se=1e-15,Li=Se*Se;function pe(i){return Math.abs(i)<Se}var J=class extends Te{constructor(...e){super(...e),this.isExtendedTriangle=!0,this.satAxes=new Array(4).fill().map(()=>new P),this.satBounds=new Array(4).fill().map(()=>new le),this.points=[this.a,this.b,this.c],this.plane=new qt,this.isDegenerateIntoSegment=!1,this.isDegenerateIntoPoint=!1,this.degenerateSegment=new ue,this.needsUpdate=!0}intersectsSphere(e){return Ei(e,this)}update(){let e=this.a,t=this.b,r=this.c,n=this.points,s=this.satAxes,o=this.satBounds,l=s[0],u=o[0];this.getNormal(l),u.setFromPoints(l,n);let m=s[1],p=o[1];m.subVectors(e,t),p.setFromPoints(m,n);let f=s[2],a=o[2];f.subVectors(t,r),a.setFromPoints(f,n);let h=s[3],g=o[3];h.subVectors(r,e),g.setFromPoints(h,n);let T=m.length(),d=f.length(),b=h.length();this.isDegenerateIntoPoint=!1,this.isDegenerateIntoSegment=!1,T<Se?d<Se||b<Se?this.isDegenerateIntoPoint=!0:(this.isDegenerateIntoSegment=!0,this.degenerateSegment.start.copy(e),this.degenerateSegment.end.copy(r)):d<Se?b<Se?this.isDegenerateIntoPoint=!0:(this.isDegenerateIntoSegment=!0,this.degenerateSegment.start.copy(t),this.degenerateSegment.end.copy(e)):b<Se&&(this.isDegenerateIntoSegment=!0,this.degenerateSegment.start.copy(r),this.degenerateSegment.end.copy(t)),this.plane.setFromNormalAndCoplanarPoint(l,e),this.needsUpdate=!1}};J.prototype.closestPointToSegment=function(){let i=new P,e=new P,t=new ue;return function(n,s=null,o=null){let{start:l,end:u}=n,m=this.points,p,f=1/0;for(let a=0;a<3;a++){let h=(a+1)%3;t.start.copy(m[a]),t.end.copy(m[h]),At(t,n,i,e),p=i.distanceToSquared(e),p<f&&(f=p,s&&s.copy(i),o&&o.copy(e))}return this.closestPointToPoint(l,i),p=l.distanceToSquared(i),p<f&&(f=p,s&&s.copy(i),o&&o.copy(l)),this.closestPointToPoint(u,i),p=u.distanceToSquared(i),p<f&&(f=p,s&&s.copy(i),o&&o.copy(u)),Math.sqrt(f)}}();J.prototype.intersectsTriangle=function(){let i=new J,e=new le,t=new le,r=new P,n=new P,s=new P,o=new P,l=new ue,u=new ue,m=new P,p=new X,f=new X;function a(v,y,S,w){let _=r;!v.isDegenerateIntoPoint&&!v.isDegenerateIntoSegment?_.copy(v.plane.normal):_.copy(y.plane.normal);let I=v.satBounds,F=v.satAxes;for(let R=1;R<4;R++){let M=I[R],B=F[R];if(e.setFromPoints(B,y.points),M.isSeparated(e)||(o.copy(_).cross(B),e.setFromPoints(o,v.points),t.setFromPoints(o,y.points),e.isSeparated(t)))return!1}let A=y.satBounds,C=y.satAxes;for(let R=1;R<4;R++){let M=A[R],B=C[R];if(e.setFromPoints(B,v.points),M.isSeparated(e)||(o.crossVectors(_,B),e.setFromPoints(o,v.points),t.setFromPoints(o,y.points),e.isSeparated(t)))return!1}return S&&(w||console.warn("ExtendedTriangle.intersectsTriangle: Triangles are coplanar which does not support an output edge. Setting edge to 0, 0, 0."),S.start.set(0,0,0),S.end.set(0,0,0)),!0}function h(v,y,S,w,_,I,F,A,C,R,M){let B=F/(F-A);R.x=w+(_-w)*B,M.start.subVectors(y,v).multiplyScalar(B).add(v),B=F/(F-C),R.y=w+(I-w)*B,M.end.subVectors(S,v).multiplyScalar(B).add(v)}function g(v,y,S,w,_,I,F,A,C,R,M){if(_>0)h(v.c,v.a,v.b,w,y,S,C,F,A,R,M);else if(I>0)h(v.b,v.a,v.c,S,y,w,A,F,C,R,M);else if(A*C>0||F!=0)h(v.a,v.b,v.c,y,S,w,F,A,C,R,M);else if(A!=0)h(v.b,v.a,v.c,S,y,w,A,F,C,R,M);else if(C!=0)h(v.c,v.a,v.b,w,y,S,C,F,A,R,M);else return!0;return!1}function T(v,y,S,w){let _=y.degenerateSegment,I=v.plane.distanceToPoint(_.start),F=v.plane.distanceToPoint(_.end);return pe(I)?pe(F)?a(v,y,S,w):(S&&(S.start.copy(_.start),S.end.copy(_.start)),v.containsPoint(_.start)):pe(F)?(S&&(S.start.copy(_.end),S.end.copy(_.end)),v.containsPoint(_.end)):v.plane.intersectLine(_,r)!=null?(S&&(S.start.copy(r),S.end.copy(r)),v.containsPoint(r)):!1}function d(v,y,S){let w=y.a;return pe(v.plane.distanceToPoint(w))&&v.containsPoint(w)?(S&&(S.start.copy(w),S.end.copy(w)),!0):!1}function b(v,y,S){let w=v.degenerateSegment,_=y.a;return w.closestPointToPoint(_,!0,r),_.distanceToSquared(r)<Li?(S&&(S.start.copy(_),S.end.copy(_)),!0):!1}function x(v,y,S,w){if(v.isDegenerateIntoSegment)if(y.isDegenerateIntoSegment){let _=v.degenerateSegment,I=y.degenerateSegment,F=n,A=s;_.delta(F),I.delta(A);let C=r.subVectors(I.start,_.start),R=F.x*A.y-F.y*A.x;if(pe(R))return!1;let M=(C.x*A.y-C.y*A.x)/R,B=-(F.x*C.y-F.y*C.x)/R;if(M<0||M>1||B<0||B>1)return!1;let D=_.start.z+F.z*M,Y=I.start.z+A.z*B;return pe(D-Y)?(S&&(S.start.copy(_.start).addScaledVector(F,M),S.end.copy(_.start).addScaledVector(F,M)),!0):!1}else return y.isDegenerateIntoPoint?b(v,y,S):T(y,v,S,w);else{if(v.isDegenerateIntoPoint)return y.isDegenerateIntoPoint?y.a.distanceToSquared(v.a)<Li?(S&&(S.start.copy(v.a),S.end.copy(v.a)),!0):!1:y.isDegenerateIntoSegment?b(y,v,S):d(y,v,S);if(y.isDegenerateIntoPoint)return d(v,y,S);if(y.isDegenerateIntoSegment)return T(v,y,S,w)}}return function(y,S=null,w=!1){this.needsUpdate&&this.update(),y.isExtendedTriangle?y.needsUpdate&&y.update():(i.copy(y),i.update(),y=i);let _=x(this,y,S,w);if(_!==void 0)return _;let I=this.plane,F=y.plane,A=F.distanceToPoint(this.a),C=F.distanceToPoint(this.b),R=F.distanceToPoint(this.c);pe(A)&&(A=0),pe(C)&&(C=0),pe(R)&&(R=0);let M=A*C,B=A*R;if(M>0&&B>0)return!1;let D=I.distanceToPoint(y.a),Y=I.distanceToPoint(y.b),qe=I.distanceToPoint(y.c);pe(D)&&(D=0),pe(Y)&&(Y=0),pe(qe)&&(qe=0);let Ye=D*Y,gt=D*qe;if(Ye>0&&gt>0)return!1;n.copy(I.normal),s.copy(F.normal);let Xe=n.cross(s),Be=0,Qr=Math.abs(Xe.x),Ko=Math.abs(Xe.y);Ko>Qr&&(Qr=Ko,Be=1),Math.abs(Xe.z)>Qr&&(Be=2);let $e=Es[Be],ps=this.a[$e],ms=this.b[$e],ds=this.c[$e],hs=y.a[$e],xs=y.b[$e],gs=y.c[$e];if(g(this,ps,ms,ds,M,B,A,C,R,p,l))return a(this,y,S,w);if(g(y,hs,xs,gs,Ye,gt,D,Y,qe,f,u))return a(this,y,S,w);if(p.y<p.x){let Kr=p.y;p.y=p.x,p.x=Kr,m.copy(l.start),l.start.copy(l.end),l.end.copy(m)}if(f.y<f.x){let Kr=f.y;f.y=f.x,f.x=Kr,m.copy(u.start),u.start.copy(u.end),u.end.copy(m)}return p.y<f.x||f.y<p.x?!1:(S&&(f.x>p.x?S.start.copy(u.start):S.start.copy(l.start),f.y<p.y?S.end.copy(u.end):S.end.copy(l.end)),!0)}}();J.prototype.distanceToPoint=function(){let i=new P;return function(t){return this.closestPointToPoint(t,i),t.distanceTo(i)}}();J.prototype.distanceToTriangle=function(){let i=new P,e=new P,t=["a","b","c"],r=new ue,n=new ue;return function(o,l=null,u=null){let m=l||u?r:null;if(this.intersectsTriangle(o,m,!0))return(l||u)&&(l&&m.getCenter(l),u&&m.getCenter(u)),0;let p=1/0;for(let f=0;f<3;f++){let a,h=t[f],g=o[h];this.closestPointToPoint(g,i),a=g.distanceToSquared(i),a<p&&(p=a,l&&l.copy(i),u&&u.copy(g));let T=this[h];o.closestPointToPoint(T,i),a=T.distanceToSquared(i),a<p&&(p=a,l&&l.copy(T),u&&u.copy(i))}for(let f=0;f<3;f++){let a=t[f],h=t[(f+1)%3];r.set(this[a],this[h]);for(let g=0;g<3;g++){let T=t[g],d=t[(g+1)%3];n.set(o[T],o[d]),At(r,n,i,e);let b=i.distanceToSquared(e);b<p&&(p=b,l&&l.copy(i),u&&u.copy(e))}}return Math.sqrt(p)}}();var j=class{constructor(e,t,r){this.isOrientedBox=!0,this.min=new P,this.max=new P,this.matrix=new V,this.invMatrix=new V,this.points=new Array(8).fill().map(()=>new P),this.satAxes=new Array(3).fill().map(()=>new P),this.satBounds=new Array(3).fill().map(()=>new le),this.alignedSatBounds=new Array(3).fill().map(()=>new le),this.needsUpdate=!1,e&&this.min.copy(e),t&&this.max.copy(t),r&&this.matrix.copy(r)}set(e,t,r){this.min.copy(e),this.max.copy(t),this.matrix.copy(r),this.needsUpdate=!0}copy(e){this.min.copy(e.min),this.max.copy(e.max),this.matrix.copy(e.matrix),this.needsUpdate=!0}};j.prototype.update=function(){return function(){let e=this.matrix,t=this.min,r=this.max,n=this.points;for(let m=0;m<=1;m++)for(let p=0;p<=1;p++)for(let f=0;f<=1;f++){let a=1*m|2*p|4*f,h=n[a];h.x=m?r.x:t.x,h.y=p?r.y:t.y,h.z=f?r.z:t.z,h.applyMatrix4(e)}let s=this.satBounds,o=this.satAxes,l=n[0];for(let m=0;m<3;m++){let p=o[m],f=s[m],a=1<<m,h=n[a];p.subVectors(l,h),f.setFromPoints(p,n)}let u=this.alignedSatBounds;u[0].setFromPointsField(n,"x"),u[1].setFromPointsField(n,"y"),u[2].setFromPointsField(n,"z"),this.invMatrix.copy(this.matrix).invert(),this.needsUpdate=!1}}();j.prototype.intersectsBox=function(){let i=new le;return function(t){this.needsUpdate&&this.update();let r=t.min,n=t.max,s=this.satBounds,o=this.satAxes,l=this.alignedSatBounds;if(i.min=r.x,i.max=n.x,l[0].isSeparated(i)||(i.min=r.y,i.max=n.y,l[1].isSeparated(i))||(i.min=r.z,i.max=n.z,l[2].isSeparated(i)))return!1;for(let u=0;u<3;u++){let m=o[u],p=s[u];if(i.setFromBox(m,t),p.isSeparated(i))return!1}return!0}}();j.prototype.intersectsTriangle=function(){let i=new J,e=new Array(3),t=new le,r=new le,n=new P;return function(o){this.needsUpdate&&this.update(),o.isExtendedTriangle?o.needsUpdate&&o.update():(i.copy(o),i.update(),o=i);let l=this.satBounds,u=this.satAxes;e[0]=o.a,e[1]=o.b,e[2]=o.c;for(let a=0;a<3;a++){let h=l[a],g=u[a];if(t.setFromPoints(g,e),h.isSeparated(t))return!1}let m=o.satBounds,p=o.satAxes,f=this.points;for(let a=0;a<3;a++){let h=m[a],g=p[a];if(t.setFromPoints(g,f),h.isSeparated(t))return!1}for(let a=0;a<3;a++){let h=u[a];for(let g=0;g<4;g++){let T=p[g];if(n.crossVectors(h,T),t.setFromPoints(n,e),r.setFromPoints(n,f),t.isSeparated(r))return!1}}return!0}}();j.prototype.closestPointToPoint=function(){return function(e,t){return this.needsUpdate&&this.update(),t.copy(e).applyMatrix4(this.invMatrix).clamp(this.min,this.max).applyMatrix4(this.matrix),t}}();j.prototype.distanceToPoint=function(){let i=new P;return function(t){return this.closestPointToPoint(t,i),t.distanceTo(i)}}();j.prototype.distanceToBox=function(){let i=["x","y","z"],e=new Array(12).fill().map(()=>new ue),t=new Array(12).fill().map(()=>new ue),r=new P,n=new P;return function(o,l=0,u=null,m=null){if(this.needsUpdate&&this.update(),this.intersectsBox(o))return(u||m)&&(o.getCenter(n),this.closestPointToPoint(n,r),o.closestPointToPoint(r,n),u&&u.copy(r),m&&m.copy(n)),0;let p=l*l,f=o.min,a=o.max,h=this.points,g=1/0;for(let d=0;d<8;d++){let b=h[d];n.copy(b).clamp(f,a);let x=b.distanceToSquared(n);if(x<g&&(g=x,u&&u.copy(b),m&&m.copy(n),x<p))return Math.sqrt(x)}let T=0;for(let d=0;d<3;d++)for(let b=0;b<=1;b++)for(let x=0;x<=1;x++){let v=(d+1)%3,y=(d+2)%3,S=b<<v|x<<y,w=1<<d|b<<v|x<<y,_=h[S],I=h[w];e[T].set(_,I);let A=i[d],C=i[v],R=i[y],M=t[T],B=M.start,D=M.end;B[A]=f[A],B[C]=b?f[C]:a[C],B[R]=x?f[R]:a[C],D[A]=a[A],D[C]=b?f[C]:a[C],D[R]=x?f[R]:a[C],T++}for(let d=0;d<=1;d++)for(let b=0;b<=1;b++)for(let x=0;x<=1;x++){n.x=d?a.x:f.x,n.y=b?a.y:f.y,n.z=x?a.z:f.z,this.closestPointToPoint(n,r);let v=n.distanceToSquared(r);if(v<g&&(g=v,u&&u.copy(r),m&&m.copy(n),v<p))return Math.sqrt(v)}for(let d=0;d<12;d++){let b=e[d];for(let x=0;x<12;x++){let v=t[x];At(b,v,r,n);let y=r.distanceToSquared(n);if(y<g&&(g=y,u&&u.copy(r),m&&m.copy(n),y<p))return Math.sqrt(y)}}return Math.sqrt(g)}}();var mo=class extends Ie{constructor(){super(()=>new J)}},oe=new mo;var Rt=new P,ho=new P;function Ni(i,e,t={},r=0,n=1/0){let s=r*r,o=n*n,l=1/0,u=null;if(i.shapecast({boundsTraverseOrder:p=>(Rt.copy(e).clamp(p.min,p.max),Rt.distanceToSquared(e)),intersectsBounds:(p,f,a)=>a<l&&a<o,intersectsTriangle:(p,f)=>{p.closestPointToPoint(e,Rt);let a=e.distanceToSquared(Rt);return a<l&&(ho.copy(Rt),l=a,u=f),a<s}}),l===1/0)return null;let m=Math.sqrt(l);return t.point?t.point.copy(ho):t.point=ho.clone(),t.distance=m,t.faceIndex=u,t}var sr=parseInt(to)>=169,Ls=parseInt(to)<=161,Le=new P,Ne=new P,Oe=new P,ar=new X,cr=new X,lr=new X,Oi=new P,Gi=new P,ki=new P,It=new P;function Ns(i,e,t,r,n,s,o,l){let u;if(s===kt?u=i.intersectTriangle(r,t,e,!0,n):u=i.intersectTriangle(e,t,r,s!==zt,n),u===null)return null;let m=i.origin.distanceTo(n);return m<o||m>l?null:{distance:m,point:n.clone()}}function zi(i,e,t,r,n,s,o,l,u,m,p){Le.fromBufferAttribute(e,s),Ne.fromBufferAttribute(e,o),Oe.fromBufferAttribute(e,l);let f=Ns(i,Le,Ne,Oe,It,u,m,p);if(f){if(r){ar.fromBufferAttribute(r,s),cr.fromBufferAttribute(r,o),lr.fromBufferAttribute(r,l),f.uv=new X;let h=Te.getInterpolation(It,Le,Ne,Oe,ar,cr,lr,f.uv);sr||(f.uv=h)}if(n){ar.fromBufferAttribute(n,s),cr.fromBufferAttribute(n,o),lr.fromBufferAttribute(n,l),f.uv1=new X;let h=Te.getInterpolation(It,Le,Ne,Oe,ar,cr,lr,f.uv1);sr||(f.uv1=h),Ls&&(f.uv2=f.uv1)}if(t){Oi.fromBufferAttribute(t,s),Gi.fromBufferAttribute(t,o),ki.fromBufferAttribute(t,l),f.normal=new P;let h=Te.getInterpolation(It,Le,Ne,Oe,Oi,Gi,ki,f.normal);f.normal.dot(i.direction)>0&&f.normal.multiplyScalar(-1),sr||(f.normal=h)}let a={a:s,b:o,c:l,normal:new P,materialIndex:0};if(Te.getNormal(Le,Ne,Oe,a.normal),f.face=a,f.faceIndex=s,sr){let h=new P;Te.getBarycoord(It,Le,Ne,Oe,h),f.barycoord=h}}return f}function Ui(i){return i&&i.isMaterial?i.side:i}function it(i,e,t,r,n,s,o){let l=r*3,u=l+0,m=l+1,p=l+2,{index:f,groups:a}=i;i.index&&(u=f.getX(u),m=f.getX(m),p=f.getX(p));let{position:h,normal:g,uv:T,uv1:d}=i.attributes;if(Array.isArray(e)){let b=r*3;for(let x=0,v=a.length;x<v;x++){let{start:y,count:S,materialIndex:w}=a[x];if(b>=y&&b<y+S){let _=Ui(e[w]),I=zi(t,h,g,T,d,u,m,p,_,s,o);if(I)if(I.faceIndex=r,I.face.materialIndex=w,n)n.push(I);else return I}}}else{let b=Ui(e),x=zi(t,h,g,T,d,u,m,p,b,s,o);if(x)if(x.faceIndex=r,x.face.materialIndex=0,n)n.push(x);else return x}return null}function q(i,e,t,r){let n=i.a,s=i.b,o=i.c,l=e,u=e+1,m=e+2;t&&(l=t.getX(l),u=t.getX(u),m=t.getX(m)),n.x=r.getX(l),n.y=r.getY(l),n.z=r.getZ(l),s.x=r.getX(u),s.y=r.getY(u),s.z=r.getZ(u),o.x=r.getX(m),o.y=r.getY(m),o.z=r.getZ(m)}function Hi(i,e,t,r,n,s,o,l){let{geometry:u,_indirectBuffer:m}=i;for(let p=r,f=r+n;p<f;p++)it(u,e,t,p,s,o,l)}function Vi(i,e,t,r,n,s,o){let{geometry:l,_indirectBuffer:u}=i,m=1/0,p=null;for(let f=r,a=r+n;f<a;f++){let h;h=it(l,e,t,f,null,s,o),h&&h.distance<m&&(p=h,m=h.distance)}return p}function Wi(i,e,t,r,n,s,o){let{geometry:l}=t,{index:u}=l,m=l.attributes.position;for(let p=i,f=e+i;p<f;p++){let a;if(a=p,q(o,a*3,u,m),o.needsUpdate=!0,r(o,a,n,s))return!0}return!1}function qi(i,e=null){e&&Array.isArray(e)&&(e=new Set(e));let t=i.geometry,r=t.index?t.index.array:null,n=t.attributes.position,s,o,l,u,m=0,p=i._roots;for(let a=0,h=p.length;a<h;a++)s=p[a],o=new Uint32Array(s),l=new Uint16Array(s),u=new Float32Array(s),f(0,m),m+=s.byteLength;function f(a,h,g=!1){let T=a*2;if(E(T,l)){let d=O(a,o),b=H(T,l),x=1/0,v=1/0,y=1/0,S=-1/0,w=-1/0,_=-1/0;for(let I=3*d,F=3*(d+b);I<F;I++){let A=r[I],C=n.getX(A),R=n.getY(A),M=n.getZ(A);C<x&&(x=C),C>S&&(S=C),R<v&&(v=R),R>w&&(w=R),M<y&&(y=M),M>_&&(_=M)}return u[a+0]!==x||u[a+1]!==v||u[a+2]!==y||u[a+3]!==S||u[a+4]!==w||u[a+5]!==_?(u[a+0]=x,u[a+1]=v,u[a+2]=y,u[a+3]=S,u[a+4]=w,u[a+5]=_,!0):!1}else{let d=k(a),b=z(a,o),x=g,v=!1,y=!1;if(e){if(!x){let A=d/8+h/32,C=b/8+h/32;v=e.has(A),y=e.has(C),x=!v&&!y}}else v=!0,y=!0;let S=x||v,w=x||y,_=!1;S&&(_=f(d,h,x));let I=!1;w&&(I=f(b,h,x));let F=_||I;if(F)for(let A=0;A<3;A++){let C=d+A,R=b+A,M=u[C],B=u[C+3],D=u[R],Y=u[R+3];u[a+A]=M<D?M:D,u[a+A+3]=B>Y?B:Y}return F}}}function me(i,e,t,r,n){let s,o,l,u,m,p,f=1/t.direction.x,a=1/t.direction.y,h=1/t.direction.z,g=t.origin.x,T=t.origin.y,d=t.origin.z,b=e[i],x=e[i+3],v=e[i+1],y=e[i+3+1],S=e[i+2],w=e[i+3+2];return f>=0?(s=(b-g)*f,o=(x-g)*f):(s=(x-g)*f,o=(b-g)*f),a>=0?(l=(v-T)*a,u=(y-T)*a):(l=(y-T)*a,u=(v-T)*a),s>u||l>o||((l>s||isNaN(s))&&(s=l),(u<o||isNaN(o))&&(o=u),h>=0?(m=(S-d)*h,p=(w-d)*h):(m=(w-d)*h,p=(S-d)*h),s>p||m>o)?!1:((m>s||s!==s)&&(s=m),(p<o||o!==o)&&(o=p),s<=n&&o>=r)}function Yi(i,e,t,r,n,s,o,l){let{geometry:u,_indirectBuffer:m}=i;for(let p=r,f=r+n;p<f;p++){let a=m?m[p]:p;it(u,e,t,a,s,o,l)}}function Xi(i,e,t,r,n,s,o){let{geometry:l,_indirectBuffer:u}=i,m=1/0,p=null;for(let f=r,a=r+n;f<a;f++){let h;h=it(l,e,t,u?u[f]:f,null,s,o),h&&h.distance<m&&(p=h,m=h.distance)}return p}function $i(i,e,t,r,n,s,o){let{geometry:l}=t,{index:u}=l,m=l.attributes.position;for(let p=i,f=e+i;p<f;p++){let a;if(a=t.resolveTriangleIndex(p),q(o,a*3,u,m),o.needsUpdate=!0,r(o,a,n,s))return!0}return!1}function ji(i,e,t,r,n,s,o){N.setBuffer(i._roots[e]),xo(0,i,t,r,n,s,o),N.clearBuffer()}function xo(i,e,t,r,n,s,o){let{float32Array:l,uint16Array:u,uint32Array:m}=N,p=i*2;if(E(p,u)){let a=O(i,m),h=H(p,u);Hi(e,t,r,a,h,n,s,o)}else{let a=k(i);me(a,l,r,s,o)&&xo(a,e,t,r,n,s,o);let h=z(i,m);me(h,l,r,s,o)&&xo(h,e,t,r,n,s,o)}}var Os=["x","y","z"];function Qi(i,e,t,r,n,s){N.setBuffer(i._roots[e]);let o=go(0,i,t,r,n,s);return N.clearBuffer(),o}function go(i,e,t,r,n,s){let{float32Array:o,uint16Array:l,uint32Array:u}=N,m=i*2;if(E(m,l)){let f=O(i,u),a=H(m,l);return Vi(e,t,r,f,a,n,s)}else{let f=Ae(i,u),a=Os[f],g=r.direction[a]>=0,T,d;g?(T=k(i),d=z(i,u)):(T=z(i,u),d=k(i));let x=me(T,o,r,n,s)?go(T,e,t,r,n,s):null;if(x){let S=x.point[a];if(g?S<=o[d+f]:S>=o[d+f+3])return x}let y=me(d,o,r,n,s)?go(d,e,t,r,n,s):null;return x&&y?x.distance<=y.distance?x:y:x||y||null}}var ur=new ee,nt=new J,st=new J,Ft=new V,Ki=new j,fr=new j;function Zi(i,e,t,r){N.setBuffer(i._roots[e]);let n=vo(0,i,t,r);return N.clearBuffer(),n}function vo(i,e,t,r,n=null){let{float32Array:s,uint16Array:o,uint32Array:l}=N,u=i*2;if(n===null&&(t.boundingBox||t.computeBoundingBox(),Ki.set(t.boundingBox.min,t.boundingBox.max,r),n=Ki),E(u,o)){let p=e.geometry,f=p.index,a=p.attributes.position,h=t.index,g=t.attributes.position,T=O(i,l),d=H(u,o);if(Ft.copy(r).invert(),t.boundsTree)return W(i,s,fr),fr.matrix.copy(Ft),fr.needsUpdate=!0,t.boundsTree.shapecast({intersectsBounds:x=>fr.intersectsBox(x),intersectsTriangle:x=>{x.a.applyMatrix4(r),x.b.applyMatrix4(r),x.c.applyMatrix4(r),x.needsUpdate=!0;for(let v=T*3,y=(d+T)*3;v<y;v+=3)if(q(st,v,f,a),st.needsUpdate=!0,x.intersectsTriangle(st))return!0;return!1}});{let b=Me(t);for(let x=T*3,v=(d+T)*3;x<v;x+=3){q(nt,x,f,a),nt.a.applyMatrix4(Ft),nt.b.applyMatrix4(Ft),nt.c.applyMatrix4(Ft),nt.needsUpdate=!0;for(let y=0,S=b*3;y<S;y+=3)if(q(st,y,h,g),st.needsUpdate=!0,nt.intersectsTriangle(st))return!0}}}else{let p=k(i),f=z(i,l);return W(p,s,ur),!!(n.intersectsBox(ur)&&vo(p,e,t,r,n)||(W(f,s,ur),n.intersectsBox(ur)&&vo(f,e,t,r,n)))}}var pr=new V,yo=new j,Ct=new j,Gs=new P,ks=new P,zs=new P,Us=new P;function Ji(i,e,t,r={},n={},s=0,o=1/0){e.boundingBox||e.computeBoundingBox(),yo.set(e.boundingBox.min,e.boundingBox.max,t),yo.needsUpdate=!0;let l=i.geometry,u=l.attributes.position,m=l.index,p=e.attributes.position,f=e.index,a=oe.getPrimitive(),h=oe.getPrimitive(),g=Gs,T=ks,d=null,b=null;n&&(d=zs,b=Us);let x=1/0,v=null,y=null;return pr.copy(t).invert(),Ct.matrix.copy(pr),i.shapecast({boundsTraverseOrder:S=>yo.distanceToBox(S),intersectsBounds:(S,w,_)=>_<x&&_<o?(w&&(Ct.min.copy(S.min),Ct.max.copy(S.max),Ct.needsUpdate=!0),!0):!1,intersectsRange:(S,w)=>{if(e.boundsTree)return e.boundsTree.shapecast({boundsTraverseOrder:I=>Ct.distanceToBox(I),intersectsBounds:(I,F,A)=>A<x&&A<o,intersectsRange:(I,F)=>{for(let A=I,C=I+F;A<C;A++){q(h,3*A,f,p),h.a.applyMatrix4(t),h.b.applyMatrix4(t),h.c.applyMatrix4(t),h.needsUpdate=!0;for(let R=S,M=S+w;R<M;R++){q(a,3*R,m,u),a.needsUpdate=!0;let B=a.distanceToTriangle(h,g,d);if(B<x&&(T.copy(g),b&&b.copy(d),x=B,v=R,y=A),B<s)return!0}}}});{let _=Me(e);for(let I=0,F=_;I<F;I++){q(h,3*I,f,p),h.a.applyMatrix4(t),h.b.applyMatrix4(t),h.c.applyMatrix4(t),h.needsUpdate=!0;for(let A=S,C=S+w;A<C;A++){q(a,3*A,m,u),a.needsUpdate=!0;let R=a.distanceToTriangle(h,g,d);if(R<x&&(T.copy(g),b&&b.copy(d),x=R,v=A,y=I),R<s)return!0}}}}}),oe.releasePrimitive(a),oe.releasePrimitive(h),x===1/0?null:(r.point?r.point.copy(T):r.point=T.clone(),r.distance=x,r.faceIndex=v,n&&(n.point?n.point.copy(b):n.point=b.clone(),n.point.applyMatrix4(pr),T.applyMatrix4(pr),n.distance=T.sub(n.point).length(),n.faceIndex=y),r)}function en(i,e=null){e&&Array.isArray(e)&&(e=new Set(e));let t=i.geometry,r=t.index?t.index.array:null,n=t.attributes.position,s,o,l,u,m=0,p=i._roots;for(let a=0,h=p.length;a<h;a++)s=p[a],o=new Uint32Array(s),l=new Uint16Array(s),u=new Float32Array(s),f(0,m),m+=s.byteLength;function f(a,h,g=!1){let T=a*2;if(E(T,l)){let d=O(a,o),b=H(T,l),x=1/0,v=1/0,y=1/0,S=-1/0,w=-1/0,_=-1/0;for(let I=d,F=d+b;I<F;I++){let A=3*i.resolveTriangleIndex(I);for(let C=0;C<3;C++){let R=A+C;R=r?r[R]:R;let M=n.getX(R),B=n.getY(R),D=n.getZ(R);M<x&&(x=M),M>S&&(S=M),B<v&&(v=B),B>w&&(w=B),D<y&&(y=D),D>_&&(_=D)}}return u[a+0]!==x||u[a+1]!==v||u[a+2]!==y||u[a+3]!==S||u[a+4]!==w||u[a+5]!==_?(u[a+0]=x,u[a+1]=v,u[a+2]=y,u[a+3]=S,u[a+4]=w,u[a+5]=_,!0):!1}else{let d=k(a),b=z(a,o),x=g,v=!1,y=!1;if(e){if(!x){let A=d/8+h/32,C=b/8+h/32;v=e.has(A),y=e.has(C),x=!v&&!y}}else v=!0,y=!0;let S=x||v,w=x||y,_=!1;S&&(_=f(d,h,x));let I=!1;w&&(I=f(b,h,x));let F=_||I;if(F)for(let A=0;A<3;A++){let C=d+A,R=b+A,M=u[C],B=u[C+3],D=u[R],Y=u[R+3];u[a+A]=M<D?M:D,u[a+A+3]=B>Y?B:Y}return F}}}function tn(i,e,t,r,n,s,o){N.setBuffer(i._roots[e]),To(0,i,t,r,n,s,o),N.clearBuffer()}function To(i,e,t,r,n,s,o){let{float32Array:l,uint16Array:u,uint32Array:m}=N,p=i*2;if(E(p,u)){let a=O(i,m),h=H(p,u);Yi(e,t,r,a,h,n,s,o)}else{let a=k(i);me(a,l,r,s,o)&&To(a,e,t,r,n,s,o);let h=z(i,m);me(h,l,r,s,o)&&To(h,e,t,r,n,s,o)}}var Hs=["x","y","z"];function rn(i,e,t,r,n,s){N.setBuffer(i._roots[e]);let o=bo(0,i,t,r,n,s);return N.clearBuffer(),o}function bo(i,e,t,r,n,s){let{float32Array:o,uint16Array:l,uint32Array:u}=N,m=i*2;if(E(m,l)){let f=O(i,u),a=H(m,l);return Xi(e,t,r,f,a,n,s)}else{let f=Ae(i,u),a=Hs[f],g=r.direction[a]>=0,T,d;g?(T=k(i),d=z(i,u)):(T=z(i,u),d=k(i));let x=me(T,o,r,n,s)?bo(T,e,t,r,n,s):null;if(x){let S=x.point[a];if(g?S<=o[d+f]:S>=o[d+f+3])return x}let y=me(d,o,r,n,s)?bo(d,e,t,r,n,s):null;return x&&y?x.distance<=y.distance?x:y:x||y||null}}var mr=new ee,at=new J,ct=new J,Mt=new V,on=new j,dr=new j;function nn(i,e,t,r){N.setBuffer(i._roots[e]);let n=So(0,i,t,r);return N.clearBuffer(),n}function So(i,e,t,r,n=null){let{float32Array:s,uint16Array:o,uint32Array:l}=N,u=i*2;if(n===null&&(t.boundingBox||t.computeBoundingBox(),on.set(t.boundingBox.min,t.boundingBox.max,r),n=on),E(u,o)){let p=e.geometry,f=p.index,a=p.attributes.position,h=t.index,g=t.attributes.position,T=O(i,l),d=H(u,o);if(Mt.copy(r).invert(),t.boundsTree)return W(i,s,dr),dr.matrix.copy(Mt),dr.needsUpdate=!0,t.boundsTree.shapecast({intersectsBounds:x=>dr.intersectsBox(x),intersectsTriangle:x=>{x.a.applyMatrix4(r),x.b.applyMatrix4(r),x.c.applyMatrix4(r),x.needsUpdate=!0;for(let v=T,y=d+T;v<y;v++)if(q(ct,3*e.resolveTriangleIndex(v),f,a),ct.needsUpdate=!0,x.intersectsTriangle(ct))return!0;return!1}});{let b=Me(t);for(let x=T,v=d+T;x<v;x++){let y=e.resolveTriangleIndex(x);q(at,3*y,f,a),at.a.applyMatrix4(Mt),at.b.applyMatrix4(Mt),at.c.applyMatrix4(Mt),at.needsUpdate=!0;for(let S=0,w=b*3;S<w;S+=3)if(q(ct,S,h,g),ct.needsUpdate=!0,at.intersectsTriangle(ct))return!0}}}else{let p=k(i),f=z(i,l);return W(p,s,mr),!!(n.intersectsBox(mr)&&So(p,e,t,r,n)||(W(f,s,mr),n.intersectsBox(mr)&&So(f,e,t,r,n)))}}var hr=new V,_o=new j,Pt=new j,Vs=new P,Ws=new P,qs=new P,Ys=new P;function sn(i,e,t,r={},n={},s=0,o=1/0){e.boundingBox||e.computeBoundingBox(),_o.set(e.boundingBox.min,e.boundingBox.max,t),_o.needsUpdate=!0;let l=i.geometry,u=l.attributes.position,m=l.index,p=e.attributes.position,f=e.index,a=oe.getPrimitive(),h=oe.getPrimitive(),g=Vs,T=Ws,d=null,b=null;n&&(d=qs,b=Ys);let x=1/0,v=null,y=null;return hr.copy(t).invert(),Pt.matrix.copy(hr),i.shapecast({boundsTraverseOrder:S=>_o.distanceToBox(S),intersectsBounds:(S,w,_)=>_<x&&_<o?(w&&(Pt.min.copy(S.min),Pt.max.copy(S.max),Pt.needsUpdate=!0),!0):!1,intersectsRange:(S,w)=>{if(e.boundsTree){let _=e.boundsTree;return _.shapecast({boundsTraverseOrder:I=>Pt.distanceToBox(I),intersectsBounds:(I,F,A)=>A<x&&A<o,intersectsRange:(I,F)=>{for(let A=I,C=I+F;A<C;A++){let R=_.resolveTriangleIndex(A);q(h,3*R,f,p),h.a.applyMatrix4(t),h.b.applyMatrix4(t),h.c.applyMatrix4(t),h.needsUpdate=!0;for(let M=S,B=S+w;M<B;M++){let D=i.resolveTriangleIndex(M);q(a,3*D,m,u),a.needsUpdate=!0;let Y=a.distanceToTriangle(h,g,d);if(Y<x&&(T.copy(g),b&&b.copy(d),x=Y,v=M,y=A),Y<s)return!0}}}})}else{let _=Me(e);for(let I=0,F=_;I<F;I++){q(h,3*I,f,p),h.a.applyMatrix4(t),h.b.applyMatrix4(t),h.c.applyMatrix4(t),h.needsUpdate=!0;for(let A=S,C=S+w;A<C;A++){let R=i.resolveTriangleIndex(A);q(a,3*R,m,u),a.needsUpdate=!0;let M=a.distanceToTriangle(h,g,d);if(M<x&&(T.copy(g),b&&b.copy(d),x=M,v=A,y=I),M<s)return!0}}}}}),oe.releasePrimitive(a),oe.releasePrimitive(h),x===1/0?null:(r.point?r.point.copy(T):r.point=T.clone(),r.distance=x,r.faceIndex=v,n&&(n.point?n.point.copy(b):n.point=b.clone(),n.point.applyMatrix4(hr),T.applyMatrix4(hr),n.distance=T.sub(n.point).length(),n.faceIndex=y),r)}function wo(i,e,t){return i===null?null:(i.point.applyMatrix4(e.matrixWorld),i.distance=i.point.distanceTo(t.ray.origin),i.object=e,i)}var xr=new j,gr=new fi,an=new P,cn=new V,ln=new P,Ao=["getX","getY","getZ"],vr=class i extends nr{static serialize(e,t={}){t={cloneBuffers:!0,...t};let r=e.geometry,n=e._roots,s=e._indirectBuffer,o=r.getIndex(),l={version:1,roots:null,index:null,indirectBuffer:null};return t.cloneBuffers?(l.roots=n.map(u=>u.slice()),l.index=o?o.array.slice():null,l.indirectBuffer=s?s.slice():null):(l.roots=n,l.index=o?o.array:null,l.indirectBuffer=s),l}static deserialize(e,t,r={}){r={setIndex:!0,indirect:!!e.indirectBuffer,...r};let{index:n,roots:s,indirectBuffer:o}=e;e.version||(console.warn("MeshBVH.deserialize: Serialization format has been changed and will be fixed up. It is recommended to regenerate any stored serialized data."),u(s));let l=new i(t,{...r,[Tt]:!0});if(l._roots=s,l._indirectBuffer=o||null,r.setIndex){let m=t.getIndex();if(m===null){let p=new K(e.index,1,!1);t.setIndex(p)}else m.array!==n&&(m.array.set(n),m.needsUpdate=!0)}return l;function u(m){for(let p=0;p<m.length;p++){let f=m[p],a=new Uint32Array(f),h=new Uint16Array(f);for(let g=0,T=f.byteLength/32;g<T;g++){let d=8*g,b=2*d;E(b,h)||(a[d+6]=a[d+6]/8-g)}}}}get primitiveStride(){return 3}get resolveTriangleIndex(){return this.resolvePrimitiveIndex}constructor(e,t={}){t.maxLeafTris&&(console.warn('MeshBVH: "maxLeafTris" option has been deprecated. Use "targetLeafSize", instead.'),t={...t,targetLeafSize:t.maxLeafTris}),super(e,t)}shiftTriangleOffsets(e){return super.shiftPrimitiveOffsets(e)}writePrimitiveBounds(e,t,r){let n=this.geometry,s=this._indirectBuffer,o=n.attributes.position,l=n.index?n.index.array:null,m=(s?s[e]:e)*3,p=m+0,f=m+1,a=m+2;l&&(p=l[p],f=l[f],a=l[a]);for(let h=0;h<3;h++){let g=o[Ao[h]](p),T=o[Ao[h]](f),d=o[Ao[h]](a),b=g;T<b&&(b=T),d<b&&(b=d);let x=g;T>x&&(x=T),d>x&&(x=d),t[r+h]=b,t[r+h+3]=x}return t}computePrimitiveBounds(e,t,r){let n=this.geometry,s=this._indirectBuffer,o=n.attributes.position,l=n.index?n.index.array:null,u=o.normalized;if(e<0||t+e-r.offset>r.length/6)throw new Error("MeshBVH: compute triangle bounds range is invalid.");let m=o.array,p=o.offset||0,f=3;o.isInterleavedBufferAttribute&&(f=o.data.stride);let a=["getX","getY","getZ"],h=r.offset;for(let g=e,T=e+t;g<T;g++){let b=(s?s[g]:g)*3,x=(g-h)*6,v=b+0,y=b+1,S=b+2;l&&(v=l[v],y=l[y],S=l[S]),u||(v=v*f+p,y=y*f+p,S=S*f+p);for(let w=0;w<3;w++){let _,I,F;u?(_=o[a[w]](v),I=o[a[w]](y),F=o[a[w]](S)):(_=m[v+w],I=m[y+w],F=m[S+w]);let A=_;I<A&&(A=I),F<A&&(A=F);let C=_;I>C&&(C=I),F>C&&(C=F);let R=(C-A)/2,M=w*2;r[x+M+0]=A+R,r[x+M+1]=R+(Math.abs(A)+R)*Qe}}return r}raycastObject3D(e,t,r=[]){let{material:n}=e;if(n===void 0)return;cn.copy(e.matrixWorld).invert(),gr.copy(t.ray).applyMatrix4(cn),ln.setFromMatrixScale(e.matrixWorld),an.copy(gr.direction).multiply(ln);let s=an.length(),o=t.near/s,l=t.far/s;if(t.firstHitOnly===!0){let u=this.raycastFirst(gr,n,o,l);u=wo(u,e,t),u&&r.push(u)}else{let u=this.raycast(gr,n,o,l);for(let m=0,p=u.length;m<p;m++){let f=wo(u[m],e,t);f&&r.push(f)}}return r}refit(e=null){return(this.indirect?en:qi)(this,e)}raycast(e,t=vt,r=0,n=1/0){let s=this._roots,o=[],l=this.indirect?tn:ji;for(let u=0,m=s.length;u<m;u++)l(this,u,t,e,o,r,n);return o}raycastFirst(e,t=vt,r=0,n=1/0){let s=this._roots,o=null,l=this.indirect?rn:Qi;for(let u=0,m=s.length;u<m;u++){let p=l(this,u,t,e,r,n);p!=null&&(o==null||p.distance<o.distance)&&(o=p)}return o}intersectsGeometry(e,t){let r=!1,n=this._roots,s=this.indirect?nn:Zi;for(let o=0,l=n.length;o<l&&(r=s(this,o,e,t),!r);o++);return r}shapecast(e){let t=oe.getPrimitive(),r=super.shapecast({...e,intersectsPrimitive:e.intersectsTriangle,scratchPrimitive:t,iterate:this.indirect?$i:Wi});return oe.releasePrimitive(t),r}bvhcast(e,t,r){let{intersectsRanges:n,intersectsTriangles:s}=r,o=oe.getPrimitive(),l=this.geometry.index,u=this.geometry.attributes.position,m=this.indirect?g=>{let T=this.resolveTriangleIndex(g);q(o,T*3,l,u)}:g=>{q(o,g*3,l,u)},p=oe.getPrimitive(),f=e.geometry.index,a=e.geometry.attributes.position,h=e.indirect?g=>{let T=e.resolveTriangleIndex(g);q(p,T*3,f,a)}:g=>{q(p,g*3,f,a)};if(s){if(!(e instanceof i))throw new Error('MeshBVH: "intersectsTriangles" callback can only be used with another MeshBVH.');let g=(T,d,b,x,v,y,S,w)=>{for(let _=b,I=b+x;_<I;_++){h(_),p.a.applyMatrix4(t),p.b.applyMatrix4(t),p.c.applyMatrix4(t),p.needsUpdate=!0;for(let F=T,A=T+d;F<A;F++)if(m(F),o.needsUpdate=!0,s(o,p,F,_,v,y,S,w))return!0}return!1};if(n){let T=n;n=function(d,b,x,v,y,S,w,_){return T(d,b,x,v,y,S,w,_)?!0:g(d,b,x,v,y,S,w,_)}}else n=g}return super.bvhcast(e,t,{intersectsRanges:n})}intersectsBox(e,t){return xr.set(e.min,e.max,t),xr.needsUpdate=!0,this.shapecast({intersectsBounds:r=>xr.intersectsBox(r),intersectsTriangle:r=>xr.intersectsTriangle(r)})}intersectsSphere(e){return this.shapecast({intersectsBounds:t=>e.intersectsBox(t),intersectsTriangle:t=>t.intersectsSphere(e)})}closestPointToGeometry(e,t,r={},n={},s=0,o=1/0){return(this.indirect?sn:Ji)(this,e,t,r,n,s,o)}closestPointToPoint(e,t={},r=0,n=1/0){return Ni(this,e,t,r,n)}};function Xs(i){switch(i){case 1:return"R";case 2:return"RG";case 3:return"RGBA";case 4:return"RGBA"}throw new Error}function $s(i){switch(i){case 1:return De;case 2:return Xt;case 3:return L;case 4:return L}}function un(i){switch(i){case 1:return mi;case 2:return $t;case 3:return Yt;case 4:return Yt}}var yr=class extends ${constructor(){super(),this.minFilter=U,this.magFilter=U,this.generateMipmaps=!1,this.overrideItemSize=null,this._forcedType=null}updateFrom(e){let t=this.overrideItemSize,r=e.itemSize,n=e.count;if(t!==null){if(r*n%t!==0)throw new Error("VertexAttributeTexture: overrideItemSize must divide evenly into buffer length.");e.itemSize=t,e.count=n*r/t}let s=e.itemSize,o=e.count,l=e.normalized,u=e.array.constructor,m=u.BYTES_PER_ELEMENT,p=this._forcedType,f=s;if(p===null)switch(u){case Float32Array:p=G;break;case Uint8Array:case Uint16Array:case Uint32Array:p=Ee;break;case Int8Array:case Int16Array:case Int32Array:p=Ut;break}let a,h,g,T,d=Xs(s);switch(p){case G:g=1,h=$s(s),l&&m===1?(T=u,d+="8",u===Uint8Array?a=yt:(a=Jr,d+="_SNORM")):(T=Float32Array,d+="32F",a=G);break;case Ut:d+=m*8+"I",g=l?Math.pow(2,u.BYTES_PER_ELEMENT*8-1):1,h=un(s),m===1?(T=Int8Array,a=Jr):m===2?(T=Int16Array,a=hi):(T=Int32Array,a=Ut);break;case Ee:d+=m*8+"UI",g=l?Math.pow(2,u.BYTES_PER_ELEMENT*8-1):1,h=un(s),m===1?(T=Uint8Array,a=yt):m===2?(T=Uint16Array,a=yi):(T=Uint32Array,a=Ee);break}f===3&&(h===L||h===Yt)&&(f=4);let b=Math.ceil(Math.sqrt(o))||1,x=f*b*b,v=new T(x),y=e.normalized;e.normalized=!1;for(let S=0;S<o;S++){let w=f*S;v[w]=e.getX(S)/g,s>=2&&(v[w+1]=e.getY(S)/g),s>=3&&(v[w+2]=e.getZ(S)/g,f===4&&(v[w+3]=1)),s>=4&&(v[w+3]=e.getW(S)/g)}e.normalized=y,this.internalFormat=d,this.format=h,this.type=a,this.image.width=b,this.image.height=b,this.image.data=v,this.needsUpdate=!0,this.dispose(),e.itemSize=r,e.count=n}},lt=class extends yr{constructor(){super(),this._forcedType=Ee}};var ut=class extends yr{constructor(){super(),this._forcedType=G}};var Tr=class{constructor(){this.index=new lt,this.position=new ut,this.bvhBounds=new $,this.bvhContents=new $,this._cachedIndexAttr=null,this.index.overrideItemSize=3}updateFrom(e){let{geometry:t}=e;if(Qs(e,this.bvhBounds,this.bvhContents),this.position.updateFrom(t.attributes.position),e.indirect){let r=e._indirectBuffer;if(this._cachedIndexAttr===null||this._cachedIndexAttr.count!==r.length)if(t.index)this._cachedIndexAttr=t.index.clone();else{let n=fo(wt(t));this._cachedIndexAttr=new K(n,1,!1)}js(t,r,this._cachedIndexAttr),this.index.updateFrom(this._cachedIndexAttr)}else this.index.updateFrom(t.index)}dispose(){let{index:e,position:t,bvhBounds:r,bvhContents:n}=this;e&&e.dispose(),t&&t.dispose(),r&&r.dispose(),n&&n.dispose()}};function js(i,e,t){let r=t.array,n=i.index?i.index.array:null;for(let s=0,o=e.length;s<o;s++){let l=3*s,u=3*e[s];for(let m=0;m<3;m++)r[l+m]=n?n[u+m]:u+m}}function Qs(i,e,t){let r=i._roots;if(r.length!==1)throw new Error("MeshBVHUniformStruct: Multi-root BVHs not supported.");let n=r[0],s=new Uint16Array(n),o=new Uint32Array(n),l=new Float32Array(n),u=n.byteLength/32,m=2*Math.ceil(Math.sqrt(u/2)),p=new Float32Array(4*m*m),f=Math.ceil(Math.sqrt(u)),a=new Uint32Array(2*f*f);for(let h=0;h<u;h++){let g=h*32/4,T=g*2,d=g;for(let b=0;b<3;b++)p[8*h+0+b]=l[d+0+b],p[8*h+4+b]=l[d+3+b];if(E(T,s)){let b=H(T,s),x=O(g,o),v=-65536|b;a[h*2+0]=v,a[h*2+1]=x}else{let b=o[g+6],x=Ae(g,o);a[h*2+0]=x,a[h*2+1]=b}}e.image.data=p,e.image.width=m,e.image.height=m,e.format=L,e.type=G,e.internalFormat="RGBA32F",e.minFilter=U,e.magFilter=U,e.generateMipmaps=!1,e.needsUpdate=!0,e.dispose(),t.image.data=a,t.image.width=f,t.image.height=f,t.format=$t,t.type=Ee,t.internalFormat="RG32UI",t.minFilter=U,t.magFilter=U,t.generateMipmaps=!1,t.needsUpdate=!0,t.dispose()}var Ge={};Zo(Ge,{bvh_distance_functions:()=>fn,bvh_ray_functions:()=>Io,bvh_struct_definitions:()=>pn,common_functions:()=>Ro});var Ro=`

// A stack of uint32 indices can can store the indices for
// a perfectly balanced tree with a depth up to 31. Lower stack
// depth gets higher performance.
//
// However not all trees are balanced. Best value to set this to
// is the trees max depth.
#ifndef BVH_STACK_DEPTH
#define BVH_STACK_DEPTH 60
#endif

#ifndef INFINITY
#define INFINITY 1e20
#endif

// Utilities
uvec4 uTexelFetch1D( usampler2D tex, uint index ) {

	uint width = uint( textureSize( tex, 0 ).x );
	uvec2 uv;
	uv.x = index % width;
	uv.y = index / width;

	return texelFetch( tex, ivec2( uv ), 0 );

}

ivec4 iTexelFetch1D( isampler2D tex, uint index ) {

	uint width = uint( textureSize( tex, 0 ).x );
	uvec2 uv;
	uv.x = index % width;
	uv.y = index / width;

	return texelFetch( tex, ivec2( uv ), 0 );

}

vec4 texelFetch1D( sampler2D tex, uint index ) {

	uint width = uint( textureSize( tex, 0 ).x );
	uvec2 uv;
	uv.x = index % width;
	uv.y = index / width;

	return texelFetch( tex, ivec2( uv ), 0 );

}

vec4 textureSampleBarycoord( sampler2D tex, vec3 barycoord, uvec3 faceIndices ) {

	return
		barycoord.x * texelFetch1D( tex, faceIndices.x ) +
		barycoord.y * texelFetch1D( tex, faceIndices.y ) +
		barycoord.z * texelFetch1D( tex, faceIndices.z );

}

void ndcToCameraRay(
	vec2 coord, mat4 cameraWorld, mat4 invProjectionMatrix,
	out vec3 rayOrigin, out vec3 rayDirection
) {

	// get camera look direction and near plane for camera clipping
	vec4 lookDirection = cameraWorld * vec4( 0.0, 0.0, - 1.0, 0.0 );
	vec4 nearVector = invProjectionMatrix * vec4( 0.0, 0.0, - 1.0, 1.0 );
	float near = abs( nearVector.z / nearVector.w );

	// get the camera direction and position from camera matrices
	vec4 origin = cameraWorld * vec4( 0.0, 0.0, 0.0, 1.0 );
	vec4 direction = invProjectionMatrix * vec4( coord, 0.5, 1.0 );
	direction /= direction.w;
	direction = cameraWorld * direction - origin;

	// slide the origin along the ray until it sits at the near clip plane position
	origin.xyz += direction.xyz * near / dot( direction, lookDirection );

	rayOrigin = origin.xyz;
	rayDirection = direction.xyz;

}
`;var fn=`

float dot2( vec3 v ) {

	return dot( v, v );

}

// implementation from https://www.shadertoy.com/view/ttfGWl, though method 2 has been removed
// and is now available at this fork: https://www.shadertoy.com/view/WlB3zW
vec3 closestPointToTriangle( vec3 p, vec3 v0, vec3 v1, vec3 v2, out vec3 barycoord ) {

    vec3 v10 = v1 - v0;
    vec3 v21 = v2 - v1;
    vec3 v02 = v0 - v2;

	vec3 p0 = p - v0;
	vec3 p1 = p - v1;
	vec3 p2 = p - v2;

    vec3 nor = cross( v10, v02 );

    // method 2, in barycentric space
    vec3  q = cross( nor, p0 );
    float d = 1.0 / dot2( nor );
    float u = d * dot( q, v02 );
    float v = d * dot( q, v10 );
    float w = 1.0 - u - v;

	if( u < 0.0 ) {

		w = clamp( dot( p2, v02 ) / dot2( v02 ), 0.0, 1.0 );
		u = 0.0;
		v = 1.0 - w;

	} else if( v < 0.0 ) {

		u = clamp( dot( p0, v10 ) / dot2( v10 ), 0.0, 1.0 );
		v = 0.0;
		w = 1.0 - u;

	} else if( w < 0.0 ) {

		v = clamp( dot( p1, v21 ) / dot2( v21 ), 0.0, 1.0 );
		w = 0.0;
		u = 1.0 - v;

	}

	// output the barycoord in v0, v1, v2 weight order
	barycoord = vec3( w, u, v );
    return u * v1 + v * v2 + w * v0;

}

float distanceToTriangles(
	// geometry info and triangle range
	sampler2D positionAttr, usampler2D indexAttr, uint offset, uint count,

	// point and cut off range
	vec3 point, float closestDistanceSquared,

	// outputs
	inout uvec4 faceIndices, inout vec3 faceNormal, inout vec3 barycoord, inout float side, inout vec3 outPoint
) {

	bool found = false;
	vec3 localBarycoord;
	for ( uint i = offset, l = offset + count; i < l; i ++ ) {

		uvec3 indices = uTexelFetch1D( indexAttr, i ).xyz;
		vec3 a = texelFetch1D( positionAttr, indices.x ).rgb;
		vec3 b = texelFetch1D( positionAttr, indices.y ).rgb;
		vec3 c = texelFetch1D( positionAttr, indices.z ).rgb;

		// get the closest point and barycoord
		vec3 closestPoint = closestPointToTriangle( point, a, b, c, localBarycoord );
		vec3 delta = point - closestPoint;
		float sqDist = dot2( delta );
		if ( sqDist < closestDistanceSquared ) {

			// set the output results
			closestDistanceSquared = sqDist;
			faceIndices = uvec4( indices.xyz, i );
			faceNormal = normalize( cross( a - b, b - c ) );
			barycoord = localBarycoord;
			outPoint = closestPoint;
			side = sign( dot( faceNormal, delta ) );

		}

	}

	return closestDistanceSquared;

}

float distanceSqToBounds( vec3 point, vec3 boundsMin, vec3 boundsMax ) {

	vec3 clampedPoint = clamp( point, boundsMin, boundsMax );
	vec3 delta = point - clampedPoint;
	return dot( delta, delta );

}

float distanceSqToBVHNodeBoundsPoint( vec3 point, sampler2D bvhBounds, uint currNodeIndex ) {

	uint cni2 = currNodeIndex * 2u;
	vec3 boundsMin = texelFetch1D( bvhBounds, cni2 ).xyz;
	vec3 boundsMax = texelFetch1D( bvhBounds, cni2 + 1u ).xyz;
	return distanceSqToBounds( point, boundsMin, boundsMax );

}

// use a macro to hide the fact that we need to expand the struct into separate fields
#define	bvhClosestPointToPoint(		bvh,		point, maxDistance, faceIndices, faceNormal, barycoord, side, outPoint	)	_bvhClosestPointToPoint(		bvh.position, bvh.index, bvh.bvhBounds, bvh.bvhContents,		point, maxDistance, faceIndices, faceNormal, barycoord, side, outPoint	)

float _bvhClosestPointToPoint(
	// bvh info
	sampler2D bvh_position, usampler2D bvh_index, sampler2D bvh_bvhBounds, usampler2D bvh_bvhContents,

	// point to check
	vec3 point, float maxDistance,

	// output variables
	inout uvec4 faceIndices, inout vec3 faceNormal, inout vec3 barycoord,
	inout float side, inout vec3 outPoint
 ) {

	// stack needs to be twice as long as the deepest tree we expect because
	// we push both the left and right child onto the stack every traversal
	int pointer = 0;
	uint stack[ BVH_STACK_DEPTH ];
	stack[ 0 ] = 0u;

	float closestDistanceSquared = maxDistance * maxDistance;
	bool found = false;
	while ( pointer > - 1 && pointer < BVH_STACK_DEPTH ) {

		uint currNodeIndex = stack[ pointer ];
		pointer --;

		// check if we intersect the current bounds
		float boundsHitDistance = distanceSqToBVHNodeBoundsPoint( point, bvh_bvhBounds, currNodeIndex );
		if ( boundsHitDistance > closestDistanceSquared ) {

			continue;

		}

		uvec2 boundsInfo = uTexelFetch1D( bvh_bvhContents, currNodeIndex ).xy;
		bool isLeaf = bool( boundsInfo.x & 0xffff0000u );
		if ( isLeaf ) {

			uint count = boundsInfo.x & 0x0000ffffu;
			uint offset = boundsInfo.y;
			closestDistanceSquared = distanceToTriangles(
				bvh_position, bvh_index, offset, count, point, closestDistanceSquared,

				// outputs
				faceIndices, faceNormal, barycoord, side, outPoint
			);

		} else {

			uint leftIndex = currNodeIndex + 1u;
			uint splitAxis = boundsInfo.x & 0x0000ffffu;
			uint rightIndex = currNodeIndex + boundsInfo.y;
			bool leftToRight = distanceSqToBVHNodeBoundsPoint( point, bvh_bvhBounds, leftIndex ) < distanceSqToBVHNodeBoundsPoint( point, bvh_bvhBounds, rightIndex );//rayDirection[ splitAxis ] >= 0.0;
			uint c1 = leftToRight ? leftIndex : rightIndex;
			uint c2 = leftToRight ? rightIndex : leftIndex;

			// set c2 in the stack so we traverse it later. We need to keep track of a pointer in
			// the stack while we traverse. The second pointer added is the one that will be
			// traversed first
			pointer ++;
			stack[ pointer ] = c2;
			pointer ++;
			stack[ pointer ] = c1;

		}

	}

	return sqrt( closestDistanceSquared );

}
`;var Io=`

#ifndef TRI_INTERSECT_EPSILON
#define TRI_INTERSECT_EPSILON 1e-5
#endif

// Raycasting
bool intersectsBounds( vec3 rayOrigin, vec3 rayDirection, vec3 boundsMin, vec3 boundsMax, out float dist ) {

	// https://www.reddit.com/r/opengl/comments/8ntzz5/fast_glsl_ray_box_intersection/
	// https://tavianator.com/2011/ray_box.html
	vec3 invDir = 1.0 / rayDirection;

	// find intersection distances for each plane
	vec3 tMinPlane = invDir * ( boundsMin - rayOrigin );
	vec3 tMaxPlane = invDir * ( boundsMax - rayOrigin );

	// get the min and max distances from each intersection
	vec3 tMinHit = min( tMaxPlane, tMinPlane );
	vec3 tMaxHit = max( tMaxPlane, tMinPlane );

	// get the furthest hit distance
	vec2 t = max( tMinHit.xx, tMinHit.yz );
	float t0 = max( t.x, t.y );

	// get the minimum hit distance
	t = min( tMaxHit.xx, tMaxHit.yz );
	float t1 = min( t.x, t.y );

	// set distance to 0.0 if the ray starts inside the box
	dist = max( t0, 0.0 );

	return t1 >= dist;

}

bool intersectsTriangle(
	vec3 rayOrigin, vec3 rayDirection, vec3 a, vec3 b, vec3 c,
	out vec3 barycoord, out vec3 norm, out float dist, out float side
) {

	// https://stackoverflow.com/questions/42740765/intersection-between-line-and-triangle-in-3d
	vec3 edge1 = b - a;
	vec3 edge2 = c - a;
	norm = cross( edge1, edge2 );

	float det = - dot( rayDirection, norm );
	float invdet = 1.0 / det;

	vec3 AO = rayOrigin - a;
	vec3 DAO = cross( AO, rayDirection );

	vec4 uvt;
	uvt.x = dot( edge2, DAO ) * invdet;
	uvt.y = - dot( edge1, DAO ) * invdet;
	uvt.z = dot( AO, norm ) * invdet;
	uvt.w = 1.0 - uvt.x - uvt.y;

	// set the hit information
	barycoord = uvt.wxy; // arranged in A, B, C order
	dist = uvt.z;
	side = sign( det );
	norm = side * normalize( norm );

	// add an epsilon to avoid misses between triangles
	uvt += vec4( TRI_INTERSECT_EPSILON );

	return all( greaterThanEqual( uvt, vec4( 0.0 ) ) );

}

bool intersectTriangles(
	// geometry info and triangle range
	sampler2D positionAttr, usampler2D indexAttr, uint offset, uint count,

	// ray
	vec3 rayOrigin, vec3 rayDirection,

	// outputs
	inout float minDistance, inout uvec4 faceIndices, inout vec3 faceNormal, inout vec3 barycoord,
	inout float side, inout float dist
) {

	bool found = false;
	vec3 localBarycoord, localNormal;
	float localDist, localSide;
	for ( uint i = offset, l = offset + count; i < l; i ++ ) {

		uvec3 indices = uTexelFetch1D( indexAttr, i ).xyz;
		vec3 a = texelFetch1D( positionAttr, indices.x ).rgb;
		vec3 b = texelFetch1D( positionAttr, indices.y ).rgb;
		vec3 c = texelFetch1D( positionAttr, indices.z ).rgb;

		if (
			intersectsTriangle( rayOrigin, rayDirection, a, b, c, localBarycoord, localNormal, localDist, localSide )
			&& localDist < minDistance
		) {

			found = true;
			minDistance = localDist;

			faceIndices = uvec4( indices.xyz, i );
			faceNormal = localNormal;

			side = localSide;
			barycoord = localBarycoord;
			dist = localDist;

		}

	}

	return found;

}

bool intersectsBVHNodeBounds( vec3 rayOrigin, vec3 rayDirection, sampler2D bvhBounds, uint currNodeIndex, out float dist ) {

	uint cni2 = currNodeIndex * 2u;
	vec3 boundsMin = texelFetch1D( bvhBounds, cni2 ).xyz;
	vec3 boundsMax = texelFetch1D( bvhBounds, cni2 + 1u ).xyz;
	return intersectsBounds( rayOrigin, rayDirection, boundsMin, boundsMax, dist );

}

// use a macro to hide the fact that we need to expand the struct into separate fields
#define	bvhIntersectFirstHit(		bvh,		rayOrigin, rayDirection, faceIndices, faceNormal, barycoord, side, dist	)	_bvhIntersectFirstHit(		bvh.position, bvh.index, bvh.bvhBounds, bvh.bvhContents,		rayOrigin, rayDirection, faceIndices, faceNormal, barycoord, side, dist	)

bool _bvhIntersectFirstHit(
	// bvh info
	sampler2D bvh_position, usampler2D bvh_index, sampler2D bvh_bvhBounds, usampler2D bvh_bvhContents,

	// ray
	vec3 rayOrigin, vec3 rayDirection,

	// output variables split into separate variables due to output precision
	inout uvec4 faceIndices, inout vec3 faceNormal, inout vec3 barycoord,
	inout float side, inout float dist
) {

	// stack needs to be twice as long as the deepest tree we expect because
	// we push both the left and right child onto the stack every traversal
	int pointer = 0;
	uint stack[ BVH_STACK_DEPTH ];
	stack[ 0 ] = 0u;

	float triangleDistance = INFINITY;
	bool found = false;
	while ( pointer > - 1 && pointer < BVH_STACK_DEPTH ) {

		uint currNodeIndex = stack[ pointer ];
		pointer --;

		// check if we intersect the current bounds
		float boundsHitDistance;
		if (
			! intersectsBVHNodeBounds( rayOrigin, rayDirection, bvh_bvhBounds, currNodeIndex, boundsHitDistance )
			|| boundsHitDistance > triangleDistance
		) {

			continue;

		}

		uvec2 boundsInfo = uTexelFetch1D( bvh_bvhContents, currNodeIndex ).xy;
		bool isLeaf = bool( boundsInfo.x & 0xffff0000u );

		if ( isLeaf ) {

			uint count = boundsInfo.x & 0x0000ffffu;
			uint offset = boundsInfo.y;

			found = intersectTriangles(
				bvh_position, bvh_index, offset, count,
				rayOrigin, rayDirection, triangleDistance,
				faceIndices, faceNormal, barycoord, side, dist
			) || found;

		} else {

			uint leftIndex = currNodeIndex + 1u;
			uint splitAxis = boundsInfo.x & 0x0000ffffu;
			uint rightIndex = currNodeIndex + boundsInfo.y;

			bool leftToRight = rayDirection[ splitAxis ] >= 0.0;
			uint c1 = leftToRight ? leftIndex : rightIndex;
			uint c2 = leftToRight ? rightIndex : leftIndex;

			// set c2 in the stack so we traverse it later. We need to keep track of a pointer in
			// the stack while we traverse. The second pointer added is the one that will be
			// traversed first
			pointer ++;
			stack[ pointer ] = c2;

			pointer ++;
			stack[ pointer ] = c1;

		}

	}

	return found;

}
`;var pn=`
struct BVH {

	usampler2D index;
	sampler2D position;

	sampler2D bvhBounds;
	usampler2D bvhContents;

};
`;var $g=`
	${Ro}
	${Io}
`;function br(i,e,t=0){if(i.isInterleavedBufferAttribute){let r=i.itemSize;for(let n=0,s=i.count;n<s;n++){let o=n+t;e.setX(o,i.getX(n)),r>=2&&e.setY(o,i.getY(n)),r>=3&&e.setZ(o,i.getZ(n)),r>=4&&e.setW(o,i.getW(n))}}else{let r=e.array,n=r.constructor,s=r.BYTES_PER_ELEMENT*i.itemSize*t;new n(r.buffer,s,i.array.length).set(i.array)}}function ke(i,e=null){let t=i.array.constructor,r=i.normalized,n=i.itemSize,s=e===null?i.count:e;return new K(new t(n*s),n,r)}function Pe(i,e){if(!i&&!e)return!0;if(!!i!=!!e)return!1;let t=i.count===e.count,r=i.normalized===e.normalized,n=i.array.constructor===e.array.constructor,s=i.itemSize===e.itemSize;return!(!t||!r||!n||!s)}function Ks(i){let e=i[0].index!==null,t=new Set(Object.keys(i[0].attributes));if(!i[0].getAttribute("position"))throw new Error("StaticGeometryGenerator: position attribute is required.");for(let r=0;r<i.length;++r){let n=i[r],s=0;if(e!==(n.index!==null))throw new Error("StaticGeometryGenerator: All geometries must have compatible attributes; make sure index attribute exists among all geometries, or in none of them.");for(let o in n.attributes){if(!t.has(o))throw new Error('StaticGeometryGenerator: All geometries must have compatible attributes; make sure "'+o+'" attribute exists among all geometries, or in none of them.');s++}if(s!==t.size)throw new Error("StaticGeometryGenerator: All geometries must have the same number of attributes.")}}function Zs(i){let e=0;for(let t=0,r=i.length;t<r;t++)e+=i[t].getIndex().count;return e}function Js(i){let e=0;for(let t=0,r=i.length;t<r;t++)e+=i[t].getAttribute("position").count;return e}function ea(i,e,t){i.index&&i.index.count!==e&&i.setIndex(null);let r=i.attributes;for(let n in r)r[n].count!==t&&i.deleteAttribute(n)}function mn(i,e={},t=new ae){let{useGroups:r=!1,forceUpdate:n=!1,skipAssigningAttributes:s=[],overwriteIndex:o=!0}=e;Ks(i);let l=i[0].index!==null,u=l?Zs(i):-1,m=Js(i);if(ea(t,u,m),r){let f=0;for(let a=0,h=i.length;a<h;a++){let g=i[a],T;l?T=g.getIndex().count:T=g.getAttribute("position").count,t.addGroup(f,T,a),f+=T}}if(l){let f=!1;if(t.index||(t.setIndex(new K(new Uint32Array(u),1,!1)),f=!0),f||o){let a=0,h=0,g=t.getIndex();for(let T=0,d=i.length;T<d;T++){let b=i[T],x=b.getIndex();if(!(!n&&!f&&s[T]))for(let y=0;y<x.count;++y)g.setX(a+y,x.getX(y)+h);a+=x.count,h+=b.getAttribute("position").count}}}let p=Object.keys(i[0].attributes);for(let f=0,a=p.length;f<a;f++){let h=!1,g=p[f];if(!t.getAttribute(g)){let b=i[0].getAttribute(g);t.setAttribute(g,ke(b,m)),h=!0}let T=0,d=t.getAttribute(g);for(let b=0,x=i.length;b<x;b++){let v=i[b],y=!n&&!h&&s[b],S=v.getAttribute(g);if(!y)if(g==="color"&&d.itemSize!==S.itemSize)for(let w=T,_=S.count;w<_;w++)S.setXYZW(w,d.getX(w),d.getY(w),d.getZ(w),1);else br(S,d,T);T+=S.count}}}function dn(i,e,t){let r=i.index,s=i.attributes.position.count,o=r?r.count:s,l=i.groups;l.length===0&&(l=[{count:o,start:0,materialIndex:0}]);let u=i.getAttribute("materialIndex");if(!u||u.count!==s){let p;t.length<=255?p=new Uint8Array(s):p=new Uint16Array(s),u=new K(p,1,!1),i.deleteAttribute("materialIndex"),i.setAttribute("materialIndex",u)}let m=u.array;for(let p=0;p<l.length;p++){let f=l[p],a=f.start,h=f.count,g=Math.min(h,o-a),T=Array.isArray(e)?e[f.materialIndex]:e,d=t.indexOf(T);for(let b=0;b<g;b++){let x=a+b;r&&(x=r.getX(x)),m[x]=d}}}function hn(i,e){if(!i.index){let t=i.attributes.position.count,r=new Array(t);for(let n=0;n<t;n++)r[n]=n;i.setIndex(r)}if(!i.attributes.normal&&e&&e.includes("normal")&&i.computeVertexNormals(),!i.attributes.uv&&e&&e.includes("uv")){let t=i.attributes.position.count;i.setAttribute("uv",new K(new Float32Array(t*2),2,!1))}if(!i.attributes.uv2&&e&&e.includes("uv2")){let t=i.attributes.position.count;i.setAttribute("uv2",new K(new Float32Array(t*2),2,!1))}if(!i.attributes.tangent&&e&&e.includes("tangent"))if(i.attributes.uv&&i.attributes.normal)i.computeTangents();else{let t=i.attributes.position.count;i.setAttribute("tangent",new K(new Float32Array(t*4),4,!1))}if(!i.attributes.color&&e&&e.includes("color")){let t=i.attributes.position.count,r=new Float32Array(t*4);r.fill(1),i.setAttribute("color",new K(r,4))}}function ft(i){let e=0;if(i.byteLength!==0){let t=new Uint8Array(i);for(let r=0;r<i.byteLength;r++){let n=t[r];e=(e<<5)-e+n,e|=0}}return e}function xn(i){let e=i.uuid,t=Object.values(i.attributes);i.index&&(t.push(i.index),e+=`index|${i.index.version}`);let r=Object.keys(t).sort();for(let n of r){let s=t[n];e+=`${n}_${s.version}|`}return e}function gn(i){let e=i.skeleton;return e?(e.boneTexture||e.computeBoneTexture(),`${ft(e.boneTexture.image.data.buffer)}_${e.boneTexture.uuid}`):null}var Sr=class{constructor(e=null){this.matrixWorld=new V,this.geometryHash=null,this.skeletonHash=null,this.primitiveCount=-1,e!==null&&this.updateFrom(e)}updateFrom(e){let t=e.geometry,r=(t.index?t.index.count:t.attributes.position.count)/3;this.matrixWorld.copy(e.matrixWorld),this.geometryHash=xn(t),this.primitiveCount=r,this.skeletonHash=gn(e)}didChange(e){let t=e.geometry,r=(t.index?t.index.count:t.attributes.position.count)/3;return!(this.matrixWorld.equals(e.matrixWorld)&&this.geometryHash===xn(t)&&this.skeletonHash===gn(e)&&this.primitiveCount===r)}};var ze=new P,Ue=new P,He=new P,vn=new we,_r=new P,Fo=new P,yn=new we,Tn=new we,wr=new V,bn=new V;function Sn(i,e,t){let r=i.skeleton,n=i.geometry,s=r.bones,o=r.boneInverses;yn.fromBufferAttribute(n.attributes.skinIndex,e),Tn.fromBufferAttribute(n.attributes.skinWeight,e),wr.elements.fill(0);for(let l=0;l<4;l++){let u=Tn.getComponent(l);if(u!==0){let m=yn.getComponent(l);bn.multiplyMatrices(s[m].matrixWorld,o[m]),ta(wr,bn,u)}}return wr.multiply(i.bindMatrix).premultiply(i.bindMatrixInverse),t.transformDirection(wr),t}function Co(i,e,t,r,n){_r.set(0,0,0);for(let s=0,o=i.length;s<o;s++){let l=e[s],u=i[s];l!==0&&(Fo.fromBufferAttribute(u,r),t?_r.addScaledVector(Fo,l):_r.addScaledVector(Fo.sub(n),l))}n.add(_r)}function ta(i,e,t){let r=i.elements,n=e.elements;for(let s=0,o=n.length;s<o;s++)r[s]+=n[s]*t}function ra(i){let{index:e,attributes:t}=i;if(e)for(let r=0,n=e.count;r<n;r+=3){let s=e.getX(r),o=e.getX(r+2);e.setX(r,o),e.setX(r+2,s)}else for(let r in t){let n=t[r],s=n.itemSize;for(let o=0,l=n.count;o<l;o+=3)for(let u=0;u<s;u++){let m=n.getComponent(o,u),p=n.getComponent(o+2,u);n.setComponent(o,u,p),n.setComponent(o+2,u,m)}}return i}function _n(i,e={},t=new ae){e={applyWorldTransforms:!0,attributes:[],...e};let r=i.geometry,n=e.applyWorldTransforms,s=e.attributes.includes("normal"),o=e.attributes.includes("tangent"),l=r.attributes,u=t.attributes;for(let x in t.attributes)(!e.attributes.includes(x)||!(x in r.attributes))&&t.deleteAttribute(x);!t.index&&r.index&&(t.index=r.index.clone()),u.position||t.setAttribute("position",ke(l.position)),s&&!u.normal&&l.normal&&t.setAttribute("normal",ke(l.normal)),o&&!u.tangent&&l.tangent&&t.setAttribute("tangent",ke(l.tangent)),Pe(r.index,t.index),Pe(l.position,u.position),s&&Pe(l.normal,u.normal),o&&Pe(l.tangent,u.tangent);let m=l.position,p=s?l.normal:null,f=o?l.tangent:null,a=r.morphAttributes.position,h=r.morphAttributes.normal,g=r.morphAttributes.tangent,T=r.morphTargetsRelative,d=i.morphTargetInfluences,b=new ii;b.getNormalMatrix(i.matrixWorld),r.index&&t.index.array.set(r.index.array);for(let x=0,v=l.position.count;x<v;x++)ze.fromBufferAttribute(m,x),p&&Ue.fromBufferAttribute(p,x),f&&(vn.fromBufferAttribute(f,x),He.fromBufferAttribute(f,x)),d&&(a&&Co(a,d,T,x,ze),h&&Co(h,d,T,x,Ue),g&&Co(g,d,T,x,He)),i.isSkinnedMesh&&(i.applyBoneTransform(x,ze),p&&Sn(i,x,Ue),f&&Sn(i,x,He)),n&&ze.applyMatrix4(i.matrixWorld),u.position.setXYZ(x,ze.x,ze.y,ze.z),p&&(n&&Ue.applyNormalMatrix(b),u.normal.setXYZ(x,Ue.x,Ue.y,Ue.z)),f&&(n&&He.transformDirection(i.matrixWorld),u.tangent.setXYZW(x,He.x,He.y,He.z,vn.w));for(let x in e.attributes){let v=e.attributes[x];v==="position"||v==="tangent"||v==="normal"||!(v in l)||(u[v]||t.setAttribute(v,ke(l[v])),Pe(l[v],u[v]),br(l[v],u[v]))}return i.matrixWorld.determinant()<0&&ra(t),t}var Ar=class extends ae{constructor(){super(),this.version=0,this.hash=null,this._diff=new Sr}isCompatible(e,t){let r=e.geometry;for(let n=0;n<t.length;n++){let s=t[n],o=r.attributes[s],l=this.attributes[s];if(o&&!Pe(o,l))return!1}return!0}updateFrom(e,t){let r=this._diff;return r.didChange(e)?(_n(e,t,this),r.updateFrom(e),this.version++,this.hash=`${this.uuid}_${this.version}`,!0):!1}};var Ir=0,Mo=1,Po=2;function oa(i,e){for(let t=0,r=i.length;t<r;t++)i[t].traverseVisible(s=>{s.isMesh&&e(s)})}function ia(i){let e=[];for(let t=0,r=i.length;t<r;t++){let n=i[t];Array.isArray(n.material)?e.push(...n.material):e.push(n.material)}return e}function na(i,e,t){if(i.length===0){e.setIndex(null);let r=e.attributes;for(let n in r)e.deleteAttribute(n);for(let n in t.attributes)e.setAttribute(t.attributes[n],new K(new Float32Array(0),4,!1))}else mn(i,t,e);for(let r in e.attributes)e.attributes[r].needsUpdate=!0}var Rr=class{constructor(e){this.objects=null,this.useGroups=!0,this.applyWorldTransforms=!0,this.generateMissingAttributes=!0,this.overwriteIndex=!0,this.attributes=["position","normal","color","tangent","uv","uv2"],this._intermediateGeometry=new Map,this._geometryMergeSets=new WeakMap,this._mergeOrder=[],this._dummyMesh=null,this.setObjects(e||[])}_getDummyMesh(){if(!this._dummyMesh){let e=new ni,t=new ae;t.setAttribute("position",new K(new Float32Array(9),3)),this._dummyMesh=new Ht(t,e)}return this._dummyMesh}_getMeshes(){let e=[];return oa(this.objects,t=>{e.push(t)}),e.sort((t,r)=>t.uuid>r.uuid?1:t.uuid<r.uuid?-1:0),e.length===0&&e.push(this._getDummyMesh()),e}_updateIntermediateGeometries(){let{_intermediateGeometry:e}=this,t=this._getMeshes(),r=new Set(e.keys()),n={attributes:this.attributes,applyWorldTransforms:this.applyWorldTransforms};for(let s=0,o=t.length;s<o;s++){let l=t[s],u=l.uuid;r.delete(u);let m=e.get(u);(!m||!m.isCompatible(l,this.attributes))&&(m&&m.dispose(),m=new Ar,e.set(u,m)),m.updateFrom(l,n)&&this.generateMissingAttributes&&hn(m,this.attributes)}r.forEach(s=>{e.delete(s)})}setObjects(e){Array.isArray(e)?this.objects=[...e]:this.objects=[e]}generate(e=new ae){let{useGroups:t,overwriteIndex:r,_intermediateGeometry:n,_geometryMergeSets:s}=this,o=this._getMeshes(),l=[],u=[],m=s.get(e)||[];this._updateIntermediateGeometries();let p=!1;o.length!==m.length&&(p=!0);for(let a=0,h=o.length;a<h;a++){let g=o[a],T=n.get(g.uuid);u.push(T);let d=m[a];!d||d.uuid!==T.uuid?(l.push(!1),p=!0):d.version!==T.version?l.push(!1):l.push(!0)}na(u,e,{useGroups:t,forceUpdate:p,skipAssigningAttributes:l,overwriteIndex:r}),p&&e.dispose(),s.set(e,u.map(a=>({version:a.version,uuid:a.uuid})));let f=Ir;return p?f=Po:l.includes(!1)&&(f=Mo),{changeType:f,materials:ia(o),geometry:e}}};function sa(i){let e=new Set;for(let t=0,r=i.length;t<r;t++){let n=i[t];for(let s in n){let o=n[s];o&&o.isTexture&&e.add(o)}}return Array.from(e)}function aa(i){let e=[],t=new Set;for(let n=0,s=i.length;n<s;n++)i[n].traverse(o=>{o.visible&&(o.isRectAreaLight||o.isSpotLight||o.isPointLight||o.isDirectionalLight)&&(e.push(o),o.iesMap&&t.add(o.iesMap))});let r=Array.from(t).sort((n,s)=>n.uuid<s.uuid?1:n.uuid>s.uuid?-1:0);return{lights:e,iesTextures:r}}var Ve=class{get initialized(){return!!this.bvh}constructor(e){this.bvhOptions={},this.attributes=["position","normal","tangent","color","uv","uv2"],this.generateBVH=!0,this.bvh=null,this.geometry=new ae,this.staticGeometryGenerator=new Rr(e),this._bvhWorker=null,this._pendingGenerate=null,this._buildAsync=!1,this._materialUuids=null}setObjects(e){this.staticGeometryGenerator.setObjects(e)}setBVHWorker(e){this._bvhWorker=e}async generateAsync(e=null){if(!this._bvhWorker)throw new Error('PathTracingSceneGenerator: "setBVHWorker" must be called before "generateAsync" can be called.');if(this.bvh instanceof Promise)return this._pendingGenerate||(this._pendingGenerate=new Promise(async()=>(await this.bvh,this._pendingGenerate=null,this.generateAsync(e)))),this._pendingGenerate;{this._buildAsync=!0;let t=this.generate(e);return this._buildAsync=!1,t.bvh=this.bvh=await t.bvh,t}}generate(e=null){let{staticGeometryGenerator:t,geometry:r,attributes:n}=this,s=t.objects;t.attributes=n,s.forEach(a=>{a.traverse(h=>{h.isSkinnedMesh&&h.skeleton&&h.skeleton.update()})});let o=t.generate(r),l=o.materials,u=o.changeType!==Ir||this._materialUuids===null||this._materialUuids.length!==length;if(!u){for(let a=0,h=l.length;a<h;a++)if(l[a].uuid!==this._materialUuids[a]){u=!0;break}}let m=sa(l),{lights:p,iesTextures:f}=aa(s);if(u&&(dn(r,l,l),this._materialUuids=l.map(a=>a.uuid)),this.generateBVH){if(this.bvh instanceof Promise)throw new Error("PathTracingSceneGenerator: BVH is already building asynchronously.");if(o.changeType===Po){let a={strategy:2,maxLeafTris:1,indirect:!0,onProgress:e,...this.bvhOptions};this._buildAsync?this.bvh=this._bvhWorker.generate(r,a):this.bvh=new vr(r,a)}else o.changeType===Mo&&this.bvh.refit()}return{bvhChanged:o.changeType!==Ir,bvh:this.bvh,needsMaterialIndexUpdate:u,lights:p,iesTextures:f,geometry:r,materials:l,textures:m,objects:s}}},Bo=class extends Ve{constructor(...e){super(...e),console.warn('DynamicPathTracingSceneGenerator has been deprecated and renamed to "PathTracingSceneGenerator".')}},Do=class extends Ve{constructor(...e){super(...e),console.warn('PathTracingSceneWorker has been deprecated and renamed to "PathTracingSceneGenerator".')}};var ca=new ci(-1,1,1,-1,0,1),Eo=class extends ae{constructor(){super(),this.setAttribute("position",new eo([-1,3,0,-1,-1,0,3,-1,0],3)),this.setAttribute("uv",new eo([0,2,0,0,2,0],2))}},la=new Eo,ie=class{constructor(e){this._mesh=new Ht(la,e)}dispose(){this._mesh.geometry.dispose()}render(e){e.render(this._mesh,ca)}get material(){return this._mesh.material}set material(e){this._mesh.material=e}};var de=class extends _e{set needsUpdate(e){super.needsUpdate=!0,this.dispatchEvent({type:"recompilation"})}constructor(e){super(e);for(let t in this.uniforms)Object.defineProperty(this,t,{get(){return this.uniforms[t].value},set(r){this.uniforms[t].value=r}})}setDefine(e,t=void 0){if(t==null){if(e in this.defines)return delete this.defines[e],this.needsUpdate=!0,!0}else if(this.defines[e]!==t)return this.defines[e]=t,this.needsUpdate=!0,!0;return!1}};var Fr=class extends de{constructor(e){super({blending:xe,uniforms:{target1:{value:null},target2:{value:null},opacity:{value:1}},vertexShader:`

				varying vec2 vUv;

				void main() {

					vUv = uv;
					gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );

				}`,fragmentShader:`

				uniform float opacity;

				uniform sampler2D target1;
				uniform sampler2D target2;

				varying vec2 vUv;

				void main() {

					vec4 color1 = texture2D( target1, vUv );
					vec4 color2 = texture2D( target2, vUv );

					float invOpacity = 1.0 - opacity;
					float totalAlpha = color1.a * invOpacity + color2.a * opacity;

					if ( color1.a != 0.0 || color2.a != 0.0 ) {

						gl_FragColor.rgb = color1.rgb * ( invOpacity * color1.a / totalAlpha ) + color2.rgb * ( opacity * color2.a / totalAlpha );
						gl_FragColor.a = totalAlpha;

					} else {

						gl_FragColor = vec4( 0.0 );

					}

				}`}),this.setValues(e)}};function Cr(i=1){let e="uint";return i>1&&(e="uvec"+i),`
		${e} sobolReverseBits( ${e} x ) {

			x = ( ( ( x & 0xaaaaaaaau ) >> 1 ) | ( ( x & 0x55555555u ) << 1 ) );
			x = ( ( ( x & 0xccccccccu ) >> 2 ) | ( ( x & 0x33333333u ) << 2 ) );
			x = ( ( ( x & 0xf0f0f0f0u ) >> 4 ) | ( ( x & 0x0f0f0f0fu ) << 4 ) );
			x = ( ( ( x & 0xff00ff00u ) >> 8 ) | ( ( x & 0x00ff00ffu ) << 8 ) );
			return ( ( x >> 16 ) | ( x << 16 ) );

		}

		${e} sobolHashCombine( uint seed, ${e} v ) {

			return seed ^ ( v + ${e}( ( seed << 6 ) + ( seed >> 2 ) ) );

		}

		${e} sobolLaineKarrasPermutation( ${e} x, ${e} seed ) {

			x += seed;
			x ^= x * 0x6c50b47cu;
			x ^= x * 0xb82f1e52u;
			x ^= x * 0xc7afe638u;
			x ^= x * 0x8d22f6e6u;
			return x;

		}

		${e} nestedUniformScrambleBase2( ${e} x, ${e} seed ) {

			x = sobolLaineKarrasPermutation( x, seed );
			x = sobolReverseBits( x );
			return x;

		}
	`}function Mr(i=1){let e="uint",t="float",r="",n=".r",s="1u";return i>1&&(e="uvec"+i,t="vec"+i,r=i+"",i===2?(n=".rg",s="uvec2( 1u, 2u )"):i===3?(n=".rgb",s="uvec3( 1u, 2u, 3u )"):(n="",s="uvec4( 1u, 2u, 3u, 4u )")),`

		${t} sobol${r}( int effect ) {

			uint seed = sobolGetSeed( sobolBounceIndex, uint( effect ) );
			uint index = sobolPathIndex;

			uint shuffle_seed = sobolHashCombine( seed, 0u );
			uint shuffled_index = nestedUniformScrambleBase2( sobolReverseBits( index ), shuffle_seed );
			${t} sobol_pt = sobolGetTexturePoint( shuffled_index )${n};
			${e} result = ${e}( sobol_pt * 16777216.0 );

			${e} seed2 = sobolHashCombine( seed, ${s} );
			result = nestedUniformScrambleBase2( result, seed2 );

			return SOBOL_FACTOR * ${t}( result >> 8 );

		}
	`}var Pr=`

	// Utils
	const float SOBOL_FACTOR = 1.0 / 16777216.0;
	const uint SOBOL_MAX_POINTS = 256u * 256u;

	${Cr(1)}
	${Cr(2)}
	${Cr(3)}
	${Cr(4)}

	uint sobolHash( uint x ) {

		// finalizer from murmurhash3
		x ^= x >> 16;
		x *= 0x85ebca6bu;
		x ^= x >> 13;
		x *= 0xc2b2ae35u;
		x ^= x >> 16;
		return x;

	}

`,wn=`

	const uint SOBOL_DIRECTIONS_1[ 32 ] = uint[ 32 ](
		0x80000000u, 0xc0000000u, 0xa0000000u, 0xf0000000u,
		0x88000000u, 0xcc000000u, 0xaa000000u, 0xff000000u,
		0x80800000u, 0xc0c00000u, 0xa0a00000u, 0xf0f00000u,
		0x88880000u, 0xcccc0000u, 0xaaaa0000u, 0xffff0000u,
		0x80008000u, 0xc000c000u, 0xa000a000u, 0xf000f000u,
		0x88008800u, 0xcc00cc00u, 0xaa00aa00u, 0xff00ff00u,
		0x80808080u, 0xc0c0c0c0u, 0xa0a0a0a0u, 0xf0f0f0f0u,
		0x88888888u, 0xccccccccu, 0xaaaaaaaau, 0xffffffffu
	);

	const uint SOBOL_DIRECTIONS_2[ 32 ] = uint[ 32 ](
		0x80000000u, 0xc0000000u, 0x60000000u, 0x90000000u,
		0xe8000000u, 0x5c000000u, 0x8e000000u, 0xc5000000u,
		0x68800000u, 0x9cc00000u, 0xee600000u, 0x55900000u,
		0x80680000u, 0xc09c0000u, 0x60ee0000u, 0x90550000u,
		0xe8808000u, 0x5cc0c000u, 0x8e606000u, 0xc5909000u,
		0x6868e800u, 0x9c9c5c00u, 0xeeee8e00u, 0x5555c500u,
		0x8000e880u, 0xc0005cc0u, 0x60008e60u, 0x9000c590u,
		0xe8006868u, 0x5c009c9cu, 0x8e00eeeeu, 0xc5005555u
	);

	const uint SOBOL_DIRECTIONS_3[ 32 ] = uint[ 32 ](
		0x80000000u, 0xc0000000u, 0x20000000u, 0x50000000u,
		0xf8000000u, 0x74000000u, 0xa2000000u, 0x93000000u,
		0xd8800000u, 0x25400000u, 0x59e00000u, 0xe6d00000u,
		0x78080000u, 0xb40c0000u, 0x82020000u, 0xc3050000u,
		0x208f8000u, 0x51474000u, 0xfbea2000u, 0x75d93000u,
		0xa0858800u, 0x914e5400u, 0xdbe79e00u, 0x25db6d00u,
		0x58800080u, 0xe54000c0u, 0x79e00020u, 0xb6d00050u,
		0x800800f8u, 0xc00c0074u, 0x200200a2u, 0x50050093u
	);

	const uint SOBOL_DIRECTIONS_4[ 32 ] = uint[ 32 ](
		0x80000000u, 0x40000000u, 0x20000000u, 0xb0000000u,
		0xf8000000u, 0xdc000000u, 0x7a000000u, 0x9d000000u,
		0x5a800000u, 0x2fc00000u, 0xa1600000u, 0xf0b00000u,
		0xda880000u, 0x6fc40000u, 0x81620000u, 0x40bb0000u,
		0x22878000u, 0xb3c9c000u, 0xfb65a000u, 0xddb2d000u,
		0x78022800u, 0x9c0b3c00u, 0x5a0fb600u, 0x2d0ddb00u,
		0xa2878080u, 0xf3c9c040u, 0xdb65a020u, 0x6db2d0b0u,
		0x800228f8u, 0x400b3cdcu, 0x200fb67au, 0xb00ddb9du
	);

	uint getMaskedSobol( uint index, uint directions[ 32 ] ) {

		uint X = 0u;
		for ( int bit = 0; bit < 32; bit ++ ) {

			uint mask = ( index >> bit ) & 1u;
			X ^= mask * directions[ bit ];

		}
		return X;

	}

	vec4 generateSobolPoint( uint index ) {

		if ( index >= SOBOL_MAX_POINTS ) {

			return vec4( 0.0 );

		}

		// NOTE: this sobol "direction" is also available but we can't write out 5 components
		// uint x = index & 0x00ffffffu;
		uint x = sobolReverseBits( getMaskedSobol( index, SOBOL_DIRECTIONS_1 ) ) & 0x00ffffffu;
		uint y = sobolReverseBits( getMaskedSobol( index, SOBOL_DIRECTIONS_2 ) ) & 0x00ffffffu;
		uint z = sobolReverseBits( getMaskedSobol( index, SOBOL_DIRECTIONS_3 ) ) & 0x00ffffffu;
		uint w = sobolReverseBits( getMaskedSobol( index, SOBOL_DIRECTIONS_4 ) ) & 0x00ffffffu;

		return vec4( x, y, z, w ) * SOBOL_FACTOR;

	}

`,An=`

	// Seeds
	uniform sampler2D sobolTexture;
	uint sobolPixelIndex = 0u;
	uint sobolPathIndex = 0u;
	uint sobolBounceIndex = 0u;

	uint sobolGetSeed( uint bounce, uint effect ) {

		return sobolHash(
			sobolHashCombine(
				sobolHashCombine(
					sobolHash( bounce ),
					sobolPixelIndex
				),
				effect
			)
		);

	}

	vec4 sobolGetTexturePoint( uint index ) {

		if ( index >= SOBOL_MAX_POINTS ) {

			index = index % SOBOL_MAX_POINTS;

		}

		uvec2 dim = uvec2( textureSize( sobolTexture, 0 ).xy );
		uint y = index / dim.x;
		uint x = index - y * dim.x;
		vec2 uv = vec2( x, y ) / vec2( dim );
		return texture( sobolTexture, uv );

	}

	${Mr(1)}
	${Mr(2)}
	${Mr(3)}
	${Mr(4)}

`;var Lo=class extends de{constructor(){super({blending:xe,uniforms:{resolution:{value:new X}},vertexShader:`

				varying vec2 vUv;
				void main() {

					vUv = uv;
					gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );

				}
			`,fragmentShader:`

				${Pr}
				${wn}

				varying vec2 vUv;
				uniform vec2 resolution;
				void main() {

					uint index = uint( gl_FragCoord.y ) * uint( resolution.x ) + uint( gl_FragCoord.x );
					gl_FragColor = generateSobolPoint( index );

				}
			`})}},Br=class{generate(e,t=256){let r=new ye(t,t,{type:G,format:L,minFilter:U,magFilter:U,generateMipmaps:!1}),n=e.getRenderTarget();e.setRenderTarget(r);let s=new ie(new Lo);return s.material.resolution.set(t,t),s.render(e),e.setRenderTarget(n),s.dispose(),r}};var Bt=class extends Wt{set bokehSize(e){this.fStop=this.getFocalLength()/e}get bokehSize(){return this.getFocalLength()/this.fStop}constructor(...e){super(...e),this.fStop=1.4,this.apertureBlades=0,this.apertureRotation=0,this.focusDistance=25,this.anamorphicRatio=1}copy(e,t){return super.copy(e,t),this.fStop=e.fStop,this.apertureBlades=e.apertureBlades,this.apertureRotation=e.apertureRotation,this.focusDistance=e.focusDistance,this.anamorphicRatio=e.anamorphicRatio,this}};var Dr=class{constructor(){this.bokehSize=0,this.apertureBlades=0,this.apertureRotation=0,this.focusDistance=10,this.anamorphicRatio=1}updateFrom(e){e instanceof Bt?(this.bokehSize=e.bokehSize,this.apertureBlades=e.apertureBlades,this.apertureRotation=e.apertureRotation,this.focusDistance=e.focusDistance,this.anamorphicRatio=e.anamorphicRatio):(this.bokehSize=0,this.apertureRotation=0,this.apertureBlades=0,this.focusDistance=10,this.anamorphicRatio=1)}};function Er(i){let e=new Uint16Array(i.length);for(let t=0,r=i.length;t<r;++t)e[t]=ne.toHalfFloat(i[t]);return e}function Rn(i,e,t=0,r=i.length){let n=t,s=t+r-1;for(;n<s;){let o=n+s>>1;i[o]<e?n=o+1:s=o}return n-t}function ua(i,e,t){return .2126*i+.7152*e+.0722*t}function fa(i,e=te){let t=i.clone();t.source=new xi({...t.image});let{width:r,height:n,data:s}=t.image,o=s;if(t.type!==e){e===te?o=new Uint16Array(s.length):o=new Float32Array(s.length);let l;s instanceof Int8Array||s instanceof Int16Array||s instanceof Int32Array?l=2**(8*s.BYTES_PER_ELEMENT-1)-1:l=2**(8*s.BYTES_PER_ELEMENT)-1;for(let u=0,m=s.length;u<m;u++){let p=s[u];t.type===te&&(p=ne.fromHalfFloat(s[u])),t.type!==G&&t.type!==te&&(p/=l),e===te&&(o[u]=ne.toHalfFloat(p))}t.image.data=o,t.type=e}if(t.flipY){let l=o;o=o.slice();for(let u=0;u<n;u++)for(let m=0;m<r;m++){let p=n-u-1,f=4*(u*r+m),a=4*(p*r+m);o[a+0]=l[f+0],o[a+1]=l[f+1],o[a+2]=l[f+2],o[a+3]=l[f+3]}t.flipY=!1,t.image.data=o}return t}var Lr=class{constructor(){let e=new $(Er(new Float32Array([0,0,0,0])),1,1);e.type=te,e.format=L,e.minFilter=re,e.magFilter=re,e.wrapS=fe,e.wrapT=fe,e.generateMipmaps=!1,e.needsUpdate=!0;let t=new $(Er(new Float32Array([0,1])),1,2);t.type=te,t.format=De,t.minFilter=re,t.magFilter=re,t.generateMipmaps=!1,t.needsUpdate=!0;let r=new $(Er(new Float32Array([0,0,1,1])),2,2);r.type=te,r.format=De,r.minFilter=re,r.magFilter=re,r.generateMipmaps=!1,r.needsUpdate=!0,this.map=e,this.marginalWeights=t,this.conditionalWeights=r,this.totalSum=0}dispose(){this.marginalWeights.dispose(),this.conditionalWeights.dispose(),this.map.dispose()}updateFrom(e){let t=fa(e);t.wrapS=fe,t.wrapT=ce;let{width:r,height:n,data:s}=t.image,o=new Float32Array(r*n),l=new Float32Array(r*n),u=new Float32Array(n),m=new Float32Array(n),p=0,f=0;for(let d=0;d<n;d++){let b=0;for(let x=0;x<r;x++){let v=d*r+x,y=ne.fromHalfFloat(s[4*v+0]),S=ne.fromHalfFloat(s[4*v+1]),w=ne.fromHalfFloat(s[4*v+2]),_=ua(y,S,w);b+=_,p+=_,o[v]=_,l[v]=b}if(b!==0)for(let x=d*r,v=d*r+r;x<v;x++)o[x]/=b,l[x]/=b;f+=b,u[d]=b,m[d]=f}if(f!==0)for(let d=0,b=u.length;d<b;d++)u[d]/=f,m[d]/=f;let a=new Uint16Array(n),h=new Uint16Array(r*n);for(let d=0;d<n;d++){let b=(d+1)/n,x=Rn(m,b);a[d]=ne.toHalfFloat((x+.5)/n)}for(let d=0;d<n;d++)for(let b=0;b<r;b++){let x=d*r+b,v=(b+1)/r,y=Rn(l,v,d*r,r);h[x]=ne.toHalfFloat((y+.5)/r)}this.dispose();let{marginalWeights:g,conditionalWeights:T}=this;g.image={width:n,height:1,data:a},g.needsUpdate=!0,T.image={width:r,height:n,data:h},T.needsUpdate=!0,this.totalSum=p,this.map=t}};var No=6,pa=0,ma=1,da=2,ha=3,xa=4,ve=new P,se=new P,In=new V,pt=new ui,Fn=new P,mt=new P,ga=new P(0,1,0),Nr=class{constructor(){let e=new $(new Float32Array(4),1,1);e.format=L,e.type=G,e.wrapS=ce,e.wrapT=ce,e.generateMipmaps=!1,e.minFilter=U,e.magFilter=U,this.tex=e,this.count=0}updateFrom(e,t=[]){let r=this.tex,n=Math.max(e.length*No,1),s=Math.ceil(Math.sqrt(n));r.image.width!==s&&(r.dispose(),r.image.data=new Float32Array(s*s*4),r.image.width=s,r.image.height=s);let o=r.image.data;for(let u=0,m=e.length;u<m;u++){let p=e[u],f=u*No*4,a=0;for(let g=0;g<No*4;g++)o[f+g]=0;p.getWorldPosition(se),o[f+a++]=se.x,o[f+a++]=se.y,o[f+a++]=se.z;let h=pa;if(p.isRectAreaLight&&p.isCircular?h=ma:p.isSpotLight?h=da:p.isDirectionalLight?h=ha:p.isPointLight&&(h=xa),o[f+a++]=h,o[f+a++]=p.color.r,o[f+a++]=p.color.g,o[f+a++]=p.color.b,o[f+a++]=p.intensity,p.getWorldQuaternion(pt),p.isRectAreaLight)ve.set(p.width,0,0).applyQuaternion(pt),o[f+a++]=ve.x,o[f+a++]=ve.y,o[f+a++]=ve.z,a++,se.set(0,p.height,0).applyQuaternion(pt),o[f+a++]=se.x,o[f+a++]=se.y,o[f+a++]=se.z,o[f+a++]=ve.cross(se).length()*(p.isCircular?Math.PI/4:1);else if(p.isSpotLight){let g=p.radius||0;Fn.setFromMatrixPosition(p.matrixWorld),mt.setFromMatrixPosition(p.target.matrixWorld),In.lookAt(Fn,mt,ga),pt.setFromRotationMatrix(In),ve.set(1,0,0).applyQuaternion(pt),o[f+a++]=ve.x,o[f+a++]=ve.y,o[f+a++]=ve.z,a++,se.set(0,1,0).applyQuaternion(pt),o[f+a++]=se.x,o[f+a++]=se.y,o[f+a++]=se.z,o[f+a++]=Math.PI*g*g,o[f+a++]=g,o[f+a++]=p.decay,o[f+a++]=p.distance,o[f+a++]=Math.cos(p.angle),o[f+a++]=Math.cos(p.angle*(1-p.penumbra)),o[f+a++]=p.iesMap?t.indexOf(p.iesMap):-1}else if(p.isPointLight){let g=ve.setFromMatrixPosition(p.matrixWorld);o[f+a++]=g.x,o[f+a++]=g.y,o[f+a++]=g.z,a++,a+=4,a+=1,o[f+a++]=p.decay,o[f+a++]=p.distance}else if(p.isDirectionalLight){let g=ve.setFromMatrixPosition(p.matrixWorld),T=se.setFromMatrixPosition(p.target.matrixWorld);mt.subVectors(g,T).normalize(),o[f+a++]=mt.x,o[f+a++]=mt.y,o[f+a++]=mt.z}}this.count=e.length;let l=ft(o.buffer);return this.hash!==l?(this.hash=l,r.needsUpdate=!0,!0):!1}};function Cn(i,e,t,r,n){if(e>r)throw new Error;let s=i.length/e,o=i.constructor.BYTES_PER_ELEMENT*8,l=1;switch(i.constructor){case Uint8Array:case Uint16Array:case Uint32Array:l=2**o-1;break;case Int8Array:case Int16Array:case Int32Array:l=2**(o-1)-1;break}for(let u=0;u<s;u++){let m=4*u,p=e*u;for(let f=0;f<r;f++)t[n+m+f]=e>=f+1?i[p+f]/l:0}}var Or=class extends ri{constructor(){super(),this._textures=[],this.type=G,this.format=L,this.internalFormat="RGBA32F"}updateAttribute(e,t){let r=this._textures[e];r.updateFrom(t);let n=r.image,s=this.image;if(n.width!==s.width||n.height!==s.height)throw new Error("FloatAttributeTextureArray: Attribute must be the same dimensions when updating single layer.");let{width:o,height:l,data:u}=s,p=o*l*4*e,f=t.itemSize;f===3&&(f=4),Cn(r.image.data,f,u,4,p),this.dispose(),this.needsUpdate=!0}setAttributes(e){let t=e[0].count,r=e.length;for(let f=0,a=r;f<a;f++)if(e[f].count!==t)throw new Error("FloatAttributeTextureArray: All attributes must have the same item count.");let n=this._textures;for(;n.length<r;){let f=new ut;n.push(f)}for(;n.length>r;)n.pop();for(let f=0,a=r;f<a;f++)n[f].updateFrom(e[f]);let o=n[0].image,l=this.image;(o.width!==l.width||o.height!==l.height||o.depth!==r)&&(l.width=o.width,l.height=o.height,l.depth=r,l.data=new Float32Array(l.width*l.height*l.depth*4));let{data:u,width:m,height:p}=l;for(let f=0,a=r;f<a;f++){let h=n[f],T=m*p*4*f,d=e[f].itemSize;d===3&&(d=4),Cn(h.image.data,d,u,4,T)}this.dispose(),this.needsUpdate=!0}};var Gr=class extends Or{updateNormalAttribute(e){this.updateAttribute(0,e)}updateTangentAttribute(e){this.updateAttribute(1,e)}updateUvAttribute(e){this.updateAttribute(2,e)}updateColorAttribute(e){this.updateAttribute(3,e)}updateFrom(e,t,r,n){this.setAttributes([e,t,r,n])}};function Oo(i,e){return i.uuid<e.uuid?1:i.uuid>e.uuid?-1:0}function kr(i){return`${i.source.uuid}:${i.colorSpace}`}function va(i){let e=new Set,t=[];for(let r=0,n=i.length;r<n;r++){let s=i[r],o=kr(s);e.has(o)||(e.add(o),t.push(s))}return t}function Mn(i){let e=i.map(r=>r.iesMap||null).filter(r=>r),t=new Set(e);return Array.from(t).sort(Oo)}function Pn(i){let e=new Set;for(let r=0,n=i.length;r<n;r++){let s=i[r];for(let o in s){let l=s[o];l&&l.isTexture&&e.add(l)}}let t=Array.from(e);return va(t).sort(Oo)}function Bn(i){let e=[];return i.traverse(t=>{t.visible&&(t.isRectAreaLight||t.isSpotLight||t.isPointLight||t.isDirectionalLight)&&e.push(t)}),e.sort(Oo)}var Ur=47,Dn=Ur*4,Go=class{constructor(){this._features={}}isUsed(e){return e in this._features}setUsed(e,t=!0){t===!1?delete this._features[e]:this._features[e]=!0}reset(){this._features={}}},zr=class extends ${constructor(){super(new Float32Array(4),1,1),this.format=L,this.type=G,this.wrapS=ce,this.wrapT=ce,this.minFilter=U,this.magFilter=U,this.generateMipmaps=!1,this.features=new Go}updateFrom(e,t){function r(g,T,d=-1){if(T in g&&g[T]){let b=kr(g[T]);return f[b]}else return d}function n(g,T,d){return T in g?g[T]:d}function s(g,T,d,b){let x=g[T]&&g[T].isTexture?g[T]:null;if(x){x.matrixAutoUpdate&&x.updateMatrix();let v=x.matrix.elements,y=0;d[b+y++]=v[0],d[b+y++]=v[3],d[b+y++]=v[6],y++,d[b+y++]=v[1],d[b+y++]=v[4],d[b+y++]=v[7],y++}return 8}let o=0,l=e.length*Ur,u=Math.ceil(Math.sqrt(l))||1,{image:m,features:p}=this,f={};for(let g=0,T=t.length;g<T;g++)f[kr(t[g])]=g;m.width!==u&&(this.dispose(),m.data=new Float32Array(u*u*4),m.width=u,m.height=u);let a=m.data;p.reset();for(let g=0,T=e.length;g<T;g++){let d=e[g];if(d.isFogVolumeMaterial){p.setUsed("FOG");for(let v=0;v<Dn;v++)a[o+v]=0;a[o+0*4+0]=d.color.r,a[o+0*4+1]=d.color.g,a[o+0*4+2]=d.color.b,a[o+2*4+3]=n(d,"emissiveIntensity",0),a[o+3*4+0]=d.emissive.r,a[o+3*4+1]=d.emissive.g,a[o+3*4+2]=d.emissive.b,a[o+13*4+1]=d.density,a[o+13*4+3]=0,a[o+14*4+2]=4,o+=Dn;continue}a[o++]=d.color.r,a[o++]=d.color.g,a[o++]=d.color.b,a[o++]=r(d,"map"),a[o++]=n(d,"metalness",0),a[o++]=r(d,"metalnessMap"),a[o++]=n(d,"roughness",0),a[o++]=r(d,"roughnessMap"),a[o++]=n(d,"ior",1.5),a[o++]=n(d,"transmission",0),a[o++]=r(d,"transmissionMap"),a[o++]=n(d,"emissiveIntensity",0),"emissive"in d?(a[o++]=d.emissive.r,a[o++]=d.emissive.g,a[o++]=d.emissive.b):(a[o++]=0,a[o++]=0,a[o++]=0),a[o++]=r(d,"emissiveMap"),a[o++]=r(d,"normalMap"),"normalScale"in d?(a[o++]=d.normalScale.x,a[o++]=d.normalScale.y):(a[o++]=1,a[o++]=1),a[o++]=n(d,"clearcoat",0),a[o++]=r(d,"clearcoatMap"),a[o++]=n(d,"clearcoatRoughness",0),a[o++]=r(d,"clearcoatRoughnessMap"),a[o++]=r(d,"clearcoatNormalMap"),"clearcoatNormalScale"in d?(a[o++]=d.clearcoatNormalScale.x,a[o++]=d.clearcoatNormalScale.y):(a[o++]=1,a[o++]=1),o++,a[o++]=n(d,"sheen",0),"sheenColor"in d?(a[o++]=d.sheenColor.r,a[o++]=d.sheenColor.g,a[o++]=d.sheenColor.b):(a[o++]=0,a[o++]=0,a[o++]=0),a[o++]=r(d,"sheenColorMap"),a[o++]=n(d,"sheenRoughness",0),a[o++]=r(d,"sheenRoughnessMap"),a[o++]=r(d,"iridescenceMap"),a[o++]=r(d,"iridescenceThicknessMap"),a[o++]=n(d,"iridescence",0),a[o++]=n(d,"iridescenceIOR",1.3);let b=n(d,"iridescenceThicknessRange",[100,400]);a[o++]=b[0],a[o++]=b[1],"specularColor"in d?(a[o++]=d.specularColor.r,a[o++]=d.specularColor.g,a[o++]=d.specularColor.b):(a[o++]=1,a[o++]=1,a[o++]=1),a[o++]=r(d,"specularColorMap"),a[o++]=n(d,"specularIntensity",1),a[o++]=r(d,"specularIntensityMap");let x=n(d,"thickness",0)===0&&n(d,"attenuationDistance",1/0)===1/0;if(a[o++]=Number(x),o++,"attenuationColor"in d?(a[o++]=d.attenuationColor.r,a[o++]=d.attenuationColor.g,a[o++]=d.attenuationColor.b):(a[o++]=1,a[o++]=1,a[o++]=1),a[o++]=n(d,"attenuationDistance",1/0),a[o++]=r(d,"alphaMap"),a[o++]=d.opacity,a[o++]=d.alphaTest,!x&&d.transmission>0)a[o++]=0;else switch(d.side){case vt:a[o++]=1;break;case kt:a[o++]=-1;break;case zt:a[o++]=0;break}a[o++]=Number(n(d,"matte",!1)),a[o++]=Number(n(d,"castShadow",!0)),a[o++]=Number(d.vertexColors)|Number(d.flatShading)<<1,a[o++]=Number(d.transparent),o+=s(d,"map",a,o),o+=s(d,"metalnessMap",a,o),o+=s(d,"roughnessMap",a,o),o+=s(d,"transmissionMap",a,o),o+=s(d,"emissiveMap",a,o),o+=s(d,"normalMap",a,o),o+=s(d,"clearcoatMap",a,o),o+=s(d,"clearcoatNormalMap",a,o),o+=s(d,"clearcoatRoughnessMap",a,o),o+=s(d,"sheenColorMap",a,o),o+=s(d,"sheenRoughnessMap",a,o),o+=s(d,"iridescenceMap",a,o),o+=s(d,"iridescenceThicknessMap",a,o),o+=s(d,"specularColorMap",a,o),o+=s(d,"specularIntensityMap",a,o),o+=s(d,"alphaMap",a,o)}let h=ft(a.buffer);return this.hash!==h?(this.hash=h,this.needsUpdate=!0,!0):!1}};var En=new he;function ya(i){return i?`${i.uuid}:${i.version}`:null}function Ta(i,e){for(let t in e)t in i&&(i[t]=e[t])}var Dt=class extends Ti{constructor(e,t,r){let n={format:L,type:yt,minFilter:re,magFilter:re,wrapS:fe,wrapT:fe,generateMipmaps:!1,...r};super(e,t,1,n),Ta(this.texture,n),this.texture.setTextures=(...o)=>{this.setTextures(...o)},this.hashes=[null];let s=new ie(new ko);this.fsQuad=s}setTextures(e,t,r=this.width,n=this.height){let s=e.getRenderTarget(),o=e.toneMapping,l=e.getClearAlpha();e.getClearColor(En);let u=t.length||1;(r!==this.width||n!==this.height||this.depth!==u)&&(this.setSize(r,n,u),this.hashes=new Array(u).fill(null)),e.setClearColor(0,0),e.toneMapping=ai;let m=this.fsQuad,p=this.hashes,f=!1;for(let a=0,h=u;a<h;a++){let g=t[a],T=ya(g);g&&(p[a]!==T||g.isWebGLRenderTarget)&&(g.matrixAutoUpdate=!1,g.matrix.identity(),m.material.map=g,e.setRenderTarget(this,a),m.render(e),g.updateMatrix(),g.matrixAutoUpdate=!0,p[a]=T,f=!0)}return m.material.map=null,e.setClearColor(En,l),e.setRenderTarget(s),e.toneMapping=o,f}dispose(){super.dispose(),this.fsQuad.dispose()}},ko=class extends _e{get map(){return this.uniforms.map.value}set map(e){this.uniforms.map.value=e}constructor(){super({uniforms:{map:{value:null}},vertexShader:`
				varying vec2 vUv;
				void main() {

					vUv = uv;
					gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );

				}
			`,fragmentShader:`
				uniform sampler2D map;
				varying vec2 vUv;
				void main() {

					gl_FragColor = texture2D( map, vUv );

				}
			`})}};function ba(i,e=Math.random()){for(let t=i.length-1;t>0;t--){let r=Math.floor(e()*(t+1)),n=i[t];i[t]=i[r],i[r]=n}return i}var Hr=class{constructor(e,t,r=Math.random){let n=e**t,s=new Uint16Array(n),o=n;for(let l=0;l<n;l++)s[l]=l;this.samples=new Float32Array(t),this.strataCount=e,this.reset=function(){for(let l=0;l<n;l++)s[l]=l;o=0},this.reshuffle=function(){o=0},this.next=function(){let{samples:l}=this;o>=s.length&&(ba(s,r),this.reshuffle());let u=s[o++];for(let m=0;m<t;m++)l[m]=(u%e+r())/e,u=Math.floor(u/e);return l}}};var Vr=class{constructor(e,t,r=Math.random){let n=0;for(let u of t)n+=u;let s=new Float32Array(n),o=[],l=0;for(let u of t){let m=new Hr(e,u,r);m.samples=new Float32Array(s.buffer,l,m.samples.length),l+=m.samples.length*4,o.push(m)}this.samples=s,this.strataCount=e,this.next=function(){for(let u of o)u.next();return s},this.reshuffle=function(){for(let u of o)u.reshuffle()},this.reset=function(){for(let u of o)u.reset()}}};var zo=class{constructor(e=0){this.m=2147483648,this.a=1103515245,this.c=12345,this.seed=e}nextInt(){return this.seed=(this.a*this.seed+this.c)%this.m,this.seed}nextFloat(){return this.nextInt()/(this.m-1)}},Wr=class extends ${constructor(e=1,t=1,r=8){super(new Float32Array(1),1,1,L,G),this.minFilter=U,this.magFilter=U,this.strata=r,this.sampler=null,this.generator=new zo,this.stableNoise=!1,this.random=()=>this.stableNoise?this.generator.nextFloat():Math.random(),this.init(e,t,r)}init(e=this.image.height,t=this.image.width,r=this.strata){let{image:n}=this;if(n.width===t&&n.height===e&&this.sampler!==null)return;let s=new Array(e*t).fill(4),o=new Vr(r,s,this.random);n.width=t,n.height=e,n.data=o.samples,this.sampler=o,this.dispose(),this.next()}next(){this.sampler.next(),this.needsUpdate=!0}reset(){this.sampler.reset(),this.generator.seed=0}};function Ln(i,e=Math.random){for(let t=i.length-1;t>0;t--){let r=~~((e()-1e-6)*t),n=i[t];i[t]=i[r],i[r]=n}}function Nn(i,e){i.fill(0);for(let t=0;t<e;t++)i[t]=1}var Et=class{constructor(e){this.count=0,this.size=-1,this.sigma=-1,this.radius=-1,this.lookupTable=null,this.score=null,this.binaryPattern=null,this.resize(e),this.setSigma(1.5)}findVoid(){let{score:e,binaryPattern:t}=this,r=1/0,n=-1;for(let s=0,o=t.length;s<o;s++){if(t[s]!==0)continue;let l=e[s];l<r&&(r=l,n=s)}return n}findCluster(){let{score:e,binaryPattern:t}=this,r=-1/0,n=-1;for(let s=0,o=t.length;s<o;s++){if(t[s]!==1)continue;let l=e[s];l>r&&(r=l,n=s)}return n}setSigma(e){if(e===this.sigma)return;let t=~~(Math.sqrt(10*2*e**2)+1),r=2*t+1,n=new Float32Array(r*r),s=e*e;for(let o=-t;o<=t;o++)for(let l=-t;l<=t;l++){let u=(t+l)*r+o+t,m=o*o+l*l;n[u]=Math.E**(-m/(2*s))}this.lookupTable=n,this.sigma=e,this.radius=t}resize(e){this.size!==e&&(this.size=e,this.score=new Float32Array(e*e),this.binaryPattern=new Uint8Array(e*e))}invert(){let{binaryPattern:e,score:t,size:r}=this;t.fill(0);for(let n=0,s=e.length;n<s;n++)if(e[n]===0){let o=~~(n/r),l=n-o*r;this.updateScore(l,o,1),e[n]=1}else e[n]=0}updateScore(e,t,r){let{size:n,score:s,lookupTable:o}=this,l=this.radius,u=2*l+1;for(let m=-l;m<=l;m++)for(let p=-l;p<=l;p++){let f=(l+p)*u+m+l,a=o[f],h=e+m;h=h<0?n+h:h%n;let g=t+p;g=g<0?n+g:g%n;let T=g*n+h;s[T]+=r*a}}addPointIndex(e){this.binaryPattern[e]=1;let t=this.size,r=~~(e/t),n=e-r*t;this.updateScore(n,r,1),this.count++}removePointIndex(e){this.binaryPattern[e]=0;let t=this.size,r=~~(e/t),n=e-r*t;this.updateScore(n,r,-1),this.count--}copy(e){this.resize(e.size),this.score.set(e.score),this.binaryPattern.set(e.binaryPattern),this.setSigma(e.sigma),this.count=e.count}};var qr=class{constructor(){this.random=Math.random,this.sigma=1.5,this.size=64,this.majorityPointsRatio=.1,this.samples=new Et(1),this.savedSamples=new Et(1)}generate(){let{samples:e,savedSamples:t,sigma:r,majorityPointsRatio:n,size:s}=this;e.resize(s),e.setSigma(r);let o=Math.floor(s*s*n),l=e.binaryPattern;Nn(l,o),Ln(l,this.random);for(let f=0,a=l.length;f<a;f++)l[f]===1&&e.addPointIndex(f);for(;;){let f=e.findCluster();e.removePointIndex(f);let a=e.findVoid();if(f===a){e.addPointIndex(f);break}e.addPointIndex(a)}let u=new Uint32Array(s*s);t.copy(e);let m;for(m=e.count-1;m>=0;){let f=e.findCluster();e.removePointIndex(f),u[f]=m,m--}let p=s*s;for(m=t.count;m<p/2;){let f=t.findVoid();t.addPointIndex(f),u[f]=m,m++}for(t.invert();m<p;){let f=t.findCluster();t.removePointIndex(f),u[f]=m,m++}return{data:u,maxValue:p}}};function Sa(i){return i>=3?4:i}function _a(i){switch(i){case 1:return De;case 2:return Xt;default:return L}}var Yr=class extends ${constructor(e=64,t=1){super(new Float32Array(4),1,1,L,G),this.minFilter=U,this.magFilter=U,this.size=e,this.channels=t,this.update()}update(){let e=this.channels,t=this.size,r=new qr;r.channels=e,r.size=t;let n=Sa(e),s=_a(n);(this.image.width!==t||s!==this.format)&&(this.image.width=t,this.image.height=t,this.image.data=new Float32Array(t**2*n),this.format=s,this.dispose());let o=this.image.data;for(let l=0,u=e;l<u;l++){let m=r.generate(),p=m.data,f=m.maxValue;for(let a=0,h=p.length;a<h;a++){let g=p[a]/f;o[a*n+l]=g}}this.needsUpdate=!0}};var On=`

	struct PhysicalCamera {

		float focusDistance;
		float anamorphicRatio;
		float bokehSize;
		int apertureBlades;
		float apertureRotation;

	};

`;var Gn=`

	struct EquirectHdrInfo {

		sampler2D marginalWeights;
		sampler2D conditionalWeights;
		sampler2D map;

		float totalSum;

	};

`;var kn=`

	#define RECT_AREA_LIGHT_TYPE 0
	#define CIRC_AREA_LIGHT_TYPE 1
	#define SPOT_LIGHT_TYPE 2
	#define DIR_LIGHT_TYPE 3
	#define POINT_LIGHT_TYPE 4

	struct LightsInfo {

		sampler2D tex;
		uint count;

	};

	struct Light {

		vec3 position;
		int type;

		vec3 color;
		float intensity;

		vec3 u;
		vec3 v;
		float area;

		// spot light fields
		float radius;
		float near;
		float decay;
		float distance;
		float coneCos;
		float penumbraCos;
		int iesProfile;

	};

	Light readLightInfo( sampler2D tex, uint index ) {

		uint i = index * 6u;

		vec4 s0 = texelFetch1D( tex, i + 0u );
		vec4 s1 = texelFetch1D( tex, i + 1u );
		vec4 s2 = texelFetch1D( tex, i + 2u );
		vec4 s3 = texelFetch1D( tex, i + 3u );

		Light l;
		l.position = s0.rgb;
		l.type = int( round( s0.a ) );

		l.color = s1.rgb;
		l.intensity = s1.a;

		l.u = s2.rgb;
		l.v = s3.rgb;
		l.area = s3.a;

		if ( l.type == SPOT_LIGHT_TYPE || l.type == POINT_LIGHT_TYPE ) {

			vec4 s4 = texelFetch1D( tex, i + 4u );
			vec4 s5 = texelFetch1D( tex, i + 5u );
			l.radius = s4.r;
			l.decay = s4.g;
			l.distance = s4.b;
			l.coneCos = s4.a;

			l.penumbraCos = s5.r;
			l.iesProfile = int( round( s5.g ) );

		} else {

			l.radius = 0.0;
			l.decay = 0.0;
			l.distance = 0.0;

			l.coneCos = 0.0;
			l.penumbraCos = 0.0;
			l.iesProfile = - 1;

		}

		return l;

	}

`;var zn=`

	struct Material {

		vec3 color;
		int map;

		float metalness;
		int metalnessMap;

		float roughness;
		int roughnessMap;

		float ior;
		float transmission;
		int transmissionMap;

		float emissiveIntensity;
		vec3 emissive;
		int emissiveMap;

		int normalMap;
		vec2 normalScale;

		float clearcoat;
		int clearcoatMap;
		int clearcoatNormalMap;
		vec2 clearcoatNormalScale;
		float clearcoatRoughness;
		int clearcoatRoughnessMap;

		int iridescenceMap;
		int iridescenceThicknessMap;
		float iridescence;
		float iridescenceIor;
		float iridescenceThicknessMinimum;
		float iridescenceThicknessMaximum;

		vec3 specularColor;
		int specularColorMap;

		float specularIntensity;
		int specularIntensityMap;
		bool thinFilm;

		vec3 attenuationColor;
		float attenuationDistance;

		int alphaMap;

		bool castShadow;
		float opacity;
		float alphaTest;

		float side;
		bool matte;

		float sheen;
		vec3 sheenColor;
		int sheenColorMap;
		float sheenRoughness;
		int sheenRoughnessMap;

		bool vertexColors;
		bool flatShading;
		bool transparent;
		bool fogVolume;

		mat3 mapTransform;
		mat3 metalnessMapTransform;
		mat3 roughnessMapTransform;
		mat3 transmissionMapTransform;
		mat3 emissiveMapTransform;
		mat3 normalMapTransform;
		mat3 clearcoatMapTransform;
		mat3 clearcoatNormalMapTransform;
		mat3 clearcoatRoughnessMapTransform;
		mat3 sheenColorMapTransform;
		mat3 sheenRoughnessMapTransform;
		mat3 iridescenceMapTransform;
		mat3 iridescenceThicknessMapTransform;
		mat3 specularColorMapTransform;
		mat3 specularIntensityMapTransform;
		mat3 alphaMapTransform;

	};

	mat3 readTextureTransform( sampler2D tex, uint index ) {

		mat3 textureTransform;

		vec4 row1 = texelFetch1D( tex, index );
		vec4 row2 = texelFetch1D( tex, index + 1u );

		textureTransform[0] = vec3(row1.r, row2.r, 0.0);
		textureTransform[1] = vec3(row1.g, row2.g, 0.0);
		textureTransform[2] = vec3(row1.b, row2.b, 1.0);

		return textureTransform;

	}

	Material readMaterialInfo( sampler2D tex, uint index ) {

		uint i = index * uint( MATERIAL_PIXELS );

		vec4 s0 = texelFetch1D( tex, i + 0u );
		vec4 s1 = texelFetch1D( tex, i + 1u );
		vec4 s2 = texelFetch1D( tex, i + 2u );
		vec4 s3 = texelFetch1D( tex, i + 3u );
		vec4 s4 = texelFetch1D( tex, i + 4u );
		vec4 s5 = texelFetch1D( tex, i + 5u );
		vec4 s6 = texelFetch1D( tex, i + 6u );
		vec4 s7 = texelFetch1D( tex, i + 7u );
		vec4 s8 = texelFetch1D( tex, i + 8u );
		vec4 s9 = texelFetch1D( tex, i + 9u );
		vec4 s10 = texelFetch1D( tex, i + 10u );
		vec4 s11 = texelFetch1D( tex, i + 11u );
		vec4 s12 = texelFetch1D( tex, i + 12u );
		vec4 s13 = texelFetch1D( tex, i + 13u );
		vec4 s14 = texelFetch1D( tex, i + 14u );

		Material m;
		m.color = s0.rgb;
		m.map = int( round( s0.a ) );

		m.metalness = s1.r;
		m.metalnessMap = int( round( s1.g ) );
		m.roughness = s1.b;
		m.roughnessMap = int( round( s1.a ) );

		m.ior = s2.r;
		m.transmission = s2.g;
		m.transmissionMap = int( round( s2.b ) );
		m.emissiveIntensity = s2.a;

		m.emissive = s3.rgb;
		m.emissiveMap = int( round( s3.a ) );

		m.normalMap = int( round( s4.r ) );
		m.normalScale = s4.gb;

		m.clearcoat = s4.a;
		m.clearcoatMap = int( round( s5.r ) );
		m.clearcoatRoughness = s5.g;
		m.clearcoatRoughnessMap = int( round( s5.b ) );
		m.clearcoatNormalMap = int( round( s5.a ) );
		m.clearcoatNormalScale = s6.rg;

		m.sheen = s6.a;
		m.sheenColor = s7.rgb;
		m.sheenColorMap = int( round( s7.a ) );
		m.sheenRoughness = s8.r;
		m.sheenRoughnessMap = int( round( s8.g ) );

		m.iridescenceMap = int( round( s8.b ) );
		m.iridescenceThicknessMap = int( round( s8.a ) );
		m.iridescence = s9.r;
		m.iridescenceIor = s9.g;
		m.iridescenceThicknessMinimum = s9.b;
		m.iridescenceThicknessMaximum = s9.a;

		m.specularColor = s10.rgb;
		m.specularColorMap = int( round( s10.a ) );

		m.specularIntensity = s11.r;
		m.specularIntensityMap = int( round( s11.g ) );
		m.thinFilm = bool( s11.b );

		m.attenuationColor = s12.rgb;
		m.attenuationDistance = s12.a;

		m.alphaMap = int( round( s13.r ) );

		m.opacity = s13.g;
		m.alphaTest = s13.b;
		m.side = s13.a;

		m.matte = bool( s14.r );
		m.castShadow = bool( s14.g );
		m.vertexColors = bool( int( s14.b ) & 1 );
		m.flatShading = bool( int( s14.b ) & 2 );
		m.fogVolume = bool( int( s14.b ) & 4 );
		m.transparent = bool( s14.a );

		uint firstTextureTransformIdx = i + 15u;

		// mat3( 1.0 ) is an identity matrix
		m.mapTransform = m.map == - 1 ? mat3( 1.0 ) : readTextureTransform( tex, firstTextureTransformIdx );
		m.metalnessMapTransform = m.metalnessMap == - 1 ? mat3( 1.0 ) : readTextureTransform( tex, firstTextureTransformIdx + 2u );
		m.roughnessMapTransform = m.roughnessMap == - 1 ? mat3( 1.0 ) : readTextureTransform( tex, firstTextureTransformIdx + 4u );
		m.transmissionMapTransform = m.transmissionMap == - 1 ? mat3( 1.0 ) : readTextureTransform( tex, firstTextureTransformIdx + 6u );
		m.emissiveMapTransform = m.emissiveMap == - 1 ? mat3( 1.0 ) : readTextureTransform( tex, firstTextureTransformIdx + 8u );
		m.normalMapTransform = m.normalMap == - 1 ? mat3( 1.0 ) : readTextureTransform( tex, firstTextureTransformIdx + 10u );
		m.clearcoatMapTransform = m.clearcoatMap == - 1 ? mat3( 1.0 ) : readTextureTransform( tex, firstTextureTransformIdx + 12u );
		m.clearcoatNormalMapTransform = m.clearcoatNormalMap == - 1 ? mat3( 1.0 ) : readTextureTransform( tex, firstTextureTransformIdx + 14u );
		m.clearcoatRoughnessMapTransform = m.clearcoatRoughnessMap == - 1 ? mat3( 1.0 ) : readTextureTransform( tex, firstTextureTransformIdx + 16u );
		m.sheenColorMapTransform = m.sheenColorMap == - 1 ? mat3( 1.0 ) : readTextureTransform( tex, firstTextureTransformIdx + 18u );
		m.sheenRoughnessMapTransform = m.sheenRoughnessMap == - 1 ? mat3( 1.0 ) : readTextureTransform( tex, firstTextureTransformIdx + 20u );
		m.iridescenceMapTransform = m.iridescenceMap == - 1 ? mat3( 1.0 ) : readTextureTransform( tex, firstTextureTransformIdx + 22u );
		m.iridescenceThicknessMapTransform = m.iridescenceThicknessMap == - 1 ? mat3( 1.0 ) : readTextureTransform( tex, firstTextureTransformIdx + 24u );
		m.specularColorMapTransform = m.specularColorMap == - 1 ? mat3( 1.0 ) : readTextureTransform( tex, firstTextureTransformIdx + 26u );
		m.specularIntensityMapTransform = m.specularIntensityMap == - 1 ? mat3( 1.0 ) : readTextureTransform( tex, firstTextureTransformIdx + 28u );
		m.alphaMapTransform = m.alphaMap == - 1 ? mat3( 1.0 ) : readTextureTransform( tex, firstTextureTransformIdx + 30u );

		return m;

	}

`;var Un=`

	struct SurfaceRecord {

		// surface type
		bool volumeParticle;

		// geometry
		vec3 faceNormal;
		bool frontFace;
		vec3 normal;
		mat3 normalBasis;
		mat3 normalInvBasis;

		// cached properties
		float eta;
		float f0;

		// material
		float roughness;
		float filteredRoughness;
		float metalness;
		vec3 color;
		vec3 emission;

		// transmission
		float ior;
		float transmission;
		bool thinFilm;
		vec3 attenuationColor;
		float attenuationDistance;

		// clearcoat
		vec3 clearcoatNormal;
		mat3 clearcoatBasis;
		mat3 clearcoatInvBasis;
		float clearcoat;
		float clearcoatRoughness;
		float filteredClearcoatRoughness;

		// sheen
		float sheen;
		vec3 sheenColor;
		float sheenRoughness;

		// iridescence
		float iridescence;
		float iridescenceIor;
		float iridescenceThickness;

		// specular
		vec3 specularColor;
		float specularIntensity;
	};

	struct ScatterRecord {
		float specularPdf;
		float pdf;
		vec3 direction;
		vec3 color;
	};

`;var Hn=`

	// samples the the given environment map in the given direction
	vec3 sampleEquirectColor( sampler2D envMap, vec3 direction ) {

		return texture2D( envMap, equirectDirectionToUv( direction ) ).rgb;

	}

	// gets the pdf of the given direction to sample
	float equirectDirectionPdf( vec3 direction ) {

		vec2 uv = equirectDirectionToUv( direction );
		float theta = uv.y * PI;
		float sinTheta = sin( theta );
		if ( sinTheta == 0.0 ) {

			return 0.0;

		}

		return 1.0 / ( 2.0 * PI * PI * sinTheta );

	}

	// samples the color given env map with CDF and returns the pdf of the direction
	float sampleEquirect( vec3 direction, inout vec3 color ) {

		float totalSum = envMapInfo.totalSum;
		if ( totalSum == 0.0 ) {

			color = vec3( 0.0 );
			return 1.0;

		}

		vec2 uv = equirectDirectionToUv( direction );
		color = texture2D( envMapInfo.map, uv ).rgb;

		float lum = luminance( color );
		ivec2 resolution = textureSize( envMapInfo.map, 0 );
		float pdf = lum / totalSum;

		return float( resolution.x * resolution.y ) * pdf * equirectDirectionPdf( direction );

	}

	// samples a direction of the envmap with color and retrieves pdf
	float sampleEquirectProbability( vec2 r, inout vec3 color, inout vec3 direction ) {

		// sample env map cdf
		float v = texture2D( envMapInfo.marginalWeights, vec2( r.x, 0.0 ) ).x;
		float u = texture2D( envMapInfo.conditionalWeights, vec2( r.y, v ) ).x;
		vec2 uv = vec2( u, v );

		vec3 derivedDirection = equirectUvToDirection( uv );
		direction = derivedDirection;
		color = texture2D( envMapInfo.map, uv ).rgb;

		float totalSum = envMapInfo.totalSum;
		float lum = luminance( color );
		ivec2 resolution = textureSize( envMapInfo.map, 0 );
		float pdf = lum / totalSum;

		return float( resolution.x * resolution.y ) * pdf * equirectDirectionPdf( direction );

	}
`;var Vn=`

	float getSpotAttenuation( const in float coneCosine, const in float penumbraCosine, const in float angleCosine ) {

		return smoothstep( coneCosine, penumbraCosine, angleCosine );

	}

	float getDistanceAttenuation( const in float lightDistance, const in float cutoffDistance, const in float decayExponent ) {

		// based upon Frostbite 3 Moving to Physically-based Rendering
		// page 32, equation 26: E[window1]
		// https://seblagarde.files.wordpress.com/2015/07/course_notes_moving_frostbite_to_pbr_v32.pdf
		float distanceFalloff = 1.0 / max( pow( lightDistance, decayExponent ), EPSILON );

		if ( cutoffDistance > 0.0 ) {

			distanceFalloff *= pow2( saturate( 1.0 - pow4( lightDistance / cutoffDistance ) ) );

		}

		return distanceFalloff;

	}

	float getPhotometricAttenuation( sampler2DArray iesProfiles, int iesProfile, vec3 posToLight, vec3 lightDir, vec3 u, vec3 v ) {

		float cosTheta = dot( posToLight, lightDir );
		float angle = acos( cosTheta ) / PI;

		return texture2D( iesProfiles, vec3( angle, 0.0, iesProfile ) ).r;

	}

	struct LightRecord {

		float dist;
		vec3 direction;
		float pdf;
		vec3 emission;
		int type;

	};

	bool intersectLightAtIndex( sampler2D lights, vec3 rayOrigin, vec3 rayDirection, uint l, inout LightRecord lightRec ) {

		bool didHit = false;
		Light light = readLightInfo( lights, l );

		vec3 u = light.u;
		vec3 v = light.v;

		// check for backface
		vec3 normal = normalize( cross( u, v ) );
		if ( dot( normal, rayDirection ) > 0.0 ) {

			u *= 1.0 / dot( u, u );
			v *= 1.0 / dot( v, v );

			float dist;

			// MIS / light intersection is not supported for punctual lights.
			if(
				( light.type == RECT_AREA_LIGHT_TYPE && intersectsRectangle( light.position, normal, u, v, rayOrigin, rayDirection, dist ) ) ||
				( light.type == CIRC_AREA_LIGHT_TYPE && intersectsCircle( light.position, normal, u, v, rayOrigin, rayDirection, dist ) )
			) {

				float cosTheta = dot( rayDirection, normal );
				didHit = true;
				lightRec.dist = dist;
				lightRec.pdf = ( dist * dist ) / ( light.area * cosTheta );
				lightRec.emission = light.color * light.intensity;
				lightRec.direction = rayDirection;
				lightRec.type = light.type;

			}

		}

		return didHit;

	}

	LightRecord randomAreaLightSample( Light light, vec3 rayOrigin, vec2 ruv ) {

		vec3 randomPos;
		if( light.type == RECT_AREA_LIGHT_TYPE ) {

			// rectangular area light
			randomPos = light.position + light.u * ( ruv.x - 0.5 ) + light.v * ( ruv.y - 0.5 );

		} else if( light.type == CIRC_AREA_LIGHT_TYPE ) {

			// circular area light
			float r = 0.5 * sqrt( ruv.x );
			float theta = ruv.y * 2.0 * PI;
			float x = r * cos( theta );
			float y = r * sin( theta );

			randomPos = light.position + light.u * x + light.v * y;

		}

		vec3 toLight = randomPos - rayOrigin;
		float lightDistSq = dot( toLight, toLight );
		float dist = sqrt( lightDistSq );
		vec3 direction = toLight / dist;
		vec3 lightNormal = normalize( cross( light.u, light.v ) );

		LightRecord lightRec;
		lightRec.type = light.type;
		lightRec.emission = light.color * light.intensity;
		lightRec.dist = dist;
		lightRec.direction = direction;

		// TODO: the denominator is potentially zero
		lightRec.pdf = lightDistSq / ( light.area * dot( direction, lightNormal ) );

		return lightRec;

	}

	LightRecord randomSpotLightSample( Light light, sampler2DArray iesProfiles, vec3 rayOrigin, vec2 ruv ) {

		float radius = light.radius * sqrt( ruv.x );
		float theta = ruv.y * 2.0 * PI;
		float x = radius * cos( theta );
		float y = radius * sin( theta );

		vec3 u = light.u;
		vec3 v = light.v;
		vec3 normal = normalize( cross( u, v ) );

		float angle = acos( light.coneCos );
		float angleTan = tan( angle );
		float startDistance = light.radius / max( angleTan, EPSILON );

		vec3 randomPos = light.position - normal * startDistance + u * x + v * y;
		vec3 toLight = randomPos - rayOrigin;
		float lightDistSq = dot( toLight, toLight );
		float dist = sqrt( lightDistSq );

		vec3 direction = toLight / max( dist, EPSILON );
		float cosTheta = dot( direction, normal );

		float spotAttenuation = light.iesProfile != - 1 ?
			getPhotometricAttenuation( iesProfiles, light.iesProfile, direction, normal, u, v ) :
			getSpotAttenuation( light.coneCos, light.penumbraCos, cosTheta );

		float distanceAttenuation = getDistanceAttenuation( dist, light.distance, light.decay );
		LightRecord lightRec;
		lightRec.type = light.type;
		lightRec.dist = dist;
		lightRec.direction = direction;
		lightRec.emission = light.color * light.intensity * distanceAttenuation * spotAttenuation;
		lightRec.pdf = 1.0;

		return lightRec;

	}

	LightRecord randomLightSample( sampler2D lights, sampler2DArray iesProfiles, uint lightCount, vec3 rayOrigin, vec3 ruv ) {

		LightRecord result;

		// pick a random light
		uint l = uint( ruv.x * float( lightCount ) );
		Light light = readLightInfo( lights, l );

		if ( light.type == SPOT_LIGHT_TYPE ) {

			result = randomSpotLightSample( light, iesProfiles, rayOrigin, ruv.yz );

		} else if ( light.type == POINT_LIGHT_TYPE ) {

			vec3 lightRay = light.u - rayOrigin;
			float lightDist = length( lightRay );
			float cutoffDistance = light.distance;
			float distanceFalloff = 1.0 / max( pow( lightDist, light.decay ), 0.01 );
			if ( cutoffDistance > 0.0 ) {

				distanceFalloff *= pow2( saturate( 1.0 - pow4( lightDist / cutoffDistance ) ) );

			}

			LightRecord rec;
			rec.direction = normalize( lightRay );
			rec.dist = length( lightRay );
			rec.pdf = 1.0;
			rec.emission = light.color * light.intensity * distanceFalloff;
			rec.type = light.type;
			result = rec;

		} else if ( light.type == DIR_LIGHT_TYPE ) {

			LightRecord rec;
			rec.dist = 1e10;
			rec.direction = light.u;
			rec.pdf = 1.0;
			rec.emission = light.color * light.intensity;
			rec.type = light.type;

			result = rec;

		} else {

			// sample the light
			result = randomAreaLightSample( light, rayOrigin, ruv.yz );

		}

		return result;

	}

`;var Wn=`

	vec3 sampleHemisphere( vec3 n, vec2 uv ) {

		// https://www.rorydriscoll.com/2009/01/07/better-sampling/
		// https://graphics.pixar.com/library/OrthonormalB/paper.pdf
		float sign = n.z == 0.0 ? 1.0 : sign( n.z );
		float a = - 1.0 / ( sign + n.z );
		float b = n.x * n.y * a;
		vec3 b1 = vec3( 1.0 + sign * n.x * n.x * a, sign * b, - sign * n.x );
		vec3 b2 = vec3( b, sign + n.y * n.y * a, - n.y );

		float r = sqrt( uv.x );
		float theta = 2.0 * PI * uv.y;
		float x = r * cos( theta );
		float y = r * sin( theta );
		return x * b1 + y * b2 + sqrt( 1.0 - uv.x ) * n;

	}

	vec2 sampleTriangle( vec2 a, vec2 b, vec2 c, vec2 r ) {

		// get the edges of the triangle and the diagonal across the
		// center of the parallelogram
		vec2 e1 = a - b;
		vec2 e2 = c - b;
		vec2 diag = normalize( e1 + e2 );

		// pick the point in the parallelogram
		if ( r.x + r.y > 1.0 ) {

			r = vec2( 1.0 ) - r;

		}

		return e1 * r.x + e2 * r.y;

	}

	vec2 sampleCircle( vec2 uv ) {

		float angle = 2.0 * PI * uv.x;
		float radius = sqrt( uv.y );
		return vec2( cos( angle ), sin( angle ) ) * radius;

	}

	vec3 sampleSphere( vec2 uv ) {

		float u = ( uv.x - 0.5 ) * 2.0;
		float t = uv.y * PI * 2.0;
		float f = sqrt( 1.0 - u * u );

		return vec3( f * cos( t ), f * sin( t ), u );

	}

	vec2 sampleRegularPolygon( int sides, vec3 uvw ) {

		sides = max( sides, 3 );

		vec3 r = uvw;
		float anglePerSegment = 2.0 * PI / float( sides );
		float segment = floor( float( sides ) * r.x );

		float angle1 = anglePerSegment * segment;
		float angle2 = angle1 + anglePerSegment;
		vec2 a = vec2( sin( angle1 ), cos( angle1 ) );
		vec2 b = vec2( 0.0, 0.0 );
		vec2 c = vec2( sin( angle2 ), cos( angle2 ) );

		return sampleTriangle( a, b, c, r.yz );

	}

	// samples an aperture shape with the given number of sides. 0 means circle
	vec2 sampleAperture( int blades, vec3 uvw ) {

		return blades == 0 ?
			sampleCircle( uvw.xy ) :
			sampleRegularPolygon( blades, uvw );

	}


`;var qn=`

	bool totalInternalReflection( float cosTheta, float eta ) {

		float sinTheta = sqrt( 1.0 - cosTheta * cosTheta );
		return eta * sinTheta > 1.0;

	}

	// https://google.github.io/filament/Filament.md.html#materialsystem/diffusebrdf
	float schlickFresnel( float cosine, float f0 ) {

		return f0 + ( 1.0 - f0 ) * pow( 1.0 - cosine, 5.0 );

	}

	vec3 schlickFresnel( float cosine, vec3 f0 ) {

		return f0 + ( 1.0 - f0 ) * pow( 1.0 - cosine, 5.0 );

	}

	vec3 schlickFresnel( float cosine, vec3 f0, vec3 f90 ) {

		return f0 + ( f90 - f0 ) * pow( 1.0 - cosine, 5.0 );

	}

	float dielectricFresnel( float cosThetaI, float eta ) {

		// https://schuttejoe.github.io/post/disneybsdf/
		float ni = eta;
		float nt = 1.0;

		// Check for total internal reflection
		float sinThetaISq = 1.0f - cosThetaI * cosThetaI;
		float sinThetaTSq = eta * eta * sinThetaISq;
		if( sinThetaTSq >= 1.0 ) {

			return 1.0;

		}

		float sinThetaT = sqrt( sinThetaTSq );

		float cosThetaT = sqrt( max( 0.0, 1.0f - sinThetaT * sinThetaT ) );
		float rParallel = ( ( nt * cosThetaI ) - ( ni * cosThetaT ) ) / ( ( nt * cosThetaI ) + ( ni * cosThetaT ) );
		float rPerpendicular = ( ( ni * cosThetaI ) - ( nt * cosThetaT ) ) / ( ( ni * cosThetaI ) + ( nt * cosThetaT ) );
		return ( rParallel * rParallel + rPerpendicular * rPerpendicular ) / 2.0;

	}

	// https://raytracing.github.io/books/RayTracingInOneWeekend.html#dielectrics/schlickapproximation
	float iorRatioToF0( float eta ) {

		return pow( ( 1.0 - eta ) / ( 1.0 + eta ), 2.0 );

	}

	vec3 evaluateFresnel( float cosTheta, float eta, vec3 f0, vec3 f90 ) {

		if ( totalInternalReflection( cosTheta, eta ) ) {

			return f90;

		}

		return schlickFresnel( cosTheta, f0, f90 );

	}

	// TODO: disney fresnel was removed and replaced with this fresnel function to better align with
	// the glTF but is causing blown out pixels. Should be revisited
	// float evaluateFresnelWeight( float cosTheta, float eta, float f0 ) {

	// 	if ( totalInternalReflection( cosTheta, eta ) ) {

	// 		return 1.0;

	// 	}

	// 	return schlickFresnel( cosTheta, f0 );

	// }

	// https://schuttejoe.github.io/post/disneybsdf/
	float disneyFresnel( vec3 wo, vec3 wi, vec3 wh, float f0, float eta, float metalness ) {

		float dotHV = dot( wo, wh );
		if ( totalInternalReflection( dotHV, eta ) ) {

			return 1.0;

		}

		float dotHL = dot( wi, wh );
		float dielectricFresnel = dielectricFresnel( abs( dotHV ), eta );
		float metallicFresnel = schlickFresnel( dotHL, f0 );

		return mix( dielectricFresnel, metallicFresnel, metalness );

	}

`;var Yn=`

	// Fast arccos approximation used to remove banding artifacts caused by numerical errors in acos.
	// This is a cubic Lagrange interpolating polynomial for x = [-1, -1/2, 0, 1/2, 1].
	// For more information see: https://github.com/gkjohnson/three-gpu-pathtracer/pull/171#issuecomment-1152275248
	float acosApprox( float x ) {

		x = clamp( x, -1.0, 1.0 );
		return ( - 0.69813170079773212 * x * x - 0.87266462599716477 ) * x + 1.5707963267948966;

	}

	// An acos with input values bound to the range [-1, 1].
	float acosSafe( float x ) {

		return acos( clamp( x, -1.0, 1.0 ) );

	}

	float saturateCos( float val ) {

		return clamp( val, 0.001, 1.0 );

	}

	float square( float t ) {

		return t * t;

	}

	vec2 square( vec2 t ) {

		return t * t;

	}

	vec3 square( vec3 t ) {

		return t * t;

	}

	vec4 square( vec4 t ) {

		return t * t;

	}

	vec2 rotateVector( vec2 v, float t ) {

		float ac = cos( t );
		float as = sin( t );
		return vec2(
			v.x * ac - v.y * as,
			v.x * as + v.y * ac
		);

	}

	// forms a basis with the normal vector as Z
	mat3 getBasisFromNormal( vec3 normal ) {

		vec3 other;
		if ( abs( normal.x ) > 0.5 ) {

			other = vec3( 0.0, 1.0, 0.0 );

		} else {

			other = vec3( 1.0, 0.0, 0.0 );

		}

		vec3 ortho = normalize( cross( normal, other ) );
		vec3 ortho2 = normalize( cross( normal, ortho ) );
		return mat3( ortho2, ortho, normal );

	}

`;var Xn=`

	// Finds the point where the ray intersects the plane defined by u and v and checks if this point
	// falls in the bounds of the rectangle on that same plane.
	// Plane intersection: https://lousodrome.net/blog/light/2020/07/03/intersection-of-a-ray-and-a-plane/
	bool intersectsRectangle( vec3 center, vec3 normal, vec3 u, vec3 v, vec3 rayOrigin, vec3 rayDirection, inout float dist ) {

		float t = dot( center - rayOrigin, normal ) / dot( rayDirection, normal );

		if ( t > EPSILON ) {

			vec3 p = rayOrigin + rayDirection * t;
			vec3 vi = p - center;

			// check if p falls inside the rectangle
			float a1 = dot( u, vi );
			if ( abs( a1 ) <= 0.5 ) {

				float a2 = dot( v, vi );
				if ( abs( a2 ) <= 0.5 ) {

					dist = t;
					return true;

				}

			}

		}

		return false;

	}

	// Finds the point where the ray intersects the plane defined by u and v and checks if this point
	// falls in the bounds of the circle on that same plane. See above URL for a description of the plane intersection algorithm.
	bool intersectsCircle( vec3 position, vec3 normal, vec3 u, vec3 v, vec3 rayOrigin, vec3 rayDirection, inout float dist ) {

		float t = dot( position - rayOrigin, normal ) / dot( rayDirection, normal );

		if ( t > EPSILON ) {

			vec3 hit = rayOrigin + rayDirection * t;
			vec3 vi = hit - position;

			float a1 = dot( u, vi );
			float a2 = dot( v, vi );

			if( length( vec2( a1, a2 ) ) <= 0.5 ) {

				dist = t;
				return true;

			}

		}

		return false;

	}

`;var $n=`

	// add texel fetch functions for texture arrays
	vec4 texelFetch1D( sampler2DArray tex, int layer, uint index ) {

		uint width = uint( textureSize( tex, 0 ).x );
		uvec2 uv;
		uv.x = index % width;
		uv.y = index / width;

		return texelFetch( tex, ivec3( uv, layer ), 0 );

	}

	vec4 textureSampleBarycoord( sampler2DArray tex, int layer, vec3 barycoord, uvec3 faceIndices ) {

		return
			barycoord.x * texelFetch1D( tex, layer, faceIndices.x ) +
			barycoord.y * texelFetch1D( tex, layer, faceIndices.y ) +
			barycoord.z * texelFetch1D( tex, layer, faceIndices.z );

	}

`;var dt=`

	// TODO: possibly this should be renamed something related to material or path tracing logic

	#ifndef RAY_OFFSET
	#define RAY_OFFSET 1e-4
	#endif

	// adjust the hit point by the surface normal by a factor of some offset and the
	// maximum component-wise value of the current point to accommodate floating point
	// error as values increase.
	vec3 stepRayOrigin( vec3 rayOrigin, vec3 rayDirection, vec3 offset, float dist ) {

		vec3 point = rayOrigin + rayDirection * dist;
		vec3 absPoint = abs( point );
		float maxPoint = max( absPoint.x, max( absPoint.y, absPoint.z ) );
		return point + offset * ( maxPoint + 1.0 ) * RAY_OFFSET;

	}

	// https://github.com/KhronosGroup/glTF/blob/main/extensions/2.0/Khronos/KHR_materials_volume/README.md#attenuation
	vec3 transmissionAttenuation( float dist, vec3 attColor, float attDist ) {

		vec3 ot = - log( attColor ) / attDist;
		return exp( - ot * dist );

	}

	vec3 getHalfVector( vec3 wi, vec3 wo, float eta ) {

		// get the half vector - assuming if the light incident vector is on the other side
		// of the that it's transmissive.
		vec3 h;
		if ( wi.z > 0.0 ) {

			h = normalize( wi + wo );

		} else {

			// Scale by the ior ratio to retrieve the appropriate half vector
			// From Section 2.2 on computing the transmission half vector:
			// https://blog.selfshadow.com/publications/s2015-shading-course/burley/s2015_pbs_disney_bsdf_notes.pdf
			h = normalize( wi + wo * eta );

		}

		h *= sign( h.z );
		return h;

	}

	vec3 getHalfVector( vec3 a, vec3 b ) {

		return normalize( a + b );

	}

	// The discrepancy between interpolated surface normal and geometry normal can cause issues when a ray
	// is cast that is on the top side of the geometry normal plane but below the surface normal plane. If
	// we find a ray like that we ignore it to avoid artifacts.
	// This function returns if the direction is on the same side of both planes.
	bool isDirectionValid( vec3 direction, vec3 surfaceNormal, vec3 geometryNormal ) {

		bool aboveSurfaceNormal = dot( direction, surfaceNormal ) > 0.0;
		bool aboveGeometryNormal = dot( direction, geometryNormal ) > 0.0;
		return aboveSurfaceNormal == aboveGeometryNormal;

	}

	// ray sampling x and z are swapped to align with expected background view
	vec2 equirectDirectionToUv( vec3 direction ) {

		// from Spherical.setFromCartesianCoords
		vec2 uv = vec2( atan( direction.z, direction.x ), acos( direction.y ) );
		uv /= vec2( 2.0 * PI, PI );

		// apply adjustments to get values in range [0, 1] and y right side up
		uv.x += 0.5;
		uv.y = 1.0 - uv.y;
		return uv;

	}

	vec3 equirectUvToDirection( vec2 uv ) {

		// undo above adjustments
		uv.x -= 0.5;
		uv.y = 1.0 - uv.y;

		// from Vector3.setFromSphericalCoords
		float theta = uv.x * 2.0 * PI;
		float phi = uv.y * PI;

		float sinPhi = sin( phi );

		return vec3( sinPhi * cos( theta ), cos( phi ), sinPhi * sin( theta ) );

	}

	// power heuristic for multiple importance sampling
	float misHeuristic( float a, float b ) {

		float aa = a * a;
		float bb = b * b;
		return aa / ( aa + bb );

	}

	// tentFilter from Peter Shirley's 'Realistic Ray Tracing (2nd Edition)' book, pg. 60
	// erichlof/THREE.js-PathTracing-Renderer/
	float tentFilter( float x ) {

		return x < 0.5 ? sqrt( 2.0 * x ) - 1.0 : 1.0 - sqrt( 2.0 - ( 2.0 * x ) );

	}
`;var Uo=`

	// https://www.shadertoy.com/view/wltcRS
	uvec4 WHITE_NOISE_SEED;

	void rng_initialize( vec2 p, int frame ) {

		// white noise seed
		WHITE_NOISE_SEED = uvec4( p, uint( frame ), uint( p.x ) + uint( p.y ) );

	}

	// https://www.pcg-random.org/
	void pcg4d( inout uvec4 v ) {

		v = v * 1664525u + 1013904223u;
		v.x += v.y * v.w;
		v.y += v.z * v.x;
		v.z += v.x * v.y;
		v.w += v.y * v.z;
		v = v ^ ( v >> 16u );
		v.x += v.y*v.w;
		v.y += v.z*v.x;
		v.z += v.x*v.y;
		v.w += v.y*v.z;

	}

	// returns [ 0, 1 ]
	float pcgRand() {

		pcg4d( WHITE_NOISE_SEED );
		return float( WHITE_NOISE_SEED.x ) / float( 0xffffffffu );

	}

	vec2 pcgRand2() {

		pcg4d( WHITE_NOISE_SEED );
		return vec2( WHITE_NOISE_SEED.xy ) / float(0xffffffffu);

	}

	vec3 pcgRand3() {

		pcg4d( WHITE_NOISE_SEED );
		return vec3( WHITE_NOISE_SEED.xyz ) / float( 0xffffffffu );

	}

	vec4 pcgRand4() {

		pcg4d( WHITE_NOISE_SEED );
		return vec4( WHITE_NOISE_SEED ) / float( 0xffffffffu );

	}
`;var jn=`

	uniform sampler2D stratifiedTexture;
	uniform sampler2D stratifiedOffsetTexture;

	uint sobolPixelIndex = 0u;
	uint sobolPathIndex = 0u;
	uint sobolBounceIndex = 0u;
	vec4 pixelSeed = vec4( 0 );

	vec4 rand4( int v ) {

		ivec2 uv = ivec2( v, sobolBounceIndex );
		vec4 stratifiedSample = texelFetch( stratifiedTexture, uv, 0 );
		return fract( stratifiedSample + pixelSeed.r ); // blue noise + stratified samples

	}

	vec3 rand3( int v ) {

		return rand4( v ).xyz;

	}

	vec2 rand2( int v ) {

		return rand4( v ).xy;

	}

	float rand( int v ) {

		return rand4( v ).x;

	}

	void rng_initialize( vec2 screenCoord, int frame ) {

		// tile the small noise texture across the entire screen
		ivec2 noiseSize = ivec2( textureSize( stratifiedOffsetTexture, 0 ) );
		ivec2 pixel = ivec2( screenCoord.xy ) % noiseSize;
		vec2 pixelWidth = 1.0 / vec2( noiseSize );
		vec2 uv = vec2( pixel ) * pixelWidth + pixelWidth * 0.5;

		// note that using "texelFetch" here seems to break Android for some reason
		pixelSeed = texture( stratifiedOffsetTexture, uv );

	}

`;var Qn=`

	// diffuse
	float diffuseEval( vec3 wo, vec3 wi, vec3 wh, SurfaceRecord surf, inout vec3 color ) {

		// https://schuttejoe.github.io/post/disneybsdf/
		float fl = schlickFresnel( wi.z, 0.0 );
		float fv = schlickFresnel( wo.z, 0.0 );

		float metalFactor = ( 1.0 - surf.metalness );
		float transFactor = ( 1.0 - surf.transmission );
		float rr = 0.5 + 2.0 * surf.roughness * fl * fl;
		float retro = rr * ( fl + fv + fl * fv * ( rr - 1.0f ) );
		float lambert = ( 1.0f - 0.5f * fl ) * ( 1.0f - 0.5f * fv );

		// TODO: subsurface approx?

		// float F = evaluateFresnelWeight( dot( wo, wh ), surf.eta, surf.f0 );
		float F = disneyFresnel( wo, wi, wh, surf.f0, surf.eta, surf.metalness );
		color = ( 1.0 - F ) * transFactor * metalFactor * wi.z * surf.color * ( retro + lambert ) / PI;

		return wi.z / PI;

	}

	vec3 diffuseDirection( vec3 wo, SurfaceRecord surf ) {

		vec3 lightDirection = sampleSphere( rand2( 11 ) );
		lightDirection.z += 1.0;
		lightDirection = normalize( lightDirection );

		return lightDirection;

	}

	// specular
	float specularEval( vec3 wo, vec3 wi, vec3 wh, SurfaceRecord surf, inout vec3 color ) {

		// if roughness is set to 0 then D === NaN which results in black pixels
		float metalness = surf.metalness;
		float roughness = surf.filteredRoughness;

		float eta = surf.eta;
		float f0 = surf.f0;

		vec3 f0Color = mix( f0 * surf.specularColor * surf.specularIntensity, surf.color, surf.metalness );
		vec3 f90Color = vec3( mix( surf.specularIntensity, 1.0, surf.metalness ) );
		vec3 F = evaluateFresnel( dot( wo, wh ), eta, f0Color, f90Color );

		vec3 iridescenceF = evalIridescence( 1.0, surf.iridescenceIor, dot( wi, wh ), surf.iridescenceThickness, f0Color );
		F = mix( F, iridescenceF,  surf.iridescence );

		// PDF
		// See 14.1.1 Microfacet BxDFs in https://www.pbr-book.org/
		float incidentTheta = acos( wo.z );
		float G = ggxShadowMaskG2( wi, wo, roughness );
		float D = ggxDistribution( wh, roughness );
		float G1 = ggxShadowMaskG1( incidentTheta, roughness );
		float ggxPdf = D * G1 * max( 0.0, abs( dot( wo, wh ) ) ) / abs ( wo.z );

		color = wi.z * F * G * D / ( 4.0 * abs( wi.z * wo.z ) );
		return ggxPdf / ( 4.0 * dot( wo, wh ) );

	}

	vec3 specularDirection( vec3 wo, SurfaceRecord surf ) {

		// sample ggx vndf distribution which gives a new normal
		float roughness = surf.filteredRoughness;
		vec3 halfVector = ggxDirection(
			wo,
			vec2( roughness ),
			rand2( 12 )
		);

		// apply to new ray by reflecting off the new normal
		return - reflect( wo, halfVector );

	}


	// transmission
	/*
	float transmissionEval( vec3 wo, vec3 wi, vec3 wh, SurfaceRecord surf, inout vec3 color ) {

		// See section 4.2 in https://www.cs.cornell.edu/~srm/publications/EGSR07-btdf.pdf

		float filteredRoughness = surf.filteredRoughness;
		float eta = surf.eta;
		bool frontFace = surf.frontFace;
		bool thinFilm = surf.thinFilm;

		color = surf.transmission * surf.color;

		float denom = pow( eta * dot( wi, wh ) + dot( wo, wh ), 2.0 );
		return ggxPDF( wo, wh, filteredRoughness ) / denom;

	}

	vec3 transmissionDirection( vec3 wo, SurfaceRecord surf ) {

		float filteredRoughness = surf.filteredRoughness;
		float eta = surf.eta;
		bool frontFace = surf.frontFace;

		// sample ggx vndf distribution which gives a new normal
		vec3 halfVector = ggxDirection(
			wo,
			vec2( filteredRoughness ),
			rand2( 13 )
		);

		vec3 lightDirection = refract( normalize( - wo ), halfVector, eta );
		if ( surf.thinFilm ) {

			lightDirection = - refract( normalize( - lightDirection ), - vec3( 0.0, 0.0, 1.0 ), 1.0 / eta );

		}

		return normalize( lightDirection );

	}
	*/

	// TODO: This is just using a basic cosine-weighted specular distribution with an
	// incorrect PDF value at the moment. Update it to correctly use a GGX distribution
	float transmissionEval( vec3 wo, vec3 wi, vec3 wh, SurfaceRecord surf, inout vec3 color ) {

		color = surf.transmission * surf.color;

		// PDF
		// float F = evaluateFresnelWeight( dot( wo, wh ), surf.eta, surf.f0 );
		// float F = disneyFresnel( wo, wi, wh, surf.f0, surf.eta, surf.metalness );
		// if ( F >= 1.0 ) {

		// 	return 0.0;

		// }

		// return 1.0 / ( 1.0 - F );

		// reverted to previous to transmission. The above was causing black pixels
		float eta = surf.eta;
		float f0 = surf.f0;
		float cosTheta = min( wo.z, 1.0 );
		float sinTheta = sqrt( 1.0 - cosTheta * cosTheta );
		float reflectance = schlickFresnel( cosTheta, f0 );
		bool cannotRefract = eta * sinTheta > 1.0;
		if ( cannotRefract ) {

			return 0.0;

		}

		return 1.0 / ( 1.0 - reflectance );

	}

	vec3 transmissionDirection( vec3 wo, SurfaceRecord surf ) {

		float roughness = surf.filteredRoughness;
		float eta = surf.eta;
		vec3 halfVector = normalize( vec3( 0.0, 0.0, 1.0 ) + sampleSphere( rand2( 13 ) ) * roughness );
		vec3 lightDirection = refract( normalize( - wo ), halfVector, eta );

		if ( surf.thinFilm ) {

			lightDirection = - refract( normalize( - lightDirection ), - vec3( 0.0, 0.0, 1.0 ), 1.0 / eta );

		}
		return normalize( lightDirection );

	}

	// clearcoat
	float clearcoatEval( vec3 wo, vec3 wi, vec3 wh, SurfaceRecord surf, inout vec3 color ) {

		float ior = 1.5;
		float f0 = iorRatioToF0( ior );
		bool frontFace = surf.frontFace;
		float roughness = surf.filteredClearcoatRoughness;

		float eta = frontFace ? 1.0 / ior : ior;
		float G = ggxShadowMaskG2( wi, wo, roughness );
		float D = ggxDistribution( wh, roughness );
		float F = schlickFresnel( dot( wi, wh ), f0 );

		float fClearcoat = F * D * G / ( 4.0 * abs( wi.z * wo.z ) );
		color = color * ( 1.0 - surf.clearcoat * F ) + fClearcoat * surf.clearcoat * wi.z;

		// PDF
		// See equation (27) in http://jcgt.org/published/0003/02/03/
		return ggxPDF( wo, wh, roughness ) / ( 4.0 * dot( wi, wh ) );

	}

	vec3 clearcoatDirection( vec3 wo, SurfaceRecord surf ) {

		// sample ggx vndf distribution which gives a new normal
		float roughness = surf.filteredClearcoatRoughness;
		vec3 halfVector = ggxDirection(
			wo,
			vec2( roughness ),
			rand2( 14 )
		);

		// apply to new ray by reflecting off the new normal
		return - reflect( wo, halfVector );

	}

	// sheen
	vec3 sheenColor( vec3 wo, vec3 wi, vec3 wh, SurfaceRecord surf ) {

		float cosThetaO = saturateCos( wo.z );
		float cosThetaI = saturateCos( wi.z );
		float cosThetaH = wh.z;

		float D = velvetD( cosThetaH, surf.sheenRoughness );
		float G = velvetG( cosThetaO, cosThetaI, surf.sheenRoughness );

		// See equation (1) in http://www.aconty.com/pdf/s2017_pbs_imageworks_sheen.pdf
		vec3 color = surf.sheenColor;
		color *= D * G / ( 4.0 * abs( cosThetaO * cosThetaI ) );
		color *= wi.z;

		return color;

	}

	// bsdf
	void getLobeWeights(
		vec3 wo, vec3 wi, vec3 wh, vec3 clearcoatWo, SurfaceRecord surf,
		inout float diffuseWeight, inout float specularWeight, inout float transmissionWeight, inout float clearcoatWeight
	) {

		float metalness = surf.metalness;
		float transmission = surf.transmission;
		// float fEstimate = evaluateFresnelWeight( dot( wo, wh ), surf.eta, surf.f0 );
		float fEstimate = disneyFresnel( wo, wi, wh, surf.f0, surf.eta, surf.metalness );

		float transSpecularProb = mix( max( 0.25, fEstimate ), 1.0, metalness );
		float diffSpecularProb = 0.5 + 0.5 * metalness;

		diffuseWeight = ( 1.0 - transmission ) * ( 1.0 - diffSpecularProb );
		specularWeight = transmission * transSpecularProb + ( 1.0 - transmission ) * diffSpecularProb;
		transmissionWeight = transmission * ( 1.0 - transSpecularProb );
		clearcoatWeight = surf.clearcoat * schlickFresnel( clearcoatWo.z, 0.04 );

		float totalWeight = diffuseWeight + specularWeight + transmissionWeight + clearcoatWeight;
		diffuseWeight /= totalWeight;
		specularWeight /= totalWeight;
		transmissionWeight /= totalWeight;
		clearcoatWeight /= totalWeight;
	}

	float bsdfEval(
		vec3 wo, vec3 clearcoatWo, vec3 wi, vec3 clearcoatWi, SurfaceRecord surf,
		float diffuseWeight, float specularWeight, float transmissionWeight, float clearcoatWeight, inout float specularPdf, inout vec3 color
	) {

		float metalness = surf.metalness;
		float transmission = surf.transmission;

		float spdf = 0.0;
		float dpdf = 0.0;
		float tpdf = 0.0;
		float cpdf = 0.0;
		color = vec3( 0.0 );

		vec3 halfVector = getHalfVector( wi, wo, surf.eta );

		// diffuse
		if ( diffuseWeight > 0.0 && wi.z > 0.0 ) {

			dpdf = diffuseEval( wo, wi, halfVector, surf, color );
			color *= 1.0 - surf.transmission;

		}

		// ggx specular
		if ( specularWeight > 0.0 && wi.z > 0.0 ) {

			vec3 outColor;
			spdf = specularEval( wo, wi, getHalfVector( wi, wo ), surf, outColor );
			color += outColor;

		}

		// transmission
		if ( transmissionWeight > 0.0 && wi.z < 0.0 ) {

			tpdf = transmissionEval( wo, wi, halfVector, surf, color );

		}

		// sheen
		color *= mix( 1.0, sheenAlbedoScaling( wo, wi, surf ), surf.sheen );
		color += sheenColor( wo, wi, halfVector, surf ) * surf.sheen;

		// clearcoat
		if ( clearcoatWi.z >= 0.0 && clearcoatWeight > 0.0 ) {

			vec3 clearcoatHalfVector = getHalfVector( clearcoatWo, clearcoatWi );
			cpdf = clearcoatEval( clearcoatWo, clearcoatWi, clearcoatHalfVector, surf, color );

		}

		float pdf =
			dpdf * diffuseWeight
			+ spdf * specularWeight
			+ tpdf * transmissionWeight
			+ cpdf * clearcoatWeight;

		// retrieve specular rays for the shadows flag
		specularPdf = spdf * specularWeight + cpdf * clearcoatWeight;

		return pdf;

	}

	float bsdfResult( vec3 worldWo, vec3 worldWi, SurfaceRecord surf, inout vec3 color ) {

		if ( surf.volumeParticle ) {

			color = surf.color / ( 4.0 * PI );
			return 1.0 / ( 4.0 * PI );

		}

		vec3 wo = normalize( surf.normalInvBasis * worldWo );
		vec3 wi = normalize( surf.normalInvBasis * worldWi );

		vec3 clearcoatWo = normalize( surf.clearcoatInvBasis * worldWo );
		vec3 clearcoatWi = normalize( surf.clearcoatInvBasis * worldWi );

		vec3 wh = getHalfVector( wo, wi, surf.eta );
		float diffuseWeight;
		float specularWeight;
		float transmissionWeight;
		float clearcoatWeight;
		getLobeWeights( wo, wi, wh, clearcoatWo, surf, diffuseWeight, specularWeight, transmissionWeight, clearcoatWeight );

		float specularPdf;
		return bsdfEval( wo, clearcoatWo, wi, clearcoatWi, surf, diffuseWeight, specularWeight, transmissionWeight, clearcoatWeight, specularPdf, color );

	}

	ScatterRecord bsdfSample( vec3 worldWo, SurfaceRecord surf ) {

		if ( surf.volumeParticle ) {

			ScatterRecord sampleRec;
			sampleRec.specularPdf = 0.0;
			sampleRec.pdf = 1.0 / ( 4.0 * PI );
			sampleRec.direction = sampleSphere( rand2( 16 ) );
			sampleRec.color = surf.color / ( 4.0 * PI );
			return sampleRec;

		}

		vec3 wo = normalize( surf.normalInvBasis * worldWo );
		vec3 clearcoatWo = normalize( surf.clearcoatInvBasis * worldWo );
		mat3 normalBasis = surf.normalBasis;
		mat3 invBasis = surf.normalInvBasis;
		mat3 clearcoatNormalBasis = surf.clearcoatBasis;
		mat3 clearcoatInvBasis = surf.clearcoatInvBasis;

		float diffuseWeight;
		float specularWeight;
		float transmissionWeight;
		float clearcoatWeight;
		// using normal and basically-reflected ray since we don't have proper half vector here
		getLobeWeights( wo, wo, vec3( 0, 0, 1 ), clearcoatWo, surf, diffuseWeight, specularWeight, transmissionWeight, clearcoatWeight );

		float pdf[4];
		pdf[0] = diffuseWeight;
		pdf[1] = specularWeight;
		pdf[2] = transmissionWeight;
		pdf[3] = clearcoatWeight;

		float cdf[4];
		cdf[0] = pdf[0];
		cdf[1] = pdf[1] + cdf[0];
		cdf[2] = pdf[2] + cdf[1];
		cdf[3] = pdf[3] + cdf[2];

		if( cdf[3] != 0.0 ) {

			float invMaxCdf = 1.0 / cdf[3];
			cdf[0] *= invMaxCdf;
			cdf[1] *= invMaxCdf;
			cdf[2] *= invMaxCdf;
			cdf[3] *= invMaxCdf;

		} else {

			cdf[0] = 1.0;
			cdf[1] = 0.0;
			cdf[2] = 0.0;
			cdf[3] = 0.0;

		}

		vec3 wi;
		vec3 clearcoatWi;

		float r = rand( 15 );
		if ( r <= cdf[0] ) { // diffuse

			wi = diffuseDirection( wo, surf );
			clearcoatWi = normalize( clearcoatInvBasis * normalize( normalBasis * wi ) );

		} else if ( r <= cdf[1] ) { // specular

			wi = specularDirection( wo, surf );
			clearcoatWi = normalize( clearcoatInvBasis * normalize( normalBasis * wi ) );

		} else if ( r <= cdf[2] ) { // transmission / refraction

			wi = transmissionDirection( wo, surf );
			clearcoatWi = normalize( clearcoatInvBasis * normalize( normalBasis * wi ) );

		} else if ( r <= cdf[3] ) { // clearcoat

			clearcoatWi = clearcoatDirection( clearcoatWo, surf );
			wi = normalize( invBasis * normalize( clearcoatNormalBasis * clearcoatWi ) );

		}

		ScatterRecord result;
		result.pdf = bsdfEval( wo, clearcoatWo, wi, clearcoatWi, surf, diffuseWeight, specularWeight, transmissionWeight, clearcoatWeight, result.specularPdf, result.color );
		result.direction = normalize( surf.normalBasis * wi );

		return result;

	}

`;var Kn=`

	// returns the hit distance given the material density
	float intersectFogVolume( Material material, float u ) {

		// https://raytracing.github.io/books/RayTracingTheNextWeek.html#volumes/constantdensitymediums
		return material.opacity == 0.0 ? INFINITY : ( - 1.0 / material.opacity ) * log( u );

	}

	ScatterRecord sampleFogVolume( SurfaceRecord surf, vec2 uv ) {

		ScatterRecord sampleRec;
		sampleRec.specularPdf = 0.0;
		sampleRec.pdf = 1.0 / ( 2.0 * PI );
		sampleRec.direction = sampleSphere( uv );
		sampleRec.color = surf.color;
		return sampleRec;

	}

`;var Zn=`

	// The GGX functions provide sampling and distribution information for normals as output so
	// in order to get probability of scatter direction the half vector must be computed and provided.
	// [0] https://www.cs.cornell.edu/~srm/publications/EGSR07-btdf.pdf
	// [1] https://hal.archives-ouvertes.fr/hal-01509746/document
	// [2] http://jcgt.org/published/0007/04/01/
	// [4] http://jcgt.org/published/0003/02/03/

	// trowbridge-reitz === GGX === GTR

	vec3 ggxDirection( vec3 incidentDir, vec2 roughness, vec2 uv ) {

		// TODO: try GGXVNDF implementation from reference [2], here. Needs to update ggxDistribution
		// function below, as well

		// Implementation from reference [1]
		// stretch view
		vec3 V = normalize( vec3( roughness * incidentDir.xy, incidentDir.z ) );

		// orthonormal basis
		vec3 T1 = ( V.z < 0.9999 ) ? normalize( cross( V, vec3( 0.0, 0.0, 1.0 ) ) ) : vec3( 1.0, 0.0, 0.0 );
		vec3 T2 = cross( T1, V );

		// sample point with polar coordinates (r, phi)
		float a = 1.0 / ( 1.0 + V.z );
		float r = sqrt( uv.x );
		float phi = ( uv.y < a ) ? uv.y / a * PI : PI + ( uv.y - a ) / ( 1.0 - a ) * PI;
		float P1 = r * cos( phi );
		float P2 = r * sin( phi ) * ( ( uv.y < a ) ? 1.0 : V.z );

		// compute normal
		vec3 N = P1 * T1 + P2 * T2 + V * sqrt( max( 0.0, 1.0 - P1 * P1 - P2 * P2 ) );

		// unstretch
		N = normalize( vec3( roughness * N.xy, max( 0.0, N.z ) ) );

		return N;

	}

	// Below are PDF and related functions for use in a Monte Carlo path tracer
	// as specified in Appendix B of the following paper
	// See equation (34) from reference [0]
	float ggxLamda( float theta, float roughness ) {

		float tanTheta = tan( theta );
		float tanTheta2 = tanTheta * tanTheta;
		float alpha2 = roughness * roughness;

		float numerator = - 1.0 + sqrt( 1.0 + alpha2 * tanTheta2 );
		return numerator / 2.0;

	}

	// See equation (34) from reference [0]
	float ggxShadowMaskG1( float theta, float roughness ) {

		return 1.0 / ( 1.0 + ggxLamda( theta, roughness ) );

	}

	// See equation (125) from reference [4]
	float ggxShadowMaskG2( vec3 wi, vec3 wo, float roughness ) {

		float incidentTheta = acos( wi.z );
		float scatterTheta = acos( wo.z );
		return 1.0 / ( 1.0 + ggxLamda( incidentTheta, roughness ) + ggxLamda( scatterTheta, roughness ) );

	}

	// See equation (33) from reference [0]
	float ggxDistribution( vec3 halfVector, float roughness ) {

		float a2 = roughness * roughness;
		a2 = max( EPSILON, a2 );
		float cosTheta = halfVector.z;
		float cosTheta4 = pow( cosTheta, 4.0 );

		if ( cosTheta == 0.0 ) return 0.0;

		float theta = acosSafe( halfVector.z );
		float tanTheta = tan( theta );
		float tanTheta2 = pow( tanTheta, 2.0 );

		float denom = PI * cosTheta4 * pow( a2 + tanTheta2, 2.0 );
		return ( a2 / denom );

	}

	// See equation (3) from reference [2]
	float ggxPDF( vec3 wi, vec3 halfVector, float roughness ) {

		float incidentTheta = acos( wi.z );
		float D = ggxDistribution( halfVector, roughness );
		float G1 = ggxShadowMaskG1( incidentTheta, roughness );

		return D * G1 * max( 0.0, dot( wi, halfVector ) ) / wi.z;

	}

`;var Jn=`

	// XYZ to sRGB color space
	const mat3 XYZ_TO_REC709 = mat3(
		3.2404542, -0.9692660,  0.0556434,
		-1.5371385,  1.8760108, -0.2040259,
		-0.4985314,  0.0415560,  1.0572252
	);

	vec3 fresnel0ToIor( vec3 fresnel0 ) {

		vec3 sqrtF0 = sqrt( fresnel0 );
		return ( vec3( 1.0 ) + sqrtF0 ) / ( vec3( 1.0 ) - sqrtF0 );

	}

	// Conversion FO/IOR
	vec3 iorToFresnel0( vec3 transmittedIor, float incidentIor ) {

		return square( ( transmittedIor - vec3( incidentIor ) ) / ( transmittedIor + vec3( incidentIor ) ) );

	}

	// ior is a value between 1.0 and 3.0. 1.0 is air interface
	float iorToFresnel0( float transmittedIor, float incidentIor ) {

		return square( ( transmittedIor - incidentIor ) / ( transmittedIor + incidentIor ) );

	}

	// Fresnel equations for dielectric/dielectric interfaces. See https://belcour.github.io/blog/research/2017/05/01/brdf-thin-film.html
	vec3 evalSensitivity( float OPD, vec3 shift ) {

		float phase = 2.0 * PI * OPD * 1.0e-9;

		vec3 val = vec3( 5.4856e-13, 4.4201e-13, 5.2481e-13 );
		vec3 pos = vec3( 1.6810e+06, 1.7953e+06, 2.2084e+06 );
		vec3 var = vec3( 4.3278e+09, 9.3046e+09, 6.6121e+09 );

		vec3 xyz = val * sqrt( 2.0 * PI * var ) * cos( pos * phase + shift ) * exp( - square( phase ) * var );
		xyz.x += 9.7470e-14 * sqrt( 2.0 * PI * 4.5282e+09 ) * cos( 2.2399e+06 * phase + shift[ 0 ] ) * exp( - 4.5282e+09 * square( phase ) );
		xyz /= 1.0685e-7;

		vec3 srgb = XYZ_TO_REC709 * xyz;
		return srgb;

	}

	// See Section 4. Analytic Spectral Integration, A Practical Extension to Microfacet Theory for the Modeling of Varying Iridescence, https://hal.archives-ouvertes.fr/hal-01518344/document
	vec3 evalIridescence( float outsideIOR, float eta2, float cosTheta1, float thinFilmThickness, vec3 baseF0 ) {

		vec3 I;

		// Force iridescenceIor -> outsideIOR when thinFilmThickness -> 0.0
		float iridescenceIor = mix( outsideIOR, eta2, smoothstep( 0.0, 0.03, thinFilmThickness ) );

		// Evaluate the cosTheta on the base layer (Snell law)
		float sinTheta2Sq = square( outsideIOR / iridescenceIor ) * ( 1.0 - square( cosTheta1 ) );

		// Handle TIR:
		float cosTheta2Sq = 1.0 - sinTheta2Sq;
		if ( cosTheta2Sq < 0.0 ) {

			return vec3( 1.0 );

		}

		float cosTheta2 = sqrt( cosTheta2Sq );

		// First interface
		float R0 = iorToFresnel0( iridescenceIor, outsideIOR );
		float R12 = schlickFresnel( cosTheta1, R0 );
		float R21 = R12;
		float T121 = 1.0 - R12;
		float phi12 = 0.0;
		if ( iridescenceIor < outsideIOR ) {

			phi12 = PI;

		}

		float phi21 = PI - phi12;

		// Second interface
		vec3 baseIOR = fresnel0ToIor( clamp( baseF0, 0.0, 0.9999 ) ); // guard against 1.0
		vec3 R1 = iorToFresnel0( baseIOR, iridescenceIor );
		vec3 R23 = schlickFresnel( cosTheta2, R1 );
		vec3 phi23 = vec3( 0.0 );
		if ( baseIOR[0] < iridescenceIor ) {

			phi23[ 0 ] = PI;

		}

		if ( baseIOR[1] < iridescenceIor ) {

			phi23[ 1 ] = PI;

		}

		if ( baseIOR[2] < iridescenceIor ) {

			phi23[ 2 ] = PI;

		}

		// Phase shift
		float OPD = 2.0 * iridescenceIor * thinFilmThickness * cosTheta2;
		vec3 phi = vec3( phi21 ) + phi23;

		// Compound terms
		vec3 R123 = clamp( R12 * R23, 1e-5, 0.9999 );
		vec3 r123 = sqrt( R123 );
		vec3 Rs = square( T121 ) * R23 / ( vec3( 1.0 ) - R123 );

		// Reflectance term for m = 0 (DC term amplitude)
		vec3 C0 = R12 + Rs;
		I = C0;

		// Reflectance term for m > 0 (pairs of diracs)
		vec3 Cm = Rs - T121;
		for ( int m = 1; m <= 2; ++ m ) {

			Cm *= r123;
			vec3 Sm = 2.0 * evalSensitivity( float( m ) * OPD, float( m ) * phi );
			I += Cm * Sm;

		}

		// Since out of gamut colors might be produced, negative color values are clamped to 0.
		return max( I, vec3( 0.0 ) );

	}

`;var es=`

	// See equation (2) in http://www.aconty.com/pdf/s2017_pbs_imageworks_sheen.pdf
	float velvetD( float cosThetaH, float roughness ) {

		float alpha = max( roughness, 0.07 );
		alpha = alpha * alpha;

		float invAlpha = 1.0 / alpha;

		float sqrCosThetaH = cosThetaH * cosThetaH;
		float sinThetaH = max( 1.0 - sqrCosThetaH, 0.001 );

		return ( 2.0 + invAlpha ) * pow( sinThetaH, 0.5 * invAlpha ) / ( 2.0 * PI );

	}

	float velvetParamsInterpolate( int i, float oneMinusAlphaSquared ) {

		const float p0[5] = float[5]( 25.3245, 3.32435, 0.16801, -1.27393, -4.85967 );
		const float p1[5] = float[5]( 21.5473, 3.82987, 0.19823, -1.97760, -4.32054 );

		return mix( p1[i], p0[i], oneMinusAlphaSquared );

	}

	float velvetL( float x, float alpha ) {

		float oneMinusAlpha = 1.0 - alpha;
		float oneMinusAlphaSquared = oneMinusAlpha * oneMinusAlpha;

		float a = velvetParamsInterpolate( 0, oneMinusAlphaSquared );
		float b = velvetParamsInterpolate( 1, oneMinusAlphaSquared );
		float c = velvetParamsInterpolate( 2, oneMinusAlphaSquared );
		float d = velvetParamsInterpolate( 3, oneMinusAlphaSquared );
		float e = velvetParamsInterpolate( 4, oneMinusAlphaSquared );

		return a / ( 1.0 + b * pow( abs( x ), c ) ) + d * x + e;

	}

	// See equation (3) in http://www.aconty.com/pdf/s2017_pbs_imageworks_sheen.pdf
	float velvetLambda( float cosTheta, float alpha ) {

		return abs( cosTheta ) < 0.5 ? exp( velvetL( cosTheta, alpha ) ) : exp( 2.0 * velvetL( 0.5, alpha ) - velvetL( 1.0 - cosTheta, alpha ) );

	}

	// See Section 3, Shadowing Term, in http://www.aconty.com/pdf/s2017_pbs_imageworks_sheen.pdf
	float velvetG( float cosThetaO, float cosThetaI, float roughness ) {

		float alpha = max( roughness, 0.07 );
		alpha = alpha * alpha;

		return 1.0 / ( 1.0 + velvetLambda( cosThetaO, alpha ) + velvetLambda( cosThetaI, alpha ) );

	}

	float directionalAlbedoSheen( float cosTheta, float alpha ) {

		cosTheta = saturate( cosTheta );

		float c = 1.0 - cosTheta;
		float c3 = c * c * c;

		return 0.65584461 * c3 + 1.0 / ( 4.16526551 + exp( -7.97291361 * sqrt( alpha ) + 6.33516894 ) );

	}

	float sheenAlbedoScaling( vec3 wo, vec3 wi, SurfaceRecord surf ) {

		float alpha = max( surf.sheenRoughness, 0.07 );
		alpha = alpha * alpha;

		float maxSheenColor = max( max( surf.sheenColor.r, surf.sheenColor.g ), surf.sheenColor.b );

		float eWo = directionalAlbedoSheen( saturateCos( wo.z ), alpha );
		float eWi = directionalAlbedoSheen( saturateCos( wi.z ), alpha );

		return min( 1.0 - maxSheenColor * eWo, 1.0 - maxSheenColor * eWi );

	}

	// See Section 5, Layering, in http://www.aconty.com/pdf/s2017_pbs_imageworks_sheen.pdf
	float sheenAlbedoScaling( vec3 wo, SurfaceRecord surf ) {

		float alpha = max( surf.sheenRoughness, 0.07 );
		alpha = alpha * alpha;

		float maxSheenColor = max( max( surf.sheenColor.r, surf.sheenColor.g ), surf.sheenColor.b );

		float eWo = directionalAlbedoSheen( saturateCos( wo.z ), alpha );

		return 1.0 - maxSheenColor * eWo;

	}

`;var ts=`

#ifndef FOG_CHECK_ITERATIONS
#define FOG_CHECK_ITERATIONS 30
#endif

// returns whether the given material is a fog material or not
bool isMaterialFogVolume( sampler2D materials, uint materialIndex ) {

	uint i = materialIndex * uint( MATERIAL_PIXELS );
	vec4 s14 = texelFetch1D( materials, i + 14u );
	return bool( int( s14.b ) & 4 );

}

// returns true if we're within the first fog volume we hit
bool bvhIntersectFogVolumeHit(
	vec3 rayOrigin, vec3 rayDirection,
	usampler2D materialIndexAttribute, sampler2D materials,
	inout Material material
) {

	material.fogVolume = false;

	for ( int i = 0; i < FOG_CHECK_ITERATIONS; i ++ ) {

		// find nearest hit
		uvec4 faceIndices = uvec4( 0u );
		vec3 faceNormal = vec3( 0.0, 0.0, 1.0 );
		vec3 barycoord = vec3( 0.0 );
		float side = 1.0;
		float dist = 0.0;
		bool hit = bvhIntersectFirstHit( bvh, rayOrigin, rayDirection, faceIndices, faceNormal, barycoord, side, dist );
		if ( hit ) {

			// if it's a fog volume return whether we hit the front or back face
			uint materialIndex = uTexelFetch1D( materialIndexAttribute, faceIndices.x ).r;
			if ( isMaterialFogVolume( materials, materialIndex ) ) {

				material = readMaterialInfo( materials, materialIndex );
				return side == - 1.0;

			} else {

				// move the ray forward
				rayOrigin = stepRayOrigin( rayOrigin, rayDirection, - faceNormal, dist );

			}

		} else {

			return false;

		}

	}

	return false;

}

`;var rs=`

	// step through multiple surface hits and accumulate color attenuation based on transmissive surfaces
	// returns true if a solid surface was hit
	bool attenuateHit(
		RenderState state,
		Ray ray, float rayDist,
		out vec3 color
	) {

		// store the original bounce index so we can reset it after
		uint originalBounceIndex = sobolBounceIndex;

		int traversals = state.traversals;
		int transmissiveTraversals = state.transmissiveTraversals;
		bool isShadowRay = state.isShadowRay;
		Material fogMaterial = state.fogMaterial;

		vec3 startPoint = ray.origin;

		// hit results
		SurfaceHit surfaceHit;

		color = vec3( 1.0 );

		bool result = true;
		for ( int i = 0; i < traversals; i ++ ) {

			sobolBounceIndex ++;

			int hitType = traceScene( ray, fogMaterial, surfaceHit );

			if ( hitType == FOG_HIT ) {

				result = true;
				break;

			} else if ( hitType == SURFACE_HIT ) {

				float totalDist = distance( startPoint, ray.origin + ray.direction * surfaceHit.dist );
				if ( totalDist > rayDist ) {

					result = false;
					break;

				}

				// TODO: attenuate the contribution based on the PDF of the resulting ray including refraction values
				// Should be able to work using the material BSDF functions which will take into account specularity, etc.
				// TODO: should we account for emissive surfaces here?

				uint materialIndex = uTexelFetch1D( materialIndexAttribute, surfaceHit.faceIndices.x ).r;
				Material material = readMaterialInfo( materials, materialIndex );

				// adjust the ray to the new surface
				bool isEntering = surfaceHit.side == 1.0;
				ray.origin = stepRayOrigin( ray.origin, ray.direction, - surfaceHit.faceNormal, surfaceHit.dist );

				#if FEATURE_FOG

				if ( material.fogVolume ) {

					fogMaterial = material;
					fogMaterial.fogVolume = surfaceHit.side == 1.0;
					i -= sign( transmissiveTraversals );
					transmissiveTraversals --;
					continue;

				}

				#endif

				if ( ! material.castShadow && isShadowRay ) {

					continue;

				}

				vec2 uv = textureSampleBarycoord( attributesArray, ATTR_UV, surfaceHit.barycoord, surfaceHit.faceIndices.xyz ).xy;
				vec4 vertexColor = textureSampleBarycoord( attributesArray, ATTR_COLOR, surfaceHit.barycoord, surfaceHit.faceIndices.xyz );

				// albedo
				vec4 albedo = vec4( material.color, material.opacity );
				if ( material.map != - 1 ) {

					vec3 uvPrime = material.mapTransform * vec3( uv, 1 );
					albedo *= texture2D( textures, vec3( uvPrime.xy, material.map ) );

				}

				if ( material.vertexColors ) {

					albedo *= vertexColor;

				}

				// alphaMap
				if ( material.alphaMap != - 1 ) {

					vec3 uvPrime = material.alphaMapTransform * vec3( uv, 1 );
					albedo.a *= texture2D( textures, vec3( uvPrime.xy, material.alphaMap ) ).x;

				}

				// transmission
				float transmission = material.transmission;
				if ( material.transmissionMap != - 1 ) {

					vec3 uvPrime = material.transmissionMapTransform * vec3( uv, 1 );
					transmission *= texture2D( textures, vec3( uvPrime.xy, material.transmissionMap ) ).r;

				}

				// metalness
				float metalness = material.metalness;
				if ( material.metalnessMap != - 1 ) {

					vec3 uvPrime = material.metalnessMapTransform * vec3( uv, 1 );
					metalness *= texture2D( textures, vec3( uvPrime.xy, material.metalnessMap ) ).b;

				}

				float alphaTest = material.alphaTest;
				bool useAlphaTest = alphaTest != 0.0;
				float transmissionFactor = ( 1.0 - metalness ) * transmission;
				if (
					transmissionFactor < rand( 9 ) && ! (
						// material sidedness
						material.side != 0.0 && surfaceHit.side == material.side

						// alpha test
						|| useAlphaTest && albedo.a < alphaTest

						// opacity
						|| material.transparent && ! useAlphaTest && albedo.a < rand( 10 )
					)
				) {

					result = true;
					break;

				}

				if ( surfaceHit.side == 1.0 && isEntering ) {

					// only attenuate by surface color on the way in
					color *= mix( vec3( 1.0 ), albedo.rgb, transmissionFactor );

				} else if ( surfaceHit.side == - 1.0 ) {

					// attenuate by medium once we hit the opposite side of the model
					color *= transmissionAttenuation( surfaceHit.dist, material.attenuationColor, material.attenuationDistance );

				}

				bool isTransmissiveRay = dot( ray.direction, surfaceHit.faceNormal * surfaceHit.side ) < 0.0;
				if ( ( isTransmissiveRay || isEntering ) && transmissiveTraversals > 0 ) {

					i -= sign( transmissiveTraversals );
					transmissiveTraversals --;

				}

			} else {

				result = false;
				break;

			}

		}

		// reset the bounce index
		sobolBounceIndex = originalBounceIndex;
		return result;

	}

`;var os=`

	vec3 ndcToRayOrigin( vec2 coord ) {

		vec4 rayOrigin4 = cameraWorldMatrix * invProjectionMatrix * vec4( coord, - 1.0, 1.0 );
		return rayOrigin4.xyz / rayOrigin4.w;
	}

	Ray getCameraRay() {

		vec2 ssd = vec2( 1.0 ) / resolution;

		// Jitter the camera ray by finding a uv coordinate at a random sample
		// around this pixel's UV coordinate for AA
		vec2 ruv = rand2( 0 );
		vec2 jitteredUv = vUv + vec2( tentFilter( ruv.x ) * ssd.x, tentFilter( ruv.y ) * ssd.y );
		Ray ray;

		#if CAMERA_TYPE == 2

			// Equirectangular projection
			vec4 rayDirection4 = vec4( equirectUvToDirection( jitteredUv ), 0.0 );
			vec4 rayOrigin4 = vec4( 0.0, 0.0, 0.0, 1.0 );

			rayDirection4 = cameraWorldMatrix * rayDirection4;
			rayOrigin4 = cameraWorldMatrix * rayOrigin4;

			ray.direction = normalize( rayDirection4.xyz );
			ray.origin = rayOrigin4.xyz / rayOrigin4.w;

		#else

			// get [- 1, 1] normalized device coordinates
			vec2 ndc = 2.0 * jitteredUv - vec2( 1.0 );
			ray.origin = ndcToRayOrigin( ndc );

			#if CAMERA_TYPE == 1

				// Orthographic projection
				ray.direction = ( cameraWorldMatrix * vec4( 0.0, 0.0, - 1.0, 0.0 ) ).xyz;
				ray.direction = normalize( ray.direction );

			#else

				// Perspective projection
				ray.direction = normalize( mat3( cameraWorldMatrix ) * ( invProjectionMatrix * vec4( ndc, 0.0, 1.0 ) ).xyz );

			#endif

		#endif

		#if FEATURE_DOF
		{

			// depth of field
			vec3 focalPoint = ray.origin + normalize( ray.direction ) * physicalCamera.focusDistance;

			// get the aperture sample
			// if blades === 0 then we assume a circle
			vec3 shapeUVW= rand3( 1 );
			int blades = physicalCamera.apertureBlades;
			float anamorphicRatio = physicalCamera.anamorphicRatio;
			vec2 apertureSample = sampleAperture( blades, shapeUVW );
			apertureSample *= physicalCamera.bokehSize * 0.5 * 1e-3;

			// rotate the aperture shape
			apertureSample =
				rotateVector( apertureSample, physicalCamera.apertureRotation ) *
				saturate( vec2( anamorphicRatio, 1.0 / anamorphicRatio ) );

			// create the new ray
			ray.origin += ( cameraWorldMatrix * vec4( apertureSample, 0.0, 0.0 ) ).xyz;
			ray.direction = focalPoint - ray.origin;

		}
		#endif

		ray.direction = normalize( ray.direction );

		return ray;

	}

`;var is=`

	vec3 directLightContribution( vec3 worldWo, SurfaceRecord surf, RenderState state, vec3 rayOrigin ) {

		vec3 result = vec3( 0.0 );

		// uniformly pick a light or environment map
		if( lightsDenom != 0.0 && rand( 5 ) < float( lights.count ) / lightsDenom ) {

			// sample a light or environment
			LightRecord lightRec = randomLightSample( lights.tex, iesProfiles, lights.count, rayOrigin, rand3( 6 ) );

			bool isSampleBelowSurface = ! surf.volumeParticle && dot( surf.faceNormal, lightRec.direction ) < 0.0;
			if ( isSampleBelowSurface ) {

				lightRec.pdf = 0.0;

			}

			// check if a ray could even reach the light area
			Ray lightRay;
			lightRay.origin = rayOrigin;
			lightRay.direction = lightRec.direction;
			vec3 attenuatedColor;
			if (
				lightRec.pdf > 0.0 &&
				isDirectionValid( lightRec.direction, surf.normal, surf.faceNormal ) &&
				! attenuateHit( state, lightRay, lightRec.dist, attenuatedColor )
			) {

				// get the material pdf
				vec3 sampleColor;
				float lightMaterialPdf = bsdfResult( worldWo, lightRec.direction, surf, sampleColor );
				bool isValidSampleColor = all( greaterThanEqual( sampleColor, vec3( 0.0 ) ) );
				if ( lightMaterialPdf > 0.0 && isValidSampleColor ) {

					// weight the direct light contribution
					float lightPdf = lightRec.pdf / lightsDenom;
					float misWeight = lightRec.type == SPOT_LIGHT_TYPE || lightRec.type == DIR_LIGHT_TYPE || lightRec.type == POINT_LIGHT_TYPE ? 1.0 : misHeuristic( lightPdf, lightMaterialPdf );
					result = attenuatedColor * lightRec.emission * state.throughputColor * sampleColor * misWeight / lightPdf;

				}

			}

		} else if ( envMapInfo.totalSum != 0.0 && environmentIntensity != 0.0 ) {

			// find a sample in the environment map to include in the contribution
			vec3 envColor, envDirection;
			float envPdf = sampleEquirectProbability( rand2( 7 ), envColor, envDirection );
			envDirection = invEnvRotation3x3 * envDirection;

			// this env sampling is not set up for transmissive sampling and yields overly bright
			// results so we ignore the sample in this case.
			// TODO: this should be improved but how? The env samples could traverse a few layers?
			bool isSampleBelowSurface = ! surf.volumeParticle && dot( surf.faceNormal, envDirection ) < 0.0;
			if ( isSampleBelowSurface ) {

				envPdf = 0.0;

			}

			// check if a ray could even reach the surface
			Ray envRay;
			envRay.origin = rayOrigin;
			envRay.direction = envDirection;
			vec3 attenuatedColor;
			if (
				envPdf > 0.0 &&
				isDirectionValid( envDirection, surf.normal, surf.faceNormal ) &&
				! attenuateHit( state, envRay, INFINITY, attenuatedColor )
			) {

				// get the material pdf
				vec3 sampleColor;
				float envMaterialPdf = bsdfResult( worldWo, envDirection, surf, sampleColor );
				bool isValidSampleColor = all( greaterThanEqual( sampleColor, vec3( 0.0 ) ) );
				if ( envMaterialPdf > 0.0 && isValidSampleColor ) {

					// weight the direct light contribution
					envPdf /= lightsDenom;
					float misWeight = misHeuristic( envPdf, envMaterialPdf );
					result = attenuatedColor * environmentIntensity * envColor * state.throughputColor * sampleColor * misWeight / envPdf;

				}

			}

		}

		// Function changed to have a single return statement to potentially help with crashes on Mac OS.
		// See issue #470
		return result;

	}

`;var ns=`

	#define SKIP_SURFACE 0
	#define HIT_SURFACE 1
	int getSurfaceRecord(
		Material material, SurfaceHit surfaceHit, sampler2DArray attributesArray,
		float accumulatedRoughness,
		inout SurfaceRecord surf
	) {

		if ( material.fogVolume ) {

			vec3 normal = vec3( 0, 0, 1 );

			SurfaceRecord fogSurface;
			fogSurface.volumeParticle = true;
			fogSurface.color = material.color;
			fogSurface.emission = material.emissiveIntensity * material.emissive;
			fogSurface.normal = normal;
			fogSurface.faceNormal = normal;
			fogSurface.clearcoatNormal = normal;

			surf = fogSurface;
			return HIT_SURFACE;

		}

		// uv coord for textures
		vec2 uv = textureSampleBarycoord( attributesArray, ATTR_UV, surfaceHit.barycoord, surfaceHit.faceIndices.xyz ).xy;
		vec4 vertexColor = textureSampleBarycoord( attributesArray, ATTR_COLOR, surfaceHit.barycoord, surfaceHit.faceIndices.xyz );

		// albedo
		vec4 albedo = vec4( material.color, material.opacity );
		if ( material.map != - 1 ) {

			vec3 uvPrime = material.mapTransform * vec3( uv, 1 );
			albedo *= texture2D( textures, vec3( uvPrime.xy, material.map ) );

		}

		if ( material.vertexColors ) {

			albedo *= vertexColor;

		}

		// alphaMap
		if ( material.alphaMap != - 1 ) {

			vec3 uvPrime = material.alphaMapTransform * vec3( uv, 1 );
			albedo.a *= texture2D( textures, vec3( uvPrime.xy, material.alphaMap ) ).x;

		}

		// possibly skip this sample if it's transparent, alpha test is enabled, or we hit the wrong material side
		// and it's single sided.
		// - alpha test is disabled when it === 0
		// - the material sidedness test is complicated because we want light to pass through the back side but still
		// be able to see the front side. This boolean checks if the side we hit is the front side on the first ray
		// and we're rendering the other then we skip it. Do the opposite on subsequent bounces to get incoming light.
		float alphaTest = material.alphaTest;
		bool useAlphaTest = alphaTest != 0.0;
		if (
			// material sidedness
			material.side != 0.0 && surfaceHit.side != material.side

			// alpha test
			|| useAlphaTest && albedo.a < alphaTest

			// opacity
			|| material.transparent && ! useAlphaTest && albedo.a < rand( 3 )
		) {

			return SKIP_SURFACE;

		}

		// fetch the interpolated smooth normal
		vec3 normal = normalize( textureSampleBarycoord(
			attributesArray,
			ATTR_NORMAL,
			surfaceHit.barycoord,
			surfaceHit.faceIndices.xyz
		).xyz );

		// roughness
		float roughness = material.roughness;
		if ( material.roughnessMap != - 1 ) {

			vec3 uvPrime = material.roughnessMapTransform * vec3( uv, 1 );
			roughness *= texture2D( textures, vec3( uvPrime.xy, material.roughnessMap ) ).g;

		}

		// metalness
		float metalness = material.metalness;
		if ( material.metalnessMap != - 1 ) {

			vec3 uvPrime = material.metalnessMapTransform * vec3( uv, 1 );
			metalness *= texture2D( textures, vec3( uvPrime.xy, material.metalnessMap ) ).b;

		}

		// emission
		vec3 emission = material.emissiveIntensity * material.emissive;
		if ( material.emissiveMap != - 1 ) {

			vec3 uvPrime = material.emissiveMapTransform * vec3( uv, 1 );
			emission *= texture2D( textures, vec3( uvPrime.xy, material.emissiveMap ) ).xyz;

		}

		// transmission
		float transmission = material.transmission;
		if ( material.transmissionMap != - 1 ) {

			vec3 uvPrime = material.transmissionMapTransform * vec3( uv, 1 );
			transmission *= texture2D( textures, vec3( uvPrime.xy, material.transmissionMap ) ).r;

		}

		// normal
		if ( material.flatShading ) {

			// if we're rendering a flat shaded object then use the face normals - the face normal
			// is provided based on the side the ray hits the mesh so flip it to align with the
			// interpolated vertex normals.
			normal = surfaceHit.faceNormal * surfaceHit.side;

		}

		vec3 baseNormal = normal;
		if ( material.normalMap != - 1 ) {

			vec4 tangentSample = textureSampleBarycoord(
				attributesArray,
				ATTR_TANGENT,
				surfaceHit.barycoord,
				surfaceHit.faceIndices.xyz
			);

			// some provided tangents can be malformed (0, 0, 0) causing the normal to be degenerate
			// resulting in NaNs and slow path tracing.
			if ( length( tangentSample.xyz ) > 0.0 ) {

				vec3 tangent = normalize( tangentSample.xyz );
				vec3 bitangent = normalize( cross( normal, tangent ) * tangentSample.w );
				mat3 vTBN = mat3( tangent, bitangent, normal );

				vec3 uvPrime = material.normalMapTransform * vec3( uv, 1 );
				vec3 texNormal = texture2D( textures, vec3( uvPrime.xy, material.normalMap ) ).xyz * 2.0 - 1.0;
				texNormal.xy *= material.normalScale;
				normal = vTBN * texNormal;

			}

		}

		normal *= surfaceHit.side;

		// clearcoat
		float clearcoat = material.clearcoat;
		if ( material.clearcoatMap != - 1 ) {

			vec3 uvPrime = material.clearcoatMapTransform * vec3( uv, 1 );
			clearcoat *= texture2D( textures, vec3( uvPrime.xy, material.clearcoatMap ) ).r;

		}

		// clearcoatRoughness
		float clearcoatRoughness = material.clearcoatRoughness;
		if ( material.clearcoatRoughnessMap != - 1 ) {

			vec3 uvPrime = material.clearcoatRoughnessMapTransform * vec3( uv, 1 );
			clearcoatRoughness *= texture2D( textures, vec3( uvPrime.xy, material.clearcoatRoughnessMap ) ).g;

		}

		// clearcoatNormal
		vec3 clearcoatNormal = baseNormal;
		if ( material.clearcoatNormalMap != - 1 ) {

			vec4 tangentSample = textureSampleBarycoord(
				attributesArray,
				ATTR_TANGENT,
				surfaceHit.barycoord,
				surfaceHit.faceIndices.xyz
			);

			// some provided tangents can be malformed (0, 0, 0) causing the normal to be degenerate
			// resulting in NaNs and slow path tracing.
			if ( length( tangentSample.xyz ) > 0.0 ) {

				vec3 tangent = normalize( tangentSample.xyz );
				vec3 bitangent = normalize( cross( clearcoatNormal, tangent ) * tangentSample.w );
				mat3 vTBN = mat3( tangent, bitangent, clearcoatNormal );

				vec3 uvPrime = material.clearcoatNormalMapTransform * vec3( uv, 1 );
				vec3 texNormal = texture2D( textures, vec3( uvPrime.xy, material.clearcoatNormalMap ) ).xyz * 2.0 - 1.0;
				texNormal.xy *= material.clearcoatNormalScale;
				clearcoatNormal = vTBN * texNormal;

			}

		}

		clearcoatNormal *= surfaceHit.side;

		// sheenColor
		vec3 sheenColor = material.sheenColor;
		if ( material.sheenColorMap != - 1 ) {

			vec3 uvPrime = material.sheenColorMapTransform * vec3( uv, 1 );
			sheenColor *= texture2D( textures, vec3( uvPrime.xy, material.sheenColorMap ) ).rgb;

		}

		// sheenRoughness
		float sheenRoughness = material.sheenRoughness;
		if ( material.sheenRoughnessMap != - 1 ) {

			vec3 uvPrime = material.sheenRoughnessMapTransform * vec3( uv, 1 );
			sheenRoughness *= texture2D( textures, vec3( uvPrime.xy, material.sheenRoughnessMap ) ).a;

		}

		// iridescence
		float iridescence = material.iridescence;
		if ( material.iridescenceMap != - 1 ) {

			vec3 uvPrime = material.iridescenceMapTransform * vec3( uv, 1 );
			iridescence *= texture2D( textures, vec3( uvPrime.xy, material.iridescenceMap ) ).r;

		}

		// iridescence thickness
		float iridescenceThickness = material.iridescenceThicknessMaximum;
		if ( material.iridescenceThicknessMap != - 1 ) {

			vec3 uvPrime = material.iridescenceThicknessMapTransform * vec3( uv, 1 );
			float iridescenceThicknessSampled = texture2D( textures, vec3( uvPrime.xy, material.iridescenceThicknessMap ) ).g;
			iridescenceThickness = mix( material.iridescenceThicknessMinimum, material.iridescenceThicknessMaximum, iridescenceThicknessSampled );

		}

		iridescence = iridescenceThickness == 0.0 ? 0.0 : iridescence;

		// specular color
		vec3 specularColor = material.specularColor;
		if ( material.specularColorMap != - 1 ) {

			vec3 uvPrime = material.specularColorMapTransform * vec3( uv, 1 );
			specularColor *= texture2D( textures, vec3( uvPrime.xy, material.specularColorMap ) ).rgb;

		}

		// specular intensity
		float specularIntensity = material.specularIntensity;
		if ( material.specularIntensityMap != - 1 ) {

			vec3 uvPrime = material.specularIntensityMapTransform * vec3( uv, 1 );
			specularIntensity *= texture2D( textures, vec3( uvPrime.xy, material.specularIntensityMap ) ).a;

		}

		surf.volumeParticle = false;

		surf.faceNormal = surfaceHit.faceNormal;
		surf.normal = normal;

		surf.metalness = metalness;
		surf.color = albedo.rgb;
		surf.emission = emission;

		surf.ior = material.ior;
		surf.transmission = transmission;
		surf.thinFilm = material.thinFilm;
		surf.attenuationColor = material.attenuationColor;
		surf.attenuationDistance = material.attenuationDistance;

		surf.clearcoatNormal = clearcoatNormal;
		surf.clearcoat = clearcoat;

		surf.sheen = material.sheen;
		surf.sheenColor = sheenColor;

		surf.iridescence = iridescence;
		surf.iridescenceIor = material.iridescenceIor;
		surf.iridescenceThickness = iridescenceThickness;

		surf.specularColor = specularColor;
		surf.specularIntensity = specularIntensity;

		// apply perceptual roughness factor from gltf. sheen perceptual roughness is
		// applied by its brdf function
		// https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#microfacet-surfaces
		surf.roughness = roughness * roughness;
		surf.clearcoatRoughness = clearcoatRoughness * clearcoatRoughness;
		surf.sheenRoughness = sheenRoughness;

		// frontFace is used to determine transmissive properties and PDF. If no transmission is used
		// then we can just always assume this is a front face.
		surf.frontFace = surfaceHit.side == 1.0 || transmission == 0.0;
		surf.eta = material.thinFilm || surf.frontFace ? 1.0 / material.ior : material.ior;
		surf.f0 = iorRatioToF0( surf.eta );

		// Compute the filtered roughness value to use during specular reflection computations.
		// The accumulated roughness value is scaled by a user setting and a "magic value" of 5.0.
		// If we're exiting something transmissive then scale the factor down significantly so we can retain
		// sharp internal reflections
		surf.filteredRoughness = applyFilteredGlossy( surf.roughness, accumulatedRoughness );
		surf.filteredClearcoatRoughness = applyFilteredGlossy( surf.clearcoatRoughness, accumulatedRoughness );

		// get the normal frames
		surf.normalBasis = getBasisFromNormal( surf.normal );
		surf.normalInvBasis = inverse( surf.normalBasis );

		surf.clearcoatBasis = getBasisFromNormal( surf.clearcoatNormal );
		surf.clearcoatInvBasis = inverse( surf.clearcoatBasis );

		return HIT_SURFACE;

	}
`;var ss=`

	struct Ray {

		vec3 origin;
		vec3 direction;

	};

	struct SurfaceHit {

		uvec4 faceIndices;
		vec3 barycoord;
		vec3 faceNormal;
		float side;
		float dist;

	};

	struct RenderState {

		bool firstRay;
		bool transmissiveRay;
		bool isShadowRay;
		float accumulatedRoughness;
		int transmissiveTraversals;
		int traversals;
		uint depth;
		vec3 throughputColor;
		Material fogMaterial;

	};

	RenderState initRenderState() {

		RenderState result;
		result.firstRay = true;
		result.transmissiveRay = true;
		result.isShadowRay = false;
		result.accumulatedRoughness = 0.0;
		result.transmissiveTraversals = 0;
		result.traversals = 0;
		result.throughputColor = vec3( 1.0 );
		result.depth = 0u;
		result.fogMaterial.fogVolume = false;
		return result;

	}

`;var as=`

	#define NO_HIT 0
	#define SURFACE_HIT 1
	#define LIGHT_HIT 2
	#define FOG_HIT 3

	// Passing the global variable 'lights' into this function caused shader program errors.
	// So global variables like 'lights' and 'bvh' were moved out of the function parameters.
	// For more information, refer to: https://github.com/gkjohnson/three-gpu-pathtracer/pull/457
	int traceScene(
		Ray ray, Material fogMaterial, inout SurfaceHit surfaceHit
	) {

		int result = NO_HIT;
		bool hit = bvhIntersectFirstHit( bvh, ray.origin, ray.direction, surfaceHit.faceIndices, surfaceHit.faceNormal, surfaceHit.barycoord, surfaceHit.side, surfaceHit.dist );

		#if FEATURE_FOG

		if ( fogMaterial.fogVolume ) {

			// offset the distance so we don't run into issues with particles on the same surface
			// as other objects
			float particleDist = intersectFogVolume( fogMaterial, rand( 1 ) );
			if ( particleDist + RAY_OFFSET < surfaceHit.dist ) {

				surfaceHit.side = 1.0;
				surfaceHit.faceNormal = normalize( - ray.direction );
				surfaceHit.dist = particleDist;
				return FOG_HIT;

			}

		}

		#endif

		if ( hit ) {

			result = SURFACE_HIT;

		}

		return result;

	}

`;var Lt=class extends de{onBeforeRender(){this.setDefine("FEATURE_DOF",this.physicalCamera.bokehSize===0?0:1),this.setDefine("FEATURE_BACKGROUND_MAP",this.backgroundMap?1:0),this.setDefine("FEATURE_FOG",this.materials.features.isUsed("FOG")?1:0)}constructor(e){super({transparent:!0,depthWrite:!1,defines:{FEATURE_MIS:1,FEATURE_RUSSIAN_ROULETTE:1,FEATURE_DOF:1,FEATURE_BACKGROUND_MAP:0,FEATURE_FOG:1,RANDOM_TYPE:2,CAMERA_TYPE:0,DEBUG_MODE:0,ATTR_NORMAL:0,ATTR_TANGENT:1,ATTR_UV:2,ATTR_COLOR:3,MATERIAL_PIXELS:Ur},uniforms:{resolution:{value:new X},opacity:{value:1},bounces:{value:10},transmissiveBounces:{value:10},filterGlossyFactor:{value:0},physicalCamera:{value:new Dr},cameraWorldMatrix:{value:new V},invProjectionMatrix:{value:new V},bvh:{value:new Tr},attributesArray:{value:new Gr},materialIndexAttribute:{value:new lt},materials:{value:new zr},textures:{value:new Dt().texture},lights:{value:new Nr},iesProfiles:{value:new Dt(360,180,{type:te,wrapS:ce,wrapT:ce}).texture},environmentIntensity:{value:1},environmentRotation:{value:new V},envMapInfo:{value:new Lr},backgroundBlur:{value:0},backgroundMap:{value:null},backgroundAlpha:{value:1},backgroundIntensity:{value:1},backgroundRotation:{value:new V},seed:{value:0},sobolTexture:{value:null},stratifiedTexture:{value:new Wr},stratifiedOffsetTexture:{value:new Yr(64,1)}},vertexShader:`

				varying vec2 vUv;
				void main() {

					vec4 mvPosition = vec4( position, 1.0 );
					mvPosition = modelViewMatrix * mvPosition;
					gl_Position = projectionMatrix * mvPosition;

					vUv = uv;

				}

			`,fragmentShader:`
				#define RAY_OFFSET 1e-4
				#define INFINITY 1e20

				precision highp isampler2D;
				precision highp usampler2D;
				precision highp sampler2DArray;
				vec4 envMapTexelToLinear( vec4 a ) { return a; }
				#include <common>

				// bvh intersection
				${Ge.common_functions}
				${Ge.bvh_struct_definitions}
				${Ge.bvh_ray_functions}

				// uniform structs
				${On}
				${kn}
				${Gn}
				${zn}
				${Un}

				// random
				#if RANDOM_TYPE == 2 	// Stratified List

					${jn}

				#elif RANDOM_TYPE == 1 	// Sobol

					${Uo}
					${Pr}
					${An}

					#define rand(v) sobol(v)
					#define rand2(v) sobol2(v)
					#define rand3(v) sobol3(v)
					#define rand4(v) sobol4(v)

				#else 					// PCG

				${Uo}

					// Using the sobol functions seems to break the the compiler on MacOS
					// - specifically the "sobolReverseBits" function.
					uint sobolPixelIndex = 0u;
					uint sobolPathIndex = 0u;
					uint sobolBounceIndex = 0u;

					#define rand(v) pcgRand()
					#define rand2(v) pcgRand2()
					#define rand3(v) pcgRand3()
					#define rand4(v) pcgRand4()

				#endif

				// common
				${$n}
				${qn}
				${dt}
				${Yn}
				${Xn}

				// environment
				uniform EquirectHdrInfo envMapInfo;
				uniform mat4 environmentRotation;
				uniform float environmentIntensity;

				// lighting
				uniform sampler2DArray iesProfiles;
				uniform LightsInfo lights;

				// background
				uniform float backgroundBlur;
				uniform float backgroundAlpha;
				#if FEATURE_BACKGROUND_MAP

				uniform sampler2D backgroundMap;
				uniform mat4 backgroundRotation;
				uniform float backgroundIntensity;

				#endif

				// camera
				uniform mat4 cameraWorldMatrix;
				uniform mat4 invProjectionMatrix;
				#if FEATURE_DOF

				uniform PhysicalCamera physicalCamera;

				#endif

				// geometry
				uniform sampler2DArray attributesArray;
				uniform usampler2D materialIndexAttribute;
				uniform sampler2D materials;
				uniform sampler2DArray textures;
				uniform BVH bvh;

				// path tracer
				uniform int bounces;
				uniform int transmissiveBounces;
				uniform float filterGlossyFactor;
				uniform int seed;

				// image
				uniform vec2 resolution;
				uniform float opacity;

				varying vec2 vUv;

				// globals
				mat3 envRotation3x3;
				mat3 invEnvRotation3x3;
				float lightsDenom;

				// sampling
				${Wn}
				${Hn}
				${Vn}

				${ts}
				${Zn}
				${es}
				${Jn}
				${Kn}
				${Qn}

				float applyFilteredGlossy( float roughness, float accumulatedRoughness ) {

					return clamp(
						max(
							roughness,
							accumulatedRoughness * filterGlossyFactor * 5.0 ),
						0.0,
						1.0
					);

				}

				vec3 sampleBackground( vec3 direction, vec2 uv ) {

					vec3 sampleDir = sampleHemisphere( direction, uv ) * 0.5 * backgroundBlur;

					#if FEATURE_BACKGROUND_MAP

					sampleDir = normalize( mat3( backgroundRotation ) * direction + sampleDir );
					return backgroundIntensity * sampleEquirectColor( backgroundMap, sampleDir );

					#else

					sampleDir = normalize( envRotation3x3 * direction + sampleDir );
					return environmentIntensity * sampleEquirectColor( envMapInfo.map, sampleDir );

					#endif

				}

				${ss}
				${os}
				${as}
				${rs}
				${is}
				${ns}

				void main() {

					// init
					rng_initialize( gl_FragCoord.xy, seed );
					sobolPixelIndex = ( uint( gl_FragCoord.x ) << 16 ) | uint( gl_FragCoord.y );
					sobolPathIndex = uint( seed );

					// get camera ray
					Ray ray = getCameraRay();

					// inverse environment rotation
					envRotation3x3 = mat3( environmentRotation );
					invEnvRotation3x3 = inverse( envRotation3x3 );
					lightsDenom =
						( environmentIntensity == 0.0 || envMapInfo.totalSum == 0.0 ) && lights.count != 0u ?
							float( lights.count ) :
							float( lights.count + 1u );

					// final color
					gl_FragColor = vec4( 0, 0, 0, 1 );

					// surface results
					SurfaceHit surfaceHit;
					ScatterRecord scatterRec;

					// path tracing state
					RenderState state = initRenderState();
					state.transmissiveTraversals = transmissiveBounces;
					#if FEATURE_FOG

					state.fogMaterial.fogVolume = bvhIntersectFogVolumeHit(
						ray.origin, - ray.direction,
						materialIndexAttribute, materials,
						state.fogMaterial
					);

					#endif

					for ( int i = 0; i < bounces; i ++ ) {

						sobolBounceIndex ++;

						state.depth ++;
						state.traversals = bounces - i;
						state.firstRay = i == 0 && state.transmissiveTraversals == transmissiveBounces;

						int hitType = traceScene( ray, state.fogMaterial, surfaceHit );

						// check if we intersect any lights and accumulate the light contribution
						// TODO: we can add support for light surface rendering in the else condition if we
						// add the ability to toggle visibility of the the light
						if ( ! state.firstRay && ! state.transmissiveRay ) {

							LightRecord lightRec;
							float lightDist = hitType == NO_HIT ? INFINITY : surfaceHit.dist;
							for ( uint i = 0u; i < lights.count; i ++ ) {

								if (
									intersectLightAtIndex( lights.tex, ray.origin, ray.direction, i, lightRec ) &&
									lightRec.dist < lightDist
								) {

									#if FEATURE_MIS

									// weight the contribution
									// NOTE: Only area lights are supported for forward sampling and can be hit
									float misWeight = misHeuristic( scatterRec.pdf, lightRec.pdf / lightsDenom );
									gl_FragColor.rgb += lightRec.emission * state.throughputColor * misWeight;

									#else

									gl_FragColor.rgb += lightRec.emission * state.throughputColor;

									#endif

								}

							}

						}

						if ( hitType == NO_HIT ) {

							if ( state.firstRay || state.transmissiveRay ) {

								gl_FragColor.rgb += sampleBackground( ray.direction, rand2( 2 ) ) * state.throughputColor;
								gl_FragColor.a = backgroundAlpha;

							} else {

								#if FEATURE_MIS

								// get the PDF of the hit envmap point
								vec3 envColor;
								float envPdf = sampleEquirect( envRotation3x3 * ray.direction, envColor );
								envPdf /= lightsDenom;

								// and weight the contribution
								float misWeight = misHeuristic( scatterRec.pdf, envPdf );
								gl_FragColor.rgb += environmentIntensity * envColor * state.throughputColor * misWeight;

								#else

								gl_FragColor.rgb +=
									environmentIntensity *
									sampleEquirectColor( envMapInfo.map, envRotation3x3 * ray.direction ) *
									state.throughputColor;

								#endif

							}
							break;

						}

						uint materialIndex = uTexelFetch1D( materialIndexAttribute, surfaceHit.faceIndices.x ).r;
						Material material = readMaterialInfo( materials, materialIndex );

						#if FEATURE_FOG

						if ( hitType == FOG_HIT ) {

							material = state.fogMaterial;
							state.accumulatedRoughness += 0.2;

						} else if ( material.fogVolume ) {

							state.fogMaterial = material;
							state.fogMaterial.fogVolume = surfaceHit.side == 1.0;

							ray.origin = stepRayOrigin( ray.origin, ray.direction, - surfaceHit.faceNormal, surfaceHit.dist );

							i -= sign( state.transmissiveTraversals );
							state.transmissiveTraversals -= sign( state.transmissiveTraversals );
							continue;

						}

						#endif

						// early out if this is a matte material
						if ( material.matte && state.firstRay ) {

							gl_FragColor = vec4( 0.0 );
							break;

						}

						// if we've determined that this is a shadow ray and we've hit an item with no shadow casting
						// then skip it
						if ( ! material.castShadow && state.isShadowRay ) {

							ray.origin = stepRayOrigin( ray.origin, ray.direction, - surfaceHit.faceNormal, surfaceHit.dist );
							continue;

						}

						SurfaceRecord surf;
						if (
							getSurfaceRecord(
								material, surfaceHit, attributesArray, state.accumulatedRoughness,
								surf
							) == SKIP_SURFACE
						) {

							// only allow a limited number of transparency discards otherwise we could
							// crash the context with too long a loop.
							i -= sign( state.transmissiveTraversals );
							state.transmissiveTraversals -= sign( state.transmissiveTraversals );

							ray.origin = stepRayOrigin( ray.origin, ray.direction, - surfaceHit.faceNormal, surfaceHit.dist );
							continue;

						}

						scatterRec = bsdfSample( - ray.direction, surf );
						state.isShadowRay = scatterRec.specularPdf < rand( 4 );

						bool isBelowSurface = ! surf.volumeParticle && dot( scatterRec.direction, surf.faceNormal ) < 0.0;
						vec3 hitPoint = stepRayOrigin( ray.origin, ray.direction, isBelowSurface ? - surf.faceNormal : surf.faceNormal, surfaceHit.dist );

						// next event estimation
						#if FEATURE_MIS

						gl_FragColor.rgb += directLightContribution( - ray.direction, surf, state, hitPoint );

						#endif

						// accumulate a roughness value to offset diffuse, specular, diffuse rays that have high contribution
						// to a single pixel resulting in fireflies
						// TODO: handle transmissive surfaces
						if ( ! surf.volumeParticle && ! isBelowSurface ) {

							// determine if this is a rough normal or not by checking how far off straight up it is
							vec3 halfVector = normalize( - ray.direction + scatterRec.direction );
							state.accumulatedRoughness += max(
								sin( acosApprox( dot( halfVector, surf.normal ) ) ),
								sin( acosApprox( dot( halfVector, surf.clearcoatNormal ) ) )
							);

							state.transmissiveRay = false;

						}

						// accumulate emissive color
						gl_FragColor.rgb += ( surf.emission * state.throughputColor );

						// skip the sample if our PDF or ray is impossible
						if ( scatterRec.pdf <= 0.0 || ! isDirectionValid( scatterRec.direction, surf.normal, surf.faceNormal ) ) {

							break;

						}

						// if we're bouncing around the inside a transmissive material then decrement
						// perform this separate from a bounce
						bool isTransmissiveRay = ! surf.volumeParticle && dot( scatterRec.direction, surf.faceNormal * surfaceHit.side ) < 0.0;
						if ( ( isTransmissiveRay || isBelowSurface ) && state.transmissiveTraversals > 0 ) {

							state.transmissiveTraversals --;
							i --;

						}

						//

						// handle throughput color transformation
						// attenuate the throughput color by the medium color
						if ( ! surf.frontFace ) {

							state.throughputColor *= transmissionAttenuation( surfaceHit.dist, surf.attenuationColor, surf.attenuationDistance );

						}

						#if FEATURE_RUSSIAN_ROULETTE

						// russian roulette path termination
						// https://www.arnoldrenderer.com/research/physically_based_shader_design_in_arnold.pdf
						uint minBounces = 3u;
						float depthProb = float( state.depth < minBounces );

						float rrProb = luminance( state.throughputColor * scatterRec.color / scatterRec.pdf );
						rrProb /= luminance( state.throughputColor );
						rrProb = sqrt( rrProb );
						rrProb = max( rrProb, depthProb );
						rrProb = min( rrProb, 1.0 );
						if ( rand( 8 ) > rrProb ) {

							break;

						}

						// perform sample clamping here to avoid bright pixels
						state.throughputColor *= min( 1.0 / rrProb, 20.0 );

						#endif

						// adjust the throughput and discard and exit if we find discard the sample if there are any NaNs
						state.throughputColor *= scatterRec.color / scatterRec.pdf;
						if ( any( isnan( state.throughputColor ) ) || any( isinf( state.throughputColor ) ) ) {

							break;

						}

						//

						// prepare for next ray
						ray.direction = scatterRec.direction;
						ray.origin = hitPoint;

					}

					gl_FragColor.a *= opacity;

					#if DEBUG_MODE == 1

					// output the number of rays checked in the path and number of
					// transmissive rays encountered.
					gl_FragColor.rgb = vec3(
						float( state.depth ),
						transmissiveBounces - state.transmissiveTraversals,
						0.0
					);
					gl_FragColor.a = 1.0;

					#endif

				}

			`}),this.setValues(e)}};function*wa(){let{_renderer:i,_fsQuad:e,_blendQuad:t,_primaryTarget:r,_blendTargets:n,_sobolTarget:s,_subframe:o,alpha:l,material:u}=this,m=new we,p=new we,f=t.material,[a,h]=n;for(;;){l?(f.opacity=this._opacityFactor/(this.samples+1),u.blending=xe,u.opacity=1):(u.opacity=this._opacityFactor/(this.samples+1),u.blending=Vt);let[g,T,d,b]=o,x=r.width,v=r.height;u.resolution.set(x*d,v*b),u.sobolTexture=s.texture,u.stratifiedTexture.init(20,u.bounces+u.transmissiveBounces+5),u.stratifiedTexture.next(),u.seed++;let y=this.tiles.x||1,S=this.tiles.y||1,w=y*S,_=Math.ceil(x*d),I=Math.ceil(v*b),F=Math.floor(g*x),A=Math.floor(T*v),C=Math.ceil(_/y),R=Math.ceil(I/S);for(let M=0;M<S;M++)for(let B=0;B<y;B++){let D=i.getRenderTarget(),Y=i.autoClear,qe=i.getScissorTest();i.getScissor(m),i.getViewport(p);let Ye=B,gt=M;if(!this.stableTiles){let Be=this._currentTile%(y*S);Ye=Be%y,gt=~~(Be/y),this._currentTile=Be+1}let Xe=S-gt-1;r.scissor.set(F+Ye*C,A+Xe*R,Math.min(C,_-Ye*C),Math.min(R,I-Xe*R)),r.viewport.set(F,A,_,I),i.setRenderTarget(r),i.setScissorTest(!0),i.autoClear=!1,e.render(i),i.setViewport(p),i.setScissor(m),i.setScissorTest(qe),i.setRenderTarget(D),i.autoClear=Y,l&&(f.target1=a.texture,f.target2=r.texture,i.setRenderTarget(h),t.render(i),i.setRenderTarget(D)),this.samples+=1/w,B===y-1&&M===S-1&&(this.samples=Math.round(this.samples)),yield}[a,h]=[h,a]}}var ls=new he,ht=class{get material(){return this._fsQuad.material}set material(e){this._fsQuad.material.removeEventListener("recompilation",this._compileFunction),e.addEventListener("recompilation",this._compileFunction),this._fsQuad.material=e}get target(){return this._alpha?this._blendTargets[1]:this._primaryTarget}set alpha(e){this._alpha!==e&&(e||(this._blendTargets[0].dispose(),this._blendTargets[1].dispose()),this._alpha=e,this.reset())}get alpha(){return this._alpha}get isCompiling(){return!!this._compilePromise}constructor(e){this.camera=null,this.tiles=new X(3,3),this.stableNoise=!1,this.stableTiles=!0,this.samples=0,this._subframe=new we(0,0,1,1),this._opacityFactor=1,this._renderer=e,this._alpha=!1,this._fsQuad=new ie(new Lt),this._blendQuad=new ie(new Fr),this._task=null,this._currentTile=0,this._compilePromise=null,this._sobolTarget=new Br().generate(e),this._primaryTarget=new ye(1,1,{format:L,type:G,magFilter:U,minFilter:U}),this._blendTargets=[new ye(1,1,{format:L,type:G,magFilter:U,minFilter:U}),new ye(1,1,{format:L,type:G,magFilter:U,minFilter:U})],this._compileFunction=()=>{let t=this.compileMaterial(this._fsQuad._mesh);t.then(()=>{this._compilePromise===t&&(this._compilePromise=null)}),this._compilePromise=t},this.material.addEventListener("recompilation",this._compileFunction)}compileMaterial(){return this._renderer.compileAsync(this._fsQuad._mesh)}setCamera(e){let{material:t}=this;t.cameraWorldMatrix.copy(e.matrixWorld),t.invProjectionMatrix.copy(e.projectionMatrixInverse),t.physicalCamera.updateFrom(e);let r=0;e.projectionMatrix.elements[15]>0&&(r=1),e.isEquirectCamera&&(r=2),t.setDefine("CAMERA_TYPE",r),this.camera=e}setSize(e,t){e=Math.ceil(e),t=Math.ceil(t),!(this._primaryTarget.width===e&&this._primaryTarget.height===t)&&(this._primaryTarget.setSize(e,t),this._blendTargets[0].setSize(e,t),this._blendTargets[1].setSize(e,t),this.reset())}getSize(e){e.x=this._primaryTarget.width,e.y=this._primaryTarget.height}dispose(){this._primaryTarget.dispose(),this._blendTargets[0].dispose(),this._blendTargets[1].dispose(),this._sobolTarget.dispose(),this._fsQuad.dispose(),this._blendQuad.dispose(),this._task=null}reset(){let{_renderer:e,_primaryTarget:t,_blendTargets:r}=this,n=e.getRenderTarget(),s=e.getClearAlpha();e.getClearColor(ls),e.setRenderTarget(t),e.setClearColor(0,0),e.clearColor(),e.setRenderTarget(r[0]),e.setClearColor(0,0),e.clearColor(),e.setRenderTarget(r[1]),e.setClearColor(0,0),e.clearColor(),e.setClearColor(ls,s),e.setRenderTarget(n),this.samples=0,this._task=null,this.material.stratifiedTexture.stableNoise=this.stableNoise,this.stableNoise&&(this.material.seed=0,this.material.stratifiedTexture.reset())}update(){this.material.onBeforeRender(),!this.isCompiling&&(this._task||(this._task=wa.call(this)),this._task.next())}};var We=new X,us=new X,Xr=new gi,$r=new he,Nt=class extends ${constructor(e=512,t=512){super(new Float32Array(e*t*4),e,t,L,G,je,fe,ce,re,re),this.generationCallback=null}update(){this.dispose(),this.needsUpdate=!0;let{data:e,width:t,height:r}=this.image;for(let n=0;n<t;n++)for(let s=0;s<r;s++){us.set(t,r),We.set(n/t,s/r),We.x-=.5,We.y=1-We.y,Xr.theta=We.x*2*Math.PI,Xr.phi=We.y*Math.PI,Xr.radius=1,this.generationCallback(Xr,We,us,$r);let l=4*(s*t+n);e[l+0]=$r.r,e[l+1]=$r.g,e[l+2]=$r.b,e[l+3]=1}}copy(e){return super.copy(e),this.generationCallback=e.generationCallback,this}};var fs=new P,Ot=class extends Nt{constructor(e=512){super(e,e),this.topColor=new he().set(16777215),this.bottomColor=new he().set(0),this.exponent=2,this.generationCallback=(t,r,n,s)=>{fs.setFromSpherical(t);let o=fs.y*.5+.5;s.lerpColors(this.bottomColor,this.topColor,o**this.exponent)}}copy(e){return super.copy(e),this.topColor.copy(e.topColor),this.bottomColor.copy(e.bottomColor),this}};var jr=class extends _e{get map(){return this.uniforms.map.value}set map(e){this.uniforms.map.value=e}get opacity(){return this.uniforms.opacity.value}set opacity(e){this.uniforms&&(this.uniforms.opacity.value=e)}constructor(e){super({uniforms:{map:{value:null},opacity:{value:1}},vertexShader:`
				varying vec2 vUv;
				void main() {

					vUv = uv;
					gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );

				}
			`,fragmentShader:`
				uniform sampler2D map;
				uniform float opacity;
				varying vec2 vUv;

				vec4 clampedTexelFatch( sampler2D map, ivec2 px, int lod ) {

					vec4 res = texelFetch( map, ivec2( px.x, px.y ), 0 );

					#if defined( TONE_MAPPING )

					res.xyz = toneMapping( res.xyz );

					#endif

			  		return linearToOutputTexel( res );

				}

				void main() {

					vec2 size = vec2( textureSize( map, 0 ) );
					vec2 pxUv = vUv * size;
					vec2 pxCurr = floor( pxUv );
					vec2 pxFrac = fract( pxUv ) - 0.5;
					vec2 pxOffset;
					pxOffset.x = pxFrac.x > 0.0 ? 1.0 : - 1.0;
					pxOffset.y = pxFrac.y > 0.0 ? 1.0 : - 1.0;

					vec2 pxNext = clamp( pxOffset + pxCurr, vec2( 0.0 ), size - 1.0 );
					vec2 alpha = abs( pxFrac );

					vec4 p1 = mix(
						clampedTexelFatch( map, ivec2( pxCurr.x, pxCurr.y ), 0 ),
						clampedTexelFatch( map, ivec2( pxNext.x, pxCurr.y ), 0 ),
						alpha.x
					);

					vec4 p2 = mix(
						clampedTexelFatch( map, ivec2( pxCurr.x, pxNext.y ), 0 ),
						clampedTexelFatch( map, ivec2( pxNext.x, pxNext.y ), 0 ),
						alpha.x
					);

					gl_FragColor = mix( p1, p2, alpha.y );
					gl_FragColor.a *= opacity;
					#include <premultiplied_alpha_fragment>

				}
			`}),this.setValues(e)}};var Ho=class extends _e{constructor(){super({uniforms:{envMap:{value:null},flipEnvMap:{value:-1}},vertexShader:`
				varying vec2 vUv;
				void main() {

					vUv = uv;
					gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );

				}`,fragmentShader:`
				#define ENVMAP_TYPE_CUBE_UV

				uniform samplerCube envMap;
				uniform float flipEnvMap;
				varying vec2 vUv;

				#include <common>
				#include <cube_uv_reflection_fragment>

				${dt}

				void main() {

					vec3 rayDirection = equirectUvToDirection( vUv );
					rayDirection.x *= flipEnvMap;
					gl_FragColor = textureCube( envMap, rayDirection );

				}`}),this.depthWrite=!1,this.depthTest=!1}},Gt=class{constructor(e){this._renderer=e,this._quad=new ie(new Ho)}generate(e,t=null,r=null){if(!e.isCubeTexture)throw new Error("CubeToEquirectMaterial: Source can only be cube textures.");let n=e.images[0],s=this._renderer,o=this._quad;t===null&&(t=4*n.height),r===null&&(r=2*n.height);let l=new ye(t,r,{type:G,colorSpace:n.colorSpace}),u=n.height,m=Math.log2(u)-2,p=1/u,f=1/(3*Math.max(Math.pow(2,m),7*16));o.material.defines.CUBEUV_MAX_MIP=`${m}.0`,o.material.defines.CUBEUV_TEXEL_WIDTH=f,o.material.defines.CUBEUV_TEXEL_HEIGHT=p,o.material.uniforms.envMap.value=e,o.material.uniforms.flipEnvMap.value=e.isRenderTargetTexture?1:-1,o.material.needsUpdate=!0;let a=s.getRenderTarget(),h=s.autoClear;s.autoClear=!0,s.setRenderTarget(l),o.render(s),s.setRenderTarget(a),s.autoClear=h;let g=new Uint16Array(t*r*4),T=new Float32Array(t*r*4);s.readRenderTargetPixels(l,0,0,t,r,T),l.dispose();for(let b=0,x=T.length;b<x;b++)g[b]=ne.toHalfFloat(T[b]);let d=new $(g,t,r,L,te);return d.minFilter=oi,d.magFilter=re,d.wrapS=fe,d.wrapT=fe,d.mapping=je,d.needsUpdate=!0,d}dispose(){this._quad.dispose()}};function Aa(i){return i.extensions.get("EXT_float_blend")}var xt=new X,Vo=class{get multipleImportanceSampling(){return!!this._pathTracer.material.defines.FEATURE_MIS}set multipleImportanceSampling(e){this._pathTracer.material.setDefine("FEATURE_MIS",e?1:0)}get transmissiveBounces(){return this._pathTracer.material.transmissiveBounces}set transmissiveBounces(e){this._pathTracer.material.transmissiveBounces=e}get bounces(){return this._pathTracer.material.bounces}set bounces(e){this._pathTracer.material.bounces=e}get filterGlossyFactor(){return this._pathTracer.material.filterGlossyFactor}set filterGlossyFactor(e){this._pathTracer.material.filterGlossyFactor=e}get samples(){return this._pathTracer.samples}get target(){return this._pathTracer.target}get tiles(){return this._pathTracer.tiles}get stableNoise(){return this._pathTracer.stableNoise}set stableNoise(e){this._pathTracer.stableNoise=e}get isCompiling(){return!!this._pathTracer.isCompiling}constructor(e){this._renderer=e,this._generator=new Ve,this._pathTracer=new ht(e),this._queueReset=!1,this._clock=new ti,this._compilePromise=null,this._lowResPathTracer=new ht(e),this._lowResPathTracer.tiles.set(1,1),this._quad=new ie(new jr({map:null,transparent:!0,blending:xe,premultipliedAlpha:e.getContextAttributes().premultipliedAlpha})),this._materials=null,this._previousEnvironment=null,this._previousBackground=null,this._internalBackground=null,this.renderDelay=100,this.minSamples=5,this.fadeDuration=500,this.enablePathTracing=!0,this.pausePathTracing=!1,this.dynamicLowRes=!1,this.lowResScale=.25,this.renderScale=1,this.synchronizeRenderSize=!0,this.rasterizeScene=!0,this.renderToCanvas=!0,this.textureSize=new X(1024,1024),this.rasterizeSceneCallback=(t,r)=>{this._renderer.render(t,r)},this.renderToCanvasCallback=(t,r,n)=>{let s=r.autoClear;r.autoClear=!1,n.render(r),r.autoClear=s},this.setScene(new di,new Wt)}setBVHWorker(e){this._generator.setBVHWorker(e)}setScene(e,t,r={}){e.updateMatrixWorld(!0),t.updateMatrixWorld();let n=this._generator;if(n.setObjects(e),this._buildAsync)return n.generateAsync(r.onProgress).then(s=>this._updateFromResults(e,t,s));{let s=n.generate();return this._updateFromResults(e,t,s)}}setSceneAsync(...e){this._buildAsync=!0;let t=this.setScene(...e);return this._buildAsync=!1,t}setCamera(e){this.camera=e,this.updateCamera()}updateCamera(){let e=this.camera;e.updateMatrixWorld(),this._pathTracer.setCamera(e),this._lowResPathTracer.setCamera(e),this.reset()}updateMaterials(){let e=this._pathTracer.material,t=this._renderer,r=this._materials,n=this.textureSize,s=Pn(r);e.textures.setTextures(t,s,n.x,n.y),e.materials.updateFrom(r,s),this.reset()}updateLights(){let e=this.scene,t=this._renderer,r=this._pathTracer.material,n=Bn(e),s=Mn(n);r.lights.updateFrom(n,s),r.iesProfiles.setTextures(t,s),this.reset()}updateEnvironment(){let e=this.scene,t=this._pathTracer.material;if(this._internalBackground&&(this._internalBackground.dispose(),this._internalBackground=null),t.backgroundBlur=e.backgroundBlurriness,t.backgroundIntensity=e.backgroundIntensity??1,t.backgroundRotation.makeRotationFromEuler(e.backgroundRotation).invert(),e.background===null)t.backgroundMap=null,t.backgroundAlpha=0;else if(e.background.isColor){this._colorBackground=this._colorBackground||new Ot(16);let r=this._colorBackground;r.topColor.equals(e.background)||(r.topColor.set(e.background),r.bottomColor.set(e.background),r.update()),t.backgroundMap=r,t.backgroundAlpha=1}else if(e.background.isCubeTexture){if(e.background!==this._previousBackground){let r=new Gt(this._renderer).generate(e.background);this._internalBackground=r,t.backgroundMap=r,t.backgroundAlpha=1}}else t.backgroundMap=e.background,t.backgroundAlpha=1;if(t.environmentIntensity=e.environment!==null?e.environmentIntensity??1:0,t.environmentRotation.makeRotationFromEuler(e.environmentRotation).invert(),this._previousEnvironment!==e.environment&&e.environment!==null)if(e.environment.isCubeTexture){let r=new Gt(this._renderer).generate(e.environment);t.envMapInfo.updateFrom(r)}else t.envMapInfo.updateFrom(e.environment);this._previousEnvironment=e.environment,this._previousBackground=e.background,this.reset()}_updateFromResults(e,t,r){let{materials:n,geometry:s,bvh:o,bvhChanged:l,needsMaterialIndexUpdate:u}=r;this._materials=n;let p=this._pathTracer.material;return l&&(p.bvh.updateFrom(o),p.attributesArray.updateFrom(s.attributes.normal,s.attributes.tangent,s.attributes.uv,s.attributes.color)),u&&p.materialIndexAttribute.updateFrom(s.attributes.materialIndex),this._previousScene=e,this.scene=e,this.camera=t,this.updateCamera(),this.updateMaterials(),this.updateEnvironment(),this.updateLights(),r}renderSample(){let e=this._lowResPathTracer,t=this._pathTracer,r=this._renderer,n=this._clock,s=this._quad;this._updateScale(),this._queueReset&&(t.reset(),e.reset(),this._queueReset=!1,s.material.opacity=0,n.start());let o=n.getDelta()*1e3,l=n.getElapsedTime()*1e3;if(!this.pausePathTracing&&this.enablePathTracing&&this.renderDelay<=l&&!this.isCompiling&&t.update(),t.alpha=t.material.backgroundAlpha!==1||!Aa(r),e.alpha=t.alpha,this.renderToCanvas){let u=this._renderer,m=this.minSamples;if(l>=this.renderDelay&&this.samples>=this.minSamples&&(this.fadeDuration!==0?s.material.opacity=Math.min(s.material.opacity+o/this.fadeDuration,1):s.material.opacity=1),!this.enablePathTracing||this.samples<m||s.material.opacity<1){if(this.dynamicLowRes&&!this.isCompiling){e.samples<1&&(e.material=t.material,e.update());let p=s.material.opacity;s.material.opacity=1-s.material.opacity,s.material.map=e.target.texture,s.render(u),s.material.opacity=p}(!this.dynamicLowRes&&this.rasterizeScene||this.dynamicLowRes&&this.isCompiling)&&this.rasterizeSceneCallback(this.scene,this.camera)}this.enablePathTracing&&s.material.opacity>0&&(s.material.opacity<1&&(s.material.blending=this.dynamicLowRes?Jo:Vt),s.material.map=t.target.texture,this.renderToCanvasCallback(t.target,u,s),s.material.blending=xe)}}reset(){this._queueReset=!0,this._pathTracer.samples=0}dispose(){this._quad.dispose(),this._quad.material.dispose(),this._pathTracer.dispose()}_updateScale(){if(this.synchronizeRenderSize){this._renderer.getDrawingBufferSize(xt);let e=Math.floor(this.renderScale*xt.x),t=Math.floor(this.renderScale*xt.y);if(this._pathTracer.getSize(xt),xt.x!==e||xt.y!==t){let r=this.lowResScale;this._pathTracer.setSize(e,t),this._lowResPathTracer.setSize(Math.floor(e*r),Math.floor(t*r))}}}};var Wo=class extends ei{constructor(){super(),this.isEquirectCamera=!0}};var qo=class extends vi{constructor(...e){super(...e),this.iesMap=null,this.radius=0}copy(e,t){return super.copy(e,t),this.iesMap=e.iesMap,this.radius=e.radius,this}};var Yo=class extends pi{constructor(...e){super(...e),this.isCircular=!1}copy(e,t){return super.copy(e,t),this.isCircular=e.isCircular,this}};var Xo=class extends de{constructor(){super({uniforms:{envMap:{value:null},blur:{value:0}},vertexShader:`

				varying vec2 vUv;
				void main() {
					vUv = uv;
					gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
				}

			`,fragmentShader:`

				#include <common>
				#include <cube_uv_reflection_fragment>

				${dt}

				uniform sampler2D envMap;
				uniform float blur;
				varying vec2 vUv;
				void main() {

					vec3 rayDirection = equirectUvToDirection( vUv );
					gl_FragColor = textureCubeUV( envMap, rayDirection, blur );

				}

			`})}},$o=class{constructor(e){this.renderer=e,this.pmremGenerator=new li(e),this.copyQuad=new ie(new Xo),this.renderTarget=new ye(1,1,{type:G,format:L})}dispose(){this.pmremGenerator.dispose(),this.copyQuad.dispose(),this.renderTarget.dispose()}generate(e,t){let{pmremGenerator:r,renderTarget:n,copyQuad:s,renderer:o}=this,l=r.fromEquirectangular(e),{width:u,height:m}=e.image;n.setSize(u,m),s.material.envMap=l.texture,s.material.blur=t;let p=o.getRenderTarget(),f=o.autoClear;o.setRenderTarget(n),o.autoClear=!0,s.render(o),o.setRenderTarget(p),o.autoClear=f;let a=new Uint16Array(u*m*4),h=new Float32Array(u*m*4);o.readRenderTargetPixels(n,0,0,u,m,h);for(let T=0,d=h.length;T<d;T++)a[T]=ne.toHalfFloat(h[T]);let g=new $(a,u,m,L,te);return g.minFilter=e.minFilter,g.magFilter=e.magFilter,g.wrapS=e.wrapS,g.wrapT=e.wrapT,g.mapping=je,g.needsUpdate=!0,l.dispose(),g}};var jo=class extends de{constructor(e){super({blending:xe,transparent:!1,depthWrite:!1,depthTest:!1,defines:{USE_SLIDER:0},uniforms:{sigma:{value:5},threshold:{value:.03},kSigma:{value:1},map:{value:null},opacity:{value:1}},vertexShader:`

				varying vec2 vUv;

				void main() {

					vUv = uv;
					gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );

				}

			`,fragmentShader:`

				//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
				//  Copyright (c) 2018-2019 Michele Morrone
				//  All rights reserved.
				//
				//  https://michelemorrone.eu - https://BrutPitt.com
				//
				//  me@michelemorrone.eu - brutpitt@gmail.com
				//  twitter: @BrutPitt - github: BrutPitt
				//
				//  https://github.com/BrutPitt/glslSmartDeNoise/
				//
				//  This software is distributed under the terms of the BSD 2-Clause license
				//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

				uniform sampler2D map;

				uniform float sigma;
				uniform float threshold;
				uniform float kSigma;
				uniform float opacity;

				varying vec2 vUv;

				#define INV_SQRT_OF_2PI 0.39894228040143267793994605993439
				#define INV_PI 0.31830988618379067153776752674503

				// Parameters:
				//	 sampler2D tex	 - sampler image / texture
				//	 vec2 uv		   - actual fragment coord
				//	 float sigma  >  0 - sigma Standard Deviation
				//	 float kSigma >= 0 - sigma coefficient
				//		 kSigma * sigma  -->  radius of the circular kernel
				//	 float threshold   - edge sharpening threshold
				vec4 smartDeNoise( sampler2D tex, vec2 uv, float sigma, float kSigma, float threshold ) {

					float radius = round( kSigma * sigma );
					float radQ = radius * radius;

					float invSigmaQx2 = 0.5 / ( sigma * sigma );
					float invSigmaQx2PI = INV_PI * invSigmaQx2;

					float invThresholdSqx2 = 0.5 / ( threshold * threshold );
					float invThresholdSqrt2PI = INV_SQRT_OF_2PI / threshold;

					vec4 centrPx = texture2D( tex, uv );
					centrPx.rgb *= centrPx.a;

					float zBuff = 0.0;
					vec4 aBuff = vec4( 0.0 );
					vec2 size = vec2( textureSize( tex, 0 ) );

					vec2 d;
					for ( d.x = - radius; d.x <= radius; d.x ++ ) {

						float pt = sqrt( radQ - d.x * d.x );

						for ( d.y = - pt; d.y <= pt; d.y ++ ) {

							float blurFactor = exp( - dot( d, d ) * invSigmaQx2 ) * invSigmaQx2PI;

							vec4 walkPx = texture2D( tex, uv + d / size );
							walkPx.rgb *= walkPx.a;

							vec4 dC = walkPx - centrPx;
							float deltaFactor = exp( - dot( dC.rgba, dC.rgba ) * invThresholdSqx2 ) * invThresholdSqrt2PI * blurFactor;

							zBuff += deltaFactor;
							aBuff += deltaFactor * walkPx;

						}

					}

					return aBuff / zBuff;

				}

				void main() {

					gl_FragColor = smartDeNoise( map, vec2( vUv.x, vUv.y ), sigma, kSigma, threshold );
					#include <tonemapping_fragment>
					#include <colorspace_fragment>
					#include <premultiplied_alpha_fragment>

					gl_FragColor.a *= opacity;

				}

			`}),this.setValues(e)}};var Qo=class extends si{constructor(e){super(e),this.isFogVolumeMaterial=!0,this.density=.015,this.emissive=new he,this.emissiveIntensity=0,this.opacity=.15,this.transparent=!0,this.roughness=1,this.metalness=0,this.setValues(e)}};return Ss(Ra);})();
