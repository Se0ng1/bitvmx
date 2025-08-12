<template>
  <v-responsive class="mx-auto main-container" max-width="1200">
    <v-row>
      <v-col cols="12">
        <v-card
          append-icon="mdi-open-in-new"
          class="py-4 white-paper-card"
          color="primary"
          href="https://arxiv.org/abs/2405.06842"
          prepend-icon="mdi-file-document"
          rel="noopener noreferrer"
          rounded="lg"
          subtitle="Read our white paper for an in-depth look at BitVMX"
          target="_blank"
          title="White Paper"
          variant="elevated"
        >
          <v-overlay opacity=".06" scrim="white" contained model-value persistent />
        </v-card>
      </v-col>
    </v-row>

    <v-row class="mt-6">
      <v-col cols="12">
        <h2 class="text-h5 mb-3">Demo</h2>
        <v-card
          append-icon="mdi-play-circle"
          class="py-4"
          color="surface-variant"
          href="https://www.youtube.com/watch?v=fMsRJbzwrEw"
          prepend-icon="mdi-video"
          rel="noopener noreferrer"
          rounded="lg"
          subtitle="Watch our video demonstration of BitVMX in action"
          target="_blank"
          title="Video Demo"
          variant="text"
        >
          <v-overlay opacity=".06" scrim="primary" contained model-value persistent />
        </v-card>
      </v-col>
    </v-row>

    <v-row class="mt-6">
      <v-col cols="12">
        <h2 class="text-h5 mb-3">Articles</h2>
      </v-col>
      <v-col cols="12">
        <v-card
          append-icon="mdi-open-in-new"
          class="py-4"
          color="surface-variant"
          href="https://bitvmx.org/knowledge/zero-knowledge-proof-verification-on-bitcoin"
          prepend-icon="mdi-newspaper"
          rel="noopener noreferrer"
          rounded="lg"
          subtitle="Martin Jonas"
          target="_blank"
          title="Zero knowledge proof verification on Bitcoin"
          variant="text"
        >
          <v-overlay opacity=".06" scrim="primary" contained model-value persistent />
        </v-card>
      </v-col>
      <v-col cols="12">
        <v-card
          append-icon="mdi-open-in-new"
          class="py-4"
          color="surface-variant"
          href="https://bitvmx.org/knowledge/optimizing-algorithms-for-bitcoin-script"
          prepend-icon="mdi-newspaper"
          rel="noopener noreferrer"
          rounded="lg"
          subtitle="Martin Jonas 1/3"
          target="_blank"
          title="Optimizing algorithms for Bitcoin Script "
          variant="text"
        >
          <v-overlay opacity=".06" scrim="primary" contained model-value persistent />
        </v-card>
      </v-col>
      <v-col cols="12">
        <v-card
          append-icon="mdi-open-in-new"
          class="py-4"
          color="surface-variant"
          href="https://bitvmx.org/knowledge/optimizing-algorithms-for-bitcoin-script-part-2"
          prepend-icon="mdi-newspaper"
          rel="noopener noreferrer"
          rounded="lg"
          subtitle="Martin Jonas 2/3"
          target="_blank"
          title="Optimizing algorithms for Bitcoin Script"
          variant="text"
        >
          <v-overlay opacity=".06" scrim="primary" contained model-value persistent />
        </v-card>
      </v-col>
      <v-col cols="12">
        <v-card
          append-icon="mdi-open-in-new"
          class="py-4"
          color="surface-variant"
          href="https://bitvmx.org/knowledge/optimizing-algorithms-for-bitcoin-script-part-3"
          prepend-icon="mdi-newspaper"
          rel="noopener noreferrer"
          rounded="lg"
          subtitle="Martin Jonas 3/3"
          target="_blank"
          title="Optimizing algorithms for Bitcoin Script"
          variant="text"
        >
          <v-overlay opacity=".06" scrim="primary" contained model-value persistent />
        </v-card>
      </v-col>
    </v-row>
  </v-responsive>
</template>

<script setup>
//
</script>

<style scoped>
.main-container {
  padding: 30px;
}

.white-paper-card {
  background-color: var(--v-primary-base);
  color: white;
}
</style>
