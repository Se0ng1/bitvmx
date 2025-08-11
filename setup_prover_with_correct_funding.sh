#!/bin/bash

# Script to setup prover with correct funding address

set -e

echo "==============================================="
echo "Prover Setup with Correct Funding"
echo "==============================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Configuration
SECRET_ORIGIN_OF_FUNDS="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
PROVER_DESTINATION="bcrt1ql3e9pgs3mmwuwrh95fecme0s0qtn2880hlwwpw"
PROVER_SIG_PUBKEY="0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"

# Step 1: Get the actual address from secret_origin_of_funds
print_info "Deriving address from secret_origin_of_funds..."
FUNDING_ADDRESS=$(docker exec bitvmx-prover-backend-1 python3 -c "
from bitcoinutils.setup import setup
from bitcoinutils.keys import PrivateKey
setup('regtest')
private_key = PrivateKey(secret_exponent=0x${SECRET_ORIGIN_OF_FUNDS})
print(private_key.get_public_key().get_segwit_address().to_string())
" 2>/dev/null || echo "bcrt1qngw83fg8dz0k749cg7k3emc7v98wy0c7azaa6h")

print_status "Funding address: $FUNDING_ADDRESS"

# Step 2: Create funding transaction to that address
print_info "Creating funding transaction..."
TX_ID=$(docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest \
    -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd -rpcwallet=testwallet \
    sendtoaddress $FUNDING_ADDRESS 0.02)

print_status "Funding transaction created: $TX_ID"

# Step 3: Mine a block to confirm
print_info "Mining block to confirm transaction..."
MINING_ADDRESS=$(docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest \
    -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd -rpcwallet=testwallet \
    getnewaddress)
docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest \
    -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd -rpcwallet=testwallet \
    generatetoaddress 1 $MINING_ADDRESS > /dev/null

print_status "Transaction confirmed"

# Step 4: Get the output index
print_info "Finding output index..."
OUTPUT_INDEX=$(docker exec bitvmx-bitcoin-regtest bitcoin-cli -regtest \
    -rpcuser=myuser -rpcpassword=SomeDecentp4ssw0rd \
    getrawtransaction $TX_ID 1 | \
    jq ".vout[] | select(.scriptPubKey.address == \"$FUNDING_ADDRESS\") | .n")

print_status "Output index: $OUTPUT_INDEX"

# Step 5: Call verifier setup first
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
    echo "Verifier response:"
    echo "$VERIFIER_RESPONSE" | jq '.'
    VERIFIER_PUBLIC_KEY=$(echo "$VERIFIER_RESPONSE" | jq -r '.public_key')
    VERIFIER_SIG_PUBLIC_KEY=$(echo "$VERIFIER_RESPONSE" | jq -r '.verifier_signature_public_key')
    VERIFIER_DEST_ADDRESS=$(echo "$VERIFIER_RESPONSE" | jq -r '.verifier_destination_address')
    print_info "Verifier public key: $VERIFIER_PUBLIC_KEY"
    print_info "Verifier signature public key: $VERIFIER_SIG_PUBLIC_KEY"
    print_info "Verifier destination address: $VERIFIER_DEST_ADDRESS"
else
    print_error "Verifier setup failed"
    echo "$VERIFIER_RESPONSE" | jq '.'
    exit 1
fi

# Step 6: Call prover setup
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
    echo "$PROVER_RESPONSE" | jq
fi

echo ""
echo "==============================================="
print_status "Both Verifier and Prover setup complete!"
echo "==============================================="
echo ""
echo "Verifier Setup:"
print_info "Public Key: $VERIFIER_PUBLIC_KEY"
print_info "Signature Public Key: $VERIFIER_SIG_PUBLIC_KEY"
print_info "Destination Address: $VERIFIER_DEST_ADDRESS"
echo ""
echo "Prover Setup:"
print_info "Setup UUID: ${SETUP_UUID:-N/A}"
print_info "Funding TX: $TX_ID"
print_info "Funding Index: $OUTPUT_INDEX"
print_info "Funding Address: $FUNDING_ADDRESS"
echo ""