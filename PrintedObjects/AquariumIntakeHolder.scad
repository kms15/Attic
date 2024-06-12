include <AquariumIntakeDimensions.scad>

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
    fastener_notch_width=6.4,
    fastener_notch_depth=0.7,
    preferred_bevel = -1,
) {
    adjusted_bevel = (
        (preferred_bevel < 0)
            ? min((od - fastener_notch_width - 2)/2, od/(2 + sqrt(2)))
            : preferred_bevel
    );
    
    difference() {
        union() {
            // front box
            translate([-overcut,-od/2,-overcut])
            cube([support_thickness+overcut, od, hole_height + overcut + od/2]);

            // support box
            translate([support_thickness,-od/2,hole_height + od/2])
            rotate([0,brace_angle,0])
            translate([0,0,-hole_height - od/2 - overcut])
            cube([(hole_height + od/2)/sin(brace_angle), od, hole_height + od/2 + overcut]);    
            
        }

        // slot out the top of the fastener hole
        translate([
            support_thickness + (od - fastener_notch_width)/tan(brace_angle)/2,
            -fastener_notch_width/2,
            hole_height
        ])
            cube([
                (hole_height + fastener_notch_width/2)/sin(brace_angle),
                fastener_notch_width,
                fastener_notch_width/2
            ]);

        // front top right bevel
        translate([0, -od/2, hole_height + od/2])
            rotate([45,0,0])
            translate([-overcut, -sqrt(2)*adjusted_bevel/2, -sqrt(2)*adjusted_bevel/2])
            cube([support_thickness + 2*overcut, sqrt(2)*adjusted_bevel, sqrt(2)*adjusted_bevel]);

        // front top left bevel
        translate([0, od/2, hole_height + od/2])
            rotate([45,0,0])
            translate([-overcut, -sqrt(2)*adjusted_bevel/2, -sqrt(2)*adjusted_bevel/2])
            cube([support_thickness + 2*overcut, sqrt(2)*adjusted_bevel, sqrt(2)*adjusted_bevel]);

        // support top right bevel
        translate([support_thickness, -od/2, hole_height + od/2])
            rotate([45,brace_angle,0])
            translate([-overcut, -sqrt(2)*adjusted_bevel/2, -sqrt(2)*adjusted_bevel/2])
            cube([
                (hole_height + od/2)/sin(brace_angle) + 2*overcut,
                sqrt(2)*adjusted_bevel,
                sqrt(2)*adjusted_bevel]
            );

        // support top left bevel
        translate([support_thickness, od/2, hole_height + od/2])
            rotate([45,brace_angle,0])
            translate([-overcut, -sqrt(2)*adjusted_bevel/2, -sqrt(2)*adjusted_bevel/2])
            cube([
                (hole_height + od/2)/sin(brace_angle) + 2*overcut,
                sqrt(2)*adjusted_bevel,
                sqrt(2)*adjusted_bevel]
            );

        // trim the front (x < 0)
        translate([
            -(hole_height + od/2 + 2*overcut),
            -(od + overcut),
            -(od - hole_height + 2*overcut)
        ])
        cube([
            hole_height + od/2 + 2*overcut,
            2*od + 2*overcut,
            2*od + hole_height + 2*overcut
        ]);
        
        // trim the bottom (z < 0)
        translate([
            -overcut,
            -(od + overcut),
            -((hole_height + od/2)/sin(brace_angle)
                + (hole_height + od/2)/cos(brace_angle) + overcut)
        ])
        cube([
            (hole_height + od/2)/sin(brace_angle)
                + (hole_height + od/2)/cos(brace_angle) + 2*overcut,
            2*od + 2*overcut,
            (hole_height + od/2)/sin(brace_angle)
                + (hole_height + od/2)/cos(brace_angle) + overcut,
        ]);
    }    
}


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
    lower_length=75,
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
                fastener_block($fn=60, hole_height=0, od=2*thickness,
                    support_thickness=(elbow_octogon_side - 2*thickness)/2);
                rotate([0,0,180])
                fastener_block($fn=60, hole_height=0, od=2*thickness,
                    support_thickness=(elbow_octogon_side - 2*thickness)/2);
            }

            // top left fastener block
            translate([0, -(pipe_od/2 + elbow_overlap - bevel - thickness), elbow_od/2 + thickness]) {
                fastener_block($fn=60, hole_height=0, od=2*thickness,
                    support_thickness=(elbow_octogon_side - 2*thickness)/2);
                rotate([0,0,180])
                fastener_block($fn=60, hole_height=0, od=2*thickness,
                    support_thickness=(elbow_octogon_side - 2*thickness)/2);
            }
            
            // middle right fastener block
            translate([0, pipe_od/2 + elbow_overlap - bevel - thickness, -(elbow_od/2 + thickness)]) {
                rotate([180,0,0])
                fastener_block($fn=60, hole_height=0, od=2*thickness,
                    support_thickness=(elbow_octogon_side - 2*thickness)/2);
                rotate([180,0,180])
                fastener_block($fn=60, hole_height=0, od=2*thickness,
                    support_thickness=(elbow_octogon_side - 2*thickness)/2);
                // central brace
                rotate([0, 45, 0])
                    translate([-10/2/sqrt(2), -10, -10/2/sqrt(2)])
                    cube(10/sqrt(2));
            }

            // middle left fastener block
            translate([
                0, 
                -(pipe_od/2 + elbow_overlap - bevel - thickness),
                -(elbow_od/2 + thickness)
            ]) {
                rotate([180,0,0])
                fastener_block($fn=60, hole_height=0, od=2*thickness,
                    support_thickness=(elbow_octogon_side - 2*thickness)/2);
                rotate([180,0,180])
                fastener_block($fn=60, hole_height=0, od=2*thickness,
                    support_thickness=(elbow_octogon_side - 2*thickness)/2);
                // central brace
                rotate([0, 45, 0])
                    translate([-10/2/sqrt(2), -0, -10/2/sqrt(2)])
                    cube(10/sqrt(2));
            }
            
            // bottom right fastener block
            translate([0, pipe_od/2 + thickness, -lower_length + thickness + bevel]) {
                rotate([-90,0,0])
                fastener_block($fn=60, hole_height=0, od=2*thickness,
                    support_thickness=(pipe_octogon_side - 2*thickness)/2);
                rotate([90,0,180])
                fastener_block($fn=60, hole_height=0, od=2*thickness,
                    support_thickness=(pipe_octogon_side - 2*thickness)/2);
            }

            // bottom left fastener block
            translate([0, -(pipe_od/2 + thickness), -lower_length + thickness + bevel]) {
                rotate([90,0,0])
                fastener_block($fn=60, hole_height=0, od=2*thickness,
                    support_thickness=(pipe_octogon_side - 2*thickness)/2);
                rotate([-90,0,180])
                fastener_block($fn=60, hole_height=0, od=2*thickness,
                    support_thickness=(pipe_octogon_side - 2*thickness)/2);
            }
        }
        // tee fitting/pipe cutout
        dummy_tee(extend=extend, $fn=120);
        
        translate([siphon_offset_x, siphon_offset_y, siphon_offset_z]) {
            // top right fastener hole
            translate([0, pipe_od/2 + elbow_overlap - bevel - thickness, elbow_od/2 + thickness])
            fastener_hole();
            
            // top left fastener hole
            translate([0, -(pipe_od/2 + elbow_overlap - bevel - thickness), elbow_od/2 + thickness])
            fastener_hole();

            // middle right fastener hole
            translate([0, pipe_od/2 + elbow_overlap - bevel - thickness, -(elbow_od/2 + thickness)])
            fastener_hole();
            
            // middle left fastener hole
            translate([0, -(pipe_od/2 + elbow_overlap - bevel - thickness), -(elbow_od/2 + thickness)])
            fastener_hole();

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
                rotate([0, -90, 0])
                union() {
                    cylinder(h=8 - default_bevel, d=10, $fn=60);
                    bevel=1;
                    translate([0,0,8 - default_bevel])
                    cylinder(h=bevel, d1=10, d2=10-bevel*2, $fn=60);
                }
        }
        
        // pipe support screw hole
        translate([
            iron_top_width + iron_top_side_indent_width + default_thickness,
            siphon_offset_y,
            siphon_offset_z
            ])
            rotate([0,0,180])
            fastener_hole(hole_depth=11);
        
        // front left fastener hole
        translate([
            iron_top_width + iron_top_side_indent_width + default_thickness,
            50 + iron_top_width
                    + iron_top_side_indent_width + default_thickness,
            - iron_top_indent_depth/2
        ])
        rotate([0,0,180])
        fastener_hole(hole_depth=9);
    }
    
    // bottom back fastener block
    translate([
        iron_top_width + iron_top_side_indent_width + default_thickness,
        iron_thickness + glass_thickness + 10,
        -iron_top_indent_depth - iron_top_indent_thickness - default_thickness
    ]) {
        difference() {
            rotate([180,0,180])
            fastener_block($fn=60);

            translate([0,0,-3.2])
            rotate([0,0,180])
            fastener_hole();
            
            translate([
                -11.5,
                0,
                -11,
            ])
                rotate([0,0,225])
                cube([12,12,12]);
        }
    }
    
    // back toggle attachment block
    translate([
        iron_top_width + iron_top_side_indent_width + default_thickness - 10,
        0,
        default_bevel
    ])
    rotate([0,0,90])
    difference() {
        union() {
            fastener_block(
                od=20,
                hole_height=10,
                support_thickness=7.5,
                $fn=60
            );
            translate([7,-10,0])
            rotate([0,0,90])
            fastener_block(hole_height=default_thickness - default_bevel + 3.2, $fn=60);
        }
        translate([0, 0, 10])
            rotate([0,0,180])
            fastener_hole(hole_depth=20);
        translate([7,-10,3.2+3])
        rotate([0,0,90])
        fastener_hole(hole_depth=25);
    }
    
    // right toggle attachment block
    translate([
        0,
        75,
        default_bevel
    ])
    difference() {
        fastener_block(
            od=20,
            hole_height=10,
            support_thickness=7.5,
            $fn=60
        );
        translate([0, 0, 10])
            rotate([0,0,180])
            fastener_hole(hole_depth=20);
    }
}

module back_edge_clip() {

    right_plate_length = 60;

    difference() {
        union() {
            // back clip
            translate([85,0,0])
            mirror([1,0,0])
            edge_clip(dx=85, corner_distance=125, back_bevels=0, mask_left_back_bevels=25);

            difference() {
                // right side plate
                translate([0, iron_top_width + iron_top_side_indent_width + default_thickness, 
                        -(iron_top_indent_thickness + iron_top_indent_depth + default_thickness),
                ])
                cube([default_thickness, right_plate_length,
                    iron_top_indent_thickness + iron_top_indent_depth + 2*default_thickness]);

                translate([
                    default_thickness,
                    iron_top_width + iron_top_side_indent_width + default_thickness
                        + right_plate_length,
                    -iron_top_indent_depth - iron_top_indent_thickness - default_thickness
                ]) {
                    // front left edge bevel
                    rotate([0,0,45])
                        translate([
                            -sqrt(2)*default_bevel/2,
                            -sqrt(2)*default_bevel/2, 
                            -overcut
                        ])
                        cube([
                            sqrt(2)*default_bevel,
                            sqrt(2)*default_bevel, 
                            iron_top_indent_depth + iron_top_indent_thickness
                                + 2*default_thickness + 2*overcut
                        ]);

                    // bottom front left edge bevel
                    rotate([90,0,0])
                        rotate([0,0,45])
                        translate([
                            -sqrt(2)*default_bevel/2,
                            -sqrt(2)*default_bevel/2, 
                            -overcut
                        ])
                        cube([
                            sqrt(2)*default_bevel,
                            sqrt(2)*default_bevel, 
                            right_plate_length/2
                        ]);

                    // top front left edge bevel
                    translate([
                        0,
                        0,
                        iron_top_indent_depth + iron_top_indent_thickness + 2*default_thickness
                    ])
                        rotate([90,0,0])
                        rotate([0,0,45])
                        translate([
                            -sqrt(2)*default_bevel/2,
                            -sqrt(2)*default_bevel/2, 
                            -overcut
                        ])
                        cube([
                            sqrt(2)*default_bevel,
                            sqrt(2)*default_bevel, 
                            right_plate_length/2
                        ]);
                }
            }
            
            // back top right fastener block
            translate([
                0,
                7,
                default_bevel,
            ])
            fastener_block($fn=60, hole_height=default_thickness - default_bevel + 3.2,
                support_thickness=5);

            // back bottom right fastener block
            translate([
                0,
                iron_thickness + glass_thickness + 10,
                -iron_top_indent_depth - iron_top_indent_thickness - default_thickness
            ])
                rotate([180,0,0])
                fastener_block($fn=60);

            // right tee-shell
            translate([-(iron_top_width + iron_top_side_indent_width + default_thickness),0,0])
            difference() {
                tee_shell();
                translate([siphon_offset_x, siphon_offset_y-100, siphon_offset_z-100])
                cube([100,200,200]);
            }
 
            // back tee-shell support
            translate([
                siphon_offset_x - iron_top_width - iron_top_side_indent_width
                    - default_thickness,
                siphon_offset_y - (pipe_od/2 + elbow_overlap - default_bevel - default_thickness),
                default_thickness
            ])
            difference() {
                rotate([0,45,0])
                    translate([-10*sqrt(2)/2, -default_thickness/2, -10*sqrt(2)/2])
                    cube([10*sqrt(2), 2*default_thickness, 10*sqrt(2)]);
                
                // cut off top of support (to avoid screw hole)
                translate([-10*sqrt(2)/2, -default_thickness/2 - overcut, 6.6])
                    cube([10*sqrt(2), default_thickness + 2*overcut, 10*sqrt(2)]);
                
                // cut off left side of top of support (to avoid left tee shell)
                translate([0, -default_thickness/2 - overcut, 3.5])
                    cube([10*sqrt(2), 2*default_thickness + 2*overcut, 10*sqrt(2)]);
                
                // cut off back left side of top of support (to avoid left tee shell)
                translate([0, default_thickness - overcut, 0])
                    cube([10*sqrt(2), 2*default_thickness + 2*overcut, 10*sqrt(2)]);
            }
        }

        // front right fastener hole
        translate([
            0,
            50 + iron_top_width
                    + iron_top_side_indent_width + default_thickness,
            - iron_top_indent_depth/2
        ])
            rotate([0,0,180])
            fastener_hole();

        // back top right fastener hole
        translate([
            0,
            7,
            default_thickness + 3.2,
        ])
            rotate([0,0,180])
            fastener_hole(hole_depth=10);

        // back bottom right fastener hole
        translate([
            0,
            iron_thickness + glass_thickness + 10,
            -iron_top_indent_depth - iron_top_indent_thickness - default_thickness - 3.2
        ])
            rotate([0,0,180])
            fastener_hole();
    }
}

module left_tee_shell() {
    // left tee-shell
    difference() {
        tee_shell();
        
        // cut out the right half
        translate([siphon_offset_x-100, siphon_offset_y-100, siphon_offset_z-100])
        cube([100,200,200]);
        
        // cut out a slot for the edge clip
        clearance = 1;
        translate([
            siphon_offset_x-100,
            0,
            -iron_top_indent_depth - iron_top_indent_thickness - default_thickness - clearance
        ])
            difference() {
                // main cutout
                cube([
                    200,
                    iron_top_width + iron_top_side_indent_width + default_thickness + clearance,
                    iron_top_indent_depth + iron_top_indent_thickness 
                        + 2*default_thickness + 2*clearance
                ]);
                
                // top cuttout inside corner bezel
                translate([
                    0,
                    iron_top_width + iron_top_side_indent_width + default_thickness + clearance,
                    iron_top_indent_depth + iron_top_indent_thickness 
                        + 2*default_thickness + 2*clearance
                ])
                    rotate([45,0,0])
                    translate([0, -default_bevel*sqrt(2)/2, -default_bevel*sqrt(2)/2])
                    cube([200, default_bevel*sqrt(2), default_bevel*sqrt(2)]);

                
                // bottom cuttout inside corner bezel
                translate([
                    0,
                    iron_top_width + iron_top_side_indent_width + default_thickness + clearance,
                    0
                ])
                    rotate([45,0,0])
                    translate([0, -default_bevel*sqrt(2)/2, -default_bevel*sqrt(2)/2])
                    cube([200, default_bevel*sqrt(2), default_bevel*sqrt(2)]);
                
            }
    }
}

module beveled_cylinder(d, h, bevel) {
    union() {
        // bottom surface/bevel
        cylinder(h=bevel, d1=d-2*bevel, d2=d);

        // middle body
        translate([0,0,bevel])
            cylinder(h=h - 2*bevel, d=d);

        // top bevel/surface
        translate([0,0,h - bevel])
            cylinder(h=bevel, d1=d, d2=d-2*bevel);
    }
}

module toggle(
    d=20,
    l=30,
    h=default_thickness*2,
    bevel=default_bevel,
) {
    difference() {
        hull() {
            beveled_cylinder(d, h, bevel);

            translate([l,0,0])
                beveled_cylinder(d, h, bevel);
        }
        
        rotate([0, -90, 0])
            fastener_hole(hole_depth=10);
    }
}

module aquarium_intake_clamp(explode=0) {
    // right edge clamp
    translate([-explode,0,0])
        color([0.5, 0.7, 0])
        right_edge_clip();

    // back edge clamp
    //translate([1,0,0])
    translate([iron_top_width + iron_top_side_indent_width + default_thickness,0,0])
        color([0, 0.7, 0])
        back_edge_clip();
 
    // left tee shell
    translate([explode,0,0])
        color([0.0, 0.7, 0.4])
        left_tee_shell();

    // back toggle
    translate([
        iron_top_width + iron_top_side_indent_width + default_thickness - explode - 10,
        -explode,
        10 + default_bevel
    ])
        color([0.7, 0.7, 0.0])
        rotate([90,90,0])
        toggle($fn=60);

    // right toggle
    translate([
        -2*explode,
        75,
        10 + default_bevel
    ])
        color([0.7, 0.7, 0.0])
        rotate([90,90,-90])
        toggle($fn=60);

    // tee_shell();
}


module test_connector_cube() {
    union() {
        cube([10,10,15]);
        
        // left down block
        translate([0.1,5,0])
            rotate([0,-90,0])
            difference() {
                fastener_block($fn=60);
                translate([0,0,3.5])
                    fastener_hole();
            }
            
        // right down block
        translate([9.9,5,0])
            rotate([0,-90,-180])
            difference() {
                fastener_block($fn=60);
                translate([0,0,3.5])
                    rotate([0,180,0])
                    fastener_hole();
            }
        
        // front up block
        translate([5,0.1,15])
            rotate([90,90,0])
            difference() {
                fastener_block($fn=60);
                translate([0,0,3.5])
                    rotate([0,180,0])
                    fastener_hole();
            }
            
        // back up block
        translate([5,9.9,15])
            rotate([90,90,180])
            difference() {
                fastener_block($fn=60);
                translate([0,0,3.5])
                    fastener_hole();
            }
    }
}


print_plate = 1;
print_test_connectors=0;


if (print_plate) {
    // right edge clip
    translate([-100,50,0])
    rotate([0,90,0])
        translate([-(iron_top_width + iron_top_side_indent_width + default_thickness),0,0])
        right_edge_clip();
    
    // back edge clip
    rotate([0,-90,0])
    translate([iron_top_width + iron_top_side_indent_width + default_thickness,0,0])
        translate([-(iron_top_width + iron_top_side_indent_width + default_thickness),0,0])
        back_edge_clip();
    
    // left tee shell
    translate([-35, 85, elbow_od/2 + default_thickness])
    rotate([0,90,0])
    translate([-siphon_offset_x, 0, 0])
    left_tee_shell();
    
    // back toggle
    translate([-110,35,0])
        toggle();
    
    // side toggle
    translate([-110,10,0])
        toggle();

    
} else if (print_test_connectors) {
    difference() {
        union() {
            test_connector_cube();
                
            translate([30,0,0])
                test_connector_cube();

            translate([10,30,0])
                rotate([0,-90,0])
                test_connector_cube();
            

            translate([30,40,0])
                rotate([90,0,0])
                test_connector_cube();
        }
        translate([-10, -10, -20])
            cube([100, 100, 20]);
    }
} else {
    aquarium_intake_clamp(explode=15);
}

// TODO:
// remaining bevels
// final check of unions and kissing surfaces