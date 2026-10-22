# Scoop Apps Bucket

[![Sync and Verify](https://github.com/rajashekarthoutam/scoop-apps/actions/workflows/sync-and-test.yml/badge.svg)](https://github.com/rajashekarthoutam/scoop-apps/actions/workflows/sync-and-test.yml)
[![Manifests](https://img.shields.io/badge/manifests-35-blue.svg)](#-package-catalog)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Security: Cloudflare Standard](https://img.shields.io/badge/security-Cloudflare%20Audit%20Standard-blueviolet.svg)](#-enterprise-security--integrity-gates)
[![VirusTotal: 80+ Engines](https://img.shields.io/badge/VirusTotal-80%2B%20Engines%20Verified-brightgreen.svg)](#-enterprise-security--integrity-gates)
[![Scoop](https://img.shields.io/badge/Scoop-Compatible-orange.svg)](https://scoop.sh)

A high-performance, strictly tested, automated **Scoop Apps Bucket** providing essential developer toolchains, AI and local LLM runners, Python and C/C++ development environments, embedded Arduino tools, and modern command-line utilities.

All manifests are automatically synchronized against upstream sources, checked for binary URL reachability, and validated against official Scoop JSON schemas via daily GitHub Actions CI.

---

## 🚀 Installation & Usage

### 1. Add the Bucket

To add this bucket to your existing [Scoop](https://scoop.sh) installation:

```powershell
scoop bucket add apps https://github.com/rajashekarthoutam/scoop-apps
```

### 2. Update Bucket Index

```powershell
scoop update
```

### 3. Install Packages

Install any application directly using Scoop:

```powershell
scoop install <package-name>
```

*Example:*
```powershell
# Install local AI runtime and modern Python tooling
scoop install ollama uv ruff

# Install full C/C++ build toolchain
scoop install gcc cmake ninja
```

### 4. Optional: Verify with VirusTotal (80+ Scanners)
Anyone can verify any package directly against 80+ commercial cybersecurity vendors before or after installation:
```powershell
# Configure free API key once (from https://virustotal.com/gui/my-apikey)
scoop config virustotal_api_key <YOUR_API_KEY>

# Scan any package across 80+ scanners
scoop virustotal uv
# Or audit all bucket packages:
scoop virustotal *
```

---

## 📦 Package Catalog

This apps bucket tracks **35 verified packages** across 5 primary developer categories:

### 🤖 AI & Local LLMs
| Package | Version | Description |
|---|---|---|
| [`ollama`](bucket/ollama.json) | 0.40.1 | Run open-weight LLMs locally (Llama, Gemma, Mistral, DeepSeek) |
| [`aichat`](bucket/aichat.json) | 0.30.0 | All-in-one CLI for OpenAI, Anthropic, Gemini, Ollama & shell integration |
| [`mods`](bucket/mods.json) | 1.8.1 | AI-powered command-line text generation and piping utility by Charm |

### ⚡ C / C++ Developer Toolchain
| Package | Version | Description |
|---|---|---|
| [`gcc`](bucket/gcc.json) | 15.2.0 | GNU Compiler Collection & binutils (MinGW-w64) |
| [`llvm`](bucket/llvm.json) | 23.1.3 | LLVM, Clang compiler toolchain, `clangd` language server & `clang-format` |
| [`cmake`](bucket/cmake.json) | 4.4.4 | Cross-platform build automation & project generator |
| [`ninja`](bucket/ninja.json) | 1.13.2 | Small, fast build system designed for speed |
| [`make`](bucket/make.json) | 4.4.1 | GNU Make build utility |
| [`gdb`](bucket/gdb.json) | 17.1 | The GNU Project Debugger |
| [`cppcheck`](bucket/cppcheck.json) | 2.22.0 | Static analysis tool for C/C++ code |

### 🐍 Python Ecosystem
| Package | Version | Description |
|---|---|---|
| [`python`](bucket/python.json) | 3.14.8 | Official Python programming language runtime |
| [`uv`](bucket/uv.json) | 0.12.24 | Extremely fast Python package & project manager written in Rust (Astral) |
| [`ruff`](bucket/ruff.json) | 0.16.10 | Extremely fast Python linter & code formatter written in Rust (Astral) |
| [`pipx`](bucket/pipx.json) | 1.17.12 | Install and run Python CLI applications in isolated environments |
| [`poetry`](bucket/poetry.json) | 2.5.1 | Python dependency management and packaging tool |

### 🔌 Embedded, FPGA, Hardware & 3D/CAD Design
| Package | Version | Description |
|---|---|---|
| [`arduino`](bucket/arduino.json) | 2.3.10 | Arduino IDE 2.x - Modern electronics prototyping & firmware development |
| [`arduino-cli`](bucket/arduino-cli.json) | 1.5.1 | Official Arduino Command Line Interface |
| [`kicad`](bucket/kicad.json) | 10.0.6 | Electronics Design Automation Suite (Schematics & PCB design) |
| [`openscad`](bucket/openscad.json) | 2021.01 | The Programmers Solid 3D CAD Modeller |
| [`prusaslicer`](bucket/prusaslicer.json) | 2.9.6 | G-code generator for 3D printers (RepRap, Makerbot, Ultimaker, etc.) |
| [`pronterface`](bucket/pronterface.json) | 2.2.0 | Pure Python 3D printer GUI host, console & live USB printer control (Printrun) |
| [`iverilog`](bucket/iverilog.json) | 14-20260804 | Icarus Verilog simulation engine (`vvp`) & GTKWave waveform verification viewer |
| [`oss-cad-suite-nightly`](bucket/oss-cad-suite-nightly.json) | 2026-10-11 | Complete open-source FPGA toolchain (Gowin FPGA support, `nextpnr-gowin`, `apicula`, `openFPGALoader`, `yosys`, `verilator`) |

### 🛠️ Core Utilities & Terminal Tools
| Package | Version | Description |
|---|---|---|
| [`7zip`](bucket/7zip.json) | 26.04 | High-compression file archiver |
| [`git`](bucket/git.json) | 2.56.0.2 | Portable Git revision control system |
| [`gh`](bucket/gh.json) | 2.102.0 | GitHub's official command-line interface |
| [`ripgrep`](bucket/ripgrep.json) | 15.2.0 | Ultra-fast recursive line-oriented search tool (`rg`) |
| [`jq`](bucket/jq.json) | 1.8.2 | Lightweight and flexible command-line JSON processor |
| [`curl`](bucket/curl.json) | 8.22.0_3 | Command-line tool for transferring data with URLs |
| [`pwsh`](bucket/pwsh.json) | 7.6.6 | Cross-platform modern PowerShell 7 |
| [`starship`](bucket/starship.json) | 1.26.0 | Fast, customizable cross-shell prompt |
| [`neovim`](bucket/neovim.json) | 0.12.5 | Modern, extensible terminal code editor |
| [`vlc`](bucket/vlc.json) | 3.0.24 | Highly versatile multimedia player and framework |
| [`vscode`](bucket/vscode.json) | 1.141.0 | Portable Visual Studio Code |

---

## 🏗️ Architecture & Automation

```text
upstream (Main / Extras) ──> [scripts/sync-and-verify.ps1] ──> [scripts/test-bucket.ps1]
                                         │                                 │
                                   Fetch & Check                      Lint & Schema
                                   Download URLs                      Validation
                                         │                                 │
                                         ▼                                 ▼
                             [scripts/security-audit.ps1]  ──> [scripts/verify-hashes-and-malware.ps1]
                                         │                                 │
                                  Cloudflare AST                   VirusTotal (80+ AVs)
                                & Domain Allowlist                 & Windows Defender
                                                                           │
                                                                           ▼
                                                                     bucket/*.json
```

* **Automated Sync**: A daily GitHub Actions workflow (`.github/workflows/sync-and-test.yml`) checks upstream repositories for newly released versions.
* **Schema Verification**: Manifests are checked with `scripts/test-bucket.ps1` before updates are accepted.
* **Integrity**: Binary download URLs are verified for reachability to ensure zero broken packages.

---

## 🔒 Enterprise Security & Integrity Gates

This repository implements strict supply chain security policies aligned with the **Cloudflare Security Audit Standards** (`SUPPLY-CHAIN-AND-RELEASE`):

1. **Vendor Domain & TLS 1.2+ Enforcement**:
   - Only direct downloads from verified official vendor domains (e.g. `github.com/releases`, `python.org`, `arduino.cc`, `nuwen.net`, `astral.sh`) are permitted.
   - Plaintext `http://` URLs, untrusted third-party mirrors, and URL shorteners are strictly blocked.
2. **Cryptographic Digest Binding**:
   - Every manifest requires an immutable cryptographic checksum (SHA-256).
   - Prevents supply chain tampering, unauthorized package substitution, or mirror poisoning.
3. **PowerShell AST Heuristic Security Audit**:
   - Automated static analysis (`scripts/security-audit.ps1`) inspects all `pre_install` and `post_install` hooks.
   - Detects and blocks arbitrary code execution (`Invoke-Expression`, `iex`), remote string downloads, unauthorized registry keys, and obfuscated Base64 blobs.
4. **VirusTotal Multi-Engine Threat Intelligence (80+ Scanners)**:
   - Automated scanner (`scripts/verify-hashes-and-malware.ps1`) integrates with the VirusTotal API v3.
   - Every package hash is scanned across 80+ commercial enterprise security engines (CrowdStrike, Microsoft Defender, Bitdefender, Kaspersky, Sophos, SentinelOne, ESET, etc.).
   - Zero detections required for clean certification.
5. **Gated GitHub Actions Verification**:
   - Automated syncs only commit when **all gates** (schema linter, Cloudflare static security audit, and multi-engine threat scans) pass with **zero critical violations**.

---

## 🤝 Contributing

Contributions are welcome! If you would like to track an additional tool or fix a manifest:

1. Fork this repository.
2. Add your application to [`config/apps.json`](config/apps.json):
   ```json
   { "name": "app-name", "source_bucket": "main", "description": "Application description" }
   ```
3. Test locally with PowerShell:
   ```powershell
   ./scripts/sync-and-verify.ps1 -AppName "app-name"
   ./scripts/test-bucket.ps1
   ```
4. Submit a Pull Request.

---

## 📄 License

This repository is licensed under the [MIT License](LICENSE).
Individual software packages installed via manifests remain under their respective upstream licenses.
