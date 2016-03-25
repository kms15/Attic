#ifndef PRIMES_H
#define PRIMES_H

#include <vector>
#include <cmath>
#include <cassert>

// Quickly finds an integer guaranteed to be greater than or equal to the nth
// prime number.
inline size_t upper_bound_for_nth_prime(size_t n) {
    if (n < 6) {
        return 11;
    } else {
        return (size_t)(n * (std::log(n) + std::log(std::log(n))));
    }
}


// Finds the first n primes, calling output(prime) each time it finds one.
template <class OutputFunc>
void first_n_primes(size_t num_primes, OutputFunc& output) {
    size_t upper_bound = upper_bound_for_nth_prime(num_primes);
    if (num_primes >= 1) {
        // output the one even prime
        size_t primes_found = 1;
        output(2);

        // then use the sieve of Eratosthenese
        // optimized to consider only odd numbers

        // Bit vector for all odd numbers up to upper bound, storing whether
        // we have found a factor of the number.
        std::vector<bool> found_factor((upper_bound + 1)/2, false);

        // For algorithmic convenience we pretend 1 was prime.
        size_t last_prime = 1;
        while (primes_found < num_primes) {
            // skip to the next number that hasn't been crossed off as a
            // multiple of a previous number.
            while (found_factor[(last_prime += 2)/2]) {
            }

            // Since it's not a multiple of a previous number, it's a prime.
            ++primes_found;
            output(last_prime);

            // cross off all multiples of that number
            // (skipping the multiples of 2 since they won't be odd)
            for (size_t mult = 3*last_prime; mult/2 < upper_bound/2;
                    mult += 2*last_prime) {
                found_factor[mult/2] = true;
            }
        }
    }
}

#endif /* PRIMES_H */
