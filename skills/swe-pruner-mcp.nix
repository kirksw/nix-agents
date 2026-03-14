{
  skills.swe-pruner-mcp = {
    description = "Context-aware code pruning via MCP tools. Use when reading large files or searching codebases to reduce token usage by 23-54%. Triggers on 'prune', 'reduce tokens', 'large files', or when context budget is constrained.";
    content = ''
      # SWE-Pruner MCP Tools

      Use this skill when reading large code files or searching codebases to reduce context window usage.

      ## When to Use

      - Reading files larger than 500 lines
      - Searching codebases with many matches
      - Context budget is constrained
      - User asks to "prune", "reduce tokens", or "focus on relevant code"
      - Exploring unfamiliar large files

      ## Available Tools

      ### `read_pruned(file_path, context_focus_question?)`

      Read a file with optional context-aware pruning.

      **Parameters:**
      - `file_path` (required): Absolute path to the file
      - `context_focus_question` (optional): Question guiding what code to keep

      **Examples:**
      ```
      # Full file (no pruning)
      read_pruned(file_path="/path/to/main.py")

      # Pruned to relevant sections
      read_pruned(
        file_path="/path/to/auth.py",
        context_focus_question="How is JWT validation implemented?"
      )
      ```

      ### `search_pruned(pattern, context_focus_question?)`

      Search codebase with optional context-aware pruning.

      **Parameters:**
      - `pattern` (required): Regex pattern to search
      - `context_focus_question` (optional): Question guiding which matches to keep

      **Examples:**
      ```
      # Search without pruning
      search_pruned(pattern="class.*Service")

      # Search with pruning
      search_pruned(
        pattern="func.*Handler",
        context_focus_question="Which handlers process HTTP requests?"
      )
      ```

      ## Pruning Behavior

      1. **No query provided**: Returns full content (no pruning)
      2. **Query + model available**: Uses ML-based line relevance scoring
      3. **Query + no model**: Falls back to heuristic pruning
      4. **Failure**: Automatically returns full content

      ## Best Practices

      1. **Start specific**: Use focused questions like "How is error handling done?" rather than "show me everything"
      2. **Chain searches**: Use search_pruned to find files, then read_pruned to dive deeper
      3. **Check stats**: View `$HOME/.cache/swe-pruner/stats.json` to see compression ratios
      4. **Model availability**: Heuristic fallback works without model files

      ## Performance Notes

      - Token savings: 23-54% average
      - First ML-backed call: slow (model load)
      - Heuristic fallback: fast, always available
      - Subsequent calls: fast (model cached)

      ## Workflow Integration

      1. Use `search_pruned` to locate relevant files
      2. Use `read_pruned` with focused questions on large files
      3. If results are insufficient, call again without question for full content
      4. Check stats file to verify pruning effectiveness
    '';
    resources = { };
    src = null;
  };
}
