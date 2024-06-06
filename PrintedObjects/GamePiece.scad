inches = 25.4; // mm
totalWidth = 0.8 * inches;
totalHeight = 0.4 * inches;
totalDepth = 0.8 * inches;
cutoutWidth = 0.4 * inches;
cutoutDepth = 0.4 * inches;

overcut = 1;

difference () {
    cube([totalWidth, totalDepth, totalHeight]);
    translate([totalWidth - cutoutWidth, -overcut, -overcut])
        cube([cutoutWidth + overcut, cutoutDepth + overcut, totalHeight + 2 * overcut]);
}
