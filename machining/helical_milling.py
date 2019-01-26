#!/usr/bin/python3
import math

inches = 25.4 # mm/inch

def main():
    with open("helical_milling.gcode","w") as f:
        x_center = 11./64 * inches
        y_center = 0.
        hole_diameter = 27./64 * inches

        cutter_diameter = 1./4 * inches
        start_depth = 0.
        end_depth = -0.6 * inches

        helix_pitch = 1 # mm
        segments_per_turn = 300
        cut_speed = 50

        tool_circle_radius = (hole_diameter - cutter_diameter)/2

        num_turns = (start_depth - end_depth)/helix_pitch + 1
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
            f"Z{start_depth + 10:5.3f} F{cut_speed}\n")

if __name__ == "__main__":
    main()
