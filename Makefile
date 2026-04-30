# folderViews — per-folder thumbnail-size + sort persistence (porsche).
#
# Default target: porsche WLAN (192.168.1.115). Override:
#     make install DEVICE=10.11.99.1            # USB
#     make install DEVICE=192.168.1.112         # ferrari (untested)
#
# Targets:
#     compile     compile src/folderViews.qml-diff -> build/folderViews.qmd
#     install     compile + scp to device + restart xochitl
#     reinstall   alias for install
#     uninstall   rm device qmd + restart xochitl (state file untouched)
#     reset       rm /home/root/.folderViews.json on device (clears all
#                 per-folder customizations) + restart xochitl
#     status      list installed qmds on device
#     decompile   decompile build/folderViews.qmd to /tmp for inspection

DEVICE   ?= 192.168.1.115
SSH       = ssh -o StrictHostKeyChecking=no root@$(DEVICE)
SCP       = scp -o StrictHostKeyChecking=no
QMD_DIR   = /home/root/xovi/exthome/qt-resource-rebuilder
EXT       = build/folderViews.qmd
SRC       = src/folderViews.qml-diff
QMLDIFF  ?= $(HOME)/src/qmldiff/target/release/qmldiff

.PHONY: compile install reinstall uninstall reset status decompile

compile: $(EXT)

$(EXT): $(SRC) reference/hashtab bin/compile-qmd.sh
	@bash bin/compile-qmd.sh $(SRC)

install: compile
	@echo "==> Pushing folderViews.qmd to $(DEVICE)"
	@$(SCP) $(EXT) root@$(DEVICE):$(QMD_DIR)/folderViews.qmd
	@echo "==> Restarting xochitl"
	@$(SSH) 'systemctl restart xochitl'
	@echo "==> Done. Open My Files, change view in a folder, navigate away and back."

reinstall: install

uninstall:
	@$(SSH) 'rm -f $(QMD_DIR)/folderViews.qmd'
	@$(SSH) 'systemctl restart xochitl'
	@echo "==> Uninstalled (state file /home/root/.folderViews.json left in place)."

reset:
	@$(SSH) 'rm -f /home/root/.folderViews.json'
	@$(SSH) 'systemctl restart xochitl'
	@echo "==> Per-folder customizations cleared."

status:
	@$(SSH) 'ls -la $(QMD_DIR)/folderViews.qmd 2>/dev/null && echo "--- state ---" && (test -f /home/root/.folderViews.json && cat /home/root/.folderViews.json || echo "(no state file yet)")'

decompile: $(EXT)
	@cp $(EXT) /tmp/folderViews.decoded.qmd
	@$(QMLDIFF) hash-diffs -r reference/hashtab /tmp/folderViews.decoded.qmd >/dev/null 2>&1
	@echo "Decompiled to /tmp/folderViews.decoded.qmd"
