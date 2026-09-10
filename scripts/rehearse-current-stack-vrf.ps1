param(
    [Parameter(Mandatory)][string]$OutputDirectory,
    [Parameter(Mandatory)][string]$ArtifactDirectory,
    [Parameter(Mandatory)][string]$MockArtifactFile,
    [string]$RpcUrl='http://127.0.0.1:8547',
    [ValidateRange(300000,2500000)][int]$CallbackGasLimit=500000
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repoRoot=Split-Path -Parent $PSScriptRoot
$deployer='0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'
. (Join-Path $PSScriptRoot 'current-stack-local-functions.ps1')

function Read-SourceBoundArtifact([string]$Path,[switch]$CurrentProfile) {
    $artifact=Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable
    $metadata=if ($artifact.Contains('rawMetadata')) {$artifact.rawMetadata | ConvertFrom-Json -AsHashtable} else {$artifact.metadata}
    if ($metadata.compiler.version -ne '0.8.19+commit.7dd6d404') {throw 'Unexpected compiler version.'}
    if ($CurrentProfile -and (-not $metadata.settings.viaIR -or -not $metadata.settings.optimizer.enabled -or $metadata.settings.optimizer.runs -ne 200 -or $metadata.settings.evmVersion -ne 'paris' -or $metadata.settings.metadata.appendCBOR -or $metadata.settings.metadata.bytecodeHash -ne 'none')) {throw 'VRF adapter requires the current viaIR/200/Paris/noCBOR profile.'}
    foreach ($item in $metadata.sources.GetEnumerator()) {
        $sourcePath=[IO.Path]::GetFullPath((Join-Path $repoRoot $item.Key))
        if (-not $sourcePath.StartsWith($repoRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {throw 'Artifact source escapes the repository.'}
        $hex='0x'+[Convert]::ToHexString([IO.File]::ReadAllBytes($sourcePath))
        if ((Invoke-Cast @('keccak',$hex)) -ine $item.Value.keccak256) {throw "Artifact source differs: $($item.Key)"}
    }
    if ($artifact.bytecode.object -notmatch '^0x[0-9a-fA-F]+$') {throw 'Artifact creation code contains unresolved links.'}
    return $artifact
}

function Deploy-Artifact([string]$Step,[object]$Artifact,[string]$ConstructorArguments='0x') {
    $data=$Artifact.bytecode.object+$ConstructorArguments.Substring(2)
    $transaction=@{from=$deployer;data=$data;value='0x0'}
    $estimate=Convert-UInt (Invoke-Rpc 'eth_estimateGas' @($transaction))
    $gas=[bigint]::Divide(($estimate*115+99),100)
    if ($gas -gt 16777216) {throw 'Deployment exceeds the transaction gas cap.'}
    $transaction.gas='0x'+$gas.ToString('x')
    $hash=Invoke-Rpc 'eth_sendTransaction' @($transaction)
    $receipt=$null
    for ($i=0;$i -lt 100 -and -not $receipt;$i++) {
        $receipt=Invoke-Rpc 'eth_getTransactionReceipt' @($hash)
        if (-not $receipt) {Start-Sleep -Milliseconds 100}
    }
    if (-not $receipt -or $receipt.status -ne '0x1') {throw "Local deployment failed: $hash"}
    $proof.receipts[$Step]=$receipt
    Write-PublicResult $result
    $code=Invoke-Rpc 'eth_getCode' @($receipt.contractAddress,'latest')
    Assert-ArtifactRuntime $Artifact $code
    return $receipt
}

$endpoint=[uri]$RpcUrl
if (-not $endpoint.IsLoopback -or $endpoint.UserInfo -ne '' -or $endpoint.Query -ne '') {throw 'Local proof requires a credential-free loopback endpoint.'}
if ((Invoke-Rpc 'eth_chainId' @()) -ne '0x7a69' -or (Invoke-Rpc 'web3_clientVersion' @()) -notmatch '^anvil/') {throw 'Local proof requires Anvil chain31337.'}
$OutputDirectory=[IO.Path]::GetFullPath($OutputDirectory)
$statePath=Join-Path $OutputDirectory 'current-stack.json'
$result=Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json -AsHashtable
if ($result.state -ne 'deployed' -or $result.deployer -ine $deployer -or $result.Contains('vrfRehearsal')) {throw 'Use a fresh DeployOnly local stack with no mint or previous VRF attempt.'}
$addresses=$result.addresses
$config=Read-Contract $addresses.entropy 'collectionEntropyConfig(uint256)(address,bool,bool,uint64,bytes32,bytes32,bytes32)' @('1')
if ($config[2]) {throw 'Collection entropy policy is locked; use a deployment before its first mint.'}
$providerPath=Join-Path $ArtifactDirectory 'StreamEntropyProviderVRF.sol/StreamEntropyProviderVRF.json'
$providerArtifact=Read-SourceBoundArtifact $providerPath -CurrentProfile
$mockArtifact=Read-SourceBoundArtifact $MockArtifactFile
$result.vrfRehearsal=[ordered]@{
    state='started';callbackGasLimit=$CallbackGasLimit
    providerArtifactSha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $providerPath).Hash.ToLowerInvariant()
    mockArtifactSha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $MockArtifactFile).Hash.ToLowerInvariant()
    limitation='Mock upstream enforces callback gas but does not verify a VRF proof, bill a subscription, or represent the Chainlink service.'
    receipts=[ordered]@{}
}
Write-PublicResult $result
$proof=$result.vrfRehearsal
$proof.receipts.mockDeployment=Deploy-Artifact 'mockDeployment' $mockArtifact
$upstream=$proof.receipts.mockDeployment.contractAddress
Write-PublicResult $result
$key=Invoke-Cast @('keccak','local VRF gas-cap demonstration')
$deploymentHash=Invoke-Cast @('keccak','current-stack development deployment v1; unaudited; not release evidence')
$manifestHash=Invoke-Cast @('keccak','explicit local mock upstream VRF adapter')
$providerConfig="($($addresses.entropy),$($addresses.executor),$upstream,1,$key,3,$CallbackGasLimit,2500000,true)"
$constructor=Invoke-Cast @('abi-encode','constructor((address,address,address,uint256,bytes32,uint16,uint32,uint32,bool),bytes32,string,bytes32)',$providerConfig,$deploymentHash,'urn:6529stream:local:mock-upstream-vrf',$manifestHash)
$proof.receipts.providerDeployment=Deploy-Artifact 'providerDeployment' $providerArtifact $constructor
$provider=$proof.receipts.providerDeployment.contractAddress
Write-PublicResult $result
foreach ($row in @(
    @('coordinator()(address)',$addresses.entropy),@('authority()(address)',$addresses.executor),
    @('vrfCoordinatorAddress()(address)',$upstream),@('keyHash()(bytes32)',$key),
    @('requestConfirmations()(uint16)','3'),@('callbackGasLimit()(uint32)',[string]$CallbackGasLimit),
    @('maximumCallbackGasLimit()(uint32)','2500000'),@('subscriptionId()(uint256)','1'),@('nativePayment()(bool)',$true)
)) {
    if ((Read-Value $provider $row[0]) -ine $row[1]) {throw "VRF configuration mismatch: $($row[0])"}
}
$callData=Invoke-Cast @('calldata','configureCollection(uint256,address,bytes32,bool,uint64)','1',$provider,$config[6],'true',[string]$config[3])
$selector=$callData.Substring(0,10)
$scope=Invoke-Cast @('keccak',(Invoke-Cast @('abi-encode','scope(address,bytes4)',$addresses.entropy,$selector)))
$newHash=Invoke-Cast @('keccak',$callData)
$zero='0x'+('0'*64)
$now=Convert-UInt (Invoke-Rpc 'eth_getBlockByNumber' @('latest',$false)).timestamp
# Include a scheduling cushion; Anvil mines a new timestamp for each transaction.
$notBefore=($now+172810).ToString();$expires=($now+777610).ToString()
$reason=Invoke-Cast @('keccak','local fresh-transaction VRF callback proof')
$request="(1,$($addresses.entropy),0,$selector,$callData,$scope,$zero,$newHash,$notBefore,$expires,$reason,urn:6529stream:local:vrf-proof,$deploymentHash)"
$scheduleData=Invoke-Cast @('calldata','scheduleGovernanceAction((uint8,address,uint256,bytes4,bytes,bytes32,bytes32,bytes32,uint64,uint64,bytes32,string,bytes32))',$request)
$proof.receipts.schedule=Send-LocalTransaction $addresses.governanceRoot 'execute(address,uint256,bytes)' @($addresses.executor,'0',$scheduleData)
$event=Find-ReceiptEvent $proof.receipts.schedule $addresses.executor 'GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)' 4
$proof.actionId=$event.topics[1]
Write-PublicResult $result
$null=Invoke-Rpc 'evm_setNextBlockTimestamp' @([long]$notBefore)
$null=Invoke-Rpc 'evm_mine' @()
$proof.receipts.configure=Send-LocalTransaction $addresses.executor 'executeGovernanceAction(bytes32,bytes)' @($proof.actionId,$callData)
$addresses.developmentProvider=$addresses.provider
$addresses.provider=$provider
$proof.upstream=$upstream;$proof.provider=$provider;$proof.state='configured'
Write-PublicResult $result
& (Join-Path $PSScriptRoot 'run-current-stack.ps1') -RpcUrl $RpcUrl -OutputDirectory $OutputDirectory -DemonstrateOnly -MockVrfCoordinator $upstream
$result=Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json -AsHashtable
if ($result.state -ne 'demonstrated') {throw 'VRF demonstration did not finish.'}
$submitted=Read-Value $upstream 'submittedCallbackGas(uint256)(uint32)' @($result.entropyRequest.providerRequestId)
if ($submitted -ne $CallbackGasLimit) {throw 'Upstream did not enforce the requested callback cap.'}
$trace=Invoke-Rpc 'debug_traceTransaction' @($result.demoReceipts.fulfillEntropy.transactionHash,@{tracer='callTracer'})
$trace | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'vrf-callback.trace.json') -Encoding utf8
$frames=@($trace.calls | Where-Object {$_.to -ieq $provider})
if ($frames.Count -ne 1 -or ($frames[0].PSObject.Properties.Name -contains 'error')) {throw 'Expected one successful adapter callback frame.'}
$callbackGas=Convert-UInt $frames[0].gasUsed
if ($callbackGas -gt $CallbackGasLimit) {throw 'Observed adapter callback exceeded its configured cap.'}
$result.vrfRehearsal.state='demonstrated'
$result.vrfRehearsal.callbackFrameGasUsed=$callbackGas.ToString()
$result.vrfRehearsal.callbackTransactionGasUsed=(Convert-UInt $result.demoReceipts.fulfillEntropy.gasUsed).ToString()
$result.vrfRehearsal.freshTransactions=$true
Write-PublicResult $result
Write-Output "Local VRF callback passed: $callbackGas gas within $CallbackGasLimit; Core notification and final metadata verified."
