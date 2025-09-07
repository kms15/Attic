$fn = 120;
overcut = 1;

module wheel(
    inner_diameter = 13,
    outer_diameter = 25,
    wheel_width = 5,
    edge_bevel = 1
    ) {

    difference() {
        union() {
            cylinder(h=edge_bevel, d1=outer_diameter - 2*edge_bevel, d2=outer_diameter);
            translate([0, 0, edge_bevel])
                cylinder(h=wheel_width - 2*edge_bevel, d=outer_diameter);
            translate([0, 0, wheel_width - edge_bevel])
                cylinder(h=edge_bevel, , d1=outer_diameter, d2=outer_diameter - 2*edge_bevel);
        }
        
        translate([0, 0, -overcut])
            cylinder(h = wheel_width + 2*overcut, d=inner_diameter);
    }
}

wheel();