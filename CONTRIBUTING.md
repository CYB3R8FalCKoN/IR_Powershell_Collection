# Contributing to IR_Powershell_Collection

First off, thank you for considering contributing to this project! It's people like you that make incident response tools sharper and more reliable for the community.

## How to Contribute

### Reporting Bugs
This section guides you through submitting a bug report. Following these guidelines helps maintainers and the community understand your report, reproduce the behavior, and find related reports.
* Before submitting, check if the issue has already been reported.
* Use the **Bug Report** issue template provided in this repository.
* Include detailed steps to reproduce, expected behavior, and environment details (OS, PS Version).

### Suggesting Enhancements
* Use the **Feature Request** issue template.
* Provide a clear and detailed explanation of the feature you want and why it's important.

### Pull Requests
1. **Fork** the repository and create your feature branch: `git checkout -b feature/my-new-feature`
2. **Commit** your changes following Conventional Commits format (e.g., `feat: append registry history key to collection`).
3. **Push** to the branch: `git push origin feature/my-new-feature`
4. **Submit a Pull Request** using the provided Pull Request template.

## Code Style Guidelines
* **Readability:** Prioritize readability over clever one-liners. This script is meant to be readable by junior analysts under pressure.
* **Native Execution:** Ensure any added commands use native PowerShell or Windows binaries where possible to reduce dependencies.
* **Third-Party Tools:** If referencing 3rd-party forensic binaries, include source URLs and ensure they are widely respected in the DFIR community.
* **Comments:** Heavily comment complex blocks of code explaining *why* the data is being collected and what adversary technique it detects.
