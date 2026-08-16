perch_diam=10; // mm
perch_len=300; // mm
$fn=60;
overcut=1;
bar_width=3; // mm
bar_spacing=297/20; // mm

num_bars=floor(perch_len / bar_spacing + 1);
first_bar_offset=(perch_len - bar_spacing * (num_bars - 1)) / 2;

translate([0,0,perch_diam/2])
rotate([0,-90,0])
difference() {
    cylinder(d=perch_diam, h=perch_len);
    translate([-perch_diam/5, 0, -overcut])
        cube([perch_diam, bar_width, perch_len + 2*overcut]);
    translate([-perch_diam/5, -bar_width/2, 2.5])
        rotate([0, 90, 0])
        cylinder(d=bar_width, h=perch_diam);
    //translate([-perch_diam/5, -bar_width/2, 2.5 - bar_width/2])
    //    cube([perch_diam, bar_width, bar_width]);
    //translate([-perch_diam/5, -bar_width/2, 17.5])
    //    rotate([0, 90, 0])
    //    cylinder(d=bar_width, h=perch_diam);
    //translate([-perch_diam/5, -bar_width/2, 17.5 - bar_width/2])
    //    cube([perch_diam, bar_width, bar_width]);
    for (i = [0 : num_bars]) {
        translate([-perch_diam/5, -bar_width,
                bar_spacing * i + first_bar_offset - bar_width])
            cube([
                perch_diam, 
                bar_width + overcut, 
                bar_width*2
            ]);
    }
}