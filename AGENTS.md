# Hoplite — Codex project instructions

## GodotPrompter

This is a Godot 4.x project. Before designing or changing a Godot system, load the installed `using-godot-prompter` skill, then load only the domain skills relevant to the task.

- Start feature design and architecture with `godot-brainstorming`.
- For implementation, use the matching domain skills such as `player-controller`, `input-handling`, `animation-system`, `ai-navigation`, `component-system`, `physics-system`, `3d-essentials`, `audio-system`, `hud-system`, or `procedural-generation`.
- Follow the project's existing GDScript conventions unless the task explicitly requires C#.
- Use third-party-addon skills only when the corresponding addon is installed in this project.
- Diagnose failures with `godot-debugging` and validate completed Godot changes with `godot-code-review` plus the relevant project checks.
- When the user asks to learn while building, also load `godot-mentor`.
