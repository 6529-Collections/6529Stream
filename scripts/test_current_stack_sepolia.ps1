$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$parseErrors=$null
$tokens=$null
$path=Join-Path $PSScriptRoot 'run-current-stack-sepolia.ps1'
$ast=[System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$parseErrors)
if ($parseErrors.Count -ne 0) {throw 'Sepolia helper syntax errors.'}
# Load only pure receipt/recovery functions. No account files, RPC calls or signers run.
$names=@('Invoke-Tool','Cast','Uint','With-Signer','Mint-TokenId','Require-FreshDeployment','Transaction-Value','Validate-RecordedDeployment','Remaining-DeploymentGas')
foreach ($definition in $ast.FindAll({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst]},$true)) {
    if ($definition.Name -in $names) {Invoke-Expression $definition.Extent.Text}
}
function Check([bool]$Condition,[string]$Label) {if (-not $Condition) {throw $Label}}
function Reject([scriptblock]$Action,[string]$Label) {
    $rejected=$false
    try {& $Action | Out-Null} catch {$rejected=$true}
    Check $rejected $Label
}
Check ((Cast @('keccak',('0x'+('00'*40000)))) -eq '0xc625f79680f7083b0bdaef0ba2e4e67b9132ea5edfcecefb31b2b5f3a5a9282e') 'Large calldata must hash through stdin without Windows argument truncation.'
Check ((Cast @('keccak','artist')) -eq '0xf8c87671fe259c56f53406842c278dbf0d49073ecc39fc38bfc052a1b1a125cb') 'Plain text hashes must exclude the pipeline newline.'
Check ((Cast @('keccak','current-stack fixed price')) -eq '0x9097b43320fd7757709222ed1b348465e24c94cdae005c30d4dd5c8421f6ddc8') 'Phase identity must match Solidity keccak256.'
$sale='0x0000000000000000000000000000000000000001'
$other='0x0000000000000000000000000000000000000002'
$topic=Cast @('keccak','NativeSaleSettled(bytes32,bytes32,uint256,bytes32,bytes32,address,uint256)')
$receipt=@{logs=@(
    @{address=$other;topics=@($topic,'0x00','0x00','0x99')},
    @{address=$sale;topics=@($topic,'0x00','0x00','0x2a')}
)}
Check ((Mint-TokenId $receipt $sale) -eq '42') 'Token ID must come from the configured sale receipt.'
Reject {Mint-TokenId @{logs=@($receipt.logs[0])} $sale} 'Another sale must not supply the token ID.'
Reject {Mint-TokenId @{logs=@($receipt.logs[1],$receipt.logs[1])} $sale} 'Ambiguous sale receipts must fail.'
$state=[ordered]@{}
$unusedPath=Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString()+'.json')
Require-FreshDeployment $unusedPath
$state.deploymentAttempt=@{}
Reject {Require-FreshDeployment $unusedPath} 'A checkpoint must block a new deployment.'
$state=[ordered]@{}
try {
    '{}' | Set-Content -LiteralPath $unusedPath
    Reject {Require-FreshDeployment $unusedPath} 'A broadcast file must block a new deployment.'
} finally {Remove-Item -LiteralPath $unusedPath -ErrorAction SilentlyContinue}
$deployer=@{address=$sale}
$transactionGasCap=[bigint]16777216
$state.deploymentAttempt=@{transactions=@(
    @{nonce='7';to=$other;value='0';inputHash=(Cast @('keccak','0x1234'))},
    @{nonce='8';to='';value='0';inputHash=(Cast @('keccak','0x5678'))}
)}
$run=@{
    transactions=@(
        @{hash='0xaaaa';transaction=@{from=$sale;to=$other;nonce='0x7';value='0x0';input='0x1234';gas='0x10000'}},
        @{hash='0xbbbb';transaction=@{from=$sale;to=$null;nonce='0x8';value='0x0';input='0x5678';gas='0x20000'}}
    )
    receipts=@(@{transactionHash='0xaaaa';status='0x1'})
}
Validate-RecordedDeployment $run
$run.transactions[1].transaction.Remove('value')
Validate-RecordedDeployment $run
Check ((Remaining-DeploymentGas $run) -eq 131072) 'Recovery must exclude already paid gas.'
$run.receipts+=@{transactionHash='0xbbbb';status='0x1'}
Check ((Remaining-DeploymentGas $run) -eq 0) 'Complete receipts must permit receipt-only recovery.'
$run.transactions[1].transaction.input='0x1234'
Reject {Validate-RecordedDeployment $run} 'Changed calldata must block resume.'
$run.transactions[1].transaction.input='0x5678'
$run.transactions[1].transaction.gas='0x1000001'
Reject {Validate-RecordedDeployment $run} 'Over-cap transaction must block resume.'
$run.transactions[1].transaction.gas='0x20000'
$run.transactions[1].transaction.nonce='0x9'
Reject {Validate-RecordedDeployment $run} 'Changed nonce must block resume.'
$passwordRecord=Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString()+'.dpapi')
try {
    ConvertTo-SecureString 'public-test-sentinel' -AsPlainText -Force | ConvertFrom-SecureString | Set-Content -LiteralPath $passwordRecord
    $Broadcast=$true
    $script:observedPasswordFile=$null
    $script:failSignerProbe=$false
    function Invoke-Tool([string]$Program,[string[]]$Arguments) {
        Check ('--password' -notin $Arguments) 'A plaintext password must never enter argv.'
        $index=[array]::IndexOf($Arguments,'--password-file')
        Check ($index -ge 0) 'Password file argument required.'
        $script:observedPasswordFile=$Arguments[$index+1]
        Check ((Get-Acl -LiteralPath (Split-Path -Parent $script:observedPasswordFile)).AreAccessRulesProtected) 'Password directory must reject inherited access.'
        Check ((Get-Content -Raw -LiteralPath $script:observedPasswordFile) -eq 'public-test-sentinel') 'Password file must preserve exact content.'
        if ($script:failSignerProbe) {throw 'Expected signer tool failure.'}
        return 'probe-succeeded'
    }
    $probe=With-Signer @{passwordRecord=$passwordRecord;keystore='unused-test-keystore'} 'fake' @('wallet','address')
    Check ($probe -eq 'probe-succeeded') 'Signer probe must complete.'
    Check (-not (Test-Path -LiteralPath $script:observedPasswordFile)) 'Password file must be deleted.'
    Check (-not (Test-Path -LiteralPath (Split-Path -Parent $script:observedPasswordFile))) 'Password directory must be deleted.'
    $script:failSignerProbe=$true
    Reject {With-Signer @{passwordRecord=$passwordRecord;keystore='unused-test-keystore'} 'fake' @('wallet','address')} 'Signer failure must propagate.'
    Check (-not (Test-Path -LiteralPath $script:observedPasswordFile)) 'Failed signer must remove its password file.'
    Check (-not (Test-Path -LiteralPath (Split-Path -Parent $script:observedPasswordFile))) 'Failed signer must remove its password directory.'
} finally {Remove-Item -LiteralPath $passwordRecord -ErrorAction SilentlyContinue}
Write-Output 'PASS: receipt token identity, duplicate rejection, fresh-attempt guards, exact-plan resume, paid-gas exclusion and transaction cap.'
