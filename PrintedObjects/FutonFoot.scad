// Feet to raise my futon up a few millimeters (so the roomba can go underneath).

leg_width = 22.25;
leg_depth = 88.5;
clearance = 1;
wall_height = 10;
wall_thickness = 5;
floor_thickness = 10;

overcut = 1;

difference() {
    cube([2*wall_thickness + clearance + leg_width,
        2*wall_thickness + clearance + leg_depth,
        floor_thickness + wall_height]);
    translate([wall_thickness, wall_thickness, floor_thickness])
    cube([clearance + leg_width,
        clearance + leg_depth,
        wall_height + overcut]);
}
