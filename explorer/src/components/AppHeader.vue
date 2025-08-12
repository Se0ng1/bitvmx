<template>
  <v-app-bar>
    <RouterLink to="/protocol">
      <img src="@/assets/bitvmx.jpg" alt="BitVMX Logo" class="logo" />
    </RouterLink>
    <v-toolbar-title>BitVMX explorer</v-toolbar-title>
    <v-spacer></v-spacer>
    <div class="nav-links">
      <RouterLink to="/protocol" :class="{ 'router-link-active': $route.path === '/protocol' }"
        >Protocol</RouterLink
      >
    </div>
    <div class="nav-dark-toggle">
      <DarkModeToggle />
    </div>
  </v-app-bar>
</template>

<script setup>
import DarkModeToggle from './DarkModeToggle.vue'
import { useRoute } from 'vue-router'

const $route = useRoute()
</script>

<style scoped lang="sass">
.nav-dark-toggle
  margin-right: 10px
  display: flex

.v-app-bar
  background-color: rgba(var(--v-theme-background), 0.8)
  color: var(--v-theme-on-background)
  display: flex
  align-items: center

.logo
  height: 40px
  margin-right: 10px
  margin-left: 10px

.nav-links
  display: flex
  gap: 20px
  margin-right: 10px

  a
    text-decoration: none
    color: var(--v-theme-on-background)
    font-weight: 500
    &:hover
      color: rgba(25, 118, 210, 1)
    &.router-link-active
      color: rgba(25, 118, 210, 1)

.network-dropdown
  margin-left: 10px
  margin-right: 10px
</style>
