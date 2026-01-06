# Strategic Context

*High-level direction and long-term considerations.*

## Overall Goal
**CURRENT TASK:** Understand and document the Claude Code hook system's input structure, specifically the HOOK_INPUT JSON format available to hooks at runtime.

**DELIVERABLES:**
1. Comprehensive documentation at `docs/HOOK_INPUT_FORMAT.md`
2. Universal debugging script for real-time hook input inspection (`/tmp/hook-debug.log`)
3. Understanding of `transcript_path` and other available fields

**PURPOSE:** Enable developers to effectively utilize hook system data when creating custom hooks. Establish debugging infrastructure for hook development.

## Current Status
- **Phase:** Investigation initiated (Iteration 1)
- **Loop ID:** Active investigation loop
- **Progress:** Planning complete, execution beginning
- **Completion Promise:** HOOK_DEBUG_COMPLETE
- **Previous Context:** Test file creation task (1767719630-29527) completed successfully

## Architectural Approach

### Investigation Strategy (Multi-Phase)
1. **Example Analysis:** Examine `stop-hook.sh` for existing hook implementation patterns
2. **Codebase Discovery:** Search for hook-related code to understand input structure
3. **Tool Development:** Create universal debugging script for all hook types
4. **Validation:** Trigger various hooks to verify data structure understanding
5. **Documentation:** Compile findings into comprehensive markdown reference

### Design Decisions
- **Generic debugging script:** Must work with any hook type, not just stop-hook
- **Real-time logging:** `/tmp/hook-debug.log` for immediate feedback during development
- **Systematic approach:** Start with concrete examples before diving into implementation details

## Key Dependencies
- Access to `stop-hook.sh` script (existing hook implementation)
- Claude Code codebase access for hook infrastructure code
- File write permissions to `/tmp` for debugging logs
- Ability to trigger hooks for testing validation
- Read/Grep/Glob tools for codebase exploration

## Risks & Considerations

**MEDIUM COMPLEXITY TASK:**
- Requires understanding both shell script layer and underlying Claude Code implementation
- Hook data structure may vary by hook type - debugging script must accommodate
- Documentation accuracy depends on thorough testing across multiple hook scenarios

**CRITICAL SUCCESS FACTORS:**
- Testing is essential - must actually trigger hooks to validate understanding
- Documentation must be developer-friendly and include practical examples
- Debugging script should be immediately useful for future hook development

**PROCESS INSIGHTS:**
- Clear completion promise (HOOK_DEBUG_COMPLETE) enables objective progress tracking
- Well-defined deliverables prevent scope creep
- Starting with existing examples (stop-hook.sh) provides concrete foundation

## Next Steps
1. Locate and read `stop-hook.sh` to understand current hook usage patterns
2. Search codebase for hook infrastructure implementation
3. Identify all fields available in HOOK_INPUT environment variable
4. Create universal debugging script with comprehensive logging
5. Test debugging mechanism across multiple hook types
6. Document findings at `docs/HOOK_INPUT_FORMAT.md`
