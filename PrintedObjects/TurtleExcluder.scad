include <AquariumIntakeDimensions.scad>

module turtle_excluder(
    wall_thickness = 2,
    grid_depth = 10,
    excluder_diameter = pipe_od+0.25,
    total_depth = elbow_overlap
) {
    union() {
        difference() {
            cylinder(h=total_depth, d=excluder_diameter, $fn=120);
            translate([0,0,-overcut])
            cylinder(h=total_depth + 2*overcut, d=excluder_diameter - 2*wall_thickness, $fn=120);
        }
        translate([-wall_thickness/2, -excluder_diameter/2 + wall_thickness/2, 0])
        cube([wall_thickness, excluder_diameter - wall_thickness, grid_depth]);
        translate([-excluder_diameter/2 + wall_thickness/2, -wall_thickness/2, 0])
        cube([excluder_diameter - wall_thickness, wall_thickness, grid_depth]);
    }
}

turtle_excluder();