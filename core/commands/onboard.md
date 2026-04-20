---
allowed-tools: Read, Glob, Grep, Bash(git:*), Bash(npm:*), Bash(cat:*)
description: Explore and understand a new codebase
argument-hint: focus (e.g. overview, api, frontend, backend) default: overview
---

Explore a codebase to understand its structure and design.

## Procedure

### 1. Basic Information

- Read CLAUDE.md / README.md
- Check the tech stack via `package.json` (or equivalent)
- Map out the directory structure

### 2. Architecture Overview

- Identify entry points
- Trace dependencies between major modules
- Follow data flow (request -> response)
- Identify external service integrations

### 3. Development Environment

- Build commands
- Test commands
- Required environment variables
- CI/CD pipeline

### 4. Code Conventions

- Patterns in use (MVC, hooks, etc.)
- How tests are written
- Naming conventions
- Error handling patterns

## Output

```
## Codebase Overview: [project name]

### Tech Stack
- Language: ...
- Framework: ...
- DB: ...
- Infra: ...

### Structure
[Directory tree and the responsibility of each directory]

### Entry Points
- [file]: [description]

### Data Flow
1. ...

### Development Commands
- Build: `...`
- Test: `...`
- Dev: `...`

### Things to Know
- [project-specific notes and gotchas]
```
