> **Original MAYIA model integration:** This revision supports the exact custom character transformer identified in your November 26 scan. Run `connectmodel.bat`, `testmodel.bat`, then `webstart.bat` or `runapp.bat`. See `docs/ORIGINAL_SCAN_FINDINGS.md`.

# MAYIA ONE 5.0 — Intelligence Workspace (source preview)

An upgraded source project based on the MAYIA NEXT 2.0 archive (which was based on 1.1), preserving its Electron app, chat history, settings, native tool protocol, workspace permissions, backup/import, and existing tests. New versions 1.2–2.0 are represented by working source implementations, with unfinished production work explicitly marked on the milestone page. No simulated provider answers or generated assets.

## Start
Install Node.js 22+ and Ollama, or configure an OpenAI-compatible cloud provider. On Windows run `START_MAYIA.bat`, or `npm install` followed by `npm run desktop:dev`. On macOS/Linux run the same npm commands from a terminal. Start Ollama and install a model e.g. `ollama pull llama3.2` before chatting locally. Verify your model supports function calls, streaming, or images before enabling those options. Disable tools or streaming if unsupported. Cloud API keys come from `MAYIA_API_KEY` in the environment; Brave Search requires `MAYIA_BRAVE_KEY`. Cloud providers may charge. No API keys included.

## ONE capabilities
- Mission Control: project-scoped chat history, instructions and model profiles; reusable workflows; reminders; supervised three-role review; public repository and article readers; dataset management; encrypted conversation export; local roster and activity log.
- Web companion: responsive text chat using the local authenticated API. See [ONE documentation](docs/ONE.md) and [milestone status](MILESTONES.md).
- Tool lifecycle: real completion/failure, permission and artifact events; concurrent pure-tool batches preserve result order.

## Retained V2 capabilities
- Chat / Cowork: streaming text, bounded context (character heuristic, not a tokenizer), model discovery, native `called_tool`, task plans, approved file list/read/create/edit, diff previews, restore when unchanged since edit, and text artifacts.
- Research: opt-in Brave search with actual snippets and source URLs, Wikipedia fallback. Each search is approved. Multiple search calls possible in Cowork. Results are snippets, not full-page verified citations; model citation claims still need review.
- Knowledge: import UTF-8 text documents (128 KiB each), local lexical retrieval, optional manually saved memory, interactive AI-generated flashcards and quizzes. Select a document to make a study set; up to 12,000 characters sent after approval. Library data is stored in local userData, not encrypted; remove individual entries in the UI. Chat backups do not include knowledge or rollback records.
- Studio: attach PNG/JPEG/WebP to a chat once (not saved or resent as image in chat history), image generation, transcription, text-to-speech, video job submission/status/download. All use real compatible endpoints. Choose the correct provider and media model; some APIs return formats not supported here. Image adapter needs base64 responses; video requires a compatible jobs API. No live microphone or camera.
- Developer: authenticated loopback API (`npm run api`), rate/concurrency limit; docs/API.md. Model lab trains a real multilingual intent classifier (included) and optionally a small causal transformer on licensed user text (not pre-trained or bundled). These are experiments, not a replacement LLM for chat. No cloud accounts or billing.
- Updates: find stable semantic-version GitHub releases with platform/architecture-matching assets, stage SHA-256-verified installer download if GitHub supplies digest, then manually install. Legacy `mayia` release ZIPs are deliberately excluded. Hash is integrity verification, not publisher authentication. No self-replacement or automatic restart; signed releases and native installer tests are outstanding.

## Build and release
`npm run check` checks backend syntax and executes tests. `npm run build` compiles the renderer. Windows: `CREATE_INSTALLER.bat` or `npm run dist:win`. macOS: `bash CREATE_MAC.command` or `npm run dist:mac`; run natively. Linux: `npm run dist`. Outputs in `release/`. GitHub Actions builds on all three platforms; artifacts are not automatically published. See docs/RELEASE.md for the release process. Native installers are not in this source ZIP. Dependencies require network access. Use the app with workspaces you trust; path and symlink checks are not a sandbox against malicious local concurrent filesystem manipulation. No shell execution, file deletion, or background agent. Reviewed edits are single-file, not atomic across multiple files; rollback backups contain previous file text and remain on device.

## Compatibility
App name/appId retained, but userData location can vary by packaging/runtime. Export the v1.1 conversation backup before migrating and import if necessary. Original v0.x binary/model files were never included in v1.1 and are not included here. Existing v1.1 preferences and chat JSON are accepted; no automatic migration of v0.x data. Keep the original project and backups until native testing succeeds.

## Windows launcher repair
Use `runapp.bat`, `webstart.bat`, `creategithubfiles.bat`, and `createexeandmac.bat`. The Mac build uses GitHub Actions on a native macOS runner, started from Windows only after approval. See [Windows launchers](docs/WINDOWS_LAUNCHERS.md) for prerequisites, exact outputs and troubleshooting.

## Original MAYIA integration
See [docs/ORIGINAL_MODEL.md](docs/ORIGINAL_MODEL.md). Start with `connectmodel.bat`, then `testmodel.bat`, then `webstart.bat` or `runapp.bat`. Original model files stay in `C:\Documents\Mayia`.
