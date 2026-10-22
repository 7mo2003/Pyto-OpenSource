# Pyto

## Open-source fork status

This independent MIT-licensed fork adds a reviewable `PYTO_OPEN_SOURCE` local full-feature build mode and a macOS GitHub Actions pipeline. It does not include any user-uploaded IPA, injected libraries taken from it, or signing credentials.

**No IPA has been produced.** Seven macOS CI attempts exposed unresolved compatibility problems in historical native dependencies, including SciPy BLAS/LAPACK configuration, libxml2/libxslt, Matplotlib, Pillow/libpng, pandas and PyYAML. [Latest tested build and diagnostics](https://github.com/7mo2003/Pyto-OpenSource/actions/runs/39694960478). The full-feature code has not been validated by a successful app build or iPhone runtime test.

See [دليل البناء وحالته بالعربية](BUILD-AR.md). Any future IPA from the workflow is unsigned and needs appropriate signing/provisioning before installation. The App Store link below belongs to the upstream project, not an installable release of this fork.

[![Download on the App Store](https://pisth.github.io/appstorebadge.svg)](https://itunes.apple.com/us/app/pyto-python-ide/id1436650069?l=fr&ls=1&mt=8)

[Documentation](https://pyto.readthedocs.io)

## Building

`$ ./setup.sh`

This will take some time because it will compile all the dependencies.

Then open `Pyto.xcworkspace` and build the `Pyto` scheme.
