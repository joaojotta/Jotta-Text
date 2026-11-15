#!/usr/bin/env python3
"""Verify rounded-surface edge coverage, symmetry, clipping, alpha and HiDPI."""
from pathlib import Path
import shlex
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='jotta-text-rounded-') as directory:
    binary=Path(directory)/'check-rounded'
    flags=shlex.split(subprocess.check_output(['pkg-config','--cflags','--libs','sdl2'],text=True))
    subprocess.run(['cc','-O2','-Wall','-Wextra','-Werror','-I'+str(ROOT/'vendor/lite-xl/src'),str(ROOT/'tests/rounded-renderer.c'),str(ROOT/'vendor/lite-xl/src/rounded_rect.c'),'-o',str(binary),*flags,'-lm'],check=True)
    subprocess.run([str(binary)],check=True)
print('PASS: antialiased corners, symmetric edges, fractional geometry, clipping, alpha blending and HiDPI')
