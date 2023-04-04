totalWidth = 25.4;
totalHeight = 12.7;
totalDepth = 25.4;
cutoutWidth = 12.7;
cutoutDepth = 12.7;

overcut = 1;

difference () {
    cube([totalWidth, totalDepth, totalHeight]);
    translate([totalWidth - cutoutWidth, -overcut, -overcut])
        cube([cutoutWidth + overcut, cutoutDepth + overcut, totalHeight + 2 * overcut]);
}
