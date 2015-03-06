rProximal = 250;
rDistal = 288;
maxReach = rProximal + rDistal;
eps = 1e-4;
$fn=100;

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

translate([0, 50])
cylinder(r=12.5, h=500);

translate([0, -125*1.4])
color([0.5,0.5,1], 0.5)
rotate([0,0,45])
//translate([-125,-125])
//square([250,250]);
//cube([250,250,200]);
cylinder(r=125*1.4,h=200);

translate([0,0,400])
rotate([45,0,0])
{
    rotate([0,30,0])
        upperArmReach();
    rotate([0,150,0])
        upperArmReach();
    rotate([0,270,0])
        upperArmReach();

    rotate([-90,0,0]) {
        union() {
            cylinder(r=100, h = rProximal);

            translate([0,0,rProximal - rDistal]) {
                cylinder(r=70, h=rDistal);
            }
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
}

