<script setup>
import { ref, onMounted } from 'vue'
import { decryptWinternitzWitness } from '@/lib/witness'

const props = defineProps({
  witness: {
    type: Array,
    required: true
  }
})

const signatures = ref([])
const code = ref('')
const controlBlock = ref()
const winternitzValues = ref([])
const dialog = ref(false)
const signaturesDialog = ref(false)

onMounted(() => {
  processWitness()
})

const processWitness = () => {
  let witnessLength = props.witness.length
  controlBlock.value = props.witness[witnessLength - 1]
  code.value = props.witness[witnessLength - 2]
  let witness = props.witness.slice(0, witnessLength - 2)
  let init = []
  let end = []
  let index = 0
  while (index < witness.length && witness[index].length === 128) {
    init.push(witness[index])
    index += 1
  }
  index = witness.length - 1
  while (index >= 0 && witness[index].length === 128) {
    end.unshift(witness[index])
    index -= 1
  }
  if (init.length > end.length) {
    signatures.value = init
    witness = witness.slice(init.length, witness.length)
  } else {
    signatures.value = end
    witness = witness.slice(0, witness.length - end.length)
  }
  winternitzValues.value = witness
}

const showDialog = () => {
  dialog.value = true
}

const showSignaturesDialog = () => {
  signaturesDialog.value = true
}
</script>

<template>
  <v-expansion-panels>
    <v-expansion-panel>
      <v-expansion-panel-title focusable="true">
        Witness Information <v-spacer></v-spacer
        ><v-btn color="primary" @click.stop="showDialog">Code</v-btn
        ><v-btn color="primary" @click.stop="showSignaturesDialog" class="signatures-button"
          >Signatures</v-btn
        >
      </v-expansion-panel-title>
      <v-expansion-panel-text>
        <ul>
          <li
            v-for="(item, index) in decryptWinternitzWitness(winternitzValues, code)"
            :key="index"
          >
            {{ item.value }} <span style="color: grey; font-size: smaller">{{ item.hash }}</span>
          </li>
        </ul>
      </v-expansion-panel-text>
    </v-expansion-panel>
  </v-expansion-panels>
  <v-dialog v-model="dialog" max-width="500">
    <v-card>
      <v-card-title>Bitcoin script binary code</v-card-title>
      <v-card-text>{{ code }}</v-card-text>
      <v-card-actions>
        <v-spacer></v-spacer>
        <v-btn color="primary" variant="flat" @click="dialog = false">Close</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
  <v-dialog v-model="signaturesDialog" max-width="500">
    <v-card>
      <v-card-title>Signatures</v-card-title>
      <v-card-text>
        <ul>
          <li v-for="(signature, index) in signatures" :key="index">{{ signature }}</li>
        </ul>
      </v-card-text>
      <v-card-actions>
        <v-spacer></v-spacer>
        <v-btn color="primary" variant="flat" @click="signaturesDialog = false">Close</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<style scoped>
.v-expansion-panel {
  margin-top: 15px;
  margin-bottom: 15px;
}
.signatures-button {
  margin-left: 20px;
  margin-right: 20px;
}
</style>
