# exynos-modem aport

Alpine/postmarketOS packaging for the public
[`pixel-mainline/exynos-modem`](https://git.deusch.me/pixel-mainline/exynos-modem)
daemon.

The package's systemd service waits for the Pixel 9a vendor mounts supplied
by `device-google-tegu` and for `/dev/umts_boot0`, then starts the combined
boot, RFS, and OEM/GEMS daemon before ModemManager.

Build it from a pmaports checkout with:

```sh
pmbootstrap build exynos-modem
```
