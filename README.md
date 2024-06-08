# Photos
[![Packaging status](https://repology.org/badge/tiny-repos/elementary-photos.svg)](https://repology.org/metapackage/elementary-photos)
[![Translation status](https://l10n.elementary.io/widgets/photos/-/svg-badge.svg)](https://l10n.elementary.io/projects/photos/?utm_source=widget)

![Photos Screenshot](data/screenshot.png?raw=true)

## Building, Testing, and Installation

You'll need the following dependencies:
* gtk4
* granite7
* meson
* valac

Run `flatpak-builder` to configure the build environment, download dependencies, build, and install

```bash
    flatpak-builder build io.elementary.videos.yml --user --install --force-clean --install-deps-from=appcenter
```

Then execute with

```bash
    flatpak run io.elementary.videos
