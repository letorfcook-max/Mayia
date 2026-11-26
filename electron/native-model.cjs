'use strict';
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const ENDPOINT='http://127.0.0.1:8766/v1',MODEL='mayia-local';
function configPath(){return path.join(process.env.LOCALAPPDATA||path.join(os.homedir(),'.local','share'),'MayiaNative','connection.json')}
function readConfig(){try{const c=JSON.parse(fs.readFileSync(configPath(),'utf8'));if(!/^[a-f0-9]{64}$/.test(c.token)||typeof c.python!=='string')return null;return c}catch{return null}}
function isNative(s){return String(s?.endpoint||'').replace(/\/$/,'')===ENDPOINT}
function nativeSettings(s={}){return {...s,provider:'custom',endpoint:ENDPOINT,model:MODEL,streaming:false,maxTokens:512}}
function nativeCapabilities(s){const c=isNative(s)?readConfig():null;return c?{kind:c.kind,tools:c.kind!=='mayia-transformer'&&c.tools===true,context:c.context}:null}
function providerKey(s){if(isNative(s))return readConfig()?.token||'';const host=new URL(s.endpoint).hostname;return s.provider==='ollama'||['localhost','127.0.0.1','[::1]'].includes(host)?'':process.env.MAYIA_API_KEY||''}
module.exports={ENDPOINT,MODEL,configPath,readConfig,isNative,nativeSettings,nativeCapabilities,providerKey};
