// Viewport-relative geometry of the reader's built rows.
//
// The web reader asked its virtualizer for any row's pixel offset, built or not
// (getOffsetForIndex), and drove the backdrop, the music switch and the sound
// autoplay off those numbers. ListView.builder only measures rows it has built,
// so we read the geometry off them once per scroll and share the result. Rows
// scrolled far above are simply absent — callers treat "absent and before the
// first visible row" as passed.
//
// Kept free of widgets so the rules that consume it stay unit-testable.

/// One built row's box, in coordinates relative to the viewport's top edge:
/// [top] is negative once the row has scrolled off the top.
typedef RowBox = ({int index, double top, double bottom});

class RowGeometry {
  /// Built rows, ascending by index.
  final List<RowBox> rows;
  final double viewportHeight;

  const RowGeometry(this.rows, this.viewportHeight);

  static const empty = RowGeometry(<RowBox>[], 0);

  /// Indices of rows intersecting the viewport, ascending. Rows held in the
  /// cacheExtent are built but off-screen, hence testing both edges.
  List<int> get visibleIndices => [
        for (final r in rows)
          if (r.bottom > 0 && r.top < viewportHeight) r.index,
      ];

  int? get firstVisibleIndex {
    for (final r in rows) {
      if (r.bottom > 0 && r.top < viewportHeight) return r.index;
    }
    return null;
  }

  RowBox? boxOf(int index) {
    for (final r in rows) {
      if (r.index == index) return r;
    }
    return null;
  }
}
