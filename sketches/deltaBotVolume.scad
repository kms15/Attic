rProximal = 330;
rDistal = 435;
maxReach = rProximal + rDistal;
eps = 1e-4;
//$fn=60;

module singleArmReach() {
    difference () {
        union () {
            difference () {
                rotate_extrude(convexity = 10)
                    translate([rProximal, 0, 0])
                    circle(r = rDistal);
                translate([-maxReach, -maxReach, -maxReach])
                    cube([maxReach, 2*maxReach, 2*maxReach]);
            }
            translate([0, -rProximal, 0])
                sphere(r=rDistal*(1+eps));
        }
        translate([0, rProximal, 0])
            sphere(r=rDistal*(1+eps));
    }
}

module upperArmReach() {
    difference() {
        circle(r = rProximal);
        translate([-2*rProximal, -2*rProximal, 0])
            square([2 * rProximal, 4 * rProximal]);
    }
}

upperArmReach();
rotate([0,120,0])
    upperArmReach();
rotate([0,-120,0])
    upperArmReach();

rotate([-90,0,0]) {
    union() {
        cylinder(r=100, h = rProximal);

        translate([0,0,rProximal - rDistal])
        cylinder(r=70, h=rDistal);
    }
}

color([0.5,0.5,0.7], 0.5)
difference() {
    translate([0, -rProximal, 0])
        sphere(r=rDistal*(1+eps));
    translate([0, rProximal, 0])
        sphere(r=rDistal*(1+eps));
}

/*
// single arm reach
color([0.5,0.5,0.7], 0.5)
union() {
    singleArmReach();
    rotate([0,120,0])
        singleArmReach();
    rotate([0,-120,0])
        singleArmReach();
}
*/
