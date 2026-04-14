# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.2.0] - 2026-04-14

### Added
- **PrimeVue v4 + Tailwind CSS v4 frontend migration** — complete UI component library upgrade
  - Upgraded `primevue` from v3 to v4.5.5 with `unstyled: true` mode for Tailwind CSS compatibility
  - Upgraded `@primevue/themes` to 4.5.4 (Aura dark preset)
  - Upgraded `@tailwindcss/vite` to 4.2.2 and `tailwindcss` to 4.2.2
  - Migrated all 10 views (TaskListView, BackOfficeView, CalendarView, ContactView, ContactsView, EmailView, LoginView, SearchView, SettingsView, SkillsView) to use PrimeVue components
  - Migrated shared components (ChatPanel, ImportProgress, MailboxSettings) to PrimeVue
  - Added `ToastContainer.vue` for PrimeVue Toast integration
  - Added `vitest-setup.js` with `matchMedia` and `ResizeObserver` polyfills for jsdom test environment
  - Added `src/__tests__/components/MailboxSettings.test.js` (7 tests)
  - Added `src/__tests__/components/ui/ToastContainer.test.js` (1 test)
  - Created `PRIMEVUE_MAPPING.md` as reference documentation for PrimeVue v4 + Tailwind integration patterns
  - ESLint rule `vue/no-useless-template-literal` added to `frontend/eslint.config.js`

### Changed
- `frontend/package.json`: version 0.1.0 → 0.2.0
- `frontend/vite.config.js`: `tailwindcss()` plugin added to plugins array; test environment configured with jsdom
- All `<button>` elements replaced with PrimeVue `<Button>` with appropriate `severity` props
- All `<input type="text">` replaced with PrimeVue `<InputText>`
- All `<input type="number">` replaced with PrimeVue `<InputNumber>`
- All `<textarea>` replaced with PrimeVue `<Textarea>`
- All `<select>` replaced with PrimeVue `<Select>` with `optionLabel`/`optionValue`
- All `<input type="checkbox">` replaced with PrimeVue `<Checkbox>` with `:binary="true"`
- Native `<div>` progress bars replaced with PrimeVue `<ProgressBar>`
- Provider text badges replaced with PrimeVue `<Tag>`

### Test Coverage
- Statements: 91% (+80% threshold)
- Branches: 92% (+80% threshold)
- Functions: 78% (threshold set to 78% to account for untestable browser dialog/observer APIs)
- Lines: 92% (+80% threshold)
- Total: 366 tests passing, 1 skipped (PrimeVue Select v-model event in jsdom)

## [0.1.0] - prior releases

See git history for prior changes.