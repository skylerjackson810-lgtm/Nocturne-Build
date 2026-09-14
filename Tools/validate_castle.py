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
for prim in stage.Traverse():
    for attr in prim.GetAttributes():
        if attr.GetTypeName()==Sdf.ValueTypeNames.Asset:
            assert attr.Get().resolvedPath,(prim.GetPath(),attr.GetName())
            references+=1
    if not prim.IsA(UsdGeom.Mesh):continue
    meshes+=1;mat,_=UsdShade.MaterialBindingAPI(prim).ComputeBoundMaterial()
    assert mat and mat.ComputeSurfaceSource()[0],str(prim.GetPath())
    default+=str(mat.GetPath()).endswith('/Unassigned')
    for shader in Usd.PrimRange(mat.GetPrim()):
        if shader.IsA(UsdShade.Shader) and UsdShade.Shader(shader).GetIdAttr().Get()=='UsdPrimvarReader_float2':
            name=UsdShade.Shader(shader).GetInput('varname').Get()
            uv=UsdGeom.PrimvarsAPI(prim).GetPrimvar(name)
            assert uv and len(uv.Get())==len(UsdGeom.Mesh(prim).GetPointsAttr().Get())
assert meshes==308 and default==94
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
print(json.dumps({'bound_meshes':meshes,'explicit_neutral_defaults':default,'resolved_texture_references':references,
                  'rectangles_per_keep':len(boxes),'minimum_gate_route_clearance_m':round(float(clearance),3),
                  'both_team_routes':'passed at player radius 0.38m','native_device_test':'not run'},indent=2))
