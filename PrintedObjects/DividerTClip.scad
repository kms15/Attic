// Clipped across two dividers (think cubicle partitions) to hold their tops at
// a right angle.

slotWidth = 27.27;
slotDepth = 10;
wallThickness = 9.5;
floorThickness = 4.5;
armLength = 44;

overcut = 1;

difference() {
	union() {
		cube([2*wallThickness + slotWidth, 2*armLength, slotDepth + floorThickness]);
		translate([wallThickness + slotWidth/2, armLength - slotWidth/2 - wallThickness, 0]) 
		cube([armLength, 2*wallThickness + slotWidth, slotDepth + floorThickness]);
	}
	translate([wallThickness, -overcut, floorThickness])
	cube([slotWidth, 2*armLength + 2*overcut, slotDepth + overcut]);
		translate([wallThickness + slotWidth/2, armLength - slotWidth/2, floorThickness]) 
	cube([armLength + overcut, slotWidth, slotDepth + overcut]);
}