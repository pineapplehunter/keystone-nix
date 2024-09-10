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
- [x] boot linux without firmware checking in opensbi
- [ ] opensbi keystone patch
- [ ] keystone eapps
- [ ] boot linux with firmware check enabled
