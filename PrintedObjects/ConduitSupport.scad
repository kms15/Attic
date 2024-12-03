overcut = 1;
$fn = 60;

module conduit_support_union(
        conduit_od=21.3,
        support_height=25,
        screw_hole_diameter=5,
        screw_head_diameter=9,
        strap_thickness=3,
        edge_thickness=2
    ) {
        block_width = conduit_od + edge_thickness * 2;
        block_length = support_height * 2;
        strap_width = screw_head_diameter + edge_thickness*2;
        screw_hole_offset = conduit_od/2 + strap_width/2 + strap_thickness;
        plateau_height = support_height + conduit_od/2;
        difference() {
            union() {
                // base block suport
                translate([-block_width/2, -block_length/2, 0])
                    cube([block_width, block_length, plateau_height]);
                
                // curve of conduit strap
                translate([0, -strap_width/2, support_height + conduit_od/2])
                    rotate([-90, 0, 0])
                    cylinder(h = strap_width, d = conduit_od + 2*strap_thickness);
                
                // screw holders
                translate([screw_hole_offset, 0, 0])
                    cylinder(h = plateau_height, d = strap_width);
                translate([-screw_hole_offset, 0, 0])
                    cylinder(h = plateau_height, d = strap_width);
                
                // screw holder support
                translate([-screw_hole_offset, -strap_width/2, 0])
                    cube([2*screw_hole_offset, strap_width, plateau_height]);
            }
            
            // conduit cutout
            translate([0, -block_length/2 - overcut, support_height + conduit_od/2])
                rotate([-90, 0, 0])
                cylinder(h = block_length + 2*overcut, d = conduit_od);
            
            // screw shaft cutout
            translate([screw_hole_offset, 0, -overcut])
                cylinder(h = plateau_height + 2*overcut, d = screw_hole_diameter);
            translate([-screw_hole_offset, 0, -overcut])
                cylinder(h = plateau_height + 2*overcut, d = screw_hole_diameter);
            
            // screw head cutout
            translate([screw_hole_offset, 0, plateau_height - screw_head_diameter/2])
                cylinder(h = strap_width/2, d1=0, d2=strap_width);
            translate([-screw_hole_offset, 0, plateau_height - screw_head_diameter/2])
                cylinder(h = strap_width/2, d1=0, d2=strap_width);
        }
}

module conduit_support_body(
        conduit_od=21.3,
        support_height=25,
        screw_hole_diameter=5,
        screw_head_diameter=9,
        strap_thickness=3,
        edge_thickness=2,
        strap_clearance=0.5
    ) {
    strap_width = screw_head_diameter + edge_thickness*2;
    screw_hole_offset = conduit_od/2 + strap_width/2 + strap_thickness;
    difference() {
        conduit_support_union(
            conduit_od=conduit_od,
            support_height=support_height,
            screw_hole_diameter=screw_hole_diameter,
            screw_head_diameter=screw_head_diameter,
            strap_thickness=strap_thickness,
            edge_thickness=edge_thickness
        );
        
        // screw holder support
        translate([
                -screw_hole_offset -strap_width/2 - overcut,
                -strap_width/2 - strap_clearance,
                support_height
            ])
            cube([
                2*screw_hole_offset + strap_width + 2*overcut,
                strap_width + 2*strap_clearance,
                conduit_od + strap_thickness + overcut
            ]);
    }
}

module conduit_support_strap(
        conduit_od=21.3,
        support_height=25,
        screw_hole_diameter=5,
        screw_head_diameter=9,
        strap_thickness=3,
        edge_thickness=2,
    ) {
    strap_width = screw_head_diameter + edge_thickness*2;
    screw_hole_offset = conduit_od/2 + strap_width/2 + strap_thickness;
    plateau_height = support_height + conduit_od/2;
    translate([0,0,-support_height])
        intersection() {
            difference() {
                conduit_support_union(
                    conduit_od=conduit_od,
                    support_height=support_height,
                    screw_hole_diameter=screw_hole_diameter,
                    screw_head_diameter=screw_head_diameter,
                    strap_thickness=strap_thickness,
                    edge_thickness=edge_thickness
                );

                translate([-conduit_od/2, -strap_width/2 - overcut, 0])
                    cube([conduit_od, strap_width + 2*overcut, plateau_height]);
            }
            
            // screw holder support
            translate([
                    -screw_hole_offset -strap_width/2 - overcut,
                    -strap_width/2,
                    support_height
                ])
                cube([
                    2*screw_hole_offset + strap_width + 2*overcut,
                    strap_width,
                    conduit_od + strap_thickness + overcut
                ]);
        }
}

conduit_support_strap();

translate([0, 50, 0])
conduit_support_body();