#!/bin/env python3

import contextlib
import json
import re
import statistics
import subprocess
import sys
import time

@contextlib.contextmanager
def use_mtu(netdev, server_ip, mtu):
    # create a /32 route with the requested mtu
    subprocess.run(
        [
            "sudo",
            "ip",
            "route",
            "add",
            str(server_ip) + "/32",
            "dev", str(netdev),
            "mtu", str(mtu)
        ],
        capture_output=True,
        text=True,
        check=True
    )

    try:
        # do the work
        yield

    finally:
        # delete the route
        subprocess.run(
            [
                "sudo",
                "ip",
                "route",
                "del",
                str(server_ip) + "/32",
                "dev", str(netdev),
                "mtu", str(mtu)
            ],
            capture_output=True,
            text=True,
            check=True
        )


def iperf_rates(server_ip, duration, parallel):
    result = subprocess.run(
        [
            "iperf3",
            "--json",
            "--time", str(duration),
            "--parallel", str(parallel),
            "--bidi",
            "--client", str(server_ip)
        ],
        capture_output=True,
        text=True,
        check=True
    )

    output = json.loads(result.stdout)

    # allow the remote server to recover
    time.sleep(0.2)

    return [
        output["end"]["sum_received"]["bits_per_second"],
        output["end"]["sum_received_bidir_reverse"]["bits_per_second"]
    ]

def iperf_stats(server_ip, num_samples, duration, parallel):
    samples = []

    # warm-up run
    iperf_rates(server_ip, duration, parallel)

    for i in range(num_samples):
        print('.', end="", flush=True)
        samples += iperf_rates(server_ip, duration, parallel)

    giga = 1e9

    return statistics.mean(samples)/giga, statistics.stdev(samples)/giga

def ping_stats(server_ip):
    result = subprocess.run(
        [
            "sudo",
            "ping",
            "-fc", "10000",
            str(server_ip),
        ],
        capture_output=True,
        text=True,
        check=True
    )

    match = re.search(
        r"rtt min/avg/max/mdev = (\d+(?:\.\d*)?)/(\d+(?:\.\d*)?)/"
            + r"(\d+(?:\.\d*)?)/(\d+(?:\.\d*)?) ms",
        result.stdout
        )

    return [
        float(match.group(2)) * 1000,
        float(match.group(4)) * 1000,
    ]

def main():
    if len(sys.argv) != 3:
        sys.stderr.write(f"Usage:\n\t{sys.argv[0]} NETDEV IPERF_SERVER_IP\n")
        exit(1)

    _, netdev, server_ip = sys.argv

    settings = [ # mtu, threads
        ( 1500, 2 ),
        ( 3992, 2 ),
        ( 9000, 2 ),
        ( 9000, 6 ),
    ]

    for mtu, parallel in settings:
        print(f"trying {parallel} streams with a {mtu} mtu", flush=True, end='')

        with use_mtu(netdev, server_ip, mtu):
            mean, stdev = iperf_stats(server_ip, num_samples=10, duration=10, parallel=parallel)

        print(f"{mean:.3f}±{stdev:.3f} Gb/s")

    # warm up
    print(f"trying flood ping: ", flush=True, end='')
    ping_stats(server_ip)

    mean, stdev = ping_stats(server_ip)
    print(f"{mean}±{stdev} μs")

if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as e:
        print(f'Error when running command "{e.cmd}":')
        sys.stderr.write(e.stdout)
        sys.stderr.write(e.stderr)
        exit(1)
