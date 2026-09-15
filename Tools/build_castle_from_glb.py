"""Repair and convert the supplied castle GLB to the runtime USDZ.
Requires numpy, Pillow, usd-core, trimesh, networkx. Usage: python Tools/build_castle_from_glb.py FILE.glb
Preserves the exterior assembly, with explicit door/interior cuts and surface repairs.
"""
from pathlib import Path
import hashlib, io, json, struct, sys, tempfile, zipfile
import numpy as np
from PIL import Image
from pxr import Usd, UsdGeom, UsdShade, Sdf, Gf, Vt
from castle_repairs import replacement, cut_portals, fix_winding, projected_uv, tile_size, interior_parts

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
    encoded=io.BytesIO();image.save(encoded,format='JPEG',quality=92 if index%3==1 else 88,subsampling=0)
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

triangle_count=0;max_error=0;opened_gates=0
repair_report=[];winding_repairs=0;projected_faces=0;portal_edits=[]
source_count=len(parts);source_triangles=sum(len(part[4]) for part in parts)
# Interior meshes are authored in the normalized asset frame.
extra=interior_parts()
parts += [(name,points/scale+origin,normals,uv,indices,mi) for name,points,normals,uv,indices,mi in extra]
for i,(name,points,normals,uv,indices,original_material) in enumerate(parts):
    mesh=UsdGeom.Mesh.Define(stage,f'/Castle/Geometry/Part_{i}');mesh.GetPrim().SetDisplayName(name)
    converted=((points-origin)*scale).astype(np.float32)
    max_error=max(max_error,float(np.abs((converted/scale+origin)-points).max()))
    if name == 'Plane.062':
        hinge=converted.min(0).copy()
        rotation=np.array([[0,0,-1],[0,1,0],[1,0,0]],dtype=np.float32)
        converted=(converted-hinge)@rotation.T+hinge
        normals=normals@rotation.T;opened_gates+=1
    mi=replacement(name,original_material);item=doc['materials'][mi]
    force_projection=(mi != original_material or uv is None or mi in [0,1,55,57,58,59,60,67])
    # Only the original shells are cut. New interior liners have explicit gaps.
    if i<source_count:
        converted,normals,uv,indices,edits=cut_portals(converted,normals,uv,indices)
        portal_edits.extend([dict(part=name,**edit) for edit in edits])
    if not len(converted):
        stage.RemovePrim(mesh.GetPath())
        continue
    if uv is None:uv=np.zeros((len(converted),2))
    converted,normals,oriented,flips=fix_winding(converted,normals,indices)
    uv=uv[oriented].reshape(-1,2);indices=np.arange(len(converted)).reshape(-1,3)
    winding_repairs+=flips
    t=uv.reshape(-1,3,2);a=t[:,1]-t[:,0];b=t[:,2]-t[:,0]
    bad=np.abs(a[:,0]*b[:,1]-a[:,1]*b[:,0])<1e-8
    if force_projection:bad[:]=True
    projected=projected_uv(converted,indices,tile_size(mi))
    projected_faces+=int(bad.sum())
    if force_projection or bad.any() or flips:
        repair_report.append({'part':name,'source_material':original_material,'runtime_material':mi,
                              'projected_faces':int(bad.sum()),'winding_fixes':flips})
    # Open shells and inward-facing export surfaces must also render from within.
    mesh.CreateDoubleSidedAttr(True)
    mesh.CreatePointsAttr(Vt.Vec3fArray.FromNumpy(converted.astype(np.float32)))
    normals/=np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-9)
    mesh.CreateNormalsAttr(Vt.Vec3fArray.FromNumpy(normals.astype(np.float32)));mesh.SetNormalsInterpolation('vertex')
    mesh.CreateFaceVertexCountsAttr([3]*len(indices));mesh.CreateFaceVertexIndicesAttr(indices.ravel().tolist())
    mesh.CreateSubdivisionSchemeAttr('none');triangle_count+=len(indices)
    mesh.CreateExtentAttr(Vt.Vec3fArray.FromNumpy(np.array([converted.min(0),converted.max(0)],dtype=np.float32)))
    UsdShade.MaterialBindingAPI.Apply(mesh.GetPrim()).Bind(materials[mi])
    pbr=item.get('pbrMetallicRoughness',{})
    for role,info in [('albedo',pbr.get('baseColorTexture')),('normal',item.get('normalTexture')),('orm',pbr.get('metallicRoughnessTexture'))]:
        if not info:continue
        assert info.get('texCoord',0)==0, (name,mi,role)
        transform=info.get('extensions',{}).get('KHR_texture_transform',{});assert transform.get('rotation',0)==0
        coords=uv*np.array(transform.get('scale',[1,1]))+np.array(transform.get('offset',[0,0]))
        coords[:,1]=1-coords[:,1]
        coords[np.repeat(bad,3)]=projected[np.repeat(bad,3)]
        UsdGeom.PrimvarsAPI(mesh).CreatePrimvar('st_'+role,Sdf.ValueTypeNames.TexCoord2fArray,'vertex').Set(Vt.Vec2fArray.FromNumpy(coords.astype(np.float32)))

assert opened_gates == 1
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
    if prim.IsA(UsdGeom.Mesh):
        material,_=UsdShade.MaterialBindingAPI(prim).ComputeBoundMaterial()
        assert material and material.ComputeSurfaceSource()[0], str(prim.GetPath())
    for attribute in prim.GetAttributes():
        if attribute.GetTypeName()==Sdf.ValueTypeNames.Asset:assert attribute.Get().resolvedPath
assert max_error<0.001
report={'source_file':source.name,'source_sha256':hashlib.sha256(blob).hexdigest(),
 'runtime_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'runtime_meshes':sum(prim.IsA(UsdGeom.Mesh) for prim in check.Traverse()),
 'source_assembly_meshes':source_count,'source_assembly_triangles':source_triangles,
 'runtime_triangles':triangle_count,'maximum_round_trip_position_error':max_error,
 'uniform_scale':scale,'source_origin':origin.tolist(),'runtime_size':((hi-lo)*scale).tolist(),
 'excluded_detached_primitives':omitted,'texture_images':len(image_report),'images':image_report,
 'explicit_default_material_bindings':0,'winding_repairs':winding_repairs,'projected_faces':projected_faces,
 'opened_gate_leaf':'Plane.062','portal_edits':portal_edits,'surface_repairs':repair_report,
 'interior_meshes':len(extra),'note':'Source architecture preserved with deliberate ground-floor portals, liners, floors and benches. Inward faces corrected; invalid UVs regenerated; missing materials mapped to existing texture sets. All meshes double-sided.'}
(ROOT/'SourceAssets/castle-direct-import.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ['images','excluded_detached_primitives','surface_repairs','portal_edits']},indent=2));print('bytes',output.stat().st_size)
