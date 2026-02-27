// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {TollanUniverseItems} from "../src/TollanUniverseItems.sol";
import {TollanUniverseItemsScript} from "../script/TollanUniverseItemsScript.s.sol";
import {IErrors} from "../src/interfaces/IErrors.sol";

contract TollanUniverseItemsTest is Test {
    TollanUniverseItems tollanUniverseItems;
    TollanUniverseItemsScript tollanUniverseItemsScript;

    address admin = makeAddr("admin");
    address minter = makeAddr("minter");
    address burner = makeAddr("burner");
    uint256 signerPrivateKey =
        0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
    address signer;
    address user = makeAddr("user");
    address user2 = makeAddr("user2");

    string constant name712 = "TollanUniverseItems";
    string constant version712 = "1.0.0";

    // Test data
    string constant PHYSICAL_ID_1 = "SWORD_001";
    string constant PHYSICAL_ID_2 = "SHIELD_002";
    string constant PHYSICAL_ID_3 = "POTION_003";
    string constant METADATA_URI_1 = "ipfs://QmTest1";
    string constant METADATA_URI_2 = "ipfs://QmTest2";
    string constant METADATA_URI_3 = "ipfs://QmTest3";
    uint256 constant AMOUNT_CAP_UNLIMITED = 0;
    uint256 constant AMOUNT_CAP_100 = 100;

    // Role constants
    bytes32 constant ADMIN_ROLE =
        0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775;
    bytes32 constant MINT_ROLE =
        0x154c00819833dac601ee5ddded6fda79d9d8b506b911b3dbd54cdb95fe6c3686;
    bytes32 constant BURN_ROLE =
        0xe97b137254058bd94f28d2f3eb79e2d34074ffb488d042e3bc958e0a57d2fa22;

    // EIP-712 typehashes
    bytes32 constant CLAIM_TYPEHASH =
        0xb395120c6a2e3f275050bc1e5ad73742df9a5de843cb9b26b18620d1cc14c78e;
    bytes32 constant CLAIM_BATCH_TYPEHASH =
        0x70dae5e3916ec9bad3f26be7851dac19106818068928cf478718012a94764f52;

    event ItemDefined(
        string indexed physicalId,
        uint256 indexed nftId,
        string metadataURI
    );
    event TokenURIUpdated(uint256 indexed tokenId, string newURI);
    event BaseURIUpdated(string newBaseURI);
    event ItemsClaimed(
        address indexed user,
        uint256[] tokenIds,
        uint256[] amounts
    );
    event ItemClaimed(address indexed user, uint256 tokenId, uint256 amount);
    event SignerUpdated(address indexed oldSigner, address indexed newSigner);

    function setUp() public {
        signer = vm.addr(signerPrivateKey);

        deal(admin, 100 ether);
        deal(minter, 100 ether);
        deal(burner, 100 ether);
        deal(signer, 100 ether);
        deal(user, 100 ether);
        deal(user2, 100 ether);

        tollanUniverseItemsScript = new TollanUniverseItemsScript();
        (tollanUniverseItems, , ) = tollanUniverseItemsScript.deploy(
            admin,
            minter,
            burner,
            signer,
            name712,
            version712
        );
    }

    // =============================================================
    // INITIALIZE TESTS
    // =============================================================

    function test_Initialize_SetsRolesCorrectly() public view {
        assertTrue(
            tollanUniverseItems.hasRole(
                tollanUniverseItems.DEFAULT_ADMIN_ROLE(),
                admin
            )
        );
        assertTrue(tollanUniverseItems.hasRole(ADMIN_ROLE, admin));
        assertTrue(tollanUniverseItems.hasRole(MINT_ROLE, minter));
        assertTrue(tollanUniverseItems.hasRole(BURN_ROLE, burner));
    }

    function test_Initialize_SetsNextTokenIdTo1() public view {
        assertEq(tollanUniverseItems.getNextTokenId(), 1);
    }

    function test_Initialize_CannotBeCalledTwice() public {
        vm.expectRevert();
        tollanUniverseItems.initialize(
            admin,
            minter,
            burner,
            signer,
            name712,
            version712
        );
    }

    // =============================================================
    // DEFINE ITEM TESTS
    // =============================================================

    function test_DefineItem_Success() public {
        vm.prank(admin);
        uint256 nftId = tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        assertEq(nftId, 1);
        assertEq(tollanUniverseItems.getNextTokenId(), 2);
        assertEq(tollanUniverseItems.getNftIdByPhysicalId(PHYSICAL_ID_1), 1);
        assertEq(tollanUniverseItems.getPhysicalIdByTokenId(1), PHYSICAL_ID_1);
    }

    function test_DefineItem_EmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit ItemDefined(PHYSICAL_ID_1, 1, METADATA_URI_1);

        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
    }

    function test_DefineItem_RevertsIfNotAdmin() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                ADMIN_ROLE
            )
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
    }

    function test_DefineItem_RevertsIfEmptyPhysicalId() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.EmptyString.selector, "")
        );
        tollanUniverseItems.defineItem(
            "",
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
    }

    function test_DefineItem_RevertsIfAlreadyDefined() public {
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IErrors.ItemAlreadyDefined.selector,
                PHYSICAL_ID_1
            )
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        vm.stopPrank();
    }

    function test_DefineItem_WithAmountCap() public {
        vm.prank(admin);
        uint256 nftId = tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_100
        );

        assertEq(
            tollanUniverseItems.getAmountCap(PHYSICAL_ID_1),
            AMOUNT_CAP_100
        );
        assertEq(nftId, 1);
    }

    // =============================================================
    // DEFINE ITEMS (BATCH) TESTS
    // =============================================================

    function test_DefineItems_Success() public {
        string[] memory physicalIds = new string[](3);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;
        physicalIds[2] = PHYSICAL_ID_3;

        string[] memory metadataURIs = new string[](3);
        metadataURIs[0] = METADATA_URI_1;
        metadataURIs[1] = METADATA_URI_2;
        metadataURIs[2] = METADATA_URI_3;

        uint256[] memory amountCaps = new uint256[](3);
        amountCaps[0] = AMOUNT_CAP_UNLIMITED;
        amountCaps[1] = AMOUNT_CAP_100;
        amountCaps[2] = AMOUNT_CAP_UNLIMITED;

        vm.prank(admin);
        uint256[] memory nftIds = tollanUniverseItems.defineItems(
            physicalIds,
            metadataURIs,
            amountCaps
        );

        assertEq(nftIds.length, 3);
        assertEq(nftIds[0], 1);
        assertEq(nftIds[1], 2);
        assertEq(nftIds[2], 3);
        assertEq(tollanUniverseItems.getNextTokenId(), 4);

        assertEq(tollanUniverseItems.getNftIdByPhysicalId(PHYSICAL_ID_1), 1);
        assertEq(tollanUniverseItems.getNftIdByPhysicalId(PHYSICAL_ID_2), 2);
        assertEq(tollanUniverseItems.getNftIdByPhysicalId(PHYSICAL_ID_3), 3);
        assertEq(tollanUniverseItems.getPhysicalIdByTokenId(1), PHYSICAL_ID_1);
        assertEq(tollanUniverseItems.getPhysicalIdByTokenId(2), PHYSICAL_ID_2);
        assertEq(tollanUniverseItems.getPhysicalIdByTokenId(3), PHYSICAL_ID_3);
        assertEq(
            tollanUniverseItems.getAmountCap(PHYSICAL_ID_1),
            AMOUNT_CAP_UNLIMITED
        );
        assertEq(
            tollanUniverseItems.getAmountCap(PHYSICAL_ID_2),
            AMOUNT_CAP_100
        );
        assertEq(
            tollanUniverseItems.getAmountCap(PHYSICAL_ID_3),
            AMOUNT_CAP_UNLIMITED
        );
    }

    function test_DefineItems_RevertsIfLengthMismatch() public {
        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        string[] memory metadataURIs = new string[](3);
        metadataURIs[0] = METADATA_URI_1;
        metadataURIs[1] = METADATA_URI_2;
        metadataURIs[2] = METADATA_URI_3;

        uint256[] memory amountCaps = new uint256[](2);

        vm.prank(admin);
        vm.expectRevert(IErrors.LengthMismatch.selector);
        tollanUniverseItems.defineItems(physicalIds, metadataURIs, amountCaps);
    }

    function test_DefineItems_RevertsIfNotAdmin() public {
        string[] memory physicalIds = new string[](1);
        physicalIds[0] = PHYSICAL_ID_1;

        string[] memory metadataURIs = new string[](1);
        metadataURIs[0] = METADATA_URI_1;

        uint256[] memory amountCaps = new uint256[](1);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                ADMIN_ROLE
            )
        );
        tollanUniverseItems.defineItems(physicalIds, metadataURIs, amountCaps);
    }

    function test_DefineItems_RevertsIfEmptyPhysicalId() public {
        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = "";

        string[] memory metadataURIs = new string[](2);
        metadataURIs[0] = METADATA_URI_1;
        metadataURIs[1] = METADATA_URI_2;

        uint256[] memory amountCaps = new uint256[](2);

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.EmptyString.selector, "")
        );
        tollanUniverseItems.defineItems(physicalIds, metadataURIs, amountCaps);
    }

    // =============================================================
    // SET TOKEN URI TESTS
    // =============================================================

    function test_SetTokenURI_Success() public {
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.expectEmit(true, false, false, true);
        emit TokenURIUpdated(1, METADATA_URI_2);
        assertEq(tollanUniverseItems.uri(1), METADATA_URI_1);

        tollanUniverseItems.setTokenURI(1, METADATA_URI_2);
        vm.stopPrank();

        assertEq(tollanUniverseItems.uri(1), METADATA_URI_2);
    }

    function test_SetTokenURI_RevertsIfNotAdmin() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                ADMIN_ROLE
            )
        );
        tollanUniverseItems.setTokenURI(1, METADATA_URI_2);
    }

    function test_SetTokenURI_RevertsIfZeroTokenId() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IErrors.ZeroUint.selector, 0));
        tollanUniverseItems.setTokenURI(0, METADATA_URI_1);
    }

    function test_SetTokenURI_RevertsIfItemNotDefined() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ItemNotDefined.selector, "")
        );
        tollanUniverseItems.setTokenURI(999, METADATA_URI_1);
    }

    // =============================================================
    // SET BASE URI TESTS
    // =============================================================

    function test_SetBaseURI_Success() public {
        string memory newBaseURI = "https://api.tollan.io/metadata/";

        vm.expectEmit(false, false, false, true);
        emit BaseURIUpdated(newBaseURI);

        vm.prank(admin);
        tollanUniverseItems.setBaseURI(newBaseURI);

        vm.prank(admin);
        tollanUniverseItems.defineItem("1", "uri", AMOUNT_CAP_UNLIMITED);

        assertEq(tollanUniverseItems.uri(1), string.concat(newBaseURI, "uri"));
    }

    function test_SetBaseURI_RevertsIfNotAdmin() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                ADMIN_ROLE
            )
        );
        tollanUniverseItems.setBaseURI("https://example.com/");
    }

    // =============================================================
    // PAUSE/UNPAUSE TESTS
    // =============================================================

    function test_Pause_Success() public {
        vm.prank(admin);
        tollanUniverseItems.pause();

        assertTrue(tollanUniverseItems.paused());
    }

    function test_Pause_RevertsIfNotAdmin() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                ADMIN_ROLE
            )
        );
        tollanUniverseItems.pause();
    }

    function test_Unpause_Success() public {
        vm.startPrank(admin);
        tollanUniverseItems.pause();
        assertTrue(tollanUniverseItems.paused());

        tollanUniverseItems.unpause();
        assertFalse(tollanUniverseItems.paused());
        vm.stopPrank();
    }

    function test_Unpause_RevertsIfNotAdmin() public {
        vm.prank(admin);
        tollanUniverseItems.pause();

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                ADMIN_ROLE
            )
        );
        tollanUniverseItems.unpause();
    }

    // =============================================================
    // SET TOKEN ROYALTY TESTS
    // =============================================================

    function test_SetTokenRoyalty_Success() public {
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_2,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.setTokenRoyalty(1, admin, 500); // 5%
        tollanUniverseItems.setTokenRoyalty(2, user, 1000); // 10%
        vm.stopPrank();

        (address receiver, uint256 royaltyAmount) = tollanUniverseItems
            .royaltyInfo(1, 10000);
        assertEq(receiver, admin);
        assertEq(royaltyAmount, 500);

        (address receiver2, uint256 royaltyAmount2) = tollanUniverseItems
            .royaltyInfo(2, 10000);
        assertEq(receiver2, user);
        assertEq(royaltyAmount2, 1000);
    }

    function test_SetTokenRoyalty_RevertsIfNotAdmin() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                ADMIN_ROLE
            )
        );
        tollanUniverseItems.setTokenRoyalty(1, admin, 500);
    }

    // =============================================================
    // SET DEFAULT ROYALTY TESTS
    // =============================================================

    function test_SetDefaultRoyalty_Success() public {
        vm.prank(admin);
        tollanUniverseItems.setDefaultRoyalty(admin, 250); // 2.5%

        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        (address receiver, uint256 royaltyAmount) = tollanUniverseItems
            .royaltyInfo(1, 10000);
        assertEq(receiver, admin);
        assertEq(royaltyAmount, 250);
    }

    function test_SetDefaultRoyalty_RevertsIfNotAdmin() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                ADMIN_ROLE
            )
        );
        tollanUniverseItems.setDefaultRoyalty(admin, 250);
    }

    // =============================================================
    // SIGNER MANAGEMENT TESTS
    // =============================================================

    function test_GetSigner_ReturnsInitialSigner() public view {
        assertEq(tollanUniverseItems.getSigner(), signer);
    }

    function test_SetSigner_Success() public {
        address newSigner = makeAddr("newSigner");
        
        vm.expectEmit(true, true, false, false);
        emit SignerUpdated(signer, newSigner);
        
        vm.prank(admin);
        tollanUniverseItems.setSigner(newSigner);
        
        assertEq(tollanUniverseItems.getSigner(), newSigner);
    }

    function test_SetSigner_RevertsIfNotAdmin() public {
        address newSigner = makeAddr("newSigner");
        
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                ADMIN_ROLE
            )
        );
        tollanUniverseItems.setSigner(newSigner);
    }

    function test_SetSigner_RevertsIfZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ZeroAddress.selector, address(0))
        );
        tollanUniverseItems.setSigner(address(0));
    }

    function test_SetSigner_EmitsEvent() public {
        address newSigner = makeAddr("newSigner");
        
        vm.expectEmit(true, true, false, false);
        emit SignerUpdated(signer, newSigner);
        
        vm.prank(admin);
        tollanUniverseItems.setSigner(newSigner);
    }

    function test_Claim_RevertsAfterSignerChange_WithOldSignature() public {
        // Define item
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        uint256 tokenId = 1;
        uint256 amount = 10;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = tollanUniverseItems.nonces(user);

        // Sign with original signer
        bytes memory signature = _signClaim(
            user,
            tokenId,
            PHYSICAL_ID_1,
            amount,
            nonce,
            deadline
        );

        // Change signer
        uint256 newSignerPrivateKey = 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890;
        address newSigner = vm.addr(newSignerPrivateKey);
        
        vm.prank(admin);
        tollanUniverseItems.setSigner(newSigner);

        // Try to claim with old signature
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidSigner.selector));
        tollanUniverseItems.claim(
            tokenId,
            PHYSICAL_ID_1,
            amount,
            deadline,
            signature
        );
    }

    function test_Claim_SuccessAfterSignerChange_WithNewSignature() public {
        // Define item
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        uint256 tokenId = 1;
        uint256 amount = 10;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = tollanUniverseItems.nonces(user);

        // Change signer
        uint256 newSignerPrivateKey = 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890;
        address newSigner = vm.addr(newSignerPrivateKey);
        
        vm.prank(admin);
        tollanUniverseItems.setSigner(newSigner);

        // Sign with new signer
        bytes memory signature = _signClaimWithKey(
            user,
            tokenId,
            PHYSICAL_ID_1,
            amount,
            nonce,
            deadline,
            newSignerPrivateKey
        );

        // Claim should succeed with new signature
        vm.prank(user);
        tollanUniverseItems.claim(
            tokenId,
            PHYSICAL_ID_1,
            amount,
            deadline,
            signature
        );

        assertEq(tollanUniverseItems.balanceOf(user, tokenId), amount);
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_1), amount);
    }

    // =============================================================
    // MINT BY PHYSICAL ID TESTS
    // =============================================================

    function test_MintByPhysicalId_Success() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(minter);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 10);

        assertEq(tollanUniverseItems.balanceOf(user, 1), 10);
        assertEq(tollanUniverseItems.totalSupply(1), 10);
    }

    function test_MintByPhysicalId_RevertsIfNotMinter() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                MINT_ROLE
            )
        );
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 10);
    }

    function test_MintByPhysicalId_RevertsIfZeroAddress() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ZeroAddress.selector, address(0))
        );
        tollanUniverseItems.mintByPhysicalId(address(0), PHYSICAL_ID_1, 10);
    }

    function test_MintByPhysicalId_RevertsIfZeroAmount() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(IErrors.ZeroUint.selector, 0));
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 0);
    }

    function test_MintByPhysicalId_RevertsIfEmptyPhysicalId() public {
        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.EmptyString.selector, "")
        );
        tollanUniverseItems.mintByPhysicalId(user, "", 10);
    }

    function test_MintByPhysicalId_RevertsIfItemNotDefined() public {
        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IErrors.ItemNotDefined.selector,
                PHYSICAL_ID_1
            )
        );
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 10);
    }

    function test_MintByPhysicalId_RevertsIfPaused() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(admin);
        tollanUniverseItems.pause();

        vm.prank(minter);
        vm.expectRevert();
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 10);
    }

    function test_MintByPhysicalId_RevertsIfAmountCapExceeded() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_100
        );

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.AmountCapExceeded.selector, 101, 100)
        );
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 101);
    }

    // =============================================================
    // MINT BATCH BY PHYSICAL ID TESTS
    // =============================================================

    function test_MintBatchByPhysicalId_Success() public {
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_2,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        vm.stopPrank();

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 20;

        vm.prank(minter);
        tollanUniverseItems.mintBatchByPhysicalId(user, physicalIds, amounts);

        assertEq(tollanUniverseItems.balanceOf(user, 1), 10);
        assertEq(tollanUniverseItems.balanceOf(user, 2), 20);
    }

    function test_MintBatchByPhysicalId_RevertsIfNotMinter() public {
        string[] memory physicalIds = new string[](1);
        physicalIds[0] = PHYSICAL_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10;

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                MINT_ROLE
            )
        );
        tollanUniverseItems.mintBatchByPhysicalId(user, physicalIds, amounts);
    }

    function test_MintBatchByPhysicalId_RevertsIfLengthMismatch() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10;

        vm.prank(minter);
        vm.expectRevert(IErrors.LengthMismatch.selector);
        tollanUniverseItems.mintBatchByPhysicalId(user, physicalIds, amounts);
    }

    function test_MintBatchByPhysicalId_RevertsIfZeroAddress() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        string[] memory physicalIds = new string[](1);
        physicalIds[0] = PHYSICAL_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10;

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ZeroAddress.selector, address(0))
        );
        tollanUniverseItems.mintBatchByPhysicalId(
            address(0),
            physicalIds,
            amounts
        );
    }

    function test_MintBatchByPhysicalId_RevertsIfItemNotDefined() public {
        string[] memory physicalIds = new string[](1);
        physicalIds[0] = PHYSICAL_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10;

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IErrors.ItemNotDefined.selector,
                PHYSICAL_ID_1
            )
        );
        tollanUniverseItems.mintBatchByPhysicalId(user, physicalIds, amounts);
    }

    // =============================================================
    // BURN BY PHYSICAL ID TESTS
    // =============================================================

    function test_BurnByPhysicalId_Success() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(minter);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 10);

        assertEq(tollanUniverseItems.balanceOf(user, 1), 10);

        vm.prank(burner);
        tollanUniverseItems.burnByPhysicalId(user, PHYSICAL_ID_1, 5);

        assertEq(tollanUniverseItems.balanceOf(user, 1), 5);
        assertEq(tollanUniverseItems.totalSupply(1), 5);
    }

    function test_BurnByPhysicalId_RevertsIfNotBurner() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(minter);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 10);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                BURN_ROLE
            )
        );
        tollanUniverseItems.burnByPhysicalId(user, PHYSICAL_ID_1, 5);
    }

    function test_BurnByPhysicalId_RevertsIfZeroAddress() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(burner);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ZeroAddress.selector, address(0))
        );
        tollanUniverseItems.burnByPhysicalId(address(0), PHYSICAL_ID_1, 5);
    }

    function test_BurnByPhysicalId_RevertsIfZeroAmount() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(burner);
        vm.expectRevert(abi.encodeWithSelector(IErrors.ZeroUint.selector, 0));
        tollanUniverseItems.burnByPhysicalId(user, PHYSICAL_ID_1, 0);
    }

    function test_BurnByPhysicalId_RevertsIfEmptyPhysicalId() public {
        vm.prank(burner);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.EmptyString.selector, "")
        );
        tollanUniverseItems.burnByPhysicalId(user, "", 5);
    }

    function test_BurnByPhysicalId_RevertsIfItemNotDefined() public {
        vm.prank(burner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IErrors.ItemNotDefined.selector,
                PHYSICAL_ID_1
            )
        );
        tollanUniverseItems.burnByPhysicalId(user, PHYSICAL_ID_1, 5);
    }

    function test_BurnByPhysicalId_RevertsIfInsufficientBalance() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(minter);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 5);

        vm.prank(burner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Errors.ERC1155InsufficientBalance.selector,
                user,
                5,
                10,
                1
            )
        );
        tollanUniverseItems.burnByPhysicalId(user, PHYSICAL_ID_1, 10);
    }

    // =============================================================
    // BURN BATCH BY PHYSICAL ID TESTS
    // =============================================================

    function test_BurnBatchByPhysicalId_Success() public {
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_2,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        vm.stopPrank();

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory mintAmounts = new uint256[](2);
        mintAmounts[0] = 10;
        mintAmounts[1] = 20;

        vm.prank(minter);
        tollanUniverseItems.mintBatchByPhysicalId(
            user,
            physicalIds,
            mintAmounts
        );

        uint256[] memory burnAmounts = new uint256[](2);
        burnAmounts[0] = 5;
        burnAmounts[1] = 10;

        vm.prank(burner);
        tollanUniverseItems.burnBatchByPhysicalId(
            user,
            physicalIds,
            burnAmounts
        );

        assertEq(tollanUniverseItems.balanceOf(user, 1), 5);
        assertEq(tollanUniverseItems.balanceOf(user, 2), 10);
    }

    function test_BurnBatchByPhysicalId_RevertsIfNotBurner() public {
        string[] memory physicalIds = new string[](1);
        physicalIds[0] = PHYSICAL_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 5;

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                BURN_ROLE
            )
        );
        tollanUniverseItems.burnBatchByPhysicalId(user, physicalIds, amounts);
    }

    function test_BurnBatchByPhysicalId_RevertsIfLengthMismatch() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 5;

        vm.prank(burner);
        vm.expectRevert(IErrors.LengthMismatch.selector);
        tollanUniverseItems.burnBatchByPhysicalId(user, physicalIds, amounts);
    }

    function test_BurnBatchByPhysicalId_RevertsIfZeroAddress() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        string[] memory physicalIds = new string[](1);
        physicalIds[0] = PHYSICAL_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 5;

        vm.prank(burner);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ZeroAddress.selector, address(0))
        );
        tollanUniverseItems.burnBatchByPhysicalId(
            address(0),
            physicalIds,
            amounts
        );
    }

    // =============================================================
    // CLAIM TESTS
    // =============================================================

    function test_Claim_Success() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        uint256 tokenId = 1;
        uint256 amount = 10;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = tollanUniverseItems.nonces(user);

        bytes memory signature = _signClaim(
            user,
            tokenId,
            PHYSICAL_ID_1,
            amount,
            nonce,
            deadline
        );

        vm.expectEmit(true, false, false, true);
        emit ItemClaimed(user, tokenId, amount);

        vm.prank(user);
        tollanUniverseItems.claim(
            tokenId,
            PHYSICAL_ID_1,
            amount,
            deadline,
            signature
        );

        assertEq(tollanUniverseItems.balanceOf(user, tokenId), amount);
        assertEq(tollanUniverseItems.nonces(user), nonce + 1);
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_1), amount);
    }

    function test_Claim_AccumulatesCorrectly() public {
        // Define item
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        uint256 tokenId = 1;

        // First claim: 50 tokens
        uint256 amount1 = 50;
        uint256 deadline1 = block.timestamp + 1 hours;
        uint256 nonce1 = tollanUniverseItems.nonces(user);
        bytes memory signature1 = _signClaim(
            user,
            tokenId,
            PHYSICAL_ID_1,
            amount1,
            nonce1,
            deadline1
        );

        vm.prank(user);
        tollanUniverseItems.claim(
            tokenId,
            PHYSICAL_ID_1,
            amount1,
            deadline1,
            signature1
        );

        // Verify first claim
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_1), 50);
        assertEq(tollanUniverseItems.balanceOf(user, tokenId), 50);

        // Second claim: 30 more tokens
        uint256 amount2 = 30;
        uint256 deadline2 = block.timestamp + 2 hours;
        uint256 nonce2 = tollanUniverseItems.nonces(user);
        bytes memory signature2 = _signClaim(
            user,
            tokenId,
            PHYSICAL_ID_1,
            amount2,
            nonce2,
            deadline2
        );

        vm.prank(user);
        tollanUniverseItems.claim(
            tokenId,
            PHYSICAL_ID_1,
            amount2,
            deadline2,
            signature2
        );

        // Verify accumulation
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_1), 80); // 50 + 30
        assertEq(tollanUniverseItems.balanceOf(user, tokenId), 80);
    }

    function test_Claim_SeparatesClaimedByPhysicalId() public {
        // Define two items
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_2,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        vm.stopPrank();

        // Claim 100 of item 1
        uint256 amount1 = 100;
        uint256 deadline1 = block.timestamp + 1 hours;
        uint256 nonce1 = tollanUniverseItems.nonces(user);
        bytes memory signature1 = _signClaim(
            user,
            1,
            PHYSICAL_ID_1,
            amount1,
            nonce1,
            deadline1
        );

        vm.prank(user);
        tollanUniverseItems.claim(1, PHYSICAL_ID_1, amount1, deadline1, signature1);

        // Claim 50 of item 2
        uint256 amount2 = 50;
        uint256 deadline2 = block.timestamp + 2 hours;
        uint256 nonce2 = tollanUniverseItems.nonces(user);
        bytes memory signature2 = _signClaim(
            user,
            2,
            PHYSICAL_ID_2,
            amount2,
            nonce2,
            deadline2
        );

        vm.prank(user);
        tollanUniverseItems.claim(2, PHYSICAL_ID_2, amount2, deadline2, signature2);

        // Verify separate tracking
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_1), 100);
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_2), 50);
        assertEq(tollanUniverseItems.balanceOf(user, 1), 100);
        assertEq(tollanUniverseItems.balanceOf(user, 2), 50);
    }

    function test_Claim_RevertsIfZeroAmount() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        bytes memory signature = "";

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IErrors.ZeroUint.selector, 0));
        tollanUniverseItems.claim(
            1,
            PHYSICAL_ID_1,
            0,
            block.timestamp + 1 hours,
            signature
        );
    }

    function test_Claim_RevertsIfEmptyPhysicalId() public {
        bytes memory signature = "";

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.EmptyString.selector, "")
        );
        tollanUniverseItems.claim(
            1,
            "",
            10,
            block.timestamp + 1 hours,
            signature
        );
    }

    function test_Claim_RevertsIfExpired() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = tollanUniverseItems.nonces(user);
        bytes memory signature = _signClaim(
            user,
            1,
            PHYSICAL_ID_1,
            10,
            nonce,
            deadline
        );

        // Warp past the deadline
        vm.warp(deadline + 1);

        vm.prank(user);
        vm.expectRevert(IErrors.SignatureExpired.selector);
        tollanUniverseItems.claim(1, PHYSICAL_ID_1, 10, deadline, signature);
    }

    function test_Claim_RevertsIfItemNotDefined() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = _signClaim(
            user,
            999,
            PHYSICAL_ID_1,
            10,
            0,
            deadline
        );

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ItemNotDefined.selector, "")
        );
        tollanUniverseItems.claim(999, PHYSICAL_ID_1, 10, deadline, signature);
    }

    function test_Claim_RevertsIfInvalidSigner() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        uint256 deadline = block.timestamp + 1 hours;
        // Sign with wrong private key
        bytes memory signature = _signClaimWithKey(
            user,
            1,
            PHYSICAL_ID_1,
            10,
            0,
            deadline,
            0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef
        );

        vm.prank(user);
        vm.expectRevert(IErrors.InvalidSigner.selector);
        tollanUniverseItems.claim(1, PHYSICAL_ID_1, 10, deadline, signature);
    }

    function test_Claim_RevertsIfPaused() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(admin);
        tollanUniverseItems.pause();

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = _signClaim(
            user,
            1,
            PHYSICAL_ID_1,
            10,
            0,
            deadline
        );

        vm.prank(user);
        vm.expectRevert();
        tollanUniverseItems.claim(1, PHYSICAL_ID_1, 10, deadline, signature);
    }

    function test_Claim_WithZeroDeadline_DoesNotExpire() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        uint256 tokenId = 1;
        uint256 amount = 10;
        uint256 deadline = 0; // No expiry
        uint256 nonce = tollanUniverseItems.nonces(user);

        bytes memory signature = _signClaim(
            user,
            tokenId,
            PHYSICAL_ID_1,
            amount,
            nonce,
            deadline
        );

        // Warp far into the future
        vm.warp(block.timestamp + 365 days);

        vm.prank(user);
        tollanUniverseItems.claim(
            tokenId,
            PHYSICAL_ID_1,
            amount,
            deadline,
            signature
        );

        assertEq(tollanUniverseItems.balanceOf(user, tokenId), amount);
    }

    // =============================================================
    // CLAIM BATCH TESTS
    // =============================================================

    function test_ClaimBatch_Success() public {
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_2,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        vm.stopPrank();

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 20;

        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = tollanUniverseItems.nonces(user);

        bytes memory signature = _signClaimBatch(
            user,
            tokenIds,
            physicalIds,
            amounts,
            nonce,
            deadline
        );

        vm.expectEmit(true, false, false, true);
        emit ItemsClaimed(user, tokenIds, amounts);

        vm.prank(user);
        tollanUniverseItems.claimBatch(
            tokenIds,
            physicalIds,
            amounts,
            deadline,
            signature
        );

        assertEq(tollanUniverseItems.balanceOf(user, 1), 10);
        assertEq(tollanUniverseItems.balanceOf(user, 2), 20);
        assertEq(tollanUniverseItems.nonces(user), nonce + 1);
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_1), 10);
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_2), 20);
    }

    function test_ClaimBatch_AccumulatesWithSingleClaim() public {
        // Define items
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_2,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        vm.stopPrank();

        // Batch claim
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 20;

        uint256 deadline1 = block.timestamp + 1 hours;
        uint256 nonce1 = tollanUniverseItems.nonces(user);
        bytes memory signature1 = _signClaimBatch(
            user,
            tokenIds,
            physicalIds,
            amounts,
            nonce1,
            deadline1
        );

        vm.prank(user);
        tollanUniverseItems.claimBatch(
            tokenIds,
            physicalIds,
            amounts,
            deadline1,
            signature1
        );

        // Verify batch claim tracking
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_1), 10);
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_2), 20);

        // Single claim 5 more of PHYSICAL_ID_1
        uint256 amount2 = 5;
        uint256 deadline2 = block.timestamp + 2 hours;
        uint256 nonce2 = tollanUniverseItems.nonces(user);
        bytes memory signature2 = _signClaim(
            user,
            1,
            PHYSICAL_ID_1,
            amount2,
            nonce2,
            deadline2
        );

        vm.prank(user);
        tollanUniverseItems.claim(1, PHYSICAL_ID_1, amount2, deadline2, signature2);

        // Verify accumulation
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_1), 15); // 10 + 5
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_2), 20); // unchanged
    }

    function test_ClaimBatch_RevertsIfLengthMismatch() public {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        string[] memory physicalIds = new string[](1);
        physicalIds[0] = PHYSICAL_ID_1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 20;

        bytes memory signature = "";

        vm.prank(user);
        vm.expectRevert(IErrors.LengthMismatch.selector);
        tollanUniverseItems.claimBatch(
            tokenIds,
            physicalIds,
            amounts,
            block.timestamp + 1 hours,
            signature
        );
    }

    function test_ClaimBatch_RevertsIfExpired() public {
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_2,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        vm.stopPrank();

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 20;

        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = tollanUniverseItems.nonces(user);
        bytes memory signature = _signClaimBatch(
            user,
            tokenIds,
            physicalIds,
            amounts,
            nonce,
            deadline
        );

        // Warp past the deadline
        vm.warp(deadline + 1);

        vm.prank(user);
        vm.expectRevert(IErrors.SignatureExpired.selector);
        tollanUniverseItems.claimBatch(
            tokenIds,
            physicalIds,
            amounts,
            deadline,
            signature
        );
    }

    function test_ClaimBatch_RevertsIfItemNotDefined() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 999; // Not defined

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 20;

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = _signClaimBatch(
            user,
            tokenIds,
            physicalIds,
            amounts,
            0,
            deadline
        );

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ItemNotDefined.selector, "")
        );
        tollanUniverseItems.claimBatch(
            tokenIds,
            physicalIds,
            amounts,
            deadline,
            signature
        );
    }

    function test_ClaimBatch_RevertsIfInvalidSigner() public {
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_2,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        vm.stopPrank();

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 20;

        uint256 deadline = block.timestamp + 1 hours;
        // Sign with wrong key
        bytes memory signature = _signClaimBatchWithKey(
            user,
            tokenIds,
            physicalIds,
            amounts,
            0,
            deadline,
            0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef
        );

        vm.prank(user);
        vm.expectRevert(IErrors.InvalidSigner.selector);
        tollanUniverseItems.claimBatch(
            tokenIds,
            physicalIds,
            amounts,
            deadline,
            signature
        );
    }

    // =============================================================
    // VIEW FUNCTIONS TESTS
    // =============================================================

    function test_GetNftIdByPhysicalId_Success() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        assertEq(tollanUniverseItems.getNftIdByPhysicalId(PHYSICAL_ID_1), 1);
    }

    function test_GetNftIdByPhysicalId_RevertsIfNotDefined() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IErrors.ItemNotDefined.selector,
                PHYSICAL_ID_1
            )
        );
        tollanUniverseItems.getNftIdByPhysicalId(PHYSICAL_ID_1);
    }

    function test_GetPhysicalIdByTokenId_Success() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        assertEq(tollanUniverseItems.getPhysicalIdByTokenId(1), PHYSICAL_ID_1);
    }

    function test_GetPhysicalIdByTokenId_RevertsIfNotDefined() public {
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ItemNotDefined.selector, "")
        );
        tollanUniverseItems.getPhysicalIdByTokenId(999);
    }

    function test_GetNextTokenId() public {
        assertEq(tollanUniverseItems.getNextTokenId(), 1);

        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        assertEq(tollanUniverseItems.getNextTokenId(), 2);
    }

    function test_IsPhysicalIdDefined() public {
        assertFalse(tollanUniverseItems.isPhysicalIdDefined(PHYSICAL_ID_1));

        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        assertTrue(tollanUniverseItems.isPhysicalIdDefined(PHYSICAL_ID_1));
    }

    function test_BalanceOfPhysicalId() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        assertEq(
            tollanUniverseItems.balanceOfPhysicalId(user, PHYSICAL_ID_1),
            0
        );

        vm.prank(minter);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 10);

        assertEq(
            tollanUniverseItems.balanceOfPhysicalId(user, PHYSICAL_ID_1),
            10
        );
    }

    function test_BalanceOfPhysicalId_RevertsIfNotDefined() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IErrors.ItemNotDefined.selector,
                PHYSICAL_ID_1
            )
        );
        tollanUniverseItems.balanceOfPhysicalId(user, PHYSICAL_ID_1);
    }

    function test_Uri_Success() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        assertEq(tollanUniverseItems.uri(1), METADATA_URI_1);
    }

    function test_Uri_RevertsIfNotDefined() public {
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ItemNotDefined.selector, "")
        );
        tollanUniverseItems.uri(999);
    }

    function test_TotalSupply() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        assertEq(tollanUniverseItems.totalSupply(1), 0);

        vm.prank(minter);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 100);

        assertEq(tollanUniverseItems.totalSupply(1), 100);
    }

    function test_SupportsInterface() public view {
        // ERC1155
        assertTrue(
            tollanUniverseItems.supportsInterface(type(IERC1155).interfaceId)
        );
        // ERC165
        assertTrue(tollanUniverseItems.supportsInterface(0x01ffc9a7));
        // AccessControl
        assertTrue(
            tollanUniverseItems.supportsInterface(
                type(IAccessControl).interfaceId
            )
        );
    }

    // =============================================================
    // ERC1155 INHERITED FUNCTIONS TESTS
    // =============================================================

    function test_BalanceOf() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(minter);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 50);

        assertEq(tollanUniverseItems.balanceOf(user, 1), 50);
    }

    function test_SafeTransferFrom() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(minter);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 50);

        vm.prank(user);
        tollanUniverseItems.safeTransferFrom(user, user2, 1, 20, "");

        assertEq(tollanUniverseItems.balanceOf(user, 1), 30);
        assertEq(tollanUniverseItems.balanceOf(user2, 1), 20);
    }

    function test_SafeBatchTransferFrom() public {
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_2,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        vm.stopPrank();

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 50;
        amounts[1] = 100;

        vm.prank(minter);
        tollanUniverseItems.mintBatchByPhysicalId(user, physicalIds, amounts);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;

        uint256[] memory transferAmounts = new uint256[](2);
        transferAmounts[0] = 20;
        transferAmounts[1] = 30;

        vm.prank(user);
        tollanUniverseItems.safeBatchTransferFrom(
            user,
            user2,
            ids,
            transferAmounts,
            ""
        );

        assertEq(tollanUniverseItems.balanceOf(user, 1), 30);
        assertEq(tollanUniverseItems.balanceOf(user, 2), 70);
        assertEq(tollanUniverseItems.balanceOf(user2, 1), 20);
        assertEq(tollanUniverseItems.balanceOf(user2, 2), 30);
    }

    function test_SetApprovalForAll() public {
        vm.prank(user);
        tollanUniverseItems.setApprovalForAll(user2, true);

        assertTrue(tollanUniverseItems.isApprovedForAll(user, user2));
    }

    // =============================================================
    // ERC1155 BURNABLE TESTS
    // =============================================================

    function test_Burn_ByOwner() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(minter);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 50);

        vm.prank(user);
        tollanUniverseItems.burn(user, 1, 20);

        assertEq(tollanUniverseItems.balanceOf(user, 1), 30);
    }

    function test_BurnBatch_ByOwner() public {
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_2,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        vm.stopPrank();

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 50;
        amounts[1] = 100;

        vm.prank(minter);
        tollanUniverseItems.mintBatchByPhysicalId(user, physicalIds, amounts);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;

        uint256[] memory burnAmounts = new uint256[](2);
        burnAmounts[0] = 10;
        burnAmounts[1] = 20;

        vm.prank(user);
        tollanUniverseItems.burnBatch(user, ids, burnAmounts);

        assertEq(tollanUniverseItems.balanceOf(user, 1), 40);
        assertEq(tollanUniverseItems.balanceOf(user, 2), 80);
    }

    // =============================================================
    // HELPER FUNCTIONS
    // =============================================================

    function _signClaim(
        address to,
        uint256 tokenId,
        string memory physicalId,
        uint256 amount,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes memory) {
        return
            _signClaimWithKey(
                to,
                tokenId,
                physicalId,
                amount,
                nonce,
                deadline,
                signerPrivateKey
            );
    }

    function _signClaimWithKey(
        address to,
        uint256 tokenId,
        string memory physicalId,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        bytes32 structHash = keccak256(
            abi.encode(
                CLAIM_TYPEHASH,
                to,
                tokenId,
                physicalId,
                amount,
                nonce,
                deadline
            )
        );

        bytes32 digest = _hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _signClaimBatch(
        address to,
        uint256[] memory tokenIds,
        string[] memory physicalIds,
        uint256[] memory amounts,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes memory) {
        return
            _signClaimBatchWithKey(
                to,
                tokenIds,
                physicalIds,
                amounts,
                nonce,
                deadline,
                signerPrivateKey
            );
    }

    function _signClaimBatchWithKey(
        address to,
        uint256[] memory tokenIds,
        string[] memory physicalIds,
        uint256[] memory amounts,
        uint256 nonce,
        uint256 deadline,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        bytes32 tokenIdsHash = keccak256(abi.encode(tokenIds));
        bytes32 amountsHash = keccak256(abi.encode(amounts));

        bytes32[] memory pHashes = new bytes32[](physicalIds.length);
        for (uint256 i = 0; i < physicalIds.length; i++) {
            pHashes[i] = keccak256(bytes(physicalIds[i]));
        }
        bytes32 physicalIdsHash = keccak256(abi.encode(pHashes));

        bytes32 structHash = keccak256(
            abi.encode(
                CLAIM_BATCH_TYPEHASH,
                to,
                tokenIdsHash,
                physicalIdsHash,
                amountsHash,
                nonce,
                deadline
            )
        );

        bytes32 digest = _hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _hashTypedDataV4(
        bytes32 structHash
    ) internal view returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name712)),
                keccak256(bytes(version712)),
                block.chainid,
                address(tollanUniverseItems)
            )
        );
        return MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
    }
}
