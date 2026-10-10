<div align="center">

<img width="100%" alt="header" src="https://capsule-render.vercel.app/api?type=waving&height=210&text=QMS%20Testnet%20Bot&fontAlign=50&fontAlignY=36&fontSize=56&desc=Say%20GM%20%26%20GN%20%7C%20Faucet%20Claim%20%7C%20Auto%20Stake%20%7C%20Multi-Wallet&descAlign=50&descAlignY=58"/>

<img alt="typing" src="https://readme-typing-svg.demolab.com?font=Inter&size=18&duration=3000&pause=650&center=true&vCenter=true&width=900&lines=Auto+Say+GM+%26+GN+On-chain+%7C+Full+Daily+Quota;Auto+Faucet+Claim+%7C+QMST+Tokens+Per+Cooldown;Auto+Stake+%7C+Random+Amount+%7C+Auto+Approve;On-chain+Transactions+%7C+QMS+Testnet+Chain+ID+19480;Multi-Wallet+%7C+All+Keys+Per+Cycle"/>

<p>
  <img alt="ruby" src="https://img.shields.io/badge/Ruby-3.2+-CC342D?logo=ruby&logoColor=white"/>
  <img alt="platform" src="https://img.shields.io/badge/Platform-QMS%20Testnet-111111"/>
  <img alt="chain" src="https://img.shields.io/badge/Chain%20ID-19480-111111"/>
  <img alt="multi-wallet" src="https://img.shields.io/badge/Multi--Wallet-Supported-111111"/>
  <img alt="author" src="https://img.shields.io/badge/by-Yuurisandesu-111111"/>
</p>

<p>
  <b>QMS Testnet Bot</b> is a full on-chain automation bot for the QMS Testnet network.<br/>
  It submits Say GM and Say GN transactions up to the daily quota, claims QMST tokens from the faucet when the cooldown has passed, and stakes a random amount of QMST into the staking contract with automatic approval, all running across multiple wallets with a live countdown between cycles.<br/>
  Built and distributed by <b>Yuurisandesu</b>.
</p>

</div>

---

## Table of Contents

- [Requirements](#requirements)
- [Install Ruby](#install-ruby)
- [Installation](#installation)
- [Configuration](#configuration)
- [Running the Bot](#running-the-bot)
- [Features](#features)
- [File Structure](#file-structure)
- [Disclaimer](#disclaimer)

---

## Requirements

- Ruby `3.2+`
- Bundler
- Git
- EVM wallet private keys with QMS Testnet native balance for gas

---

## Install Ruby

### Linux

```bash
sudo apt update && sudo apt install -y ruby ruby-bundler git
```

### macOS

```bash
brew install ruby
```

### Windows

Download and run the installer from https://rubyinstaller.org. Make sure to check **Add Ruby executables to your PATH** during installation. Verify with:

```bash
ruby --version
```

### Termux (Android)

```bash
pkg update && pkg install ruby git
```

---

## Installation

**Clone the repository:**

```bash
git clone https://github.com/Yuurisan-N1/Qms-Testnet.git
cd Qms-Testnet
```

**Install dependencies:**

```bash
bundle install
```

---

## Configuration

### 1. Private Keys (.env)

Copy `.env.example` to `.env` and fill in your EVM wallet private keys:

```env
PRIVATEKEY_1=0xyourprivatekeyhere
PRIVATEKEY_2=0xyourprivatekeyhere
```

Add as many `PRIVATEKEY_N` entries as wallets you want to run. All wallets are processed sequentially per cycle. Keys with or without the `0x` prefix are both accepted.

### 2. Bot Settings (config.json)

| Setting | Description |
|---|---|
| `say_gm_gn.enabled` | Enable or disable Say GM and GN transactions |
| `faucet.enabled` | Enable or disable faucet claim |
| `staking.enabled` | Enable or disable staking |
| `staking.amount_min` | Minimum QMST amount to stake per cycle |
| `staking.amount_max` | Maximum QMST amount to stake per cycle |
| `settings.sleep_seconds` | Seconds to wait between full cycles |

---

## Running the Bot

```bash
ruby bot.rb
```

Press `Ctrl+C` at any time to stop the bot cleanly.

---

## Features

### Say GM and GN
The bot reads the remaining GM and GN quotas from the GMGN contract for each wallet. It then sends a `sayGM` transaction for each remaining GM slot and a `sayGN` transaction for each remaining GN slot. The fee per message is read live from the contract before sending. Each transaction is confirmed on-chain before moving to the next one.

### Faucet Claim
The bot checks whether the faucet cooldown has passed for the wallet by querying `canClaim` on the faucet contract. If eligible, it sends a `claim` transaction and logs the transaction hash on success. If still on cooldown, the remaining wait time in minutes is calculated from `nextClaimTime` and logged.

### Auto Staking
The bot fetches the wallet's current QMST token balance and the contract's minimum stake requirement. A random stake amount is chosen between `amount_min` and `amount_max` from config. If the balance is sufficient and the amount is above the minimum, the bot checks the current token allowance for the staking contract. If the allowance is insufficient, it sends an `approve` transaction first. After approval is confirmed, it sends a `stake` transaction and logs the hash on success.

### On-chain Transaction Handling
Every transaction is built with a live nonce, gas estimate with a 20% buffer, and current gas price. If gas estimation fails, the block gas limit with a 15% buffer is used as a fallback. Each sent transaction is polled until confirmed or times out after 120 seconds.

### Multi Wallet
All wallets in `.env` are processed sequentially within every cycle. Each wallet is processed independently and the cycle number is logged at the start of each round.

### Auto Countdown
After all wallets complete a cycle, the bot displays a live `HH:MM:SS` countdown until the next cycle starts.

---

## File Structure

```text
Qms-Testnet/
├── bot.rb              # Main bot, full on-chain cycle automation
├── config.json         # Feature toggles, staking range, sleep duration
├── Gemfile             # Ruby gem dependencies
├── .env.example        # Private key template
├── LICENSE             # License file
└── utils/
    └── banner.rb       # Banner using yuurisan module
```

---

## Disclaimer

This tool is built for educational and technical exploration purposes. Use it wisely and at your own responsibility.

---

<div align="center">
<img width="100%" alt="footer" src="https://capsule-render.vercel.app/api?type=waving&height=120&section=footer"/>
</div>