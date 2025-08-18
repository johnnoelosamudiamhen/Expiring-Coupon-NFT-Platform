# 🎫 Expiring Coupon NFT Platform

A revolutionary Web3 solution that brings trust, transparency, and security to digital discount systems through blockchain-based NFT coupons.

## 🌟 Overview

The Expiring Coupon NFT Platform transforms traditional coupon systems by leveraging Stacks blockchain smart contracts. Merchants can issue tamper-proof NFT coupons with embedded discount values, expiry dates, and redemption logic, eliminating duplication and abuse while providing complete trackability.

## ✨ Key Features

### 🏪 For Merchants
- **Secure Coupon Issuance**: Mint NFT coupons with customizable discount percentages and expiry blocks
- **Fraud Prevention**: Blockchain-based validation prevents duplication and unauthorized usage
- **Usage Analytics**: Track total coupons issued, redeemed, and discount amounts given
- **Flexible Redemption**: Support for single-use, multi-use, and event-based coupons

### 👥 For Users
- **Ownership Verification**: True ownership of coupons through NFT technology
- **Transparent Expiry**: Clear visibility of coupon validity and expiration
- **Transferable**: Send coupons to other users (if desired)
- **Savings Tracking**: Monitor total redemptions and savings achieved
- **Marketplace Trading**: Buy and sell unused coupons in a decentralized marketplace

### 🔧 Technical Features
- **Time-Based Validation**: Automatic expiry checking using block height
- **Multi-Use Support**: Configurable usage limits per coupon
- **Merchant Authorization**: Role-based access control for coupon creation
- **Comprehensive Statistics**: Detailed analytics for merchants and users

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet/getting-started) installed
- Stacks wallet for testing

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-username/Expiring-Coupon-NFT-Platform.git
cd Expiring-Coupon-NFT-Platform
```

2. Check contract validity:
```bash
clarinet check
```

3. Run tests:
```bash
npm install
npm test
```

## 📖 Usage Guide

### 🔐 Contract Owner Functions

#### Add Merchant
```clarity
(contract-call? .expiring-coupon-nft-platform add-merchant 'SP1MERCHANT-ADDRESS-HERE)
```

#### Remove Merchant
```clarity
(contract-call? .expiring-coupon-nft-platform remove-merchant 'SP1MERCHANT-ADDRESS-HERE)
```

### 🏪 Merchant Functions

#### Mint Coupon
```clarity
(contract-call? .expiring-coupon-nft-platform mint-coupon 
  'SP1CUSTOMER-ADDRESS     ;; recipient
  u20                      ;; 20% discount
  u144                     ;; expires in 144 blocks (~24 hours)
  u1                       ;; single use
  "WELCOME20"              ;; coupon type
)
```

#### Deactivate Coupon
```clarity
(contract-call? .expiring-coupon-nft-platform deactivate-coupon u1)
```

### 👤 User Functions

#### Redeem Coupon
```clarity
(contract-call? .expiring-coupon-nft-platform redeem-coupon 
  u1          ;; token-id
  u100        ;; purchase amount (will get 20% discount = 20 STX off)
)
```

#### Transfer Coupon
```clarity
(contract-call? .expiring-coupon-nft-platform transfer 
  u1                        ;; token-id
  tx-sender                 ;; sender
  'SP1RECIPIENT-ADDRESS     ;; recipient
)
```

#### Burn Coupon
```clarity
(contract-call? .expiring-coupon-nft-platform burn-coupon u1)
```

#### Create Marketplace Listing
```clarity
(contract-call? .expiring-coupon-nft-platform create-listing 
  u1          ;; token-id
  u50         ;; price in STX
  u144        ;; listing expires in 144 blocks (~24 hours)
)
```

#### Buy Coupon from Marketplace
```clarity
(contract-call? .expiring-coupon-nft-platform buy-coupon u1)  ;; listing-id
```

#### Cancel Listing
```clarity
(contract-call? .expiring-coupon-nft-platform cancel-listing u1)  ;; listing-id
```

## 📊 Read-Only Functions

### Check Coupon Validity
```clarity
(contract-call? .expiring-coupon-nft-platform is-coupon-valid u1)
```

### Get Coupon Details
```clarity
(contract-call? .expiring-coupon-nft-platform get-coupon-data u1)
```

### Get Merchant Statistics
```clarity
(contract-call? .expiring-coupon-nft-platform get-merchant-stats 'SP1MERCHANT-ADDRESS)
```

### Calculate Discount
```clarity
(contract-call? .expiring-coupon-nft-platform calculate-discount u100 u20)
;; Returns u20 (20% of 100)
```

### Get Marketplace Listing
```clarity
(contract-call? .expiring-coupon-nft-platform get-marketplace-listing u1)
```

### Check Listing Validity
```clarity
(contract-call? .expiring-coupon-nft-platform is-listing-valid u1)
```

### Get Listing History
```clarity
(contract-call? .expiring-coupon-nft-platform get-listing-history u1)
```

## 🏗️ Contract Architecture

### Data Structures

- **Coupon NFT**: ERC-721 compliant non-fungible tokens
- **Coupon Data**: Discount percentage, expiry block, usage limits, merchant info
- **Usage Tracking**: Per-user redemption history
- **Merchant Registry**: Authorized coupon issuers
- **Analytics**: Comprehensive statistics for all participants
- **Marketplace Listings**: Secondary market for coupon trading
- **Listing History**: Complete transaction records for marketplace sales

### Security Features

- **Owner-only Functions**: Contract deployment and merchant management
- **Merchant Authorization**: Only registered merchants can issue coupons
- **Ownership Verification**: Users must own coupons to redeem them
- **Expiry Validation**: Automatic time-based validation
- **Usage Limits**: Configurable redemption constraints

## 🔧 Development

### Testing
```bash
clarinet test
```

### Deployment
```bash
clarinet deploy --testnet
```

## 📄 Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | err-owner-only | Only contract owner can perform this action |
| u101 | err-not-token-owner | User doesn't own the specified coupon |
| u102 | err-coupon-expired | Coupon has passed its expiry block |
| u103 | err-coupon-already-used | Coupon has reached its usage limit |
| u104 | err-invalid-discount | Discount percentage must be 1-100 |
| u105 | err-invalid-expiry | Expiry blocks must be greater than 0 |
| u106 | err-coupon-not-found | Specified coupon doesn't exist |
| u107 | err-unauthorized-merchant | Caller is not a registered merchant |
| u108 | err-merchant-not-found | Merchant not found in registry |
| u109 | err-listing-not-found | Marketplace listing doesn't exist |
| u110 | err-insufficient-payment | Not enough STX provided for purchase |
| u111 | err-cannot-buy-own-listing | Users cannot buy their own listings |
| u112 | err-listing-expired | Marketplace listing has expired |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📜 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🌐 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity/)
- [Clarinet Developer Tools](https://docs.hiro.so/clarinet/)

---

**Built with ❤️ on Stacks Blockchain** 🚀
