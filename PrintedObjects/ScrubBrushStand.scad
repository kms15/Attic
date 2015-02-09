// Used to hold scrub brushes and sponges near the kitchen sink

totalLength = 100;
hole1Diameter = 25;
hole3Diameter = 35;
slotDepth = 100;
slot1Width = 25;
slot2Width = 40;
slot3Width = 15;
slot4Width = 25;
wallThickness = 6;
floorThickness = 6;
hole1x = wallThickness;
slot1x = hole1x + hole1Diameter + wallThickness;
slot2x = slot1x + slot1Width + wallThickness;
slot3x = slot2x + slot2Width + wallThickness;
slot4x = slot3x + slot3Width + wallThickness;
hole3x = slot4x + slot4Width + wallThickness;
totalWidth = hole3x + hole3Diameter + wallThickness;
overcut = 1;

difference() {
    cube([totalWidth, totalLength, floorThickness + slotDepth]);

    // left holes
    translate([hole1x + hole1Diameter/2, wallThickness + hole1Diameter/2, floorThickness])
        cylinder(d=hole1Diameter, h=slotDepth + overcut);
    translate([hole1x + hole1Diameter/2, totalLength - wallThickness - hole1Diameter/2, floorThickness])
        cylinder(d=hole1Diameter, h=slotDepth + overcut);

    // slot 1
    translate([slot1x, -overcut, floorThickness])
        cube([slot1Width, totalLength + 2*overcut, slotDepth + overcut]);

    // slot 2
    translate([slot2x, -overcut, floorThickness])
        cube([slot2Width, totalLength + 2*overcut, slotDepth + overcut]);

    // slot 3
    translate([slot3x, -overcut, floorThickness])
        cube([slot3Width, totalLength + 2*overcut, slotDepth + overcut]);

    // slot 4
    translate([slot4x, -overcut, floorThickness])
        cube([slot4Width, totalLength + 2*overcut, slotDepth + overcut]);

    // right holes
    translate([hole3x + hole3Diameter/2, wallThickness + hole3Diameter/2, floorThickness])
        cylinder(d=hole3Diameter, h=slotDepth + overcut);
    translate([hole3x + hole3Diameter/2, totalLength - wallThickness - hole3Diameter/2, floorThickness])
        cylinder(d=hole3Diameter, h=slotDepth + overcut);
};
