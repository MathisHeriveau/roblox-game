# Everyday commands. Run `make help` for the list.
# Rokit installs tool shims in ~/.rokit/bin; prepend it so targets work in any shell.
# SHELL is set explicitly because GNU Make 3.81 (macOS default) exec()s simple recipes with its
# startup PATH and would otherwise ignore the exported value.
export PATH := $(HOME)/.rokit/bin:$(PATH)
SHELL := env PATH=$(PATH) /bin/bash

GAME_PROJECT := default.project.json
TEST_PROJECT := test.project.json
BUILD_DIR    := build

.DEFAULT_GOAL := help
.PHONY: help install tools packages studio-plugin dev dev-test build build-test studio studio-test \
        format format-check lint typecheck validate test check sourcemap clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

install: tools packages ## Install pinned tools (Rokit) and Luau packages (Wally)
	@lune setup >/dev/null && echo "Lune type definitions installed (~/.lune/.typedefs)"
	@echo "Done. Optional: 'make studio-plugin' installs the Rojo plugin into Roblox Studio."

tools: ## Install the toolchain pinned in rokit.toml
	@command -v rokit >/dev/null || { echo "Rokit missing: see README.md#prerequisites"; exit 1; }
	rokit install

packages: ## Install Wally packages (DevPackages/, Packages/)
	wally install

STUDIO_PLUGINS_DIR := $(HOME)/Documents/Roblox/Plugins

studio-plugin: ## Install the Rojo plugin matching the pinned Rojo version into Studio
	@# Studio creates its plugins folder on first launch; create it so this also works before that (macOS).
	@if [ "$(shell uname)" = "Darwin" ]; then mkdir -p "$(STUDIO_PLUGINS_DIR)"; fi
	rojo plugin install

dev: ## Live-sync the GAME into Studio (Rojo plugin > Connect)
	rojo serve $(GAME_PROJECT)

dev-test: ## Live-sync the TEST place (includes specs + TestRunner) into Studio
	rojo serve $(TEST_PROJECT)

build: ## Build the shippable place file -> build/game.rbxl
	@mkdir -p $(BUILD_DIR)
	rojo build $(GAME_PROJECT) -o $(BUILD_DIR)/game.rbxl

build-test: ## Build the test place file -> build/test.rbxl
	@mkdir -p $(BUILD_DIR)
	rojo build $(TEST_PROJECT) -o $(BUILD_DIR)/test.rbxl

studio: build ## Build and open the game place in Roblox Studio
	open $(BUILD_DIR)/game.rbxl

studio-test: build-test ## Build and open the test place in Studio (press Play to run specs)
	open $(BUILD_DIR)/test.rbxl

format: ## Format all Luau with StyLua
	stylua .

format-check: ## Fail if any file is not formatted
	stylua --check .

lint: ## Lint with Selene (game + specs, then Lune tooling)
	selene src tests
	cd tools && selene --config selene.toml .

typecheck: ## Strict Luau type checking with luau-lsp + Roblox definitions
	./tools/typecheck.sh

validate: ## Validate Rojo projects and architecture invariants
	lune run tools/validate-project.luau

test: ## Run all specs headlessly (Lune + TestEZ)
	lune run tools/test.luau

check: format-check lint typecheck validate test ## Everything CI runs
	@printf "\033[32mAll checks passed.\033[0m\n"

sourcemap: ## Regenerate sourcemap.json (the VS Code extension does this automatically)
	rojo sourcemap $(TEST_PROJECT) --output sourcemap.json

clean: ## Remove build outputs and caches
	rm -rf $(BUILD_DIR) sourcemap.json .cache
