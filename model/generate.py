"""Generate text from a locally trained TinyMayia checkpoint. Not a chat model."""
import argparse
import torch
from train_transformer import TinyMayia

def main():
    p = argparse.ArgumentParser()
    p.add_argument('checkpoint')
    p.add_argument('prompt')
    p.add_argument('--bytes', type=int, default=200)
    p.add_argument('--temperature', type=float, default=.8)
    a = p.parse_args()
    if not 1 <= a.bytes <= 4096 or not 0.1 <= a.temperature <= 2:
        p.error('bytes: 1–4096; temperature: 0.1–2')
    checkpoint = torch.load(a.checkpoint, map_location='cpu', weights_only=True)
    if checkpoint.get('format') != 'tiny-mayia-byte-v1' or checkpoint.get('context') != 128 or checkpoint.get('width') != 128:
        raise ValueError('Expected a locally trained TinyMayia checkpoint')
    model = TinyMayia(); model.load_state_dict(checkpoint['state_dict']); model.eval()
    tokens = list(a.prompt.encode('utf-8')) or [32]
    with torch.inference_mode():
        for _ in range(a.bytes):
            x = torch.tensor([tokens[-128:]], dtype=torch.long)
            probabilities = torch.softmax(model(x)[0, -1] / a.temperature, dim=-1)
            tokens.append(int(torch.multinomial(probabilities, 1).item()))
    print(bytes(tokens).decode('utf-8', errors='replace'))
if __name__ == '__main__': main()
