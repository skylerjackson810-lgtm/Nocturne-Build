"""Structural validation only. Does not replace xcodebuild or device testing.
Dependencies: pip install tree-sitter tree-sitter-swift openstep-parser
"""
from pathlib import Path
from tree_sitter import Language, Parser
import tree_sitter_swift
from openstep_parser import OpenStepDecoder
import json, plistlib, xml.etree.ElementTree as ET, wave
root=Path(__file__).resolve().parents[1]
parser=Parser(Language(tree_sitter_swift.language()))
errors=[]
for p in root.rglob('*.swift'):
 tree=parser.parse(p.read_bytes())
 stack=[tree.root_node]
 while stack:
  node=stack.pop()
  if node.type=='ERROR' or node.is_missing:errors.append(f'{p.relative_to(root)}:{node.start_point} {node.type}')
  stack.extend(node.children)
assert not errors,errors
project=OpenStepDecoder.ParseFromString((root/'Nocturne.xcodeproj/project.pbxproj').read_text())
objects=project['objects']
for key,obj in objects.items():
 for field in ['fileRef','buildConfigurationList','mainGroup','productRefGroup','productReference','target','targetProxy','containerPortal','remoteGlobalIDString']:
  if field in obj:assert obj[field] in objects,(key,field,obj[field])
 for field in ['children','files','buildPhases','buildRules','dependencies','targets','buildConfigurations']:
  for target in obj.get(field,[]):assert target in objects,(key,field,target)
source_paths=set()
resource_paths=set()
for obj in objects.values():
 if obj['isa']=='PBXGroup' and (obj.get('name')=='Nocturne' or obj.get('path')=='Tests'):
  base=root/(obj.get('path') or '')
  for child in obj['children']:
   ref=objects[child]
   if ref['isa']=='PBXFileReference':
    path=base/ref['path'];assert path.exists(),path
    if path.suffix=='.swift':source_paths.add(path.resolve())
    else:resource_paths.add(path.resolve())
expected_sources={p.resolve() for directory in ['App','Game','Gameplay','Platform','UI','Tests'] for p in (root/directory).rglob('*.swift')}
assert source_paths==expected_sources
for path in root.rglob('*.plist'):
 plistlib.loads(path.read_bytes())
for path in root.rglob('Contents.json'):
 data=json.loads(path.read_text())
 for image in data.get('images',[]):
  if 'filename' in image:assert (path.parent/image['filename']).is_file()
for p in (root/'Nocturne/Resources').glob('*.wav'):
 with wave.open(str(p)) as sound:
  assert sound.getnframes()>0 and sound.getnchannels()==1
scheme=ET.parse(root/'Nocturne.xcodeproj/xcshareddata/xcschemes/Nocturne.xcscheme')
for ref in scheme.findall('.//BuildableReference'):assert ref.attrib['BlueprintIdentifier'] in objects
info=plistlib.loads((root/'Info.plist').read_bytes())
assert 'NSMicrophoneUsageDescription' in info and 'NSSpeechRecognitionUsageDescription' in info
assert all('Landscape' in x for x in info['UISupportedInterfaceOrientations'])
print(json.dumps({'swift_grammar_files':len(source_paths),'swift_syntax_errors':len(errors),'xcode_objects':len(objects),
'file_references':'all resolved','plists_assets_audio_scheme':'valid','native_compilation':'not available','native_xctests':'not executed'},indent=2))
