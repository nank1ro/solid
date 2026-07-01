# Third-party packages in a Solid project

Every pub package's README, every Stack Overflow answer, every AI-generated setup instruction assumes `lib/` is where you write code. In a Solid project that assumption is inverted: `source/` is where you write code, `lib/` is generated.

This reference catalogues the redirect pattern for common packages.

## The general rule

When a package's docs say:

- *"Create `lib/<x>.dart` and put this in it..."* → create `source/<x>.dart` instead.
- *"Register this in `lib/main.dart`..."* → edit `source/main.dart` instead.
- *"Import via `package:<your_app>/<x>.dart`..."* → from inside `source/`, use a **relative** import (`../path/to/x.dart`). The `package:<your_app>/...` form resolves to `lib/` (the generated realm) and the generator rejects it.

The package itself stays in `pubspec.yaml` exactly as the docs describe. Only the *Dart files you write that import it* move from `lib/` to `source/`.

## When a new code generator is added

If the new package is itself a `build_runner` builder (freezed, json_serializable, drift, riverpod_generator, isar_generator, mockito with `@GenerateMocks`, …), it reads from `lib/` by default. To make it read from `source/` too, ensure your `build.yaml` `targets.$default.sources` includes `source/**`:

```yaml
targets:
  $default:
    sources:
      - source/**
      - lib/**
      - $package$
```

The Solid setup already puts `source/**` first — keep it there and other generators will pick up your source files automatically.

## Per-package gotchas

### `go_router`

The README says: *"Create `lib/router.dart` with your `GoRouter` config and import it from `lib/main.dart`."*

In a Solid project:
- Create `source/router.dart` with the `GoRouter` config.
- Import it from `source/main.dart` via a relative path: `import 'router.dart';`.
- No `lib/` files created or edited by you. build_runner produces `lib/router.dart` and `lib/main.dart` from your source.

```dart title="source/router.dart"
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'home_page.dart';
import 'settings_page.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomePage()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
  ],
);
```

```dart title="source/main.dart"
import 'package:flutter/material.dart';

import 'router.dart';

void main() {
  runApp(MaterialApp.router(routerConfig: appRouter));
}
```

### `freezed`

The README tells you to create `lib/models/user.dart` and run `build_runner`. In a Solid project:
- Create `source/models/user.dart`.
- Freezed generates `*.freezed.dart` siblings. Where those land depends on `build.yaml`. If `source/**` is in your sources list (Solid's setup ensures this), freezed reads your `source/models/user.dart` and emits `source/models/user.freezed.dart`. Solid then transpiles both `source/` files into `lib/`.
- Inside `source/`, import the freezed-generated file via a relative `.freezed.dart` path: `part 'user.freezed.dart';`.

### `json_serializable`

Same redirect as freezed — create the annotated class under `source/`, let the generator produce the `.g.dart` sibling under `source/`, and Solid copies the whole thing to `lib/` on build.

### `riverpod` / `flutter_riverpod` + `riverpod_generator`

Riverpod docs say: *"Define providers in `lib/providers/`."* In Solid:
- Create `source/providers/<x>.dart`.
- `riverpod_generator` emits `*.g.dart` siblings — same deal as freezed.
- Providers read in widgets via `ref.watch(...)` work without modification, because by the time the code runs, it's the generated `lib/` version.

That said: if you're using Riverpod, you may not need Solid at all (both are reactive state libraries). Mixing them in one project is unusual but supported — Solid handles the widget-local state, Riverpod handles app-global.

### `drift`

Drift docs say create `lib/database.dart`. In Solid: `source/database.dart`. Drift's generated `*.g.dart` lands as a sibling.

### `isar`

Same — `source/<collection>.dart` for the annotated classes.

### `get_it`

`get_it` doesn't generate code; it's runtime DI. The README still tells you to call `GetIt.I.registerSingleton(...)` in `lib/main.dart`. Substitute `source/main.dart`.

### `flutter_bloc`

The pattern guides write `lib/blocs/<x>_bloc.dart` and `lib/blocs/<x>_event.dart` etc. Substitute `source/blocs/<x>_bloc.dart` etc.

### `provider`

`provider` is already a Solid dependency (it backs `@SolidEnvironment`). Use it directly when you need multiple providers or when the `.environment(...)` chain gets long.

### `dio` / `http` / `chopper` / API client packages

These are runtime libraries with no code generation — `lib/`-vs-`source/` doesn't apply to the package itself. But the *Dart files you write to consume them* (your `ApiClient` class, your DTOs) go under `source/`.

## What if the new package isn't listed here?

Apply the rule of thumb: anywhere the docs say `lib/`, substitute `source/`. The package itself stays normal in `pubspec.yaml`. If it's a code generator, make sure `source/**` is in `build.yaml` sources.
