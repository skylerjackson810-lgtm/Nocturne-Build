"""Regenerate the checked-in Xcode project and procedural audio. Python 3 only."""
from pathlib import Path
import hashlib, json, plistlib, math, random, struct, wave
root=Path(__file__).resolve().parents[1]
app=root
assets=app/'Resources/Assets.xcassets'
assets.mkdir(parents=True,exist_ok=True)
(assets/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}},indent=2))
(assets/'MoonlitCourt.imageset/Contents.json').write_text(json.dumps({'images':[{'filename':'moonlit-court.png','idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2))
launch=assets/'LaunchBackground.colorset'; launch.mkdir(exist_ok=True)
(launch/'Contents.json').write_text(json.dumps({'colors':[{'idiom':'universal','color':{'color-space':'srgb','components':{'alpha':'1.000','red':'0.025','green':'0.025','blue':'0.055'}}}],'info':{'author':'xcode','version':1}},indent=2))
info={'CFBundleDevelopmentRegion':'en','CFBundleDisplayName':'Nocturne','CFBundleExecutable':'$(EXECUTABLE_NAME)',
'CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0','CFBundleName':'$(PRODUCT_NAME)',
'CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.3.0','CFBundleVersion':'3','LSRequiresIPhoneOS':True,
'UILaunchScreen':{'UIColorName':'LaunchBackground'},'UIRequiresFullScreen':True,'UIStatusBarHidden':True,
'UISupportedInterfaceOrientations':['UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],
'UISupportedInterfaceOrientations~ipad':['UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],
'UIRequiredDeviceCapabilities':['arm64'],'NSMicrophoneUsageDescription':'Your voice casts spells. No audio is sent to other players.',
'NSSpeechRecognitionUsageDescription':'Recognize spoken spell names on your device to cast magic.','ITSAppUsesNonExemptEncryption':False,
'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False}}
(app/'Info.plist').write_bytes(plistlib.dumps(info))
for key,duration in [('cast',0.4),('impact',0.2),('hurt',0.18)]:
 rng=random.Random(key); sample_rate=22050
 samples=[]
 for n in range(int(duration*sample_rate)):
  t=n/sample_rate; progress=t/duration; env=math.sin(min(1,progress*12)*math.pi/2)*(1-progress)**2
  noise=rng.uniform(-1,1)
  if key=='cast': value=(noise*0.35+math.sin(2*math.pi*(160*t+650*t*t))*0.45)*env
  elif key=='impact': value=(noise*0.65+math.sin(2*math.pi*70*t)*0.3)*env
  else: value=math.sin(2*math.pi*(100*t-80*t*t))*env*0.5
  samples.append(struct.pack('<h',int(max(-1,min(1,value))*16000)))
 with wave.open(str(app/'Resources'/f'{key}.wav'),'wb') as w:
  w.setnchannels(1);w.setsampwidth(2);w.setframerate(sample_rate);w.writeframes(b''.join(samples))
# Original 32-second minor-key ambient loop: drones, soft chord pads, and bells.
# No external recordings, speech, or licensed music. Deterministic and click-free.
rate=22050; duration=32; notes=[74,77,81,76,72,69,65,69,74,77,79,72,69,65,64,69]
chords=[(50,53,57),(46,50,53),(48,52,55),(45,49,52)]
music=bytearray()
def hz(midi): return 440*2**((midi-69)/12)
for n in range(rate*duration):
 t=n/rate; bar=int(t/8); local=t%8
 pad=sum(math.sin(2*math.pi*hz(note)*t)+0.22*math.sin(2*math.pi*hz(note)*2.003*t)
         for note in chords[bar])*0.055*math.sin(math.pi*local/8)**0.7
 event=int(t/2); age=t%2; bell_freq=hz(notes[event])
 bell=(math.sin(2*math.pi*bell_freq*age)+0.25*math.sin(2*math.pi*bell_freq*2.76*age))*math.exp(-age*2.8)*min(1,age/0.012)*0.2
 drone=(math.sin(2*math.pi*73.416*t)+0.45*math.sin(2*math.pi*110*t))*0.07
 fade=min(1,t/0.12,(duration-t)/0.12)
 value=(pad+bell+drone)*fade
 music.extend(struct.pack('<h',int(max(-1,min(1,value))*28000)))
with wave.open(str(app/'Resources/menu.wav'),'wb') as w:
 w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(music)
def ident(value): return hashlib.sha256(value.encode()).hexdigest()[:24].upper()
objects={}
def add(keyname,isa,**fields):
 key=ident(keyname);objects[key]={'isa':isa,**fields};return key
main=ident('group-main'); products=ident('group-products'); project=ident('project'); target=ident('target-app'); tests=ident('target-tests')
app_product=add('app-product','PBXFileReference',explicitFileType='wrapper.application',includeInIndex='0',path='Nocturne.app',sourceTree='BUILT_PRODUCTS_DIR')
test_product=add('test-product','PBXFileReference',explicitFileType='wrapper.cfbundle',includeInIndex='0',path='NocturneTests.xctest',sourceTree='BUILT_PRODUCTS_DIR')
source_refs=[];source_build=[]
source_directories = ['App', 'Game', 'Gameplay', 'Platform', 'UI']
for p in sorted(file for directory in source_directories for file in (app/directory).rglob('*') if file.suffix in ['.swift','.metal']):
 rel=str(p.relative_to(app)); ref=add('source-ref-'+rel,'PBXFileReference',lastKnownFileType='sourcecode.metal' if p.suffix=='.metal' else 'sourcecode.swift',path=rel,sourceTree='<group>')
 source_refs.append(ref);source_build.append(add('source-build-'+rel,'PBXBuildFile',fileRef=ref))
resource_refs=[]; resource_build=[]
for rel,kind in [('Resources/Assets.xcassets','folder.assetcatalog')]+[(f'Resources/{n}.wav','audio.wav') for n in ['cast','impact','hurt','menu']]:
 ref=add('resource-ref-'+rel,'PBXFileReference',lastKnownFileType=kind,path=rel,sourceTree='<group>')
 resource_refs.append(ref);resource_build.append(add('resource-build-'+rel,'PBXBuildFile',fileRef=ref))
plist_ref=add('info-plist','PBXFileReference',lastKnownFileType='text.plist.xml',path='Info.plist',sourceTree='<group>')
app_group=add('app-group','PBXGroup',children=source_refs+resource_refs+[plist_ref],name='Nocturne',sourceTree='<group>')
test_refs=[];test_build=[]
for p in sorted((root/'Tests').glob('*.swift')):
 ref=add('test-ref-'+p.name,'PBXFileReference',lastKnownFileType='sourcecode.swift',path=p.name,sourceTree='<group>')
 test_refs.append(ref);test_build.append(add('test-build-'+p.name,'PBXBuildFile',fileRef=ref))
test_group=add('test-group','PBXGroup',children=test_refs,path='Tests',sourceTree='<group>')
add('group-products','PBXGroup',children=[app_product,test_product],name='Products',sourceTree='<group>')
add('group-main','PBXGroup',children=[app_group,test_group,products],sourceTree='<group>')
def phase(name,kind,files):return add(name,kind,buildActionMask='2147483647',files=files,runOnlyForDeploymentPostprocessing='0')
app_phases=[phase('app-sources','PBXSourcesBuildPhase',source_build),phase('app-frameworks','PBXFrameworksBuildPhase',[]),phase('app-resources','PBXResourcesBuildPhase',resource_build)]
test_phases=[phase('test-sources','PBXSourcesBuildPhase',test_build),phase('test-frameworks','PBXFrameworksBuildPhase',[]),phase('test-resources','PBXResourcesBuildPhase',[])]
common={'IPHONEOS_DEPLOYMENT_TARGET':'18.0','SDKROOT':'iphoneos','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES',
'CLANG_ENABLE_OBJC_ARC':'YES','SWIFT_STRICT_CONCURRENCY':'targeted','ENABLE_USER_SCRIPT_SANDBOXING':'YES'}
def configs(name,settings):
 refs=[]
 for mode in ['Debug','Release']:
  build={**settings,'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O',
   'DEBUG_INFORMATION_FORMAT':'dwarf' if mode=='Debug' else 'dwarf-with-dsym'}
  if mode=='Debug':build.update({'SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG','ENABLE_TESTABILITY':'YES','ONLY_ACTIVE_ARCH':'YES'})
  refs.append(add(name+'-'+mode,'XCBuildConfiguration',buildSettings=build,name=mode))
 return add(name+'-list','XCConfigurationList',buildConfigurations=refs,defaultConfigurationIsVisible='0',defaultConfigurationName='Release')
project_configs=configs('project-config',common)
app_configs=configs('app-config',{'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.example.NocturnePrototype',
'INFOPLIST_FILE':'Info.plist','GENERATE_INFOPLIST_FILE':'NO','TARGETED_DEVICE_FAMILY':'1,2','CODE_SIGN_STYLE':'Automatic',
'SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SUPPORTS_MACCATALYST':'NO','SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD':'NO',
'LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/Frameworks']})
test_configs=configs('test-config',{'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.example.NocturnePrototypeTests',
'GENERATE_INFOPLIST_FILE':'YES','TARGETED_DEVICE_FAMILY':'1,2','CODE_SIGN_STYLE':'Automatic','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/Nocturne.app/Nocturne',
'BUNDLE_LOADER':'$(TEST_HOST)','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/Frameworks','@loader_path/Frameworks']})
proxy=add('test-app-proxy','PBXContainerItemProxy',containerPortal=project,proxyType='1',remoteGlobalIDString=target,remoteInfo='Nocturne')
dependency=add('test-app-dependency','PBXTargetDependency',target=target,targetProxy=proxy)
add('target-app','PBXNativeTarget',buildConfigurationList=app_configs,buildPhases=app_phases,buildRules=[],dependencies=[],name='Nocturne',productName='Nocturne',productReference=app_product,productType='com.apple.product-type.application')
add('target-tests','PBXNativeTarget',buildConfigurationList=test_configs,buildPhases=test_phases,buildRules=[],dependencies=[dependency],name='NocturneTests',productName='NocturneTests',productReference=test_product,productType='com.apple.product-type.bundle.unit-test')
add('project','PBXProject',attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'1600','TargetAttributes':{target:{'CreatedOnToolsVersion':'16.0'},tests:{'CreatedOnToolsVersion':'16.0','TestTargetID':target}}},buildConfigurationList=project_configs,compatibilityVersion='Xcode 14.0',developmentRegion='en',hasScannedForEncodings='0',knownRegions=['en','Base'],mainGroup=main,productRefGroup=products,projectDirPath='',projectRoot='',targets=[target,tests])
def encode(value,indent=0):
 if isinstance(value,dict):return '{\n'+''.join('\t'*(indent+1)+json.dumps(k)+' = '+encode(v,indent+1)+';\n' for k,v in value.items())+'\t'*indent+'}'
 if isinstance(value,list):return '(\n'+''.join('\t'*(indent+1)+encode(v,indent+1)+',\n' for v in value)+'\t'*indent+')'
 return json.dumps(str(value))
pbx={'archiveVersion':'1','classes':{},'objectVersion':'56','objects':objects,'rootObject':project}
(root/'Nocturne.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n'+encode(pbx)+'\n')
ref=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Nocturne.app" BlueprintName="Nocturne" ReferencedContainer="container:Nocturne.xcodeproj"/>'
tref=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{tests}" BuildableName="NocturneTests.xctest" BlueprintName="NocturneTests" ReferencedContainer="container:Nocturne.xcodeproj"/>'
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{tref}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
(root/'Nocturne.xcodeproj/xcshareddata/xcschemes/Nocturne.xcscheme').write_text(scheme)
print(f'Generated Xcode project: {len(source_refs)} application source files (Swift + Metal), {len(test_refs)} test files, {len(resource_refs)} bundled resources.')
