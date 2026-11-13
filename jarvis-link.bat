@echo off & title JARVIS LINK - keep this window open & powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Content '%~f0' | Select-Object -Skip 2 | Out-String | Invoke-Expression" & pause & exit /b
:: JARVIS LINK - everything below line 2 is PowerShell. Double-click this file to run it.
$ErrorActionPreference='Continue'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$API='https://script.google.com/macros/s/AKfycbxt0WzAqyHe7Cy0mjeUHwwz73qVzW_zjBJOSBSuqLbyhqkDc3rFM1_6SsICcvBIHRFG/exec'
$LM='http://localhost:1234'
try{Add-Type -MemberDefinition '[System.Runtime.InteropServices.DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint f);' -Name U -Namespace WJL
[W.U]::SetThreadExecutionState(2147483649)|Out-Null}catch{}
Clear-Host
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host '   JARVIS LINK - your laptop AI bridge' -ForegroundColor Cyan
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host ''
$API2=$API
try{$null=Invoke-WebRequest -Uri $API -Method Get -MaximumRedirection 0 -TimeoutSec 20 -UseBasicParsing}catch{
  $resp=$_.Exception.Response
  if($resp -and $resp.Headers -and $resp.Headers['Location']){$API2=$resp.Headers['Location']}
}
function Rpc($fn,$arg){
  $body=@{fn=$fn;a=$arg}|ConvertTo-Json -Depth 6 -Compress
  Invoke-RestMethod -Method Post -Uri $API2 -ContentType 'text/plain; charset=utf-8' -Body $body -TimeoutSec 60 -UseBasicParsing
}
Write-Host 'Checking JARVIS server...'
$pinged=$false
while(-not $pinged){
  try{$t=Rpc 'ping' @();if($t.ok){$pinged=$true}else{Start-Sleep 5}}catch{Write-Host 'No internet yet - retrying...' -ForegroundColor Yellow;Start-Sleep 5}
}
Write-Host 'JARVIS server OK.' -ForegroundColor Green
$model=$null
Write-Host 'Looking for LM Studio server on this laptop...'
for($i=0;$i -lt 60 -and -not $model;$i++){
  try{$m=Invoke-RestMethod -Uri "$LM/v1/models" -TimeoutSec 4
    if($m.data -and @($m.data).Count -gt 0){
      $cands=@($m.data);$pick=$cands|Where-Object{$_.id -match 'instruct'}|Select-Object -First 1
      if(-not $pick){$pick=$cands[0]}
      $model=$pick.id}}catch{}
  if(-not $model){if($i -eq 0){Write-Host 'Not found yet. In LM Studio: open "Model Server", load a model, press Start Server.' -ForegroundColor Yellow};Start-Sleep 5}
}
if(-not $model){Write-Host 'Still no model found. Start the LM Studio server, then run JARVIS LINK again.' -ForegroundColor Red;Write-Host '';Read-Host 'Press Enter to close'|Out-Null;exit}
Write-Host "Model found: $model" -ForegroundColor Green
$token=$null
while(-not $token){
  Write-Host ''
  $code=Read-Host 'Type the 4-digit code shown in JARVIS (phone: tap the Laptop button)'
  try{$r=Rpc 'll_pair' @("$code")
    if($r.ok){$token=$r.token}else{Write-Host 'Wrong or expired code. Tap the Laptop button in JARVIS again for a new one.' -ForegroundColor Yellow}
  }catch{Write-Host 'Internet problem - trying again.' -ForegroundColor Yellow;Start-Sleep 5}
}
Write-Host ''
Write-Host 'CONNECTED! JARVIS will now answer from your laptop.' -ForegroundColor Green
Write-Host 'Keep this black window open while you chat. Close it to disconnect.' -ForegroundColor Green
Write-Host ''
while($true){
  try{
    $r=Rpc 'll_poll' @($token,22)
    if(-not $r.ok){
      Write-Host 'Session expired. Pair again:' -ForegroundColor Yellow
      $token=$null
      while(-not $token){$code=Read-Host 'Type the 4-digit code shown in JARVIS';try{$p=Rpc 'll_pair' @("$code");if($p.ok){$token=$p.token}else{Write-Host 'Wrong or expired code.' -ForegroundColor Yellow}}catch{Start-Sleep 5}}
    }
    elseif($r.job){
      $job=$r.job
      $last=$job.h[@($job.h).Count-1].text
      Write-Host "JARVIS asked: $last" -ForegroundColor Cyan
      $msgs=@(@{role='system';content='You are JARVIS, a helpful personal AI assistant. Always address the user as Sir. Reply in the language the user writes in (Tamil, English or Tanglish). Keep answers short: 2 to 6 sentences.'})
      foreach($m in $job.h){$msgs+=@{role=($(if($m.role -eq 'model'){'assistant'}else{'user'}));content=[string]$m.text}}
      $body=@{model=$model;messages=$msgs;max_tokens=220;temperature=0.7}
      try{
        $res=Invoke-RestMethod -Method Post -Uri "$LM/v1/chat/completions" -ContentType 'application/json' -Body ($body|ConvertTo-Json -Depth 8) -TimeoutSec 600
        $txt=[string]$res.choices[0].message.content
        if(-not $txt.Trim()){$txt='(empty reply from laptop model)'}
      }catch{$txt='Sorry Sir, my laptop brain had a hiccup. Please check LM Studio is still running.'}
      try{$null=Rpc 'll_reply' @($token,$job.id,$txt,'LAPTOP')}catch{}
    }
  }catch{Start-Sleep 5}
}
