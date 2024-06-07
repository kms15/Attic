include <AquariumIntakeDimensions.scad>

module edge_clip(
    dx = default_thickness,
    dy = iron_top_width + iron_top_indent_width + default_thickness,
    top_dz = default_thickness,
    bottom_dz = default_thickness,
    lip_dy=iron_top_indent_width,
    lip_dz=iron_top_indent_thickness,
    edge_dy=iron_top_width,
    edge_dz=iron_top_indent_depth,
    undercut_dy=iron_thickness + glass_thickness,
    corner_cut=default_bevel,
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
        translate([-overcut, 0, top_dz])
        rotate([45,0,0])
        translate([0, -corner_cut/(2*sqrt(2)), -corner_cut/(2*sqrt(2))]) 
        cube([dx + 2 * overcut, corner_cut/sqrt(2), corner_cut/sqrt(2)]); 
        
        // bevel at bottom of top of edge
        translate([-overcut, 0, 0])
        rotate([45,0,0])
        translate([0, -corner_cut/(2*sqrt(2)), -corner_cut/(2*sqrt(2))]) 
        cube([dx + 2 * overcut, corner_cut/sqrt(2), corner_cut/sqrt(2)]);        

        // bevel between top of lip and side of edge
        translate([-overcut, edge_dy, -edge_dz])
        rotate([45,0,0])
        translate([0, -corner_cut/(2*sqrt(2)), -corner_cut/(2*sqrt(2))]) 
        cube([dx + 2 * overcut, corner_cut/sqrt(2), corner_cut/sqrt(2)]);
        
        // bevel between bottom of lip and glass
        translate([-overcut, undercut_dy, - edge_dz - lip_dz])
        rotate([45,0,0])
        translate([0, -corner_cut/(2*sqrt(2)), -corner_cut/(2*sqrt(2))]) 
        cube([dx + 2 * overcut, corner_cut/sqrt(2), corner_cut/sqrt(2)]);
/*
        // bevel at top of edge
        translate([-overcut, 0, (h - edge_height - lip_height)/2 + lip_height + edge_height])
        rotate([45,0,0])
        translate([0, -corner_cut/(2*sqrt(2)), -corner_cut/(2*sqrt(2))]) 
        cube([l + 2 * overcut, corner_cut/sqrt(2), corner_cut/sqrt(2)]);        
        
        // bevel between top of lip and side of edge
        translate([-overcut, edge_width, (h - edge_height - lip_height)/2 + lip_height])
        rotate([45,0,0])
        translate([0, -corner_cut/(2*sqrt(2)), -corner_cut/(2*sqrt(2))]) 
        cube([l + 2 * overcut, corner_cut/sqrt(2), corner_cut/sqrt(2)]);
        
        // bevel between bottom of lip and glass
        translate([-overcut, edge_width + lip_width - undercut_width, (h - edge_height - lip_height)/2])
        rotate([45,0,0])
        translate([0, -corner_cut/(2*sqrt(2)), -corner_cut/(2*sqrt(2))]) 
        cube([l + 2 * overcut, corner_cut/sqrt(2), corner_cut/sqrt(2)]);
        */
    }
}

module aquarium_intake_clamp() {
    // right pipe clamp
    color([0, 0.7, 0])
    translate([40,10,aquarium_height-60])
    cube([29,100,150]);

    // back edge clamp
    color([0, 0.7, 0])
    translate([40,0.01,aquarium_height-25])
    cube([80,40,35]);  

    // left pipe clamp
    color([0.5, 0.7, 0.7])
    translate([40 + 31,10,aquarium_height-60])
    cube([29,100,150]);

    // right edge clamp
    color([0.5, 0.7, 0])
    translate([0.01,0.01,aquarium_height-25])
    cube([40,120,35]);

    // right latch
    color([0, 1, 0.7])
    translate([-10,60 - 10/2,aquarium_height-30])
    cube([10,10,40]);

    // rear latch
    color([0, 1, 0.7])
    translate([20,-10,aquarium_height-30])
    cube([10,10,40]);
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
translate([-30, 0, 0])
difference() {
    rotate([0,-90,0])
    edge_clip(lip_height=5 - 0.25, undercut_width=13.5);
    
    translate([-13,26,4])
    rotate([0,0,90])
    linear_extrude()
    text("-1");
}
*/
edge_clip();