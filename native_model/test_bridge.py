import json
import tempfile
import threading
import unittest
import urllib.request
import urllib.error
from pathlib import Path
from http.server import ThreadingHTTPServer
from bridge import discover, parse_answer, plain_messages, handler_for, MODEL_ID, PREFIX

TOOLS=[{'type':'function','function':{'name':'calculate','parameters':{'type':'object'}}}]
class TestBridge(unittest.TestCase):
    def test_discovery(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d); (p/'mayia-adapter').mkdir(); (p/'mayia-adapter'/'adapter_config.json').write_text('{"base_model_name_or_path":"test/base"}'); (p/'mayia-adapter'/'adapter_model.safetensors').touch(); (p/'mayia-checkpoints').mkdir(); (p/'mayia-checkpoints'/'config.json').write_text('{}'); (p/'mayia-checkpoints'/'model.safetensors').touch(); (p/'own.gguf').touch(); (p/'old.pt').touch(); (p/'.venv').mkdir(); (p/'.venv'/'skip.gguf').touch()
            out=discover(p); self.assertEqual({x['kind'] for x in out},{'adapter','transformers','gguf','unknown'}); self.assertEqual(len(out),4); self.assertEqual(out[0]['base_hint'],'test/base')
    def test_tools(self):
        msg,reason=parse_answer(PREFIX+'{"name":"calculate","arguments":{"expression":"2+2"}}',TOOLS)
        self.assertEqual(reason,'tool_calls'); self.assertEqual(json.loads(msg['tool_calls'][0]['function']['arguments'])['expression'],'2+2')
        self.assertEqual(parse_answer(PREFIX+'{"name":"shell","arguments":{}}',TOOLS)[1],'stop')
        self.assertEqual(parse_answer(PREFIX+'{"name":"calculate","arguments":{}}',[])[1],'stop')
    def test_history(self):
        m=plain_messages([{'role':'system','content':'Be helpful'},{'role':'user','content':'2+2'},{'role':'assistant','content':None,'tool_calls':[{'function':{'name':'calculate','arguments':'{"expression":"2+2"}'}}]},{'role':'tool','content':'4'}],TOOLS)
        self.assertIn('Tools are optional',m[0]['content']); self.assertIn(PREFIX,m[2]['content']); self.assertIn('untrusted data',m[3]['content'])
    def test_text_only(self):
        with self.assertRaises(ValueError): plain_messages([{'role':'user','content':[{'type':'image_url'}]}],[])
    def test_http(self):
        class Fake:
            def generate(self,messages,tools,max_tokens,temperature):
                return 'Test response', {'total_tokens': 7}
        cfg={'token':'a'*64,'kind':'transformers','tools':False}; server=ThreadingHTTPServer(('127.0.0.1',0),handler_for(cfg,Fake())); thread=threading.Thread(target=server.serve_forever,daemon=True); thread.start()
        try:
            base='http://127.0.0.1:'+str(server.server_port)
            with self.assertRaises(urllib.error.HTTPError) as cm: urllib.request.urlopen(base+'/health')
            self.assertEqual(cm.exception.code,401)
            headers={'Authorization':'Bearer '+cfg['token'],'Content-Type':'application/json'}
            with urllib.request.urlopen(urllib.request.Request(base+'/health',headers=headers)) as r: self.assertEqual(json.load(r)['model'],MODEL_ID)
            body=json.dumps({'model':MODEL_ID,'messages':[{'role':'user','content':'hello'}],'stream':True}).encode()
            with urllib.request.urlopen(urllib.request.Request(base+'/v1/chat/completions',headers=headers,data=body)) as r: self.assertEqual(json.load(r)['choices'][0]['message']['content'],'Test response')
        finally: server.shutdown(); server.server_close(); thread.join()
if __name__=='__main__': unittest.main()
