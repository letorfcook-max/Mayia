'use strict';
const fs=require('node:fs'), path=require('node:path'), os=require('node:os'), crypto=require('node:crypto');
const {spawnSync,spawn}=require('node:child_process');
const readline=require('node:readline/promises');
const ROOT=path.resolve(__dirname,'..');
const REPO='letorfcook-max/Mayia';
const cleanEnv=()=>{const e={...process.env};for(const k of Object.keys(e))if(['electron_skip_binary_download','electron_override_dist_path','electron_run_as_node'].includes(k.toLowerCase()))delete e[k];e.npm_config_ignore_scripts='false';return e};
function run(exe,args,{cwd=ROOT,env=process.env,capture=false,allowFailure=false,timeout}={}){
  const result=spawnSync(exe,args,{cwd,env,stdio:capture?['ignore','pipe','pipe']:'inherit',encoding:'utf8',windowsHide:true,timeout});
  if(result.error||result.status!==0){if(allowFailure)return null;throw Error(`${exe} exited ${result.status??'with an error'}${result.error?': '+result.error.message:''}${capture&&result.stderr?'\n'+result.stderr.trim():''}`)}
  return capture?result.stdout.trim():true;
}
function npm(args,opts={}){
  // The arguments below are fixed by this source; no user-supplied shell strings.
  if(process.platform==='win32'){
    if(args.some(x=>!(/^[a-zA-Z0-9:._=-]+$/.test(x))))throw Error('Invalid npm argument');
    return run(process.env.ComSpec||'cmd.exe',['/d','/s','/c','npm '+args.join(' ')],{env:cleanEnv(),...opts});
  }
  return run('npm',args,{env:cleanEnv(),...opts});
}
function electronBinary(root=ROOT,platform=process.platform){
  const base=path.join(root,'node_modules','electron');
  try{const rel=fs.readFileSync(path.join(base,'path.txt'),'utf8').trim();const expected=platform==='win32'?'electron.exe':platform==='darwin'?'Electron.app/Contents/MacOS/Electron':'electron';if(rel.replace(/\\/g,'/')!==expected)return null;const binary=path.join(base,'dist',expected);return fs.statSync(binary).isFile()&&fs.statSync(binary).size>0?binary:null}catch{return null}
}
function verifyElectron(){const binary=electronBinary();return !!(binary&&run(binary,['--version'],{env:cleanEnv(),capture:true,allowFailure:true,timeout:30000}));}
function ensureDependencies(){
  const pkg=JSON.parse(fs.readFileSync(path.join(ROOT,'package.json'),'utf8'));
  if(Number(process.versions.node.split('.')[0])<22)throw Error('Install Node.js 22 LTS or newer first.');
  const missing=Object.keys({...pkg.dependencies,...pkg.devDependencies}).some(n=>!fs.existsSync(path.join(ROOT,'node_modules',n,'package.json')));
  if(missing){console.log('[1/3] Installing npm dependencies, including Electron binary…');try{npm(['install','--include=dev','--ignore-scripts=false','--no-audit','--no-fund']);}catch(e){if(Object.keys({...pkg.dependencies,...pkg.devDependencies}).some(n=>!fs.existsSync(path.join(ROOT,'node_modules',n,'package.json')))||verifyElectron())throw e;console.log('npm left package metadata but Electron is broken; attempting recovery.');}}
  if(!verifyElectron()){
    console.log('[2/3] Electron binary missing or invalid. Running its official installer…');
    const installer=path.join(ROOT,'node_modules','electron','install.js');
    if(fs.existsSync(installer))run(process.execPath,[installer],{env:cleanEnv(),allowFailure:true});
    if(!verifyElectron()){
      console.log('[repair] Removing only the broken Electron npm package and retrying with a fresh Electron download cache.');
      fs.rmSync(path.join(ROOT,'node_modules','electron'),{recursive:true,force:true});
      const cache=fs.mkdtempSync(path.join(os.tmpdir(),'mayia-electron-cache-'));
      try{npm(['install','--include=dev','--ignore-scripts=false','--no-audit','--no-fund'],{env:{...cleanEnv(),electron_config_cache:cache,ELECTRON_CACHE:cache}})}finally{fs.rmSync(cache,{recursive:true,force:true})}
    }
  }
  if(!verifyElectron())throw Error('Electron still cannot start. Check access to github.com/electron/electron/releases and release-assets.githubusercontent.com, antivirus quarantine, proxy settings and disk space. No system security settings were changed.');
  console.log('[3/3] Electron executable verified.');
}
function stageSource(root=ROOT,outRoot=path.join(ROOT,'GITHUB_FILES')){
  const version=JSON.parse(fs.readFileSync(path.join(root,'package.json'),'utf8')).version;
  if(!/^\d+\.\d+\.\d+$/.test(version))throw Error('Expected a semantic package version');
  const stamp=new Date().toISOString().replace(/[^0-9]/g,'').slice(0,17)+'-'+crypto.randomBytes(3).toString('hex');
  const dest=path.join(outRoot,`Mayia-${version}-${stamp}`);
  const manifest=JSON.parse(fs.readFileSync(path.join(root,'scripts','github-source.json'),'utf8'));
  fs.mkdirSync(dest,{recursive:true});
  for(const name of [...new Set([...manifest,...(fs.existsSync(path.join(root,'package-lock.json'))?['package-lock.json']:[])])]){
    if(typeof name!=='string'||name.includes('\\')||name.split('/').some(x=>!x||x==='.'||x==='..')||path.isAbsolute(name))throw Error('Invalid source manifest path');
    let src=root;for(const part of name.split('/')){src=path.join(src,part);if(fs.lstatSync(src).isSymbolicLink())throw Error('Source symlinks are not supported: '+name)}
    if(!fs.statSync(src).isFile())throw Error('Not a source file: '+name);
    const target=path.join(dest,name);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(src,target);
  }
  console.log('GitHub-ready source: '+dest);return dest;
}
function listInstallers(dir,ext){return fs.readdirSync(dir,{withFileTypes:true}).filter(x=>x.isFile()&&x.name.endsWith(ext)).map(x=>path.join(dir,x.name));}
function checksum(file){const hash=crypto.createHash('sha256'),fd=fs.openSync(file,'r');try{const buf=Buffer.alloc(1024*1024);let n;while((n=fs.readSync(fd,buf,0,buf.length,null))>0)hash.update(buf.subarray(0,n));}finally{fs.closeSync(fd)}return hash.digest('hex');}
function copyInstallers(files,dest){fs.mkdirSync(dest,{recursive:true});for(const f of files){const target=path.join(dest,path.basename(f));if(path.resolve(f)!==path.resolve(target))fs.copyFileSync(f,target);fs.writeFileSync(target+'.sha256',`${checksum(target)}  ${path.basename(target)}\n`);console.log('Verified output: '+target)}}
function windowsBuild(){ensureDependencies();npm(['run','check']);const release=path.join(ROOT,'release');fs.mkdirSync(release,{recursive:true});const started=Date.now();npm(['run','dist:win'],{env:{...cleanEnv(),CSC_IDENTITY_AUTO_DISCOVERY:'false'}});const files=listInstallers(release,'.exe').filter(f=>fs.statSync(f).mtimeMs>=started-2000);if(!files.length)throw Error('Build returned without a new Windows installer.');return files;}
async function macBuild(source,dest){
  run('git',['--version']);run('gh',['--version']);run('gh',['auth','status','--hostname','github.com']);
  const repo=JSON.parse(run('gh',['repo','view',REPO,'--json','nameWithOwner,viewerPermission'],{capture:true}));if(repo.nameWithOwner.toLowerCase()!==REPO.toLowerCase()||!['ADMIN','MAINTAIN','WRITE'].includes(repo.viewerPermission))throw Error('GitHub account needs write access to '+REPO);
  const branch='mayia-build/'+path.basename(source).toLowerCase();
  console.log('Creating isolated source-only branch '+branch+' (main and existing releases will not change).');
  run('git',['init','-b',branch],{cwd:source});run('git',['add','--all'],{cwd:source});run('git',['-c','user.name=Mayia Build','-c','user.email=mayia-build@users.noreply.github.com','-c','commit.gpgsign=false','commit','-m','Build MAYIA native installers'],{cwd:source});
  const sha=run('git',['rev-parse','HEAD'],{cwd:source,capture:true});
  run('git',['-c','credential.helper=','-c','credential.helper=!gh auth git-credential','push',`https://github.com/${REPO}.git`,`HEAD:refs/heads/${branch}`],{cwd:source});
  console.log(`Native Mac build: https://github.com/${REPO}/actions`);
  let id;for(let attempt=0;attempt<36;attempt++){
    const runs=JSON.parse(run('gh',['run','list','--repo',REPO,'--branch',branch,'--limit','20','--json','databaseId,headSha,workflowName'],{capture:true}));
    id=runs.find(r=>r.headSha===sha&&r.workflowName==='MAYIA Native Mac Build')?.databaseId;if(id)break;await new Promise(r=>setTimeout(r,5000));
  }
  if(!id)throw Error('GitHub did not start the Mac workflow. Check Actions settings, permissions, and the branch '+branch);
  console.log('Waiting for GitHub Actions run '+id+'; this terminal can remain open.');
  run('gh',['run','watch',String(id),'--repo',REPO,'--exit-status']);
  fs.mkdirSync(dest,{recursive:true});run('gh',['run','download',String(id),'--repo',REPO,'--name','macos-installers','--dir',dest]);
  const dmgs=listInstallers(dest,'.dmg');if(!dmgs.some(f=>path.basename(f).includes('arm64'))||!dmgs.some(f=>path.basename(f).includes('x64')))throw Error('Mac build did not return both architectures. Inspect run '+id);
  copyInstallers([...dmgs,...listInstallers(dest,'.zip')],dest);
}
async function buildBoth(){
  const files=windowsBuild();const dest=path.join(ROOT,'NATIVE_BUILDS',new Date().toISOString().replace(/[^0-9]/g,''));copyInstallers(files,path.join(dest,'Windows'));
  console.log('\nWindows EXE completed. macOS requires a real Mac runner. The following step will upload the allowlisted source to a new branch of '+REPO+' and use GitHub Actions. No main branch or release is replaced. GitHub runner usage may be billed according to your account.');
  const rl=readline.createInterface({input:process.stdin,output:process.stdout});let answer;try{answer=await rl.question('Build Mac on GitHub now? Type YES to authorize the source upload: ')}finally{rl.close()}
  if(answer.trim()!=='YES'){console.log('Mac build not started. Windows installer: '+dest);return;}
  const source=stageSource();await macBuild(source,path.join(dest,'macOS'));console.log('Both platform outputs: '+dest);
}
function webStart(native){
  if(Number(process.versions.node.split('.')[0])<22)throw Error('Install Node.js 22 LTS or newer first.');
  const {createApi}=require('../electron/api.cjs');const n=require('../electron/native-model.cjs');const endpoint=native?n.ENDPOINT:process.env.MAYIA_ENDPOINT||'http://127.0.0.1:11434/v1';const model=native?n.MODEL:process.env.MAYIA_MODEL||'llama3.2';const port=Number(process.env.MAYIA_API_PORT||8787);if(!Number.isInteger(port)||port<1024||port>65535)throw Error('Invalid MAYIA_API_PORT');
  const token=process.env.MAYIA_LOCAL_TOKEN||crypto.randomBytes(32).toString('hex');const local=['localhost','127.0.0.1','[::1]'].includes(new URL(endpoint).hostname);const server=createApi({web:true,token,settings:native?n.nativeSettings():{endpoint,model},apiKey:native?n.providerKey({endpoint}):local?'':process.env.MAYIA_API_KEY});server.requestTimeout=30000;
  server.on('error',e=>{native?.stop();console.error('Web start failed: '+e.message);process.exitCode=1});server.on('close',()=>native?.stop());
  server.listen(port,'127.0.0.1',()=>{const url=`http://127.0.0.1:${port}/`;console.log(`\nMAYIA WEB: ${url}\nModel: ${model}\nEndpoint: ${endpoint}\nAccess token (paste into the web page):\n${token}\nKeep this window open. Ctrl+C stops the server.\n`);if(process.platform==='win32'){const child=spawn(process.env.ComSpec||'cmd.exe',['/d','/s','/c',`start "" ${url}`],{stdio:'ignore',windowsHide:true});child.on('error',()=>console.log('Open the URL manually.'));}});
}
async function main(){switch(process.argv[2]){case 'web':return webStart(await require('./native-launch.cjs').startNative());case 'github':return stageSource();case 'app':{ensureDependencies();const native=await require('./native-launch.cjs').startNative();try{return npm(['run','desktop:dev'],{env:{...cleanEnv(),...(native?{MAYIA_USE_NATIVE:'1'}:{})}})}finally{native?.stop()}}case 'windows':return windowsBuild();case 'both':return buildBoth();default:throw Error('Usage: launchers.cjs web|github|app|windows|both')}}
if(require.main===module)main().catch(e=>{console.error('\n[MAYIA ERROR] '+e.message);process.exitCode=1});
module.exports={electronBinary,stageSource,checksum,cleanEnv};
