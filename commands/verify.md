# /verify — Verification Engineering Harness

5-phase verification loop:
1. Detect language, generate property-based tests
2. Build interaction matrix (A→B, B→C→A pipelines)
3. Fix-retry loop (max 3 iterations)
4. Adversarial sub-agent tries to break the code
5. Structured PASS/FAIL report with all fixes documented

Usage: `/verify [file_or_directory]`

Default: current working directory.
