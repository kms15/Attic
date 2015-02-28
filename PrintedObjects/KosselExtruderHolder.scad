// Used to hold the extruder on a Kossel printer without zip-ties
$fn=60;

m3Clearance = 0.25;
m3Diameter = 3;
m3NutDiameter = 6;
m3NutThickness = 2.4;
m3SHCSHeadDiameter = 5.5;
m3SHCSHeadHeight = 3;

module m3NutTrap(h = m3NutThickness) {
    $fn=6;
    cylinder(h=h, r=m3NutDiameter/2);
}

SHCSFloorHeight = 3;
SHCSCounterboreDepth = m3SHCSHeadHeight + 2 * m3Clearance;
blockHeight = SHCSFloorHeight + SHCSCounterboreDepth;
blockWallThickness = 2;
blockWidth = m3NutDiameter + blockWallThickness;

overcut = 1;
gearBoxDiameter = 36;
ringThickness = 2;
ringHeight = 12;
ringGap = 3;

gapBlockWidth = ringThickness + 2*blockWallThickness + m3NutDiameter;
gapBlockDepth = 2*blockHeight + ringGap;

mountingBlockWidth = 2*blockWallThickness + m3NutDiameter;
mountingBlockDepth = blockHeight;
mountingBlockHeight = 40;

filletRadius = 10;

mountingBlockFilletY = sqrt(
    pow(gearBoxDiameter/2 + ringThickness + filletRadius, 2) -
    pow(mountingBlockWidth/2 + filletRadius, 2));
mountingBlockFilletXRingContact = (gearBoxDiameter/2 + ringThickness)
    / (gearBoxDiameter/2 + ringThickness + filletRadius) *
    (mountingBlockWidth/2 + filletRadius);

gapBlockFilletX = sqrt(
    pow(gearBoxDiameter/2 + ringThickness + filletRadius, 2) -
    pow(gapBlockDepth/2 + filletRadius, 2));
gapBlockFilletYRingContact = (gearBoxDiameter/2 + ringThickness)
    / (gearBoxDiameter/2 + ringThickness + filletRadius) *
    (gapBlockDepth/2 + filletRadius);

difference() {
    union() {
        // outside of ring
        cylinder(r=gearBoxDiameter/2 + ringThickness, h=ringHeight);

        // ring tensioning block
        translate([0,-gapBlockDepth/2,0])
            cube([gearBoxDiameter/2 + gapBlockWidth - ringHeight/2,
                gapBlockDepth, ringHeight]);
        translate([gearBoxDiameter/2 + gapBlockWidth - ringHeight/2,
                -gapBlockDepth/2, ringHeight/2])
            rotate([-90,0,0])
            cylinder(r=ringHeight/2, h=gapBlockDepth);

        // mounting block
        translate([-mountingBlockWidth/2,0,0])
            cube([mountingBlockWidth, mountingBlockDepth + gearBoxDiameter/2,
                mountingBlockHeight - mountingBlockWidth/2]);
        translate([0, 0, mountingBlockHeight - mountingBlockWidth/2])
            rotate([-90,0,0])
            cylinder(r=mountingBlockWidth/2,
                h=gearBoxDiameter/2 + mountingBlockDepth);

        // mounting block reinforcements, pre-fillet
        translate([-mountingBlockFilletXRingContact,0,0])
            cube([2*mountingBlockFilletXRingContact,
                min(filletRadius, mountingBlockDepth) + gearBoxDiameter/2,
                ringHeight + filletRadius]);
        intersection() {
            cylinder(r=gearBoxDiameter/2 + ringThickness,
                h=ringHeight + filletRadius);
            translate([-mountingBlockWidth/2 - filletRadius,0])
            cube([mountingBlockWidth + 2*filletRadius,
                gearBoxDiameter/2 + ringThickness,
                ringHeight + filletRadius]);
        }

        // gap block reinforcements, pre-fillet
        translate([0, -gapBlockFilletYRingContact, 0])
            cube([min(filletRadius, gapBlockWidth/2) + gearBoxDiameter/2,
                2*gapBlockFilletYRingContact,
                ringHeight]);
    }

    // inside of ring
    translate([0,0,-overcut])
        cylinder(r=gearBoxDiameter/2, h=mountingBlockHeight + 2*overcut);

    // gap in ring and ring tensioning block
    translate([0,-ringGap/2, -overcut])
        cube([gearBoxDiameter/2 + gapBlockWidth + overcut, ringGap,
            ringHeight + 2*overcut]);

    // horizontal fillets in mounting block
    translate([-mountingBlockWidth/2 - filletRadius, -overcut,
            ringHeight + filletRadius])
        rotate([-90,0,0])
        cylinder(r=filletRadius, h=mountingBlockHeight + 2*overcut);
    translate([mountingBlockWidth/2 + filletRadius, -overcut,
            ringHeight + filletRadius])
        rotate([-90,0,0])
        cylinder(r=filletRadius, h=mountingBlockHeight + 2*overcut);

    // vertical fillets in mounting block
    translate([mountingBlockWidth/2 + filletRadius,
            mountingBlockFilletY, -overcut])
        cylinder(r=filletRadius, h=2*overcut + ringHeight + filletRadius);
    translate([-(mountingBlockWidth/2 + filletRadius),
            mountingBlockFilletY, -overcut])
        cylinder(r=filletRadius, h=2*overcut + ringHeight + filletRadius);

    // vertical fillets in ring-tensioning block
    translate([gapBlockFilletX, gapBlockDepth/2 + filletRadius, -overcut])
        cylinder(r=filletRadius, h=2*overcut + ringHeight + filletRadius);
    translate([gapBlockFilletX, -(gapBlockDepth/2 + filletRadius), -overcut])
        cylinder(r=filletRadius, h=2*overcut + ringHeight + filletRadius);

    // hole for tensioning screw
    translate([gearBoxDiameter/2 + gapBlockWidth/2,
            -gapBlockDepth/2 - filletRadius, ringHeight/2])
        rotate([-90,0,0]) {
            cylinder(r=m3Diameter/2 + m3Clearance,
                h=gapBlockDepth + 2*filletRadius);
            cylinder(r=m3SHCSHeadDiameter/2 + m3Clearance,
                h=SHCSCounterboreDepth + filletRadius);
            translate([0, 0,
                    filletRadius + gapBlockDepth - SHCSCounterboreDepth])
                m3NutTrap(SHCSCounterboreDepth + filletRadius);
        }

    // mounting holes
    translate ([0, 0, mountingBlockWidth/2])
        rotate([-90,0,0]) {
            cylinder(r=m3Diameter/2 + m3Clearance,
                h=gearBoxDiameter/2 + mountingBlockDepth + overcut);
            cylinder(r=m3SHCSHeadDiameter/2 + m3Clearance,
                h=gearBoxDiameter/2 + SHCSCounterboreDepth);
        }
    translate ([0, 0, mountingBlockHeight/2])
        rotate([-90,0,0]) {
            cylinder(r=m3Diameter/2 + m3Clearance,
                h=gearBoxDiameter/2 + mountingBlockDepth + overcut);
            cylinder(r=m3SHCSHeadDiameter/2 + m3Clearance,
                h=gearBoxDiameter/2 + SHCSCounterboreDepth);
        }
    translate ([0, 0, mountingBlockHeight - mountingBlockWidth/2])
        rotate([-90,0,0]) {
            cylinder(r=m3Diameter/2 + m3Clearance,
                h=gearBoxDiameter/2 + mountingBlockDepth + overcut);
            cylinder(r=m3SHCSHeadDiameter/2 + m3Clearance,
                h=gearBoxDiameter/2 + SHCSCounterboreDepth);
        }
}
