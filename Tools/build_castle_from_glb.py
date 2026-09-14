"""Direct, non-decimating glTF -> USDZ conversion for the supplied castle.
Requires numpy, Pillow, usd-core. Usage: python Tools/build_castle_from_glb.py FILE.glb
Preserves every triangle of the castle assembly; excludes detached export debris.
"""
from pathlib import Path
import hashlib, io, json, struct, sys, tempfile, zipfile
import numpy as np
from PIL import Image
from pxr import Usd, UsdGeom, UsdShade, Sdf, Gf, Vt

ROOT = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1]); blob = source.read_bytes()
assert struct.unpack_from('<4sII', blob) == (b'glTF', 2, len(blob))
length = struct.unpack_from('<I', blob, 12)[0]
doc = json.loads(blob[20:20+length]); binary_start = 28+length
assert set(doc.get('extensionsRequired', [])) <= {'KHR_texture_transform'}

def read_accessor(index):
    a = doc['accessors'][index]; assert 'sparse' not in a
    view = doc['bufferViews'][a['bufferView']]
    dtype = np.dtype({5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']])
    width = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    return np.ndarray((a['count'],width), dtype=dtype, buffer=blob,
        offset=binary_start+view.get('byteOffset',0)+a.get('byteOffset',0),
        strides=(view.get('byteStride',width*dtype.itemsize),dtype.itemsize)).copy()

parts=[]; omitted=[]
def visit(index, parent):
    node=doc['nodes'][index]
    if 'matrix' in node: local=np.array(node['matrix']).reshape(4,4).T
    else:
        x,y,z,w=node.get('rotation',[0,0,0,1]); local=np.eye(4)
        local[:3,:3]=np.array([[1-2*y*y-2*z*z,2*x*y-2*z*w,2*x*z+2*y*w],
            [2*x*y+2*z*w,1-2*x*x-2*z*z,2*y*z-2*x*w],
            [2*x*z-2*y*w,2*y*z+2*x*w,1-2*x*x-2*y*y]])@np.diag(node.get('scale',[1,1,1]))
        local[:3,3]=node.get('translation',[0,0,0])
    world=parent@local
    if 'mesh' in node:
        for part_index, primitive in enumerate(doc['meshes'][node['mesh']]['primitives']):
            assert primitive.get('mode',4)==4
            positions=read_accessor(primitive['attributes']['POSITION'])@world[:3,:3].T+world[:3,3]
            midpoint=(positions.min(0)+positions.max(0))/2
            if midpoint[1]<100 or midpoint[0]<-40:
                omitted.append({'node':node.get('name',str(index)),'primitive':part_index}); continue
            normals=read_accessor(primitive['attributes']['NORMAL'])@np.linalg.inv(world[:3,:3])
            normals/=np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-9)
            uv=read_accessor(primitive['attributes']['TEXCOORD_0']) if 'TEXCOORD_0' in primitive['attributes'] else None
            indices=read_accessor(primitive['indices']).ravel().reshape(-1,3)
            if np.linalg.det(world[:3,:3])<0:indices=indices[:,[0,2,1]]
            parts.append((node.get('name',str(index)),positions,normals,uv,indices,primitive.get('material')))
    for child in node.get('children',[]): visit(child,world)
for index in doc['scenes'][doc.get('scene',0)]['nodes']:visit(index,np.eye(4))
lo=np.min([p[1].min(0) for p in parts],0);hi=np.max([p[1].max(0) for p in parts],0)
scale=52/max((hi-lo)[[0,2]]); origin=(lo+hi)/2;origin[1]=lo[1]
stage=Usd.Stage.CreateInMemory();root=UsdGeom.Xform.Define(stage,'/Castle');stage.SetDefaultPrim(root.GetPrim())
UsdGeom.SetStageUpAxis(stage,UsdGeom.Tokens.y);UsdGeom.SetStageMetersPerUnit(stage,1)
materials={}; image_payloads={}; image_report=[]
for index,item in enumerate(doc['images']):
    view=doc['bufferViews'][item['bufferView']];offset=binary_start+view.get('byteOffset',0)
    image=Image.open(io.BytesIO(blob[offset:offset+view['byteLength']])).convert('RGB')
    original_size=image.size;image.thumbnail((1024,1024),Image.Resampling.LANCZOS)
    encoded=io.BytesIO();image.save(encoded,format='JPEG',quality=95,subsampling=0)
    name=f'textures/castle_{index:02d}.jpg';image_payloads[name]=encoded.getvalue()
    image_report.append({'name':item.get('name'),'path':name,'source_size':original_size,'runtime_size':image.size})

for index,item in enumerate(doc['materials']):
    path=f'/Castle/Materials/Material_{index}';mat=UsdShade.Material.Define(stage,path)
    mat.GetPrim().SetDisplayName(item.get('name',str(index)))
    shader=UsdShade.Shader.Define(stage,path+'/Surface');shader.CreateIdAttr('UsdPreviewSurface')
    shader.CreateOutput('surface',Sdf.ValueTypeNames.Token);mat.CreateSurfaceOutput().ConnectToSource(shader.ConnectableAPI(),'surface')
    pbr=item.get('pbrMetallicRoughness',{});color=pbr.get('baseColorFactor',[1,1,1,1])
    shader.CreateInput('diffuseColor',Sdf.ValueTypeNames.Color3f).Set(Gf.Vec3f(*color[:3]))
    shader.CreateInput('roughness',Sdf.ValueTypeNames.Float).Set(pbr.get('roughnessFactor',1))
    shader.CreateInput('metallic',Sdf.ValueTypeNames.Float).Set(pbr.get('metallicFactor',1))
    assert item.get('alphaMode','OPAQUE')=='OPAQUE'
    for role,info in [('albedo',pbr.get('baseColorTexture')),('normal',item.get('normalTexture')),('orm',pbr.get('metallicRoughnessTexture'))]:
        if not info or info.get('texCoord',0)==-1:continue
        assert info.get('texCoord',0)==0
        # Bake each slot's transformed UVs into an explicit mesh primvar. This
        # avoids importer-dependent UsdTransform2d handling and name retargeting.
        reader=UsdShade.Shader.Define(stage,path+'/'+role+'UV');reader.CreateIdAttr('UsdPrimvarReader_float2')
        reader.CreateInput('varname',Sdf.ValueTypeNames.Token).Set('st_'+role)
        reader.CreateOutput('result',Sdf.ValueTypeNames.Float2)
        tex=UsdShade.Shader.Define(stage,path+'/'+role);tex.CreateIdAttr('UsdUVTexture')
        image_index=doc['textures'][info['index']]['source']
        tex.CreateInput('file',Sdf.ValueTypeNames.Asset).Set(Sdf.AssetPath(f'textures/castle_{image_index:02d}.jpg'))
        tex.CreateInput('st',Sdf.ValueTypeNames.Float2).ConnectToSource(reader.ConnectableAPI(),'result')
        tex.CreateInput('sourceColorSpace',Sdf.ValueTypeNames.Token).Set('sRGB' if role=='albedo' else 'raw')
        for axis in ['S','T']:tex.CreateInput('wrap'+axis,Sdf.ValueTypeNames.Token).Set('repeat')
        for channel,typ in [('rgb',Sdf.ValueTypeNames.Float3),('g',Sdf.ValueTypeNames.Float),('b',Sdf.ValueTypeNames.Float)]:tex.CreateOutput(channel,typ)
        if role=='albedo':
            tex.CreateInput('scale',Sdf.ValueTypeNames.Float4).Set(Gf.Vec4f(*color))
            shader.GetInput('diffuseColor').ConnectToSource(tex.ConnectableAPI(),'rgb')
        elif role=='normal':
            strength=info.get('scale',1)
            tex.CreateInput('scale',Sdf.ValueTypeNames.Float4).Set(Gf.Vec4f(2*strength,2*strength,2,1))
            tex.CreateInput('bias',Sdf.ValueTypeNames.Float4).Set(Gf.Vec4f(-strength,-strength,-1,0))
            shader.CreateInput('normal',Sdf.ValueTypeNames.Normal3f).ConnectToSource(tex.ConnectableAPI(),'rgb')
        else:
            tex.CreateInput('scale',Sdf.ValueTypeNames.Float4).Set(Gf.Vec4f(1,pbr.get('roughnessFactor',1),pbr.get('metallicFactor',1),1))
            shader.GetInput('roughness').ConnectToSource(tex.ConnectableAPI(),'g');shader.GetInput('metallic').ConnectToSource(tex.ConnectableAPI(),'b')
    materials[index]=mat

triangle_count=0;max_error=0
for i,(name,points,normals,uv,indices,material_index) in enumerate(parts):
    mesh=UsdGeom.Mesh.Define(stage,f'/Castle/Geometry/Part_{i}');mesh.GetPrim().SetDisplayName(name)
    converted=((points-origin)*scale).astype(np.float32)
    max_error=max(max_error,float(np.abs((converted/scale+origin)-points).max()))
    mesh.CreatePointsAttr(Vt.Vec3fArray.FromNumpy(converted))
    mesh.CreateNormalsAttr(Vt.Vec3fArray.FromNumpy(normals.astype(np.float32)));mesh.SetNormalsInterpolation('vertex')
    mesh.CreateFaceVertexCountsAttr([3]*len(indices));mesh.CreateFaceVertexIndicesAttr(indices.ravel().tolist())
    mesh.CreateSubdivisionSchemeAttr('none');triangle_count+=len(indices)
    mesh.CreateExtentAttr(Vt.Vec3fArray.FromNumpy(np.array([converted.min(0),converted.max(0)])))
    if material_index is not None:
        item=doc['materials'][material_index];mesh.CreateDoubleSidedAttr(item.get('doubleSided',False))
        UsdShade.MaterialBindingAPI.Apply(mesh.GetPrim()).Bind(materials[material_index])
        if uv is not None:
            pbr=item.get('pbrMetallicRoughness',{})
            for role,info in [('albedo',pbr.get('baseColorTexture')),('normal',item.get('normalTexture')),('orm',pbr.get('metallicRoughnessTexture'))]:
                if not info or info.get('texCoord',0)==-1:continue
                transform=info.get('extensions',{}).get('KHR_texture_transform',{});assert transform.get('rotation',0)==0
                assert transform.get('texCoord',0)==0
                coords=uv*np.array(transform.get('scale',[1,1]))+np.array(transform.get('offset',[0,0]))
                coords[:,1]=1-coords[:,1]
                UsdGeom.PrimvarsAPI(mesh).CreatePrimvar('st_'+role,Sdf.ValueTypeNames.TexCoord2fArray,'vertex').Set(Vt.Vec2fArray.FromNumpy(coords.astype(np.float32)))

output=ROOT/'Resources/Castle.usdz'
# USDZ uses stored entries aligned to 64-byte boundaries, with the USD first.
def add(archive,name,payload):
    info=zipfile.ZipInfo(name);info.compress_type=zipfile.ZIP_STORED
    padding=(-(archive.fp.tell()+30+len(name.encode())+4))%64
    info.extra=struct.pack('<HH',0x1986,padding)+bytes(padding)
    archive.writestr(info,payload)
with tempfile.TemporaryDirectory() as directory:
    binary=Path(directory)/'Castle.usdc';stage.GetRootLayer().Export(str(binary))
    with zipfile.ZipFile(output,'w') as archive:
        add(archive,'Castle.usdc',binary.read_bytes())
        for name,payload in image_payloads.items():add(archive,name,payload)
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    with output.open('rb') as f:
        for info in archive.infolist():
            f.seek(info.header_offset+26);a,b=struct.unpack('<HH',f.read(4));assert (info.header_offset+30+a+b)%64==0
check=Usd.Stage.Open(str(output));assert check
for prim in check.Traverse():
    for attribute in prim.GetAttributes():
        if attribute.GetTypeName()==Sdf.ValueTypeNames.Asset:assert attribute.Get().resolvedPath
assert max_error<0.001
report={'source_file':source.name,'source_sha256':hashlib.sha256(blob).hexdigest(),
 'runtime_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'runtime_meshes':len(parts),
 'retained_triangles':triangle_count,'removed_triangles_from_retained_meshes':0,'maximum_round_trip_position_error':max_error,
 'uniform_scale':scale,'source_origin':origin.tolist(),'runtime_size':((hi-lo)*scale).tolist(),
 'excluded_detached_primitives':omitted,'texture_images':len(image_report),'images':image_report,
 'note':'Direct latest GLB conversion; original topology, normals, slot UV transforms and material indices preserved.'}
(ROOT/'SourceAssets/castle-direct-import.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ['images','excluded_detached_primitives']},indent=2));print('bytes',output.stat().st_size)
