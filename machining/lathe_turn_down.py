#!/usr/bin/python3
import math

def cut_to(y):
    move_clearance = 0.2
    f_move = 150
    f_cut = 20
    f.write("G0 X{0:.4f} Y{1:.4f} F{2}\n".format(x0, y, f_move))
    f.write("G1 X{0:.4f} Y{1:.4f} F{2}\n".format(x1, y, f_cut))
    f.write("G0 X{0:.4f} Y{1:.4f} F{2}\n".format(x1, y + move_clearance, f_move))
    f.write("G0 X{0:.4f} Y{1:.4f} F{2}\n".format(x0, y + move_clearance, f_move))

with open("lathe_turn_down.gcode","w") as f:
    x0 = 0
    y0 = 6
    x1 = 30
    y1 = 4
    big_cut = 0.1
    fine_cut = 0.02

    estimated_transition_cuts = max(12, math.ceil(big_cut/fine_cut))
    transition_diameter = y1 + 2 * estimated_transition_cuts * fine_cut

    y = y0
    while y > transition_diameter:
        y -= big_cut
        cut_to(y)

    transition_cuts = max(0, math.ceil((y-y1)/(2*fine_cut)))
    margin = y-y1 - transition_cuts * fine_cut
    delta_delta_cut = 2 * margin / ((transition_cuts + 1) * transition_cuts)
    for i in range(transition_cuts, 0, -1):
        y -= fine_cut + i * delta_delta_cut
        cut_to(y)
