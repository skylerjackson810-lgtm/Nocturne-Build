"""Restore GLB materials onto the normalized USD castle (offline only).

Requires usd-core, Pillow and numpy. Run with --glb PATH to extract a new
source; without it, rebuild using the included optimized textures and manifest.
The large original GLB is never copied into the app or source distribution.
"""
from pathlib import Path
import argparse, hashlib, io, json, struct, subprocess, sys, tempfile, zipfile
import numpy as np
from PIL import Image
from pxr import Usd, UsdGeom, UsdShade, UsdUtils, Sdf, Gf, Tf

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'SourceAssets/castle-textures.json'
TEXTURES = ROOT / 'SourceAssets/CastleTextures'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def extract(path):
    blob = path.read_bytes()
    assert struct.unpack_from('<4sII', blob) == (b'glTF', 2, len(blob))
    offset, doc, binary = 12, None, None
    while offset < len(blob):
        size, kind = struct.unpack_from('<II', blob, offset)
        offset += 8
        chunk = blob[offset:offset + size]
        assert len(chunk) == size
        if kind == 0x4e4f534a: doc = json.loads(chunk)
        elif kind == 0x004e4942: binary = chunk
        offset += size
    assert doc is not None and binary is not None
    assert set(doc.get('extensionsRequired', [])) <= {'KHR_texture_transform'}
    TEXTURES.mkdir(parents=True, exist_ok=True)
    normal_images = {doc['textures'][m['normalTexture']['index']]['source']
                     for m in doc['materials'] if 'normalTexture' in m}
    images = []
    for index, item in enumerate(doc['images']):
        view = doc['bufferViews'][item['bufferView']]
        assert view.get('buffer', 0) == 0 and item['mimeType'] == 'image/png'
        start = view.get('byteOffset', 0)
        raw = binary[start:start + view['byteLength']]
        image = Image.open(io.BytesIO(raw)); original_size = image.size
        image = image.convert('RGB')
        image.thumbnail((512, 512), Image.Resampling.LANCZOS)
        if index in normal_images:
            normals = np.asarray(image, dtype=np.float32) / 127.5 - 1
            normals /= np.maximum(np.linalg.norm(normals, axis=2, keepdims=True), 1e-8)
            image = Image.fromarray(np.uint8(np.clip((normals + 1) * 127.5, 0, 255)))
        name = f'texture_{index:02d}.png'
        encoded = io.BytesIO()
        image.save(encoded, format='PNG', optimize=True)
        (TEXTURES / name).write_bytes(encoded.getvalue())
        images.append({'name': item.get('name', name), 'file': name,
                       'original_size': original_size, 'size': image.size,
                       'sha256': digest(TEXTURES / name)})
    manifest = {'source_file': path.name, 'source_bytes': len(blob),
                'source_sha256': digest(path), 'images': images,
                'materials': doc['materials'], 'textures': doc['textures'],
                'samplers': doc.get('samplers', []), 'maximum_texture_size': 512,
                'note': 'Optimized images extracted from user GLB; original GLB remains separate.'}
    MANIFEST.write_text(json.dumps(manifest, indent=2) + '\n')

def rebuild():
    manifest = json.loads(MANIFEST.read_text())
    for image in manifest['images']:
        assert digest(TEXTURES / image['file']) == image['sha256']
    # Recreate the geometry from the unchanged USDZ source, not a previous
    # textured output: repeated imports cannot accumulate shader nodes.
    subprocess.run([sys.executable, str(ROOT / 'Tools/prepare_castle.py')], check=True,
                   stdout=subprocess.DEVNULL)
    output = ROOT / 'Resources/Castle.usdz'
    source = Usd.Stage.Open(str(output))
    stage = Usd.Stage.Open(source.Flatten())
    materials = {}
    for item in manifest['materials']:
        # The GLB repeats Wood/Path Rocks with invalid texCoord=-1 for UV-less
        # meshes. Keep the valid material; preserve plain USD materials there.
        materials.setdefault(Tf.MakeValidIdentifier(item['name']), item)
    fallback_meshes = []
    for prim in stage.Traverse():
        if not prim.IsA(UsdGeom.Mesh): continue
        uv = UsdGeom.PrimvarsAPI(prim).GetPrimvar('st')
        material = UsdShade.MaterialBindingAPI(prim).ComputeBoundMaterial()[0]
        if material and (not uv or not uv.Get()):
            path = Sdf.Path('/UntexturedMaterials/' + material.GetPrim().GetName())
            if not stage.GetPrimAtPath(path):
                stage.DefinePrim('/UntexturedMaterials', 'Scope')
                Sdf.CopySpec(stage.GetRootLayer(), material.GetPath(), stage.GetRootLayer(), path)
                fallback = UsdShade.Material(stage.GetPrimAtPath(path))
                fallback_shader = UsdShade.Shader(stage.GetPrimAtPath(path.AppendChild('PreviewSurface')))
                fallback.CreateSurfaceOutput().ConnectToSource(fallback_shader.ConnectableAPI(), 'surface')
            UsdShade.MaterialBindingAPI.Apply(prim).Bind(UsdShade.Material(stage.GetPrimAtPath(path)))
            fallback_meshes.append(str(prim.GetPath()))

    restored, unmatched = [], []
    for prim in list(stage.GetPrimAtPath('/Materials').GetChildren()):
        item = materials.get(prim.GetName())
        if item is None:
            unmatched.append(str(prim.GetPath())); continue
        if item.get('pbrMetallicRoughness', {}).get('baseColorTexture', {}).get('texCoord', 0) == -1:
            # A texture reference with no UV set cannot be restored faithfully.
            continue
        material = UsdShade.Material(prim)
        shader = UsdShade.Shader(stage.GetPrimAtPath(prim.GetPath().AppendChild('PreviewSurface')))
        assert shader
        uv = UsdShade.Shader.Define(stage, prim.GetPath().AppendChild('TextureCoordinates'))
        uv.CreateIdAttr('UsdPrimvarReader_float2')
        uv.CreateInput('varname', Sdf.ValueTypeNames.Token).Set('st')
        uv.CreateOutput('result', Sdf.ValueTypeNames.Float2)

        def texture(info, role, srgb=False):
            assert info.get('texCoord', 0) == 0
            transform = info.get('extensions', {}).get('KHR_texture_transform', {})
            assert transform.get('texCoord', 0) == 0 and transform.get('rotation', 0) == 0
            scale = transform.get('scale', [1, 1]); offset = transform.get('offset', [0, 0])
            mapping = UsdShade.Shader.Define(stage, prim.GetPath().AppendChild(role + 'UV'))
            mapping.CreateIdAttr('UsdTransform2d')
            mapping.CreateInput('in', Sdf.ValueTypeNames.Float2).ConnectToSource(uv.ConnectableAPI(), 'result')
            # Existing USD st values match the GLB UV convention. Apply glTF's
            # per-slot tiling, then change top-left image origin to USD bottom-left.
            mapping.CreateInput('scale', Sdf.ValueTypeNames.Float2).Set(Gf.Vec2f(scale[0], -scale[1]))
            mapping.CreateInput('translation', Sdf.ValueTypeNames.Float2).Set(Gf.Vec2f(offset[0], 1 - offset[1]))
            mapping.CreateOutput('result', Sdf.ValueTypeNames.Float2)
            descriptor = manifest['textures'][info['index']]
            image = manifest['images'][descriptor['source']]
            node = UsdShade.Shader.Define(stage, prim.GetPath().AppendChild(role + 'Texture'))
            node.CreateIdAttr('UsdUVTexture')
            node.CreateInput('file', Sdf.ValueTypeNames.Asset).Set(Sdf.AssetPath('textures/' + image['file']))
            node.CreateInput('sourceColorSpace', Sdf.ValueTypeNames.Token).Set('sRGB' if srgb else 'raw')
            node.CreateInput('st', Sdf.ValueTypeNames.Float2).ConnectToSource(mapping.ConnectableAPI(), 'result')
            sampler = manifest['samplers'][descriptor['sampler']] if 'sampler' in descriptor else {}
            wraps = {10497: 'repeat', 33071: 'clamp', 33648: 'mirror'}
            for axis in ['S', 'T']:
                node.CreateInput('wrap' + axis, Sdf.ValueTypeNames.Token).Set(wraps[sampler.get('wrap' + axis, 10497)])
            for name, typ in [('rgb', Sdf.ValueTypeNames.Float3), ('r', Sdf.ValueTypeNames.Float),
                              ('g', Sdf.ValueTypeNames.Float), ('b', Sdf.ValueTypeNames.Float)]:
                node.CreateOutput(name, typ)
            return node

        pbr = item.get('pbrMetallicRoughness', {})
        assert item.get('alphaMode', 'OPAQUE') == 'OPAQUE'
        color = pbr.get('baseColorFactor', [1, 1, 1, 1])
        shader.CreateInput('diffuseColor', Sdf.ValueTypeNames.Color3f).Set(Gf.Vec3f(*color[:3]))
        shader.CreateInput('metallic', Sdf.ValueTypeNames.Float).Set(pbr.get('metallicFactor', 1))
        shader.CreateInput('roughness', Sdf.ValueTypeNames.Float).Set(pbr.get('roughnessFactor', 1))
        if 'baseColorTexture' in pbr:
            node = texture(pbr['baseColorTexture'], 'Albedo', True)
            node.CreateInput('scale', Sdf.ValueTypeNames.Float4).Set(Gf.Vec4f(*color))
            shader.GetInput('diffuseColor').ConnectToSource(node.ConnectableAPI(), 'rgb')
            restored.append(str(material.GetPath()))
        if 'normalTexture' in item:
            node = texture(item['normalTexture'], 'Normal')
            strength = item['normalTexture'].get('scale', 1)
            node.CreateInput('scale', Sdf.ValueTypeNames.Float4).Set(Gf.Vec4f(2 * strength, 2 * strength, 2, 1))
            node.CreateInput('bias', Sdf.ValueTypeNames.Float4).Set(Gf.Vec4f(-strength, -strength, -1, 0))
            shader.CreateInput('normal', Sdf.ValueTypeNames.Normal3f).ConnectToSource(node.ConnectableAPI(), 'rgb')
        if 'metallicRoughnessTexture' in pbr:
            node = texture(pbr['metallicRoughnessTexture'], 'MetallicRoughness')
            node.CreateInput('scale', Sdf.ValueTypeNames.Float4).Set(Gf.Vec4f(1, pbr.get('roughnessFactor', 1), pbr.get('metallicFactor', 1), 1))
            shader.GetInput('roughness').ConnectToSource(node.ConnectableAPI(), 'g')
            shader.GetInput('metallic').ConnectToSource(node.ConnectableAPI(), 'b')

    with tempfile.TemporaryDirectory() as directory:
        directory = Path(directory); (directory / 'textures').mkdir()
        for image in manifest['images']:
            (directory / 'textures' / image['file']).write_bytes((TEXTURES / image['file']).read_bytes())
        binary = directory / 'Castle.usdc'
        stage.GetRootLayer().Export(str(binary))
        packaged = directory / 'Castle.usdz'
        assert UsdUtils.CreateNewUsdzPackage(Sdf.AssetPath(str(binary)), str(packaged))
        with zipfile.ZipFile(packaged) as archive:
            assert archive.testzip() is None
            assert sum(n.endswith('.png') for n in archive.namelist()) == len(manifest['images'])
            names = set(archive.namelist())
        check = Usd.Stage.Open(str(packaged))
        for prim in check.Traverse():
            for attribute in prim.GetAttributes():
                if attribute.GetTypeName() == Sdf.ValueTypeNames.Asset:
                    asset = attribute.Get()
                    assert asset and asset.path in names and asset.resolvedPath
                for connection in attribute.GetConnections():
                    assert check.GetObjectAtPath(connection)
        output.write_bytes(packaged.read_bytes())
    report = json.loads((ROOT / 'SourceAssets/castle-import.json').read_text())
    report.update(runtime_sha256=digest(output), texture_images=len(manifest['images']),
                  texture_source_sha256=manifest['source_sha256'], textured_materials=len(restored),
                  unmatched_materials=unmatched, meshes_without_uvs=fallback_meshes,
                  maximum_texture_size=512, materials_and_uvs='GLB textures and tiling restored; USD geometry/UVs retained',
                  note='Original USDZ remains unchanged; textures recovered from separately supplied GLB.')
    (ROOT / 'SourceAssets/castle-import.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'textured_materials': len(restored), 'embedded_images': len(manifest['images']),
                      'runtime_bytes': output.stat().st_size, 'unmatched_materials': unmatched,
                      'meshes_without_uvs': len(fallback_meshes)}, indent=2))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--glb', type=Path)
    args = parser.parse_args()
    if args.glb: extract(args.glb)
    rebuild()
