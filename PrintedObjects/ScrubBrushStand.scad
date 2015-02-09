// Used to hold scrub brushes and sponges near the kitchen sink
$fn=60;
totalLength = 100;
hole1Diameter = 35;
hole3Diameter = 35;
slotDepth = 80;
slot1Width = 25;
slot2Width = 40;
slot3Width = 25;
wallThickness = 6;
floorThickness = 6;
hole1x = wallThickness;
slot1x = hole1x + hole1Diameter + wallThickness;
slot2x = slot1x + slot1Width + wallThickness;
slot3x = slot2x + slot2Width + wallThickness;
hole3x = slot3x + slot3Width + wallThickness;
totalWidth = hole3x + hole3Diameter + wallThickness;
overcut = 1;

difference() {
    union() {
        cube([totalWidth, totalLength, floorThickness + slotDepth]);
        translate([hole1x + hole1Diameter/2, 0, floorThickness + slotDepth]) rotate([-90,0,0])
        cylinder(r=(wallThickness + hole1Diameter/2), h=totalLength);
        translate([hole3x + hole3Diameter/2, 0, floorThickness + slotDepth]) rotate([-90,0,0])
        cylinder(r=(wallThickness + hole3Diameter/2), h=totalLength);
        translate([slot2x - wallThickness/2, 0, floorThickness + slotDepth]) rotate([-90,0,0])
        cylinder(r=wallThickness/2, h=totalLength);
        translate([slot3x - wallThickness/2, 0, floorThickness + slotDepth]) rotate([-90,0,0])
        cylinder(r=wallThickness/2, h=totalLength);
    }

    // left holes
    translate([hole1x + hole1Diameter/2, wallThickness + hole1Diameter/2, floorThickness + hole1Diameter/2]) {
        cylinder(r=hole1Diameter/2, h=slotDepth + wallThickness + overcut);
        sphere(r=hole1Diameter/2);
    }
    translate([hole1x + hole1Diameter/2, totalLength - wallThickness - hole1Diameter/2, floorThickness + hole1Diameter/2]) {
        cylinder(r=hole1Diameter/2, h=slotDepth + wallThickness + overcut);
        sphere(r=hole1Diameter/2);
    }
    translate([hole1x + hole1Diameter/2 - floorThickness/2, -overcut, -overcut])
        cube([floorThickness, totalLength + 2*overcut, floorThickness + 2*overcut]);

    // slot 1
    translate([slot1x, -overcut, floorThickness + slot1Width/2])
        cube([slot1Width, totalLength + 2*overcut, slotDepth + overcut]);
    translate([slot1x + slot1Width/2, -overcut, floorThickness + slot1Width/2]) rotate([-90,0,0])
        cylinder(r=slot1Width/2, h=totalLength + 2*overcut);

    // slot 2
    translate([slot2x, -overcut, floorThickness + slot2Width/2])
        cube([slot2Width, totalLength + 2*overcut, slotDepth + overcut]);
    translate([slot2x + slot2Width/2, -overcut, floorThickness + slot2Width/2]) rotate([-90,0,0])
        cylinder(r=slot2Width/2, h=totalLength + 2*overcut);

    // slot 3
    translate([slot3x, -overcut, floorThickness + slot3Width/2])
        cube([slot3Width, totalLength + 2*overcut, slotDepth + overcut]);
    translate([slot3x + slot3Width/2, -overcut, floorThickness + slot3Width/2]) rotate([-90,0,0])
        cylinder(r=slot3Width/2, h=totalLength + 2*overcut);

    // right holes
    translate([hole3x + hole3Diameter/2, wallThickness + hole3Diameter/2, floorThickness + hole3Diameter/2]) {
        cylinder(r=hole3Diameter/2, h=slotDepth + wallThickness + overcut);
        sphere(r=hole3Diameter/2);
    }
    translate([hole3x + hole3Diameter/2, totalLength - wallThickness - hole3Diameter/2, floorThickness + hole3Diameter/2]) {
        cylinder(r=hole3Diameter/2, h=slotDepth + wallThickness + overcut);
        sphere(r=hole3Diameter/2);
    }
    translate([hole3x + hole3Diameter/2 - floorThickness/2, -overcut, -overcut])
        cube([floorThickness, totalLength + 2*overcut, floorThickness + 2*overcut]);
};
