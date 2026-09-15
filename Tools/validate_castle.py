"""Validate material bindings and ground routes in the shipped asset, not Blender.
Requires usd-core and numpy. Native RealityKit/device verification is separate.
"""
from pathlib import Path
import hashlib, json, re
import numpy as np
from pxr import Usd, UsdGeom, UsdShade, Sdf
root=Path(__file__).resolve().parents[1];asset=root/'Resources/Castle.usdz'
report=json.loads((root/'SourceAssets/castle-navigation.json').read_text())
assert report['runtime_sha256']==hashlib.sha256(asset.read_bytes()).hexdigest()
swift=(root/'Game/CastleLayout.swift').read_text()
rows=re.findall(r'^            \[([^\]]+)\],$',swift,re.M)
assert [[float(n) for n in row.split(',')] for row in rows]==report['boxes']
assert f"courtyardHeight: Float = {report['courtyard_height']}" in swift
assert f"gateX: Float = {report['gate_x']}" in swift
assert f"spawnZ: Float = {report['spawn_z']}" in swift
stage=Usd.Stage.Open(str(asset));meshes=default=references=0
asset_report=json.loads((root/"SourceAssets/castle-direct-import.json").read_text())
for prim in stage.Traverse():
    for attr in prim.GetAttributes():
        if attr.GetTypeName()==Sdf.ValueTypeNames.Asset:
            assert attr.Get().resolvedPath,(prim.GetPath(),attr.GetName())
            references+=1
    if not prim.IsA(UsdGeom.Mesh):continue
    assert UsdGeom.Mesh(prim).GetDoubleSidedAttr().Get(), str(prim.GetPath())
    for attr in [UsdGeom.Mesh(prim).GetPointsAttr(),UsdGeom.Mesh(prim).GetNormalsAttr()]:
        assert np.isfinite(np.array(attr.Get())).all(),str(prim.GetPath())
    meshes+=1;mat,_=UsdShade.MaterialBindingAPI(prim).ComputeBoundMaterial()
    assert mat and mat.ComputeSurfaceSource()[0],str(prim.GetPath())
    default+=str(mat.GetPath()).endswith('/Unassigned')
    surface=mat.ComputeSurfaceSource()[0]
    if not surface.GetInput('diffuseColor').GetConnectedSource():
        assert str(mat.GetPath()).split('_')[-1] in ['53','54','56','61'],str(mat.GetPath())
    for shader in Usd.PrimRange(mat.GetPrim()):
        if shader.IsA(UsdShade.Shader) and UsdShade.Shader(shader).GetIdAttr().Get()=='UsdPrimvarReader_float2':
            name=UsdShade.Shader(shader).GetInput('varname').Get()
            uv=UsdGeom.PrimvarsAPI(prim).GetPrimvar(name)
            assert uv and len(uv.Get())==len(UsdGeom.Mesh(prim).GetPointsAttr().Get())
            coords=np.array(uv.Get());assert np.isfinite(coords).all()
            mesh=UsdGeom.Mesh(prim);faces=np.array(mesh.GetFaceVertexIndicesAttr().Get()).reshape(-1,3)
            tri=np.array(mesh.GetPointsAttr().Get())[faces];area=np.linalg.norm(np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]),axis=1)
            t=coords[faces];a=t[:,1]-t[:,0];b=t[:,2]-t[:,0]
            assert not np.any((area>1e-6)&(np.abs(a[:,0]*b[:,1]-a[:,1]*b[:,0])<1e-12)),str(prim.GetPath())
assert meshes==asset_report["runtime_meshes"] and default==0
boxes=np.array(report['boxes']);radius=.38
# Continuous clear straight route sampled at 2cm; clearance exceeds sampling error.
points=np.array([[report['gate_x'],z] for z in np.arange(-24,report['spawn_z']+.001,.02)])
nearest=np.maximum(boxes[None,:,:2],np.minimum(points[:,None,:],boxes[None,:,2:4]))
clearance=np.sqrt(((nearest-points[:,None,:])**2).sum(2)).min()
assert clearance>radius+.02,clearance
# Replay axis-separated movement with world-transformed boxes for BOTH teams.
for side in [1,-1]:
    centers=(boxes[:,:2]+boxes[:,2:4])/2*side+[-report['gate_x']*side,58*side]
    half=(boxes[:,2:4]-boxes[:,:2])/2
    p=np.array([0.,(58+report['spawn_z'])*side])
    for step in range(440):
        next=p+[0,-side*.04];next=np.clip(next,[-52,-80],[52,80])
        near=np.maximum(centers-half,np.minimum(next,centers+half))
        assert np.all(((near-next)**2).sum(1)>=radius**2),(side,step)
        assert np.isclose(np.linalg.norm(next-p),.04)
        p=next
    assert abs(p[1])<35
# The scene and collision share the same local-to-world pose and no aggregate blocker.
source=(root/'Game/CastleBases.swift').read_text()
assert 'TeamBases.blocker' not in source and 'TeamBases.collision(team)' in source
session=(root/'Game/GameSession.swift').read_text()
assert session.count('applySpawn();')==2 and 'VolcanoLayout.depthBoundary' in session
print(json.dumps({'bound_meshes':meshes,'untextured_fallbacks':default,'resolved_texture_references':references,
                  'rectangles_per_keep':len(boxes),'minimum_gate_route_clearance_m':round(float(clearance),3),
                  'both_team_routes':'passed at player radius 0.38m','native_device_test':'not run'},indent=2))

# Reachability through the courtyard (including the tree/rocks), not just a
# hand-picked point inside each room. Padding includes sampling uncertainty.
from collections import deque
step=.2;xs=np.arange(-24,25,step);zs=np.arange(-19,20,step)
X,Z=np.meshgrid(xs,zs);free=np.ones(X.shape,dtype=bool)
for x0,z0,x1,z1,h in boxes:
    near_x=np.maximum(x0,np.minimum(X,x1));near_z=np.maximum(z0,np.minimum(Z,z1))
    free &= (X-near_x)**2+(Z-near_z)**2 >= .4**2
start=(round((report['spawn_z']-zs[0])/step),round((report['gate_x']-xs[0])/step))
assert free[start]
visited={start};queue=deque([start])
while queue:
    y,x=queue.popleft()
    for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:
        n=(y+dy,x+dx)
        if 0<=n[0]<len(zs) and 0<=n[1]<len(xs) and free[n] and n not in visited:
            visited.add(n);queue.append(n)
for name,p in [('East workshop',(11,2.3)),('Timber hall',(2.5,12)),('West study',(-4.85,6.7))]:
    n=(round((p[1]-zs[0])/step),round((p[0]-xs[0])/step))
    assert n in visited,(name,p)

angle=np.radians(25)
def west(v):return np.array([-7.2*np.cos(angle)+v*np.sin(angle),7.2*np.sin(angle)+v*np.cos(angle)])
for side in [1,-1]:
    centers=(boxes[:,:2]+boxes[:,2:4])/2*side+[-report['gate_x']*side,58*side]
    half=(boxes[:,2:4]-boxes[:,:2])/2
    for start,end in [(np.array([6,2.3]),np.array([12,2.3])),(np.array([2.5,8]),np.array([2.5,12])),(west(.4),west(4.4))]:
        start=start*side+[-report['gate_x']*side,58*side];end=end*side+[-report['gate_x']*side,58*side]
        p=start.copy()
        for destination in [end,start]:
            delta=(destination-p)/200
            for _ in range(200):
                for axis in [0,1]:
                    candidate=p.copy();candidate[axis]+=delta[axis]
                    near=np.maximum(centers-half,np.minimum(candidate,centers+half))
                    if np.all(((near-candidate)**2).sum(1)>=.38**2):p=candidate
            assert np.linalg.norm(p-destination)<.005,(side,p,destination)
print('Three building interiors reachable from spawn; six team/room entry-and-exit replays passed.')
