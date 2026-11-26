// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AgentPact} from "../contracts/AgentPact.sol";

/// @notice Minimal stand-in for the Agent ID ERC-721 (balanceOf only).
contract MockAgentId {
    mapping(address => uint256) public balances;

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function setBalance(address account, uint256 amount) external {
        balances[account] = amount;
    }
}

contract AgentPactTest is Test {
    address internal constant AGENT_ID = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    AgentPact internal pact;
    MockAgentId internal mock;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA901);
    address internal mallory = address(0xAA11CE);

    uint256 internal constant ONE_DAY = 1 days;

    function setUp() public {
        mock = new MockAgentId();
        // Put the mock's code at the real Agent ID address so the
        // hardcoded constant in AgentPact resolves to it on this chain.
        vm.etch(AGENT_ID, address(mock).code);

        pact = new AgentPact();

        MockAgentId(AGENT_ID).setBalance(alice, 1);
        MockAgentId(AGENT_ID).setBalance(bob, 1);
        MockAgentId(AGENT_ID).setBalance(carol, 1);
        // mallory holds no Agent ID.
    }

    function _createPact(address creator, string memory title, uint256 deadline) internal returns (uint256) {
        vm.prank(creator);
        return pact.createPact(title, deadline);
    }

    // --- Access control: non-holders ---

    function test_NonHolderCannotCreate() public {
        vm.prank(mallory);
        vm.expectRevert(AgentPact.NotAgentIdHolder.selector);
        pact.createPact("Ship it", block.timestamp + ONE_DAY);
    }

    function test_NonHolderCannotJoin() public {
        uint256 id = _createPact(alice, "Ship it", block.timestamp + ONE_DAY);
        vm.prank(mallory);
        vm.expectRevert(AgentPact.NotAgentIdHolder.selector);
        pact.joinPact(id);
    }

    function test_NonHolderCannotResolve() public {
        uint256 id = _createPact(alice, "Ship it", block.timestamp + ONE_DAY);
        vm.warp(block.timestamp + ONE_DAY + 1);
        vm.prank(mallory);
        vm.expectRevert(AgentPact.NotAgentIdHolder.selector);
        pact.resolvePact(id, true);
    }

    // --- Create validation ---

    function test_CreatePastDeadlineReverts() public {
        vm.prank(alice);
        vm.expectRevert(AgentPact.InvalidDeadline.selector);
        pact.createPact("Too late", block.timestamp - 1);
    }

    function test_CreateNowDeadlineReverts() public {
        vm.prank(alice);
        vm.expectRevert(AgentPact.InvalidDeadline.selector);
        pact.createPact("Right now", block.timestamp);
    }

    function test_CreateDeadlineBeyond30DaysReverts() public {
        vm.prank(alice);
        vm.expectRevert(AgentPact.InvalidDeadline.selector);
        pact.createPact("Too far", block.timestamp + 30 days + 1);
    }

    function test_CreateEmptyTitleReverts() public {
        vm.prank(alice);
        vm.expectRevert(AgentPact.InvalidTitle.selector);
        pact.createPact("", block.timestamp + ONE_DAY);
    }

    function test_CreateTitleTooLongReverts() public {
        // 141 bytes.
        string memory longTitle = string(
            abi.encodePacked(
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
            )
        );
        assertEq(bytes(longTitle).length, 141);
        vm.prank(alice);
        vm.expectRevert(AgentPact.InvalidTitle.selector);
        pact.createPact(longTitle, block.timestamp + ONE_DAY);
    }

    function test_CreateDeadlineExactly30DaysOk() public {
        vm.prank(alice);
        uint256 id = pact.createPact("A month out", block.timestamp + 30 days);
        assertEq(id, 0);
    }

    function test_CreateEmitsEventAndCreatorIsParticipant() public {
        uint256 deadline = block.timestamp + 7 days;
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit AgentPact.PactCreated(0, alice, "Ship it", deadline);
        uint256 id = pact.createPact("Ship it", deadline);

        assertEq(id, 0);
        assertEq(pact.totalPacts(), 1);
        assertTrue(pact.isParticipant(id, alice));
        (,,,,, uint256 count,,) = pact.getPact(id);
        assertEq(count, 1);
    }

    // --- Join rules ---

    function test_JoinTwiceReverts() public {
        uint256 id = _createPact(alice, "Ship it", block.timestamp + ONE_DAY);
        vm.prank(bob);
        pact.joinPact(id);
        vm.prank(bob);
        vm.expectRevert(AgentPact.AlreadyJoined.selector);
        pact.joinPact(id);
    }

    function test_JoinNonexistentReverts() public {
        vm.prank(bob);
        vm.expectRevert(AgentPact.PactNotFound.selector);
        pact.joinPact(99);
    }

    function test_JoinAfterDeadlineReverts() public {
        uint256 deadline = block.timestamp + ONE_DAY;
        uint256 id = _createPact(alice, "Ship it", deadline);
        vm.warp(deadline);
        vm.prank(bob);
        vm.expectRevert(AgentPact.PactClosed.selector);
        pact.joinPact(id);
    }

    function test_JoinEmitsEvent() public {
        uint256 id = _createPact(alice, "Ship it", block.timestamp + ONE_DAY);
        vm.prank(bob);
        vm.expectEmit(true, true, false, true);
        emit AgentPact.PactJoined(id, bob);
        pact.joinPact(id);
        assertTrue(pact.isParticipant(id, bob));
    }

    // --- Resolve rules ---

    function test_ResolveBeforeDeadlineReverts() public {
        uint256 id = _createPact(alice, "Ship it", block.timestamp + ONE_DAY);
        vm.prank(alice);
        vm.expectRevert(AgentPact.DeadlineNotPassed.selector);
        pact.resolvePact(id, true);
    }

    function test_ResolveTwiceReverts() public {
        uint256 id = _createPact(alice, "Ship it", block.timestamp + ONE_DAY);
        vm.warp(block.timestamp + ONE_DAY + 1);
        vm.prank(alice);
        pact.resolvePact(id, true);
        vm.prank(alice);
        vm.expectRevert(AgentPact.AlreadyResolved.selector);
        pact.resolvePact(id, false);
    }

    function test_ResolveByNonParticipantReverts() public {
        uint256 id = _createPact(alice, "Ship it", block.timestamp + ONE_DAY);
        vm.warp(block.timestamp + ONE_DAY + 1);
        vm.prank(bob); // holder, but never joined
        vm.expectRevert(AgentPact.NotParticipant.selector);
        pact.resolvePact(id, true);
    }

    function test_ResolveNonexistentReverts() public {
        vm.warp(block.timestamp + ONE_DAY + 1);
        vm.prank(alice);
        vm.expectRevert(AgentPact.PactNotFound.selector);
        pact.resolvePact(42, true);
    }

    // --- Happy path ---

    function test_HappyPathCountsAreCorrect() public {
        uint256 deadline = block.timestamp + 7 days;
        uint256 id = _createPact(alice, "Launch the dApp", deadline);

        vm.prank(bob);
        pact.joinPact(id);
        vm.prank(carol);
        pact.joinPact(id);

        vm.warp(deadline + 1);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit AgentPact.PactResolved(id, alice, true);
        pact.resolvePact(id, true);

        vm.prank(bob);
        pact.resolvePact(id, true);

        vm.prank(carol);
        pact.resolvePact(id, false);

        // --- getPact counts (scoped so locals drop off the stack) ---
        {
            (
                uint256 pid,
                address creator,
                string memory title,
                uint256 dl,
                uint256 createdAt,
                uint256 participantCount,
                uint256 successCount,
                uint256 failCount
            ) = pact.getPact(id);

            assertEq(pid, id);
            assertEq(creator, alice);
            assertEq(title, "Launch the dApp");
            assertEq(dl, deadline);
            assertGt(createdAt, 0);
            assertEq(participantCount, 3);
            assertEq(successCount, 2);
            assertEq(failCount, 1);
        }

        // --- participants in join order ---
        {
            address[] memory participants = pact.getParticipants(id);
            assertEq(participants.length, 3);
            assertEq(participants[0], alice);
            assertEq(participants[1], bob);
            assertEq(participants[2], carol);
        }

        // --- per-participant resolutions ---
        {
            (bool resolvedA, bool successA) = pact.getResolution(id, alice);
            assertTrue(resolvedA);
            assertTrue(successA);
        }
        {
            (bool resolvedC, bool successC) = pact.getResolution(id, carol);
            assertTrue(resolvedC);
            assertFalse(successC);
        }
        {
            (bool resolvedM,) = pact.getResolution(id, mallory);
            assertFalse(resolvedM);
        }
    }

    // --- Views on missing pacts ---

    function test_ViewsOnMissingPact() public {
        vm.expectRevert(AgentPact.PactNotFound.selector);
        pact.getPact(7);

        vm.expectRevert(AgentPact.PactNotFound.selector);
        pact.getParticipants(7);

        assertFalse(pact.isParticipant(7, alice));
        (bool resolved, bool success) = pact.getResolution(7, alice);
        assertFalse(resolved);
        assertFalse(success);
    }

    function test_TotalPactsIncrements() public {
        assertEq(pact.totalPacts(), 0);
        _createPact(alice, "One", block.timestamp + ONE_DAY);
        _createPact(bob, "Two", block.timestamp + 2 days);
        assertEq(pact.totalPacts(), 2);
    }
}
