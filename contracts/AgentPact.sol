// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title AgentPact
/// @notice Public on-chain commitments for Agent ID holders.
/// @dev Anyone holding a Binance Agent ID (non-transferable ERC-721) can
///      create a pact, join pacts, and self-report the outcome after the
///      deadline. No money, no tokens, no fees — only gas.
///      There is NO owner/admin, NO payable/receive/fallback, NO token,
///      NO fee, NO withdraw, NO pause, NO upgrade. The deployer has no
///      special rights after deployment.
interface IAgentId {
    function balanceOf(address account) external view returns (uint256);
}

contract AgentPact {
    /// @notice Binance Agent ID (SPACE ID) contract on BNB Chain.
    address public constant AGENT_ID = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    /// @notice Maximum pact duration: 30 days.
    uint256 public constant MAX_DURATION = 30 days;

    /// @notice Maximum title length in bytes.
    uint256 public constant MAX_TITLE_LENGTH = 140;

    struct Pact {
        uint256 id;
        address creator;
        string title;
        uint256 deadline;
        uint256 createdAt;
    }

    struct Resolution {
        bool resolved;
        bool success;
    }

    uint256 private _pactCount;

    mapping(uint256 => Pact) private _pacts;
    mapping(uint256 => address[]) private _participants;
    mapping(uint256 => mapping(address => bool)) private _isParticipant;
    mapping(uint256 => mapping(address => Resolution)) private _resolutions;
    mapping(uint256 => uint256) private _successCount;
    mapping(uint256 => uint256) private _failCount;

    event PactCreated(uint256 indexed id, address indexed creator, string title, uint256 deadline);
    event PactJoined(uint256 indexed id, address indexed participant);
    event PactResolved(uint256 indexed id, address indexed participant, bool success);

    error NotAgentIdHolder();
    error InvalidTitle();
    error InvalidDeadline();
    error PactNotFound();
    error AlreadyJoined();
    error NotParticipant();
    error AlreadyResolved();
    error DeadlineNotPassed();
    error PactClosed();

    modifier onlyAgentId() {
        if (IAgentId(AGENT_ID).balanceOf(msg.sender) == 0) revert NotAgentIdHolder();
        _;
    }

    modifier pactExists(uint256 pactId) {
        if (pactId >= _pactCount) revert PactNotFound();
        _;
    }

    /// @notice Create a new pact. The creator automatically becomes a participant.
    /// @param title What the creator commits to do (1-140 characters).
    /// @param deadline Unix timestamp in the future, at most 30 days from now.
    /// @return id The new pact's id.
    function createPact(string calldata title, uint256 deadline) external onlyAgentId returns (uint256 id) {
        bytes memory titleBytes = bytes(title);
        if (titleBytes.length == 0 || titleBytes.length > MAX_TITLE_LENGTH) revert InvalidTitle();
        if (deadline <= block.timestamp || deadline > block.timestamp + MAX_DURATION) revert InvalidDeadline();

        id = _pactCount;
        _pactCount++;

        _pacts[id] = Pact({id: id, creator: msg.sender, title: title, deadline: deadline, createdAt: block.timestamp});

        _participants[id].push(msg.sender);
        _isParticipant[id][msg.sender] = true;

        emit PactCreated(id, msg.sender, title, deadline);
    }

    /// @notice Join an existing pact before its deadline.
    function joinPact(uint256 pactId) external onlyAgentId pactExists(pactId) {
        if (block.timestamp >= _pacts[pactId].deadline) revert PactClosed();
        if (_isParticipant[pactId][msg.sender]) revert AlreadyJoined();

        _participants[pactId].push(msg.sender);
        _isParticipant[pactId][msg.sender] = true;

        emit PactJoined(pactId, msg.sender);
    }

    /// @notice Self-report the outcome of a pact after its deadline.
    /// @dev One resolution per participant; it cannot be changed afterwards.
    function resolvePact(uint256 pactId, bool success) external onlyAgentId pactExists(pactId) {
        if (!_isParticipant[pactId][msg.sender]) revert NotParticipant();
        if (block.timestamp < _pacts[pactId].deadline) revert DeadlineNotPassed();
        if (_resolutions[pactId][msg.sender].resolved) revert AlreadyResolved();

        _resolutions[pactId][msg.sender] = Resolution({resolved: true, success: success});
        if (success) {
            _successCount[pactId]++;
        } else {
            _failCount[pactId]++;
        }

        emit PactResolved(pactId, msg.sender, success);
    }

    /// @notice Total number of pacts ever created.
    function totalPacts() external view returns (uint256) {
        return _pactCount;
    }

    /// @notice Full pact details including live participant/result counts.
    function getPact(uint256 pactId)
        external
        view
        pactExists(pactId)
        returns (
            uint256 id,
            address creator,
            string memory title,
            uint256 deadline,
            uint256 createdAt,
            uint256 participantCount,
            uint256 successCount,
            uint256 failCount
        )
    {
        Pact storage p = _pacts[pactId];
        id = p.id;
        creator = p.creator;
        title = p.title;
        deadline = p.deadline;
        createdAt = p.createdAt;
        participantCount = _participants[pactId].length;
        successCount = _successCount[pactId];
        failCount = _failCount[pactId];
    }

    /// @notice All participant addresses of a pact, in join order.
    function getParticipants(uint256 pactId) external view pactExists(pactId) returns (address[] memory) {
        return _participants[pactId];
    }

    /// @notice Whether an address joined a pact.
    function isParticipant(uint256 pactId, address account) external view returns (bool) {
        if (pactId >= _pactCount) return false;
        return _isParticipant[pactId][account];
    }

    /// @notice A participant's resolution: (resolved, success).
    function getResolution(uint256 pactId, address account) external view returns (bool resolved, bool success) {
        if (pactId >= _pactCount) return (false, false);
        Resolution storage r = _resolutions[pactId][account];
        return (r.resolved, r.success);
    }
}
