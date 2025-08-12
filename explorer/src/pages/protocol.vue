<template>
  <div class="protocol">
    <v-row>
      <v-col cols="12" md="6">
        <h1>Protocol explorer</h1>
      </v-col>
      <v-col cols="12" md="6">
        <v-select
          v-model="selectedNetwork"
          :items="networks"
          label="Network"
          @update:modelValue="setNetwork"
          class="network-dropdown"
        />
      </v-col>
    </v-row>
    <ProtocolInput
      :transactionId="transactionId"
      @submit="handleProtocolSubmit"
      @clear="clearTransactionData"
    />

    <template v-if="transactionData && transactionData.length > 0">
      <v-row>
        <v-col cols="12" md="4">
          <div class="role-legend role-funding">Funding</div>
        </v-col>
        <v-col cols="12" md="4">
          <div class="role-legend role-prover">Prover</div>
        </v-col>
        <v-col cols="12" md="4">
          <div class="role-legend role-verifier">Verifier</div>
        </v-col>
      </v-row>
    </template>
    <TransactionInfo
      v-if="transactionData && transactionData.length > 0"
      :transactionData="transactionData[0]"
      :position="null"
    />
    <template v-if="transactionData && transactionData.length > 0">
      <TransactionInfo
        v-for="(transaction, index) in transactionData.slice(1)"
        :key="index"
        :transactionData="transaction"
        :position="index % 2"
        :index="index"
      />
    </template>
  </div>
</template>

<script setup>
import { ref, onMounted, watch } from 'vue'
import ProtocolInput from '@/components/ProtocolInput.vue'
import TransactionInfo from '@/components/TransactionInfo.vue'
import { useNetworkStore } from '@/stores/network'
import { useRouter, useRoute } from 'vue-router'
import { updateNetwork } from '@/lib/transactions'

const networkStore = useNetworkStore()
const router = useRouter()
const route = useRoute()

const transactionData = ref(null)
const selectedNetwork = ref('')
const transactionId = ref('')

onMounted(async () => {
  const networkParam = route.query.network
  const txIdParam = route.query.txid

  if (networkParam && ['mainnet', 'testnet', 'mutinynet', 'regtest'].includes(networkParam)) {
    await setNetwork(networkParam)
  } else {
    const savedNetworkId = networkStore.networkId || 'mutinynet'
    await setNetwork(savedNetworkId)
  }

  if (txIdParam && typeof txIdParam === 'string') {
    transactionId.value = txIdParam
  }
})

const networks = ['mainnet', 'testnet', 'mutinynet', 'regtest']

const updateQueryParams = () => {
  const query = { network: selectedNetwork.value }
  if (transactionData.value !== null && transactionData.value !== '') {
    query['txid'] = transactionData.value[0]['txid']
  } else if (transactionId.value !== null && transactionId.value !== '') {
    query['txid'] = transactionId.value
  }
  router.replace({ query })
}

const handleProtocolSubmit = (data) => {
  transactionData.value = data
  if (data && data.length > 0) {
    const txid = data[0].txid
    updateQueryParams()
  }
}

const clearTransactionData = () => {
  transactionData.value = null
  const { txid, ...restQuery } = route.query
  updateQueryParams()
}

const setNetwork = async (network) => {
  await updateNetwork(network)
  networkStore.setNetworkId(network)
  selectedNetwork.value = network
  updateQueryParams()
}

watch(
  () => route.query.network,
  async (newNetwork) => {
    if (newNetwork && ['mainnet', 'testnet', 'mutinynet', 'regtest'].includes(newNetwork)) {
      await setNetwork(newNetwork)
    }
  }
)
</script>

<style scoped>
.protocol {
  margin: 0 auto;
  padding: 20px;
}

.role-legend {
  text-align: center;
  margin: 10px;
  margin-top: 20px;
  margin-bottom: 5px;
  padding: 10px;
}

.role-funding {
  background-color: rgb(var(--v-theme-funding_background));
}

.role-prover {
  background-color: rgb(var(--v-theme-prover_background));
}

.role-verifier {
  background-color: rgb(var(--v-theme-verifier_background));
}

h1 {
  margin-bottom: 20px;
}

.empty-txid-message {
  color: red; /* Change to your preferred color */
  text-align: center;
  margin-top: 20px;
}
</style>
