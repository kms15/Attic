include <AquariumIntakeDimensions.scad>

module edge_clip(
    dx = 125,
    dy = iron_top_width + iron_top_side_indent_width + default_thickness,
    top_dz = default_thickness,
    bottom_dz = default_thickness,
    lip_dy=iron_top_side_indent_width,
    lip_dz=iron_top_indent_thickness,
    edge_dy=iron_top_width,
    edge_dz=iron_top_indent_depth,
    undercut_dy=iron_thickness + glass_thickness,
    corner_cut=default_bevel,
    corner_distance=300,
    corner_lip_cut=10,
    corner_edge_cut=5,
    corner_undercut=20,
    back_bevels=1,
    mask_left_back_bevels=-overcut,
) {
    difference() {
        // create the body
        translate([0,0,- bottom_dz - lip_dz - edge_dz])
        cube([dx, dy, bottom_dz + lip_dz + edge_dz + top_dz]);
        
        // cut out the edge
        translate([-overcut, -overcut, -edge_dz - overcut])
        cube([dx + 2 * overcut, edge_dy + overcut, edge_dz + overcut]);
        
        // cut out the lip
        translate([-overcut, -overcut, -edge_dz - lip_dz])
        cube([dx + 2 * overcut, edge_dy + lip_dy + overcut, lip_dz]);
        
        // cut out the glass section
        translate([-overcut, -overcut, -edge_dz - lip_dz - bottom_dz - overcut])
        cube([dx + 2 * overcut, undercut_dy + overcut, bottom_dz + 2*overcut]);

        // bevel at top of top of edge
        translate([0, 0, top_dz])
        rotate([45,0,0])
        translate([-overcut, -corner_cut*sqrt(2)/2, -corner_cut*sqrt(2)/2]) 
        cube([dx + 2 * overcut, corner_cut*sqrt(2), corner_cut*sqrt(2)]); 
        
        // bevel at bottom of top of edge
        translate([0, 0, 0])
        rotate([45,0,0])
        translate([-overcut, -corner_cut*sqrt(2)/2, -corner_cut*sqrt(2)/2]) 
        cube([dx + 2 * overcut, corner_cut*sqrt(2), corner_cut*sqrt(2)]);     

        // bevel between top of lip and side of edge
        translate([0, edge_dy, -edge_dz])
        rotate([45,0,0])
        translate([-overcut, -corner_cut*sqrt(2)/2, -corner_cut*sqrt(2)/2]) 
        cube([dx + 2 * overcut, corner_cut*sqrt(2), corner_cut*sqrt(2)]); 
        
        // bevel between bottom of lip and glass
        translate([0, undercut_dy, - edge_dz - lip_dz])
        rotate([45,0,0])
        translate([-overcut, -corner_cut*sqrt(2)/2, -corner_cut*sqrt(2)/2]) 
        cube([dx + 2 * overcut, corner_cut*sqrt(2), corner_cut*sqrt(2)]); 
        
        // top inside bevel
        translate([0, dy, top_dz])
        rotate([45,0,0])
        translate([-overcut, -corner_cut*sqrt(2)/2, -corner_cut*sqrt(2)/2]) 
        cube([dx + overcut - mask_left_back_bevels, corner_cut*sqrt(2), corner_cut*sqrt(2)]);      
        
        // bottom inside bevel
        translate([0, dy, - bottom_dz - lip_dz - edge_dz])
        rotate([45,0,0])
        translate([-overcut, -corner_cut*sqrt(2)/2, -corner_cut*sqrt(2)/2]) 
        cube([dx + overcut - mask_left_back_bevels, corner_cut*sqrt(2), corner_cut*sqrt(2)]); 
   
        // top front bevel
        translate([0, 0, top_dz])
        rotate([0,45,0])
        translate([-corner_cut*sqrt(2)/2, -overcut, -corner_cut*sqrt(2)/2]) 
        cube([corner_cut*sqrt(2), dy + 2 * overcut, corner_cut*sqrt(2)]); 
   
        // bottom front bevel
        translate([0, 0, - bottom_dz - lip_dz - edge_dz])
        rotate([0,45,0])
        translate([-corner_cut*sqrt(2)/2, -overcut, -corner_cut*sqrt(2)/2]) 
        cube([corner_cut*sqrt(2), dy + 2 * overcut, corner_cut*sqrt(2)]); 
   
        // top back bevel
        if (back_bevels) {
            translate([dx, 0, top_dz])
            rotate([0,45,0])
            translate([-corner_cut*sqrt(2)/2, -overcut, -corner_cut*sqrt(2)/2]) 
            cube([corner_cut*sqrt(2), dy + 2 * overcut, corner_cut*sqrt(2)]); 

       
            // bottom back bevel
            translate([dx, 0, - bottom_dz - lip_dz - edge_dz])
            rotate([0,45,0])
            translate([-corner_cut*sqrt(2)/2, -overcut, -corner_cut*sqrt(2)/2]) 
            cube([corner_cut*sqrt(2), dy + 2 * overcut, corner_cut*sqrt(2)]);
        }
        
        // right front bevel
        translate([0, 0, 0])
        rotate([0,0,45])
        translate([-corner_cut*sqrt(2)/2, -corner_cut*sqrt(2)/2,
            - bottom_dz - lip_dz - edge_dz - overcut]) 
        cube([corner_cut*sqrt(2), corner_cut*sqrt(2),
            bottom_dz + lip_dz + edge_dz + top_dz + 2 * overcut]);        
        
        // left front bevel
        translate([0, dy, 0])
        rotate([0,0,45])
        translate([-corner_cut*sqrt(2)/2, -corner_cut*sqrt(2)/2,
            - bottom_dz - lip_dz - edge_dz - overcut]) 
        cube([corner_cut*sqrt(2), corner_cut*sqrt(2),
            bottom_dz + lip_dz + edge_dz + top_dz + 2 * overcut]);        
        
        if (back_bevels) {
            // right back bevel
            translate([dx, 0, 0])
            rotate([0,0,45])
            translate([-corner_cut*sqrt(2)/2, -corner_cut*sqrt(2)/2,
                - bottom_dz - lip_dz - edge_dz - overcut]) 
            cube([corner_cut*sqrt(2), corner_cut*sqrt(2),
                bottom_dz + lip_dz + edge_dz + top_dz + 2 * overcut]);        
            
            // left back bevel
            if (mask_left_back_bevels < corner_cut) {
                translate([dx, dy, 0])
                rotate([0,0,45])
                translate([-corner_cut*sqrt(2)/2, -corner_cut*sqrt(2)/2,
                    - bottom_dz - lip_dz - edge_dz - overcut]) 
                cube([corner_cut*sqrt(2), corner_cut*sqrt(2),
                    bottom_dz + lip_dz + edge_dz + top_dz + 2 * overcut]);
            }
        }
        
        //
        // corner cutouts
        //
        
        // back edge cutout
        translate([corner_distance - edge_dy, -overcut, - edge_dz - overcut])
        cube([edge_dy + overcut, dy + 2*overcut, edge_dz + overcut]);
        
        // back lip cutout
        translate([corner_distance - edge_dy - lip_dy, -overcut, - edge_dz - lip_dz])
        cube([edge_dy + lip_dy + overcut, dy + 2*overcut, lip_dz]);

        // back undercut cutout
        translate([corner_distance - undercut_dy, -overcut, - edge_dz - lip_dz - bottom_dz - overcut])
        cube([undercut_dy + overcut, dy + 2*overcut, bottom_dz + 2*overcut]);          

        // corner edge bevel
        translate([corner_distance - edge_dy, edge_dy, 0])
        rotate([0,0,45])
        translate([-corner_edge_cut*sqrt(2)/2, -corner_edge_cut*sqrt(2)/2,
            - edge_dz - overcut]) 
        cube([corner_edge_cut*sqrt(2), corner_edge_cut*sqrt(2),
            edge_dz + overcut]);        

        // lip edge bevel
        translate([corner_distance - edge_dy - lip_dy, edge_dy + lip_dy, 0])
        rotate([0,0,45])
        translate([-corner_lip_cut*sqrt(2)/2, -corner_lip_cut*sqrt(2)/2,
            - edge_dz - lip_dz]) 
        cube([corner_lip_cut*sqrt(2), corner_lip_cut*sqrt(2),
            lip_dz]);
            
        // corner undercut bevel
        translate([corner_distance - undercut_dy, undercut_dy, 0])
        rotate([0,0,45])
        translate([-corner_undercut*sqrt(2)/2, -corner_undercut*sqrt(2)/2,
            - bottom_dz - lip_dz - edge_dz - overcut]) 
        cube([corner_undercut*sqrt(2), corner_undercut*sqrt(2),
            bottom_dz + 2 * overcut]);

        // back edge bevel
        translate([corner_distance, 0, 0])
        rotate([0,45,0])
        translate([-corner_cut*sqrt(2)/2, -overcut, -corner_cut*sqrt(2)/2]) 
        cube([corner_cut*sqrt(2), dy + 2 * overcut, corner_cut*sqrt(2)]); 

        // back lip bevel
        translate([corner_distance - edge_dy, 0, -edge_dz])
        rotate([0,45,0])
        translate([-corner_cut*sqrt(2)/2, -overcut, -corner_cut*sqrt(2)/2]) 
        cube([corner_cut*sqrt(2), dy + 2 * overcut, corner_cut*sqrt(2)]); 

        // back undercut bevel
        translate([corner_distance - undercut_dy, 0, -edge_dz - lip_dz])
        rotate([0,45,0])
        translate([-corner_cut*sqrt(2)/2, -overcut, -corner_cut*sqrt(2)/2]) 
        cube([corner_cut*sqrt(2), dy + 2 * overcut, corner_cut*sqrt(2)]); 
    }
}

module dummy_tee(expand=0, extend=0) {
    translate([siphon_offset_x, siphon_offset_y, siphon_offset_z])
    union() {
        // tee fitting
        rotate([180, 0, 0])
        cylinder(h=pipe_od/2 + elbow_overlap + extend, d=elbow_od + 2*expand);
        rotate([90, 0, 0])
        translate([0,0,-(pipe_od/2 + elbow_overlap + extend)])
        cylinder(h=pipe_od + 2*elbow_overlap + 2*extend, d=elbow_od + 2*expand);            
        
        // inner pipe
        rotate([180, 0, 0])
        cylinder(h=100, d=pipe_od + 2*expand);
        rotate([90, 0, 0])
        translate([0,0,-100])
        cylinder(h=2*100, d=pipe_od + 2*expand);            
    }
}

module tee_shell(
    thickness=default_thickness,
    lower_length=70,
    bevel=default_bevel,
    extend=5,
) {
    elbow_octogon_diameter = (elbow_od + 2*thickness)/cos(180/8);
    pipe_octogon_diameter = (pipe_od + 2*thickness)/cos(180/8);
    elbow_octogon_bevel_diameter = (elbow_od + 2*thickness - 2*bevel)/cos(180/8);
    pipe_octogon_bevel_diameter = (pipe_od + 2*thickness - 2*bevel)/cos(180/8);
    
    elbow_octogon_side = (elbow_od + 2*thickness) / (1 + sqrt(2));
    pipe_octogon_side = (pipe_od + 2*thickness) / (1 + sqrt(2));
    
    difference() {
        translate([siphon_offset_x, siphon_offset_y, siphon_offset_z])
        union() {
            // large lower part of tee
            rotate([180, 0, 0])
            rotate([0, 0, 22.5])
            union() {
                cylinder(h=pipe_od/2 + elbow_overlap + extend, d=elbow_octogon_diameter, $fn=8);
                // bevel to small pipe
                translate([0,0,pipe_od/2 + elbow_overlap + extend])
                cylinder(h=(elbow_od - pipe_od)/2,
                    d1=elbow_octogon_diameter,
                    d2=pipe_octogon_diameter,
                    $fn=8);
            }
            // horizontal part of tee
            rotate([90, 0, 0])
            rotate([0, 0, 22.5])
            translate([0,0,-(pipe_od/2 + elbow_overlap - bevel)])
            union () {
                cylinder(h=pipe_od + 2*elbow_overlap - 2*bevel, d=elbow_octogon_diameter, $fn=8);
                translate([0,0,pipe_od + 2*elbow_overlap - 2*bevel])
                cylinder(h=bevel,
                    d1=elbow_octogon_diameter,
                    d2=elbow_octogon_bevel_diameter,
                    $fn=8);
                translate([0,0,-bevel])
                cylinder(h=bevel,
                    d1=elbow_octogon_bevel_diameter,
                    d2=elbow_octogon_diameter,
                    $fn=8);            }
            
            // lower pipe
            rotate([180, 0, 0])
            rotate([0, 0, 22.5])
            union() {
                cylinder(h=lower_length - bevel, 
                    d=pipe_octogon_diameter, $fn=8);
                translate([0,0,lower_length - bevel])
                cylinder(h=bevel,
                    d1=pipe_octogon_diameter,
                    d2=pipe_octogon_bevel_diameter,
                    $fn=8);
            }
            
            // left lower brace
            difference() {
                translate([elbow_od/2, -pipe_octogon_side/2, -lower_length + bevel])
                    cube([thickness, pipe_octogon_side, lower_length]);
                translate([pipe_od/2 + thickness - bevel, -pipe_octogon_side/2 - overcut, -lower_length])
                    rotate([0, 45, 0])
                    cube([
                        (elbow_octogon_diameter - pipe_od)/2,
                        pipe_octogon_side + 2*overcut,
                        lower_length - bevel
                    ]);
                // front edge bevel
                translate([elbow_od/2 + thickness, pipe_octogon_side/2, -lower_length + bevel])
                rotate([0,0,45])
                translate([-default_bevel*sqrt(2)/2, -(default_bevel+overcut)*sqrt(2)/2,
                    - overcut]) 
                cube([default_bevel*sqrt(2), (default_bevel + overcut)*sqrt(2),
                    lower_length + 2*overcut]);
                // back edge bevel
                translate([elbow_od/2 + thickness, -pipe_octogon_side/2, -lower_length + bevel])
                rotate([0,0,-45])
                translate([-default_bevel*sqrt(2)/2, -(default_bevel+overcut)*sqrt(2)/2,
                    - overcut]) 
                cube([default_bevel*sqrt(2), (default_bevel + overcut)*sqrt(2),
                    lower_length + 2*overcut]);
            }
                        
            // right lower brace
            rotate([0,0,180])
            difference() {
                translate([elbow_od/2, -pipe_octogon_side/2, -lower_length + bevel])
                    cube([thickness, pipe_octogon_side, lower_length]);
                translate([pipe_od/2 + thickness - bevel, -pipe_octogon_side/2 - overcut, -lower_length])
                    rotate([0, 45, 0])
                    cube([
                        (elbow_octogon_diameter - pipe_od)/2,
                        pipe_octogon_side + 2*overcut,
                        lower_length - bevel
                    ]);
                // front edge bevel
                translate([elbow_od/2 + thickness, pipe_octogon_side/2, -lower_length + bevel])
                rotate([0,0,45])
                translate([-default_bevel*sqrt(2)/2, -(default_bevel+overcut)*sqrt(2)/2,
                    - overcut]) 
                cube([default_bevel*sqrt(2), (default_bevel + overcut)*sqrt(2),
                    lower_length + 2*overcut]);
                // back edge bevel
                translate([elbow_od/2 + thickness, -pipe_octogon_side/2, -lower_length + bevel])
                rotate([0,0,-45])
                translate([-default_bevel*sqrt(2)/2, -(default_bevel+overcut)*sqrt(2)/2,
                    - overcut]) 
                cube([default_bevel*sqrt(2), (default_bevel + overcut)*sqrt(2),
                    lower_length + 2*overcut]);
            }
            
            // top right fastener block
            translate([0, pipe_od/2 + elbow_overlap - bevel - thickness, elbow_od/2 + thickness]) {
                fastener_block($fn=60, hole_height=0, od=2*thickness, support_thickness=thickness);
                rotate([0,0,180])
                fastener_block($fn=60, hole_height=0, od=2*thickness, support_thickness=thickness);
            }

            // top left fastener block
            translate([0, -(pipe_od/2 + elbow_overlap - bevel - thickness), elbow_od/2 + thickness]) {
                fastener_block($fn=60, hole_height=0, od=2*thickness, support_thickness=thickness);
                rotate([0,0,180])
                fastener_block($fn=60, hole_height=0, od=2*thickness, support_thickness=thickness);
            }
            
            // middle right fastener block
            translate([0, pipe_od/2 + elbow_overlap - bevel - thickness, -(elbow_od/2 + thickness)]) {
                rotate([180,0,0])
                fastener_block($fn=60, hole_height=0, od=2*thickness, support_thickness=thickness);
                rotate([180,0,180])
                fastener_block($fn=60, hole_height=0, od=2*thickness, support_thickness=thickness);
            }

            // middle left fastener block
            translate([0, -(pipe_od/2 + elbow_overlap - bevel - thickness), -(elbow_od/2 + thickness)]) {
                rotate([180,0,0])
                fastener_block($fn=60, hole_height=0, od=2*thickness, support_thickness=thickness);
                rotate([180,0,180])
                fastener_block($fn=60, hole_height=0, od=2*thickness, support_thickness=thickness);
            }
            
            // bottom right fastener block
            translate([0, pipe_od/2 + thickness, -lower_length + thickness + bevel]) {
                rotate([-90,0,0])
                fastener_block($fn=60, hole_height=0, od=2*thickness);
                rotate([90,0,180])
                fastener_block($fn=60, hole_height=0, od=2*thickness);
            }

            // bottom left fastener block
            translate([0, -(pipe_od/2 + thickness), -lower_length + thickness + bevel]) {
                rotate([90,0,0])
                fastener_block($fn=60, hole_height=0, od=2*thickness);
                rotate([-90,0,180])
                fastener_block($fn=60, hole_height=0, od=2*thickness);
            }
        }
        // tee fitting/pipe cutout
        dummy_tee(extend=extend, $fn=120);
        
        translate([siphon_offset_x, siphon_offset_y, siphon_offset_z]) {
            // top right fastener hole
            translate([0, pipe_od/2 + elbow_overlap - bevel - thickness, elbow_od/2 + thickness])
            fastener_hole(hole_depth=2*thickness);
            
            // top left fastener hole
            translate([0, -(pipe_od/2 + elbow_overlap - bevel - thickness), elbow_od/2 + thickness])
            fastener_hole(hole_depth=2*thickness);

            // middle right fastener hole
            translate([0, pipe_od/2 + elbow_overlap - bevel - thickness, -(elbow_od/2 + thickness)])
            fastener_hole(hole_depth=2*thickness);
            
            // middle left fastener hole
            translate([0, -(pipe_od/2 + elbow_overlap - bevel - thickness), -(elbow_od/2 + thickness)])
            fastener_hole(hole_depth=2*thickness);

            // bottom right fastener hole
            translate([0, pipe_od/2 + thickness, -lower_length + thickness + bevel])
            fastener_hole();

            // bottom left fastener hole
            translate([0, -(pipe_od/2 + thickness), -lower_length + thickness + bevel])
            fastener_hole();
            
            // right side fastener hole
            translate([-elbow_od/2 - thickness, 0, 0])
            rotate([0,0,180])
            fastener_hole(hole_depth=4);
        }
    }
}

module right_edge_clip() {
    
    difference() {
        union() {
            // main clip
            translate([0,125,0])
            rotate([0,0,-90])
            edge_clip(dx=125, corner_distance=125,
                mask_left_back_bevels=60 + iron_top_width
                    + iron_top_side_indent_width + default_thickness);
            
            // pipe support brace
            translate([default_bevel, siphon_offset_y - default_thickness/2, default_thickness])
            difference() {
                // body of brace
                cube([
                    iron_top_width
                        + iron_top_side_indent_width + default_thickness - default_bevel,
                    default_thickness,
                    iron_top_width
                        + iron_top_side_indent_width + default_thickness - default_bevel
                ]);
                
                // cut square to triangle
                rotate([0,-45,0])
                translate([-overcut,-overcut,0])
                cube([
                    sqrt(2)*(iron_top_width
                        + iron_top_side_indent_width + default_thickness - default_bevel)
                        + 2*overcut,        
                    default_thickness + 2*overcut,
                    sqrt(2)*(iron_top_width
                        + iron_top_side_indent_width + default_thickness - default_bevel)
                ]);
          
                // front edge bevel
                translate([0, default_thickness, 0])
                rotate([0,45,0])
                rotate([0,0,-45])
                translate([-default_bevel*sqrt(2)/2, -(default_bevel+overcut)*sqrt(2)/2,
                    - overcut]) 
                cube([default_bevel*sqrt(2), (default_bevel + overcut)*sqrt(2),
                    sqrt(2)*(iron_top_width
                        + iron_top_side_indent_width + default_thickness - default_bevel)
                        + 2*overcut]);             
          
                // back edge bevel
                rotate([0,45,0])
                rotate([0,0,45])
                translate([-default_bevel*sqrt(2)/2, -(default_bevel+overcut)*sqrt(2)/2,
                    - overcut]) 
                cube([default_bevel*sqrt(2), (default_bevel + overcut)*sqrt(2),
                    sqrt(2)*(iron_top_width
                        + iron_top_side_indent_width + default_thickness - default_bevel)
                        + 2*overcut]);
            }
            
            // pipe support internal bevel
            translate([sqrt(2)*(default_thickness+default_bevel), siphon_offset_y, default_thickness])
                rotate([0,90,0])
                difference() {
                    rotate([0,0,45])
                    translate([-default_thickness, -default_thickness, 0]) 
                    cube([2*default_thickness, 2*default_thickness,
                        iron_top_width + iron_top_side_indent_width + default_thickness
                        - sqrt(2)*(default_thickness+default_bevel)
                    ]);
                    translate([overcut, -3*default_thickness/2, -overcut])
                    cube([3*default_thickness, 3*default_thickness, iron_top_width + 2*overcut]);
                }
            
            // pipe support screw block
            translate([
                iron_top_width + iron_top_side_indent_width + default_thickness,
                siphon_offset_y,
                siphon_offset_z
            ])
            difference() {
                rotate([0, -90, 0]) {
                    cylinder(h=8 - default_bevel, d=10, $fn=60);
                    translate([0,0,8 - default_bevel])
                    cylinder(h=default_bevel, d1=10, d2=10-default_bevel*2, $fn=60);
                }
            }
            
            // bottom screw block
        }
        
        // pipe support screw hole
        translate([
            iron_top_width + iron_top_side_indent_width + default_thickness,
            siphon_offset_y,
            siphon_offset_z
            ])
            rotate([0,0,180])
            fastener_hole(hole_depth=11);
    }
}

module back_edge_clip() {
    translate([85,0,0])
    mirror([1,0,0])
    edge_clip(dx=85, corner_distance=125, back_bevels=0, mask_left_back_bevels=40);

    translate([0, iron_top_width + iron_top_side_indent_width + default_thickness, 
            -(iron_top_indent_thickness + iron_top_indent_depth + default_thickness),
    ])
    cube([default_thickness, 60,
        iron_top_indent_thickness + iron_top_indent_depth + 2*default_thickness]);
}

module aquarium_intake_clamp() {
    // right edge clamp
    color([0.5, 0.7, 0])
    right_edge_clip();

    // back edge clamp
    translate([iron_top_width + iron_top_side_indent_width + default_thickness,0,0])
    color([0, 0.7, 0])
    back_edge_clip();
    
    // top tee    
    //color([0.7, 0.7, 0, 0.2])
    //dummy_tee();
    
    color([0, 0.7, 0])
    tee_shell();
}


print_plate = 0;

module fastener_hole(
    hole_diameter=3.2,
    hole_depth=6,
    front_clearance=20,
    rear_clearance=20,
    front_counterbore_diameter=6.4,
    rear_counterbore_diameter=6.4,
) {
    // screw hole
    rotate([0,90,0])
    translate([0,0,-hole_depth/2 - overcut])
    cylinder(h=hole_depth + 2*overcut, d=hole_diameter, $fn=30);
    
    // head countersink
    rotate([0,90,0])
    translate([0,0,hole_depth/2])
    cylinder(h=front_clearance, d=front_counterbore_diameter, $fn=30);
    
    // nut countersink
    rotate([0,-90,0])
    translate([0,0,hole_depth/2])
    rotate([0,0,30])
    cylinder(h=rear_clearance, d=rear_counterbore_diameter, $fn=6);
}

module fastener_block(
    support_thickness=3,
    od = 10,
    hole_height=3.5,
    brace_angle=45,
) {
    difference() {
        union() {
            // front disk
            translate([-overcut,0,hole_height])
            rotate([0, 90, 0])
            cylinder(d=od, h=support_thickness+overcut);
            
            // front box
            translate([-overcut,-od/2,-overcut])
            cube([support_thickness+overcut, od, hole_height + overcut]);
            
            // sphere body
            translate([support_thickness,0,hole_height])
            sphere(d=od);
            
            // support brace
            translate([support_thickness,0,hole_height])
            rotate([0, 90+brace_angle, 0])
            cylinder(d=od, h=(hole_height + od/2)/sin(brace_angle));
            
            // support box
            translate([support_thickness,-od/2,hole_height])
            rotate([0,brace_angle,0])
            translate([0,0,-hole_height - overcut])
            cube([(hole_height + od/2)/sin(brace_angle), od, hole_height + overcut]);    
        }
        
        // trim the front (x < 0)
        translate([
            -(hole_height + od/2 + 2*overcut),
            -(od/2 + overcut),
            -(od/2 - hole_height + 2*overcut)
        ])
        cube([
            hole_height + od/2 + 2*overcut,
            od + 2*overcut,
            od + hole_height + 2*overcut
        ]);
        
        // trim the bottom (z < 0)
        translate([
            -overcut,
            -(od/2 + overcut),
            -((hole_height + od/2)/sin(brace_angle)
                + (hole_height + od/2)/cos(brace_angle) + overcut)
        ])
        cube([
            (hole_height + od/2)/sin(brace_angle)
                + (hole_height + od/2)/cos(brace_angle) + 2*overcut,
            od + 2*overcut,
            (hole_height + od/2)/sin(brace_angle)
                + (hole_height + od/2)/cos(brace_angle) + overcut,
        ]);
    }
}

if (print_plate) {
    //
    rotate([0,90,0])
    translate([-(iron_top_width + iron_top_side_indent_width + default_thickness),0,0])
    right_edge_clip();
} else {
    aquarium_intake_clamp();
}

