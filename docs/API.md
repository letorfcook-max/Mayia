# Local developer API
Only use on trusted local machines. It listens on 127.0.0.1, requires a bearer token (minimum 32 characters), limits requests to 30/minute and two concurrent requests, and has no Cowork tools or CORS access. It forwards text requests to the configured provider, which may charge for use. It is not a public hosting, billing, or accounts system.

PowerShell:
```powershell
$env:MAYIA_LOCAL_TOKEN = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
$env:MAYIA_ENDPOINT = 'http://127.0.0.1:11434/v1'
$env:MAYIA_MODEL = 'llama3.2'
npm run api
```
From another terminal set the same token and call:
```powershell
$headers = @{ Authorization = "Bearer $env:MAYIA_LOCAL_TOKEN" }
Invoke-RestMethod http://127.0.0.1:8787/v1/chat/completions -Method Post -Headers $headers -ContentType application/json -Body '{"messages":[{"role":"user","content":"Hello"}]}'
```
GET `/health`, GET `/v1/models` also require auth. POST accepts text user/assistant messages, configured model only, no streaming or tools. Use MAYIA_API_KEY for remote providers. Do not bind this service to the public internet; use a separately designed auth and billing service for hosted accounts.
