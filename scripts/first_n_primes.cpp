// prints the first n primes, where n is specified at the command line
// The primes are printed one per line to make it easy to pipe them to a file
// or to another process.

#include <iostream>
#include <sstream>

#include "primes.h"

void usage() {
    std::cerr << "usage:\n\tfirst_n_primes <n>\n";
}

void output_n(size_t n) {
    std::cout << n << "\n";
}

int main(int argc, char** argv) {
    if (argc != 2) {
        usage();
        return 1;
    }

    size_t num_primes;
    std::istringstream is(argv[1]);
    is >> num_primes;
    if (!is) {
        usage();
        return 1;
    }

    first_n_primes(num_primes, output_n);

    return 0;
}
