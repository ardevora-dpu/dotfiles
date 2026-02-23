#!/usr/bin/env python3
"""
Create a new coding tutorial template with proper frontmatter.

Usage:
    uv run python .claude/skills/coding-tutor/scripts/create_tutorial.py "React Hooks"
    uv run python .claude/skills/coding-tutor/scripts/create_tutorial.py "State Management" --concepts "Redux,Context,State"
"""

import argparse
import subprocess
import sys
from datetime import datetime
from pathlib import Path

try:
    from .tutorials_paths import get_tutorials_directory
except ImportError:
    from tutorials_paths import get_tutorials_directory


def get_repo_name() -> str:
    """Get the current git repository name."""
    try:
        result = subprocess.run(
            ['git', 'rev-parse', '--show-toplevel'],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            return result.stdout.strip().split('/')[-1]
    except Exception:
        pass
    return "unknown"


def check_uncommitted_changes() -> None:
    """Check for uncommitted changes and print a warning if any exist."""
    try:
        result = subprocess.run(
            ['git', 'status', '--porcelain'],
            capture_output=True, text=True
        )
        if result.returncode == 0 and result.stdout.strip():
            lines = result.stdout.strip().split('\n')
            print(f"WARNING: You have {len(lines)} uncommitted change(s). Commit and push before proceeding.")
            print(result.stdout)
    except Exception:
        pass


def slugify(text: str) -> str:
    """Convert text to URL-friendly slug."""
    return text.lower().replace(" ", "-").replace("_", "-")


def create_tutorial(
    topic: str,
    concepts: str | None = None,
    output_dir: str | Path | None = None
) -> Path:
    """
    Create a new tutorial template file.

    Args:
        topic: Main topic of the tutorial
        concepts: Comma-separated concepts (defaults to topic)
        output_dir: Directory to save tutorial (defaults to ~/coding-tutor-tutorials/)

    Returns:
        Path to created tutorial file
    """
    # Default output directory is the central tutorials repo (sibling to git root)
    if output_dir is None:
        output_dir = get_tutorials_directory()
    else:
        output_dir = Path(output_dir)

    # Create output directory if it doesn't exist
    output_dir.mkdir(parents=True, exist_ok=True)

    # Generate filename: YYYY-MM-DD-topic-slug.md
    date_str_filename = datetime.now().strftime("%Y-%m-%d")
    date_str_frontmatter = datetime.now().strftime("%d-%m-%Y")
    slug = slugify(topic)
    filename = f"{date_str_filename}-{slug}.md"
    filepath = output_dir / filename

    # Default concepts to topic if not provided
    if concepts is None:
        concepts = topic

    # Get current repo name
    repo_name = get_repo_name()

    # Create tutorial template with YAML frontmatter and embedded guidance
    template = f"""---
concepts: {concepts}
source_repo: {repo_name}
description: [TODO: Fill after completing tutorial - one paragraph summary]
understanding_score: null
last_quizzed: null
prerequisites: []
created: {date_str_frontmatter}
last_updated: {date_str_frontmatter}
---

# {topic}

[TODO: Opening paragraph - Start with the WHY. What problem does this concept solve? Why should the learner care about this? Connect it to their goal of becoming a senior engineer.

NOTE: Update the frontmatter 'prerequisites' field with up to 3 relevant past tutorials if this builds on previous concepts (e.g., [coding-tutor-tutorials/2025-11-20-basics.md]). Leave as empty array [] if this is foundational.]

## First Principles

[TODO: Decompose the concept:

- What is this actually? (not what it's called, what it is)
- What fundamental problem does it solve?
- What are the atomic parts?
- If we rebuilt it from scratch, what would we keep?]

## The Problem

[TODO: Describe a real scenario from this project where this concept matters. Use code, docs, or data. Make it concrete - not "X is useful for Y" but "look at this example in src/... or docs/... where we need to do Y - that's the problem this concept solves"]

## Key Concepts

[TODO: Build mental models, not just definitions. Use:
- Analogies that connect to things they already understand
- ASCII diagrams if helpful for visualising relationships
- ELI5 explanations that get to the essence
- Break complex concepts into digestible pieces
- Predict and address likely points of confusion

Remember: Teach the "shape" of the concept, not just the syntax.]

## Examples from Project Materials

[TODO: Include 2-4 real examples from this repository. For each example:

### Example 1: [Brief description]
**Location:** src/components/User.tsx:25-30 or docs/investment-process/phase-7-extraction-guide.md#Tag-Set-A

```
# Paste the relevant code snippet or document excerpt here
```

**What this demonstrates:** [Explain what's happening and why this is a good example of the concept]

Repeat for each example. Use actual file paths and anchors (line numbers or headings). The more specific, the stickier the learning.]

## Build It Yourself

[TODO: Use a light but effortful exercise. Avoid long code writing. Options:

- Outline the steps from memory
- Annotate an existing snippet and explain why it works
- Choose the correct implementation from 2-3 options and justify the choice
- Identify where in this project the concept should be applied next

If the learner wants to write code, keep it short and focused (one function or a small change).]

## Teach It Back

[TODO: Ask the learner to explain this to a smart 12-year-old. No jargon. Record:

- Learner's explanation
- Tutor's feedback on gaps and misconceptions]

## Cross-Domain Thinking

[TODO: Connect the concept to another field or programming domain. Use it to reinforce the first principles.]

## Summary

[TODO: Key takeaways - what should stick in their mind after this tutorial? 3-5 bullet points capturing:
- The core concept in one sentence
- When to use it
- Common pitfalls to avoid
- How it connects to their broader learning journey]

---

## Q&A

[Questions and answers will be added here as the learner asks them during the tutorial]

## Quiz History

[Quiz sessions will be recorded here after the learner is quizzed on this topic]
"""

    # Write template to file
    filepath.write_text(template)

    return filepath


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create a new coding tutorial template"
    )
    parser.add_argument(
        "topic",
        help="Topic of the tutorial (e.g., 'React Hooks')"
    )
    parser.add_argument(
        "--concepts",
        help="Comma-separated concepts (defaults to topic)",
        default=None
    )
    parser.add_argument(
        "--output-dir",
        help="Output directory for tutorial (defaults to ~/coding-tutor-tutorials/)",
        default=None
    )

    args = parser.parse_args()

    check_uncommitted_changes()

    try:
        filepath = create_tutorial(args.topic, args.concepts, args.output_dir)
        print(f"Created tutorial template: {filepath}")
        print(f"Edit the file to add content and update the frontmatter")
        return 0
    except Exception as e:
        print(f"Error creating tutorial: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
