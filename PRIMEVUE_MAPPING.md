# PrimeVue Component Mapping

Reference guide for migrating Vue components to PrimeVue v4 with Tailwind CSS `unstyled: true` mode.

## Theme Configuration

```js
// main.js
import PrimeVue from 'primevue/config'
import Aura from '@primeuix/themes/aura'

app.use(PrimeVue, {
  unstyled: true,
  theme: {
    preset: Aura,
    options: { darkModeSelector: '.dark' }
  }
})
```

Import path: `@primeuix/themes/aura` (confirmed across all projects).

## Component Mapping

| HTML Element | PrimeVue Component | Notes |
|---|---|---|
| `<button>` | `<Button>` | Set `severity` prop for color; `text` prop for text-only style |
| `<input type="text">` | `<InputText>` | Use `v-model`, supports `placeholder`, `disabled` |
| `<input type="number">` | `<InputNumber>` | Set `:min`, `:max`, `:step`, `:maxFractionDigits` |
| `<textarea>` | `<Textarea>` | Set `rows`, `autoResize` prop |
| `<select>` | `<Select>` | Use `:options`, `optionLabel`, `optionValue`; handles `v-model` |
| `<input type="checkbox">` | `<Checkbox>` | Use `v-model` with `:binary="true"` for single checkbox |
| `<progress>` bar | `<ProgressBar>` | Use `:value` (0-100); renders `data-pc-section="value"` child |
| `<span>` badge | `<Tag>` | Set `value` prop; severity maps to color |

### Button Severity Levels

```vue
<Button label="Primary" severity="primary" />
<Button label="Success" severity="success" />
<Button label="Info" severity="info" />
<Button label="Warning" severity="warning" />
<Button label="Danger" severity="danger" />
<Button label="Secondary" severity="secondary" />
```

For text-only buttons (like filter toggles), add `text` prop.

### Select Component

```vue
<Select
  v-model="mb.polling_interval_seconds"
  :options="pollingOptions"
  optionLabel="label"
  optionValue="value"
  @change="saveMailbox(mb)"
/>
```

Options should be an array of `{ label: string, value: any }`.

### ProgressBar

```vue
<ProgressBar :value="percent" :showValue="false" />
```

In unstyled mode, the fill div is identified by `data-pc-section="value"` attribute.

## Test Selectors (jsdom environment)

| Test Purpose | Selector |
|---|---|
| ProgressBar fill | `[data-pc-section="value"]` |
| Filter buttons with active state | `.filter-btn.active` (add `active` class conditionally) |
| Search button | `.search-btn` (add class to Button) |
| Skill activate/deactivate | `.btn-activate` / `.btn-deactivate` (add class conditionally) |

## Required Polyfills (vitest-setup.js)

```js
// matchMedia — PrimeVue Select uses it
if (typeof window.matchMedia !== 'function') {
  Object.defineProperty(window, 'matchMedia', {
    writable: true, configurable: true,
    value: (query) => ({ matches: false, media: query, onchange: null,
      addListener: () => {}, removeListener: () => {},
      addEventListener: () => {}, removeEventListener: () => {},
      dispatchEvent: () => true })
  })
}

// ResizeObserver — PrimeVue Textarea uses it
if (typeof window.ResizeObserver === 'undefined') {
  window.ResizeObserver = class ResizeObserver {
    observe() {} unobserve() {} disconnect() {}
  }
}
```

## Global Plugin Registration

In `vitest-setup.js`, register PrimeVue globally for all tests:

```js
import PrimeVue from 'primevue/config'
import Aura from '@primeuix/themes/aura'
const { config } = require('@vue/test-utils')
config.global.plugins = config.global.plugins || []
config.global.plugins.push([PrimeVue, {
  unstyled: true,
  theme: { preset: Aura, options: { darkModeSelector: '.dark' } }
}])
```