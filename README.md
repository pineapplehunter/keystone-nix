# Keystone Nix

Nix packages and a NixOS VM test for the
[Keystone](https://keystone-enclave.org) RISC-V enclave stack.

> [!WARNING]
> Keystone upstream is no longer actively maintained and is transitioning to
> the Confidential Computing Consortium's Emeritus stage. This repository is a
> research and development environment, not a supported production TEE. The
> boot ROM uses Keystone's public test key and software-simulated secure-boot
> flow; it does **not** provide a production hardware root of trust.

## Supported systems

The flake is continuously evaluated and tested on an `x86_64-linux` host. It
cross-compiles the guest system and Keystone components for RISC-V. Other host
systems are not currently advertised because CI does not exercise them.

Requirements:

- Nix with flakes enabled
- enough free disk space for a cross-compiled NixOS VM
- support for the NixOS test feature when building the VM check

The optional signed cache is controlled by the repository operator. Nix always
retains its configured substituters, including `cache.nixos.org`; reject the
flake's cache configuration or pass `--no-substitute` to build locally. The
public key in `flake.nix` authenticates cache objects, but does not turn the
test-key Keystone boot chain into a production security boundary.

## Run the interactive VM

```console
nix run
```

This launches the NixOS test driver's interactive Python REPL using the same VM
definition as the automated enclave test. Start the VM and attach to its serial
console at the prompt:

```python
machine.start()
machine.shell_interact()
```

Use <kbd>Ctrl-D</kbd> to leave the guest shell and again to leave the REPL. The
test driver then shuts down QEMU and removes its temporary state.

The VM defaults to 4 GiB RAM and 4 virtual CPUs. QEMU's final options can be
overridden without rebuilding, for example:

```console
QEMU_OPTS='-m 2G -smp 2' nix run
```

Additional user-network options can be supplied through `QEMU_NET_OPTS`. For
example, a loopback-only forwarding rule is:

```console
QEMU_NET_OPTS='hostfwd=tcp:127.0.0.1:10022-:22' nix run
```

The demo image does not enable SSH by default. If a custom configuration does,
QEMU reports a bind failure when the requested host port is already occupied.
`TMPDIR`/`XDG_RUNTIME_DIR` control test-driver temporary state, and
`--keep-machine-state` can be passed to retain reusable VM state.

## Build outputs

```console
nix build .#driver             # RISC-V kernel module tree
nix build .#bootrom            # bootrom.bin and bootrom.elf
nix build .#sm                 # OpenSBI firmware with Keystone SM
nix build .#sdk                # Keystone host/enclave SDK
nix build .#runtime            # Eyrie runtime and raw loader
nix build .#runtime-with-plugin
nix build .#hello-ke           # hello enclave and hello-runner
nix build .#qemu               # RISC-V-only QEMU with custom ROM support
nix build .#systemConfig       # cross-compiled NixOS closure
```

Build results appear through the usual `result` symlink unless `--no-link` is
used. Package versions contain the date of the pinned Keystone revision. Local
patch purposes and update rules are recorded in [`PATCHES.md`](PATCHES.md).

The overlay and rootfs module are available as `overlays.default` and
`nixosModules.rootfs`. The rootfs module expects the NixOS sd-image options used
by `configuration.nix`.

## Test and develop

```console
nix fmt -- --ci
nix flake check --all-systems --no-build
nix build .#checks.x86_64-linux.package-set --no-link
nix build .#checks.x86_64-linux.qemu-rom-property --no-link
nix build .#checks.x86_64-linux.keystone-enclave --no-link
```

The enclave test boots through the Keystone test boot ROM and security monitor,
then verifies runner argument and initialization failures, an enclave execution
failure, driver/device setup, and successful hello-world output. `nix develop`
provides the cross-binutils wrapper and ShellCheck.

When updating `flake.lock`:

1. Read upstream release and security notes, including OpenSBI and QEMU.
2. Rebase every entry in `PATCHES.md` and remove fixes already upstream.
3. Run formatting, all package checks, the QEMU property check, and the full VM
   test shown above.
4. Confirm that package versions and the pinned-source date still agree.

## Feature and security status

| Area | Status |
| --- | --- |
| Keystone driver, SDK, Eyrie runtime | Built from the pinned source |
| Hello eapp | Built by Nix and executed in the VM test |
| Custom QEMU ROM property and Keystone boot ROM | Booted by the enclave VM test; property/error paths checked separately |
| Keystone security monitor | Integrated with OpenSBI 1.1 |
| Firmware measurement flow | Experimental software simulation with public test keys |
| Hardware root of trust / production secure boot | Not provided |
| Upstream security maintenance | Keystone upstream is inactive; local users must audit/backport fixes |

OpenSBI is intentionally pinned to 1.1 inside the `keystone` package scope.
Keystone's security-monitor integration targets that older OpenSBI API and does
not build unchanged against current OpenSBI 1.8.1: after removing the obsolete
1.1 Makefile patch, the build expects a Keystone platform Kconfig `defconfig`
that the old platform tree does not provide. The normal nixpkgs `opensbi`
package remains untouched for overlay consumers. Before production use, review
all security and correctness changes between 1.1 and the current nixpkgs
version and backport relevant fixes or port Keystone to the current API.

The example NixOS configuration is deliberately convenient for local emulation
(root console autologin, a documented demo password, and no firewall). Do not
expose it to an untrusted network or deploy it as a secure system.
