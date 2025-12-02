# Even More Minimal devShell

Based on https://fzakaria.com/2021/08/02/a-minimal-nix-shell.html . Now without coreutils.

```console
$ nix path-info --closure-size --human-readable $(nix develop --command bash -c 'echo ${NIX_GCROOT}')
/nix/store/yl5va82skr3mn5r18f01m7gx98j5ayyp-minimal-env    9.9 MiB
```

```console
$ nix run nixpkgs#nix-tree -- $(nix develop --command bash -c 'echo ${NIX_GCROOT}')
```

![Graph](minimal.png)
