"""Optional offline USDZ material review, not a RealityKit/device screenshot.
Requires usd-core, numpy, Pillow, trimesh, pyrender and PyOpenGL >= 3.1.10.
Run: python Tools/preview_castle.py OUTPUT_DIRECTORY
"""
import os
os.environ.setdefault('PYOPENGL_PLATFORM','egl')
from pathlib import Path
import sys,io,zipfile
import numpy as np
import trimesh,pyrender
from pxr import Usd,UsdGeom,UsdShade
from PIL import Image
root=Path(__file__).resolve().parents[1]
output=Path(sys.argv[1]);output.mkdir(parents=True,exist_ok=True)
asset=root/'Resources/Castle.usdz';stage=Usd.Stage.Open(str(asset));archive=zipfile.ZipFile(asset)
scene=pyrender.Scene(bg_color=[.016,.02,.035,1.],ambient_light=[.5,.5,.5]);textures={}
for prim in stage.Traverse():
    if not prim.IsA(UsdGeom.Mesh):continue
    m=UsdGeom.Mesh(prim);points=np.array(m.GetPointsAttr().Get());faces=np.array(m.GetFaceVertexIndicesAttr().Get()).reshape(-1,3)
    mat,_=UsdShade.MaterialBindingAPI(prim).ComputeBoundMaterial();shader=mat.ComputeSurfaceSource()[0]
    color=shader.GetInput('diffuseColor').Get();texture=None
    connection=shader.GetInput('diffuseColor').GetConnectedSource()
    if connection:
        tex=UsdShade.Shader(connection[0]);f=tex.GetInput('file').Get().path
        if f not in textures:textures[f]=pyrender.Texture(source=np.array(Image.open(io.BytesIO(archive.read(f))).convert('RGB')),source_channels='RGB')
        texture=textures[f];color=[1.,1.,1.]
    mesh=trimesh.Trimesh(points,faces,vertex_normals=np.array(m.GetNormalsAttr().Get()),process=False)
    uv=UsdGeom.PrimvarsAPI(prim).GetPrimvar('st_albedo')
    if uv:mesh.visual=trimesh.visual.TextureVisuals(uv=np.array(uv.Get()))
    material=pyrender.MetallicRoughnessMaterial(baseColorFactor=np.array([*color,1.],dtype=float),baseColorTexture=texture,metallicFactor=0.,roughnessFactor=.9,doubleSided=True)
    scene.add(pyrender.Mesh.from_trimesh(mesh,material=material,smooth=True))
floor=trimesh.creation.box(extents=[150,.1,150]);floor.apply_translation([0,4.57,0])
scene.add(pyrender.Mesh.from_trimesh(floor,material=pyrender.MetallicRoughnessMaterial(baseColorFactor=[.13,.14,.14,1.],roughnessFactor=1.)))
pose=trimesh.transformations.euler_matrix(-.6,-.5,0)
scene.add(pyrender.DirectionalLight(color=[.83,.87,1.],intensity=2.),pose=pose)
r=pyrender.OffscreenRenderer(1100,750)
views=[('outer_rocks',[-40,12,-2],[-10,9,1]),('outside',[35,13,-36],[0,11,1]),('courtyard',[0,6.37,-5],[0,7,6]),('east_entry',[4,6.37,2.3],[12,6.37,2.3]),('west_room',[-4.8,6.37,6.8],[-6.6,6.2,4.5])]
for name,eye,target in views:
    eye=np.array(eye,float);z=eye-np.array(target,float);z/=np.linalg.norm(z);x=np.cross([0,1,0],z);x/=np.linalg.norm(x);y=np.cross(z,x)
    pose=np.eye(4);pose[:3,:3]=np.stack([x,y,z],axis=1);pose[:3,3]=eye
    node=scene.add(pyrender.PerspectiveCamera(yfov=np.radians(65)),pose=pose)
    color,depth=r.render(scene);Image.fromarray(color).save(output/(name+'.png'));scene.remove_node(node)
    print(name,flush=True)
r.delete()
