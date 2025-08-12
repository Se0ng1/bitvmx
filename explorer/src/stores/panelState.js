import { defineStore } from 'pinia'

export const usePanelStateStore = defineStore('panelState', {
  state: () => ({
    panelStates: {}
  }),
  actions: {
    setPanelState(txid, index, state) {
      if (!this.panelStates[txid]) {
        this.panelStates[txid] = {}
      }
      this.panelStates[txid][index] = state
    },
    getPanelState(txid, index) {
      return this.panelStates[txid]?.[index] || false
    }
  }
})
