cameraTubeOuterDiameter = 14.2;
cameraTubeHeight = 10;
eyepieceTubeInnerDiameter = 30.5;
flangeHeight = 2;
flangeWidth = flangeHeight;
eyepieceCuffHeight = 20;
clearance = 0.25;

$fn = 60;
overcut = 0.01;
adapterDiameter = eyepieceTubeInnerDiameter - 2*clearance;
adapterHeight = cameraTubeHeight;

difference() {
    union () {
        cylinder(h=adapterHeight, d=adapterDiameter);
        cylinder(h=flangeHeight, d=adapterDiameter + 2*flangeWidth);
    }
    translate([0,0,-overcut])
        cylinder(h=adapterHeight + 2*overcut, 
            d=cameraTubeOuterDiameter + 2*clearance);
}
