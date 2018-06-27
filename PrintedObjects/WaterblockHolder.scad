$fn=60;
waterblockDim=[41+0.5,41+0.5,12+1];
wallThickness=5;
curvature=3;
insertDiam=6.4;
insertHeight=10;
m5HoleDiam=5.3;
m5CountersinkDiam=10.3;
pillarDiam=insertDiam + 2*wallThickness;

module waterBlockHolder(useInserts=0) {
difference() {
    union () {
        // main body
        translate([
            -waterblockDim[0]/2 - wallThickness + curvature,
            -waterblockDim[1]/2 - wallThickness + curvature,
            0])
            minkowski() {
                cube([
                    waterblockDim[0] + 2*wallThickness - 2*curvature,
                    waterblockDim[1] + 2*wallThickness - 2*curvature,
                    waterblockDim[2] + wallThickness - 1]);
                cylinder(r=curvature, h=1);
            }
        // left pillar
        translate([-waterblockDim[0]/2 - pillarDiam/2, 0, 0])
            cylinder(d=pillarDiam, h=waterblockDim[2] + wallThickness);
        translate([-waterblockDim[0]/2 - pillarDiam/2, - pillarDiam/2, 0])
            cube([pillarDiam/2, pillarDiam, waterblockDim[2] + wallThickness]);
        // right pillar
        translate([waterblockDim[0]/2 + pillarDiam/2, 0, 0])
            cylinder(d=pillarDiam, h=waterblockDim[2] + wallThickness);
        translate([waterblockDim[0]/2, - pillarDiam/2, 0])
            cube([pillarDiam/2, pillarDiam, waterblockDim[2] + wallThickness]);
    }

    // waterblock cutout
    translate([-waterblockDim[0]/2, -waterblockDim[1]/2, wallThickness])
        cube(waterblockDim + [0,0,1]);

    // left tubing cutout
    translate([-waterblockDim[0]/2, waterblockDim[1]/2 - 1, waterblockDim[2]/2 + wallThickness])
        cube([waterblockDim[0]/3, wallThickness + 1 + 1, waterblockDim[2] + 1]);
    translate([-waterblockDim[0]/3, waterblockDim[1]/2 - 1, waterblockDim[2]/2 + wallThickness])
        rotate([-90,0,0]) cylinder(d=waterblockDim[0]/3, h=wallThickness + 1 + 1);

    // right tubing cutout
    translate([waterblockDim[0]/6, waterblockDim[1]/2 - 1, waterblockDim[2]/2 + wallThickness])
        cube([waterblockDim[0]/3, wallThickness + 1 + 1, waterblockDim[2] + 1]);
    translate([waterblockDim[0]/3, waterblockDim[1]/2 - 1, waterblockDim[2]/2 + wallThickness])
        rotate([-90,0,0]) cylinder(d=waterblockDim[0]/3, h=wallThickness + 1 + 1);

    // screw cutouts
    translate([-waterblockDim[0]/2 - pillarDiam/2, 0, -1])
        cylinder(d=m5HoleDiam, h=waterblockDim[2] + wallThickness + 1 + 1);
    translate([waterblockDim[0]/2 + pillarDiam/2, 0, -1])
        cylinder(d=m5HoleDiam, h=waterblockDim[2] + wallThickness + 1 + 1);

    // hole for pushing out waterblock
    translate([0, 0, -1])
        cylinder(d=waterblockDim[0]/3, h=waterblockDim[2] + wallThickness + 1 + 1);


    if (useInserts != 0) {
        // insert cutouts
        translate([-waterblockDim[0]/2 - pillarDiam/2, 0, waterblockDim[2] + wallThickness - insertHeight])
            cylinder(d=insertDiam, h=waterblockDim[2] + wallThickness + 1 + 1);
        translate([waterblockDim[0]/2 + pillarDiam/2, 0, waterblockDim[2] + wallThickness - insertHeight])
            cylinder(d=insertDiam, h=waterblockDim[2] + wallThickness + 1 + 1);
    } else {
        // screw countersinking
        translate([-waterblockDim[0]/2 - pillarDiam/2, 0, -1])
            cylinder(d=m5CountersinkDiam, h=waterblockDim[2] + 1);
        translate([waterblockDim[0]/2 + pillarDiam/2, 0, -1])
            cylinder(d=m5CountersinkDiam, h=waterblockDim[2] + 1);
    }
}
}

translate([0, 40, 0]) waterBlockHolder();
translate([0, -40, 0]) waterBlockHolder(useInserts=1);
