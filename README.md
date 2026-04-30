# folderViews

Per-folder **thumbnail size + sort key + sort direction** for xochitl's
My Files browser on the rMPP Move (porsche). Each folder remembers its
own view settings across xochitl restarts.

## What it does

By default xochitl persists three globals for the My Files browser:

- `[General]/ExplorerThumbnail` — `Large/Medium/Small/List`
- `[General]/HomeSortOrder` — sort key (e.g. last-modified, alphabetical)
- `[General]/AscendingSort` — sort direction

Whenever you change any of those in one folder, xochitl applies the
change to every folder. With this plugin loaded, those three values are
also saved per-folder, keyed by the folder's UUID. Navigate to a folder
that has a saved record, and the plugin restores its view.

Folders without a saved record fall back to whatever's currently in
`xochitl.conf` (i.e. the most-recently-used view).

State file: `/home/root/.folderViews.json`

```json
{
  "<folder-uuid>": { "thumbnailSize": 0, "homeSortOrder": 7, "ascendingOrder": false },
  "__root__":      { "thumbnailSize": 3, "homeSortOrder": 0, "ascendingOrder": true }
}
```

`__root__` is the My Files root (xochitl's empty-string parent).

## Install

```
make install                              # default DEVICE=192.168.1.115 (porsche WLAN)
make install DEVICE=10.11.99.1            # USB
```

Requires:

- `qt-resource-rebuilder` xovi extension on the device (already shipped
  on porsche).
- `qmldiff` binary at `~/src/qmldiff/target/release/qmldiff` (or set
  `QMLDIFF=...`).
- `reference/hashtab` (symlinked from `freeColour.plugin/reference/hashtab`,
  fw 3.26.0.68).

Restarts xochitl on install. ~2s downtime.

## Uninstall

```
make uninstall    # removes the qmd; state file kept in case you reinstall
make reset        # clears per-folder customizations (state file)
```

`make uninstall` followed by `make reset` returns the device to stock.

## How it works

Patches `/qml/device/view/syncserviceexplorer/TreeExplorerView.qml`,
inserting six properties / four signal handlers / six functions at the
root `Item#treeExplorerView`:

- Watcher properties (`fvWatchFolder`, `fvWatchSort`, `fvWatchAsc`,
  `fvWatchThumb`) mirror `treeExplorerView.explorer.currentFolderId`,
  `Settings.homeSortOrder`, `Settings.ascendingOrder`, and
  `thumbnailSettings.thumbnailSize`. QML re-emits `...Changed` on
  watcher mirrors whenever the upstream binding propagates, giving us
  reliable signal entry points.
- `onFvWatchFolderChanged → fvApply()` restores the saved view for the
  newly-current folder.
- `onFvWatchSort/Asc/ThumbChanged → fvPersist()` snapshots the current
  globals into the per-folder map.
- `fvApplying` flag suppresses the persist→apply→persist feedback loop.
- `Component.onCompleted: fvApply()` covers the initial folder shown at
  xochitl startup.

State I/O is via `XMLHttpRequest` GET/PUT to `file:///home/root/...`,
the same pattern `shoppingMode.qmd` and `freeColour.qmd` use for
persistent state.

## Limitations / non-goals

- **My Files only.** The patch hooks `TreeExplorerView.qml`. Tag,
  search, trash, favorites, integrations, and filter views (PDFs /
  Notebooks / Ebooks) are unaffected — they use `ExplorerView.qml`
  inside `TagExplorerView.qml`, which goes via a separate
  `thumbnailSettings { settingsKey: ThumbnailSettings.Explorer }`
  instance. Same xochitl.conf key, but those views aren't routed
  through our hook, so they show whatever's currently in the globals.
- **No "Set as default for all" button.** Out of scope for v1. To
  reset all per-folder customizations: `make reset`. Adding a button
  would require also patching `SortDropdown.qml`.
- **No migration / versioning.** If we change the JSON shape later,
  the next load just throws away unrecognized fields.
- **Foreign folder caveat.** Mirrored docs land under porsche's
  `Ferrari/` UUID. That folder gets its own per-folder view, but
  ferrari's UUIDs underneath are also visible — and ferrari's per-folder
  prefs are *not* synced. If we ever want symmetric ferrari↔porsche
  per-folder views, the JSON would need to live in mirrored state.

## Reset / debugging

```
make status            # shows installed qmd + current state file
make reset             # rm /home/root/.folderViews.json + xochitl restart
ssh porsche-wlan 'journalctl -u xochitl -n 200 -f' | grep -i 'folderviews\|qt-resource'
```

If xochitl fails to start after install, the QML parse failed. Pull
journalctl, find the parse error, fix the diff, recompile, reinstall.
Worst case: `ssh root@<device> 'rm /home/root/xovi/exthome/qt-resource-rebuilder/folderViews.qmd && systemctl restart xochitl'`.

## Related

- `freeColour.plugin/` — reference for the qmldiff toolchain (hashtab,
  compile-qmd.sh).
- `shoppingMode.plugin/` — reference for the file-based-state pattern
  via XMLHttpRequest GET/PUT.
- `~/src/rm-xovi-extensions/qt-resource-rebuilder/` — the xovi extension
  that loads our qmd at runtime, hooking `qRegisterResourceData`.
- `~/Documents/remarkable/ferrari/scratch/qml-dump/all-decompressed.bin`
  — the QML tree this diff was authored against (firmware 3.26.0.68).
