// a cup for the bottom of a table leg designed to hold polyurithane padding to
// absorb vibrations (e.g. from a milling machine)
use <MCAD/regular_shapes.scad>
$fn = 120;

footRadius = 32/2;
sorbothaneThickness = 12.7;
radialClearance = 6;
heightClearance = 3;
wallThickness = 5;
floorThickness = wallThickness;

difference () {
    union () {
        cylinder(r=footRadius + radialClearance + wallThickness,
            h=wallThickness + 2*sorbothaneThickness + heightClearance);
        translate ([0, 0, wallThickness + 2*sorbothaneThickness + heightClearance])
            torus(footRadius + radialClearance + wallThickness,
                footRadius + radialClearance);
    }
    translate ([0, 0, wallThickness])
    cylinder(r=footRadius + radialClearance, h=2*sorbothaneThickness + heightClearance + 1);
}
