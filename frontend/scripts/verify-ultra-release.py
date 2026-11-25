"""Verify a native Ultra bundle before publishing and emit a named release asset."""
import hashlib, json, os, pathlib, plistlib, shutil, subprocess, sys, tempfile
ROOT = pathlib.Path(__file__).resolve().parents[2]
CONFIG = json.loads((ROOT/'frontend/src-tauri/tauri.conf.json').read_text())
VERSION = CONFIG['version']
PLATFORM, TARGET = sys.argv[1:3]
VARIANT = sys.argv[3] if len(sys.argv)>3 else 'cpu'
PROFILE = ROOT/'target'/TARGET/'release'
DIST = ROOT/'dist-ultra'; DIST.mkdir(exist_ok=True)
def run(*args, **kwargs): return subprocess.check_output(args, **kwargs)
def require(condition, message):
    if not condition: raise RuntimeError(message)
def smoke(sidecars):
    suffix = '.exe' if PLATFORM == 'windows' else ''
    require(b'ffmpeg version' in run(str(sidecars/('ffmpeg'+suffix)),'-version'), 'FFmpeg smoke failed')
    result = run(str(sidecars/('llama-helper'+suffix)),input=b'{"type":"ping"}\n{"type":"shutdown"}\n').decode()
    messages = [json.loads(line) for line in result.splitlines() if line.startswith('{')]
    require(any(x.get('type')=='pong' for x in messages), 'llama-helper did not respond')
if PLATFORM == 'windows':
    installer = next((PROFILE/'bundle/nsis').glob('*.exe'))
    seven = shutil.which('7z') or r'C:\Program Files-Zipz.exe'
    require(pathlib.Path(seven).is_file(), '7-Zip is required for installer verification')
    run(seven,'t',str(installer))
    with tempfile.TemporaryDirectory(prefix='ultra-payload-') as folder:
        run(seven,'x',str(installer),'-o'+folder,'-y','meetily-ultra.exe','ffmpeg.exe','llama-helper.exe','runtime-deps/*','binaries/onnxruntime/*')
        stage = pathlib.Path(folder)
        packaged = (stage/'meetily-ultra.exe').read_bytes().replace(b'__TAURI_BUNDLE_TYPE_VAR_NSS',b'__TAURI_BUNDLE_TYPE_VAR_UNK')
        require(packaged == (PROFILE/'meetily-ultra.exe').read_bytes(), 'Wrong packaged application')
        for name in ['ffmpeg','llama-helper']:
            require((stage/(name+'.exe')).read_bytes() == (ROOT/f'frontend/src-tauri/binaries/{name}-{TARGET}.exe').read_bytes(), 'Wrong sidecar '+name)
        for name in ['onnxruntime.dll','onnxruntime_providers_shared.dll','DirectML.dll']:
            source=(ROOT/'frontend/src-tauri/binaries/onnxruntime'/name).read_bytes()
            for rel in ['binaries/onnxruntime','runtime-deps']:
                require((stage/rel/name).read_bytes()==source,'Wrong packaged runtime '+name)
        require((stage/'runtime-deps/vc_redist.x64.exe').stat().st_size>1_000_000,'Missing Visual C++ runtime installer')
        os.environ['PATH']=str(stage/'binaries/onnxruntime')+os.pathsep+os.environ['PATH']
        if VARIANT == 'cuda':
            for name in ['cudart64_13.dll','cublas64_13.dll','cublasLt64_13.dll']:
                require((stage/'runtime-deps'/name).read_bytes()==(ROOT/'frontend/src-tauri/runtime-deps'/name).read_bytes(), 'Wrong CUDA runtime '+name)
            os.environ['PATH']=str(stage/'runtime-deps')+os.pathsep+os.environ['PATH']
        smoke(stage)
    suffix='-cuda' if VARIANT=='cuda' else ''
    output=DIST/f'Meetily-Ultra_{VERSION}_windows-x64{suffix}-setup.exe'
    shutil.copy2(installer,output)
else:
    app=PROFILE/'bundle/macos/Meetily Ultra.app'
    info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
    require(info['CFBundleIdentifier']=='com.ampersandru.meetily-ultra','Wrong app ID')
    require(info['CFBundleShortVersionString']==VERSION,'Wrong app version')
    require(info.get('NSMicrophoneUsageDescription') and info.get('NSAudioCaptureUsageDescription'),'Missing capture permissions')
    require(info.get('LSMinimumSystemVersion')=='14.2','Wrong macOS deployment target')
    architecture='arm64' if TARGET.startswith('aarch64') else 'x86_64'
    for executable in ['meetily-ultra','ffmpeg','llama-helper']:
        file=app/'Contents/MacOS'/executable
        require(architecture in run('lipo','-archs',str(file)).decode(),'Wrong architecture '+executable)
        build_info=run('xcrun','vtool','-show-build',str(file)).decode()
        import re
        minimum=re.search(r'\bminos\s+([0-9.]+)',build_info)
        require(minimum is not None,'Missing Mach-O deployment target '+executable)
        parts=tuple(int(x) for x in minimum.group(1).split('.'))
        require((parts+(0,0))[:3] <= (14,2,0),'Binary requires newer macOS: '+executable)

    for rel in ['templates/standard_meeting.json','resources/diarization/segmentation-3.0-fp16.onnx','resources/diarization/wespeaker-resnet34-LM.onnx','resources/diarization/xvec_transform.npz','icon.icns']:
        require((app/'Contents/Resources'/rel).exists(),'Missing bundled resource '+rel)
    run('codesign','--verify','--deep','--strict',str(app))
    smoke(app/'Contents/MacOS')
    installer=next((PROFILE/'bundle/dmg').glob('*.dmg'))
    run('hdiutil','verify',str(installer))
    arch='arm64' if TARGET.startswith('aarch64') else 'x64'
    output=DIST/f'Meetily-Ultra_{VERSION}_macos-{arch}.dmg'
    shutil.copy2(installer,output)
checksum=hashlib.sha256(output.read_bytes()).hexdigest()
output.with_name(output.name+'.sha256').write_text(f'{checksum}  {output.name}\n')
print(json.dumps({'asset':str(output),'sha256':checksum,'bytes':output.stat().st_size}))
