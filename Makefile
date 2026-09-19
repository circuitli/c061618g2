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
#PDK           ?= ihp

# Force the build directory to anchor strictly to your current terminal path
# Use simple relative paths so Docker and the shell align perfectly
BUILD_DIR     := openlane
OUTPUT_DIR    := macros

# Keep find local to prevent path duplication errors
JSON_TARGETS  := $(shell find $(BUILD_DIR) -maxdepth 3 -type f -name "config.json" 2>/dev/null)
MACRO_SUBDIRS := $(patsubst %/,%,$(dir $(JSON_TARGETS)))
MACRO_NAMES   := $(notdir $(MACRO_SUBDIRS))

# Tool execution definition hook
OPENLANE_CONTAINER := docker run --rm \
  -v "$(CURDIR)":/work \
  -v "$(PDK_ROOT)":"$(PDK_ROOT)" \
  -e PDK_ROOT="$(PDK_ROOT)" \
  -w /work \
  ghcr.io/librelane/librelane:3.0.5 \
  python3 -m librelane

.PHONY: all clean ensure

# Main Entry Point: Runs the entire macro set simultaneously in one container
$(MACRO_NAMES):
	@echo "================================================================="
	@echo "🔨 Hardening macro component: [$@]"
	@echo "================================================================="
	
	@case "$(PDK_TARGET)" in \
		ihp-sg13g2) PDK_FINAL="ihp-sg13g2" ;; \
		sky130A)    PDK_FINAL="sky130A" ;; \
		gf180mcuC)  PDK_FINAL="gf180mcuC" ;; \
		*) echo "❌ Error: Invalid PDK select."; exit 1 ;; \
	esac; \
	\
	container_status=0; \
	\
	LOCAL_CONFIGS=""; \
	for file in $(JSON_TARGETS); do \
		if echo "$$file" | grep -q "/$@/"; then \
			LOCAL_CONFIGS="$$LOCAL_CONFIGS $$file"; \
		fi; \
	done; \
	\
	if [ -n "$$LOCAL_CONFIGS" ] ; then \
		echo "Executing librelane..."; \
		$(OPENLANE_CONTAINER) --manual-pdk --pdk-root "$(PDK_ROOT)" --pdk "$$PDK_FINAL" $$LOCAL_CONFIGS || container_status=$$?; \
	else \
		echo "❌ Error: No configurations found matching macro folder: $@"; \
		exit 1; \
	fi; \
	\
	if [ $$container_status -ne 0 ]; then \
		echo "❌ Error: LibreLane failed on macro $@ with exit code $$container_status"; \
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
	@echo "🧹 Wiping old synthesis run records and macro delivery paths..."; \
	@for dir in $(MACRO_NAMES); do \
		rm -rf $(BUILD_DIR)/$$dir/runs/; \
	done; \
	rm -rf $(OUTPUT_DIR); \
	@echo "✨ Workspace is completely clean."

# Ensure directories exist
ensure:
	@echo "🧹 Creating macro and record delivery paths..." ; \
	@for dir in $(MACRO_NAMES); do \
		mkdir -p $(BUILD_DIR)/$$dir/runs/.placeholder; \
		touch $(BUILD_DIR)/$$dir/runs/.placeholder/.placeholder; \
	done; \
	mkdir -p $(OUTPUT_DIR); \
	@echo "✨ Workspace is completely ready for consumption."
