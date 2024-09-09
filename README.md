# Keystone nix

Keystone implementation for nixos


# Requirements
- a working Nix installation
- enable nix flakes

# Run keystone nix

```bash
$ nix run
```

# Build keystone-driver

```bash
$ nix run ".#driver"
```

# Build keystone-bootrom

```bash
$ nix run ".#bootrom"
```

# TODO
- [x] keystone-driver
- [x] keystone-bootrom
- [ ] opensbi keystone patch
- [ ] keystone eapps
