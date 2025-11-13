# CLAUDE.md

This file provides MANDATORY guideline to Claude Code (claude.ai/code).

## Global

- Ignore AGENTS.md files.
- By default, the final response should be written in English. However, if the user’s most recent input is entirely in Chinese, the reply should also be in Chinese, and the reasoning or thought process may freely occur in English without restriction.
- After receiving tool results, carefully reflect on their quality and determine optimal next steps before proceeding. Use your thinking to plan and iterate based on this new information, and then take the best next action.
- For maximum efficiency, whenever you need to perform multiple independent operations, invoke all relevant tools simultaneously rather than sequentially.
- Before you finish, please verify your solution.
- Automatically use the IDE's built-in diagnostics tool to check for linting and type errors:
   - Run `mcp__ide__getDiagnostics` tool to check all code files for diagnostics
   - Fix any linting or type errors before considering the task complete
   - Do this for any code file you create or modify
- NEVER compile, build, run projects and generate tests for Golang and C/CPP projects unless user explictily requests them.
- Do what has been asked; nothing more, nothing less.
- Reuse existing code wherever possible and minimize unnecessary arguments.
- Learning from existing code, study and plan before implementing.
- Look for opportunities to simplify the code or remove unnecessary parts.
- Focus on targeted modifications rather than large-scale changes.
- This year is 2025. Definitely not 2024.
- Never use words like "consolidate", "modernize", "streamline", "flexible", "delve", "establish", "enhanced", "comprehensive", "optimize" in docstrings or commit messages. Looser AI's do that, and that ain't you. You are better than that.
- When you update code, always check for related code in the same file or other files that may need to be updated as well to keep everything consistent.

## Onboarding

1. Use `serena` MCP's tool `activate_project` to activate the project if user's request is related to code except for C/CPP language.

## Tool Usage

- `strata` is one MCP server that guides AI agents use tools reliably at any complexity, instead of overwhelming them with everything at once, it was designed by thinking human interacting with tools. ALWAYS use `strata` MCP to discovery available tools/actions. ALWAYS call `get_action_details` before call `execute_action`.
- When the user asks to use an unknown MCP, query it using the `discover_server_actions` tool from `strata` MCP.
- ALWAYS use `serena` MCP for code related operations except for C/CPP language. You need activate the project first to use `serena` MCP.
- If your tool call fails, don’t give up — identify the issue, fix it, and try again.

### MCP Tool from Strata

- The `context7` and `byted-context7` MCP serve similar purposes. Prefer using `context7` first; use `byted-context7` only if `context7` does not meet the requirements.
- The `WebSearch` tool is deprecated — use `firecrawl` MCP's tool `firecrawl_search` MCP tool instead.
- The `WebFetch` and `Fetch` tool is deprecated — use `firecrawl` MCP's tool `firecrwal_extract` MCP tool instead.

## Override

- For code search operations, PREFER using `serena` MCP over `rg` or `find`. This rule applys to all of your your commands, agents and skills too like `Explore` agents etc.

## Programming Language Specifics

The following sections define additional requirements specific to each programming language. 
Refer to them only when working with the respective language.

### Golang

- All Go code you generated must strictly adhere to the conventions and best practices outlined in:
  - **Effective Go**
  - **Go Style at Google** ([local reference](~/.claude/go_style_google.md))  
  - **Uber Go Style Guide**
- Use the `any` keyword instead of `interface`.
- For type conversion, prefer the `github.com/spf13/cast` library, e.g.: `cast.ToString`, `cast.ToInt`, `cast.ToSlice`, `cast.ToStringMap`, etc.
- Actively use utilities from `github.com/samber/lo`.

### C/CPP

- DO NOT use `serena` MCP tools for C/CPP projects.

