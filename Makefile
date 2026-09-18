# Copyright 2026 circuitli (https://github.com)
# 
# Licensed under the CERN Open Hardware Licence Version 2 - Weakly Reciprocal (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://cern-ohl.web.cern.ch/
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# =============================================================================
# AUTOMATED MULTI-MACRO HARDENING PIPELINE
# =============================================================================

# Shorthand PDK parameter selection (Defaults to IHP SG13G2)
PDK           ?= ihp
BUILD_DIR     := openlane
OUTPUT_DIR    := macros

# Tool execution definition hook
OPENLANE_CONTAINER := docker run --rm \
  -v "$(CURDIR)":/work \
  -v "$(PDK_ROOT)":"$(PDK_ROOT)" \
  -e PDK_ROOT="$(PDK_ROOT)" \
  -w /work \
  ghcr.io/librelane/librelane:3.0.5 \
  python3 -m librelane

# 1. Dynamically find all subdirectories inside openlane/
MACRO_SUBDIRS := $(wildcard $(BUILD_DIR)/*)
MACRO_NAMES   := $(notdir $(MACRO_SUBDIRS))

# 2. Build the exact list of ALL configuration file paths space-separated
JSON_TARGETS  := $(foreach dir,$(MACRO_NAMES),$(BUILD_DIR)/$(dir)/config.json)

.PHONY: all clean

# Main Entry Point: Runs the entire macro set simultaneously in one container
all:
	@echo "================================================================="
	@echo "🔨 Hardening all macro components together"
	@echo "================================================================="
	
	@case "$(PDK)" in \
		ihp)    PDK_TARGET="ihp-sg13g2" ;; \
		sky130) PDK_TARGET="sky130A" ;; \
		gf180)  PDK_TARGET="gf180mcuC" ;; \
		*) echo "❌ Error: Invalid PDK select. Use PDK=ihp|sky130|gf180"; exit 1 ;; \
	esac; \
	\
	container_status=0; \
	if [ -n "$(JSON_TARGETS)" ] ; then \
		$(OPENLANE_CONTAINER) --manual-pdk --pdk-root $(PDK_ROOT) --pdk $$PDK_TARGET $(JSON_TARGETS) || container_status=$$?; \
	fi; \
	if [ "$$container_status" -ne 0 ]; then \
		echo "❌ Error: LibreLane multi-macro build failed with exit code $$container_status"; \
		exit $$container_status; \
	fi; \
	\
	echo "📦 Extracting and organizing abstract views..."; \
	for macro in $(MACRO_NAMES); do \
		RAW_LEF=$$(find $(BUILD_DIR)/$$macro/runs/ -type f -name "*.lef" -print -quit); \
		RAW_LIB=$$(find $(BUILD_DIR)/$$macro/runs/ -type f -name "*.lib" -print -quit); \
		RAW_GDS=$$(find $(BUILD_DIR)/$$macro/runs/ -type f -name "*.gds" -print -quit); \
		RAW_NL=$$(find $(BUILD_DIR)/$$macro/runs/ -type f -name "*.nl.v" -print -quit); \
		RAW_PNL=$$(find $(BUILD_DIR)/$$macro/runs/ -type f -name "*.pnl.v" -print -quit); \
		RAW_SPEF=$$(find $(BUILD_DIR)/$$macro/runs/ -type f -name "*.spef" -print -quit); \
		\
		mkdir -p "$(OUTPUT_DIR)/lef" "$(OUTPUT_DIR)/lib" "$(OUTPUT_DIR)/gds" "$(OUTPUT_DIR)/nl" "$(OUTPUT_DIR)/pnl" "$(OUTPUT_DIR)/spef"; \
		\
		if [ -n "$$RAW_LEF" ] ; then cp "$$RAW_LEF"  "$(OUTPUT_DIR)/lef"; fi; \
		if [ -n "$$RAW_LIB"  ]; then cp "$$RAW_LIB"  "$(OUTPUT_DIR)/lib/$$macro.lib"; fi; \
		if [ -n "$$RAW_GDS"  ]; then cp "$$RAW_GDS"  "$(OUTPUT_DIR)/gds/$$macro.gds"; fi; \
		if [ -n "$$RAW_NL"   ]; then cp "$$RAW_NL"   "$(OUTPUT_DIR)/nl"; fi; \
		if [ -n "$$RAW_PNL"  ]; then cp "$$RAW_PNL"  "$(OUTPUT_DIR)/pnl"; fi; \
		if [ -n "$$RAW_SPEF" ]; then cp "$$RAW_SPEF" "$(OUTPUT_DIR)/spef"; fi; \
	done; \
	echo "✅ Successfully delivered all abstract macro views to: $(OUTPUT_DIR)"

# Clean environment workspace pass
clean:
	@echo "🧹 Wiping old synthesis run records and macro delivery paths..."
	@for dir in $(MACRO_NAMES); do \
		rm -rf $(BUILD_DIR)/$$dir/runs/; \
	done
	rm -rf $(OUTPUT_DIR)
	@echo "✨ Workspace is completely clean."
