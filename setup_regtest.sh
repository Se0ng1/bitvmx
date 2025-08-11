#!/bin/bash

# BitVMX Regtest Setup Script
# This script automates the setup of prover and verifier on regtest network

set -e

echo "==============================================="
echo "BitVMX Regtest Setup Script"
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

# Clean up function
cleanup() {
    print_info "Cleaning up previous containers and volumes..."
    docker compose -f docker-compose.regtest.yml down -v 2>/dev/null || true
    docker volume rm bitvmx_bitcoin-regtest-data 2>/dev/null || true
    print_status "Cleanup complete"
}

# Start services
start_services() {
    print_info "Starting Docker services..."
    docker compose -f docker-compose.regtest.yml up -d
    print_status "Services started"
    
    # Wait for services to be ready
    print_info "Waiting for services to initialize..."
    sleep 10
    
    # Check if services are running
    if docker ps | grep -q bitvmx-bitcoin-regtest && \
       docker ps | grep -q bitvmx-verifier-regtest && \
       docker ps | grep -q bitvmx-prover-regtest; then
        print_status "All services are running"
    else
        print_error "Some services failed to start"
        docker compose -f docker-compose.regtest.yml logs
        exit 1
    fi
}

# Setup Bitcoin wallet and funding
setup_bitcoin() {
    print_info "Setting up Bitcoin regtest wallet..."
    
    # Create wallet
    docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest -rpcuser=user -rpcpassword=password createwallet testwallet 2>/dev/null || true
    
    # Generate blocks to get coins
    print_info "Mining blocks to generate coins..."
    ADDRESS=$(docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest -rpcuser=user -rpcpassword=password -rpcwallet=testwallet getnewaddress)
    docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest -rpcuser=user -rpcpassword=password -rpcwallet=testwallet generatetoaddress 101 $ADDRESS > /dev/null
    
    print_status "Generated 101 blocks, wallet has coins"
    
    # Get balance
    BALANCE=$(docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest -rpcuser=user -rpcpassword=password -rpcwallet=testwallet getbalance)
    print_info "Wallet balance: $BALANCE BTC"
}

# Create funding transaction
create_funding_tx() {
    print_info "Creating funding transaction..."
    
    # The private key used in .env_common
    PRIVATE_KEY="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    
    # Import the private key
    docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest -rpcuser=user -rpcpassword=password -rpcwallet=testwallet importprivkey $PRIVATE_KEY "" false > /dev/null
    
    # Get the address for this private key
    FUNDING_ADDRESS=$(docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest -rpcuser=user -rpcpassword=password -rpcwallet=testwallet getaddressinfo bcrt1ql3e9pgs3mmwuwrh95fecme0s0qtn2880hlwwpw | jq -r '.address')
    
    print_info "Funding address: $FUNDING_ADDRESS"
    
    # Send funds to the funding address
    TX_ID=$(docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest -rpcuser=user -rpcpassword=password -rpcwallet=testwallet sendtoaddress $FUNDING_ADDRESS 0.02)
    
    print_status "Created funding transaction: $TX_ID"
    
    # Mine a block to confirm the transaction
    print_info "Mining block to confirm transaction..."
    MINING_ADDRESS=$(docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest -rpcuser=user -rpcpassword=password -rpcwallet=testwallet getnewaddress)
    docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest -rpcuser=user -rpcpassword=password -rpcwallet=testwallet generatetoaddress 1 $MINING_ADDRESS > /dev/null
    
    print_status "Transaction confirmed"
    echo "$TX_ID"
}

# Setup verifier
setup_verifier() {
    print_info "Setting up verifier..."
    
    # Call verifier setup API
    RESPONSE=$(curl -s -X POST http://localhost:8080/api/v1/setup \
        -H "Content-Type: application/json" \
        -d '{
            "setup_uuid": "test-setup-'$(date +%s)'",
            "network": "regtest"
        }')
    
    if echo "$RESPONSE" | grep -q "public_key"; then
        print_status "Verifier setup successful"
        echo "$RESPONSE" | jq '.'
    else
        print_error "Verifier setup failed"
        echo "$RESPONSE"
        return 1
    fi
}

# Setup prover
setup_prover() {
    print_info "Setting up prover..."
    
    # Get the funding transaction ID
    FUNDING_TX_ID=$1
    
    if [ -z "$FUNDING_TX_ID" ]; then
        print_error "No funding transaction ID provided"
        return 1
    fi
    
    # Call prover setup API
    RESPONSE=$(curl -s -X POST http://localhost:8081/api/v1/setup \
        -H "Content-Type: application/json" \
        -d '{
            "max_amount_of_steps": 10,
            "amount_of_input_words": 2,
            "amount_of_bits_wrong_step_search": 5,
            "amount_of_bits_per_digit_checksum": 8,
            "funding_tx_id": "'$FUNDING_TX_ID'",
            "funding_index": 0,
            "secret_origin_of_funds": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            "prover_destination_address": "bcrt1ql3e9pgs3mmwuwrh95fecme0s0qtn2880hlwwpw",
            "prover_signature_private_key": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            "prover_signature_public_key": "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        }')
    
    if echo "$RESPONSE" | grep -q "setup_uuid"; then
        print_status "Prover setup successful"
        echo "$RESPONSE" | jq '.'
        SETUP_UUID=$(echo "$RESPONSE" | jq -r '.setup_uuid')
        echo "$SETUP_UUID"
    else
        print_error "Prover setup failed"
        echo "$RESPONSE"
        return 1
    fi
}

# Test verifier public_keys API
test_verifier_public_keys() {
    print_info "Testing verifier public_keys API..."
    
    # This is just a test call to verify the API is working
    RESPONSE=$(curl -s -X POST http://localhost:8080/api/v1/public_keys \
        -H "Content-Type: application/json" \
        -d '{
            "bitvmx_protocol_setup_properties_dto": {
                "setup_uuid": "test-uuid",
                "uuid": "test-uuid-2",
                "funding_amount_of_satoshis": 1000000,
                "step_fees_satoshis": 30000,
                "funding_tx_id": "dummy",
                "funding_index": 0,
                "verifier_address_dict": {},
                "prover_destination_address": "bcrt1ql3e9pgs3mmwuwrh95fecme0s0qtn2880hlwwpw",
                "prover_signature_public_key": "test",
                "verifier_signature_public_key": "test",
                "verifier_destination_address": "bcrt1ql3e9pgs3mmwuwrh95fecme0s0qtn2880hlwwpw",
                "seed_unspendable_public_key": "test",
                "prover_destroyed_public_key": "test",
                "verifier_destroyed_public_key": "test",
                "bitvmx_protocol_properties_dto": {
                    "max_amount_of_steps": 10,
                    "amount_of_input_words": 2,
                    "amount_of_bits_wrong_step_search": 5,
                    "amount_of_bits_per_digit_checksum": 8
                },
                "bitvmx_prover_winternitz_public_keys_dto": {
                    "step_trace_commitments_winternitz_public_keys": [],
                    "last_step_commitment_winternitz_public_key": [],
                    "halt_step_commitment_winternitz_public_key": [],
                    "hash_search_winternitz_public_keys": []
                }
            }
        }')
    
    if echo "$RESPONSE" | grep -q "verifier_public_key"; then
        print_status "Verifier public_keys API is working"
    else
        print_error "Verifier public_keys API test failed"
        echo "$RESPONSE"
    fi
}

# Main execution
main() {
    echo ""
    print_info "Starting BitVMX regtest setup..."
    echo ""
    
    # Clean up previous runs
    cleanup
    echo ""
    
    # Start services
    start_services
    echo ""
    
    # Setup Bitcoin
    setup_bitcoin
    echo ""
    
    # Create funding transaction
    FUNDING_TX_ID=$(create_funding_tx)
    echo ""
    
    # Setup verifier first
    setup_verifier
    echo ""
    
    # Setup prover with funding transaction
    SETUP_UUID=$(setup_prover "$FUNDING_TX_ID")
    echo ""
    
    # Test verifier public_keys API
    test_verifier_public_keys
    echo ""
    
    print_status "Setup complete!"
    print_info "Verifier API: http://localhost:8080/api/v1"
    print_info "Prover API: http://localhost:8081/api/v1"
    print_info "Bitcoin RPC: http://localhost:8443"
    if [ ! -z "$SETUP_UUID" ]; then
        print_info "Setup UUID: $SETUP_UUID"
    fi
    echo ""
    print_info "To view logs: docker compose -f docker-compose.regtest.yml logs -f"
    print_info "To stop services: docker compose -f docker-compose.regtest.yml down"
    echo ""
}

# Handle script arguments
case "${1:-}" in
    clean)
        cleanup
        ;;
    stop)
        print_info "Stopping services..."
        docker compose -f docker-compose.regtest.yml down
        print_status "Services stopped"
        ;;
    logs)
        docker compose -f docker-compose.regtest.yml logs -f
        ;;
    *)
        main
        ;;
esac