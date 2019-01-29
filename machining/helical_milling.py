#!/usr/bin/python3
import math

inches = 25.4 # mm/inch

def mill_helix( f, x_center, y_center, hole_diameter, cutter_diameter,
        start_depth, end_depth, helix_pitch, cut_speed,
        segments_per_turn = 300 ):

        tool_circle_radius = (hole_diameter - cutter_diameter)/2
        num_turns = (start_depth - end_depth)/helix_pitch + 2
        num_steps = math.ceil(num_turns * segments_per_turn)

        for i in range(num_steps):
            x = x_center + tool_circle_radius * math.sin(
                    2 * math.pi * i / segments_per_turn)
            y = y_center + tool_circle_radius * math.cos(
                    2 * math.pi * i / segments_per_turn)
            z = max(end_depth, start_depth -
                helix_pitch * i * 1./ segments_per_turn)
            f.write(f"G1 X{x:5.3f} Y{y:5.3f} Z{z:5.3f} F{cut_speed}" +
                    f";{ i * 1./ segments_per_turn :5.3f}\n")

        f.write(f"G1 X{x_center:5.3f} Y{y_center:5.3f} " +
            f"Z{end_depth + tool_circle_radius:5.3f} F{cut_speed}\n")
        f.write(f"G0 X{x_center:5.3f} Y{y_center:5.3f} " +
            f"Z{start_depth + 1:5.3f} F{cut_speed}\n")


def main():
    with open("helical_milling.gcode","w") as f:

        settings = {
                "hole_diameter": 27./64 * inches,
                "cutter_diameter": 1./4 * inches,
                "start_depth": 0.5 + 1./4 * inches,
                "end_depth": 0,
                "helix_pitch": 1, # mm
                "cut_speed": 50,
        }

        x = -(0.25/2 + 0.5) * inches
        ys = [
                (-0.25/2 - 2 + 2.5/2 + 27./64) * inches,
                (-0.25/2 - 2 - 2.5/2 - 27./64) * inches,
                ]
        zmove = 17
        for y in ys:
            f.write(f"G0 Z{zmove} F50]\n")
            f.write(f"G0 X{x} Y{y} Z{zmove} F100\n")
            mill_helix(f, x, y, **settings)

        f.write(f"G0 Z{zmove}\n")
        f.write(f"G0 X0 Y0 Z{zmove}\n")

if __name__ == "__main__":
    main()
