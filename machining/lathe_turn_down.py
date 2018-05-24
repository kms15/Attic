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
    transition_diameter = stop_depth - 2 * estimated_transition_cuts * fine_cut

    depth = start_depth
    while depth < transition_diameter:
        depth += rough_cut
        yield depth

    transition_cuts = max(0, math.ceil((stop_depth - depth)/(2*fine_cut)))
    margin = stop_depth - depth - transition_cuts * fine_cut
    delta_delta_cut = 2 * margin / ((transition_cuts + 1) * transition_cuts)
    for i in range(transition_cuts, 0, -1):
        depth += fine_cut + i * delta_delta_cut
        yield depth


def main():
    with open("lathe_turn_down.gcode","w") as f:
        x0 = 0
        y0 = 4
        x1 = 2
        y1 = 6
        cut_dir = [0, -1]
        d0 = 0
        d1 = 2

        f_cut = 20
        f_move = 150
        cut_path = [[x0, y0], [x1, y1]]
        clearance = [x * 0.2 for x in cut_dir]
        move_path = [[x - c for x,c in zip(xy, clearance)]
                for xy in reversed(cut_path)]

        for d in cut_depths(d0, d1):
            next_cut = [[x + c*d for x,c in zip(xy, cut_dir)]
                    for xy in cut_path]
            speed = f_move
            for x,y in next_cut:
                f.write("G0 X{0:.4f} Y{1:.4f} F{2}\n".format(x, y, speed))
                speed = f_cut
            for x,y in move_path:
                f.write("G0 X{0:.4f} Y{1:.4f} F{2}\n".format(x, y, f_move))

if __name__ == "__main__":
    main()
