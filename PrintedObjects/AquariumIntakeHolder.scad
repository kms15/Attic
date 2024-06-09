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
        cube([dx + 2 * overcut, corner_cut*sqrt(2), corner_cut*sqrt(2)]);      
        
        // bottom inside bevel
        translate([0, dy, - bottom_dz - lip_dz - edge_dz])
        rotate([45,0,0])
        translate([-overcut, -corner_cut*sqrt(2)/2, -corner_cut*sqrt(2)/2]) 
        cube([dx + 2 * overcut, corner_cut*sqrt(2), corner_cut*sqrt(2)]); 
   
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
        translate([dx, 0, top_dz])
        rotate([0,45,0])
        translate([-corner_cut*sqrt(2)/2, -overcut, -corner_cut*sqrt(2)/2]) 
        cube([corner_cut*sqrt(2), dy + 2 * overcut, corner_cut*sqrt(2)]); 
   
        // bottom back bevel
        translate([dx, 0, - bottom_dz - lip_dz - edge_dz])
        rotate([0,45,0])
        translate([-corner_cut*sqrt(2)/2, -overcut, -corner_cut*sqrt(2)/2]) 
        cube([corner_cut*sqrt(2), dy + 2 * overcut, corner_cut*sqrt(2)]); 
        
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
        
        // right back bevel
        translate([dx, 0, 0])
        rotate([0,0,45])
        translate([-corner_cut*sqrt(2)/2, -corner_cut*sqrt(2)/2,
            - bottom_dz - lip_dz - edge_dz - overcut]) 
        cube([corner_cut*sqrt(2), corner_cut*sqrt(2),
            bottom_dz + lip_dz + edge_dz + top_dz + 2 * overcut]);        
        
        // left back bevel
        translate([dx, dy, 0])
        rotate([0,0,45])
        translate([-corner_cut*sqrt(2)/2, -corner_cut*sqrt(2)/2,
            - bottom_dz - lip_dz - edge_dz - overcut]) 
        cube([corner_cut*sqrt(2), corner_cut*sqrt(2),
            bottom_dz + lip_dz + edge_dz + top_dz + 2 * overcut]);        
        
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
                translate([elbow_od/2, -pipe_octogon_side/2, -lower_length])
                    cube([thickness, pipe_octogon_side, lower_length]);
                translate([pipe_od/2 + thickness - bevel, -pipe_octogon_side/2 - overcut, -lower_length])
                    rotate([0, 45, 0])
                    cube([
                        (elbow_octogon_diameter - pipe_od)/2,
                        pipe_octogon_side + 2*overcut,
                        lower_length
                    ]);
            }
                        
            // right lower brace
            rotate([0,0,180])
            difference() {
                translate([elbow_od/2, -pipe_octogon_side/2, -lower_length])
                    cube([thickness, pipe_octogon_side, lower_length]);
                translate([pipe_od/2 + thickness - bevel, -pipe_octogon_side/2 - overcut, -lower_length])
                    rotate([0, 45, 0])
                    cube([
                        (elbow_octogon_diameter - pipe_od)/2,
                        pipe_octogon_side + 2*overcut,
                        lower_length
                    ]);
            }
        }
        dummy_tee(extend=extend, $fn=120);
    }
}

module right_edge_clip() {
    translate([0,125,0])
    rotate([0,0,-90])
    edge_clip(dx=125, corner_distance=125);
}

module back_edge_clip() {
    translate([125,0,0])
    mirror([1,0,0])
    edge_clip(dx=85, corner_distance=125);
}

module aquarium_intake_clamp() {
    // right edge clamp
    color([0.5, 0.7, 0])
    right_edge_clip();

    // back edge clamp
    color([0, 0.7, 0])
    back_edge_clip();
    
    // top tee    
    //color([0.7, 0.7, 0, 0.2])
    //dummy_tee();
    
    color([0, 0.7, 0])
    tee_shell();
    
/*
    // right pipe clamp
    color([0, 0.7, 0])
    translate([40,10,-60])
    cube([29,100,150]);

    // left pipe clamp
    color([0.5, 0.7, 0.7])
    translate([40 + 31,10,-60])
    cube([29,100,150]);

    // right latch
    color([0, 1, 0.7])
    translate([-10,60 - 10/2,-30])
    cube([10,10,40]);

    // rear latch
    color([0, 1, 0.7])
    translate([20,-10,-30])
    cube([10,10,40]);
*/
}

/*
// clip 1
translate([30, 0, 0])
difference() {
    rotate([0,-90,0])
    edge_clip(lip_height=5 + 0.25, undercut_width=13.5);
    
    translate([-13,29,4])
    rotate([0,0,90])
    linear_extrude()
    text("1");
}

// clip 0
difference() {
    rotate([0,-90,0])
    edge_clip(undercut_width=13.5);

    translate([-13,29,4])
    rotate([0,0,90])
    linear_extrude()
    text("0");
}

// clip -1
translate([-30, 0, 0])[
difference() {
    rotate([0,-90,0])
    edge_clip(lip_height=5 - 0.25, undercut_width=13.5);
    
    translate([-13,26,4])
    rotate([0,0,90])
    linear_extrude()
    text("-1");
}
*/

//aquarium_intake_clamp();

print_plate = 0;

if (print_plate) {
    translate([0,0,iron_top_width + iron_top_side_indent_width + default_thickness])
    rotate([-90,0,0])
    edge_clip(include_corner=1);
} else {
    aquarium_intake_clamp();
}

