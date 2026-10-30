# Contributing to MYCELIA

- **Code style:** typed GDScript (`:=` or explicit types). Use tabs, `snake_case`, `class_name` for reusable types, and `##` doc comments on public classes and functions.
- **Separate logic from presentation.** Rules belong in `RefCounted` models. Nodes only present them.
- **Communicate through signals.** Emit facts on `EventBus` rather than calling other systems directly.
- **Content is data.** Add spells, creatures, items and quests in `tools/build_content.gd` and regenerate the resources. Write dialogue in `resources/dialogue/*.json`.
- **Before committing**, run both of these. Both must pass.

  Compile-check every script:

  ```bash
  godot --headless res://tools/dev/check_scripts.tscn
  ```

  Run the test suite:

  ```bash
  godot --headless --fixed-fps 60 res://tests/test_runner.tscn
  ```

- **Visual changes:** capture before and after shots with `tools/dev/capture_tour.tscn` or `capture_ui.tscn`, and check the primitive and draw-call log.
- **Documentation:** keep `docs/DEVELOPMENT_STATUS.md` and `docs/KNOWN_ISSUES.md` truthful.
