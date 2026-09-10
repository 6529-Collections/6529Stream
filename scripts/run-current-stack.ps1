param(
    [string]$RpcUrl = 'http://127.0.0.1:8547',
    [string]$OutputDirectory = (Join-Path $env:TEMP '6529stream-current-local'),
    [string]$ArtifactDirectory,
    [string]$CacheDirectory,
    [string]$BroadcastDirectory,
    [ValidateRange(100,150)][int]$DeploymentGasEstimateMultiplier = 115,
    [switch]$DeployOnly,
    [switch]$DemonstrateOnly,
    [switch]$RequireExtendedStack,
    [string]$MockVrfCoordinator
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
$deployer = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'
$protocol = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8'

. (Join-Path $PSScriptRoot 'current-stack-local-functions.ps1')

# This helper deliberately uses only an existing loopback Anvil node and its standard
# public, unlocked development accounts. It never reads or writes a private key.
$endpoint = [uri]$RpcUrl
if (-not $endpoint.IsLoopback) { throw 'Local demo requires a loopback RPC endpoint.' }
if ($endpoint.UserInfo -ne '' -or $endpoint.Query -ne '') { throw 'Public demo artifacts require an RPC URL without embedded credentials.' }
if ((Invoke-Rpc 'eth_chainId' @()) -ne '0x7a69') { throw 'Local demo requires Anvil chain 31337.' }
$accounts = @(Invoke-Rpc 'eth_accounts' @())
if ($deployer.ToLowerInvariant() -notin @($accounts | ForEach-Object { $_.ToLowerInvariant() })) {
    throw 'The standard first Anvil account is not unlocked.'
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
foreach ($name in @('ArtifactDirectory','CacheDirectory','BroadcastDirectory')) {
    $value = Get-Variable -Name $name -ValueOnly
    if (-not $value) {
        $leaf = @{ArtifactDirectory='out';CacheDirectory='cache';BroadcastDirectory='broadcast'}[$name]
        $value = Join-Path $OutputDirectory $leaf
    } elseif (-not [IO.Path]::IsPathRooted($value)) { $value = Join-Path $repoRoot $value }
    Set-Variable -Name $name -Value ([IO.Path]::GetFullPath($value))
}
$broadcastPath = Join-Path $BroadcastDirectory 'DeployCurrentStack.s.sol/31337/run-latest.json'
if ($DeployOnly -and $DemonstrateOnly) { throw 'DeployOnly and DemonstrateOnly are mutually exclusive.' }
if (-not $DemonstrateOnly) { Require-FreshLocalRun (Join-Path $OutputDirectory 'current-stack.json') $broadcastPath }
Push-Location $repoRoot
$savedDeployer = $env:STREAM_DEPLOYER
$savedTreasury = $env:STREAM_PROTOCOL_TREASURY
$savedArtist = $env:STREAM_ARTIST
$savedPlatform = $env:STREAM_PLATFORM_SIGNER
$savedProfile = $env:FOUNDRY_PROFILE
$savedBroadcast = $env:FOUNDRY_BROADCAST
try {
    $env:FOUNDRY_PROFILE = 'current'
    $env:FOUNDRY_BROADCAST = $BroadcastDirectory
    $env:STREAM_DEPLOYER = $deployer
    $env:STREAM_PROTOCOL_TREASURY = $protocol
    $env:STREAM_ARTIST = $deployer
    $env:STREAM_PLATFORM_SIGNER = $deployer
    if (-not $DemonstrateOnly) {
        $skip = @('--skip','test')
        $result = [ordered]@{
            schema='6529stream.current-local-demo.v1';state='deployment-started';chainId=31337;rpcUrl=$RpcUrl
            sourceCommit=((& git rev-parse HEAD) -join '').Trim();compilerProfile='current'
            artifactDirectory=$ArtifactDirectory;cacheDirectory=$CacheDirectory;broadcastReceipts=$broadcastPath
        }
        Write-PublicResult $result
        & forge script script/current/DeployCurrentStack.s.sol:DeployCurrentStack @skip `
            --via-ir --build-info --isolate --out $ArtifactDirectory --cache-path $CacheDirectory `
            --rpc-url $RpcUrl --sender $deployer --unlocked --broadcast --slow `
            --gas-estimate-multiplier $DeploymentGasEstimateMultiplier
        if ($LASTEXITCODE -ne 0) { throw 'Current-stack deployment failed.' }

        $broadcast = Get-Content -Raw -LiteralPath $broadcastPath | ConvertFrom-Json
        if (@($broadcast.receipts | Where-Object { $_.status -notin @('0x1','1',1) }).Count -ne 0) { throw 'A deployment receipt failed.' }
        $addresses = [ordered]@{}
        $names = [ordered]@{
            core='StreamCore'; executor='StreamGovernanceExecutor'
            registry='StreamModuleRegistry'; manifest='StreamSystemManifest'; manager='StreamMintManager'
            ledger='StreamMintLedger'; sale='StreamFixedPriceSaleAdapter'; auction='StreamEnglishAuctionHouse'
            factory='StreamSplitFactory'; entropy='StreamEntropyCoordinator'; metadata='StreamMetadataRouter'
            royalty='StreamRoyaltyResolver'; artistRegistry='StreamCollectionArtistRegistry'; provider='DevelopmentEntropyProvider'
        }
        foreach ($item in $names.GetEnumerator()) { $addresses[$item.Key] = Get-DeploymentAddress $broadcast $item.Value }
        $extensions=@{erc20Sale='StreamERC20FixedPriceSaleAdapter';primaryRevenueResolver='StreamRevenueResolver'}
        foreach ($item in $extensions.GetEnumerator()) {
            $address=Get-DeploymentAddress $broadcast $item.Value -Optional
            if ($address) {$addresses[$item.Key]=$address}
        }
        $addresses.governanceRoot = (Read-Contract $addresses.executor 'governanceRootState()(address,bytes32,uint64)')[0]
        $addresses.roleRegistry = Read-Value $addresses.executor 'roleRegistry()(address)'
        $addresses.assetPolicyRegistry = Read-Value $addresses.factory 'assetPolicyRegistry()(address)'
        $artistLabel = Invoke-Cast @('keccak','artist')
        $protocolLabel = Invoke-Cast @('keccak','protocol')
        $splitMetadata = Invoke-Cast @('keccak','development split')
        $entries = "[($deployer,900000,$artistLabel),($protocol,100000,$protocolLabel)]"
        $profile = Read-Value $addresses.factory 'profileIdFor((address,uint32,bytes32)[],bytes32)(bytes32)' @($entries,$splitMetadata)
        $addresses.wallet = Read-Value $addresses.factory 'walletFor(bytes32)(address)' @($profile)
        $result.state='deployed';$result.developmentEntropy=$true
        $result.randomnessDisclosure='Controller-supplied local values; not secure randomness.'
        $result.deployer=$deployer;$result.protocol=$protocol;$result.addresses=$addresses;$result.profile=$profile
        $result.demoReceipts=[ordered]@{}
        Write-PublicResult $result
    } else {
        $result=Get-Content -Raw -LiteralPath (Join-Path $OutputDirectory 'current-stack.json') | ConvertFrom-Json -AsHashtable
        if ($result.state -ne 'deployed' -or $result.chainId -ne 31337 -or $result.deployer -ine $deployer) { throw 'Demonstration requires a local deployment with no previous mint attempt.' }
        $addresses=$result.addresses;$profile=$result.profile
    }
    if ($RequireExtendedStack -and (-not $addresses.Contains('erc20Sale') -or -not $addresses.Contains('primaryRevenueResolver'))) {throw 'The extended stack requires ERC20 sale and primary revenue resolver deployments.'}
    $publisherType=Invoke-Cast @('keccak','STATE_EXPORT_PUBLISHER')
    $publisher=Read-Contract $addresses.core 'getSatellitePointer(bytes32)(address,bytes32,bool,bytes32,bytes4,address,uint8,bytes32,bytes32,uint64)' @($publisherType)
    if ($publisher[0] -ne '0x0000000000000000000000000000000000000000') {
        if ($publisher[0] -ine $addresses.executor -or $publisher[3] -ine $publisherType -or $publisher[5] -ine $addresses.registry -or $publisher[6] -ne 1) {throw 'State export publisher pointer is not the active registered Executor.'}
        if (-not (Read-Value $addresses.executor 'supportsInterface(bytes4)(bool)' @($publisher[4]))) {throw 'Publisher interface is not supported by its target.'}
        $addresses.stateExportPublisher=$publisher[0]
        $result.publisherPointer=$publisher
    } elseif ($RequireExtendedStack) {throw 'The extended stack requires its active state export publisher pointer.'}
    Write-PublicResult $result
    if ($DeployOnly) { Write-Output (Join-Path $OutputDirectory 'current-stack.json'); return }
    if ($MockVrfCoordinator) {
        if ((Read-Value $addresses.provider 'vrfCoordinatorAddress()(address)') -ine $MockVrfCoordinator) { throw 'VRF adapter upstream differs from the explicit local mock.' }
        $result.developmentEntropy=$false
        $result.randomnessDisclosure='Real Stream VRF adapter with a local mock upstream; excludes Chainlink proof verification, service operation and billing.'
        $result.mockVrfCoordinator=$MockVrfCoordinator
    }
    $result.state='demonstration-started'
    Write-PublicResult $result

    $phase = Invoke-Cast @('keccak','current-stack fixed price')
    $tokenData = '0x' + [Convert]::ToHexString([Text.Encoding]::UTF8.GetBytes('Stream local demonstration'))
    $tokenDataHash = Invoke-Cast @('keccak',$tokenData)
    $commitment = Invoke-Cast @('keccak','local demo commitment')
    $nonce = Invoke-Cast @('keccak','local demo sale 1')
    $policy = Read-Value $addresses.manager 'phasePolicyHash(uint256,bytes32)(bytes32)' @('1',$phase)
    $epoch = Read-Value $addresses.sale 'signerEpoch()(uint64)'
    $block = Invoke-Rpc 'eth_getBlockByNumber' @('latest',$false)
    $deadline = ([Convert]::ToUInt64($block.timestamp.Substring(2),16) + 3600).ToString()
    if ((Read-Value $addresses.artistRegistry 'acceptedArtist(uint256)(address)' @('1')) -ine $deployer) {
        $attribution = Read-Value $addresses.artistRegistry 'attribution(uint256)((address,address,bytes32,bytes32,bytes32,uint64,uint64))' @('1')
        $acceptanceNonce = Read-Value $addresses.artistRegistry 'acceptanceNonces(address)(uint256)' @($deployer)
        $result.demoReceipts.acceptArtist = Send-LocalTransaction $addresses.artistRegistry 'acceptArtist(uint256,bytes32,uint256,uint64,bytes)' @('1',$attribution[3],$acceptanceNonce,$deadline,'0x')
        Write-PublicResult $result
    }
    if ((Read-Value $addresses.artistRegistry 'acceptedArtist(uint256)(address)' @('1')) -ine $deployer) { throw 'Artist attribution was not accepted.' }
    $price = '10000000000000000'
    $fields = @(
        @('collectionId','uint256'),@('phaseId','bytes32'),@('payer','address'),@('recipient','address')
        @('artist','address'),@('profileId','bytes32'),@('tokenDataHash','bytes32'),@('mintCommitment','bytes32')
        @('mintPolicyHash','bytes32'),@('price','uint256'),@('nonce','bytes32'),@('deadline','uint64'),@('signerEpoch','uint64')
    )
    $message = [ordered]@{
        collectionId='1'; phaseId=$phase; payer=$deployer; recipient=$deployer; artist=$deployer
        profileId=$profile; tokenDataHash=$tokenDataHash; mintCommitment=$commitment; mintPolicyHash=$policy
        price=$price; nonce=$nonce; deadline=$deadline; signerEpoch=$epoch
    }
    $typedData = @{
        types=@{
            EIP712Domain=@(@{name='name';type='string'},@{name='version';type='string'},@{name='chainId';type='uint256'},@{name='verifyingContract';type='address'})
            SaleAuthorization=@($fields | ForEach-Object { @{name=$_[0];type=$_[1]} })
        }
        primaryType='SaleAuthorization'
        domain=@{name='6529StreamFixedPriceSale';version='1';chainId='31337';verifyingContract=$addresses.sale}
        message=$message
    }
    $signature = Invoke-Rpc 'eth_signTypedData_v4' @($deployer,($typedData | ConvertTo-Json -Depth 30 -Compress))
    $tuple = '(' + (($message.GetEnumerator() | ForEach-Object {$_.Value}) -join ',') + ')'
    $result.demoReceipts.buy = Send-LocalTransaction $addresses.sale `
        'buy((uint256,bytes32,address,address,address,bytes32,bytes32,bytes32,bytes32,uint256,bytes32,uint64,uint64),bytes,bytes,bytes)' `
        @($tuple,$tokenData,$signature,$signature) $price
    $tokenId = Get-MintedTokenId $result.demoReceipts.buy $addresses.sale
    $result.tokenId=$tokenId
    Write-PublicResult $result
    $result.demoReceipts.requestEntropy = Send-LocalTransaction $addresses.entropy 'requestEntropy(uint256)' @($tokenId)
    $request = Get-EntropyRequest $result.demoReceipts.requestEntropy $addresses.entropy $tokenId $addresses.provider
    $result.entropyRequest=$request
    Write-PublicResult $result
    $raw = Invoke-Cast @('keccak','DEVELOPMENT ONLY deterministic demonstration output')
    $result.demoReceipts.fulfillEntropy = if ($MockVrfCoordinator) {
        Send-LocalTransaction $MockVrfCoordinator 'fulfill(uint256,uint256)' @($request.providerRequestId,(Convert-UInt $raw).ToString())
    } else {
        Send-LocalTransaction $addresses.provider 'fulfill(uint256,bytes32)' @($request.providerRequestId,$raw)
    }
    $seed=Read-Contract $addresses.entropy 'tokenSeed(uint256)(bytes32,bool)' @($tokenId)
    if (-not $seed[1] -or $seed[0] -eq ('0x'+('0'*64))) { throw 'Entropy seed was not finalized.' }
    if ((Read-Value $addresses.entropy 'pendingRequestCount()(uint256)') -ne 0) { throw 'Entropy remains pending.' }
    $result.seed=$seed[0]
    $result.providerResult=Read-Contract $addresses.provider 'providerResultStatus(uint256)(uint8,bytes32,bytes32,bool,bool)' @($request.providerRequestId)
    if (-not $result.providerResult[3] -or -not $result.providerResult[4]) { throw 'Provider result was not stored and delivered.' }
    if ((Convert-UInt $result.demoReceipts.fulfillEntropy.blockNumber) -le (Convert-UInt $result.demoReceipts.requestEntropy.blockNumber)) { throw 'Callback must be mined in a later transaction/block.' }
    Write-PublicResult $result
    $notification = Find-ReceiptEvent $result.demoReceipts.fulfillEntropy $addresses.core 'MetadataUpdate(uint256)' 1
    $notifiedToken = Invoke-Cast @('abi-decode','notification()(uint256)',$notification.data,'--json') | ConvertFrom-Json
    if ([string]$notifiedToken[0] -ne $tokenId -or (Read-Value $addresses.entropy 'metadataNotificationPending(uint256)(bool)' @($tokenId))) { throw 'Core metadata notification did not complete.' }
    $result.metadataNotificationDelivered=$true
    $tokenURI = Read-Value $addresses.core 'tokenURI(uint256)(string)' @($tokenId)
    if (-not $tokenURI.StartsWith('data:application/json;base64,')) { throw 'Expected onchain metadata data URI.' }
    $metadataJson = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($tokenURI.Split(',')[1]))
    $metadata = $metadataJson | ConvertFrom-Json
    if ($metadata.metadata_state -ne 'final') { throw 'Entropy did not finalize metadata.' }
    $metadataJson | Set-Content -LiteralPath (Join-Path $OutputDirectory 'token-1.metadata.json') -Encoding utf8
    if ($metadata.animation_url.StartsWith('data:text/html;base64,')) {
        [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($metadata.animation_url.Split(',')[1])) |
            Set-Content -LiteralPath (Join-Path $OutputDirectory 'token-1.artwork.html') -Encoding utf8
    }
    $result.demoReceipts.artistWithdrawal = Send-LocalTransaction $addresses.wallet 'release(address,address,address)' @('0x0000000000000000000000000000000000000000',$deployer,$deployer)
    Write-PublicResult $result
    $result.demoReceipts.protocolWithdrawal = Send-LocalTransaction $addresses.wallet 'release(address,address,address)' @('0x0000000000000000000000000000000000000000',$protocol,$protocol)
    Write-PublicResult $result
    $asset='0x0000000000000000000000000000000000000000'
    $artistReleased=Read-Value $addresses.wallet 'accountReleased(address,address)(uint256)' @($asset,$deployer)
    $protocolReleased=Read-Value $addresses.wallet 'accountReleased(address,address)(uint256)' @($asset,$protocol)
    if ((Convert-UInt $artistReleased) -ne ((Convert-UInt $price)*9/10) -or (Convert-UInt $protocolReleased) -ne ((Convert-UInt $price)/10)) { throw 'Split withdrawal accounting differs from the paid sale.' }
    $result.withdrawals=[ordered]@{artistWei=$artistReleased;protocolWei=$protocolReleased}
    $result.demoReceipts.transfer = Send-LocalTransaction $addresses.core 'transferFrom(address,address,uint256)' @($deployer,$protocol,$tokenId)
    $owner = Read-Value $addresses.core 'ownerOf(uint256)(address)' @($tokenId)
    if ($owner.ToLowerInvariant() -ne $protocol.ToLowerInvariant()) { throw 'NFT transfer did not complete.' }
    $result.tokenId = $tokenId
    $result.owner = $owner
    $result.metadataState = $metadata.metadata_state
    $result.royaltyInfo = Read-Contract $addresses.core 'royaltyInfo(uint256,uint256)(address,uint256)' @($tokenId,$price)
    $result.state = 'demonstrated'
    Write-PublicResult $result
    Write-Output (Join-Path $OutputDirectory 'current-stack.json')
} finally {
    $env:STREAM_DEPLOYER = $savedDeployer
    $env:STREAM_PROTOCOL_TREASURY = $savedTreasury
    $env:STREAM_ARTIST = $savedArtist
    $env:STREAM_PLATFORM_SIGNER = $savedPlatform
    $env:FOUNDRY_PROFILE = $savedProfile
    $env:FOUNDRY_BROADCAST = $savedBroadcast
    Pop-Location
}
