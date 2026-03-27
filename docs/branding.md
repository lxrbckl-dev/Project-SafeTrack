# Branding & Style System (Herzog)

> Full brand system for internal Herzog applications. WCAG 2.1 AA compliant (v2).

---

## Typography

| Role | Font | Weight | Usage |
|---|---|---|---|
| Headings | Oswald | 400–700 | Page titles, section headings, card titles, KPI values, logo text. Uppercase, letter-spacing 0.04–0.08em |
| Body | Roboto | 300–700 | Body text, labels, nav links, buttons, form elements, table content |
| Monospace | Courier New | — | Hex codes, technical values, code |

**Font imports:**
```
https://fonts.googleapis.com/css2?family=Oswald:wght@400;500;600;700&display=swap
https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700&display=swap
```

---

## Color Palette

### Brand Colors
| Name | Hex | Role |
|---|---|---|
| Herzog Gold | `#FFD100` | Primary brand color, accents |
| Bright Yellow | `#FFDD00` | Secondary gold accent |
| Dark Yellow | `#F1B80E` | Gold hover/pressed states |
| Rich Black | `#000000` | Structural: headings, logo blocks |
| Dark Gray | `#58595B` | Primary body text |
| Mid Gray | `#6D6E71` | Secondary text, inactive nav |
| Smoke | `#A7A9AC` | Tertiary text, placeholders |
| Accent Gray | `#D1D3D4` | Borders, dividers (legacy) |

### Action Colors (Navy Family)
Navy is reserved for **interactive/actionable elements only**. Never use navy for structural elements.

| Name | Hex | Role |
|---|---|---|
| Navy Blue | `#1E3A5F` | Primary buttons, links, active states |
| Navy Light | `#2E5A8F` | Hover states for navy elements |
| Navy Dark | `#0F1F33` | Dark mode surfaces, card backgrounds |

### Semantic Colors
| Name | Hex | Light Variant | Role |
|---|---|---|---|
| Success Green | `#1E6B38` | `#D4EDDA` | Complete, positive |
| Error Red | `#AB2D24` | `#F8D7DA` | Overdue, errors |
| Warning Amber | `#8A5700` | `#FFF3CD` | In progress, caution |
| Info Teal | `#086670` | `#D1ECF1` | Scheduled, info |

### Extended Neutrals
| Name | Hex | Role |
|---|---|---|
| White | `#FFFFFF` | Card backgrounds, nav bg |
| Off White | `#FAFAFA` | Page body, subtle surfaces |
| Light Gray | `#F5F5F5` | Page background, table headers |
| Border Gray | `#E5E5E5` | Decorative borders, dividers |
| Input Border | `#8E8E8E` | Form input/select boundaries (3.3:1 on white) |

### Data Visualization Palette (Use in Order)
1. `#1E3A5F` — Navy Blue (Series 1)
2. `#086670` — Info Teal (Series 2)
3. `#FFD100` — Herzog Gold (Series 3)
4. `#1E6B38` — Success Green (Positive)
5. `#AB2D24` — Error Red (Negative)
6. `#6B4C9A` — Chart Purple (Series 4)
7. `#8A5700` — Warning Amber (Series 5)
8. `#4A6274` — Chart Slate (Neutral)

---

## CSS Variables
```css
:root {
  /* Brand Colors */
  --herzog-gold: #FFD100;
  --bright-yellow: #FFDD00;
  --dark-yellow: #F1B80E;
  --rich-black: #000000;
  --dark-gray: #58595B;
  --mid-gray: #6D6E71;
  --smoke: #A7A9AC;
  --accent-gray: #D1D3D4;

  /* Action Colors */
  --navy-blue: #1E3A5F;
  --navy-light: #2E5A8F;
  --navy-dark: #0F1F33;

  /* Semantic Colors */
  --success-green: #1E6B38;
  --success-light: #D4EDDA;
  --error-red: #AB2D24;
  --error-light: #F8D7DA;
  --warning-amber: #8A5700;
  --warning-light: #FFF3CD;
  --info-teal: #086670;
  --info-light: #D1ECF1;

  /* Extended Neutrals */
  --white: #FFFFFF;
  --off-white: #FAFAFA;
  --light-gray: #F5F5F5;
  --border-gray: #E5E5E5;
  --input-border: #8E8E8E;

  /* Data Visualization */
  --chart-purple: #6B4C9A;
  --chart-slate: #4A6274;
}
```

---

## Color Role Guidelines: Navy vs. Black

**Use Navy Blue for:** Primary action buttons, hyperlinks, active tab indicators, dark mode card backgrounds, data viz Series 1, interactive hover/focus states, user avatar backgrounds.

**Use Rich Black / Dark Gray for:** Section headings, body text, secondary button borders/text, navigation labels, table headers, card titles, logo block background.

---

## Navigation Layouts

### Pattern 1: Left Sidebar (Default for complex apps — 5+ sections)
- **Sidebar background**: `#000000` (Rich Black), width 200–220px, collapsible
- **Logo**: Oswald 700, `#FFD100` on black
- **Nav items**: Roboto 400, `#A7A9AC` default
- **Active item**: `#FFD100` text with gold left-border (3–4px)
- **Hover**: Slight background lighten or text brighten
- **Icons**: 18–20px, same color as text, left of label

### Pattern 2: Top Nav — Full Black Header (Simpler apps — 3–6 sections)
```
┌────────────────────────────────────────────────────────────────┐
│  LOGO  |  Nav Links                Search | Notif | DM | User │
│                    (full black bar)                            │
╞════════════════════════════════════════════════════════════════╡  ← 3px gold border
│ Breadcrumbs                                                    │
├────────────────────────────────────────────────────────────────┤
│ Page Content                                                   │
```
- **Header**: Full-width `#000000`, 56px height, `3px solid #FFD100` bottom border
- **Logo**: "HERZOG" in Oswald 700, `#FFD100`, optional app name divider
- **Nav links**: Inactive `#A7A9AC` Roboto 500, Active `#FFFFFF` Roboto 600 with 3px `#FFD100` underline
- **Mobile (< 900px)**: Hamburger collapse, black dropdown

---

## Component Styles

### Buttons
| Type | Background | Text | Border | Hover |
|---|---|---|---|---|
| Primary | `#1E3A5F` | `#FFFFFF` | none | `#2E5A8F` |
| Secondary | `#FFFFFF` | `#58595B` | `1px solid #E5E5E5` | bg `#F5F5F5` |
| Accent | `#FFD100` | `#000000` | none | `#F1B80E` |

Padding: `0.5rem 1rem` · Font: Roboto 600, 0.82rem · Border-radius: 5px

### Cards
Background `#FFFFFF` · Border `1px solid #E5E5E5` · Radius 8px · Padding 1.1–1.25rem
Hover: `box-shadow: 0 4px 12px rgba(0,0,0,0.06)` · Title: Oswald, uppercase, `#000000`
Optional gold left-border (`4px solid #FFD100`) for KPI/stat cards

### Status Badges
Font: Roboto 600–700, 0.7rem, uppercase · Padding `0.15rem 0.6rem` · Radius 3px
- Active/Complete: `#D4EDDA` bg, `#1E6B38` text
- In Progress/Pending: `#FFF3CD` bg, `#8A5700` text
- Overdue/Error: `#F8D7DA` bg, `#AB2D24` text
- Scheduled/Info: `#D1ECF1` bg, `#086670` text

### Tables
Header: `#FAFAFA` bg, Roboto 600, 0.72rem, uppercase, `#6D6E71` text
Body: Roboto 400, 0.82rem, `#58595B` text · Hover: `#FAFAFA` bg
Primary column: Roboto 600, `#000000`

### Form Elements
Border: `1px solid #8E8E8E` · Radius 5px · Font: Roboto 400, 0.82rem
Focus: `border-color: #1E3A5F; outline: 2px solid #1E3A5F; outline-offset: 1px`

---

## Dark Mode
- Page background: `#000000`
- Card backgrounds: `#0F1F33` (Navy Dark)
- Card borders: `1px solid #6E7073` (3.3:1 on Navy Dark)
- Primary text: `#FAFAFA`
- Secondary text: `#A7A9AC`
- Buttons (primary): `#2E5A8F` (Navy Light)
- Logo area: Navy Dark background with Gold text

---

## Page Layout Conventions
- **Page Header**: Oswald 1.6rem, `#000000`, uppercase. Action buttons right-aligned.
- **KPI Row**: 4 columns desktop, 2 mobile (<900px). Gold left-border, label + large Oswald value.
- **Chart Section**: 2 columns desktop, 1 mobile. Navy default fill for bars.
- **Data Table**: Full-width card, header row with "View All" button.

---

## Reference Implementations

Three working HTML demos were built as proofs-of-concept for the branding system. These can be used as reference when translating the brand to Flutter:

- **`herzog-demo-sidebar.html`** — Sidebar navigation pattern with full interactive states, theme support, skip-nav link, and responsive behavior
- **`herzog-demo-topnav.html`** — Top navigation pattern with black header, gold border, hamburger mobile menu, dropdown styling, and breadcrumbs
- **`herzog-style-guide.html`** — Comprehensive interactive component showcase: color swatches, typography samples, buttons, cards, badges, tables, form elements, focus indicators, and light/dark mode toggle

> These files have been archived. The specifications in this document are the source of truth; the HTML demos validated that the specs work end-to-end.

---

## Herzog Context
- North American rail and heavy/highway infrastructure contractor, HQ in St. Joseph, MO
- Seven divisions: HCC, HRSI, HSI, HTI, HTSI, Herzog Energy, Green Group
- Field environments often have limited connectivity — offline-first matters
- Interfaces with Class 1 railroads: BNSF, UP, CSX, NS, CN, KCS
- Proprietary platforms: RailSentry, PTC Hosting, Switchboard, GIS Software, Video Track Chart, CMMS
- Build-it-ourselves culture; tools should feel professional and purpose-built
