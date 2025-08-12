import { defineStore } from 'pinia'
import { useTransactionStore } from '@/stores/transactions' // Import the transaction store
import { updateNetwork } from '@/lib/transactions'

export const useNetworkStore = defineStore('network', {
  state: () => ({
    networkId: localStorage.getItem('networkId') || '' // Initialize with an empty string or a default value
  }),
  actions: {
    async setNetworkId(newNetworkId) {
      this.networkId = newNetworkId
      localStorage.setItem('networkId', newNetworkId) // Save the network ID to local storage
      // Erase txId when network changes
      const transactionStore = useTransactionStore()
      transactionStore.setTxId('') // Clear the transaction ID
      // Update network functions
      await updateNetwork(newNetworkId)
    }
  }
})
