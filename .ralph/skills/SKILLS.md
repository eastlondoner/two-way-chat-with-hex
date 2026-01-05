```markdown
# Learned Skills

*Reusable patterns and lessons learned from iterations.*

## Patterns That Work

### Iterative Feature Development
**Pattern:** Build features in phases: core functionality → tests → documentation  
**Benefit:** Reduces over-engineering risk and enables early validation  
**Context:** Applied when adding `/search-journals` command to ralph-journal plugin  
**Key principle:** Validate working implementation before investing in tests/docs

## Anti-Patterns to Avoid
None documented yet.

## Useful Commands
None documented yet.

## Design Considerations

### Search Feature Implementation
When building keyword search across files:
- **Case sensitivity:** Decide upfront (case-insensitive often more user-friendly)
- **Matching strategy:** Regex vs literal matching (impacts complexity and user expectations)
- **Performance:** Consider early optimization for large file collections
- **Context extraction:** Lines before/after matches significantly impact usefulness
```
