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
        translate([-overcut, -corner_cut/(2*sqrt(2)), -corner_cut/(2*sqrt(2))]) 
        cube([dx + 2 * overcut, corner_cut/sqrt(2), corner_cut/sqrt(2)]); 
        
        // bevel at bottom of top of edge
        translate([0, 0, 0])
        rotate([45,0,0])
        translate([-overcut, -corner_cut/(2*sqrt(2)), -corner_cut/(2*sqrt(2))]) 
        cube([dx + 2 * overcut, corner_cut/sqrt(2), corner_cut/sqrt(2)]);        

        // bevel between top of lip and side of edge
        translate([0, edge_dy, -edge_dz])
        rotate([45,0,0])
        translate([-overcut, -corner_cut/(2*sqrt(2)), -corner_cut/(2*sqrt(2))]) 
        cube([dx + 2 * overcut, corner_cut/sqrt(2), corner_cut/sqrt(2)]);
        
        // bevel between bottom of lip and glass
        translate([0, undercut_dy, - edge_dz - lip_dz])
        rotate([45,0,0])
        translate([-overcut, -corner_cut/(2*sqrt(2)), -corner_cut/(2*sqrt(2))]) 
        cube([dx + 2 * overcut, corner_cut/sqrt(2), corner_cut/sqrt(2)]);
        
        // top inside bevel
        translate([0, dy, top_dz])
        rotate([45,0,0])
        translate([-overcut, -corner_cut/(2*sqrt(2)), -corner_cut/(2*sqrt(2))]) 
        cube([dx + 2 * overcut, corner_cut/sqrt(2), corner_cut/sqrt(2)]);        
        
        // bottom inside bevel
        translate([0, dy, - bottom_dz - lip_dz - edge_dz])
        rotate([45,0,0])
        translate([-overcut, -corner_cut/(2*sqrt(2)), -corner_cut/(2*sqrt(2))]) 
        cube([dx + 2 * overcut, corner_cut/sqrt(2), corner_cut/sqrt(2)]);
   
        // top front bevel
        translate([0, 0, top_dz])
        rotate([0, 45,0])
        translate([-corner_cut/(2*sqrt(2)), -overcut, -corner_cut/(2*sqrt(2))]) 
        cube([corner_cut/sqrt(2), dy + 2 * overcut, corner_cut/sqrt(2)]);
   
        // bottom front bevel
        translate([0, 0, - bottom_dz - lip_dz - edge_dz])
        rotate([0, 45,0])
        translate([-corner_cut/(2*sqrt(2)), -overcut, -corner_cut/(2*sqrt(2))]) 
        cube([corner_cut/sqrt(2), dy + 2 * overcut, corner_cut/sqrt(2)]);
   
        // top back bevel
        translate([dx, 0, top_dz])
        rotate([0, 45,0])
        translate([-corner_cut/(2*sqrt(2)), -overcut, -corner_cut/(2*sqrt(2))]) 
        cube([corner_cut/sqrt(2), dy + 2 * overcut, corner_cut/sqrt(2)]);
   
        // bottom back bevel
        translate([dx, 0, - bottom_dz - lip_dz - edge_dz])
        rotate([0, 45,0])
        translate([-corner_cut/(2*sqrt(2)), -overcut, -corner_cut/(2*sqrt(2))]) 
        cube([corner_cut/sqrt(2), dy + 2 * overcut, corner_cut/sqrt(2)]);
        
        // right front bevel
        translate([0, 0, 0])
        rotate([0, 0, 45])
        translate([-corner_cut/(2*sqrt(2)), -corner_cut/(2*sqrt(2)), - bottom_dz - lip_dz - edge_dz]) 
        cube([corner_cut/sqrt(2), corner_cut/sqrt(2),
            bottom_dz + lip_dz + edge_dz + top_dz + 2 * overcut]);        
        
        // left front bevel
        translate([0, dy, 0])
        rotate([0, 0, 45])
        translate([-corner_cut/(2*sqrt(2)), -corner_cut/(2*sqrt(2)), - bottom_dz - lip_dz - edge_dz]) 
        cube([corner_cut/sqrt(2), corner_cut/sqrt(2),
            bottom_dz + lip_dz + edge_dz + top_dz + 2 * overcut]);
        
        // right back bevel
        translate([dx, 0, 0])
        rotate([0, 0, 45])
        translate([-corner_cut/(2*sqrt(2)), -corner_cut/(2*sqrt(2)), - bottom_dz - lip_dz - edge_dz]) 
        cube([corner_cut/sqrt(2), corner_cut/sqrt(2),
            bottom_dz + lip_dz + edge_dz + top_dz + 2 * overcut]);        
        
        // left back bevel
        translate([dx, dy, 0])
        rotate([0, 0, 45])
        translate([-corner_cut/(2*sqrt(2)), -corner_cut/(2*sqrt(2)), - bottom_dz - lip_dz - edge_dz]) 
        cube([corner_cut/sqrt(2), corner_cut/sqrt(2),
            bottom_dz + lip_dz + edge_dz + top_dz + 2 * overcut]);
    }
}

module aquarium_intake_clamp() {
    // right pipe clamp
    color([0, 0.7, 0])
    translate([40,10,-60])
    cube([29,100,150]);

    // back edge clamp
    color([0, 0.7, 0])
    translate([40,0.01,-25])
    cube([80,40,35]);  

    // left pipe clamp
    color([0.5, 0.7, 0.7])
    translate([40 + 31,10,-60])
    cube([29,100,150]);

    // right edge clamp
    color([0.5, 0.7, 0])
    translate([0,125,0])
    rotate([0,0,-90])
    edge_clip(dx=125);
    //translate([0.01,0.01,-25])
    //cube([40,120,35]);

    // right latch
    color([0, 1, 0.7])
    translate([-10,60 - 10/2,-30])
    cube([10,10,40]);

    // rear latch
    color([0, 1, 0.7])
    translate([20,-10,-30])
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

//aquarium_intake_clamp();

//rotate([0,-90,0])
edge_clip();