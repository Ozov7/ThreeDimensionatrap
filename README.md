# ThreeDimensionatrap

# drosera-security-traps
Production ready trap 

Here's your 3-Vector Drosera Security Traps documentation in the requested format:

---

# Drosera Security Traps: MEV + Governance + Oracle Protection

## Overview
This suite of three production-ready traps monitors critical DeFi attack vectors and triggers alerts when sophisticated manipulation patterns are detected.  
It demonstrates Drosera's capability to autonomously secure decentralized systems across financial, governance, and oracle domains.

---

## What It Does

### MEV Sandwich Detector
* Monitors **Uniswap V3 swap events** for frontrun/victim/backrun transaction patterns.
* Triggers when price impact exceeds 0.5% AND estimated profit exceeds 0.1 ETH.
* Implements **multi-block pattern analysis** to confirm sandwich attacks.
* Uses **hardcoded pool addresses** for Drosera compatibility (zero-argument constructor).

### Governance Attack Monitor
* Tracks **COMP token delegation and voting events** in Compound Governor.
* Triggers when voting power spikes >10% during active proposals.
* Detects **flash loan voting patterns** and delegation manipulation.
* Monitors **voting windows** for suspicious activity.

### Oracle Manipulation Detector
* Cross-verifies **Chainlink vs Uniswap price feeds** for deviations.
* Triggers when price deviation exceeds 5% between independent sources.
* Correlates **volume spikes** with price movements.
* Identifies **manipulation timing patterns** (attack → profit → oracle update).

---

## Key Files

### Trap Contracts
* `src/traps/MEVSandwichDetector.sol` - Core MEV detection with Uniswap V3 event analysis.
* `src/traps/GovernanceAttackMonitor.sol` - Governance attack monitoring with Compound integration.
* `src/traps/OracleManipulationDetector.sol` - Oracle manipulation detection across multiple sources.

### Response System
* `src/responders/SecurityResponder.sol` - Unified response handler for all three trap types.
* `src/interfaces/ITrap.sol` - Trap interface for Drosera compatibility.

### Configuration
* `drosera.toml` - Complete Drosera configuration for all three traps.
* `foundry.toml` - Foundry configuration with optimized build settings.
* `script/Deploy.s.sol` - Complete deployment script with automatic configuration generation.

### Testing
* `test/MEVSandwichDetector.t.sol` - Comprehensive MEV trap tests.
* `test/GovernanceAttackMonitor.t.sol` - Governance trap test suite.
* `test/OracleManipulationDetector.t.sol` - Oracle trap validation tests.

---

## Detection Logic

### MEV Sandwich Detection (`collect()` function)
The trap analyzes Uniswap V3 Swap events for sandwich patterns:
```solidity
// Monitor Swap events from Uniswap V3 pool
if (logs[i].topics[0] != SWAP_TOPIC || logs[i].topics.length < 7) continue;

// Decode swap parameters
(, int256 amount0, int256 amount1, , , , ) = abi.decode(
    logs[i].data,
    (address, int256, int256, uint160, uint128, int24, address)
);

// Analyze transaction timing and relationships
address sender = address(uint160(uint256(logs[i].topics[6])));
```

### Governance Attack Detection (`evaluateResponse()` function)
The trap identifies voting manipulation:
```solidity
// Monitor delegation changes and voting events
_addEventFilter(GOVERNANCE_TOKEN, DELEGATE_VOTES_CHANGED);
_addEventFilter(GOVERNOR, VOTE_CAST);

// Detect voting power spikes during active proposals
if (votingPowerChange > VOTING_POWER_SPIKE_BPS) {
    return (true, abi.encode(alert));
}
```

### Oracle Manipulation Detection
The trap cross-verifies price sources:
```solidity
// Compare Chainlink vs Uniswap prices
uint256 chainlinkNormalized = chainlinkPrice * 1e10; // 8 → 18 decimals
uint256 deviation;

if (chainlinkNormalized > uniswapPrice) {
    deviation = ((chainlinkNormalized - uniswapPrice) * 10000) / chainlinkNormalized;
}

// Alert on significant deviations
if (deviation > MAX_DEVIATION_BPS) {
    return (true, abi.encode(alert));
}
```

---

## Response System

### Unified Responder (`SecurityResponder.sol`)
All three traps feed into a single response handler:

```solidity
// MEV Attack Response
function handleMEVAlert(bytes calldata alertData) external {
    (address victim, address attacker, uint256 profit, uint256 impact) = 
        abi.decode(alertData, (address, address, uint256, uint256));
    emit MEVAlert(victim, attacker, profit, impact);
    // Mitigation: Pause pool, increase slippage, notify monitoring
}

// Governance Attack Response  
function handleGovernanceAlert(bytes calldata alertData) external {
    (uint256 proposalId, address actor, string memory alertType, uint256 change) =
        abi.decode(alertData, (uint256, address, string, uint256));
    emit GovernanceAlert(proposalId, actor, alertType, change);
    // Mitigation: Delay proposal, escalate to multisig, freeze delegations
}

// Oracle Attack Response
function handleOracleAlert(bytes calldata alertData) external {
    (address oracle, uint256 reported, uint256 reference, uint256 deviation) =
        abi.decode(alertData, (address, uint256, uint256, uint256));
    emit OracleAlert(oracle, reported, reference, deviation);
    // Mitigation: Switch to fallback, pause borrowing, trigger circuit breaker
}
```

---

## Configuration

### Drosera Configuration (`drosera.toml`)
```toml
[trap.mev_sandwich]
address = "0x..."
response_contract = "0x..."
response_function = "handleMEVAlert"
block_sample_size = 3
cooldown_period_blocks = 10

[trap.governance_monitor]
address = "0x..."
response_contract = "0x..."
response_function = "handleGovernanceAlert"
block_sample_size = 10

[trap.oracle_detector]
address = "0x..."
response_contract = "0x..."
response_function = "handleOracleAlert"
block_sample_size = 2
```

### Deployment
```bash
# Deploy all contracts
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast

# The script automatically generates drosera.toml configuration
```

---

## Security Features

* **Planner Safety**: All traps include empty data blob guards
* **Rising Edge Detection**: Prevents repeated triggers on sustained conditions
* **Multi-Source Verification**: Oracle trap validates across independent sources
* **Pattern Confirmation**: MEV trap requires multi-transaction patterns
* **Parameter Validation**: All thresholds are validated and constrained

---

## Testing

```bash
# Test all traps
forge test

# Test specific components
forge test --match-contract MEVSandwichDetectorTest
forge test --match-contract GovernanceAttackMonitorTest  
forge test --match-contract OracleManipulationDetectorTest

# Gas optimization analysis
forge test --gas-report
```

---

## License
MIT License - Production-ready for Drosera Network integration.
