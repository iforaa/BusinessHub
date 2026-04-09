# UI Redesign — Warm & Approachable

## Goal

Restyle the entire Hub UI with a warm, earthy, approachable palette. Improve card design, sidebar grouping, search results, transcript view, and overall typography/spacing.

## Design System

### Colors

- **Background:** `#f8f7f4` (warm off-white)
- **Card/surface:** `#fff` with `#e8e5df` borders
- **Text primary:** `#2d2a26`
- **Text secondary:** `#5c5549`
- **Text muted:** `#a09888`
- **Accent (focus/hover):** `#c4b89c`
- **Subtle background:** `#f0ece4`, `#faf8f5`

### Signal badges (muted earthy)

- Bug: `bg: #f8f0ee, text: #9a6b5e`
- Feature: `bg: #f0f4ee, text: #6b7f5e`
- Commitment: `bg: #eef0f4, text: #5e6b7f`
- Positive: `bg: #f4f2ee, text: #7f7a5e`

### Transcript speaker colors (muted)

- Speaker A: sage — `bg: #f5f8f2, border: #dfe8d8, name: #7a8b6e`
- Speaker B: sand — `bg: #f8f5f0, border: #e8dfd4, name: #8b7a5e`
- Speaker C: sky — `bg: #f0f5f8, border: #d4dfe8, name: #5e7a8b`
- Speaker D: mauve — `bg: #f8f0f5, border: #e8d4df, name: #8b5e7a`
- (Fallback for unassigned people — cycle through these)

### Search highlight

- `bg: #f5edd4, text: #6b5d3e` (warm gold)

### Typography

- Font: system font stack (-apple-system, BlinkMacSystemFont, Segoe UI)
- Card titles: 15px, weight 600
- Body text: 14px, line-height 1.55
- Muted/meta: 12-13px
- Section labels: 10px uppercase, letter-spacing 0.8px
- Page titles: 22px, weight 700, tracking -0.3px

## Pages

### Header

- White background, bottom border
- Logo: "TenFore Hub" — TenFore bold, Hub muted
- Nav links: Feed, People — subtle rounded pill on hover/active

### Feed (/)

- **Sidebar:** grouped by role (Team, Clients, Other) with uppercase labels. No color dots. Name + count, subtle hover with white bg + shadow.
- **Search box:** rounded, warm focus ring
- **Cards:** rounded-10, 16px padding, subtle hover. Title + date on first line, participants as plain comma-separated names below, summary text, then muted signal badges.
- **Unprocessed cards:** italic muted transcript preview instead of summary.

### Search results

- Same sidebar visible
- Result count in muted text
- Each result: subtle header bar (topic, date, participants) in `#faf8f5`, excerpts below with dashed separators, warm gold highlights on matched terms.

### AI answer

- Muted "AI Answer" badge in earthy tones (not purple)
- Markdown-rendered body
- Sources section below with separator line

### Document detail (/documents/:id, /documents/raw/:id)

- Back link, large title, meta line (participants, date)
- **Summary section:** white card, uppercase section label
- **Signals section:** each signal with its badge + quoted content + speaker attribution
- **Action items section:** simple text list
- **Transcript section:** chat bubbles with muted earthy speaker colors. Same speaker's consecutive messages omit the name. Rounded bubbles with colored backgrounds.

### People (/people)

- Keep current functionality (role dropdown, context input, color picker)
- Apply same warm card/table styling

## Implementation

All changes are CSS/template only — no backend changes. Update:
1. `assets/css/app.css` — custom properties and base styles
2. `lib/hub_web/components/layouts/app.html.heex` — header
3. `lib/hub_web/live/feed_live.ex` — sidebar grouping, card styles, search results, AI answer
4. `lib/hub_web/live/document_live.ex` — transcript bubbles, section styling
5. `lib/hub_web/components/document_card.ex` — card styling
6. `lib/hub_web/live/people_live.ex` — table styling
