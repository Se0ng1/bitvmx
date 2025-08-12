<script setup>
import { ref, onMounted, watch } from 'vue' // Added watch import
import { fetchProtocolData } from '@/lib/transactions'
import { useTransactionStore } from '@/stores/transactions'
import { useNetworkStore } from '@/stores/network' // Import the network store

const props = defineProps({
  transactionId: {
    type: String,
    default: ''
  }
})

const transactionStore = useTransactionStore()
const networkStore = useNetworkStore() // Access the network store
const inputValue = ref(props.transactionId || transactionStore.txId) // Initialize with prop or store value
const errorMessage = ref('')
const isLoading = ref(false) // Loading state
const emit = defineEmits(['submit', 'clear']) // Added 'clear' event

const isValidTxId = (txid) => {
  const txidRegex = /^[a-fA-F0-9]{64}$/
  return txidRegex.test(txid)
}

const handleSubmit = async () => {
  emit('clear') // Emit clear event to reset transactionData
  if (isValidTxId(inputValue.value)) {
    isLoading.value = true // Set loading to true
    try {
      const transactions = await fetchProtocolData(inputValue.value)
      emit('submit', transactions)
      errorMessage.value = ''
      transactionStore.setTxId(inputValue.value) // Save the transaction ID to the store
    } catch (error) {
      errorMessage.value = error.message
      emit('submit', null)
    } finally {
      isLoading.value = false // Reset loading state
    }
  } else {
    errorMessage.value = 'Invalid Bitcoin transaction ID format'
    emit('submit', null)
  }
}

const setTransactionId = (txid) => {
  inputValue.value = txid // Set inputValue to the provided txid
  transactionStore.setTxId(txid) // Save the transaction ID to the store
  handleSubmit() // Call handleSubmit after setting the transaction ID
}

// Keep the onMounted behavior
onMounted(() => {
  if (props.transactionId) {
    setTransactionId(props.transactionId)
  } else {
    inputValue.value = transactionStore.txId // Set inputValue to the transaction ID on mount
  }
})

// Watch for network changes and reset txId
watch(
  () => networkStore.networkId,
  (newNetwork) => {
    transactionStore.setTxId('') // Clear the transaction ID when network changes
    inputValue.value = '' // Clear the input value
    emit('clear') // Emit clear event to reset transactionData in the parent component
  }
)

// Watch for changes in the transactionId prop
watch(
  () => props.transactionId,
  (newTransactionId) => {
    if (newTransactionId && newTransactionId !== inputValue.value) {
      setTransactionId(newTransactionId)
    }
  }
)
</script>

<template>
  <div class="protocol-input">
    <v-text-field
      v-model="inputValue"
      label="Enter a Bitcoin transaction ID that is part of the protocol"
      outlined
    />
    <v-btn @click="handleSubmit" color="primary">Submit</v-btn>
    <p v-if="errorMessage" class="error-message">{{ errorMessage }}</p>
    <div v-if="isLoading" class="d-flex justify-center">
      <v-progress-circular indeterminate color="primary" size="64"></v-progress-circular>
    </div>
    <div v-if="!isLoading && (!inputValue || inputValue === '')" class="empty-txid-message">
      <div v-if="networkStore.networkId === 'mainnet'">
        <v-btn
          @click="
            setTransactionId('315fdd660aec892f452791827e5e961283851df411c1132e5544505d9d855279')
          "
          color="secondary"
          class="full-width-button"
          >Load execution challenge example</v-btn
        >
      </div>
      <div v-else-if="networkStore.networkId === 'testnet'">
        <v-btn
          @click="
            setTransactionId('0cffcabff6fd8c4689615dc3ead360630bb243040d43f9074aca06b728323a00')
          "
          color="secondary"
          class="full-width-button"
          >Load execution challenge example</v-btn
        >
      </div>
      <div v-else-if="networkStore.networkId === 'mutinynet'">
        <v-row>
          <v-col cols="12" md="6" lg="3">
            <v-btn
              @click="
                setTransactionId('034c3c76bab34f7a04dec6fd6023126f999b9dd27c7dc16c6758478dc52df9fe')
              "
              color="secondary"
              class="full-width-button"
              >Load execution challenge example 1</v-btn
            >
          </v-col>
          <v-col cols="12" md="6" lg="3">
            <v-btn
              @click="
                setTransactionId('bcef1e72c5c26ffb6e53876f265a0408f1a2af3fb35c3e214b9f460c88c8b9fb')
              "
              color="secondary"
              class="full-width-button"
              >Load execution challenge example 2</v-btn
            >
          </v-col>
          <v-col cols="12" md="6" lg="3">
            <v-btn
              @click="
                setTransactionId('be2e881a0e223c3d6a6e6cb56bdb17cc33b1ec96c860408db4b787fd908da748')
              "
              color="secondary"
              class="full-width-button"
              >Load wrong hash challenge</v-btn
            >
          </v-col>
          <v-col cols="12" md="6" lg="3">
            <v-btn
              @click="
                setTransactionId('4b1c5b70ad1b6769dbe668e18481b6437d7ebb78fbe7eac6def5f1c9330e7c07')
              "
              color="secondary"
              class="full-width-button"
              >Load wrong read value challenge</v-btn
            >
          </v-col>
        </v-row>
      </div>
      <div v-else-if="networkStore.networkId === 'regtest'">
        <p>Enter a transaction ID from your local regtest node</p>
      </div>
    </div>
  </div>
</template>

<style scoped>
.v-progress-circular {
  margin-top: 40px;
  margin-bottom: 40px;
}

.protocol-input {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-top: 20px;
}

input {
  padding: 5px;
}

.error-message {
  color: rgb(var(--v-theme-error));
}

.full-width-button {
  width: 100%;
}
</style>
