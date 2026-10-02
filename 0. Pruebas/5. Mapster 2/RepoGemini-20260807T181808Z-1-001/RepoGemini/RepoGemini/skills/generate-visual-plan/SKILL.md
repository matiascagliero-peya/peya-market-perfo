---
name: generate-visual-plan
description: Generate a visual HTML implementation plan — detailed feature specification with state machines, code snippets, and edge cases. Use when the user wants a visual plan for a feature, an implementation spec, a technical design document rendered as HTML, or asks to plan out a feature visually. Also trigger for "plan de implementacion", "spec visual", or "diseño tecnico".
---

Load the visual-explainer skill, then generate a comprehensive visual implementation plan as a self-contained HTML page.

Follow the visual-explainer skill workflow. Read the reference template, CSS patterns, and mermaid theming references before generating. Use an editorial or blueprint aesthetic, but vary fonts and palette from previous diagrams.

**Data gathering phase** — understand the context before designing:

1. **Parse the feature request.** Extract:
   - The core problem being solved
   - Desired user-facing behavior
   - Any constraints or requirements mentioned
   - Scope boundaries (what's explicitly out of scope)

2. **Read the relevant codebase.** Identify:
   - Files that will need modification
   - Existing patterns to follow (code style, architecture, naming conventions)
   - Related functionality that the feature should integrate with
   - Types, interfaces, and APIs the feature must conform to

3. **Understand the extension points.** Look for:
   - Hook points, event systems, or plugin architectures
   - Configuration options or flags
   - Public APIs that might need extension
   - Test patterns used in the codebase

4. **Check for prior art.** Search for:
   - Similar features already implemented
   - Related issues or discussions
   - Existing code that can be reused or extended

**Design phase** — work through the implementation before writing HTML:

1. **State design.** What new state variables are needed? What existing state is affected? Draw the state machine if behavior has multiple modes.

2. **API design.** What commands, functions, or endpoints are added? What are the signatures? What are the error cases?

3. **Integration design.** How does this feature interact with existing functionality? What hooks or events are involved?

4. **Edge cases.** Walk through unusual scenarios: concurrent operations, error conditions, boundary values, user mistakes.

**Verification checkpoint** — before generating HTML, produce a structured fact sheet:
- Every state variable (new and modified) with its type and purpose
- Every function/command/API with its signature
- Every file that needs modification with the specific changes
- Every edge case with expected behavior
- Every assumption about the codebase that the plan relies on
Verify each against the code. If something cannot be verified, mark it as uncertain. This fact sheet is your source of truth during HTML generation.

**Diagram structure** — the page should include:

1. **Header** — feature name, one-line description, scope summary.
2. **The Problem** — side-by-side comparison panels showing current behavior vs. desired behavior.
3. **State Machine** — Mermaid flowchart or stateDiagram showing the states and transitions.
4. **State Variables** — card grid showing new state and existing state (if modified).
5. **Modified Functions** — for each function that needs changes, show function name, file path, key code snippet, and explanation.
6. **Commands / API** — table with command/function name, parameters, and behavior description.
7. **Edge Cases** — table listing scenarios and expected behaviors.
8. **Test Requirements** — table or card grid showing test categories and specific tests to add.
9. **File References** — table mapping files to the changes needed.
10. **Implementation Notes** — callout boxes for backward compatibility, critical warnings, and performance considerations.

**Visual hierarchy:**
- Sections 1-3 should dominate the viewport on load (hero depth)
- Sections 4-6 are core implementation details (elevated cards)
- Sections 7-10 are reference material (flat or recessed depth)

**Code block requirements:**
- Always use `white-space: pre-wrap` and `word-break: break-word`
- Include file path headers where relevant
- Keep snippets focused — show the pattern, not the full implementation

**Overflow prevention:**
- Apply `min-width: 0` on all grid/flex children
- Use `overflow-wrap: break-word` on all text containers
- Test tables with wide content don't overflow their container

Write to `~/.agent/diagrams/` with a descriptive filename (e.g., `feature-name-plan.html`). Open the result in the browser.

Ultrathink.
