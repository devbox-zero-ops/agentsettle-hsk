// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @title AgentSettlementVault
 * @notice Programmable AI Agent Payment Mandates, A2A Settlement & Verifiable Execution Memory
 *         built for HashKey Chain Testnet (Chain ID 133) — HSK Chain Horizon Hackathon.
 */
contract AgentSettlementVault {
    struct Mandate {
        address owner;
        address agent;
        address token;           // address(0) = native HSK, otherwise ERC-20 (e.g., USDT/USDC)
        uint256 maxPerTx;
        uint256 dailyLimit;
        uint256 spentToday;
        uint64 dayWindowStart;
        uint64 expiresAt;
        bool active;
    }

    struct SettlementRecord {
        uint256 id;
        uint256 mandateId;
        address agent;
        address recipient;
        address token;
        uint256 amount;
        bytes32 taskMemoryHash;  // keccak256 of verifiable agent reasoning / receipt log
        string memo;
        uint64 settledAt;
    }

    uint256 public nextMandateId = 1;
    uint256 public nextSettlementId = 1;

    mapping(uint256 => Mandate) public mandates;
    mapping(uint256 => uint256) public mandateBalances;
    mapping(uint256 => SettlementRecord) public settlements;

    uint256 private _locked = 1;
    modifier nonReentrant() {
        require(_locked == 1, "REENTRANCY");
        _locked = 2;
        _;
        _locked = 1;
    }

    event MandateCreated(
        uint256 indexed mandateId,
        address indexed owner,
        address indexed agent,
        address token,
        uint256 maxPerTx,
        uint256 dailyLimit,
        uint64 expiresAt
    );
    event MandateFunded(uint256 indexed mandateId, uint256 amount);
    event MandateRevoked(uint256 indexed mandateId, uint256 refundedAmount);
    event AgentSettled(
        uint256 indexed settlementId,
        uint256 indexed mandateId,
        address indexed recipient,
        uint256 amount,
        bytes32 taskMemoryHash,
        string memo
    );

    function createMandate(
        address agent,
        address token,
        uint256 maxPerTx,
        uint256 dailyLimit,
        uint64 expiresAt
    ) external payable returns (uint256 mandateId) {
        require(agent != address(0), "INVALID_AGENT");
        require(maxPerTx > 0 && dailyLimit >= maxPerTx, "INVALID_LIMITS");
        require(expiresAt > block.timestamp, "EXPIRED");

        mandateId = nextMandateId++;
        mandates[mandateId] = Mandate({
            owner: msg.sender,
            agent: agent,
            token: token,
            maxPerTx: maxPerTx,
            dailyLimit: dailyLimit,
            spentToday: 0,
            dayWindowStart: uint64(block.timestamp),
            expiresAt: expiresAt,
            active: true
        });

        emit MandateCreated(mandateId, msg.sender, agent, token, maxPerTx, dailyLimit, expiresAt);

        if (msg.value > 0) {
            require(token == address(0), "ETH_ONLY_FOR_NATIVE");
            mandateBalances[mandateId] += msg.value;
            emit MandateFunded(mandateId, msg.value);
        }
    }

    function fundMandateERC20(uint256 mandateId, uint256 amount) external nonReentrant {
        Mandate storage m = mandates[mandateId];
        require(m.active, "INACTIVE");
        require(m.token != address(0), "NOT_ERC20");
        require(amount > 0, "ZERO_AMOUNT");
        require(IERC20(m.token).transferFrom(msg.sender, address(this), amount), "TRANSFER_FAILED");
        mandateBalances[mandateId] += amount;
        emit MandateFunded(mandateId, amount);
    }

    /**
     * @notice Autonomous A2A settlement executed by the authorized AI Agent within mandate guardrails.
     */
    function executeAgentSettlement(
        uint256 mandateId,
        address recipient,
        uint256 amount,
        bytes32 taskMemoryHash,
        string calldata memo
    ) external nonReentrant returns (uint256 settlementId) {
        Mandate storage m = mandates[mandateId];
        require(m.active, "MANDATE_INACTIVE");
        require(msg.sender == m.agent, "ONLY_AUTHORIZED_AGENT");
        require(block.timestamp <= m.expiresAt, "MANDATE_EXPIRED");
        require(recipient != address(0), "INVALID_RECIPIENT");
        require(amount > 0 && amount <= m.maxPerTx, "EXCEEDS_MAX_PER_TX");
        require(mandateBalances[mandateId] >= amount, "INSUFFICIENT_VAULT_BALANCE");

        if (block.timestamp >= m.dayWindowStart + 1 days) {
            m.dayWindowStart = uint64(block.timestamp);
            m.spentToday = 0;
        }
        require(m.spentToday + amount <= m.dailyLimit, "EXCEEDS_DAILY_LIMIT");

        m.spentToday += amount;
        mandateBalances[mandateId] -= amount;

        if (m.token == address(0)) {
            (bool ok, ) = payable(recipient).call{value: amount}("");
            require(ok, "NATIVE_TRANSFER_FAILED");
        } else {
            require(IERC20(m.token).transfer(recipient, amount), "ERC20_TRANSFER_FAILED");
        }

        settlementId = nextSettlementId++;
        settlements[settlementId] = SettlementRecord({
            id: settlementId,
            mandateId: mandateId,
            agent: msg.sender,
            recipient: recipient,
            token: m.token,
            amount: amount,
            taskMemoryHash: taskMemoryHash,
            memo: memo,
            settledAt: uint64(block.timestamp)
        });

        emit AgentSettled(settlementId, mandateId, recipient, amount, taskMemoryHash, memo);
    }

    /**
     * @notice Emergency kill-switch: owner revokes mandate and withdraws all remaining funds.
     */
    function revokeMandate(uint256 mandateId) external nonReentrant {
        Mandate storage m = mandates[mandateId];
        require(m.active, "ALREADY_INACTIVE");
        require(msg.sender == m.owner, "ONLY_OWNER");

        m.active = false;
        uint256 bal = mandateBalances[mandateId];
        mandateBalances[mandateId] = 0;

        if (bal > 0) {
            if (m.token == address(0)) {
                (bool ok, ) = payable(m.owner).call{value: bal}("");
                require(ok, "REFUND_FAILED");
            } else {
                require(IERC20(m.token).transfer(m.owner, bal), "ERC20_REFUND_FAILED");
            }
        }
        emit MandateRevoked(mandateId, bal);
    }
}
