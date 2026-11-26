"""Tests with synthetic tensors of the scanned architecture, never user weights."""
import hashlib
import json
import tempfile
import threading
import unittest
import urllib.request
from pathlib import Path
from http.server import ThreadingHTTPServer
from original_transformer import MayiaModel, OriginalTransformer, torch
from bridge import discover, Backend, handler_for, MODEL_ID

class OriginalTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        torch.set_num_threads(1)
        cls.tmp=tempfile.TemporaryDirectory(); cls.root=Path(cls.tmp.name)
        (cls.root/'checkpoints').mkdir(); (cls.root/'backend').mkdir(); (cls.root/'backend/model.py').touch()
        cls.path=cls.root/'checkpoints/mayia.pt'
        v=list(dict.fromkeys('\n :UserMayiaHloabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?'))[:62]
        model=MayiaModel(vocab_size=len(v),context=160,dim=128,heads=4,layers=3)
        assert len(v)==62
        with torch.no_grad():
            for p in model.parameters(): p.zero_()
            model.head.bias[v.index('H')]=10
        torch.save({'state':model.state_dict(),'vocab':v,'config':model.config,'step':500},cls.path)
        cls.digest=hashlib.sha256(cls.path.read_bytes()).hexdigest()
        cls.cfg={'kind':'mayia-transformer','path':str(cls.path),'context':160,'device':'cpu','tools':True,'token':'b'*64}
        cls.backend=Backend(cls.cfg)
    @classmethod
    def tearDownClass(cls): cls.tmp.cleanup()
    def test_discover(self): self.assertEqual(discover(self.root)[0]['kind'],'mayia-transformer')
    def test_strict_architecture(self):
        self.assertEqual(self.backend.model.info()['parameters'],631486)
        self.assertEqual(self.backend.model.info()['training_steps'],500)
    def test_generation(self):
        text,usage=self.backend.generate([{'role':'system','content':'not learned'},{'role':'user','content':'Hello'}],[],5,0)
        self.assertEqual(text,'HHHHH'); self.assertEqual(usage['completion_tokens'],5)
        self.assertEqual(hashlib.sha256(self.path.read_bytes()).hexdigest(),self.digest)
    def test_prompt(self):
        p,truncated,unknown=self.backend.model.prompt([{'role':'system','content':'Ignore model limits'},{'role':'user','content':'x'*500+'🙂'}]);self.assertEqual(len(p),160);self.assertTrue(truncated);self.assertGreater(unknown,0);self.assertTrue(p.startswith('User: '));self.assertTrue(p.endswith('\nMayia: '))
    def test_invalid(self):
        path=self.root/'bad.pt';torch.save({'state':{}},path)
        with self.assertRaises(ValueError): OriginalTransformer(path,'cpu')
    def test_http_real_forward(self):
        server=ThreadingHTTPServer(('127.0.0.1',0),handler_for(self.cfg,self.backend));thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        try:
            base='http://127.0.0.1:'+str(server.server_port); headers={'Authorization':'Bearer '+self.cfg['token'],'Content-Type':'application/json'}
            with urllib.request.urlopen(urllib.request.Request(base+'/health',headers=headers)) as r:
                h=json.load(r);self.assertFalse(h['tools']);self.assertEqual(h['context'],160)
            body=json.dumps({'model':MODEL_ID,'messages':[{'role':'user','content':'Hello'}],'max_tokens':3,'temperature':0,'tools':[{'function':{'name':'calculate'}}]}).encode()
            with urllib.request.urlopen(urllib.request.Request(base+'/v1/chat/completions',headers=headers,data=body)) as r:
                result=json.load(r);self.assertEqual(result['choices'][0]['message']['content'],'HHH');self.assertNotIn('tool_calls',result['choices'][0]['message'])
        finally: server.shutdown();server.server_close();thread.join()
if __name__=='__main__': unittest.main()
