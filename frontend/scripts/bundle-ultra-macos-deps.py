"""Copy non-system Mach-O dependencies into the app, then sign the closure."""
import hashlib, os, pathlib, shutil, stat, subprocess, sys
app=pathlib.Path(sys.argv[1]).resolve()
frameworks=app/'Contents/Frameworks'; frameworks.mkdir(exist_ok=True)
repo=pathlib.Path(__file__).resolve().parents[2]
seen={}; fingerprints={}; queue=[(p,p) for p in (app/'Contents/MacOS').iterdir() if p.is_file()]
def run(*args):return subprocess.check_output(args,text=True)
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
while queue:
 source, binary=queue.pop(0)
 if binary in seen:continue
 seen[binary]=True
 dependencies=[line.strip().split(' (')[0] for line in run('otool','-L',str(source)).splitlines()[1:]]
 for dependency in dependencies:
  if dependency.startswith(('/usr/lib/','/System/Library/')):continue
  name=pathlib.Path(dependency).name
  if dependency.startswith('/'):
   origin=pathlib.Path(dependency)
  else:
   candidates=[source.parent/name,frameworks/name,pathlib.Path('/opt/homebrew/lib')/name,pathlib.Path('/usr/local/lib')/name]
   origin=next((p for p in candidates if p.is_file()),None)
   if origin is None:origin=next((p for p in (repo/'target').rglob(name) if p.is_file()),None)
  if origin is None or not origin.is_file():raise RuntimeError('Unresolved Mach-O dependency: '+dependency)
  destination=frameworks/name
  original_hash=digest(origin)
  if name in fingerprints and fingerprints[name]!=original_hash:
   raise RuntimeError('Conflicting bundled dylib basename: '+name)
  fingerprints[name]=original_hash
  if not destination.exists():
   shutil.copyfile(origin,destination)
   destination.chmod(destination.stat().st_mode|stat.S_IWUSR)
   queue.append((origin,destination))
  relative='@loader_path/'+name if binary.parent==frameworks else '@executable_path/../Frameworks/'+name
  if binary==destination:
   run('install_name_tool','-id','@rpath/'+name,str(binary))
  else:run('install_name_tool','-change',dependency,relative,str(binary))
for binary in sorted(frameworks.iterdir()):
 run('codesign','--force','--sign','-','--timestamp=none',str(binary))
# Sidecars also need fresh signatures after install_name_tool changes.
for binary in (app/'Contents/MacOS').iterdir():
 if binary.is_file():run('codesign','--force','--sign','-','--timestamp=none',str(binary))
print('Vendored and signed',len(list(frameworks.iterdir())),'non-system dependencies')
