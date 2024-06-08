include <AquariumIntakeDimensions.scad>
use <AquariumIntakeHolder.scad>

overcut=1;
$fn=120;

pvc_color=[0.9, 0.9, 0.9];
camlock_color=[0.5, 0.5, 0.5];

module aquarium(
    l=aquarium_length,
    w=aquarium_width,
    h=aquarium_height,
    glass_thickness=glass_thickness,
    iron_width=iron_width,
    iron_top=iron_top_width,
    iron_top_side_indent_width=iron_top_side_indent_width,
    iron_top_back_indent_width=iron_top_back_indent_width,
    iron_top_indent_depth=iron_top_indent_depth,
    iron_top_indent_thickness=iron_top_indent_thickness,
    iron_thickness=iron_thickness,
    iron_top_cross_bar_width=iron_top_cross_bar_width,
    ) {
    // angle irons
    color([0.4, 0.4, 0.4]) difference() {
        // bounding cube
        cube([l,w,h]);
        // cut out sides
        translate([-overcut, -overcut, iron_width])
            cube([
                l + 2 * overcut,
                w + 2 * overcut,
                h - 2 * iron_width

            ]);
        // cut out inner box
        translate([iron_thickness, iron_thickness, iron_thickness])
            cube([
                l - 2 * iron_thickness,
                w - 2 * iron_thickness,
                h - iron_thickness - iron_top_indent_depth - iron_top_indent_thickness
            ]);
        // cut out top and bottom on the right side
        translate([
            iron_top_width + iron_top_side_indent_width,
            iron_top_width + iron_top_back_indent_width,
            -overcut
            ])
            cube([
                l/2 - iron_top_width - 2 * iron_top_side_indent_width - iron_top_cross_bar_width/2,
                w - 2 * iron_top_width - 2 * iron_top_back_indent_width,
                h + 2 * overcut
            ]);
        // cut out top and bottom on the left side
        translate([
            l/2 + iron_top_cross_bar_width/2 + iron_top_side_indent_width,
            iron_top_width + iron_top_back_indent_width,
            -overcut
            ])
            cube([
                l/2 - iron_top_width - 2 * iron_top_side_indent_width - iron_top_cross_bar_width/2,
                w - 2 * iron_top_width - 2 * iron_top_back_indent_width,
                h + 2 * overcut
            ]);
        // cut out the top indent
        translate([iron_top_width, iron_top_width, aquarium_height - iron_top_indent_depth])
            cube([
                l - 2 * iron_top_width,
                w - 2 * iron_top_width,
                iron_top_indent_depth + overcut
            ]);
   }

    // water
    color([0, 0.7, 1, 0.1])
    translate([iron_thickness + glass_thickness, iron_thickness + glass_thickness, iron_thickness + glass_thickness])
    cube([l - 2 * (iron_thickness + glass_thickness), w - 2 * (iron_thickness + glass_thickness), h*0.4]);

    // glass
    color([1, 1, 1, 0.2])
    translate([iron_thickness, iron_thickness, iron_thickness])
    difference() {
        cube([l - 2 * iron_thickness, w - 2 * iron_thickness, h - 2 * iron_thickness]);
        translate([glass_thickness, glass_thickness, glass_thickness])
            cube([
                l - 2 * glass_thickness - 2 * iron_thickness,
                w - 2 * glass_thickness - 2 * iron_thickness,
                h - glass_thickness + overcut - 2 * iron_thickness
            ]);
    }
}

// aquarium();

module pipe(l, od=pipe_od, id=pipe_id, col=pvc_color) {
    color(col)
    difference() {
        cylinder(h = l, d = od);
        translate([0, 0, -overcut])
            cylinder(h = l + 2 * overcut, d = id);
    }
}

module elbow(l=elbow_overlap,  od=elbow_od, id=pipe_od, col=pvc_color) {
    color(col)
    difference() {
        union() {
            sphere(od/2);
            rotate([0, 90, 0])
            cylinder(h = l + id/2, d = od);
            cylinder(h = l + id/2, d = od);
        }
        union() {
            sphere(id/2);
            rotate([0, 90, 0])
            cylinder(h = l + id/2 + overcut, d = id);
            cylinder(h = l + id/2 + overcut, d = id);
        }
    }
}

module tee(l=elbow_overlap,  od=elbow_od, id=pipe_od) {
    color(pvc_color)
    difference() {
        union() {
            translate([-l - id/2, 0, 0])
            rotate([0, 90, 0])
            cylinder(h = 2 * l + id, d = od);
            cylinder(h = l + id/2, d = od);
        }
        union() {
            translate([-l - id/2 - overcut, 0, 0])
            rotate([0, 90, 0])
            cylinder(h = 2*l + id + 2*overcut, d = id);
            cylinder(h = l + id/2 + overcut, d = id);
        }
    }
}

module fourway(l=elbow_overlap,  od=elbow_od, id=pipe_od) {
    color(pvc_color)
    difference() {
        union() {
            translate([-l - id/2, 0, 0])
            rotate([0, 90, 0])
            cylinder(h = 2 * l + id, d = od);
            cylinder(h = l + id/2, d = od);
            rotate([90, 0, 0])
            cylinder(h = l + id/2, d = od);
        }
        union() {
            translate([-l - id/2 - overcut, 0, 0])
            rotate([0, 90, 0])
            cylinder(h = 2*l + id + 2*overcut, d = id);
            cylinder(h = l + id/2 + overcut, d = id);
            rotate([90, 0, 0])
            cylinder(h = l + id/2 + overcut, d = id);
        }
    }
}

module npt_adapter(
    l=npt_adapter_length,
    od=npt_adapter_od,
    id=pipe_od,
    overlap=npt_adapter_overlap,
    hex_diameter=npt_adapter_hex_diameter,
    hex_length=npt_adapter_hex_length
) {
    union() {
        pipe(l=l, od=od, id=id);
        translate([0,0,l/2 - hex_length/2])
        pipe(l=hex_length, od=hex_diameter, id=od, $fn=6);
    }
}

module camlock_female_npt(
    l=camlock_female_npt_length,
    id=camlock_male_part_id,
    npt_od=pipe_od,
    overlap=camlock_female_npt_overlap,
    socket_outer_length=camlock_female_npt_wide_length,
    socket_od=camlock_female_npt_wide_od,
    socket_id=camlock_male_part_od + camlock_clearance,
    socket_inner_length=camlock_male_part_length,
) {
    union() {
        pipe(l=l - socket_inner_length, od=npt_od, id=id, col=camlock_color);
        translate([0,0, l-socket_outer_length])
            pipe(l=socket_outer_length, od=socket_od, id=socket_id, col=camlock_color);
        translate([0,0, l-socket_inner_length])
            pipe(l=socket_outer_length - socket_inner_length, od=socket_od, id=id, col=camlock_color);
        color([0.8, 0.8, 0.8])
        translate([-socket_od/2 - socket_od/16, -socket_od/16, l - socket_outer_length - socket_od/8])
            cube([socket_od/8, socket_od/8, socket_outer_length]);
        color([0.8, 0.8, 0.8])
        translate([socket_od/2 - socket_od/16, -socket_od/16, l - socket_outer_length - socket_od/8])
            cube([socket_od/8, socket_od/8, socket_outer_length]);
    }
}

module camlock_male_npt(
    l=camlock_female_npt_length,
    id=camlock_male_part_id,
    npt_od=pipe_od,
    hex_od=camlock_male_npt_hex_od,
    hex_length=camlock_male_npt_hex_length,
    male_part_od=camlock_male_part_od,
    male_part_length=camlock_male_part_length,
) {
    union() {
        pipe(l=l, od=npt_od, id=id, col=camlock_color);
        translate([0,0, l - male_part_length - hex_length])
            pipe(l=hex_length, od=hex_od, id=npt_od, $fn=6, col=camlock_color);
        translate([0,0, l - male_part_length - overcut])
            pipe(l=male_part_length, od=male_part_od, id=id, col=camlock_color);
    }
}

module valve(
    valve_pipe_od=45,
    valve_pipe_id=pipe_od,
    valve_pipe_length=valve_pipe_length,
    valve_stem_diameter=30,
    valve_stem_length=10,
    valve_box_length=54,
    valve_box_width=67,
    valve_box_height=54,
    valve_box_y_offset=-25,
    valve_box_z_offset=-35,
    pipe_color=[0.7, 0.7, 0.7],
    box_color=[0.3,0.4,0.8],
) {
    union() {
        pipe(l=valve_pipe_length, od=valve_pipe_od, id=valve_pipe_id, col=pipe_color);
        translate([0, 0, valve_pipe_length/2])
        rotate([0,90,0])
        translate([0, 0, valve_pipe_id/2])
        color(pipe_color)
        cylinder(h=valve_stem_length + valve_pipe_od/2 - valve_pipe_id/2, d=valve_stem_diameter);
    }

    color(box_color)
    translate([valve_pipe_od/2 + valve_stem_length, valve_box_y_offset,
        valve_pipe_length/2 + valve_box_z_offset])
        cube([valve_box_length, valve_box_width, valve_box_height]);
}

module npt_reducer_elbow(
    ntp_length=22,
    npt_od=pipe_od,
    hex_od=43,
    hex_length=9,
    elbow_od=18,
    elbow_id=12,
    elbow_length=50 - 12/2,
) {
    union() {
        pipe(l=ntp_length + hex_length, od=npt_od, id=elbow_id, col=camlock_color);
        translate([0,0, ntp_length])
            pipe(l=hex_length, od=hex_od, id=npt_od, $fn=6, col=camlock_color);
        translate([0,0, elbow_length])
            rotate([0, 90, 0])
            elbow(l=elbow_length,  od=elbow_od, id=elbow_id, col=camlock_color);
    }
}


//translate([-100,-100,0])
//npt_elbow();

module siphon(
    inside_overhang = aquarium_height - 75,
    outside_overhang = 200,
    siphon_offset_x = 70,
    siphon_offset_y = 60,
    siphon_height = 55,
    u_width = 100,
    fitting_clearance=3,
    echo_lengths=0,
    ) {
    // intake
    translate([siphon_offset_x, siphon_offset_y, aquarium_height - inside_overhang + pipe_od/2 + elbow_overlap])
        rotate([90,90,180])
        fourway();

    // ascending pipe
    ascending_pipe_l = inside_overhang - elbow_overlap - pipe_od + siphon_height - pipe_od/2;
    translate([siphon_offset_x, siphon_offset_y, aquarium_height - inside_overhang + pipe_od + elbow_overlap])
        pipe(ascending_pipe_l);

    // top tee
    translate([siphon_offset_x, siphon_offset_y, aquarium_height + siphon_height])
        rotate([180, 0, 90])
        tee();

    // top water pipe
    top_water_pipe_length = u_width - pipe_od;
    translate([siphon_offset_x, siphon_offset_y - pipe_od/2, aquarium_height + siphon_height])
        rotate([90, 0, 0])
        pipe(top_water_pipe_length);

    // water elbow down
    translate([siphon_offset_x, siphon_offset_y - u_width, aquarium_height + siphon_height])
        rotate([0, 90, 90])
        elbow();

    // descending water pipe
    descending_water_pipe_length = outside_overhang + siphon_height - pipe_od/2
            - npt_adapter_length + npt_adapter_overlap
            - camlock_female_npt_length + camlock_female_npt_overlap;
    translate([siphon_offset_x, siphon_offset_y - u_width,
            aquarium_height - outside_overhang
                + npt_adapter_length - npt_adapter_overlap
                + camlock_female_npt_length - camlock_female_npt_overlap])
        pipe(descending_water_pipe_length);

    // water outflow adapter
    translate([siphon_offset_x, siphon_offset_y - u_width, aquarium_height - outside_overhang + camlock_female_npt_length - camlock_female_npt_overlap])
        npt_adapter();

    // water outflow clamlock socket
    translate([siphon_offset_x, siphon_offset_y - u_width, aquarium_height - outside_overhang + camlock_female_npt_length])
        rotate([180,0,0])
        camlock_female_npt();

    // top air pipe
    top_air_pipe_length = elbow_overlap + npt_adapter_overlap + fitting_clearance;
    translate([siphon_offset_x, siphon_offset_y + pipe_od/2, aquarium_height + siphon_height])
        rotate([-90,0,0])
        pipe(top_air_pipe_length);

    // top air adapter
    translate([siphon_offset_x, siphon_offset_y + pipe_od/2 + elbow_overlap + fitting_clearance, aquarium_height + siphon_height])
        rotate([-90,0,0])
        npt_adapter();

    // top air camlock socket
    translate([siphon_offset_x, siphon_offset_y + pipe_od/2 + elbow_overlap + fitting_clearance + npt_adapter_length - camlock_female_npt_overlap, aquarium_height + siphon_height])
        rotate([-90,0,0])
        camlock_female_npt();

    // top air camlock plug
    translate([
            siphon_offset_x,
            siphon_offset_y + pipe_od/2 + elbow_overlap + fitting_clearance
                + npt_adapter_length - camlock_female_npt_overlap
                + camlock_female_npt_length + camlock_male_npt_length
                - camlock_male_part_length + camlock_clearance,
            aquarium_height + siphon_height
        ])
        rotate([90,0,0])
        camlock_male_npt();

    // siphon-break valve
    translate([
            siphon_offset_x,
            siphon_offset_y + pipe_od/2 + elbow_overlap + fitting_clearance
                + npt_adapter_length - camlock_female_npt_overlap
                + camlock_female_npt_length + camlock_male_npt_length
                - camlock_male_part_length + camlock_clearance
                - camlock_male_npt_overlap,
            aquarium_height + siphon_height
        ])
        rotate([-90,-90,0])
        valve();


    // siphon-break overflow
    translate([
            siphon_offset_x,
            siphon_offset_y + pipe_od/2 + elbow_overlap + fitting_clearance
                + npt_adapter_length - camlock_female_npt_overlap
                + camlock_female_npt_length + camlock_male_npt_length
                - camlock_male_part_length + camlock_clearance
                - camlock_male_npt_overlap
                + valve_pipe_length - npt_reducer_elbow_overlap,
            aquarium_height + siphon_height
        ])
        rotate([-90,90,0])
        npt_reducer_elbow();

    if (echo_lengths > 0) {
        echo("Ascending pipe length:", ascending_pipe_l, "mm");
        echo("Top water pipe length:", top_water_pipe_length, "mm");
        echo("Descending water pipe length: ", descending_water_pipe_length, "mm")
        echo("Top air pipe length:", top_air_pipe_length, "mm");
    }
}

#translate([0,0,aquarium_height])
aquarium_intake_clamp();

siphon();

translate([aquarium_length,0,0])
mirror([1,0,0])
siphon(echo_lengths=1);

aquarium();
