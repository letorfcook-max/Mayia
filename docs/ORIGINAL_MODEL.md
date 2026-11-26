# Connect the original MAYIA model

The original installation is expected at `C:\Documents\Mayia`. This integration does not copy, delete, retrain, or upload any of its files. The new project is separate. The model weights are not included in this archive; they stay on your PC.

## Windows quick start

1. Extract the archive into a NEW folder (do not overwrite `C:\Documents\Mayia` or reuse broken `node_modules`).
2. Double-click `connectmodel.bat`. It scans the original root using its `.venv\Scripts\python.exe` when working, otherwise a system Python. Select the actual full model or fine-tuned adapter. If prompted for a base, provide the exact original local base model folder (a cached copy can be suggested). No model is downloaded.
3. Double-click `testmodel.bat`. This actually loads the selected checkpoint and generates a short answer. Check the device and the result. The command fails if the weights or runtime are incompatible.
4. `runapp.bat` starts the model, validates Electron and launches the app. `webstart.bat` uses the same model and runs without Electron. The launcher waits for authenticated readiness. It stops the model it started when it closes. If using both clients or an installed app, first run `startmodel.bat` in a separate console and leave it open. Then either launcher can reuse that process. Close it when finished.
5. If using an installed desktop app, run `startmodel.bat` from this source kit and select **Settings → Use my original MAYIA model**. Discover models returns `mayia-local`. That is an API alias for the checkpoint you selected, not a new model.

`scanmodel.bat` only lists recognized candidates; it does not execute the old scripts. To use a different folder, open PowerShell in this source folder and run `$env:MAYIA_ORIGINAL_ROOT = 'D:\path\Mayia'` then `./connectmodel.bat`. Existing selections are stored in `%LOCALAPPDATA%\MayiaNative\connection.json` (paths, options and a random local token). Do not upload this file. Run setup again to change models; stop the previous server first.

## Exact original MAYIA v0.4 support

The scan identified `C:\Documents\Mayia\checkpoints\mayia.pt` and `backend/model.py`. Select `[mayia-transformer]` in connectmodel.bat. The original class and character vocabulary are supported directly; no Transformers, Ollama, downloads or retraining required. The loader reads `state`, `config`, `vocab`, and `step` using `torch.load(..., weights_only=True)` and checks all tensor shapes through strict state loading. Select auto or CPU; the scanned PyTorch installation is CPU-only. See [scan findings](ORIGINAL_SCAN_FINDINGS.md).

## Supported formats

- Full Hugging Face causal LM directory: `config.json` plus model weights (prefer safetensors) and tokenizer files. Uses the original `torch` and `transformers` environment.
- PEFT/LoRA directory: `adapter_config.json` and `adapter_model.safetensors` (or trusted legacy `.bin`). Requires the *matching original base* weights and tokenizer plus `peft`. The adapter is actually applied using `PeftModel.from_pretrained`, never ignored. An incorrect base can fail or degrade results. Check the original training metadata.
- GGUF: a complete model file supported by installed `llama-cpp-python`. GPU offload depends on the build and available VRAM. Multi-part files require a runtime that supports those splits.
- Original `checkpoints/mayia.pt`: supported for the scanned MAYIA architecture. Other raw `.pt`, `.pth`, `.ckpt`: detected, not loaded generically. These can be a state dict, optimizer state, TorchScript, custom architecture or something else. Never rename them or load arbitrary pickles. If your actual model is one of these, provide the original `chat_mayia.py`, `mayia2.py`, `mayia2_config.json` (remove secrets), `requirements.txt`, and the model directory listing. The bridge needs the original model class, tokenizer, inference function and prompt format to integrate exactly. No need to upload gigabytes of weights.

No dependency or model installation is performed automatically in the Python environment. If imports fail, inspect the existing Python environment and original `requirements.txt`; install missing compatible libraries into a separate environment or your own original environment after reviewing the changes. GPU inference requires a matching CUDA-enabled PyTorch build. For legacy `.bin` checkpoints the bridge requires explicit trust confirmation and PyTorch >=2.6. Only use your own trusted files. Custom model code via `trust_remote_code` is disabled. The HF engine uses FP16 on CUDA, FP32 on CPU; it does not automatically quantize or offload very large models. Use a suitable checkpoint and sufficient VRAM/RAM. Context and generation are bounded, and old turns can be dropped to fit. The prompt template is taken from the original tokenizer if supported; otherwise role-labeled text is used, which may not match old training formats.

## App capabilities and limitations

The bridge is bound to 127.0.0.1:8766 only and uses a local bearer token; chat is not forwarded to a cloud model. The web companion retains its separate access token. Explicit search tools may use the network if enabled and approved. No telemetry is added by the bridge. The existing app can still select other providers manually. A text model cannot produce real images, audio or video through this bridge. Studio needs a separate compatible media provider. Actual token-by-token streaming is not implemented for this bridge; the full response is returned when generated. Cancellation stops the desktop request but may not interrupt an in-progress Python generation. Only one generation is allowed at a time.

The original character transformer has native tool calling disabled and does not process system instructions, images, or document excerpts as a distinct instruction format. Other compatible checkpoints may support optional experimental function calling, which translates a strictly formatted model-generated `MAYIA_TOOL_CALL: {"name":"...","arguments":{...}}` line into a compatible function call. Only names actually offered by the app are accepted; the existing Cowork permissions still apply. The model must learn or follow this format. No tool call is invented by the bridge. If the model fails to follow it, disable tools or use normal chat. Tool definitions can consume significant context.

## Verification

`npm run check` runs existing Node tests and integration configuration tests. From `native_model`, run `python -m unittest -v test_bridge test_original` for discovery and authenticated HTTP tests using a stub backend (not real inference). `testmodel.bat` is the real inference test on your own PC. We inspected the exact architecture, checkpoint metadata, and tokenizer from the scan, but actual trained tensor values were not exported. Real inference with the original weights and native Windows executables remains unverified. Native installer and Mac workflow testing remain outstanding. The installers package the UI, not your private model or Python environment; the separate bridge source is required to start your local runtime.
