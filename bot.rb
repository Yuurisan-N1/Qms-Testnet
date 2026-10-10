require "json"
require "dotenv"
require "eth"
require_relative "utils/banner"

MY_PROJECT = "Qms Testnet"

RESET = "\033[0m"
BOLD = "\033[1m"
RED = "\033[91m"
GREEN = "\033[92m"
YELLOW = "\033[93m"

def log_green(msg)
  puts "#{GREEN}#{BOLD}#{msg}#{RESET}"
end

def log_yellow(msg)
  puts "#{YELLOW}#{BOLD}#{msg}#{RESET}"
end

def log_red(msg)
  puts "#{RED}#{BOLD}#{msg}#{RESET}"
end

def handle_sigint
  puts
  log_red("Script stopped by user.")
  exit(0)
end

Signal.trap("INT") { handle_sigint }

Dotenv.load

RPC_URL = "https://rpc.testnet.qms.finance"
CHAIN_ID = 19480

GMGN_ADDRESS = Eth::Address.new("0x13c77Cb77a9eF3EAb234D4d172188200Bce890B4").to_s
FAUCET_ADDRESS = Eth::Address.new("0x6Af7De37FE1834443e620FBfdE6BF13889adc0bd").to_s
STAKING_ADDRESS = Eth::Address.new("0xCb330D77e4AE155037a0D687eE02152Af249B693").to_s
STAKING_TOKEN_ADDRESS = Eth::Address.new("0x465E0D7d5d1AffB90E3eE90C5631E717e995a186").to_s

GMGN_ABI = [
  {"inputs"=>[{"internalType"=>"address","name"=>"user","type"=>"address"}],"name"=>"remainingGM","outputs"=>[{"internalType"=>"uint256","name"=>"","type"=>"uint256"}],"stateMutability"=>"view","type"=>"function"},
  {"inputs"=>[{"internalType"=>"address","name"=>"user","type"=>"address"}],"name"=>"remainingGN","outputs"=>[{"internalType"=>"uint256","name"=>"","type"=>"uint256"}],"stateMutability"=>"view","type"=>"function"},
  {"inputs"=>[{"internalType"=>"string","name"=>"text","type"=>"string"}],"name"=>"sayGM","outputs"=>[],"stateMutability"=>"payable","type"=>"function"},
  {"inputs"=>[{"internalType"=>"string","name"=>"text","type"=>"string"}],"name"=>"sayGN","outputs"=>[],"stateMutability"=>"payable","type"=>"function"},
  {"inputs"=>[],"name"=>"fee","outputs"=>[{"internalType"=>"uint256","name"=>"","type"=>"uint256"}],"stateMutability"=>"view","type"=>"function"},
]

FAUCET_ABI = [
  {"inputs"=>[{"internalType"=>"address","name"=>"user","type"=>"address"}],"name"=>"canClaim","outputs"=>[{"internalType"=>"bool","name"=>"","type"=>"bool"}],"stateMutability"=>"view","type"=>"function"},
  {"inputs"=>[],"name"=>"claim","outputs"=>[],"stateMutability"=>"nonpayable","type"=>"function"},
  {"inputs"=>[{"internalType"=>"address","name"=>"user","type"=>"address"}],"name"=>"nextClaimTime","outputs"=>[{"internalType"=>"uint256","name"=>"","type"=>"uint256"}],"stateMutability"=>"view","type"=>"function"},
]

STAKING_ABI = [
  {"inputs"=>[{"internalType"=>"uint256","name"=>"amount","type"=>"uint256"}],"name"=>"stake","outputs"=>[],"stateMutability"=>"nonpayable","type"=>"function"},
  {"inputs"=>[{"internalType"=>"address","name"=>"","type"=>"address"}],"name"=>"stakes","outputs"=>[{"internalType"=>"uint256","name"=>"amount","type"=>"uint256"},{"internalType"=>"uint256","name"=>"stakedAt","type"=>"uint256"},{"internalType"=>"uint256","name"=>"lastClaimed","type"=>"uint256"}],"stateMutability"=>"view","type"=>"function"},
  {"inputs"=>[],"name"=>"minStakeAmount","outputs"=>[{"internalType"=>"uint256","name"=>"","type"=>"uint256"}],"stateMutability"=>"view","type"=>"function"},
]

STAKING_TOKEN_ABI = [
  {"inputs"=>[{"internalType"=>"address","name"=>"account","type"=>"address"}],"name"=>"balanceOf","outputs"=>[{"internalType"=>"uint256","name"=>"","type"=>"uint256"}],"stateMutability"=>"view","type"=>"function"},
  {"inputs"=>[{"internalType"=>"address","name"=>"to","type"=>"address"},{"internalType"=>"uint256","name"=>"amount","type"=>"uint256"}],"name"=>"transfer","outputs"=>[{"internalType"=>"bool","name"=>"","type"=>"bool"}],"stateMutability"=>"nonpayable","type"=>"function"},
  {"inputs"=>[{"internalType"=>"address","name"=>"from","type"=>"address"},{"internalType"=>"address","name"=>"to","type"=>"address"},{"internalType"=>"uint256","name"=>"amount","type"=>"uint256"}],"name"=>"transferFrom","outputs"=>[{"internalType"=>"bool","name"=>"","type"=>"bool"}],"stateMutability"=>"nonpayable","type"=>"function"},
  {"inputs"=>[{"internalType"=>"address","name"=>"spender","type"=>"address"},{"internalType"=>"uint256","name"=>"amount","type"=>"uint256"}],"name"=>"approve","outputs"=>[{"internalType"=>"bool","name"=>"","type"=>"bool"}],"stateMutability"=>"nonpayable","type"=>"function"},
  {"inputs"=>[{"internalType"=>"address","name"=>"_owner","type"=>"address"},{"internalType"=>"address","name"=>"spender","type"=>"address"}],"name"=>"allowance","outputs"=>[{"internalType"=>"uint256","name"=>"","type"=>"uint256"}],"stateMutability"=>"view","type"=>"function"},
]

def load_config
  JSON.parse(File.read("config.json"))
end

def load_private_keys
  keys = []
  i = 1
  loop do
    key = ENV["PRIVATEKEY_#{i}"]
    break if key.nil? || key.empty?
    keys << key.strip
    i += 1
  end
  keys
end

def build_base_tx(w3, addr, value = 0)
  tx = {
    from: addr,
    nonce: w3.eth_get_transaction_count(addr, "latest")["result"].to_i(16),
    chain_id: CHAIN_ID,
  }
  tx[:value] = value if value != 0
  tx
end

def estimate_and_send(w3, tx, account)
  begin
    gas = w3.eth_estimate_gas(tx)["result"].to_i(16)
    tx[:gas] = (gas * 1.2).to_i
  rescue StandardError
    block = w3.eth_get_block_by_number("latest", false)["result"]
    tx[:gas] = (block["gasLimit"].to_i(16) * 1.15).to_i
  end

  tx[:gas_price] = w3.eth_gas_price["result"].to_i(16)

  signed = Eth::Tx.new({
    nonce: tx[:nonce],
    gas_price: tx[:gas_price],
    gas_limit: tx[:gas],
    to: tx[:to],
    value: tx[:value] || 0,
    data: tx[:data] || "",
    chain_id: tx[:chain_id],
  })
  signed.sign(account)
  tx_hash = w3.eth_send_raw_transaction(signed.hex)["result"]

  start = Time.now
  receipt = nil
  loop do
    receipt = w3.eth_get_transaction_receipt(tx_hash)["result"]
    break if receipt
    raise "Transaction #{tx_hash} is not in the chain after 120 seconds" if Time.now - start > 120
    sleep 0.1
  end
  receipt["status"] = receipt["status"].to_i(16)
  [tx_hash.sub(/\A0x/, ""), receipt]
end

def countdown(seconds)
  seconds.downto(1) do |remaining|
    h = remaining / 3600
    m = (remaining % 3600) / 60
    s = remaining % 60
    print "\r#{YELLOW}#{BOLD}Next cycle starts in #{format('%02d', h)}:#{format('%02d', m)}:#{format('%02d', s)}#{RESET}"
    $stdout.flush
    sleep(1)
  end
  puts
end

def process_say_gm_gn(w3, account)
  gmgn = Eth::Contract.from_abi(name: "GMGN", address: GMGN_ADDRESS, abi: GMGN_ABI)
  addr = account.address.to_s

  begin
    fee = w3.call(gmgn, "fee")
  rescue StandardError
    log_red("Failed to fetch GM GN contract fee from chain.")
    return
  end

  remaining_gm = w3.call(gmgn, "remainingGM", addr)
  log_yellow("Remaining GM quota for today is #{remaining_gm}.")

  remaining_gm.times do |i|
    begin
      data = gmgn.function("sayGM", args: 1).encode_call("gm")
      tx = build_base_tx(w3, addr, fee)
      tx[:to] = GMGN_ADDRESS
      tx[:data] = data
      _tx_hash, receipt = estimate_and_send(w3, tx, account)
      if receipt["status"] == 1
        log_green("GM message #{i + 1} sent successfully on chain.")
      else
        log_red("GM message #{i + 1} transaction was reverted on chain.")
      end
    rescue StandardError
      log_red("Failed to send GM message #{i + 1} to the contract.")
    end
  end

  remaining_gn = w3.call(gmgn, "remainingGN", addr)
  log_yellow("Remaining GN quota for today is #{remaining_gn}.")

  remaining_gn.times do |i|
    begin
      data = gmgn.function("sayGN", args: 1).encode_call("gn")
      tx = build_base_tx(w3, addr, fee)
      tx[:to] = GMGN_ADDRESS
      tx[:data] = data
      _tx_hash, receipt = estimate_and_send(w3, tx, account)
      if receipt["status"] == 1
        log_green("GN message #{i + 1} sent successfully on chain.")
      else
        log_red("GN message #{i + 1} transaction was reverted on chain.")
      end
    rescue StandardError
      log_red("Failed to send GN message #{i + 1} to the contract.")
    end
  end
end

def process_faucet(w3, account)
  faucet = Eth::Contract.from_abi(name: "Faucet", address: FAUCET_ADDRESS, abi: FAUCET_ABI)
  addr = account.address.to_s

  begin
    can_claim = w3.call(faucet, "canClaim", addr)
  rescue StandardError
    log_red("Failed to check faucet claim eligibility from chain.")
    return
  end

  unless can_claim
    begin
      next_time = w3.call(faucet, "nextClaimTime", addr)
      now = Time.now.to_i
      wait_minutes = [0, (next_time - now) / 60].max
      log_yellow("Faucet cooldown is still active, next claim available in #{wait_minutes} minutes.")
    rescue StandardError
      log_yellow("Faucet cooldown is still active for this account.")
    end
    return
  end

  log_yellow("Faucet cooldown has passed, proceeding to claim QMST tokens.")

  begin
    data = Eth::Util.prefix_hex(faucet.function("claim", args: 0).signature)
    tx = build_base_tx(w3, addr)
    tx[:to] = FAUCET_ADDRESS
    tx[:data] = data
    tx_hash, receipt = estimate_and_send(w3, tx, account)
    if receipt["status"] == 1
      log_green("QMST tokens claimed successfully with hash #{tx_hash}.")
    else
      log_red("Faucet claim transaction was reverted on chain.")
    end
  rescue StandardError
    log_red("Failed to claim QMST tokens from the faucet contract.")
  end
end

def process_staking(w3, account, cfg)
  staking = Eth::Contract.from_abi(name: "Staking", address: STAKING_ADDRESS, abi: STAKING_ABI)
  token = Eth::Contract.from_abi(name: "StakingToken", address: STAKING_TOKEN_ADDRESS, abi: STAKING_TOKEN_ABI)
  addr = account.address.to_s
  decimals = 18
  symbol = "QMST"

  begin
    balance = w3.call(token, "balanceOf", addr)
  rescue StandardError
    log_red("Failed to fetch token balance from chain.")
    return
  end

  begin
    min_stake = w3.call(staking, "minStakeAmount")
  rescue StandardError
    log_red("Failed to fetch minimum stake amount from chain.")
    return
  end

  amount_min = cfg["staking"].fetch("amount_min", 10)
  amount_max = cfg["staking"].fetch("amount_max", 50)
  stake_amount_human = amount_min + (amount_max - amount_min) * rand
  stake_amount = (stake_amount_human * 10**decimals).to_i

  log_yellow("Wallet balance is #{format('%.4f', Rational(balance, 10**decimals).to_f)} #{symbol} and minimum stake is #{format('%.4f', Rational(min_stake, 10**decimals).to_f)} #{symbol}.")

  if balance < stake_amount
    log_red("Insufficient token balance to cover the selected stake amount.")
    return
  end

  if stake_amount < min_stake
    log_red("Selected stake amount is below the contract minimum requirement.")
    return
  end

  begin
    allowance = w3.call(token, "allowance", addr, STAKING_ADDRESS)
  rescue StandardError
    log_red("Failed to check token allowance for the staking contract.")
    return
  end

  if allowance < stake_amount
    log_yellow("Approving staking contract to spend #{format('%.4f', stake_amount_human)} #{symbol} tokens.")
    begin
      data = token.function("approve", args: 2).encode_call(STAKING_ADDRESS, stake_amount)
      tx = build_base_tx(w3, addr)
      tx[:to] = STAKING_TOKEN_ADDRESS
      tx[:data] = data
      _tx_hash, receipt = estimate_and_send(w3, tx, account)
      if receipt["status"] == 1
        log_green("Token approval confirmed successfully on chain.")
      else
        log_red("Token approval transaction was reverted on chain.")
        return
      end
    rescue StandardError
      log_red("Failed to approve tokens for the staking contract.")
      return
    end
  end

  log_yellow("Staking #{format('%.4f', stake_amount_human)} #{symbol} tokens into the contract.")

  begin
    data = staking.function("stake", args: 1).encode_call(stake_amount)
    tx = build_base_tx(w3, addr)
    tx[:to] = STAKING_ADDRESS
    tx[:data] = data
    tx_hash, receipt = estimate_and_send(w3, tx, account)
    if receipt["status"] == 1
      log_green("Staking transaction confirmed successfully with hash #{tx_hash}.")
    else
      log_red("Staking transaction was reverted by the contract.")
    end
  rescue StandardError
    log_red("Failed to execute the staking transaction on chain.")
  end
end

def process_account(w3, account, cfg, idx, total)
  addr = account.address.to_s
  log_green("Processing with address #{addr}.")

  process_say_gm_gn(w3, account) if cfg["say_gm_gn"]["enabled"]

  process_faucet(w3, account) if cfg["faucet"]["enabled"]

  process_staking(w3, account, cfg) if cfg["staking"]["enabled"]

  log_green("Account #{idx + 1} processing completed successfully.")
end

def main
  show_banner(MY_PROJECT)

  cfg = load_config
  private_keys = load_private_keys

  if private_keys.empty?
    log_red("No private keys found in the environment file.")
    exit(1)
  end

  w3 = Eth::Client.create(RPC_URL)
  connected = begin
    w3.web3_client_version
    true
  rescue StandardError
    false
  end
  unless connected
    log_red("Unable to connect to the RPC endpoint.")
    exit(1)
  end

  log_yellow("Connected to network with chain ID #{w3.eth_chain_id['result'].to_i(16)}.")

  cycle = 1
  loop do
    log_green("Starting automation cycle number #{cycle}.")

    accounts = private_keys.map { |pk| Eth::Key.new(priv: pk.sub(/\A0x/, "")) }

    accounts.each_with_index do |account, idx|
      puts if idx > 0
      process_account(w3, account, cfg, idx, accounts.length)
    end

    sleep_seconds = cfg["settings"]["sleep_seconds"]
    log_yellow("All accounts processed")
    countdown(sleep_seconds)

    show_banner(MY_PROJECT)
    cycle += 1
  end
end

main if __FILE__ == $PROGRAM_NAME