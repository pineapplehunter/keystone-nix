# Local patch inventory

The Keystone source is pinned by `flake.lock` (currently revision
`73aeab79b97f4cea3e418897841e5534fc978f4b`). Unless noted otherwise, these
changes are local compatibility fixes and have not been submitted upstream.
Keystone is no longer actively maintained, so removal is determined by testing
against a newly pinned revision.

| Patch/change | Target | Reason | Upstream status |
| --- | --- | --- | --- |
| `qemu.patch` | QEMU 11.0.3 | Add the Keystone boot-ROM machine property, enlarge MROM, and place the generated FDT after the custom ROM. | Keystone-specific local feature; not upstream. Rebase and run `qemu-rom-property` whenever QEMU changes. |
| `keystone-runtime/req_pages_define.patch` | Keystone runtime | Move `req_pages` before control flow that can jump past its declaration; required by current compilers. | Not upstream in the pinned source. |
| `keystone-sdk/stdint.patch` | Keystone SDK | Include `<cstdint>` where fixed-width integer types are used by C++ headers. | Not upstream in the pinned source. A related include for `json11.cpp` is applied in `package.nix`. |
| `keystone-sm/opensbi-change-basename.patch` | OpenSBI 1.1 | Replace a host `basename` shell call with GNU Make functions for a hermetic cross-build. | Local build-system fix; OpenSBI 1.1 is frozen here for Keystone API compatibility. |
| `keystone-sm/opensbi-firmware-secure-boot.patch` | OpenSBI 1.1 | Reserve the fixed firmware symbols used by Keystone's software-simulated secure-boot/test-key flow. | Keystone test-platform integration; not suitable as a production root of trust. |
| `keystone-runtime/package.nix` substitutions | Keystone runtime | Rename the obsolete `sbadaddr` CSR and force non-relaxed/non-PIC loader address materialization. | Local compatibility/layout fixes. |
| `keystone-sm/package.nix` substitutions | Keystone SM/OpenSBI | Rename `sbadaddr` and select GNU C11 for modern compilers. | Local compatibility fixes. |

The former `nix-ld-riscv.patch` was removed after RISC-V support landed in
nix-ld itself. This is why package/check builds must be run after every input
update rather than assuming that a patch which still exists is still needed.
