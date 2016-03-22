// prints the first n primes, where n is specified at the command line
// The primes are printed one per line to make it easy to pipe them to a file
// or to another process.

#include <iostream>
#include <sstream>
#include <vector>

void usage() {
    std::cerr << "usage:\n\tfirst_n_primes <n>\n";
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

    // For the first version we'll use an incremental sieve
    // (simple, but inefficient)
    std::vector<unsigned long long> primes;
    primes.reserve(num_primes);

    unsigned long next_val = 2;
    while (primes.size() < num_primes) {
        bool factor_found = false;

        for (size_t i = 0; i < primes.size() && i*i < next_val; ++i) {
            if (next_val % primes[i] == 0) {
                factor_found = true;
                break;
            }
        }

        if (!factor_found) {
            std::cout << next_val << "\n";
            primes.push_back(next_val);
        }
        ++next_val;
    }

    return 0;
}
