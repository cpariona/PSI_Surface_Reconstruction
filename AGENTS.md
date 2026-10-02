# AGENTS.md

Keep this repository simple and reviewable.

- `src/+psi` owns maintained implementation.
- Hardware access stays in `+hardware`; scientific processing stays in `+processing`.
- `workflows/` and `app/` orchestrate backend code; do not duplicate scientific or hardware logic there.
- Prefer the smallest change that solves the requested problem.
- Do not add wrappers, managers, compatibility layers, configuration systems, logging frameworks, or generic helpers unless they are required by an actual use case.
- Do not add tests unless a change needs them to protect a real failure mode or scientific result.
- Do not refactor unrelated code.
- Preserve the TPZ001 initialization sequence: connect, initialize settings, polling, enable, `GetPiezoConfiguration`, then voltage control.
- MATLAB owns the hardware while the application is running; Kinesis and ThorCam should remain closed.
