inch = 25.4;
block_dimensions = [4, 1, 1] * inch;
hole_diam = 27./64 * inch;
mounting_hole_spacing = 2.5 * inch;
side_plate_length = 10 * inch;
side_plate_thickness = 1./4 * inch;

eps = 1;
$fn = 60;
expansion = (1 - cos(lookup($t, [[0,0], [0.25,0], [0.5,180], [0.75,180], [1,0]])))/2;

module mounting_block() {
    difference () {
        translate(-block_dimensions/2)
            cube(block_dimensions);

        // wire hole
        translate([0, 0, -block_dimensions[2]/2 - eps])
            cylinder(h=block_dimensions[2] + 2*eps, d=hole_diam);
        translate([-hole_diam/2, -block_dimensions[1]/2 - eps, -block_dimensions[2]/2 - eps])
            cube([hole_diam, block_dimensions[1]/2 + eps, block_dimensions[2] + 2*eps]);

        // treadmill mounting holes
        translate([-mounting_hole_spacing/2, 0, -block_dimensions[2]/2 - eps])
            cylinder(h=block_dimensions[2] + 2*eps, d=hole_diam);
        translate([mounting_hole_spacing/2, 0, -block_dimensions[2]/2 - eps])
            cylinder(h=block_dimensions[2] + 2*eps, d=hole_diam);

        // side plate mounting holes
        rotate([90, 0, 0]) {
            translate([-mounting_hole_spacing/2 - hole_diam, 0, -block_dimensions[2]/2 - eps])
                cylinder(h=block_dimensions[2] + 2*eps, d=hole_diam);
            translate([mounting_hole_spacing/2 + hole_diam, 0, -block_dimensions[2]/2 - eps])
                cylinder(h=block_dimensions[2] + 2*eps, d=hole_diam);
        }
    }
}

module side_plate() {
    difference () {
        translate(-[block_dimensions[0], side_plate_length, side_plate_thickness]/2)
        cube([block_dimensions[0], side_plate_length, side_plate_thickness]);

        for (i = [1, -1]) {
            for (j = [1, -1]) {
                translate([
                        i * (mounting_hole_spacing/2 + hole_diam),
                        j * (side_plate_length - block_dimensions[2])/2,
                        -side_plate_thickness/2 - eps
                    ])
                    cylinder(h=side_plate_thickness + 2*eps, d=hole_diam);

                translate([
                        i * (3*inch / 2),
                        j * (side_plate_length - block_dimensions[2])/2,
                        -side_plate_thickness/2 - eps
                    ])
                    cylinder(h=side_plate_thickness + 2*eps, d=hole_diam);
            }
        }
    }
}

// bottom support block
mounting_block();

// top support block
translate ([0, 0, side_plate_length - block_dimensions[2]])
    mounting_block();

translate([
        0,
        -(side_plate_thickness + block_dimensions[1] + eps)/2 - 40*expansion,
        (side_plate_length - block_dimensions[2])/2
    ])
    rotate ([90,0,0])
    side_plate();

translate([
        0,
        +(side_plate_thickness + block_dimensions[1] + eps)/2 + 40*expansion,
        (side_plate_length - block_dimensions[2])/2
    ])
    rotate ([90,0,0])
    side_plate();
