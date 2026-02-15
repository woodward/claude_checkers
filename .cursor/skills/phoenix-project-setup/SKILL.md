---
name: phoenix-project-setup
description: Performs post-generation setup steps for a new Phoenix project created with mix phx.new. Use when the user creates a new Phoenix project, scaffolds a Phoenix app, or asks to run their standard Phoenix setup steps.
---

# Phoenix Project Setup

Post-generation setup steps to run after `mix phx.new`. Execute these steps in order, committing after each step.

## Step 1: Add commit format rule to AGENTS.md

1. Ensure `AGENTS.md` contains the following rule in the Project guidelines section:
   - After every git commit, always display the result using this exact format:
     `Committed: \`<short-sha>\` at <YYYY-MM-DD HH:MM:SS> — <commit subject>`
   - The timestamp comes from `git log -1 --format='%ci'` immediately after the commit
2. This must be done before any other commits so all transcripts are parseable by the commit annotation script

## Step 2: Set formatter line length to 120

1. In `.formatter.exs`, add `line_length: 120` to the keyword list
2. Run `mix format` to reformat the entire project with the new line length

## Step 3: Alphabetize mix.exs dependencies

1. Sort the dependency tuples in the `deps/0` function in `mix.exs` alphabetically by package name

## Step 4: Update all dependencies

1. Run `mix deps.update --all` to update all mix dependencies
2. Look up the latest stable versions of **esbuild** and **Tailwind CSS**
3. Update the `version` values in `config/config.exs` for both `:esbuild` and `:tailwind`

## Step 5: Sync dependency version specs

1. Run `mix deps` to see the actual installed versions
2. Update each dependency in `mix.exs` to:
   - Use 2-digit version specs (e.g., `"~> 1.10"` not `"~> 1.10.2"`)
   - Match the currently installed minor version (e.g., if `telemetry_poller 1.3.0` is installed, use `"~> 1.3"` not `"~> 1.0"`)
3. Run `mix deps.get` to verify all deps still resolve cleanly

## Step 6: Replace vendored daisyUI with npm package

1. Delete `assets/vendor/daisyui.js` and `assets/vendor/daisyui-theme.js`
2. Initialize npm in the `assets/` directory if no `package.json` exists: `npm init -y` (run from within `assets/`)
3. Install daisyui: `npm install daisyui` (run from within `assets/`)
4. Update `assets/css/app.css`:
   - Change `@plugin "../vendor/daisyui"` to `@plugin "daisyui"`
   - Change all `@plugin "../vendor/daisyui-theme"` to `@plugin "daisyui/theme"`
5. Add `"cmd npm i --prefix assets"` to the `assets.setup` alias in `mix.exs`
6. Ensure `assets/node_modules/` is in `.gitignore` (it should already be)
7. Commit both `assets/package.json` and `assets/package-lock.json`

## Step 7: Update vendored assets

1. Check the latest versions of `topbar.js` and `heroicons.js` in `assets/vendor/`
2. Also check if the heroicons tag in `mix.exs` (e.g., `tag: "v2.2.0"`) has a newer release
3. Update any that are outdated

---

## Optional steps

The following steps are optional enhancements.

## Optional: Replace CoreComponents with DaisyUIComponents

Replace Phoenix's generated `core_components.ex` with the `daisy_ui_components` library (installed as a dependency, not injected).

1. Add `{:daisy_ui_components, "~> 0.9"}` to `mix.exs` (alphabetized)
2. Run `mix deps.get`
3. Add to `config/config.exs`:
   ```elixir
   config :daisy_ui_components, translate_function: &MyAppWeb.Gettext.translate_error/1
   ```
4. Add `@source "../../deps/daisy_ui_components";` in `assets/css/app.css` (after the other `@source` lines)
5. In `lib/my_app_web.ex`, in the `html_helpers` block:
   - Replace `import MyAppWeb.CoreComponents` with `use DaisyUIComponents, core_components: true`
6. Move `translate_error/1` and `translate_errors/2` from `core_components.ex` to the Gettext module (`lib/my_app_web/gettext.ex`)
7. Remove the local `flash_group/1` definition from `layouts.ex` (the library provides it)
8. Remove any stale `<Layouts.flash_group>` calls from templates (e.g., `home.html.heex`) since flash is handled in the app layout
9. Delete `lib/my_app_web/components/core_components.ex`
10. Run `mix compile --warnings-as-errors` to verify

## Optional: Add PhoenixTest for feature testing

Add [PhoenixTest](https://github.com/germsvel/phoenix_test) for a unified way of writing feature tests for both LiveView and static pages.

1. Add `{:phoenix_test, "~> 0.9", only: :test, runtime: false}` to `mix.exs` (alphabetized)
2. Run `mix deps.get`
3. Add to `config/test.exs`:
   ```elixir
   config :phoenix_test, :endpoint, MyAppWeb.Endpoint
   ```
4. Add `import PhoenixTest` to the `using` block in `test/support/conn_case.ex`
5. Run `mix compile --warnings-as-errors` to verify

## Optional: Add DemoLive page for DaisyUIComponents

Add a demo LiveView that showcases the DaisyUIComponents in action, adapted from the [storybook welcome example](https://github.com/phcurado/daisy_ui_components/blob/main/storybook/storybook/welcome.story.exs) ([live demo](https://daisy-ui-components-site.fly.dev/storybook/welcome)).

1. Create `lib/my_app_web/live/demo_live.ex` and `lib/my_app_web/live/demo_live.html.heex`
2. The template should exercise a variety of components: navbar, breadcrumbs, stats, card, table, badges, pagination, modal, simple_form, input, button, drawer, menu, dropdown, avatar
3. Use `@impl Phoenix.LiveView` (not `@impl true`) for callbacks
4. Add a route in the router: `live "/demo", DemoLive`
5. Note: check actual slot names in the library source — e.g., navbar uses `:navbar_start`/`:navbar_end` (not `:start`/`:end`), and dropdown uses `inner_block` (not `:trigger`)
6. Run `mix compile --warnings-as-errors` to verify
