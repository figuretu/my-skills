# Skill Design Principles

This document serves as both a creation guide and an optimization checklist. When creating a new skill, follow these principles from the start. When optimizing an existing skill, use them as a review checklist.

## 1. Skill Structure

Every skill consists of a required SKILL.md and optional bundled resources:

```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter: name + description (required)
│   └── Markdown instructions (required)
└── Bundled Resources (optional)
    ├── scripts/      - Executable code (Python/Bash/etc.)
    ├── references/   - Documentation loaded into context as needed
    └── assets/       - Files used in output (templates, icons, fonts, etc.)
```

## 2. Progressive Disclosure

Skills use a three-level loading system to manage context efficiently:

1. **Metadata (name + description)** — Always in context (~100 words). This is the trigger layer.
2. **SKILL.md body** — Loaded when skill triggers (<5k words). Core workflow lives here.
3. **Bundled resources** — Loaded as needed by Claude (unlimited). Scripts can execute without reading into context.

**Implication**: Keep SKILL.md lean. Move detailed reference material, schemas, and examples to `references/` files. Information should live in either SKILL.md or references, not both.

## 3. Metadata Quality

The `name` and `description` in YAML frontmatter determine when Claude will use the skill.

- **name**: hyphen-case, lowercase letters/digits/hyphens only, max 40 chars
- **description**: Specific about what the skill does and when to use it
  - Use third-person voice (e.g., "This skill should be used when..." or describe scenarios directly)
  - List trigger scenarios using "(1) ... (2) ... (3) ..." format
  - No angle brackets in description
  - Include enough context for Claude to decide whether to activate the skill

## 4. Content Organization

**SKILL.md** should contain:
- Core workflow / execution steps
- References to bundled resources (so Claude knows they exist and when to use them)
- Concise procedural instructions

**SKILL.md** should NOT contain:
- Lengthy reference material (move to `references/`)
- Duplicated content that also exists in bundled resources
- Verbose explanations when a script or reference file would be clearer

### Common Structure Patterns

Choose the pattern that best fits the skill's purpose (patterns can be mixed):

1. **Workflow-Based** — Sequential processes with clear steps (e.g., "Step 1 → Step 2 → Step 3")
2. **Task-Based** — Multiple independent operations/capabilities (e.g., "Merge PDFs" / "Split PDFs")
3. **Reference/Guidelines** — Standards or specifications (e.g., "Colors" / "Typography")
4. **Capabilities-Based** — Interrelated features (e.g., "### 1. Feature" / "### 2. Feature")

## 5. Bundled Resources Selection

### Scripts (`scripts/`)
- **When to include**: Same code is rewritten repeatedly, or deterministic reliability is needed
- **Examples**: `rotate_pdf.py`, `fill_form_fields.py`, `init_skill.py`
- **Benefits**: Token efficient, deterministic, executable without loading into context

### References (`references/`)
- **When to include**: Documentation Claude should reference while working, but not always
- **Examples**: API docs, database schemas, domain knowledge, company policies, detailed workflow guides
- **Best practice**: If files are large (>10k words), include grep search patterns in SKILL.md
- **Avoid duplication**: Content lives in references OR SKILL.md, not both

### Assets (`assets/`)
- **When to include**: Files used in the final output, not loaded into context
- **Examples**: Templates (.pptx, .docx), images, fonts, boilerplate code directories

## 6. Writing Conventions

- Use **imperative/infinitive form** (verb-first instructions), not second person
  - ✅ "Execute the validation script" / "To accomplish X, do Y"
  - ❌ "You should execute..." / "If you need to..."
- Trigger scenarios use "(1) ... (2) ... (3) ..." format
- Follow the language conventions from the repository's AGENTS.md
- Keep the skill's original language style (English stays English, Chinese stays Chinese)
- Technical terms remain in English regardless of the skill's language
