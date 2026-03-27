AJV = npx ajv
SCHEMA = schemas/flowdsl.schema.json
EXAMPLES = examples

.PHONY: validate validate-file docs help

## validate: validate all example files in examples/ and examples/integrations/
validate:
	@echo "Validating all examples against $(SCHEMA)..."
	@for f in $(EXAMPLES)/*.flowdsl.json $(EXAMPLES)/*.flowdsl.yaml \
	           $(EXAMPLES)/integrations/*.flowdsl.json $(EXAMPLES)/integrations/*.flowdsl.yaml; do \
		[ -e "$$f" ] || continue; \
		echo "  checking $$f"; \
		$(AJV) validate -s $(SCHEMA) -d "$$f" --strict=false -c ajv-formats || exit 1; \
	done
	@echo "All examples valid."

## validate-file FILE=path: validate a single file
validate-file:
ifndef FILE
	$(error FILE is not set. Usage: make validate-file FILE=path/to/your.flowdsl.yaml)
endif
	@echo "Validating $(FILE) against $(SCHEMA)..."
	$(AJV) validate -s $(SCHEMA) -d "$(FILE)" --strict=false -c ajv-formats

## docs: list all documentation files
docs:
	@echo "FlowDSL specification docs:"
	@find docs -name "*.md" | sort | sed 's/^/  /'

## help: show available targets
help:
	@echo "Available targets:"
	@grep -E '^## ' Makefile | sed 's/^## /  /'
