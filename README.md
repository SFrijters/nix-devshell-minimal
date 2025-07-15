# Even More Minimal devShell

Based on https://fzakaria.com/2021/08/02/a-minimal-nix-shell.html .

```console
$ nix path-info --closure-size --human-readable $(nix develop --command bash -c 'echo ${NIX_GCROOT}')
/nix/store/0pdgy5pwsjp6cqmk98yf4zx30gj7nigm-minimal-env   33.1 MiB
```
