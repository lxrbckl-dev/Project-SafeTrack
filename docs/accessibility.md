# Accessibility (ADA/WCAG)

---

## Verified Contrast Ratios

| Combination | Ratio | Grade |
|---|---|---|
| Black on White | 21.0:1 | AAA |
| Gold on Black | 14.4:1 | AAA |
| Navy on White | 11.5:1 | AAA |
| White on Navy Dark | 16.6:1 | AAA |
| Gold on Navy | 7.9:1 | AAA |
| Dark Gray on White | 7.0:1 | AAA |
| Dark Gray on Light Gray | 6.4:1 | AA |
| Mid Gray on White | 5.1:1 | AA |
| Warning Amber on Warn BG | 5.5:1 | AA |
| Info Teal on Info BG | 5.4:1 | AA |
| Success Green on Succ BG | 5.3:1 | AA |
| Error Red on Error BG | 5.0:1 | AA |
| Input Border on White | 3.3:1 | 1.4.11 |
| Dark Card Border on Navy | 3.3:1 | 1.4.11 |

---

## Focus Indicators (WCAG 2.4.7)
- **Light backgrounds**: `outline: 2px solid #1E3A5F; outline-offset: 2px`
- **Dark backgrounds**: `outline: 2px solid #FFD100; outline-offset: 2px`
- Skip-navigation link required as first focusable element

```css
*:focus-visible {
  outline: 2px solid var(--navy-blue);
  outline-offset: 2px;
}
[data-theme="dark"] *:focus-visible {
  outline-color: var(--herzog-gold);
}
```

---

## Text Resizing (WCAG 1.4.4)
- All text readable at 200% scale
- Use `rem`/`em` units, never fixed `px` for body text
- Containers must expand without clipping

---

## Reflow (WCAG 1.4.10)
- No horizontal scrolling at 320px viewport width
- Breakpoints: 320px, 768px, 900px, 1200px minimum
- KPI grids: 4 cols → 2 cols (<900px) → 1 col (<480px)

---

## Text Spacing (WCAG 1.4.12)
Layouts must not break with: line-height 1.5×, paragraph spacing 2×, letter-spacing 0.12×, word-spacing 0.16×. Use `min-height` instead of `height`.

---

## Content on Hover/Focus (WCAG 1.4.13)
Tooltips/popovers must be **dismissible** (Escape), **hoverable**, and **persistent**.

---

## Reduced Motion (WCAG 2.3.3)
```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```
