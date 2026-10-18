enum gmvex_cmd {
    MOVETO,
    LINETO,
    QUADTO,
    CUBICTO
}

enum gmvex_join {
    BEVEL,
    ROUND,
    MITER
}

enum gmvex_cap {
    BUTT,
    ROUND,
    SQUARE
}

enum gmvex_winding {
    EVENODD,
    NONZERO
}

enum gmvex_gradient {
    LINEAR,
    RADIAL
}

enum gmvex_bool {
    UNION,
    INTERSECTION,
    A_NOT_C,
    C_NOT_A
}

enum gmvex_halign { LEFT, CENTER, RIGHT }
enum gmvex_valign { TOP, MIDDLE, BASELINE, BOTTOM }