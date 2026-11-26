# Original MAYIA integration — scan-based audit

Basis: MAYIA_FULL_SCAN_20261126_175849_140302.zip, specifically SOURCE_TXT/backend/model.py.txt, backend/api.py.txt, backend/train.py.txt, MODEL_METADATA/0001_mayia.pt.txt, and 04_ENVIRONMENT_AND_DEPENDENCIES.txt. The user’s actual trained weights are not in the scan. No original history, training examples, inventory, or personal report data is included here.

- Original root: C:\Documents\Mayia
- Python: 3.11.9, existing `.venv\Scripts\python.exe`
- Checkpoint: `checkpoints/mayia.pt`, 7,618,771 bytes, 500 steps
- Architecture: learned character embeddings, learned positional embeddings, three pre-norm TransformerEncoderLayers with causal masking, final LayerNorm, linear vocabulary head.
- Configuration: vocab_size=62, context=160, dim=128, heads=4, layers=3.
- 631,486 model parameters, counted from state tensors, excluding optimizer state.
- Checkpoint dictionary: state, optimizer, step, vocab, config. The ordered character vocabulary is part of the checkpoint. Inference ignores optimizer state.
- Original prompt: `User: ...\nMayia: `, with recent history; unsupported characters replaced with spaces; generate up to 100 characters using rolling context and stop on newline. The bridge preserves the prompt format and uses the original top-k=8 sampling with temperature; temperature zero additionally supports greedy decoding.
- Original API `reliable` uses curated responses, not neural inference. This bridge uses the original transformer only. No silent canned response, cloud fallback, or model substitution after an original-model connection is selected.
- Original environment reports torch 2.15.0+cpu, no CUDA build. The loader chooses CPU on auto when CUDA is unavailable. No dependency changes or model downloads are performed.
- Current model has a tiny context and vocabulary; generation may be short, incoherent, repetitive or empty. It does not have trained function calling or system-role instruction support. Chat and Cowork can send text, but autonomous tools and image input are disabled for this checkpoint. Projects and other application features remain available; they do not expand the model's abilities.

## Start

Extract to a fresh folder, keeping the original model where it is. Run connectmodel.bat; choose the `mayia-transformer` candidate and auto device. Run testmodel.bat, then webstart.bat (no Electron) or runapp.bat. The bridge will authenticate its loopback endpoint on port 8766 and the web app uses its own separate access token. If installed desktop is used, startmodel.bat must remain running and select original model in Settings. Mac/Windows builds remain source-only, not tested native installers.

## Verification

63 Node tests and 11 Python tests. The six new Python tests use a synthetic state dict with the exact architecture dimensions and parameter count, including actual CPU forward passes and an authenticated HTTP round trip, not a trained quality benchmark. Tests confirm strict loading, read-only inference, bounded prompt, and no tool execution. Real original weight values, quality, Windows Electron binary repair and native packaging remain untested. Existing Python packages are used; no retraining or modifications to the original root. The local API is not a production multi-user service. No GitHub changes made.
