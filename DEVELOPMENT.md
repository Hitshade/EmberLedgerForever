# Development

Source: `addon/EmberLedgerForever`. Baseline version: 0.5.0.

## Tests
Use Python 3.12 and install the test dependency:

```text
python -m pip install -r requirements-dev.txt
python tests/test_alpha.py
python tests/test_broker.py
```

The tests use mocked Lua 5.1 APIs. They do not replace real-client verification.
`tests/test_native.py` additionally requires an external Forever UI source directory, as documented in that script. Those reference files are not bundled.

## Changes and releases
Work on a feature branch, review the diff, run the relevant tests, then test in-game. Preserve current saved settings, licenses, and vendor library notices.

Package only the addon directory for players. Keep research, reference archives, personal handoffs, game settings, credentials, and old packages outside Git. CurseForge publishing remains manual; this repository does not deploy releases automatically.
