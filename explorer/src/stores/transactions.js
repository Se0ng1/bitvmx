import { defineStore } from 'pinia'

export const useTransactionStore = defineStore('transactions', {
  state: () => ({
    txId: localStorage.getItem('txId') || '' // Initialize with an empty string or a default value
  }),
  actions: {
    setTxId(newTxId) {
      this.txId = newTxId
      localStorage.setItem('txId', newTxId) // Save the transaction ID to local storage
    }
  }
})
