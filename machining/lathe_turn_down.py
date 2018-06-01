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


def gcode_coords(names, values):
    return " ".join(
        ["{0}{1:.4f}".format(l,x) for l,x in zip(names, values)]
    )


def main():
    with open("lathe_turn_down.gcode","w") as f:
        coordinates = ['X', 'Y', 'A']
        pitch = 1.25
        cut_path = [[0, 4, 0], [27 - pitch, 4, -27/pitch + 1], [27, 5, -27/pitch]]
        theta = math.pi/6
        cut_dir = [-math.sin(theta), -math.cos(theta), 0]
        d0 = 1.15
        d1 = 1.25
        #f.write("M92 A3200\n")

        cut_speed = 20
        move_speed = 50
        clearance = [x * 0.2 for x in cut_dir]
        move_path = [[x - c for x,c in zip(xs, clearance)]
                for xs in reversed(cut_path)]

        for d in cut_depths(d0, d1):
            next_cut = [[x + c*d for x,c in zip(xy, cut_dir)]
                    for xy in cut_path]
            speed = move_speed
            for xs in next_cut:
                f.write("G0 {0} F{1}\n".format(
                    gcode_coords(coordinates, xs), speed)
                );
                speed = cut_speed
            for xs in move_path:
                f.write("G0 {0} F{1}\n".format(
                    gcode_coords(coordinates, xs), move_speed)
                );

if __name__ == "__main__":
    main()
