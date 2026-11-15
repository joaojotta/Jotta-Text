# GitHub trial

This is an optional **desktop-only experiment**. Enable it in **Preferences →
Settings → General → Experimental features → GitHub trial**, choose **Apply**,
then open **Tools → GitHub (experimental)…** or press **Ctrl+Alt+G**.
The switch defaults to off and persists between launches. Switching it off hides
the trial command and stops the panel. Normal startup starts no Git processes or
network requests. Disabling/removing the feature preserves your repositories
and commits.

## Try it

The initial panel has three steps:

1. **Sign in to GitHub**. The app displays and copies a one-time code, opens
   GitHub in your browser and waits for authorization. GitHub identifies the
   authorization as **GitHub CLI**. Close the panel to cancel. **Sign out** removes
   the account from the app's CLI configuration.
2. **Browse…** for the **local folder** you want to connect.
3. **Choose repository…** lists repositories you can write to, including private
   repositories. Type to filter, scroll or use the arrow keys and Enter. Use
   Next/Previous page for additional repositories. **New repository…** opens
   GitHub's repository creation page; refresh the picker after creating one.

Choose **Connect folder**, then **Sync now**. The app remembers the pairing and
fills missing Git author details locally from the signed-in account. Existing
author, signing and hook settings are retained. A matching SSH origin is changed
to HTTPS so it can use the browser login; a different origin is never replaced.

For an existing source folder, select an empty GitHub repository. An empty local
folder can instead download an existing repository. Connecting a populated folder
to an unrelated populated repository stops without overwriting its files.

Sync stages, commits and pushes all saved changes that Git tracks, respecting
`.gitignore`. It uses your message from Changes if provided, otherwise “Update
from Jotta Text”. Save open documents first. Incoming updates are applied only
as a fast-forward with a clean folder; unsaved work, local modifications alongside
incoming commits and divergent histories require review before continuing. A
failed push preserves the local commit so it can be retried. Sync is explicit;
there is no automatic upload when you type or save.

Choose **Changes…** for the detailed Git controls:

1. Open a local repository folder, or choose **Clone…**, enter its GitHub HTTPS
   or SSH URL, and choose a destination parent folder. A new folder is created
   using the repository name. Existing directories are not overwritten. Opening
   the clone keeps the normal save/discard/cancel prompts for your open documents.
2. **Refresh** / **F5** shows the current branch, changed paths, index/worktree
   status and the staged-file count. Click a path; Up/Down move through the list.
   The list supports the mouse wheel and a draggable scrollbar.
3. **Working diff** and **Staged diff** open an untitled snapshot for inspection.
   That snapshot is separate from the source file. **Stage file** and **Unstage
   file** change the Git index for the selected path.
4. Enter a commit message and choose **Commit staged** (or **Ctrl+Enter**). Git
   commits all currently staged files, including files staged outside Jotta Text.
   It uses saved disk content; unsaved editor buffers stay in the editor. Stale
   branch/index snapshots require another refresh before committing.
5. **Fetch** refreshes origin's remote branches. **Push** sends the current local
   branch to the same branch name on origin and sets its upstream. Push uses no
   force flag; divergent remote history is rejected. Review the displayed
   repository and branch before clicking it.
6. **GitHub**, **Issues** and **Pull requests** open the corresponding GitHub page
   in your default browser. This trial does not create issues or pull requests.

Git status supports normal repositories and linked worktrees. The first 1,000
changed paths are displayed. Untracked text diffs are limited to 256 KiB; tracked
diff output is bounded to 1 MiB. Submodule management, merge/rebase/conflict
resolution, branch creation, repository creation, force push and browser Git
integration are outside this trial. Fetch does not merge changes into your files.

## Git and authentication

Native Linux/AppImage and Windows portable builds use **installed Git** from
PATH. Install Git / Git for Windows and restart Jotta Text if the panel reports it
missing. The Flatpak includes a small Git runtime from its Freedesktop SDK;
it does not execute host programs or add a host-spawn permission.

The desktop packages include official GitHub CLI 2.83.1, pinned by archive SHA-256
in `tools/github-cli.lock.json`. Browser login is handled by that CLI with its
configuration under `USERDIR/github-auth`, outside the connected source folder.
Only the one-time code and account metadata are sent to the UI. Git operations
use the bundled helper for this login, overriding incompatible host credential
helpers for that operation without changing global Git configuration. URLs with
embedded credentials are rejected. Login requests workflow access so uploading
this project's GitHub Actions files works too.

GitHub CLI uses the system credential store when available. If it is unavailable,
it stores credentials in a private file (mode 0600) in that app settings directory;
the directory is created with mode 0700. Flatpak keeps its existing permissions,
including no host-spawn or additional secret-service access. Windows portable
keeps this configuration under `user/`; preserve your private copy during upgrades.

The advanced controls can still reuse existing Git authentication when no app
login is configured. SSH uses batch mode and an already trusted host key.
Git hooks and commit signing retain your Git configuration.

GitHub's [credential setup instructions](https://docs.github.com/en/get-started/git-basics/caching-your-github-credentials-in-git)
describe GitHub CLI and Git Credential Manager. Native/Windows installations can
reuse these tools when they are available in Git's environment. Flatpak uses
the bundled browser-login helper.

Network actions currently accept a single **github.com** origin URL. GitHub
Enterprise and multiple push URLs are not supported. Closing the panel cancels
the current operation; cancellation cannot undo an operation that has already
completed. Refresh afterward to inspect the repository's actual state.

## Validation and removal

```bash
vendor/litefront/node/node --test --test-isolation=none tests/test-github-trial.mjs
vendor/litefront/node/node --test --test-isolation=none tests/test-github-setup.mjs
python3 tests/test-github-trial.py
python3 tests/test-github-trial.py --flatpak-build dist/build
```

The backend tests clone/fetch/push only against disposable **local bare
repositories**, with a fake login helper/API for authentication tests. They cover
browser-code streaming, repository selection, connection persistence, ignored
files, first upload, empty-folder download, fast-forward sync and refusal of
divergent histories, plus staging, unstage, staged-only commits, stale state,
non-fast-forward rejection, literal/Unicode paths, linked worktrees and hooks.
The actual editor test checks the opt-in switch, keyboard/mouse input, Portuguese
labels, commit/diff behavior, unsaved buffer isolation, disabling and restart.
Public HTTPS cloning was also checked against GitHub's `octocat/Hello-World`
repository, including the Flatpak transport. Authenticated GitHub pushes have
not been performed as part of these tests.

The implementation is isolated in `profile/litefront/github/`, its small
`profile/plugins/litefront_github.lua` entry point and `tools/github-trial.mjs`.
The remaining integration points are the General setting, Tools menu entry,
bundle-copy line, URL-opening helper mode and Flatpak Git installer. No Lite XL
engine changes are needed. These can be removed together if the trial is not
useful; the first step is simply turning its setting off.
