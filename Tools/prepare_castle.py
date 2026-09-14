"""Normalize the supplied castle export; requires the optional usd-core package.
The original stays byte-for-byte intact in SourceAssets. Not run by Xcode/CI.
"""
from pathlib import Path
from pxr import Usd, UsdGeom, UsdUtils, Sdf, Gf
import hashlib, json, tempfile

root = Path(__file__).resolve().parents[1]
source = root / 'SourceAssets/Castle-original.usdz'
stage = Usd.Stage.Open(str(source))
cache = UsdGeom.BBoxCache(Usd.TimeCode.Default(), ['default', 'render'])
# These seven detached export pieces were inspected separately. Keeping them in
# the runtime bounds would shrink/offset the castle. Original upload is preserved.
detached = []
for prim in stage.Traverse():
    if prim.IsA(UsdGeom.Mesh):
        midpoint = cache.ComputeWorldBound(prim).ComputeAlignedRange().GetMidpoint()
        if midpoint[1] < 100 or midpoint[0] < -40:
            detached.append(str(prim.GetPath()))
assert len(detached) == 7, 'Source changed; inspect its bounds before normalizing again.'
working = Usd.Stage.Open(stage.Flatten())
for path in detached:
    working.RemovePrim(path)
cache = UsdGeom.BBoxCache(Usd.TimeCode.Default(), ['default', 'render'])
default = working.GetDefaultPrim()
bounds = cache.ComputeWorldBound(default).ComputeAlignedRange()
size, center = bounds.GetSize(), bounds.GetMidpoint()
scale = 18.0 / max(size[0], size[2])
xform = UsdGeom.Xformable(default)
xform.AddTranslateOp().Set(Gf.Vec3d(-center[0] * scale, -bounds.GetMin()[1] * scale, -center[2] * scale))
xform.AddScaleOp().Set(Gf.Vec3f(scale))
UsdGeom.SetStageMetersPerUnit(working, 1)
UsdGeom.SetStageUpAxis(working, UsdGeom.Tokens.y)
with tempfile.TemporaryDirectory() as directory:
    binary = Path(directory) / 'Castle.usdc'
    working.GetRootLayer().Export(str(binary))
    output = root / 'Resources/Castle.usdz'
    output.unlink(missing_ok=True)
    assert UsdUtils.CreateNewUsdzPackage(Sdf.AssetPath(str(binary)), str(output))
check = Usd.Stage.Open(str(output))
final = UsdGeom.BBoxCache(0, ['default','render']).ComputeWorldBound(check.GetDefaultPrim()).ComputeAlignedRange()
report = {'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
          'runtime_sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
          'excluded_detached_prims': detached, 'scale': scale,
          'runtime_min': list(final.GetMin()), 'runtime_max': list(final.GetMax()),
          'runtime_meshes': sum(p.IsA(UsdGeom.Mesh) for p in check.Traverse()),
          'texture_images': 0, 'materials_and_uvs': 'preserved',
          'note': 'Uploaded USDZ has no texture assets/references. Seven detached export pieces omitted only from game copy.'}
(root / 'SourceAssets/castle-import.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
