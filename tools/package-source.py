#!/usr/bin/env python3
"""Package the project source without local state or downloaded dependencies."""
import hashlib
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parent.parent
FILES = ('.gitignore', '.gitattributes', '.editorconfig', 'README.md', 'BUILD_UBUNTU.md', 'BUILD_WINDOWS.md',
         'PUBLISHING.md', 'GITHUB_TRIAL.md', 'CHANGELOG.md', 'VERSION',
         'vendor/litefront/tooling/package.json',
         'vendor/litefront/tooling/package-lock.json')
DIRECTORIES = ('.github', 'docs', 'example', 'flatpak', 'fonts', 'icons', 'profile',
               'scripts', 'tests', 'tools', 'web')

def main():
    version = (ROOT / 'VERSION').read_text().strip()
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise SystemExit('Invalid VERSION')
    paths = [ROOT / name for name in FILES]
    for name in DIRECTORIES:
        for path in (ROOT / name).rglob('*'):
            parts = path.relative_to(ROOT / name).parts
            if any(part.startswith('.') or part in ('__pycache__', 'node_modules')
                   for part in parts) or path.suffix in ('.pyc', '.pyo'):
                continue
            if path.is_file():
                paths.append(path)
    stem = f'JottaText-{version}-source'
    archive = ROOT / 'dist' / f'{stem}.zip'
    archive.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
        for path in sorted(paths):
            if path.is_symlink():
                raise SystemExit(f'Source must not contain symlinks: {path}')
            zipped.write(path, Path(stem) / path.relative_to(ROOT))
    with archive.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    Path(str(archive) + '.sha256').write_text(f'{digest}  {archive.name}\n')
    print(f'Packaged {archive.relative_to(ROOT)} ({len(paths)} source files)')

if __name__ == '__main__':
    main()
