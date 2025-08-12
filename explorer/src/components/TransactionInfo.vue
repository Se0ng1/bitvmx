<script setup>
import { ref, computed } from 'vue'
import WitnessInfo from './WitnessInfo.vue'
import { fetchTransactionURL } from '@/lib/transactions'
import CryptoJS from 'crypto-js'

const props = defineProps({
  transactionData: {
    type: Object,
    required: true
  },
  position: {
    type: Number,
    required: false,
    default: null,
    validator: (value) => value === 0 || value === 1 || value === null
  },
  index: {
    type: Number,
    required: false,
    default: null
  }
})

const processedWitness = (input) => {
  if (!input.witness) return []

  let witness = input.witness.map((item) => (item === '' ? '00' : item))

  return witness
}

const componentStyle = computed(() => {
  const className =
    props.position === null
      ? 'funding-transaction'
      : props.position === 0
        ? 'prover-transaction'
        : 'verifier-transaction'
  return { class: className }
})

const hashCalculatorDialog = ref(false)
const hashInput = ref('')

const openHashCalculatorDialog = () => {
  hashCalculatorDialog.value = true
}

const calculateHash = () => {
  // Assuming there's a function to calculate the hash based on the input
  // This is a placeholder for the actual hash calculation logic
  console.log(`Calculating hash for input: ${hashInput.value}`)
  hashInput.value = CryptoJS.enc.Hex.stringify(
    CryptoJS.RIPEMD160(CryptoJS.SHA256(CryptoJS.enc.Hex.parse(hashInput.value)))
  )
}
</script>

<template>
  <div class="transaction-info" :class="componentStyle.class" :style="{ overflowX: 'auto' }">
    <v-expansion-panels>
      <v-expansion-panel>
        <v-expansion-panel-title focusable="true">
          <span style="user-select: all"
            >Transaction id {{ props.index !== null ? ` ${props.index + 1}` : '' }}:
            {{ transactionData.txid }}</span
          >
          <v-spacer></v-spacer>
          <v-btn
            variant="text"
            class="open-detail-button"
            @click.stop="openInNewTab(transactionData.txid)"
            >Open detail</v-btn
          >
        </v-expansion-panel-title>
        <v-expansion-panel-text>
          <div v-if="Object.keys(transactionData).length > 0">
            <v-row>
              <v-col cols="12" sm="6" md="3">
                <p><strong>Size:</strong> {{ transactionData.size }} B</p>
              </v-col>
              <v-col cols="12" sm="6" md="3">
                <p><strong>Virtual size:</strong> {{ transactionData.weight / 4 }} vB</p>
              </v-col>
              <v-col cols="12" sm="6" md="3">
                <p><strong>Weight:</strong> {{ transactionData.weight }}</p>
              </v-col>
              <v-col cols="12" sm="6" md="3">
                <p><strong>Lock Time:</strong> {{ transactionData.locktime }}</p>
              </v-col>
            </v-row>
            <h4>Inputs</h4>
            <ul style="list-style-type: none">
              <li v-for="(input, index) in transactionData.vin" :key="index">
                <v-expansion-panels>
                  <v-expansion-panel>
                    <v-expansion-panel-title focusable="true">
                      <p>Transaction id: {{ input.txid }}</p>
                      <v-spacer></v-spacer>
                      <v-btn
                        variant="text"
                        class="open-detail-button"
                        @click.stop="openInNewTab(input.txid)"
                        >Open detail</v-btn
                      >
                    </v-expansion-panel-title>
                    <v-expansion-panel-text>
                      <v-row>
                        <v-col cols="12" sm="6">
                          <p>Address: {{ input.prevout.scriptpubkey_address }}</p>
                        </v-col>
                        <v-col cols="12" sm="6">
                          <p>Type: {{ input.prevout.scriptpubkey_type }}</p>
                        </v-col>
                      </v-row>
                      <v-row>
                        <v-col cols="12" sm="6">
                          <p>Vout: {{ input.vout }}</p>
                        </v-col>
                        <v-col cols="12" sm="6">
                          <p>Amount: {{ input.prevout.value }}</p>
                        </v-col>
                      </v-row>
                      <div v-if="input.prevout.scriptpubkey_type === 'v1_p2tr'">
                        <WitnessInfo :witness="input.witness" />
                      </div>
                      <v-expansion-panels v-if="input.witness && input.witness.length > 0">
                        <v-expansion-panel>
                          <v-expansion-panel-title focusable="true">
                            Raw witness<v-spacer></v-spacer
                            ><v-btn
                              variant="text"
                              class="open-detail-button"
                              @click.stop="openHashCalculatorDialog"
                              >Open hash calculator</v-btn
                            >
                          </v-expansion-panel-title>
                          <v-expansion-panel-text>
                            <div class="witness-box">
                              <ul style="list-style-type: none">
                                <li v-for="(item, wIndex) in input.witness" :key="wIndex">
                                  <code>{{ item === '' ? '00' : item }}</code>
                                </li>
                              </ul>
                            </div>
                          </v-expansion-panel-text>
                        </v-expansion-panel>
                      </v-expansion-panels>
                    </v-expansion-panel-text>
                  </v-expansion-panel>
                </v-expansion-panels>
              </li>
            </ul>
            <h4>Outputs:</h4>
            <ul>
              <li v-for="(output, index) in transactionData.vout" :key="index">
                <p>Value: {{ output.value }} BTC</p>
                <p>Script Pub Key Type: {{ output.scriptpubkey_type }}</p>
                <p>Address: {{ output.scriptpubkey_address }}</p>
              </li>
            </ul>
          </div>
        </v-expansion-panel-text>
      </v-expansion-panel>
    </v-expansion-panels>
  </div>
  <v-dialog v-model="hashCalculatorDialog" max-width="500">
    <v-card>
      <v-card-title>Hash Calculator</v-card-title>
      <v-card-text>
        <v-text-field
          v-model="hashInput"
          label="Input for hash calculation"
          hide-details=""
        ></v-text-field>
      </v-card-text>
      <v-card-actions>
        <v-btn class="dialog-button" color="primary" variant="flat" @click="calculateHash"
          >Calculate Hash</v-btn
        >
        <v-spacer></v-spacer>
        <v-btn
          class="dialog-button"
          color="text"
          variant="flat"
          @click="hashCalculatorDialog = false"
          >Close</v-btn
        >
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script>
function openInNewTab(txid) {
  const url = fetchTransactionURL(txid)
  const win = window.open(url, '_blank')
  win.focus()
}
</script>

<style scoped>
.v-expansion-panel-title {
  overflow-x: auto;
}

.v-expansion-panel-text {
  overflow-x: auto;
}

ul {
  padding-left: 20px;
}

li {
  margin-bottom: 10px;
}

.witness-box {
  max-height: 150px;
  overflow: auto;
  border: 1px solid;
  padding: 5px;
}

.witness-box ul {
  margin: 0;
  padding-left: 20px;
  white-space: nowrap;
}

.witness-box li {
  margin-bottom: 5px;
}

.witness-box code {
  font-family: monospace;
  word-break: keep-all;
}

.transaction-info {
  padding: 10px;
  margin-top: 15px;
  margin-bottom: 15px;
}

.funding-transaction {
  background-color: rgb(var(--v-theme-funding_background));
}

.prover-transaction {
  margin-right: 60px;
  background-color: rgb(var(--v-theme-prover_background));
}

.verifier-transaction {
  margin-left: 60px;
  background-color: rgb(var(--v-theme-verifier_background));
}

.open-detail-button {
  margin-right: 20px;
}

.dialog-button {
  margin: 15px;
}
</style>
