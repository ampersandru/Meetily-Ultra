"""Reclaim only selected intermediate outputs after all native tests finish."""
import pathlib, shutil, sys
repo=pathlib.Path(__file__).resolve().parents[2]
target_root=(repo/'target').resolve()
if not target_root.is_relative_to(repo):raise RuntimeError('Refusing an external target directory')
target=sys.argv[1]
if sys.platform!='darwin' or target not in {'aarch64-apple-darwin','x86_64-apple-darwin'}:
    raise SystemExit('This cleanup is restricted to the two macOS release targets')
for profile in [target_root/target/'release', target_root/'release']:
    for name in ['build','deps','incremental','.fingerprint','libapp_lib.a','libapp_lib.dylib','libapp_lib.rlib']:
        path=profile/name
        if path.is_symlink() or not path.resolve().is_relative_to(target_root):
            raise RuntimeError('Refusing nonlocal build cleanup: '+str(path))
        if path.is_dir():shutil.rmtree(path)
        elif path.is_file():path.unlink()
print('Reclaimed Rust intermediates; app bundle, executables and sidecars preserved')
