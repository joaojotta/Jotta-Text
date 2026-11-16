# Publish Jotta Text on GitHub

The current release is **0.7.0**. Suggested repository name: **jotta-text**.

## Prepare the source

From this project directory:

```bash
python3 tools/package-source.py
```

This creates `dist/JottaText-0.7.0-source.zip` and its SHA-256 checksum. Extract
it to a new directory and open a terminal in the extracted folder. The archive
includes the application source, engine patch, dependency locks, fonts, icons,
attribution, tests and GitHub Actions workflow. Downloaded dependencies, build
outputs, Git metadata and local configuration are excluded.

## Create the repository

In Jotta Text, enable **GitHub trial** in Settings, then open **Tools → GitHub
(experimental)…**. Sign in, choose the extracted source folder, create/select an
empty `jotta-text` repository, and choose **Connect folder → Sync now**. The app
sets up Git and the remote for you. The commands below are a terminal alternative.

Create an empty repository named `jotta-text` in your GitHub account, without
adding a README or other initial files. In the extracted source directory, run:

```bash
git init -b main
git add .
git commit -m "Initial Jotta Text 0.7.0 source"
git remote add origin https://github.com/joaojotta/jotta-text.git
git push -u origin main
```

Use your configured GitHub credentials when Git requests authentication.
The existing `.gitignore` keeps later builds and dependency downloads out of Git.
Run `python3 tools/check-source.py` before syncing to check that required source
files are present and no local clone has been added as an unconfigured submodule.
Keep `.gitattributes` in the repository so Windows checks out patches with LF
line endings.
Third-party source and asset license notices are preserved in the source and
redistributable packages; see [Credits and licenses](README.md#credits-and-licenses).

## Build the downloadable packages

After the push, **Actions → Build Jotta Text** builds and tests the Flatpak,
AppImage, Windows installer, Windows portable ZIP and browser ZIP. Every run keeps them in its
**Artifacts** section.

## Publish a release

Update `VERSION` and add a matching `## Jotta Text v<version> — <date>` entry to
`CHANGELOG.md`, then push to `main`. When every job passes, the **release** job
creates the `v<version>` tag on that commit and publishes a GitHub Release with
all five packages, their checksums and that changelog entry as release notes.
You do not need to create the tag yourself.

A push that keeps an already released `VERSION` is built and tested but not
published again. Pushing a `v<version>` tag by hand still works; it must match
`VERSION`. CI does not deploy the browser edition to a web server. Build commands
for local development are in [README.md](README.md),
[BUILD_UBUNTU.md](BUILD_UBUNTU.md) and [BUILD_WINDOWS.md](BUILD_WINDOWS.md).
