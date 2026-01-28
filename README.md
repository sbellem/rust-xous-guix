# rust-xous-guix
GNU Guix package for Rust with `riscv32imac-unknown-xous-elf` target support.

## Installing GNU Guix
Choose your own way: https://guix.gnu.org/en/download/.

## Quick Start

### Option 1: Direct build

```bash
guix build -L . rust-xous
```

### Option 2: Development shell

```bash
guix shell -L . rust-xous
rustc --print target-list | grep xous
# riscv32imac-unknown-xous-elf
```

### Option 3: As a Guix channel

Add to `~/.config/guix/channels.scm`:

```scheme
(cons (channel
        (name 'rust-xous)
        (url "https://github.com/sbellem/rust-xous-guix"))
      %default-channels)
```

Then:

```bash
guix pull
guix build rust-xous
```

## Packages

| Package | Description |
|---------|-------------|
| `rust-xous` | Complete Rust toolchain with Xous target |
| `xous-sysroot` | Standard library for riscv32imac-unknown-xous-elf |
| `rust-sysroot-merged` | Merged sysroot with all targets |

## Architecture
The build process mirrors the Nix flake implementation:

1. **Vendor dependencies**: Pre-vendor Cargo dependencies for offline build
2. **Build sysroot**: Compile libstd for riscv32imac-unknown-xous-elf using RISC-V cross-compiler
3. **Merge sysroot**: Combine base Rust targets with Xous target
4. **Wrap toolchain**: Create rustc/cargo wrappers that use the merged sysroot


## Troubleshooting

### Hash mismatch errors
Guix uses content-addressed storage. If you get hash errors, update the hash
in `rust-xous.scm` with the value Guix reports.

### Missing RISC-V cross-compiler
The package automatically pulls in `riscv32-none-elf-gcc` from Guix's
cross-compilation infrastructure. No manual installation needed.
