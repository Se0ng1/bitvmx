#!/bin/bash

# BitVMX Protocol Step Execution Script
# Executes input provision and alternating next_step calls

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

print_result() {
    echo -e "${CYAN}[=]${NC} $1"
}

# Check if setup UUID is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <setup_uuid> [input_hex]"
    echo "Example: $0 120abf0d-ad9f-4d73-a57f-52ed0854227c"
    echo "Example with custom input: $0 120abf0d-ad9f-4d73-a57f-52ed0854227c 1111111100000000"
    exit 1
fi

SETUP_UUID=$1
INPUT_HEX=${2:-"1111111100000000"}  # Default input if not provided

echo "==============================================="
echo "BitVMX Protocol Execution"
echo "==============================================="
print_info "Setup UUID: $SETUP_UUID"
print_info "Input Hex: $INPUT_HEX"
echo ""

# Step 1: Copy ELF file to expected location
copy_elf_file() {
    print_step "Preparing execution environment..."
    
    docker exec bitvmx-prover-backend-1 bash -c "
        mkdir -p /bitvmx-backend/BitVMX-CPU/docker-riscv32/riscv32/build/ && 
        cp /bitvmx-backend/execution_files/test_input.elf /bitvmx-backend/BitVMX-CPU/docker-riscv32/riscv32/build/ 2>/dev/null || true
    "
    
    print_status "Execution environment ready"
}

# Step 2: Provide input to prover
provide_input() {
    print_step "Providing input to prover..."
    
    INPUT_RESPONSE=$(curl -s -X POST http://localhost:8081/api/v1/input \
        -H "Content-Type: application/json" \
        -d "{
            \"input_hex\": \"$INPUT_HEX\",
            \"setup_uuid\": \"$SETUP_UUID\"
        }")
    
    if echo "$INPUT_RESPONSE" | grep -q "error\|detail"; then
        print_error "Failed to provide input:"
        echo "$INPUT_RESPONSE" | jq '.' 2>/dev/null || echo "$INPUT_RESPONSE"
        return 1
    else
        print_status "Input provided successfully"
        return 0
    fi
}

# Step 3: Execute protocol steps
execute_protocol() {
    print_step "Starting protocol execution..."
    echo ""
    
    local MAX_STEPS=20
    local STEP_COUNT=0
    local PROTOCOL_COMPLETE=false
    local CHALLENGE_DETECTED=false
    
    for i in $(seq 1 $MAX_STEPS); do
        echo "═══════════════════════════════════════════════"
        print_info "Round $i"
        echo "═══════════════════════════════════════════════"
        
        # Prover next step
        print_step "Prover executing next step..."
        PROVER_RESPONSE=$(curl -s -X POST http://localhost:8081/api/v1/next_step \
            -H "Content-Type: application/json" \
            -d "{\"setup_uuid\": \"$SETUP_UUID\"}")
        
        if echo "$PROVER_RESPONSE" | grep -q "executed_step"; then
            PROVER_STEP=$(echo "$PROVER_RESPONSE" | jq -r '.executed_step')
            PROVER_TX=$(echo "$PROVER_RESPONSE" | jq -r '.tx_id // "N/A"')
            print_status "Prover executed: $PROVER_STEP"
            if [ "$PROVER_TX" != "N/A" ] && [ "$PROVER_TX" != "null" ]; then
                print_result "Transaction: ${PROVER_TX:0:16}..."
            fi
            
            # Mine block to confirm transaction
            print_info "Mining block..."
            docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest \
                -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd -rpcwallet=testwallet \
                generatetoaddress 1 $(docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest \
                -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd -rpcwallet=testwallet getnewaddress) > /dev/null
            print_status "Block mined"
            ((STEP_COUNT++))
        else
            if echo "$PROVER_RESPONSE" | grep -q "No more steps"; then
                print_info "Prover: No more steps to execute"
            else
                print_info "Prover response: $(echo "$PROVER_RESPONSE" | jq -c '.detail // .' 2>/dev/null)"
            fi
        fi
        
        echo ""
        sleep 2
        
        # Verifier next step
        print_step "Verifier executing next step..."
        VERIFIER_RESPONSE=$(curl -s -X POST http://localhost:8080/api/v1/next_step \
            -H "Content-Type: application/json" \
            -d "{\"setup_uuid\": \"$SETUP_UUID\"}")
        
        if echo "$VERIFIER_RESPONSE" | grep -q "executed_step"; then
            VERIFIER_STEP=$(echo "$VERIFIER_RESPONSE" | jq -r '.executed_step')
            VERIFIER_TX=$(echo "$VERIFIER_RESPONSE" | jq -r '.tx_id // "N/A"')
            
            # Check if this is trigger_protocol (verification complete)
            if [ "$VERIFIER_STEP" = "trigger_protocol" ]; then
                PROTOCOL_COMPLETE=true
                echo ""
                echo "╔═══════════════════════════════════════════════╗"
                echo "║     ✨ PROTOCOL COMPLETED SUCCESSFULLY! ✨     ║"
                echo "╚═══════════════════════════════════════════════╝"
                print_status "Verification Result: HASHES MATCH"
                print_info "No challenge needed - computation is correct"
                print_result "Total steps executed: $STEP_COUNT"
                break
            fi
            
            print_status "Verifier executed: $VERIFIER_STEP"
            if [ "$VERIFIER_TX" != "N/A" ] && [ "$VERIFIER_TX" != "null" ]; then
                print_result "Transaction: ${VERIFIER_TX:0:16}..."
            fi
            
            # Mine block
            print_info "Mining block..."
            docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest \
                -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd -rpcwallet=testwallet \
                generatetoaddress 1 $(docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest \
                -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd -rpcwallet=testwallet getnewaddress) > /dev/null
            print_status "Block mined"
            ((STEP_COUNT++))
        else
            # Check for protocol completion or challenge
            if echo "$VERIFIER_RESPONSE" | grep -q "both hashes are equal"; then
                PROTOCOL_COMPLETE=true
                echo ""
                echo "╔═══════════════════════════════════════════════╗"
                echo "║     ✨ PROTOCOL COMPLETED SUCCESSFULLY! ✨     ║"
                echo "╚═══════════════════════════════════════════════╝"
                print_status "Computation verified - hashes match!"
                print_info "No challenge needed"
                print_result "Total steps executed: $STEP_COUNT"
                break
            elif echo "$VERIFIER_RESPONSE" | grep -q "challenge"; then
                CHALLENGE_DETECTED=true
                echo ""
                echo "╔═══════════════════════════════════════════════╗"
                echo "║         ⚠️  CHALLENGE INITIATED! ⚠️           ║"
                echo "╚═══════════════════════════════════════════════╝"
                print_error "Computation mismatch detected!"
                echo "$VERIFIER_RESPONSE" | jq '.'
                print_info "Challenge protocol will continue..."
                # Continue with challenge resolution
            else
                if echo "$VERIFIER_RESPONSE" | grep -q "No more steps"; then
                    print_info "Verifier: No more steps to execute"
                else
                    print_info "Verifier response: $(echo "$VERIFIER_RESPONSE" | jq -c '.detail // .' 2>/dev/null)"
                fi
            fi
        fi
        
        echo ""
        sleep 2
        
        # Check if both parties have no more steps
        if ! echo "$PROVER_RESPONSE" | grep -q "executed_step" && \
           ! echo "$VERIFIER_RESPONSE" | grep -q "executed_step"; then
            if [ "$PROTOCOL_COMPLETE" = false ]; then
                print_info "Protocol execution completed"
                print_result "Total steps executed: $STEP_COUNT"
            fi
            break
        fi
    done
    
    # Final summary
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "Protocol Execution Summary"
    echo "═══════════════════════════════════════════════"
    print_info "Setup UUID: $SETUP_UUID"
    print_info "Input: $INPUT_HEX"
    print_info "Total rounds: $i"
    print_info "Total steps executed: $STEP_COUNT"
    
    if [ "$PROTOCOL_COMPLETE" = true ]; then
        print_status "Result: SUCCESS - Computation verified"
    elif [ "$CHALLENGE_DETECTED" = true ]; then
        print_error "Result: CHALLENGE - Dispute resolution needed"
    else
        print_info "Result: Protocol ended normally"
    fi
}

# Step 4: Check final state
check_final_state() {
    echo ""
    print_step "Checking final state..."
    
    # Check prover state
    print_info "Prover state:"
    docker exec bitvmx-prover-backend-1 bash -c "
        if [ -f /bitvmx-backend/prover_files/$SETUP_UUID/bitvmx_protocol_verifier_dto.json ]; then
            cat /bitvmx-backend/prover_files/$SETUP_UUID/bitvmx_protocol_verifier_dto.json | \
            jq '{
                last_confirmed_step: .last_confirmed_step,
                last_confirmed_step_tx_id: .last_confirmed_step_tx_id
            }' 2>/dev/null || echo 'Unable to parse state'
        else
            echo 'No state file found'
        fi
    "
    
    # Check verifier state
    print_info "Verifier state:"
    docker exec bitvmx-verifier-backend-1 bash -c "
        if [ -f /bitvmx-backend/verifier_files/$SETUP_UUID/bitvmx_protocol_verifier_dto.json ]; then
            cat /bitvmx-backend/verifier_files/$SETUP_UUID/bitvmx_protocol_verifier_dto.json | \
            jq '{
                last_confirmed_step: .last_confirmed_step,
                published_halt_hash: .published_halt_hash,
                input_hex: .input_hex
            }' 2>/dev/null || echo 'Unable to parse state'
        else
            echo 'No state file found'
        fi
    "
}

# Main execution
main() {
    # Step 1: Prepare environment
    copy_elf_file
    echo ""
    
    # Step 2: Provide input
    if ! provide_input; then
        print_error "Failed to provide input. Exiting."
        exit 1
    fi
    echo ""
    
    # Step 3: Execute protocol
    execute_protocol
    
    # Step 4: Check final state
    check_final_state
    
    echo ""
    echo "═══════════════════════════════════════════════"
    print_status "Protocol execution script completed"
    echo "═══════════════════════════════════════════════"
}

# Run main function
main