#!/usr/bin/env python3
"""Exercise the rename's first-launch recovery with disposable user data."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='jotta-text-migration-') as directory:
    home = Path(directory)
    legacy = home / '.var/app/dev.jottaxl.JottaXL/config/litefront'
    target = home / '.var/app/io.github.joaojotta.JottaText/config/litefront'
    env = dict(os.environ, HOME=str(home))
    def migrate():
        subprocess.run(['sh', str(ROOT / 'scripts/migrate-flatpak-settings.sh'),
                        str(target)], env=env, check=True)
    migrate()
    assert not target.exists(), 'A clean install should leave creation to the launcher'
    (legacy / 'recovery').mkdir(parents=True)
    (legacy / 'settings.lua').write_text('theme = "jotta-dark"\n')
    (legacy / 'documents.lua').write_text('unsaved documents and open folders\n')
    (legacy / 'recovery/untitled.txt').write_text('Unwritten changes: ação\n')
    migrate()
    for path in legacy.rglob('*'):
        if path.is_file():
            assert (target / path.relative_to(legacy)).read_bytes() == path.read_bytes()
    (target / 'settings.lua').write_text('new settings\n')
    (target / 'recovery/untitled.txt').write_text('new unsaved changes\n')
    migrate()
    assert (target / 'settings.lua').read_text() == 'new settings\n'
    assert (target / 'recovery/untitled.txt').read_text() == 'new unsaved changes\n'
    assert (legacy / 'recovery/untitled.txt').read_text() == 'Unwritten changes: ação\n'
    assert not list(target.parent.glob('.jotta-text-migrate.*'))
print('PASS: first-launch Flatpak migration preserves recovery and existing settings')
