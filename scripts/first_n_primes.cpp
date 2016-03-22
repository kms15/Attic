// prints the first n primes, where n is specified at the command line
// The primes are printed one per line to make it easy to pipe them to a file
// or to another process.

#include <iostream>
#include <sstream>
#include <vector>
#include <cmath>

void usage() {
    std::cerr << "usage:\n\tfirst_n_primes <n>\n";
}

typedef unsigned long long uint;

uint upper_bound_for_nth_prime(uint n) {
    if (n < 6) {
        return 11;
    } else {
        return (uint)(n * (std::log(n) + std::log(std::log(n))));
    }
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

    // For this version we'll use the sieve of Eratosthenese
    // optimized to consider only odd numbers
    if (num_primes >= 1) {
        std::vector<bool> is_prime(
                (upper_bound_for_nth_prime(num_primes) + 1)/2,
                true);
        size_t primes_found = 1;
        size_t last_prime = 1;
        is_prime[1/2] = false;
        while (primes_found < num_primes) {
            // skip to the next possible prime number
            while (!is_prime[(last_prime += 2)/2]) {
            }
            ++primes_found;

            // cross off all multiples of that number
            // (skipping the multiples of 2 since they won't be odd)
            for (size_t mult = 3*last_prime; mult/2 < is_prime.size();
                    mult += 2*last_prime) {
                is_prime[mult/2] = false;
            }
        }

        // drain the sieve
        std::cout << "2\n";
        size_t prev_prime = 1;
        while (prev_prime != last_prime) {
            // skip to the next possible prime number
            while (!is_prime[(prev_prime += 2)/2]) {
            }
            std::cout << prev_prime << "\n";
        }
    }

    return 0;
}
