# Windows launchers — MAYIA ONE 5.0

Extract the entire ZIP to a new folder (prefer a short path, e.g. `C:\Mayia\MAYIA_NEXT`). Keep the original project and exported chat backup. Do not copy the old `node_modules` folder. Install Node.js 22 LTS and ensure Node/npm are on PATH. Double-click the desired BAT. No administrator elevation is performed by these launchers.

| File | What it does |
|---|---|
| `webstart.bat` | Launches the built-in local web companion at `http://127.0.0.1:8787/` and prints its access token. Opens your browser on Windows. No Electron or npm installation needed. Keep the window open. |
| `runapp.bat` | Installs missing npm packages, checks Electron's `path.txt`, real binary and `--version`, then tries the official Electron installer and a clean Electron-only reinstall if needed. Starts desktop development mode. |
| `creategithubfiles.bat` | Copies an explicit source manifest plus package-lock.json if present into a new subfolder of `GITHUB_FILES`. Includes `.github/workflows`. Does not publish or alter GitHub. Review this folder before uploading; add any new source file to `scripts/github-source.json`. |
| `createexeandmac.bat` | Repairs dependencies, runs checks, builds Windows x64 NSIS locally, saves EXE and SHA-256 sidecar in `NATIVE_BUILDS/<timestamp>/Windows`. Asks for explicit YES to upload the source to an isolated `mayia-build/...` branch in `letorfcook-max/Mayia` and run native Mac CI. Waits for CI and downloads Intel and Apple Silicon DMGs/ZIPs to the corresponding `macOS` directory. |

`START_MAYIA.bat` and `CREATE_INSTALLER.bat` remain compatible aliases for desktop and Windows-only build. Existing app features, model settings, userData location and version are unchanged. No native installers are included in the source archive.

## Web
The local API is bound to loopback only. Paste the token printed in the terminal into the web companion. Do not share it. Web chat uses its own provider settings and is not the full desktop Cowork UI. Default is Ollama at `http://127.0.0.1:11434/v1` and `llama3.2`. Run `ollama pull llama3.2` if necessary. In PowerShell before starting the batch, optionally set `$env:MAYIA_ENDPOINT`, `$env:MAYIA_MODEL`, `$env:MAYIA_API_KEY` (remote provider only), `$env:MAYIA_API_PORT`, or `$env:MAYIA_LOCAL_TOKEN` (at least 32 characters). No credentials are written to source files. The server does not automatically load `.env`.

## Mac build from Windows
1. Install Git for Windows and GitHub CLI (`winget install --id Git.Git -e` and `winget install --id GitHub.cli -e`), then reopen the terminal.
2. Run `gh auth login --hostname github.com --web --git-protocol https`. The signed-in GitHub account needs write access to `letorfcook-max/Mayia` and permission to push workflow files; if needed, authorize workflow scope using `gh auth refresh -h github.com -s workflow`. GitHub Actions must be enabled and runner usage may be billed depending on the account. The workflow uses the repository's hosted macOS runner, not a Windows cross-compiler.
3. Run `createexeandmac.bat`. After successful Windows build, type YES to authorize the upload. A unique source-only branch is created (independent history, no changes to main or old release assets). The branch is left for auditing. Its push runs `.github/workflows/mayia-native.yml`; the launcher waits for the exact commit's successful run and downloads its artifacts. If the terminal closes, retrieve artifacts from the repository's Actions page. Do not merge the build branch blindly. No release is published automatically.
4. Verify both DMGs and test on actual Macs. No Developer ID signing/notarization credentials are supplied; the CI produces test builds only (may be ad-hoc signed). Apple Gatekeeper may reject them. Windows EXE is also not configured for trusted publisher signing. Configure legitimate signing credentials before distribution; do not disable OS security protections.

## Electron error recovery
The previous launcher only tested `node_modules/electron/package.json`, not whether the binary had actually installed. This launcher enables npm lifecycle scripts, unsets Electron binary-skip/override variables for its child processes, and repairs the Electron package only if necessary. It leaves chat history and other application files alone. If repair still fails, inspect the npm/installer error (network access to GitHub Electron releases and release-assets.githubusercontent.com, free space, proxy or antivirus quarantine). It does not change firewall, antivirus, or system execution policies. The project keeps its existing dependency versions; Electron 33 is old and should be upgraded and regression-tested before production distribution.

If Vite reports that port 5173 is occupied, stop the other development server. For NSIS errors involving symlink creation or winCodeSign extraction, inspect the exact error; Windows Developer Mode or an appropriately elevated terminal may be necessary for build tooling. This is separate from the Electron download error. The native build commands and Windows-specific launcher behavior require a real Windows test. GitHub branch push, macOS build and download require a live authenticated run.

## Mac-only retry after rollback history fix
From PowerShell in the updated project, run ` .\createexeandmac.bat mac` (without the leading space), then type `YES` to upload the fixed source and start a new Mac build. The Windows installer is not rebuilt. The launcher prints failed-step logs if the remote run fails. A new build branch is required; rerunning the old failed commit would reuse the old bug.
The rollback history now canonicalizes the workspace root using `fs.realpath`, matching the existing edit and rollback implementation. The native CI checks remain mandatory.
