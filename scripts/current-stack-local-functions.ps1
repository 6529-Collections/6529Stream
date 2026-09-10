# Shared local-only RPC, receipt and accounting helpers. No top-level RPC or signer access.
function Invoke-Rpc([string]$Method, [object[]]$Parameters) {
    $body = @{jsonrpc='2.0'; id=1; method=$Method; params=$Parameters} | ConvertTo-Json -Depth 30 -Compress
    $response = Invoke-RestMethod -Uri $RpcUrl -Method Post -ContentType 'application/json' -Body $body
    if ($response.PSObject.Properties.Name -contains 'error') { throw ($response.error | ConvertTo-Json -Compress) }
    return $response.result
}

function Invoke-Cast([string[]]$Arguments) {
    # Hex stdin is decoded by cast; ordinary text stays in argv to avoid a newline.
    $result = if ($Arguments.Count -eq 2 -and $Arguments[0] -eq 'keccak' -and $Arguments[1].StartsWith('0x')) {
        $Arguments[1] | & cast keccak
    } else { & cast @Arguments }
    if ($LASTEXITCODE -ne 0) { throw "cast failed: $($Arguments[0])" }
    return ($result -join "`n").Trim()
}

function Read-Contract([string]$Target, [string]$Signature, [string[]]$Arguments = @()) {
    $decoded = Invoke-Cast (@('call',$Target,$Signature) + $Arguments + @('--rpc-url',$RpcUrl,'--gas-limit','16000000','--json')) | ConvertFrom-Json -NoEnumerate
    return ,@($decoded)
}

function Read-Value([string]$Target, [string]$Signature, [string[]]$Arguments = @()) {
    return (Read-Contract $Target $Signature $Arguments)[0]
}

function Convert-UInt([string]$Value) {
    if ($Value.StartsWith('0x')) { return [bigint]::Parse(('0'+$Value.Substring(2)),[Globalization.NumberStyles]::AllowHexSpecifier) }
    return [bigint]::Parse($Value)
}

function Find-ReceiptEvent([object]$Receipt, [string]$Address, [string]$Signature, [int]$TopicCount) {
    $topic = Invoke-Cast @('keccak',$Signature)
    $events = @($Receipt.logs | Where-Object {
        $_.address -ieq $Address -and $_.topics.Count -eq $TopicCount -and $_.topics[0] -ieq $topic
    })
    if ($events.Count -ne 1) { throw "Expected exactly one $Signature event from $Address." }
    return $events[0]
}

function Get-MintedTokenId([object]$Receipt, [string]$Sale) {
    $event = Find-ReceiptEvent $Receipt $Sale 'NativeSaleSettled(bytes32,bytes32,uint256,bytes32,bytes32,address,uint256)' 4
    return (Convert-UInt $event.topics[3]).ToString()
}

function Get-EntropyRequest([object]$Receipt, [string]$Entropy, [string]$TokenId, [string]$Provider) {
    $event = Find-ReceiptEvent $Receipt $Entropy 'EntropyRequested(bytes32,uint256,bytes32,address,uint256)' 4
    if ((Convert-UInt $event.topics[2]) -ne (Convert-UInt $TokenId)) { throw 'Entropy receipt belongs to another token.' }
    $decoded = Invoke-Cast @('abi-decode','request()(address,uint256)',$event.data,'--json') | ConvertFrom-Json
    if ($decoded[0] -ine $Provider) { throw 'Entropy receipt belongs to another provider.' }
    return [ordered]@{requestKey=$event.topics[1];scopeId=$event.topics[3];providerRequestId=[string]$decoded[1]}
}

function Require-FreshLocalRun([string]$StatePath, [string]$BroadcastPath) {
    if ((Test-Path -LiteralPath $StatePath) -or (Test-Path -LiteralPath $BroadcastPath)) {
        throw 'Existing local deployment evidence must be retained; use fresh output and broadcast directories.'
    }
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

function Get-DeploymentAddress([object]$Broadcast, [string]$Name, [switch]$Optional) {
    $matches = @($Broadcast.transactions | Where-Object { $_.contractName -eq $Name -and $_.transactionType -eq 'CREATE' })
    if ($matches.Count -eq 0 -and $Optional) { return $null }
    if ($matches.Count -ne 1) { throw "Expected exactly one deployment receipt for $Name" }
    return $matches[0].contractAddress
}

function Write-PublicResult([object]$Result) {
    $Result | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'current-stack.json') -Encoding utf8
}

function Assert-ArtifactRuntime([object]$Artifact,[string]$Code) {
    $expected=$Artifact.deployedBytecode.object.ToLowerInvariant()
    $actual=$Code.ToLowerInvariant()
    if ($actual.Length -ne $expected.Length) {throw 'Deployed runtime size differs from artifact.'}
    # Compare all executable bytes, masking only compiler-declared immutables.
    # The provider's public immutable/config getters are asserted separately below.
    $immutableRanges=if ($Artifact.deployedBytecode.Contains('immutableReferences')) {$Artifact.deployedBytecode.immutableReferences.Values} else {@()}
    foreach ($ranges in $immutableRanges) {
        foreach ($range in $ranges) {
            $start=2+2*$range.start;$length=2*$range.length
            $actual=$actual.Remove($start,$length).Insert($start,('0'*$length))
            $expected=$expected.Remove($start,$length).Insert($start,('0'*$length))
        }
    }
    if ($actual -ne $expected) {throw 'Deployed runtime differs outside compiler-declared immutable ranges.'}
}
