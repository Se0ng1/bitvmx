#!/bin/bash

# Bitcoin Regtest Setup Script
# This script sets up a Bitcoin regtest node and prepares funding

set -e

echo "==============================================="
echo "Bitcoin Regtest Setup Script"
echo "==============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[i]${NC} $1"
}

# Start Bitcoin regtest node
start_bitcoin() {
    print_info "Starting Bitcoin regtest node..."
    docker compose down bitcoin-regtest-node -v 2>/dev/null || true
    docker compose up bitcoin-regtest-node -d
    print_status "Bitcoin regtest node started"
    
    # Wait for node to be ready
    print_info "Waiting for Bitcoin node to initialize..."
    sleep 5
    
    # Check if node is running
    if docker ps | grep -q bitvmx-bitcoin-regtest; then
        print_status "Bitcoin node is running"
    else
        print_error "Bitcoin node failed to start"
        docker logs bitvmx-bitcoin-regtest
        exit 1
    fi
}

# Setup wallet and mine blocks
setup_wallet() {
    print_info "Setting up Bitcoin wallet..."
    
    # Create wallet (descriptor wallet is fine, we'll just send directly to the address)
    docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd createwallet testwallet 2>/dev/null || true
    
    # Generate initial blocks
    print_info "Mining 101 blocks to generate coins..."
    ADDRESS=$(docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd -rpcwallet=testwallet getnewaddress)
    docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd -rpcwallet=testwallet generatetoaddress 101 $ADDRESS > /dev/null
    
    print_status "Generated 101 blocks"
    
    # Get balance
    BALANCE=$(docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd -rpcwallet=testwallet getbalance)
    print_info "Wallet balance: $BALANCE BTC"
}

# Create funding transaction for the specific private key
create_funding() {
    print_info "Creating funding transaction..."
    
    # The address that corresponds to the private key in .env_common
    # Private key: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
    FUNDING_ADDRESS="bcrt1ql3e9pgs3mmwuwrh95fecme0s0qtn2880hlwwpw"
    
    print_info "Funding address: $FUNDING_ADDRESS"
    
    # Send funds to the funding address
    TX_ID=$(docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd -rpcwallet=testwallet sendtoaddress $FUNDING_ADDRESS 0.02)
    
    print_status "Created funding transaction: $TX_ID"
    
    # Mine a block to confirm
    print_info "Mining block to confirm transaction..."
    MINING_ADDRESS=$(docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd -rpcwallet=testwallet getnewaddress)
    docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd -rpcwallet=testwallet generatetoaddress 1 $MINING_ADDRESS > /dev/null
    
    print_status "Transaction confirmed"
    
    # Show transaction details
    print_info "Transaction details:"
    docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd -rpcwallet=testwallet gettransaction $TX_ID | jq '.amount, .confirmations'
    
    echo ""
    print_status "Funding transaction ready!"
    print_info "Transaction ID: $TX_ID"
    print_info "Funding Index: 0"
    print_info "Amount: 0.02 BTC (2000000 satoshis)"
    echo ""
    print_info "You can use this transaction for prover/verifier setup"
}

# Main execution
main() {
    echo ""
    start_bitcoin
    echo ""
    setup_wallet
    echo ""
    create_funding
    echo ""
    print_status "Bitcoin regtest setup complete!"
    print_info "Bitcoin RPC: http://localhost:8443"
    print_info "RPC User: myuser"
    print_info "RPC Password: SomeDecentp4ssw0rd"
    echo ""
    print_info "To view logs: docker logs -f bitvmx-bitcoin-regtest"
    print_info "To stop: docker compose down bitcoin-regtest-node"
    echo ""
}

# Handle script arguments
case "${1:-}" in
    stop)
        print_info "Stopping Bitcoin node..."
        docker compose down bitcoin-regtest-node
        print_status "Bitcoin node stopped"
        ;;
    clean)
        print_info "Cleaning up..."
        docker compose down bitcoin-regtest-node -v
        print_status "Cleanup complete"
        ;;
    logs)
        docker logs -f bitvmx-bitcoin-regtest
        ;;
    *)
        main
        ;;
esac