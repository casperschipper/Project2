# Invert matrix

> BIT, EMR-3 8.2 entry 24: flip every cell of the matrix.

The **Invert** button next to the [matrix](fields/harmony-matrix) grid is a one-shot action, not a persisted setting: clicking it immediately flips every checkbox - every previously allowed transition becomes forbidden, and every previously forbidden one becomes allowed - and that's it. There is nothing left "on" afterwards to remember or to turn back off; click it again to flip back.

It only appears in **Matrix** mode, since it acts directly on the checkboxes you've hand-toggled. A chord-derived preview has no checkboxes of its own to flip - use **"Use as editable matrix"** first to fork the preview into a real matrix, then invert that if you want its complement.

[Forbidden tones](fields/harmony-forbidden-tones) are unaffected - inversion only ever touches the matrix of intervals, never the separate list of forbidden tones.

## Related

- [harmony matrix](fields/harmony-matrix)
