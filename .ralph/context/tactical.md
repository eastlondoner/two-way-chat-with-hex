# Tactical Context

*Current goals and immediate details for the task at hand.*

## Current Blockers
- None

## Recent Decisions
- **New task initiated:** Document hook system input structure in Claude Code
- **Approach:** Systematic investigation starting with existing hook example (stop-hook.sh), then create universal debugging script
- **Deliverable:** Documentation at docs/HOOK_INPUT_FORMAT.md
- **Completion promise:** HOOK_DEBUG_COMPLETE
- **Testing strategy:** Trigger various hooks to verify understanding of HOOK_INPUT data structure

## Important Details

### Current Task: Hook System Documentation
- **Goal:** Understand and document the HOOK_INPUT JSON format available to hooks
- **Key deliverables:**
  1. Examine stop-hook.sh for current hook usage patterns
  2. Document HOOK_INPUT structure (transcript_path and other fields)
  3. Create debugging script logging to /tmp/hook-debug.log
  4. Test debugging mechanism
  5. Generate docs/HOOK_INPUT_FORMAT.md

### Execution Plan
1. ⏳ Read stop-hook.sh to see existing hook implementation
2. Search codebase for hook-related code to understand input structure
3. Create universal hook debugging script for logging all input data
4. Test debugging script by triggering various hooks
5. Compile findings into markdown documentation

### Technical Notes
- HOOK_INPUT is an environment variable containing JSON data
- transcript_path structure needs documentation
- Debugging script should be generic (work with any hook type)
- Real-world testing crucial - must trigger hooks to verify data structure
- Investigation requires examining both shell scripts and Claude Code implementation

### Context
- Part of understanding Claude Code's hook system architecture
- Establishes debugging mechanism for real-time hook inspection
- Systematic approach: concrete examples first, then comprehensive documentation
- Status: Just initiated - no actions taken yet
