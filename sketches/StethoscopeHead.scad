$fn=1000;
translate([0,0,0]) cylinder(h=3,d=47);
cylinder(h=5,d=41);
translate([0,0,5]) cylinder(h=18,d=25);
translate([0,0,23]) cylinder(h=2,r1=12.5,r2=10.5);
translate([0,0,5]) cylinder(h=5,r1=20.5,r2=12.5);
translate([0,0,18]) rotate([90,0,0]) cylinder(h=40,d=10);
translate([0,0,18]) rotate([90,0,0]) rotate([0,47,0]) cylinder(h=40,d=10);