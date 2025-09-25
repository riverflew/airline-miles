# Airline Miles Smart Contract

A verification smart contract for frequent flyer points ownership and loyalty program validation on the Stacks blockchain.

## Description

The Airline Miles smart contract provides a decentralized platform for managing airline loyalty programs, tracking frequent flyer points, and enabling verification mechanisms for points ownership and transfers. Built on Clarity for the Stacks blockchain, this contract ensures transparent and secure management of loyalty program data.

## Features

- **Multi-Airline Support**: Register and manage multiple airline loyalty programs
- **Tiered Loyalty System**: Automatic tier calculation (Bronze, Silver, Gold, Platinum) based on lifetime points
- **Points Management**: Award, redeem, and transfer points between users
- **Transaction History**: Complete audit trail of all points transactions
- **Verification Functions**: Validate user balances, tier status, and minimum requirements
- **Access Control**: Owner-only functions for airline registration and contract management
- **Security Features**: Contract pause functionality and comprehensive error handling

## Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity v2
- **Epoch**: 2.5
- **Contract Name**: airline-miles
- **Version**: 1.0.0

### Loyalty Tiers

| Tier | Lifetime Points Required |
|------|--------------------------|
| Bronze | 0 - 24,999 |
| Silver | 25,000 - 49,999 |
| Gold | 50,000 - 99,999 |
| Platinum | 100,000+ |

## Installation

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks CLI tools
- Node.js (for package management)

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd airline-miles
```

2. Navigate to the contract directory:
```bash
cd airline-miles_contract
```

3. Check contract syntax:
```bash
clarinet check
```

4. Run tests:
```bash
clarinet test
```

## Usage Examples

### Register an Airline (Contract Owner Only)

```clarity
(contract-call? .airline-miles register-airline "Delta Airlines" u2)
;; Returns: (ok u1) - airline ID 1 with 2x points multiplier
```

### Register for Loyalty Program

```clarity
(contract-call? .airline-miles register-loyalty-account u1)
;; Registers user for airline ID 1
```

### Award Points

```clarity
(contract-call? .airline-miles award-points 'SP1234... u1 u1000)
;; Awards 1000 base points (multiplied by airline multiplier)
```

### Redeem Points

```clarity
(contract-call? .airline-miles redeem-points u1 u500)
;; Redeems 500 points from airline ID 1
```

### Transfer Points

```clarity
(contract-call? .airline-miles transfer-points 'SP5678... u1 u250)
;; Transfers 250 points to another user
```

### Check Points Balance

```clarity
(contract-call? .airline-miles get-points-balance 'SP1234... u1)
;; Returns: (ok u2500) - current points balance
```

## Contract Functions Documentation

### Public Functions

#### `register-airline`
Registers a new airline in the system (owner only).
- **Parameters**: `name` (string-ascii 50), `points-multiplier` (uint)
- **Returns**: `(response uint uint)` - airline ID on success
- **Access**: Contract owner only

#### `register-loyalty-account`
Registers a user for an airline's loyalty program.
- **Parameters**: `airline-id` (uint)
- **Returns**: `(response bool uint)`
- **Access**: Any user

#### `award-points`
Awards points to a user account.
- **Parameters**: `user` (principal), `airline-id` (uint), `base-points` (uint)
- **Returns**: `(response uint uint)` - actual points awarded (after multiplier)
- **Access**: Contract owner or active airline

#### `redeem-points`
Allows users to redeem their points.
- **Parameters**: `airline-id` (uint), `points-to-redeem` (uint)
- **Returns**: `(response bool uint)`
- **Access**: Account holder only

#### `transfer-points`
Transfers points between user accounts.
- **Parameters**: `recipient` (principal), `airline-id` (uint), `points-to-transfer` (uint)
- **Returns**: `(response bool uint)`
- **Access**: Account holder only

#### `set-contract-paused`
Pauses or unpauses contract operations.
- **Parameters**: `paused` (bool)
- **Returns**: `(response bool uint)`
- **Access**: Contract owner only

### Read-Only Functions

#### `get-airline`
Retrieves airline information.
- **Parameters**: `airline-id` (uint)
- **Returns**: `(optional airline-data)`

#### `get-loyalty-account`
Retrieves user's loyalty account data.
- **Parameters**: `user` (principal), `airline-id` (uint)
- **Returns**: `(optional account-data)`

#### `get-points-balance`
Gets user's current points balance.
- **Parameters**: `user` (principal), `airline-id` (uint)
- **Returns**: `(response uint uint)`

#### `verify-tier-status`
Verifies user's current tier.
- **Parameters**: `user` (principal), `airline-id` (uint)
- **Returns**: `(response uint uint)`

#### `get-transaction`
Retrieves transaction details.
- **Parameters**: `tx-id` (uint)
- **Returns**: `(optional transaction-data)`

#### `verify-minimum-balance`
Checks if user meets minimum points requirement.
- **Parameters**: `user` (principal), `airline-id` (uint), `minimum-points` (uint)
- **Returns**: `(response bool uint)`

#### `verify-tier-or-higher`
Verifies if user has required tier or higher.
- **Parameters**: `user` (principal), `airline-id` (uint), `required-tier` (uint)
- **Returns**: `(response bool uint)`

#### `get-contract-status`
Returns current contract status information.
- **Returns**: Contract status object with pause state and counters

### Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | ERR_UNAUTHORIZED | Unauthorized access attempt |
| u101 | ERR_INVALID_AMOUNT | Invalid amount provided |
| u102 | ERR_INSUFFICIENT_BALANCE | Insufficient points balance |
| u103 | ERR_AIRLINE_NOT_FOUND | Airline not registered |
| u104 | ERR_ALREADY_REGISTERED | User already registered |
| u105 | ERR_NOT_REGISTERED | User not registered |
| u106 | ERR_INVALID_TIER | Invalid tier specified |

## Deployment Guide

### Local Deployment (Testnet)

1. Start Clarinet console:
```bash
clarinet console
```

2. Deploy the contract:
```clarity
::deploy_contract airline-miles
```

3. Test basic functionality:
```clarity
(contract-call? .airline-miles register-airline "Test Airline" u1)
(contract-call? .airline-miles register-loyalty-account u1)
```

### Mainnet Deployment

1. Configure your deployment settings in `Clarinet.toml`

2. Deploy using Clarinet:
```bash
clarinet deploy --network mainnet
```

3. Verify deployment on Stacks Explorer

### Post-Deployment Setup

1. Register initial airlines using the contract owner account
2. Configure points multipliers based on airline partnerships
3. Set up monitoring for contract events
4. Implement frontend integration for user interactions

## Security Notes

### Access Control
- Contract owner has administrative privileges for airline registration and contract management
- Users can only manage their own loyalty accounts
- Airlines cannot directly modify user balances (only award points)

### Data Integrity
- All transactions are recorded with block height timestamps
- Points balances are validated before transfers or redemptions
- Tier calculations are deterministic and transparent

### Best Practices
- Always verify user registration before operations
- Check contract pause status in external integrations
- Implement proper error handling for all function calls
- Monitor transaction history for unusual patterns

### Known Limitations
- Points cannot be converted back to base currency
- No expiration mechanism for unused points
- Transfer restrictions between different airline programs
- Contract pause affects all operations (emergency use only)

## Development

### Testing
Run comprehensive tests using Clarinet:
```bash
clarinet test
```

### Code Analysis
Enable strict analysis in `Clarinet.toml` for production deployments:
```toml
[repl.analysis.check_checker]
strict = true
```

### Contributing
1. Fork the repository
2. Create a feature branch
3. Run tests and analysis
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For technical support and questions:
- Create an issue in the repository
- Review the contract documentation
- Check the Stacks developer resources

---

**Note**: This contract is designed for educational and development purposes. Ensure thorough testing and security audits before production deployment.