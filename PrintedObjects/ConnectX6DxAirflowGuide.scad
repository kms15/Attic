$fn = 60;
overcut = 0.5;

wall_thickness_x = 2;
wall_thickness_y = 2;
wall_thickness_z = 2;

box_inside_x = 140;
box_inside_y = 56-2;
box_inside_z = 15;

top_vent_x_length = 10;
top_vent_y_length = 47;
top_vent_offset_y = 5;

hole_support_diameter = 7;

card_hole1_x = 139;
card_hole1_y = 3 - 1;
card_hole1_d = 3;

card_hole2_x = 37;
card_hole2_y = 58 - 1;
card_hole2_d = 3;

led_notch_z = 1;
led_notch_length = 4;

card_edge_notch_z = 1;
card_edge_notch_length = 84;
card_edge_notch_offset = 45;

fan_box_overlap_x = 2;
fan_box_inside_x = 51 - fan_box_overlap_x + 1;

duct_notch_offset_y = 32;
duct_notch_length_y = 20.5;

fan_hole1_x = box_inside_x + 7.4;
fan_hole1_y = 3;
fan_hole1_d = 3;

fan_hole2_x = box_inside_x + 45.4;
fan_hole2_y = 46;
fan_hole2_d = 3;

corner_radius_bottom = 10;
corner_radius_top = 25;

module cx6dx_airflow_guide() {
    difference() {
        union() {
            // main body top
            translate([0, -wall_thickness_y, -wall_thickness_z])
                cube([
                    box_inside_x + wall_thickness_x  + fan_box_inside_x - corner_radius_top,
                    wall_thickness_y + corner_radius_top + overcut,
                    box_inside_z + wall_thickness_z
                ]);
            // main body mid
            translate([0, -wall_thickness_y + corner_radius_top - overcut, -wall_thickness_z])
                cube([
                    box_inside_x + wall_thickness_x + fan_box_inside_x,
                    box_inside_y + 2 * wall_thickness_y + 2 * overcut
                        - corner_radius_top - corner_radius_bottom,
                    box_inside_z + wall_thickness_z
                ]);
            // main body bottom
            translate([
                    0,
                    box_inside_y + wall_thickness_y - overcut - corner_radius_bottom,
                    -wall_thickness_z
                ])
                cube([
                    box_inside_x + wall_thickness_x + fan_box_inside_x - corner_radius_bottom,
                    corner_radius_bottom + overcut,
                    box_inside_z + wall_thickness_z
                ]);
            translate([
                    box_inside_x + wall_thickness_x + fan_box_inside_x - corner_radius_bottom,
                    box_inside_y + wall_thickness_y - corner_radius_bottom,
                    -wall_thickness_z
                ])
                cylinder(h = box_inside_z + wall_thickness_z, r = corner_radius_bottom);
            // main body lower corner radius
            translate([
                    box_inside_x + wall_thickness_x + fan_box_inside_x - corner_radius_top,
                    -wall_thickness_y + corner_radius_top,
                    -wall_thickness_z
                ])
                cylinder(h = box_inside_z + wall_thickness_z, r = corner_radius_top);
            
            // card hole1 support
            translate([card_hole1_x, card_hole1_y, - wall_thickness_z])
            cylinder(h = box_inside_z + wall_thickness_z, d = hole_support_diameter + 1);
            // card hole2 support
            translate([card_hole2_x, card_hole2_y, - wall_thickness_z])
            cylinder(h = box_inside_z + wall_thickness_z, d = hole_support_diameter);
        }
        // circuit box cutout
        difference() {
            translate([-overcut, 0, 0])
                cube([
                    box_inside_x + overcut,
                    box_inside_y,
                    box_inside_z + overcut
                ]);
            // card hole2 support cutout
            translate([card_hole1_x, card_hole1_y, - wall_thickness_z])
            cylinder(h = box_inside_z + wall_thickness_z, d = hole_support_diameter + 1);            
        }
        // fan box cutout
        union() {
            translate([box_inside_x + fan_box_overlap_x, 0, 0])
                cube([
                    fan_box_inside_x - fan_box_overlap_x - corner_radius_top + wall_thickness_x,
                    corner_radius_top + overcut,
                    box_inside_z + overcut
                ]);
            translate([
                    box_inside_x + fan_box_overlap_x, corner_radius_top - wall_thickness_x - overcut, 0])
                cube([
                    fan_box_inside_x - fan_box_overlap_x,
                    box_inside_y - corner_radius_top - corner_radius_bottom
                        + 2*wall_thickness_x + 2*overcut,
                    box_inside_z + overcut
                ]);
            translate([
                    box_inside_x + fan_box_overlap_x,
                    box_inside_y - (corner_radius_bottom - wall_thickness_y) - overcut,
                    0
                ])
                cube([
                    fan_box_inside_x - fan_box_overlap_x - corner_radius_bottom + wall_thickness_x,
                    corner_radius_bottom - wall_thickness_y + overcut,
                    box_inside_z + overcut
                ]);
            translate([
                    box_inside_x + fan_box_inside_x + wall_thickness_x - corner_radius_top,
                    corner_radius_top - wall_thickness_x,
                    0
                ])
                cylinder(h = box_inside_z + overcut, r = corner_radius_top - wall_thickness_x);
            translate([
                    box_inside_x + fan_box_inside_x + wall_thickness_x - corner_radius_bottom,
                    box_inside_y - corner_radius_bottom + wall_thickness_x,
                    0
                ])
                cylinder(h = box_inside_z + overcut, r = corner_radius_bottom - wall_thickness_x);
        }
        // duct notch cutout
        translate([box_inside_x - overcut, duct_notch_offset_y, 0])
            cube([
                fan_box_overlap_x + 2*overcut,
                duct_notch_length_y,
                box_inside_z + overcut
            ]);        
        // top vent cutout
        translate([-overcut, top_vent_offset_y, - (wall_thickness_z + overcut)])
            cube([
                top_vent_x_length + overcut,
                top_vent_y_length,
                wall_thickness_z + 2*overcut
            ]);
        // card hole1
        translate([card_hole1_x, card_hole1_y, - wall_thickness_z - overcut])
        cylinder(h = box_inside_z + wall_thickness_z + 2*overcut, d = card_hole1_d);
        // card hole2
        translate([card_hole2_x, card_hole2_y, - wall_thickness_z - overcut])
        cylinder(h = box_inside_z + wall_thickness_z + 2*overcut, d = card_hole2_d);
        // fan hole1
        translate([fan_hole1_x, fan_hole1_y, - wall_thickness_z - overcut])
        cylinder(h = box_inside_z + wall_thickness_z + 2*overcut, d = fan_hole1_d);
        // fan hole2
        translate([fan_hole2_x, fan_hole2_y, - wall_thickness_z - overcut])
        cylinder(h = box_inside_z + wall_thickness_z + 2*overcut, d = fan_hole2_d);
        // led notch
        translate([-overcut, box_inside_y - overcut, box_inside_z - led_notch_z])
            cube([
                led_notch_length + overcut,
                wall_thickness_y + 2*overcut,
                led_notch_z + overcut
            ]);
        // card edge notch
        translate([card_edge_notch_offset, box_inside_y - overcut, box_inside_z - card_edge_notch_z])
            cube([
                card_edge_notch_length,
                wall_thickness_y + 2*overcut,
                card_edge_notch_z + overcut
            ]);
    }
}

cx6dx_airflow_guide();