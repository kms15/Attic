cameraLensDiameter = 15;
eyepieceDiameter = 30;
wallThickness = 5;
cameraLensCuffHeight = 20;
eyepieceCuffHeight = 20;
clearance = 0.25;

$fn = 60;
overcut = 0.01;
adapterDiameter = max(cameraLensDiameter, eyepieceDiameter) + 
    2*wallThickness + 2*clearance;
adapterHeight = cameraLensCuffHeight + eyepieceCuffHeight;

difference() {
    cylinder(h=adapterHeight, d=adapterDiameter);
    translate([0,0,-overcut])
        cylinder(h=cameraLensCuffHeight + 2*overcut, 
            d=cameraLensDiameter + 2*clearance);
    translate([0,0,cameraLensCuffHeight])
        cylinder(h=eyepieceCuffHeight + overcut, 
            d=eyepieceDiameter + 2*clearance);}