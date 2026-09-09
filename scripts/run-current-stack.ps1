param(
    [string]$RpcUrl = 'http://127.0.0.1:8547',
    [string]$OutputDirectory = (Join-Path $env:TEMP '6529stream-current-local'),
    [switch]$DeployOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
$deployer = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'
$protocol = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8'

function Invoke-Rpc([string]$Method, [object[]]$Parameters) {
    $body = @{jsonrpc='2.0'; id=1; method=$Method; params=$Parameters} | ConvertTo-Json -Depth 30 -Compress
    $response = Invoke-RestMethod -Uri $RpcUrl -Method Post -ContentType 'application/json' -Body $body
    if ($response.PSObject.Properties.Name -contains 'error') { throw ($response.error | ConvertTo-Json -Compress) }
    return $response.result
}

function Invoke-Cast([string[]]$Arguments) {
    $result = & cast @Arguments
    if ($LASTEXITCODE -ne 0) { throw "cast failed: $($Arguments[0])" }
    return ($result -join "`n").Trim()
}

function Read-Contract([string]$Target, [string]$Signature, [string[]]$Arguments = @()) {
    return Invoke-Cast (@('call',$Target,$Signature) + $Arguments + @('--rpc-url',$RpcUrl,'--gas-limit','16000000'))
}

function Send-LocalTransaction(
    [string]$Target, [string]$Signature, [string[]]$Arguments = @(), [string]$Value = '0'
) {
    $result = Invoke-Cast (@('send',$Target,$Signature) + $Arguments + @(
        '--value',$Value,'--unlocked','--from',$deployer,'--rpc-url',$RpcUrl,'--gas-limit','16000000','--json'
    )) | ConvertFrom-Json
    if ($result.status -notin @('0x1','1',1)) { throw "Transaction reverted: $($result.transactionHash)" }
    return $result
}

function Get-DeploymentAddress([object]$Broadcast, [string]$Name) {
    $matches = @($Broadcast.transactions | Where-Object { $_.contractName -eq $Name -and $_.transactionType -eq 'CREATE' })
    if ($matches.Count -eq 0) { throw "No deployment receipt for $Name" }
    return $matches[0].contractAddress
}

function Write-PublicResult([object]$Result) {
    $Result | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'current-stack.json') -Encoding utf8
}

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
Push-Location $repoRoot
$savedDeployer = $env:STREAM_DEPLOYER
$savedTreasury = $env:STREAM_PROTOCOL_TREASURY
$savedArtist = $env:STREAM_ARTIST
$savedPlatform = $env:STREAM_PLATFORM_SIGNER
try {
    $env:STREAM_DEPLOYER = $deployer
    $env:STREAM_PROTOCOL_TREASURY = $protocol
    $env:STREAM_ARTIST = $deployer
    $env:STREAM_PLATFORM_SIGNER = $deployer
    $skip = @('--skip','test')
    Get-ChildItem script -Recurse -Filter '*.s.sol' |
        Where-Object { $_.Name -ne 'DeployCurrentStack.s.sol' } |
        ForEach-Object { $skip += @('--skip',$_.Name) }
    & forge script script/current/DeployCurrentStack.s.sol:DeployCurrentStack @skip `
        --via-ir --isolate --out out/current-stack-development --cache-path cache/current-stack-development `
        --rpc-url $RpcUrl --sender $deployer --unlocked --broadcast --slow
    if ($LASTEXITCODE -ne 0) { throw 'Current-stack deployment failed.' }

    $broadcastPath = Join-Path $repoRoot 'broadcast/DeployCurrentStack.s.sol/31337/run-latest.json'
    $broadcast = Get-Content -Raw -LiteralPath $broadcastPath | ConvertFrom-Json
    $addresses = [ordered]@{}
    $names = [ordered]@{
        core='StreamCore'; executor='StreamGovernanceExecutor'; governanceRoot='StreamGovernanceActor'
        registry='StreamModuleRegistry'; manifest='StreamSystemManifest'; manager='StreamMintManager'
        ledger='StreamMintLedger'; sale='StreamFixedPriceSaleAdapter'; auction='StreamEnglishAuctionHouse'
        factory='StreamSplitFactory'; entropy='StreamEntropyCoordinator'; metadata='StreamMetadataRouter'
        royalty='StreamRoyaltyResolver'; artistRegistry='StreamCollectionArtistRegistry'; provider='DevelopmentEntropyProvider'
    }
    foreach ($item in $names.GetEnumerator()) { $addresses[$item.Key] = Get-DeploymentAddress $broadcast $item.Value }
    $artistLabel = Invoke-Cast @('keccak','artist')
    $protocolLabel = Invoke-Cast @('keccak','protocol')
    $splitMetadata = Invoke-Cast @('keccak','development split')
    $entries = "[($deployer,900000,$artistLabel),($protocol,100000,$protocolLabel)]"
    $profile = Read-Contract $addresses.factory 'profileIdFor((address,uint32,bytes32)[],bytes32)(bytes32)' @($entries,$splitMetadata)
    $addresses.wallet = Read-Contract $addresses.factory 'walletFor(bytes32)(address)' @($profile)
    $result = [ordered]@{
        schema='6529stream.current-local-demo.v1'; state='deployed'; chainId=31337; rpcUrl=$RpcUrl
        developmentEntropy=$true; randomnessDisclosure='Controller-supplied local values; not secure randomness.'
        deployer=$deployer; protocol=$protocol; addresses=$addresses; profile=$profile
        broadcastReceipts='broadcast/DeployCurrentStack.s.sol/31337/run-latest.json'; demoReceipts=[ordered]@{}
    }
    Write-PublicResult $result
    if ($DeployOnly) { Write-Output (Join-Path $OutputDirectory 'current-stack.json'); return }

    $phase = Invoke-Cast @('keccak','current-stack fixed price')
    $tokenData = '0x' + [Convert]::ToHexString([Text.Encoding]::UTF8.GetBytes('Stream local demonstration'))
    $tokenDataHash = Invoke-Cast @('keccak',$tokenData)
    $commitment = Invoke-Cast @('keccak','local demo commitment')
    $nonce = Invoke-Cast @('keccak','local demo sale 1')
    $policy = Read-Contract $addresses.manager 'phasePolicyHash(uint256,bytes32)(bytes32)' @('1',$phase)
    $epoch = Read-Contract $addresses.sale 'signerEpoch()(uint64)'
    $block = Invoke-Rpc 'eth_getBlockByNumber' @('latest',$false)
    $deadline = ([Convert]::ToUInt64($block.timestamp.Substring(2),16) + 3600).ToString()
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
    $tokenId = Read-Contract $addresses.core 'lastAllocatedTokenId()(uint256)'
    $providerRequestId = Read-Contract $addresses.provider 'nextRequestId()(uint256)'
    $result.demoReceipts.requestEntropy = Send-LocalTransaction $addresses.entropy 'requestEntropy(uint256)' @($tokenId)
    $raw = Invoke-Cast @('keccak','DEVELOPMENT ONLY deterministic demonstration output')
    $result.demoReceipts.fulfillEntropy = Send-LocalTransaction $addresses.provider 'fulfill(uint256,bytes32)' @($providerRequestId,$raw)
    $tokenURI = Read-Contract $addresses.core 'tokenURI(uint256)(string)' @($tokenId) | ConvertFrom-Json
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
    $result.demoReceipts.protocolWithdrawal = Send-LocalTransaction $addresses.wallet 'release(address,address,address)' @('0x0000000000000000000000000000000000000000',$protocol,$protocol)
    $result.demoReceipts.transfer = Send-LocalTransaction $addresses.core 'transferFrom(address,address,uint256)' @($deployer,$protocol,$tokenId)
    $owner = Read-Contract $addresses.core 'ownerOf(uint256)(address)' @($tokenId)
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
    Pop-Location
}
