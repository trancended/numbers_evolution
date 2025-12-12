# Frontend Rules - Numbers Evolution

## Tailwind CSS v4
- Use new CSS-first import syntax in `app.css`: `@import "tailwindcss" source(none)`
- Use `@source` directives to auto-detect classes in templates
- Use `@theme` for configuration directly in CSS (no `tailwind.config.js` needed)
- Never use `@apply` in raw CSS
- Custom variants for LiveView loading states: `phx-click-loading`, `phx-submit-loading`
- Bundle size is minimal (only used classes compiled)
- Zero runtime overhead - pure compiled CSS

## DaisyUI Components
- Use DaisyUI component classes for rapid UI development
- Available components: `btn`, `card`, `modal`, `dropdown`, `form-control`, `table`, `drawer`, `navbar`
- Two themes configured: light (Phoenix-inspired) and dark (Elixir-inspired)
- Theme switching via `data-theme` attribute on root element
- DaisyUI is pure CSS - zero JavaScript dependencies
- Custom components preferred over DaisyUI where uniqueness needed
- Never install other CSS frameworks - use DaisyUI + custom Tailwind

## Heroicons
- Icons available as CSS classes: `hero-x-mark`, `hero-check`, etc.
- Use imported `<.icon name="hero-{icon-name}">` component from `core_components.ex`
- Never use Heroicons modules directly
- Icon sizing via `class="w-5 h-5"` on icon component

## JavaScript and TypeScript
- Import all external libraries into `app.js` and `app.css`
- Never write inline `<script>` tags in templates
- Place all JS hooks in `assets/js` directory
- Use `phx-update="ignore"` for elements managed by JS hooks
- Use `phx-hook="HookName"` for LiveView JavaScript interop
- TypeScript config available in `assets/tsconfig.json`

## UI/UX Requirements
- Create responsive interfaces using Tailwind breakpoints
- Implement subtle micro-interactions (hover effects, smooth transitions)
- Maintain clean typography, spacing, and layout balance
- Add loading states for async operations
- Ensure smooth page transitions without full reloads (LiveView SPA)
- Mobile-first responsive design (tested from 320px to 1920px)
- Hamburger menu for mobile navigation
- Touch-friendly button sizes on mobile

## Forms
- Use `<.input>` component from `core_components.ex` for all form inputs
- Always use `Phoenix.Component.form/1` and `to_form/2` in LiveView
- Forms driven by `@form` assign in LiveView templates
- Access fields via `@form[:field_name]`
- Custom classes override all defaults - provide full styling when overriding
- Always add unique DOM IDs to forms for testing (e.g., `id="strategy-form"`)
- Display validation errors via LiveView changeset errors
- Never use deprecated `Phoenix.HTML.form_for`

## LiveView Specifics
- Single Page Application architecture - all on `/` route (avoid `/dashboard`)
- Dynamic section show/hide without page reloads
- Real-time updates via LiveView messaging (e.g., simulation progress every 2 seconds)
- Use `phx-click`, `phx-change`, `phx-submit` for event handling
- Never use `live_redirect`/`live_patch` - use `<.link navigate={}>` and `<.link patch={}>`
- Avoid LiveComponent unless strong specific need
- Use streams for collections to prevent memory bloating

## Responsive Design
- Mobile navigation: hamburger menu pattern
- Forms: single column on mobile
- Visual elements (number balls): stack vertically on small screens
- Lists (strategies, simulations): readable on all screen sizes
- Test on viewport range: 320px (iPhone SE) to 1920px (desktop)

## Accessibility
- Semantic HTML structure
- Proper ARIA labels where needed
- Keyboard navigation support
- Color contrast meeting WCAG standards
- Focus indicators visible and clear

