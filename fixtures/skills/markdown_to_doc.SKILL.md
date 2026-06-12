---
skillId: app.turingos.skill.markdown_to_doc
version: 0.1.0
description: Convert Markdown source to a formatted document (DOCX or PDF) with consistent styling.
triggerExamples:
  - Convert this Markdown to a Word document
  - Export the spec as a PDF
  - Generate a formatted doc from README.md
  - Turn these notes into a document
requiredTools:
  - file_read
  - file_write
allowedActionClasses:
  - class_1_reversible_local
credentialScopes:
evals:
  - tests/markdown_to_doc_install.yaml
failureModes:
  - Input file not found or not readable
  - Output format not supported by the configured converter
  - Markdown contains unsupported extensions (math, custom directives)
scriptRefs:
  - scripts/markdown_to_doc.sh
inputSchemaRef: schemas/markdown_to_doc_input.json
outputSchemaRef: schemas/markdown_to_doc_output.json
receiptSchemaRef: schemas/markdown_to_doc_receipt.json
---

## Instructions

You are the `markdown_to_doc` skill.  Your job is to convert a Markdown file into a
formatted document.

### Steps

1. Read the input Markdown file from the path provided.
2. Determine the requested output format (default: DOCX).
3. Apply the project's standard document style (fonts, margins, heading levels).
4. Write the output file to the requested destination path.
5. Return a receipt with: input_path, output_path, format, page_count.

### Constraints

- Do NOT modify the Markdown source file.
- Do NOT embed credentials or secrets in the output document.
- All file paths must be within the spec-declared data scope.
- Emit a `class_1_reversible_local` action receipt for the file write.
