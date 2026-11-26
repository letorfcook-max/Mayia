"""Optional tiny byte-level causal transformer. Requires torch. Train on your own licensed corpus."""
import argparse, pathlib, torch
from torch import nn
class TinyMayia(nn.Module):
    def __init__(self, context=128, width=128):
        super().__init__();self.context=context;self.embedding=nn.Embedding(256,width);self.position=nn.Embedding(context,width);self.layers=nn.TransformerEncoder(nn.TransformerEncoderLayer(width,4,4*width,batch_first=True,dropout=.1),3);self.head=nn.Linear(width,256)
    def forward(self,x):
        n=x.shape[1];h=self.embedding(x)+self.position(torch.arange(n,device=x.device));mask=torch.triu(torch.ones(n,n,device=x.device,dtype=torch.bool),1);return self.head(self.layers(h,mask=mask,is_causal=True))
def main():
    p=argparse.ArgumentParser();p.add_argument('corpus',type=pathlib.Path);p.add_argument('--steps',type=int,default=1000);p.add_argument('--out',default='tiny-mayia.pt');a=p.parse_args();torch.manual_seed(42);device='cuda' if torch.cuda.is_available() else 'cpu';raw=a.corpus.read_bytes();assert len(raw)>=10000,'Provide at least 10 KB of licensed text';data=torch.tensor(list(raw),dtype=torch.long);split=int(len(data)*.9);train,val=data[:split],data[split:];model=TinyMayia().to(device);opt=torch.optim.AdamW(model.parameters(),lr=3e-4);lossfn=nn.CrossEntropyLoss()
    def batch(d):
        idx=torch.randint(len(d)-129,(16,));x=torch.stack([d[i:i+128] for i in idx]).to(device);y=torch.stack([d[i+1:i+129] for i in idx]).to(device);return x,y
    for i in range(a.steps):
        model.train();x,y=batch(train);loss=lossfn(model(x).reshape(-1,256),y.reshape(-1));opt.zero_grad();loss.backward();torch.nn.utils.clip_grad_norm_(model.parameters(),1);opt.step()
        if i%100==0 or i==a.steps-1:
            model.eval();x,y=batch(val)
            with torch.no_grad():v=lossfn(model(x).reshape(-1,256),y.reshape(-1))
            print(f'step {i} train {loss.item():.4f} validation {v.item():.4f}',flush=True)
    torch.save({'state_dict':model.state_dict(),'context':128,'width':128,'format':'tiny-mayia-byte-v1'},a.out)
if __name__=='__main__':main()
