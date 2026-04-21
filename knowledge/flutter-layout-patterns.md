# Flutter Layout Patterns

Patterns and gotchas for Flutter UI development, including Flutter web.

---

## Phantom Spacing from Padding + SizedBox.shrink()

When a widget conditionally renders nothing (`SizedBox.shrink()`), any parent `Padding` still takes up space:

```dart
// BAD: Padding renders even when chart is invisible
if (featureEnabled)
  Padding(
    padding: const EdgeInsets.only(top: 16),
    child: ChartWidget(data: data), // returns SizedBox.shrink() when empty
  ),
```

**Fix:** Move padding inside the child widget so it only applies when content renders:

```dart
// GOOD: Chart handles its own top padding internally
if (featureEnabled)
  ChartWidget(data: data), // includes padding only when rendering content
```

---

## Vertical Centering in Rows (Icon + Text)

When placing a Column of text next to an icon in a Row, always set `mainAxisSize: MainAxisSize.min` on the text Column:

```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.center, // vertical center
  children: [
    CircleAvatar(radius: 24),
    SizedBox(width: 20),
    Column(
      mainAxisSize: MainAxisSize.min, // CRITICAL for vertical centering
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Label', style: Theme.of(context).textTheme.bodyMedium),
        Text('Value', style: Theme.of(context).textTheme.headlineMedium),
      ],
    ),
  ],
)
```

Without `mainAxisSize: MainAxisSize.min`, the Column expands to fill available height and `CrossAxisAlignment.center` on the Row cannot vertically center it.

---

## Left-Align Content in a Full-Width Card

Use `CrossAxisAlignment.stretch` on the outer Column to force child Rows to fill width, then default `MainAxisAlignment.start` left-aligns the Row content:

```dart
Card(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, // Row fills card width
    children: [
      Row(
        // MainAxisAlignment.start is default — content left-aligned
        crossAxisAlignment: CrossAxisAlignment.center, // vertical center
        children: [icon, text],
      ),
    ],
  ),
)
```

---

## Text Line-Height Asymmetry

Large text styles (e.g. `headlineMedium`) often have more descent/line-height than smaller styles (e.g. `bodyMedium`) have ascent. A text block combining both appears visually shifted upward within equal padding — this is inherent to font metrics. Compensate at the container level if needed, not the text level.

---

## Flutter Web Debugging

- **CanvasKit renderer** (default for web): renders to `<canvas>`, not DOM elements. Chrome DevTools DOM inspection is useless.
- **Playwright screenshots** are the only reliable way to verify visual layout.
- **Flutter DDC** takes ~45 seconds to load. Use in-app navigation (clicking), not URL navigation (which triggers full reload).
- **Accessibility snapshots** from Playwright don't map to visual boundaries on canvas — use viewport/element screenshots instead.
