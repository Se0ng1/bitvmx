/**
 * plugins/vuetify.js
 *
 * Framework documentation: https://vuetifyjs.com`
 */

// Styles
import '@mdi/font/css/materialdesignicons.css'
import 'vuetify/styles'

// Composables
import { createVuetify } from 'vuetify'
import colors from 'vuetify/util/colors'

// https://vuetifyjs.com/en/introduction/why-vuetify/#feature-guides
export default createVuetify({
  theme: {
    defaultTheme: 'light',
    themes: {
      light: {
        dark: false,
        colors: {
          prover_background: colors.lightGreen.lighten4,
          verifier_background: colors.blue.lighten4,
          funding_background: colors.amber.lighten4
        }
      },
      dark: {
        dark: true,
        colors: {
          prover_background: colors.lightGreen.lighten2,
          verifier_background: colors.blue.lighten2,
          funding_background: colors.amber.darken4
        }
      }
    }
  }
})
