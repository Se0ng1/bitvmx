<template>
  <v-switch
    v-model="isDarkMode"
    @change="toggleDarkMode"
    hide-details=""
    class="dark-toggle"
  ></v-switch>
</template>

<script setup>
import { ref, watch } from 'vue'
import { useTheme } from 'vuetify'

const isDarkMode = ref(false)
const theme = useTheme()

const toggleDarkMode = () => {
  theme.global.name.value = isDarkMode.value ? 'dark' : 'light'
}

// Watch for changes in isDarkMode and update the theme accordingly
watch(isDarkMode, (newValue) => {
  toggleDarkMode()
})
</script>

<style scoped>
.dark-toggle {
  margin-left: 10px;
  margin-right: 10px;
}
.v-messages {
  min-height: flex;
}
</style>
