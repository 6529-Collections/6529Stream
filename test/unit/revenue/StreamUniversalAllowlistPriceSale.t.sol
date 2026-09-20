// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/UniversalAllowlistPriceFixture.sol";

contract StreamUniversalAllowlistPriceSaleTest is UniversalAllowlistPriceFixture {
    function testPaidPayerProofCommitsExactOriginalDomainAndBatchBytes() public {
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_e(payer,payer,address(0xBEEF),1);
        bytes32 domain=keccak256(abi.encode(keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),keccak256("6529StreamUniversalFixedPriceSaleAdapter"),keccak256("1"),block.chainid,address(priceSale)));
        bytes32 digest=keccak256(abi.encodePacked(hex"1901",domain,keccak256(abi.encode(priceSale.SALE_AUTHORIZATION_TYPEHASH(),e.authorization))));
        require(digest==priceSale.authorizationDigest(e.authorization),"original authorization domain");
        IStreamMintManager.MintBatch memory b;
        b.collectionId=1;b.phaseId=PHASE;b.payer=payer;b.initialRecipients=new address[](1);b.initialRecipients[0]=address(0xBEEF);b.beneficiaries=b.initialRecipients;
        b.tokenData=new bytes[](1);b.tokenData[0]=e.tokenData;b.mintCommitments=new bytes32[](1);b.mintCommitments[0]=e.authorization.mintCommitment;b.expectedPolicyHash=manager.POLICY();b.authorizationId=keccak256(abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"),digest));b.contextHash=digest;b.resolverData=proofData;
        bytes32 expected=keccak256(abi.encode(b,address(priceSale),uint256(0)));
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c=_pay(e);
        require(c.sale.amount==375 && c.operationIdentityCommitment==expected,"exact proof batch and amount");
        require(token.balanceOf(wallet)==375 && recorder.totalOfficialSettled(address(token))==375 && manager.ownerOf(1)==address(0xBEEF),"one exact paid mint");
    }
    function testRecipientProofUsesBeneficiaryAndNoOverrideUsesBasePrice() public {
        _bind(address(0xBEEF),IStreamMintManager.CounterKeyMode.RECIPIENT,false,0);
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c=_pay(_e(payer,payer,address(0xBEEF),1));
        require(c.sale.amount==1000 && token.balanceOf(wallet)==1000,"base fallback and beneficiary");
    }
    function testWrongSubjectMissingAndNoncanonicalEnvelopeRefuse() public {
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_e(payer,payer,payer,1);
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,bytes memory data)=priceSale.previewAllowlistExecution(e,proofData);
        bytes memory bad=bytes.concat(data,hex"00");c.saleExecutionHash=keccak256(bad);
        vm.expectRevert();vm.prank(payer);payment.settleERC20PrimarySaleByPayer(c,bad);_unused();
        vm.expectRevert();priceSale.previewAllowlistExecution(e,"");
        _bind(address(0xCAFE),IStreamMintManager.CounterKeyMode.PAYER,true,375);
        vm.expectRevert();priceSale.previewAllowlistExecution(e,proofData);_unused();
    }
    function testSelectedAmountCannotBeChangedEvenWithMatchingOuterHash() public {
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_e(payer,payer,payer,1);
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,)=priceSale.previewAllowlistExecution(e,proofData);
        bytes memory bad=abi.encode(keccak256("6529STREAM_UNIVERSAL_ALLOWLIST_EXECUTION_V1"),e,uint256(376),proofData);
        c.sale.amount=376;c.saleExecutionHash=keccak256(bad);
        vm.expectRevert();vm.prank(payer);payment.settleERC20PrimarySaleByPayer(c,bad);_unused();
    }
    function testDedicatedCapabilityHasNoProoflessEntryAndOriginalSaleRemainsUsable() public {
        require(!priceSale.supportsInterface(type(IStreamUniversalFixedPriceSaleAdapter).interfaceId),"no legacy capability advertised");
        require(priceSale.supportsInterface(type(IStreamUniversalAllowlistPriceSale).interfaceId),"dedicated capability");
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_e(payer,payer,payer,1);
        (bool ok,)=address(priceSale).staticcall(abi.encodeCall(IStreamUniversalFixedPriceSaleAdapter.previewExecution,(e)));
        require(!ok,"proofless preview absent");
        (ok,)=address(priceSale).call(abi.encodeCall(IStreamUniversalFixedPriceSaleAdapter.registerSale,(_config())));
        require(!ok,"proofless registration absent");
        e.authorization.saleId=originalSaleId;e.authorization.saleConfigHash=sale.saleRecord(originalSaleId).configHash;
        bytes32 digest=sale.authorizationDigest(e.authorization);
        e.platformSignature=_sign(PLATFORM_KEY,digest);e.artistSignature=_sign(ARTIST_KEY,digest);
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c=sale.previewExecution(e);
        vm.prank(payer);payment.settleERC20PrimarySaleByPayer(c,abi.encode(e));
        require(token.balanceOf(wallet)==1000 && priceManager.nonce()==0,"original carrier and replay remain independent");
    }
    function testDeclaredZeroIsFreeWithoutERC20IntentOrOfficialSettlement() public {
        _bind(payer,IStreamMintManager.CounterKeyMode.PAYER,true,0);_registerPrice(true);
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_e(payer,payer,payer,1);
        vm.recordLogs();vm.prank(payer);(uint256 tokenId,bytes32 root,bytes32 executionId)=priceSale.executeAllowlistFreeMint(e,proofData);
        require(tokenId==1 && root!=0 && priceSale.executionStatus(executionId)==2 && priceSale.authorizationUsed(artist,bytes32(uint256(1))),"free mint commits same replay");
        require(token.balanceOf(payer)==10000 && token.balanceOf(wallet)==0 && token.allowance(payer,address(payment))==10000 && recorder.totalOfficialSettled(address(token))==0,"no amount-zero payment or official revenue");
        Vm.Log[] memory logs=vm.getRecordedLogs();for(uint256 i;i<logs.length;++i)require(logs[i].emitter!=address(payment) && logs[i].emitter!=address(recorder),"no payment intent or official event");
        vm.expectRevert();vm.prank(payer);priceSale.executeAllowlistFreeMint(e,proofData);
    }
    function testUndeclaredZeroAndWrongFreeExecutorRefuse() public {
        _bind(payer,IStreamMintManager.CounterKeyMode.PAYER,true,0);
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_e(payer,payer,payer,1);
        vm.expectRevert(abi.encodeWithSelector(IStreamUniversalAllowlistPriceSale.SalePriceOverrideZeroUndeclared.selector,saleId));priceSale.previewAllowlistExecution(e,proofData);
        _registerPrice(true);e=_e(payer,payer,payer,1);
        vm.expectRevert(abi.encodeWithSelector(IStreamUniversalAllowlistPriceSale.InvalidUniversalPriceProfile.selector));priceSale.executeAllowlistFreeMint(e,proofData);_unused();
    }
    function testNonzeroPublishedFeeRequiresNativeAllowanceThenIdenticalRetry() public {
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_e(payer,payer,payer,1);
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,bytes memory data)=priceSale.previewAllowlistExecution(e,proofData);
        ImmediateRevealFixture(core.entropy()).configure(true,1,1,0);
        vm.expectRevert();vm.prank(payer);payment.settleERC20PrimarySaleByPayer(c,data);_unused();
        vm.deal(payer,1);
        vm.prank(payer);payment.settleERC20PrimarySaleByPayer{value:1}(c,data);
        require(token.balanceOf(wallet)==375 && ImmediateRevealFixture(core.entropy()).revealFeeEscrow(1)==1 && payer.balance==0,"same signed data with separately funded native fee");
    }
    function testZeroFeeAtMintAttemptsAndProviderFailureIsIsolated() public {
        ImmediateRevealFixture(core.entropy()).configure(true,0,0,0);_pay(_e(payer,payer,payer,1));
        require(ImmediateRevealFixture(core.entropy()).requests()==1,"actual bounded request attempt");
        ImmediateRevealFixture(core.entropy()).configure(true,0,0,1);_pay(_e(payer,payer,payer,2));
        require(manager.nonce()==2 && token.balanceOf(wallet)==750,"provider failure cannot undo paid mint");
    }
    function testLateManagerFailureRollsBackAndIdenticalExecutionRetries() public {
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_e(payer,payer,payer,1);
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,bytes memory data)=priceSale.previewAllowlistExecution(e,proofData);
        manager.configure(1);vm.expectRevert();vm.prank(payer);payment.settleERC20PrimarySaleByPayer(c,data);_unused();
        manager.configure(0);vm.prank(payer);payment.settleERC20PrimarySaleByPayer(c,data);
        require(token.balanceOf(wallet)==375 && priceSale.executionStatus(c.executionBinding.executionId)==2,"identical retry completes once");
        vm.expectRevert();vm.prank(payer);payment.settleERC20PrimarySaleByPayer(c,data);
    }
    function testSafePayerUsesOriginalContract20FrameAndLeafPrice() public {
        uint256[] memory keys=new uint256[](2);keys[0]=0xAA;keys[1]=0xBB;
        OfficialSafe account=createOfficialSafe(deploySafeComponents("1.4.1"),safeOwnerAddresses(keys),2,571);
        token.mint(address(account),2000);require(executeSafe(account,keys,address(token),0,abi.encodeCall(token.approve,(address(payment),uint256(2000))),0),"Safe approval");
        _bind(address(account),IStreamMintManager.CounterKeyMode.PAYER,true,375);
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_e(address(account),address(account),payer,1);
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,bytes memory data)=priceSale.previewAllowlistExecution(e,proofData);
        require(executeSafe(account,keys,address(payment),0,abi.encodeCall(payment.settleERC20PrimarySaleByPayer,(c,data)),0),"Safe payer CALL");
        require(token.balanceOf(address(account))==1625 && token.balanceOf(wallet)==375 && manager.ownerOf(1)==payer,"Safe funds original beneficiary");
    }
    function testRelayedIntentBindsLeafAmountAndOriginalPayer() public {
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_e(payer,address(this),payer,1);
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,bytes memory data)=priceSale.previewAllowlistExecution(e,proofData);
        StreamPrimarySettlementTypes.PaymentIntent memory intent=StreamPrimarySettlementTypes.PaymentIntent(payer,address(token),374,saleId,_primaryPolicy(),keccak256("price intent"),uint64(block.timestamp+100));
        bytes memory sig=_sign(PAYER_KEY,payment.paymentIntentDigest(intent));vm.expectRevert();payment.settleERC20PrimarySaleWithIntent(c,intent,sig,data);_unused();
        intent.maxAmount=375;sig=_sign(PAYER_KEY,payment.paymentIntentDigest(intent));payment.settleERC20PrimarySaleWithIntent(c,intent,sig,data);require(token.balanceOf(wallet)==375,"original intent maxAmount compares actual tier");
    }
    function testConstructorRegistersOnlyCanonicalRevealRowAndRejectsInvalidConfigs() public {
        require(priceSale.governanceAuthority()==factory.governanceAuthority(),"canonical factory authority");
        bytes32[] memory ids=priceSale.gasParameterIds();require(ids.length==1 && ids[0]==GAS,"one fixed inventory row");
        IStreamGasParameterHost.GasParameterConfig memory g=_revealConfig();g.name="UNRELATED";
        vm.expectRevert();new StreamUniversalAllowlistPriceSale(IStreamMintManager(address(manager)),recorder,vm.addr(PLATFORM_KEY),artists,g);
        g=_revealConfig();g.floor=99999;
        vm.expectRevert();new StreamUniversalAllowlistPriceSale(IStreamMintManager(address(manager)),recorder,vm.addr(PLATFORM_KEY),artists,g);
        g=_revealConfig();g.genesisValue=99999;
        vm.expectRevert();new StreamUniversalAllowlistPriceSale(IStreamMintManager(address(manager)),recorder,vm.addr(PLATFORM_KEY),artists,g);
        g=_revealConfig();g.failureClass=1;
        vm.expectRevert();new StreamUniversalAllowlistPriceSale(IStreamMintManager(address(manager)),recorder,vm.addr(PLATFORM_KEY),artists,g);
    }
    function testGovernedRevealRaiseUsesExactDelayedOriginalGGPState() public {
        bytes32 scope=keccak256(abi.encode(bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),block.chainid,address(priceSale),GAS));
        bytes32 domain=0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;
        bytes32 oldHash=keccak256(abi.encode(domain,scope,uint256(1000000),uint256(100000),uint8(2),uint64(1)));
        bytes32 next=keccak256(abi.encode(domain,scope,uint256(1500000),uint256(100000),uint8(2),uint64(2)));
        _context(scope,oldHash,next,1);
        vm.expectRevert();priceSale.raiseGasParameter(GAS,1500000);
        vm.expectRevert();vm.prank(address(0xF00));priceSale.raiseGasParameter(GAS,1500000);
        _context(scope,oldHash,next,0);vm.expectRevert();vm.prank(address(revenueAuthority));priceSale.raiseGasParameter(GAS,1500000);
        _context(scope,oldHash,bytes32(uint256(1)),1);vm.expectRevert();vm.prank(address(revenueAuthority));priceSale.raiseGasParameter(GAS,1500000);
        _context(scope,oldHash,next,1);vm.prank(address(revenueAuthority));priceSale.raiseGasParameter(GAS,1500000);_clearContext();
        (uint256 value,uint256 floor,uint8 class_,uint64 revision)=priceSale.gasParameterInfo(GAS);require(value==1500000 && floor==100000 && class_==2 && revision==2,"original GGP row");
        bytes32 sameValueNext=keccak256(abi.encode(domain,scope,uint256(1500000),uint256(100000),uint8(2),uint64(3)));
        _context(scope,next,sameValueNext,1);
        vm.expectRevert(abi.encodeWithSelector(IStreamGasParameterHost.GasParameterNotARaise.selector,GAS,uint256(1500000),uint256(1500000)));
        vm.prank(address(revenueAuthority));priceSale.raiseGasParameter(GAS,1500000);
        bytes32 excessiveNext=keccak256(abi.encode(domain,scope,uint256(3000001),uint256(100000),uint8(2),uint64(3)));
        _context(scope,next,excessiveNext,1);
        vm.expectRevert(abi.encodeWithSelector(IStreamGasParameterHost.GasParameterRaiseBoundExceeded.selector,GAS,uint256(1500000),uint256(3000001)));
        vm.prank(address(revenueAuthority));priceSale.raiseGasParameter(GAS,3000001);_clearContext();
        (value,floor,class_,revision)=priceSale.gasParameterInfo(GAS);
        require(value==1500000 && floor==100000 && class_==2 && revision==2,"refused values retain original GGP state");
    }

    function testOldVerifyingAddressSignaturesCannotAuthorizeDedicatedCarrier() public {
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_e(payer,payer,payer,1);
        bytes32 wrong=sale.authorizationDigest(e.authorization);
        e.platformSignature=_sign(PLATFORM_KEY,wrong);e.artistSignature=_sign(ARTIST_KEY,wrong);
        vm.expectRevert();priceSale.previewAllowlistExecution(e,proofData);_unused();
    }
    function testDirectPaidCallbackAndModuleRevocationRefuseAtomically() public {
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_e(payer,payer,payer,1);
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,bytes memory data)=priceSale.previewAllowlistExecution(e,proofData);
        vm.expectRevert();priceSale.executeERC20PreRevenueSingleStep(c,data);_unused();
        _status(address(priceSale),ModuleRegistryStatus.INCIDENT_REVOKED);
        vm.expectRevert();vm.prank(payer);payment.settleERC20PrimarySaleByPayer(c,data);_unused();
    }
    function testEIP2612ExactTierLateFailureRestoresNonceAndIdenticalPermitRetries() public {
        vm.deal(payer,125); ImmediateRevealFixture(core.entropy()).configure(true,0,100,0);
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_e(payer,payer,payer,1);
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,bytes memory data)=priceSale.previewAllowlistExecution(e,proofData);
        StreamPrimarySettlementTypes.EIP2612PermitAuthorization memory p;p.deadline=block.timestamp+1 hours;
        (p.v,p.r,p.s)=vm.sign(PAYER_KEY,token.permitDigest(payer,address(payment),375,p.deadline));
        manager.configure(1);vm.expectRevert();vm.prank(payer);payment.settleERC20PrimarySaleWithEIP2612Permit{value:125}(c,p,data);
        _unused();require(payer.balance==125 && priceSale.refundLiability()==0 && ImmediateRevealFixture(core.entropy()).revealFeeEscrow(1)==0,"native rollback with permit");require(token.nonces(payer)==0 && token.allowance(payer,address(payment))==10000,"permit rollback");
        manager.configure(0);vm.prank(payer);payment.settleERC20PrimarySaleWithEIP2612Permit{value:125}(c,p,data);
        require(token.nonces(payer)==1 && token.allowance(payer,address(payment))==0 && token.balanceOf(wallet)==375,"exact leaf permit amount");
        require(priceSale.refundableBalance(saleId,payer)==25 && priceSale.refundLiability()==25 && ImmediateRevealFixture(core.entropy()).revealFeeEscrow(1)==100,"permit wei and ERC20 remain separate");
    }
    function testOfficialPermit2ExactTierLateFailureRestoresBitmapAndRetries() public {
        vm.deal(payer,125); ImmediateRevealFixture(core.entropy()).configure(true,0,100,0);
        vm.prank(payer);token.approve(permit2,1000);
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_e(payer,payer,payer,1);
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,bytes memory data)=priceSale.previewAllowlistExecution(e,proofData);
        StreamPrimarySettlementTypes.Permit2TransferAuthorization memory p;p.nonce=255;p.deadline=block.timestamp+1 hours;
        bytes32 tokenHash=keccak256(abi.encode(keccak256("TokenPermissions(address token,uint256 amount)"),address(token),uint256(375)));
        bytes32 permitHash=keccak256(abi.encode(keccak256("PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"),tokenHash,address(payment),p.nonce,p.deadline));
        p.signature=_sign(PAYER_KEY,keccak256(abi.encodePacked(hex"1901",permit2Domain(permit2),permitHash)));
        manager.configure(1);vm.expectRevert();vm.prank(payer);payment.settleERC20PrimarySaleWithPermit2{value:125}(c,p,data);
        _unused();require(payer.balance==125 && priceSale.refundLiability()==0 && ImmediateRevealFixture(core.entropy()).revealFeeEscrow(1)==0,"native rollback with permit");require(IStreamPinnedPermit2(permit2).nonceBitmap(payer,0)==0 && token.allowance(payer,permit2)==1000,"Permit2 rollback");
        manager.configure(0);vm.prank(payer);payment.settleERC20PrimarySaleWithPermit2{value:125}(c,p,data);
        require(IStreamPinnedPermit2(permit2).nonceBitmap(payer,0)==uint256(1)<<255 && token.allowance(payer,permit2)==625 && token.balanceOf(wallet)==375,"same original Permit2 signature exact tier");
        require(priceSale.refundableBalance(saleId,payer)==25 && priceSale.refundLiability()==25 && ImmediateRevealFixture(core.entropy()).revealFeeEscrow(1)==100,"permit wei and ERC20 remain separate");
    }
    function testTokenReentrancyCannotCancelSaleDuringPaidExecution() public {
        token.setCallback(address(priceSale),abi.encodeCall(priceSale.cancelSale,(saleId)));
        priceSale.transferOwnership(address(token));
        _pay(_e(payer,payer,payer,1));
        require(!token.callbackSuccess() && token.callbackResultHash()==keccak256(abi.encodeWithSignature("Error(string)","ReentrancyGuard: reentrant call")),"host guard survives callback");
        require(!priceSale.saleRecord(saleId).cancelled && token.balanceOf(wallet)==375,"outer execution completes once");
    }
    function testLatePriceChangeRollsBackPaymentAndIdenticalBytesRetry() public {
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_e(payer,payer,payer,1);
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,bytes memory data)=priceSale.previewAllowlistExecution(e,proofData);
        bytes32 wrong=keccak256("callback changed price root");
        token.setCallback(address(priceManager),abi.encodeCall(priceManager.setCounter,(COUNTER,IStreamMintManager.CounterKeyMode.PAYER,wrong)));
        vm.expectRevert();vm.prank(payer);payment.settleERC20PrimarySaleByPayer(c,data);_unused();
        token.setCallback(address(0),"");vm.prank(payer);payment.settleERC20PrimarySaleByPayer(c,data);
        require(token.balanceOf(wallet)==375,"same original leaf after callback rollback");
    }
}
