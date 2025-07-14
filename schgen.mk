# Schematic Generation Makefile
# Usage: make -f schgen.mk VSRC=./path/to/verilog/files [TOP=module_name]
#
# This makefile:
# 1. Finds all .v and .sv files in VSRC directory
# 2. Converts .sv files to .v using sv2v
# 3. Copies all .v files to scheme/sv2v/
# 4. Analyzes module dependencies
# 5. Generates high-level schematics using Yosys
# 6. Converts DOT files to PNG images

# Default values
VSRC ?= .
TOP ?= auto
OUTPUT_BASE = $(VSRC)/scheme
SV2V_DIR = $(OUTPUT_BASE)/sv2v
DOT_DIR = $(OUTPUT_BASE)/dot
PNG_DIR = $(OUTPUT_BASE)/png

# Tools
YOSYS = yosys
SV2V = ./sv2v
DOT = dot

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m # No Color

.PHONY: all clean setup convert analyze generate generate-all convert-images help list-modules

# Default target
all: setup convert analyze generate convert-images
	@echo "$(GREEN)✓ Schematic generation complete!$(NC)"
	@echo "$(BLUE)Generated files:$(NC)"
	@find $(PNG_DIR) -name "*.png" -exec echo "  📊 {}" \;

# Create directory structure
setup:
	@echo "$(BLUE)📁 Setting up directories...$(NC)"
	@mkdir -p $(SV2V_DIR) $(DOT_DIR) $(PNG_DIR)

# Convert SystemVerilog files to Verilog and copy all Verilog files
convert: setup
	@echo "$(BLUE)🔄 Processing Verilog files...$(NC)"
	@if [ ! -d "$(VSRC)" ]; then \
		echo "$(RED)❌ Error: Source directory $(VSRC) does not exist$(NC)"; \
		exit 1; \
	fi
	
	# Find and convert .sv files (with smart caching)
	@sv_files=$$(find $(VSRC) -maxdepth 1 -name "*.sv" -type f 2>/dev/null || true); \
	if [ -n "$$sv_files" ]; then \
		echo "$(YELLOW)🔧 Converting SystemVerilog files...$(NC)"; \
		for sv_file in $$sv_files; do \
			basename=$$(basename $$sv_file .sv); \
			target_file="$(SV2V_DIR)/$$basename.v"; \
			if [ ! -f "$$target_file" ] || [ "$$sv_file" -nt "$$target_file" ]; then \
				echo "  Converting $$sv_file -> $$target_file"; \
				$(SV2V) $$sv_file > $$target_file; \
			else \
				echo "  ⏭️  Skipping $$sv_file (already converted and up-to-date)"; \
			fi; \
		done; \
	fi
	
	# Copy .v files (with smart caching)
	@v_files=$$(find $(VSRC) -maxdepth 1 -name "*.v" -type f 2>/dev/null || true); \
	if [ -n "$$v_files" ]; then \
		echo "$(YELLOW)📋 Copying Verilog files...$(NC)"; \
		for v_file in $$v_files; do \
			target_file="$(SV2V_DIR)/$$(basename $$v_file)"; \
			if [ ! -f "$$target_file" ] || [ "$$v_file" -nt "$$target_file" ]; then \
				echo "  Copying $$v_file -> $(SV2V_DIR)/"; \
				cp $$v_file $(SV2V_DIR)/; \
			else \
				echo "  ⏭️  Skipping $$v_file (already copied and up-to-date)"; \
			fi; \
		done; \
	fi
	
	@if [ -z "$$(find $(SV2V_DIR) -name "*.v" -type f 2>/dev/null)" ]; then \
		echo "$(RED)❌ Error: No Verilog files found in $(VSRC)$(NC)"; \
		exit 1; \
	fi

# Analyze module dependencies and find top module
analyze: convert
	@echo "$(BLUE)🔍 Analyzing module dependencies...$(NC)"
	@echo "# Module Analysis Report" > $(SV2V_DIR)/analysis.txt
	@echo "# Generated on $$(date)" >> $(SV2V_DIR)/analysis.txt
	@echo "" >> $(SV2V_DIR)/analysis.txt
	
	# Extract all module definitions
	@echo "## Modules found:" >> $(SV2V_DIR)/analysis.txt
	@rm -f $(SV2V_DIR)/modules.list
	@for v_file in $(SV2V_DIR)/*.v; do \
		if [ -f "$$v_file" ]; then \
			grep -E "^\s*module\s+" $$v_file | awk '{print $$2}' | while read module; do \
				if [ -n "$$module" ]; then \
					echo "  $$(basename $$v_file): $$module" >> $(SV2V_DIR)/analysis.txt; \
					echo "$$module" >> $(SV2V_DIR)/modules.list; \
				fi; \
			done; \
		fi; \
	done
	
	# Find module instantiations
	@echo "" >> $(SV2V_DIR)/analysis.txt
	@echo "## Module instantiations:" >> $(SV2V_DIR)/analysis.txt
	@for v_file in $(SV2V_DIR)/*.v; do \
		if [ -f "$$v_file" ]; then \
			echo "### In $$(basename $$v_file):" >> $(SV2V_DIR)/analysis.txt; \
			grep -E "^\s*[a-zA-Z_][a-zA-Z0-9_]*\s+[a-zA-Z_][a-zA-Z0-9_]*\s*\(" $$v_file | \
			grep -v -E "^\s*(module|input|output|wire|reg|parameter|localparam|assign)" | \
			sed 's/^\s*\([a-zA-Z_][a-zA-Z0-9_]*\)\s\+\([a-zA-Z_][a-zA-Z0-9_]*\).*/    instantiates: \1 as \2/' >> $(SV2V_DIR)/analysis.txt || true; \
		fi; \
	done
	
	@echo "$(GREEN)📋 Module analysis complete. See $(SV2V_DIR)/analysis.txt$(NC)"

# Generate schematics for all modules
generate: analyze
	@echo "$(BLUE)🎨 Generating schematics...$(NC)"
	
	# Determine top module
	@if [ "$(TOP)" = "auto" ]; then \
		echo "$(YELLOW)🔍 Auto-detecting top module...$(NC)"; \
		top_module=$$($(MAKE) -f $(lastword $(MAKEFILE_LIST)) find-top VSRC=$(VSRC)); \
		if [ -z "$$top_module" ]; then \
			echo "$(RED)❌ Could not auto-detect top module. Please specify TOP=module_name$(NC)"; \
			echo "$(BLUE)Available modules:$(NC)"; \
			$(MAKE) -f $(lastword $(MAKEFILE_LIST)) list-modules VSRC=$(VSRC); \
			exit 1; \
		fi; \
		echo "$(GREEN)🎯 Auto-detected top module: $$top_module$(NC)"; \
	else \
		top_module=$(TOP); \
		echo "$(GREEN)🎯 Using specified top module: $$top_module$(NC)"; \
	fi; \
	\
	echo "$(YELLOW)🔧 Generating schematic for $$top_module...$(NC)"; \
	$(YOSYS) -p "\
		read_verilog $(SV2V_DIR)/*.v; \
		hierarchy -top $$top_module; \
		proc; \
		opt; \
		fsm; \
		opt; \
		memory; \
		opt; \
		show -format dot -prefix $(DOT_DIR)/$$top_module $$top_module" 2>/dev/null || \
	(echo "$(RED)❌ Failed to generate schematic for $$top_module$(NC)"; exit 1); \
	\
	if [ -f "$(DOT_DIR)/$$top_module.dot" ]; then \
		echo "$(GREEN)✓ Generated: $(DOT_DIR)/$$top_module.dot$(NC)"; \
	else \
		echo "$(RED)❌ Failed to generate DOT file for $$top_module$(NC)"; \
		exit 1; \
	fi

# Generate schematics for all modules
generate-all: analyze
	@echo "$(BLUE)🎨 Generating schematics for all modules...$(NC)"
	@if [ ! -f "$(SV2V_DIR)/modules.list" ]; then \
		echo "$(RED)❌ Error: No modules found. Run 'make analyze' first.$(NC)"; \
		exit 1; \
	fi
	@modules=$$(cat $(SV2V_DIR)/modules.list 2>/dev/null | sort | uniq || true); \
	if [ -z "$$modules" ]; then \
		echo "$(RED)❌ Error: No modules found in modules.list$(NC)"; \
		exit 1; \
	fi; \
	\
	total_modules=$$(echo "$$modules" | wc -l | tr -d ' '); \
	echo "$(GREEN)🎯 Found $$total_modules modules to process$(NC)"; \
	echo "$$modules" | while read module; do \
		if [ -n "$$module" ]; then \
			echo "$(YELLOW)🔧 Generating schematic for $$module...$(NC)"; \
			$(YOSYS) -p "\
				read_verilog $(SV2V_DIR)/*.v; \
				hierarchy -top $$module; \
				proc; \
				opt; \
				fsm; \
				opt; \
				memory; \
				opt; \
				show -format dot -prefix $(DOT_DIR)/$$module $$module" 2>/dev/null && \
			echo "$(GREEN)✓ Generated: $(DOT_DIR)/$$module.dot$(NC)" || \
			echo "$(RED)❌ Failed to generate schematic for $$module$(NC)"; \
		fi; \
	done

# Find top module automatically
find-top:
	@if [ ! -f "$(SV2V_DIR)/modules.list" ]; then \
		exit 1; \
	fi
	@modules=$$(cat $(SV2V_DIR)/modules.list 2>/dev/null | tr '\n' ' ' || true); \
	if [ -z "$$modules" ]; then \
		exit 1; \
	fi; \
	\
	for module in $$modules; do \
		if [ -n "$$module" ]; then \
			is_instantiated=false; \
			for v_file in $(SV2V_DIR)/*.v; do \
				if [ -f "$$v_file" ] && grep -qE "^\s*$$module\s+[a-zA-Z_][a-zA-Z0-9_]*\s*\(" $$v_file; then \
					is_instantiated=true; \
					break; \
				fi; \
			done; \
			if [ "$$is_instantiated" = "false" ]; then \
				echo "$$module"; \
				exit 0; \
			fi; \
		fi; \
	done

# Convert DOT files to PNG images
convert-images:
	@echo "$(BLUE)🖼️  Converting to images...$(NC)"
	@for dot_file in $(DOT_DIR)/*.dot; do \
		if [ -f "$$dot_file" ]; then \
			basename=$$(basename $$dot_file .dot); \
			echo "  Converting $$dot_file -> $(PNG_DIR)/$$basename.png"; \
			$(DOT) -Tpng $$dot_file -o $(PNG_DIR)/$$basename.png; \
			if [ -f "$(PNG_DIR)/$$basename.png" ]; then \
				echo "$(GREEN)✓ Generated: $(PNG_DIR)/$$basename.png$(NC)"; \
			fi; \
		fi; \
	done

# List all available modules
list-modules:
	@echo "$(BLUE)📋 Available modules in $(VSRC):$(NC)"
	@if [ -f "$(SV2V_DIR)/modules.list" ]; then \
		cat $(SV2V_DIR)/modules.list | while read module; do \
			echo "  📦 $$module"; \
		done; \
	else \
		echo "  $(YELLOW)⚠️  No modules found. Run 'make analyze' first.$(NC)"; \
	fi

# Generate schematic for specific module
module:
	@if [ -z "$(MODULE)" ]; then \
		echo "$(RED)❌ Error: MODULE parameter required$(NC)"; \
		echo "$(BLUE)Usage: make -f schgen.mk module MODULE=module_name VSRC=$(VSRC)$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)🎨 Generating schematic for module: $(MODULE)$(NC)"
	@$(YOSYS) -p "\
		read_verilog $(SV2V_DIR)/*.v; \
		hierarchy -top $(MODULE); \
		proc; \
		opt; \
		fsm; \
		opt; \
		memory; \
		opt; \
		show -format dot -prefix $(DOT_DIR)/$(MODULE) $(MODULE)" || \
	(echo "$(RED)❌ Failed to generate schematic for $(MODULE)$(NC)"; exit 1)
	@if [ -f "$(DOT_DIR)/$(MODULE).dot" ]; then \
		echo "$(GREEN)✓ Generated: $(DOT_DIR)/$(MODULE).dot$(NC)"; \
		$(DOT) -Tpng $(DOT_DIR)/$(MODULE).dot -o $(PNG_DIR)/$(MODULE).png; \
		echo "$(GREEN)✓ Generated: $(PNG_DIR)/$(MODULE).png$(NC)"; \
	fi

# Clean generated files
clean:
	@echo "$(YELLOW)🧹 Cleaning generated files...$(NC)"
	@rm -rf $(OUTPUT_BASE)
	@echo "$(GREEN)✓ Cleaned$(NC)"

# Show help
help:
	@echo "$(BLUE)🔧 Schematic Generation Makefile$(NC)"
	@echo ""
	@echo "$(YELLOW)Usage:$(NC)"
	@echo "  make -f schgen.mk VSRC=./path/to/verilog [TOP=module_name]"
	@echo ""
	@echo "$(YELLOW)Parameters:$(NC)"
	@echo "  VSRC    - Directory containing .v/.sv files (required)"
	@echo "  TOP     - Top module name (auto-detected if not specified)"
	@echo "  MODULE  - Specific module for 'module' target"
	@echo ""
	@echo "$(YELLOW)Targets:$(NC)"
	@echo "  all           - Complete workflow (default)"
	@echo "  setup         - Create directory structure"
	@echo "  convert       - Convert .sv files and copy .v files"
	@echo "  analyze       - Analyze module dependencies"
	@echo "  generate      - Generate schematic for top module"
	@echo "  generate-all  - Generate schematics for ALL modules"
	@echo "  convert-images- Convert DOT files to PNG"
	@echo "  module        - Generate schematic for specific MODULE"
	@echo "  list-modules  - List all available modules"
	@echo "  clean         - Remove generated files"
	@echo "  help          - Show this help"
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make -f schgen.mk VSRC=./iCESugar/examples/vga"
	@echo "  make -f schgen.mk VSRC=./src TOP=cpu_core"
	@echo "  make -f schgen.mk generate-all VSRC=./src"
	@echo "  make -f schgen.mk module MODULE=alu VSRC=./src"
	@echo ""
	@echo "$(YELLOW)Requirements:$(NC)"
	@echo "  - yosys (for schematic generation)"
	@echo "  - sv2v (for SystemVerilog conversion)"
	@echo "  - dot/graphviz (for image conversion)"

# Debug target to show variables
debug:
	@echo "$(BLUE)🔍 Debug Information:$(NC)"
	@echo "VSRC: $(VSRC)"
	@echo "TOP: $(TOP)"
	@echo "OUTPUT_BASE: $(OUTPUT_BASE)"
	@echo "SV2V_DIR: $(SV2V_DIR)"
	@echo "DOT_DIR: $(DOT_DIR)"
	@echo "PNG_DIR: $(PNG_DIR)"
	@echo ""
	@echo "$(BLUE)Tools:$(NC)"
	@which $(YOSYS) >/dev/null 2>&1 && echo "✓ yosys found" || echo "❌ yosys not found"
	@which $(SV2V) >/dev/null 2>&1 && echo "✓ sv2v found" || echo "❌ sv2v not found"
	@which $(DOT) >/dev/null 2>&1 && echo "✓ dot found" || echo "❌ dot not found"
