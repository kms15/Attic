// A replacement shade for a torchiere

wall_thickness = 1;
floor_thickness = wall_thickness;
fastener_spacing = 90.5;
fastener_diameter = 5;
fastener_ring = 20;
ring_inner_diameter = 122;
ring_outer_diameter = 128;
height = 150;
overcut = 1;

difference() {
    cylinder(h = height, r1 = ring_outer_diameter/2, r2 = ring_outer_diameter/2 + height);
    translate([0,0,floor_thickness])
    cylinder(h = height, r1 = ring_outer_diameter/2 - wall_thickness*sqrt(2) + floor_thickness,
        r2 = ring_outer_diameter/2 + height - wall_thickness*sqrt(2) + floor_thickness);
    translate([0,0,-overcut])
        intersection() {
            cylinder(h = floor_thickness + 2*overcut, r = ring_inner_diameter/2);
            difference() {
                translate([-ring_inner_diameter/2,-fastener_spacing/2,-overcut])
                    cube([ring_inner_diameter,fastener_spacing,
                        floor_thickness + 4*overcut]);
                translate([0, -fastener_spacing/2, -overcut*2])
                    cylinder(r=fastener_ring/2, h=floor_thickness + 8*overcut);
                translate([0, fastener_spacing/2, -overcut*2])
                    cylinder(r=fastener_ring/2, h=floor_thickness + 8*overcut);
            }
        }
    translate([0, -fastener_spacing/2, -overcut])
        cylinder(r=fastener_diameter/2, h=floor_thickness + 2*overcut);
    translate([0, fastener_spacing/2, -overcut])
        cylinder(r=fastener_diameter/2, h=floor_thickness + 2*overcut);
    //translate([0,0,-10]) cube([1000,1000,1000]);
}
