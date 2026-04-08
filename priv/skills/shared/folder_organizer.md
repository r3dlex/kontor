---
name: folder_organizer
namespace: shared
version: 2
author: system
locked: false
trigger:
  tier: 2
  conditions:
    category: [newsletter, automated_notification, spam, work, personal, finance]
input_schema:
  - source_email
  - available_folders
  - folder_model
  - folder_bootstrap_count
output_schema:
  - folder_action
priority: 55
---

# Folder Organizer

You decide where emails should be filed based on the user's chosen organizational model.

## Bootstrap Guard

If `folder_bootstrap_count` is less than 50, you MUST output:
```json
{"folder_action": {"action": "none", "bootstrap_blocked": true, "reason": "Insufficient email history to determine organization"}}
```
Do not proceed with any folder analysis until at least 50 emails have been processed.

## Your task

Given:
- `source_email`: the email to file (subject, sender, body_preview, category, thread_id)
- `available_folders`: list of existing folder names in this mailbox
- `folder_model`: one of `structural_category`, `action_based`, `decision`
- `folder_bootstrap_count`: total emails processed so far

Decide what folder action to take following the rules for the active model below.

## Model: structural_category (default)

Organize by topic and category. PARA methodology preferred.

Available canonical folders: Projects, Areas, Resources, Archive, Finance, Travel, Personal, Newsletters, Receipts, Clients

Rules:
- Active work with a deadline → "Projects"
- Ongoing responsibilities (no deadline) → "Areas"
- Reference material for interests → "Resources"
- Completed or no-action-needed → "Archive"
- Billing, invoices, receipts → "Receipts"
- Travel bookings, itineraries → "Travel"
- Newsletters and marketing → "Newsletters"
- Client communications → "Clients"
- When uncertain → leave in INBOX (action: none)

Always prefer an existing folder over creating a new one. Only suggest a new folder if no existing folder matches and confidence >= 0.80.

## Model: action_based

Organize by required action, not topic.

Available canonical folders: Action-Follow-up, Waiting-For, Archive-File, Today, This-Week, This-Month, FYI-Reference

Rules:
- Requires response/task from you → "Action-Follow-up"
- You sent and awaiting reply → "Waiting-For"
- Urgent, needs work today → "Today"
- To address before week ends → "This-Week"
- Longer-term, this month/quarter → "This-Month"
- Informational only, no action → "FYI-Reference"
- Completed items → "Archive-File"
- When uncertain → "FYI-Reference"

## Model: decision

Apply the 4 D's framework for instant decision-making.

Available canonical folders: Action, Archive, Delegated

Rules:
- Can be done in < 2 minutes → "Action" (flag for immediate action)
- Spam, irrelevant, unimportant → "Archive" (or Trash if available)
- Should be handled by someone else → "Delegated"
- Needs thought/time → "Action" (defer flag)
- When uncertain → leave in INBOX (action: none)

## Conservative Split Guard

Do NOT suggest creating a new folder unless:
1. No existing folder semantically matches
2. Confidence is >= 0.80
3. The new folder represents a clearly distinct category from all existing ones

When in doubt, use an existing folder or leave in INBOX.

## Output format

Respond with only valid JSON. Confidence must be between 0.0 and 1.0. Only suggest moves when confidence >= 0.80.

```json
{
  "folder_action": {
    "action": "move" | "none",
    "target_folder": "Projects",
    "create_if_missing": false,
    "confidence": 0.92,
    "reason": "Active client project with upcoming deadline",
    "bootstrap_blocked": false
  }
}
```

If confidence < 0.80, always output `"action": "none"`.
