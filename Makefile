# Everyday commands. Run `make help` for the list.
#
# Tools are pinned by Rokit and called through their shims in ~/.rokit/bin by ABSOLUTE, QUOTED path:
#   - GNU Make 3.81 (macOS default) looks programs up with its *startup* PATH when it runs a recipe
#     directly, so merely adding ~/.rokit/bin to PATH here is not enough;
#   - PATH (or HOME) may contain spaces (e.g. VS Code terminals add "Application Support" paths),
#     so it must never be spliced unquoted into a command.
# PATH is still exported so child scripts (typecheck.sh, Lune scripts) find the same tools.
ROKIT_BIN := $(HOME)/.rokit/bin
export PATH := $(ROKIT_BIN):$(PATH)

ROKIT  := "$(ROKIT_BIN)/rokit"
ROJO   := "$(ROKIT_BIN)/rojo"
STYLUA := "$(ROKIT_BIN)/stylua"
SELENE := "$(ROKIT_BIN)/selene"
WALLY  := "$(ROKIT_BIN)/wally"
LUNE   := "$(ROKIT_BIN)/lune"

GAME_PROJECT := default.project.json
TEST_PROJECT := test.project.json
BUILD_DIR    := build
STUDIO_PLUGINS_DIR := $(HOME)/Documents/Roblox/Plugins

.DEFAULT_GOAL := help
.PHONY: help install tools packages studio-plugin dev dev-test build build-test studio studio-test \
        format format-check lint typecheck validate test check sourcemap clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

install: tools packages ## Install pinned tools (Rokit) and Luau packages (Wally)
	@$(LUNE) setup >/dev/null && echo "Lune type definitions installed (~/.lune/.typedefs)"
	@echo "Done. Optional: 'make studio-plugin' installs the Rojo plugin into Roblox Studio."

tools: ## Install the toolchain pinned in rokit.toml
	@test -x $(ROKIT) || { echo "Rokit missing: see README.md#prerequisites"; exit 1; }
	$(ROKIT) install

packages: ## Install Wally packages (DevPackages/, Packages/)
	$(WALLY) install

studio-plugin: ## Install the Rojo plugin matching the pinned Rojo version into Studio
	@# Studio creates its plugins folder on first launch; create it so this also works before that (macOS).
	@if [ "$$(uname)" = "Darwin" ]; then mkdir -p "$(STUDIO_PLUGINS_DIR)"; fi
	$(ROJO) plugin install

dev: ## Live-sync the GAME into Studio (Rojo plugin > Connect)
	$(ROJO) serve $(GAME_PROJECT)

dev-test: ## Live-sync the TEST place (includes specs + TestRunner) into Studio
	$(ROJO) serve $(TEST_PROJECT)

build: ## Build the shippable place file -> build/game.rbxl
	@mkdir -p $(BUILD_DIR)
	$(ROJO) build $(GAME_PROJECT) -o $(BUILD_DIR)/game.rbxl

build-test: ## Build the test place file -> build/test.rbxl
	@mkdir -p $(BUILD_DIR)
	$(ROJO) build $(TEST_PROJECT) -o $(BUILD_DIR)/test.rbxl

studio: build ## Build and open the game place in Roblox Studio
	open $(BUILD_DIR)/game.rbxl

studio-test: build-test ## Build and open the test place in Studio (press Play to run specs)
	open $(BUILD_DIR)/test.rbxl

format: ## Format all Luau with StyLua
	$(STYLUA) .

format-check: ## Fail if any file is not formatted
	$(STYLUA) --check .

lint: ## Lint with Selene (game + specs, then Lune tooling)
	$(SELENE) src tests
	cd tools && $(SELENE) --config selene.toml .

typecheck: ## Strict Luau type checking with luau-lsp + Roblox definitions
	./tools/typecheck.sh

validate: ## Validate Rojo projects and architecture invariants
	$(LUNE) run tools/validate-project.luau

test: ## Run all specs headlessly (Lune + TestEZ)
	$(LUNE) run tools/test.luau

check: format-check lint typecheck validate test ## Everything CI runs
	@printf "\033[32mAll checks passed.\033[0m\n"

sourcemap: ## Regenerate sourcemap.json (the VS Code extension does this automatically)
	$(ROJO) sourcemap $(TEST_PROJECT) --output sourcemap.json

clean: ## Remove build outputs and caches
	rm -rf $(BUILD_DIR) sourcemap.json .cache
