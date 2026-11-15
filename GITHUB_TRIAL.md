# GitHub trial

This is an optional **desktop-only experiment**. Enable it in **Preferences →
Settings → General → Experimental features → GitHub trial**, choose **Apply**,
then open **Tools → GitHub (experimental)…** or press **Ctrl+Alt+G**.
The switch defaults to off and persists between launches. Switching it off hides
the trial command and stops the panel. Normal startup starts no Git processes or
network requests. Disabling/removing the feature preserves your repositories
and commits.

## Try it

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

Configure your Git author identity and GitHub authentication outside Jotta Text
before committing or accessing private repositories. Existing credential helpers
or configured SSH keys handle authentication. The app does not ask for, save or
log a GitHub token. URLs with embedded credentials are rejected. SSH uses batch
mode and an already trusted host key; interactive terminal authentication is
unavailable. Git hooks and commit signing retain your Git configuration.

GitHub's [credential setup instructions](https://docs.github.com/en/get-started/git-basics/caching-your-github-credentials-in-git)
describe GitHub CLI and Git Credential Manager. Native/Windows installations can
reuse these tools when they are available in Git's environment. Flatpak has its
own environment: host-only credential helpers and external SSH-agent sockets may
be unavailable. Use the native build to try your existing host authentication
without changing Flatpak permissions.

Network actions currently accept a single **github.com** origin URL. GitHub
Enterprise and multiple push URLs are not supported. Closing the panel cancels
the current operation; cancellation cannot undo an operation that has already
completed. Refresh afterward to inspect the repository's actual state.

## Validation and removal

```bash
vendor/litefront/node/node --test --test-isolation=none tests/test-github-trial.mjs
python3 tests/test-github-trial.py
python3 tests/test-github-trial.py --flatpak-build dist/build
```

The backend tests clone/fetch/push only against disposable **local bare
repositories**. They cover staging, unstage, staged-only commits, stale state,
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
