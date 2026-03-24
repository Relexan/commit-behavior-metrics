# Commit-Level Behavioral Metrics Extraction Tool

> ⚡ Developed for empirical software engineering research on behavioral complexity and implementation strategies.

This project provides a PowerShell-based script for extracting commit-level software metrics. It is designed to support empirical software engineering research by analyzing how behavioral changes are implemented across software systems.

## 🎯 Purpose

The tool focuses on measuring **behavioral complexity** and **structural impact** of commits. Instead of full static analysis, it relies on **diff-based metric extraction** to provide consistent and comparable results across different projects.

## 📊 Extracted Metrics

The script computes the following metrics:

- **CF (Changed Files):** Number of modified files in a commit  
- **CAU (Changed Architectural Units):** Approximation based on directory structure  
- **LCC (Lines of Code Changed):** Insertions + deletions  
- **Normalized LCC:** LCC relative to file size  
- **CM (Changed Methods):** Estimated number of modified methods  
- **CC (Cyclomatic Complexity):** Based on control-flow constructs  
- **LOCG (Logical Operators Count):** &&, ||, ! occurrences  
- **APC (Atomic Predicate Count):** Comparison and predicate expressions  
- **CondChurn:** Conditional statement changes (if, switch, etc.)

## ⚠️ Notes on Methodology

This tool uses **heuristic and diff-based metric extraction** rather than full static code analysis. The goal is to ensure:

- Consistency across commits  
- Comparability between different systems  
- Lightweight and reproducible measurement  

> These metrics are suitable for **empirical comparison**, not exact static analysis.

## 🛠️ Usage

### 1. Clone the target repository
### 2. Run the script
.\script.ps1 -Repo "PATH_TO_TARGET_REPO" -Hash "COMMIT_HASH"
