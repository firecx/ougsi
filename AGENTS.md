# Repository Guidelines

## Project Structure

This repository is in the design phase for a server orchestration system. Specifications live in `doc/Техническое задание/`. Use `Техническое задание v2.docx` as the implementation baseline and `План разработки v2.md` in the same directory to identify the current task and its dependencies. Keep the existing versioned filenames for the specifications.

The first prototype creates a KVM virtual machine through the orchestrator, VM service, and node agent. The specification calls for Java/Spring Boot services, a C++17 node agent, and a C#/.NET Windows adapter. Preserve service boundaries and document service APIs in OpenAPI. Source, test, and runtime asset directories will be established with the prototype.

## Development Commands

Build, test, and local run commands will be introduced with the prototype. Document the exact commands and prerequisites when adding the first runnable components.

- `git status --short` lists changed and untracked files.
- `git diff --check` checks unstaged tracked edits for whitespace errors. Review newly created documents separately.
- `git log -5 --oneline` shows recent commits and their subjects.

## Style and Testing

Keep specifications and user-facing documentation in Russian and preserve the terminology used in the v2 specification. Use descriptive module and test names. When introducing a module, document its formatter, indentation conventions, and test runner alongside its build instructions.

The first implementation should add automated builds and unit tests for every change. Name tests for the behavior they verify. Use the development plan’s acceptance criteria for integration tests, starting with a reproducible KVM request that reaches the agent and records the result. Test frameworks and coverage thresholds are still open.

## Commits and Pull Requests

Recent commits use short plain-text subjects such as `TS update`. Keep subjects brief and name the specific change. In pull requests, summarize what changed, reference the relevant plan task or specification section, and report the checks performed. Link an issue when one exists.
