#!/usr/bin/python3
import math

# Generate a series of depths that cut a material at start_depth down to the
# stop depth, starting with rough_cut depth cuts and gradual transitioning
# to fine_cut depth cuts near the end (with a minimum of min_transition_cuts
# of somewhat finer cuts near the end).
def cut_depths(start_depth, stop_depth, rough_cut=0.1, fine_cut=0.02,
        min_transition_cuts=11):
    estimated_transition_cuts = max(min_transition_cuts + 1,
            math.ceil(rough_cut/fine_cut))
    transition_diameter = stop_depth + 2 * estimated_transition_cuts * fine_cut

    depth = start_depth
    while depth > transition_diameter:
        depth -= rough_cut
        yield depth

    transition_cuts = max(0, math.ceil((depth - stop_depth)/(2*fine_cut)))
    margin = depth - stop_depth - transition_cuts * fine_cut
    delta_delta_cut = 2 * margin / ((transition_cuts + 1) * transition_cuts)
    for i in range(transition_cuts, 0, -1):
        depth -= fine_cut + i * delta_delta_cut
        yield depth

# Writes gcode to a file f that will move to the start of a cut at (x0, y0)
# and speed f_move, cut to (x1, y1) at speed f_cut, then move back by
# (x_clearance, y_clearance) and move back near the start of the cut (at
# (x0 + x_clearance, x1 + y_clearance).
def cut_to(f, x0, y0, x1, y1, x_clearance=0, y_clearance=0.2,
        f_move=150, f_cut=20):
    move_clearance = 0.2
    f_move = 150
    f_cut = 20
    f.write("G0 X{0:.4f} Y{1:.4f} F{2}\n".format(x0, y0, f_move))
    f.write("G1 X{0:.4f} Y{1:.4f} F{2}\n".format(x1, y1, f_cut))
    f.write("G0 X{0:.4f} Y{1:.4f} F{2}\n".format(x1 + x_clearance,
        y1 + y_clearance, f_move))
    f.write("G0 X{0:.4f} Y{1:.4f} F{2}\n".format(x0 + x_clearance,
        y0 + y_clearance, f_move))


def main():
    with open("lathe_turn_down.gcode","w") as f:
        x0 = 0
        y0 = 6
        x1 = 30
        y1 = 4

        for y in cut_depths(y0, y1):
            cut_to(f, x0, y, x1, y);

if __name__ == "__main__":
    main()
