# modemmanager-samsung-sit

Alpine/postmarketOS aport for the `sd-samsung-sit` branch of
`pixel-mainline/ModemManager`.

`modemmanager-samsung-sit` provides and replaces `modemmanager` with provider
priority 100. Its split packages likewise replace the stock ModemManager split
packages, while the ABI library remains named `libmm-glib` so existing reverse
dependencies keep working.

## Build with pmbootstrap

Put this directory in a configured pmaports channel (for example under
`device/testing/`), then run:

```sh
pmbootstrap build modemmanager-samsung-sit
```

Add `modemmanager-samsung-sit` to the target device package's `depends` to make
the image select it instead of Alpine's `modemmanager` package.
