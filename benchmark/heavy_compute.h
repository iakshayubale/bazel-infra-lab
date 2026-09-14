#pragma once

#include <vector>
#include <cmath>
#include <complex>
#include <algorithm>

namespace heavy_compute {

// Matrix operations
class MatrixCompute {
public:
    static void compute_matrix_multiply(int size);
    static void compute_matrix_inverse(int size);
    static void compute_eigenvalues(int size);
};

// Sorting algorithms
class SortCompute {
public:
    static void quick_sort_large();
    static void merge_sort_large();
    static void heap_sort_large();
};

// Cryptography operations
class CryptoCompute {
public:
    static void compute_sha256(int iterations);
    static void compute_rsa_operations();
};

// Encoding operations
class EncodingCompute {
public:
    static void compute_base64_encode(int size);
    static void compute_deflate_compress();
};

// Neural network template computations
template<typename T>
class NeuralCompute {
public:
    static void compute_forward_pass(int layers, int neurons);
    static void compute_backward_pass(int layers, int neurons);
};

}  // namespace heavy_compute
