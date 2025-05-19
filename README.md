# GitHub Artifacts Manager

A PowerShell utility for managing GitHub Actions artifacts across repositories with advanced filtering, reporting, and cleanup capabilities.

## Description

This tool provides a comprehensive solution for GitHub repository administrators to manage artifacts created by GitHub Actions workflows. It offers an interactive interface to analyze, report on, and clean up artifacts across multiple repositories with flexible filtering options.

## Key Features

 - **Repository Agnostic:** Works with any GitHub organization or personal account
 - **Flexible Selection:** Choose individual repositories or scan entire organizations
 - **Advanced Filtering:** Filter artifacts by:
   - Date ranges
   - Age in days (e.g., older than 60 days)
   - Creation dates
 - **Detailed Reporting:**
 - Repository-level summaries
   - Size analytics (bytes, MB, GB)
   - Creation date tracking
**Data Export:** Save artifact information to CSV for audit and record-keeping
**Bulk Cleanup:** Safely delete artifacts that match your criteria
**Error Handling:** Robust error management with diagnostic information

## Use Cases

 - **Storage Optimization:** Identify and remove old artifacts to reduce GitHub storage costs
 - **Audit & Compliance:** Generate reports on artifact usage across repositories
 - **Maintenance Automation:** Schedule regular cleanup of artifacts older than your retention policy
 - **Storage Analysis:** Identify repositories consuming excessive artifact storage

## Requirements

 - PowerShell 5.1 or higher
 - GitHub CLI (gh) installed and authenticated
 - Appropriate GitHub permissions for the target repositories

## Recommended Usage

For standard maintenance, running the script with the "older than X days" option (typically 45-60 days) provides a good balance between retention and storage optimization.
This utility is designed to be used as part of a regular maintenance schedule to keep GitHub Actions storage usage optimized while maintaining sufficient artifact history.RetryClaude can make mistakes. Please double-check responses.
