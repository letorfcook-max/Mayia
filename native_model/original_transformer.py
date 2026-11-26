"""Exact MAYIA v0.4 architecture from the owner's scan, with bounded inference."""
import torch
from torch import nn
import torch.nn.functional as F


class MayiaModel(nn.Module):
    def __init__(self, vocab_size=256, context=128, dim=128, heads=4, layers=3):
        super().__init__()
        self.context = context
        self.config = dict(vocab_size=vocab_size, context=context, dim=dim, heads=heads, layers=layers)
        self.token = nn.Embedding(vocab_size, dim)
        self.position = nn.Embedding(context, dim)
        self.blocks = nn.ModuleList([nn.TransformerEncoderLayer(dim, heads, dim*4, dropout=0.1, batch_first=True, norm_first=True) for _ in range(layers)])
        self.norm = nn.LayerNorm(dim)
        self.head = nn.Linear(dim, vocab_size)

    def forward(self, x, targets=None):
        b,t = x.shape
        h = self.token(x) + self.position(torch.arange(t, device=x.device))
        mask = torch.triu(torch.ones(t,t,device=x.device,dtype=torch.bool),diagonal=1)
        for block in self.blocks:
            h = block(h,src_mask=mask)
        logits = self.head(self.norm(h))
        loss = F.cross_entropy(logits.reshape(-1,logits.size(-1)),targets.reshape(-1)) if targets is not None else None
        return logits,loss


class OriginalTransformer:
    def __init__(self, path, device='auto'):
        # Never fall back to arbitrary pickle execution or load a remote model.
        ck = torch.load(path, map_location='cpu', weights_only=True)
        if not isinstance(ck, dict) or not {'state','config','vocab','step'} <= ck.keys():
            raise ValueError('Not an original MAYIA v0.4 checkpoint (expected state, config, vocab, step)')
        c = ck['config']; v = ck['vocab']
        if not isinstance(c,dict) or set(c) != {'vocab_size','context','dim','heads','layers'} or any(type(x) is not int for x in c.values()):
            raise ValueError('Invalid MAYIA architecture configuration')
        if not (2 <= c['vocab_size'] <= 1024 and 16 <= c['context'] <= 4096 and 8 <= c['dim'] <= 1024 and 1 <= c['heads'] <= 32 and c['dim'] % c['heads'] == 0 and 1 <= c['layers'] <= 12):
            raise ValueError('Unsupported MAYIA architecture dimensions')
        if not isinstance(v,(list,tuple)) or len(v)!=c['vocab_size'] or any(not isinstance(x,str) or len(x)!=1 for x in v) or len(set(v)) != len(v) or ' ' not in v or '\n' not in v:
            raise ValueError('Invalid original character vocabulary')
        if not isinstance(ck['state'],dict) or any(not isinstance(x,torch.Tensor) for x in ck['state'].values()):
            raise ValueError('Invalid model state')
        self.device = ('cuda' if torch.cuda.is_available() else 'cpu') if device=='auto' else device
        if self.device not in ('cpu','cuda') or (self.device=='cuda' and not torch.cuda.is_available()):
            raise ValueError('CUDA not available in this Python runtime; select CPU or auto')
        if self.device == 'cpu':
            torch.set_num_threads(min(4, torch.get_num_threads()))
        self.vocab = list(v); self.lookup = {x:i for i,x in enumerate(v)}; self.context = c['context']; self.step = int(ck['step'])
        self.model = MayiaModel(**c)
        self.model.load_state_dict(ck['state'],strict=True)
        self.model.to(self.device).eval()
        self.parameters = sum(p.numel() for p in self.model.parameters())
        self.config = dict(c)
        del ck

    def prompt(self, messages):
        # Original training format only. System instructions and tool messages are
        # deliberately not injected into a model that never learned those roles.
        turns = []
        for msg in messages:
            role = msg.get('role'); content = msg.get('content')
            if role not in ('user','assistant'): continue
            if not isinstance(content,str): raise ValueError('Original MAYIA is text only')
            turns.append((role, content.replace('\r',' ').replace('\n',' ')))
        if not turns or turns[-1][0]!='user': raise ValueError('A final user message is required')
        prefix='User: '; suffix='\nMayia: '
        latest=turns[-1][1]; room=self.context-len(prefix)-len(suffix)
        truncated=len(latest)>room
        latest=latest[-room:]
        prompt=prefix+latest+suffix
        for role,content in reversed(turns[:-1][-4:]):
            item=('User: ' if role=='user' else 'Mayia: ')+content+'\n'
            if len(item)+len(prompt)>self.context: break
            prompt=item+prompt
        unsupported=sum(c not in self.lookup for c in prompt)
        # Matches the original API's unknown-character fallback.
        prompt=''.join(c if c in self.lookup else ' ' for c in prompt)
        return prompt,truncated,unsupported

    @torch.inference_mode()
    def generate(self, messages, tools, max_tokens, temperature):
        prompt, truncated, unsupported=self.prompt(messages)
        ids=torch.tensor([[self.lookup[c] for c in prompt]],dtype=torch.long,device=self.device)
        original=ids.shape[-1]; output=[]; stop=self.lookup['\n']; sampled=0
        for _ in range(min(max_tokens,100)):
            logits,_=self.model(ids[:,-self.context:]); scores=logits[:,-1,:]
            if temperature==0:
                nxt=scores.argmax(dim=-1,keepdim=True)
            else:
                scores=scores/max(temperature,0.1)
                top=torch.topk(scores,min(8,scores.shape[-1])).values
                scores=scores.masked_fill(scores<top[:,-1,None],float('-inf'))
                nxt=torch.multinomial(F.softmax(scores,dim=-1),1)
            token=nxt.item(); sampled+=1
            if token==stop: break
            output.append(self.vocab[token]); ids=torch.cat((ids,nxt),dim=1)
        text=''.join(output).strip()
        if not text: raise RuntimeError('Original transformer produced no visible text. Try a short greeting or another temperature; this checkpoint is experimental.')
        return text, {'prompt_tokens':original,'completion_tokens':sampled,'total_tokens':original+sampled,'context_truncated':truncated,'unknown_characters':unsupported}

    def info(self):
        return {'architecture':'MayiaModel character transformer','parameters':self.parameters,'context':self.context,'training_steps':self.step,'vocab_size':len(self.vocab),'device':self.device,'tools':False,'system_instructions':False}
