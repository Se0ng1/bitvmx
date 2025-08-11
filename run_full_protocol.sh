#!/bin/bash

# BitVMX Protocol Full Execution Script
# Runs setup and executes the full protocol with alternating prover/verifier steps

set -e

echo "==============================================="
echo "BitVMX Protocol Full Execution"
echo "==============================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[i]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[>]${NC} $1"
}

# Configuration - Generate random secret for each run to avoid reuse issues
SECRET_ORIGIN_OF_FUNDS=$(openssl rand -hex 32)
PROVER_DESTINATION="bcrt1ql3e9pgs3mmwuwrh95fecme0s0qtn2880hlwwpw"
# Generate public key from the new private key
PROVER_SIG_PUBKEY=$(docker exec bitvmx-prover-backend-1 python3 -c "
from bitcoinutils.setup import setup
from bitcoinutils.keys import PrivateKey
setup('regtest')
private_key = PrivateKey(secret_exponent=0x${SECRET_ORIGIN_OF_FUNDS})
print(private_key.get_public_key().to_hex())
" 2>/dev/null || echo "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798")

# Step 1: Setup (from setup_prover_with_correct_funding.sh)
run_setup() {
    print_step "Running full setup..."
    
    # Get funding address
    print_info "Deriving address from secret_origin_of_funds..."
    FUNDING_ADDRESS=$(docker exec bitvmx-prover-backend-1 python3 -c "
from bitcoinutils.setup import setup
from bitcoinutils.keys import PrivateKey
setup('regtest')
private_key = PrivateKey(secret_exponent=0x${SECRET_ORIGIN_OF_FUNDS})
print(private_key.get_public_key().get_segwit_address().to_string())
" 2>/dev/null || echo "bcrt1qngw83fg8dz0k749cg7k3emc7v98wy0c7azaa6h")
    
    print_status "Funding address: $FUNDING_ADDRESS"
    
    # Create funding transaction
    print_info "Creating funding transaction..."
    TX_ID=$(docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest \
        -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd -rpcwallet=testwallet \
        sendtoaddress $FUNDING_ADDRESS 0.02)
    
    print_status "Funding transaction created: $TX_ID"
    
    # Mine block
    print_info "Mining block to confirm transaction..."
    MINING_ADDRESS=$(docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest \
        -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd -rpcwallet=testwallet \
        getnewaddress)
    docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest \
        -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd -rpcwallet=testwallet \
        generatetoaddress 1 $MINING_ADDRESS > /dev/null
    
    print_status "Transaction confirmed"
    
    # Get output index
    print_info "Finding output index..."
    OUTPUT_INDEX=$(docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest \
        -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd \
        getrawtransaction $TX_ID 1 | \
        jq ".vout[] | select(.scriptPubKey.address == \"$FUNDING_ADDRESS\") | .n")
    
    print_status "Output index: $OUTPUT_INDEX"
    
    # Setup verifier
    print_info "Setting up verifier..."
    SETUP_ID="setup-$(date +%s)"
    VERIFIER_RESPONSE=$(curl -s -X POST http://localhost:8080/api/v1/setup \
        -H "Content-Type: application/json" \
        -d "{
            \"setup_uuid\": \"$SETUP_ID\",
            \"network\": \"regtest\"
        }")
    
    if echo "$VERIFIER_RESPONSE" | grep -q "public_key"; then
        print_status "Verifier setup successful"
    else
        print_error "Verifier setup failed"
        echo "$VERIFIER_RESPONSE"
        exit 1
    fi
    
    # Setup prover
    print_info "Setting up prover..."
    PROVER_RESPONSE=$(curl -s -X POST http://localhost:8081/api/v1/setup \
        -H "Content-Type: application/json" \
        -d "{
            \"max_amount_of_steps\": 10,
            \"amount_of_input_words\": 2,
            \"amount_of_bits_wrong_step_search\": 3,
            \"amount_of_bits_per_digit_checksum\": 4,
            \"funding_tx_id\": \"$TX_ID\",
            \"funding_index\": $OUTPUT_INDEX,
            \"secret_origin_of_funds\": \"$SECRET_ORIGIN_OF_FUNDS\",
            \"prover_destination_address\": \"$PROVER_DESTINATION\",
            \"prover_signature_private_key\": \"$SECRET_ORIGIN_OF_FUNDS\",
            \"prover_signature_public_key\": \"$PROVER_SIG_PUBKEY\"
        }")
    
    if echo "$PROVER_RESPONSE" | grep -q "setup_uuid"; then
        SETUP_UUID=$(echo "$PROVER_RESPONSE" | jq -r '.setup_uuid')
        print_status "Prover setup successful!"
        print_info "Setup UUID: $SETUP_UUID"
    else
        print_error "Prover setup failed"
        echo "$PROVER_RESPONSE"
        exit 1
    fi
    
    echo "$SETUP_UUID"
}

# Step 2: Provide input
provide_input() {
    local SETUP_UUID=$1
    print_step "Providing input to prover..."
    
    curl -s -X POST http://localhost:8081/api/v1/input \
        -H "Content-Type: application/json" \
        -d "{
            \"input_hex\": \"1111111100000000\",
            \"setup_uuid\": \"$SETUP_UUID\"
        }" > /dev/null
    
    print_status "Input provided"
    
    # Copy ELF file to expected location
    docker exec bitvmx-prover-backend-1 bash -c "
        mkdir -p /bitvmx-backend/BitVMX-CPU/docker-riscv32/riscv32/build/ && 
        cp /bitvmx-backend/execution_files/test_input.elf /bitvmx-backend/BitVMX-CPU/docker-riscv32/riscv32/build/
    " 2>/dev/null
}

# Step 3: Execute protocol with alternating steps
execute_protocol() {
    local SETUP_UUID=$1
    print_step "Executing protocol steps (alternating prover/verifier)..."
    
    local MAX_STEPS=20
    local PROVER_STEP=""
    local VERIFIER_STEP=""
    local CHALLENGE_DETECTED=false
    
    for i in $(seq 1 $MAX_STEPS); do
        echo ""
        print_info "========== Round $i =========="
        
        # Prover next step
        print_step "Calling Prover next_step..."
        PROVER_RESPONSE=$(curl -s -X POST http://localhost:8081/api/v1/next_step \
            -H "Content-Type: application/json" \
            -d "{\"setup_uuid\": \"$SETUP_UUID\"}" 2>/dev/null)
        
        if echo "$PROVER_RESPONSE" | grep -q "executed_step"; then
            PROVER_STEP=$(echo "$PROVER_RESPONSE" | jq -r '.executed_step')
            print_status "Prover executed: $PROVER_STEP"
            
            # Mine block for transaction confirmation
            docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest \
                -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd -rpcwallet=testwallet \
                generatetoaddress 1 $(docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest \
                -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd -rpcwallet=testwallet getnewaddress) > /dev/null
            print_info "Block mined"
        else
            print_info "Prover response:"
            echo "$PROVER_RESPONSE" | jq '.' 2>/dev/null || echo "$PROVER_RESPONSE"
        fi
        
        sleep 2
        
        # Verifier next step
        print_step "Calling Verifier next_step..."
        VERIFIER_RESPONSE=$(curl -s -X POST http://localhost:8080/api/v1/next_step \
            -H "Content-Type: application/json" \
            -d "{\"setup_uuid\": \"$SETUP_UUID\"}" 2>/dev/null)
        
        if echo "$VERIFIER_RESPONSE" | grep -q "executed_step"; then
            VERIFIER_STEP=$(echo "$VERIFIER_RESPONSE" | jq -r '.executed_step')
            print_status "Verifier executed: $VERIFIER_STEP"
            
            # Mine block
            docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest \
                -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd -rpcwallet=testwallet \
                generatetoaddress 1 $(docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest \
                -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd -rpcwallet=testwallet getnewaddress) > /dev/null
            print_info "Block mined"
        else
            # Check for specific messages
            if echo "$VERIFIER_RESPONSE" | grep -q "both hashes are equal"; then
                echo ""
                print_status "==============================================="
                print_status "✨ PROTOCOL COMPLETED SUCCESSFULLY! ✨"
                print_status "==============================================="
                print_info "Result: Computation verified - hashes match"
                print_info "No challenge needed - Prover's computation is correct"
                break
            elif echo "$VERIFIER_RESPONSE" | grep -q "challenge"; then
                echo ""
                print_error "==============================================="
                print_error "⚠️  CHALLENGE INITIATED! ⚠️"
                print_error "==============================================="
                print_info "Computation mismatch detected"
                CHALLENGE_DETECTED=true
                echo "$VERIFIER_RESPONSE" | jq '.' 2>/dev/null || echo "$VERIFIER_RESPONSE"
            else
                print_info "Verifier response:"
                echo "$VERIFIER_RESPONSE" | jq '.' 2>/dev/null || echo "$VERIFIER_RESPONSE"
            fi
        fi
        
        sleep 2
        
        # Check if both failed (protocol might be complete)
        if ! echo "$PROVER_RESPONSE" | grep -q "executed_step" && \
           ! echo "$VERIFIER_RESPONSE" | grep -q "executed_step"; then
            if ! echo "$VERIFIER_RESPONSE" | grep -q "both hashes are equal"; then
                print_info "Both prover and verifier have no more steps"
            fi
            break
        fi
    done
    
    if [ "$CHALLENGE_DETECTED" = true ]; then
        print_info "Continuing challenge resolution..."
        # Additional challenge handling logic can be added here
    fi
}

# Step 4: Show final results
show_results() {
    local SETUP_UUID=$1
    echo ""
    echo "==============================================="
    print_step "Final Protocol Results"
    echo "==============================================="
    
    # Check transaction count
    print_info "Checking blockchain transactions..."
    TX_COUNT=$(docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest \
        -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd \
        getblockcount 2>/dev/null || echo "0")
    print_info "Total blocks: $TX_COUNT"
    
    # Check prover final state
    print_info "Prover final state:"
    docker exec bitvmx-prover-backend-1 bash -c "
        if [ -f /bitvmx-backend/prover_files/$SETUP_UUID/bitvmx_protocol_verifier_dto.json ]; then
            cat /bitvmx-backend/prover_files/$SETUP_UUID/bitvmx_protocol_verifier_dto.json | \
            jq '{last_confirmed_step: .last_confirmed_step, last_confirmed_step_tx_id: .last_confirmed_step_tx_id}' 2>/dev/null
        fi
    " 2>/dev/null || echo "No state file found"
    
    # Check verifier final state
    print_info "Verifier final state:"
    docker exec bitvmx-verifier-backend-1 bash -c "
        if [ -f /bitvmx-backend/verifier_files/$SETUP_UUID/bitvmx_protocol_verifier_dto.json ]; then
            cat /bitvmx-backend/verifier_files/$SETUP_UUID/bitvmx_protocol_verifier_dto.json | \
            jq '{
                last_confirmed_step: .last_confirmed_step,
                published_halt_hash: .published_halt_hash,
                input_hex: .input_hex
            }' 2>/dev/null
        fi
    " 2>/dev/null || echo "No state file found"
    
    echo ""
    print_status "Protocol execution complete!"
}

# Main execution
main() {
    echo ""
    
    # Step 1: Run setup
    SETUP_UUID=$(run_setup)
    echo ""
    
    # Step 2: Provide input
    provide_input "$SETUP_UUID"
    echo ""
    
    # Step 3: Execute protocol
    execute_protocol "$SETUP_UUID"
    echo ""
    
    # Step 4: Show results
    show_results "$SETUP_UUID"
    echo ""
}

# Run
main