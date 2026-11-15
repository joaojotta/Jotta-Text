#!/usr/bin/env python3
"""Stage the browser shell and locally served browser-only tool libraries."""
from pathlib import Path
import shutil
ROOT=Path(__file__).resolve().parent.parent
out=ROOT/'dist/web'
out.mkdir(parents=True,exist_ok=True)
(out/'jottaxl.js').unlink(missing_ok=True)
for path in (ROOT/'web').iterdir():
    if path.suffix in ('.html','.mjs','.css'):shutil.copy2(path,out/path.name)
assets=out/'assets';assets.mkdir(exist_ok=True)
for source,name in [(ROOT/'icons/icon.svg','icon.svg'),(ROOT/'fonts/Rubik-VariableFont_wght.ttf','Rubik.ttf')]:
    shutil.copy2(source,assets/name)
modules=ROOT/'vendor/litefront/tooling/node_modules'
prettier=out/'lib/prettier';prettier.mkdir(parents=True,exist_ok=True)
for name in ['standalone.mjs','LICENSE','THIRD-PARTY-NOTICES.md']:
    shutil.copy2(modules/'prettier'/name,prettier/name)
shutil.copytree(modules/'prettier/plugins',prettier/'plugins',dirs_exist_ok=True)
shutil.copy2(modules/'@prettier/plugin-php/standalone.js',out/'lib/php.mjs')
shutil.copy2(modules/'@prettier/plugin-php/LICENSE',out/'lib/php-LICENSE')
shutil.copy2(ROOT/'profile/assets/NOTICE.md',out/'assets/NOTICE.md')
shutil.copy2(ROOT/'VERSION',out/'VERSION')
shutil.copy2(ROOT/'web/README.md',out/'README.md')
shutil.copytree(ROOT/'profile/assets/licenses',assets/'licenses',dirs_exist_ok=True)
shutil.copy2(ROOT/'vendor/lite-xl/LICENSE',assets/'lite-xl-LICENSE.txt')
print('Browser shell and tool libraries staged in dist/web')
