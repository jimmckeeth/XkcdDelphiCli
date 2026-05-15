# Project Instructions: XkcdDelphiCli

## Core Mandates: PowerShell 5.1 Compatibility

This environment uses **PowerShell 5.1** by default for the `run_shell_command` tool.

- **NEVER use `&&` or `||` operators.** They are not supported in PowerShell 5.1.
- **ALWAYS use `;` to chain commands.**
- **STRICTLY ADHERE to this rule.** If you must use PowerShell 7 features, you MUST explicitly wrap the command in `pwsh -c "..."`.

## Versioning & Release

- **Pre-commit**: Versioning is automated via `.git/hooks/pre-commit` which calls `UpdateVersion.ps1`.
- **Release**: Build and package via `makerelease.ps1`. It handles build-time hash stamping and cleanup.
