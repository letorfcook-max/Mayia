'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const n=require('../electron/native-model.cjs');
test('original model settings select local endpoint and text model',()=>{const s=n.nativeSettings({theme:'light'});assert.equal(s.endpoint,'http://127.0.0.1:8766/v1');assert.equal(s.model,'mayia-local');assert.equal(s.streaming,false);assert.equal(s.theme,'light');});
test('native model credential is scoped to exact loopback endpoint',()=>{assert.equal(n.isNative({endpoint:'https://example.org/v1'}),false);assert.equal(n.isNative({endpoint:'http://127.0.0.1:8766/v1/'}),true);assert.equal(n.isNative({endpoint:'http://127.0.0.1:8766/v1?other=true'}),false);assert.equal(n.providerKey({endpoint:'http://127.0.0.1:9999/v1'}),'');});
