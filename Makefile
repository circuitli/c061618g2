# =============================================================================
# AUTOMATED MULTI-MACRO HARDENING PIPELINE
# =============================================================================

# Shorthand PDK parameter selection (Defaults to IHP SG13G2)
PDK           ?= ihp
BUILD_DIR     := openlane
OUTPUT_DIR    := macro

# THE ARCHITECTURAL WIN: The tool execution definition is kept purely as the binary hook.
# The actual file array targets are dynamically appended at runtime.
OPENLANE_CONTAINER := docker run --rm \
  -v "$(CURDIR)":"$(CURDIR)" \
  -v "$$LOCAL_PDK_ROOT":"$$LOCAL_PDK_ROOT" \
  -e PDK_ROOT="$$LOCAL_PDK_ROOT" \
  -w "$(CURDIR)" \
  ghcr.io/librelane/librelane:3.0.5 \
  python3 -m librelane

# Dynamically find all immediate subdirectories inside macro_build/
# Each subdirectory represents a standalone block (e.g., macro_build/filter_1)
MACRO_SUBDIRS := $(wildcard $(BUILD_DIR)/*)
MACRO_NAMES   := $(notdir $(MACRO_SUBDIRS))
JSON_TARGETS  := $(foreach dir,$(MACRO_NAMES),$(BUILD_DIR)/$(dir)/config.json)

.PHONY: all clean $(MACRO_NAMES)

# 1. Main entry point: Hardens every discovered macro block sequentially
all: $(MACRO_NAMES)

# 2. Pattern Rule: Hardens an individual directory target
$(MACRO_NAMES):
	@echo "================================================================="
	@echo "🔨 Hardening macro component: [$@]"
	@echo "================================================================="
	
	# Resolve shorthand PDK platform names to strict OpenLane 2 system definitions
	@case "$(PDK)" in \
		ihp)    PDK_TARGET="ihp-sg13g2" ;; \
		sky130) PDK_TARGET="sky130A" ;; \
		gf180)  PDK_TARGET="gf180mcuC" ;; \
		*) echo "❌ Error: Invalid PDK select. Use PDK=ihp|sky130|gf180"; exit 1 ;; \
	esac; \
	\
	# Let OpenLane consume the environment parameter directly from the Docker instance map.
	$(OPENLANE_CONTAINER) --manual-pdk --pdk $$PDK_TARGET $(JSON_TARGETS); \
	\
	# Locate the true physical hardware layout and timing assets
	RAW_LEF =$$(find $(BUILD_DIR)/$@/runs/ -type f -path "*/final/lef/*"    -name "*.lef" -print -quit); \
	RAW_LIB =$$(find $(BUILD_DIR)/$@/runs/ -type f -path "*/final/lib/*"    -name "*.lib" -print -quit); \
	RAW_GDS =$$(find $(BUILD_DIR)/$@/runs/ -type f -path "*/final/gds/*"    -name "*.gds" -print -quit); \
	RAW_NL  =$$(find $(BUILD_DIR)/$@/runs/ -type f -path "*/final/nl/*"     -name "*.v" -print -quit); \
	RAW_PNL =$$(find $(BUILD_DIR)/$@/runs/ -type f -path "*/final/pnl/*"    -name "*.v" -print -quit); \
	RAW_SPEF=$$(find $(BUILD_DIR)/$@/runs/ -type f -path "*/final/spef/*/*" -name "*.v" -print -quit); \
	\
	mkdir -p $(OUTPUT_DIR); \
	\
	# Safe copy operations mapping abstracts straight to the delivery folder
	if [ -n "$$RAW_LEF" ] ; then cp "$$RAW_LEF"  "$(OUTPUT_DIR)/lef/$@.lef"; fi; \
	if [ -n "$$RAW_LIB"  ]; then cp "$$RAW_LIB"  "$(OUTPUT_DIR)/lib/$@.lib"; fi; \
	if [ -n "$$RAW_GDS"  ]; then cp "$$RAW_GDS"  "$(OUTPUT_DIR)/gds/$@.gds"; fi; \
	if [ -n "$$RAW_NL"   ]; then cp "$$RAW_NL"   "$(OUTPUT_DIR)/nl/$@.v"; fi; \
	if [ -n "$$RAW_PNL"  ]; then cp "$$RAW_PNL"  "$(OUTPUT_DIR)/pnl/$@.v"; fi; \
    if [ -n "$$RAW_SPEF" ]; then cp "$$RAW_SPEF" "$(OUTPUT_DIR)/spef/$@.spef"; fi; \
	\
	echo "✅ Successfully delivered abstract macro views to: $(OUTPUT_DIR)/$@.*"

# 3. Clean environment workspace pass
clean:
	@echo "🧹 Wiping old synthesis run records and macro delivery paths..."
	@for dir in $(MACRO_NAMES); do \
		rm -rf $(BUILD_DIR)/$$dir/runs/; \
	done
	rm -rf $(OUTPUT_DIR)
	@echo "✨ Workspace is completely clean."
