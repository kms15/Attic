inner_diameter=86;
wall_thickness=2;
height =55;
$fn=180;
overcut=0.5;
angle=45;

difference() {
    rotate([0,angle,0])
        translate([0, 0, -height])
        cylinder(h = 2*height, d = inner_diameter + 2*wall_thickness);
    rotate([0,angle,0])
        translate([0, 0, -height - overcut])
        cylinder(h = 2*height + 2*overcut, d = inner_diameter);
    translate([-(height + inner_diameter), -(height + inner_diameter), -2*(height + inner_diameter)])
        cube(2*(height + inner_diameter));
}