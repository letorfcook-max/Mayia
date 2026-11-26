# MAYIA ONE 5.0 source preview

## New desktop operations
Open Mission control in the sidebar. Create a project and select it; existing personal chats remain in Personal workspace. New chats carry the selected project ID. Set a fast/deep model ID supported by your configured endpoint. Auto chooses the deep preference for Cowork and the fast preference for Chat. Project instructions and selected workflow are sent to the provider. Knowledge remains a global library; Cowork folders are selected separately. Global memory stays opt-in and can be excluded per project.

Reminders run only while Electron is open, checked every 15 seconds; once/hourly/daily/weekly. They use fixed elapsed intervals rather than calendar recurrence, and one catch-up notification after missed intervals. They do not execute AI tasks. Review calls three role prompts in sequence to the configured model, after confirmation; this is not an autonomous agent team. Workflow templates are instructions only, not executable code. GitHub and Wikipedia read publicly available data on fixed hosts; verify sources yourself. Teams is a local roster, not access control. Artifacts preview plain source text without execution.

## Browser companion
Set a strong local token (minimum 32 characters). With Ollama started and a compatible model installed:

```powershell
$env:MAYIA_LOCAL_TOKEN = node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
$env:MAYIA_MODEL = 'llama3.2'
$env:MAYIA_LOCAL_TOKEN
npm run web
```

Open http://127.0.0.1:8787/ and enter the displayed token. Keep it private. The browser sends chat requests to the same-origin gateway; the token and conversations stay in tab memory until refresh. The web companion uses non-streaming text chat. The API intentionally binds to loopback; do not expose it through port forwarding. A public deployment needs TLS, authentication, separate user storage, quotas and infrastructure review. `/v1/usage` (token required) reports in-memory accepted request count, completed provider responses, caught failures, active count and start time; it is not billing data. Counters reset on restart. The manifest is provided for browser presentation; native mobile apps and offline PWA service worker are not included.

## Backup and training
Encrypted exports cover conversations only, with scrypt and AES-256-GCM. The local chat/knowledge/roster stores are not encrypted. Imports merge by chat ID (imported wins); project IDs unknown on this device move to Personal. Back up the original data first. Export dataset train/test examples as separate JSONL files. Existing `model/train.py` creates a small intent classifier; `model/train_transformer.py` trains a byte transformer on licensed text. `python model/generate.py tiny-mayia.pt "Hello"` runs experimental generation after training, not capable assistant inference. No new production model weights are bundled. Torch is optional and not installed by npm.

## Verification scope
Run `npm run check`, then install dependencies and `npm run build` and test native Electron. Local tests mock external provider calls or use loopback HTTP, not real paid providers. No production certification, deployment, live GitHub modification, or signed installers. See MILESTONES.md for remaining gaps.
