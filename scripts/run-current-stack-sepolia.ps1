param(
    [ValidateSet('Preflight','Subscription','Deploy','ResumeDeploy','Activate','Mint','RequestEntropy','Readback','Settle')]
    [string]$Stage = 'Preflight',
    [string]$RpcUrl = 'https://ethereum-sepolia-rpc.publicnode.com',
    [string]$AccountsPath = (Join-Path $env:USERPROFILE '.codex/stream-testnet/accounts.json'),
    [string]$OutputDirectory = (Join-Path $env:TEMP '6529stream-current-sepolia'),
    [string]$ArtifactDirectory = 'out/current-stack-sepolia',
    [string]$CacheDirectory = 'cache/current-stack-sepolia',
    [string]$BroadcastDirectory = 'broadcast',
    [ValidateRange(100,200)][int]$DeploymentGasEstimateMultiplier = 120,
    [string]$SubscriptionFundingWei = '1200000000000000000',
    [string]$MintPriceWei = '1000000000000',
    [string]$MaxFeePerGasWei = '0',
    [string]$PriorityFeeWei = '1000000',
    [switch]$Broadcast
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
foreach ($pathName in @('ArtifactDirectory','CacheDirectory','BroadcastDirectory')) {
    $selectedPath=Get-Variable -Name $pathName -ValueOnly
    if (-not [IO.Path]::IsPathRooted($selectedPath)) {$selectedPath=Join-Path $repoRoot $selectedPath}
    Set-Variable -Name $pathName -Value ([IO.Path]::GetFullPath($selectedPath))
}
$coordinator = '0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B'
$keyHash = '0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae'
$transactionGasCap = [bigint]16777216
$statePath = Join-Path $OutputDirectory 'state.json'
$state = [ordered]@{schema='6529stream.current-sepolia.v1';chainId=11155111;receipts=[ordered]@{}}
if (Test-Path -LiteralPath $statePath) {
    $state = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json -AsHashtable
}
$accounts = Get-Content -Raw -LiteralPath $AccountsPath | ConvertFrom-Json
$deployer = @($accounts | Where-Object role -eq 'stream-deployer')[0]
$artist = @($accounts | Where-Object role -eq 'stream-artist')[0]
$platform = @($accounts | Where-Object role -eq 'stream-platform')[0]
foreach ($account in @($deployer,$artist,$platform)) {
    if ($account.chainId -ne 11155111 -or $account.address -notmatch '^0x[0-9a-fA-F]{40}$') {
        throw 'Dedicated Sepolia account metadata required.'
    }
}

function Invoke-Tool([string]$Program, [string[]]$Arguments, [AllowNull()][string]$StandardInput=$null) {
    # Keep captured errors private: RPC endpoints or signer arguments may be sensitive.
    $executable = (Get-Command $Program -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $captured = if (-not $PSBoundParameters.ContainsKey('StandardInput')) { & $executable @Arguments 2>&1 }
        else { $StandardInput | & $executable @Arguments 2>&1 }
    if ($LASTEXITCODE -ne 0) {
        $selector=if ($Arguments[0] -eq 'estimate') {[regex]::Match(($captured -join ' '),'0x[0-9a-fA-F]{8}').Value} else {''}
        throw "$Program $($Arguments[0]) failed $selector; command output withheld."
    }
    return ($captured -join "`n").Trim()
}
function Cast([string[]]$Arguments) {
    # Genesis calldata and deployed runtime exceed Windows' command-line limit.
    if ($Arguments.Count -eq 2 -and $Arguments[0] -eq 'keccak' -and $Arguments[1].StartsWith('0x')) {
        return Invoke-Tool 'cast' @('keccak') $Arguments[1]
    }
    return Invoke-Tool 'cast' $Arguments
}
function Rpc([string]$Method, [string[]]$Arguments = @()) {
    return (Cast (@('rpc',$Method) + $Arguments + @('--rpc-url',$RpcUrl))) | ConvertFrom-Json -AsHashtable
}
function Uint([string]$Value) {
    if ($Value.StartsWith('0x')) {
        return [bigint]::Parse(('0'+$Value.Substring(2)),[Globalization.NumberStyles]::AllowHexSpecifier)
    }
    return [bigint]::Parse(($Value -split '\s')[0])
}
function Read([string]$Target,[string]$Signature,[string[]]$Arguments = @()) {
    $decoded = Cast (@('call',$Target,$Signature)+$Arguments+@('--rpc-url',$RpcUrl,'--gas-limit','16000000','--json')) | ConvertFrom-Json -NoEnumerate
    return ,@($decoded)
}
function Save-State {
    New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
    $nextStatePath = "$statePath.next"
    $state | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $nextStatePath -Encoding utf8
    Move-Item -LiteralPath $nextStatePath -Destination $statePath -Force
}
function With-Signer([object]$Account,[string]$Program,[string[]]$Arguments) {
    if (-not $Broadcast) { throw 'Signing requires -Broadcast; default mode is read-only.' }
    $secure = (Get-Content -Raw -LiteralPath $Account.passwordRecord).Trim() | ConvertTo-SecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $passwordDirectory=$null
    $passwordFile=$null
    try {
        $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        $passwordDirectory=Join-Path $env:TEMP ('stream-signer-'+[guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $passwordDirectory | Out-Null
        $acl=Get-Acl -LiteralPath $passwordDirectory
        $acl.SetAccessRuleProtection($true,$false)
        foreach ($identity in @([Security.Principal.WindowsIdentity]::GetCurrent().User,
            [Security.Principal.SecurityIdentifier]::new('S-1-5-18'))) {
            $rule=[Security.AccessControl.FileSystemAccessRule]::new(
                $identity,'FullControl','ContainerInherit,ObjectInherit','None','Allow')
            $acl.AddAccessRule($rule)
        }
        Set-Acl -LiteralPath $passwordDirectory -AclObject $acl
        $passwordFile=Join-Path $passwordDirectory 'password'
        [IO.File]::WriteAllText($passwordFile,$password,[Text.UTF8Encoding]::new($false))
        return Invoke-Tool $Program ($Arguments + @('--keystore',$Account.keystore,'--password-file',$passwordFile))
    } finally {
        try {
            if ($passwordFile -and (Test-Path -LiteralPath $passwordFile)) {Remove-Item -LiteralPath $passwordFile -Force}
            if ($passwordDirectory -and (Test-Path -LiteralPath $passwordDirectory)) {Remove-Item -LiteralPath $passwordDirectory -Force}
        } finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
            $password = $null
            $secure.Dispose()
        }
    }
}
function Record-Receipt([string]$Label,[object]$Receipt) {
    if ($Receipt.status -notin @('0x1','1',1)) { throw "Transaction failed: $Label" }
    $state.receipts[$Label] = [ordered]@{
        transactionHash=$Receipt.transactionHash;blockNumber=$Receipt.blockNumber
        gasUsed=$Receipt.gasUsed;effectiveGasPrice=$Receipt.effectiveGasPrice;status=$Receipt.status
        feePayer=$Receipt.from
    }
    Save-State
}
function Send([string]$Label,[string]$Target,[string]$Signature,[string[]]$Arguments=@(),[string]$Value='0') {
    $base = @($Target,$Signature)+$Arguments+@('--from',$deployer.address,'--rpc-url',$RpcUrl,'--value',$Value)
    $estimate = Uint (Cast (@('estimate')+$base))
    $limit = [bigint]::Max(21000,[bigint]::Divide(($estimate*120+99),100))
    if ($limit -gt $transactionGasCap) { throw "$Label estimate exceeds the transaction cap." }
    $balance = Uint (Cast @('balance',$deployer.address,'--rpc-url',$RpcUrl))
    if ($balance -lt $limit*$maxFee+(Uint $Value)) { throw "Insufficient balance for $Label." }
    $receipt = With-Signer $deployer 'cast' (@('send')+$base+@(
        '--gas-limit',$limit.ToString(),'--gas-price',$maxFee.ToString(),
        '--priority-gas-price',$tip.ToString(),'--confirmations','1','--json'
    )) | ConvertFrom-Json -AsHashtable
    Record-Receipt $Label $receipt
    return $receipt
}
function Sign-Typed([object]$Account,[object]$Data) {
    return With-Signer $Account 'cast' @('wallet','sign','--data',($Data | ConvertTo-Json -Depth 30 -Compress))
}
function Require-Addresses {
    if (-not $state.Contains('addresses')) { throw 'Deploy stage has not recorded addresses.' }
}
function Subscription-State {
    return Read $coordinator 'getSubscription(uint256)(uint96,uint96,uint64,address,address[])' @($state.subscriptionId)
}
function Mint-TokenId([object]$Receipt,[string]$Sale) {
    $topic = Cast @('keccak','NativeSaleSettled(bytes32,bytes32,uint256,bytes32,bytes32,address,uint256)')
    $events = @($Receipt.logs | Where-Object {
        $_.address -ieq $Sale -and $_.topics.Count -eq 4 -and $_.topics[0] -eq $topic
    })
    if ($events.Count -ne 1) { throw 'Expected exactly one paid-sale token receipt.' }
    return (Uint $events[0].topics[3]).ToString()
}
function Require-FreshDeployment([string]$BroadcastFile) {
    if ($state.Contains('deploymentAttempt') -or (Test-Path -LiteralPath $BroadcastFile)) {
        throw 'An existing deployment attempt requires receipt recovery with ResumeDeploy; a new deployment is blocked.'
    }
}
function Transaction-Value([object]$Transaction) {
    # Foundry omits the zero value on its generated library deployment transactions.
    if ($Transaction.Contains('value')) {return Uint $Transaction['value']}
    return [bigint]0
}
function Validate-RecordedDeployment([object]$Run) {
    if ($Run.transactions.Count -ne $state.deploymentAttempt.transactions.Count) {
        throw 'Recorded deployment transaction count differs from the checkpoint.'
    }
    for ($i=0; $i -lt $Run.transactions.Count; $i++) {
        $tx=$Run.transactions[$i].transaction
        $expected=$state.deploymentAttempt.transactions[$i]
        $inputHash=Cast @('keccak',$tx.input)
        if ($tx.from -ine $deployer.address -or (Uint $tx.nonce).ToString() -ne $expected.nonce -or
            $inputHash -ne $expected.inputHash -or [string]$tx['to'] -ine $expected.to -or
            (Transaction-Value $tx).ToString() -ne $expected.value -or (Uint $tx.gas) -gt $transactionGasCap) {
            throw 'Recorded deployment differs from the exact checkpoint; manual receipt recovery required.'
        }
    }
}
function Remaining-DeploymentGas([object]$Run) {
    $confirmed=@($Run.receipts | Where-Object {$_.status -in @('0x1','1',1)} | ForEach-Object {$_.transactionHash})
    $remaining=[bigint]0
    foreach ($tx in $Run.transactions) {
        if (-not $tx.hash -or $tx.hash -notin $confirmed) { $remaining+=Uint $tx.transaction.gas }
    }
    return $remaining
}

Push-Location $repoRoot
try {
    if ((Uint (Cast @('chain-id','--rpc-url',$RpcUrl))) -ne 11155111) { throw 'Sepolia RPC required.' }
    $config = Read $coordinator 's_config()(uint16,uint32,bool,uint32,uint32,uint32,uint32,uint8,uint8)'
    $provingKey = Read $coordinator 's_provingKeys(bytes32)(bool,uint64)' @($keyHash)
    if (-not $provingKey[0] -or (Uint $config[0]) -gt 3 -or (Uint $config[1]) -lt 1500000) {
        throw 'Live VRF configuration does not support the selected parameters.'
    }
    $latest = Rpc 'eth_getBlockByNumber' @('latest','false')
    $history = Rpc 'eth_feeHistory' @('0x14','latest','[10,25,50]')
    $baseFee = Uint $latest.baseFeePerGas
    $recentMaximum = @($history.baseFeePerGas | ForEach-Object {Uint $_} | Sort-Object)[-1]
    $tip = Uint $PriorityFeeWei
    $maxFee = Uint $MaxFeePerGasWei
    if ($maxFee -eq 0) { $maxFee = [bigint]::Divide(($recentMaximum*125+99),100)+$tip }
    if ($maxFee -lt $baseFee+$tip) { throw 'Chosen max fee is below current base fee plus tip.' }
    $balance = Uint (Cast @('balance',$deployer.address,'--rpc-url',$RpcUrl))
    # Pinned real-coordinator fork: 48 transactions, 100,267,574 estimated execution gas
    # including linked libraries and subscription setup. Round up plus 3m for the demo.
    # This is an expected cost estimate; each signed transaction also has a max-fee bound.
    $remainingGasBudget = if ($state.Contains('addresses')) {[bigint]3000000} else {[bigint]104000000}
    $receiptOnlyRecovery=$false
    if ($Stage -eq 'ResumeDeploy' -and $state.Contains('deploymentAttempt') -and
        (Test-Path -LiteralPath $state.deploymentAttempt.broadcastFile)) {
        $recorded=Get-Content -Raw -LiteralPath $state.deploymentAttempt.broadcastFile | ConvertFrom-Json -AsHashtable
        Validate-RecordedDeployment $recorded
        $remaining=Remaining-DeploymentGas $recorded
        $receiptOnlyRecovery=$remaining -eq 0
        $remainingGasBudget=[bigint]::Divide(($remaining*100+$DeploymentGasEstimateMultiplier-1),$DeploymentGasEstimateMultiplier)+3000000
    }
    # Chainlink gates fulfillment on the gas lane's maximum-cost reserve, not the
    # current transaction gas price. The 300k allowance covers verification and
    # coordinator overhead; the observed Sepolia UI max cost was 1.1133045 ETH.
    $minimumVRFReserve=[bigint]::Divide((1800000*(Uint $provingKey[1])*(100+(Uint $config[7]))+99),100)+(Uint $config[5])*1000000000000
    $subscriptionTarget=if (-not $PSBoundParameters.ContainsKey('SubscriptionFundingWei') -and $state.Contains('subscriptionReserveTargetWei')) {
        Uint $state.subscriptionReserveTargetWei
    } else {Uint $SubscriptionFundingWei}
    if ($subscriptionTarget -lt $minimumVRFReserve) {throw 'Selected subscription funding is below the gas-lane fulfillment reserve.'}
    $subscriptionBalance=if ($state.Contains('subscriptionId')) {Uint (Subscription-State)[1]} else {[bigint]0}
    $nativeFunding=if ($state.Contains('oracleFulfillment')) {[bigint]0} else {[bigint]::Max(0,$subscriptionTarget-$subscriptionBalance)}
    $expectedFee = $baseFee+$tip
    $required = [bigint]::Divide(($remainingGasBudget*$expectedFee*110+99),100)+$nativeFunding+(Uint $MintPriceWei)
    $state.accounts = @{deployer=$deployer.address;artist=$artist.address;platform=$platform.address;protocol=$deployer.address}
    $state.vrf = @{coordinator=$coordinator;keyHash=$keyHash;confirmations=3;callbackGas=1500000;maximumCallbackGas=2500000;nativePayment=$true}
    $state.preflight = [ordered]@{
        blockNumber=(Uint $latest.number).ToString();baseFeeWei=$baseFee.ToString()
        priorityFeeWei=$tip.ToString();maxFeeWei=$maxFee.ToString();balanceWei=$balance.ToString()
        remainingGasBudget=$remainingGasBudget.ToString();estimatedRequiredBalanceWei=$required.ToString()
        expectedFeePerGasWei=$expectedFee.ToString();feeReservePercent=10;subscriptionFundingWei=$nativeFunding.ToString()
        subscriptionReserveTargetWei=$subscriptionTarget.ToString();minimumVRFReserveWei=$minimumVRFReserve.ToString()
        recentMaximumBaseFeeWei=$recentMaximum.ToString();recentPriorityFeeSamples=$history.reward
        shortfallWei=[bigint]::Max(0,$required-$balance).ToString();requestedStage=$Stage;broadcast=[bool]$Broadcast
        deploymentGasEstimateMultiplier=$DeploymentGasEstimateMultiplier
    }
    Save-State
    if ((-not $Broadcast -and $Stage -ne 'Readback') -or $Stage -eq 'Preflight') {
        $state.preflight | ConvertTo-Json
        Write-Output "Read-only plan: $statePath"
        return
    }
    if ($Stage -notin @('Readback') -and -not $receiptOnlyRecovery -and $balance -lt $required) {
        throw 'Full-flow budget is not funded; no transaction was signed or sent.'
    }

    if ($Stage -eq 'Subscription') {
        $state.subscriptionReserveTargetWei=$subscriptionTarget.ToString()
        if (-not $state.Contains('subscriptionId')) {
            $receipt = Send 'createSubscription' $coordinator 'createSubscription()'
            $topic = Cast @('keccak','SubscriptionCreated(uint256,address)')
            $log = @($receipt.logs | Where-Object { $_.address -ieq $coordinator -and $_.topics[0] -eq $topic })
            if ($log.Count -ne 1) { throw 'Expected one real SubscriptionCreated receipt.' }
            $state.subscriptionId = (Uint $log[0].topics[1]).ToString()
            Save-State
        }
        $subscription = Subscription-State
        if ($subscription[3] -ine $deployer.address) { throw 'Dedicated deployer does not own subscription.' }
        $topup = [bigint]::Max(0,$subscriptionTarget-(Uint $subscription[1]))
        if ($topup -gt 0) {
            $fundLabel=if ($state.receipts.Contains('fundSubscription')) {"fundSubscriptionTopup-$($state.receipts.Count)"} else {'fundSubscription'}
            $null = Send $fundLabel $coordinator 'fundSubscriptionWithNative(uint256)' @($state.subscriptionId) $topup.ToString()
        }
        $subscription = Subscription-State
        $state.subscriptionFunded = (Uint $subscription[1]).ToString()
        Save-State
    }

    if ($Stage -in @('Deploy','ResumeDeploy')) {
        if ($state.Contains('addresses')) { throw 'Addresses already recorded; use Activate or Readback.' }
        $broadcastFile = Join-Path $BroadcastDirectory 'DeployCurrentStack.s.sol/11155111/run-latest.json'
        if ($Stage -eq 'Deploy') { Require-FreshDeployment $broadcastFile }
        elseif (-not $state.Contains('deploymentAttempt') -or -not (Test-Path -LiteralPath $broadcastFile)) {
            throw 'Resume requires the checkpoint and its original Forge broadcast file; recover receipts before continuing.'
        }
        if (-not $state.Contains('subscriptionId')) { throw 'Run Subscription first.' }
        $subscription = Subscription-State
        if ($subscription[3] -ine $deployer.address -or (Uint $subscription[1]) -eq 0) { throw 'Owned funded subscription required.' }
        $environment = @{
            FOUNDRY_BROADCAST=$BroadcastDirectory
            STREAM_DEPLOYER=$deployer.address;STREAM_PROTOCOL_TREASURY=$deployer.address
            STREAM_ARTIST=$artist.address;STREAM_PLATFORM_SIGNER=$platform.address
            STREAM_VRF_COORDINATOR=$coordinator;STREAM_VRF_SUBSCRIPTION_ID=$state.subscriptionId
            STREAM_VRF_KEY_HASH=$keyHash;STREAM_VRF_CONFIRMATIONS='3';STREAM_VRF_CALLBACK_GAS='1500000'
            STREAM_VRF_MAX_CALLBACK_GAS='2500000';STREAM_VRF_NATIVE_PAYMENT='true'
        }
        $saved = @{}
        foreach ($key in $environment.Keys) {$saved[$key]=[Environment]::GetEnvironmentVariable($key);[Environment]::SetEnvironmentVariable($key,$environment[$key])}
        try {
            $skip = @('--skip','test')
            Get-ChildItem script -Recurse -Filter '*.s.sol' | Where-Object Name -ne 'DeployCurrentStack.s.sol' |
                ForEach-Object {$skip+=@('--skip',$_.Name)}
            $forgeArguments = @('script','script/current/DeployCurrentStack.s.sol:DeployCurrentStack')+$skip+@(
                '--via-ir','--build-info','--isolate','--out',$ArtifactDirectory,'--cache-path',$CacheDirectory,
                '--rpc-url',$RpcUrl,'--sender',$deployer.address,'--slow',
                '--with-gas-price',$maxFee.ToString(),'--priority-gas-price',$tip.ToString(),'--gas-estimate-multiplier',$DeploymentGasEstimateMultiplier.ToString()
            )
            $sourceCommit=Invoke-Tool 'git' @('rev-parse','HEAD')
            if ($Stage -eq 'ResumeDeploy') {
                if ($sourceCommit -ne $state.deploymentAttempt.sourceCommit) { throw 'Resume must use the checkpoint source commit.' }
                if ($state.deploymentAttempt.Contains('gasEstimateMultiplier') -and $state.deploymentAttempt.gasEstimateMultiplier -ne $DeploymentGasEstimateMultiplier) {
                    throw 'Resume must use the checkpoint deployment gas multiplier.'
                }
                $recorded=Get-Content -Raw -LiteralPath $broadcastFile | ConvertFrom-Json -AsHashtable
                Validate-RecordedDeployment $recorded
                if (-not $receiptOnlyRecovery) {
                    $null=With-Signer $deployer 'forge' ($forgeArguments+@('--broadcast','--resume'))
                }
            } else {
            $null = Invoke-Tool 'forge' $forgeArguments
            $dryRunFile = Join-Path $BroadcastDirectory 'DeployCurrentStack.s.sol/11155111/dry-run/run-latest.json'
            $dryRun = Get-Content -Raw -LiteralPath $dryRunFile | ConvertFrom-Json -AsHashtable
            $estimatedTotal = [bigint]0
            foreach ($tx in $dryRun.transactions) {
                $gas = Uint $tx.transaction.gas
                if ($gas -gt $transactionGasCap) {throw 'Deployment transaction exceeds Sepolia gas cap.'}
                $estimatedTotal += $gas
            }
            $expectedGas = [bigint]::Divide(($estimatedTotal*100+$DeploymentGasEstimateMultiplier-1),$DeploymentGasEstimateMultiplier)+3000000
            if ([bigint]::Divide(($expectedGas*$expectedFee*110+99),100)+(Uint $MintPriceWei) -gt $balance) {
                throw 'Exact deployment simulation exceeds the complete-flow funding budget.'
            }
            $state.estimatedDeploymentGas=$estimatedTotal.ToString()
            $state.deploymentAttempt=[ordered]@{
                sourceCommit=$sourceCommit;startingNonce=(Uint (Cast @('nonce',$deployer.address,'--rpc-url',$RpcUrl))).ToString()
                artifactDirectory=$ArtifactDirectory;cacheDirectory=$CacheDirectory;broadcastDirectory=$BroadcastDirectory
                gasEstimateMultiplier=$DeploymentGasEstimateMultiplier
                broadcastFile=$broadcastFile;status='checkpointed-before-signing'
                transactions=@($dryRun.transactions | ForEach-Object {
                    $tx=$_.transaction
                    @{nonce=(Uint $tx.nonce).ToString();to=[string]$tx['to'];value=(Transaction-Value $tx).ToString();inputHash=(Cast @('keccak',$tx.input));gasLimit=(Uint $tx.gas).ToString()}
                })
            }
            $firstNonce=$state.deploymentAttempt.transactions[0].nonce
            $pendingNonce=(Uint (Cast @('nonce',$deployer.address,'--block','pending','--rpc-url',$RpcUrl))).ToString()
            if ($state.deploymentAttempt.startingNonce -ne $firstNonce -or $pendingNonce -ne $firstNonce) {
                throw 'Deployer nonce changed during planning; no deployment was signed.'
            }
            Save-State
            $null = With-Signer $deployer 'forge' ($forgeArguments+@('--broadcast'))
            }
        } finally {foreach ($key in $saved.Keys) {[Environment]::SetEnvironmentVariable($key,$saved[$key])}}
        $run = Get-Content -Raw -LiteralPath $broadcastFile | ConvertFrom-Json -AsHashtable
        Validate-RecordedDeployment $run
        if ($run.receipts.Count -ne $run.transactions.Count) { throw 'Deployment receipts are incomplete; use ResumeDeploy.' }
        $names = @{core='StreamCore';executor='StreamGovernanceExecutor';registry='StreamModuleRegistry';manifest='StreamSystemManifest';manager='StreamMintManager';ledger='StreamMintLedger';sale='StreamFixedPriceSaleAdapter';auction='StreamEnglishAuctionHouse';factory='StreamSplitFactory';entropy='StreamEntropyCoordinator';metadata='StreamMetadataRouter';royalty='StreamRoyaltyResolver';artists='StreamCollectionArtistRegistry';provider='StreamEntropyProviderVRF'}
        $completedAddresses = [ordered]@{}
        foreach ($key in $names.Keys) {
            $tx = @($run.transactions | Where-Object { $_.contractName -eq $names[$key] -and $_.transactionType -eq 'CREATE' })
            if ($tx.Count -ne 1) {throw "Missing deployment receipt for $key."}
            $completedAddresses[$key]=$tx[0].contractAddress
        }
        foreach ($receipt in $run.receipts) {
            if ($receipt.status -notin @('0x1','1',1)) {throw 'A deployment transaction reverted; inspect its receipt before recovery.'}
        }
        if (-not (Read $completedAddresses.executor 'genesisInitialized()(bool)')[0]) {throw 'Deployment genesis readback failed.'}
        $state.addresses=$completedAddresses
        $state.deploymentSourceCommit = Invoke-Tool 'git' @('rev-parse','HEAD')
        $state.deploymentAttempt.status='complete'
        $index=0
        foreach ($receipt in $run.receipts) { Record-Receipt "deployment-$index" $receipt; $index++ }
        Save-State
    }

    if ($Stage -eq 'Activate') {
        Require-Addresses
        $subscription = Subscription-State
        if ($state.addresses.provider -notin $subscription[4]) {
            $null = Send 'addConsumer' $coordinator 'addConsumer(uint256,address)' @($state.subscriptionId,$state.addresses.provider)
        }
        $attribution = Read $state.addresses.artists 'attribution(uint256)((address,address,bytes32,bytes32,bytes32,uint64,uint64))' @('1')
        if ($attribution[0][0] -ine $artist.address) {throw 'Unexpected nominated artist.'}
        if ($attribution[0][1] -eq '0x0000000000000000000000000000000000000000') {
            $nonce = (Read $state.addresses.artists 'acceptanceNonces(address)(uint256)' @($artist.address))[0]
            $deadline = ((Uint $latest.timestamp)+3600).ToString()
            $digest = (Read $state.addresses.artists 'acceptanceDigest(uint256,bytes32,uint256,uint64)(bytes32)' @('1',$attribution[0][3],$nonce,$deadline))[0]
            $signature = With-Signer $artist 'cast' @('wallet','sign','--no-hash',$digest)
            $null = Send 'acceptArtist' $state.addresses.artists 'acceptArtist(uint256,bytes32,uint256,uint64,bytes)' @('1',$attribution[0][3],$nonce,$deadline,$signature)
            $signature=$null
        }
        if ((Read $state.addresses.artists 'acceptedArtist(uint256)(address)' @('1'))[0] -ine $artist.address) {
            throw 'Artist acceptance readback failed.'
        }
        $subscription=Subscription-State
        if ($state.addresses.provider -notin $subscription[4]) {throw 'Consumer registration readback failed.'}
        $state.activated=$true
        Save-State
    }

    if ($Stage -eq 'Mint') {
        Require-Addresses
        if (-not $state.Contains('activated')) {throw 'Run Activate first.'}
        if ($state.Contains('tokenId')) {throw 'Demo token already recorded; use Readback.'}
        $phase=Cast @('keccak','current-stack fixed price')
        $entries="[($($artist.address),900000,$(Cast @('keccak','artist'))),($($deployer.address),100000,$(Cast @('keccak','protocol')))]"
        $profile=(Read $state.addresses.factory 'profileIdFor((address,uint32,bytes32)[],bytes32)(bytes32)' @($entries,(Cast @('keccak','development split'))))[0]
        $tokenData='0x'+[Convert]::ToHexString([Text.Encoding]::UTF8.GetBytes('Stream Sepolia public demonstration'))
        $message=[ordered]@{
            collectionId='1';phaseId=$phase;payer=$deployer.address;recipient=$deployer.address;artist=$artist.address
            profileId=$profile;tokenDataHash=(Cast @('keccak',$tokenData));mintCommitment=(Cast @('keccak','Stream Sepolia demonstration commitment'))
            mintPolicyHash=(Read $state.addresses.manager 'phasePolicyHash(uint256,bytes32)(bytes32)' @('1',$phase))[0]
            price=$MintPriceWei;nonce=(Cast @('keccak','Stream Sepolia demonstration sale 1'))
            deadline=((Uint $latest.timestamp)+3600).ToString();signerEpoch=(Read $state.addresses.sale 'signerEpoch()(uint64)')[0]
        }
        $fields=@(@('collectionId','uint256'),@('phaseId','bytes32'),@('payer','address'),@('recipient','address'),@('artist','address'),@('profileId','bytes32'),@('tokenDataHash','bytes32'),@('mintCommitment','bytes32'),@('mintPolicyHash','bytes32'),@('price','uint256'),@('nonce','bytes32'),@('deadline','uint64'),@('signerEpoch','uint64'))
        $typed=@{types=@{EIP712Domain=@(@{name='name';type='string'},@{name='version';type='string'},@{name='chainId';type='uint256'},@{name='verifyingContract';type='address'});SaleAuthorization=@($fields | ForEach-Object {@{name=$_[0];type=$_[1]}})};primaryType='SaleAuthorization';domain=@{name='6529StreamFixedPriceSale';version='1';chainId='11155111';verifyingContract=$state.addresses.sale};message=$message}
        $artistSignature=Sign-Typed $artist $typed
        $platformSignature=Sign-Typed $platform $typed
        $tuple='('+(($message.Values)-join ',')+')'
        $paidMint=Send 'paidMint' $state.addresses.sale 'buy((uint256,bytes32,address,address,address,bytes32,bytes32,bytes32,bytes32,uint256,bytes32,uint64,uint64),bytes,bytes,bytes)' @($tuple,$tokenData,$platformSignature,$artistSignature) $MintPriceWei
        $artistSignature=$null;$platformSignature=$null
        $state.tokenId=Mint-TokenId $paidMint $state.addresses.sale
        $state.mintPriceWei=$MintPriceWei
        $state.wallet=(Read $state.addresses.factory 'walletFor(bytes32)(address)' @($profile))[0]
        Save-State
    }
    if ($Stage -in @('Mint','RequestEntropy')) {
        Require-Addresses
        if (-not $state.Contains('tokenId')) {throw 'Mint a token before requesting entropy.'}
        if ($state.Contains('entropyRequested')) {throw 'Entropy already requested; use Readback.'}
        $receipt=Send 'requestEntropy' $state.addresses.entropy 'requestEntropy(uint256)' @($state.tokenId)
        $requestTopic=Cast @('keccak','VRFEntropyRequested(uint16,bytes32,uint256,uint256,uint32,bytes32,uint16,uint32,uint32)')
        $requestLog=@($receipt.logs | Where-Object {$_.address -ieq $state.addresses.provider -and $_.topics[0] -eq $requestTopic})
        if ($requestLog.Count -ne 1) {throw 'Missing provider request receipt.'}
        $state.providerRequestId=(Uint $requestLog[0].topics[2]).ToString()
        $state.requestKey=$requestLog[0].topics[1]
        $state.entropyRequested=$true
        Save-State
    }

    if ($Stage -eq 'Readback') {
        Require-Addresses
        $state.subscriptionReadback=Subscription-State
        $state.addresses.roleRegistry=(Read $state.addresses.executor 'roleRegistry()(address)')[0]
        $rootState=Read $state.addresses.executor 'governanceRootState()(address,bytes32,uint64)'
        $state.addresses.governanceRoot=$rootState[0]
        $state.governanceRootState=@{address=$rootState[0];codeHash=$rootState[1];revision=$rootState[2]}
        $state.addresses.assetPolicyRegistry=(Read $state.addresses.factory 'assetPolicyRegistry()(address)')[0]
        if ($state.Contains('wallet')) {$state.addresses.splitWallet=$state.wallet}
        $state.governanceRoles=[ordered]@{}
        $roleSource=Get-Content -Raw -LiteralPath 'smart-contracts/domains/governance/StreamRoles.sol'
        foreach ($match in [regex]::Matches($roleSource,'keccak256\("(ROLE_[A-Z_]+)"\)')) {
            $roleName=$match.Groups[1].Value
            $roleHash=Cast @('keccak',$roleName)
            $count=Uint (Read $state.addresses.roleRegistry 'roleHolderCount(bytes32)(uint256)' @($roleHash))[0]
            if ($count -gt 32) {throw 'Unexpected role enumeration size.'}
            $holders=@(for ($i=0; $i -lt $count; $i++) {
                (Read $state.addresses.roleRegistry 'roleHolderAt(bytes32,uint256)(address)' @($roleHash,$i.ToString()))[0]
            })
            $state.governanceRoles[$roleName]=$holders
        }
        $state.governanceActors=[ordered]@{root=@{address=$rootState[0];controller=(Read $rootState[0] 'controller()(address)')[0]}}
        $guardianIndex=0
        foreach ($guardian in $state.governanceRoles.ROLE_TERMINAL_FREEZE_VETO) {
            $name="guardian$guardianIndex"
            $state.addresses[$name]=$guardian
            $state.governanceActors[$name]=@{address=$guardian;controller=(Read $guardian 'controller()(address)')[0]}
            $guardianIndex++
        }
        $state.runtimeCodeHashes=[ordered]@{}
        foreach ($name in $state.addresses.Keys) {
            $code=Cast @('code',$state.addresses[$name],'--rpc-url',$RpcUrl)
            if ($code -eq '0x') {throw "Missing live code for $name."}
            $state.runtimeCodeHashes[$name]=Cast @('keccak',$code)
        }
        if ((Read $state.addresses.provider 'subscriptionId()(uint256)')[0].ToString() -ne $state.subscriptionId) {
            throw 'Adapter subscription readback mismatch.'
        }
        if ($state.Contains('providerRequestId')) {
            $state.providerResult=Read $state.addresses.provider 'providerResultStatus(uint256)(uint8,bytes32,bytes32,bool,bool)' @($state.providerRequestId)
            $topic=Cast @('keccak','VRFEntropyReceived(uint16,bytes32,uint256,bytes32)')
            $requestTopic='0x'+(Uint $state.providerRequestId).ToString('x').TrimStart('0').PadLeft(64,'0')
            $filter=@{address=$state.addresses.provider;fromBlock=$state.receipts.requestEntropy.blockNumber;toBlock='latest';topics=@($topic,$state.requestKey,$requestTopic)}
            $fulfilled=@(Rpc 'eth_getLogs' @(($filter | ConvertTo-Json -Compress)))
            if ($fulfilled.Count -gt 1) {throw 'Unexpected duplicate oracle fulfillment event.'}
            if ($fulfilled.Count -eq 1) {
                $receipt=Rpc 'eth_getTransactionReceipt' @($fulfilled[0].transactionHash)
                if (@($receipt.logs | Where-Object {$_.address -ieq $coordinator}).Count -eq 0) {throw 'Fulfillment receipt lacks the upstream coordinator event.'}
                Record-Receipt 'oracleFulfillment' $receipt
                $state.oracleFulfillment=@{transactionHash=$receipt.transactionHash;blockNumber=$receipt.blockNumber;providerEventTopic=$topic;requestKey=$state.requestKey;providerRequestId=$state.providerRequestId}
            }
        }
        if ($state.Contains('tokenId')) {
            $uri=(Read $state.addresses.core 'tokenURI(uint256)(string)' @($state.tokenId))[0]
            if (-not $uri.StartsWith('data:application/json;base64,')) {throw 'Unexpected metadata URI.'}
            $metadata=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($uri.Split(',')[1]))
            $data=$metadata | ConvertFrom-Json
            $state.metadataState=$data.metadata_state
            $metadata | Set-Content -LiteralPath (Join-Path $OutputDirectory 'token.metadata.json') -Encoding utf8
            $state.royaltyInfo=Read $state.addresses.core 'royaltyInfo(uint256,uint256)(address,uint256)' @($state.tokenId,$state.mintPriceWei)
        }
        Save-State
    }
    if ($Stage -eq 'Settle') {
        Require-Addresses
        if (-not $state.Contains('tokenId') -or -not $state.Contains('metadataState') -or $state.metadataState -ne 'final') {
            throw 'Run Readback after the real Chainlink fulfillment reaches final metadata.'
        }
        $asset='0x0000000000000000000000000000000000000000'
        $null=Send 'artistWithdrawal' $state.wallet 'release(address,address,address)' @($asset,$artist.address,$artist.address)
        $null=Send 'protocolWithdrawal' $state.wallet 'release(address,address,address)' @($asset,$deployer.address,$deployer.address)
        $null=Send 'transfer' $state.addresses.core 'transferFrom(address,address,uint256)' @($deployer.address,$artist.address,$state.tokenId)
        $state.finalOwner=(Read $state.addresses.core 'ownerOf(uint256)(address)' @($state.tokenId))[0]
        if ($state.finalOwner -ine $artist.address) {throw 'Transfer readback failed.'}
        $state.demonstrated=$true
        Save-State
    }
    $feesPaid=[bigint]0
    foreach ($receipt in $state.receipts.Values) {
        if (-not $receipt.Contains('feePayer') -or $receipt.feePayer -ieq $deployer.address) {
            $feesPaid+=(Uint $receipt.gasUsed)*(Uint $receipt.effectiveGasPrice)
        }
    }
    $state.recordedGasFeesPaidWei=$feesPaid.ToString()
    $state.deployerBalanceWei=(Uint (Cast @('balance',$deployer.address,'--rpc-url',$RpcUrl))).ToString()
    Save-State
    Write-Output $statePath
} finally {Pop-Location}
