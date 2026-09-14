"""Package the complete buildable source without git internals or build products."""
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
output = root.parent / 'Nocturne-Cinder-Caldera-Complete.zip'
directories = ['App', 'Game', 'Gameplay', 'Platform', 'UI', 'Resources', 'Tests',
               'Tools', 'Nocturne.xcodeproj', '.github', 'Preview']
documents = ['Info.plist', 'README.md', 'START-HERE.md', 'VALIDATION.md', 'ARTWORK.md',
             'GITHUB-FIX.md', 'LOWPOLY-AUDIO-UPDATE.md']
files = [root / name for name in documents]
files += [p for name in directories for p in (root / name).rglob('*')
          if p.is_file() and '__pycache__' not in p.parts and p.name != '.DS_Store']
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(files):
        archive.write(path, path.relative_to(root))
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    names = set(archive.namelist())
    for required in ['Game/RetroShaders.metal', 'Game/VolcanoBuilder.swift',
                     'Resources/menu.wav', 'Nocturne.xcodeproj/project.pbxproj',
                     '.github/workflows/build.yml', 'App/NocturneApp.swift']:
        assert required in names, required
print(f'{output}: {len(files)} files, {output.stat().st_size:,} bytes; integrity verified')
