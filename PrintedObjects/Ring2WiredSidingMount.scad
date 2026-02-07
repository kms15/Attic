overcut=1;
depth=15;
width=32;
hole_diameter=4;
$fn=30;

rotate([180,0,0])
    translate([0,0,-depth])
    difference() {
        cube([width,100,depth]);
        translate([5,19,-overcut])
            cube([22, 39, depth + 2*overcut]);
        translate([0,3*25.4,0])
            rotate([atan(0.5/4),0,0])
            translate([-overcut, 0, -depth*2])
            cube([width + 2*overcut, 25.4*4, 2*depth]);
        translate([0,-1*25.4,0])
            rotate([atan(0.5/4),0,0])
            translate([-overcut, 0, -depth*2])
            cube([width + 2*overcut, 25.4*4, 2*depth]);
        translate([width/2, 5,-overcut])
            cylinder(d=hole_diameter, h=depth+2*overcut);
        translate([width/2, 81,-overcut])
            cylinder(d=hole_diameter, h=depth+2*overcut);
    }