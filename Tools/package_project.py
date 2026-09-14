"""Package the complete buildable source without git internals or build products."""
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
output = root.parent / 'Nocturne-Moonlit-Valley-Complete.zip'
staging = output.with_suffix('.zip.partial')
directories = ['App', 'Game', 'Gameplay', 'Platform', 'UI', 'Resources', 'Tests',
               'Tools', 'Nocturne.xcodeproj', '.github', 'Preview', 'SourceAssets']
documents = ['Info.plist', 'README.md', 'START-HERE.md', 'VALIDATION.md', 'ARTWORK.md',
             'GITHUB-FIX.md', 'LOWPOLY-AUDIO-UPDATE.md', 'CASTLE-UPDATE.md', 'TEXTURE-UPDATE.md',
             'HISTORICAL-README.md', 'HISTORICAL-START-HERE.md', 'HISTORICAL-VALIDATION.md']
files = [root / name for name in documents]
files += [p for name in directories for p in (root / name).rglob('*')
          if p.is_file() and '__pycache__' not in p.parts and p.name != '.DS_Store']
with zipfile.ZipFile(staging, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(files):
        archive.write(path, path.relative_to(root))
with zipfile.ZipFile(staging) as archive:
    assert archive.testzip() is None
    names = set(archive.namelist())
    for required in ['Game/RetroShaders.metal', 'Game/VolcanoBuilder.swift',
                     'Resources/menu.wav', 'Nocturne.xcodeproj/project.pbxproj',
                     '.github/workflows/build.yml', 'App/NocturneApp.swift', 'Resources/Castle.usdz',
                     'SourceAssets/Castle-original.usdz', 'Resources/TerrainRock.jpg',
                     'Game/SceneDetail.swift', 'Game/ValleyAtmosphere.swift', 'Game/WizardHand.swift',
                     'SourceAssets/castle-direct-import.json']:
        assert required in names, required
staging.replace(output)
print(f'{output}: {len(files)} files, {output.stat().st_size:,} bytes; integrity verified')
